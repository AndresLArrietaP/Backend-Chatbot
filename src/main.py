# # src/main.py
# # -*- coding: utf-8 -*-
# """
# Módulo: main
# ------------
# API FastAPI para:
# - Generar SQL a partir de lenguaje natural (NL → SQL) con controles de seguridad.
# - Ejecutar consultas contra la base de datos.
# - Normalizar resultados y (opcional) sintetizar una respuesta en lenguaje natural.

# Cambios:
# - Código renombrado al español (funciones/variables) y documentado.
# - Comentarios clave y limpieza.
# - Se mantienen rutas/paths idénticos y compatibilidad con módulos `database` y `llm`
#   (ambos exponen alias en inglés y español), por lo que no se cambia el comportamiento.
# """

# import json
# import logging
# import re
# import time
# import unicodedata
# from decimal import Decimal
# from hashlib import sha1
# from typing import Any, Dict, List, Optional, Tuple, Union

# from decouple import config as env
# from fastapi import APIRouter, Depends, Header, HTTPException, Query, Request
# from pydantic import BaseModel

# from . import database
# from . import llm

# log = logging.getLogger(__name__)
# router = APIRouter()

# # =============================================================================
# # Normalización / utilidades
# # =============================================================================

# def _a_numero(v: Any) -> Any:
#     """Convierte Decimal/int/float a float; devuelve el valor original en otros casos."""
#     if isinstance(v, Decimal):
#         return float(v)
#     if isinstance(v, (int, float)):
#         return float(v)
#     return v


# def _normalizar_nombre_clave(s: str) -> str:
#     """Normaliza una etiqueta para comparación: sin acentos, minúsculas y sin espacios extremos."""
#     if not s:
#         return ""
#     s_norm = unicodedata.normalize("NFKD", s)
#     s_no_acc = "".join(ch for ch in s_norm if not unicodedata.combining(ch))
#     return s_no_acc.strip().lower()


# def normalizar_filas(
#     filas: List[Dict[str, Any]],
#     columnas_miles_implicitos: List[str],
#     decimales: int = 3,
#     formatear_cadenas: bool = True,
# ) -> List[Dict[str, Any]]:
#     """
#     Normaliza filas con reglas de "milésimas implícitas" y formato de números.

#     - Divide por 1000 si se detecta patrón de milésimas implícitas.
#     - Si `formatear_cadenas=True`, devuelve números formateados como string con separador de miles.
#     """
#     columnas_implicitas = {_normalizar_nombre_clave(c) for c in (columnas_miles_implicitos or []) if c and c.strip()}

#     auto_kw = env("IMPLIED_MILLIS_AUTO_HEURISTIC", default=True, cast=bool)
#     auto_detect = env("IMPLIED_MILLIS_AUTODETECT", default=True, cast=bool)
#     ratio_umbral = env("IMPLIED_MILLIS_RATIO_THRESHOLD", default=0.8, cast=float)
#     min_abs = env("IMPLIED_MILLIS_MIN_ABS", default=100000, cast=int)

#     keywords_env = env(
#         "IMPLIED_MILLIS_KEYWORDS",
#         default="despachado,original,pendiente,total linea,total línea,total despachado,total original,total pendiente"
#     )
#     kw_list = [_normalizar_nombre_clave(w) for w in keywords_env.split(",") if w.strip()]

#     def _nombre_tiene_keyword(nombre_low: str) -> bool:
#         return any((kw in nombre_low) for kw in kw_list if kw)

#     def _es_gran_multiplo_1000(x: float) -> bool:
#         nearest = round(x)
#         return (abs(x - nearest) < 1e-9) and (abs(nearest) >= min_abs) and (nearest % 1000 == 0)

#     col_valores_num: Dict[str, List[float]] = {}
#     for r in filas or []:
#         for k, v in (r or {}).items():
#             if isinstance(v, Decimal):
#                 col_valores_num.setdefault(k, []).append(float(v))
#             elif isinstance(v, (int, float)):
#                 col_valores_num.setdefault(k, []).append(float(v))

#     columnas_auto_dividir = set()
#     if auto_detect and filas:
#         for col, vals in col_valores_num.items():
#             if len(vals) < 5:
#                 continue
#             vals_sorted = sorted(vals)
#             mid = len(vals_sorted) // 2
#             mediana = (vals_sorted[mid] if len(vals_sorted) % 2 == 1
#                        else 0.5 * (vals_sorted[mid - 1] + vals_sorted[mid]))
#             mult_cnt = sum(1 for x in vals if _es_gran_multiplo_1000(x))
#             ratio = mult_cnt / len(vals)
#             if ratio >= ratio_umbral or (mediana >= (min_abs * 2) and ratio >= 0.6):
#                 columnas_auto_dividir.add(_normalizar_nombre_clave(col))

#     salida: List[Dict[str, Any]] = []
#     for r in filas:
#         nr: Dict[str, Any] = {}
#         for k, v in (r or {}).items():
#             nombre_low = _normalizar_nombre_clave(k)
#             val = _a_numero(v)

#             if isinstance(val, (int, float)) or isinstance(v, Decimal):
#                 valf = float(val)

#                 dividir = False
#                 col_marcada = nombre_low in columnas_auto_dividir
#                 senal_suave = (nombre_low in columnas_implicitas) or (auto_kw and _nombre_tiene_keyword(nombre_low))

#                 if col_marcada:
#                     dividir = True
#                 elif senal_suave and _es_gran_multiplo_1000(valf):
#                     dividir = True

#                 if dividir:
#                     valf = valf / 1000.0

#                 if formatear_cadenas:
#                     if abs(valf - round(valf)) < 1e-9:
#                         nr[k] = f"{int(round(valf)):,}"
#                     else:
#                         nr[k] = f"{valf:,.{decimales}f}"
#                 else:
#                     nr[k] = round(valf, decimales)
#             else:
#                 nr[k] = v
#         salida.append(nr)

#     return salida

# def _parse_list_param(v: Optional[Union[List[str], str]]) -> Optional[List[str]]:
#     """
#     Acepta:
#     - None
#     - ["a", "b"] (multi query)
#     - "a,b" (csv)
#     - "a" (single)
#     """
#     if v is None:
#         return None
#     if isinstance(v, list):
#         out = []
#         for item in v:
#             if item is None:
#                 continue
#             out.extend([x.strip() for x in str(item).split(",") if x.strip()])
#         return out or None
#     # string
#     s = str(v).strip()
#     if not s:
#         return None
#     return [x.strip() for x in s.split(",") if x.strip()] or None

