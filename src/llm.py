# src/llm.py
# -*- coding: utf-8 -*-
"""
Módulo: llm
-----------
Capa orquestadora entre la API y el proveedor LLM activo (Gemini / OpenAI).

Antes de delegar al modelo de lenguaje, este módulo analiza la consulta del usuario
con heurísticas livianas (regex) para detectar la intención y enriquecer el prompt
con instrucciones SQL específicas del dominio. Esto compensa las limitaciones de los
modelos al generar SQL para una base de datos con quirks propios (duplicados por fecha,
columnas con guión, UUIDs como PK, esquemas separados por área, etc.).

Responsabilidades principales:
  1. Detectar la intención de la consulta (triage, tendencia, historial crudo, etc.).
  2. Intentar generar SQL directamente en Python para los casos bien definidos,
     sin pasar por el LLM (más rápido, más confiable, sin alucinaciones).
  3. Reforzar el prompt con instrucciones adicionales para los casos que sí van al LLM.
  4. Delegar la generación de SQL al proveedor activo (GeminiProvider u OpenAIProvider).
  5. Construir la respuesta analítica final en lenguaje natural (cuando se activa).

Flujo de despacho para /human_query:
  main.py
    → intentar_historial_crudo_directo()   # muestra a muestra, sin promediar
    → intentar_tendencia_directo()         # serie mensual AVG, sin LLM
    → intentar_triage_directo()            # triage con límites LP/LC reales
    → consulta_humana_a_sql()              # LLM + refuerzos de heurística
"""

from __future__ import annotations

import asyncio
import datetime
import json
import logging
import re
from typing import Any, Dict, List, Optional

from .providers.factory import obtener_proveedor as _obtener_proveedor

log = logging.getLogger(__name__)

# Proveedor LLM activo, instanciado una sola vez al importar el módulo.
# Se selecciona en función de la variable de entorno LLM_PROVIDER (.env).
_proveedor = _obtener_proveedor()


# ==============================================================================
#  PATRONES REGEX DE DETECCIÓN DE INTENCIÓN
#
#  Cada patrón identifica un tipo de consulta o intención del usuario.
#  Se evalúan sobre la consulta actual + el contexto conversacional acumulado,
#  lo que permite capturar referencias como "de esos resultados" o "el mismo equipo".
#
#  Criterio de diseño: preferir falsos positivos (activar un refuerzo innecesario)
#  sobre falsos negativos (no activar el refuerzo cuando se necesita).
#  Un refuerzo de más rara vez rompe; un refuerzo de menos sí puede dar SQL incorrecto.
# ==============================================================================

# Consultas que comparan dos valores, métricas o entidades entre sí.
_RE_PISTA_COMPARACION = re.compile(
    r"\b(supera|mayor\s+que|menor\s+que|más\s+que|menos\s+que|compar|vs\.?|versus|diferenc|pendien|despach)\b",
    re.IGNORECASE,
)

# Consultas que piden la última muestra, el registro más reciente o usan ventanas analíticas.
_RE_PISTA_ULTIMO_VENTANA = re.compile(
    r"\b(ultimo|último|mas\s+reciente|más\s+reciente|row_number|rank|dense_rank|over\s*\(|partition\s+by|cte|ventana)\b",
    re.IGNORECASE,
)

# Exclusión explícita de nulos — el usuario lo pide directamente.
_RE_PISTA_EXCLUSION_NULOS = re.compile(
    r"\b(sin\s+nulos|sin\s+null|no\s+nulo|no\s+null|excluir\s+nulos|excluir\s+null|solo\s+con\s+valor|solo\s+con\s+datos|solo\s+disponibles)\b",
    re.IGNORECASE,
)

# Referencias deícticas que indican que la consulta depende del contexto previo.
# "eso", "de esos resultados", "quédate solo con", "los mismos", etc.
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

# Peticiones de interpretación, resumen o diagnóstico sobre datos ya obtenidos.
_RE_PISTA_SINTESIS_INTERPRETACION = re.compile(
    r"\b(explica|explícame|explicame|interpreta|interpretación|interpretacion|"
    r"resume|resumen|concluye|conclusión|conclusion|diagnostica|diagnóstico|diagnostico|"
    r"tendencia|estable|incremento|decreciente|descendente|comportamiento|"
    r"patron|patrón|desgaste|contaminacion|contaminación)\b",
    re.IGNORECASE,
)

# Peticiones de priorización o filtro por severidad: "los más críticos", "peores", etc.
_RE_PISTA_CRITICIDAD = re.compile(
    r"\b(crítico|critico|críticos|criticos|severo|severa|severos|severas|"
    r"alarma|riesgo|urgente|peor|peores|más\s+alto|mas\s+alto|"
    r"prioriza|priorizalos|priorízalos|ordena|ordenalos|ordénalos)\b",
    re.IGNORECASE,
)

# Mención de un compartimiento o sistema mecánico (motor, hidráulico, etc.)
# dentro del contexto de análisis de aceite.
_RE_PISTA_COMPARTIMIENTO_ACEITE = re.compile(
    r"\b(motor|transmision|transmisión|hidraulico|hidráulico|diferencial|mando\s+final|reductor|convertidor)\b",
    re.IGNORECASE,
)

# Mención de métricas o conceptos de análisis de aceite (ppm, TBN, viscosidad, metales, etc.)
_RE_PISTA_ANALISIS_ACEITE = re.compile(
    r"\b(aceite|ppm|tbn|tan|viscos|muestra|muestreo|horas\s+de\s+aceite|horometro|horómetro|"
    r"fe_ppm|cu_ppm|si_ppm|al_ppm|cr_ppm|pb_ppm|sn_ppm|ni_ppm|ag_ppm|mn_ppm|"
    r"v_ppm|ti_ppm|cd_ppm|b_ppm|mg_ppm|ca_ppm|zn_ppm|p_ppm|mo_ppm|ba_ppm|"
    r"hierro|cobre|silicio|cromo|plomo|aluminio|niquel|níquel|estaño|plata|manganeso|"
    r"vanadio|titanio|cadmio|boro|magnesio|calcio|zinc|fosforo|fósforo|molibdeno|bario|"
    r"indice\s+pq|índice\s+pq)\b",
    re.IGNORECASE,
)

# Consultas orientadas a datos de laboratorio: muestras, análisis, condición del aceite.
_RE_PISTA_LABORATORIO_ACEITE = re.compile(
    r"\b(muestra[s]?|muestreo|analisis\s+de\s+aceite|análisis\s+de\s+aceite|laboratorio|"
    r"aceite.*reciente|reciente.*aceite|aceite.*ultimo|ultimo.*aceite|aceite.*último|último.*aceite|"
    r"aceite.*detalle|detalle.*aceite|datos.*aceite|aceite.*datos|"
    r"ppm|tbn|tan|viscos|fe_ppm|cu_ppm|si_ppm|al_ppm|b_ppm|ca_ppm|na_ppm|k_ppm|"
    r"grado\s+de\s+aceite|condicion.*aceite|condición.*aceite|aceite.*condicion|aceite.*condición)\b",
    re.IGNORECASE,
)

# Consultas que piden los compartimientos o componentes de un modelo/equipo/proyecto.
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

# Consultas que piden catálogos o dimensiones del negocio: proyectos, modelos, flotas, tipos de equipo.
_RE_PISTA_DIMENSIONAL = re.compile(
    # "lista/enlista/enumera + entidad dimensional"
    r"\b(?:listar?|enlistar?|enl[ií]sta(?:me|te|r)?|enumerar?)\b"
    r".{0,80}"
    r"\b(proyecto[s]?|modelo[s]?|tipo[s]?|equipo[s]?|flota[s]?|incidente[s]?|falla[s]?|aver[ií]a[s]?)\b"
    r"|"
    # "dame los/todas los X" con artículo directo — evita capturar frases genéricas
    r"\bdame\b\s+(?:los?|las?|todos?\s+los?|todas?\s+las?|un\s+listado\s+de|el\s+listado\s+de)\s+(?:proyecto[s]?|modelo[s]?|tipo[s]?\s+de\s+equipo[s]?|flota[s]?|incidente[s]?|falla[s]?)\b"
    r"|"
    # "todos los X" dimensional
    r"\btodo[s]?\s+(?:los?|las?)\s+(?:proyecto[s]?|modelo[s]?|tipo[s]?|equipo[s]?|incidente[s]?|falla[s]?)\b"
    r"|"
    # "qué/cuáles/cuántos X hay" — cubre "tipos de equipo hay", "cuántos modelos existen"
    r"\b(?:qu[eé]|cu[aá]les?|cu[aá]ntos?)\s+(?:proyecto[s]?|modelo[s]?|tipo[s]?|equipo[s]?|incidente[s]?|falla[s]?).{0,30}(?:hay|existen?|tiene[n]?|present[e]?[s]?)\b",
    re.IGNORECASE | re.DOTALL,
)

# Mención explícita de proyecto minero por nombre propio.
_RE_PISTA_PROYECTO_MINERO = re.compile(
    r"\b(proyecto|antapaccay|las\s+bambas|antamina|cerro\s+verde|quellaveco|toromocho|"
    r"cuajone|toquepala|marcona|lagunas\s+norte|bayovar)\b",
    re.IGNORECASE,
)

# Mención de modelo de equipo (nomenclaturas Komatsu, Caterpillar, etc.)
_RE_PISTA_MODELO_EQUIPO = re.compile(
    r"\b(modelo|980e|930e|d475|d375|d155|wa[0-9]+|hd[0-9]+|ht[0-9]+|pc[0-9]+|730e|830e|"
    r"wd[0-9]+|bw[0-9]+|pv[0-9]+|gd[0-9]+|vqc?[0-9]+|wb[0-9]+)\b",
    re.IGNORECASE,
)


# ==============================================================================
#  TENDENCIAS HISTÓRICAS
#
#  Detecta consultas del tipo "cómo ha variado el Fe en los últimos 2 años",
#  "tendencia mensual del TBN", "evolución mes a mes", "histórico de X".
#
#  Exclusión mutua con triage: si el usuario pide tendencia de los "observados",
#  triage tiene prioridad (interesa la última muestra con límites, no la serie).
#  Exclusión mutua con muestras_individuales: si el usuario pide datos sin promediar,
#  el LLM genera SELECT plano sin GROUP BY (tendencia_directo retorna None).
# ==============================================================================

_RE_PISTA_TENDENCIA_HISTORICA = re.compile(
    r"\b(tendencia[s]?|evoluci[oó]n|evolucionar?|fluctuaci[oó]n(?:es)?|fluctu[aá]|"
    r"variaci[oó]n|c[oó]mo\s+ha\s+variado|ha\s+variado|c[oó]mo\s+evolucion[oó]|"
    r"a\s+lo\s+largo\s+del\s+tiempo|con\s+el\s+tiempo|en\s+el\s+tiempo|"
    r"hist[oó]rico[s]?|hist[oó]rica[s]?|progresi[oó]n|"
    r"mes\s+a\s+mes|mensual(?:mente)?|por\s+mes|por\s+periodo|"
    r"[uú]ltimos?\s+\d+\s+mes(?:es)?|[uú]ltimos?\s+\d+\s+a[nñ]os?)\b",
    re.IGNORECASE,
)

