# src/main.py
# -*- coding: utf-8 -*-
"""
Módulo: main
------------
Router principal de la API (FastAPI) — NL→SQL sobre Azure SQL / PostgreSQL.

Endpoints disponibles:
  GET  /health                      Healthcheck básico.
  GET  /llm/ping                    Verifica disponibilidad del proveedor LLM.
  GET  /llm/models                  Lista los modelos disponibles del proveedor.
  GET  /chat/context/{session_id}   Recupera el historial de conversación de una sesión.
  GET  /schema                      Devuelve el esquema de la BD (cacheado).
  POST /schema/refresh              Fuerza la recarga del caché de esquema.
  POST /human_query                 Endpoint principal: NL → SQL → resultado → respuesta.
  POST /sql                         Ejecución directa de SQL (solo lectura, validado).

Flujo de /human_query:
  1. Recupera contexto de sesión (GestorContextoConversacional).
  2. Evalúa si la consulta puede resolverse desde memoria (sin re-ejecutar SQL):
     a. _puede_refinar_desde_memoria()   → filtra/ordena el resultado previo.
     b. _puede_responder_desde_memoria() → sintetiza/interpreta sin nueva query.
  3. Si necesita SQL nuevo:
     a. Obtiene/cachea el esquema relevante.
     b. Llama a llm.consulta_humana_a_sql() con heurísticas de dominio.
     c. Limpia, valida y ejecuta el SQL.
     d. Reintentos automáticos: empty-result, null-group, null-projection, window-retry.
  4. Genera análisis determinístico (analitica.py).
  5. Construye respuesta en lenguaje natural (LLM o fallback estadístico).
  6. Registra el turno en la sesión activa.

Mecanismos de reintento:
  SQL_EMPTY_RESULT_RETRY      — reescribe cuando el resultado es 0 filas.
  SQL_NULL_GROUP_RETRY        — corrige GROUP BY con NULLs distorsionadores.
  SQL_NULL_PROJECTION_RETRY   — agrega COALESCE en proyecciones con NULLs.
  SQL_LATEST_WINDOW_RETRY     — reescribe hacia CTE/ROW_NUMBER para "último registro".

Continuidad conversacional (memoria):
  _RE_INTERPRETACION_MEMORIA  / _puede_responder_desde_memoria()
  _RE_REFINAR_MEMORIA         / _puede_refinar_desde_memoria()
  → Detectan intenciones como "explica", "resume", "prioriza", "quédate solo con…"
    y responden usando las filas ya en memoria (sql=null, executed=false).
"""

from __future__ import annotations

import asyncio
import json
import logging
import time
import unicodedata
import uuid
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
REQUEST_TIMEOUT = env("REQUEST_TIMEOUT", default=200, cast=int)
DB_QUERY_TIMEOUT = env("DB_QUERY_TIMEOUT", default=60, cast=int)
MAX_SQL_RETRIES_TOTAL = env("MAX_SQL_RETRIES_TOTAL", default=1, cast=int)

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
CONTEXTO_CHAT_MAX_FILAS_RESULTADO = env("CONTEXTO_CHAT_MAX_FILAS_RESULTADO", default=200, cast=int)
CONTEXTO_CHAT_PERSISTIR_ARCHIVO = env("CONTEXTO_CHAT_PERSISTIR_ARCHIVO", default=True, cast=bool)
CONTEXTO_CHAT_ARCHIVO = env("CONTEXTO_CHAT_ARCHIVO", default=".cache/contexto_chat.json")

RESPUESTA_DEBUG = env("RESPUESTA_DEBUG", default=False, cast=bool)

