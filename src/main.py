# src/main.py
import json
import logging
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, HTTPException, Depends, Header, Request, Query
from pydantic import BaseModel

from . import database
from . import llm

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
    summarize: Optional[bool] = True   # si False → no llamar OpenAI para respuesta


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
        # Compatibilidad con config.py (TARGET_SCHEMAS cadena comma-separada)
        schemas = [s.strip() for s in getattr(settings, "TARGET_SCHEMAS", "public").split(",")]

    schema_json = database.get_schema_json(
        schemas=schemas,
        tables=tables,
        max_tables=getattr(settings, "MAX_SCHEMA_TABLES", 50),
        max_columns=getattr(settings, "MAX_SCHEMA_COLUMNS", 2000),
    )
    return schema_json

"""
@router.get("/llm/ping", dependencies=[Depends(api_key_guard)])
async def llm_ping(request: Request) -> Dict[str, Any]:
    try:
        txt = await llm.build_answer([{"ok": True}], "ping")
        return {"status": "ok", "gemini_reply": txt[:200]}
    except Exception as e:
        return {"status": "error", "detail": str(e)}
""" 

@router.get("/llm/ping", dependencies=[Depends(api_key_guard)])
async def llm_ping(request: Request) -> Dict[str, Any]:
    try:
        txt = await llm.ping()
        return {"status": "ok", "gemini_reply": (txt or "")[:200]}
    except Exception as e:
        # Devuelve el error del SDK tal cual para diagnosticar
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

    return {
        "schemas_requested": schemas,
        "schema_json": schema_json
    }

@router.get("/debug/tables")
def debug_tables(request: Request):
    settings = request.app.state.settings
    schemas = [s.strip() for s in getattr(settings, "TARGET_SCHEMAS", "public").split(",")]

    schema_json = database.get_schema_json(schemas=schemas)
    tables = [t["table"] for t in schema_json.get("tables", [])]

    return {
        "tables_detected": tables
    }
    
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

    return {
        "raw_llm_sql_json": sql_json
    }


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
    forbidden_hits = database.find_forbidden_tokens(sql_clean)

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

        logger.debug("[/human_query] allowed_fqn=%s", allowed_fqn)  # [DEBUG]
        
        dialect = payload.dialect or getattr(settings, "DB_DIALECT", "postgresql")
        default_limit = payload.limit or getattr(settings, "MAX_ROWS_DEFAULT", 100)
        max_limit = getattr(settings, "MAX_ROWS_HARD", 1000)
        llm_model = getattr(settings, "GEMINI_MODEL", "gemini-1.5-flash")


        # 2) Obtener SQL (override → LLM)
        if payload.sql_query_override:
            sql_query = payload.sql_query_override
            result_dict = {"sql_query": sql_query, "original_query": payload.human_query}
            logger.debug("[/human_query] using sql_query_override=%r", sql_query)  # [DEBUG]
        else:
            sql_json = await llm.human_query_to_sql(
                payload.human_query,
                schema_json=schema_json,
                dialect=dialect,
                default_limit=default_limit,
                model=llm_model,
            )
            logger.debug("[/human_query] LLM raw JSON=%s", (sql_json[:500] if sql_json else None))  # [DEBUG
            if not sql_json:
                raise HTTPException(status_code=500, detail="Falló la generación de la consulta SQL")

            result_dict = json.loads(sql_json)
            sql_query = result_dict.get("sql_query")
            if not sql_query:
                raise HTTPException(status_code=500, detail="El LLM no devolvió 'sql_query'")

        
        # Limpieza antes de dry-run / ejecución
        sql_query = database.clean_sql(sql_query)

        # 3) Dry-run
        if not payload.execute:
            if not database.is_safe_select(sql_query) or not database.restrict_to_allowed_tables(sql_query, allowed_fqn):
                
                logger.debug("[/human_query] FAIL dry-run safe=%s allowed=%s",
                             database.is_safe_select(sql_query),
                             database.restrict_to_allowed_tables(sql_query, allowed_fqn))  # [DEBUG]

                raise HTTPException(status_code=400, detail="SQL insegura o fuera de las tablas permitidas.")
            return {"sql_query": sql_query, "original_query": result_dict.get("original_query")}

        # 4) Ejecutar SQL real
        rows = await database.query(
            sql_query,
            allowed_fqn=allowed_fqn,
            default_limit=default_limit,
            max_limit=max_limit,
        )

        # 5) Resumen opcional en lenguaje natural
        if not payload.summarize:
            return {"rows": rows, "row_count": len(rows), "sql_query": sql_query}

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
