# src/llm.py
# -*- coding: utf-8 -*-
"""
Módulo: llm
-----------
Capa orquestadora entre la API y el proveedor LLM activo (Gemini / OpenAI).

Responsabilidades:
  1. Detectar la intención de la consulta mediante heurísticas regex livianas
     (compartimiento de aceite, ventana CTE, comparativa, continuidad, criticidad…).
  2. Reforzar el prompt con instrucciones adicionales según la intención detectada,
     mejorando la precisión del SQL generado sin modificar la consulta del usuario.
  3. Delegar la generación de SQL al proveedor activo (GeminiProvider u OpenAIProvider).
  4. Construir la respuesta analítica final (build_answer / construir_respuesta).
  5. Exponer aliases en inglés para compatibilidad con código anterior.

Flujo principal:
  consulta_humana_a_sql()
    → detección de heurísticas
    → refuerzo del prompt
    → proveedor.consulta_humana_a_sql()
    → validación del JSON de salida
    → enriquecimiento (original_query, heuristicas_aplicadas)
"""

from __future__ import annotations

import asyncio
import json
import logging
import re
from typing import Any, Dict, List, Optional

from .providers.factory import obtener_proveedor as _obtener_proveedor

log = logging.getLogger(__name__)

_proveedor = _obtener_proveedor()


# ==============================================================================
#  Patrones regex de detección de intención (heurísticas livianas)
#  Se evalúan sobre la consulta del usuario + contexto conversacional.
# ==============================================================================

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
    r"tendencia|estable|incremento|decreciente|descendente|comportamiento|"
    r"patron|patrón|desgaste|contaminacion|contaminación)\b",
    re.IGNORECASE,
)

_RE_PISTA_CRITICIDAD = re.compile(
    r"\b(crítico|critico|críticos|criticos|severo|severa|severos|severas|"
    r"alarma|riesgo|urgente|peor|peores|más\s+alto|mas\s+alto|"
    r"prioriza|priorizalos|priorízalos|ordena|ordenalos|ordénalos)\b",
    re.IGNORECASE,
)

_RE_PISTA_COMPARTIMIENTO_ACEITE = re.compile(
    r"\b(motor|transmision|transmisión|hidraulico|hidráulico|diferencial|mando\s+final|reductor|convertidor)\b",
    re.IGNORECASE,
)

_RE_PISTA_ANALISIS_ACEITE = re.compile(
    r"\b(aceite|ppm|tbn|tan|viscos|muestra|muestreo|horas\s+de\s+aceite|horometro|horómetro|"
    r"fe_ppm|cu_ppm|si_ppm|hierro|cobre|silicio|cromo|plomo|aluminio|indice\s+pq|índice\s+pq)\b",
    re.IGNORECASE,
)

_RE_PISTA_LABORATORIO_ACEITE = re.compile(
    r"\b(muestra[s]?|muestreo|analisis\s+de\s+aceite|análisis\s+de\s+aceite|laboratorio|"
    r"aceite.*reciente|reciente.*aceite|aceite.*ultimo|ultimo.*aceite|aceite.*último|último.*aceite|"
    r"aceite.*detalle|detalle.*aceite|datos.*aceite|aceite.*datos|"
    r"ppm|tbn|tan|viscos|fe_ppm|cu_ppm|si_ppm|al_ppm|b_ppm|ca_ppm|na_ppm|k_ppm|"
    r"grado\s+de\s+aceite|condicion.*aceite|condición.*aceite|aceite.*condicion|aceite.*condición)\b",
    re.IGNORECASE,
)

_RE_PISTA_COMPONENTES_MODELO = re.compile(
    r"\b(componente[s]?|compartimiento[s]?)\b.{0,80}\b(modelo|equipo|maquina|máquina|proyecto)\b"
    r"|\b(modelo|equipo|maquina|máquina|proyecto)\b.{0,80}\b(componente[s]?|compartimiento[s]?)\b"
    r"|\b(qué\s+componentes|cuáles\s+componentes|listar\s+componentes|enlista[r]?\s+componentes"
    r"|dame\s+los\s+componentes|dame\s+los\s+compartimientos|qué\s+compartimientos"
    r"|todos?\s+(?:los?|las?)\s+componentes?|todos?\s+(?:los?|las?)\s+compartimientos?"
    r"|componentes?\s+presentes?|compartimientos?\s+presentes?"
    r"|enl[ií]sta(?:me|te|r)?\s+.*\bcomponentes?\b|enl[ií]sta(?:me|te|r)?\s+.*\bcompartimientos?\b)\b",
    re.IGNORECASE | re.DOTALL,
)