# def _respuesta_resumen_local(filas: List[Dict[str, Any]], consulta_humana: str) -> str:
#     """Genera un resumen local simple cuando el LLM no responde."""
#     if not filas:
#         return f"No se encontraron datos para la consulta: “{consulta_humana}”."

#     muestra = filas[0]
#     columnas_texto: List[str] = []
#     columnas_num: List[str] = []

#     for k in muestra.keys():
#         es_num = False
#         for r in filas:
#             v = r.get(k)
#             if isinstance(v, (int, float, Decimal)):
#                 es_num = True
#                 break
#             if isinstance(v, str):
#                 try:
#                     float(v.replace(",", ""))
#                     es_num = True
#                     break
#                 except Exception:
#                     pass
#         if es_num:
#             columnas_num.append(k)
#         else:
#             columnas_texto.append(k)

#     def _puntuar_texto(nombre: str) -> int:
#         n = _normalizar_nombre_clave(nombre)
#         if any(x in n for x in ["id", "codigo", "código", "pedido", "orden", "documento", "doc", "cliente"]):
#             return 3
#         return 1

#     def _puntuar_num(nombre: str) -> int:
#         n = _normalizar_nombre_clave(nombre)
#         if any(x in n for x in ["total", "monto", "importe", "valor", "cantidad", "despach", "pendien", "saldo"]):
#             return 3
#         return 1

#     columnas_texto.sort(key=_puntuar_texto, reverse=True)
#     columnas_num.sort(key=_puntuar_num, reverse=True)

#     col_clave = columnas_texto[0] if columnas_texto else None
#     col_valor = columnas_num[0] if columnas_num else None

#     bullets: List[str] = []
#     bullets.append(f"Filas analizadas: {len(filas)}.")

#     if col_valor:
#         total = 0.0
#         for r in filas:
#             v = r.get(col_valor)
#             try:
#                 if isinstance(v, str):
#                     v = float(v.replace(",", ""))
#                 elif isinstance(v, Decimal):
#                     v = float(v)
#                 elif not isinstance(v, (int, float)):
#                     v = 0.0
#             except Exception:
#                 v = 0.0
#             total += float(v)
#         bullets.append(f"Suma de “{col_valor}”: {total:,.3f}")

#     if col_clave and col_valor:
#         agg: Dict[str, float] = {}
#         for r in filas:
#             k = str(r.get(col_clave) or "(Sin valor)")
#             v = r.get(col_valor)
#             try:
#                 if isinstance(v, str):
#                     v = float(v.replace(",", ""))
#                 elif isinstance(v, Decimal):
#                     v = float(v)
#                 elif not isinstance(v, (int, float)):
#                     v = 0.0
#             except Exception:
#                 v = 0.0
#             agg[k] = agg.get(k, 0.0) + float(v)
#         top = sorted(agg.items(), key=lambda kv: kv[1], reverse=True)[:3]
#         if top:
#             bullets.append("Top por {0}: {1}".format(
#                 col_clave,
#                 "; ".join([f"{k} = {v:,.3f}" for k, v in top])
#             ))

#     partes = [f"Consulta: “{consulta_humana}”."]
#     if col_valor and col_clave:
#         partes.append(f"Se analizó “{col_valor}” por “{col_clave}” y se listan los principales aportes.")
#     elif col_valor:
#         partes.append(f"Se destaca la métrica “{col_valor}”.")
#     else:
#         partes.append("No se identificó una métrica numérica dominante; se muestran datos generales.")

#     final = " ".join(p if p.endswith((".", "!", "?")) else p + "." for p in partes)
#     for b in bullets[:3]:
#         final += f"\n- {b}"
#     return final


# # =============================================================================
# # Cache LLM → SQL
# # =============================================================================

# _CACHE_SQL: Dict[str, Dict[str, Any]] = {}
# TTL_CACHE_SQL = env("SQL_CACHE_TTL_SECONDS", default=300, cast=int)
# MAX_CACHE_SQL = env("SQL_CACHE_MAX", default=256, cast=int)

# def _clave_cache(consulta_humana: str, esquema_json: Dict[str, Any], dialecto: str, limite_por_defecto: int) -> str:
#     """Hash estable del input para cachear respuestas NL→SQL del LLM."""
#     payload = json.dumps(
#         {"q": consulta_humana, "schema": esquema_json, "dialect": dialecto, "limit": limite_por_defecto},
#         ensure_ascii=False, sort_keys=True
#     )
#     return sha1(payload.encode("utf-8")).hexdigest()

# def _cache_obtener(key: str) -> Optional[str]:
#     item = _CACHE_SQL.get(key)
#     if not item:
#         return None
#     if time.time() > item["exp"]:
#         _CACHE_SQL.pop(key, None)
#         return None
#     return item["sql_json"]

# def _cache_guardar(key: str, sql_json: str) -> None:
#     if len(_CACHE_SQL) >= MAX_CACHE_SQL:
#         oldest = min(_CACHE_SQL.items(), key=lambda kv: kv[1]["exp"])[0]
#         _CACHE_SQL.pop(oldest, None)
#     _CACHE_SQL[key] = {"exp": time.time() + TTL_CACHE_SQL, "sql_json": sql_json}


# # =============================================================================
# # Helpers tipo / blindajes SQL
# # =============================================================================

# def _es_tipo_texto(tipo_str: str) -> bool:
#     t = (tipo_str or "").lower()
#     return any(x in t for x in ["char", "text", "varchar", "string", "clob"])


# def _mapa_tipos_esquema(esquema_json: Dict[str, Any], tablas_solicitadas: Optional[List[str]]) -> Dict[str, str]:
#     """Devuelve mapa columna -> tipo (limitado a tablas_solicitadas si aplica)."""
#     wanted = {_normalizar_nombre_clave(t) for t in (tablas_solicitadas or []) if t}
#     mp: Dict[str, str] = {}
#     for tb in (esquema_json.get("tables", []) or []):
#         tname = _normalizar_nombre_clave(tb.get("table") or "")
#         if wanted and (tname not in wanted):
#             continue
#         for c in (tb.get("columns", []) or []):
#             nm = c.get("name")
#             tp = c.get("type") or ""
#             if nm and nm not in mp:
#                 mp[nm] = tp
#     return mp


# def _columnas_no_texto(esquema_json: Dict[str, Any], tablas_solicitadas: Optional[List[str]]) -> List[str]:
#     mp = _mapa_tipos_esquema(esquema_json, tablas_solicitadas)
#     return [nm for nm, tp in mp.items() if nm and (not _es_tipo_texto(tp))]