# Cuando el usuario pide registros individuales sin agregar ("muestra por muestra",
# "sin promediar", "todas las fechas"), tendencia_directo cede al LLM.
# Esto evita que el LLM reutilice el patrón CTE+ROW_NUMBER del contexto de triage
# y devuelva solo 1 muestra en lugar del historial completo.
_RE_MUESTRAS_INDIVIDUALES = re.compile(
    r"\b(sin\s+promediar|muestra\s+[a-z]*\s*muestra|muestra\s+a\s+muestra|"
    r"cada\s+muestra|muestra[s]?\s+individual(?:es)?|muestra[s]?\s+real(?:es)?|"
    r"registro[s]?\s+individual(?:es)?|registro[s]?\s+crudo[s]?|"
    r"sin\s+agrupar|dato[s]?\s+crudo[s]?|fecha[s]?\s+exacta[s]?|"
    r"todas\s+las\s+fechas|todas\s+las\s+muestras|"
    r"historial|dame\s+el\s+historial|ver\s+el\s+historial)\b",
    re.IGNORECASE,
)


def _es_intencion_tendencia_historica(texto: str) -> bool:
    return bool(_RE_PISTA_TENDENCIA_HISTORICA.search(texto or ""))


def _es_intencion_muestras_individuales(texto: str) -> bool:
    """Detecta cuando el usuario quiere registros crudos, no promedios mensuales."""
    return bool(_RE_MUESTRAS_INDIVIDUALES.search(texto or ""))


def _reforzar_tendencia_historica(q: str) -> str:
    """
    Refuerzo de prompt para tendencia histórica cuando intentar_tendencia_directo()
    devuelve None (sin compartimiento detectado → el LLM debe inferirlo).

    Notas importantes que el LLM debe respetar:
    - EOMONTH() en SQL Server devuelve tipo 'date', no datetime. Compatible con _a_fecha().
    - AVG mensual suaviza picos puntuales y reduce el número de filas al LLM.
    - NUNCA ROW_NUMBER/rn=1: para tendencia se necesitan todas las muestras, no solo la última.
    """
    like_compartimiento = _detectar_like_compartimiento(q)
    proyecto = _detectar_proyecto(q)

    # Construir filtros y JOINs según lo que se detectó en la consulta.
    filtros = ["LD.[FechaMuestreo]>=DATEADD(MONTH,-24,GETDATE())"]
    joins = "JOIN [Mine].[MiningEquipment] ME WITH (NOLOCK) ON ME.[Id]=LD.[MiningEquipmentId]"
    group_prefix = "LD.[Compartimiento]"

    if like_compartimiento:
        filtros.append(f"LD.[Compartimiento] LIKE '{like_compartimiento}'")
    if proyecto:
        # Si hay proyecto, añadir el JOIN a MiningProject y agrupar también por proyecto.
        joins += (
            " JOIN [Mine].[MiningProject] MP WITH (NOLOCK) ON MP.[Id]=ME.[MiningProjectId]"
        )
        filtros.append(f"MP.[Name] LIKE '%{proyecto}%'")
        group_prefix = "MP.[Name],LD.[Compartimiento]"

    where_clause = " AND ".join(filtros)

    instruccion = (
        f"SELECT TOP(300) {group_prefix},EOMONTH(LD.[FechaMuestreo]) AS [Mes],"
        "AVG(LD.[Fe_ppm]) AS [Fe_ppm],AVG(LD.[Cr_ppm]) AS [Cr_ppm],"
        "AVG(LD.[Ni_ppm]) AS [Ni_ppm],AVG(LD.[Pb_ppm]) AS [Pb_ppm],"
        "AVG(LD.[Sn_ppm]) AS [Sn_ppm],AVG(LD.[Cu_ppm]) AS [Cu_ppm],"
        "AVG(LD.[Si_ppm]) AS [Si_ppm],AVG(LD.[Al_ppm]) AS [Al_ppm],"
        "AVG(LD.[Indice_PQ]) AS [Indice_PQ],AVG(LD.[TBN]) AS [TBN],"
        "COUNT(*) AS [Muestras] "
        f"FROM [Oil].[LaboratoryData] LD WITH (NOLOCK) {joins} "
        f"WHERE {where_clause} "
        f"GROUP BY {group_prefix},EOMONTH(LD.[FechaMuestreo]) "
        f"ORDER BY {group_prefix},[Mes] "
        "— EOMONTH() devuelve tipo date, úsalo sin CAST. "
        "NUNCA usar ROW_NUMBER/rn para este tipo de consulta. "
        "Si el usuario pide un metal específico, incluirlo como primera métrica AVG."
    )

    return q.strip() + " | TENDENCIA-HISTORICA: " + instruccion


# ==============================================================================
#  CASO DE USO PRINCIPAL: Triage masivo de componentes observados
#
#  El escenario más frecuente del producto: el usuario pregunta por el estado
#  del universo completo de un tipo de componente (ej: "54 motores de tracción
#  de Antapaccay") y el sistema devuelve SOLO los que están fuera de límites LP/LC.
#
#  0 filas es una respuesta válida ("ningún componente observado en este momento").
#  Nunca debe tratarse como error ni disparar el retry de resultado vacío.
#
#  Flujo de despacho (en main.py):
#    1. intentar_historial_crudo_directo()  → muestra a muestra, sin promediar
#    2. intentar_tendencia_directo()        → serie mensual AVG, bypasa LLM
#    3. intentar_triage_directo()           → doble CTE con LP/LC reales
#    4. LLM + _reforzar_triage_observados() → caso general sin proyecto o compartimiento conocido
# ==============================================================================

_RE_PISTA_TRIAGE_OBSERVADOS = re.compile(
    # Estado explícito de observación / anomalía operativa
    r"\b(observad[ao]s?|condici[oó]n\s+observad[ao]|con\s+observaci[oó]n|en\s+observaci[oó]n|"
    r"fuera\s+de\s+l[ií]mite[s]?|fuera\s+de\s+rango|fuera\s+de\s+norma|"
    r"con\s+anomal[ií]a[s]?|con\s+alerta[s]?|con\s+problema[s]?|"
    r"necesitan?\s+atenci[oó]n|requieren?\s+atenci[oó]n|"
    r"prestar(?:le)?\s+atenci[oó]n|a\s+(?:los?\s+)?que\s+prestarle\s+atenci[oó]n|"
    # Patrón "estado de los N [componente]" — captura "estado de los 54 motores"
    r"estado\s+de\s+(?:los?|las?|todos?\s+los?|todas?\s+las?)?\s*\d*\s*"
    r"(?:motor(?:es)?|transmisi[oó]n(?:es)?|componente[s]?|equipo[s]?|compartimiento[s]?|"
    r"mando[s]?\s+final(?:es)?|diferencial(?:es)?|hidr[aá]ulico[s]?|rueda[s]?)|"
    # "cuáles/qué [componentes] están observados/con anomalía"
    r"cu[aá]les?\s+(?:motor(?:es)?|transmisi[oó]n(?:es)?|componente[s]?|equipo[s]?)\s+"
    r"(?:est[aá][ns]?|tienen?|presentan?)\s+(?:observaci[oó]n|anomal[ií]a|problema|alerta|fuera)|"
    r"qu[eé]\s+(?:motor(?:es)?|transmisi[oó]n(?:es)?|componente[s]?|equipo[s]?)\s+"
    r"(?:est[aá][ns]?|tiene[n]?)\s+(?:observaci[oó]n|anomal[ií]a|problema)|"
    # "cuáles están observados / tienen problemas" (forma corta)
    r"cu[aá]les?\s+(?:est[aá][ns]?|tienen?|presentan?)\s+(?:observaci[oó]n|anomal[ií]a|problema|fuera)|"
    # Verbos de acción directa sobre el subconjunto observado
    r"filtrar?\s+(?:los?|las?)\s+observados?|"
    r"solo\s+(?:los?|las?)\s+observados?|"
    r"dame\s+(?:los?|las?)\s+observados?|"
    # Masa crítica de componentes sin metal específico mencionado
    r"(?:54|todos?\s+los?)\s+(?:motor(?:es)?\s+de\s+tracci[oó]n|transmisi[oó]n(?:es)?)|"
    r"masa\s+de\s+componentes?|universo\s+de\s+(?:componentes?|equipos?)"
    r")\b",
    re.IGNORECASE,
)


# ==============================================================================
#  MAPEO DETERMINÍSTICO: keyword → filtro LIKE en Compartimiento
#
#  Los valores reales del campo [Oil].[LaboratoryData].[Compartimiento] son:
#    'MOTOR DE TRACCION RH', 'MOTOR DE TRACCION LH'
#    'RUEDA DELANTERA RH', 'RUEDA DELANTERA LH'
#    'SISTEMA HIDRAULICO', 'MOTOR'
#
#  Usar keyword único en el LIKE, no frase compuesta:
#    ✅ '%TRACCION%'  (captura RH y LH con un solo patrón)
#    ❌ '%MOTOR TRACCION%'  (falla porque el valor real tiene "DE" en medio)
# ==============================================================================

_COMPARTIMIENTO_KEYWORD_MAP: List[tuple] = [
    # (patrón de detección en la consulta, filtro LIKE para el WHERE en SQL)
    # Orden crítico: primero los patrones específicos, el catch-all de "motor" al final.
    (re.compile(r"\btracci[oó]n\b", re.IGNORECASE), "%TRACCION%"),
    (re.compile(r"\bhidr[aá]ulic[ao]s?\b", re.IGNORECASE), "%HIDRAUL%"),
    (re.compile(r"\brueda[s]?\b", re.IGNORECASE), "%RUEDA%"),
    (re.compile(r"\bmando\s+final\b", re.IGNORECASE), "%MANDO%"),
    (re.compile(r"\bdiferencial\b", re.IGNORECASE), "%DIFERENCIAL%"),
    (re.compile(r"\btransmisi[oó]n\b", re.IGNORECASE), "%TRANSMISION%"),
    (re.compile(r"\bcaja\s+(?:de\s+)?giro\b|\bcg\s+(?:rear|front|trasero|delantero)\b", re.IGNORECASE), "%GIRO%"),
    (re.compile(r"\bpto\b|toma\s+de\s+fuerza|power\s+take[\s\-]off", re.IGNORECASE), "%PTO%"),
    (re.compile(r"\bmotores?\b", re.IGNORECASE), "MOTOR"),  # último: catch-all; "motor de tracción" ya matcheó tracción antes
]

# Proyectos mineros conocidos mapeados a su nombre real en BD.
# Se usa en filtros LIKE sobre [Mine].[MiningProject].[Name].
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


# ==============================================================================
#  FUNCIONES DE DETECCIÓN
# ==============================================================================

