# src/analitica.py
# -*- coding: utf-8 -*-
"""
Módulo: analitica
-----------------
Utilidades determinísticas para analizar resultados tabulares y enriquecer
la respuesta del chatbot con métricas estadísticas, tendencias y sugerencias
de gráfico.

No depende de ningún LLM: todo el análisis es numérico/categórico puro.
Se llama desde src/main.py después de ejecutar el SQL y antes de construir
la respuesta en lenguaje natural.

Funciones públicas:
    generar_analisis_resultado(filas, consulta_humana) → Dict
        Genera el bloque de análisis completo: métricas por columna numérica,
        distribución categórica, tendencias temporales y sugerencias de gráfico.

    renderizar_resumen_analitico(analisis) → str
        Convierte el dict de análisis en texto legible como fallback cuando
        el LLM no produce una respuesta aceptable.
"""

from __future__ import annotations

from datetime import date, datetime
from decimal import Decimal
from typing import Any, Dict, Iterable, List, Optional, Tuple
import math
import re


# ==============================================================================
#  Conversión de tipos
# ==============================================================================

def _a_float(valor: Any) -> Optional[float]:
    """Convierte cualquier valor a float manejando formatos ES/US y símbolos.
    Devuelve None si no es convertible para no contaminar estadísticas."""
    if valor is None:
        return None
    if isinstance(valor, bool):
        return None
    if isinstance(valor, Decimal):
        return float(valor)
    if isinstance(valor, (int, float)):
        if isinstance(valor, float) and math.isnan(valor):
            return None
        return float(valor)
    if isinstance(valor, str):
        s = valor.strip()
        if not s:
            return None
        s = s.replace("%", "")
        if re.search(r"\d,\d+$", s) and "." in s:
            s = s.replace(".", "").replace(",", ".")
        else:
            s = s.replace(",", "")
        s = re.sub(r"[^0-9\.-]", "", s)
        if s in {"", ".", "-", "-."}:
            return None
        try:
            return float(s)
        except Exception:
            return None
    return None


def _a_fecha(valor: Any) -> Optional[datetime]:
    """Parsea fechas desde datetime/date nativos o strings en múltiples formatos.
    Soporta el tipo date que devuelve EOMONTH() en SQL Server."""
    if valor is None:
        return None
    if isinstance(valor, datetime):
        return valor
    if isinstance(valor, date):
        return datetime.combine(valor, datetime.min.time())
    if isinstance(valor, str):
        s = valor.strip()
        if not s:
            return None
        formatos = [
            "%Y-%m-%d",
            "%Y-%m-%d %H:%M:%S",
            "%Y-%m-%d %H:%M:%S.%f",
            "%d/%m/%Y",
            "%d-%m-%Y",
            "%Y/%m/%d",
        ]
        for fmt in formatos:
            try:
                return datetime.strptime(s, fmt)
            except Exception:
                continue
    return None


# ==============================================================================
#  Detección de columnas por nombre y tipo de contenido
# ==============================================================================

def _es_nombre_fecha(nombre: str) -> bool:
    n = (nombre or "").lower()
    pistas = ["fecha", "date", "time", "tiempo", "periodo", "period", "mes", "anio", "año"]
    return any(p in n for p in pistas)


def _es_nombre_categorico_util(nombre: str) -> bool:
    n = (nombre or "").lower()
    if not n:
        return False
    if _es_nombre_fecha(n):
        return False
    malas = ["id", "count", "total", "avg", "sum", "promedio", "media", "min", "max", "metricvalue"]
    if any(p in n for p in malas):
        return False
    return True


def _formatear_numero(x: float) -> str:
    try:
        if abs(x) >= 1000:
            return f"{x:,.0f}".replace(",", "_").replace("_", ",")
        if abs(x) >= 10:
            return f"{x:.2f}".rstrip("0").rstrip(".")
        return f"{x:.4f}".rstrip("0").rstrip(".")
    except Exception:
        return str(x)


# ==============================================================================
#  Estadísticas numéricas
# ==============================================================================

def _percentil(valores: List[float], q: float) -> float:
    """Percentil por interpolación lineal discreta sobre lista ya ordenada."""
    if not valores:
        return 0.0
    vs = sorted(valores)
    idx = int(max(0, min(len(vs) - 1, round((len(vs) - 1) * q))))
    return vs[idx]


