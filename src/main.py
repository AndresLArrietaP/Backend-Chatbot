# src/main.py
import json
import logging
import re
import time
import unicodedata
from decimal import Decimal
from hashlib import sha1
from typing import Any, Dict, List, Optional, Tuple

from decouple import config as env
from fastapi import APIRouter, Depends, Header, HTTPException, Query, Request
from pydantic import BaseModel

from . import database
from . import llm

logger = logging.getLogger(__name__)
router = APIRouter()

# =============================================================================
# Normalización / utilidades
# =============================================================================

def _to_number(v: Any) -> Any:
    if isinstance(v, Decimal):
        return float(v)
    if isinstance(v, (int, float)):
        return float(v)
    return v

def _norm_key_name(s: str) -> str:
    if not s:
        return ""
    s_norm = unicodedata.normalize("NFKD", s)
    s_no_acc = "".join(ch for ch in s_norm if not unicodedata.combining(ch))
    return s_no_acc.strip().lower()

def normalize_rows(
    rows: List[Dict[str, Any]],
    implied_millis_cols: List[str],
    decimal_places: int = 3,
    fmt_strings: bool = True,
) -> List[Dict[str, Any]]:
    """
    - Divide por 1000 si se detecta patrón de "milésimas implícitas"
    - Formatea como string si fmt_strings=True
    """
    implied_exact = {_norm_key_name(c) for c in (implied_millis_cols or []) if c and c.strip()}

    auto_kw = env("IMPLIED_MILLIS_AUTO_HEURISTIC", default=True, cast=bool)
    auto_detect = env("IMPLIED_MILLIS_AUTODETECT", default=True, cast=bool)
    ratio_threshold = env("IMPLIED_MILLIS_RATIO_THRESHOLD", default=0.8, cast=float)
    min_abs = env("IMPLIED_MILLIS_MIN_ABS", default=100000, cast=int)

    keywords_env = env(
        "IMPLIED_MILLIS_KEYWORDS",
        default="despachado,original,pendiente,total linea,total línea,total despachado,total original,total pendiente"
    )
    kw_list = [_norm_key_name(w) for w in keywords_env.split(",") if w.strip()]

    def _name_has_keyword(name_low: str) -> bool:
        return any((kw in name_low) for kw in kw_list if kw)

    def _is_big_multiple_of_1000(x: float) -> bool:
        nearest = round(x)
        return (abs(x - nearest) < 1e-9) and (abs(nearest) >= min_abs) and (nearest % 1000 == 0)

    col_numeric_values: Dict[str, List[float]] = {}
    for r in rows or []:
        for k, v in (r or {}).items():
            if isinstance(v, Decimal):
                col_numeric_values.setdefault(k, []).append(float(v))
            elif isinstance(v, (int, float)):
                col_numeric_values.setdefault(k, []).append(float(v))

    auto_divide_cols = set()
    if auto_detect and rows:
        for col, vals in col_numeric_values.items():
            if len(vals) < 5:
                continue
            vals_sorted = sorted(vals)
            mid = len(vals_sorted) // 2
            median = (vals_sorted[mid] if len(vals_sorted) % 2 == 1
                      else 0.5 * (vals_sorted[mid - 1] + vals_sorted[mid]))
            mult_cnt = sum(1 for x in vals if _is_big_multiple_of_1000(x))
            ratio = mult_cnt / len(vals)
            if ratio >= ratio_threshold or (median >= (min_abs * 2) and ratio >= 0.6):
                auto_divide_cols.add(_norm_key_name(col))

    out: List[Dict[str, Any]] = []
    for r in rows:
        nr: Dict[str, Any] = {}
        for k, v in (r or {}).items():
            name_low = _norm_key_name(k)
            val = _to_number(v)

            if isinstance(val, (int, float)) or isinstance(v, Decimal):
                valf = float(val)

                must_divide = False
                col_marked = name_low in auto_divide_cols
                soft_signal = (name_low in implied_exact) or (auto_kw and _name_has_keyword(name_low))

                if col_marked:
                    must_divide = True
                elif soft_signal and _is_big_multiple_of_1000(valf):
                    must_divide = True

                if must_divide:
                    valf = valf / 1000.0

                if fmt_strings:
                    if abs(valf - round(valf)) < 1e-9:
                        nr[k] = f"{int(round(valf)):,}"
                    else:
                        nr[k] = f"{valf:,.{decimal_places}f}"
                else:
                    nr[k] = round(valf, decimal_places)
            else:
                nr[k] = v
        out.append(nr)

    return out