# Patrón para detectar negaciones que preceden a un compartimiento.
# Busca en el texto inmediatamente antes del match: "no me incluyas los de [tracción]",
# "sin [tracción]", "excepto [tracción]", "menos los de [tracción]", etc.
# El ancla $ asegura que la negación está justo antes del compartimiento, no en otra parte.
_RE_NEGACION_CERCA = re.compile(
    r"(?:no\s+(?:me\s+)?inclu\w*"
    r"|sin\b"
    r"|excepto\b"
    r"|salvo\b"
    r"|menos\b"
    r"|exclu\w+)"
    r"(?:\s+(?:los|las|el|la)\b)?"
    r"(?:\s+(?:de|del)\b)?"
    r"\s*$",
    re.IGNORECASE,
)


def _detectar_like_compartimiento(q: str) -> Optional[str]:
    """
    Recorre _COMPARTIMIENTO_KEYWORD_MAP y retorna el primer patrón LIKE que aplica.
    Retorna None si ningún keyword de compartimiento está en la consulta.

    Si un compartimiento está negado ("no incluyas tracción", "sin tracción"),
    lo salta y busca el siguiente match. Esto evita que "motores sin tracción"
    genere triage DE tracción en vez de motores excluyendo tracción.
    """
    for patron, like in _COMPARTIMIENTO_KEYWORD_MAP:
        m = patron.search(q or "")
        if m:
            # Verificar si el match está precedido por una negación
            texto_antes = (q or "")[:m.start()]
            if _RE_NEGACION_CERCA.search(texto_antes):
                continue  # saltar: este compartimiento está negado
            return like
    return None


def _detectar_proyecto(q: str) -> Optional[str]:
    """
    Retorna el nombre del proyecto minero (tal como está en BD) si se menciona en la consulta.
    Usa coincidencia de substring en minúsculas para evitar falsos negativos por mayúsculas.
    """
    q_lower = (q or "").lower()
    for keyword, nombre in _PROYECTOS_CONOCIDOS:
        if keyword in q_lower:
            return nombre
    return None


# Regex para códigos de equipo individuales: letras cortas + dígitos (CA3198, WA600, PC4000…)
_RE_EQUIPO_CODE = re.compile(r"\b([A-Z]{1,3}\d{3,5})\b")

# Referencia coloquial: "el 3196", "equipo 3196", "camión 3196", "del 3196" — sin prefijo de letras.
# Captura 4-5 dígitos precedidos por una palabra de referencia directa o preposición.
_RE_EQUIPO_COLOQUIAL = re.compile(
    r"\b(?:el|del|la|equipo|camión|camion|unidad|maquina|máquina|código|codigo)\s+(\d{4,5})\b",
    re.IGNORECASE,
)


def _detectar_equipo_code(q: str) -> Optional[str]:
    """
    Extrae código de equipo de la consulta.
    - Código completo (CA3196, WA600) → retorna el código exacto para WHERE =
    - Referencia coloquial ("el 3196", "equipo 3196") → retorna '%3196' para WHERE LIKE
      con fallback a 'CA{num}' si el número está en rango de flota Antapaccay (3100-3200).
    """
    m = _RE_EQUIPO_CODE.search(q or "")
    if m:
        return m.group(1)
    m_col = _RE_EQUIPO_COLOQUIAL.search(q or "")
    if m_col:
        num = m_col.group(1)
        if not (2000 <= int(num) <= 2030):  # excluir años
            return f"%{num}"
    return None


# Marca/tipo de aceite: Shell, Mobil, Castrol, etc. → filtra LD.[Grado]
_GRADO_ACEITE_MAP: List[tuple] = [
    (re.compile(r"\bshell\b", re.IGNORECASE), "Shell"),
    (re.compile(r"\bmobil\b", re.IGNORECASE), "Mobil"),
    (re.compile(r"\bcastrol\b", re.IGNORECASE), "Castrol"),
    (re.compile(r"\btotal\b", re.IGNORECASE), "Total"),
]


def _detectar_grado_aceite(q: str) -> Optional[str]:
    """
    Detecta marca o tipo de aceite en la consulta.
    Retorna el nombre de la marca para pasarlo a _grado_where_clause().
    Retorna None si no hay mención explícita de marca.
    """
    for pat, nombre in _GRADO_ACEITE_MAP:
        if pat.search(q or ""):
            return nombre
    return None


def _grado_where_clause(grado: str) -> str:
    """
    Genera la cláusula WHERE SQL para filtrar por marca de aceite.
    Mobil: captura también 'MOBILGEAR SHC 680' y 'M-SHC GEAR 680'
    — variantes reales en BD (M-SHC = Mobil SHC abreviado, no contiene 'MOBIL').
    """
    if grado == "Mobil":
        return "(LD.[Grado] LIKE '%MOBIL%' OR LD.[Grado] LIKE '%M-SHC%')"
    return f"LD.[Grado] LIKE '%{grado}%'"


# Regex para extraer ventana temporal expresada en meses o años.
_RE_VENTANA_MESES = re.compile(r"\b(\d+)\s+mes(?:es)?\b", re.IGNORECASE)
_RE_VENTANA_ANIOS = re.compile(r"\b(\d+)\s+a[nñ]o[s]?\b", re.IGNORECASE)


def _detectar_ventana_meses(q: str) -> int:
    """
    Extrae la ventana temporal de la consulta y la expresa siempre en meses.
    Si el usuario dice "2 años" → retorna 24. Si no menciona período → retorna 24 (default).
    """
    m = _RE_VENTANA_MESES.search(q or "")
    if m:
        return int(m.group(1))
    m = _RE_VENTANA_ANIOS.search(q or "")
    if m:
        # Convertir años a meses para usar en DATEADD(MONTH, -N, GETDATE())
        return int(m.group(1)) * 12
    return 24  # ventana default: 24 meses hacia atrás

_MESES_ES: dict[str, int] = {
    "enero": 1, "febrero": 2, "marzo": 3, "abril": 4,
    "mayo": 5, "junio": 6, "julio": 7, "agosto": 8,
    "septiembre": 9, "octubre": 10, "noviembre": 11, "diciembre": 12,
}

_RE_FECHA_CORTE = re.compile(
    r"\bhasta\s+(?:el\s+)?(?:\d{1,2}\s+de\s+)?"
    r"(enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre)"
    r"(?:\s+(?:de\s+)?(\d{4}))?",
    re.IGNORECASE,
)


def _detectar_fecha_corte(q: str) -> Optional[str]:
    """
    Detecta frases como "hasta abril", "hasta abril 2026", "hasta el 30 de abril".
    Retorna el último día del mes en formato 'YYYY-MM-DD' para usar como filtro superior
    en la cláusula WHERE (LD.[FechaMuestreo] <= 'YYYY-MM-DD').
    """
    m = _RE_FECHA_CORTE.search(q or "")
    if not m:
        return None
    mes_num = _MESES_ES.get(m.group(1).lower())
    if not mes_num:
        return None
    anio = int(m.group(2)) if m.group(2) else datetime.date.today().year
    if mes_num == 12:
        ultimo_dia = datetime.date(anio + 1, 1, 1) - datetime.timedelta(days=1)
    else:
        ultimo_dia = datetime.date(anio, mes_num + 1, 1) - datetime.timedelta(days=1)
    return ultimo_dia.strftime("%Y-%m-%d")


_RE_MES_ACTUAL = re.compile(
    r"\b(mes\s+actual|hasta\s+hoy|al\s+d[ií]a|este\s+mes|del\s+mes\s+actual|incluye?\s+(?:el\s+)?mes)\b",
    re.IGNORECASE,
)


def _usuario_pide_mes_actual(q: str) -> bool:
    return bool(_RE_MES_ACTUAL.search(q or ""))


def _fecha_corte_defecto() -> str:
    """Último día del mes anterior. Usado como upper bound por defecto en triage."""
    hoy = datetime.date.today()
    return (hoy.replace(day=1) - datetime.timedelta(days=1)).strftime("%Y-%m-%d")


# ==============================================================================
#  UTILIDADES INTERNAS
# ==============================================================================

def _json_cauto_loads(s: str) -> Optional[Dict[str, Any]]:
    """
    Intenta parsear un string como JSON. Retorna el dict si es válido, None si falla.
    Se usa para procesar la salida del LLM que debería venir como JSON.
    """
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
    # Requiere AMBAS condiciones: mención de compartimiento Y mención de análisis de aceite.
    # Evita activar el refuerzo en consultas genéricas sobre motores sin contexto de aceite.
    t = texto or ""
    return bool(_RE_PISTA_COMPARTIMIENTO_ACEITE.search(t)) and bool(_RE_PISTA_ANALISIS_ACEITE.search(t))


def _es_intencion_laboratorio_aceite(texto: str) -> bool:
    return bool(_RE_PISTA_LABORATORIO_ACEITE.search(texto or ""))


def _es_intencion_dimensional(texto: str) -> bool:
    return bool(_RE_PISTA_DIMENSIONAL.search(texto or ""))


def _es_intencion_join_proyecto_modelo(texto: str) -> bool:
    """
    Detecta consultas que cruzan datos de aceite con proyecto y/o modelo de equipo.
    Requiere mención de aceite Y al menos proyecto O modelo. No aplica a triage puro.
    """
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
    # La continuidad solo aplica si HAY contexto previo. Sin contexto, no hay referencia posible.
    t = texto or ""
    c = contexto or ""
    return bool(c.strip()) and bool(_RE_PISTA_CONTINUIDAD.search(t))


def _es_intencion_sintesis_interpretacion(texto: str) -> bool:
    return bool(_RE_PISTA_SINTESIS_INTERPRETACION.search(texto or ""))


def _es_intencion_criticidad(texto: str) -> bool:
    return bool(_RE_PISTA_CRITICIDAD.search(texto or ""))


# ==============================================================================
#  FUNCIONES DE REFUERZO DE PROMPT
#
#  Cada función toma la consulta del usuario y le agrega instrucciones SQL
#  específicas del dominio, para que el LLM genere consultas correctas desde
#  el primer intento sin necesidad de reintentos.
#
#  Convención de nombre: _reforzar_*
#  Prefijo en el prompt: " | NOMBRE-HEURISTICA: ..."
# ==============================================================================

def _reforzar_consulta_dimensional(q: str) -> str:
    """Indica al LLM qué tablas y columnas usar para consultas de catálogo/dimensiones."""
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
    """
    Inyecta la cadena de JOINs correcta para cruzar datos de aceite con proyecto y modelo.
    Incluye ROW_NUMBER para última muestra — GROUP BY+MAX no es suficiente porque
    LaboratoryData tiene múltiples filas para la misma fecha (duplicados confirmados en BD).
    """
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
    """
    Fuerza el uso de [Oil].[LaboratoryData] en lugar de [dbo].[OilAnalysis].
    LaboratoryData es la tabla con datos en tiempo real; OilAnalysis es legacy.
    """
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
    """
    Orienta al LLM a filtrar por el campo Compartimiento en LaboratoryData,
    no por tablas de catálogo de componentes. Evita confusión con dbo.Component.
    """
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
    """
    Instrucciones para consultas sobre compartimientos de un modelo o equipo.
    Incluye dos errores frecuentes de SQL Server que el LLM tiende a cometer:
      - Error 8127: ORDER BY con alias que no está directamente en el SELECT (GROUP BY).
      - Error 156: TOP antes de DISTINCT → sintaxis inválida en SQL Server.
    """
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
    """
    Instrucciones para consultas de "último/más reciente registro".
    La clave: no filtrar IS NOT NULL sobre métricas de salida antes de ROW_NUMBER,
    porque eso eliminaría equipos completos que sí tienen registro pero con métrica nula.
    """
    extra_nulos = ""
    if not _usuario_pide_excluir_nulos(q):
        # Solo añadir esta advertencia si el usuario NO pidió explícitamente excluir nulos.
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
    """Asegura que las consultas comparativas incluyan ambas métricas y la diferencia calculada."""
    return (
        q.strip()
        + " | IMPORTANTE: si la consulta implica comparar 2 campos (A vs B), el SELECT DEBE incluir "
          "las 2 métricas y una columna Diferencia = (A - B), y ordenar por Diferencia DESC cuando "
          "se esté limitando la cantidad de filas devueltas."
    )


