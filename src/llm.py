# src/llm.py
# -*- coding: utf-8 -*-
"""
Módulo: llm
-----------
Capa orquestadora sobre el proveedor LLM (Gemini/OpenAI).

Responsabilidades:
- Aplicar heurísticas livianas antes de enviar la consulta al proveedor.
- Reforzar consultas de continuidad conversacional.
- Reforzar consultas del dominio análisis de aceite.
- Mantener compatibilidad con proveedores Gemini/OpenAI.
"""

from __future__ import annotations

import json
import logging
import re
from typing import Any, Dict, List, Optional

from .providers.factory import obtener_proveedor as _obtener_proveedor

log = logging.getLogger(__name__)

_proveedor = _obtener_proveedor()

# -----------------------------------------------------------------------------
# Heurísticas de intención
# -----------------------------------------------------------------------------

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

_RE_PISTA_CONTINUIDAD = re.compile(
    r"\b("
    r"ahora|luego|después|despues|de\s+esos\s+resultados|de\s+ese\s+resultado|"
    r"de\s+esas\s+filas|de\s+estos\s+registros|de\s+los\s+mismos|de\s+las\s+mismas|"
    r"quédate|quedate|quédate\s+solo|quedate\s+solo|mantén|manten|manteniendo|"
    r"sin\s+volver\s+a\s+listar|sin\s+repetir|sin\s+relistar|"
    r"eso|esa|ese|esos|esas|aquello|aquellos|aquellas|"
    r"los\s+más\s+críticos|los\s+mas\s+criticos|los\s+críticos|los\s+criticos"
    r")\b",
    re.IGNORECASE,
)

_RE_PISTA_SINTESIS_INTERPRETACION = re.compile(
    r"\b(explica|explícame|explicame|interpreta|interpretación|interpretacion|"
    r"resume|resumen|concluye|conclusión|conclusion|diagnostica|diagnóstico|diagnostico|"
    r"tendencia|estable|incremento|decreciente|descendente|comportamiento)\b",
    re.IGNORECASE,
)

_RE_PISTA_CRITICIDAD = re.compile(
    r"\b(crítico|critico|críticos|criticos|severo|severa|severos|severas|"
    r"alarma|riesgo|urgente|peor|peores|más\s+alto|mas\s+alto)\b",
    re.IGNORECASE,
)

# ------------------------- Heurísticas compartimiento aceite ---------------------------

_RE_PISTA_COMPARTIMIENTO_ACEITE = re.compile(
    r"\b(motor|transmision|transmisión|hidraulico|hidráulico|diferencial|mando\s+final|reductor|convertidor)\b",
    re.IGNORECASE,
)

_RE_PISTA_ANALISIS_ACEITE = re.compile(
    r"\b(aceite|ppm|tbn|tan|viscos|muestra|muestreo|horas\s+de\s+aceite|horometro|horómetro|"
    r"fe_ppm|cu_ppm|si_ppm|hierro|cobre|silicio|cromo|plomo|aluminio|indice\s+pq|índice\s+pq)\b",
    re.IGNORECASE,
)


# -----------------------------------------------------------------------------
# Utilidades heurísticas
# -----------------------------------------------------------------------------

def _json_cauto_loads(s: str) -> Optional[Dict[str, Any]]:
    try:
        obj = json.loads(s or "")
        return obj if isinstance(obj, dict) else None
    except Exception:
        return None


def _es_intencion_compartimiento_aceite(texto: str) -> bool:
    t = texto or ""
    return bool(_RE_PISTA_COMPARTIMIENTO_ACEITE.search(t)) and bool(_RE_PISTA_ANALISIS_ACEITE.search(t))


def _es_intencion_ultimo_ventana(texto: str) -> bool:
    return bool(_RE_PISTA_ULTIMO_VENTANA.search(texto or ""))


def _usuario_pide_excluir_nulos(texto: str) -> bool:
    return bool(_RE_PISTA_EXCLUSION_NULOS.search(texto or ""))


def _es_intencion_comparativa(texto: str) -> bool:
    return bool(_RE_PISTA_COMPARACION.search(texto or ""))


def _es_intencion_continuidad(texto: str, contexto: str) -> bool:
    t = texto or ""
    c = contexto or ""
    return bool(c.strip()) and bool(_RE_PISTA_CONTINUIDAD.search(t))


