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
import unicodedata
from typing import Any, Dict, List, Optional

from .providers.factory import obtener_proveedor as _obtener_proveedor

log = logging.getLogger(__name__)


# ==============================================================================
#  NORMALIZACIÓN DE TEXTO — robustez ante tildes faltantes
#
#  Los usuarios escriben sin tildes constantemente ("ultimo analisis",
#  "traccion", "condicion", "cuantos"). Varios regex usan tildes duras
#  (ej: 'últi(?:mo|ma)') que NO matchean texto sin tilde → la heurística no
#  dispara → SQL incorrecto o fallback al LLM.
#
#  _buscar() matchea el regex contra el texto ORIGINAL y contra una copia SIN
#  tildes. Solo puede AÑADIR detecciones, nunca quitar (acorde al criterio del
#  módulo: preferir falsos positivos sobre falsos negativos). Cero riesgo de
#  romper detecciones existentes.
# ==============================================================================

def _strip_accents(s: str) -> str:
    """Quita tildes/diacríticos: 'último'→'ultimo', 'tracción'→'traccion', 'año'→'ano'."""
    if not s:
        return ""
    return "".join(
        c for c in unicodedata.normalize("NFD", s)
        if unicodedata.category(c) != "Mn"
    )


_STRIPPED_PATTERN_CACHE: Dict[Any, "re.Pattern"] = {}


def _regex_sin_tildes(regex: "re.Pattern") -> "re.Pattern":
    """Versión del patrón con sus literales/clases sin tildes (cacheada).
    Ej: 'últi(?:mo|ma)' → 'ulti(?:mo|ma)'; 'a[nñ]o' → 'a[nn]o'; '[oó]' → '[oo]'.
    Stripping solo elimina marcas combinantes → el patrón resultante siempre es válido."""
    cached = _STRIPPED_PATTERN_CACHE.get(regex)
    if cached is None:
        cached = re.compile(_strip_accents(regex.pattern), regex.flags)
        _STRIPPED_PATTERN_CACHE[regex] = cached
    return cached


def _buscar(regex: "re.Pattern", texto: str) -> bool:
    """True si el regex matchea el texto. Robusto ante tildes en AMBAS direcciones:
    - texto con tilde vs patrón base (ej: 'tracción' vs 'tracci[oó]n')
    - texto base vs patrón con tilde dura (ej: 'ultimo' vs 'últi(?:mo|ma)')
    Matchea el texto original, y si no, el texto sin tildes contra el patrón sin tildes."""
    t = texto or ""
    if regex.search(t):
        return True
    return bool(_regex_sin_tildes(regex).search(_strip_accents(t)))

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
    r"\b(supera|mayor\s+que|menor\s+que|más\s+que|menos\s+que|compar|vs\.?|versus|diferenc|pendien|despach|"
    r"frente\s+a|en\s+comparaci[oó]n|comparado\s+con|respecto\s+a|entre\s+proyecto[s]?|entre\s+flota[s]?|"
    r"mejor\s+que|peor\s+que|a\s+diferencia\s+de)\b",
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
    r"alarma[s]?|riesgo[s]?|urgente[s]?|peor|peores|más\s+alto|mas\s+alto|"
    r"prioriza|priorizalos|priorízalos|ordena|ordenalos|ordénalos|"
    r"ranking|clasifica|clasific[ao]|mayor\s+prioridad|alta\s+prioridad|"
    r"m[áa]s\s+grave[s]?|m[áa]s\s+cr[ií]tico[s]?|preocupante[s]?|en\s+riesgo|"
    r"tbn\s+bajo|bajo\s+tbn|valor(?:es)?\s+bajos?|nivel(?:es)?\s+bajo[s]?|elevado[s]?)\b",
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
    # "qué/cuáles/cuántos X hay/tiene" — cubre "cuántos equipos hay", "cuántos 980E tiene Antapaccay"
    r"\b(?:qu[eé]|cu[aá]les?|cu[aá]nt(?:o[s]?|a[s]?))\s+"
    r"(?:proyecto[s]?|modelo[s]?|tipo[s]?|equipo[s]?|camion(?:es)?|unidad(?:es)?|m[aá]quina[s]?|"
    r"980[Ee]?(?:-\d)?|930[Ee]?|d475|d375|hd[0-9]+|wa[0-9]+|pc[0-9]+|"
    r"incidente[s]?|falla[s]?)"
    r".{0,40}(?:hay|existen?|tiene[n]?|present[e]?[s]?|registra[n]?|cuenta[n]?)\b",
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
    return _buscar(_RE_PISTA_TENDENCIA_HISTORICA, texto)


# ==============================================================================
#  AGREGACIÓN — consultas de promedio/máximo/mínimo/conteo + GROUP BY
#
#  Se activa cuando el usuario pide estadísticas agrupadas, no registros individuales.
#  Ejemplos: "promedio de Fe por proyecto", "máximo de cobre en hidráulicos",
#  "cuántas muestras hay por mes", "comparar promedios entre proyectos".
# ==============================================================================

_RE_PISTA_AGREGACION = re.compile(
    r"\b(promedio[s]?|media\s+de|average|"
    r"m[áa]ximo\s+de|m[áa]x(?:imo)?|"
    r"m[ií]nimo\s+de|m[ií]n(?:imo)?|"
    r"suma\s+de|total\s+de|sumar|totaliz|"
    r"contar\s+(?:muestra[s]?|registro[s]?|equipo[s]?|an[aá]lisis)|"
    r"cu[aá]nt(?:o[s]?|a[s]?)\s+(?:muestra[s]?|registro[s]?|an[aá]lisis|dato[s]?)|"
    r"estad[ií]stica[s]?|desviaci[oó]n\s+est[aá]ndar|varianza|"
    r"por\s+proyecto|por\s+flota|por\s+modelo|agrupar\s+por|agrupado\s+por|"
    r"distribuci[oó]n\s+de|desglose\s+por|breakdown\s+por)\b",
    re.IGNORECASE,
)


def _es_intencion_agregacion(texto: str) -> bool:
    return _buscar(_RE_PISTA_AGREGACION, texto)


# ==============================================================================
#  PERÍODOS DE CALENDARIO
#
#  Detecta "este año", "este trimestre", "Q1 2025", "año 2024", etc.
#  Permite generar filtros de fecha precisos en vez de DATEADD(MONTH,-N,...).
# ==============================================================================

_RE_PISTA_PERIODO_CALENDARIO = re.compile(
    r"\b(este\s+a[nñ]o|a[nñ]o\s+actual|a[nñ]o\s+en\s+curso|"
    r"este\s+trimestre|trimestre\s+actual|"
    r"este\s+semestre|semestre\s+actual|"
    r"Q[1-4](?:\s*20\d{2})?|"
    r"primer\s+trimestre|segundo\s+trimestre|tercer\s+trimestre|cuarto\s+trimestre|"
    r"20\d{2}\b)"  # año específico: 2023, 2024, 2025...
    ,
    re.IGNORECASE,
)


def _es_intencion_periodo_calendario(texto: str) -> bool:
    return _buscar(_RE_PISTA_PERIODO_CALENDARIO, texto)


def _reforzar_periodo_calendario(q: str) -> str:
    """Genera el filtro de fecha correcto para períodos de calendario expresados en lenguaje natural."""
    hoy = datetime.date.today()
    q_l = (q or "").lower()
    hint = ""

    # "este año" / "año actual"
    if re.search(r"\beste\s+a[nñ]o\b|\ba[nñ]o\s+actual\b|\ba[nñ]o\s+en\s+curso\b", q_l):
        hint = (
            f"este año ({hoy.year}): "
            f"LD.[FechaMuestreo] >= '{hoy.year}-01-01' AND LD.[FechaMuestreo] <= GETDATE()"
        )
    # "primer/segundo/tercer/cuarto trimestre" o "este trimestre"
    elif re.search(r"\bprimer\s+trimestre\b", q_l):
        hint = f"Q1 {hoy.year}: LD.[FechaMuestreo] BETWEEN '{hoy.year}-01-01' AND '{hoy.year}-03-31'"
    elif re.search(r"\bsegundo\s+trimestre\b", q_l):
        hint = f"Q2 {hoy.year}: LD.[FechaMuestreo] BETWEEN '{hoy.year}-04-01' AND '{hoy.year}-06-30'"
    elif re.search(r"\btercer\s+trimestre\b", q_l):
        hint = f"Q3 {hoy.year}: LD.[FechaMuestreo] BETWEEN '{hoy.year}-07-01' AND '{hoy.year}-09-30'"
    elif re.search(r"\bcuarto\s+trimestre\b", q_l):
        hint = f"Q4 {hoy.year}: LD.[FechaMuestreo] BETWEEN '{hoy.year}-10-01' AND '{hoy.year}-12-31'"
    elif re.search(r"\beste\s+trimestre\b|\btrimestre\s+actual\b", q_l):
        q_num = (hoy.month - 1) // 3 + 1
        mes_inicio = (q_num - 1) * 3 + 1
        inicio = datetime.date(hoy.year, mes_inicio, 1)
        hint = f"Q{q_num} {hoy.year}: LD.[FechaMuestreo] >= '{inicio}' AND LD.[FechaMuestreo] <= GETDATE()"
    # "este semestre"
    elif re.search(r"\beste\s+semestre\b|\bsemestre\s+actual\b", q_l):
        sem = 1 if hoy.month <= 6 else 2
        inicio = datetime.date(hoy.year, 1 if sem == 1 else 7, 1)
        hint = f"semestre {sem} de {hoy.year}: LD.[FechaMuestreo] >= '{inicio}' AND LD.[FechaMuestreo] <= GETDATE()"
    # "Q1/Q2/Q3/Q4 [año]"
    else:
        m_q = re.search(r"\bQ([1-4])(?:\s*(20\d{2}))?\b", q, re.IGNORECASE)
        if m_q:
            q_num = int(m_q.group(1))
            anio_q = int(m_q.group(2)) if m_q.group(2) else hoy.year
            mes_inicio = (q_num - 1) * 3 + 1
            mes_fin = mes_inicio + 2
            fin_dia = 31 if mes_fin in (3, 12) else 30 if mes_fin in (6, 9) else 28
            hint = (
                f"Q{q_num} {anio_q}: "
                f"LD.[FechaMuestreo] BETWEEN '{anio_q}-{mes_inicio:02d}-01' "
                f"AND '{anio_q}-{mes_fin:02d}-{fin_dia}'"
            )
        else:
            # Año específico: "2024", "2025"
            m_yr = re.search(r"\b(20\d{2})\b", q)
            if m_yr:
                yr = m_yr.group(1)
                hint = f"año {yr}: LD.[FechaMuestreo] BETWEEN '{yr}-01-01' AND '{yr}-12-31'"

    if not hint:
        return q

    return (
        q.strip()
        + f" | PERIODO-CALENDARIO: {hint}. "
          "Usa este rango de fechas exacto en el WHERE en lugar de DATEADD(MONTH,-N,GETDATE()). "
          "No uses @año ni variables — usa las fechas literales calculadas arriba."
    )


