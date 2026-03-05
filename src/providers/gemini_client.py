# src/providers/gemini_client.py
# -*- coding: utf-8 -*-
"""
Módulo: providers.gemini_client
--------------------------------
Cliente del proveedor Gemini (Google GenAI) para:
- NL → SQL (con salida JSON robusta) con timeouts, hedging y cadena de fallback.
- Construcción de respuestas en lenguaje natural (build_answer) basada en filas/resultados.

Notas de diseño:
- Se mantiene la lógica original, pero se renombra a español (funciones, variables y docstrings).
- Se agregan *alias* de compatibilidad para los nombres en inglés: `human_query_to_sql`, `build_answer`, `list_models`.
- Se documentan utilidades clave y se limpian comentarios redundantes.

Precauciones:
- No se modifican literales sensibles (nombres de columnas/tablas, macros, claves .env).
- Las instrucciones del sistema (prompts) se mantienen con precisión semántica; algunos fragmentos siguen en inglés para mayor exactitud.
"""

from typing import Any, List, Dict, Optional, Tuple
from decouple import config as env
import json
import re
import time
import asyncio
from decimal import Decimal
from datetime import date, datetime
from google import genai
from logging import getLogger

log = getLogger(__name__)


# ============================= Utilidades comunes =============================

def _a_json_seguro(v: Any) -> Any:
    """Convierte valores a tipos JSON-seguros (Decimal → float, fechas → ISO, contenedores recursivos)."""
    if isinstance(v, Decimal):
        return float(v)
    if isinstance(v, (datetime, date)):
        return v.isoformat()
    if isinstance(v, list):
        return [_a_json_seguro(x) for x in v]
    if isinstance(v, tuple):
        return tuple(_a_json_seguro(x) for x in v)
    if isinstance(v, dict):
        return {k: _a_json_seguro(val) for k, val in v.items()}
    return v


def _compactar_filas_para_resumen(filas: List[Dict[str, Any]], max_filas: int, max_caracteres: int) -> str:
    """
    Recorta filas y longitud total para limitar tokens/latencia (solo CONTEXTO, no output final).

    Args:
        filas: Lista de filas de resultados (dict).
        max_filas: Máximo número de filas a incluir.
        max_caracteres: Máximos caracteres del JSON resultante.

    Returns:
        Cadena JSON (str) con una muestra compactada de filas.
    """
    if not filas:
        return "[]"

    def _normalizar_fila(r: Dict[str, Any]) -> Dict[str, Any]:
        out: Dict[str, Any] = {}
        for k, v in (r or {}).items():
            v2 = _a_json_seguro(v)
            if isinstance(v2, str) and len(v2) > 220:
                out[k] = v2[:220] + "…"
            else:
                out[k] = v2
        return out

    datos = [_normalizar_fila(r) for r in filas[:max_filas]]
    s = json.dumps(datos, ensure_ascii=False)

    if len(s) <= max_caracteres:
        return s

    # Búsqueda binaria del número de filas que permiten no exceder max_caracteres.
    lo, hi = 1, len(datos)
    mejor = "[]"
    while lo <= hi:
        mid = (lo + hi) // 2
        s2 = json.dumps(datos[:mid], ensure_ascii=False)
        if len(s2) <= max_caracteres:
            mejor = s2
            lo = mid + 1
        else:
            hi = mid - 1
    return mejor


def _parsear_reintentar_en_segundos(msg: str) -> float:
    """Extrae (si existe) un 'retry in Xs' del mensaje para esperar X segundos. [1.0, 60.0]."""
    m = re.search(r"retry in\s+([0-9]+(?:\.[0-9]+)?)s", (msg or "").lower())
    if m:
        try:
            v = float(m.group(1))
            return max(1.0, min(v, 60.0))
        except Exception:
            return 0.0
    return 0.0


def _mensaje_excepcion(e: Exception) -> str:
    """Estándar de logging para excepciones de la API Gemini."""
    status = (getattr(e, "status", "") or "")
    code = (getattr(e, "code", "") or "")
    msg = (getattr(e, "message", "") or str(e))
    return f"status={status} code={code} msg={msg}"


# ======================= Perfil analítico determinístico =======================

def _intentar_float(v: Any) -> Optional[float]:
    """
    Intenta convertir diversos formatos numéricos (US/EU y cadenas con símbolos) a float.
    Devuelve None si no es convertible con seguridad.
    """
    try:
        if v is None:
            return None
        if isinstance(v, Decimal):
            return float(v)
        if isinstance(v, (int, float)):
            return float(v)
        if isinstance(v, str):
            s = v.strip()
            if not s:
                return None

            # Formato europeo: 1.234,56
            if re.search(r"\d,\d{1,}\s*$", s) and "." in s:
                s = s.replace(".", "").replace(",", ".")
            else:
                # Formato US: 1,234.56
                s = s.replace(",", "")

            s = re.sub(r"[^0-9\.\-]", "", s)
            if s in ("", "-", ".", "-.") :
                return None
            return float(s)
    except Exception:
        return None
    return None