def _resumen_numerico(valores: List[float]) -> Dict[str, Any]:
    """Calcula min/max/media/mediana/p90/Q1/Q3/outliers IQR para una columna numérica."""
    vs = sorted(valores)
    n = len(vs)
    q1 = _percentil(vs, 0.25)
    q3 = _percentil(vs, 0.75)
    iqr = max(1e-12, q3 - q1)
    lim_sup = q3 + 1.5 * iqr
    lim_inf = q1 - 1.5 * iqr
    return {
        "n": n,
        "min": vs[0],
        "max": vs[-1],
        "mean": sum(vs) / n,
        "median": _percentil(vs, 0.50),
        "p90": _percentil(vs, 0.90),
        "q1": q1,
        "q3": q3,
        "ceros": sum(1 for x in vs if abs(x) < 1e-12),
        "outliers_altos": sum(1 for x in vs if x > lim_sup),
        "outliers_bajos": sum(1 for x in vs if x < lim_inf),
    }


# ==============================================================================
#  Selección de columnas representativas
# ==============================================================================

def _buscar_columna_tiempo(filas: List[Dict[str, Any]]) -> Optional[str]:
    """Detecta la columna más apta para eje temporal (por nombre y por contenido parseable)."""
    if not filas:
        return None
    columnas = list(filas[0].keys())

    # preferencia por nombre
    candidatas = [c for c in columnas if _es_nombre_fecha(c)]
    candidatas += [c for c in columnas if c not in candidatas]

    for col in candidatas:
        valores = [_a_fecha(f.get(col)) for f in filas[:80]]
        validos = sum(1 for v in valores if v is not None)
        if validos >= max(3, int(len(valores) * 0.4)):
            return col
    return None


def _buscar_columnas_numericas(filas: List[Dict[str, Any]]) -> List[str]:
    # Umbral 45%: una columna con el 45% de valores parseables como float se considera numérica.
    # Evita que columnas mixtas (código de equipo que a veces tiene números) sean tratadas como métricas.
    # Score extra (+20) para columnas del dominio de aceites (ppm, TBN, viscosidad, horometro).
    # Score penalización (-20) para IDs y códigos: son numéricos pero no tienen sentido estadístico.
    if not filas:
        return []
    columnas = list(filas[0].keys())
    out: List[Tuple[int, str]] = []
    for col in columnas:
        valores = [_a_float(f.get(col)) for f in filas[:200]]
        validos = [v for v in valores if v is not None]
        if len(validos) >= max(3, int(len(valores) * 0.45)):
            score = 0
            ncol = col.lower()
            if any(p in ncol for p in ["ppm", "tasa", "hor", "vis", "v100", "tbn", "tan", "indice", "metric", "valor", "value"]):
                score += 20
            if any(p in ncol for p in ["id", "code", "codigo"]):
                score -= 20
            out.append((score, col))
    out.sort(key=lambda x: (-x[0], x[1].lower()))
    return [c for _, c in out]


def _buscar_columna_categoria(filas: List[Dict[str, Any]], excluir: Iterable[str] = ()) -> Optional[str]:
    excluidas = {c.lower() for c in excluir}
    if not filas:
        return None
    columnas = list(filas[0].keys())
    candidatas: List[Tuple[int, str]] = []
    for col in columnas:
        if col.lower() in excluidas:
            continue
        if not _es_nombre_categorico_util(col):
            continue
        valores = [f.get(col) for f in filas[:120]]
        textos = [str(v).strip() for v in valores if isinstance(v, str) and str(v).strip()]
        if len(textos) >= max(2, int(len(valores) * 0.25)):
            distintos = len(set(textos))
            score = 0
            ncol = col.lower()
            if any(p in ncol for p in ["component", "compart", "equipo", "equipment", "modelo", "project", "proyecto", "condicion", "estado", "metricname", "parameter", "parametro"]):
                score += 20
            score += min(distintos, 15)
            candidatas.append((score, col))
    candidatas.sort(key=lambda x: (-x[0], x[1].lower()))
    return candidatas[0][1] if candidatas else None


# ==============================================================================
#  Tendencia temporal
# ==============================================================================