def _local_summary_answer(rows: List[Dict[str, Any]], human_query: str) -> str:
    """
    Fallback local simple (no LLM) si falla el resumen.
    """
    if not rows:
        return f"No se encontraron datos para la consulta: “{human_query}”."

    sample = rows[0]
    text_cols: List[str] = []
    num_cols: List[str] = []

    for k in sample.keys():
        is_num = False
        for r in rows:
            v = r.get(k)
            if isinstance(v, (int, float, Decimal)):
                is_num = True
                break
            if isinstance(v, str):
                try:
                    float(v.replace(",", ""))
                    is_num = True
                    break
                except Exception:
                    pass
        if is_num:
            num_cols.append(k)
        else:
            text_cols.append(k)

    # pick best
    def _score_text(name: str) -> int:
        n = _norm_key_name(name)
        if any(x in n for x in ["id", "codigo", "código", "pedido", "orden", "documento", "doc", "cliente"]):
            return 3
        return 1

    def _score_num(name: str) -> int:
        n = _norm_key_name(name)
        if any(x in n for x in ["total", "monto", "importe", "valor", "cantidad", "despach", "pendien", "saldo"]):
            return 3
        return 1

    text_cols.sort(key=_score_text, reverse=True)
    num_cols.sort(key=_score_num, reverse=True)

    key_col = text_cols[0] if text_cols else None
    val_col = num_cols[0] if num_cols else None

    bullets: List[str] = []
    bullets.append(f"Filas analizadas: {len(rows)}.")

    if val_col:
        total = 0.0
        for r in rows:
            v = r.get(val_col)
            try:
                if isinstance(v, str):
                    v = float(v.replace(",", ""))
                elif isinstance(v, Decimal):
                    v = float(v)
                elif not isinstance(v, (int, float)):
                    v = 0.0
            except Exception:
                v = 0.0
            total += float(v)
        bullets.append(f"Suma de “{val_col}”: {total:,.3f}")

    if key_col and val_col:
        agg: Dict[str, float] = {}
        for r in rows:
            k = str(r.get(key_col) or "(Sin valor)")
            v = r.get(val_col)
            try:
                if isinstance(v, str):
                    v = float(v.replace(",", ""))
                elif isinstance(v, Decimal):
                    v = float(v)
                elif not isinstance(v, (int, float)):
                    v = 0.0
            except Exception:
                v = 0.0
            agg[k] = agg.get(k, 0.0) + float(v)
        top = sorted(agg.items(), key=lambda kv: kv[1], reverse=True)[:3]
        if top:
            bullets.append("Top por {0}: {1}".format(
                key_col,
                "; ".join([f"{k} = {v:,.3f}" for k, v in top])
            ))

    summary_parts = [f"Consulta: “{human_query}”."]
    if val_col and key_col:
        summary_parts.append(f"Se analizó “{val_col}” por “{key_col}” y se listan los principales aportes.")
    elif val_col:
        summary_parts.append(f"Se destaca la métrica “{val_col}”.")
    else:
        summary_parts.append("No se identificó una métrica numérica dominante; se muestran datos generales.")

    final = " ".join(p if p.endswith((".", "!", "?")) else p + "." for p in summary_parts)
    for b in bullets[:3]:
        final += f"\n- {b}"
    return final


# =============================================================================
# Cache LLM → SQL
# =============================================================================