def _reforzar_consulta_continuidad(q: str) -> str:
    """
    Indica al LLM que resuelva referencias deícticas usando el contexto conversacional.
    Sin este refuerzo, Flash tiende a ignorar el contexto y consultar el universo completo.
    """
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
    """Evita que Flash amplíe columnas o cambie de tabla cuando el usuario pide interpretación."""
    return (
        q.strip()
        + " | IMPORTANTE: si el usuario pide explicar, resumir, interpretar, concluir o diagnosticar, "
          "prioriza conservar el mismo conjunto de resultados ya establecido en el contexto. "
          "No amplíes columnas ni cambies de tabla principal sin necesidad. "
          "Si la intención es analítica y no transaccional, mantén el foco en interpretar el subconjunto ya construido."
    )


def _reforzar_consulta_criticidad(q: str) -> str:
    """Instrucción para ordenar por severidad sin inventar umbrales que no existen en BD."""
    return (
        q.strip()
        + " | IMPORTANTE: si el usuario pide los casos más críticos y no define una regla exacta, "
          "prioriza el orden descendente por las métricas de desgaste o contaminación explícitamente mencionadas "
          "en la consulta actual o presentes en el contexto conversacional inmediato. "
          "Evita inventar umbrales operativos que no existan en la base. "
          "Para encontrar 'el más alto/mayor/top N' por un metal en un compartimiento: "
          "usa CTE con ROW_NUMBER() OVER (PARTITION BY MiningEquipmentId,Compartimiento ORDER BY FechaMuestreo DESC) "
          "para obtener la última muestra por equipo, luego selecciona el TOP con ORDER BY metal DESC. "
          "NUNCA ordenes solo por fecha ni uses MAX() sin deduplicar por equipo primero."
    )


# ==============================================================================
#  GENERADORES DE SQL DIRECTO (sin LLM)
#
#  Para los casos de uso más frecuentes y bien definidos, el SQL se genera
#  directamente en Python. Esto garantiza consistencia, evita alucinaciones
#  del modelo y es significativamente más rápido que una llamada al LLM.
#
#  Orden de prioridad en main.py/_generar_sql():
#    1. intentar_historial_crudo_directo()          — muestra a muestra, sin promediar
#    2. intentar_ultimo_analisis_flota_directo()    — última muestra por equipo, SIN filtro LP/LC
#    3. intentar_tendencia_directo()                — AVG mensual, serie temporal
#    4. intentar_triage_directo()                   — doble CTE con LP/LC reales de BD
#    5. intentar_ranking_directo()                  — top-N por metal con ROW_NUMBER
#    6. LLM                                         — caso general
# ==============================================================================

# Regex de intención: "último análisis", "última muestra", "últimos resultados" de flota.
# NO aplica si hay lenguaje de triage (eso se guarda por la guardia _es_intencion_triage_observados).
_RE_PISTA_ULTIMO_ANALISIS_FLOTA = re.compile(
    r"\b(?:"
    r"últi(?:mo|ma)\s+(?:an[aá]lisis|resultado|reporte|muestreo|muestra|toma)"
    r"|últimos?\s+(?:resultados?|an[aá]lisis)"
    r")\b",
    re.IGNORECASE,
)


def _es_intencion_ultimo_analisis_flota(texto: str) -> bool:
    return bool(_RE_PISTA_ULTIMO_ANALISIS_FLOTA.search(texto or ""))


# Regex para "últimos N análisis/registros" — usado en consulta_humana_a_sql() como hint al LLM
# para que genere TOP(N) o rn<=N en vez de rn=1.
_RE_ULTIMOS_N = re.compile(
    r"\búltim[oa]s?\s+(\d+)\s+(?:an[aá]lisis|registro[s]?|muestra[s]?|resultado[s]?|reporte[s]?)\b",
    re.IGNORECASE,
)


def intentar_historial_crudo_directo(consulta_humana: str) -> Optional[str]:
    """
    Genera SQL de registros individuales (sin AVG ni GROUP BY) directamente en Python.

    Problema que resuelve: cuando el contexto conversacional incluye triage,
    el LLM tiende a reutilizar el patrón CTE+ROW_NUMBER → rn=1, lo que devuelve
    solo 1 muestra (la más reciente) en lugar del historial completo solicitado.
    Este bypass garantiza un SELECT plano con todas las filas del período.

    Se activa cuando:
      - El usuario pide datos "sin promediar", "muestra por muestra", etc.
      - Se detecta un compartimiento conocido.
      - Se detecta un equipo específico (CA3198) O un proyecto (Antapaccay).

    Retorna None si no hay suficiente información → cae al LLM.
    """
    if not _es_intencion_muestras_individuales(consulta_humana):
        return None
    # Triage tiene prioridad absoluta, incluso sobre registros crudos.
    if _es_intencion_triage_observados(consulta_humana):
        return None

    like_comp = _detectar_like_compartimiento(consulta_humana)
    equipo_code = _detectar_equipo_code(consulta_humana)
    proyecto = _detectar_proyecto(consulta_humana)

    # Sin compartimiento o sin al menos un filtro de equipo/proyecto,
    # el SELECT devolvería toda la tabla → no es determinístico ni útil.
    if not like_comp or (not equipo_code and not proyecto):
        return None

    ventana = _detectar_ventana_meses(consulta_humana)
    filtro_fecha = f"LD.[FechaMuestreo]>=DATEADD(MONTH,-{ventana},GETDATE())"
    filtro_comp = f"LD.[Compartimiento] LIKE '{like_comp}'"

    grado = _detectar_grado_aceite(consulta_humana)
    _where_grado = f" AND {_grado_where_clause(grado)}" if grado else ""

    # Columnas base: fecha + código de equipo + compartimiento + métricas MT completas
    # + campos operativos (Condicion, Horometro, CodigoMuestreo, Oxidacion, Agua).
    base_cols = (
        f"LD.[FechaMuestreo],ME.[Code] AS [Equipo],LD.[Compartimiento],LD.[Grado],"
        f"LD.[Condicion],LD.[CodigoMuestreo],LD.[Horometro],"
        f"LD.[Fe_ppm],LD.[Cr_ppm],LD.[Ni_ppm],LD.[Pb_ppm],LD.[Sn_ppm],"
        f"LD.[Cu_ppm],LD.[Si_ppm],LD.[Al_ppm],LD.[Indice_PQ],"
        f"LD.[B_ppm],LD.[P_ppm],LD.[V100],LD.[TBN],LD.[HorasDeAceite],"
        f"LD.[Oxidacion],LD.[Agua]"
    )
    base_joins = (
        f"FROM [Oil].[LaboratoryData] LD WITH (NOLOCK) "
        f"JOIN [Mine].[MiningEquipment] ME WITH (NOLOCK) ON ME.[Id]=LD.[MiningEquipmentId] "
        f"JOIN [Mine].[MiningProject] MP WITH (NOLOCK) ON MP.[Id]=ME.[MiningProjectId]"
    )

    if equipo_code:
        # Código exacto (CA3196) → igualdad; referencia coloquial (%3196) → LIKE.
        where_equipo = (
            f"ME.[Code] LIKE '{equipo_code}'"
            if equipo_code.startswith("%")
            else f"ME.[Code]='{equipo_code}'"
        )
        sql = (
            f"SELECT TOP(500) {base_cols} "
            f"{base_joins} "
            f"WHERE {filtro_comp} AND {where_equipo} AND {filtro_fecha}{_where_grado} "
            f"ORDER BY LD.[FechaMuestreo] DESC"
        )
    else:
        # Sin equipo específico: filtrar por proyecto para acotar el universo.
        sql = (
            f"SELECT TOP(500) {base_cols} "
            f"{base_joins} "
            f"WHERE {filtro_comp} AND MP.[Name] LIKE '%{proyecto}%' AND {filtro_fecha}{_where_grado} "
            f"ORDER BY LD.[FechaMuestreo] DESC"
        )
    return sql


