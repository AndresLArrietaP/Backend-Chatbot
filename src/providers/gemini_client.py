from typing import Any, List, Dict, Optional
from decouple import config as env
import json
import re
import time
import asyncio
from decimal import Decimal
from datetime import date, datetime
from google import genai
from logging import getLogger

log = getLogger(__name__)


# ============================= Utilidades comunes =============================

def _to_json_safe(v: Any) -> Any:
    if isinstance(v, Decimal):
        return float(v)
    if isinstance(v, (datetime, date)):
        return v.isoformat()
    if isinstance(v, list):
        return [_to_json_safe(x) for x in v]
    if isinstance(v, tuple):
        return tuple(_to_json_safe(x) for x in v)
    if isinstance(v, dict):
        return {k: _to_json_safe(val) for k, val in v.items()}
    return v


def _compact_rows_for_summary(rows: List[Dict[str, Any]], max_rows: int, max_chars: int) -> str:
    """Recorta filas y longitud total para limitar tokens/latencia."""
    if not rows:
        return "[]"

    def _norm_row(r: Dict[str, Any]) -> Dict[str, Any]:
        out: Dict[str, Any] = {}
        for k, v in (r or {}).items():
            v2 = _to_json_safe(v)
            if isinstance(v2, str) and len(v2) > 200:
                out[k] = v2[:200] + "…"
            else:
                out[k] = v2
        return out

    data = [_norm_row(r) for r in rows[:max_rows]]
    s = json.dumps(data, ensure_ascii=False)
    if len(s) <= max_chars:
        return s

    lo, hi = 1, len(data)
    best = "[]"
    while lo <= hi:
        mid = (lo + hi) // 2
        s2 = json.dumps(data[:mid], ensure_ascii=False)
        if len(s2) <= max_chars:
            best = s2
            lo = mid + 1
        else:
            hi = mid - 1
    return best


def _parse_retry_after_secs(msg: str) -> float:
    """Extrae 'retry in Xs' del mensaje (X en 1..60s)."""
    m = re.search(r"retry in\s+([0-9]+(?:\.[0-9]+)?)s", (msg or "").lower())
    if m:
        try:
            v = float(m.group(1))
            return max(1.0, min(v, 60.0))
        except Exception:
            return 0.0
    return 0.0


def _ex_msg(e: Exception) -> str:
    status = (getattr(e, "status", "") or "")
    code = (getattr(e, "code", "") or "")
    msg = (getattr(e, "message", "") or str(e))
    return f"status={status} code={code} msg={msg}"


# ============================ Proveedor Gemini ================================