_SQL_CACHE: Dict[str, Dict[str, Any]] = {}
SQL_CACHE_TTL = env("SQL_CACHE_TTL_SECONDS", default=300, cast=int)
SQL_CACHE_MAX = env("SQL_CACHE_MAX", default=256, cast=int)

def _cache_key(human_query: str, schema_json: Dict[str, Any], dialect: str, default_limit: int) -> str:
    payload = json.dumps(
        {"q": human_query, "schema": schema_json, "dialect": dialect, "limit": default_limit},
        ensure_ascii=False, sort_keys=True
    )
    return sha1(payload.encode("utf-8")).hexdigest()

def _cache_get(key: str) -> Optional[str]:
    item = _SQL_CACHE.get(key)
    if not item:
        return None
    if time.time() > item["exp"]:
        _SQL_CACHE.pop(key, None)
        return None
    return item["sql_json"]

def _cache_put(key: str, sql_json: str) -> None:
    if len(_SQL_CACHE) >= SQL_CACHE_MAX:
        oldest = min(_SQL_CACHE.items(), key=lambda kv: kv[1]["exp"])[0]
        _SQL_CACHE.pop(oldest, None)
    _SQL_CACHE[key] = {"exp": time.time() + SQL_CACHE_TTL, "sql_json": sql_json}


# =============================================================================
# Generalización: detectar intentos y columnas desde schema + query
# =============================================================================

_TOTAL_RE = re.compile(r"^\s*(gran\s*)?total(es)?\s*$", re.IGNORECASE)

_COMPARATIVE_CUES = [
    "supera", "mayor", "menor", "inferior", "superior", ">", "<", ">=", "<=",
    "excede", "sobrepasa", "más que", "menos que", "higher", "lower", "greater", "less",
]

_LIST_CUES = ["lista", "listar", "muéstrame", "mostrar", "dame", "devuélveme", "retorna", "return", "top"]

_SELECT_CLAUSE_RE = re.compile(r"^\s*select\s+(?P<cols>.*?)\s+from\s", re.IGNORECASE | re.DOTALL)

def _extract_select_clause(sql: str) -> str:
    m = _SELECT_CLAUSE_RE.search(sql or "")
    return (m.group("cols") if m else "") or ""

def _schema_tables(schema_json: Dict[str, Any]) -> List[Dict[str, Any]]:
    return schema_json.get("tables", []) or []

def _schema_all_columns(schema_json: Dict[str, Any]) -> List[str]:
    cols: List[str] = []
    for t in _schema_tables(schema_json):
        for c in (t.get("columns", []) or []):
            nm = c.get("name")
            if nm and nm not in cols:
                cols.append(nm)
    return cols

def _schema_columns_for_tables(schema_json: Dict[str, Any], requested_tables: Optional[List[str]]) -> List[str]:
    """
    Si el usuario pasa tables=["X"], limitamos columnas a esas tablas.
    requested_tables puede venir con nombre sin schema; comparamos por "table".
    """
    if not requested_tables:
        return _schema_all_columns(schema_json)

    wanted = {_norm_key_name(t) for t in requested_tables if t}
    cols: List[str] = []
    for t in _schema_tables(schema_json):
        tname = _norm_key_name(t.get("table") or "")
        if tname and tname in wanted:
            for c in (t.get("columns", []) or []):
                nm = c.get("name")
                if nm and nm not in cols:
                    cols.append(nm)
    # fallback si no encontró nada
    return cols or _schema_all_columns(schema_json)

def _find_mentioned_columns(human_query: str, schema_cols: List[str]) -> List[str]:
    """
    Heurística general:
    - si el nombre normalizado de la columna aparece como substring en el query normalizado, se considera mencionada
    - orden por longitud (preferir matches más específicos)
    """
    qn = _norm_key_name(human_query)
    hits: List[Tuple[int, str]] = []
    for col in schema_cols:
        cn = _norm_key_name(col)
        if not cn:
            continue
        if cn in qn:
            hits.append((len(cn), col))
    hits.sort(key=lambda x: x[0], reverse=True)

    out: List[str] = []
    seen = set()
    for _, col in hits:
        if col not in seen:
            out.append(col)
            seen.add(col)
    return out