def intentar_ultimo_analisis_flota_directo(consulta_humana: str) -> Optional[str]:
    """
    Genera SQL del último análisis por equipo+compartimiento directamente en Python.

    Diferencia clave con triage_directo:
      - NO filtra por LP/LC — devuelve TODOS los equipos con su muestra más reciente,
        independientemente de si están observados o dentro de límites.
      - Columnas base confirmadas (Fe, Cu, Si, Al, TBN). Se expandirán a PQ/Cr/Ni/etc.
        tras verificar las columnas reales de [Oil].[LaboratoryData] en SSMS.

    Caso de uso principal: "dame el último análisis de los 27 equipos de Antapaccay"
    → 1 fila por (equipo, compartimiento), última fecha registrada de cada uno.
    El formato es independiente del mes — cada equipo puede tener distinta última fecha.

    Requiere: al menos compartimiento O proyecto detectado.
    """
    if _es_intencion_triage_observados(consulta_humana):
        return None
    if _es_intencion_tendencia_historica(consulta_humana):
        return None
    if not _es_intencion_ultimo_analisis_flota(consulta_humana):
        return None

    like_comp = _detectar_like_compartimiento(consulta_humana)
    proyecto = _detectar_proyecto(consulta_humana)
    # Guard: sin al menos compartimiento O proyecto, no podemos generar SQL determinístico.
    # "None" (string) indica bug upstream; "MOTOR" sin % es catch-all demasiado amplio.
    if like_comp in ("None", "MOTOR"):
        like_comp = None
    if not like_comp and not proyecto:
        return None

    fecha_corte = _detectar_fecha_corte(consulta_humana)
    if not fecha_corte and not _usuario_pide_mes_actual(consulta_humana):
        fecha_corte = _fecha_corte_defecto()
    _sql_fecha_corte = f" AND LD.[FechaMuestreo]<='{fecha_corte}'" if fecha_corte else ""

    _where_comp = f" AND LD.[Compartimiento] LIKE '{like_comp}'" if like_comp else ""
    _where_proy = f" AND MP.[Name] LIKE '%{proyecto}%'" if proyecto else ""

    grado = _detectar_grado_aceite(consulta_humana)
    _where_grado = f" AND {_grado_where_clause(grado)}" if grado else ""

    sql = (
        f"WITH LatestSamples AS ("
        f"SELECT ME.[Code] AS [EquipmentCode],LD.[Compartimiento],LD.[Grado],"
        f"LD.[Condicion],LD.[CodigoMuestreo],LD.[Horometro],"
        f"LD.[Fe_ppm],LD.[Cr_ppm],LD.[Ni_ppm],LD.[Pb_ppm],LD.[Sn_ppm],"
        f"LD.[Cu_ppm],LD.[Si_ppm],LD.[Al_ppm],LD.[Indice_PQ],"
        f"LD.[B_ppm],LD.[P_ppm],LD.[V100],LD.[TBN],LD.[HorasDeAceite],LD.[FechaMuestreo],"
        f"LD.[Oxidacion],LD.[Agua],"
        f"ROW_NUMBER() OVER (PARTITION BY LD.[MiningEquipmentId],LD.[Compartimiento] "
        f"ORDER BY LD.[FechaMuestreo] DESC) AS rn "
        f"FROM [Oil].[LaboratoryData] LD WITH (NOLOCK) "
        f"JOIN [Mine].[MiningEquipment] ME WITH (NOLOCK) ON ME.[Id]=LD.[MiningEquipmentId] "
        f"JOIN [Mine].[MiningProject] MP WITH (NOLOCK) ON MP.[Id]=ME.[MiningProjectId] "
        f"WHERE LD.[FechaMuestreo]>=DATEADD(YEAR,-2,GETDATE()){_sql_fecha_corte}"
        f"{_where_comp}{_where_proy}{_where_grado}"
        f") "
        f"SELECT TOP(200) [EquipmentCode],[Compartimiento],[Grado],"
        f"[Condicion],[CodigoMuestreo],[Horometro],"
        f"[Fe_ppm],[Cr_ppm],[Ni_ppm],[Pb_ppm],[Sn_ppm],"
        f"[Cu_ppm],[Si_ppm],[Al_ppm],[Indice_PQ],"
        f"[B_ppm],[P_ppm],[V100],[TBN],[HorasDeAceite],[FechaMuestreo],"
        f"[Oxidacion],[Agua] "
        f"FROM LatestSamples "
        f"WHERE rn=1 "
        f"ORDER BY [EquipmentCode]"
    )
    return sql


def intentar_tendencia_directo(consulta_humana: str) -> Optional[str]:
    """
    Genera SQL de tendencia histórica mensual directamente en Python, sin LLM.

    SQL producido:
      - AVG de métricas agrupado por EOMONTH(FechaMuestreo) + Compartimiento [+ Proyecto o Equipo]
      - Sin ROW_NUMBER ni rn=1: devuelve TODAS las muestras del período (no solo la última)
      - Sin filtro LP/LC: la tendencia muestra la evolución real, independiente de límites
      - ORDER BY [Mes] ASC → serie cronológica para facilitar visualización temporal

    Tres variantes de agrupación según contexto:
      - Con equipo específico (CA3198) → filtra por ME.[Code], agrupa por Equipo + Mes
      - Con proyecto (Antapaccay)      → filtra por MP.[Name], agrupa solo por Mes
      - Sin proyecto ni equipo         → agrupa también por MP.[Name] para distinguir flotas

    Retorna None si no aplica → el llamador cae al LLM con refuerzo de prompt.
    """
    if not _es_intencion_tendencia_historica(consulta_humana):
        return None
    # Triage tiene prioridad: "tendencia de los observados" debe ir a triage, no a tendencia.
    if _es_intencion_triage_observados(consulta_humana):
        return None
    # Si el usuario pide registros individuales, historial_crudo_directo tiene prioridad.
    if _es_intencion_muestras_individuales(consulta_humana):
        return None
    # Sin compartimiento conocido no podemos generar SQL determinístico.
    # "None" (string) indica bug upstream; "MOTOR" sin % es catch-all demasiado amplio.
    like_comp = _detectar_like_compartimiento(consulta_humana)
    if not like_comp or like_comp in ("None", "MOTOR"):
        return None

    equipo_code = _detectar_equipo_code(consulta_humana)
    proyecto = _detectar_proyecto(consulta_humana)

    grado = _detectar_grado_aceite(consulta_humana)
    _where_grado = f" AND {_grado_where_clause(grado)}" if grado else ""

    # Métricas agregadas por mes: AVG suaviza outliers puntuales. Cubre set completo MT.
    base_metricas = (
        f"AVG(LD.[Fe_ppm]) AS [Fe_ppm],"
        f"AVG(LD.[Cr_ppm]) AS [Cr_ppm],"
        f"AVG(LD.[Ni_ppm]) AS [Ni_ppm],"
        f"AVG(LD.[Pb_ppm]) AS [Pb_ppm],"
        f"AVG(LD.[Sn_ppm]) AS [Sn_ppm],"
        f"AVG(LD.[Cu_ppm]) AS [Cu_ppm],"
        f"AVG(LD.[Si_ppm]) AS [Si_ppm],"
        f"AVG(LD.[Al_ppm]) AS [Al_ppm],"
        f"AVG(LD.[Indice_PQ]) AS [Indice_PQ],"
        f"AVG(LD.[TBN]) AS [TBN],"
        f"COUNT(*) AS [Muestras]"
    )
    base_joins = (
        f"FROM [Oil].[LaboratoryData] LD WITH (NOLOCK) "
        f"JOIN [Mine].[MiningEquipment] ME WITH (NOLOCK) ON ME.[Id]=LD.[MiningEquipmentId] "
        f"JOIN [Mine].[MiningProject] MP WITH (NOLOCK) ON MP.[Id]=ME.[MiningProjectId]"
    )
    filtro_fecha = f"LD.[FechaMuestreo]>=DATEADD(MONTH,-24,GETDATE())"
    filtro_comp = f"LD.[Compartimiento] LIKE '{like_comp}'"

    if equipo_code:
        # Código exacto → igualdad; coloquial (%3196) → LIKE (misma lógica que historial_crudo).
        where_equipo_t = (
            f"ME.[Code] LIKE '{equipo_code}'"
            if equipo_code.startswith("%")
            else f"ME.[Code]='{equipo_code}'"
        )
        sql = (
            f"SELECT TOP(300) "
            f"ME.[Code] AS [Equipo],"
            f"EOMONTH(LD.[FechaMuestreo]) AS [Mes],"
            f"LD.[Compartimiento],"
            f"{base_metricas} "
            f"{base_joins} "
            f"WHERE {filtro_comp} AND {where_equipo_t} AND {filtro_fecha}{_where_grado} "
            f"GROUP BY ME.[Code],EOMONTH(LD.[FechaMuestreo]),LD.[Compartimiento] "
            f"ORDER BY [Mes] ASC"
        )
    elif proyecto:
        # Proyecto específico: promedio mensual del universo completo del proyecto.
        sql = (
            f"SELECT TOP(300) "
            f"EOMONTH(LD.[FechaMuestreo]) AS [Mes],"
            f"LD.[Compartimiento],"
            f"{base_metricas} "
            f"{base_joins} "
            f"WHERE {filtro_comp} AND MP.[Name] LIKE '%{proyecto}%' AND {filtro_fecha}{_where_grado} "
            f"GROUP BY EOMONTH(LD.[FechaMuestreo]),LD.[Compartimiento] "
            f"ORDER BY [Mes] ASC"
        )
    else:
        # Sin filtro de proyecto: incluir MP.[Name] en SELECT y GROUP BY para que
        # Copilot Studio / el usuario pueda distinguir qué proyecto es cada serie.
        sql = (
            f"SELECT TOP(300) "
            f"MP.[Name] AS [Proyecto],"
            f"EOMONTH(LD.[FechaMuestreo]) AS [Mes],"
            f"LD.[Compartimiento],"
            f"{base_metricas} "
            f"{base_joins} "
            f"WHERE {filtro_comp} AND {filtro_fecha}{_where_grado} "
            f"GROUP BY MP.[Name],EOMONTH(LD.[FechaMuestreo]),LD.[Compartimiento] "
            f"ORDER BY MP.[Name],[Mes] ASC"
        )
    return sql


