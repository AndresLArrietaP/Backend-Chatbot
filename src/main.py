# src/main.py
# -*- coding: utf-8 -*-
"""
Módulo: main
------------
Router principal de la API (FastAPI) para NL→SQL sobre Azure SQL (SQL Server).

Incluye:
- Endpoints base:
  - GET  /            -> raíz
  - GET  /health      -> health check
  - GET  /schema      -> introspección del esquema (cacheado)
  - POST /schema/refresh -> refresca caché de esquema
  - POST /human_query -> NL→SQL + ejecución opcional
  - POST /sql         -> ejecutar SQL directo (solo lectura)

- Endpoints LLM utilitarios (de la versión anterior):
  - GET  /llm/ping
  - GET  /llm/models

Seguridad:
- Solo consultas de lectura (SELECT/CTE, EXPLAIN si está permitido, VALUES si está permitido).
- Allow-list por tablas consultables según el esquema retornado.
- Guardia opcional por API key:
    Si configuras `API_KEY` en settings (vía config.py/.env),
    entonces valida el header `x-api-key`.
    Si NO configuras `API_KEY`, no exige nada.

Notas MSSQL:
- DB_DIALECT=mssql → se usa TOP en lugar de LIMIT desde database.py.
- No hay fallback determinístico tipo Postgres (evita errores de sintaxis).

Mejoras (genéricas) añadidas:
- Reintento opcional si la consulta devuelve 0 filas O si la salida está dominada por NULL
  en columnas típicas de agrupación (caso LEFT JOIN + GROUP BY sobre dimensión nullable).
  El reintento pide al LLM reescribir el SQL con reglas "null-safe" sin exigir al usuario saber SQL.
"""

import json
import logging
import time
import unicodedata
from decimal import Decimal
from hashlib import sha1
from typing import Any, Dict, List, Optional, Tuple, Union

from decouple import config as env
from fastapi import APIRouter, Depends, Header, HTTPException, Query, Request
from fastapi.concurrency import run_in_threadpool
from pydantic import BaseModel, Field

from . import database
from . import llm

log = logging.getLogger(__name__)
logging.basicConfig(level=logging.DEBUG if env("DEBUG", default=False, cast=bool) else logging.INFO)

# =========================
#  Router
# =========================
router = APIRouter()

# =========================
#  Configuración (env)
# =========================
DB_DIALECT = (env("DB_DIALECT", default="postgresql") or "").strip().lower()

TARGET_SCHEMAS = [s.strip() for s in (env("TARGET_SCHEMAS", default="public") or "").split(",") if s.strip()]

MAX_ROWS_DEFAULT = env("MAX_ROWS_DEFAULT", default=100, cast=int)
MAX_ROWS_HARD = env("MAX_ROWS_HARD", default=1000, cast=int)

MAX_SCHEMA_TABLES = env("MAX_SCHEMA_TABLES", default=50, cast=int)
MAX_SCHEMA_COLUMNS = env("MAX_SCHEMA_COLUMNS", default=2000, cast=int)

DECIMAL_PLACES = env("DECIMAL_PLACES", default=3, cast=int)

# Cache (para schema)
SCHEMA_CACHE_TTL = env("SQL_CACHE_TTL_SECONDS", default=300, cast=int)
SCHEMA_CACHE_MAX = env("SQL_CACHE_MAX", default=256, cast=int)

# Reintento genérico si el resultado sale vacío (0 filas)
SQL_EMPTY_RESULT_RETRY = env("SQL_EMPTY_RESULT_RETRY", default=True, cast=bool)
SQL_EMPTY_RESULT_RETRY_MAX = env("SQL_EMPTY_RESULT_RETRY_MAX", default=1, cast=int)

# Reintento genérico si el resultado está “dominado por NULL” en dimensiones típicas (GROUP BY con LEFT JOIN)
SQL_NULL_GROUP_RETRY = env("SQL_NULL_GROUP_RETRY", default=True, cast=bool)
SQL_NULL_GROUP_RETRY_MAX = env("SQL_NULL_GROUP_RETRY_MAX", default=1, cast=int)

