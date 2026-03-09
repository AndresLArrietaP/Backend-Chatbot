# src/main.py
# -*- coding: utf-8 -*-
"""
Módulo: main
------------
Router principal de la API (FastAPI) para NL→SQL sobre Azure SQL / PostgreSQL.

Incluye:
- Endpoints base de salud y esquema.
- Endpoints NL→SQL y SQL directo.
- Generación opcional de respuesta analítica en lenguaje natural.
- Contexto conversacional en memoria para continuidad entre turnos.
"""

from __future__ import annotations

import json
import logging
import time
import unicodedata
import re
from decimal import Decimal
from hashlib import sha1
from typing import Any, Dict, List, Optional, Tuple, Union

from decouple import config as env
from fastapi import APIRouter, Depends, Header, HTTPException, Query, Request
from fastapi.concurrency import run_in_threadpool
from pydantic import BaseModel, Field

from . import database
from . import llm
from .analitica import generar_analisis_resultado, renderizar_resumen_analitico
from .contexto_chat import GestorContextoConversacional

log = logging.getLogger(__name__)
logging.basicConfig(level=logging.DEBUG if env("DEBUG", default=False, cast=bool) else logging.INFO)

router = APIRouter()

DB_DIALECT = (env("DB_DIALECT", default="postgresql") or "").strip().lower()
TARGET_SCHEMAS = [s.strip() for s in (env("TARGET_SCHEMAS", default="public") or "").split(",") if s.strip()]

MAX_ROWS_DEFAULT = env("MAX_ROWS_DEFAULT", default=100, cast=int)
MAX_ROWS_HARD = env("MAX_ROWS_HARD", default=1000, cast=int)

MAX_SCHEMA_TABLES = env("MAX_SCHEMA_TABLES", default=50, cast=int)
MAX_SCHEMA_COLUMNS = env("MAX_SCHEMA_COLUMNS", default=2000, cast=int)

DECIMAL_PLACES = env("DECIMAL_PLACES", default=3, cast=int)

SCHEMA_CACHE_TTL = env("SQL_CACHE_TTL_SECONDS", default=300, cast=int)
SCHEMA_CACHE_MAX = env("SQL_CACHE_MAX", default=256, cast=int)

SQL_EMPTY_RESULT_RETRY = env("SQL_EMPTY_RESULT_RETRY", default=True, cast=bool)
SQL_EMPTY_RESULT_RETRY_MAX = env("SQL_EMPTY_RESULT_RETRY_MAX", default=1, cast=int)

SQL_NULL_GROUP_RETRY = env("SQL_NULL_GROUP_RETRY", default=True, cast=bool)
SQL_NULL_GROUP_RETRY_MAX = env("SQL_NULL_GROUP_RETRY_MAX", default=1, cast=int)

SQL_NULL_PROJECTION_RETRY = env("SQL_NULL_PROJECTION_RETRY", default=True, cast=bool)
SQL_NULL_PROJECTION_RETRY_MAX = env("SQL_NULL_PROJECTION_RETRY_MAX", default=1, cast=int)

SQL_LATEST_WINDOW_RETRY = env("SQL_LATEST_WINDOW_RETRY", default=True, cast=bool)
SQL_LATEST_WINDOW_RETRY_MAX = env("SQL_LATEST_WINDOW_RETRY_MAX", default=1, cast=int)

ESQUEMA_RELEVANTE_ACTIVO = env("ESQUEMA_RELEVANTE_ACTIVO", default=True, cast=bool)
ESQUEMA_RELEVANTE_MAX_TABLAS = env("ESQUEMA_RELEVANTE_MAX_TABLAS", default=18, cast=int)

GENERAR_RESPUESTA_TEXTO = env("GENERAR_RESPUESTA_TEXTO", default=True, cast=bool)
INCLUIR_ANALISIS_RESULTADO = env("INCLUIR_ANALISIS_RESULTADO", default=True, cast=bool)
INCLUIR_SUGERENCIAS_GRAFICO = env("INCLUIR_SUGERENCIAS_GRAFICO", default=True, cast=bool)

CONTEXTO_CHAT_TTL_MINUTOS = env("CONTEXTO_CHAT_TTL_MINUTOS", default=45, cast=int)
CONTEXTO_CHAT_MAX_TURNOS = env("CONTEXTO_CHAT_MAX_TURNOS", default=8, cast=int)
CONTEXTO_CHAT_MAX_CARACTERES = env("CONTEXTO_CHAT_MAX_CARACTERES", default=5000, cast=int)
CONTEXTO_CHAT_PERSISTIR_ARCHIVO = env("CONTEXTO_CHAT_PERSISTIR_ARCHIVO", default=True, cast=bool)
CONTEXTO_CHAT_ARCHIVO = env("CONTEXTO_CHAT_ARCHIVO", default=".cache/contexto_chat.json")