# Detecta consultas de listado/catálogo de entidades dimensionales del negocio
_RE_PISTA_DIMENSIONAL = re.compile(
    # "lista/enlista/enumera + entidad"
    r"\b(?:listar?|enlistar?|enl[ií]sta(?:me|te|r)?|enumerar?)\b"
    r".{0,80}"
    r"\b(proyecto[s]?|modelo[s]?|tipo[s]?|equipo[s]?|flota[s]?|incidente[s]?|falla[s]?|aver[ií]a[s]?)\b"
    r"|"
    # "dame los/las/todos los X" dimensional — requiere artículo directo para evitar falsos positivos
    r"\bdame\b\s+(?:los?|las?|todos?\s+los?|todas?\s+las?|un\s+listado\s+de|el\s+listado\s+de)\s+(?:proyecto[s]?|modelo[s]?|tipo[s]?\s+de\s+equipo[s]?|flota[s]?|incidente[s]?|falla[s]?)\b"
    r"|"
    # "todos los X" dimensional
    r"\btodo[s]?\s+(?:los?|las?)\s+(?:proyecto[s]?|modelo[s]?|tipo[s]?|equipo[s]?|incidente[s]?|falla[s]?)\b"
    r"|"
    # "qué/cuáles/cuántos X (de Y)? hay/existen/tienen" — permite "tipos de equipo hay", "cuántos modelos hay"
    r"\b(?:qu[eé]|cu[aá]les?|cu[aá]ntos?)\s+(?:proyecto[s]?|modelo[s]?|tipo[s]?|equipo[s]?|incidente[s]?|falla[s]?).{0,30}(?:hay|existen?|tiene[n]?|present[e]?[s]?)\b",
    re.IGNORECASE | re.DOTALL,
)

# Detecta menciones de proyecto minero (por nombre o genérico)
_RE_PISTA_PROYECTO_MINERO = re.compile(
    r"\b(proyecto|antapaccay|las\s+bambas|antamina|cerro\s+verde|quellaveco|toromocho|"
    r"cuajone|toquepala|marcona|lagunas\s+norte|bayovar)\b",
    re.IGNORECASE,
)

# Detecta menciones de modelo de equipo (nombres Komatsu / Caterpillar / etc.)
_RE_PISTA_MODELO_EQUIPO = re.compile(
    r"\b(modelo|980e|d475|d375|d155|wa[0-9]+|hd[0-9]+|ht[0-9]+|pc[0-9]+|730e|830e|"
    r"wd[0-9]+|bw[0-9]+|pv[0-9]+|gd[0-9]+|vqc?[0-9]+|wb[0-9]+)\b",
    re.IGNORECASE,
)


# ==============================================================================
#  Utilidades internas
# ==============================================================================

def _json_cauto_loads(s: str) -> Optional[Dict[str, Any]]:
    try:
        obj = json.loads(s or "")
        return obj if isinstance(obj, dict) else None
    except Exception:
        return None


def _es_intencion_componentes_modelo(texto: str) -> bool:
    return bool(_RE_PISTA_COMPONENTES_MODELO.search(texto or ""))


def _es_intencion_compartimiento_aceite(texto: str) -> bool:
    t = texto or ""
    return bool(_RE_PISTA_COMPARTIMIENTO_ACEITE.search(t)) and bool(_RE_PISTA_ANALISIS_ACEITE.search(t))


def _es_intencion_laboratorio_aceite(texto: str) -> bool:
    return bool(_RE_PISTA_LABORATORIO_ACEITE.search(texto or ""))


def _es_intencion_dimensional(texto: str) -> bool:
    return bool(_RE_PISTA_DIMENSIONAL.search(texto or ""))


def _es_intencion_join_proyecto_modelo(texto: str) -> bool:
    """Detecta consultas que cruzan análisis de aceite con proyecto y/o modelo de equipo."""
    t = texto or ""
    tiene_aceite = bool(_RE_PISTA_LABORATORIO_ACEITE.search(t)) or bool(_RE_PISTA_ANALISIS_ACEITE.search(t))
    tiene_proyecto = bool(_RE_PISTA_PROYECTO_MINERO.search(t))
    tiene_modelo = bool(_RE_PISTA_MODELO_EQUIPO.search(t))
    return tiene_aceite and (tiene_proyecto or tiene_modelo)


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


# ==============================================================================
#  Funciones de refuerzo de prompt (inyectadas según heurística detectada)
# ==============================================================================

