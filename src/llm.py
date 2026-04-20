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
    r"fe_ppm|cu_ppm|si_ppm|al_ppm|cr_ppm|pb_ppm|sn_ppm|ni_ppm|ag_ppm|mn_ppm|"
    r"v_ppm|ti_ppm|cd_ppm|b_ppm|mg_ppm|ca_ppm|zn_ppm|p_ppm|mo_ppm|ba_ppm|"
    r"hierro|cobre|silicio|cromo|plomo|aluminio|niquel|níquel|estaño|plata|manganeso|"
    r"vanadio|titanio|cadmio|boro|magnesio|calcio|zinc|fosforo|fósforo|molibdeno|bario|"
    r"indice\s+pq|índice\s+pq)\b",
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
#  TENDENCIAS HISTÓRICAS: evolución de métricas de aceite en el tiempo
#  "cómo ha variado el Fe", "tendencia del TBN en los últimos 2 años"
# ==============================================================================

_RE_PISTA_TENDENCIA_HISTORICA = re.compile(
    r"\b(tendencia[s]?|evoluci[oó]n|evolucionar?|fluctuaci[oó]n(?:es)?|fluctu[aá]|"
    r"variaci[oó]n|c[oó]mo\s+ha\s+variado|ha\s+variado|c[oó]mo\s+evolucion[oó]|"
    r"a\s+lo\s+largo\s+del\s+tiempo|con\s+el\s+tiempo|en\s+el\s+tiempo|"
    r"hist[oó]rico[s]?|hist[oó]rica[s]?|historial|progresi[oó]n|"
    r"mes\s+a\s+mes|mensual(?:mente)?|por\s+mes|por\s+periodo|"
    r"[uú]ltimos?\s+\d+\s+mes(?:es)?|[uú]ltimos?\s+\d+\s+a[nñ]os?)\b",
    re.IGNORECASE,
)


def _es_intencion_tendencia_historica(texto: str) -> bool:
    return bool(_RE_PISTA_TENDENCIA_HISTORICA.search(texto or ""))


def _reforzar_tendencia_historica(q: str) -> str:
    """
    Guía al LLM a generar SQL de tendencia histórica mensual.
    Usa EOMONTH() como columna de fecha agrupada (devuelve tipo date — compatible con analitica.py).
    AVG por mes reduce filas y suaviza la serie temporal.
    """
    like_compartimiento = _detectar_like_compartimiento(q)
    proyecto = _detectar_proyecto(q)

    filtros = ["LD.[FechaMuestreo]>=DATEADD(MONTH,-24,GETDATE())"]
    joins = "JOIN [Mine].[MiningEquipment] ME WITH (NOLOCK) ON ME.[Id]=LD.[MiningEquipmentId]"
    group_prefix = "LD.[Compartimiento]"

    if like_compartimiento:
        filtros.append(f"LD.[Compartimiento] LIKE '{like_compartimiento}'")
    if proyecto:
        joins += (
            " JOIN [Mine].[MiningProject] MP WITH (NOLOCK) ON MP.[Id]=ME.[MiningProjectId]"
        )
        filtros.append(f"MP.[Name] LIKE '%{proyecto}%'")
        group_prefix = "MP.[Name],LD.[Compartimiento]"

    where_clause = " AND ".join(filtros)

    instruccion = (
        f"SELECT TOP(300) {group_prefix},EOMONTH(LD.[FechaMuestreo]) AS [Mes],"
        "AVG(LD.[Fe_ppm]) AS [Fe_ppm],AVG(LD.[Cu_ppm]) AS [Cu_ppm],"
        "AVG(LD.[Si_ppm]) AS [Si_ppm],AVG(LD.[Al_ppm]) AS [Al_ppm],"
        "AVG(LD.[TBN]) AS [TBN],COUNT(*) AS [Muestras] "
        f"FROM [Oil].[LaboratoryData] LD WITH (NOLOCK) {joins} "
        f"WHERE {where_clause} "
        f"GROUP BY {group_prefix},EOMONTH(LD.[FechaMuestreo]) "
        f"ORDER BY {group_prefix},[Mes]. "
        "EOMONTH() devuelve tipo date — úsalo tal cual, sin CAST. "
        "NUNCA usar ROW_NUMBER/rn para este tipo de consulta. "
        "Si el usuario pide un metal específico, incluirlo como primera métrica AVG."
    )

    return q.strip() + " | TENDENCIA-HISTORICA: " + instruccion