# def _sql_cast_trim_no_texto(sql: str, esquema_json: Dict[str, Any], dialecto: str, tablas_solicitadas: Optional[List[str]]) -> str:
#     """
#     Reescribe TRIM("col_no_text") -> TRIM(CAST("col_no_text" AS TEXT)) en Postgres.
#     Ejecutar DESPUÉS de expandir_macros (NUMERIC_CLEAN introduce TRIM).
#     """
#     s = (sql or "")
#     if not s.strip():
#         return s

#     no_texto = _columnas_no_texto(esquema_json, tablas_solicitadas=tablas_solicitadas)
#     if not no_texto:
#         return s

#     d = (dialecto or "").lower()
#     tipo_cast = "TEXT" if d in ("postgresql", "postgres", "postgre") else "VARCHAR"
#     if d in ("mssql", "sqlserver"):
#         tipo_cast = "NVARCHAR(4000)"

#     for col in sorted(no_texto, key=len, reverse=True):
#         col_q = re.escape(col)
#         p1 = re.compile(rf"\bTRIM\s*\(\s*\"{col_q}\"\s*\)", re.IGNORECASE)
#         s = p1.sub(lambda m: f'TRIM(CAST("{col}" AS {tipo_cast}))', s)

#         p2 = re.compile(
#             rf"\bTRIM\s*\(\s*(?P<q>(?:\w+|\"[^\"]+\")\s*\.\s*)+\"{col_q}\"\s*\)",
#             re.IGNORECASE
#         )
#         s = p2.sub(lambda m: f'TRIM(CAST({m.group("q")}"{col}" AS {tipo_cast}))', s)

#     return s


# def _reescribir_numeric_clean_no_texto(sql: str, esquema_json: Dict[str, Any], dialecto: str, tablas_solicitadas: Optional[List[str]]) -> str:
#     """
#     Si el LLM usa NUMERIC_CLEAN("col") sobre una columna NO-TEXTO (ej. BIGINT),
#     reescribe a CAST("col" AS numeric/DECIMAL), evitando TRIM/regex de la macro.
#     """
#     s = (sql or "")
#     if not s.strip():
#         return s

#     no_texto = _columnas_no_texto(esquema_json, tablas_solicitadas=tablas_solicitadas)
#     if not no_texto:
#         return s

#     d = (dialecto or "").lower()
#     cast_num = "numeric" if d in ("postgresql", "postgres", "postgre") else "DECIMAL(38,10)"

#     for col in sorted(no_texto, key=len, reverse=True):
#         col_q = re.escape(col)
#         p = re.compile(rf"\bNUMERIC_CLEAN\s*\(\s*\"{col_q}\"\s*\)", re.IGNORECASE)
#         s = p.sub(lambda m: f'CAST("{col}" AS {cast_num})', s)

#         p2 = re.compile(
#             rf"\bNUMERIC_CLEAN\s*\(\s*(?P<q>(?:\w+|\"[^\"]+\")\s*\.\s*)+\"{col_q}\"\s*\)",
#             re.IGNORECASE
#         )
#         s = p2.sub(lambda m: f'CAST({m.group("q")}"{col}" AS {cast_num})', s)

#     return s


# # =============================================================================
# # Generalización: detectar intenciones y columnas desde schema + query
# # =============================================================================

# _RE_TOTAL = re.compile(r"^\s*(gran\s*)?total(es)?\s*$", re.IGNORECASE)

# _PISTAS_COMPARACION = [
#     "supera", "mayor", "menor", "inferior", "superior", "&gt;", "&lt;", "&gt;=", "&lt;=",
#     "excede", "sobrepasa", "más que", "menos que", "higher", "lower", "greater", "less",
# ]

# _PISTAS_LISTA = ["lista", "listar", "muéstrame", "mostrar", "dame", "devuélveme", "retorna", "return", "top"]

# _RE_CLAUSULA_SELECT = re.compile(r"^\s*select\s+(?P<cols>.*?)\s+from\s", re.IGNORECASE | re.DOTALL)


# def _extraer_clausula_select(sql: str) -> str:
#     m = _RE_CLAUSULA_SELECT.search(sql or "")
#     return (m.group("cols") if m else "") or ""


# def _tablas_esquema(esquema_json: Dict[str, Any]) -> List[Dict[str, Any]]:
#     return esquema_json.get("tables", []) or []


# def _todas_columnas_esquema(esquema_json: Dict[str, Any]) -> List[str]:
#     cols: List[str] = []
#     for t in _tablas_esquema(esquema_json):
#         for c in (t.get("columns", []) or []):
#             nm = c.get("name")
#             if nm and nm not in cols:
#                 cols.append(nm)
#     return cols


# def _columnas_esquema_para_tablas(esquema_json: Dict[str, Any], tablas_solicitadas: Optional[List[str]]) -> List[str]:
#     if not tablas_solicitadas:
#         return _todas_columnas_esquema(esquema_json)

#     wanted = {_normalizar_nombre_clave(t) for t in tablas_solicitadas if t}
#     cols: List[str] = []
#     for t in _tablas_esquema(esquema_json):
#         tname = _normalizar_nombre_clave(t.get("table") or "")
#         if tname and tname in wanted:
#             for c in (t.get("columns", []) or []):
#                 nm = c.get("name")
#                 if nm and nm not in cols:
#                     cols.append(nm)
#     return cols or _todas_columnas_esquema(esquema_json)


# def _columnas_mencionadas(consulta_humana: str, columnas_esquema: List[str]) -> List[str]:
#     qn = _normalizar_nombre_clave(consulta_humana)
#     hits: List[Tuple[int, str]] = []
#     for col in columnas_esquema:
#         cn = _normalizar_nombre_clave(col)
#         if not cn:
#             continue
#         if cn in qn:
#             hits.append((len(cn), col))
#     hits.sort(key=lambda x: x[0], reverse=True)

#     out: List[str] = []
#     seen = set()
#     for _, col in hits:
#         if col not in seen:
#             out.append(col)
#             seen.add(col)
#     return out


# def _tiene_intencion_comparacion(consulta_humana: str) -> bool:
#     qn = _normalizar_nombre_clave(consulta_humana)
#     return any(cue in qn for cue in _PISTAS_COMPARACION)


# def _tiene_intencion_lista(consulta_humana: str) -> bool:
#     qn = _normalizar_nombre_clave(consulta_humana)
#     return any(cue in qn for cue in _PISTAS_LISTA)


# def _elegir_columna_clave(columnas_esquema: List[str], consulta_humana: str) -> Optional[str]:
#     qn = _normalizar_nombre_clave(consulta_humana)
#     preferidas = [
#         "id", "codigo", "código", "pedido", "orden", "documento", "doc",
#         "factura", "boleta", "cliente", "material", "producto", "ruc", "serie", "numero", "nro"
#     ]