def intentar_triage_directo(consulta_humana: str) -> Optional[str]:
    """
    Genera el SQL de triage directamente en Python cuando compartimiento + proyecto son conocidos.
    Es el bypass más crítico del sistema: garantiza SQL correcto para el caso de uso principal.

    SQL producido (doble CTE):
      LatestSamples — última muestra real por equipo+compartimiento usando ROW_NUMBER DESC.
        Importante: GROUP BY+MAX(FechaMuestreo) NO es suficiente porque LaboratoryData
        tiene múltiples filas por la misma fecha (duplicados confirmados en BD).
        ROW_NUMBER garantiza exactamente 1 fila por (equipo, compartimiento).

      LimitesLC — límites LP y LC reales de [Eqpcare].[lc], colapsados por MIN/MAX:
        MIN para metales ppm (límite más restrictivo entre modelos del mismo componente).
        MAX para TBN (invertido: el TBN bajo dispara alerta, MAX es el más permisivo = menos falsos positivos).

    Filtro de observados:
      WHERE Fe > ISNULL(LP, 60) OR Al > ISNULL(LP, 25) OR ...
      ISNULL usa límites referenciales del dominio como fallback: si no hay fila en [Eqpcare].[lc]
      para ese componente/proyecto, se aplican umbrales genéricos en lugar de 9999
      (que devolvería 0 resultados silenciosamente cuando el JOIN no matchea).

    Retorna None si no hay compartimiento O no hay proyecto → cae al LLM con refuerzo.
    """
    if not _es_intencion_triage_observados(consulta_humana):
        return None
    like_comp = _detectar_like_compartimiento(consulta_humana)
    proyecto = _detectar_proyecto(consulta_humana)
    # Sin ambos datos no podemos construir la doble CTE determinística.
    # Guard adicional: like_comp="MOTOR" (catch-all sin %) es demasiado genérico para triage;
    # like_comp="None" (string) indica un bug upstream que debe caer al LLM.
    if not like_comp or like_comp in ("None", "MOTOR") or not proyecto:
        return None
    
    # Triage evalúa el estado ACTUAL: usa la muestra más reciente sin límite superior de fecha.
    # Solo aplica corte explícito si el usuario lo pide ("hasta abril").
    # _fecha_corte_defecto() NO se aplica aquí — excluiría muestras del mes en curso
    # y devolvería equipos como "observados" aunque ya tengan análisis nuevos normales.
    fecha_corte = _detectar_fecha_corte(consulta_humana)
    _sql_fecha_corte = f" AND LD.[FechaMuestreo]<='{fecha_corte}'" if fecha_corte else ""

    grado = _detectar_grado_aceite(consulta_humana)
    _where_grado = f" AND {_grado_where_clause(grado)}" if grado else ""

    sql = (
        # ── CTE 1: LatestSamples ────────────────────────────────────────────────
        f"WITH LatestSamples AS ("
        f"SELECT ME.[Code] AS [EquipmentCode],LD.[Compartimiento],LD.[Grado],"
        f"LD.[Condicion],LD.[CodigoMuestreo],LD.[Horometro],LD.[HorasDeAceite],"
        f"LD.[Fe_ppm],LD.[Cr_ppm],LD.[Ni_ppm],LD.[Pb_ppm],LD.[Sn_ppm],"
        f"LD.[Cu_ppm],LD.[Si_ppm],LD.[Al_ppm],LD.[Indice_PQ],LD.[TBN],LD.[FechaMuestreo],"
        f"ROW_NUMBER() OVER (PARTITION BY LD.[MiningEquipmentId],LD.[Compartimiento] "
        f"ORDER BY LD.[FechaMuestreo] DESC) AS rn "
        f"FROM [Oil].[LaboratoryData] LD WITH (NOLOCK) "
        f"JOIN [Mine].[MiningEquipment] ME WITH (NOLOCK) ON ME.[Id]=LD.[MiningEquipmentId] "
        f"JOIN [Mine].[MiningProject] MP WITH (NOLOCK) ON MP.[Id]=ME.[MiningProjectId] "
        f"WHERE LD.[Compartimiento] LIKE '{like_comp}' "
        f"AND MP.[Name] LIKE '%{proyecto}%' "
        f"AND LD.[FechaMuestreo]>=DATEADD(YEAR,-2,GETDATE()){_sql_fecha_corte}{_where_grado}"
        f"), "
        # ── CTE 2: LimitesLC ─────────────────────────────────────────────────────
        # MIN para metales ppm: límite más restrictivo entre modelos del mismo componente.
        # MAX para TBN: TBN bajo = alerta → referencia más alta = menos falsos positivos.
        # Metales nuevos (Cr/Ni/Pb/Sn/PQ): fallback 9999 → solo disparan si lc tiene datos reales.
        f"LimitesLC AS ("
        f"SELECT [COMPONENTE],"
        f"MIN([FIERRO - LP]) AS [FIERRO - LP],MIN([FIERRO - LC]) AS [FIERRO - LC],"
        f"MIN([ALUMINIO - LP]) AS [ALUMINIO - LP],MIN([ALUMINIO - LC]) AS [ALUMINIO - LC],"
        f"MIN([COBRE - LP]) AS [COBRE - LP],MIN([COBRE - LC]) AS [COBRE - LC],"
        f"MIN([SILICIO - LP]) AS [SILICIO - LP],MIN([SILICIO - LC]) AS [SILICIO - LC],"
        f"MIN([CROMO - LP]) AS [CROMO - LP],MIN([CROMO - LC]) AS [CROMO - LC],"
        f"MIN([NIQUEL - LP]) AS [NIQUEL - LP],MIN([NIQUEL - LC]) AS [NIQUEL - LC],"
        f"MIN([PLOMO - LP]) AS [PLOMO - LP],MIN([PLOMO - LC]) AS [PLOMO - LC],"
        f"MIN([ESTAÑO - LP]) AS [ESTAÑO - LP],MIN([ESTAÑO - LC]) AS [ESTAÑO - LC],"
        f"MIN([PQ - LP]) AS [PQ - LP],MIN([PQ - LC]) AS [PQ - LC],"
        f"MAX([TBN - LP]) AS [TBN - LP],MAX([TBN - LC]) AS [TBN - LC] "
        f"FROM [Eqpcare].[lc] WITH (NOLOCK) "
        f"WHERE [Proyecto] LIKE '%{proyecto}%' AND [COMPONENTE] LIKE '{like_comp}' "
        f"GROUP BY [COMPONENTE]"
        f") "
        # ── SELECT final ─────────────────────────────────────────────────────────
        f"SELECT TOP(200) "
        f"LS.[EquipmentCode],LS.[Compartimiento],LS.[Grado],"
        f"LS.[Condicion],LS.[CodigoMuestreo],LS.[Horometro],LS.[HorasDeAceite],"
        f"LS.[Fe_ppm],LS.[Cr_ppm],LS.[Ni_ppm],LS.[Pb_ppm],LS.[Sn_ppm],"
        f"LS.[Cu_ppm],LS.[Si_ppm],LS.[Al_ppm],LS.[Indice_PQ],LS.[TBN],LS.[FechaMuestreo],"
        f"LC.[FIERRO - LP],LC.[FIERRO - LC],"
        f"LC.[ALUMINIO - LP],LC.[ALUMINIO - LC],"
        f"LC.[COBRE - LP],LC.[COBRE - LC],"
        f"LC.[SILICIO - LP],LC.[SILICIO - LC],"
        f"LC.[CROMO - LP],LC.[CROMO - LC],"
        f"LC.[NIQUEL - LP],LC.[NIQUEL - LC],"
        f"LC.[PLOMO - LP],LC.[PLOMO - LC],"
        f"LC.[ESTAÑO - LP],LC.[ESTAÑO - LC],"
        f"LC.[PQ - LP],LC.[PQ - LC],"
        f"LC.[TBN - LP],LC.[TBN - LC] "
        f"FROM LatestSamples LS "
        f"LEFT JOIN LimitesLC LC ON LC.[COMPONENTE]=LS.[Compartimiento] "
        f"WHERE LS.rn=1 "
        f"AND ("
        f"LS.[Fe_ppm]>ISNULL(LC.[FIERRO - LP],60) OR "
        f"LS.[Al_ppm]>ISNULL(LC.[ALUMINIO - LP],25) OR "
        f"LS.[Cu_ppm]>ISNULL(LC.[COBRE - LP],30) OR "
        f"LS.[Si_ppm]>ISNULL(LC.[SILICIO - LP],25) OR "
        f"LS.[Cr_ppm]>ISNULL(LC.[CROMO - LP],9999) OR "
        f"LS.[Ni_ppm]>ISNULL(LC.[NIQUEL - LP],9999) OR "
        f"LS.[Pb_ppm]>ISNULL(LC.[PLOMO - LP],9999) OR "
        f"LS.[Sn_ppm]>ISNULL(LC.[ESTAÑO - LP],9999) OR "
        f"LS.[Indice_PQ]>ISNULL(LC.[PQ - LP],9999) OR "
        f"(LC.[TBN - LP] IS NOT NULL AND LS.[TBN]>0 AND LS.[TBN]<LC.[TBN - LP])"
        f") "
        f"ORDER BY LS.[Fe_ppm] DESC"
    )
    return sql


# ==============================================================================
# RANKING DIRECTO — top N por metal sin LLM
# Detecta "top N por metal" o superlativos ("mayor Fe", "el más alto en Si").
# Usa ROW_NUMBER CTE para deduplicar la última muestra por equipo+compartimiento.
# Requiere metal + (compartimiento o proyecto). Sin ambos → cae al LLM.
# ==============================================================================

_RE_RANKING_TOPN = re.compile(
    r"\btop\s*(\d+)\b|los\s+(\d+)\s+(?:m[áa]s|(?:con\s+)?mayor(?:es)?|peores?)",
    re.IGNORECASE,
)
_RE_RANKING_EL_MAYOR = re.compile(
    r"\b(?:el\s+)?(?:m[áa]s\s+(?:alto|elevado|cr[ií]tico|contaminado)|m[áa]ximo|peor)\b",
    re.IGNORECASE,
)
_METAL_RANKING_MAP: List[tuple] = [
    # (regex de detección, columna en LaboratoryData, orden SQL)
    (re.compile(r"\b(?:fe(?:_ppm)?|fierro|hierro)\b", re.IGNORECASE), "Fe_ppm", "DESC"),
    (re.compile(r"\b(?:si(?:_ppm)?|silicio|s[ií]lice)\b", re.IGNORECASE), "Si_ppm", "DESC"),
    (re.compile(r"\b(?:cu(?:_ppm)?|cobre)\b", re.IGNORECASE), "Cu_ppm", "DESC"),
    (re.compile(r"\b(?:al(?:_ppm)?|aluminio)\b", re.IGNORECASE), "Al_ppm", "DESC"),
    (re.compile(r"\b(?:cr(?:_ppm)?|cromo)\b", re.IGNORECASE), "Cr_ppm", "DESC"),
    (re.compile(r"\b(?:ni(?:_ppm)?|n[ií]quel)\b", re.IGNORECASE), "Ni_ppm", "DESC"),
    (re.compile(r"\b(?:pb(?:_ppm)?|plomo)\b", re.IGNORECASE), "Pb_ppm", "DESC"),
    (re.compile(r"\b(?:sn(?:_ppm)?|esta[ñn]o)\b", re.IGNORECASE), "Sn_ppm", "DESC"),
    (re.compile(r"\b(?:pq|[íi]ndice\s+pq)\b", re.IGNORECASE), "Indice_PQ", "DESC"),
    (re.compile(r"\bTBN\b", re.IGNORECASE), "TBN", "ASC"),
]


def intentar_ranking_directo(consulta_humana: str) -> Optional[str]:
    """
    Genera SQL de ranking Top-N directamente en Python sin LLM.
    Activa cuando la consulta pide los N equipos con más/menos de un metal concreto
    y hay compartimiento o proyecto detectado.

    SQL producido: CTE LatestSamples con ROW_NUMBER para deduplicar la última muestra
    por (equipo, compartimiento), luego SELECT TOP(N) ordenado por el metal objetivo.
    """
    if _es_intencion_triage_observados(consulta_humana):
        return None
    if _es_intencion_tendencia_historica(consulta_humana):
        return None

    m_topn = _RE_RANKING_TOPN.search(consulta_humana)
    m_mayor = _RE_RANKING_EL_MAYOR.search(consulta_humana)
    if not m_topn and not m_mayor:
        return None

    metal_col: Optional[str] = None
    metal_order = "DESC"
    for pat, col, order in _METAL_RANKING_MAP:
        if pat.search(consulta_humana):
            metal_col = col
            metal_order = order
            break
    if not metal_col:
        return None

    n_val = 10
    if m_topn:
        g = m_topn.group(1) or m_topn.group(2)
        if g:
            n_val = int(g)
    elif m_mayor:
        n_val = 1

    like_comp = _detectar_like_compartimiento(consulta_humana)
    proyecto = _detectar_proyecto(consulta_humana)
    # Guard: "None" (string) indica bug upstream; "MOTOR" sin % es catch-all demasiado amplio.
    if like_comp in ("None", "MOTOR"):
        like_comp = None
    if not like_comp and not proyecto:
        return None

    _where_comp = f" AND LD.[Compartimiento] LIKE '{like_comp}'" if like_comp else ""
    _where_proy = f" AND MP.[Name] LIKE '%{proyecto}%'" if proyecto else ""

    fecha_corte = _detectar_fecha_corte(consulta_humana)
    if not fecha_corte and not _usuario_pide_mes_actual(consulta_humana):
        fecha_corte = _fecha_corte_defecto()
    _sql_fecha_corte = f" AND LD.[FechaMuestreo]<='{fecha_corte}'" if fecha_corte else ""

    grado = _detectar_grado_aceite(consulta_humana)
    _where_grado = f" AND {_grado_where_clause(grado)}" if grado else ""

    sql = (
        f"WITH LatestSamples AS ("
        f"SELECT ME.[Code] AS [EquipmentCode],LD.[Compartimiento],LD.[Grado],"
        f"LD.[Condicion],LD.[CodigoMuestreo],LD.[Horometro],"
        f"LD.[Fe_ppm],LD.[Cr_ppm],LD.[Ni_ppm],LD.[Pb_ppm],LD.[Sn_ppm],"
        f"LD.[Cu_ppm],LD.[Si_ppm],LD.[Al_ppm],LD.[Indice_PQ],LD.[TBN],LD.[FechaMuestreo],"
        f"LD.[HorasDeAceite],"
        f"ROW_NUMBER() OVER (PARTITION BY LD.[MiningEquipmentId],LD.[Compartimiento] "
        f"ORDER BY LD.[FechaMuestreo] DESC) AS rn "
        f"FROM [Oil].[LaboratoryData] LD WITH (NOLOCK) "
        f"JOIN [Mine].[MiningEquipment] ME WITH (NOLOCK) ON ME.[Id]=LD.[MiningEquipmentId] "
        f"JOIN [Mine].[MiningProject] MP WITH (NOLOCK) ON MP.[Id]=ME.[MiningProjectId] "
        f"WHERE LD.[FechaMuestreo]>=DATEADD(YEAR,-2,GETDATE()){_sql_fecha_corte}"
        f"{_where_comp}{_where_proy}{_where_grado}"
        f") "
        f"SELECT TOP({n_val}) [EquipmentCode],[Compartimiento],[Grado],"
        f"[Condicion],[CodigoMuestreo],[Horometro],"
        f"[Fe_ppm],[Cr_ppm],[Ni_ppm],[Pb_ppm],[Sn_ppm],"
        f"[Cu_ppm],[Si_ppm],[Al_ppm],[Indice_PQ],[TBN],[FechaMuestreo],"
        f"[HorasDeAceite] "
        f"FROM LatestSamples "
        f"WHERE rn=1 AND [{metal_col}] IS NOT NULL "
        f"ORDER BY [{metal_col}] {metal_order}"
    )
    return sql


