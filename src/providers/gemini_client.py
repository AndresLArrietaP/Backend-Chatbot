# src/providers/gemini_client.py
from typing import Any, List, Dict, Optional, Tuple
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
    """Recorta filas y longitud total para limitar tokens/latencia (solo CONTEXTO, no output final)."""
    if not rows:
        return "[]"

    def _norm_row(r: Dict[str, Any]) -> Dict[str, Any]:
        out: Dict[str, Any] = {}
        for k, v in (r or {}).items():
            v2 = _to_json_safe(v)
            if isinstance(v2, str) and len(v2) > 220:
                out[k] = v2[:220] + "…"
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


# ======================= Perfil analítico determinístico =======================

def _try_float(v: Any) -> Optional[float]:
    try:
        if v is None:
            return None
        if isinstance(v, Decimal):
            return float(v)
        if isinstance(v, (int, float)):
            return float(v)
        if isinstance(v, str):
            s = v.strip()
            if not s:
                return None

            # EU: 1.234,56
            if re.search(r"\d,\d{1,}\s*$", s) and "." in s:
                s = s.replace(".", "").replace(",", ".")
            else:
                # US: 1,234.56
                s = s.replace(",", "")

            s = re.sub(r"[^0-9\.\-]", "", s)
            if s in ("", "-", ".", "-."):
                return None
            return float(s)
    except Exception:
        return None
    return None


