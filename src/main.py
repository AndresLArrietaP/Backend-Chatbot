# src/main.py
import json
import logging
import unicodedata
import time
from hashlib import sha1
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, HTTPException, Depends, Header, Request, Query
from pydantic import BaseModel

from . import database
from . import llm

# ---- helpers de normalización y configuración ----
from decimal import Decimal
from decouple import config as env

logger = logging.getLogger(__name__)
router = APIRouter()

def _to_number(v):
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
    Normaliza resultados numéricos con detección robusta de milésimas implícitas
    SIN depender de 'implied_millis_cols' como regla dura.

    Reglas de división x1000 SOLO si:
      (A) La AUTODETECCIÓN por distribución marca la columna, o
      (B) (pista explícita o keyword) Y el valor individual luce "múltiplo de 1000" y es grande.

    Formato:
      - Si 'fmt_strings' es True:
          * Números enteros -> sin decimales y con separador de miles COMA (p. ej., 42,869)
          * Números no enteros -> con 'decimal_places' y separador de miles COMA
    """
    # Pistas explícitas (soft)
    implied_exact = {_norm_key_name(c) for c in (implied_millis_cols or []) if c and c.strip()}

    # Flags / parámetros
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

    # ---------- 1) Stats de columna para AUTODETECCIÓN ----------
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
                continue  # muestra pequeña
            vals_sorted = sorted(vals)
            mid = len(vals_sorted) // 2
            median = (vals_sorted[mid] if len(vals_sorted) % 2 == 1
                      else 0.5 * (vals_sorted[mid - 1] + vals_sorted[mid]))
            mult_cnt = sum(1 for x in vals if _is_big_multiple_of_1000(x))
            ratio = mult_cnt / len(vals)
            if ratio >= ratio_threshold or (median >= (min_abs * 2) and ratio >= 0.6):
                auto_divide_cols.add(_norm_key_name(col))

    # ---------- 2) Aplicar normalización ----------
    out: List[Dict[str, Any]] = []
    for r in rows:
        nr: Dict[str, Any] = {}
        for k, v in (r or {}).items():
            name_low = _norm_key_name(k)
            val = _to_number(v)

            if isinstance(val, (int, float)) or isinstance(v, Decimal):
                valf = float(val)

                # División x1000 si corresponde
                must_divide = False
                col_marked = name_low in auto_divide_cols
                soft_signal = (name_low in implied_exact) or (auto_kw and _name_has_keyword(name_low))

                if col_marked:
                    must_divide = True
                elif soft_signal and _is_big_multiple_of_1000(valf):
                    must_divide = True

                if must_divide:
                    valf = valf / 1000.0

                # Formateo
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

# -------- Fallback de resumen local (determinista y limpio) --------
def _local_summary_answer(rows: List[Dict[str, Any]], human_query: str) -> str:
    if not rows:
        return f"No se encontraron datos para la consulta: “{human_query}”."

    # Detecta posibles columnas de clave (texto) y de valor (numérica)
    sample = rows[0]
    text_cols: List[str] = []
    num_cols: List[str] = []

    # Clasificación simple por tipo / parseo
    for k in sample.keys():
        is_num = False
        for r in rows:
            v = r.get(k)
            if isinstance(v, (int, float, Decimal)):
                is_num = True
                break
            if isinstance(v, str):
                try:
                    float(v.replace(",", ""))  # por si vienen formateados
                    is_num = True
                    break
                except Exception:
                    pass
        if is_num:
            num_cols.append(k)
        else:
            text_cols.append(k)

    # Heurísticas de nombres para priorizar columnas comunes en tu dataset
    def _score_text(name: str) -> int:
        n = name.lower()
        # prioriza "Material" o similares
        if "material" in n:
            return 3
        if "cliente" in n:
            return 2
        return 1

    def _score_num(name: str) -> int:
        n = name.lower()
        if "total línea" in n or "total linea" in n:
            return 4
        if "despachado" in n or "cantidad" in n or "total" in n:
            return 3
        if "valor" in n:
            return 2
        return 1

    # Elige columnas candidatas
    text_cols.sort(key=_score_text, reverse=True)
    num_cols.sort(key=_score_num, reverse=True)

    key_col = text_cols[0] if text_cols else None
    val_col = num_cols[0] if num_cols else None

    # Construcción del resumen
    bullets: List[str] = []
    bullets.append(f"Filas analizadas: {len(rows)}.")

    if val_col:
        # suma total
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

    # Top-3 por clave textual (si existen ambas)
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

    # Construye el texto final (2–3 frases sin markdown)
    summary_parts = []
    summary_parts.append(f"Consulta: “{human_query}”.")
    if val_col and key_col:
        summary_parts.append(f"Se analizó “{val_col}” por “{key_col}” y se listan los principales aportes.")
    elif val_col:
        summary_parts.append(f"Se destaca la métrica “{val_col}”.")
    else:
        summary_parts.append("No se identificó una métrica numérica dominante; se muestran datos generales.")

    final = " ".join(p if p.endswith(('.', '!', '?')) else p + "." for p in summary_parts)
    # Añade 2–3 bullets en líneas nuevas
    for b in bullets[:3]:
        final += f"\n- {b}"
    return final
# ------------------- LLM SQL cache (LRU+TTL) -------------------
_SQL_CACHE: Dict[str, Dict[str, Any]] = {}
SQL_CACHE_TTL = env("SQL_CACHE_TTL_SECONDS", default=300, cast=int)  # 5 min
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
    # Evict simple por expiración y tamaño
    if len(_SQL_CACHE) >= SQL_CACHE_MAX:
        oldest = min(_SQL_CACHE.items(), key=lambda kv: kv[1]["exp"])[0]
        _SQL_CACHE.pop(oldest, None)
    _SQL_CACHE[key] = {"exp": time.time() + SQL_CACHE_TTL, "sql_json": sql_json}

# ---------------------------------------------------------

# --------- Auth opcional por API Key ---------
async def api_key_guard(request: Request, x_api_key: Optional[str] = Header(default=None)):
    settings = request.app.state.settings
    required = getattr(settings, "API_KEY", "") or ""
    if not required:
        return
    if not x_api_key or x_api_key != required:
        raise HTTPException(status_code=401, detail="API key inválida")

# --------- Modelo ---------
class PostHumanQueryPayload(BaseModel):
    human_query: str
    sql_query_override: Optional[str] = None
    schemas: Optional[List[str]] = None
    tables: Optional[List[str]] = None
    dialect: Optional[str] = None
    limit: Optional[int] = None
    execute: bool = True
    schema_refresh: bool = False
    summarize: Optional[bool] = True   # si False → no llamar LLM para respuesta
    # Control de salida por request (sin tocar .env)
    format_numbers: Optional[bool] = None         # si None -> usa .env RETURN_FORMATTED_NUMBERS
    decimals: Optional[int] = None                # si None -> usa .env DECIMAL_PLACES
    implied_millis_cols: Optional[List[str]] = None  # override por request

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
    
@router.get("/configz", dependencies=[Depends(api_key_guard)])
def configz(request: Request):
    s = request.app.state.settings
    k = (getattr(s, "GOOGLE_API_KEY", "") or "")
    return {
        "LLM_PROVIDER": getattr(s, "LLM_PROVIDER", "gemini"),
        "GOOGLE_API_KEY_prefix": ((k[:6] + "...") if k else "(empty)"),
        "GEMINI_MODEL": getattr(s, "GEMINI_MODEL", ""),
        "GEMINI_MODEL_ANSWER": getattr(s, "GEMINI_MODEL_ANSWER", ""),
        "OPENAI_MODEL": getattr(s, "OPENAI_MODEL", ""),
    }

@router.get("/llm/models", dependencies=[Depends(api_key_guard)])
def llm_models() -> Dict[str, Any]:
    try:
        return llm.list_models()
    except Exception as e:
        return {"status": "error", "detail": str(e)}

# ------- DEBUG endpoints --------
@router.get("/debug/schema")
def debug_schema(request: Request):
    settings = request.app.state.settings
    schemas = [s.strip() for s in getattr(settings, "TARGET_SCHEMAS", "public").split(",")]

    schema_json = database.get_schema_json(
        schemas=schemas,
        tables=None,
        max_tables=200,
        max_columns=5000,
    )
    return {"schemas_requested": schemas, "schema_json": schema_json}

@router.get("/debug/tables")
def debug_tables(request: Request):
    settings = request.app.state.settings
    schemas = [s.strip() for s in getattr(settings, "TARGET_SCHEMAS", "public").split(",")]

    schema_json = database.get_schema_json(schemas=schemas)
    tables = [t["table"] for t in schema_json.get("tables", [])]
    return {"tables_detected": tables}
    
@router.post("/debug/llm_sql")
async def debug_llm_sql(request: Request, payload: PostHumanQueryPayload):
    settings = request.app.state.settings
    schemas = payload.schemas or [s.strip() for s in getattr(settings, "TARGET_SCHEMAS", "public").split(",")]
    schema_json = database.get_schema_json(schemas=schemas, tables=payload.tables)

    # Cache LLM -> SQL
    cache_key = _cache_key(payload.human_query, schema_json, payload.dialect or "postgresql", payload.limit or 100)
    cached = _cache_get(cache_key)
    if cached:
        sql_json = cached
    else:
        sql_json = await llm.human_query_to_sql(
            payload.human_query,
            schema_json=schema_json,
            dialect=payload.dialect or "postgresql",
            default_limit=payload.limit or 100,
            model=None,  # deja que el provider elija por .env
        )
        _cache_put(cache_key, sql_json)

    return {"raw_llm_sql_json": sql_json}

@router.post("/debug/llm_sql_full")
async def debug_llm_sql_full(request: Request, payload: PostHumanQueryPayload):
    settings = request.app.state.settings

    schemas = payload.schemas or [s.strip() for s in getattr(settings, "TARGET_SCHEMAS", "public").split(",")]
    schema_json = database.get_schema_json(schemas=schemas, tables=payload.tables)
    allowed_fqn = [f'{t["schema"]}."{t["table"]}"' for t in schema_json.get("tables", [])]

    cache_key = _cache_key(payload.human_query, schema_json, payload.dialect or "postgresql", payload.limit or 100)
    cached = _cache_get(cache_key)
    if cached:
        raw_json = cached
    else:
        raw_json = await llm.human_query_to_sql(
            payload.human_query,
            schema_json=schema_json,
            dialect=payload.dialect or "postgresql",
            default_limit=payload.limit or 100,
            model=None,  # deja que el provider elija por .env
        )
        _cache_put(cache_key, raw_json)

    try:
        parsed = json.loads(raw_json)
    except Exception:
        parsed = {"error": "No se pudo parsear JSON", "raw": raw_json}

    sql_raw = parsed.get("sql_query", "")

    # Pipeline consistente
    sql_clean = database.clean_sql(sql_raw)
    sql_clean = database.expand_macros(sql_clean)
    sql_clean = database.sanitize_explain(sql_clean)
    sql_clean = database.qualify_tables(sql_clean, allowed_fqn)

    safe = database.is_safe_select(sql_clean)
    allowed = database.restrict_to_allowed_tables(sql_clean, allowed_fqn)
    forbidden_hits = database.find_forbidden_tokens(sql_clean) if hasattr(database, "find_forbidden_tokens") else []

    return {
        "LLM_raw_JSON": raw_json,
        "sql_processed": sql_clean,
        "allowed_fqn": allowed_fqn,
        "is_safe_select": safe,
        "restrict_ok": allowed,
        "forbidden_hits": forbidden_hits,
        "schema_used": schema_json,
    }
# ------- /DEBUG endpoints --------
    
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
        allowed_fqn = [f'{t["schema"]}."{t["table"]}"' for t in schema_json.get("tables", [])]

        dialect = payload.dialect or getattr(settings, "DB_DIALECT", "postgresql")
        default_limit = payload.limit or getattr(settings, "MAX_ROWS_DEFAULT", 100)
        max_limit = getattr(settings, "MAX_ROWS_HARD", 1000)

        # 2) Obtener SQL (override → LLM)
        if payload.sql_query_override:
            sql_query = payload.sql_query_override
            result_dict = {"sql_query": sql_query, "original_query": payload.human_query}
            logger.debug("[/human_query] using sql_query_override=%r", sql_query)
        else:
            # Cache LLM -> SQL
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
                    model=None,  # provider por .env
                )
                _cache_put(cache_key, sql_json)

            logger.debug("[/human_query] LLM raw JSON=%s", (sql_json[:500] if sql_json else None))
            if not sql_json:
                raise HTTPException(status_code=500, detail="Falló la generación de la consulta SQL")

            result_dict = json.loads(sql_json)
            sql_query = result_dict.get("sql_query")
            if not sql_query:
                raise HTTPException(status_code=500, detail="El LLM no devolvió 'sql_query'")

        # Limpieza + macros + saneo EXPLAIN + qualify (consistente para dry-run y ejecución)
        sql_query = database.clean_sql(sql_query)
        sql_query = database.expand_macros(sql_query)
        sql_query = database.sanitize_explain(sql_query)
        sql_query = database.qualify_tables(sql_query, allowed_fqn)

        # 3) Dry-run
        if not payload.execute:
            if not database.is_safe_select(sql_query) or not database.restrict_to_allowed_tables(sql_query, allowed_fqn):
                logger.debug("[/human_query] FAIL dry-run safe=%s allowed=%s",
                             database.is_safe_select(sql_query),
                             database.restrict_to_allowed_tables(sql_query, allowed_fqn))
                raise HTTPException(status_code=400, detail="SQL insegura o fuera de las tablas permitidas.")
            return {"sql_query": sql_query, "original_query": result_dict.get("original_query")}

        # 4) Ejecutar SQL real (database.query repite saneos por defensa en profundidad)
        rows_raw = await database.query(
            sql_query,
            allowed_fqn=allowed_fqn,
            default_limit=default_limit,
            max_limit=max_limit,
        )

        # 4.1) Normalización post-DB
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

        # 5) Resumen opcional en lenguaje natural (usar filas normalizadas)
        if not payload.summarize:
            return {
                "rows": rows,
                "row_count": len(rows),
                "sql_query": sql_query
            }

        try:
            answer = await llm.build_answer(rows, payload.human_query, model=None)
            if not (answer or "").strip():
                # Fallback determinista
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

    except Exception as e:
        logger.exception("Error en /human_query")
        raise HTTPException(status_code=500, detail=str(e))