# Mapa escalable de periodos de agrupación para tendencia/historial.
# Orden importante: más específico primero (lustro antes que anual, semestral antes que mensual).
# Cada tupla: (regex, sql_expr_template, col_alias, ventana_meses_default)
# {FMS} se sustituye por LD.[FechaMuestreo] al generar el SQL.
_FMS = "LD.[FechaMuestreo]"
_PERIODO_AGG_MAP: List[tuple] = [
    (re.compile(r"\blustro[s]?\b|\bquinquenal\b|\bpor\s+lustro[s]?\b", re.IGNORECASE),
     "DATEFROMPARTS(YEAR({FMS})/5*5,1,1)", "Periodo", 120),
    (re.compile(r"\bsemestral\b|\bpor\s+semestre[s]?\b|\bsemestre\s+a\s+semestre\b", re.IGNORECASE),
     "DATEFROMPARTS(YEAR({FMS}),((MONTH({FMS})-1)/6)*6+1,1)", "Periodo", 60),
    (re.compile(r"\bcuatrimestral\b|\bpor\s+cuatrimestre[s]?\b", re.IGNORECASE),
     "DATEFROMPARTS(YEAR({FMS}),((MONTH({FMS})-1)/4)*4+1,1)", "Periodo", 48),
    (re.compile(r"\btrimestral\b|\bpor\s+trimestre[s]?\b|\btrimestre\s+a\s+trimestre\b", re.IGNORECASE),
     "DATEFROMPARTS(YEAR({FMS}),((MONTH({FMS})-1)/3)*3+1,1)", "Periodo", 36),
    (re.compile(r"\bbimestral\b|\bpor\s+bimestre[s]?\b", re.IGNORECASE),
     "DATEFROMPARTS(YEAR({FMS}),((MONTH({FMS})-1)/2)*2+1,1)", "Periodo", 24),
    (re.compile(r"\banual\b|\bpor\s+a[nñ]o[s]?\b|\ba[nñ]o\s+a\s+a[nñ]o\b", re.IGNORECASE),
     "DATEFROMPARTS(YEAR({FMS}),1,1)", "Periodo", 60),
    (re.compile(r"\bmes\s+a\s+mes\b|\bmensual(?:es|mente)?\b|\bpor\s+mes(?:es)?\b|"
                r"\bpromedio\s+(?:mensual|por\s+mes)\b|\bpromedio[s]?\s+de\s+mes\b", re.IGNORECASE),
     "EOMONTH({FMS})", "Mes", 36),
]


def _detectar_periodo_agrupacion(q: str) -> Optional[tuple]:
    """Retorna (group_by_expr, col_alias, ventana_meses_default) o None si no se pide agregación por periodo."""
    for pat, expr_tpl, alias, ventana in _PERIODO_AGG_MAP:
        if pat.search(q or ""):
            return (expr_tpl.replace("{FMS}", _FMS), alias, ventana)
    return None


def _es_intencion_muestras_individuales(texto: str) -> bool:
    """Detecta cuando el usuario quiere registros crudos, no promedios mensuales."""
    return _buscar(_RE_MUESTRAS_INDIVIDUALES, texto)


def _reforzar_tendencia_historica(q: str) -> str:
    """
    Refuerzo de prompt para tendencia histórica cuando intentar_tendencia_directo()
    devuelve None (sin compartimiento detectado → el LLM debe inferirlo).

    CRÍTICO — consistencia con el path directo:
    - DEFAULT (sin keyword de periodo): últimas N muestras INDIVIDUALES por equipo+compartimiento
      (ROW_NUMBER rn<=8). NO promediar. Esto refleja lo que el usuario espera al decir "tendencia".
    - SOLO si el usuario dice "mensual/trimestral/anual/etc.": AVG por periodo (EOMONTH/DATEFROMPARTS).
    Antes este hint SIEMPRE forzaba AVG mensual de 24 meses → contradecía el path directo
    y producía "todo el historial" cuando el usuario solo pidió "tendencia".
    """
    like_compartimiento = _detectar_like_compartimiento(q)
    proyecto = _detectar_proyecto(q)
    periodo_agg = _detectar_periodo_agrupacion(q)

    joins = "JOIN [Mine].[MiningEquipment] ME WITH (NOLOCK) ON ME.[Id]=LD.[MiningEquipmentId]"
    filtros: List[str] = []
    if like_compartimiento:
        filtros.append(f"LD.[Compartimiento] LIKE '{like_compartimiento}'")
    if proyecto:
        joins += " JOIN [Mine].[MiningProject] MP WITH (NOLOCK) ON MP.[Id]=ME.[MiningProjectId]"
        filtros.append(f"MP.[Name] LIKE '%{proyecto}%'")

    _hint_980e_tend = ""
    if proyecto and proyecto.lower() == "antapaccay":
        _hint_980e_tend = (
            " ANTAPACCAY-980E: agregar JOIN [Mine].[EquipmentFleet] EF WITH (NOLOCK) ON EF.[Id]=ME.[EquipmentFleetId]"
            " y WHERE EF.[Model] LIKE '%980E%'."
        )
    _excluir_ddi = (
        " SIEMPRE excluir post-dializado: "
        "AND (LD.[CM] IS NULL OR LD.[CM] NOT IN ('DDI','DIALIZADO','RELLENO+DIALIZADO'))."
    )

    if periodo_agg:
        # ── Usuario pidió agregación por periodo → AVG ───────────────────────────
        _expr, _alias, _ventana_def = periodo_agg
        ventana = _detectar_ventana_meses(q, default=_ventana_def)
        group_prefix = "MP.[Name],LD.[Compartimiento]" if proyecto else "LD.[Compartimiento]"
        filtros.append(f"LD.[FechaMuestreo]>=DATEADD(MONTH,-{ventana},GETDATE())")
        where_clause = " AND ".join(filtros) if filtros else "1=1"
        instruccion = (
            f"El usuario pidió agregación por periodo. "
            f"SELECT TOP(300) {group_prefix},{_expr} AS [{_alias}],"
            "AVG(LD.[Fe_ppm]) AS [Fe_ppm],AVG(LD.[Cr_ppm]) AS [Cr_ppm],"
            "AVG(LD.[Ni_ppm]) AS [Ni_ppm],AVG(LD.[Cu_ppm]) AS [Cu_ppm],"
            "AVG(LD.[Si_ppm]) AS [Si_ppm],AVG(LD.[Al_ppm]) AS [Al_ppm],"
            "AVG(LD.[Indice_PQ]) AS [Indice_PQ],AVG(LD.[TBN]) AS [TBN],"
            "COUNT(*) AS [Muestras] "
            f"FROM [Oil].[LaboratoryData] LD WITH (NOLOCK) {joins} "
            f"WHERE {where_clause} "
            f"GROUP BY {group_prefix},{_expr} "
            f"ORDER BY {group_prefix},[{_alias}] "
            "— EOMONTH()/DATEFROMPARTS() devuelven tipo date, úsalos sin CAST. "
            "NUNCA usar ROW_NUMBER/rn en agregación por periodo."
            + _excluir_ddi
        )
    else:
        # ── DEFAULT: últimas 8 muestras individuales (NO promediar) ──────────────
        n = _detectar_n_muestras_tendencia(q)
        filtros.append("LD.[FechaMuestreo]>=DATEADD(YEAR,-3,GETDATE())")
        where_clause = " AND ".join(filtros) if filtros else "1=1"
        instruccion = (
            f"TENDENCIA DEFAULT = últimas {n} muestras INDIVIDUALES por equipo+compartimiento. "
            f"NO promediar, NO agrupar por mes (el usuario NO pidió 'mensual'/'historial'). "
            f"WITH Samples AS (SELECT ME.[Code] AS [Equipo],LD.[Compartimiento],LD.[FechaMuestreo],"
            f"LD.[Fe_ppm],LD.[Cr_ppm],LD.[Ni_ppm],LD.[Pb_ppm],LD.[Sn_ppm],"
            f"LD.[Cu_ppm],LD.[Si_ppm],LD.[Al_ppm],LD.[Indice_PQ],LD.[TBN],"
            f"ROW_NUMBER() OVER (PARTITION BY LD.[MiningEquipmentId],LD.[Compartimiento] "
            f"ORDER BY LD.[FechaMuestreo] DESC) AS rn "
            f"FROM [Oil].[LaboratoryData] LD WITH (NOLOCK) {joins} "
            f"WHERE {where_clause}{_excluir_ddi.replace(' SIEMPRE excluir post-dializado: ','')} ) "
            f"SELECT * FROM Samples WHERE rn<={n} ORDER BY [Compartimiento],[FechaMuestreo] ASC. "
            f"NUNCA pongas TOP dentro del CTE. Une LP/LC de [Eqpcare].[lc] si hay compartimiento conocido."
            + _hint_980e_tend
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
    r"fuera\s+de\s+espec(?:ificaci[oó]n)?[s]?|fuera\s+de\s+spec[s]?|"
    r"con\s+anomal[ií]a[s]?|con\s+alerta[s]?|con\s+problema[s]?|en\s+alarma[s]?|"
    r"necesitan?\s+atenci[oó]n|requieren?\s+atenci[oó]n|"
    r"prestar(?:le)?\s+atenci[oó]n|a\s+(?:los?\s+)?que\s+prestarle\s+atenci[oó]n|"
    r"supera[n]?\s+(?:el\s+)?l[ií]mite|superan?\s+(?:el\s+)?umbral|"
    # Patrón "estado de los N [componente]" — captura "estado de los 54 motores"
    r"estado\s+de\s+(?:los?|las?|todos?\s+los?|todas?\s+las?)?\s*\d*\s*"
    r"(?:motor(?:es)?|transmisi[oó]n(?:es)?|componente[s]?|equipo[s]?|compartimiento[s]?|"
    r"mando[s]?\s+final(?:es)?|diferencial(?:es)?|hidr[aá]ulico[s]?|rueda[s]?|flota[s]?)|"
    # "cómo están los [componentes]" — consulta de estado sin "observado" explícito
    r"c[oó]mo\s+est[aá]n?\s+(?:los?|las?)?\s*"
    r"(?:motor(?:es)?|hidr[aá]ulico[s]?|transmisi[oó]n(?:es)?|rueda[s]?|"
    r"mando[s]?\s+final(?:es)?|diferencial(?:es)?|componente[s]?|equipo[s]?|la\s+flota)|"
    # "¿están bien/mal/dentro/fuera los [componentes]?"
    r"(?:motor(?:es)?|hidr[aá]ulico[s]?|transmisi[oó]n(?:es)?|rueda[s]?|componente[s]?|equipo[s]?)\s+"
    r"(?:est[aá][ns]?\s+(?:bien|mal|fuera|dentro|observad[ao]|en\s+alarma)|"
    r"dentro\s+de\s+l[ií]mite[s]?|fuera\s+de\s+l[ií]mite[s]?)|"
    # "hay algún/alguna [observado/fuera/problema/alerta]"
    r"hay\s+alg[uú]n[a]?\s+(?:observad[ao]|fuera|problema|alerta|anomal[ií]a)|"
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
    r"masa\s+de\s+componentes?|universo\s+de\s+(?:componentes?|equipos?)|"
    # "salud de la flota", "status de equipos"
    r"salud\s+de\s+(?:la\s+)?(?:flota|equipo[s]?)|"
    r"status\s+de\s+(?:los?|las?\s+)?(?:equipo[s]?|motor(?:es)?|componente[s]?)"
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
    # Abreviaturas de campo usadas por ingenieros en mina (Motor de Tracción LH/RH):
    #   MDLH/MDRH, MTLH/MTRH, "MT RH"/"MT LH" (con espacio), EMT/"EMT RH", "E MT"
    #   "EMT de izquierda/derecha" → izquierda=LH, derecha=RH (ambos %TRACCION%)
    (re.compile(r"\bMD[LR]H\b|\bE?MT(?:\s*[LR]H)?\b", re.IGNORECASE), "%TRACCION%"),
    (re.compile(r"\bhidr[aá]ulic[ao]s?\b", re.IGNORECASE), "%HIDRAUL%"),
    (re.compile(r"\brueda[s]?\b", re.IGNORECASE), "%RUEDA%"),
    (re.compile(r"\bmando\s+final\b", re.IGNORECASE), "%MANDO%"),
    (re.compile(r"\bdiferencial\b", re.IGNORECASE), "%DIFERENCIAL%"),
    (re.compile(r"\btransmisi[oó]n\b", re.IGNORECASE), "%TRANSMISION%"),
    (re.compile(r"\bcaja\s+(?:de\s+)?giro\b|\bcg\s+(?:rear|front|trasero|delantero)\b", re.IGNORECASE), "%GIRO%"),
    (re.compile(r"\bpto\b|toma\s+de\s+fuerza|power\s+take[\s\-]off", re.IGNORECASE), "%PTO%"),
    (re.compile(r"\bmotores?\b", re.IGNORECASE), "MOTOR"),  # último: catch-all; "motor de tracción" ya matcheó tracción antes
]

