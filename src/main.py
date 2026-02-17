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
        schemas = [s.strip() for s in getattr(settings, "TARGET_SCHEMAS", "public").split(",")]

    schema_json = database.get_schema_json(
        schemas=schemas,
        tables=tables,
        max_tables=getattr(settings, "MAX_SCHEMA_TABLES", 50),
        max_columns=getattr(settings, "MAX_SCHEMA_COLUMNS", 2000),
    )
    return schema_json


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
        default_limit = payload.limit or 100
        max_limit = getattr(settings, "MAX_QUERY_LIMIT", 1000)
        llm_model = getattr(settings, "GEMINI_MODEL", "gemini-1.5-flash")

        # 2) Obtener SQL (override → LLM)
        if payload.sql_query_override:
            sql_query = payload.sql_query_override
            result_dict = {"sql_query": sql_query, "original_query": payload.human_query}
        else:
            sql_json = await llm.human_query_to_sql(
                payload.human_query,
                schema_json=schema_json,
                dialect=dialect,
                default_limit=default_limit,
                model=llm_model,
            )
            if not sql_json:
                raise HTTPException(status_code=500, detail="Falló la generación de la consulta SQL")

            result_dict = json.loads(sql_json)
            sql_query = result_dict.get("sql_query")
            if not sql_query:
                raise HTTPException(status_code=500, detail="El LLM no devolvió 'sql_query'")

        # 3) Dry-run
        if not payload.execute:
            if not database.is_safe_select(sql_query) or not database.restrict_to_allowed_tables(sql_query, allowed_fqn):
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
            #answer = await llm.build_answer(rows, payload.human_query)
            return {
                "answer": answer,
                "rows": rows[:50],
                "sql_query": sql_query
            }
        except Exception:
            logger.exception("Fallo al generar 'answer'.")
            return {
                "rows": rows,
                "row_count": len(rows),
                "sql_query": sql_query,
                "warning": "Fallo al generar el resumen con OpenAI"
            }

    except Exception as e:
        logger.exception("Error en /human_query")
        raise HTTPException(status_code=500, detail=str(e))
