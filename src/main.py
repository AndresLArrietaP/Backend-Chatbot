"""# src/main.py
import json
import logging
from typing import Dict

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from . import database
from . import llm

logger = logging.getLogger(__name__)
router = APIRouter()

class PostHumanQueryPayload(BaseModel):
    human_query: str

@router.get("/")
def root() -> Dict[str, str]:
    return {"status": "ok", "docs": "/docs"}

@router.get("/healthz")
def healthz() -> Dict[str, str]:
    return {"status": "healthy"}

@router.post(
    "/human_query",
    name="Human Query",
    operation_id="post_human_query",
    description="Transforma lenguaje natural a SQL, consulta la BD y devuelve respuesta.",
)
async def human_query(payload: PostHumanQueryPayload) -> Dict[str, str]:
    try:
        # 1) LLM: transforma pregunta → SQL (retorna JSON string con 'sql_query')
        sql_json = await llm.human_query_to_sql(payload.human_query)
        if not sql_json:
            raise HTTPException(status_code=500, detail="Falló la generación de la consulta SQL")

        result_dict = json.loads(sql_json)
        sql_query = result_dict.get("sql_query")
        if not sql_query:
            raise HTTPException(status_code=500, detail="El LLM no devolvió 'sql_query'")

        # 2) Ejecuta SQL
        rows = await database.query(sql_query)

        # 3) LLM: redacta respuesta para humano
        answer = await llm.build_answer(rows, payload.human_query)
        if not answer:
            raise HTTPException(status_code=500, detail="Falló la generación de la respuesta")

        return {"answer": answer}

    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Error en /human_query")
        raise HTTPException(status_code=500, detail=str(e))"""
        
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
        return  # sin auth requerida
    if not x_api_key or x_api_key != required:
        raise HTTPException(status_code=401, detail="API key inválida")

# --------- Models ---------
class PostHumanQueryPayload(BaseModel):
    human_query: str
    schemas: Optional[List[str]] = None   # p.ej. ["public"]
    tables: Optional[List[str]] = None    # p.ej. ["ConsumoMARC", "OtraTabla"]
    dialect: Optional[str] = None         # override de DB_DIALECT
    limit: Optional[int] = None           # override de default limit
    execute: bool = True                  # si false => solo devuelve la SQL
    schema_refresh: bool = False          # fuerza refresco de esquema

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

@router.post(
    "/human_query",
    name="Human Query",
    operation_id="post_human_query",
    description="Transforma lenguaje natural a SQL, valida y ejecuta (opcional).",
    dependencies=[Depends(api_key_guard)],
)
async def human_query(request: Request, payload: PostHumanQueryPayload) -> Dict[str, Any]:
    try:
        settings = request.app.state.settings

        # 1) Esquema actual (dinámico)
        if payload.schema_refresh:
            database.refresh_schema_cache()

        schemas = payload.schemas or [s.strip() for s in getattr(settings, "TARGET_SCHEMAS", "public").split(",")]
        schema_json = database.get_schema_json(
            schemas=schemas,
            tables=payload.tables,
            max_tables=getattr(settings, "MAX_SCHEMA_TABLES", 50),
            max_columns=getattr(settings, "MAX_SCHEMA_COLUMNS", 2000),
        )

        # Lista de tablas permitidas con FQN como aparecerá en SQL (heurístico)
        allowed_fqn = [f'{t["schema"]}."{t["table"]}"' for t in schema_json.get("tables", [])]

        # 2) Dialecto y límites
        dialect = payload.dialect or getattr(settings, "DB_DIALECT", "postgresql")
        default_limit = payload.limit or 100
        max_limit = getattr(settings, "MAX_QUERY_LIMIT", 1000)

        # 3) LLM → SQL (JSON)
        sql_json = await llm.human_query_to_sql(
            payload.human_query,
            schema_json=schema_json,
            dialect=dialect,
            default_limit=default_limit,
        )
        if not sql_json:
            raise HTTPException(status_code=500, detail="Falló la generación de la consulta SQL")

        result_dict = json.loads(sql_json)
        sql_query = result_dict.get("sql_query")
        if not sql_query:
            raise HTTPException(status_code=500, detail="El LLM no devolvió 'sql_query'")

        # 4) Dry-run (si execute=false)
        if not payload.execute:
            # Validamos seguridad aún en dry-run para que sea útil al integrarlo con un bot
            if not database.is_safe_select(sql_query) or not database.restrict_to_allowed_tables(sql_query, allowed_fqn):
                raise HTTPException(status_code=400, detail="SQL insegura o fuera de las tablas permitidas.")
            return {"sql_query": sql_query, "original_query": result_dict.get("original_query")}

        # 5) Ejecuta con seguridad
        rows = await database.query(
            sql_query,
            allowed_fqn=allowed_fqn,
            default_limit=default_limit,
            max_limit=max_limit,
        )

        # 6) Respuesta en lenguaje natural
        answer = await llm.build_answer(rows, payload.human_query)
        if not answer:
            raise HTTPException(status_code=500, detail="Falló la generación de la respuesta")

        return {"answer": answer, "rows": rows[: min(len(rows), 50)]}  # devuelvo muestra pequeña si quieres

    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Error en /human_query")
        raise HTTPException(status_code=500, detail=str(e))