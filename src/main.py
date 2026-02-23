# src/main.py
import json
import logging
import unicodedata
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, HTTPException, Depends, Header, Request, Query
from pydantic import BaseModel

from . import database
from . import llm

# ---- helpers de normalización y configuración ----
from decimal import Decimal
from decouple import config as env



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
    - Divide entre 1000.0 las columnas/aliases listados en implied_millis_cols (match exacto por nombre normalizado).
    - Heurística opcional: si el nombre contiene alguna keyword (subcadena) y el valor luce inflado (>=100000 y múltiplo de 1000),
      divide entre 1000. Las keywords vienen de .env y se comparan en minúsculas, sin tildes.
    - Redondeo y formateo opcional.
    """
    # Lista explícita (match exacto por nombre normalizado)
    implied_exact = {_norm_key_name(c) for c in implied_millis_cols if c and c.strip()}

    # Heurística configurable por .env
    auto_heur = env("IMPLIED_MILLIS_AUTO_HEURISTIC", default=True, cast=bool)
    keywords_env = env(
        "IMPLIED_MILLIS_KEYWORDS",
        # incluimos variantes típicas
        default="despachado,original,pendiente,total linea,total línea,total despachado,total original,total pendiente"
    )
    kw_list = [_norm_key_name(w) for w in keywords_env.split(",") if w.strip()]

    def _name_has_keyword(name_low: str) -> bool:
        # subcadena: si alguna keyword aparece dentro del nombre normalizado
        return any((kw in name_low) for kw in kw_list if kw)

    out: List[Dict[str, Any]] = []

    for r in rows:
        nr: Dict[str, Any] = {}
        for k, v in (r or {}).items():
            name_low = _norm_key_name(k)
            val = _to_number(v)

            if isinstance(val, (int, float)) or isinstance(v, Decimal):
                valf = float(val)

                must_divide = False

                # 1) Regla explícita (alias exacto en la lista)
                if name_low in implied_exact:
                    must_divide = True

                # 2) Heurística (si activa): nombre contiene keyword y valor "inflado"
                if not must_divide and auto_heur and _name_has_keyword(name_low):
                    nearest = round(valf)
                    if abs(valf - nearest) < 1e-9 and abs(nearest) >= 100000 and nearest % 1000 == 0:
                        must_divide = True

                if must_divide:
                    valf = valf / 1000.0

                valf = round(valf, decimal_places)
                nr[k] = f"{valf:,.{decimal_places}f}" if fmt_strings else valf
            else:
                nr[k] = v
        out.append(nr)

    return out

# ---------------------------------------------------------

logger = logging.getLogger(__name__)
router = APIRouter()

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
    # NUEVO: control de salida por request (sin tocar .env)
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
        "GOOGLE_API_KEY_prefix": (k[:6] + "...") if k else "(empty)",
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
    llm_model = getattr(settings, "GEMINI_MODEL", "gemini-1.5-flash")

    sql_json = await llm.human_query_to_sql(
        payload.human_query,
        schema_json=schema_json,
        dialect=payload.dialect or "postgresql",
        default_limit=payload.limit or 100,
        model=llm_model,
    )
    return {"raw_llm_sql_json": sql_json}

@router.post("/debug/llm_sql_full")
async def debug_llm_sql_full(request: Request, payload: PostHumanQueryPayload):
    settings = request.app.state.settings

    schemas = payload.schemas or [s.strip() for s in getattr(settings, "TARGET_SCHEMAS", "public").split(",")]
    schema_json = database.get_schema_json(schemas=schemas, tables=payload.tables)
    allowed_fqn = [f'{t["schema"]}."{t["table"]}"' for t in schema_json.get("tables", [])]

    llm_model = getattr(settings, "GEMINI_MODEL", "gemini-1.5-flash")
    raw_json = await llm.human_query_to_sql(
        payload.human_query,
        schema_json=schema_json,
        dialect=payload.dialect or "postgresql",
        default_limit=payload.limit or 100,
        model=llm_model,
    )

    try:
        parsed = json.loads(raw_json)
    except Exception:
        parsed = {"error": "No se pudo parsear JSON", "raw": raw_json}

    sql_raw = parsed.get("sql_query", "")
    sql_clean = database.clean_sql(sql_raw)

    safe = database.is_safe_select(sql_clean)
    allowed = database.restrict_to_allowed_tables(sql_clean, allowed_fqn)
    forbidden_hits = database.find_forbidden_tokens(sql_clean) if hasattr(database, "find_forbidden_tokens") else []

    return {
        "LLM_raw_JSON": raw_json,
        "sql_raw": sql_raw,
        "sql_clean": sql_clean,
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
        llm_model = getattr(settings, "GEMINI_MODEL", "gemini-1.5-flash")

        # 2) Obtener SQL (override → LLM)
        if payload.sql_query_override:
            sql_query = payload.sql_query_override
            result_dict = {"sql_query": sql_query, "original_query": payload.human_query}
            logger.debug("[/human_query] using sql_query_override=%r", sql_query)
        else:
            sql_json = await llm.human_query_to_sql(
                payload.human_query,
                schema_json=schema_json,
                dialect=dialect,
                default_limit=default_limit,
                model=llm_model,
            )
            logger.debug("[/human_query] LLM raw JSON=%s", (sql_json[:500] if sql_json else None))
            if not sql_json:
                raise HTTPException(status_code=500, detail="Falló la generación de la consulta SQL")

            result_dict = json.loads(sql_json)
            sql_query = result_dict.get("sql_query")
            if not sql_query:
                raise HTTPException(status_code=500, detail="El LLM no devolvió 'sql_query'")

        # Limpieza + macro
        sql_query = database.clean_sql(sql_query)
        sql_query = database.expand_numeric_clean(sql_query)

        # 3) Dry-run
        if not payload.execute:
            if not database.is_safe_select(sql_query) or not database.restrict_to_allowed_tables(sql_query, allowed_fqn):
                logger.debug("[/human_query] FAIL dry-run safe=%s allowed=%s",
                             database.is_safe_select(sql_query),
                             database.restrict_to_allowed_tables(sql_query, allowed_fqn))
                raise HTTPException(status_code=400, detail="SQL insegura o fuera de las tablas permitidas.")
            return {"sql_query": sql_query, "original_query": result_dict.get("original_query")}

        # 4) Ejecutar SQL real
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
            answer = await llm.build_answer(rows, payload.human_query, model=llm_model)
            return {
                "answer": answer,
                "rows": rows[:50],
                "row_count": len(rows),
                "sql_query": sql_query
            }
        except Exception as ex:
            logger.exception("Fallo al generar 'answer'.")
            return {
                "rows": rows[:50],
                "row_count": len(rows),
                "sql_query": sql_query,
                "warning": f"No se pudo generar el resumen (LLM): {str(ex)[:180]}",
                "can_retry_summary": True
            }

    except Exception as e:
        logger.exception("Error en /human_query")
        raise HTTPException(status_code=500, detail=str(e))