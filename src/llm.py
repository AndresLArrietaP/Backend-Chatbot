# src/llm.py
# -*- coding: utf-8 -*-
"""
Módulo: llm
-----------
Capa orquestadora sobre el proveedor LLM (Gemini/OpenAI).

Responsabilidades:
- Convertir una consulta en lenguaje natural a SQL (NL→SQL).
- Pedir al proveedor que genere una respuesta textual (build_answer).

API principal (la que usas en tu backend):
✅ consulta_humana_a_sql(...)

Notas:
- Este módulo trabaja con un proveedor creado por `src.providers.factory`.
- Mantiene wrappers/alias por compatibilidad con código anterior.
- Evita sesgar el dialecto mencionando explícitamente LIMIT/TOP en refuerzos.
"""

from __future__ import annotations

import json
import logging
import re
from typing import Any, Dict, List, Optional

from .providers.factory import obtener_proveedor as _obtener_proveedor

log = logging.getLogger(__name__)

# Proveedor (singleton simple)
_proveedor = _obtener_proveedor()



# ------------------------- Heurísticas de intención ---------------------------

_RE_PISTA_COMPARACION = re.compile(
    r"\b(supera|mayor\s+que|menor\s+que|más\s+que|menos\s+que|compar|vs\.?|versus|diferenc|pendien|despach)\b",
    re.IGNORECASE,
)

_RE_PISTA_ULTIMO_VENTANA = re.compile(
    r"\b(ultimo|último|mas\s+reciente|más\s+reciente|row_number|rank|dense_rank|over\s*\(|partition\s+by|cte|ventana)\b",
    re.IGNORECASE,
)

_RE_PISTA_EXCLUSION_NULOS = re.compile(
    r"\b(sin\s+nulos|sin\s+null|no\s+nulo|no\s+null|excluir\s+nulos|excluir\s+null|solo\s+con\s+valor|solo\s+con\s+datos|solo\s+disponibles)\b",
    re.IGNORECASE,
)

_RE_PISTA_METRICA_EXPLICITA = re.compile(
    r"\b(fe_ppm|cu_ppm|cr_ppm|pb_ppm|sn_ppm|al_ppm|si_ppm|na_ppm|k_ppm|li_ppm|sb_ppm|tbn|tan|v100|viscosidad40|horometro)\b",
    re.IGNORECASE,
)


def _es_intencion_ultimo_ventana(texto: str) -> bool:
    """Detecta intención de último registro / CTE / funciones ventana."""
    return bool(_RE_PISTA_ULTIMO_VENTANA.search(texto or ""))


def _usuario_pide_excluir_nulos(texto: str) -> bool:
    """Detecta si el usuario quiere excluir nulos explícitamente."""
    return bool(_RE_PISTA_EXCLUSION_NULOS.search(texto or ""))


def _reforzar_consulta_ultimo_ventana(q: str) -> str:
    """
    Refuerzo genérico para consultas de último/más reciente por entidad.
    """
    extra_nulos = ""
    if not _usuario_pide_excluir_nulos(q):
        extra_nulos = (
            " IMPORTANTE: si buscas el último o más reciente registro por entidad con CTE/ROW_NUMBER, "
            "NO agregues por defecto filtros IS NOT NULL sobre métricas pedidas en la salida "
            "(por ejemplo ppm, horas, valores numéricos), porque eso puede eliminar entidades completas "
            "antes de calcular ROW_NUMBER. Solo excluye nulos si el usuario lo pidió explícitamente."
        )

    return (
        q.strip()
        + " | IMPORTANTE: si la consulta busca el último o más reciente registro por entidad, "
          "mantén la lógica con CTE/ROW_NUMBER/PARTITION BY y usa LEFT JOIN para relaciones opcionales. "
          "Si usas un CTE o subquery para rankear, NO pongas TOP/LIMIT dentro de ese CTE o subquery. "
          "Si necesitas limitar filas, aplícalo únicamente en el SELECT final después de WHERE rn = 1. "
          "Puedes filtrar la clave de partición a IS NOT NULL cuando esa clave sea la entidad de negocio pedida "
          "(por ejemplo EquipmentComponentId), pero no filtres métricas pedidas salvo petición explícita. "
          "Si el usuario pidió columnas descriptivas provenientes de tablas opcionales, no las proyectes crudas si pueden quedar NULL: "
          "usa COALESCE con columnas reales de fallback relacionadas. "
          "No uses literales artificiales como 'N/A', 'Unknown' o similares dentro del SQL."
        + extra_nulos
    )

def _es_intencion_comparativa(texto: str) -> bool:
    """Heurística básica para detectar intención comparativa."""
    return bool(_RE_PISTA_COMPARACION.search(texto or ""))


def _reforzar_consulta_comparativa(q: str) -> str:
    """
    Refuerzo genérico:
    Si la consulta implica comparar A vs B, pide incluir A, B y (A-B).
    No menciona LIMIT/TOP para no sesgar el dialecto; solo pide ordenar
    por Diferencia cuando se esté limitando filas.
    """
    return (
        q.strip()
        + " | IMPORTANTE: Si la consulta implica comparar 2 campos (A vs B), el SELECT DEBE incluir "
          "las 2 métricas y una columna Diferencia = (A - B), y ordenar por Diferencia DESC cuando "
          "se esté limitando la cantidad de filas devueltas."
    )