def _reforzar_triage_observados(q: str) -> str:
    """
    Refuerzo de prompt para el caso de uso PRINCIPAL cuando el triage directo no aplica
    (sin compartimiento o sin proyecto detectado → el LLM debe inferirlos).

    Inyecta instrucciones detalladas sobre:
    - Estructura de la doble CTE (LatestSamples + LimitesLC).
    - Por qué ROW_NUMBER y no GROUP BY+MAX (duplicados por fecha en LaboratoryData).
    - Fallback ISNULL(col, 9999) para evitar falsos positivos cuando falta fila en lc.
    - Valores reales del campo Compartimiento (evita patrones LIKE incorrectos).
    """
    like_compartimiento = _detectar_like_compartimiento(q)
    proyecto = _detectar_proyecto(q)

    # Columnas de límites en [Eqpcare].[lc] — nombres con espacios y guión, requieren corchetes.
    # Incluye set completo MT: FIERRO, ALUMINIO, COBRE, SILICIO, CROMO, NIQUEL, PLOMO, ESTAÑO, PQ, TBN.
    _lc_cols = (
        "LC.[FIERRO - LP],LC.[FIERRO - LC],"
        "LC.[ALUMINIO - LP],LC.[ALUMINIO - LC],"
        "LC.[COBRE - LP],LC.[COBRE - LC],"
        "LC.[SILICIO - LP],LC.[SILICIO - LC],"
        "LC.[CROMO - LP],LC.[CROMO - LC],"
        "LC.[NIQUEL - LP],LC.[NIQUEL - LC],"
        "LC.[PLOMO - LP],LC.[PLOMO - LC],"
        "LC.[ESTAÑO - LP],LC.[ESTAÑO - LC],"
        "LC.[PQ - LP],LC.[PQ - LC],"
        "LC.[TBN - LP],LC.[TBN - LC]"
    )

    # Condición de observado: supera al menos UN límite LP.
    # Fallbacks referenciales del dominio para Fe/Al/Cu/Si (no 9999) → resultado válido aunque
    # el JOIN con Eqpcare.lc no matchee. Cr/Ni/Pb/Sn/PQ usan 9999 → solo disparan si hay datos reales en lc.
    _umbral_lc = (
        "LS.[Fe_ppm]>ISNULL(LC.[FIERRO - LP],60) OR "
        "LS.[Al_ppm]>ISNULL(LC.[ALUMINIO - LP],25) OR "
        "LS.[Cu_ppm]>ISNULL(LC.[COBRE - LP],30) OR "
        "LS.[Si_ppm]>ISNULL(LC.[SILICIO - LP],25) OR "
        "LS.[Cr_ppm]>ISNULL(LC.[CROMO - LP],9999) OR "
        "LS.[Ni_ppm]>ISNULL(LC.[NIQUEL - LP],9999) OR "
        "LS.[Pb_ppm]>ISNULL(LC.[PLOMO - LP],9999) OR "
        "LS.[Sn_ppm]>ISNULL(LC.[ESTAÑO - LP],9999) OR "
        "LS.[Indice_PQ]>ISNULL(LC.[PQ - LP],9999) OR "
        "(LC.[TBN - LP] IS NOT NULL AND LS.[TBN]>0 AND LS.[TBN]<LC.[TBN - LP])"
    )
    # Mismo criterio que intentar_triage_directo: estado actual = última muestra sin corte.
    fecha_corte = _detectar_fecha_corte(q)
    filtro_fecha_corte = f" AND LD.[FechaMuestreo]<='{fecha_corte}'" if fecha_corte else ""

    # CTE de límites: se construye con o sin filtro de proyecto según lo detectado.
    # MIN para ppm (más restrictivo), MAX para TBN (más permisivo = menos falsos positivos).
    _lc_mins = (
        "MIN([FIERRO - LP]) AS [FIERRO - LP],MIN([FIERRO - LC]) AS [FIERRO - LC],"
        "MIN([ALUMINIO - LP]) AS [ALUMINIO - LP],MIN([ALUMINIO - LC]) AS [ALUMINIO - LC],"
        "MIN([COBRE - LP]) AS [COBRE - LP],MIN([COBRE - LC]) AS [COBRE - LC],"
        "MIN([SILICIO - LP]) AS [SILICIO - LP],MIN([SILICIO - LC]) AS [SILICIO - LC],"
        "MIN([CROMO - LP]) AS [CROMO - LP],MIN([CROMO - LC]) AS [CROMO - LC],"
        "MIN([NIQUEL - LP]) AS [NIQUEL - LP],MIN([NIQUEL - LC]) AS [NIQUEL - LC],"
        "MIN([PLOMO - LP]) AS [PLOMO - LP],MIN([PLOMO - LC]) AS [PLOMO - LC],"
        "MIN([ESTAÑO - LP]) AS [ESTAÑO - LP],MIN([ESTAÑO - LC]) AS [ESTAÑO - LC],"
        "MIN([PQ - LP]) AS [PQ - LP],MIN([PQ - LC]) AS [PQ - LC],"
        "MAX([TBN - LP]) AS [TBN - LP],MAX([TBN - LC]) AS [TBN - LC]"
    )
    if proyecto and like_compartimiento:
        _limites_cte_con_proyecto = (
            f"LimitesLC AS ("
            f"SELECT [COMPONENTE],{_lc_mins} "
            f"FROM [Eqpcare].[lc] WITH (NOLOCK) "
            f"WHERE [Proyecto] LIKE '%{proyecto}%' AND [COMPONENTE] LIKE '{like_compartimiento}' "
            f"GROUP BY [COMPONENTE])"
        )
    elif proyecto:
        # Sin compartimiento detectado: filtrar solo por proyecto para no escribir LIKE 'None'.
        _limites_cte_con_proyecto = (
            f"LimitesLC AS ("
            f"SELECT [COMPONENTE],{_lc_mins} "
            f"FROM [Eqpcare].[lc] WITH (NOLOCK) "
            f"WHERE [Proyecto] LIKE '%{proyecto}%' "
            f"GROUP BY [COMPONENTE])"
        )
    elif like_compartimiento:
        _limites_cte_con_proyecto = (
            f"LimitesLC AS ("
            f"SELECT [COMPONENTE],{_lc_mins} "
            f"FROM [Eqpcare].[lc] WITH (NOLOCK) "
            f"WHERE [COMPONENTE] LIKE '{like_compartimiento}' "
            f"GROUP BY [COMPONENTE])"
        )
    else:
        # Sin ningún dato conocido: sin filtro (el LLM infiere el WHERE).
        _limites_cte_con_proyecto = (
            f"LimitesLC AS (SELECT [COMPONENTE],{_lc_mins} "
            "FROM [Eqpcare].[lc] WITH (NOLOCK) GROUP BY [COMPONENTE])"
        )

    # Construir la instrucción de CTE según qué información se detectó.
    if like_compartimiento and proyecto:
        instruccion_cte = (
            f"2 CTEs: LatestSamples y LimitesLC. "
            f"LatestSamples: JOINs a ME y MP WITH (NOLOCK). "
            f"SELECT SIN TOP: ME.[Code] AS [EquipmentCode], LD.[Compartimiento], "
            f"LD.[Fe_ppm],LD.[Cr_ppm],LD.[Ni_ppm],LD.[Pb_ppm],LD.[Sn_ppm],"
            f"LD.[Cu_ppm],LD.[Si_ppm],LD.[Al_ppm],LD.[Indice_PQ],LD.[TBN],LD.[FechaMuestreo], "
            f"ROW_NUMBER() OVER (PARTITION BY LD.[MiningEquipmentId],LD.[Compartimiento] ORDER BY LD.[FechaMuestreo] DESC) AS rn. "
            f"WHERE: LD.[Compartimiento] LIKE '{like_compartimiento}' AND MP.[Name] LIKE '%{proyecto}%' AND LD.[FechaMuestreo]>=DATEADD(YEAR,-2,GETDATE()){filtro_fecha_corte}. "
            f"{_limites_cte_con_proyecto}. "
            f"SELECT externo: SELECT TOP(200) LS.[EquipmentCode],LS.[Compartimiento],LS.[Fe_ppm],LS.[Cr_ppm],LS.[Ni_ppm],LS.[Pb_ppm],LS.[Sn_ppm],LS.[Cu_ppm],LS.[Si_ppm],LS.[Al_ppm],LS.[Indice_PQ],LS.[TBN],LS.[FechaMuestreo],{_lc_cols} "
            f"FROM LatestSamples LS LEFT JOIN LimitesLC LC ON LC.[COMPONENTE]=LS.[Compartimiento] "
            f"WHERE LS.rn=1 AND ({_umbral_lc}). "
        )
    elif like_compartimiento:
        instruccion_cte = (
            f"2 CTEs: LatestSamples y LimitesLC. "
            f"LatestSamples: JOIN a ME WITH (NOLOCK). "
            f"SELECT SIN TOP: ME.[Code] AS [EquipmentCode], LD.[Compartimiento], "
            f"LD.[Fe_ppm],LD.[Cr_ppm],LD.[Ni_ppm],LD.[Pb_ppm],LD.[Sn_ppm],"
            f"LD.[Cu_ppm],LD.[Si_ppm],LD.[Al_ppm],LD.[Indice_PQ],LD.[TBN],LD.[FechaMuestreo], "
            f"ROW_NUMBER() OVER (PARTITION BY LD.[MiningEquipmentId],LD.[Compartimiento] ORDER BY LD.[FechaMuestreo] DESC) AS rn. "
            f"WHERE: LD.[Compartimiento] LIKE '{like_compartimiento}' AND LD.[FechaMuestreo]>=DATEADD(YEAR,-2,GETDATE()){filtro_fecha_corte}. "
            f"{_limites_cte_con_proyecto}. "
            f"SELECT externo: SELECT TOP(200) LS.[EquipmentCode],LS.[Compartimiento],LS.[Fe_ppm],LS.[Cr_ppm],LS.[Ni_ppm],LS.[Pb_ppm],LS.[Sn_ppm],LS.[Cu_ppm],LS.[Si_ppm],LS.[Al_ppm],LS.[Indice_PQ],LS.[TBN],LS.[FechaMuestreo],{_lc_cols} "
            f"FROM LatestSamples LS LEFT JOIN LimitesLC LC ON LC.[COMPONENTE]=LS.[Compartimiento] "
            f"WHERE LS.rn=1 AND ({_umbral_lc}). "
        )
    else:
        # Sin compartimiento: instrucción genérica, el LLM debe inferir el filtro LIKE.
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
          "NUNCA filtrar LD.[Condicion]='OBSERVADA' — [Condicion] es numérico (1/2/3), no texto. Estado observado = superar LP en metales. "
          "DEVUELVE SOLO observados. 0 filas=válido. ORDER BY LS.[Fe_ppm] DESC."
    )