def _reforzar_consulta_dimensional(q: str) -> str:
    return (
        q.strip()
        + " | IMPORTANTE — TABLAS DIMENSIONALES / CATÁLOGO: "
          "Proyectos mineros → [Mine].[MiningProject] (columnas clave: Name, Department, Client). "
          "Modelos y tipos de equipo → [Mine].[EquipmentFleet] (columnas clave: Model, Type, Description). "
          "Equipos individuales → [Mine].[MiningEquipment] (columnas: Code; "
          "FK EquipmentFleetId → [Mine].[EquipmentFleet]; FK MiningProjectId → [Mine].[MiningProject]). "
          "Para listar todos los componentes/compartimientos distintos → "
          "SELECT DISTINCT [Compartimiento] FROM [Oil].[LaboratoryData] WHERE [Compartimiento] IS NOT NULL. "
          "Incidentes o fallas → buscar en el esquema [Eqpcare] (revisar schema para el nombre exacto de la tabla). "
          "En listados usa SELECT DISTINCT sin métricas agregadas. "
          "En SQL Server: SELECT DISTINCT TOP(N) — DISTINCT siempre antes de TOP."
    )


def _reforzar_join_proyecto_modelo_aceite(q: str) -> str:
    return (
        q.strip()
        + " | IMPORTANTE — CADENA DE JOIN para análisis de aceite con proyecto y/o modelo: "
          "La tabla base de muestras es [Oil].[LaboratoryData] (alias LD). "
          "Para cruzar con proyecto y modelo usa SIEMPRE esta cadena exacta de JOINs: "
          "JOIN [Mine].[MiningEquipment] AS ME ON ME.[Id] = LD.[MiningEquipmentId] "
          "JOIN [Mine].[EquipmentFleet]  AS EF ON EF.[Id] = ME.[EquipmentFleetId] "
          "JOIN [Mine].[MiningProject]   AS MP ON MP.[Id] = ME.[MiningProjectId] . "
          "Filtro por proyecto: WHERE MP.[Name] LIKE '%<NombreProyecto>%'  (no es UUID, es texto). "
          "Filtro por modelo: EF.[Model] contiene el modelo (ej: '980E'); "
          "si el usuario dice '980E-5', interpreta como EF.[Model] = '980E' AND EF.[Type] = '5'. "
          "Si dice solo '980E' sin tipo, filtra con EF.[Model] LIKE '980E%'. "
          "El código legible del equipo está en ME.[Code]. "
          "Si la consulta pide las últimas N muestras POR componente/compartimiento, "
          "usa ROW_NUMBER() OVER (PARTITION BY LD.[Compartimiento] ORDER BY LD.[FechaMuestreo] DESC) AS rn "
          "dentro de un CTE y luego filtra WHERE rn <= N (no rn = 1). "
          "NO pongas TOP ni LIMIT dentro del CTE; aplica el límite solo en el SELECT final."
    )


def _reforzar_tabla_laboratorio_aceite(q: str) -> str:
    return (
        q.strip()
        + " | IMPORTANTE: para consultas sobre muestras de aceite, análisis de aceite o datos de laboratorio, "
          "la tabla principal y preferida es [Oil].[LaboratoryData] (contiene datos en tiempo real). "
          "USA [Oil].[LaboratoryData] como tabla base por defecto. "
          "NO uses [dbo].[OilAnalysis] para este tipo de consultas salvo que el usuario lo pida explícitamente "
          "o que la columna requerida no exista en [Oil].[LaboratoryData]. "
          "Las columnas de muestras (FechaMuestreo, Compartimiento, HorasDeAceite, Horometro, CodigoMuestreo, "
          "Fe_ppm, Cu_ppm, Al_ppm, B_ppm, TBN, TAN, Viscosidad, etc.) están en [Oil].[LaboratoryData]."
    )


def _reforzar_consulta_compartimiento_aceite(q: str) -> str:
    return (
        q.strip()
        + " | IMPORTANTE: si el usuario menciona motor, transmisión, hidráulico, diferencial, mando final, "
          "reductor o convertidor dentro del contexto de análisis de aceite, interprétalo primero como un valor "
          "del campo descriptivo Compartimiento del hecho de análisis de aceite. "
          "La tabla preferida para datos de análisis de aceite es [Oil].[LaboratoryData]; "
          "usa [Oil].[LaboratoryData].[Compartimiento] para filtrar por compartimiento. "
          "Prefiere filtrar con LIKE sobre Compartimiento. "
          "NO uses dbo.Component.ComponentName salvo que el usuario pida explícitamente el componente maestro, "
          "catálogo de componentes o una dimensión de componente de catálogo."
    )


