# src/llm.py
# -*- coding: utf-8 -*-
"""
Módulo: llm
-----------
Capa orquestadora sobre el proveedor LLM (Gemini/OpenAI) para:
- NL → SQL: refuerza consultas con intención comparativa y asegura salida JSON.
- build_answer: delega la construcción de respuesta en el proveedor.

Cambios:
- Nombres y comentarios en español.
- Docstrings y logging más claros.
- Compatibilidad: se mantienen alias con los nombres originales en inglés.
"""

from __future__ import annotations

import json
import logging
import re
from typing import Any, Dict, List, Optional

# Compatibilidad con la factoría (maneja ambos nombres: obtener_proveedor/get_provider)
# try:
#     from .providers.factory import obtener_proveedor as _obtener_proveedor
# except Exception:
#     from .providers.factory import get_provider as _obtener_proveedor  # type: ignore

from .providers.factory import obtener_proveedor as _obtener_proveedor

log = logging.getLogger(__name__)

# Singleton simple del proveedor
_proveedor = _obtener_proveedor()


# ============================ Utilidades generales ============================

# Pistas léxicas de consultas de comparación (A vs B, mayor/menor, diferencia, pendiente/despachado, etc.)
_RE_PISTA_COMPARACION = re.compile(
    r"\b(supera|mayor\s+que|menor\s+que|más\s+que|menos\s+que|compar|vs\.?|versus|diferenc|pendien|despach)\b",
    re.IGNORECASE,
)


def _parece_consulta_comparacion(consulta_humana: str) -> bool:
    """Heurística básica para detectar intención comparativa en la consulta natural."""
    return bool(_RE_PISTA_COMPARACION.search(consulta_humana or ""))


def _json_cauto_loads(s: str) -> Optional[Dict[str, Any]]:
    """Carga JSON en modo seguro; devuelve dict o None si no es JSON válido."""
    try:
        obj = json.loads(s or "")
        return obj if isinstance(obj, dict) else None
    except Exception:
        return None


def _reforzar_consulta_comparativa(consulta_humana: str) -> str:
    """
    Refuerzo general (agnóstico al dominio):
    - Si el usuario sugiere comparar 2 campos (A vs B), fuerza que el SQL incluya A, B y la diferencia.
    - El proveedor decide las columnas precisas según el esquema.
    """
    return (
        consulta_humana.strip()
        + " | IMPORTANTE: Si la consulta implica comparar 2 campos (A vs B), el SELECT DEBE incluir "
          "las 2 métricas y una columna Diferencia = (A - B), y ordenar por Diferencia DESC cuando haya LIMIT."
    )


# ============================ API pública del módulo ============================

def listar_modelos() -> Dict[str, Any]:
    """
    Lista los modelos disponibles en el proveedor activo.
    Mantiene la estructura del dict que expone el cliente subyacente.
    """
    return _proveedor.listar_modelos() if hasattr(_proveedor, "listar_modelos") else _proveedor.list_models()


async def ping(modelo: Optional[str] = None) -> str:
    """Ping al proveedor (útil para health-check/latencia básica)."""
    return await _proveedor.ping(model=modelo) if "model" in _proveedor.ping.__code__.co_varnames else await _proveedor.ping(modelo)  # type: ignore


async def consulta_humana_a_sql(
    consulta_humana: str,
    esquema_json: Dict[str, Any],
    dialecto: str = "postgresql",
    limite_por_defecto: int = 100,
    modelo: Optional[str] = None,
) -> str:
    """
    Convierte una consulta natural en SQL seguro, devolviendo:
        {"sql_query": "...", "original_query": "..."}

    Reglas:
    - Refuerza automáticamente consultas con intención comparativa (A > B) para
      evitar SELECT que solo devuelven identificadores.
    - Preserva comportamiento del proveedor; si devuelve JSON inválido, se retorna tal cual
      (el proveedor ya aplica su propio aseguramiento/reparación de JSON).
    """
    q = (consulta_humana or "").strip()
    if not q:
        raise ValueError("consulta_humana vacía")

    q_reforzada = _reforzar_consulta_comparativa(q) if _parece_consulta_comparacion(q) else q

    # Llamada al proveedor (compat: español/inglés)
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

    # Validación suave
    obj = _json_cauto_loads(salida)
    if not obj or "sql_query" not in obj:
        log.warning("[llm.consulta_humana_a_sql] salida no-JSON o sin sql_query. len=%s", len(salida or ""))
        return salida

    # Asegurar original_query para trazabilidad
    if not obj.get("original_query"):
        obj["original_query"] = q
    return json.dumps(obj, ensure_ascii=False)


async def construir_respuesta(
    filas: List[Dict[str, Any]],
    consulta_humana: str,
    modelo: Optional[str] = None,
) -> str:
    """
    Genera un texto de respuesta basado en:
    - filas (resultados SQL)
    - consulta original del usuario
    - modelo a usar (opcional, con fallback interno)

    Delegado 1:1 al proveedor activo.
    """
    if hasattr(_proveedor, "construir_respuesta"):
        return await _proveedor.construir_respuesta(filas=filas, consulta_humana=consulta_humana, modelo=modelo)
    return await _proveedor.build_answer(rows=filas, human_query=consulta_humana, model=modelo)  # type: ignore