# ==============================================================================
#  CASO DE USO PRINCIPAL: Triage masivo de componentes observados
#  "estado de los 54 motores de tracción → solo los observados"
# ==============================================================================

_RE_PISTA_TRIAGE_OBSERVADOS = re.compile(
    # Estado explícito de observación / anomalía
    r"\b(observado[s]?|con\s+observaci[oó]n|en\s+observaci[oó]n|"
    r"fuera\s+de\s+l[ií]mite[s]?|fuera\s+de\s+rango|fuera\s+de\s+norma|"
    r"con\s+anomal[ií]a[s]?|con\s+alerta[s]?|con\s+problema[s]?|"
    r"necesitan?\s+atenci[oó]n|requieren?\s+atenci[oó]n|"
    r"prestar(?:le)?\s+atenci[oó]n|a\s+(?:los?\s+)?que\s+prestarle\s+atenci[oó]n|"
    # Patrón "estado de los N [componente]"
    r"estado\s+de\s+(?:los?|las?|todos?\s+los?|todas?\s+las?)?\s*\d*\s*"
    r"(?:motor(?:es)?|transmisi[oó]n(?:es)?|componente[s]?|equipo[s]?|compartimiento[s]?|"
    r"mando[s]?\s+final(?:es)?|diferencial(?:es)?|hidr[aá]ulico[s]?|rueda[s]?)|"
    # "cuáles/qué [componentes] están observados/con anomalía"
    r"cu[aá]les?\s+(?:motor(?:es)?|transmisi[oó]n(?:es)?|componente[s]?|equipo[s]?)\s+"
    r"(?:est[aá][ns]?|tienen?|presentan?)\s+(?:observaci[oó]n|anomal[ií]a|problema|alerta|fuera)|"
    r"qu[eé]\s+(?:motor(?:es)?|transmisi[oó]n(?:es)?|componente[s]?|equipo[s]?)\s+"
    r"(?:est[aá][ns]?|tiene[n]?)\s+(?:observaci[oó]n|anomal[ií]a|problema)|"
    # "cuáles están observados / tienen problemas"
    r"cu[aá]les?\s+(?:est[aá][ns]?|tienen?|presentan?)\s+(?:observaci[oó]n|anomal[ií]a|problema|fuera)|"
    # Acción directa de filtrado
    r"filtrar?\s+(?:los?|las?)\s+observados?|"
    r"solo\s+(?:los?|las?)\s+observados?|"
    r"dame\s+(?:los?|las?)\s+observados?|"
    # Masa crítica de componentes sin nombre de metal específico
    r"(?:54|todos?\s+los?)\s+(?:motor(?:es)?\s+de\s+tracci[oó]n|transmisi[oó]n(?:es)?)|"
    r"masa\s+de\s+componentes?|universo\s+de\s+(?:componentes?|equipos?)"
    r")\b",
    re.IGNORECASE,
)


# ==============================================================================
#  Mapeo determinístico: keyword del usuario → filtro LIKE en Compartimiento
#  Se usa en triage_observados para garantizar el filtro en la CTE.
# ==============================================================================

_COMPARTIMIENTO_KEYWORD_MAP: List[tuple] = [
    # (regex de detección, patrón LIKE para SQL)
    (re.compile(r"\btracci[oó]n\b", re.IGNORECASE), "%TRACCION%"),
    (re.compile(r"\bhidr[aá]ulic[ao]\b", re.IGNORECASE), "%HIDRAUL%"),
    (re.compile(r"\brueda[s]?\s+delantera[s]?\b", re.IGNORECASE), "%RUEDA%"),
    (re.compile(r"\bmando\s+final\b", re.IGNORECASE), "%MANDO%"),
    (re.compile(r"\bdiferencial\b", re.IGNORECASE), "%DIFERENCIAL%"),
    (re.compile(r"\btransmisi[oó]n\b", re.IGNORECASE), "%TRANSMISION%"),
]

# Proyectos mineros conocidos: (keyword lowercase, nombre para LIKE)
_PROYECTOS_CONOCIDOS: List[tuple] = [
    ("antapaccay", "Antapaccay"),
    ("las bambas", "Las Bambas"),
    ("antamina", "Antamina"),
    ("cerro verde", "Cerro Verde"),
    ("quellaveco", "Quellaveco"),
    ("toromocho", "Toromocho"),
    ("cuajone", "Cuajone"),
    ("toquepala", "Toquepala"),
    ("marcona", "Marcona"),
    ("lagunas norte", "Lagunas Norte"),
    ("bayovar", "Bayovar"),
]