def _calcular_perfil(filas: List[Dict[str, Any]], max_claves_top: int = 8) -> Dict[str, Any]:
    """
    Calcula un perfil determinístico con métricas básicas numéricas y categorías top.

    Args:
        filas: filas de resultados (lista de dicts).
        max_claves_top: máximo de categorías destacadas por columna.

    Returns:
        Dict con claves: row_count, sampled_rows, numeric, categorical.
    """
    if not filas:
        return {"row_count": 0, "numeric": {}, "categorical": {}, "notes": ["no_rows"]}

    columnas = list(filas[0].keys())
    valores_num: Dict[str, List[float]] = {c: [] for c in columnas}
    cuentas_cat: Dict[str, Dict[str, int]] = {c: {} for c in columnas}

    muestra = filas[: min(len(filas), 5000)]

    for r in muestra:
        for c in columnas:
            v = r.get(c)
            fv = _intentar_float(v)
            if fv is not None:
                valores_num[c].append(fv)
            else:
                if isinstance(v, str):
                    t = v.strip()
                    if t:
                        cuentas_cat[c][t] = cuentas_cat[c].get(t, 0) + 1

    numericas: Dict[str, Any] = {}
    for c, vals in valores_num.items():
        if len(vals) < 5:
            continue
        vs = sorted(vals)
        n = len(vs)

        mn = vs[0]
        mx = vs[-1]
        mean = sum(vs) / n
        median = vs[n // 2] if n % 2 == 1 else 0.5 * (vs[n // 2 - 1] + vs[n // 2])
        p90 = vs[int(0.90 * (n - 1))]
        zeros = sum(1 for x in vs if abs(x) < 1e-12)

        q1 = vs[int(0.25 * (n - 1))]
        q3 = vs[int(0.75 * (n - 1))]
        iqr = max(1e-12, (q3 - q1))
        upper = q3 + 1.5 * iqr
        lower = q1 - 1.5 * iqr
        out_hi = sum(1 for x in vs if x > upper)
        out_lo = sum(1 for x in vs if x < lower)

        numericas[c] = {
            "n": n,
            "min": mn,
            "max": mx,
            "mean": mean,
            "median": median,
            "p90": p90,
            "q1": q1,
            "q3": q3,
            "zeros": zeros,
            "outliers_hi": out_hi,
            "outliers_lo": out_lo,
        }

    categoricas: Dict[str, Any] = {}
    for c, mp in cuentas_cat.items():
        if len(mp) < 2:
            continue
        top = sorted(mp.items(), key=lambda kv: kv[1], reverse=True)[:max_claves_top]
        total_vistos = sum(mp.values())
        categoricas[c] = {
            "distinct_seen": len(mp),
            "top": [{"value": k, "count": v, "share": (v / total_vistos if total_vistos else 0.0)} for k, v in top],
        }

    return {
        "row_count": len(filas),
        "sampled_rows": len(muestra),
        "numeric": numericas,
        "categorical": categoricas,
    }


def _formatear_numero(x: float) -> str:
    """Formatea números para lectura humana con reglas simples (miles, 2-4 decimales donde aplique)."""
    try:
        if abs(x) >= 1000:
            return f"{x:,.0f}".replace(",", "_").replace("_", ",")
        if abs(x) >= 10:
            return f"{x:.2f}".rstrip("0").rstrip(".")
        return f"{x:.4f}".rstrip("0").rstrip(".")
    except Exception:
        return str(x)


def _respuesta_local_de_respaldo(consulta_humana: str, filas: List[Dict[str, Any]], perfil: Dict[str, Any]) -> str:
    """
    Respuesta local cuando el modelo no produce un resumen aceptable.
    Produce puntos básicos a partir del perfil numérico/categórico.
    """
    rc = int(perfil.get("row_count") or 0)
    muestreadas = int(perfil.get("sampled_rows") or min(rc, 0))
    numericas = perfil.get("numeric") or {}
    categoricas = perfil.get("categorical") or {}

    lineas: List[str] = []
    lineas.append(f"Se analizaron {rc} filas (muestra usada para perfil: {muestreadas}).")

    def puntuar_metrica(m: Dict[str, Any]) -> float:
        try:
            rango = float(m["max"]) - float(m["min"])
            return rango + 0.1 * float(m.get("outliers_hi", 0) + m.get("outliers_lo", 0))
        except Exception:
            return 0.0

    ordenadas: List[Tuple[str, Dict[str, Any]]] = sorted(
        numericas.items(), key=lambda kv: puntuar_metrica(kv[1]), reverse=True
    )[:2]

    for col, m in ordenadas:
        n = int(m.get("n") or 0)
        mn = float(m.get("min") or 0.0)
        mx = float(m.get("max") or 0.0)
        med = float(m.get("median") or 0.0)
        mean = float(m.get("mean") or 0.0)
        p90 = float(m.get("p90") or 0.0)
        zeros = int(m.get("zeros") or 0)
        ohi = int(m.get("outliers_hi") or 0)
        olo = int(m.get("outliers_lo") or 0)

        lineas.append(
            f"- **{col}** (n={n}): min={_formatear_numero(mn)}, mediana={_formatear_numero(med)}, "
            f"p90={_formatear_numero(p90)}, max={_formatear_numero(mx)} (promedio={_formatear_numero(mean)})."
        )
        if zeros > 0:
            lineas.append(f"- En **{col}** hay {zeros} valores en cero.")
        if (ohi + olo) > 0:
            lineas.append(f"- En **{col}** se detectan outliers por IQR: altos={ohi}, bajos={olo}.")

    def escoger_claves_cat(cats: Dict[str, Any]) -> List[str]:
        if not cats:
            return []
        preferidas = ["cliente", "material", "pedido", "codigo", "producto", "ruc", "proveedor"]
        claves = list(cats.keys())
        claves_ordenadas = sorted(
            claves,
            key=lambda k: (0 if any(p in k.lower() for p in preferidas) else 1, -int(cats[k].get("distinct_seen") or 0)),
        )
        return claves_ordenadas[:2]

    for k in escoger_claves_cat(categoricas):
        top = (categoricas.get(k) or {}).get("top") or []
        if not top:
            continue
        t0 = top[0]
        share = float(t0.get("share") or 0.0)
        lineas.append(
            f"- **{k}**: principal = {t0.get('value')} ({t0.get('count')} registros, {share*100:.1f}% del muestreo categórico)."
        )

    if len(lineas) == 1:
        lineas.append("No hay suficientes columnas numéricas/categóricas para un análisis adicional con esta muestra.")

    return "\n".join(lineas).strip()


# ============================ Proveedor Gemini ================================

class GeminiProvider:
    """
    Proveedor Gemini (Google GenAI).

    Características:
    - Usa system_instruction en config.
    - Filtra candidatos contra modelos visibles por tu clave/proyecto.
    - Maneja 404/429 con fallback/espera.
    - NL→SQL robusto con reparación de JSON.
    - build_answer devuelve TEXTO en lenguaje natural.

    Guard rails:
    - Tipos: NO usar TRIM/NUMERIC_CLEAN sobre columnas no-texto (BIGINT/INT/NUMERIC/DATE).
    - Filtros por tipo: TEXT -> COALESCE(TRIM(col),'') <> ''; NO-TEXT -> col IS NOT NULL.
    - Post-proceso: reemplaza TRIM(col_no_texto) por TRIM(CAST(col_no_texto AS TEXT/NVARCHAR)) según dialecto.
    - Opción estricta: fallo temprano si se detecta NUMERIC_CLEAN sobre no-texto (variable de entorno).
    """

    def __init__(self) -> None:
        """Inicializa el cliente Gemini y prelista modelos visibles (si es posible)."""
        api_key = (env("GOOGLE_API_KEY", default="") or "").strip()
        if not api_key:
            raise RuntimeError("Falta GOOGLE_API_KEY en .env")
        self.cliente = genai.Client(api_key=api_key)

        self._nombres_disponibles: List[str] = []
        try:
            self._nombres_disponibles = [m.name for m in self.cliente.models.list() if getattr(m, "name", "")]
            log.info("[gemini] modelos visibles: %s", self._nombres_disponibles)
        except Exception as e:
            log.warning("[gemini] No se pudo listar modelos: %s", e)
            self._nombres_disponibles = []

    # ------------------------- Resolución de modelos --------------------------

    def _resolver_modelo(self, nombre: Optional[str]) -> str:
        """Normaliza el nombre del modelo principal para NL→SQL."""
        nm = (nombre or env("GEMINI_MODEL", default="gemini-3-flash")).strip()
        return nm if nm.startswith("models/") else f"models/{nm}"

    def _resolver_modelo_respuesta(self, nombre: Optional[str]) -> str:
        """Normaliza el nombre del modelo para respuestas/síntesis (build_answer)."""
        nm = (nombre or env("GEMINI_MODEL_ANSWER", default="gemini-3-pro")).strip()
        return nm if nm.startswith("models/") else f"models/{nm}"

    def _cadena_fallback(self, primario_full: str, clave_env: str) -> List[str]:
        """
        Construye cadena de fallback a partir de:
        - Modelo primario
        - Candidatos en .env
        - Defaults
        Filtra por modelos realmente visibles cuando es posible.
        """
        cruda = env(clave_env, default="")
        en_lista = [s.strip() for s in cruda.split(",") if s.strip()]

        defaults = [
            "models/gemini-3-pro",
            "models/gemini-3-flash",
            "models/gemini-2.5-pro",
            "models/gemini-2.5-flash",
            "models/gemini-2-flash",
            "models/gemini-2-flash-lite",
        ]

        def norm(m: str) -> str:
            return m if m.startswith("models/") else f"models/{m}"

        cadena_total: List[str] = []
        vistos = set()
        for m in [primario_full] + [norm(x) for x in en_lista] + defaults:
            if m and m not in vistos:
                cadena_total.append(m)
                vistos.add(m)

        if not self._nombres_disponibles:
            return cadena_total

        cadena = [m for m in cadena_total if m in self._nombres_disponibles]
        return cadena or cadena_total

    # ----------------------------- Timeouts/Hedging ---------------------------

    def _tiempos_espera(self) -> Dict[str, float]:
        """Lee configuración de timeouts/hedging desde .env."""
        return {
            "per_model_timeout": env("LLM_PER_MODEL_TIMEOUT", default=18.0, cast=float),
            "total_timeout": env("LLM_TOTAL_TIMEOUT", default=40.0, cast=float),
            "hedge_stagger": env("LLM_HEDGE_STAGGER", default=0.6, cast=float),
            "hedge_parallel": env("LLM_HEDGE_PARALLEL", default=2, cast=int),
        }

    async def _llamar_generar(self, modelo: str, contenidos: Any, configuracion: Dict[str, Any], timeout_modelo: float):
        """Envuelve generate_content en un hilo y con timeout por modelo."""
        try:
            resp = await asyncio.wait_for(
                asyncio.to_thread(self.cliente.models.generate_content, model=modelo, contents=contenidos, config=configuracion),
                timeout=timeout_modelo
            )
            return resp
        except Exception as e:
            return e

    # -------------------------- SQL post-fix: ORDER BY ------------------------

    def _sql_tiene_order_by(self, sql: str) -> bool:
        return bool(re.search(r"\bORDER\s+BY\b", sql, flags=re.IGNORECASE))

    def _inyectar_order_by_antes_de_limit(self, sql: str, expresion_orden: str) -> str:
        m = re.search(r"\bLIMIT\s+\d+\b", sql, flags=re.IGNORECASE)
        if m:
            i = m.start()
            return sql[:i].rstrip() + f"\nORDER BY {expresion_orden}\n" + sql[i:].lstrip()
        return sql.rstrip() + f"\nORDER BY {expresion_orden}\n"

    def _orden_automatico(self, sql: str, consulta_humana: str = "") -> str:
        """Inserta un ORDER BY razonable antes de LIMIT cuando no existe uno explícito."""
        if not sql or self._sql_tiene_order_by(sql):
            return sql

        tiene_limit = bool(re.search(r"\bLIMIT\s+\d+\b", sql, flags=re.IGNORECASE))
        if not tiene_limit:
            return sql

        if re.search(r'AS\s+"Pendiente"\b', sql, flags=re.IGNORECASE) and re.search(r'AS\s+"Despachado"\b', sql, flags=re.IGNORECASE):
            return self._inyectar_order_by_antes_de_limit(sql, '("Pendiente" - "Despachado") DESC, "Pendiente" DESC')

        alias_candidatos = [
            "Total", "Total Despachado", "Total Pendiente", "Despachado", "Pendiente",
            "Monto", "Cantidad", "Importe", "Suma", "Sum", "Diferencia"
        ]
        for a in alias_candidatos:
            if re.search(rf'AS\s+"{re.escape(a)}"\b', sql, flags=re.IGNORECASE):
                return self._inyectar_order_by_antes_de_limit(sql, f'"{a}" DESC')

        m = re.search(r'AS\s+"([^"]+)"', sql, flags=re.IGNORECASE)
        if m:
            alias = m.group(1)
            if not any(x in alias.lower() for x in ["pedido", "cliente", "material", "codigo", "id"]):
                return self._inyectar_order_by_antes_de_limit(sql, f'"{alias}" DESC')

        return sql

    # -------------------------- Postgres: DATE_PART('day', A - B) -------------

    def _arreglar_postgres_datepart_day(self, sql: str) -> str:
        """
        En Postgres: date1 - date2 (DATE - DATE) ya devuelve INTEGER (días).
        Evita DATE_PART('day', date1 - date2).
        """
        s = (sql or "")
        if not s.strip():
            return s

        p = re.compile(
            r"DATE_PART\s*\(\s*'day'\s*,\s*\(\s*(?P<a>.+?)\s*-\s*(?P<b>.+?)\s*\)\s*\)",
            re.IGNORECASE | re.DOTALL
        )
        s = p.sub(lambda m: f"(({m.group('a').strip()}) - ({m.group('b').strip()}))", s)

        p2 = re.compile(
            r"DATE_PART\s*\(\s*'day'\s*,\s*(?P<a>.+?)\s*-\s*(?P<b>.+?)\s*\)",
            re.IGNORECASE | re.DOTALL
        )
        s = p2.sub(lambda m: f"(({m.group('a').strip()}) - ({m.group('b').strip()}))", s)

        return s

    # -------------------------- Ayudas de esquema (tipos) ---------------------

    def _mapa_tipos_esquema(self, esquema_json: Dict[str, Any]) -> Dict[str, str]:
        """
        Mapa: "Nombre Columna" -> "TIPO"
        Nota: si hay columnas repetidas en varias tablas, toma la primera ocurrencia (para 1 tabla, suficiente).
        """
        mp: Dict[str, str] = {}
        for t in (eschema := (esquema_json.get("tables", []) or [])):
            for c in (t.get("columns", []) or []):
                nm = c.get("name")
                tp = (c.get("type") or "")
                if nm and nm not in mp:
                    mp[nm] = tp
        return mp

    def _es_tipo_texto(self, tipo_str: str) -> bool:
        t = (tipo_str or "").lower()
        return any(x in t for x in ["char", "text", "varchar", "string", "clob"])

    def _columnas_no_texto(self, esquema_json: Dict[str, Any]) -> List[str]:
        mp = self._mapa_tipos_esquema(esquema_json)
        out = []
        for nm, tp in mp.items():
            if nm and (not self._es_tipo_texto(tp)):
                out.append(nm)
        return out

    def _columnas_texto(self, esquema_json: Dict[str, Any]) -> List[str]:
        mp = self._mapa_tipos_esquema(esquema_json)
        out = []
        for nm, tp in mp.items():
            if nm and self._es_tipo_texto(tp):
                out.append(nm)
        return out

    # -------------------------- Guard rails SQL (post) -------------------------

    def _proteger_trim_no_texto(self, sql: str, esquema_json: Dict[str, Any], dialecto: str) -> str:
        """
        Si el LLM usa TRIM() sobre columnas no-texto (BIGINT, NUMERIC, etc), reescribe para evitar error:
        - Postgres: TRIM(CAST(col AS TEXT))
        - Otros:    TRIM(CAST(col AS VARCHAR))
        - SQLServer: TRIM(CAST(col AS NVARCHAR(4000)))
        """
        s = (sql or "")
        if not s.strip():
            return s

        no_texto = self._columnas_no_texto(esquema_json)
        if not no_texto:
            return s

        d = (dialecto or "").lower()
        tipo_cast = "TEXT" if d in ("postgresql", "postgres", "postgre") else "VARCHAR"
        if d in ("mssql", "sqlserver"):
            tipo_cast = "NVARCHAR(4000)"

        for col in sorted(no_texto, key=len, reverse=True):
            col_q = re.escape(col)

            # TRIM("Col")
            p1 = re.compile(rf"\bTRIM\s*\(\s*\"{col_q}\"\s*\)", re.IGNORECASE)
            s = p1.sub(lambda m: f'TRIM(CAST("{col}" AS {tipo_cast}))', s)

            # TRIM(<qualifiers>."Col")
            p2 = re.compile(
                rf"\bTRIM\s*\(\s*(?P<q>(?:\w+|\"[^\"]+\")\s*\.\s*)+\"{col_q}\"\s*\)",
                re.IGNORECASE
            )
            s = p2.sub(lambda m: f'TRIM(CAST({m.group("q")}"{col}" AS {tipo_cast}))', s)

        return s

    def _proteger_numeric_clean_no_texto(self, sql: str, esquema_json: Dict[str, Any]) -> None:
        """
        Opción estricta: falla temprano si se detecta NUMERIC_CLEAN sobre columnas no-texto.
        Activación con: SQL_FAIL_ON_NUMERIC_CLEAN_NONTEXT=true en .env
        """
        estricto = env("SQL_FAIL_ON_NUMERIC_CLEAN_NONTEXT", default=False, cast=bool)
        if not estricto:
            return

        s = (sql or "")
        if not s.strip():
            return

        no_texto = self._columnas_no_texto(esquema_json)
        if not no_texto:
            return

        columnas_malas = []
        for col in no_texto:
            col_q = re.escape(col)
            if re.search(rf"\bNUMERIC_CLEAN\s*\(\s*\"{col_q}\"\s*\)", s, flags=re.IGNORECASE):
                columnas_malas.append(col)

        if columnas_malas:
            raise RuntimeError(f"SQL inválida: NUMERIC_CLEAN aplicado sobre columnas no-texto: {columnas_malas}")

    # -------------------------- Validación de JSON SQL ------------------------

    def _asegurar_sql_json(self, payload: str) -> str:
        """
        Acepta:
        - JSON limpio {"sql_query":"...","original_query":"..."}
        - JSON embebido en texto
        - Casos con escapes / truncados
        - Fallback: si solo viene SQL, lo envuelve en el JSON esperado
        """
        def _probar(s: str) -> Optional[Dict[str, Any]]:
            try:
                obj = json.loads(s)
                if isinstance(obj, dict) and "sql_query" in obj:
                    obj.setdefault("original_query", "")
                    return obj
            except Exception:
                return None
            return None

        t = (payload or "").strip()

        obj = _probar(t)
        if obj:
            return json.dumps(obj, ensure_ascii=False)

        m = re.search(r"\{.*\}", t, re.DOTALL)
        if m:
            obj = _probar(m.group(0))
            if obj:
                return json.dumps(obj, ensure_ascii=False)

        # "sql_query": ".... (truncado/escapes)"
        m2 = re.search(r'"sql_query"\s*:\s*"(?P<q>.*)', t, re.DOTALL)
        if m2:
            crudo = m2.group("q")
            crudo = crudo.replace('\\"', '"')
            crudo = crudo.replace("\\n", "\n").replace("\\t", "\t")
            ultima_comilla = crudo.rfind('"')
            sql = crudo[:ultima_comilla] if ultima_comilla > 0 else crudo
            sql = sql.strip()
            if sql:
                return json.dumps({"sql_query": sql, "original_query": ""}, ensure_ascii=False)

        if re.search(r"^\s*(with\b|select\b|explain\b)", t, re.IGNORECASE):
            return json.dumps({"sql_query": t, "original_query": ""}, ensure_ascii=False)

        raise RuntimeError(f"Gemini devolvió un formato inesperado: {t[:400]}")

    # -------------------------------- NL -> SQL -------------------------------

    async def consulta_humana_a_sql(
        self,
        consulta: str,
        esquema_json: Dict[str, Any],
        dialecto: str = "postgresql",
        limite_por_defecto: int = 100,
        modelo: Optional[str] = None
    ) -> str:
        """
        Convierte una consulta en lenguaje natural a SQL válido y seguro (solo lectura), devolviendo JSON:
        { "sql_query": "...", "original_query": "..." }

        Aplica:
        - Hedging + fallback de modelos
        - Timeouts por modelo y totales
        - Postprocesos correctivos (ORDER BY, trims, date diff Postgres)
        - Validación y reparación de JSON
        """
        esquema_compacto = [
            {
                "schema": t["schema"],
                "table": t["table"],
                "columns": [{"name": c["name"], "type": c.get("type", "")} for c in t["columns"]],
                "fq_name": t.get("fq_name"),
            }
            for t in esquema_json.get("tables", [])
        ]
        fq_names = [t.get("fq_name") for t in esquema_json.get("tables", []) if t.get("fq_name")]

        # Pistas de tipos (clave para evitar TRIM(bigint), etc.)
        columnas_no_texto = self._columnas_no_texto(esquema_json)
        columnas_texto = self._columnas_texto(esquema_json)

        # --- justo antes de construir system_instruction, agrega este helper local ---
        def _reglas_por_dialecto(d: str) -> str:
            dd = (d or "").lower().strip()

            if dd in ("mssql", "sqlserver"):
                return f"""
DIALECT: SQL SERVER (T-SQL / Azure SQL)

- Use square brackets for identifiers, especially if they contain spaces or accents:
  Example: [Fecha de Pedido], [NroMuestraBDAccess].
- Prefer fully-qualified names EXACTLY as they appear in <allowed_fqn> (e.g., [dbo].[Project]).
- Do NOT use LIMIT. Use TOP ({limite_por_defecto}) in the SELECT clause.
- Do NOT use Postgres-only macros or syntax:
  - NO NUMERIC_CLEAN(...)
  - NO DATE_PARSE(...)
  - NO regex operators (~, !~*)
- For numeric text cleanup (only if the column is TEXT in schema), use TRY_CONVERT/TRY_CAST patterns, e.g.:
  TRY_CONVERT(decimal(38,10), REPLACE(REPLACE(LTRIM(RTRIM([Col])), '.', ''), ',', '.'))
  (Keep it simple; avoid complex regex.)
- For DATE parsing of TEXT (only if needed), use TRY_CONVERT(date, ...) with a known style when possible.
- When using TOP, if the query is an aggregation or ranking, include an ORDER BY that matches the intent
  (e.g., ORDER BY SUM(...) DESC, ORDER BY [Fecha] DESC).
""".strip()

            # Default: Postgres-style
            return f"""
DIALECT: POSTGRESQL

- Use double quotes for identifiers with spaces/accents: "Fecha de Pedido".
- Prefer fully-qualified names EXACTLY as they appear in <allowed_fqn>.
- You MAY use macros (server expands): NUMERIC_CLEAN("Col"), DATE_PARSE("Col").
- Always add LIMIT {limite_por_defecto} if missing.
- Regex operators (~, !~*) are allowed only in Postgres.
""".strip()


# --- Reemplaza tu system_instruction actual por este ---
        system_instruction = fr"""
You are a careful SQL generator for {dialecto.upper()}.

Hard rules:
- Output must be READ-ONLY: SELECT/CTE/EXPLAIN (without ANALYZE). No INSERT/UPDATE/DELETE/DDL/CALL.
- Use only tables/columns from the provided schema. Do not hallucinate.
- {self._cita_dialecto(dialecto)}
- Prefer fully-qualified names exactly as in <allowed_fqn>.
- Always include a row limit in the dialect-appropriate way.

{_reglas_por_dialecto(dialecto)}

IMPORTANT:
- Do NOT add UNION, ROLLUP, CUBE, GROUPING SETS, or any total/overall rows.
- Do NOT return “total” rows (no summary rows); return only the per-group rows requested.

FIELD & TYPE RULES (VERY IMPORTANT):
- The schema provides column types.
- DO NOT use TRIM(), COALESCE(TRIM(...),''), regex, or string comparisons on NON-TEXT columns
  (e.g., BIGINT/INT/NUMERIC/DATE/DATETIME/UNIQUEIDENTIFIER).
- For NON-TEXT null checks use: [Col] IS NOT NULL  (or "Col" IS NOT NULL in Postgres).
- For TEXT blank checks:
  - SQL Server: COALESCE(LTRIM(RTRIM([Col])), '') <> ''
  - Postgres:   COALESCE(TRIM("Col"), '') <> ''

NUMERIC cleanup rules:
- If a metric column is already numeric in schema, use it directly (or CAST/TRY_CAST if needed).
- NEVER apply numeric cleanup to identifiers/keys.
- If the user asks for totals by some key:
  SELECT <key>, SUM(<metric>) AS <alias>
  GROUP BY <key>
  ORDER BY SUM(<metric>) DESC

Footer/total rows exclusion:
- If grouping by a TEXT key:
  - SQL Server example:
      WHERE COALESCE(LTRIM(RTRIM([Key])), '') <> ''
        AND LOWER(LTRIM(RTRIM([Key]))) NOT LIKE 'total%'
        AND LOWER(LTRIM(RTRIM([Key]))) NOT LIKE 'gran total%'
        AND LOWER(LTRIM(RTRIM([Key]))) NOT LIKE 'totales%'
  - Postgres example:
      WHERE COALESCE(TRIM("Key"), '') <> ''
        AND "Key" !~* '^\s*total'
        AND "Key" !~* '^\s*gran\s*total'
        AND "Key" !~* '^\s*totales'

Field coverage (VERY IMPORTANT):
- If the user asks for specific fields (e.g., “material”, “pedido venta”, “despachado”, “pendiente”),
  you MUST include those corresponding columns in the SELECT list.
- Avoid queries that return only identifiers when the user asked totals/metrics.

Return ONLY valid JSON:
{{
  "sql_query": "...",
  "original_query": "{consulta}"
}}

<schema_json>
{json.dumps(esquema_compacto, ensure_ascii=False)}
</schema_json>
<allowed_fqn>
{json.dumps(fq_names, ensure_ascii=False)}
</allowed_fqn>
<type_hints>
text_columns={json.dumps(columnas_texto, ensure_ascii=False)}
non_text_columns={json.dumps(columnas_no_texto, ensure_ascii=False)}
</type_hints>
""".strip()

        primario_full = self._resolver_modelo(modelo)
        modelos = self._cadena_fallback(primario_full, "GEMINI_MODEL_CANDIDATES")

        tcfg = self._tiempos_espera()
        timeout_por_modelo = tcfg["per_model_timeout"]
        timeout_total = tcfg["total_timeout"]
        escalonado = tcfg["hedge_stagger"]
        paralelas = max(1, tcfg["hedge_parallel"])

        contenidos = [{"role": "user", "parts": [{"text": consulta}]}]
        configuracion = {
            "response_mime_type": "application/json",
            "temperature": 0.06,
            "max_output_tokens": int(env("SQL_MAX_OUTPUT_TOKENS", default=2600)),
            "system_instruction": system_instruction,
        }

        inicio = time.time()
        tareas: List[asyncio.Task] = []
        lanzadas = 0
        errores: List[str] = []
        ganador: Optional[str] = None

        async def _lanzar(m: str):
            res = await self._llamar_generar(m, contenidos, configuracion, timeout_por_modelo)
            return m, res

        for i in range(min(paralelas, len(modelos))):
            tareas.append(asyncio.create_task(_lanzar(modelos[i])))
            lanzadas += 1

        while (time.time() - inicio) < timeout_total and tareas:
            restante = max(0.1, timeout_total - (time.time() - inicio))
            hechas, pendientes = await asyncio.wait(tareas, return_when=asyncio.FIRST_COMPLETED, timeout=restante)

            if not hechas:
                if lanzadas < len(modelos):
                    await asyncio.sleep(escalonado)
                    tareas.append(asyncio.create_task(_lanzar(modelos[lanzadas])))
                    lanzadas += 1
                else:
                    break
                continue

            for d in hechas:
                mdl, res = await d
                if isinstance(res, Exception):
                    msg = _mensaje_excepcion(res)
                    errores.append(f"{mdl}: {msg}")

                    status = (getattr(res, "status", "") or "").upper()
                    code = (getattr(res, "code", "") or "")
                    code_str = str(code).upper()

                    # 404 / modelo no disponible: probar siguiente
                    if status == "NOT_FOUND" or "not found" in msg.lower() or "no longer available" in msg.lower():
                        continue

                    # 429 / cuota: dormir y seguir intentando si hay tiempo
                    if status == "RESOURCE_EXHAUSTED" or code_str == "429":
                        esperar_s = _parsear_reintentar_en_segundos(msg)
                        if esperar_s > 0:
                            await asyncio.sleep(esperar_s)
                        continue

                    continue

                # Cancelar el resto y elegir primer ganador
                for p in pendientes:
                    p.cancel()

                texto = (res.text or "").strip()
                if texto:
                    log.info("[gemini.consulta_humana_a_sql] ganador=%s (lat=%.2fs)", mdl, time.time() - inicio)
                    ganador = texto
                    tareas.clear()
                    break

                errores.append(f"{mdl}: respuesta vacía")

            tareas = [t for t in tareas if not t.done()]
            if ganador:
                break

            if lanzadas < len(modelos) and len(tareas) < paralelas:
                await asyncio.sleep(escalonado)
                tareas.append(asyncio.create_task(_lanzar(modelos[lanzadas])))
                lanzadas += 1

        def _posprocesar_sql(sql: str) -> str:
            """Aplica correcciones y guard-rails al SQL."""
            sql2 = (sql or "").strip()
            if (dialecto or "").lower() in ("postgresql", "postgres", "postgre"):
                sql2 = self._arreglar_postgres_datepart_day(sql2)
            sql2 = self._orden_automatico(sql2, consulta)

            # Guard rails de tipos
            sql2 = self._proteger_trim_no_texto(sql2, esquema_json=esquema_json, dialecto=dialecto)
            self._proteger_numeric_clean_no_texto(sql2, esquema_json=esquema_json)

            return sql2

        if ganador:
            try:
                obj = json.loads(self._asegurar_sql_json(ganador))
            except Exception:
                # Reparar JSON con un pase adicional
                prompt_reparacion = (
                    "Devuelve EXCLUSIVAMENTE un JSON válido con el formato:\n"
                    '{ "sql_query": "...", "original_query": "..." }\n'
                    "Sin markdown, sin texto extra.\n\n"
                    f"Texto a corregir:\n{ganador[:9000]}"
                )
                contenidos_reparar = [{"role": "user", "parts": [{"text": prompt_reparacion}]}]
                resp_reparar = await asyncio.to_thread(
                    self.cliente.models.generate_content,
                    model=modelos[0],
                    contents=contenidos_reparar,
                    config={
                        "response_mime_type": "application/json",
                        "temperature": 0.0,
                        "max_output_tokens": int(env("SQL_REPAIR_MAX_TOKENS", default=900)),
                    },
                )
                obj = json.loads(self._asegurar_sql_json((resp_reparar.text or "").strip()))

            sql = _posprocesar_sql(obj.get("sql_query") or "")
            obj["sql_query"] = sql
            return json.dumps(obj, ensure_ascii=False)

        # Fallback secuencial si todo falló
        for mdl in modelos:
            try:
                res = await asyncio.wait_for(
                    asyncio.to_thread(self.cliente.models.generate_content, model=mdl, contents=contenidos, config=configuracion),
                    timeout=timeout_por_modelo * 1.4
                )
                txt = (res.text or "").strip()
                if txt:
                    obj = json.loads(self._asegurar_sql_json(txt))
                    obj["sql_query"] = _posprocesar_sql(obj.get("sql_query") or "")
                    log.info("[gemini.consulta_humana_a_sql] ganador(secuencial)=%s", mdl)
                    return json.dumps(obj, ensure_ascii=False)
            except Exception as e:
                errores.append(f"{mdl}: {_mensaje_excepcion(e)}")

        raise RuntimeError("Fallo consulta_humana_a_sql: " + " ; ".join(errores[-8:]))

    # ---------------------------- Render de respuesta -------------------------

    def _renderizar_objeto_respuesta(self, obj: Dict[str, Any]) -> str:
        """Normaliza/limpia el objeto JSON de respuesta y lo renderiza como texto."""
        resumen = (obj.get("summary") or "").strip()
        hallazgos = obj.get("insights") or []
        salvedades = obj.get("caveats") or []

        def limpiar_lista(xs, max_n):
            out = []
            for x in (xs or [])[:max_n]:
                if isinstance(x, str):
                    t = re.sub(r"\s+", " ", x.strip())
                    t = re.sub(r"^(\*|-|•|\u2022)\s*", "", t)
                    if t:
                        out.append(t)
            return out

        ins = limpiar_lista(hallazgos, 10)
        cav = limpiar_lista(salvedades, 4)

        lineas: List[str] = []
        if resumen:
            lineas.append(resumen if resumen.endswith((".", "!", "?")) else resumen + ".")
        for t in ins:
            lineas.append(f"- {t}")
        for t in cav:
            lineas.append(f"Nota: {t}")
        return "\n".join(lineas).strip()

    def _parece_truncado(self, texto: str) -> bool:
        """Heurística simple para detectar texto cortado/incompleto."""
        t = (texto or "").strip()
        if not t:
            return True
        if re.search(r"\b\d+\.\s*$", t):
            return True
        if re.search(r"(debido a que|porque|ya que|se debe a que)\s*$", t, flags=re.IGNORECASE):
            return True
        if not t.endswith((".", "!", "?", "…")) and len(t) < 220:
            return True
        return False

    def _parece_alucinada(self, renderizado: str, claves_fila: List[str]) -> bool:
        """
        Heurística simple para detectar alucinaciones obvias cuando las columnas no soportan el contenido.
        """
        texto = (renderizado or "").lower()
        claves = " ".join([k.lower() for k in (claves_fila or [])])

        terminos_sospechosos = [
            "asia", "asia-pacífico", "pacifico", "marketing", "campaña", "roi", "retención",
            "lealtad", "proyecciones", "mercados emergentes", "interanual", "cambiari",
            "lanzamiento", "producto alfa", "canales tradicionales"
        ]

        if any(t in texto for t in terminos_sospechosos):
            cols_rel = ["roi", "marketing", "campaña", "retención", "mercado", "región", "producto", "proyección"]
            if not any(rc in claves for rc in cols_rel):
                return True

        if "crecim" in texto and not any(x in claves for x in ["fecha", "mes", "año", "trimestre", "periodo", "week"]):
            return True

        return False

    def _primer_json(self, s: str) -> Optional[Dict[str, Any]]:
        """Obtiene el primer objeto JSON embebido en el texto (si existe)."""
        s = (s or "").strip()
        try:
            obj = json.loads(s)
            if isinstance(obj, dict):
                return obj
        except Exception:
            pass
        m = re.search(r"\{.*\}", s, re.DOTALL)
        if not m:
            return None
        try:
            obj = json.loads(m.group(0))
            if isinstance(obj, dict):
                return obj
        except Exception:
            return None
        return None

    async def _reparar_o_continuar_json(
        self,
        mdl: str,
        schema_json_str: str,
        ultimo_texto: str,
        timeout_s: float,
        config_base: Dict[str, Any],
    ) -> Optional[Dict[str, Any]]:
        """Reparación/continuación para producir un JSON válido conforme al schema esperado."""
        prompt_reparar = (
            "El texto anterior está incompleto o inválido.\n"
            "Devuelve SOLO un JSON válido que cumpla EXACTAMENTE el schema.\n"
            "Reglas:\n"
            "- No inventes contexto.\n"
            "- Usa únicamente lo presente en `rows` y `profile`.\n"
            "- Asegura que `summary` termine en frase completa.\n\n"
            f"Schema:\n{schema_json_str}\n\n"
            f"Texto a reparar:\n{(ultimo_texto or '')[:12000]}"
        )
        contenidos = [{"role": "user", "parts": [{"text": prompt_reparar}]}]
        try:
            resp = await asyncio.wait_for(
                asyncio.to_thread(self.cliente.models.generate_content, model=mdl, contents=contenidos, config=config_base),
                timeout=timeout_s
            )
            txt = (resp.text or "").strip()
            obj = self._primer_json(txt)
            return obj
        except Exception:
            return None

    # -------------------------------- Resumen --------------------------------

    async def construir_respuesta(
        self,
        filas: List[Dict[str, Any]],
        consulta_humana: str,
        modelo: Optional[str] = None
    ) -> str:
        """
        Construye una respuesta en lenguaje natural a partir de:
        - filas (muestra compactada)
        - un perfil estadístico determinístico
        - un schema JSON de salida: {"summary": str, "insights": [str], "caveats": [str]}

        Retorna:
            Texto en español con resumen + bullets y notas cuando apliquen.
        """
        max_filas = int(env("ANSWER_MAX_ROWS", default=400))
        max_caracteres = int(env("ANSWER_MAX_CHARS", default=12000))
        filas_json = _compactar_filas_para_resumen(filas, max_filas, max_caracteres)

        perfil = _calcular_perfil(filas, max_claves_top=8)
        perfil_json = json.dumps(perfil, ensure_ascii=False)[:14000]

        claves_fila = list(filas[0].keys()) if filas else []

        schema = {
            "type": "object",
            "properties": {
                "summary": {"type": "string"},
                "insights": {"type": "array", "items": {"type": "string"}, "minItems": 0, "maxItems": 10},
                "caveats": {"type": "array", "items": {"type": "string"}, "minItems": 0, "maxItems": 4},
            },
            "required": ["summary"],
            "additionalProperties": False
        }
        system_instruction = json.dumps(schema, ensure_ascii=False)

        prompt = (
            "Eres un ANALISTA SENIOR de datos.\n"
            "Tu respuesta DEBE basarse únicamente en los campos y valores presentes en `rows` y en `profile`.\n\n"
            "PROHIBIDO:\n"
            "- Inventar contexto (mercados, regiones, campañas, productos, proyecciones) si NO aparece en columnas/valores.\n"
            "- Usar ejemplos genéricos.\n\n"
            "OBLIGATORIO:\n"
            "- Si hay métricas numéricas en `profile.numeric`, menciona (cuando aplique): máximo, mínimo, mediana y p90.\n"
            "- Si hay ceros/outliers, indícalo solo si aparece en `profile`.\n"
            "- Si hay claves categóricas en `profile.categorical`, menciona concentración (top y %).\n"
            "- Si la evidencia es insuficiente, dilo explícitamente.\n"
            "- No dejes frases cortadas.\n\n"
            "Devuelve EXCLUSIVAMENTE un JSON válido con este schema (sin markdown):\n"
            '{ "summary": "...", "insights": ["..."], "caveats": ["..."] }\n\n'
            f"Pregunta:\n{consulta_humana}\n\n"
            f"Columnas disponibles:\n{json.dumps(claves_fila, ensure_ascii=False)}\n\n"
            f"Profile (estadístico real):\n{perfil_json}\n\n"
            f"Rows (muestra truncada):\n{filas_json}\n"
        ).strip()

        primario_full = self._resolver_modelo_respuesta(modelo)
        modelos = self._cadena_fallback(primario_full, "GEMINI_MODEL_ANSWER_CANDIDATES")

        timeout_por_modelo = float(env("ANSWER_PER_MODEL_TIMEOUT", default=55.0))
        timeout_total = float(env("ANSWER_TOTAL_TIMEOUT", default=140.0))

        contenidos_base = [{"role": "user", "parts": [{"text": prompt}]}]
        config_base = {
            "response_mime_type": "application/json",
            "temperature": float(env("ANSWER_TEMPERATURE", default=0.14)),
            "max_output_tokens": int(env("ANSWER_MAX_OUTPUT_TOKENS", default=4096)),
            "system_instruction": system_instruction,
        }

        inicio = time.time()
        errores: List[str] = []
        schema_str = system_instruction

        async def _invocar(mdl: str, contenidos, config, timeout_s: float):
            try:
                resp = await asyncio.wait_for(
                    asyncio.to_thread(self.cliente.models.generate_content, model=mdl, contents=contenidos, config=config),
                    timeout=timeout_s
                )
                return resp.text or ""
            except Exception as e:
                return e

        for mdl in modelos:
            rem = timeout_total - (time.time() - inicio)
            if rem <= 0.5:
                break

            for intento in range(2):
                rem2 = timeout_total - (time.time() - inicio)
                if rem2 <= 0.5:
                    break

                timeout_este = min(timeout_por_modelo * (1.0 + 0.25 * intento), rem2)
                txt = await _invocar(mdl, contenidos_base, config_base, timeout_este)

                if isinstance(txt, Exception):
                    msg = _mensaje_excepcion(txt)
                    errores.append(f"{mdl}: {msg}")

                    status = (getattr(txt, "status", "") or "").upper()
                    code = (getattr(txt, "code", "") or "")
                    code_str = str(code).upper()

                    if status == "NOT_FOUND" or "not found" in msg.lower() or "no longer available" in msg.lower():
                        break

                    if status == "RESOURCE_EXHAUSTED" or code_str == "429":
                        esperar_s = _parsear_reintentar_en_segundos(msg)
                        if esperar_s > 0 and rem2 > esperar_s:
                            await asyncio.sleep(esperar_s)
                        continue

                    continue

                obj = self._primer_json(txt)
                if obj and isinstance(obj, dict) and (obj.get("summary") or "").strip():
                    renderizado = self._renderizar_objeto_respuesta(obj)

                    if renderizado and not self._parece_alucinada(renderizado, claves_fila) and not self._parece_truncado(renderizado):
                        log.info("[gemini.construir_respuesta] ganador=%s intento=%d lat=%.2fs", mdl, intento + 1, time.time() - inicio)
                        return renderizado

                    if renderizado and self._parece_truncado(renderizado) and rem2 > 8.0:
                        obj2 = await self._reparar_o_continuar_json(
                            mdl=mdl,
                            schema_json_str=schema_str,
                            ultimo_texto=txt,
                            timeout_s=min(22.0, rem2),
                            config_base=config_base,
                        )
                        if obj2 and (obj2.get("summary") or "").strip():
                            renderizado2 = self._renderizar_objeto_respuesta(obj2)
                            if renderizado2 and not self._parece_alucinada(renderizado2, claves_fila) and not self._parece_truncado(renderizado2):
                                log.info("[gemini.construir_respuesta] ganador(repair)=%s lat=%.2fs", mdl, time.time() - inicio)
                                return renderizado2

                # Intento de fix rápido del JSON
                prompt_fix = (
                    "Corrige el siguiente texto a un JSON VÁLIDO que cumpla exactamente el schema. "
                    "NO des explicaciones. NO agregues contexto que no esté en `rows`/`profile`. "
                    "Asegura que `summary` termine en frase completa.\n"
                    f"{(txt or '')[:12000]}"
                )
                contenidos_fix = [{"role": "user", "parts": [{"text": prompt_fix}]}]
                txt_fix = await _invocar(mdl, contenidos_fix, config_base, min(22.0, rem2))

                if not isinstance(txt_fix, Exception):
                    obj2 = self._primer_json(txt_fix)
                    if obj2 and isinstance(obj2, dict) and (obj2.get("summary") or "").strip():
                        renderizado2 = self._renderizar_objeto_respuesta(obj2)
                        if renderizado2 and not self._parece_alucinada(renderizado2, claves_fila) and not self._parece_truncado(renderizado2):
                            log.info("[gemini.construir_respuesta] ganador(fix)=%s lat=%.2fs", mdl, time.time() - inicio)
                            return renderizado2

                errores.append(f"{mdl}: sin JSON válido/aceptable (intento {intento + 1})")

        log.warning("[gemini.construir_respuesta] fallback local. errores: %s", "; ".join(errores[-8:]))
        return _respuesta_local_de_respaldo(consulta_humana=consulta_humana, filas=filas, perfil=perfil)

    # --------------------------------- Ping -----------------------------------

    async def ping(self, modelo: Optional[str] = None) -> str:
        """Comprueba disponibilidad devolviendo el primer texto no vacío."""
        primario_full = self._resolver_modelo(modelo)
        modelos = self._cadena_fallback(primario_full, "GEMINI_MODEL_CANDIDATES")
        ultimo = ""
        for m in modelos:
            try:
                resp = await asyncio.to_thread(
                    self.cliente.models.generate_content,
                    model=m,
                    contents=[{"role": "user", "parts": [{"text": "ping"}]}],
                )
                t = (resp.text or "").strip()
                if t:
                    return t
                ultimo = t
            except Exception as e:
                log.warning("[gemini] ping falló con %s: %s", m, e)
                continue
        return ultimo

    # --------------------------------- Aux ------------------------------------

    def _cita_dialecto(self, dialecto: str) -> str:
        """Indica cómo citar identificadores para distintos SGBD."""
        d = (dialecto or "postgresql").lower()
        if d in ("postgresql", "sqlite"):
            return 'Use double quotes for identifiers.'
        if d == "mysql":
            return 'Use backticks for identifiers.'
        if d in ("mssql", "sqlserver"):
            return 'Use square brackets for identifiers.'
        return 'Use double quotes by default.'

    def listar_modelos(self) -> Dict[str, Any]:
        """Devuelve el listado de modelos visibles por la clave/proyecto actual."""
        items = []
        try:
            for m in self.cliente.models.list():
                metodos = getattr(m, "supported_generation_methods", None) or getattr(m, "generation_methods", None)
                items.append({"name": m.name, "methods": metodos})
            return {"status": "ok", "models": items}
        except Exception as e:
            return {"status": "error", "detail": str(e)}