def _compute_profile(rows: List[Dict[str, Any]], max_keys_top: int = 8) -> Dict[str, Any]:
    if not rows:
        return {"row_count": 0, "numeric": {}, "categorical": {}, "notes": ["no_rows"]}

    cols = list(rows[0].keys())
    num_vals: Dict[str, List[float]] = {c: [] for c in cols}
    cat_counts: Dict[str, Dict[str, int]] = {c: {} for c in cols}

    sample = rows[: min(len(rows), 5000)]

    for r in sample:
        for c in cols:
            v = r.get(c)
            fv = _try_float(v)
            if fv is not None:
                num_vals[c].append(fv)
            else:
                if isinstance(v, str):
                    t = v.strip()
                    if t:
                        cat_counts[c][t] = cat_counts[c].get(t, 0) + 1

    numeric: Dict[str, Any] = {}
    for c, vals in num_vals.items():
        if len(vals) < 5:
            continue
        vs = sorted(vals)
        n = len(vs)

        mn = vs[0]
        mx = vs[-1]
        mean = sum(vs) / n
        median = vs[n // 2] if n % 2 == 1 else 0.5 * (vs[n // 2 - 1] + vs[n // 2])
        p90 = vs[int(0.90 * (n - 1))]
        zeros = sum(1 for x in vs if abs(x) < 1e-12)

        q1 = vs[int(0.25 * (n - 1))]
        q3 = vs[int(0.75 * (n - 1))]
        iqr = max(1e-12, (q3 - q1))
        upper = q3 + 1.5 * iqr
        lower = q1 - 1.5 * iqr
        out_hi = sum(1 for x in vs if x > upper)
        out_lo = sum(1 for x in vs if x < lower)

        numeric[c] = {
            "n": n,
            "min": mn,
            "max": mx,
            "mean": mean,
            "median": median,
            "p90": p90,
            "q1": q1,
            "q3": q3,
            "zeros": zeros,
            "outliers_hi": out_hi,
            "outliers_lo": out_lo,
        }

    categorical: Dict[str, Any] = {}
    for c, mp in cat_counts.items():
        if len(mp) < 2:
            continue
        top = sorted(mp.items(), key=lambda kv: kv[1], reverse=True)[:max_keys_top]
        total_seen = sum(mp.values())
        categorical[c] = {
            "distinct_seen": len(mp),
            "top": [{"value": k, "count": v, "share": (v / total_seen if total_seen else 0.0)} for k, v in top],
        }

    return {
        "row_count": len(rows),
        "sampled_rows": len(sample),
        "numeric": numeric,
        "categorical": categorical,
    }


def _fmt_num(x: float) -> str:
    try:
        if abs(x) >= 1000:
            return f"{x:,.0f}".replace(",", "_").replace("_", ",")
        if abs(x) >= 10:
            return f"{x:.2f}".rstrip("0").rstrip(".")
        return f"{x:.4f}".rstrip("0").rstrip(".")
    except Exception:
        return str(x)


def _local_fallback_answer(human_query: str, rows: List[Dict[str, Any]], profile: Dict[str, Any]) -> str:
    rc = int(profile.get("row_count") or 0)
    sampled = int(profile.get("sampled_rows") or min(rc, 0))
    numeric = profile.get("numeric") or {}
    categorical = profile.get("categorical") or {}

    lines: List[str] = []
    lines.append(f"Se analizaron {rc} filas (muestra usada para perfil: {sampled}).")

    def score_metric(m: Dict[str, Any]) -> float:
        try:
            rng = float(m["max"]) - float(m["min"])
            return rng + 0.1 * float(m.get("outliers_hi", 0) + m.get("outliers_lo", 0))
        except Exception:
            return 0.0

    metrics_sorted: List[Tuple[str, Dict[str, Any]]] = sorted(
        numeric.items(), key=lambda kv: score_metric(kv[1]), reverse=True
    )[:2]

    for col, m in metrics_sorted:
        n = int(m.get("n") or 0)
        mn = float(m.get("min") or 0.0)
        mx = float(m.get("max") or 0.0)
        med = float(m.get("median") or 0.0)
        mean = float(m.get("mean") or 0.0)
        p90 = float(m.get("p90") or 0.0)
        zeros = int(m.get("zeros") or 0)
        ohi = int(m.get("outliers_hi") or 0)
        olo = int(m.get("outliers_lo") or 0)

        lines.append(
            f"- **{col}** (n={n}): min={_fmt_num(mn)}, mediana={_fmt_num(med)}, p90={_fmt_num(p90)}, max={_fmt_num(mx)} "
            f"(promedio={_fmt_num(mean)})."
        )
        if zeros > 0:
            lines.append(f"- En **{col}** hay {zeros} valores en cero.")
        if (ohi + olo) > 0:
            lines.append(f"- En **{col}** se detectan outliers por IQR: altos={ohi}, bajos={olo}.")

    def pick_cat_keys(cats: Dict[str, Any]) -> List[str]:
        if not cats:
            return []
        preferred = ["cliente", "material", "pedido", "codigo", "producto", "ruc", "proveedor"]
        keys = list(cats.keys())
        keys_sorted = sorted(
            keys,
            key=lambda k: (0 if any(p in k.lower() for p in preferred) else 1, -int(cats[k].get("distinct_seen") or 0)),
        )
        return keys_sorted[:2]

    for k in pick_cat_keys(categorical):
        top = (categorical.get(k) or {}).get("top") or []
        if not top:
            continue
        t0 = top[0]
        share = float(t0.get("share") or 0.0)
        lines.append(
            f"- **{k}**: principal = {t0.get('value')} ({t0.get('count')} registros, {share*100:.1f}% del muestreo categórico)."
        )

    if len(lines) == 1:
        lines.append("No hay suficientes columnas numéricas/categóricas para un análisis adicional con esta muestra.")

    return "\n".join(lines).strip()


# ============================ Proveedor Gemini ================================

class GeminiProvider:
    """
    - Usa system_instruction en config (no role system).
    - Filtra candidatos contra modelos visibles por tu clave/proyecto.
    - Maneja 404/429 con fallback/espera.
    - human_query_to_sql: salida JSON robusta + repair.
    - build_answer devuelve TEXTO.

    Cambios clave para robustez:
    - Instrucciones de tipos: NO TRIM/NUMERIC_CLEAN sobre columnas no-text (BIGINT/INT/NUMERIC/DATE).
    - Policy de filtros por tipo: TEXT -> COALESCE(TRIM(col),'') <> ''; NO-TEXT -> col IS NOT NULL.
    - Post-proceso “guard rails” para reemplazar TRIM("col_no_text") por TRIM(CAST("col_no_text" AS TEXT)) en Postgres
      (solo si el LLM lo hace mal).
    - Opcional: “hard fail” si detecta NUMERIC_CLEAN aplicado sobre no-text (configurable).
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
        nm = (name or env("GEMINI_MODEL", default="gemini-3-flash")).strip()
        return nm if nm.startswith("models/") else f"models/{nm}"

    def _resolve_answer_model(self, name: Optional[str]) -> str:
        nm = (name or env("GEMINI_MODEL_ANSWER", default="gemini-3-pro")).strip()
        return nm if nm.startswith("models/") else f"models/{nm}"

    def _fallback_chain(self, primary_full: str, env_key: str) -> List[str]:
        raw = env(env_key, default="")
        env_list = [s.strip() for s in raw.split(",") if s.strip()]

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
            "per_model_timeout": env("LLM_PER_MODEL_TIMEOUT", default=18.0, cast=float),
            "total_timeout": env("LLM_TOTAL_TIMEOUT", default=40.0, cast=float),
            "hedge_stagger": env("LLM_HEDGE_STAGGER", default=0.6, cast=float),
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

    # -------------------------- SQL post-fix: ORDER BY ------------------------

    def _sql_has_order_by(self, sql: str) -> bool:
        return bool(re.search(r"\bORDER\s+BY\b", sql, flags=re.IGNORECASE))

    def _inject_order_by_before_limit(self, sql: str, order_expr: str) -> str:
        m = re.search(r"\bLIMIT\s+\d+\b", sql, flags=re.IGNORECASE)
        if m:
            i = m.start()
            return sql[:i].rstrip() + f"\nORDER BY {order_expr}\n" + sql[i:].lstrip()
        return sql.rstrip() + f"\nORDER BY {order_expr}\n"

    def _auto_order_by(self, sql: str, human_query: str = "") -> str:
        if not sql or self._sql_has_order_by(sql):
            return sql

        has_limit = bool(re.search(r"\bLIMIT\s+\d+\b", sql, flags=re.IGNORECASE))
        if not has_limit:
            return sql

        if re.search(r'AS\s+"Pendiente"\b', sql, flags=re.IGNORECASE) and re.search(r'AS\s+"Despachado"\b', sql, flags=re.IGNORECASE):
            return self._inject_order_by_before_limit(sql, '("Pendiente" - "Despachado") DESC, "Pendiente" DESC')

        alias_candidates = [
            "Total", "Total Despachado", "Total Pendiente", "Despachado", "Pendiente",
            "Monto", "Cantidad", "Importe", "Suma", "Sum", "Diferencia"
        ]
        for a in alias_candidates:
            if re.search(rf'AS\s+"{re.escape(a)}"\b', sql, flags=re.IGNORECASE):
                return self._inject_order_by_before_limit(sql, f'"{a}" DESC')

        m = re.search(r'AS\s+"([^"]+)"', sql, flags=re.IGNORECASE)
        if m:
            alias = m.group(1)
            if not any(x in alias.lower() for x in ["pedido", "cliente", "material", "codigo", "id"]):
                return self._inject_order_by_before_limit(sql, f'"{alias}" DESC')

        return sql

    # -------------------------- Postgres: DATE_PART('day', A - B) --------------

    def _fix_postgres_datepart_day(self, sql: str) -> str:
        """
        Postgres: date1 - date2 (DATE - DATE) ya devuelve INTEGER (días).
        Evitar DATE_PART('day', date1 - date2).
        """
        s = (sql or "")
        if not s.strip():
            return s

        p = re.compile(
            r"DATE_PART\s*\(\s*'day'\s*,\s*\(\s*(?P<a>.+?)\s*-\s*(?P<b>.+?)\s*\)\s*\)",
            re.IGNORECASE | re.DOTALL
        )
        s = p.sub(lambda m: f"(({m.group('a').strip()}) - ({m.group('b').strip()}))", s)

        p2 = re.compile(
            r"DATE_PART\s*\(\s*'day'\s*,\s*(?P<a>.+?)\s*-\s*(?P<b>.+?)\s*\)",
            re.IGNORECASE | re.DOTALL
        )
        s = p2.sub(lambda m: f"(({m.group('a').strip()}) - ({m.group('b').strip()}))", s)

        return s

    # -------------------------- Schema helpers (tipos) -------------------------

    def _schema_type_map(self, schema_json: Dict[str, Any]) -> Dict[str, str]:
        """
        Map: "Column Name" -> "TYPE"
        Nota: si hay columnas repetidas en varias tablas, esto toma la primera ocurrencia;
        para tu caso (1 tabla) está perfecto.
        """
        mp: Dict[str, str] = {}
        for t in (schema_json.get("tables", []) or []):
            for c in (t.get("columns", []) or []):
                nm = c.get("name")
                tp = (c.get("type") or "")
                if nm and nm not in mp:
                    mp[nm] = tp
        return mp

    def _is_text_type(self, type_str: str) -> bool:
        t = (type_str or "").lower()
        return any(x in t for x in ["char", "text", "varchar", "string", "clob"])

    def _non_text_columns(self, schema_json: Dict[str, Any]) -> List[str]:
        mp = self._schema_type_map(schema_json)
        out = []
        for nm, tp in mp.items():
            if nm and (not self._is_text_type(tp)):
                out.append(nm)
        return out

    def _text_columns(self, schema_json: Dict[str, Any]) -> List[str]:
        mp = self._schema_type_map(schema_json)
        out = []
        for nm, tp in mp.items():
            if nm and self._is_text_type(tp):
                out.append(nm)
        return out

    # -------------------------- Guard rails SQL (post) -------------------------

    def _guard_trim_nontext(self, sql: str, schema_json: Dict[str, Any], dialect: str) -> str:
        """
        Si el LLM mete TRIM() sobre columnas no-text (BIGINT, etc),
        reescribimos para evitar errores (p.ej. Postgres btrim(bigint)).

        - Postgres: TRIM(CAST(col AS TEXT))
        - Otros: TRIM(CAST(col AS VARCHAR))
        """
        s = (sql or "")
        if not s.strip():
            return s

        non_text = self._non_text_columns(schema_json)
        if not non_text:
            return s

        d = (dialect or "").lower()
        cast_type = "TEXT" if d in ("postgresql", "postgres", "postgre") else "VARCHAR"
        if d in ("mssql", "sqlserver"):
            cast_type = "NVARCHAR(4000)"

        for col in sorted(non_text, key=len, reverse=True):
            col_q = re.escape(col)

            # TRIM("Col")
            p1 = re.compile(rf"\bTRIM\s*\(\s*\"{col_q}\"\s*\)", re.IGNORECASE)
            s = p1.sub(lambda m: f'TRIM(CAST("{col}" AS {cast_type}))', s)

            # TRIM(<qualifiers>."Col")
            p2 = re.compile(
                rf"\bTRIM\s*\(\s*(?P<q>(?:\w+|\"[^\"]+\")\s*\.\s*)+\"{col_q}\"\s*\)",
                re.IGNORECASE
            )
            s = p2.sub(lambda m: f'TRIM(CAST({m.group("q")}"{col}" AS {cast_type}))', s)

            # COALESCE(TRIM("Col"), '') también lo cubre por el TRIM interno

        return s

    def _guard_numeric_clean_nontext(self, sql: str, schema_json: Dict[str, Any]) -> None:
        """
        Opcional: falla temprano si el modelo usa NUMERIC_CLEAN sobre columnas no-text.
        Activación: env(SQL_FAIL_ON_NUMERIC_CLEAN_NONTEXT)=true
        """
        strict = env("SQL_FAIL_ON_NUMERIC_CLEAN_NONTEXT", default=False, cast=bool)
        if not strict:
            return

        s = (sql or "")
        if not s.strip():
            return

        non_text = self._non_text_columns(schema_json)
        if not non_text:
            return

        bad_cols = []
        for col in non_text:
            col_q = re.escape(col)
            if re.search(rf"\bNUMERIC_CLEAN\s*\(\s*\"{col_q}\"\s*\)", s, flags=re.IGNORECASE):
                bad_cols.append(col)

        if bad_cols:
            raise RuntimeError(f"SQL inválida: NUMERIC_CLEAN aplicado sobre columnas no-text: {bad_cols}")

    # -------------------------- Validación de JSON SQL ------------------------

    def _ensure_sql_json(self, payload: str) -> str:
        """
        Acepta:
        - JSON limpio {"sql_query":"...","original_query":"..."}
        - JSON dentro de texto
        - casos con escapes raros / truncados
        - fallback: si solo viene SQL, lo envuelve en JSON
        """
        def _try(s: str) -> Optional[Dict[str, Any]]:
            try:
                obj = json.loads(s)
                if isinstance(obj, dict) and "sql_query" in obj:
                    obj.setdefault("original_query", "")
                    return obj
            except Exception:
                return None
            return None

        t = (payload or "").strip()

        obj = _try(t)
        if obj:
            return json.dumps(obj, ensure_ascii=False)

        m = re.search(r"\{.*\}", t, re.DOTALL)
        if m:
            obj = _try(m.group(0))
            if obj:
                return json.dumps(obj, ensure_ascii=False)

        # "sql_query": ".... (truncado/escapes)"
        m2 = re.search(r'"sql_query"\s*:\s*"(?P<q>.*)', t, re.DOTALL)
        if m2:
            raw = m2.group("q")
            raw = raw.replace('\\"', '"')
            raw = raw.replace("\\n", "\n").replace("\\t", "\t")
            last_quote = raw.rfind('"')
            sql = raw[:last_quote] if last_quote > 0 else raw
            sql = sql.strip()
            if sql:
                return json.dumps({"sql_query": sql, "original_query": ""}, ensure_ascii=False)

        if re.search(r"^\s*(with\b|select\b|explain\b)", t, re.IGNORECASE):
            return json.dumps({"sql_query": t, "original_query": ""}, ensure_ascii=False)

        raise RuntimeError(f"Gemini devolvió un formato inesperado: {t[:400]}")

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

        # info de tipos para el prompt (clave para evitar TRIM(bigint))
        non_text_cols = self._non_text_columns(schema_json)
        text_cols = self._text_columns(schema_json)

        system_instruction = fr"""
You are a careful SQL generator for {dialect.upper()}.

Hard rules:
- Output must be READ-ONLY: SELECT/CTE/EXPLAIN (without ANALYZE). No INSERT/UPDATE/DELETE/DDL/CALL.
- Use only tables/columns from the provided schema. Do not hallucinate.
- {self._dialect_quote(dialect)}
- Quote identifiers with spaces/accents: "Fecha de Pedido".
- Prefer fully-qualified names exactly as in <allowed_fqn>.
- Use macros (server expands): NUMERIC_CLEAN("Col"), DATE_PARSE("Col").
- Always add LIMIT {default_limit} if missing.
- When aggregating, include meaningful ORDER BY (e.g., ORDER BY SUM(...) DESC).

IMPORTANT:
- Do NOT add UNION, ROLLUP, CUBE, GROUPING SETS, or any total/overall rows.
- Do NOT return “total” rows (no summary rows); return only the per-group rows requested.

FIELD & TYPE RULES (VERY IMPORTANT):
- The schema provides column types.
- DO NOT use TRIM(), COALESCE(TRIM(...),''), regex (~), or string comparisons on NON-TEXT columns (e.g., BIGINT/INT/NUMERIC/DATE/TIMESTAMP).
- For NON-TEXT null checks use: "Col" IS NOT NULL.
- For TEXT blank checks use: COALESCE(TRIM("Col"), '') <> ''.

NUMERIC_CLEAN usage:
- Use NUMERIC_CLEAN("Col") ONLY for TEXT columns that represent numbers (amounts/quantities).
- NEVER apply NUMERIC_CLEAN to identifiers/keys (e.g., orders, ids, codes) if those columns are NON-TEXT.
- If a metric column is already numeric in schema, use it directly or CAST as needed; do NOT wrap it with NUMERIC_CLEAN.

When grouping by a TEXT key, exclude totals/footer rows and blank keys:
  WHERE COALESCE(TRIM("Key"), '') <> ''
    AND "Key" !~* '^\s*total'
    AND "Key" !~* '^\s*gran\s*total'
    AND "Key" !~* '^\s*totales'

If grouping by a NON-TEXT key (like BIGINT order id):
  WHERE "Key" IS NOT NULL

Field coverage (VERY IMPORTANT):
- If the user asks for specific fields (e.g., “material”, “pedido venta”, “despachado”, “pendiente”),
  you MUST include those corresponding columns in the SELECT list.
- If the user asks for totals by some key:
  SELECT <key>, SUM(<metric>) AS "<alias>"
  GROUP BY <key>
- If the user asks for “despachado y pendiente por pedido/material”, include BOTH metrics in SELECT:
  SUM(NUMERIC_CLEAN("Despachado")) AS "Total Despachado",
  SUM(NUMERIC_CLEAN("Pendiente"))  AS "Total Pendiente"
  and group by the requested keys.
- Avoid queries that return only identifiers (e.g., SELECT DISTINCT "Pedido Venta") when the user asked totals/metrics.

POSTGRES DATE DIFF RULE (VERY IMPORTANT):
- DATE_PARSE(...) returns a DATE.
- Day difference is computed as: (DATE_PARSE(b) - DATE_PARSE(a)) returning INTEGER.
- DO NOT use DATE_PART('day', DATE_PARSE(b) - DATE_PARSE(a)). Avoid DATE_PART('day', <date1> - <date2>).

Return ONLY valid JSON:
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
<type_hints>
text_columns={json.dumps(text_cols, ensure_ascii=False)}
non_text_columns={json.dumps(non_text_cols, ensure_ascii=False)}
</type_hints>
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
            "temperature": 0.06,
            "max_output_tokens": int(env("SQL_MAX_OUTPUT_TOKENS", default=2600)),
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

        def _postprocess_sql(sql: str) -> str:
            sql2 = (sql or "").strip()
            if (dialect or "").lower() in ("postgresql", "postgres", "postgre"):
                sql2 = self._fix_postgres_datepart_day(sql2)
            sql2 = self._auto_order_by(sql2, human_query)

            # guard rails
            sql2 = self._guard_trim_nontext(sql2, schema_json=schema_json, dialect=dialect)
            self._guard_numeric_clean_nontext(sql2, schema_json=schema_json)

            return sql2

        if winner:
            try:
                obj = json.loads(self._ensure_sql_json(winner))
            except Exception:
                repair_prompt = (
                    "Devuelve EXCLUSIVAMENTE un JSON válido con el formato:\n"
                    '{ "sql_query": "...", "original_query": "..." }\n'
                    "Sin markdown, sin texto extra.\n\n"
                    f"Texto a corregir:\n{winner[:9000]}"
                )
                repair_contents = [{"role": "user", "parts": [{"text": repair_prompt}]}]
                repair_resp = await asyncio.to_thread(
                    self.client.models.generate_content,
                    model=models[0],
                    contents=repair_contents,
                    config={
                        "response_mime_type": "application/json",
                        "temperature": 0.0,
                        "max_output_tokens": int(env("SQL_REPAIR_MAX_TOKENS", default=900)),
                    },
                )
                obj = json.loads(self._ensure_sql_json((repair_resp.text or "").strip()))

            sql = _postprocess_sql(obj.get("sql_query") or "")
            obj["sql_query"] = sql
            return json.dumps(obj, ensure_ascii=False)

        # Fallback secuencial si todo falló
        for mdl in models:
            try:
                res = await asyncio.wait_for(
                    asyncio.to_thread(self.client.models.generate_content, model=mdl, contents=contents, config=config),
                    timeout=per_model_timeout * 1.4
                )
                txt = (res.text or "").strip()
                if txt:
                    obj = json.loads(self._ensure_sql_json(txt))
                    obj["sql_query"] = _postprocess_sql(obj.get("sql_query") or "")
                    log.info("[gemini.human_query_to_sql] winner(sequential)=%s", mdl)
                    return json.dumps(obj, ensure_ascii=False)
            except Exception as e:
                errors.append(f"{mdl}: {_ex_msg(e)}")

        raise RuntimeError("Fallo human_query_to_sql: " + " ; ".join(errors[-8:]))

    # ---------------------------- Answer Rendering ----------------------------

    def _render_answer_obj(self, obj: Dict[str, Any]) -> str:
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

        ins = clean_list(insights, 10)
        cav = clean_list(caveats, 4)

        lines: List[str] = []
        if summary:
            lines.append(summary if summary.endswith((".", "!", "?")) else summary + ".")
        for t in ins:
            lines.append(f"- {t}")
        for t in cav:
            lines.append(f"Nota: {t}")
        return "\n".join(lines).strip()

    def _looks_truncated(self, text: str) -> bool:
        t = (text or "").strip()
        if not t:
            return True
        if re.search(r"\b\d+\.\s*$", t):
            return True
        if re.search(r"(debido a que|porque|ya que|se debe a que)\s*$", t, flags=re.IGNORECASE):
            return True
        if not t.endswith((".", "!", "?", "…")) and len(t) < 220:
            return True
        return False

    def _looks_hallucinated(self, rendered: str, row_keys: List[str]) -> bool:
        text = (rendered or "").lower()
        keys = " ".join([k.lower() for k in (row_keys or [])])

        suspicious_terms = [
            "asia", "asia-pacífico", "pacifico", "marketing", "campaña", "roi", "retención",
            "lealtad", "proyecciones", "mercados emergentes", "interanual", "cambiari",
            "lanzamiento", "producto alfa", "canales tradicionales"
        ]

        if any(t in text for t in suspicious_terms):
            related_cols = ["roi", "marketing", "campaña", "retención", "mercado", "región", "producto", "proyección"]
            if not any(rc in keys for rc in related_cols):
                return True

        if "crecim" in text and not any(x in keys for x in ["fecha", "mes", "año", "trimestre", "periodo", "week"]):
            return True

        return False

    def _first_json(self, s: str) -> Optional[Dict[str, Any]]:
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

    async def _repair_or_continue_json(
        self,
        mdl: str,
        schema_json_str: str,
        last_txt: str,
        timeout_s: float,
        base_config: Dict[str, Any],
    ) -> Optional[Dict[str, Any]]:
        repair_prompt = (
            "El texto anterior está incompleto o inválido.\n"
            "Devuelve SOLO un JSON válido que cumpla EXACTAMENTE el schema.\n"
            "Reglas:\n"
            "- No inventes contexto.\n"
            "- Usa únicamente lo presente en `rows` y `profile`.\n"
            "- Asegura que `summary` termine en frase completa.\n\n"
            f"Schema:\n{schema_json_str}\n\n"
            f"Texto a reparar:\n{(last_txt or '')[:12000]}"
        )
        contents = [{"role": "user", "parts": [{"text": repair_prompt}]}]
        try:
            resp = await asyncio.wait_for(
                asyncio.to_thread(self.client.models.generate_content, model=mdl, contents=contents, config=base_config),
                timeout=timeout_s
            )
            txt = (resp.text or "").strip()
            obj = self._first_json(txt)
            return obj
        except Exception:
            return None

    # -------------------------------- Resumen --------------------------------

    async def build_answer(
        self,
        rows: List[Dict[str, Any]],
        human_query: str,
        model: Optional[str] = None
    ) -> str:

        max_rows = int(env("ANSWER_MAX_ROWS", default=400))
        max_chars = int(env("ANSWER_MAX_CHARS", default=12000))
        rows_json = _compact_rows_for_summary(rows, max_rows=max_rows, max_chars=max_chars)

        profile = _compute_profile(rows, max_keys_top=8)
        profile_json = json.dumps(profile, ensure_ascii=False)[:14000]

        row_keys = list(rows[0].keys()) if rows else []

        schema = {
            "type": "object",
            "properties": {
                "summary": {"type": "string"},
                "insights": {"type": "array", "items": {"type": "string"}, "minItems": 0, "maxItems": 10},
                "caveats": {"type": "array", "items": {"type": "string"}, "minItems": 0, "maxItems": 4},
            },
            "required": ["summary"],
            "additionalProperties": False
        }
        system_instruction = json.dumps(schema, ensure_ascii=False)

        prompt = (
            "Eres un ANALISTA SENIOR de datos.\n"
            "Tu respuesta DEBE basarse únicamente en los campos y valores presentes en `rows` y en `profile`.\n\n"
            "PROHIBIDO:\n"
            "- Inventar contexto (mercados, regiones, campañas, productos, proyecciones) si NO aparece en columnas/valores.\n"
            "- Usar ejemplos genéricos.\n\n"
            "OBLIGATORIO:\n"
            "- Si hay métricas numéricas en `profile.numeric`, menciona (cuando aplique): máximo, mínimo, mediana y p90.\n"
            "- Si hay ceros/outliers, indícalo solo si aparece en `profile`.\n"
            "- Si hay claves categóricas en `profile.categorical`, menciona concentración (top y %).\n"
            "- Si la evidencia es insuficiente, dilo explícitamente.\n"
            "- No dejes frases cortadas.\n\n"
            "Devuelve EXCLUSIVAMENTE un JSON válido con este schema (sin markdown):\n"
            '{ "summary": "...", "insights": ["..."], "caveats": ["..."] }\n\n'
            f"Pregunta:\n{human_query}\n\n"
            f"Columnas disponibles:\n{json.dumps(row_keys, ensure_ascii=False)}\n\n"
            f"Profile (estadístico real):\n{profile_json}\n\n"
            f"Rows (muestra truncada):\n{rows_json}\n"
        ).strip()

        primary_full = self._resolve_answer_model(model)
        models = self._fallback_chain(primary_full, "GEMINI_MODEL_ANSWER_CANDIDATES")

        per_model_timeout = float(env("ANSWER_PER_MODEL_TIMEOUT", default=55.0))
        total_timeout = float(env("ANSWER_TOTAL_TIMEOUT", default=140.0))

        base_contents = [{"role": "user", "parts": [{"text": prompt}]}]
        base_config = {
            "response_mime_type": "application/json",
            "temperature": float(env("ANSWER_TEMPERATURE", default=0.14)),
            "max_output_tokens": int(env("ANSWER_MAX_OUTPUT_TOKENS", default=4096)),
            "system_instruction": system_instruction,
        }

        start = time.time()
        errors: List[str] = []
        schema_str = system_instruction

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

                obj = self._first_json(txt)
                if obj and isinstance(obj, dict) and (obj.get("summary") or "").strip():
                    rendered = self._render_answer_obj(obj)

                    if rendered and not self._looks_hallucinated(rendered, row_keys) and not self._looks_truncated(rendered):
                        log.info("[gemini.build_answer] winner=%s attempt=%d lat=%.2fs", mdl, attempt + 1, time.time() - start)
                        return rendered

                    if rendered and self._looks_truncated(rendered) and rem2 > 8.0:
                        obj2 = await self._repair_or_continue_json(
                            mdl=mdl,
                            schema_json_str=schema_str,
                            last_txt=txt,
                            timeout_s=min(22.0, rem2),
                            base_config=base_config,
                        )
                        if obj2 and (obj2.get("summary") or "").strip():
                            rendered2 = self._render_answer_obj(obj2)
                            if rendered2 and not self._looks_hallucinated(rendered2, row_keys) and not self._looks_truncated(rendered2):
                                log.info("[gemini.build_answer] winner(repair)=%s lat=%.2fs", mdl, time.time() - start)
                                return rendered2

                fix_prompt = (
                    "Corrige el siguiente texto a un JSON VÁLIDO que cumpla exactamente el schema. "
                    "NO des explicaciones. NO agregues contexto que no esté en `rows`/`profile`. "
                    "Asegura que `summary` termine en frase completa.\n"
                    f"{(txt or '')[:12000]}"
                )
                fix_contents = [{"role": "user", "parts": [{"text": fix_prompt}]}]
                fix_txt = await _invoke(mdl, fix_contents, base_config, min(22.0, rem2))

                if not isinstance(fix_txt, Exception):
                    obj2 = self._first_json(fix_txt)
                    if obj2 and isinstance(obj2, dict) and (obj2.get("summary") or "").strip():
                        rendered2 = self._render_answer_obj(obj2)
                        if rendered2 and not self._looks_hallucinated(rendered2, row_keys) and not self._looks_truncated(rendered2):
                            log.info("[gemini.build_answer] winner(fix)=%s lat=%.2fs", mdl, time.time() - start)
                            return rendered2

                errors.append(f"{mdl}: sin JSON válido/aceptable (attempt {attempt + 1})")

        log.warning("[gemini.build_answer] fallback local. errores: %s", "; ".join(errors[-8:]))
        return _local_fallback_answer(human_query=human_query, rows=rows, profile=profile)

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