_GESTOR_CONTEXTO = GestorContextoConversacional(
    ttl_minutos=CONTEXTO_CHAT_TTL_MINUTOS,
    max_turnos=CONTEXTO_CHAT_MAX_TURNOS,
    max_caracteres=CONTEXTO_CHAT_MAX_CARACTERES,
    max_filas_resultado=CONTEXTO_CHAT_MAX_FILAS_RESULTADO,
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

_RE_INTERPRETACION_MEMORIA = re.compile(
    r"\b("
    r"sin\s+volver\s+a\s+listar|sin\s+repetir|explica|explicame|explícame|"
    r"interpreta|interpretacion|interpretación|resume|resumen|concluye|conclusion|conclusión|"
    r"patron|patrón|apunta|desgaste|contaminacion|contaminación|"
    r"diagnostica|diagnóstico|diagnostico|"
    r"prioriza|priorizarse|priorizalos|priorízalos|cuál\s+priorizar|cuales\s+priorizar"
    r")\b",
    re.IGNORECASE,
)

_RE_REFINAR_MEMORIA = re.compile(
    r"\b("
    r"quedate|quédate|solo\s+con|mas\s+criticos|más\s+críticos|"
    r"mas\s+altos|más\s+altos|top\s+\d+|ordena|ordenalos|ordénalos|"
    r"prioriza|priorizalos|priorízalos"
    r")\b",
    re.IGNORECASE,
)

_RE_PIDE_LISTAR = re.compile(
    r"\b(muestrame|muéstrame|lista|tabla|filas|registros|devuelveme|devuélveme|trae|dame)\b",
    re.IGNORECASE,
)


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


def _normalizar_token(s: str) -> str:
    return _normalizar_str(s).lower()


def _a_jsonable(rows: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    out: List[Dict[str, Any]] = []
    for r in rows or []:
        nr: Dict[str, Any] = {}
        for k, v in (r or {}).items():
            if isinstance(v, Decimal):
                nr[k] = float(round(v, DECIMAL_PLACES))
            elif isinstance(v, uuid.UUID):
                nr[k] = str(v)
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

_RE_INTENCION_INTERPRETAR_RESULTADO_PREVIO = re.compile(
    r"\b("
    r"sin\s+volver\s+a\s+listar|sin\s+repetir|"
    r"explica|explícame|explicame|interpreta|interpretación|interpretacion|"
    r"resume|resumen|concluye|conclusión|conclusion|"
    r"qué\s+significa|que\s+significa|"
    r"patron|patrón|apunta|sugiere|"
    r"desgaste|contaminacion|contaminación|"
    r"prioriza|priorizarse|priorizalos|priorízalos|cuál\s+priorizar|cuales\s+priorizar"
    r")\b",
    re.IGNORECASE,
)

_RE_INTENCION_PEDIR_DATOS_NUEVOS = re.compile(
    r"\b("
    r"muestrame|muéstrame|lista|trae|traeme|tráeme|"
    r"consulta|busca|obt[eé]n|filtra|agrupa|"
    r"ahora\s+para|ahora\s+de|otro\s+proyecto|otra\s+tabla"
    r")\b",
    re.IGNORECASE,
)

def _debe_responder_desde_resultado_previo(
    human_query: str,
    ultimo_resultado: Dict[str, Any],
) -> bool:
    if not ultimo_resultado:
        return False

    rows_previas = list(ultimo_resultado.get("rows") or [])
    if not rows_previas:
        return False

    q = (human_query or "").strip()
    if not q:
        return False

    if _RE_INTENCION_PEDIR_DATOS_NUEVOS.search(q):
        return False

    return bool(_RE_INTENCION_INTERPRETAR_RESULTADO_PREVIO.search(q))


def _valor_es_numerico(v: Any) -> bool:
    return isinstance(v, (int, float, Decimal)) and not isinstance(v, bool)


def _columnas_numericas(rows: List[Dict[str, Any]]) -> List[str]:
    if not rows:
        return []
    columnas = list(rows[0].keys())
    out: List[str] = []
    for c in columnas:
        valores = [r.get(c) for r in rows if r.get(c) is not None]
        if valores and all(_valor_es_numerico(v) for v in valores[:20]):
            out.append(c)
    return out


def _inferir_columna_metrica(query: str, columnas: List[str]) -> Optional[str]:
    q = _normalizar_token(query)
    mapa_columnas = {_normalizar_token(c): c for c in columnas}

    sinonimos = {
        "Fe_ppm": ["fe_ppm", "fe", "hierro"],
        "Cu_ppm": ["cu_ppm", "cu", "cobre"],
        "Si_ppm": ["si_ppm", "si", "silicio"],
        "HorasDeAceite": ["horasdeaceite", "horas de aceite", "horas", "aceite"],
        "PQIndex": ["pqindex", "pq", "indice pq", "índice pq"],
    }

    for col_real, alias_list in sinonimos.items():
        if col_real in columnas and any(alias in q for alias in alias_list):
            return col_real

    for normalizada, real in mapa_columnas.items():
        if normalizada in q:
            return real

    if any(tok in q for tok in ["contaminacion", "contaminación"]) and "Si_ppm" in columnas:
        return "Si_ppm"

    if any(tok in q for tok in ["desgaste", "critico", "crítico", "criticos", "críticos"]):
        for pref in ["Fe_ppm", "PQIndex", "Cu_ppm", "Si_ppm"]:
            if pref in columnas:
                return pref

    return columnas[0] if columnas else None


def _determinar_sentido_orden(query: str) -> str:
    q = _normalizar_token(query)
    if any(x in q for x in ["menor", "menores", "asc", "ascendente", "bajo", "bajos"]):
        return "asc"
    return "desc"


def _determinar_top_n(query: str, total: int) -> int:
    if total <= 0:
        return 0

    m = re.search(r"\btop\s*(\d+)\b", query, flags=re.IGNORECASE)
    if not m:
        m = re.search(r"\bprimeros?\s+(\d+)\b", query, flags=re.IGNORECASE)
    if not m:
        m = re.search(r"\b(\d+)\s+m[aá]s\s+cr[ií]ticos\b", query, flags=re.IGNORECASE)

    if m:
        try:
            n = int(m.group(1))
            return max(1, min(total, n))
        except Exception:
            pass

    q = _normalizar_token(query)
    if "criticos" in q or "críticos" in q or "solo con" in q or "quedate" in q or "quédate" in q:
        if total <= 10:
            return min(total, 5)
        if total <= 30:
            return min(total, 10)
        return min(total, 20)

    return total


def _filtrar_y_ordenar_resultado_previo(
    rows: List[Dict[str, Any]],
    consulta_humana: str,
) -> Optional[Dict[str, Any]]:
    if not rows:
        return None

    columnas_num = _columnas_numericas(rows)
    if not columnas_num:
        return None

    columna_metric = _inferir_columna_metrica(consulta_humana, columnas_num)
    if not columna_metric:
        return None

    sentido = _determinar_sentido_orden(consulta_humana)
    top_n = _determinar_top_n(consulta_humana, len(rows))

    rows_validas = [r for r in rows if r.get(columna_metric) is not None]
    if not rows_validas:
        return None

    rows_ordenadas = sorted(
        rows_validas,
        key=lambda r: float(r.get(columna_metric) or 0),
        reverse=(sentido == "desc"),
    )

    rows_finales = rows_ordenadas[:top_n]
    return {
        "rows": rows_finales,
        "columna_metric": columna_metric,
        "sentido": sentido,
        "top_n": top_n,
    }


def _puede_refinar_desde_memoria(
    consulta_humana: str,
    ultimo_resultado: Dict[str, Any],
) -> bool:
    rows = ultimo_resultado.get("rows_resultado") or []
    if not rows:
        return False

    q = consulta_humana or ""
    if not _RE_REFINAR_MEMORIA.search(q):
        return False

    if "sin volver a listar" in _normalizar_token(q):
        return False

    return True


def _puede_responder_desde_memoria(
    consulta_humana: str,
    ultimo_resultado: Dict[str, Any],
) -> bool:
    rows = ultimo_resultado.get("rows_resultado") or []
    if not rows:
        return False

    q = consulta_humana or ""
    if not _RE_INTERPRETACION_MEMORIA.search(q):
        return False

    if _RE_PIDE_LISTAR.search(q):
        return False

    return True


def _armar_respuesta_desde_resultado_previo(
    *,
    human: str,
    session_id: str,
    rows: List[Dict[str, Any]],
    incluir_respuesta_texto: bool,
    estado_contexto_antes: Optional[Dict[str, Any]],
    usa_contexto_memoria: bool,
    usa_contexto_externo: bool,
    contexto_memoria: str,
    contexto_conversacional: str,
    modo_debug: bool,
    origen_respuesta: str,
    consulta_origen_resultado_previo: Optional[str] = None,
    columnas_resultado_previo: Optional[List[str]] = None,
    metrica_refinada: Optional[str] = None,
) -> Dict[str, Any]:
    analisis_resultado = generar_analisis_resultado(rows, consulta_humana=human) if INCLUIR_ANALISIS_RESULTADO else {}

    if isinstance(analisis_resultado, dict):
        analisis_resultado.pop("consulta_humana", None)

    if (not INCLUIR_SUGERENCIAS_GRAFICO) and isinstance(analisis_resultado, dict):
        analisis_resultado.pop("graficos_sugeridos", None)

    if rows and incluir_respuesta_texto:
        try:
            respuesta_textual = llm.run_sync_construir_respuesta(rows, human)
            if not (respuesta_textual or "").strip():
                respuesta_textual = renderizar_resumen_analitico(analisis_resultado)
        except Exception:
            log.exception("No se pudo construir respuesta textual desde resultado previo. Se usa fallback determinístico.")
            respuesta_textual = renderizar_resumen_analitico(analisis_resultado)
    elif rows:
        respuesta_textual = renderizar_resumen_analitico(analisis_resultado)
    else:
        respuesta_textual = "No hay un resultado previo suficiente en memoria para responder con evidencia."

    if session_id:
        _GESTOR_CONTEXTO.registrar_turno(
            session_id=session_id,
            consulta_usuario=human,
            sql_generado="",
            respuesta_textual=respuesta_textual,
            row_count=len(rows),
            filas_resultado=rows,
            analisis_resultado=analisis_resultado,
        )

    estado_contexto_despues = _GESTOR_CONTEXTO.obtener_estado(session_id) if session_id else None

    respuesta: Dict[str, Any] = {
        "ok": True,
        "human_query": human,
        "dialect": "mssql" if es_mssql() else "postgresql",
        "sql": None,
        "executed": False,
        "origen_respuesta": origen_respuesta,
        "row_count": len(rows),
        "answer_text": respuesta_textual,
        "contexto_aplicado": True,
        "contexto_sesion": estado_contexto_despues,
    }

    if origen_respuesta.endswith("_filtrado"):
        respuesta["rows"] = rows

    if INCLUIR_ANALISIS_RESULTADO:
        respuesta["analisis"] = analisis_resultado

    if modo_debug:
        respuesta["debug"] = {
            "modo": origen_respuesta,
            "contexto": {
                "session_id": session_id,
                "turnos_antes": (estado_contexto_antes or {}).get("turnos", 0) if isinstance(estado_contexto_antes, dict) else 0,
                "turnos_despues": (estado_contexto_despues or {}).get("turnos", 0) if isinstance(estado_contexto_despues, dict) else 0,
                "usa_contexto_memoria": usa_contexto_memoria,
                "usa_contexto_externo": usa_contexto_externo,
                "preview_memoria": contexto_memoria[:800],
                "preview_contexto_total": contexto_conversacional[:1200],
                "consulta_origen_resultado_previo": consulta_origen_resultado_previo,
                "row_count_resultado_previo": len(rows),
                "columnas_resultado_previo": columnas_resultado_previo or (list(rows[0].keys()) if rows else []),
                "metrica_refinada": metrica_refinada,
            }
        }

    return respuesta


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
    ultimo_resultado = _GESTOR_CONTEXTO.obtener_ultimo_resultado(session_id)
    return {
        "ok": True,
        "estado": estado,
        "contexto": contexto,
        "ultimo_resultado": {
            "disponible": bool(ultimo_resultado.get("rows_resultado")),
            "row_count": int(ultimo_resultado.get("row_count") or 0),
            "columnas": ultimo_resultado.get("columnas_resultado") or [],
            "consulta_origen": ultimo_resultado.get("consulta_usuario") or "",
        },
    }


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
    try:
        return await asyncio.wait_for(
            _procesar_human_query(payload),
            timeout=REQUEST_TIMEOUT,
        )
    except asyncio.TimeoutError:
        raise HTTPException(
            status_code=408,
            detail="La consulta tardó demasiado. Intenta ser más específico o simplificar la pregunta.",
        )


async def _procesar_human_query(payload: HumanQueryRequest) -> Dict[str, Any]:
    human = _normalizar_str(payload.human_query)
    if not human:
        raise HTTPException(status_code=400, detail="human_query vacío.")

    session_id = (payload.session_id or "").strip()
    modo_debug = RESPUESTA_DEBUG if payload.modo_debug is None else bool(payload.modo_debug)

    if payload.reset_contexto and session_id:
        _GESTOR_CONTEXTO.olvidar(session_id)

    estado_contexto_antes = _GESTOR_CONTEXTO.obtener_estado(session_id) if session_id else None
    contexto_memoria = _GESTOR_CONTEXTO.obtener_contexto(session_id) if session_id else ""
    ultimo_resultado = _GESTOR_CONTEXTO.obtener_ultimo_resultado(session_id) if session_id else {}
    contexto_externo = _normalizar_str(payload.conversation_context or "")
    contexto_conversacional = _combinar_contextos(contexto_externo, contexto_memoria)
    ultimo_resultado = _GESTOR_CONTEXTO.obtener_ultimo_resultado(session_id) if session_id else {}

    usa_contexto_memoria = bool(contexto_memoria.strip())
    usa_contexto_externo = bool(contexto_externo.strip())
    contexto_aplicado = usa_contexto_memoria or usa_contexto_externo

    incluir_respuesta_texto = GENERAR_RESPUESTA_TEXTO if payload.incluir_respuesta_texto is None else bool(payload.incluir_respuesta_texto)

    if _puede_refinar_desde_memoria(human, ultimo_resultado):
        refinado = _filtrar_y_ordenar_resultado_previo(
            rows=ultimo_resultado.get("rows_resultado") or [],
            consulta_humana=human,
        )
        if refinado and refinado.get("rows"):
            return _armar_respuesta_desde_resultado_previo(
                human=human,
                session_id=session_id,
                rows=refinado["rows"],
                incluir_respuesta_texto=incluir_respuesta_texto,
                estado_contexto_antes=estado_contexto_antes,
                usa_contexto_memoria=usa_contexto_memoria,
                usa_contexto_externo=usa_contexto_externo,
                contexto_memoria=contexto_memoria,
                contexto_conversacional=contexto_conversacional,
                modo_debug=modo_debug,
                origen_respuesta="resultado_previo_en_memoria_filtrado",
                consulta_origen_resultado_previo=ultimo_resultado.get("consulta_usuario"),
                columnas_resultado_previo=ultimo_resultado.get("columnas_resultado") or [],
                metrica_refinada=refinado.get("columna_metric"),
            )

    if _puede_responder_desde_memoria(human, ultimo_resultado):
        rows_previas = ultimo_resultado.get("rows_resultado") or []
        if rows_previas:
            return _armar_respuesta_desde_resultado_previo(
                human=human,
                session_id=session_id,
                rows=rows_previas,
                incluir_respuesta_texto=incluir_respuesta_texto,
                estado_contexto_antes=estado_contexto_antes,
                usa_contexto_memoria=usa_contexto_memoria,
                usa_contexto_externo=usa_contexto_externo,
                contexto_memoria=contexto_memoria,
                contexto_conversacional=contexto_conversacional,
                modo_debug=modo_debug,
                origen_respuesta="resultado_previo_en_memoria",
                consulta_origen_resultado_previo=ultimo_resultado.get("consulta_usuario"),
                columnas_resultado_previo=ultimo_resultado.get("columnas_resultado") or [],
            )

        if _debe_responder_desde_resultado_previo(human, ultimo_resultado):
            rows_previas = list(ultimo_resultado.get("rows") or [])
            analisis_previo = dict(ultimo_resultado.get("analisis") or {})

            incluir_respuesta_texto = (
                GENERAR_RESPUESTA_TEXTO
                if payload.incluir_respuesta_texto is None
                else bool(payload.incluir_respuesta_texto)
            )

            if rows_previas and incluir_respuesta_texto:
                try:
                    respuesta_textual = await llm.construir_respuesta(rows_previas, human)
                    if not respuesta_textual.strip():
                        respuesta_textual = renderizar_resumen_analitico(analisis_previo)
                except Exception:
                    log.exception("No se pudo construir la respuesta textual desde resultado previo. Se usa fallback determinístico.")
                    respuesta_textual = renderizar_resumen_analitico(analisis_previo)
            else:
                respuesta_textual = renderizar_resumen_analitico(analisis_previo)

            if session_id:
                _GESTOR_CONTEXTO.registrar_turno(
                    session_id=session_id,
                    consulta_usuario=human,
                    sql_generado="",
                    respuesta_textual=respuesta_textual,
                    row_count=len(rows_previas),
                    filas_resultado=rows_previas,
                    analisis_resultado=analisis_previo,
                    origen_respuesta="resultado_previo_en_memoria",
                )

            estado_contexto_despues = _GESTOR_CONTEXTO.obtener_estado(session_id) if session_id else None

            respuesta_memoria: Dict[str, Any] = {
                "ok": True,
                "human_query": human,
                "dialect": payload.dialect or ("mssql" if es_mssql() else "postgresql"),
                "sql": None,
                "executed": False,
                "origen_respuesta": "resultado_previo_en_memoria",
                "row_count": len(rows_previas),
                "answer_text": respuesta_textual,
                "contexto_aplicado": True,
                "contexto_sesion": estado_contexto_despues,
            }

            if INCLUIR_ANALISIS_RESULTADO and analisis_previo:
                respuesta_memoria["analisis"] = analisis_previo

            if modo_debug:
                respuesta_memoria["debug"] = {
                    "modo": "resultado_previo_en_memoria",
                    "contexto": {
                        "session_id": session_id,
                        "turnos_antes": (estado_contexto_antes or {}).get("turnos", 0) if isinstance(estado_contexto_antes, dict) else 0,
                        "turnos_despues": (estado_contexto_despues or {}).get("turnos", 0) if isinstance(estado_contexto_despues, dict) else 0,
                        "usa_contexto_memoria": bool(contexto_memoria.strip()),
                        "usa_contexto_externo": False,
                        "preview_memoria": contexto_memoria[:800],
                        "consulta_origen_resultado_previo": ultimo_resultado.get("consulta_usuario"),
                        "row_count_resultado_previo": len(rows_previas),
                        "columnas_resultado_previo": list(rows_previas[0].keys()) if rows_previas else [],
                    }
                }

            return respuesta_memoria

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
        try:
            sql_json = await llm.consulta_humana_a_sql(
                consulta_humana=consulta_humana,
                esquema_json=esquema_llm,
                dialecto=dialecto,
                limite_por_defecto=limite_por_defecto,
                modelo=None,
                conversation_context=contexto_conversacional,
            )
        except RuntimeError as exc:
            raise HTTPException(
                status_code=503,
                detail=f"El modelo LLM no pudo generar la consulta: {str(exc)[:300]}",
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
        # asyncio.shield(fut) crea un wrapper cancelable sin cancelar el thread subyacente.
        # Cuando asyncio.wait_for cancela el wrapper, el Future interno sigue en background
        # y wait_for retorna TimeoutError INMEDIATAMENTE (sin _cancel_and_wait bloqueante).
        loop = asyncio.get_running_loop()
        fut = loop.run_in_executor(
            None,
            lambda: database.consultar(sql_actual, allowed_fqn, limite_por_defecto, limite_maximo),
        )
        try:
            rows_local = await asyncio.wait_for(asyncio.shield(fut), timeout=DB_QUERY_TIMEOUT)
        except asyncio.TimeoutError:
            log.warning(
                "[db_timeout] BD no respondió en %ss — retornando 408 (thread sigue en background).",
                DB_QUERY_TIMEOUT,
            )
            raise HTTPException(
                status_code=408,
                detail=(
                    f"La consulta SQL tardó más de {DB_QUERY_TIMEOUT}s en ejecutarse. "
                    "Intenta acotar el rango de fechas o simplificar la pregunta."
                ),
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
                "modo": "nl_to_sql_dry_run",
                "tablas_prompt_llm": tablas_prompt_llm,
                "contexto": {
                    "session_id": session_id,
                    "usa_contexto_memoria": usa_contexto_memoria,
                    "usa_contexto_externo": usa_contexto_externo,
                    "preview_memoria": contexto_memoria[:800],
                    "preview_contexto_total": contexto_conversacional[:1200],
                    "ultimo_resultado_disponible": bool((ultimo_resultado.get("rows_resultado") or [])),
                    "ultimo_resultado_row_count": int(ultimo_resultado.get("row_count") or 0),
                }
            }

        return respuesta_dry

    warning_sql_retry: List[str] = []
    _retries_total = 0  # presupuesto compartido entre todos los tipos de reintento

    try:
        rows = await _ejecutar_sql_actual(sql_query)
    except HTTPException:
        raise  # propaga 408 (timeout BD) sin convertirlo en 500
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
        _retries_total < MAX_SQL_RETRIES_TOTAL
        and SQL_EMPTY_RESULT_RETRY
        and len(rows) == 0
        and SQL_EMPTY_RESULT_RETRY_MAX > 0
        and (not _usuario_pide_estricto(human))
        and _sql_sugiere_riesgo_de_cero_filas(sql_query)
    ):
        for _ in range(int(SQL_EMPTY_RESULT_RETRY_MAX)):
            _retries_total += 1
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

            except HTTPException:
                raise
            except Exception:
                log.exception("Reintento semántico (0 filas) falló.")
                break

    if (
        _retries_total < MAX_SQL_RETRIES_TOTAL
        and SQL_NULL_GROUP_RETRY
        and SQL_NULL_GROUP_RETRY_MAX > 0
        and (not _usuario_pide_estricto(human))
        and _resultado_parece_grupo_nulo(rows, sql_query)
    ):
        for _ in range(int(SQL_NULL_GROUP_RETRY_MAX)):
            _retries_total += 1
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

            except HTTPException:
                raise
            except Exception:
                log.exception("Reintento null-safe (grupo NULL) falló.")
                break

    if (
        _retries_total < MAX_SQL_RETRIES_TOTAL
        and SQL_NULL_PROJECTION_RETRY
        and SQL_NULL_PROJECTION_RETRY_MAX > 0
        and (not _usuario_pide_estricto(human))
        and _resultado_parece_proyeccion_nula(rows, sql_query)
    ):
        for _ in range(int(SQL_NULL_PROJECTION_RETRY_MAX)):
            _retries_total += 1
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

            except HTTPException:
                raise
            except Exception:
                log.exception("Reintento null-safe (proyección nula) falló.")
                break

    if (
        _retries_total < MAX_SQL_RETRIES_TOTAL
        and SQL_LATEST_WINDOW_RETRY
        and SQL_LATEST_WINDOW_RETRY_MAX > 0
        and (not _usuario_pide_estricto(human))
        and _resultado_parece_latest_sobre_restringido(rows, sql_query, limite_por_defecto)
    ):
        for _ in range(int(SQL_LATEST_WINDOW_RETRY_MAX)):
            _retries_total += 1
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

            except HTTPException:
                raise
            except Exception:
                log.exception("Reintento latest/window falló.")
                break

    analisis_resultado = generar_analisis_resultado(rows, consulta_humana=human) if INCLUIR_ANALISIS_RESULTADO else {}

    if isinstance(analisis_resultado, dict):
        analisis_resultado.pop("consulta_humana", None)

    if (not INCLUIR_SUGERENCIAS_GRAFICO) and isinstance(analisis_resultado, dict):
        analisis_resultado.pop("graficos_sugeridos", None)

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
            filas_resultado=rows,
            analisis_resultado=analisis_resultado if isinstance(analisis_resultado, dict) else {},
            origen_respuesta="nl_to_sql_normal",
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
            "modo": "nl_to_sql_normal",
            "tablas_prompt_llm": tablas_prompt_llm,
            "contexto": {
                "session_id": session_id,
                "turnos_antes": (estado_contexto_antes or {}).get("turnos", 0) if isinstance(estado_contexto_antes, dict) else 0,
                "turnos_despues": (estado_contexto_despues or {}).get("turnos", 0) if isinstance(estado_contexto_despues, dict) else 0,
                "usa_contexto_memoria": usa_contexto_memoria,
                "usa_contexto_externo": usa_contexto_externo,
                "preview_memoria": contexto_memoria[:800],
                "preview_contexto_total": contexto_conversacional[:1200],
                "ultimo_resultado_disponible": bool((ultimo_resultado.get("rows_resultado") or [])),
                "ultimo_resultado_row_count": int(ultimo_resultado.get("row_count") or 0),
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


# ══════════════════════════════════════════════════════════════════════════════
#  ENDPOINT FUTURO: GET /alerts/oil
#  Estado: SCAFFOLDING — comentado hasta que se active la funcionalidad.
#
#  Para activar:
#    1. Descomentar todo el bloque de abajo.
#    2. Agregar el import en la cabecera del archivo:
#         from .alertas import verificar_alertas, ALERTAS_ACEITE_HABILITADAS
#    3. Setear ALERTAS_ACEITE_HABILITADAS=true en .env
#    4. Completar los TODOs en src/alertas.py (tabla de límites en BD)
#    5. Configurar el flujo en Power Automate (ver docstring en alertas.py)
#
#  Respuesta JSON que consume Power Automate:
#    {
#      "ok": true,
#      "total": 3,
#      "criticos": 1,
#      "precaucion": 2,
#      "periodo_horas": 24,
#      "checked_at": "2026-03-26T10:00:00Z",
#      "alertas": [
#        {
#          "equipo_id": "...",
#          "codigo_equipo": "T305459",
#          "compartimiento": "MOTOR",
#          "fecha_muestreo": "2026-03-26",
#          "codigo_muestra": "T317662",
#          "metal": "Hierro (Fe)",
#          "categoria": "desgaste",
#          "valor_ppm": 115.0,
#          "limite_precaucion": 60.0,
#          "limite_critico": 100.0,
#          "severidad": "critico"
#        },
#        ...
#      ]
#    }
# ══════════════════════════════════════════════════════════════════════════════

# from .alertas import verificar_alertas, ALERTAS_ACEITE_HABILITADAS   # ← descomentar al activar

# @router.get(
#     "/alerts/oil",
#     summary="Alertas de metales fuera de límite en análisis de aceite",
#     tags=["Alertas"],
# )
# async def get_alertas_aceite(
#     horas_atras: int = Query(
#         default=24,
#         ge=1,
#         le=168,
#         description="Ventana de tiempo hacia atrás en horas (1–168). Por defecto: 24.",
#     ),
# ):
#     """
#     Consulta [Oil].[LaboratoryData] para el período indicado y devuelve las
#     muestras donde algún metal supera los límites LP (precaución) o LC (crítico).
#
#     Pensado para ser llamado por Power Automate en un flujo programado que
#     envía notificaciones por correo cuando total > 0.
#     """
#     if not ALERTAS_ACEITE_HABILITADAS:
#         return {
#             "ok": False,
#             "mensaje": "Módulo de alertas deshabilitado. "
#                        "Setear ALERTAS_ACEITE_HABILITADAS=true en .env para activar.",
#             "total": 0,
#             "alertas": [],
#         }
#
#     try:
#         alertas = await run_in_threadpool(verificar_alertas, horas_atras)
#     except Exception as e:
#         log.exception("Error en /alerts/oil")
#         raise HTTPException(status_code=500, detail=f"Error verificando alertas: {str(e)}")
#
#     criticos   = sum(1 for a in alertas if a.severidad == "critico")
#     precaucion = sum(1 for a in alertas if a.severidad == "precaucion")
#
#     return {
#         "ok"           : True,
#         "total"        : len(alertas),
#         "criticos"     : criticos,
#         "precaucion"   : precaucion,
#         "periodo_horas": horas_atras,
#         "checked_at"   : datetime.now(timezone.utc).isoformat(),
#         "alertas"      : [a.to_dict() for a in alertas],
#     }