# Columna que indica el tipo de muestra en [Oil].[LaboratoryData]: CM (varchar 30).
# Valores confirmados 2026-05-13 en BD: M/MUESTRA/MUESTREO/MONI=Monitoreo,
# C/CAMBIO=Cambio, ADI=Antes de Dialización (muestra real → incluir), DDI=Después de Dialización,
# DIALIZADO=post-dializado, RELLENO+DIALIZADO=combinado. NULL=9123 filas (histórico → incluir).
# Excluir DDI/DIALIZADO/RELLENO+DIALIZADO globalmente — metales artificialmente bajos post-proceso.
# Aunque DDI solo ocurre en Motor Tracción, el filtro se aplica a TODOS los queries por seguridad.
_TIPO_MUESTRA_COL: str = "CM"
_TIPO_MUESTRA_MT_EXCLUIR = ("DDI", "DIALIZADO", "RELLENO+DIALIZADO")


def _where_excluir_cm() -> str:
    """Excluye muestras post-dializado de cualquier query sobre LaboratoryData.
    Aplicar globalmente — aunque DDI solo aparece en Motor Tracción, no filtra otras filas.
    """
    excluir = ",".join(f"'{v}'" for v in _TIPO_MUESTRA_MT_EXCLUIR)
    return f" AND (LD.[{_TIPO_MUESTRA_COL}] IS NULL OR LD.[{_TIPO_MUESTRA_COL}] NOT IN ({excluir}))"

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

# LP de Fe confirmados por proyecto (fuente: [Eqpcare].[lc] verificado 2026-05-22).
# Se usa como fallback en ISNULL cuando el JOIN con LimitesLC no matchea por naming.
# Solo Fe: es el metal de alerta más crítico y el único con LP validado en todos los proyectos.
_PROYECTO_FE_LP_FALLBACK: dict = {
    "Antapaccay": 200,
    "Antamina":   200,
    "Cerro Verde": 80,
    "Toromocho":  145,
}


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


# Lado del componente: izquierdo (LH) / derecho (RH). Los valores en BD terminan en
# " LH"/" RH" (ej: 'MOTOR DE TRACCION LH', 'RUEDA DELANTERA RH').
_RE_LADO_LH = re.compile(r"\b(izquierd[ao]s?|lh|left)\b", re.IGNORECASE)
_RE_LADO_RH = re.compile(r"\b(derech[ao]s?|rh|right)\b", re.IGNORECASE)


def _detectar_lado(q: str) -> Optional[str]:
    """Detecta lado izquierdo/derecho → 'LH'/'RH'. None si no se especifica (ambos lados).
    Evita falsos positivos: 'RH'/'LH' como palabra suelta o izquierdo/derecho explícito."""
    t = q or ""
    lh = _buscar(_RE_LADO_LH, t)
    rh = _buscar(_RE_LADO_RH, t)
    if lh and not rh:
        return "LH"
    if rh and not lh:
        return "RH"
    return None  # ambos o ninguno → no filtrar


def _where_lado(lado: Optional[str]) -> str:
    """Cláusula WHERE para filtrar el compartimiento al lado pedido (LH/RH).
    Los valores en BD terminan en ' LH'/' RH'. Vacío si no se pidió lado."""
    if lado in ("LH", "RH"):
        return f" AND LD.[Compartimiento] LIKE '%{lado}'"
    return ""


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


def _join_modelo_antapaccay(proyecto: Optional[str]) -> tuple:
    """
    Retorna (extra_join, extra_where) para restringir resultados al modelo 980E en Antapaccay.
    Aplicado en todos los paths directos — 980E es la única flota bajo contrato KMMP en este sitio.
    Para otros proyectos retorna cadenas vacías (sin efecto).
    """
    if (proyecto or "").lower() == "antapaccay":
        return (
            " JOIN [Mine].[EquipmentFleet] EF WITH (NOLOCK) ON EF.[Id]=ME.[EquipmentFleetId]",
            " AND EF.[Model] LIKE '%980E%'",
        )
    return ("", "")


# Regex para extraer ventana temporal expresada en meses o años.
_RE_VENTANA_MESES = re.compile(r"\b(\d+)\s+mes(?:es)?\b", re.IGNORECASE)
_RE_VENTANA_ANIOS = re.compile(r"\b(\d+)\s+a[nñ]o[s]?\b", re.IGNORECASE)


def _detectar_ventana_meses(q: str, default: int = 24) -> int:
    """
    Extrae la ventana temporal de la consulta y la expresa siempre en meses.
    Si el usuario dice "2 años" → retorna 24. Si no menciona período → retorna `default`.
    """
    m = _RE_VENTANA_MESES.search(q or "")
    if m:
        return int(m.group(1))
    m = _RE_VENTANA_ANIOS.search(q or "")
    if m:
        return int(m.group(1)) * 12
    return default


_N_TENDENCIA_DEFAULT = 8   # muestras por defecto para tendencia por equipo
_N_TENDENCIA_MAX = 12      # máximo permitido (evita respuestas excesivamente largas)
_HISTORIAL_VENTANA_MAX_INDIVIDUAL = 6  # >6 meses → auto-switch a AVG mensual en historial


def _detectar_n_muestras_tendencia(q: str) -> int:
    """Extrae cuántas muestras usar en tendencia por equipo. Default 6, máximo 12."""
    m = _RE_ULTIMOS_N.search(q or "")
    if m:
        return min(int(m.group(1)), _N_TENDENCIA_MAX)
    m = _RE_VENTANA_MESES.search(q or "")
    if m:
        # Interpreta "últimas X muestras" si el usuario dice "últimos X" sin especificar unidad
        n = int(m.group(1))
        if n <= _N_TENDENCIA_MAX:
            return n
    return _N_TENDENCIA_DEFAULT

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
    return _buscar(_RE_MES_ACTUAL, q)


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
    return _buscar(_RE_PISTA_TRIAGE_OBSERVADOS, texto)


def _es_intencion_componentes_modelo(texto: str) -> bool:
    return _buscar(_RE_PISTA_COMPONENTES_MODELO, texto)


def _es_intencion_compartimiento_aceite(texto: str) -> bool:
    # Requiere AMBAS condiciones: mención de compartimiento Y mención de análisis de aceite.
    # Evita activar el refuerzo en consultas genéricas sobre motores sin contexto de aceite.
    return _buscar(_RE_PISTA_COMPARTIMIENTO_ACEITE, texto) and _buscar(_RE_PISTA_ANALISIS_ACEITE, texto)


def _es_intencion_laboratorio_aceite(texto: str) -> bool:
    return _buscar(_RE_PISTA_LABORATORIO_ACEITE, texto)


def _es_intencion_dimensional(texto: str) -> bool:
    return _buscar(_RE_PISTA_DIMENSIONAL, texto)


def _es_intencion_join_proyecto_modelo(texto: str) -> bool:
    """
    Detecta consultas que cruzan datos de aceite con proyecto y/o modelo de equipo.
    Requiere mención de aceite Y al menos proyecto O modelo. No aplica a triage puro.
    """
    tiene_aceite = _buscar(_RE_PISTA_LABORATORIO_ACEITE, texto) or _buscar(_RE_PISTA_ANALISIS_ACEITE, texto)
    tiene_proyecto = _buscar(_RE_PISTA_PROYECTO_MINERO, texto)
    tiene_modelo = _buscar(_RE_PISTA_MODELO_EQUIPO, texto)
    return tiene_aceite and (tiene_proyecto or tiene_modelo)


def _es_intencion_ultimo_ventana(texto: str) -> bool:
    return _buscar(_RE_PISTA_ULTIMO_VENTANA, texto)


def _usuario_pide_excluir_nulos(texto: str) -> bool:
    return _buscar(_RE_PISTA_EXCLUSION_NULOS, texto)


def _es_intencion_comparativa(texto: str) -> bool:
    return _buscar(_RE_PISTA_COMPARACION, texto)


def _es_intencion_continuidad(texto: str, contexto: str) -> bool:
    # La continuidad solo aplica si HAY contexto previo. Sin contexto, no hay referencia posible.
    c = contexto or ""
    return bool(c.strip()) and _buscar(_RE_PISTA_CONTINUIDAD, texto)


def _es_intencion_sintesis_interpretacion(texto: str) -> bool:
    return _buscar(_RE_PISTA_SINTESIS_INTERPRETACION, texto)