def _calcular_tendencia_simple(fechas: List[datetime], valores: List[float]) -> Dict[str, Any]:
    """
    Estima dirección de tendencia (ascendente/descendente/estable/mixta)
    comparando primer vs último valor y contando cambios de signo.
    Mínimo 3 puntos. Umbral de estabilidad: cambio relativo < 5%.
    """
    pares = sorted(zip(fechas, valores), key=lambda x: x[0])
    if len(pares) < 3:
        return {"direccion": "insuficiente", "descripcion": "Sin suficientes puntos para estimar tendencia."}

    serie = [v for _, v in pares]
    primero = serie[0]
    ultimo = serie[-1]
    cambio_abs = ultimo - primero
    base = abs(primero) if abs(primero) > 1e-9 else 1.0
    cambio_rel = cambio_abs / base

    # monotonía suave
    subidas = 0
    bajadas = 0
    for i in range(1, len(serie)):
        if serie[i] > serie[i - 1]:
            subidas += 1
        elif serie[i] < serie[i - 1]:
            bajadas += 1

    if abs(cambio_rel) < 0.05:
        direccion = "estable"
        descripcion = "Tendencia estable o con variación leve en el período analizado."
    elif cambio_abs > 0 and subidas >= bajadas:
        direccion = "ascendente"
        descripcion = "Tendencia ascendente en la serie analizada."
    elif cambio_abs < 0 and bajadas >= subidas:
        direccion = "descendente"
        descripcion = "Tendencia descendente en la serie analizada."
    else:
        direccion = "mixta"
        descripcion = "La serie muestra variaciones mixtas sin dirección única dominante."

    return {
        "direccion": direccion,
        "descripcion": descripcion,
        "valor_inicial": primero,
        "valor_final": ultimo,
        "cambio_absoluto": cambio_abs,
        "cambio_relativo": cambio_rel,
        "puntos": len(serie),
    }


# ==============================================================================
#  API pública
# ==============================================================================

