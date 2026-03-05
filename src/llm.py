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

    q_reforzada = _reforzar_consulta_comparativa(q) if _es_intencion_comparativa(q) else q

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