def _es_intencion_criticidad(texto: str) -> bool:
    return _buscar(_RE_PISTA_CRITICIDAD, texto)


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
          "Proyectos mineros → [Mine].[MiningProject] (PK: Id | columnas: Name, Department, Client). "
          "Modelos y tipos de equipo → [Mine].[EquipmentFleet] (PK: Id | columnas: Model, Type, Description). "
          "Equipos individuales → [Mine].[MiningEquipment] "
          "(PK: Id | Code = identificador ej:'CA3160' — NO es el modelo; "
          "COLUMNAS INEXISTENTES — NUNCA usar: EquipmentCode, EquipmentId, ModelCode, FleetCode; "
          "FK EquipmentFleetId → [Mine].[EquipmentFleet]; FK MiningProjectId → [Mine].[MiningProject]). "
          "Para CONTAR o LISTAR equipos por modelo y proyecto: "
          "SELECT COUNT(ME.[Id]) FROM [Mine].[MiningEquipment] ME WITH (NOLOCK) "
          "JOIN [Mine].[EquipmentFleet] EF WITH (NOLOCK) ON EF.[Id]=ME.[EquipmentFleetId] "
          "JOIN [Mine].[MiningProject] MP WITH (NOLOCK) ON MP.[Id]=ME.[MiningProjectId] "
          "WHERE MP.[Name] LIKE '%Antapaccay%' AND EF.[Model] LIKE '%980%'. "
          "Para listar compartimientos → SELECT DISTINCT [Compartimiento] FROM [Oil].[LaboratoryData] WHERE [Compartimiento] IS NOT NULL. "
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
          "reductor o convertidor dentro del contexto de análisis de aceite, interprétalo como un valor "
          "del campo LD.[Compartimiento] en [Oil].[LaboratoryData]. "
          "Valores reales en BD (usar LIKE con keyword corto, NUNCA frase compuesta con 'DE'): "
          "'MOTOR DE TRACCION RH'/'LH' → LIKE '%TRACCION%'; "
          "'SISTEMA HIDRAULICO' → LIKE '%HIDRAUL%'; "
          "'RUEDA DELANTERA RH'/'LH' → LIKE '%RUEDA%'; "
          "'MOTOR' (motor principal) → LIKE '%MOTOR%' AND NOT LIKE '%TRACCION%'. "
          "Prefiere filtrar con LIKE sobre Compartimiento. "
          "NO uses dbo.Component.ComponentName salvo que el usuario pida explícitamente el catálogo de componentes."
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
        + " | IMPORTANTE: si la consulta implica comparar 2 campos o 2 entidades (A vs B), el SELECT DEBE incluir "
          "las 2 métricas y una columna Diferencia = (A - B), ordenar por Diferencia DESC. "
          "Para comparar ENTRE PROYECTOS (ej: Antapaccay vs Cerro Verde): "
          "usar AVG(LD.[Fe_ppm]) GROUP BY MP.[Name] — incluir MP.[Name] en SELECT y GROUP BY. "
          "Para comparar entre modelos: GROUP BY EF.[Model]. "
          "Para comparar entre compartimientos: GROUP BY LD.[Compartimiento]. "
          "NUNCA inventar valores de límite LP/LC — si se piden, obtenerlos de [Eqpcare].[lc] con ISNULL(...,9999)."
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
          "prioriza el orden descendente por las métricas de desgaste o contaminación mencionadas. "
          "Evita inventar umbrales operativos que no existan en la base. "
          "Para 'el más alto/mayor/top N' por metal: "
          "CTE con ROW_NUMBER() OVER (PARTITION BY LD.[MiningEquipmentId],LD.[Compartimiento] "
          "ORDER BY LD.[FechaMuestreo] DESC) AS rn → WHERE rn=1 → ORDER BY metal DESC. "
          "NUNCA ordenes solo por fecha ni uses MAX() sin deduplicar por equipo primero. "
          "EXCEPCIÓN TBN: TBN bajo es malo (falla de aceite). "
          "Para 'el peor TBN': ORDER BY TBN ASC (no DESC). "
          "Para triage por TBN: WHERE LS.[TBN] < LC.[TBN - LP] (menor que LP = observado)."
    )