def _has_comparison_intent(human_query: str) -> bool:
    qn = _norm_key_name(human_query)
    return any(cue in qn for cue in _COMPARATIVE_CUES)

def _has_list_intent(human_query: str) -> bool:
    qn = _norm_key_name(human_query)
    return any(cue in qn for cue in _LIST_CUES)

def _pick_key_column(schema_cols: List[str], human_query: str) -> Optional[str]:
    """
    Escoge una columna “identificadora” de manera general.
    """
    qn = _norm_key_name(human_query)

    preferred_keywords = [
        "id", "codigo", "código", "pedido", "orden", "documento", "doc",
        "factura", "boleta", "cliente", "material", "producto", "ruc", "serie", "numero", "nro"
    ]

    def score(col: str) -> int:
        n = _norm_key_name(col)
        s = 0
        # si la columna se menciona en query, sube
        if n and n in qn:
            s += 5
        for kw in preferred_keywords:
            if kw in n:
                s += 3
        # penaliza columnas que suenan a métricas
        if any(x in n for x in ["monto", "importe", "total", "cantidad", "valor", "saldo"]):
            s -= 2
        return s

    ranked = sorted(schema_cols, key=score, reverse=True)
    best = ranked[0] if ranked else None
    # requiere mínimo puntaje para evitar elegir cualquier cosa
    if best and score(best) >= 2:
        return best
    return ranked[0] if ranked else None

def _sql_has_column_in_select(sql: str, col: str) -> bool:
    """
    Verifica presencia del nombre/alias en el SELECT list (no en WHERE).
    """
    if not sql or not col:
        return False
    sel = _extract_select_clause(sql)
    if not sel:
        return False

    col_esc = re.escape(col)
    patterns = [
        rf'"\s*{col_esc}\s*"',                      # "Pendiente"
        rf'\.\s*"\s*{col_esc}\s*"',                 # public."T"."Pendiente"
        rf'\bas\s+"{col_esc}"\b',                   # ... AS "Pendiente"
        rf'\bNUMERIC_CLEAN\s*\(\s*[^)]*"{col_esc}"',# NUMERIC_CLEAN(... "Pendiente"
        rf'\bDATE_PARSE\s*\(\s*[^)]*"{col_esc}"',   # DATE_PARSE("Fecha")
    ]
    return any(re.search(p, sel, flags=re.IGNORECASE | re.DOTALL) for p in patterns)

def _looks_like_distinct_id_only(sql: str) -> bool:
    s = (sql or "").lower()
    return ("select distinct" in s) and ("sum(" not in s) and ("group by" not in s)

def _augment_query_for_required_select(human_query: str, key_col: Optional[str], metric_cols: List[str]) -> str:
    """
    Instrucción general para forzar que el SELECT traiga las métricas usadas.
    """
    parts = [human_query.strip(), "| OBLIGATORIO: el SELECT debe incluir:"]
    if key_col:
        parts.append(f'"{key_col}"')
    for c in metric_cols[:3]:
        parts.append(f'NUMERIC_CLEAN("{c}") AS "{c}"')
    if len(metric_cols) >= 2:
        parts.append(f'(NUMERIC_CLEAN("{metric_cols[0]}") - NUMERIC_CLEAN("{metric_cols[1]}")) AS "Diferencia"')
    parts.append("Si hay comparación, las columnas comparadas deben estar en SELECT.")
    parts.append("Devuelve SOLO JSON.")
    return " ".join(parts)