#     def puntuar(col: str) -> int:
#         n = _normalizar_nombre_clave(col)
#         s = 0
#         if n and n in qn:
#             s += 5
#         for kw in preferidas:
#             if kw in n:
#                 s += 3
#         if any(x in n for x in ["monto", "importe", "total", "cantidad", "valor", "saldo"]):
#             s -= 2
#         return s

#     ranked = sorted(columnas_esquema, key=puntuar, reverse=True)
#     best = ranked[0] if ranked else None
#     if best and puntuar(best) >= 2:
#         return best
#     return ranked[0] if ranked else None


# def _sql_tiene_columna_en_select(sql: str, col: str) -> bool:
#     if not sql or not col:
#         return False
#     sel = _extraer_clausula_select(sql)
#     if not sel:
#         return False

#     col_esc = re.escape(col)
#     patrones = [
#         rf'"\s*{col_esc}\s*"',
#         rf'\.\s*"\s*{col_esc}\s*"',
#         rf'\bas\s+"{col_esc}"\b',
#         rf'\bNUMERIC_CLEAN\s*\(\s*[^)]*"{col_esc}"',
#         rf'\bDATE_PARSE\s*\(\s*[^)]*"{col_esc}"',
#     ]
#     return any(re.search(p, sel, flags=re.IGNORECASE | re.DOTALL) for p in patrones)


# def _parece_distinct_solo_id(sql: str) -> bool:
#     s = (sql or "").lower()
#     return ("select distinct" in s) and ("sum(" not in s) and ("group by" not in s)


# def _aumentar_consulta_para_select_requerido(consulta_humana: str, col_clave: Optional[str], columnas_metricas: List[str]) -> str:
#     partes = [consulta_humana.strip(), "| OBLIGATORIO: el SELECT debe incluir:"]
#     if col_clave:
#         partes.append(f'"{col_clave}"')
#     for c in columnas_metricas[:3]:
#         partes.append(f'NUMERIC_CLEAN("{c}") AS "{c}"')
#     if len(columnas_metricas) >= 2:
#         partes.append(f'(NUMERIC_CLEAN("{columnas_metricas[0]}") - NUMERIC_CLEAN("{columnas_metricas[1]}")) AS "Diferencia"')
#     partes.append("Si hay comparación, las columnas comparadas deben estar en SELECT.")
#     partes.append("Devuelve SOLO JSON.")
#     return " ".join(partes)


# def _inferir_operador_comparacion(consulta_humana: str) -> str:
#     qn = _normalizar_nombre_clave(consulta_humana)
#     if "&gt;=" in qn:
#         return "&gt;="
#     if "&lt;=" in qn:
#         return "&lt;="
#     if "&gt;" in qn:
#         return "&gt;"
#     if "&lt;" in qn:
#         return "&lt;"
#     if any(x in qn for x in ["menor", "inferior", "less", "lower", "menos que"]):
#         return "&lt;"
#     return "&gt;"


# def _quitar_filas_tipo_total(filas: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
#     """Elimina filas donde alguna columna textual está en blanco o coincide con 'total/gran total'."""
#     if not filas:
#         return filas

#     sample_keys = list(filas[0].keys())
#     columnas_texto: List[str] = []
#     for k in sample_keys:
#         for r in filas[:30]:
#             v = r.get(k)
#             if isinstance(v, str):
#                 columnas_texto.append(k)
#                 break
#     columnas_texto = list(dict.fromkeys(columnas_texto))

#     if not columnas_texto:
#         return filas

#     cleaned: List[Dict[str, Any]] = []
#     for r in filas:
#         drop = False
#         for k in columnas_texto:
#             v = r.get(k)
#             if v is None:
#                 drop = True
#                 break
#             if isinstance(v, str):
#                 t = v.strip()
#                 if t == "" or _RE_TOTAL.match(t):
#                     drop = True
#                     break
#         if not drop:
#             cleaned.append(r)
#     return cleaned


# # =============================================================================
# # Auth opcional API Key
# # =============================================================================

# async def guardia_api_key(request: Request, x_api_key: Optional[str] = Header(default=None)):
#     """Verifica API Key si la app tiene `API_KEY` configurada en settings."""
#     settings = request.app.state.settings
#     requerido = getattr(settings, "API_KEY", "") or ""
#     if not requerido:
#         return
#     if not x_api_key or x_api_key != requerido:
#         raise HTTPException(status_code=401, detail="API key inválida")


# # =============================================================================
# # Modelo request
# # =============================================================================

# class PayloadConsultaHumana(BaseModel):
#     """Modelo de entrada para /human_query."""
#     human_query: str
#     sql_query_override: Optional[str] = None
#     schemas: Optional[List[str]] = None
#     tables: Optional[List[str]] = None
#     dialect: Optional[str] = None
#     limit: Optional[int] = None
#     execute: bool = True
#     schema_refresh: bool = False
#     summarize: Optional[bool] = True
#     format_numbers: Optional[bool] = None
#     decimals: Optional[int] = None
#     implied_millis_cols: Optional[List[str]] = None


# # =============================================================================
# # Endpoints
# # =============================================================================

# @router.get("/")
# def raiz() -> Dict[str, str]:
#     return {"status": "ok", "docs": "/docs"}


# @router.get("/healthz")
# def healthz() -> Dict[str, str]:
#     return {"status": "healthy"}


# @router.get("/schema", dependencies=[Depends(guardia_api_key)])
# def obtener_esquema(
#     request: Request,
#     schemas: Optional[Union[List[str], str]] = Query(default=None),
#     tables: Optional[Union[List[str], str]] = Query(default=None),
# ) -> Dict[str, Any]:
#     settings = request.app.state.settings

#     schemas_list = _parse_list_param(schemas)
#     tables_list = _parse_list_param(tables)

#     if not schemas_list:
#         schemas_list = [s.strip() for s in getattr(settings, "TARGET_SCHEMAS", "public").split(",")]

#     esquema_json = database.obtener_esquema_json(
#         esquemas=schemas_list,
#         tablas=tables_list,
#         max_tablas=getattr(settings, "MAX_SCHEMA_TABLES", 50),
#         max_columnas=getattr(settings, "MAX_SCHEMA_COLUMNS", 2000),
#     )
#     return esquema_json


# @router.get("/llm/ping", dependencies=[Depends(guardia_api_key)])
# async def llm_ping(request: Request) -> Dict[str, Any]:
#     try:
#         txt = await llm.ping()
#         return {"status": "ok", "gemini_reply": (txt or "")[:200]}
#     except Exception as e:
#         return {"status": "error", "detail": str(e)}