def generar_analisis_resultado(
    filas: List[Dict[str, Any]],
    consulta_humana: str = "",
    max_metricas: int = 4,
) -> Dict[str, Any]:
    """
    Genera un análisis estructurado y determinístico del resultado tabular.

    Detecta automáticamente:
      - Columnas numéricas → min/max/media/p90/outliers IQR
      - Columna categórica → distribución top-5
      - Columna temporal   → tendencia por serie (si hay ≥ 3 puntos)
      - Sugerencias de gráfico → línea, barras o dispersión según los datos

    Devuelve un dict con claves:
      row_count, columnas, columna_tiempo, columna_categoria,
      metricas, categorias, tendencias, resumen_ejecutivo,
      graficos_sugeridos, consulta_humana
    """
    if not filas:
        return {
            "row_count": 0,
            "columnas": [],
            "metricas": {},
            "categorias": {},
            "tendencias": {},
            "resumen_ejecutivo": "La consulta no devolvió filas, por lo que no hay evidencia para analizar máximos, mínimos ni tendencia.",
            "graficos_sugeridos": [],
        }

    columnas = list(filas[0].keys())
    columnas_numericas = _buscar_columnas_numericas(filas)
    columna_tiempo = _buscar_columna_tiempo(filas)
    columna_categoria = _buscar_columna_categoria(filas, excluir=[columna_tiempo] if columna_tiempo else [])

    metricas: Dict[str, Any] = {}
    for col in columnas_numericas[:max_metricas]:
        valores = [_a_float(f.get(col)) for f in filas]
        validos = [v for v in valores if v is not None]
        if len(validos) >= 3:
            metricas[col] = _resumen_numerico(validos)

    categorias: Dict[str, Any] = {}
    if columna_categoria:
        conteo: Dict[str, int] = {}
        for fila in filas[:400]:
            v = fila.get(columna_categoria)
            if isinstance(v, str) and v.strip():
                conteo[v.strip()] = conteo.get(v.strip(), 0) + 1
        if conteo:
            total = sum(conteo.values())
            top = sorted(conteo.items(), key=lambda kv: kv[1], reverse=True)[:5]
            categorias[columna_categoria] = {
                "distinct": len(conteo),
                "top": [
                    {"valor": k, "count": c, "share": (c / total if total else 0.0)}
                    for k, c in top
                ],
            }

    tendencias: Dict[str, Any] = {}
    if columna_tiempo:
        fechas_crudas = [_a_fecha(f.get(columna_tiempo)) for f in filas]
        for col in columnas_numericas[:max_metricas]:
            pares_validos = [
                (fecha, _a_float(fila.get(col)))
                for fecha, fila in zip(fechas_crudas, filas)
                if fecha is not None and _a_float(fila.get(col)) is not None
            ]
            if len(pares_validos) >= 3:
                fechas = [x[0] for x in pares_validos]
                valores = [x[1] for x in pares_validos]
                tendencias[col] = _calcular_tendencia_simple(fechas, valores)

    frases: List[str] = [f"Se analizaron {len(filas)} filas y {len(columnas)} columnas útiles en el resultado."]

    if metricas:
        for nombre, m in list(metricas.items())[:2]:
            frases.append(
                f"En {nombre}, el mínimo es {_formatear_numero(m['min'])}, el máximo {_formatear_numero(m['max'])}, "
                f"la mediana {_formatear_numero(m['median'])} y el p90 {_formatear_numero(m['p90'])}."
            )
            if m.get("outliers_altos") or m.get("outliers_bajos"):
                frases.append(
                    f"{nombre} presenta outliers por IQR (altos={m.get('outliers_altos', 0)}, bajos={m.get('outliers_bajos', 0)})."
                )

    if categorias:
        nombre, data = next(iter(categorias.items()))
        if data.get("top"):
            top0 = data["top"][0]
            frases.append(
                f"La mayor concentración categórica aparece en {nombre}: {top0['valor']} representa {top0['share'] * 100:.1f}% de la muestra categórica observada."
            )

    if tendencias:
        nombre, data = next(iter(tendencias.items()))
        frases.append(f"Para {nombre}, la tendencia detectada es {data.get('direccion', 'indefinida')}: {data.get('descripcion', '')}")
    elif columna_tiempo and metricas:
        frases.append("Hay columna temporal disponible, pero la serie no tuvo suficientes puntos válidos para estimar tendencia robusta.")
    else:
        frases.append("No se detectó una serie temporal suficientemente consistente para evaluar tendencia en este resultado.")

    graficos: List[Dict[str, Any]] = []
    if columna_tiempo and columnas_numericas:
        graficos.append(
            {
                "tipo": "linea",
                "titulo": f"Tendencia de {columnas_numericas[0]} por {columna_tiempo}",
                "eje_x": columna_tiempo,
                "eje_y": columnas_numericas[0],
                "motivo": "Existe columna temporal y una métrica numérica apta para analizar evolución.",
            }
        )
    if columna_categoria and columnas_numericas:
        graficos.append(
            {
                "tipo": "barras",
                "titulo": f"Comparación de {columnas_numericas[0]} por {columna_categoria}",
                "eje_x": columna_categoria,
                "eje_y": columnas_numericas[0],
                "motivo": "Existe una dimensión categórica útil y una métrica numérica comparable.",
            }
        )
    if len(columnas_numericas) >= 2:
        graficos.append(
            {
                "tipo": "dispersión",
                "titulo": f"Relación entre {columnas_numericas[0]} y {columnas_numericas[1]}",
                "eje_x": columnas_numericas[0],
                "eje_y": columnas_numericas[1],
                "motivo": "Hay al menos dos métricas numéricas que podrían correlacionarse.",
            }
        )

    return {
        "row_count": len(filas),
        "columnas": columnas,
        "columna_tiempo": columna_tiempo,
        "columna_categoria": columna_categoria,
        "metricas": metricas,
        "categorias": categorias,
        "tendencias": tendencias,
        "resumen_ejecutivo": " ".join(frases).strip(),
        "graficos_sugeridos": graficos,
        "consulta_humana": consulta_humana,
    }


# ==============================================================================
#  Generación de URL de gráfico via QuickChart.io
#  Deshabilitado por defecto — activar con INCLUIR_CHART_URL=true en .env
#  No afecta ninguna funcionalidad existente.
# ==============================================================================