def _es_intencion_sintesis_interpretacion(texto: str) -> bool:
    return bool(_RE_PISTA_SINTESIS_INTERPRETACION.search(texto or ""))


def _es_intencion_criticidad(texto: str) -> bool:
    return bool(_RE_PISTA_CRITICIDAD.search(texto or ""))


# -----------------------------------------------------------------------------
# Refuerzos de prompt
# -----------------------------------------------------------------------------

def _reforzar_consulta_compartimiento_aceite(q: str) -> str:
    return (
        q.strip()
        + " | IMPORTANTE: si el usuario menciona motor, transmisión, hidráulico, diferencial, mando final, "
          "reductor o convertidor dentro del contexto de análisis de aceite, interprétalo primero como un valor "
          "del campo descriptivo Compartimiento del hecho de análisis de aceite "
          "(por ejemplo dbo.OilAnalysis.Compartimiento u Oil.LaboratoryData.Compartimiento). "
          "Prefiere filtrar con LIKE sobre Compartimiento. "
          "NO uses dbo.Component.ComponentName salvo que el usuario pida explícitamente el componente maestro, "
          "catálogo de componentes o una dimensión de componente de catálogo."
    )


def _reforzar_consulta_ultimo_ventana(q: str) -> str:
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


def _reforzar_consulta_comparativa(q: str) -> str:
    return (
        q.strip()
        + " | IMPORTANTE: si la consulta implica comparar 2 campos (A vs B), el SELECT DEBE incluir "
          "las 2 métricas y una columna Diferencia = (A - B), y ordenar por Diferencia DESC cuando "
          "se esté limitando la cantidad de filas devueltas."
    )


def _reforzar_consulta_continuidad(q: str) -> str:
    return (
        q.strip()
        + " | IMPORTANTE: la consulta actual depende del contexto conversacional previo. "
          "Resuelve referencias como 'ahora', 'eso', 'de esos resultados', 'los mismos', "
          "'quédate solo con', 'sin volver a listar', manteniendo por defecto el mismo subconjunto, "
          "mismo proyecto, mismas entidades, mismos filtros base y mismo universo ya establecido, "
          "salvo que el usuario indique explícitamente un cambio. "
          "Si el usuario pide reinterpretar, resumir, explicar o priorizar, NO abras un dataset nuevo innecesariamente."
    )


def _reforzar_consulta_sintesis_interpretacion(q: str) -> str:
    return (
        q.strip()
        + " | IMPORTANTE: si el usuario pide explicar, resumir, interpretar, concluir o diagnosticar, "
          "prioriza conservar el mismo conjunto de resultados ya establecido en el contexto. "
          "No amplíes columnas ni cambies de tabla principal sin necesidad. "
          "Si la intención es analítica y no transaccional, mantén el foco en interpretar el subconjunto ya construido."
    )


def _reforzar_consulta_criticidad(q: str) -> str:
    return (
        q.strip()
        + " | IMPORTANTE: si el usuario pide los casos más críticos y no define una regla exacta, "
          "prioriza el orden descendente por las métricas de desgaste o contaminación explícitamente mencionadas "
          "en la consulta actual o presentes en el contexto conversacional inmediato. "
          "Evita inventar umbrales operativos que no existan en la base."
    )


# -----------------------------------------------------------------------------
# API pública del módulo
# -----------------------------------------------------------------------------

def listar_modelos() -> Dict[str, Any]:
    if hasattr(_proveedor, "listar_modelos"):
        return _proveedor.listar_modelos()
    return _proveedor.list_models()  # type: ignore[attr-defined]


async def ping(modelo: Optional[str] = None) -> str:
    if "modelo" in _proveedor.ping.__code__.co_varnames:
        return await _proveedor.ping(modelo=modelo)  # type: ignore[misc]
    if "model" in _proveedor.ping.__code__.co_varnames:
        return await _proveedor.ping(model=modelo)  # type: ignore[misc]
    return await _proveedor.ping(modelo)  # type: ignore[misc]