def _json_cauto_loads(s: str) -> Optional[Dict[str, Any]]:
    """Intenta cargar JSON y devolver dict; si no, None."""
    try:
        obj = json.loads(s or "")
        return obj if isinstance(obj, dict) else None
    except Exception:
        return None



# ------------------------- API pública ---------------------------------------

def listar_modelos() -> Dict[str, Any]:
    """Lista modelos disponibles del proveedor activo."""
    if hasattr(_proveedor, "listar_modelos"):
        return _proveedor.listar_modelos()
    return _proveedor.list_models()


async def ping(modelo: Optional[str] = None) -> str:
    """Ping al proveedor (útil para health-check)."""
    if "model" in _proveedor.ping.__code__.co_varnames:
        return await _proveedor.ping(model=modelo)  # type: ignore
    return await _proveedor.ping(modelo)  # type: ignore


async def consulta_humana_a_sql(
    consulta_humana: str,
    esquema_json: Dict[str, Any],
    dialecto: str = "postgresql",
    limite_por_defecto: int = 100,
    modelo: Optional[str] = None,
    conversation_context: Optional[str] = None
) -> str:
    """
    Convierte NL → SQL mediante el proveedor activo.

    Args:
        consulta_humana: prompt del usuario en lenguaje natural
        esquema_json: salida de database.obtener_esquema_json(...)
        dialecto: 'mssql'/'sqlserver' o 'postgresql', etc.
        limite_por_defecto: número de filas a limitar (TOP/LIMIT según dialecto)
        modelo: override opcional del modelo del proveedor

    Returns:
        JSON string con forma:
          {"sql_query":"...", "original_query":"..."}
    """
    q = (consulta_humana or "").strip()
    if not q:
        raise ValueError("consulta_humana vacía")

    #q_reforzada = q
    contexto = (conversation_context or "").strip()

    if contexto:
        q_reforzada = (
            "CONTEXTO CONVERSACIONAL PREVIO:\n"
            f"{contexto}\n\n"
            "NUEVA SOLICITUD DEL USUARIO:\n"
            f"{q}\n\n"
            "REGLA MUY IMPORTANTE: si la nueva solicitud es una continuación "
            "como 'eso mismo', 'ahora', 'solo...', 'pero para...', "
            "'enséñame igual', conserva la intención analítica previa "
            "(misma entidad, misma métrica, misma granularidad) "
            "y modifica solo la nueva restricción o filtro."
        )
    else:
        q_reforzada = q

    base_heuristica = f"{contexto} {q}".strip()

    if _es_intencion_comparativa(base_heuristica):
        q_reforzada = _reforzar_consulta_comparativa(q_reforzada)

    if _es_intencion_ultimo_ventana(base_heuristica):
        q_reforzada = _reforzar_consulta_ultimo_ventana(q_reforzada)

    # Compatibilidad: proveedor puede exponer métodos en español o en inglés
    if hasattr(_proveedor, "consulta_humana_a_sql"):
        salida = await _proveedor.consulta_humana_a_sql(
            consulta=q_reforzada,
            esquema_json=esquema_json,
            dialecto=dialecto,
            limite_por_defecto=limite_por_defecto,
            modelo=modelo,
        )
    else:
        salida = await _proveedor.human_query_to_sql(  # type: ignore
            human_query=q_reforzada,
            schema_json=esquema_json,
            dialect=dialecto,
            default_limit=limite_por_defecto,
            model=modelo,
        )

    obj = _json_cauto_loads(salida)
    if not obj or "sql_query" not in obj:
        log.warning("[llm.consulta_humana_a_sql] salida no-JSON o sin sql_query (len=%s)", len(salida or ""))
        return salida

    if not obj.get("original_query"):
        obj["original_query"] = q

    return json.dumps(obj, ensure_ascii=False)


async def construir_respuesta(
    filas: List[Dict[str, Any]],
    consulta_humana: str,
    modelo: Optional[str] = None,
) -> str:
    """
    Genera respuesta textual (delegado al proveedor).

    Args:
        filas: resultados del SQL
        consulta_humana: prompt original del usuario
        modelo: modelo opcional

    Returns:
        Texto final en lenguaje natural.
    """
    if hasattr(_proveedor, "construir_respuesta"):
        return await _proveedor.construir_respuesta(filas=filas, consulta_humana=consulta_humana, modelo=modelo)
    return await _proveedor.build_answer(rows=filas, human_query=consulta_humana, model=modelo)  # type: ignore


# ------------------------- Wrappers de compatibilidad -------------------------

async def human_query_to_sql(
    human_query: str,
    schema_json: Dict[str, Any],
    dialect: str = "postgresql",
    default_limit: int = 100,
    model: Optional[str] = None,
) -> str:
    """Alias async legacy para mantener compatibilidad."""
    return await consulta_humana_a_sql(
        consulta_humana=human_query,
        esquema_json=schema_json,
        dialecto=dialect,
        limite_por_defecto=default_limit,
        modelo=model,
    )


def extraer_sql_de_json(sql_json: str) -> Optional[str]:
    """Utilidad: extrae 'sql_query' de un JSON string si existe."""
    obj = _json_cauto_loads(sql_json)
    if obj and "sql_query" in obj:
        return str(obj["sql_query"])
    return None