def _reforzar_componentes_modelo(q: str) -> str:
    return (
        q.strip()
        + " | IMPORTANTE: cuando el usuario pida 'componentes' o 'compartimientos' de un equipo o modelo, "
          "los compartimientos se encuentran en el campo Compartimiento de la tabla de análisis de aceite "
          "(tabla preferida: [Oil].[LaboratoryData].[Compartimiento]), NO en tablas de catálogo de componentes. "
          "USA SELECT DISTINCT [LD].[Compartimiento] — NUNCA uses GROUP BY para listar compartimientos, "
          "ya que en SQL Server GROUP BY con alias en ORDER BY genera error 8127. "
          "En SQL Server el orden obligatorio es SELECT DISTINCT TOP (N), NUNCA SELECT TOP (N) DISTINCT "
          "— poner TOP antes de DISTINCT genera error de sintaxis 156. "
          "Filtra con [LD].[Compartimiento] IS NOT NULL directamente en el WHERE, no en COALESCE del SELECT. "
          "Si el usuario menciona un nombre de proyecto (ej: 'Antapaccay'), ese nombre NO es el ID: "
          "haz JOIN [Mine].[MiningEquipment] → [Mine].[MiningProject] para resolver nombre → UUID. "
          "El modelo del equipo está en [Mine].[EquipmentFleet].[Model], no en ninguna otra tabla. "
          "Para obtener compartimientos por modelo, la cadena de JOIN es: "
          "[Mine].[EquipmentFleet] AS EF "
          "JOIN [Mine].[MiningEquipment] AS ME ON ME.[EquipmentFleetId] = EF.[Id] "
          "JOIN [Oil].[LaboratoryData] AS LD ON LD.[MiningEquipmentId] = ME.[Id], "
          "luego SELECT DISTINCT LD.[Compartimiento]. "
          "Si el usuario pide 'cualquier modelo' o 'el primer modelo', usa un CTE o subquery con TOP 1 "
          "sobre [Mine].[EquipmentFleet] para fijar ese modelo, luego obtén sus compartimientos con DISTINCT. "
          "En ORDER BY usa únicamente columnas que aparezcan directamente en el SELECT sin alias compuesto. "
          "No uses COALESCE en el SELECT de compartimientos — selecciona la columna directamente."
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
          "Si el contexto ya contiene un subconjunto previamente filtrado, NO vuelvas al universo completo "
          "ni amplíes el rango temporal por defecto. "
          "Si el usuario pide reinterpretar, resumir, explicar o priorizar, prioriza el subconjunto ya disponible."
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


# ==============================================================================
#  API pública del módulo
# ==============================================================================

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
    q = (consulta_humana or "").strip()
    if not q:
        raise ValueError("consulta_humana vacía")

    contexto = (conversation_context or "").strip()
    base_heuristica = f"{contexto} {q}".strip()
    q_reforzada = q

    heuristicas_aplicadas: List[str] = []

    if _es_intencion_dimensional(base_heuristica):
        q_reforzada = _reforzar_consulta_dimensional(q_reforzada)
        heuristicas_aplicadas.append("dimensional")

    if _es_intencion_laboratorio_aceite(base_heuristica):
        q_reforzada = _reforzar_tabla_laboratorio_aceite(q_reforzada)
        heuristicas_aplicadas.append("laboratorio_aceite")

    if _es_intencion_join_proyecto_modelo(base_heuristica):
        q_reforzada = _reforzar_join_proyecto_modelo_aceite(q_reforzada)
        heuristicas_aplicadas.append("join_proyecto_modelo")

    if _es_intencion_componentes_modelo(base_heuristica):
        q_reforzada = _reforzar_componentes_modelo(q_reforzada)
        heuristicas_aplicadas.append("componentes_modelo")

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


def run_sync_construir_respuesta(
    filas: List[Dict[str, Any]],
    consulta_humana: str,
    modelo: Optional[str] = None,
) -> str:
    return asyncio.run(construir_respuesta(filas, consulta_humana, modelo=modelo))


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


# ==============================================================================
#  Helpers de extracción
# ==============================================================================

def extraer_sql_de_json(sql_json: str) -> Optional[str]:
    obj = _json_cauto_loads(sql_json)
    if obj and "sql_query" in obj:
        return str(obj["sql_query"])
    return None