def _detectar_like_compartimiento(q: str) -> Optional[str]:
    """Detecta el patrón LIKE de compartimiento desde keywords en la consulta."""
    for patron, like in _COMPARTIMIENTO_KEYWORD_MAP:
        if patron.search(q or ""):
            return like
    return None


def _detectar_proyecto(q: str) -> Optional[str]:
    """Detecta el nombre del proyecto minero desde la consulta."""
    q_lower = (q or "").lower()
    for keyword, nombre in _PROYECTOS_CONOCIDOS:
        if keyword in q_lower:
            return nombre
    return None


# ==============================================================================
#  Utilidades internas
# ==============================================================================

def _json_cauto_loads(s: str) -> Optional[Dict[str, Any]]:
    try:
        obj = json.loads(s or "")
        return obj if isinstance(obj, dict) else None
    except Exception:
        return None


def _es_intencion_triage_observados(texto: str) -> bool:
    """Detecta el caso de uso principal: estado masivo de componentes → solo los observados."""
    return bool(_RE_PISTA_TRIAGE_OBSERVADOS.search(texto or ""))


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
        + " | JOIN-ACEITE: base=[Oil].[LaboratoryData] AS LD. "
          "JOIN [Mine].[MiningEquipment] AS ME ON ME.[Id]=LD.[MiningEquipmentId] "
          "JOIN [Mine].[EquipmentFleet] AS EF ON EF.[Id]=ME.[EquipmentFleetId] "
          "JOIN [Mine].[MiningProject] AS MP ON MP.[Id]=ME.[MiningProjectId]. "
          "Proyecto: MP.[Name] LIKE '%nombre%'. Modelo: EF.[Model] LIKE '%modelo%'. Equipo: ME.[Code]. "
          "Siempre: LD.[Compartimiento] IS NOT NULL AND LD.[FechaMuestreo]>=DATEADD(YEAR,-5,GETDATE()). "
          "Última muestra por componente: CTE con ROW_NUMBER() OVER (PARTITION BY LD.[MiningEquipmentId],LD.[Compartimiento] ORDER BY LD.[FechaMuestreo] DESC) AS rn, filtra rn=1 (NUNCA GROUP BY+MAX). TOP(200) en SELECT final."
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


def intentar_tendencia_directo(consulta_humana: str) -> Optional[str]:
    """
    Genera SQL de tendencia histórica mensual directamente en Python.
    Retorna ALL muestras agrupadas por mes — sin filtro LP/LC, sin ROW_NUMBER/rn.
    Solo activa cuando se detecta intención tendencia + compartimiento + proyecto.
    """
    if not _es_intencion_tendencia_historica(consulta_humana):
        return None
    like_comp = _detectar_like_compartimiento(consulta_humana)
    proyecto = _detectar_proyecto(consulta_humana)
    if not like_comp or not proyecto:
        return None

    sql = (
        f"SELECT TOP(300) "
        f"EOMONTH(LD.[FechaMuestreo]) AS [Mes],"
        f"LD.[Compartimiento],"
        f"AVG(LD.[Fe_ppm]) AS [Fe_ppm],"
        f"AVG(LD.[Cu_ppm]) AS [Cu_ppm],"
        f"AVG(LD.[Si_ppm]) AS [Si_ppm],"
        f"AVG(LD.[Al_ppm]) AS [Al_ppm],"
        f"AVG(LD.[TBN]) AS [TBN],"
        f"COUNT(*) AS [Muestras] "
        f"FROM [Oil].[LaboratoryData] LD WITH (NOLOCK) "
        f"JOIN [Mine].[MiningEquipment] ME WITH (NOLOCK) ON ME.[Id]=LD.[MiningEquipmentId] "
        f"JOIN [Mine].[MiningProject] MP WITH (NOLOCK) ON MP.[Id]=ME.[MiningProjectId] "
        f"WHERE LD.[Compartimiento] LIKE '{like_comp}' "
        f"AND MP.[Name] LIKE '%{proyecto}%' "
        f"AND LD.[FechaMuestreo]>=DATEADD(MONTH,-24,GETDATE()) "
        f"GROUP BY EOMONTH(LD.[FechaMuestreo]),LD.[Compartimiento] "
        f"ORDER BY [Mes] ASC"
    )
    return sql