# @router.get("/llm/models", dependencies=[Depends(guardia_api_key)])
# def llm_modelos() -> Dict[str, Any]:
#     try:
#         return llm.listar_modelos()
#     except Exception as e:
#         return {"status": "error", "detail": str(e)}


# @router.post("/schema/refresh", dependencies=[Depends(guardia_api_key)])
# def refrescar_esquema() -> Dict[str, str]:
#     database.refrescar_cache_esquema()
#     return {"status": "ok", "message": "Schema cache refreshed"}


# @router.post("/human_query", dependencies=[Depends(guardia_api_key)])
# async def consulta_humana(request: Request, payload: PayloadConsultaHumana) -> Dict[str, Any]:
#     """
#     Flujo principal:
#     1) Construcción del esquema y allow-list (FQN).
#     2) Heurísticas para detectar intención comparativa y columnas relevantes.
#     3) Generación de SQL (con cache) y correcciones preventivas por tipos.
#     4) Expansión de macros + guard rails.
#     5) Seguridad (solo-lectura + allow-list).
#     6) Ejecución (opcional) + normalización y síntesis.
#     """
#     try:
#         settings = request.app.state.settings

#         # 1) Esquema
#         if payload.schema_refresh:
#             database.refrescar_cache_esquema()

#         esquemas = payload.schemas or [s.strip() for s in getattr(settings, "TARGET_SCHEMAS", "public").split(",")]
#         esquema_json = database.obtener_esquema_json(
#             esquemas=esquemas,
#             tablas=payload.tables,
#             max_tablas=getattr(settings, "MAX_SCHEMA_TABLES", 50),
#             max_columnas=getattr(settings, "MAX_SCHEMA_COLUMNS", 2000),
#         )

#         allowed_fqn: List[str] = []
#         for t in esquema_json.get("tables", []) or []:
#             fq = t.get("fq_name")
#             if fq:
#                 allowed_fqn.append(fq)
#             else:
#                 allowed_fqn.append(f'{t["schema"]}."{t["table"]}"')

#         dialecto = payload.dialect or getattr(settings, "DB_DIALECT", "postgresql")
#         limite_por_defecto = payload.limit or getattr(settings, "MAX_ROWS_DEFAULT", 100)
#         limite_maximo = getattr(settings, "MAX_ROWS_HARD", 1000)

#         # 2) Heurísticas
#         columnas_esquema = _columnas_esquema_para_tablas(esquema_json, payload.tables)
#         columnas_mencion = _columnas_mencionadas(payload.human_query, columnas_esquema)
#         intencion_comparar = _tiene_intencion_comparacion(payload.human_query) and (len(columnas_mencion) >= 2)

#         tabla_fqn = allowed_fqn[0] if allowed_fqn else None
#         if payload.tables:
#             wanted = {_normalizar_nombre_clave(x) for x in payload.tables if x}
#             for t in esquema_json.get("tables", []) or []:
#                 if _normalizar_nombre_clave(t.get("table") or "") in wanted:
#                     tabla_fqn = (t.get("fq_name") or f'{t["schema"]}."{t["table"]}"')
#                     break
#         if not tabla_fqn:
#             raise HTTPException(status_code=500, detail="No se pudo determinar una tabla objetivo desde el esquema.")

#         op = _inferir_operador_comparacion(payload.human_query)
#         col_clave = _elegir_columna_clave(columnas_esquema, payload.human_query)
#         col_izq = columnas_mencion[0] if len(columnas_mencion) >= 1 else None
#         col_der = columnas_mencion[1] if len(columnas_mencion) >= 2 else None

#         # 3) SQL
#         if payload.sql_query_override:
#             sql_query = payload.sql_query_override
#             result_dict = {"sql_query": sql_query, "original_query": payload.human_query}
#             log.debug("[/human_query] using sql_query_override=%r", sql_query)
#         else:
#             cache_key = _clave_cache(payload.human_query, esquema_json, dialecto, limite_por_defecto)
#             cached = _cache_obtener(cache_key)
#             if cached:
#                 log.debug("[/human_query] LLM SQL cache HIT")
#                 sql_json = cached
#             else:
#                 sql_json = await llm.consulta_humana_a_sql(
#                     consulta_humana=payload.human_query,
#                     esquema_json=esquema_json,
#                     dialecto=dialecto,
#                     limite_por_defecto=limite_por_defecto,
#                     modelo=None,
#                 )
#                 _cache_guardar(cache_key, sql_json)

#             log.debug("[/human_query] LLM raw JSON=%s", (sql_json[:700] if sql_json else None))
#             if not sql_json:
#                 raise HTTPException(status_code=500, detail="Falló la generación de la consulta SQL")

#             result_dict = json.loads(sql_json)
#             sql_query = result_dict.get("sql_query")
#             if not sql_query:
#                 raise HTTPException(status_code=500, detail="El LLM no devolvió 'sql_query'")

#             if intencion_comparar and col_izq and col_der:
#                 if (_parece_distinct_solo_id(sql_query)
#                     or (not _sql_tiene_columna_en_select(sql_query, col_izq))
#                     or (not _sql_tiene_columna_en_select(sql_query, col_der))):
#                     forced_query = _aumentar_consulta_para_select_requerido(
#                         payload.human_query,
#                         col_clave=col_clave,
#                         columnas_metricas=[col_izq, col_der],
#                     )
#                     log.debug("[/human_query] retry forced_query=%s", forced_query)
#                     sql_json2 = await llm.consulta_humana_a_sql(
#                         consulta_humana=forced_query,
#                         esquema_json=esquema_json,
#                         dialecto=dialecto,
#                         limite_por_defecto=limite_por_defecto,
#                         modelo=None,
#                     )
#                     if sql_json2:
#                         try:
#                             parsed2 = json.loads(sql_json2)
#                             sql2 = (parsed2.get("sql_query") or "").strip()
#                             if sql2:
#                                 sql_query = sql2
#                                 result_dict = parsed2
#                         except Exception:
#                             pass

#         # =======================
#         # 4) Pipeline CORREGIDO
#         # =======================

#         # 4.1 limpieza base
#         sql_query = database.limpiar_sql(sql_query)
#         sql_query = database.sanear_explain(sql_query)
#         sql_query = database.calificar_tablas(sql_query, allowed_fqn)

#         # 4.2 Preventivo: antes de expandir_macros, arregla NUMERIC_CLEAN sobre no-texto
#         sql_query = _reescribir_numeric_clean_no_texto(
#             sql_query, esquema_json=esquema_json, dialecto=dialecto, tablas_solicitadas=payload.tables
#         )

