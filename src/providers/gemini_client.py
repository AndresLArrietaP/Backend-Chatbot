# src/providers/gemini_client.py
from typing import Any, List, Dict, Optional
from decouple import config as env
import json
import re
import time
from google import genai
from google.genai import errors as genai_errors
from logging import getLogger

log = getLogger(__name__)

def _compact_rows_for_summary(rows: List[Dict[str, Any]], max_chars: int = 8000) -> str:
    """
    Compacta filas a un JSON con tamaño acotado:
      - Trunca strings > 200 chars.
      - Si aún excede max_chars, reduce filas por binary search.
    """
    if not rows:
        return "[]"
    out: List[Dict[str, Any]] = []
    for r in rows:
        nr: Dict[str, Any] = {}
        for k, v in (r or {}).items():
            if isinstance(v, str) and len(v) > 200:
                nr[k] = v[:200] + "…"
            else:
                nr[k] = v
        out.append(nr)

    s = json.dumps(out, ensure_ascii=False)
    if len(s) <= max_chars:
        return s

    lo, hi = 0, len(out)
    best = "[]"
    while lo < hi:
        mid = (lo + hi) // 2
        s2 = json.dumps(out[:max(1, mid)], ensure_ascii=False)
        if len(s2) <= max_chars:
            best = s2
            lo = mid + 1
        else:
            hi = mid
    return best