def intentar_triage_directo(consulta_humana: str) -> Optional[str]:
    """
    Genera el SQL de triage directamente en Python cuando compartimiento + proyecto son conocidos.
    Evita la llamada al LLM para el caso de uso principal (mayor confiabilidad que el template LLM).
    Retorna la SQL string lista para ejecutar, o None si no aplica.
    """
    if not _es_intencion_triage_observados(consulta_humana):
        return None
    like_comp = _detectar_like_compartimiento(consulta_humana)
    proyecto = _detectar_proyecto(consulta_humana)
    if not like_comp or not proyecto:
        return None

    # LimitesLC colapsa múltiples filas por modelo en [Eqpcare].[lc]
    # usando MIN para ppm (límite más restrictivo) y MAX para TBN (invertido).
    sql = (
        f"WITH LatestSamples AS ("
        f"SELECT ME.[Code] AS [EquipmentCode],LD.[Compartimiento],"
        f"LD.[Fe_ppm],LD.[Cu_ppm],LD.[Si_ppm],LD.[Al_ppm],LD.[TBN],LD.[FechaMuestreo],"
        f"ROW_NUMBER() OVER (PARTITION BY LD.[MiningEquipmentId],LD.[Compartimiento] "
        f"ORDER BY LD.[FechaMuestreo] DESC) AS rn "
        f"FROM [Oil].[LaboratoryData] LD WITH (NOLOCK) "
        f"JOIN [Mine].[MiningEquipment] ME WITH (NOLOCK) ON ME.[Id]=LD.[MiningEquipmentId] "
        f"JOIN [Mine].[MiningProject] MP WITH (NOLOCK) ON MP.[Id]=ME.[MiningProjectId] "
        f"WHERE LD.[Compartimiento] LIKE '{like_comp}' "
        f"AND MP.[Name] LIKE '%{proyecto}%' "
        f"AND LD.[FechaMuestreo]>=DATEADD(YEAR,-2,GETDATE())"
        f"), "
        f"LimitesLC AS ("
        f"SELECT [COMPONENTE],"
        f"MIN([FIERRO - LP]) AS [FIERRO - LP],MIN([FIERRO - LC]) AS [FIERRO - LC],"
        f"MIN([ALUMINIO - LP]) AS [ALUMINIO - LP],MIN([ALUMINIO - LC]) AS [ALUMINIO - LC],"
        f"MIN([COBRE - LP]) AS [COBRE - LP],MIN([COBRE - LC]) AS [COBRE - LC],"
        f"MIN([SILICIO - LP]) AS [SILICIO - LP],MIN([SILICIO - LC]) AS [SILICIO - LC],"
        f"MAX([TBN - LP]) AS [TBN - LP],MAX([TBN - LC]) AS [TBN - LC] "
        f"FROM [Eqpcare].[lc] WITH (NOLOCK) "
        f"WHERE [Proyecto] LIKE '%{proyecto}%' AND [COMPONENTE] LIKE '{like_comp}' "
        f"GROUP BY [COMPONENTE]"
        f") "
        f"SELECT TOP(200) "
        f"LS.[EquipmentCode],LS.[Compartimiento],"
        f"LS.[Fe_ppm],LS.[Cu_ppm],LS.[Si_ppm],LS.[Al_ppm],LS.[TBN],LS.[FechaMuestreo],"
        f"LC.[FIERRO - LP],LC.[FIERRO - LC],"
        f"LC.[ALUMINIO - LP],LC.[ALUMINIO - LC],"
        f"LC.[COBRE - LP],LC.[COBRE - LC],"
        f"LC.[SILICIO - LP],LC.[SILICIO - LC],"
        f"LC.[TBN - LP],LC.[TBN - LC] "
        f"FROM LatestSamples LS "
        f"LEFT JOIN LimitesLC LC ON LC.[COMPONENTE]=LS.[Compartimiento] "
        f"WHERE LS.rn=1 "
        f"AND ("
        f"LS.[Fe_ppm]>ISNULL(LC.[FIERRO - LP],9999) OR "
        f"LS.[Al_ppm]>ISNULL(LC.[ALUMINIO - LP],9999) OR "
        f"LS.[Cu_ppm]>ISNULL(LC.[COBRE - LP],9999) OR "
        f"LS.[Si_ppm]>ISNULL(LC.[SILICIO - LP],9999) OR "
        f"LS.[TBN]<ISNULL(LC.[TBN - LP],0)"
        f") "
        f"ORDER BY LS.[Fe_ppm] DESC"
    )
    return sql