#         # 4.3 Expandir macros (puede introducir TRIM/regex)
#         sql_query = database.expandir_macros(sql_query)

#         # 4.4 Reescribir TRIM(bigint) => TRIM(CAST(bigint AS TEXT/NVARCHAR))
#         sql_query = _sql_cast_trim_no_texto(
#             sql_query, esquema_json=esquema_json, dialecto=dialecto, tablas_solicitadas=payload.tables
#         )

#         # 5) Validación de seguridad
#         if not database.es_select_seguro(sql_query):
#             raise HTTPException(status_code=400, detail="SQL insegura (no es SELECT/CTE/EXPLAIN permitido).")

#         if not database.restringir_a_tablas_permitidas(sql_query, allowed_fqn):
#             if intencion_comparar and col_izq and col_der:
#                 # Fallback determinístico si se sale del schema
#                 sql_query = f"""
# SELECT
#   {f'"{col_clave}" AS "{col_clave}",' if col_clave else ''}
#   CAST("{col_izq}" AS numeric) AS "{col_izq}",
#   CAST("{col_der}" AS numeric) AS "{col_der}",
#   (CAST("{col_izq}" AS numeric) - CAST("{col_der}" AS numeric)) AS "Diferencia"
# FROM {tabla_fqn}
# WHERE "{col_izq}" IS NOT NULL AND "{col_der}" IS NOT NULL
#   AND CAST("{col_izq}" AS numeric) {op} CAST("{col_der}" AS numeric)
# ORDER BY "Diferencia" DESC
# LIMIT {int(limite_por_defecto)}
# """.strip()

#                 sql_query = database.limpiar_sql(sql_query)
#                 sql_query = database.sanear_explain(sql_query)
#                 sql_query = database.calificar_tablas(sql_query, allowed_fqn)
#                 if not database.restringir_a_tablas_permitidas(sql_query, allowed_fqn):
#                     raise HTTPException(status_code=400, detail="La consulta referencia tablas no permitidas según el esquema actual.")
#             else:
#                 raise HTTPException(status_code=400, detail="La consulta referencia tablas no permitidas según el esquema actual.")

#         # Dry-run
#         if not payload.execute:
#             return {"sql_query": sql_query, "original_query": result_dict.get("original_query")}

#         # 6) Ejecutar
#         filas_raw = await database.consultar(
#             sql_query,
#             permitidos_fqn=allowed_fqn,
#             limite_por_defecto=limite_por_defecto,
#             limite_maximo=limite_maximo,
#         )

#         # 6.2 Limpiar filas tipo TOTAL
#         filas_raw = _quitar_filas_tipo_total(filas_raw)

#         # 7) Normalizar
#         columnas_implicitas_env = [s.strip() for s in (env("IMPLIED_MILLIS_COLUMNS", default="") or "").split(",") if s.strip()]
#         columnas_implicitas = payload.implied_millis_cols if payload.implied_millis_cols is not None else columnas_implicitas_env

#         formatear_env = env("RETURN_FORMATTED_NUMBERS", default=True, cast=bool)
#         formatear = payload.format_numbers if payload.format_numbers is not None else formatear_env

#         decimales_env = env("DECIMAL_PLACES", default=3, cast=int)
#         decimales = payload.decimals if payload.decimals is not None else decimales_env

#         filas = normalizar_filas(
#             filas_raw,
#             columnas_miles_implicitos=columnas_implicitas,
#             decimales=decimales,
#             formatear_cadenas=formatear
#         )

#         # 8) Resumen opcional
#         if not payload.summarize:
#             return {"rows": filas, "row_count": len(filas), "sql_query": sql_query}

#         try:
#             respuesta = await llm.construir_respuesta(filas, payload.human_query, modelo=None)
#             if not (respuesta or "").strip():
#                 local_answer = _respuesta_resumen_local(filas, payload.human_query)
#                 return {
#                     "answer": local_answer,
#                     "answer_source": "local_fallback",
#                     "rows": filas[:50],
#                     "row_count": len(filas),
#                     "sql_query": sql_query,
#                     "warning": "Resumen generado localmente por falta de respuesta del LLM."
#                 }
#             return {
#                 "answer": respuesta,
#                 "answer_source": "llm",
#                 "rows": filas[:50],
#                 "row_count": len(filas),
#                 "sql_query": sql_query
#             }
#         except Exception as ex:
#             log.exception("Fallo al generar 'answer'.")
#             local_answer = _respuesta_resumen_local(filas, payload.human_query)
#             return {
#                 "answer": local_answer,
#                 "answer_source": "local_fallback",
#                 "rows": filas[:50],
#                 "row_count": len(filas),
#                 "sql_query": sql_query,
#                 "warning": f"LLM falló, se usó resumen local: {str(ex)[:160]}"
#             }

#     except HTTPException:
#         raise
#     except Exception as e:
#         log.exception("Error en /human_query")
#         raise HTTPException(status_code=500, detail=str(e))

# src/main.py
# -*- coding: utf-8 -*-
"""
Módulo: main
------------
Router principal de la API (FastAPI) para NL→SQL sobre Azure SQL (SQL Server).

Incluye:
- Endpoints base:
  - GET  /            -> raíz
  - GET  /health      -> health check
  - GET  /schema      -> introspección del esquema (cacheado)
  - POST /schema/refresh -> refresca caché de esquema
  - POST /human_query -> NL→SQL + ejecución opcional
  - POST /sql         -> ejecutar SQL directo (solo lectura)

- Endpoints LLM utilitarios (de la versión anterior):
  - GET  /llm/ping
  - GET  /llm/models

Seguridad:
- Solo consultas de lectura (SELECT/CTE, EXPLAIN si está permitido, VALUES si está permitido).
- Allow-list por tablas consultables según el esquema retornado.
- Guardia opcional por API key:
    Si configuras `API_KEY` en settings (vía config.py/.env),
    entonces valida el header `x-api-key`.
    Si NO configuras `API_KEY`, no exige nada.

Notas MSSQL:
- DB_DIALECT=mssql → se usa TOP en lugar de LIMIT desde database.py.
- No hay fallback determinístico tipo Postgres (evita errores de sintaxis).
"""

import json
import logging
import time
import unicodedata
from decimal import Decimal
from hashlib import sha1
from typing import Any, Dict, List, Optional, Tuple, Union

from decouple import config as env
from fastapi import APIRouter, Depends, Header, HTTPException, Query, Request
from fastapi.concurrency import run_in_threadpool
from pydantic import BaseModel, Field

from . import database
from . import llm