class GeminiProvider:
    def __init__(self) -> None:
        api_key = (env("GOOGLE_API_KEY", default="") or "").strip()
        if not api_key:
            raise RuntimeError("Falta GOOGLE_API_KEY en .env")
        self.client = genai.Client(api_key=api_key)

    def _resolve_model(self, name: Optional[str]) -> str:
        nm = (name or env("GEMINI_MODEL", default="gemini-1.5-flash")).strip()
        return nm if nm.startswith("models/") else f"models/{nm}"

    def _resolve_answer_model(self, name: Optional[str]) -> str:
        """
        Permite un modelo distinto para el RESUMEN (si no se define, usa GEMINI_MODEL).
        Puedes setear GEMINI_MODEL_ANSWER en .env para separar cargas.
        """
        nm = (name or env("GEMINI_MODEL_ANSWER", default=env("GEMINI_MODEL", default="gemini-1.5-flash"))).strip()
        return nm if nm.startswith("models/") else f"models/{nm}"

    def _dialect_quote(self, dialect: str) -> str:
        d = (dialect or "postgresql").lower()
        if d in ("postgresql","sqlite"):
            return 'Use double quotes for identifiers.'
        if d == "mysql":
            return 'Use backticks for identifiers.'
        if d in ("mssql","sqlserver"):
            return 'Use square brackets for identifiers.'
        return 'Use double quotes by default.'

    def list_models(self) -> Dict[str, Any]:
        items = []
        for m in self.client.models.list():
            methods = getattr(m, "supported_generation_methods", None) or getattr(m, "generation_methods", None)
            items.append({"name": m.name, "methods": methods})
        return {"status": "ok", "models": items}

    def _ensure_sql_json(self, text_payload: str) -> str:
        """
        Asegura que el modelo devolvió un JSON con al menos "sql_query".
        Si vino mezclado con texto, intenta extraer el primer objeto JSON.
        """
        def _try(s: str) -> Optional[str]:
            try:
                obj = json.loads(s)
                if isinstance(obj, dict) and "sql_query" in obj:
                    return json.dumps(obj, ensure_ascii=False)
            except Exception:
                return None
            return None

        ok = _try(text_payload.strip())
        if ok:
            return ok

        m = re.search(r"\{.*\}", text_payload, re.DOTALL)
        if m:
            ok = _try(m.group(0))
            if ok:
                return ok

        raise RuntimeError(f"Gemini devolvió un formato inesperado: {text_payload[:300]}")

    async def human_query_to_sql(
        self,
        human_query: str,
        schema_json: Dict[str,Any],
        dialect: str="postgresql",
        default_limit: int=100,
        model: Optional[str]=None
    ) -> str:
        # Enviamos nombres + tipos para que el modelo sepa cuándo castear
        schema_compact = [
            {
                "schema": t["schema"],
                "table": t["table"],
                "columns": [{"name": c["name"], "type": c.get("type", "")} for c in t["columns"]],
                "fq_name": t.get("fq_name")
            }
            for t in schema_json.get("tables", [])
        ]
        fq_names = [t.get("fq_name") for t in schema_json.get("tables", []) if t.get("fq_name")]

        system_prompt = f"""
You are a careful SQL generator for {dialect.upper()}.

Rules:
- Generate only READ-ONLY statements:
  * Allowed: SELECT queries (including WITH/CTE), window functions, aggregates (SUM/COUNT/AVG...), scalar functions, and optionally EXPLAIN (without ANALYZE).
  * Avoid any data-modifying or destructive statements: INSERT, UPDATE, DELETE, DROP, ALTER, TRUNCATE, CREATE, MERGE, REPLACE, COPY, VACUUM, GRANT, REVOKE.
- Use ONLY tables/columns from the provided schema JSON (do not hallucinate).
- {self._dialect_quote(dialect)}
- If identifiers contain spaces or accents, quote them accordingly (e.g., "Fecha de Pedido").
- Prefer fully-qualified names exactly as listed in <allowed_fqn> when referencing tables (e.g., public."Table").
- If the user asks for totals or grouping (e.g., "total", "por cada ..."), generate proper aggregates with GROUP BY and SUM/COUNT/AVG as appropriate.
- IMPORTANT (PostgreSQL): if a numeric aggregation is required and the column type is TEXT/VARCHAR or the values include formatting (thousands separators, currency),
  convert it to NUMERIC safely using this pattern:
  COALESCE(NULLIF(REGEXP_REPLACE("Col", '[^0-9\\.-]', '', 'g'), '')::numeric, 0)
- Include a meaningful ORDER BY when helpful.
- Add LIMIT {default_limit} if the user didn't specify it.
- Return a strict JSON object with keys: "sql_query" and "original_query". No extra keys.

<schema_json>
{json.dumps(schema_compact, ensure_ascii=False)}
</schema_json>

<allowed_fqn>
{json.dumps(fq_names, ensure_ascii=False)}
</allowed_fqn>
""".strip()

        mdl = self._resolve_model(model)
        resp = self.client.models.generate_content(
            model=mdl,
            contents=[
                {"role": "system", "parts": [{"text": system_prompt}]},
                {"role": "user",   "parts": [{"text": human_query}]}
            ],
            config={"response_mime_type": "application/json"}
        )
        log.debug("[gemini.human_query_to_sql] resp.text=%s", (resp.text[:800] if resp and resp.text else None))
        return self._ensure_sql_json(resp.text or "")

    async def build_answer(
        self,
        rows: List[Dict[str,Any]],
        human_query: str,
        model: Optional[str]=None
    ) -> str:
        """
        Resumen robusto:
          - compacta filas
          - reintenta 3 veces con backoff incremental
          - fallback entre varios modelos si 503/429
        """
        rows_json = _compact_rows_for_summary(rows, max_chars=8000)

        prompt = f"""
Eres un analista. Resume en español (6–8 oraciones) la respuesta a la pregunta del usuario,
citando cifras y observaciones clave a partir de las filas provistas.

Pregunta:
{human_query}

Filas (JSON):
{rows_json}

Instrucciones:
- Menciona totales, agrupaciones o tendencias cuando sean evidentes.
- Si no hay datos suficientes o están vacíos, díselo explícitamente.
- No inventes campos que no existan en las filas.
""".strip()

        primary = self._resolve_answer_model(model)
        mdl_candidates = [
            primary,
            "models/gemini-1.5-flash",
            "models/gemini-flash-latest",
            "models/gemini-1.5-pro",
        ]

        last_err: Optional[Exception] = None
        for attempt in range(3):
            for mdl in mdl_candidates:
                try:
                    resp = self.client.models.generate_content(model=mdl, contents=prompt)
                    text = (resp.text or "").strip()
                    if text:
                        return text
                    last_err = RuntimeError("Respuesta vacía del modelo")
                except (genai_errors.ServerError, genai_errors.APIError) as e:
                    last_err = e
                except Exception as e:
                    last_err = e
            time.sleep(1.5 * (attempt + 1))

        raise RuntimeError(f"Fallo build_answer tras reintentos/fallbacks: {last_err}")

    async def ping(self, model: Optional[str]=None) -> str:
        mdl = self._resolve_model(model)
        resp = self.client.models.generate_content(model=mdl, contents="ping")
        return resp.text or ""