def _reforzar_triage_observados(q: str) -> str:
    """
    Refuerzo de prompt para el caso de uso PRINCIPAL:
    consulta masiva del estado de N componentes → devolver SOLO los observados.
    Genera SQL eficiente (ROW_NUMBER, WITH NOLOCK, filtro LP/LC) desde el primer intento.
    Si se detecta el tipo de compartimiento en la consulta, inyecta el LIKE como obligatorio
    para evitar escaneos completos de [Oil].[LaboratoryData] que causan timeouts.
    """
    like_compartimiento = _detectar_like_compartimiento(q)
    proyecto = _detectar_proyecto(q)

    # Columnas con espacio/guión en [Eqpcare].[lc] — siempre con corchetes en SQL Server
    _lc_cols = (
        "LC.[FIERRO - LP],LC.[FIERRO - LC],"
        "LC.[ALUMINIO - LP],LC.[ALUMINIO - LC],"
        "LC.[COBRE - LP],LC.[COBRE - LC],"
        "LC.[SILICIO - LP],LC.[SILICIO - LC],"
        "LC.[TBN - LP],LC.[TBN - LC]"
    )
    # Umbral con ISNULL: si LC no tiene fila o columna es NULL → fallback conservador
    _umbral_lc = (
        "LS.[Fe_ppm]>ISNULL(LC.[FIERRO - LP],9999) OR "
        "LS.[Al_ppm]>ISNULL(LC.[ALUMINIO - LP],9999) OR "
        "LS.[Cu_ppm]>ISNULL(LC.[COBRE - LP],9999) OR "
        "LS.[Si_ppm]>ISNULL(LC.[SILICIO - LP],9999) OR "
        "LS.[TBN]<ISNULL(LC.[TBN - LP],0)"
    )

    # CTE de límites: colapsa múltiples filas por modelo con MIN (ppm) y MAX (TBN invertido)
    _limites_cte_con_proyecto = (
        f"LimitesLC AS ("
        f"SELECT [COMPONENTE],"
        f"MIN([FIERRO - LP]) AS [FIERRO - LP],MIN([FIERRO - LC]) AS [FIERRO - LC],"
        f"MIN([ALUMINIO - LP]) AS [ALUMINIO - LP],MIN([ALUMINIO - LC]) AS [ALUMINIO - LC],"
        f"MIN([COBRE - LP]) AS [COBRE - LP],MIN([COBRE - LC]) AS [COBRE - LC],"
        f"MIN([SILICIO - LP]) AS [SILICIO - LP],MIN([SILICIO - LC]) AS [SILICIO - LC],"
        f"MAX([TBN - LP]) AS [TBN - LP],MAX([TBN - LC]) AS [TBN - LC] "
        f"FROM [Eqpcare].[lc] WITH (NOLOCK) "
        f"WHERE [Proyecto] LIKE '%{proyecto}%' AND [COMPONENTE] LIKE '{like_compartimiento}' "
        f"GROUP BY [COMPONENTE])"
    ) if proyecto else (
        f"LimitesLC AS ("
        f"SELECT [COMPONENTE],"
        f"MIN([FIERRO - LP]) AS [FIERRO - LP],MIN([FIERRO - LC]) AS [FIERRO - LC],"
        f"MIN([ALUMINIO - LP]) AS [ALUMINIO - LP],MIN([ALUMINIO - LC]) AS [ALUMINIO - LC],"
        f"MIN([COBRE - LP]) AS [COBRE - LP],MIN([COBRE - LC]) AS [COBRE - LC],"
        f"MIN([SILICIO - LP]) AS [SILICIO - LP],MIN([SILICIO - LC]) AS [SILICIO - LC],"
        f"MAX([TBN - LP]) AS [TBN - LP],MAX([TBN - LC]) AS [TBN - LC] "
        f"FROM [Eqpcare].[lc] WITH (NOLOCK) "
        f"WHERE [COMPONENTE] LIKE '{like_compartimiento}' "
        f"GROUP BY [COMPONENTE])"
    ) if like_compartimiento else (
        "LimitesLC AS ("
        "SELECT [COMPONENTE],"
        "MIN([FIERRO - LP]) AS [FIERRO - LP],MIN([FIERRO - LC]) AS [FIERRO - LC],"
        "MIN([ALUMINIO - LP]) AS [ALUMINIO - LP],MIN([ALUMINIO - LC]) AS [ALUMINIO - LC],"
        "MIN([COBRE - LP]) AS [COBRE - LP],MIN([COBRE - LC]) AS [COBRE - LC],"
        "MIN([SILICIO - LP]) AS [SILICIO - LP],MIN([SILICIO - LC]) AS [SILICIO - LC],"
        "MAX([TBN - LP]) AS [TBN - LP],MAX([TBN - LC]) AS [TBN - LC] "
        "FROM [Eqpcare].[lc] WITH (NOLOCK) GROUP BY [COMPONENTE])"
    )

    if like_compartimiento and proyecto:
        instruccion_cte = (
            f"2 CTEs: LatestSamples y LimitesLC. "
            f"LatestSamples: JOINs a ME y MP WITH (NOLOCK). "
            f"SELECT SIN TOP: ME.[Code] AS [EquipmentCode], LD.[Compartimiento], LD.[Fe_ppm], LD.[Cu_ppm], LD.[Si_ppm], LD.[Al_ppm], LD.[TBN], LD.[FechaMuestreo], "
            f"ROW_NUMBER() OVER (PARTITION BY LD.[MiningEquipmentId],LD.[Compartimiento] ORDER BY LD.[FechaMuestreo] DESC) AS rn. "
            f"WHERE: LD.[Compartimiento] LIKE '{like_compartimiento}' AND MP.[Name] LIKE '%{proyecto}%' AND LD.[FechaMuestreo]>=DATEADD(YEAR,-2,GETDATE()). "
            f"{_limites_cte_con_proyecto}. "
            f"SELECT externo: SELECT TOP(200) LS.[EquipmentCode],LS.[Compartimiento],LS.[Fe_ppm],LS.[Cu_ppm],LS.[Si_ppm],LS.[Al_ppm],LS.[TBN],LS.[FechaMuestreo],{_lc_cols} "
            f"FROM LatestSamples LS LEFT JOIN LimitesLC LC ON LC.[COMPONENTE]=LS.[Compartimiento] "
            f"WHERE LS.rn=1 AND ({_umbral_lc}). "
        )
    elif like_compartimiento:
        instruccion_cte = (
            f"2 CTEs: LatestSamples y LimitesLC. "
            f"LatestSamples: JOIN a ME WITH (NOLOCK). "
            f"SELECT SIN TOP: ME.[Code] AS [EquipmentCode], LD.[Compartimiento], LD.[Fe_ppm], LD.[Cu_ppm], LD.[Si_ppm], LD.[Al_ppm], LD.[TBN], LD.[FechaMuestreo], "
            f"ROW_NUMBER() OVER (PARTITION BY LD.[MiningEquipmentId],LD.[Compartimiento] ORDER BY LD.[FechaMuestreo] DESC) AS rn. "
            f"WHERE: LD.[Compartimiento] LIKE '{like_compartimiento}' AND LD.[FechaMuestreo]>=DATEADD(YEAR,-2,GETDATE()). "
            f"{_limites_cte_con_proyecto}. "
            f"SELECT externo: SELECT TOP(200) LS.[EquipmentCode],LS.[Compartimiento],LS.[Fe_ppm],LS.[Cu_ppm],LS.[Si_ppm],LS.[Al_ppm],LS.[TBN],LS.[FechaMuestreo],{_lc_cols} "
            f"FROM LatestSamples LS LEFT JOIN LimitesLC LC ON LC.[COMPONENTE]=LS.[Compartimiento] "
            f"WHERE LS.rn=1 AND ({_umbral_lc}). "
        )
    else:
        instruccion_cte = (
            "Compartimiento: usa keyword simple (ej: '%TRACCION%', '%HIDRAUL%'). "
            "2 CTEs: LatestSamples y LimitesLC. LatestSamples: JOIN a ME. "
            "SELECT SIN TOP: ME.[Code] AS [EquipmentCode], columnas LD, "
            "ROW_NUMBER() OVER (PARTITION BY LD.[MiningEquipmentId],LD.[Compartimiento] ORDER BY LD.[FechaMuestreo] DESC) AS rn. "
            f"LimitesLC: {_limites_cte_con_proyecto}. "
            f"SELECT externo: SELECT TOP(200) LS.[EquipmentCode],LS.[Compartimiento],LS.[Fe_ppm],LS.[Cu_ppm],LS.[Si_ppm],LS.[Al_ppm],LS.[TBN],LS.[FechaMuestreo],{_lc_cols} "
            "FROM LatestSamples LS LEFT JOIN LimitesLC LC ON LC.[COMPONENTE]=LS.[Compartimiento] "
            f"WHERE LS.rn=1 AND ({_umbral_lc}). "
        )
    return (
        q.strip()
        + " | TRIAGE-OBSERVADOS: "
          "CTE con ROW_NUMBER (NUNCA GROUP BY+MAX — BD tiene duplicados por fecha). "
          "NUNCA poner TOP dentro de ningún CTE. WITH (NOLOCK) en todos los FROM/JOIN de datos. "
        + instruccion_cte
        + "JOINs en LatestSamples: SOLO [Mine].[MiningEquipment] y [Mine].[MiningProject] — NUNCA [Mine].[EquipmentFleet]. "
          "Compartimiento — valores reales: 'MOTOR DE TRACCION RH/LH', 'SISTEMA HIDRAULICO', 'MOTOR', 'RUEDA DELANTERA RH/LH'. "
          "NUNCA '%MOTOR TRACCION%'. Motor sin tracción → LIKE '%MOTOR%' AND NOT LIKE '%TRACCION%'. "
          "Columnas [Eqpcare].[lc] con espacios usan corchetes: [FIERRO - LP], [TBN - LP]. "
          "DEVUELVE SOLO observados. 0 filas=válido. ORDER BY LS.[Fe_ppm] DESC."
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

    # Detectar proyecto y compartimiento al inicio — usados en triage y para suprimir
    # heurísticas redundantes que añaden EquipmentFleet (puede no estar en allowed_fqn).
    _triage_like_comp = _detectar_like_compartimiento(base_heuristica)
    _triage_proyecto = _detectar_proyecto(base_heuristica)
    _triage_cte_completo = bool(_triage_like_comp and _triage_proyecto)

    # ── PRIORIDAD MÁXIMA: caso de uso principal del producto ──────────────────
    # "estado de los N motores → solo los observados"
    # Se evalúa primero para que el prompt triage domine sobre heurísticas generales.
    if _es_intencion_triage_observados(base_heuristica):
        q_reforzada = _reforzar_triage_observados(q_reforzada)
        heuristicas_aplicadas.append("triage_observados")
        # Forzar join_proyecto_modelo SOLO si el triage no inyectó JOINs específicos.
        # Cuando _triage_cte_completo=True, el prompt ya tiene MiningEquipment+MiningProject
        # sin EquipmentFleet — agregar join_proyecto_modelo causaría SQL con EquipmentFleet
        # que puede no estar en allowed_fqn → blindar 400 → segunda llamada LLM innecesaria.
        if not _triage_cte_completo and not _es_intencion_join_proyecto_modelo(base_heuristica):
            q_reforzada = _reforzar_join_proyecto_modelo_aceite(q_reforzada)
            heuristicas_aplicadas.append("join_proyecto_modelo")

    if _es_intencion_dimensional(base_heuristica):
        q_reforzada = _reforzar_consulta_dimensional(q_reforzada)
        heuristicas_aplicadas.append("dimensional")

    if _es_intencion_laboratorio_aceite(base_heuristica):
        q_reforzada = _reforzar_tabla_laboratorio_aceite(q_reforzada)
        heuristicas_aplicadas.append("laboratorio_aceite")

    # join_proyecto_modelo: suprimir cuando triage ya especificó los JOINs completos
    # (evita que Flash incluya EquipmentFleet y provoque rechazo en blindar_sql).
    if not _triage_cte_completo and _es_intencion_join_proyecto_modelo(base_heuristica):
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

    # Tendencia histórica: solo si NO es triage (triage devuelve última muestra, no serie temporal)
    if (
        _es_intencion_tendencia_historica(base_heuristica)
        and "triage_observados" not in heuristicas_aplicadas
    ):
        q_reforzada = _reforzar_tendencia_historica(q_reforzada)
        heuristicas_aplicadas.append("tendencia_historica")

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