log = logging.getLogger(__name__)
logging.basicConfig(level=logging.DEBUG if env("DEBUG", default=False, cast=bool) else logging.INFO)

# =========================
#  Router
# =========================
router = APIRouter()

# =========================
#  Configuración (env)
# =========================
DB_DIALECT = (env("DB_DIALECT", default="postgresql") or "").strip().lower()

TARGET_SCHEMAS = [s.strip() for s in (env("TARGET_SCHEMAS", default="public") or "").split(",") if s.strip()]

MAX_ROWS_DEFAULT = env("MAX_ROWS_DEFAULT", default=100, cast=int)
MAX_ROWS_HARD = env("MAX_ROWS_HARD", default=1000, cast=int)

MAX_SCHEMA_TABLES = env("MAX_SCHEMA_TABLES", default=50, cast=int)
MAX_SCHEMA_COLUMNS = env("MAX_SCHEMA_COLUMNS", default=2000, cast=int)

DECIMAL_PLACES = env("DECIMAL_PLACES", default=3, cast=int)

# Cache (para schema)
SCHEMA_CACHE_TTL = env("SQL_CACHE_TTL_SECONDS", default=300, cast=int)
SCHEMA_CACHE_MAX = env("SQL_CACHE_MAX", default=256, cast=int)

# =========================
#  Helpers
# =========================

def es_mssql() -> bool:
    return DB_DIALECT.startswith("mssql")


def _normalizar_str(s: str) -> str:
    """Quita acentos y espacios extra, útil para inputs del usuario."""
    s = s or ""
    s = unicodedata.normalize("NFKD", s)
    s = "".join([c for c in s if not unicodedata.combining(c)])
    return s.strip()