async def consulta_humana_a_sql(
    consulta_humana: str,
    esquema_json: Dict[str, Any],
    dialecto: str = "postgresql",
    limite_por_defecto: int = 100,
    modelo: Optional[str] = None,
    conversation_context: Optional[str] = None,
) -> str:
    """
    Convierte NL → SQL mediante el proveedor activo.
    """
    q = (consulta_humana or "").strip()
    if not q:
        raise ValueError("consulta_humana vacía")

    contexto = (conversation_context or "").strip()
    base_heuristica = f"{contexto} {q}".strip()
    q_reforzada = q

    heuristicas_aplicadas: List[str] = []

    if _es_intencion_compartimiento_aceite(base_heuristica):
        q_reforzada = _reforzar_consulta_compartimiento_aceite(q_reforzada)
        heuristicas_aplicadas.append("compartimiento_aceite")

    if _es_intencion_comparativa(base_heuristica):
        q_reforzada = _reforzar_consulta_comparativa(q_reforzada)
        heuristicas_aplicadas.append("comparativa")

    if _es_intencion_ultimo_ventana(base_heuristica):
        q_reforzada = _reforzar_consulta_ultimo_ventana(q_reforzada)
        heuristicas_aplicadas.append("ultimo_ventana")

    if _es_intencion_continuidad(q, contexto):
        q_reforzada = _reforzar_consulta_continuidad(q_reforzada)
        heuristicas_aplicadas.append("continuidad")

    if _es_intencion_sintesis_interpretacion(base_heuristica):
        q_reforzada = _reforzar_consulta_sintesis_interpretacion(q_reforzada)
        heuristicas_aplicadas.append("sintesis_interpretacion")

    if _es_intencion_criticidad(base_heuristica):
        q_reforzada = _reforzar_consulta_criticidad(q_reforzada)
        heuristicas_aplicadas.append("criticidad")

    if contexto:
        q_reforzada = (
            q_reforzada.strip()
            + " | IMPORTANTE: considera el contexto conversacional ya proporcionado para resolver referencias como "
              "'eso', 'los mismos', 'ahora compáralo', 'ese componente', 'ese equipo', "
              "'quédate con los más críticos' o solicitudes de continuidad."
        )

    if heuristicas_aplicadas:
        log.debug(
            "[llm.consulta_humana_a_sql] heurísticas=%s consulta=%s",
            ",".join(heuristicas_aplicadas),
            q[:300],
        )

    if hasattr(_proveedor, "consulta_humana_a_sql"):
        try:
            salida = await _proveedor.consulta_humana_a_sql(
                consulta=q_reforzada,
                esquema_json=esquema_json,
                dialecto=dialecto,
                limite_por_defecto=limite_por_defecto,
                modelo=modelo,
                conversation_context=contexto,
            )
        except TypeError:
            salida = await _proveedor.consulta_humana_a_sql(
                consulta=q_reforzada,
                esquema_json=esquema_json,
                dialecto=dialecto,
                limite_por_defecto=limite_por_defecto,
                modelo=modelo,
            )
    else:
        salida = await _proveedor.human_query_to_sql(  # type: ignore[attr-defined]
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

    if heuristicas_aplicadas and not obj.get("heuristicas_aplicadas"):
        obj["heuristicas_aplicadas"] = heuristicas_aplicadas

    return json.dumps(obj, ensure_ascii=False)


async def construir_respuesta(
    filas: List[Dict[str, Any]],
    consulta_humana: str,
    modelo: Optional[str] = None,
) -> str:
    if hasattr(_proveedor, "construir_respuesta"):
        return await _proveedor.construir_respuesta(
            filas=filas,
            consulta_humana=consulta_humana,
            modelo=modelo,
        )
    return await _proveedor.build_answer(  # type: ignore[attr-defined]
        rows=filas,
        human_query=consulta_humana,
        model=modelo,
    )


async def human_query_to_sql(
    human_query: str,
    schema_json: Dict[str, Any],
    dialect: str = "postgresql",
    default_limit: int = 100,
    model: Optional[str] = None,
    conversation_context: Optional[str] = None,
) -> str:
    return await consulta_humana_a_sql(
        consulta_humana=human_query,
        esquema_json=schema_json,
        dialecto=dialect,
        limite_por_defecto=default_limit,
        modelo=model,
        conversation_context=conversation_context,
    )


def extraer_sql_de_json(sql_json: str) -> Optional[str]:
    obj = _json_cauto_loads(sql_json)
    if obj and "sql_query" in obj:
        return str(obj["sql_query"])
    return None