def _build_direct_sql_compare(
    table_fqn: str,
    key_col: Optional[str],
    left_col: str,
    right_col: str,
    op: str,
    limit: int,
) -> str:
    """
    Fallback determinístico para comparaciones tipo A > B, A < B, etc.
    """
    # alias estables (pero “generales”)
    left_alias = left_col
    right_alias = right_col

    select_cols = []
    if key_col:
        select_cols.append(f'"{key_col}" AS "{key_col}"')
    select_cols.append(f'NUMERIC_CLEAN("{left_col}") AS "{left_alias}"')
    select_cols.append(f'NUMERIC_CLEAN("{right_col}") AS "{right_alias}"')
    select_cols.append(f'(NUMERIC_CLEAN("{left_col}") - NUMERIC_CLEAN("{right_col}")) AS "Diferencia"')

    # order by diferencia coherente según operador
    if op in [">", ">="]:
        order = '"Diferencia" DESC'
    elif op in ["<", "<="]:
        order = '"Diferencia" ASC'
    else:
        order = 'ABS("Diferencia") DESC'

    return f"""
SELECT
  {", ".join(select_cols)}
FROM {table_fqn}
WHERE
  COALESCE(TRIM("{left_col}"), '') <> ''
  AND COALESCE(TRIM("{right_col}"), '') <> ''
  AND NUMERIC_CLEAN("{left_col}") {op} NUMERIC_CLEAN("{right_col}")
ORDER BY {order}
LIMIT {int(limit)}
""".strip()

def _infer_compare_operator(human_query: str) -> str:
    """
    Heurística: por defecto si dice “supera/mayor” => '>'
                si dice “menor/inferior” => '<'
    """
    qn = _norm_key_name(human_query)
    if ">=" in qn:
        return ">="
    if "<=" in qn:
        return "<="
    if ">" in qn:
        return ">"
    if "<" in qn:
        return "<"
    if any(x in qn for x in ["menor", "inferior", "less", "lower", "menos que"]):
        return "<"
    # default: supera/mayor/excede
    return ">"