# ==============================================================================
#  API PÚBLICA DEL MÓDULO
# ==============================================================================

def listar_modelos() -> Dict[str, Any]:
    """Delega al proveedor activo para listar los modelos disponibles."""
    if hasattr(_proveedor, "listar_modelos"):
        return _proveedor.listar_modelos()
    return _proveedor.list_models()  # type: ignore[attr-defined]


async def ping(modelo: Optional[str] = None) -> str:
    """Verifica que el proveedor LLM activo responde. Soporta firma en español e inglés."""
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
    Función principal de orquestación: convierte una consulta en lenguaje natural a SQL.

    Proceso interno:
      1. Evalúa la consulta + contexto contra todas las heurísticas de detección.
      2. Encadena los refuerzos de prompt que correspondan según las intenciones detectadas.
      3. Delega al proveedor LLM activo con el prompt enriquecido.
      4. Valida la respuesta JSON del LLM y añade metadatos (original_query, heuristicas_aplicadas).

    Retorna siempre un string: JSON con sql_query si el LLM responde bien,
    o el texto crudo si la respuesta no es JSON válido (se registra warning en logs).
    """
    q = (consulta_humana or "").strip()
    if not q:
        raise ValueError("consulta_humana vacía")

    contexto = (conversation_context or "").strip()
    # base_heuristica combina contexto + consulta actual para evaluar heurísticas.
    # Así las referencias deícticas como "los mismos equipos" se resuelven correctamente.
    base_heuristica = f"{contexto} {q}".strip()
    q_reforzada = q  # el prompt que se enviará al LLM, enriquecido progresivamente

    heuristicas_aplicadas: List[str] = []

    # Detectar compartimiento y proyecto al inicio para saber si el triage CTE estará completo.
    # Si ambos se detectan, _triage_cte_completo=True indica que el prompt triage ya incluye
    # todos los JOINs necesarios → no añadir join_proyecto_modelo después (causaría EquipmentFleet
    # en el SQL, que puede no estar en allowed_fqn y dispararía el blindaje → 400 innecesario).
    _triage_like_comp = _detectar_like_compartimiento(base_heuristica)
    _triage_proyecto = _detectar_proyecto(base_heuristica)
    _triage_cte_completo = bool(_triage_like_comp and _triage_proyecto)

    # ── Prioridad máxima: triage de componentes observados ───────────────────
    # Se evalúa primero para que sus instrucciones dominen sobre heurísticas generales.
    if _es_intencion_triage_observados(base_heuristica):
        q_reforzada = _reforzar_triage_observados(q_reforzada)
        heuristicas_aplicadas.append("triage_observados")
        # join_proyecto_modelo solo si el triage no inyectó JOINs propios.
        if not _triage_cte_completo and not _es_intencion_join_proyecto_modelo(base_heuristica):
            q_reforzada = _reforzar_join_proyecto_modelo_aceite(q_reforzada)
            heuristicas_aplicadas.append("join_proyecto_modelo")

    # Catálogos y dimensiones del negocio (proyectos, modelos, flotas).
    if _es_intencion_dimensional(base_heuristica):
        q_reforzada = _reforzar_consulta_dimensional(q_reforzada)
        heuristicas_aplicadas.append("dimensional")

    # Asegurar que las consultas de aceite usen [Oil].[LaboratoryData] como tabla base.
    if _es_intencion_laboratorio_aceite(base_heuristica):
        q_reforzada = _reforzar_tabla_laboratorio_aceite(q_reforzada)
        heuristicas_aplicadas.append("laboratorio_aceite")

    # JOIN aceite + proyecto/modelo: suprimir si triage ya definió los JOINs completos.
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

    # Continuidad: solo aplica si hay contexto previo Y hay referencias deícticas.
    if _es_intencion_continuidad(q, contexto):
        q_reforzada = _reforzar_consulta_continuidad(q_reforzada)
        heuristicas_aplicadas.append("continuidad")

    if _es_intencion_sintesis_interpretacion(base_heuristica):
        q_reforzada = _reforzar_consulta_sintesis_interpretacion(q_reforzada)
        heuristicas_aplicadas.append("sintesis_interpretacion")

    if _es_intencion_criticidad(base_heuristica):
        q_reforzada = _reforzar_consulta_criticidad(q_reforzada)
        heuristicas_aplicadas.append("criticidad")

    # Tendencia histórica: solo si NO es triage.
    # Triage necesita la última muestra; tendencia necesita la serie completa. Son opuestos.
    if (
        _es_intencion_tendencia_historica(base_heuristica)
        and "triage_observados" not in heuristicas_aplicadas
    ):
        q_reforzada = _reforzar_tendencia_historica(q_reforzada)
        heuristicas_aplicadas.append("tendencia_historica")

    # Código coloquial ("el 3196", "equipo 3196") → hint para usar LIKE '%3196' en ME.[Code].
    # Incluye variantes: '%3196' y 'CA3196' para maximizar match en primer intento.
    m_col = _RE_EQUIPO_COLOQUIAL.search(q or "")
    if m_col:
        num = m_col.group(1)
        if not (2000 <= int(num) <= 2030):
            q_reforzada = (
                q_reforzada.strip()
                + f" | IMPORTANTE: '{num}' es un código de equipo incompleto — "
                  f"usa ME.[Code] LIKE '%{num}' para encontrarlo. "
                  f"Variantes comunes: 'CA{num}', '{num}'. "
                  f"Si LIKE '%{num}' no devuelve resultados, intenta ME.[Code]='CA{num}'."
            )
            heuristicas_aplicadas.append("equipo_coloquial")

    # Marca/tipo de aceite (Shell, Mobil…) → columna LD.[Grado] LIKE '%Shell%'.
    grado_hint = _detectar_grado_aceite(q)
    if grado_hint:
        q_reforzada = (
            q_reforzada.strip()
            + f" | IMPORTANTE: la marca/tipo de aceite '{grado_hint}' se almacena en "
              f"LD.[Grado] de [Oil].[LaboratoryData]. Filtra con LD.[Grado] LIKE '%{grado_hint}%'. "
              f"Para comparar Shell vs Mobil en una misma consulta, usa GROUP BY LD.[Grado]."
        )
        heuristicas_aplicadas.append("grado_aceite")

    # Hint "últimos N": evita que el LLM genere rn=1 cuando el usuario pide N registros.
    m_ultimos_n = _RE_ULTIMOS_N.search(q or "")
    if m_ultimos_n:
        n_pedidos = m_ultimos_n.group(1)
        q_reforzada = (
            q_reforzada.strip()
            + f" | IMPORTANTE: el usuario pide los últimos {n_pedidos} registros por equipo. "
              f"Usa ROW_NUMBER() OVER (PARTITION BY MiningEquipmentId ORDER BY FechaMuestreo DESC) AS rn "
              f"y filtra WHERE rn <= {n_pedidos} en el SELECT externo. "
              f"NUNCA pongas TOP({n_pedidos}) dentro del CTE — causa error de sintaxis en SQL Server. "
              f"NUNCA uses rn = 1 cuando se piden {n_pedidos} registros."
        )
        heuristicas_aplicadas.append("ultimos_n")

    # Recordar al LLM que debe resolver referencias al contexto conversacional.
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

    # Delegar al proveedor activo. Se intenta con conversation_context primero;
    # si el proveedor no lo soporta (TypeError), se reintenta sin ese parámetro.
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
        # Alias en inglés para compatibilidad con implementaciones antiguas del proveedor.
        salida = await _proveedor.human_query_to_sql(  # type: ignore[attr-defined]
            human_query=q_reforzada,
            schema_json=esquema_json,
            dialect=dialecto,
            default_limit=limite_por_defecto,
            model=modelo,
        )

    # Intentar parsear la respuesta del LLM como JSON.
    obj = _json_cauto_loads(salida)
    if not obj or "sql_query" not in obj:
        # El LLM no devolvió JSON válido — se registra y se retorna el texto crudo.
        # database.py intentará extraer el SQL de todas formas.
        log.warning("[llm.consulta_humana_a_sql] salida no-JSON o sin sql_query (len=%s)", len(salida or ""))
        return salida

    # Enriquecer el JSON con metadatos para trazabilidad y debugging.
    if not obj.get("original_query"):
        obj["original_query"] = q  # preservar la consulta original sin refuerzos

    if heuristicas_aplicadas and not obj.get("heuristicas_aplicadas"):
        obj["heuristicas_aplicadas"] = heuristicas_aplicadas  # qué heurísticas se dispararon

    return json.dumps(obj, ensure_ascii=False)


async def construir_respuesta(
    filas: List[Dict[str, Any]],
    consulta_humana: str,
    modelo: Optional[str] = None,
) -> str:
    """
    Construye la respuesta analítica en lenguaje natural a partir de los resultados SQL.
    Solo se usa cuando GENERAR_RESPUESTA_TEXTO=true (deshabilitado en producción con Copilot Studio).
    """
    if hasattr(_proveedor, "construir_respuesta"):
        return await _proveedor.construir_respuesta(
            filas=filas,
            consulta_humana=consulta_humana,
            modelo=modelo,
        )
    # Alias en inglés para compatibilidad.
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
    """Versión síncrona de construir_respuesta para contextos sin event loop activo."""
    return asyncio.run(construir_respuesta(filas, consulta_humana, modelo=modelo))


# Alias en inglés mantenido por compatibilidad con código externo que usa human_query_to_sql.
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