RESPUESTA_DEBUG = env("RESPUESTA_DEBUG", default=False, cast=bool)

_GESTOR_CONTEXTO = GestorContextoConversacional(
    ttl_minutos=CONTEXTO_CHAT_TTL_MINUTOS,
    max_turnos=CONTEXTO_CHAT_MAX_TURNOS,
    max_caracteres=CONTEXTO_CHAT_MAX_CARACTERES,
    persistir_archivo=CONTEXTO_CHAT_PERSISTIR_ARCHIVO,
    ruta_archivo=CONTEXTO_CHAT_ARCHIVO,
)

_SCHEMA_CACHE: Dict[str, Tuple[float, Any]] = {}

_TABLAS_PRIORITARIAS_DOMINIO = {
    "dbo.oilanalysis",
    "oil.laboratorydata",
    "dbo.equipment",
    "dbo.equipmentcomponent",
    "dbo.component",
    "dbo.project",
    "eqpcare.lc",
    "eqpcare.lc2",
    "eqpcare.lb",
    "eqpcare.hscc",
    "eqpcare.hshistorico",
    "eqpcare.trend",
    "dbo.trendbi",
    "mine.miningequipment",
    "mine.miningproject",
    "mine.equipmentfleet",
}


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
    schema_refresh: bool = False
    conversation_context: Optional[str] = None
    session_id: Optional[str] = None
    reset_contexto: bool = False
    incluir_respuesta_texto: Optional[bool] = None
    modo_debug: Optional[bool] = None


class SQLQueryRequest(BaseModel):
    sql: str
    execute: bool = True
    limit: Optional[int] = None


def es_mssql() -> bool:
    return DB_DIALECT.startswith("mssql")


def _normalizar_str(s: str) -> str:
    s = s or ""
    s = unicodedata.normalize("NFKD", s)
    s = "".join([c for c in s if not unicodedata.combining(c)])
    return s.strip()