# =========================
#  Helpers
# =========================

def es_mssql() -> bool:
    return DB_DIALECT.startswith("mssql")


def _normalizar_str(s: str) -> str:
    """Quita acentos y espacios extra, útil para inputs del usuario."""
    s = s or ""
    s = unicodedata.normalize("NFKD", s)
    s = "".join([c for c in s if not unicodedata.combining(c)])
    return s.strip()


def _a_jsonable(rows: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Convierte Decimals a float redondeado para JSON."""
    out: List[Dict[str, Any]] = []
    for r in rows or []:
        nr: Dict[str, Any] = {}
        for k, v in (r or {}).items():
            if isinstance(v, Decimal):
                nr[k] = float(round(v, DECIMAL_PLACES))
            else:
                nr[k] = v
        out.append(nr)
    return out


def _hash_payload(obj: Any) -> str:
    raw = json.dumps(obj, sort_keys=True, ensure_ascii=False).encode("utf-8")
    return sha1(raw).hexdigest()


def _parse_list_param(v: Optional[Union[List[str], str]]) -> Optional[List[str]]:
    """
    Soporta:
      - None
      - ["a","b"]
      - "a,b"
      - "a"
    """
    if v is None:
        return None
    if isinstance(v, list):
        out: List[str] = []
        for item in v:
            if item is None:
                continue
            out.extend([x.strip() for x in str(item).split(",") if x.strip()])
        return out or None
    s = str(v).strip()
    if not s:
        return None
    return [x.strip() for x in s.split(",") if x.strip()] or None


def _usuario_pide_estricto(human_query: str) -> bool:
    """
    Si el usuario exige explícitamente un resultado estricto (solo coincidencias / excluir null / etc.),
    evitamos reescrituras "null-safe" que cambien la semántica.
    """
    q = (human_query or "").lower()
    pistas = [
        "solo coincidencias",
        "solo matching",
        "excluir null",
        "sin null",
        "no null",
        "solo donde exista",
        "solo donde haya",
        "únicamente los que tengan",
        "solo los que tengan",
        "estricto",
        "exactamente",
        "obligatorio",
    ]
    return any(p in q for p in pistas)


def _sql_sugiere_riesgo_de_cero_filas(sql: str) -> bool:
    """
    Heurística simple para decidir si vale la pena reintentar:
    - Tiene JOINs (posibles pérdidas por INNER JOIN)
    - y además agregaciones (GROUP BY/HAVING) o filtros IS NOT NULL que podrían vaciar el set.
    """
    s = (sql or "").lower()
    if " join " in s and (" group by " in s or " having " in s):
        return True
    if " join " in s and " is not null" in s:
        return True
    return False


def _sql_tiene_group_by(sql: str) -> bool:
    return " group by " in (sql or "").lower()


def _resultado_parece_grupo_nulo(rows: List[Dict[str, Any]], sql: str) -> bool:
    """
    Detecta el patrón típico:
    - Consulta con GROUP BY (o agregación)
    - Resultado de 1 (o pocos) registros donde columnas de etiqueta/dimensión salen NULL
    Esto suele ser LEFT JOIN + GROUP BY dimensión nullable, sin COALESCE ni filtro strict.
    """
    if not rows:
        return False
    if not _sql_tiene_group_by(sql):
        return False

    # Casos típicos: 1 fila, o muy pocas filas (ej. solo un grupo NULL)
    if len(rows) > 3:
        return False

    # Si hay alguna clave "string-like" que es None en todas las filas, sugiere grupo NULL.
    # (No nos amarramos a nombres específicos)
    keys = list(rows[0].keys())
    if not keys:
        return False

    sospechosas = 0
    for k in keys:
        # ignorar métricas numéricas obvias (avg_, sum_, count, total, n)
        lk = k.lower()
        if any(tok in lk for tok in ["avg", "sum", "count", "total", "prom", "media", "n", "min", "max"]):
            continue

        all_null = all((r.get(k) is None) for r in rows)
        if all_null:
            sospechosas += 1

    return sospechosas >= 1


def _construir_prompt_retry_nullsafe(
    human_query: str,
    dialecto: str,
    limite_por_defecto: int,
    sql_anterior: str
) -> str:
    """
    Prompt genérico para pedir al LLM una reescritura:
    - Evitar perder filas por joins opcionales.
    - Evitar grupo NULL al agrupar por campos del lado derecho de LEFT JOIN.
    - Mantener intención original.
    """
    return (
        f"{human_query.strip()}\n\n"
        f"IMPORTANTE (reintento): el SQL anterior fue problemático (0 filas o agrupación NULL). "
        f"Reescribe el SQL para {dialecto.upper()} manteniendo la intención, pero aplicando reglas null-safe.\n"
        f"- Si una relación puede ser opcional (join key nullable o match incompleto), prefiere LEFT JOIN en vez de INNER JOIN.\n"
        f"- Si hay agregación (GROUP BY/HAVING) y la dimensión viene del lado derecho de un LEFT JOIN:\n"
        f"  * Si el usuario NO pidió estricto, evita agrupar en NULL: crea una etiqueta no nula con COALESCE "
        f"    (dimensión derecha primero y luego alguna etiqueta descriptiva disponible en tablas base/puente) "
        f"    y agrupa por la MISMA expresión.\n"
        f"  * Si el usuario pidió estricto, filtra con WHERE dimension_derecha IS NOT NULL.\n"
        f"- Asegura límite de filas apropiado (SQL Server: TOP({limite_por_defecto})).\n"
        f"Devuelve SOLO JSON con sql_query.\n\n"
        f"SQL anterior (referencia, NO lo repitas igual):\n{sql_anterior}"
    )

# =========================
#  Cache de /schema
# =========================
_SCHEMA_CACHE: Dict[str, Tuple[float, Any]] = {}


def _cache_get(key: str) -> Optional[Any]:
    rec = _SCHEMA_CACHE.get(key)
    if not rec:
        return None
    ts, val = rec
    if (time.time() - ts) > SCHEMA_CACHE_TTL:
        _SCHEMA_CACHE.pop(key, None)
        return None
    return val


def _cache_set(key: str, val: Any) -> None:
    if len(_SCHEMA_CACHE) >= SCHEMA_CACHE_MAX:
        oldest = min(_SCHEMA_CACHE.items(), key=lambda kv: kv[1][0])[0]
        _SCHEMA_CACHE.pop(oldest, None)
    _SCHEMA_CACHE[key] = (time.time(), val)


# =========================
#  Guardia opcional API Key
# =========================
async def guardia_api_key(
    request: Request,
    x_api_key: Optional[str] = Header(default=None, alias="x-api-key"),
) -> None:
    """
    Verifica API Key si la app tiene `API_KEY` configurada en settings.

    - Si NO hay API_KEY configurada: no hace nada (rutas abiertas).
    - Si hay API_KEY: exige header `x-api-key` igual al valor configurado.
    """
    settings = getattr(request.app.state, "settings", None)
    requerido = (getattr(settings, "API_KEY", "") if settings else "") or ""
    if not requerido:
        return
    if not x_api_key or x_api_key != requerido:
        raise HTTPException(status_code=401, detail="API key inválida")


# =========================
#  Modelos Pydantic
# =========================

class SchemaRequest(BaseModel):
    schemas: Optional[List[str]] = Field(default=None)
    tables: Optional[List[str]] = Field(default=None)


class HumanQueryRequest(BaseModel):
    human_query: str
    execute: bool = True
    schemas: Optional[List[str]] = None
    tables: Optional[List[str]] = None
    limit: Optional[int] = None
    dialect: Optional[str] = None
    schema_refresh: bool = False  # como en tu versión antigua (opcional)


class SQLQueryRequest(BaseModel):
    sql: str
    execute: bool = True
    limit: Optional[int] = None


# =============================================================================
# Endpoints base
# =============================================================================

@router.get("/")
def raiz() -> Dict[str, str]:
    return {"status": "ok", "docs": "/docs"}


@router.get("/health")
def health() -> Dict[str, Any]:
    return {"ok": True, "dialect": DB_DIALECT}


# =============================================================================
# Endpoints LLM (recuperados)
# =============================================================================

@router.get("/llm/ping", dependencies=[Depends(guardia_api_key)])
async def llm_ping() -> Dict[str, Any]:
    """
    Ping al proveedor LLM activo. Útil para validar conectividad y credenciales.
    """
    try:
        txt = await llm.ping()
        return {"status": "ok", "reply": (txt or "")[:200]}
    except Exception as e:
        log.exception("Error en /llm/ping")
        return {"status": "error", "detail": str(e)}


@router.get("/llm/models", dependencies=[Depends(guardia_api_key)])
def llm_modelos() -> Dict[str, Any]:
    """
    Devuelve modelos disponibles del proveedor activo.
    """
    try:
        return llm.listar_modelos()
    except Exception as e:
        log.exception("Error en /llm/models")
        return {"status": "error", "detail": str(e)}


# =============================================================================
# Esquema (cacheado)
# =============================================================================

@router.get("/schema", dependencies=[Depends(guardia_api_key)])
def schema_get(
    schemas: Optional[Union[List[str], str]] = Query(default=None),
    tables: Optional[Union[List[str], str]] = Query(default=None),
) -> Dict[str, Any]:
    sch_list = _parse_list_param(schemas) or TARGET_SCHEMAS
    tbl_list = _parse_list_param(tables) or None

    payload_key = _hash_payload({"schemas": sch_list, "tables": tbl_list})
    cached = _cache_get(payload_key)
    if cached:
        return cached

    data = database.obtener_esquema_json(
        esquemas=sch_list,
        tablas=tbl_list,
        max_tablas=MAX_SCHEMA_TABLES,
        max_columnas=MAX_SCHEMA_COLUMNS,
    )
    _cache_set(payload_key, data)
    return data


@router.post("/schema/refresh", dependencies=[Depends(guardia_api_key)])
def schema_refresh(req: SchemaRequest) -> Dict[str, Any]:
    """
    Refresca caché de esquema:
    - limpia cache interno de database
    - limpia cache local de este módulo
    """
    database.invalidar_cache_esquema()
    _SCHEMA_CACHE.clear()

    sch_list = req.schemas or TARGET_SCHEMAS
    tbl_list = req.tables or None

    data = database.obtener_esquema_json(
        esquemas=sch_list,
        tablas=tbl_list,
        max_tablas=MAX_SCHEMA_TABLES,
        max_columnas=MAX_SCHEMA_COLUMNS,
    )
    return {"ok": True, "schema": data}


# =============================================================================
# NL → SQL (principal)
# =============================================================================

@router.post("/human_query", dependencies=[Depends(guardia_api_key)])
async def human_query(payload: HumanQueryRequest) -> Dict[str, Any]:
    """
    Flujo principal NL→SQL.

    - schema_refresh=true fuerza refrescar esquema antes de generar SQL.
    - execute=false devuelve solo el SQL (dry-run).

    Mejoras:
    - Si execute=true y devuelve 0 filas, puede reintentar 1 vez (configurable) con reescritura null-safe.
    - Si execute=true y devuelve 1-3 filas con dimensión(es) NULL (típico GROUP BY con LEFT JOIN),
      puede reintentar 1 vez (configurable) con reglas null-safe.
    """
    human = _normalizar_str(payload.human_query)
    if not human:
        raise HTTPException(status_code=400, detail="human_query vacío.")

    if payload.schema_refresh:
        database.invalidar_cache_esquema()
        _SCHEMA_CACHE.clear()

    limite_por_defecto = int(payload.limit or MAX_ROWS_DEFAULT)
    limite_maximo = int(MAX_ROWS_HARD)

    esquemas = payload.schemas or TARGET_SCHEMAS
    tablas = payload.tables or None

    esquema_json = database.obtener_esquema_json(
        esquemas=esquemas,
        tablas=tablas,
        max_tablas=MAX_SCHEMA_TABLES,
        max_columnas=MAX_SCHEMA_COLUMNS,
    )
    allowed_fqn = [f"{t['schema']}.{t['table']}" for t in esquema_json.get("tables", [])]

    dialecto = payload.dialect or ("mssql" if es_mssql() else "postgresql")

    async def _generar_sql(consulta_humana: str) -> str:
        """Llama al LLM y extrae sql_query."""
        sql_json = await llm.consulta_humana_a_sql(
            consulta_humana=consulta_humana,
            esquema_json=esquema_json,
            dialecto=dialecto,
            limite_por_defecto=limite_por_defecto,
            modelo=None,
        )
        try:
            obj = json.loads(sql_json)
        except Exception:
            obj = None
        if not isinstance(obj, dict) or "sql_query" not in obj:
            raise HTTPException(status_code=500, detail="El LLM no devolvió JSON válido con 'sql_query'.")
        sql = str(obj.get("sql_query") or "").strip()
        if not sql:
            raise HTTPException(status_code=500, detail="El LLM devolvió 'sql_query' vacío.")
        return sql

    def _blindar_sql(sql: str) -> str:
        """
        Aplica guardrails (limpieza + seguridad + allow-list + heurística nullable joins).
        Nota: preferir_left_join_por_nullable NO fuerza COALESCE; solo evita perder filas por INNER JOIN.
        El caso GROUP BY con NULL se corrige en el prompt de reintento y/o en el proveedor.
        """
        sql2 = database.limpiar_sql(sql)
        sql2 = database.sanear_explain(sql2)
        sql2 = database.calificar_tablas(sql2, allowed_fqn)
        sql2 = database.preferir_left_join_por_nullable(sql2, esquema_json)

        if not database.es_select_seguro(sql2):
            raise HTTPException(status_code=400, detail="SQL insegura (no es SELECT/CTE/EXPLAIN permitido).")

        if not database.restringir_a_tablas_permitidas(sql2, allowed_fqn):
            raise HTTPException(status_code=400, detail="La consulta referencia tablas no permitidas según el esquema actual.")

        return sql2

    # 1) Generar SQL inicial
    sql_query = _blindar_sql(await _generar_sql(human))

    # Dry run
    if not payload.execute:
        return {
            "ok": True,
            "human_query": human,
            "dialect": dialecto,
            "sql": sql_query,
            "executed": False,
        }

    # 2) Ejecutar en threadpool
    try:
        rows = await run_in_threadpool(
            database.consultar,
            sql_query,
            allowed_fqn,
            limite_por_defecto,
            limite_maximo,
        )
        rows = _a_jsonable(rows)

        # 3A) Reintento genérico si 0 filas (y parece riesgo por JOIN/GBY)
        if (
            SQL_EMPTY_RESULT_RETRY
            and len(rows) == 0
            and SQL_EMPTY_RESULT_RETRY_MAX > 0
            and (not _usuario_pide_estricto(human))
            and _sql_sugiere_riesgo_de_cero_filas(sql_query)
        ):
            for _ in range(int(SQL_EMPTY_RESULT_RETRY_MAX)):
                try:
                    human_retry = _construir_prompt_retry_nullsafe(
                        human_query=human,
                        dialecto=dialecto,
                        limite_por_defecto=limite_por_defecto,
                        sql_anterior=sql_query,
                    )
                    sql_retry = _blindar_sql(await _generar_sql(human_retry))

                    rows2 = await run_in_threadpool(
                        database.consultar,
                        sql_retry,
                        allowed_fqn,
                        limite_por_defecto,
                        limite_maximo,
                    )
                    rows2 = _a_jsonable(rows2)

                    if rows2:
                        return {
                            "ok": True,
                            "human_query": human,
                            "dialect": dialecto,
                            "sql": sql_retry,
                            "executed": True,
                            "rows": rows2,
                            "row_count": len(rows2),
                            "warning": (
                                "La consulta original devolvió 0 filas; "
                                "se reescribió automáticamente con reglas null-safe (joins/agrupación) para recuperar resultados."
                            ),
                        }

                    sql_query = sql_retry
                    rows = rows2

                except Exception:
                    log.exception("Reintento null-safe (0 filas) falló.")
                    break

        # 3B) Reintento si el resultado parece “grupo NULL” (caso típico LEFT JOIN + GROUP BY)
        if (
            SQL_NULL_GROUP_RETRY
            and SQL_NULL_GROUP_RETRY_MAX > 0
            and (not _usuario_pide_estricto(human))
            and _resultado_parece_grupo_nulo(rows, sql_query)
        ):
            for _ in range(int(SQL_NULL_GROUP_RETRY_MAX)):
                try:
                    human_retry = _construir_prompt_retry_nullsafe(
                        human_query=human,
                        dialecto=dialecto,
                        limite_por_defecto=limite_por_defecto,
                        sql_anterior=sql_query,
                    )
                    sql_retry = _blindar_sql(await _generar_sql(human_retry))

                    rows2 = await run_in_threadpool(
                        database.consultar,
                        sql_retry,
                        allowed_fqn,
                        limite_por_defecto,
                        limite_maximo,
                    )
                    rows2 = _a_jsonable(rows2)

                    # preferimos una salida con etiquetas no nulas (o al menos que no sea solo NULL)
                    if rows2 and (not _resultado_parece_grupo_nulo(rows2, sql_retry)):
                        return {
                            "ok": True,
                            "human_query": human,
                            "dialect": dialecto,
                            "sql": sql_retry,
                            "executed": True,
                            "rows": rows2,
                            "row_count": len(rows2),
                            "warning": (
                                "La consulta original generó grupos NULL (JOIN opcional + agregación). "
                                "Se reescribió automáticamente para agrupar con etiqueta null-safe."
                            ),
                        }

                    sql_query = sql_retry
                    rows = rows2

                except Exception:
                    log.exception("Reintento null-safe (grupo NULL) falló.")
                    break

        return {
            "ok": True,
            "human_query": human,
            "dialect": dialecto,
            "sql": sql_query,
            "executed": True,
            "rows": rows,
            "row_count": len(rows),
        }

    except Exception as e:
        log.exception("Error ejecutando SQL en /human_query")
        raise HTTPException(status_code=500, detail=f"Error ejecutando SQL: {str(e)}")


# =============================================================================
# SQL directo
# =============================================================================

@router.post("/sql", dependencies=[Depends(guardia_api_key)])
async def sql_query(payload: SQLQueryRequest) -> Dict[str, Any]:
    """
    Ejecuta SQL directo con guardrails (solo lectura + allow-list).
    """
    sql = database.limpiar_sql(payload.sql)
    if not sql:
        raise HTTPException(status_code=400, detail="sql vacío.")

    limite_por_defecto = int(payload.limit or MAX_ROWS_DEFAULT)
    limite_maximo = int(MAX_ROWS_HARD)

    esquema_json = database.obtener_esquema_json(
        esquemas=TARGET_SCHEMAS,
        tablas=None,
        max_tablas=MAX_SCHEMA_TABLES,
        max_columnas=MAX_SCHEMA_COLUMNS,
    )
    allowed_fqn = [f"{t['schema']}.{t['table']}" for t in esquema_json.get("tables", [])]

    sql = database.sanear_explain(sql)
    sql = database.calificar_tablas(sql, allowed_fqn)

    if not database.es_select_seguro(sql):
        raise HTTPException(status_code=400, detail="SQL insegura (no es SELECT/CTE/EXPLAIN permitido).")

    if not database.restringir_a_tablas_permitidas(sql, allowed_fqn):
        raise HTTPException(status_code=400, detail="La consulta referencia tablas no permitidas según el esquema actual.")

    if not payload.execute:
        return {"ok": True, "sql": sql, "executed": False}

    try:
        rows = await run_in_threadpool(
            database.consultar,
            sql,
            allowed_fqn,
            limite_por_defecto,
            limite_maximo,
        )
        rows = _a_jsonable(rows)
        return {"ok": True, "sql": sql, "executed": True, "rows": rows, "row_count": len(rows)}
    except Exception as e:
        log.exception("Error ejecutando SQL en /sql")
        raise HTTPException(status_code=500, detail=f"Error ejecutando SQL: {str(e)}")