def _drop_total_like_rows(rows: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    Elimina filas con claves textuales nulas/vacías o tipo TOTAL/TOTALES.
    """
    if not rows:
        return rows

    sample_keys = list(rows[0].keys())
    text_cols: List[str] = []
    for k in sample_keys:
        for r in rows[:30]:
            v = r.get(k)
            if isinstance(v, str):
                text_cols.append(k)
                break
    text_cols = list(dict.fromkeys(text_cols))

    if not text_cols:
        return rows

    cleaned: List[Dict[str, Any]] = []
    for r in rows:
        drop = False
        for k in text_cols:
            v = r.get(k)
            if v is None:
                drop = True
                break
            if isinstance(v, str):
                t = v.strip()
                if t == "" or _TOTAL_RE.match(t):
                    drop = True
                    break
        if not drop:
            cleaned.append(r)
    return cleaned


# =============================================================================
# Auth opcional API Key
# =============================================================================

async def api_key_guard(request: Request, x_api_key: Optional[str] = Header(default=None)):
    settings = request.app.state.settings
    required = getattr(settings, "API_KEY", "") or ""
    if not required:
        return
    if not x_api_key or x_api_key != required:
        raise HTTPException(status_code=401, detail="API key inválida")


# =============================================================================
# Modelo request
# =============================================================================

class PostHumanQueryPayload(BaseModel):
    human_query: str
    sql_query_override: Optional[str] = None
    schemas: Optional[List[str]] = None
    tables: Optional[List[str]] = None
    dialect: Optional[str] = None
    limit: Optional[int] = None
    execute: bool = True
    schema_refresh: bool = False
    summarize: Optional[bool] = True
    format_numbers: Optional[bool] = None
    decimals: Optional[int] = None
    implied_millis_cols: Optional[List[str]] = None


# =============================================================================
# Endpoints
# =============================================================================

@router.get("/")
def root() -> Dict[str, str]:
    return {"status": "ok", "docs": "/docs"}

@router.get("/healthz")
def healthz() -> Dict[str, str]:
    return {"status": "healthy"}

@router.get("/schema", dependencies=[Depends(api_key_guard)])
def get_schema(
    request: Request,
    schemas: Optional[List[str]] = Query(default=None),
    tables: Optional[List[str]] = Query(default=None),
) -> Dict[str, Any]:
    settings = request.app.state.settings
    if not schemas:
        schemas = [s.strip() for s in getattr(settings, "TARGET_SCHEMAS", "public").split(",")]

    schema_json = database.get_schema_json(
        schemas=schemas,
        tables=tables,
        max_tables=getattr(settings, "MAX_SCHEMA_TABLES", 50),
        max_columns=getattr(settings, "MAX_SCHEMA_COLUMNS", 2000),
    )
    return schema_json

@router.get("/llm/ping", dependencies=[Depends(api_key_guard)])
async def llm_ping(request: Request) -> Dict[str, Any]:
    try:
        txt = await llm.ping()
        return {"status": "ok", "gemini_reply": (txt or "")[:200]}
    except Exception as e:
        return {"status": "error", "detail": str(e)}

@router.get("/llm/models", dependencies=[Depends(api_key_guard)])
def llm_models() -> Dict[str, Any]:
    try:
        return llm.list_models()
    except Exception as e:
        return {"status": "error", "detail": str(e)}

@router.post("/schema/refresh", dependencies=[Depends(api_key_guard)])
def refresh_schema() -> Dict[str, str]:
    database.refresh_schema_cache()
    return {"status": "ok", "message": "Schema cache refreshed"}


@router.post("/human_query", dependencies=[Depends(api_key_guard)])
async def human_query(request: Request, payload: PostHumanQueryPayload) -> Dict[str, Any]:
    try:
        settings = request.app.state.settings

        # 1) Esquema
        if payload.schema_refresh:
            database.refresh_schema_cache()

        schemas = payload.schemas or [s.strip() for s in getattr(settings, "TARGET_SCHEMAS", "public").split(",")]
        schema_json = database.get_schema_json(
            schemas=schemas,
            tables=payload.tables,
            max_tables=getattr(settings, "MAX_SCHEMA_TABLES", 50),
            max_columns=getattr(settings, "MAX_SCHEMA_COLUMNS", 2000),
        )

        # allowed_fqn usando fq_name si existe
        allowed_fqn: List[str] = []
        for t in schema_json.get("tables", []) or []:
            fq = t.get("fq_name")
            if fq:
                allowed_fqn.append(fq)
            else:
                allowed_fqn.append(f'{t["schema"]}."{t["table"]}"')

        dialect = payload.dialect or getattr(settings, "DB_DIALECT", "postgresql")
        default_limit = payload.limit or getattr(settings, "MAX_ROWS_DEFAULT", 100)
        max_limit = getattr(settings, "MAX_ROWS_HARD", 1000)

        # 2) Preparar heurísticas “generalistas”
        schema_cols = _schema_columns_for_tables(schema_json, payload.tables)
        mentioned_cols = _find_mentioned_columns(payload.human_query, schema_cols)
        compare_intent = _has_comparison_intent(payload.human_query) and (len(mentioned_cols) >= 2)
        list_intent = _has_list_intent(payload.human_query)

        # Elegir tabla target (primera permitida, o la primera que coincide con payload.tables)
        table_fqn = allowed_fqn[0] if allowed_fqn else None
        if payload.tables:
            wanted = {_norm_key_name(x) for x in payload.tables if x}
            for t in schema_json.get("tables", []) or []:
                if _norm_key_name(t.get("table") or "") in wanted:
                    table_fqn = (t.get("fq_name") or f'{t["schema"]}."{t["table"]}"')
                    break
        if not table_fqn:
            raise HTTPException(status_code=500, detail="No se pudo determinar una tabla objetivo desde el esquema.")

        # Para comparación: define left/right (dos primeras más específicas)
        op = _infer_compare_operator(payload.human_query)
        key_col = _pick_key_column(schema_cols, payload.human_query)

        left_col = mentioned_cols[0] if len(mentioned_cols) >= 1 else None
        right_col = mentioned_cols[1] if len(mentioned_cols) >= 2 else None

        # 3) Obtener SQL (override → LLM)
        if payload.sql_query_override:
            sql_query = payload.sql_query_override
            result_dict = {"sql_query": sql_query, "original_query": payload.human_query}
            logger.debug("[/human_query] using sql_query_override=%r", sql_query)
        else:
            cache_key = _cache_key(payload.human_query, schema_json, dialect, default_limit)
            cached = _cache_get(cache_key)
            if cached:
                logger.debug("[/human_query] LLM SQL cache HIT")
                sql_json = cached
            else:
                sql_json = await llm.human_query_to_sql(
                    payload.human_query,
                    schema_json=schema_json,
                    dialect=dialect,
                    default_limit=default_limit,
                    model=None,
                )
                _cache_put(cache_key, sql_json)

            logger.debug("[/human_query] LLM raw JSON=%s", (sql_json[:700] if sql_json else None))
            if not sql_json:
                raise HTTPException(status_code=500, detail="Falló la generación de la consulta SQL")

            result_dict = json.loads(sql_json)
            sql_query = result_dict.get("sql_query")
            if not sql_query:
                raise HTTPException(status_code=500, detail="El LLM no devolvió 'sql_query'")

            # 3.1) Auto-retry general: si es consulta de comparación/listado, exigir que métricas estén en SELECT
            if compare_intent and left_col and right_col:
                if (_looks_like_distinct_id_only(sql_query)
                    or (not _sql_has_column_in_select(sql_query, left_col))
                    or (not _sql_has_column_in_select(sql_query, right_col))):
                    forced_query = _augment_query_for_required_select(
                        payload.human_query,
                        key_col=key_col,
                        metric_cols=[left_col, right_col],
                    )
                    logger.debug("[/human_query] retry forced_query=%s", forced_query)

                    sql_json2 = await llm.human_query_to_sql(
                        forced_query,
                        schema_json=schema_json,
                        dialect=dialect,
                        default_limit=default_limit,
                        model=None,
                    )
                    logger.debug("[/human_query] retry raw JSON=%s", (sql_json2[:700] if sql_json2 else None))
                    if sql_json2:
                        try:
                            parsed2 = json.loads(sql_json2)
                            sql2 = (parsed2.get("sql_query") or "").strip()
                            if sql2:
                                sql_query = sql2
                                result_dict = parsed2
                        except Exception:
                            pass

        # 4) Higiene + macros + EXPLAIN + qualify
        sql_query = database.clean_sql(sql_query)
        sql_query = database.expand_macros(sql_query)
        sql_query = database.sanitize_explain(sql_query)
        sql_query = database.qualify_tables(sql_query, allowed_fqn)

        # 5) Validación de seguridad ANTES de ejecutar
        if not database.is_safe_select(sql_query):
            raise HTTPException(status_code=400, detail="SQL insegura (no es SELECT/CTE/EXPLAIN permitido).")

        if not database.restrict_to_allowed_tables(sql_query, allowed_fqn):
            # Si era comparación y podemos resolver directo, hacemos fallback determinístico
            if compare_intent and left_col and right_col:
                sql_query = _build_direct_sql_compare(
                    table_fqn=table_fqn,
                    key_col=key_col,
                    left_col=left_col,
                    right_col=right_col,
                    op=op,
                    limit=default_limit,
                )
                sql_query = database.clean_sql(sql_query)
                sql_query = database.expand_macros(sql_query)
                sql_query = database.sanitize_explain(sql_query)
                sql_query = database.qualify_tables(sql_query, allowed_fqn)

                if not database.restrict_to_allowed_tables(sql_query, allowed_fqn):
                    raise HTTPException(status_code=400, detail="La consulta referencia tablas no permitidas según el esquema actual.")
            else:
                raise HTTPException(status_code=400, detail="La consulta referencia tablas no permitidas según el esquema actual.")

        # Dry-run
        if not payload.execute:
            return {"sql_query": sql_query, "original_query": result_dict.get("original_query")}

        # 6) Ejecutar SQL real
        try:
            rows_raw = await database.query(
                sql_query,
                allowed_fqn=allowed_fqn,
                default_limit=default_limit,
                max_limit=max_limit,
            )
        except Exception as ex:
            msg = str(ex) or ""
            if "tablas no permitidas" in msg.lower():
                raise HTTPException(status_code=400, detail="La consulta referencia tablas no permitidas según el esquema actual.")
            raise

        # 6.1) Post-check general: si era comparación, asegúrate que en filas vienen las 2 métricas
        if compare_intent and left_col and right_col:
            def _rows_have_key(rows: List[Dict[str, Any]], colname: str) -> bool:
                if not rows or not colname:
                    return False
                return any(colname in r for r in rows[:5])

            left_ok = _rows_have_key(rows_raw, left_col)
            right_ok = _rows_have_key(rows_raw, right_col)

            # Si el LLM filtró usando WHERE pero no seleccionó las métricas, re-ejecuta con fallback determinístico
            if not (left_ok and right_ok):
                logger.warning("[/human_query] Post-check: faltan métricas comparadas en rows. Re-ejecutando con fallback determinístico.")
                sql_fallback = _build_direct_sql_compare(
                    table_fqn=table_fqn,
                    key_col=key_col,
                    left_col=left_col,
                    right_col=right_col,
                    op=op,
                    limit=default_limit,
                )
                sql_fallback = database.clean_sql(sql_fallback)
                sql_fallback = database.expand_macros(sql_fallback)
                sql_fallback = database.sanitize_explain(sql_fallback)
                sql_fallback = database.qualify_tables(sql_fallback, allowed_fqn)

                rows_raw = await database.query(
                    sql_fallback,
                    allowed_fqn=allowed_fqn,
                    default_limit=default_limit,
                    max_limit=max_limit,
                )
                sql_query = sql_fallback

        # 6.2) Limpieza de filas TOTAL / vacías
        rows_raw = _drop_total_like_rows(rows_raw)

        # 7) Normalización post-DB
        implied_cols_env = [s.strip() for s in (env("IMPLIED_MILLIS_COLUMNS", default="") or "").split(",") if s.strip()]
        implied_cols = payload.implied_millis_cols if payload.implied_millis_cols is not None else implied_cols_env

        fmt_strings_env = env("RETURN_FORMATTED_NUMBERS", default=True, cast=bool)
        fmt_strings = payload.format_numbers if payload.format_numbers is not None else fmt_strings_env

        decimal_places_env = env("DECIMAL_PLACES", default=3, cast=int)
        decimal_places = payload.decimals if payload.decimals is not None else decimal_places_env

        rows = normalize_rows(
            rows_raw,
            implied_millis_cols=implied_cols,
            decimal_places=decimal_places,
            fmt_strings=fmt_strings
        )

        # 8) Resumen opcional
        if not payload.summarize:
            return {"rows": rows, "row_count": len(rows), "sql_query": sql_query}

        try:
            answer = await llm.build_answer(rows, payload.human_query, model=None)
            if not (answer or "").strip():
                local_answer = _local_summary_answer(rows, payload.human_query)
                return {
                    "answer": local_answer,
                    "answer_source": "local_fallback",
                    "rows": rows[:50],
                    "row_count": len(rows),
                    "sql_query": sql_query,
                    "warning": "Resumen generado localmente por falta de respuesta del LLM."
                }
            return {
                "answer": answer,
                "answer_source": "llm",
                "rows": rows[:50],
                "row_count": len(rows),
                "sql_query": sql_query
            }
        except Exception as ex:
            logger.exception("Fallo al generar 'answer'.")
            local_answer = _local_summary_answer(rows, payload.human_query)
            return {
                "answer": local_answer,
                "answer_source": "local_fallback",
                "rows": rows[:50],
                "row_count": len(rows),
                "sql_query": sql_query,
                "warning": f"LLM falló, se usó resumen local: {str(ex)[:160]}"
            }

    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Error en /human_query")
        raise HTTPException(status_code=500, detail=str(e))