def _reforzar_consulta_agregacion(q: str) -> str:
    """Instrucciones para queries de agregación (AVG/MAX/MIN/COUNT + GROUP BY) en SQL Server."""
    return (
        q.strip()
        + " | AGREGACION-SQL: para consultas de promedio/máximo/mínimo/conteo en SQL Server: "
          "1. Usar AVG(LD.[Fe_ppm]), MAX(LD.[Fe_ppm]), MIN(LD.[Fe_ppm]), COUNT(*) directamente. "
          "2. GROUP BY las columnas de agrupación: MP.[Name] (por proyecto), EF.[Model] (por modelo), "
          "LD.[Compartimiento] (por compartimiento), EOMONTH(LD.[FechaMuestreo]) (por mes). "
          "3. NUNCA usar ROW_NUMBER en consultas de agregación — ROW_NUMBER deduplica registros, no agrupa. "
          "4. HAVING para filtrar después del GROUP BY (ej: HAVING AVG(LD.[Fe_ppm])>100). "
          "5. Para 'cuántas muestras': COUNT(LD.[LaboratoryDataId]). "
          "6. En SQL Server: ORDER BY la misma expresión del SELECT (no alias en ORDER BY si no está en SELECT → error 8127). "
          "7. Siempre WITH (NOLOCK) en todas las tablas."
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

# Regex de intención: "último análisis", "última muestra", "registro más reciente", etc.
# Incluye variantes coloquiales: "el más reciente", "dato más reciente", "info más reciente".
# NO aplica si hay lenguaje de triage (eso se guarda por la guardia _es_intencion_triage_observados).
_RE_PISTA_ULTIMO_ANALISIS_FLOTA = re.compile(
    r"\b(?:"
    r"últi(?:mo|ma)\s+(?:an[aá]lisis|resultado|reporte|muestreo|muestra|toma|registro|dato|informe|lectura)"
    r"|últimos?\s+(?:resultados?|an[aá]lisis|registros?|datos?)"
    r"|(?:registro|dato|resultado|informe|an[aá]lisis|muestra|lectura)s?\s+m[aá]s\s+recientes?"
    r")\b",
    re.IGNORECASE,
)


def _es_intencion_ultimo_analisis_flota(texto: str) -> bool:
    return _buscar(_RE_PISTA_ULTIMO_ANALISIS_FLOTA, texto)


# Intención de evaluar la CONDICIÓN/ESTADO de un equipo contra sus límites LP/LC.
# Distinto de triage puro (que filtra SOLO observados): aquí el usuario pide ver
# el estado completo de un equipo específico vs límites. Caso típico del inspector:
# "condición del MT del 3171", "cómo está el EMT izquierdo del 3198 vs límites".
_RE_PISTA_CONDICION_EVAL = re.compile(
    r"\b(condici[oó]n|estado|c[oó]mo\s+est[aá]|diagn[oó]stico|diagnostica|"
    r"eval[uú]a(?:r|me)?|evaluaci[oó]n|"
    r"vs\s+l[ií]mite|contra\s+(?:el\s+|sus\s+)?l[ií]mite|respecto\s+a\s+(?:los?\s+)?l[ií]mite|"
    r"fuera\s+de\s+l[ií]mite|dentro\s+de\s+l[ií]mite|"
    r"observad[ao]|cr[ií]tic[ao]|precauci[oó]n|fuera\s+de\s+rango)\b",
    re.IGNORECASE,
)


def _es_intencion_condicion_eval(texto: str) -> bool:
    return _buscar(_RE_PISTA_CONDICION_EVAL, texto)


# Regex para "últimos N análisis/registros" — usado en consulta_humana_a_sql() como hint al LLM
# para que genere TOP(N) o rn<=N en vez de rn=1.
_RE_ULTIMOS_N = re.compile(
    r"\b[uú]ltim[oa]s?\s+(\d+)\s+(?:an[aá]lisis|registro[s]?|muestra[s]?|resultado[s]?|reporte[s]?)\b",
    re.IGNORECASE,
)


def intentar_conteo_flota_directo(consulta_humana: str) -> Optional[str]:
    """
    Genera SQL de conteo de equipos por modelo/proyecto directamente en Python.

    Activa cuando el usuario pregunta "cuántos [camiones/equipos/unidades] [modelo] tiene [proyecto]".
    Evita que el LLM invente columnas inexistentes como EquipmentCode o EquipmentId.

    SQL generado: COUNT(ME.[Id]) con JOIN ME→EF→MP, filtrando por modelo y/o proyecto.
    Retorna None si no hay modelo ni proyecto detectado.
    """
    # Activar solo si hay intención de conteo explícita
    if not re.search(
        r"\bcu[aá]nt(?:o[s]?|a[s]?)\b|\bn[uú]mero\s+de\b|\bcantidad\s+de\b|\bcont(?:ar|eo)\b",
        consulta_humana, re.IGNORECASE
    ):
        return None
    # No activar para queries de aceite/triage/historial — tienen sus propios paths
    if _es_intencion_triage_observados(consulta_humana):
        return None
    if _es_intencion_laboratorio_aceite(consulta_humana):
        return None

    proyecto = _detectar_proyecto(consulta_humana)
    # Detectar modelo de equipo en la consulta
    m_modelo = re.search(
        r"\b(980[Ee]?(?:-\d)?|930[Ee]?|d475|d375|d155|hd[0-9]+|wa[0-9]+|pc[0-9]+)\b",
        consulta_humana, re.IGNORECASE
    )
    modelo_str = m_modelo.group(1).upper() if m_modelo else None

    # Necesitamos al menos proyecto o modelo para que el query sea determinístico
    if not proyecto and not modelo_str:
        return None

    _where_modelo = f" AND EF.[Model] LIKE '%{modelo_str}%'" if modelo_str else ""
    _where_proyecto = f" AND MP.[Name] LIKE '%{proyecto}%'" if proyecto else ""

    # Alias descriptivo para la columna de resultado
    if modelo_str and proyecto:
        alias = f"[Total_{modelo_str}_en_{proyecto.replace(' ', '_')}]"
    elif modelo_str:
        alias = f"[Total_{modelo_str}]"
    else:
        alias = f"[Total_Equipos_{proyecto.replace(' ', '_')}]"

    sql = (
        f"SELECT COUNT(ME.[Id]) AS {alias}, "
        f"MP.[Name] AS [Proyecto], EF.[Model] AS [Modelo] "
        f"FROM [Mine].[MiningEquipment] ME WITH (NOLOCK) "
        f"JOIN [Mine].[EquipmentFleet] EF WITH (NOLOCK) ON EF.[Id]=ME.[EquipmentFleetId] "
        f"JOIN [Mine].[MiningProject] MP WITH (NOLOCK) ON MP.[Id]=ME.[MiningProjectId] "
        f"WHERE 1=1{_where_modelo}{_where_proyecto} "
        f"GROUP BY MP.[Name], EF.[Model] "
        f"ORDER BY MP.[Name], EF.[Model]"
    )
    return sql


def intentar_ultimo_analisis_con_limites_directo(consulta_humana: str) -> Optional[str]:
    """
    Genera SQL del último análisis por equipo+compartimiento CON columnas LP/LC incluidas.

    Caso de uso: el usuario pide el último análisis de un equipo/flota Y quiere ver
    el estado vs límites en la misma respuesta (sin filtrar a solo los observados).

    Ejemplos:
      "dame un barrido del último análisis del CA3160 y cuál está fuera de límites"
      "último análisis del 3177 con sus límites"
      "cómo está el CA3164 en su último análisis vs los límites"

    Diferencia con intentar_triage_directo:
      - Triage devuelve SOLO los que superan LP/LC (filtro WHERE).
      - Este path devuelve TODOS con columnas LP/LC visibles + estado computado.
      - Ideal para inspeccionar un equipo individual o subconjunto pequeño.

    Diferencia con intentar_ultimo_analisis_flota_directo:
      - Este path incluye LP/LC columns (CROSS JOIN LimitesLC).
      - Requiere compartimiento detectado (para hacer el JOIN a lc).

    Retorna None si no aplica → cae al intentar_triage_directo o LLM.
    """
    # Tendencia/historial tienen sus propios paths — no robar esas consultas.
    if _es_intencion_tendencia_historica(consulta_humana):
        return None
    if _es_intencion_muestras_individuales(consulta_humana):
        return None

    like_comp = _detectar_like_compartimiento(consulta_humana)
    equipo_code = _detectar_equipo_code(consulta_humana)
    proyecto = _detectar_proyecto(consulta_humana)

    # Sin compartimiento no podemos hacer el JOIN a [Eqpcare].[lc]
    if not like_comp or like_comp in ("None", "MOTOR"):
        return None

    # ── Disparadores ─────────────────────────────────────────────────────────
    # Caso A (PRINCIPAL del inspector): equipo específico + intención de evaluar
    #   condición/estado/límites. Ej: "condición del MT del 3171", "cómo está el
    #   EMT izquierdo del 3198 vs límites". Devuelve el equipo con LP/LC + Estado.
    # Caso B (barrido): "último análisis ... y cuál está fuera de límites" —
    #   combo de último-análisis + triage sobre un equipo/proyecto.
    # Pure triage de proyecto ("dame los OBSERVADOS de la flota") NO entra aquí:
    #   eso lo maneja intentar_triage_directo (filtra solo a los observados).
    caso_a = bool(equipo_code) and _es_intencion_condicion_eval(consulta_humana)
    caso_b = (
        _es_intencion_ultimo_analisis_flota(consulta_humana)
        and _es_intencion_triage_observados(consulta_humana)
    )
    if not caso_a and not caso_b:
        return None
    # Necesitamos al menos equipo O proyecto para un query determinístico
    if not equipo_code and not proyecto:
        return None

    proyecto_inferido = not bool(proyecto)
    if not proyecto:
        proyecto = "Antapaccay"

    _fe_lp_fallback = _PROYECTO_FE_LP_FALLBACK.get(proyecto, 9999)
    _join_980e, _where_980e = _join_modelo_antapaccay(None if proyecto_inferido else proyecto)
    _where_comp = f" AND LD.[Compartimiento] LIKE '{like_comp}'"
    # Lado izquierdo/derecho (LH/RH): filtra SOLO las muestras (LaboratoryData), NO los límites
    # (LP/LC son iguales por lado). Si el usuario dice "MT izquierdo", devolver solo LH — evita
    # que el RH contamine las recomendaciones con max() sobre filas no mostradas.
    _where_lado_sql = _where_lado(_detectar_lado(consulta_humana))
    _where_proy = f" AND MP.[Name] LIKE '%{proyecto}%'"
    _where_cm = _where_excluir_cm()

    grado = _detectar_grado_aceite(consulta_humana)
    _where_grado = f" AND {_grado_where_clause(grado)}" if grado else ""

    if equipo_code:
        _where_equipo = (
            f" AND ME.[Code] LIKE '{equipo_code}'"
            if equipo_code.startswith("%")
            else f" AND ME.[Code]='{equipo_code}'"
        )
    else:
        _where_equipo = ""

    # CTE LimitesLC — mismo patrón CROSS JOIN que intentar_triage_directo
    _lc_cols = (
        f"MIN([FIERRO - LP]) AS [FIERRO - LP],MIN([FIERRO - LC]) AS [FIERRO - LC],"
        f"MIN([COBRE - LP]) AS [COBRE - LP],MIN([COBRE - LC]) AS [COBRE - LC],"
        f"MIN([SILICIO - LP]) AS [SILICIO - LP],MIN([SILICIO - LC]) AS [SILICIO - LC],"
        f"MIN([ALUMINIO - LP]) AS [ALUMINIO - LP],MIN([ALUMINIO - LC]) AS [ALUMINIO - LC],"
        f"MIN([CROMO - LP]) AS [CROMO - LP],MIN([CROMO - LC]) AS [CROMO - LC],"
        f"MIN([NIQUEL - LP]) AS [NIQUEL - LP],MIN([NIQUEL - LC]) AS [NIQUEL - LC],"
        f"MIN([PLOMO - LP]) AS [PLOMO - LP],MIN([ESTAÑO - LP]) AS [ESTAÑO - LP],"
        f"MIN([PQ - LP]) AS [PQ - LP],MIN([PQ - LC]) AS [PQ - LC],"
        f"MAX([TBN - LP]) AS [TBN - LP]"
    )

    sql = (
        f"WITH LatestSamples AS ("
        f"SELECT ME.[Code] AS [EquipmentCode],MP.[Name] AS [Proyecto],LD.[Compartimiento],"
        f"LD.[FechaMuestreo],LD.[Horometro],LD.[HorasDeAceite],LD.[CM],"
        f"LD.[Fe_ppm],LD.[Cr_ppm],LD.[Ni_ppm],LD.[Pb_ppm],LD.[Sn_ppm],"
        f"LD.[Cu_ppm],LD.[Si_ppm],LD.[Al_ppm],LD.[Indice_PQ],LD.[TBN],LD.[Grado],"
        f"ROW_NUMBER() OVER (PARTITION BY LD.[MiningEquipmentId],LD.[Compartimiento] "
        f"ORDER BY LD.[FechaMuestreo] DESC) AS rn "
        f"FROM [Oil].[LaboratoryData] LD WITH (NOLOCK) "
        f"JOIN [Mine].[MiningEquipment] ME WITH (NOLOCK) ON ME.[Id]=LD.[MiningEquipmentId] "
        f"JOIN [Mine].[MiningProject] MP WITH (NOLOCK) ON MP.[Id]=ME.[MiningProjectId]"
        f"{_join_980e} "
        f"WHERE LD.[FechaMuestreo]>=DATEADD(YEAR,-2,GETDATE())"
        f"{_where_comp}{_where_lado_sql}{_where_proy}{_where_equipo}{_where_980e}{_where_cm}{_where_grado}"
        f"), "
        f"LimitesLC AS ("
        f"SELECT {_lc_cols} "
        f"FROM [Eqpcare].[lc] WITH (NOLOCK) "
        f"WHERE [Proyecto] LIKE '%{proyecto}%' AND [COMPONENTE] LIKE '{like_comp}'"
        f") "
        f"SELECT TOP(200) "
        f"LS.[EquipmentCode],LS.[Proyecto],LS.[Compartimiento],LS.[FechaMuestreo],"
        f"LS.[Fe_ppm],LC.[FIERRO - LP],LC.[FIERRO - LC],"
        f"LS.[Cu_ppm],LC.[COBRE - LP],LC.[COBRE - LC],"
        f"LS.[Si_ppm],LC.[SILICIO - LP],LC.[SILICIO - LC],"
        f"LS.[Al_ppm],LC.[ALUMINIO - LP],LC.[ALUMINIO - LC],"
        f"LS.[Cr_ppm],LC.[CROMO - LP],LC.[CROMO - LC],"
        f"LS.[Ni_ppm],LC.[NIQUEL - LP],LC.[NIQUEL - LC],"
        f"LS.[Pb_ppm],LC.[PLOMO - LP],"
        f"LS.[Indice_PQ],LC.[PQ - LP],LC.[PQ - LC],"
        f"LS.[TBN],LC.[TBN - LP],"
        f"LS.[HorasDeAceite],LS.[CM],LS.[Grado],"
        f"CASE "
        f"WHEN LS.[Fe_ppm]>ISNULL(LC.[FIERRO - LC],9999) OR LS.[Cu_ppm]>ISNULL(LC.[COBRE - LC],9999) "
        f"  OR LS.[Si_ppm]>ISNULL(LC.[SILICIO - LC],9999) OR LS.[Cr_ppm]>ISNULL(LC.[CROMO - LC],9999) "
        f"  OR LS.[Ni_ppm]>ISNULL(LC.[NIQUEL - LC],9999) OR LS.[Indice_PQ]>ISNULL(LC.[PQ - LC],9999) "
        f"  OR (LC.[TBN - LP] IS NOT NULL AND LS.[TBN]>0 AND LS.[TBN]<LC.[TBN - LP]) "
        f"THEN 'CRITICO' "
        f"WHEN LS.[Fe_ppm]>ISNULL(LC.[FIERRO - LP],{_fe_lp_fallback}) OR LS.[Cu_ppm]>ISNULL(LC.[COBRE - LP],9999) "
        f"  OR LS.[Si_ppm]>ISNULL(LC.[SILICIO - LP],9999) OR LS.[Cr_ppm]>ISNULL(LC.[CROMO - LP],9999) "
        f"  OR LS.[Ni_ppm]>ISNULL(LC.[NIQUEL - LP],9999) OR LS.[Indice_PQ]>ISNULL(LC.[PQ - LP],9999) "
        f"THEN 'PRECAUCION' "
        f"ELSE 'NORMAL' END AS [Estado] "
        f"FROM LatestSamples LS "
        f"CROSS JOIN LimitesLC LC "
        f"WHERE LS.rn=1 "
        f"ORDER BY LS.[EquipmentCode],LS.[Compartimiento]"
    )
    return sql


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

    ventana = _detectar_ventana_meses(consulta_humana, default=3)
    filtro_comp = f"LD.[Compartimiento] LIKE '{like_comp}'" + _where_lado(_detectar_lado(consulta_humana))

    grado = _detectar_grado_aceite(consulta_humana)
    _where_grado = f" AND {_grado_where_clause(grado)}" if grado else ""

    base_joins = (
        f"FROM [Oil].[LaboratoryData] LD WITH (NOLOCK) "
        f"JOIN [Mine].[MiningEquipment] ME WITH (NOLOCK) ON ME.[Id]=LD.[MiningEquipmentId] "
        f"JOIN [Mine].[MiningProject] MP WITH (NOLOCK) ON MP.[Id]=ME.[MiningProjectId]"
    )
    _join_980e, _where_980e = _join_modelo_antapaccay(proyecto)

    # Auto-switch: si la ventana supera 6 meses, agrupa por mes (AVG mensual) en lugar de
    # devolver miles de filas individuales. La columna [Mes] es reconocida por analitica.py.
    if ventana > _HISTORIAL_VENTANA_MAX_INDIVIDUAL:
        filtro_fecha_avg = f"LD.[FechaMuestreo]>=DATEADD(MONTH,-{ventana},GETDATE())"
        if equipo_code:
            where_equipo = (
                f"ME.[Code] LIKE '{equipo_code}'"
                if equipo_code.startswith("%")
                else f"ME.[Code]='{equipo_code}'"
            )
            sql = (
                f"SELECT ME.[Code] AS [Equipo],MP.[Name] AS [Proyecto],LD.[Compartimiento],"
                f"EOMONTH(LD.[FechaMuestreo]) AS [Mes],"
                f"AVG(LD.[Fe_ppm]) AS [Fe_ppm],AVG(LD.[Cr_ppm]) AS [Cr_ppm],"
                f"AVG(LD.[Ni_ppm]) AS [Ni_ppm],AVG(LD.[Pb_ppm]) AS [Pb_ppm],AVG(LD.[Sn_ppm]) AS [Sn_ppm],"
                f"AVG(LD.[Cu_ppm]) AS [Cu_ppm],AVG(LD.[Si_ppm]) AS [Si_ppm],AVG(LD.[Al_ppm]) AS [Al_ppm],"
                f"AVG(LD.[Indice_PQ]) AS [Indice_PQ],AVG(LD.[TBN]) AS [TBN],"
                f"COUNT(*) AS [NMuestras] "
                f"{base_joins}{_join_980e} "
                f"WHERE {filtro_comp} AND {where_equipo} "
                f"AND {filtro_fecha_avg}{_where_980e}{_where_grado} "
                f"GROUP BY ME.[Code],MP.[Name],LD.[Compartimiento],EOMONTH(LD.[FechaMuestreo]) "
                f"ORDER BY [Equipo],[Compartimiento],[Mes] ASC"
            )
        else:
            sql = (
                f"SELECT MP.[Name] AS [Proyecto],LD.[Compartimiento],"
                f"EOMONTH(LD.[FechaMuestreo]) AS [Mes],"
                f"AVG(LD.[Fe_ppm]) AS [Fe_ppm],AVG(LD.[Cr_ppm]) AS [Cr_ppm],"
                f"AVG(LD.[Ni_ppm]) AS [Ni_ppm],AVG(LD.[Pb_ppm]) AS [Pb_ppm],AVG(LD.[Sn_ppm]) AS [Sn_ppm],"
                f"AVG(LD.[Cu_ppm]) AS [Cu_ppm],AVG(LD.[Si_ppm]) AS [Si_ppm],AVG(LD.[Al_ppm]) AS [Al_ppm],"
                f"AVG(LD.[Indice_PQ]) AS [Indice_PQ],AVG(LD.[TBN]) AS [TBN],"
                f"COUNT(DISTINCT ME.[Id]) AS [NEquipos],COUNT(*) AS [NMuestras] "
                f"{base_joins}{_join_980e} "
                f"WHERE {filtro_comp} AND MP.[Name] LIKE '%{proyecto}%' "
                f"AND {filtro_fecha_avg}{_where_980e}{_where_grado} "
                f"GROUP BY MP.[Name],LD.[Compartimiento],EOMONTH(LD.[FechaMuestreo]) "
                f"ORDER BY [Proyecto],[Compartimiento],[Mes] ASC"
            )
        return sql

    # Muestras individuales (ventana ≤ 6 meses)
    # Columnas base: fecha + código de equipo + compartimiento + métricas MT completas
    # + campos operativos (Condicion, Horometro, CodigoMuestreo, Oxidacion, Agua).
    filtro_fecha = f"LD.[FechaMuestreo]>=DATEADD(MONTH,-{ventana},GETDATE())"
    base_cols = (
        f"LD.[FechaMuestreo],ME.[Code] AS [Equipo],LD.[Compartimiento],LD.[Grado],"
        f"LD.[Condicion],LD.[CodigoMuestreo],LD.[Horometro],"
        f"LD.[Fe_ppm],LD.[Cr_ppm],LD.[Ni_ppm],LD.[Pb_ppm],LD.[Sn_ppm],"
        f"LD.[Cu_ppm],LD.[Si_ppm],LD.[Al_ppm],LD.[Indice_PQ],"
        f"LD.[B_ppm],LD.[P_ppm],LD.[V100],LD.[TBN],LD.[HorasDeAceite],"
        f"LD.[Oxidacion],LD.[Agua]"
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
            f"{base_joins}{_join_980e} "
            f"WHERE {filtro_comp} AND {where_equipo} AND {filtro_fecha}{_where_980e}{_where_grado} "
            f"ORDER BY LD.[FechaMuestreo] DESC"
        )
    else:
        # Sin equipo específico: filtrar por proyecto para acotar el universo.
        sql = (
            f"SELECT TOP(500) {base_cols} "
            f"{base_joins}{_join_980e} "
            f"WHERE {filtro_comp} AND MP.[Name] LIKE '%{proyecto}%' AND {filtro_fecha}{_where_980e}{_where_grado} "
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

    _where_comp = (f" AND LD.[Compartimiento] LIKE '{like_comp}'" + _where_lado(_detectar_lado(consulta_humana))) if like_comp else ""
    _where_proy = f" AND MP.[Name] LIKE '%{proyecto}%'" if proyecto else ""

    grado = _detectar_grado_aceite(consulta_humana)
    _where_grado = f" AND {_grado_where_clause(grado)}" if grado else ""
    _join_980e, _where_980e = _join_modelo_antapaccay(proyecto)

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
        f"JOIN [Mine].[MiningProject] MP WITH (NOLOCK) ON MP.[Id]=ME.[MiningProjectId]"
        f"{_join_980e} "
        f"WHERE LD.[FechaMuestreo]>=DATEADD(YEAR,-2,GETDATE()){_sql_fecha_corte}"
        f"{_where_comp}{_where_proy}{_where_980e}{_where_grado}"
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
    Genera SQL de tendencia histórica directamente en Python, sin LLM.

    Dos modos según lo que el usuario pide:
    - DEFAULT (muestras individuales): últimas N muestras por equipo+compartimiento usando
      ROW_NUMBER() ORDER BY FechaMuestreo DESC → WHERE rn<=N → ORDER BY FechaMuestreo ASC.
      N=6 por defecto, máx 12 (_detectar_n_muestras_tendencia).
      Equipo path incluye LP/LC de [Eqpcare].[lc]. Proyecto/else paths sin LP/LC.
    - AVG POR PERIODO (cuando usuario dice "mensual", "trimestral", "anual", etc.):
      AVG de métricas GROUP BY expresión de periodo (_PERIODO_AGG_MAP).
      Columna de salida: [Mes] (mensual) o [Periodo] (otros) → reconocida por analitica.py.
      Ventana temporal: determinada por el periodo elegido o por mención explícita del usuario.

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

    base_joins = (
        f"FROM [Oil].[LaboratoryData] LD WITH (NOLOCK) "
        f"JOIN [Mine].[MiningEquipment] ME WITH (NOLOCK) ON ME.[Id]=LD.[MiningEquipmentId] "
        f"JOIN [Mine].[MiningProject] MP WITH (NOLOCK) ON MP.[Id]=ME.[MiningProjectId]"
    )
    filtro_comp = f"LD.[Compartimiento] LIKE '{like_comp}'" + _where_lado(_detectar_lado(consulta_humana))

    _join_980e, _where_980e = _join_modelo_antapaccay(proyecto)

    periodo_agg = _detectar_periodo_agrupacion(consulta_humana)

    # ── Helper: CTE LimitesLC (reutilizado en varios paths) ──────────────────────
    def _limites_cte(filtro_proyecto: str) -> str:
        return (
            f"LimitesLC AS ("
            f"SELECT MIN([FIERRO - LP]) AS [FIERRO - LP],MIN([FIERRO - LC]) AS [FIERRO - LC],"
            f"MIN([ALUMINIO - LP]) AS [ALUMINIO - LP],MIN([ALUMINIO - LC]) AS [ALUMINIO - LC],"
            f"MIN([COBRE - LP]) AS [COBRE - LP],MIN([COBRE - LC]) AS [COBRE - LC],"
            f"MIN([SILICIO - LP]) AS [SILICIO - LP],MIN([SILICIO - LC]) AS [SILICIO - LC],"
            f"MIN([CROMO - LP]) AS [CROMO - LP],MIN([CROMO - LC]) AS [CROMO - LC],"
            f"MIN([NIQUEL - LP]) AS [NIQUEL - LP],MIN([NIQUEL - LC]) AS [NIQUEL - LC],"
            f"MIN([PQ - LP]) AS [PQ - LP],MIN([PQ - LC]) AS [PQ - LC],"
            f"MAX([TBN - LP]) AS [TBN - LP],MAX([TBN - LC]) AS [TBN - LC] "
            f"FROM [Eqpcare].[lc] WITH (NOLOCK) "
            f"WHERE [COMPONENTE] LIKE '{like_comp}' AND {filtro_proyecto}"
            f")"
        )

    _lc_select = (
        "l.[FIERRO - LP],l.[FIERRO - LC],l.[ALUMINIO - LP],l.[ALUMINIO - LC],"
        "l.[COBRE - LP],l.[COBRE - LC],l.[SILICIO - LP],l.[SILICIO - LC],"
        "l.[CROMO - LP],l.[CROMO - LC],l.[NIQUEL - LP],l.[NIQUEL - LC],"
        "l.[PQ - LP],l.[PQ - LC],l.[TBN - LP],l.[TBN - LC]"
    )

    if equipo_code:
        where_equipo_t = (
            f"ME.[Code] LIKE '{equipo_code}'"
            if equipo_code.startswith("%")
            else f"ME.[Code]='{equipo_code}'"
        )
        _wt = _where_excluir_cm()

        if periodo_agg:
            # ── EQUIPO · AVG por periodo (mensual / trimestral / anual / etc.) ──
            _expr, _alias, _ventana_def = periodo_agg
            _ventana_agg = _detectar_ventana_meses(consulta_humana, default=_ventana_def)
            sql = (
                f"WITH Mensual AS ("
                f"SELECT ME.[Code] AS [Equipo],MP.[Name] AS [Proyecto],LD.[Compartimiento],"
                f"{_expr} AS [{_alias}],"
                f"AVG(LD.[Fe_ppm]) AS [Fe_ppm],AVG(LD.[Cr_ppm]) AS [Cr_ppm],"
                f"AVG(LD.[Ni_ppm]) AS [Ni_ppm],AVG(LD.[Pb_ppm]) AS [Pb_ppm],AVG(LD.[Sn_ppm]) AS [Sn_ppm],"
                f"AVG(LD.[Cu_ppm]) AS [Cu_ppm],AVG(LD.[Si_ppm]) AS [Si_ppm],AVG(LD.[Al_ppm]) AS [Al_ppm],"
                f"AVG(LD.[Indice_PQ]) AS [Indice_PQ],AVG(LD.[TBN]) AS [TBN],"
                f"AVG(LD.[HorasDeAceite]) AS [HorasDeAceite],COUNT(*) AS [NMuestras] "
                f"FROM [Oil].[LaboratoryData] LD WITH (NOLOCK) "
                f"JOIN [Mine].[MiningEquipment] ME WITH (NOLOCK) ON ME.[Id]=LD.[MiningEquipmentId] "
                f"JOIN [Mine].[MiningProject] MP WITH (NOLOCK) ON MP.[Id]=ME.[MiningProjectId]"
                f"{_join_980e} "
                f"WHERE {filtro_comp} AND {where_equipo_t} "
                f"AND LD.[FechaMuestreo]>=DATEADD(MONTH,-{_ventana_agg},GETDATE()){_wt}{_where_grado}{_where_980e} "
                f"GROUP BY ME.[Code],MP.[Name],LD.[Compartimiento],{_expr}"
                f"),"
                f"{_limites_cte('[Proyecto] IN (SELECT DISTINCT [Proyecto] FROM Mensual)')} "
                f"SELECT m.[Equipo],m.[Proyecto],m.[Compartimiento],m.[{_alias}],"
                f"m.[Fe_ppm],m.[Cr_ppm],m.[Ni_ppm],m.[Pb_ppm],m.[Sn_ppm],"
                f"m.[Cu_ppm],m.[Si_ppm],m.[Al_ppm],m.[Indice_PQ],m.[TBN],"
                f"m.[HorasDeAceite],m.[NMuestras],{_lc_select} "
                f"FROM Mensual m LEFT JOIN LimitesLC l ON 1=1 "
                f"ORDER BY m.[Compartimiento],m.[{_alias}] ASC"
            )
        else:
            # ── EQUIPO · Default: últimas N muestras individuales + LP/LC ──────────
            n_muestras = _detectar_n_muestras_tendencia(consulta_humana)
            sql = (
                f"WITH Samples AS ("
                f"SELECT ME.[Code] AS [Equipo],MP.[Name] AS [Proyecto],LD.[Compartimiento],LD.[FechaMuestreo],"
                f"LD.[Fe_ppm],LD.[Cr_ppm],LD.[Ni_ppm],LD.[Pb_ppm],LD.[Sn_ppm],"
                f"LD.[Cu_ppm],LD.[Si_ppm],LD.[Al_ppm],LD.[Indice_PQ],LD.[TBN],"
                f"LD.[HorasDeAceite],LD.[Horometro],"
                f"ROW_NUMBER() OVER (PARTITION BY LD.[MiningEquipmentId],LD.[Compartimiento] "
                f"ORDER BY LD.[FechaMuestreo] DESC) AS rn "
                f"FROM [Oil].[LaboratoryData] LD WITH (NOLOCK) "
                f"JOIN [Mine].[MiningEquipment] ME WITH (NOLOCK) ON ME.[Id]=LD.[MiningEquipmentId] "
                f"JOIN [Mine].[MiningProject] MP WITH (NOLOCK) ON MP.[Id]=ME.[MiningProjectId]"
                f"{_join_980e} "
                f"WHERE {filtro_comp} AND {where_equipo_t} "
                f"AND LD.[FechaMuestreo]>=DATEADD(YEAR,-3,GETDATE()){_wt}{_where_grado}{_where_980e}"
                f"),"
                f"{_limites_cte('[Proyecto] IN (SELECT DISTINCT [Proyecto] FROM Samples)')} "
                f"SELECT s.[Equipo],s.[Proyecto],s.[Compartimiento],s.[FechaMuestreo],"
                f"s.[Fe_ppm],s.[Cr_ppm],s.[Ni_ppm],s.[Pb_ppm],s.[Sn_ppm],"
                f"s.[Cu_ppm],s.[Si_ppm],s.[Al_ppm],s.[Indice_PQ],s.[TBN],"
                f"s.[HorasDeAceite],s.[Horometro],{_lc_select} "
                f"FROM Samples s LEFT JOIN LimitesLC l ON 1=1 "
                f"WHERE s.rn<={n_muestras} "
                f"ORDER BY s.[Compartimiento],s.[FechaMuestreo] ASC"
            )

    elif proyecto:
        _wt = _where_excluir_cm()

        if periodo_agg:
            # ── PROYECTO · AVG por periodo (mensual / trimestral / anual / etc.) ──
            _expr, _alias, _ventana_def = periodo_agg
            _ventana_agg = _detectar_ventana_meses(consulta_humana, default=_ventana_def)
            sql = (
                f"WITH Mensual AS ("
                f"SELECT LD.[Compartimiento],{_expr} AS [{_alias}],"
                f"AVG(LD.[Fe_ppm]) AS [Fe_ppm],AVG(LD.[Cr_ppm]) AS [Cr_ppm],"
                f"AVG(LD.[Ni_ppm]) AS [Ni_ppm],AVG(LD.[Pb_ppm]) AS [Pb_ppm],AVG(LD.[Sn_ppm]) AS [Sn_ppm],"
                f"AVG(LD.[Cu_ppm]) AS [Cu_ppm],AVG(LD.[Si_ppm]) AS [Si_ppm],AVG(LD.[Al_ppm]) AS [Al_ppm],"
                f"AVG(LD.[Indice_PQ]) AS [Indice_PQ],AVG(LD.[TBN]) AS [TBN],"
                f"COUNT(DISTINCT ME.[Id]) AS [NEquipos],COUNT(*) AS [NMuestras] "
                f"{base_joins}{_join_980e} "
                f"WHERE {filtro_comp} AND MP.[Name] LIKE '%{proyecto}%' "
                f"AND LD.[FechaMuestreo]>=DATEADD(MONTH,-{_ventana_agg},GETDATE()){_wt}{_where_grado}{_where_980e} "
                f"GROUP BY LD.[Compartimiento],{_expr}"
                f"),"
            )
            _filtro_proy_lc = f"[Proyecto] LIKE '%{proyecto}%'"
            sql += (
                f"{_limites_cte(_filtro_proy_lc)} "
                f"SELECT m.[Compartimiento],m.[{_alias}],"
                f"m.[Fe_ppm],m.[Cr_ppm],m.[Ni_ppm],m.[Pb_ppm],m.[Sn_ppm],"
                f"m.[Cu_ppm],m.[Si_ppm],m.[Al_ppm],m.[Indice_PQ],m.[TBN],"
                f"m.[NEquipos],m.[NMuestras],{_lc_select} "
                f"FROM Mensual m LEFT JOIN LimitesLC l ON 1=1 "
                f"ORDER BY m.[Compartimiento],m.[{_alias}] ASC"
            )
        else:
            # ── PROYECTO · Default: últimas N muestras por equipo (snapshot flota) ──
            n_muestras = _detectar_n_muestras_tendencia(consulta_humana)
            sql = (
                f"WITH Samples AS ("
                f"SELECT ME.[Code] AS [Equipo],LD.[Compartimiento],LD.[FechaMuestreo],"
                f"LD.[Fe_ppm],LD.[Cr_ppm],LD.[Ni_ppm],LD.[Pb_ppm],LD.[Sn_ppm],"
                f"LD.[Cu_ppm],LD.[Si_ppm],LD.[Al_ppm],LD.[Indice_PQ],LD.[TBN],"
                f"LD.[HorasDeAceite],LD.[Horometro],"
                f"ROW_NUMBER() OVER (PARTITION BY LD.[MiningEquipmentId],LD.[Compartimiento] "
                f"ORDER BY LD.[FechaMuestreo] DESC) AS rn "
                f"{base_joins}{_join_980e} "
                f"WHERE {filtro_comp} AND MP.[Name] LIKE '%{proyecto}%' "
                f"AND LD.[FechaMuestreo]>=DATEADD(YEAR,-3,GETDATE()){_wt}{_where_grado}{_where_980e}"
                f") "
                f"SELECT [Equipo],[Compartimiento],[FechaMuestreo],"
                f"[Fe_ppm],[Cr_ppm],[Ni_ppm],[Pb_ppm],[Sn_ppm],"
                f"[Cu_ppm],[Si_ppm],[Al_ppm],[Indice_PQ],[TBN],"
                f"[HorasDeAceite],[Horometro] "
                f"FROM Samples WHERE rn<={n_muestras} "
                f"ORDER BY [Equipo],[FechaMuestreo] ASC"
            )

    else:
        _wt = _where_excluir_cm()

        if periodo_agg:
            # ── ELSE · AVG por periodo sin proyecto (distingue flotas por proyecto) ──
            _expr, _alias, _ventana_def = periodo_agg
            _ventana_agg = _detectar_ventana_meses(consulta_humana, default=_ventana_def)
            sql = (
                f"SELECT MP.[Name] AS [Proyecto],LD.[Compartimiento],"
                f"{_expr} AS [{_alias}],"
                f"AVG(LD.[Fe_ppm]) AS [Fe_ppm],AVG(LD.[Cr_ppm]) AS [Cr_ppm],"
                f"AVG(LD.[Ni_ppm]) AS [Ni_ppm],AVG(LD.[Pb_ppm]) AS [Pb_ppm],AVG(LD.[Sn_ppm]) AS [Sn_ppm],"
                f"AVG(LD.[Cu_ppm]) AS [Cu_ppm],AVG(LD.[Si_ppm]) AS [Si_ppm],AVG(LD.[Al_ppm]) AS [Al_ppm],"
                f"AVG(LD.[Indice_PQ]) AS [Indice_PQ],AVG(LD.[TBN]) AS [TBN],"
                f"COUNT(*) AS [NMuestras] "
                f"{base_joins} "
                f"WHERE {filtro_comp} "
                f"AND LD.[FechaMuestreo]>=DATEADD(MONTH,-{_ventana_agg},GETDATE()){_wt}{_where_grado} "
                f"GROUP BY MP.[Name],LD.[Compartimiento],{_expr} "
                f"ORDER BY [Proyecto],[Compartimiento],[{_alias}] ASC"
            )
        else:
            # ── ELSE · Default: últimas N muestras sin proyecto ───────────────────
            n_muestras = _detectar_n_muestras_tendencia(consulta_humana)
            sql = (
                f"WITH Samples AS ("
                f"SELECT MP.[Name] AS [Proyecto],ME.[Code] AS [Equipo],"
                f"LD.[Compartimiento],LD.[FechaMuestreo],"
                f"LD.[Fe_ppm],LD.[Cr_ppm],LD.[Ni_ppm],LD.[Pb_ppm],LD.[Sn_ppm],"
                f"LD.[Cu_ppm],LD.[Si_ppm],LD.[Al_ppm],LD.[Indice_PQ],LD.[TBN],"
                f"LD.[HorasDeAceite],LD.[Horometro],"
                f"ROW_NUMBER() OVER (PARTITION BY LD.[MiningEquipmentId],LD.[Compartimiento] "
                f"ORDER BY LD.[FechaMuestreo] DESC) AS rn "
                f"{base_joins} "
                f"WHERE {filtro_comp} "
                f"AND LD.[FechaMuestreo]>=DATEADD(YEAR,-3,GETDATE()){_wt}{_where_grado}"
                f") "
                f"SELECT [Proyecto],[Equipo],[Compartimiento],[FechaMuestreo],"
                f"[Fe_ppm],[Cr_ppm],[Ni_ppm],[Pb_ppm],[Sn_ppm],"
                f"[Cu_ppm],[Si_ppm],[Al_ppm],[Indice_PQ],[TBN],"
                f"[HorasDeAceite],[Horometro] "
                f"FROM Samples WHERE rn<={n_muestras} "
                f"ORDER BY [Proyecto],[Equipo],[FechaMuestreo] ASC"
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
    equipo_code = _detectar_equipo_code(consulta_humana)

    # Guard: "MOTOR" (catch-all sin %) solo se permite si hay equipo específico;
    # sin equipo es demasiado ambiguo (¿motor de tracción? ¿motor principal?) → LLM.
    # "None" (string) = bug upstream → siempre al LLM.
    if not like_comp or like_comp == "None":
        return None
    if like_comp == "MOTOR" and not equipo_code:
        return None

    # Sin proyecto explícito → Antapaccay (proyecto principal de KomfIA).
    # El filtro 980E NO se aplica en este caso: la consulta es genérica y no
    # implica exclusividad de flota. Solo se aplica cuando el usuario menciona
    # explícitamente "Antapaccay" (proyecto_inferido=False).
    proyecto_inferido = not bool(proyecto)
    if not proyecto:
        proyecto = "Antapaccay"

    # Triage evalúa el estado ACTUAL: usa la muestra más reciente sin límite superior de fecha.
    # Solo aplica corte explícito si el usuario lo pide ("hasta abril").
    # _fecha_corte_defecto() NO se aplica aquí — excluiría muestras del mes en curso
    # y devolvería equipos como "observados" aunque ya tengan análisis nuevos normales.
    fecha_corte = _detectar_fecha_corte(consulta_humana)
    _sql_fecha_corte = f" AND LD.[FechaMuestreo]<='{fecha_corte}'" if fecha_corte else ""

    if equipo_code:
        _where_equipo = (
            f" AND ME.[Code] LIKE '{equipo_code}'"
            if equipo_code.startswith("%")
            else f" AND ME.[Code]='{equipo_code}'"
        )
    else:
        _where_equipo = ""

    grado = _detectar_grado_aceite(consulta_humana)
    _where_grado = f" AND {_grado_where_clause(grado)}" if grado else ""
    # Lado LH/RH: filtra SOLO las muestras, NO LimitesLC (LP/LC iguales por lado).
    _where_lado_t = _where_lado(_detectar_lado(consulta_humana))
    # 980E solo cuando Antapaccay fue mencionado explícitamente, nunca para defaults.
    _join_980e, _where_980e = _join_modelo_antapaccay(None if proyecto_inferido else proyecto)
    _where_cm = _where_excluir_cm()

    # Fallback Fe LP por proyecto: si el JOIN con LimitesLC no matchea (naming distinto
    # de [COMPONENTE] en [Eqpcare].[lc]), ISNULL(9999) silenciaría equipos realmente
    # observados. Solo Fe: es el único metal con LP confirmado en todos los proyectos.
    _fe_lp_fallback = _PROYECTO_FE_LP_FALLBACK.get(proyecto, 9999)

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
        f"JOIN [Mine].[MiningProject] MP WITH (NOLOCK) ON MP.[Id]=ME.[MiningProjectId]"
        f"{_join_980e} "
        f"WHERE LD.[Compartimiento] LIKE '{like_comp}'{_where_lado_t} "
        f"AND MP.[Name] LIKE '%{proyecto}%' "
        f"AND LD.[FechaMuestreo]>=DATEADD(YEAR,-2,GETDATE()){_sql_fecha_corte}"
        f"{_where_equipo}{_where_980e}{_where_cm}{_where_grado}"
        f"), "
        # ── CTE 2: LimitesLC ─────────────────────────────────────────────────────
        # Sin GROUP BY [COMPONENTE]: MIN sobre todos los rows del proyecto+keyword devuelve
        # exactamente 1 fila. Incluso si el WHERE no matchea (proyecto sin datos en lc),
        # SQL Server devuelve 1 fila con todos NULLs → ISNULL fallback actúa correctamente.
        # Elimina la dependencia de exact-match por nombre de [COMPONENTE], que varía entre
        # proyectos (ej: "MOTOR TRACCION RH" vs "MOTOR DE TRACCION RH").
        # CROSS JOIN (no LEFT JOIN) porque LimitesLC siempre tiene exactamente 1 fila.
        f"LimitesLC AS ("
        f"SELECT "
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
        f"WHERE [Proyecto] LIKE '%{proyecto}%' AND [COMPONENTE] LIKE '{like_comp}'"
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
        f"CROSS JOIN LimitesLC LC "
        f"WHERE LS.rn=1 "
        f"AND ("
        f"LS.[Fe_ppm]>ISNULL(LC.[FIERRO - LP],{_fe_lp_fallback}) OR "
        f"LS.[Al_ppm]>ISNULL(LC.[ALUMINIO - LP],9999) OR "
        f"LS.[Cu_ppm]>ISNULL(LC.[COBRE - LP],9999) OR "
        f"LS.[Si_ppm]>ISNULL(LC.[SILICIO - LP],9999) OR "
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

    _where_comp = (f" AND LD.[Compartimiento] LIKE '{like_comp}'" + _where_lado(_detectar_lado(consulta_humana))) if like_comp else ""
    _where_proy = f" AND MP.[Name] LIKE '%{proyecto}%'" if proyecto else ""

    fecha_corte = _detectar_fecha_corte(consulta_humana)
    if not fecha_corte and not _usuario_pide_mes_actual(consulta_humana):
        fecha_corte = _fecha_corte_defecto()
    _sql_fecha_corte = f" AND LD.[FechaMuestreo]<='{fecha_corte}'" if fecha_corte else ""

    grado = _detectar_grado_aceite(consulta_humana)
    _where_grado = f" AND {_grado_where_clause(grado)}" if grado else ""
    _join_980e, _where_980e = _join_modelo_antapaccay(proyecto)
    _where_cm = _where_excluir_cm()

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
        f"JOIN [Mine].[MiningProject] MP WITH (NOLOCK) ON MP.[Id]=ME.[MiningProjectId]"
        f"{_join_980e} "
        f"WHERE LD.[FechaMuestreo]>=DATEADD(YEAR,-2,GETDATE()){_sql_fecha_corte}"
        f"{_where_comp}{_where_proy}{_where_980e}{_where_cm}{_where_grado}"
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
    # Fallback 9999 en todos los metales → sin datos reales en lc NUNCA se dispara un falso positivo.
    _umbral_lc = (
        "LS.[Fe_ppm]>ISNULL(LC.[FIERRO - LP],9999) OR "
        "LS.[Al_ppm]>ISNULL(LC.[ALUMINIO - LP],9999) OR "
        "LS.[Cu_ppm]>ISNULL(LC.[COBRE - LP],9999) OR "
        "LS.[Si_ppm]>ISNULL(LC.[SILICIO - LP],9999) OR "
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
        # Sin GROUP BY: MIN sobre todos los rows del proyecto+keyword → 1 fila siempre.
        # Si el proyecto no existe en lc, devuelve 1 fila con NULLs → ISNULL fallback actúa.
        # Elimina la dependencia del exact-match de [COMPONENTE] entre proyectos.
        _limites_cte_con_proyecto = (
            f"LimitesLC AS ("
            f"SELECT {_lc_mins} "
            f"FROM [Eqpcare].[lc] WITH (NOLOCK) "
            f"WHERE [Proyecto] LIKE '%{proyecto}%' AND [COMPONENTE] LIKE '{like_compartimiento}')"
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
        # Sin proyecto detectado: incluir [Proyecto] en el GROUP BY y el JOIN usa el proyecto
        # del equipo → cada equipo obtiene el LP/LC de su propio proyecto, no el MIN global.
        _limites_cte_con_proyecto = (
            f"LimitesLC AS ("
            f"SELECT [Proyecto],[COMPONENTE],{_lc_mins} "
            f"FROM [Eqpcare].[lc] WITH (NOLOCK) "
            f"WHERE [COMPONENTE] LIKE '{like_compartimiento}' "
            f"GROUP BY [Proyecto],[COMPONENTE])"
        )
    else:
        # Sin datos conocidos: incluir [Proyecto] en GROUP BY → cada equipo usa el LP de su
        # propio proyecto, no el MIN global (evita LP=80 de Cerro Verde aplicado a Antapaccay).
        _limites_cte_con_proyecto = (
            f"LimitesLC AS (SELECT [Proyecto],[COMPONENTE],{_lc_mins} "
            "FROM [Eqpcare].[lc] WITH (NOLOCK) GROUP BY [Proyecto],[COMPONENTE])"
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
            f"FROM LatestSamples LS CROSS JOIN LimitesLC LC "
            f"WHERE LS.rn=1 AND ({_umbral_lc}). "
        )
    elif like_compartimiento:
        instruccion_cte = (
            f"2 CTEs: LatestSamples y LimitesLC. "
            f"LatestSamples: JOIN a ME y MP WITH (NOLOCK). "
            f"SELECT SIN TOP: ME.[Code] AS [EquipmentCode], MP.[Name] AS [Proyecto], LD.[Compartimiento], "
            f"LD.[Fe_ppm],LD.[Cr_ppm],LD.[Ni_ppm],LD.[Pb_ppm],LD.[Sn_ppm],"
            f"LD.[Cu_ppm],LD.[Si_ppm],LD.[Al_ppm],LD.[Indice_PQ],LD.[TBN],LD.[FechaMuestreo], "
            f"ROW_NUMBER() OVER (PARTITION BY LD.[MiningEquipmentId],LD.[Compartimiento] ORDER BY LD.[FechaMuestreo] DESC) AS rn. "
            f"WHERE: LD.[Compartimiento] LIKE '{like_compartimiento}' AND LD.[FechaMuestreo]>=DATEADD(YEAR,-2,GETDATE()){filtro_fecha_corte}. "
            f"{_limites_cte_con_proyecto}. "
            f"SELECT externo: SELECT TOP(200) LS.[EquipmentCode],LS.[Proyecto],LS.[Compartimiento],LS.[Fe_ppm],LS.[Cr_ppm],LS.[Ni_ppm],LS.[Pb_ppm],LS.[Sn_ppm],LS.[Cu_ppm],LS.[Si_ppm],LS.[Al_ppm],LS.[Indice_PQ],LS.[TBN],LS.[FechaMuestreo],{_lc_cols} "
            f"FROM LatestSamples LS LEFT JOIN LimitesLC LC ON LC.[COMPONENTE]=LS.[Compartimiento] AND LC.[Proyecto] LIKE '%'+LS.[Proyecto]+'%' "
            f"WHERE LS.rn=1 AND ({_umbral_lc}). "
        )
    else:
        # Sin compartimiento: instrucción genérica, el LLM infiere el filtro LIKE.
        # MP JOIN obligatorio para que LS.[Proyecto] exista → JOIN LP/LC sea por proyecto correcto.
        _default_proyecto_hint = (
            "" if proyecto
            else "Sin proyecto especificado → filtrar por Antapaccay: MP.[Name] LIKE '%Antapaccay%'. "
        )
        instruccion_cte = (
            "Compartimiento: usa keyword simple (ej: '%TRACCION%', '%HIDRAUL%'). "
            + _default_proyecto_hint
            + "2 CTEs: LatestSamples y LimitesLC. LatestSamples: JOIN a ME y MP WITH (NOLOCK). "
            "SELECT SIN TOP: ME.[Code] AS [EquipmentCode], MP.[Name] AS [Proyecto], columnas LD, "
            "ROW_NUMBER() OVER (PARTITION BY LD.[MiningEquipmentId],LD.[Compartimiento] ORDER BY LD.[FechaMuestreo] DESC) AS rn. "
            f"LimitesLC: {_limites_cte_con_proyecto}. "
            f"SELECT externo: SELECT TOP(200) LS.[EquipmentCode],LS.[Proyecto],LS.[Compartimiento],LS.[Fe_ppm],LS.[Cu_ppm],LS.[Si_ppm],LS.[Al_ppm],LS.[TBN],LS.[FechaMuestreo],{_lc_cols} "
            "FROM LatestSamples LS LEFT JOIN LimitesLC LC ON LC.[COMPONENTE]=LS.[Compartimiento] AND LC.[Proyecto] LIKE '%'+LS.[Proyecto]+'%' "
            f"WHERE LS.rn=1 AND ({_umbral_lc}). "
        )

    _hint_980e = (
        " ANTAPACCAY-980E: agregar JOIN [Mine].[EquipmentFleet] EF WITH (NOLOCK) ON EF.[Id]=ME.[EquipmentFleetId]"
        " y WHERE EF.[Model] LIKE '%980E%' — solo flota 980E bajo contrato KMMP en Antapaccay."
    ) if (proyecto or "").lower() == "antapaccay" else ""

    return (
        q.strip()
        + " | TRIAGE-OBSERVADOS: "
          "CTE con ROW_NUMBER (NUNCA GROUP BY+MAX — BD tiene duplicados por fecha). "
          "NUNCA poner TOP dentro de ningún CTE. WITH (NOLOCK) en todos los FROM/JOIN de datos. "
        + instruccion_cte
        + "JOINs en LatestSamples: [Mine].[MiningEquipment] y [Mine].[MiningProject] requeridos. "
          "Compartimiento — valores reales: 'MOTOR DE TRACCION RH/LH', 'SISTEMA HIDRAULICO', 'MOTOR', 'RUEDA DELANTERA RH/LH'. "
          "NUNCA '%MOTOR TRACCION%'. Motor sin tracción → LIKE '%MOTOR%' AND NOT LIKE '%TRACCION%'. "
          "Columnas [Eqpcare].[lc] con espacios usan corchetes: [FIERRO - LP], [TBN - LP]. "
          "NUNCA filtrar LD.[Condicion]='OBSERVADA' — [Condicion] es numérico (1/2/3), no texto. Estado observado = superar LP en metales. "
          "EXCLUIR DDI: agregar AND (LD.[CM] IS NULL OR LD.[CM] NOT IN ('DDI','DIALIZADO','RELLENO+DIALIZADO')) en LatestSamples WHERE. "
          "DEVUELVE SOLO observados. 0 filas=válido. ORDER BY LS.[Fe_ppm] DESC."
        + _hint_980e
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

    # Agregación: promedio/máximo/mínimo/conteo + GROUP BY.
    if _es_intencion_agregacion(base_heuristica):
        q_reforzada = _reforzar_consulta_agregacion(q_reforzada)
        heuristicas_aplicadas.append("agregacion")

    # Períodos de calendario: "este año", "Q1 2025", "año 2024", etc.
    if _es_intencion_periodo_calendario(base_heuristica):
        q_reforzada = _reforzar_periodo_calendario(q_reforzada)
        heuristicas_aplicadas.append("periodo_calendario")

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