def generar_chart_url(
    filas: List[Dict[str, Any]],
    graficos_sugeridos: List[Dict[str, Any]],
    max_filas: int = 20,
) -> Optional[str]:
    """
    Genera una URL pública de imagen de gráfico usando QuickChart.io.

    Toma la primera sugerencia de graficos_sugeridos y los datos de filas,
    construye un Chart.js config, y hace POST a QuickChart para obtener
    una URL corta permanente.

    Estrategia de dos pasos:
      1. POST a QuickChart /chart/create → URL corta permanente (preferida para Copilot Studio)
      2. Fallback: GET URL con config codificada → funciona solo para datasets pequeños
         (la URL se vuelve demasiado larga para más de ~20 filas)

    Devuelve None si no hay sugerencias, si los datos son insuficientes,
    o si la llamada HTTP falla — nunca lanza excepciones.

    Activar con INCLUIR_CHART_URL=true en .env (deshabilitado por defecto).
    """
    if not filas or not graficos_sugeridos:
        return None

    sugerencia = graficos_sugeridos[0]
    eje_x = sugerencia.get("eje_x", "")
    eje_y = sugerencia.get("eje_y", "")
    titulo = sugerencia.get("titulo", "")
    tipo_interno = sugerencia.get("tipo", "barras")

    if not eje_x or not eje_y:
        return None

    _tipo_map = {"barras": "bar", "linea": "line", "dispersión": "scatter"}
    tipo_chartjs = _tipo_map.get(tipo_interno, "bar")

    muestra = filas[:max_filas]
    labels = [str(r.get(eje_x, "")) for r in muestra]
    data: List[Any] = []
    for r in muestra:
        v = _a_float(r.get(eje_y))
        data.append(round(v, 2) if v is not None else 0)

    if not any(v != 0 for v in data):
        return None

    # Colores por severidad si la columna X contiene códigos de equipo
    color_fondo = "rgba(54, 162, 235, 0.8)"
    color_borde = "rgba(54, 162, 235, 1)"

    chart_config: Dict[str, Any] = {
        "type": tipo_chartjs,
        "data": {
            "labels": labels,
            "datasets": [{
                "label": eje_y,
                "data": data,
                "backgroundColor": color_fondo,
                "borderColor": color_borde,
                "borderWidth": 1,
                "fill": tipo_chartjs == "line",
            }],
        },
        "options": {
            "plugins": {
                "title": {"display": bool(titulo), "text": titulo},
                "legend": {"display": False},
            },
            "scales": {
                "x": {"ticks": {"maxRotation": 45, "minRotation": 0}},
                "y": {"beginAtZero": False},
            },
        },
    }

    try:
        import json
        import urllib.request

        payload = json.dumps({"chart": chart_config}, separators=(",", ":")).encode()
        req = urllib.request.Request(
            "https://quickchart.io/chart/create",
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=5) as resp:
            result = json.loads(resp.read().decode())
            url = result.get("url", "")
            if url:
                return url
    except Exception:
        pass

    # Fallback: GET URL codificada (funciona para datasets pequeños)
    try:
        import json
        import urllib.parse
        encoded = urllib.parse.quote(
            json.dumps(chart_config, separators=(",", ":")), safe=""
        )
        return f"https://quickchart.io/chart?c={encoded}&w=700&h=400&bkg=white"
    except Exception:
        return None


def renderizar_resumen_analitico(analisis: Dict[str, Any]) -> str:
    """Convierte el análisis estructurado en un texto breve y legible."""
    if not analisis or not analisis.get("row_count"):
        return "La consulta no devolvió filas, por lo que no fue posible construir un análisis analítico confiable."

    lineas: List[str] = []
    resumen = (analisis.get("resumen_ejecutivo") or "").strip()
    if resumen:
        lineas.append(resumen)

    metricas = analisis.get("metricas") or {}
    for nombre, m in list(metricas.items())[:2]:
        lineas.append(
            f"- {nombre}: min={_formatear_numero(m['min'])}, mediana={_formatear_numero(m['median'])}, "
            f"p90={_formatear_numero(m['p90'])}, max={_formatear_numero(m['max'])}."
        )

    tendencias = analisis.get("tendencias") or {}
    for nombre, t in list(tendencias.items())[:1]:
        lineas.append(
            f"- Tendencia de {nombre}: {t.get('direccion', 'indefinida')} "
            f"(inicio={_formatear_numero(t.get('valor_inicial', 0.0))}, "
            f"fin={_formatear_numero(t.get('valor_final', 0.0))})."
        )

    return "\n".join(lineas).strip()