class GeminiProvider:
    """
    - Usa system_instruction en config (no role system).
    - Filtra candidatos contra modelos visibles por tu clave/proyecto.
    - Maneja 404/429 con fallback/espera.
    - build_answer devuelve TEXTO (no JSON escapado).
    """

    def __init__(self) -> None:
        api_key = (env("GOOGLE_API_KEY", default="") or "").strip()
        if not api_key:
            raise RuntimeError("Falta GOOGLE_API_KEY en .env")
        self.client = genai.Client(api_key=api_key)

        self._available_names: List[str] = []
        try:
            self._available_names = [m.name for m in self.client.models.list() if getattr(m, "name", "")]
            log.info("[gemini] modelos visibles: %s", self._available_names)
        except Exception as e:
            log.warning("[gemini] No se pudo listar modelos: %s", e)
            self._available_names = []

    # ------------------------- Resolución de modelos --------------------------

    def _resolve_model(self, name: Optional[str]) -> str:
        # Default NUEVO recomendado: gemini-3-flash (si tu cuenta lo tiene)
        nm = (name or env("GEMINI_MODEL", default="gemini-3-flash")).strip()
        return nm if nm.startswith("models/") else f"models/{nm}"

    def _resolve_answer_model(self, name: Optional[str]) -> str:
        nm = (
            name
            or env("GEMINI_MODEL_ANSWER", default=env("GEMINI_MODEL", default="gemini-3-flash"))
        ).strip()
        return nm if nm.startswith("models/") else f"models/{nm}"

    def _fallback_chain(self, primary_full: str, env_key: str) -> List[str]:
        """
        Crea cadena de candidatos intersectando con modelos realmente visibles.
        """
        raw = env(env_key, default="")
        env_list = [s.strip() for s in raw.split(",") if s.strip()]

        # Defaults orientados a tu panel (Gemini 3 / 2.5 / 2)
        defaults = [
            "models/gemini-3-pro",
            "models/gemini-3-flash",
            "models/gemini-2.5-pro",
            "models/gemini-2.5-flash",
            "models/gemini-2-flash",
            "models/gemini-2-flash-lite",
        ]

        def norm(m: str) -> str:
            return m if m.startswith("models/") else f"models/{m}"

        chain_all: List[str] = []
        seen = set()
        for m in [primary_full] + [norm(x) for x in env_list] + defaults:
            if m and m not in seen:
                chain_all.append(m)
                seen.add(m)

        if not self._available_names:
            return chain_all

        chain = [m for m in chain_all if m in self._available_names]
        return chain or chain_all

    # ----------------------------- Timeouts/Hedging ---------------------------

    def _timeouts(self) -> Dict[str, float]:
        return {
            "per_model_timeout": env("LLM_PER_MODEL_TIMEOUT", default=16.0, cast=float),
            "total_timeout": env("LLM_TOTAL_TIMEOUT", default=32.0, cast=float),
            "hedge_stagger": env("LLM_HEDGE_STAGGER", default=0.5, cast=float),
            "hedge_parallel": env("LLM_HEDGE_PARALLEL", default=2, cast=int),
        }

    async def _call_generate(self, model: str, contents: Any, config: Dict[str, Any], per_model_timeout: float):
        try:
            resp = await asyncio.wait_for(
                asyncio.to_thread(self.client.models.generate_content, model=model, contents=contents, config=config),
                timeout=per_model_timeout
            )
            return resp
        except Exception as e:
            return e

    # -------------------------- Validación de JSON SQL ------------------------

    def _ensure_sql_json(self, payload: str) -> str:
        def _try(s: str) -> Optional[str]:
            try:
                obj = json.loads(s)
                if isinstance(obj, dict) and "sql_query" in obj:
                    obj.setdefault("original_query", "")
                    return json.dumps(obj, ensure_ascii=False)
            except Exception:
                return None

        t = (payload or "").strip()
        ok = _try(t)
        if ok:
            return ok

        m = re.search(r"\{.*\}", t, re.DOTALL)
        if m:
            ok = _try(m.group(0))
            if ok:
                return ok

        raise RuntimeError(f"Gemini devolvió un formato inesperado: {t[:300]}")

    # -------------------------------- NL -> SQL --------------------------------

    async def human_query_to_sql(
        self,
        human_query: str,
        schema_json: Dict[str, Any],
        dialect: str = "postgresql",
        default_limit: int = 100,
        model: Optional[str] = None
    ) -> str:

        schema_compact = [
            {
                "schema": t["schema"],
                "table": t["table"],
                "columns": [{"name": c["name"], "type": c.get("type", "")} for c in t["columns"]],
                "fq_name": t.get("fq_name"),
            }
            for t in schema_json.get("tables", [])
        ]
        fq_names = [t.get("fq_name") for t in schema_json.get("tables", []) if t.get("fq_name")]

        system_instruction = fr"""
You are a careful SQL generator for {dialect.upper()}.

Rules:
- Only READ-ONLY statements (SELECT/CTE/EXPLAIN without ANALYZE). No INSERT/UPDATE/DELETE/DDL/CALL.
- Use only tables/columns from the provided schema. Do not hallucinate.
- {self._dialect_quote(dialect)}
- Quote identifiers with spaces/accents (e.g., "Fecha de Pedido").
- Prefer fully-qualified names as in <allowed_fqn>.
- Use macros (server expands): NUMERIC_CLEAN("Col"), DATE_PARSE("Col").

IMPORTANT:
- Do NOT add UNION, ROLLUP, CUBE, GROUPING SETS, or any total/overall rows.
- Do NOT return “total” rows (no summary rows); return only the per-group rows requested.

When grouping by a key, exclude totals/footer rows and blank keys:
  WHERE COALESCE(TRIM("Key"), '') <> ''
    AND "Key" !~* '^\s*total'
    AND "Key" !~* '^\s*gran\s*total'
    AND "Key" !~* '^\s*totales'

- Include a meaningful ORDER BY when aggregating (e.g., ORDER BY SUM(...) DESC).
- Add LIMIT {default_limit} if missing.

Return ONLY:
{{
  "sql_query": "...",
  "original_query": "{human_query}"
}}

<schema_json>
{json.dumps(schema_compact, ensure_ascii=False)}
</schema_json>
<allowed_fqn>
{json.dumps(fq_names, ensure_ascii=False)}
</allowed_fqn>
""".strip()

        primary_full = self._resolve_model(model)
        models = self._fallback_chain(primary_full, "GEMINI_MODEL_CANDIDATES")

        tcfg = self._timeouts()
        per_model_timeout = tcfg["per_model_timeout"]
        total_timeout = tcfg["total_timeout"]
        hedge_stagger = tcfg["hedge_stagger"]
        hedge_parallel = max(1, tcfg["hedge_parallel"])

        contents = [{"role": "user", "parts": [{"text": human_query}]}]
        config = {
            "response_mime_type": "application/json",
            "temperature": 0.08,
            "max_output_tokens": 900,
            "system_instruction": system_instruction,
        }

        start = time.time()
        tasks: List[asyncio.Task] = []
        launched = 0
        errors: List[str] = []
        winner: Optional[str] = None

        async def _launch(m: str):
            res = await self._call_generate(m, contents, config, per_model_timeout)
            return m, res

        for i in range(min(hedge_parallel, len(models))):
            tasks.append(asyncio.create_task(_launch(models[i])))
            launched += 1

        while (time.time() - start) < total_timeout and tasks:
            remaining = max(0.1, total_timeout - (time.time() - start))
            done, pending = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED, timeout=remaining)

            if not done:
                if launched < len(models):
                    await asyncio.sleep(hedge_stagger)
                    tasks.append(asyncio.create_task(_launch(models[launched])))
                    launched += 1
                else:
                    break
                continue

            for d in done:
                mdl, res = await d
                if isinstance(res, Exception):
                    msg = _ex_msg(res)
                    errors.append(f"{mdl}: {msg}")

                    status = (getattr(res, "status", "") or "").upper()
                    code = (getattr(res, "code", "") or "")
                    code_str = str(code).upper()

                    if status == "NOT_FOUND" or "not found" in msg.lower() or "no longer available" in msg.lower():
                        continue

                    if status == "RESOURCE_EXHAUSTED" or code_str == "429":
                        wait_s = _parse_retry_after_secs(msg)
                        if wait_s > 0:
                            await asyncio.sleep(wait_s)
                        continue

                    continue

                for p in pending:
                    p.cancel()
                txt = (res.text or "").strip()
                if txt:
                    log.info("[gemini.human_query_to_sql] winner=%s (lat=%.2fs)", mdl, time.time() - start)
                    winner = txt
                    tasks.clear()
                    break
                errors.append(f"{mdl}: respuesta vacía")

            tasks = [t for t in tasks if not t.done()]
            if winner:
                break

            if launched < len(models) and len(tasks) < hedge_parallel:
                await asyncio.sleep(hedge_stagger)
                tasks.append(asyncio.create_task(_launch(models[launched])))
                launched += 1

        if winner:
            return self._ensure_sql_json(winner)

        # Fallback secuencial si todo falló
        for mdl in models:
            try:
                res = await asyncio.wait_for(
                    asyncio.to_thread(self.client.models.generate_content, model=mdl, contents=contents, config=config),
                    timeout=per_model_timeout * 1.25
                )
                txt = (res.text or "").strip()
                if txt:
                    log.info("[gemini.human_query_to_sql] winner(sequential)=%s", mdl)
                    return self._ensure_sql_json(txt)
            except Exception as e:
                errors.append(f"{mdl}: {_ex_msg(e)}")

        raise RuntimeError("Fallo human_query_to_sql: " + " ; ".join(errors[-8:]))

    # ---------------------------- Answer Rendering ----------------------------

    def _render_answer_obj(self, obj: Dict[str, Any]) -> str:
        """
        Render final a texto (para que no salga JSON escapado).
        Espera: {summary: str, insights: [str], caveats: [str]}
        """
        summary = (obj.get("summary") or "").strip()
        insights = obj.get("insights") or []
        caveats = obj.get("caveats") or []

        def clean_list(xs, max_n):
            out = []
            for x in (xs or [])[:max_n]:
                if isinstance(x, str):
                    t = re.sub(r"\s+", " ", x.strip())
                    t = re.sub(r"^(\*|-|•|\u2022)\s*", "", t)
                    if t:
                        out.append(t)
            return out

        ins = clean_list(insights, 5)
        cav = clean_list(caveats, 2)

        lines: List[str] = []
        if summary:
            lines.append(summary if summary.endswith(('.', '!', '?')) else summary + ".")

        for t in ins:
            lines.append(f"- {t}")

        for t in cav:
            lines.append(f"Nota: {t}")

        return "\n".join(lines).strip()

    # -------------------------------- Resumen --------------------------------

    async def build_answer(
        self,
        rows: List[Dict[str, Any]],
        human_query: str,
        model: Optional[str] = None
    ) -> str:
        """
        Devuelve TEXTO final (no JSON string).
        Objetivo: “analista senior” (2–4 bullets con insights y 0–2 caveats).
        """

        max_rows = int(env("ANSWER_MAX_ROWS", default=140))
        max_chars = int(env("ANSWER_MAX_CHARS", default=3800))
        rows_json = _compact_rows_for_summary(rows, max_rows=max_rows, max_chars=max_chars)

        schema = {
            "type": "object",
            "properties": {
                "summary": {"type": "string"},
                "insights": {"type": "array", "items": {"type": "string"}, "minItems": 0, "maxItems": 6},
                "caveats": {"type": "array", "items": {"type": "string"}, "minItems": 0, "maxItems": 4},
            },
            "required": ["summary"],
            "additionalProperties": False
        }

        system_instruction = json.dumps(schema, ensure_ascii=False)

        prompt = (
            "Eres un ANALISTA SENIOR de datos. Interpreta la información con enfoque ejecutivo.\n"
            "Devuelve EXCLUSIVAMENTE un JSON válido con este schema (sin markdown):\n"
            '{ "summary": "...", "insights": ["..."], "caveats": ["..."] }\n\n'
            "Reglas:\n"
            "- Usa solo lo que está en las filas; no inventes.\n"
            "- En insights: incluye hallazgos accionables (concentración, ranking, outliers, caídas a cero, etc.).\n"
            "- No repitas valores innecesariamente; sintetiza.\n"
            "- Caveats: máximo 2, solo si hay posibles problemas de calidad (nulos, ceros, datos truncados, etc.).\n\n"
            f"Pregunta:\n{human_query}\n\n"
            f"Filas (JSON truncado):\n{rows_json}\n"
        ).strip()

        primary_full = self._resolve_answer_model(model)
        models = self._fallback_chain(primary_full, "GEMINI_MODEL_ANSWER_CANDIDATES")

        # Preferimos calidad: secuencial, más tokens
        per_model_timeout = float(env("ANSWER_PER_MODEL_TIMEOUT", default=25.0))
        total_timeout = float(env("ANSWER_TOTAL_TIMEOUT", default=55.0))

        base_contents = [{"role": "user", "parts": [{"text": prompt}]}]
        base_config = {
            "response_mime_type": "application/json",
            "temperature": float(env("ANSWER_TEMPERATURE", default=0.18)),
            "max_output_tokens": int(env("ANSWER_MAX_OUTPUT_TOKENS", default=1400)),
            "system_instruction": system_instruction,
        }

        start = time.time()
        errors: List[str] = []

        def _first_json(s: str) -> Optional[Dict[str, Any]]:
            s = (s or "").strip()
            try:
                obj = json.loads(s)
                if isinstance(obj, dict):
                    return obj
            except Exception:
                pass
            m = re.search(r"\{.*\}", s, re.DOTALL)
            if not m:
                return None
            try:
                obj = json.loads(m.group(0))
                if isinstance(obj, dict):
                    return obj
            except Exception:
                return None
            return None

        async def _invoke(mdl: str, contents, config, timeout_s: float):
            try:
                resp = await asyncio.wait_for(
                    asyncio.to_thread(self.client.models.generate_content, model=mdl, contents=contents, config=config),
                    timeout=timeout_s
                )
                return resp.text or ""
            except Exception as e:
                return e

        for mdl in models:
            rem = total_timeout - (time.time() - start)
            if rem <= 0.5:
                break

            # 2 intentos por modelo (mejor JSON)
            for attempt in range(2):
                rem2 = total_timeout - (time.time() - start)
                if rem2 <= 0.5:
                    break

                timeout_this = min(per_model_timeout * (1.0 + 0.25 * attempt), rem2)
                txt = await _invoke(mdl, base_contents, base_config, timeout_this)

                if isinstance(txt, Exception):
                    msg = _ex_msg(txt)
                    errors.append(f"{mdl}: {msg}")

                    status = (getattr(txt, "status", "") or "").upper()
                    code = (getattr(txt, "code", "") or "")
                    code_str = str(code).upper()

                    if status == "NOT_FOUND" or "not found" in msg.lower() or "no longer available" in msg.lower():
                        break

                    if status == "RESOURCE_EXHAUSTED" or code_str == "429":
                        wait_s = _parse_retry_after_secs(msg)
                        if wait_s > 0 and rem2 > wait_s:
                            await asyncio.sleep(wait_s)
                        continue

                    continue

                obj = _first_json(txt)
                if obj:
                    # Render a texto
                    rendered = self._render_answer_obj(obj)
                    if rendered:
                        log.info("[gemini.build_answer] winner=%s attempt=%d lat=%.2fs", mdl, attempt + 1, time.time() - start)
                        return rendered[:1600]

                # Auto-fix: “corrige a JSON”
                fix_prompt = (
                    "Corrige el siguiente texto a un JSON VÁLIDO que cumpla exactamente el schema:\n"
                    f"{(txt or '')[:5000]}"
                )
                fix_contents = [{"role": "user", "parts": [{"text": fix_prompt}]}]
                fix_txt = await _invoke(mdl, fix_contents, base_config, min(10.0, rem2))

                if not isinstance(fix_txt, Exception):
                    obj2 = _first_json(fix_txt)
                    if obj2:
                        rendered = self._render_answer_obj(obj2)
                        if rendered:
                            log.info("[gemini.build_answer] winner(fix)=%s lat=%.2fs", mdl, time.time() - start)
                            return rendered[:1600]

                errors.append(f"{mdl}: sin JSON válido (attempt {attempt + 1})")

        log.warning("[gemini.build_answer] sin JSON: %s", "; ".join(errors[-8:]))
        return ""

    # --------------------------------- Ping -----------------------------------

    async def ping(self, model: Optional[str] = None) -> str:
        primary_full = self._resolve_model(model)
        models = self._fallback_chain(primary_full, "GEMINI_MODEL_CANDIDATES")
        last = ""
        for m in models:
            try:
                resp = await asyncio.to_thread(
                    self.client.models.generate_content,
                    model=m,
                    contents=[{"role": "user", "parts": [{"text": "ping"}]}],
                )
                t = (resp.text or "").strip()
                if t:
                    return t
                last = t
            except Exception as e:
                log.warning("[gemini] ping falló con %s: %s", m, e)
                continue
        return last

    # --------------------------------- Aux ------------------------------------

    def _dialect_quote(self, dialect: str) -> str:
        d = (dialect or "postgresql").lower()
        if d in ("postgresql", "sqlite"):
            return 'Use double quotes for identifiers.'
        if d == "mysql":
            return 'Use backticks for identifiers.'
        if d in ("mssql", "sqlserver"):
            return 'Use square brackets for identifiers.'
        return 'Use double quotes by default.'

    def list_models(self) -> Dict[str, Any]:
        items = []
        try:
            for m in self.client.models.list():
                methods = getattr(m, "supported_generation_methods", None) or getattr(m, "generation_methods", None)
                items.append({"name": m.name, "methods": methods})
            return {"status": "ok", "models": items}
        except Exception as e:
            return {"status": "error", "detail": str(e)}