def _a_jsonable(rows: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Convierte Decimals a float redondeado para JSON."""
    out: List[Dict[str, Any]] = []
    for r in rows or []:
        nr: Dict[str, Any] = {}
        for k, v in (r or {}).items():
            if isinstance(v, Decimal):
                nr[k] = float(round(v, DECIMAL_PLACES))
            else:
                nr[k] = v
        out.append(nr)
    return out


def _hash_payload(obj: Any) -> str:
    raw = json.dumps(obj, sort_keys=True, ensure_ascii=False).encode("utf-8")
    return sha1(raw).hexdigest()


def _parse_list_param(v: Optional[Union[List[str], str]]) -> Optional[List[str]]:
    """
    Soporta:
      - None
      - ["a","b"]
      - "a,b"
      - "a"
    """
    if v is None:
        return None
    if isinstance(v, list):
        out: List[str] = []
        for item in v:
            if item is None:
                continue
            out.extend([x.strip() for x in str(item).split(",") if x.strip()])
        return out or None
    s = str(v).strip()
    if not s:
        return None
    return [x.strip() for x in s.split(",") if x.strip()] or None


# =========================
#  Cache de /schema
# =========================
_SCHEMA_CACHE: Dict[str, Tuple[float, Any]] = {}


def _cache_get(key: str) -> Optional[Any]:
    rec = _SCHEMA_CACHE.get(key)
    if not rec:
        return None
    ts, val = rec
    if (time.time() - ts) > SCHEMA_CACHE_TTL:
        _SCHEMA_CACHE.pop(key, None)
        return None
    return val


def _cache_set(key: str, val: Any) -> None:
    if len(_SCHEMA_CACHE) >= SCHEMA_CACHE_MAX:
        oldest = min(_SCHEMA_CACHE.items(), key=lambda kv: kv[1][0])[0]
        _SCHEMA_CACHE.pop(oldest, None)
    _SCHEMA_CACHE[key] = (time.time(), val)


# =========================
#  Guardia opcional API Key
# =========================
async def guardia_api_key(
    request: Request,
    x_api_key: Optional[str] = Header(default=None, alias="x-api-key"),
) -> None:
    """
    Verifica API Key si la app tiene `API_KEY` configurada en settings.

    - Si NO hay API_KEY configurada: no hace nada (rutas abiertas).
    - Si hay API_KEY: exige header `x-api-key` igual al valor configurado.
    """
    settings = getattr(request.app.state, "settings", None)
    requerido = (getattr(settings, "API_KEY", "") if settings else "") or ""
    if not requerido:
        return
    if not x_api_key or x_api_key != requerido:
        raise HTTPException(status_code=401, detail="API key inválida")


# =========================
#  Modelos Pydantic
# =========================

class SchemaRequest(BaseModel):
    schemas: Optional[List[str]] = Field(default=None)
    tables: Optional[List[str]] = Field(default=None)


class HumanQueryRequest(BaseModel):
    human_query: str
    execute: bool = True
    schemas: Optional[List[str]] = None
    tables: Optional[List[str]] = None
    limit: Optional[int] = None
    dialect: Optional[str] = None
    schema_refresh: bool = False  # como en tu versión antigua (opcional)


class SQLQueryRequest(BaseModel):
    sql: str
    execute: bool = True
    limit: Optional[int] = None


# =============================================================================
# Endpoints base
# =============================================================================

@router.get("/")
def raiz() -> Dict[str, str]:
    return {"status": "ok", "docs": "/docs"}


@router.get("/health")
def health() -> Dict[str, Any]:
    return {"ok": True, "dialect": DB_DIALECT}


# =============================================================================
# Endpoints LLM (recuperados)
# =============================================================================

@router.get("/llm/ping", dependencies=[Depends(guardia_api_key)])
async def llm_ping() -> Dict[str, Any]:
    """
    Ping al proveedor LLM activo. Útil para validar conectividad y credenciales.
    """
    try:
        txt = await llm.ping()
        return {"status": "ok", "reply": (txt or "")[:200]}
    except Exception as e:
        log.exception("Error en /llm/ping")
        return {"status": "error", "detail": str(e)}


@router.get("/llm/models", dependencies=[Depends(guardia_api_key)])
def llm_modelos() -> Dict[str, Any]:
    """
    Devuelve modelos disponibles del proveedor activo.
    """
    try:
        return llm.listar_modelos()
    except Exception as e:
        log.exception("Error en /llm/models")
        return {"status": "error", "detail": str(e)}


# =============================================================================
# Esquema (cacheado)
# =============================================================================

@router.get("/schema", dependencies=[Depends(guardia_api_key)])
def schema_get(
    schemas: Optional[Union[List[str], str]] = Query(default=None),
    tables: Optional[Union[List[str], str]] = Query(default=None),
) -> Dict[str, Any]:
    sch_list = _parse_list_param(schemas) or TARGET_SCHEMAS
    tbl_list = _parse_list_param(tables) or None

    payload_key = _hash_payload({"schemas": sch_list, "tables": tbl_list})
    cached = _cache_get(payload_key)
    if cached:
        return cached

    data = database.obtener_esquema_json(
        esquemas=sch_list,
        tablas=tbl_list,
        max_tablas=MAX_SCHEMA_TABLES,
        max_columnas=MAX_SCHEMA_COLUMNS,
    )
    _cache_set(payload_key, data)
    return data


@router.post("/schema/refresh", dependencies=[Depends(guardia_api_key)])
def schema_refresh(req: SchemaRequest) -> Dict[str, Any]:
    """
    Refresca caché de esquema:
    - limpia cache interno de database
    - limpia cache local de este módulo
    """
    database.invalidar_cache_esquema()
    _SCHEMA_CACHE.clear()

    sch_list = req.schemas or TARGET_SCHEMAS
    tbl_list = req.tables or None

    data = database.obtener_esquema_json(
        esquemas=sch_list,
        tablas=tbl_list,
        max_tablas=MAX_SCHEMA_TABLES,
        max_columnas=MAX_SCHEMA_COLUMNS,
    )
    return {"ok": True, "schema": data}


# =============================================================================
# NL → SQL (principal)
# =============================================================================

@router.post("/human_query", dependencies=[Depends(guardia_api_key)])
async def human_query(payload: HumanQueryRequest) -> Dict[str, Any]:
    """
    Flujo principal NL→SQL.

    - schema_refresh=true fuerza refrescar esquema antes de generar SQL.
    - execute=false devuelve solo el SQL (dry-run).
    """
    human = _normalizar_str(payload.human_query)
    if not human:
        raise HTTPException(status_code=400, detail="human_query vacío.")

    if payload.schema_refresh:
        database.invalidar_cache_esquema()
        _SCHEMA_CACHE.clear()

    limite_por_defecto = int(payload.limit or MAX_ROWS_DEFAULT)
    limite_maximo = int(MAX_ROWS_HARD)

    esquemas = payload.schemas or TARGET_SCHEMAS
    tablas = payload.tables or None

    esquema_json = database.obtener_esquema_json(
        esquemas=esquemas,
        tablas=tablas,
        max_tablas=MAX_SCHEMA_TABLES,
        max_columnas=MAX_SCHEMA_COLUMNS,
    )
    allowed_fqn = [f"{t['schema']}.{t['table']}" for t in esquema_json.get("tables", [])]

    dialecto = payload.dialect or ("mssql" if es_mssql() else "postgresql")

    # 1) LLM → JSON string
    sql_json = await llm.consulta_humana_a_sql(
        consulta_humana=human,
        esquema_json=esquema_json,
        dialecto=dialecto,
        limite_por_defecto=limite_por_defecto,
        modelo=None,
    )

    try:
        obj = json.loads(sql_json)
    except Exception:
        obj = None

    if not isinstance(obj, dict) or "sql_query" not in obj:
        raise HTTPException(status_code=500, detail="El LLM no devolvió JSON válido con 'sql_query'.")

    sql_query = str(obj.get("sql_query") or "").strip()
    if not sql_query:
        raise HTTPException(status_code=500, detail="El LLM devolvió 'sql_query' vacío.")

    # 2) Guardrails (limpieza + seguridad)
    sql_query = database.limpiar_sql(sql_query)
    sql_query = database.sanear_explain(sql_query)
    sql_query = database.calificar_tablas(sql_query, allowed_fqn)
    sql_query = database.preferir_left_join_por_nullable(sql_query, esquema_json)

    if not database.es_select_seguro(sql_query):
        raise HTTPException(status_code=400, detail="SQL insegura (no es SELECT/CTE/EXPLAIN permitido).")

    if not database.restringir_a_tablas_permitidas(sql_query, allowed_fqn):
        # MSSQL: no fallback Postgres
        raise HTTPException(status_code=400, detail="La consulta referencia tablas no permitidas según el esquema actual.")

    # Dry run
    if not payload.execute:
        return {
            "ok": True,
            "human_query": human,
            "dialect": dialecto,
            "sql": sql_query,
            "executed": False,
        }

    # 3) Ejecutar en threadpool
    try:
        rows = await run_in_threadpool(
            database.consultar,
            sql_query,
            allowed_fqn,
            limite_por_defecto,
            limite_maximo,
        )
        rows = _a_jsonable(rows)
        return {
            "ok": True,
            "human_query": human,
            "dialect": dialecto,
            "sql": sql_query,
            "executed": True,
            "rows": rows,
            "row_count": len(rows),
        }
    except Exception as e:
        log.exception("Error ejecutando SQL en /human_query")
        raise HTTPException(status_code=500, detail=f"Error ejecutando SQL: {str(e)}")


# =============================================================================
# SQL directo
# =============================================================================

@router.post("/sql", dependencies=[Depends(guardia_api_key)])
async def sql_query(payload: SQLQueryRequest) -> Dict[str, Any]:
    """
    Ejecuta SQL directo con guardrails (solo lectura + allow-list).
    """
    sql = database.limpiar_sql(payload.sql)
    if not sql:
        raise HTTPException(status_code=400, detail="sql vacío.")

    limite_por_defecto = int(payload.limit or MAX_ROWS_DEFAULT)
    limite_maximo = int(MAX_ROWS_HARD)

    esquema_json = database.obtener_esquema_json(
        esquemas=TARGET_SCHEMAS,
        tablas=None,
        max_tablas=MAX_SCHEMA_TABLES,
        max_columnas=MAX_SCHEMA_COLUMNS,
    )
    allowed_fqn = [f"{t['schema']}.{t['table']}" for t in esquema_json.get("tables", [])]

    sql = database.sanear_explain(sql)
    sql = database.calificar_tablas(sql, allowed_fqn)

    if not database.es_select_seguro(sql):
        raise HTTPException(status_code=400, detail="SQL insegura (no es SELECT/CTE/EXPLAIN permitido).")

    if not database.restringir_a_tablas_permitidas(sql, allowed_fqn):
        raise HTTPException(status_code=400, detail="La consulta referencia tablas no permitidas según el esquema actual.")

    if not payload.execute:
        return {"ok": True, "sql": sql, "executed": False}

    try:
        rows = await run_in_threadpool(
            database.consultar,
            sql,
            allowed_fqn,
            limite_por_defecto,
            limite_maximo,
        )
        rows = _a_jsonable(rows)
        return {"ok": True, "sql": sql, "executed": True, "rows": rows, "row_count": len(rows)}
    except Exception as e:
        log.exception("Error ejecutando SQL en /sql")
        raise HTTPException(status_code=500, detail=f"Error ejecutando SQL: {str(e)}")