def _a_jsonable(rows: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
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
    Heurística para decidir si conviene reintentar cuando una consulta devuelve 0 filas.
    Detecta joins + filtros descriptivos que suelen sobrerrestringir.
    """
    s = (sql or "").lower()

    if " join " in s and (" group by " in s or " having " in s):
        return True

    if " join " in s and " is not null" in s:
        return True

    if " join " in s and (" like " in s or "componentname" in s or "compartimiento" in s or "description" in s):
        return True

    return False


def _sql_tiene_group_by(sql: str) -> bool:
    return " group by " in (sql or "").lower()


def _resultado_parece_grupo_nulo(rows: List[Dict[str, Any]], sql: str) -> bool:
    if not rows:
        return False
    if not _sql_tiene_group_by(sql):
        return False
    if len(rows) > 3:
        return False

    keys = list(rows[0].keys())
    sospechosas = 0
    for k in keys:
        lk = k.lower()
        if any(tok in lk for tok in ["avg", "sum", "count", "total", "prom", "media", "n", "min", "max"]):
            continue
        all_null = all((r.get(k) is None) for r in rows)
        if all_null:
            sospechosas += 1
    return sospechosas >= 1


def _sql_parece_ultimo_por_entidad(sql: str) -> bool:
    s = (sql or "").lower()
    return (
        "row_number(" in s
        or " over (" in s
        or "over(partition by" in s
        or " partition by " in s
    )


def _resultado_parece_proyeccion_nula(rows: List[Dict[str, Any]], sql: str) -> bool:
    if not rows:
        return False

    s = (sql or "").lower()
    if " left join " not in f" {s} ":
        return False
    if not _sql_parece_ultimo_por_entidad(sql):
        return False

    muestra = rows[: min(len(rows), 12)]
    if not muestra:
        return False

    sospechosas = 0
    for k in muestra[0].keys():
        lk = k.lower()
        if any(tok in lk for tok in [
            "fecha", "date", "hora", "time", "rn", "row_number",
            "ppm", "tbn", "tan", "vis", "v100", "metric", "value",
            "horometro", "smr", "count", "sum", "avg", "total", "min", "max"
        ]):
            continue
        nulls = sum(1 for r in muestra if r.get(k) is None)
        if nulls >= max(1, int(len(muestra) * 0.5)):
            sospechosas += 1
    return sospechosas >= 1


def _sql_parece_latest_window(sql: str) -> bool:
    s = (sql or "").lower()
    return (
        "row_number(" in s
        or " over (" in s
        or " partition by " in s
    )


def _sql_tiene_filtros_is_not_null_sospechosos(sql: str) -> bool:
    s = (sql or "")
    return bool(re.search(
        r"\[(?!.*(?:Id|ID|Code|CODE|Fecha|Date|Time))[^\]]+\]\s+IS\s+NOT\s+NULL",
        s,
        flags=re.IGNORECASE,
    ))


def _resultado_parece_latest_sobre_restringido(rows: List[Dict[str, Any]], sql: str, limit: int) -> bool:
    if not _sql_parece_latest_window(sql):
        return False
    if not _sql_tiene_filtros_is_not_null_sospechosos(sql):
        return False
    umbral = max(3, min(10, int(limit * 0.1)))
    return len(rows) <= umbral


def _construir_prompt_retry_latest_window(
    human_query: str,
    dialecto: str,
    limite_por_defecto: int,
    sql_anterior: str,
) -> str:
    return (
        f"{human_query.strip()}\n\n"
        f"IMPORTANTE (reintento): el SQL anterior de tipo latest/window quedó sobre-restringido. "
        f"Reescribe el SQL para {dialecto.upper()} manteniendo la intención.\n"
        f"- Conserva la lógica con CTE + ROW_NUMBER/PARTITION BY si aplica.\n"
        f"- No pongas TOP/LIMIT dentro del CTE o subquery que calcula ROW_NUMBER(); "
        f"si hace falta limitar, aplícalo solo en el SELECT final después de WHERE rn = 1.\n"
        f"- No filtres por defecto métricas de salida con IS NOT NULL antes del ROW_NUMBER, "
        f"salvo que el usuario haya pedido excluir nulos explícitamente.\n"
        f"- Para columnas descriptivas provenientes de LEFT JOIN opcionales, usa COALESCE con columnas reales de fallback.\n"
        f"- No uses literales como 'N/A', 'Unknown' o equivalentes.\n"
        f"- Mantén el límite de filas apropiado para SQL Server: TOP({limite_por_defecto}).\n"
        f"Devuelve SOLO JSON con sql_query.\n\n"
        f"SQL anterior (referencia, NO lo repitas igual):\n{sql_anterior}"
    )


def _construir_prompt_retry_proyeccion_nullsafe(
    human_query: str,
    dialecto: str,
    limite_por_defecto: int,
    sql_anterior: str,
) -> str:
    return (
        f"{human_query.strip()}\n\n"
        f"IMPORTANTE (reintento): el SQL anterior devolvió filas con NULL en columnas descriptivas solicitadas. "
        f"Reescribe el SQL para {dialecto.upper()} manteniendo la intención original.\n"
        f"- Si usas LEFT JOIN a tablas opcionales y el usuario pidió columnas descriptivas del SELECT, "
        f"usa COALESCE(campo_derecho, fallback1, fallback2) para evitar NULL en la proyección.\n"
        f"- Si la consulta busca el último o más reciente registro por entidad usando CTE / ROW_NUMBER / OVER(PARTITION BY), "
        f"mantén esa lógica.\n"
        f"- NO excluyas por defecto filas por métricas pedidas antes de calcular ROW_NUMBER(); "
        f"solo agrega IS NOT NULL sobre esa métrica si el usuario lo pidió explícitamente.\n"
        f"- Conserva el límite de filas apropiado para SQL Server: TOP({limite_por_defecto}).\n"
        f"Devuelve SOLO JSON con sql_query.\n\n"
        f"SQL anterior (referencia, NO lo repitas igual):\n{sql_anterior}"
    )


def _construir_prompt_retry_nullsafe(
    human_query: str,
    dialecto: str,
    limite_por_defecto: int,
    sql_anterior: str,
) -> str:
    return (
        f"{human_query.strip()}\n\n"
        f"IMPORTANTE (reintento): el SQL anterior fue problemático (0 filas o agrupación NULL). "
        f"Reescribe el SQL para {dialecto.upper()} manteniendo la intención, pero aplicando reglas null-safe.\n"
        f"- Si una relación puede ser opcional, prefiere LEFT JOIN en vez de INNER JOIN.\n"
        f"- Si hay agregación y la dimensión viene del lado derecho de un LEFT JOIN:\n"
        f"  * Si el usuario NO pidió estricto, evita agrupar en NULL: crea una etiqueta no nula con COALESCE.\n"
        f"  * Si el usuario pidió estricto, filtra con WHERE dimension_derecha IS NOT NULL.\n"
        f"- Asegura límite de filas apropiado (SQL Server: TOP({limite_por_defecto})).\n"
        f"Devuelve SOLO JSON con sql_query.\n\n"
        f"SQL anterior (referencia, NO lo repitas igual):\n{sql_anterior}"
    )


def _construir_prompt_retry_blindado(
    human_query: str,
    dialecto: str,
    sql_anterior: str,
    detalle_error: str,
    allowed_fqn: List[str],
) -> str:
    return (
        f"{human_query.strip()}\n\n"
        f"IMPORTANTE (reparación automática): el SQL anterior fue rechazado por la capa de validación.\n"
        f"Reescribe el SQL para {dialecto.upper()} cumpliendo estrictamente estas reglas:\n"
        f"- Usa EXCLUSIVAMENTE tablas de la allow-list.\n"
        f"- No uses ninguna otra tabla fuera de esa lista.\n"
        f"- La consulta debe quedar COMPLETA y ejecutable.\n"
        f"- Mantén la intención analítica original.\n"
        f"- Devuelve SOLO JSON con sql_query.\n\n"
        f"<allowed_fqn>\n{json.dumps(sorted(allowed_fqn), ensure_ascii=False)}\n</allowed_fqn>\n\n"
        f"Detalle del rechazo:\n{detalle_error}\n\n"
        f"SQL anterior (referencia, NO lo repitas igual):\n{sql_anterior}"
    )


def _es_error_sql_reintentable(detalle: str) -> bool:
    t = (detalle or "").lower()
    pistas = [
        "incorrect syntax near",
        "unclosed quotation mark",
        "object or column name is missing or empty",
        "could not be bound",
        "invalid column name",
        "statement(s) could not be prepared",
        "syntax error",
    ]
    return any(p in t for p in pistas)


def _construir_prompt_retry_sql_error(
    human_query: str,
    dialecto: str,
    sql_anterior: str,
    detalle_error: str,
    allowed_fqn: List[str],
) -> str:
    return (
        f"{human_query.strip()}\n\n"
        f"IMPORTANTE (reparación automática): el SQL anterior falló al ejecutar en {dialecto.upper()}.\n"
        f"Reescribe el SQL completo y ejecutable.\n"
        f"- Usa SOLO tablas de esta allow-list.\n"
        f"- No dejes SQL truncada o parcial.\n"
        f"- No dejes aliases vacíos.\n"
        f"- Mantén la intención original del usuario.\n"
        f"- Devuelve SOLO JSON con sql_query.\n\n"
        f"<allowed_fqn>\n{json.dumps(sorted(allowed_fqn), ensure_ascii=False)}\n</allowed_fqn>\n\n"
        f"Detalle del error SQL Server:\n{detalle_error}\n\n"
        f"SQL anterior (referencia, NO la repitas igual):\n{sql_anterior}"
    )


def _construir_prompt_retry_cero_filas_semantico(
    human_query: str,
    dialecto: str,
    limite_por_defecto: int,
    sql_anterior: str,
) -> str:
    return (
        f"{human_query.strip()}\n\n"
        f"IMPORTANTE (reintento): el SQL anterior devolvió 0 filas. "
        f"Reescribe el SQL para {dialecto.upper()} manteniendo la intención original.\n"
        f"- Si el usuario menciona motor, transmisión, hidráulico, diferencial, mando final, reductor o convertidor "
        f"en contexto de análisis de aceite, trátalo preferentemente como valor descriptivo de Compartimiento "
        f"en tablas de análisis de aceite, no como dbo.Component.ComponentName.\n"
        f"- Prefiere filtros tipo LIKE sobre Compartimiento cuando aplique.\n"
        f"- Mantén el límite apropiado para SQL Server: TOP({limite_por_defecto}).\n"
        f"- Devuelve SOLO JSON con sql_query.\n\n"
        f"SQL anterior (referencia, NO lo repitas igual):\n{sql_anterior}"
    )


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


def _tokenizar_consulta(texto: str) -> List[str]:
    t = _normalizar_str(texto).lower()
    tokens = re.findall(r"[a-z0-9_áéíóúñ]+", t)
    return [tk for tk in tokens if len(tk) >= 3]


def _seleccionar_esquema_para_llm(esquema_json: Dict[str, Any], human_query: str) -> Dict[str, Any]:
    """
    Reduce ruido para el LLM priorizando tablas del dominio aceite/equipo.
    No cambia la allow-list final de ejecución: solo la visión del LLM.
    """
    tablas = esquema_json.get("tables", []) or []
    if not ESQUEMA_RELEVANTE_ACTIVO or len(tablas) <= ESQUEMA_RELEVANTE_MAX_TABLAS:
        return esquema_json

    tokens = set(_tokenizar_consulta(human_query))
    tablas_puntuadas: List[Tuple[int, Dict[str, Any]]] = []

    for t in tablas:
        schema = (t.get("schema") or "").strip()
        table = (t.get("table") or "").strip()
        fq = f"{schema}.{table}".lower()
        score = 0

        if fq in _TABLAS_PRIORITARIAS_DOMINIO:
            score += 50

        nombre_tabla = f"{schema} {table}".lower()
        columnas = t.get("columns", []) or []
        columnas_texto = " ".join((c.get("name") or "") for c in columnas).lower()

        for tk in tokens:
            if tk in nombre_tabla:
                score += 12
            if tk in columnas_texto:
                score += 4

        if any(k in tokens for k in ["aceite", "oil", "ppm", "viscosidad", "tbn", "tan", "horometro", "muestra", "compartimiento", "condicion", "sos"]):
            if fq in {
                "dbo.oilanalysis", "oil.laboratorydata", "eqpcare.lc", "eqpcare.lc2",
                "eqpcare.lb", "eqpcare.hscc", "eqpcare.hshistorico", "eqpcare.trend",
                "dbo.trendbi"
            }:
                score += 20

        if any(k in tokens for k in ["equipo", "equipment", "modelo", "proyecto", "cliente", "componente"]):
            if fq in {
                "dbo.equipment", "dbo.equipmentcomponent", "dbo.component", "dbo.project",
                "mine.miningequipment", "mine.miningproject", "mine.equipmentfleet"
            }:
                score += 20

        if any(k in tokens for k in ["falla", "fault", "averia", "avería"]):
            if fq == "eqpcare.fault":
                score += 25

        if any(k in tokens for k in ["payload", "carga", "carguio", "despacho"]):
            if fq in {"dbo.payload", "dbo.payloadm"}:
                score += 25

        if score > 0:
            tablas_puntuadas.append((score, t))

    if not tablas_puntuadas:
        return esquema_json

    tablas_puntuadas.sort(
        key=lambda x: (-x[0], f"{x[1].get('schema')}.{x[1].get('table')}".lower())
    )

    seleccionadas = [t for _, t in tablas_puntuadas[:ESQUEMA_RELEVANTE_MAX_TABLAS]]
    fq_seleccion = {f"{t.get('schema')}.{t.get('table')}".lower() for t in seleccionadas}

    puentes = ["dbo.equipment", "dbo.equipmentcomponent", "dbo.component", "dbo.project"]
    if any(x in fq_seleccion for x in ["dbo.oilanalysis", "oil.laboratorydata"]):
        for t in tablas:
            fq = f"{t.get('schema')}.{t.get('table')}".lower()
            if fq in puentes and fq not in fq_seleccion and len(seleccionadas) < max(ESQUEMA_RELEVANTE_MAX_TABLAS, 8):
                seleccionadas.append(t)
                fq_seleccion.add(fq)

    return {"tables": seleccionadas}


def _combinar_contextos(contexto_externo: str, contexto_memoria: str) -> str:
    partes = []
    if contexto_memoria.strip():
        partes.append("CONTEXTO EN MEMORIA DE LA SESIÓN:\n" + contexto_memoria.strip())
    if contexto_externo.strip():
        partes.append("CONTEXTO ENVIADO POR EL FRONTEND:\n" + contexto_externo.strip())
    return "\n\n".join(partes).strip()


async def guardia_api_key(
    request: Request,
    x_api_key: Optional[str] = Header(default=None, alias="x-api-key"),
) -> None:
    settings = getattr(request.app.state, "settings", None)
    requerido = (getattr(settings, "API_KEY", "") if settings else "") or ""
    if not requerido:
        return
    if not x_api_key or x_api_key != requerido:
        raise HTTPException(status_code=401, detail="API key inválida")


@router.get("/")
def raiz() -> Dict[str, str]:
    return {"status": "ok", "docs": "/docs"}


@router.get("/health")
def health() -> Dict[str, Any]:
    return {"ok": True, "dialect": DB_DIALECT}


@router.get("/llm/ping", dependencies=[Depends(guardia_api_key)])
async def llm_ping() -> Dict[str, Any]:
    try:
        txt = await llm.ping()
        return {"status": "ok", "reply": (txt or "")[:200]}
    except Exception as e:
        log.exception("Error en /llm/ping")
        return {"status": "error", "detail": str(e)}


@router.get("/llm/models", dependencies=[Depends(guardia_api_key)])
def llm_modelos() -> Dict[str, Any]:
    try:
        return llm.listar_modelos()
    except Exception as e:
        log.exception("Error en /llm/models")
        return {"status": "error", "detail": str(e)}


@router.get("/chat/context/{session_id}", dependencies=[Depends(guardia_api_key)])
def ver_contexto(session_id: str) -> Dict[str, Any]:
    contexto = _GESTOR_CONTEXTO.obtener_contexto(session_id)
    estado = _GESTOR_CONTEXTO.obtener_estado(session_id)
    return {"ok": True, "estado": estado, "contexto": contexto}


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


@router.post("/human_query", dependencies=[Depends(guardia_api_key)])
async def human_query(payload: HumanQueryRequest) -> Dict[str, Any]:
    human = _normalizar_str(payload.human_query)
    if not human:
        raise HTTPException(status_code=400, detail="human_query vacío.")

    session_id = (payload.session_id or "").strip()
    modo_debug = RESPUESTA_DEBUG if payload.modo_debug is None else bool(payload.modo_debug)

    if payload.reset_contexto and session_id:
        _GESTOR_CONTEXTO.olvidar(session_id)

    estado_contexto_antes = _GESTOR_CONTEXTO.obtener_estado(session_id) if session_id else None
    contexto_memoria = _GESTOR_CONTEXTO.obtener_contexto(session_id) if session_id else ""
    contexto_externo = _normalizar_str(payload.conversation_context or "")
    contexto_conversacional = _combinar_contextos(contexto_externo, contexto_memoria)

    usa_contexto_memoria = bool(contexto_memoria.strip())
    usa_contexto_externo = bool(contexto_externo.strip())
    contexto_aplicado = usa_contexto_memoria or usa_contexto_externo

    if payload.schema_refresh:
        database.invalidar_cache_esquema()
        _SCHEMA_CACHE.clear()

    limite_por_defecto = int(payload.limit or MAX_ROWS_DEFAULT)
    limite_maximo = int(MAX_ROWS_HARD)
    esquemas = payload.schemas or TARGET_SCHEMAS
    tablas = payload.tables or None

    esquema_total = database.obtener_esquema_json(
        esquemas=esquemas,
        tablas=tablas,
        max_tablas=MAX_SCHEMA_TABLES,
        max_columnas=MAX_SCHEMA_COLUMNS,
    )
    esquema_llm = _seleccionar_esquema_para_llm(esquema_total, human)

    allowed_fqn = [f"{t['schema']}.{t['table']}" for t in esquema_total.get("tables", [])]
    tablas_prompt_llm = [f"{t['schema']}.{t['table']}" for t in esquema_llm.get("tables", [])]
    dialecto = payload.dialect or ("mssql" if es_mssql() else "postgresql")

    async def _generar_sql(consulta_humana: str) -> str:
        sql_json = await llm.consulta_humana_a_sql(
            consulta_humana=consulta_humana,
            esquema_json=esquema_llm,
            dialecto=dialecto,
            limite_por_defecto=limite_por_defecto,
            modelo=None,
            conversation_context=contexto_conversacional,
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
        sql2 = database.limpiar_sql(sql)
        sql2 = database.sanear_explain(sql2)
        sql2 = database.calificar_tablas(sql2, allowed_fqn)
        sql2 = database.preferir_left_join_por_nullable(sql2, esquema_total)

        if (dialecto or "").lower() in ("mssql", "sqlserver"):
            sql2 = database.hacer_groupby_nullsafe_mssql(
                sql2,
                esquema_json=esquema_total,
                consulta_humana=human,
            )

        if not database.es_select_seguro(sql2):
            raise HTTPException(status_code=400, detail="SQL insegura (no es SELECT/CTE/EXPLAIN permitido).")

        if not database.restringir_a_tablas_permitidas(sql2, allowed_fqn):
            raise HTTPException(status_code=400, detail="La consulta referencia tablas no permitidas según el esquema actual.")

        return sql2

    async def _generar_y_blindar(consulta_humana: str) -> str:
        prompt_actual = consulta_humana
        ultimo_sql = ""
        ultimo_detalle = ""

        for intento in range(3):
            ultimo_sql = await _generar_sql(prompt_actual)
            try:
                return _blindar_sql(ultimo_sql)
            except HTTPException as e:
                if e.status_code != 400:
                    raise

                ultimo_detalle = str(e.detail)
                log.warning(
                    "SQL rechazada en blindado intento=%s detalle=%s sql=%s",
                    intento + 1,
                    ultimo_detalle,
                    ultimo_sql[:1500],
                )
                prompt_actual = _construir_prompt_retry_blindado(
                    human_query=human,
                    dialecto=dialecto,
                    sql_anterior=ultimo_sql,
                    detalle_error=ultimo_detalle,
                    allowed_fqn=allowed_fqn,
                )

        raise HTTPException(status_code=400, detail=f"SQL rechazada tras reintento automático: {ultimo_detalle}")

    async def _ejecutar_sql_actual(sql_actual: str) -> List[Dict[str, Any]]:
        rows_local = await run_in_threadpool(
            database.consultar,
            sql_actual,
            allowed_fqn,
            limite_por_defecto,
            limite_maximo,
        )
        return _a_jsonable(rows_local)

    sql_query = await _generar_y_blindar(human)

    if not payload.execute:
        respuesta_dry: Dict[str, Any] = {
            "ok": True,
            "human_query": human,
            "dialect": dialecto,
            "sql": sql_query,
            "executed": False,
            "contexto_aplicado": contexto_aplicado,
            "contexto_sesion": _GESTOR_CONTEXTO.obtener_estado(session_id) if session_id else None,
        }

        if modo_debug:
            respuesta_dry["debug"] = {
                "tablas_prompt_llm": tablas_prompt_llm,
                "contexto": {
                    "session_id": session_id,
                    "usa_contexto_memoria": usa_contexto_memoria,
                    "usa_contexto_externo": usa_contexto_externo,
                    "preview_memoria": contexto_memoria[:800],
                    "preview_contexto_total": contexto_conversacional[:1200],
                }
            }

        return respuesta_dry

    warning_sql_retry: List[str] = []

    try:
        rows = await _ejecutar_sql_actual(sql_query)
    except Exception as e:
        detalle_sql = str(e)
        if _es_error_sql_reintentable(detalle_sql):
            try:
                human_retry = _construir_prompt_retry_sql_error(
                    human_query=human,
                    dialecto=dialecto,
                    sql_anterior=sql_query,
                    detalle_error=detalle_sql,
                    allowed_fqn=allowed_fqn,
                )
                sql_query = await _generar_y_blindar(human_retry)
                rows = await _ejecutar_sql_actual(sql_query)
                warning_sql_retry.append(
                    "La SQL inicial falló por sintaxis o ensamblado incompleto; se reparó automáticamente y se ejecutó una versión corregida."
                )
            except HTTPException:
                raise
            except Exception as e2:
                log.exception("Reintento automático por error SQL ejecutable falló.")
                raise HTTPException(status_code=500, detail=f"Error ejecutando SQL: {str(e2)}")
        else:
            log.exception("Error ejecutando SQL en /human_query")
            raise HTTPException(status_code=500, detail=f"Error ejecutando SQL: {detalle_sql}")

    if (
        SQL_EMPTY_RESULT_RETRY
        and len(rows) == 0
        and SQL_EMPTY_RESULT_RETRY_MAX > 0
        and (not _usuario_pide_estricto(human))
        and _sql_sugiere_riesgo_de_cero_filas(sql_query)
    ):
        for _ in range(int(SQL_EMPTY_RESULT_RETRY_MAX)):
            try:
                human_retry = _construir_prompt_retry_cero_filas_semantico(
                    human_query=human,
                    dialecto=dialecto,
                    limite_por_defecto=limite_por_defecto,
                    sql_anterior=sql_query,
                )
                sql_retry = await _generar_y_blindar(human_retry)
                rows_retry = await _ejecutar_sql_actual(sql_retry)

                if rows_retry:
                    sql_query = sql_retry
                    rows = rows_retry
                    warning_sql_retry.append(
                        "La consulta original devolvió 0 filas; se reescribió automáticamente con un ajuste semántico para recuperar resultados."
                    )
                    break

                sql_query = sql_retry
                rows = rows_retry

            except Exception:
                log.exception("Reintento semántico (0 filas) falló.")
                break

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
                sql_retry = await _generar_y_blindar(human_retry)
                rows_retry = await _ejecutar_sql_actual(sql_retry)

                if rows_retry and (not _resultado_parece_grupo_nulo(rows_retry, sql_retry)):
                    sql_query = sql_retry
                    rows = rows_retry
                    warning_sql_retry.append(
                        "La consulta original generó grupos nulos; se reescribió automáticamente con agrupación null-safe."
                    )
                    break

                sql_query = sql_retry
                rows = rows_retry

            except Exception:
                log.exception("Reintento null-safe (grupo NULL) falló.")
                break

    if (
        SQL_NULL_PROJECTION_RETRY
        and SQL_NULL_PROJECTION_RETRY_MAX > 0
        and (not _usuario_pide_estricto(human))
        and _resultado_parece_proyeccion_nula(rows, sql_query)
    ):
        for _ in range(int(SQL_NULL_PROJECTION_RETRY_MAX)):
            try:
                human_retry = _construir_prompt_retry_proyeccion_nullsafe(
                    human_query=human,
                    dialecto=dialecto,
                    limite_por_defecto=limite_por_defecto,
                    sql_anterior=sql_query,
                )
                sql_retry = await _generar_y_blindar(human_retry)
                rows_retry = await _ejecutar_sql_actual(sql_retry)

                if rows_retry and (not _resultado_parece_proyeccion_nula(rows_retry, sql_retry)):
                    sql_query = sql_retry
                    rows = rows_retry
                    warning_sql_retry.append(
                        "La consulta original devolvió columnas descriptivas nulas; se reescribió con proyección null-safe."
                    )
                    break

                sql_query = sql_retry
                rows = rows_retry

            except Exception:
                log.exception("Reintento null-safe (proyección nula) falló.")
                break

    if (
        SQL_LATEST_WINDOW_RETRY
        and SQL_LATEST_WINDOW_RETRY_MAX > 0
        and (not _usuario_pide_estricto(human))
        and _resultado_parece_latest_sobre_restringido(rows, sql_query, limite_por_defecto)
    ):
        for _ in range(int(SQL_LATEST_WINDOW_RETRY_MAX)):
            try:
                human_retry = _construir_prompt_retry_latest_window(
                    human_query=human,
                    dialecto=dialecto,
                    limite_por_defecto=limite_por_defecto,
                    sql_anterior=sql_query,
                )
                sql_retry = await _generar_y_blindar(human_retry)
                rows_retry = await _ejecutar_sql_actual(sql_retry)

                if rows_retry and len(rows_retry) > len(rows):
                    sql_query = sql_retry
                    rows = rows_retry
                    warning_sql_retry.append(
                        "La consulta original de tipo latest/window quedó demasiado restringida; se reescribió evitando filtros innecesarios."
                    )
                    break

            except Exception:
                log.exception("Reintento latest/window falló.")
                break

    analisis_resultado = generar_analisis_resultado(rows, consulta_humana=human) if INCLUIR_ANALISIS_RESULTADO else {}

    if isinstance(analisis_resultado, dict):
        analisis_resultado.pop("consulta_humana", None)

    if (not INCLUIR_SUGERENCIAS_GRAFICO) and isinstance(analisis_resultado, dict):
        analisis_resultado.pop("graficos_sugeridos", None)

    incluir_respuesta_texto = GENERAR_RESPUESTA_TEXTO if payload.incluir_respuesta_texto is None else bool(payload.incluir_respuesta_texto)

    if rows and incluir_respuesta_texto:
        try:
            respuesta_textual = await llm.construir_respuesta(rows, human)
            if not respuesta_textual.strip():
                respuesta_textual = renderizar_resumen_analitico(analisis_resultado)
        except Exception:
            log.exception("No se pudo construir la respuesta textual con el proveedor. Se usa fallback determinístico.")
            respuesta_textual = renderizar_resumen_analitico(analisis_resultado)
    elif rows:
        respuesta_textual = renderizar_resumen_analitico(analisis_resultado)
    else:
        respuesta_textual = "La consulta no devolvió filas, por lo que no fue posible construir una respuesta analítica con evidencia suficiente."

    if session_id:
        _GESTOR_CONTEXTO.registrar_turno(
            session_id=session_id,
            consulta_usuario=human,
            sql_generado=sql_query,
            respuesta_textual=respuesta_textual,
            row_count=len(rows),
        )

    estado_contexto_despues = _GESTOR_CONTEXTO.obtener_estado(session_id) if session_id else None

    respuesta: Dict[str, Any] = {
        "ok": True,
        "human_query": human,
        "dialect": dialecto,
        "sql": sql_query,
        "executed": True,
        "rows": rows,
        "row_count": len(rows),
        "answer_text": respuesta_textual,
        "contexto_aplicado": contexto_aplicado,
        "contexto_sesion": estado_contexto_despues,
    }

    if INCLUIR_ANALISIS_RESULTADO:
        respuesta["analisis"] = analisis_resultado

    if warning_sql_retry:
        respuesta["warning"] = " ".join(warning_sql_retry)

    if modo_debug:
        respuesta["debug"] = {
            "tablas_prompt_llm": tablas_prompt_llm,
            "contexto": {
                "session_id": session_id,
                "turnos_antes": (estado_contexto_antes or {}).get("turnos", 0) if isinstance(estado_contexto_antes, dict) else 0,
                "turnos_despues": (estado_contexto_despues or {}).get("turnos", 0) if isinstance(estado_contexto_despues, dict) else 0,
                "usa_contexto_memoria": usa_contexto_memoria,
                "usa_contexto_externo": usa_contexto_externo,
                "preview_memoria": contexto_memoria[:800],
                "preview_contexto_total": contexto_conversacional[:1200],
            }
        }

    return respuesta


@router.post("/sql", dependencies=[Depends(guardia_api_key)])
async def sql_query(payload: SQLQueryRequest) -> Dict[str, Any]:
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

        analisis_resultado = generar_analisis_resultado(rows, consulta_humana="SQL directo") if INCLUIR_ANALISIS_RESULTADO else {}

        respuesta = {
            "ok": True,
            "sql": sql,
            "executed": True,
            "rows": rows,
            "row_count": len(rows),
        }

        if INCLUIR_ANALISIS_RESULTADO:
            respuesta["analisis"] = analisis_resultado
            respuesta["answer_text"] = renderizar_resumen_analitico(analisis_resultado)

        return respuesta

    except Exception as e:
        log.exception("Error ejecutando SQL en /sql")
        raise HTTPException(status_code=500, detail=f"Error ejecutando SQL: {str(e)}")