# src/llm.py
from __future__ import annotations

import json
import logging
import re
from typing import Any, Dict, List, Optional

from .providers.factory import get_provider

logger = logging.getLogger(__name__)

# Singleton simple del provider
_provider = get_provider()


# ============================ Helpers “general” ============================

_COMPARE_HINT_RE = re.compile(
    r"\b(supera|mayor\s+que|menor\s+que|más\s+que|menos\s+que|compar|vs\.?|versus|diferenc|pendien|despach)\b",
    re.IGNORECASE,
)

def _looks_like_comparison_query(human_query: str) -> bool:
    return bool(_COMPARE_HINT_RE.search(human_query or ""))

def _safe_json_loads(s: str) -> Optional[Dict[str, Any]]:
    try:
        obj = json.loads(s or "")
        return obj if isinstance(obj, dict) else None
    except Exception:
        return None

def _enrich_query_for_comparison(human_query: str) -> str:
    """
    Refuerzo general (no atado a ConsumoMARC):
    - Si el usuario pide “lista donde A supera B”, fuerza que el SQL incluya A, B y la diferencia.
    - Deja al provider la decisión de qué columnas exactas usar según el schema.
    """
    return (
        human_query.strip()
        + " | IMPORTANTE: Si la consulta implica comparar 2 campos (A vs B), el SELECT DEBE incluir "
          "las 2 métricas y una columna Diferencia = (A - B), y ordenar por Diferencia DESC cuando haya LIMIT."
    )


# ============================ API pública del módulo ============================

def list_models() -> Dict[str, Any]:
    return _provider.list_models()


async def ping(model: Optional[str] = None) -> str:
    return await _provider.ping(model=model)


async def human_query_to_sql(
    human_query: str,
    schema_json: Dict[str, Any],
    dialect: str = "postgresql",
    default_limit: int = 100,
    model: Optional[str] = None,
) -> str:
    """
    Retorna un JSON string: {"sql_query": "...", "original_query": "..."}
    Compatible con tu main.py (parsea json.loads()).

    Mejora general:
    - Si detecta una intención de comparación (A>B), refuerza el prompt para evitar
      SELECT solo de IDs (caso que te pasaba).
    - No rompe si el provider ya devuelve bien.
    """
    q = (human_query or "").strip()
    if not q:
        raise ValueError("human_query vacío")

    q2 = _enrich_query_for_comparison(q) if _looks_like_comparison_query(q) else q

    out = await _provider.human_query_to_sql(
        human_query=q2,
        schema_json=schema_json,
        dialect=dialect,
        default_limit=default_limit,
        model=model,
    )

    # Validación suave: si no es JSON, lo dejamos tal cual (tu provider ya intenta asegurar JSON)
    obj = _safe_json_loads(out)
    if not obj or "sql_query" not in obj:
        logger.warning("[llm.human_query_to_sql] salida no-JSON o sin sql_query. len=%s", len(out or ""))
        return out

    # Asegura original_query consistente (para trazabilidad)
    if not obj.get("original_query"):
        obj["original_query"] = q
    return json.dumps(obj, ensure_ascii=False)


async def build_answer(
    rows: List[Dict[str, Any]],
    human_query: str,
    model: Optional[str] = None,
) -> str:
    return await _provider.build_answer(
        rows=rows,
        human_query=human_query,
        model=model,
    )