# # src/database.py
# # -*- coding: utf-8 -*-
# """
# Módulo: database
# ----------------
# Herramientas de acceso a base de datos (SQLAlchemy) y utilidades de seguridad
# y normalización para ejecutar consultas SQL generadas por LLM de forma segura.

# Cambios principales:
# - Nombres de funciones y variables internas en español.
# - Docstrings claros en español.
# - Comentarios clave y limpieza de ruido.
# - Se mantienen alias de compatibilidad con los nombres originales en inglés
#   (p. ej., `get_schema_json`, `clean_sql`, `expand_macros`, `query`, etc.)
#   para no romper otros módulos mientras migras todo el proyecto.

# Comportamiento y estructura se mantienen sin cambios.
# """

# from typing import Any, List, Dict, Optional, Tuple
# from decouple import config as env
# import re
# import logging

# from sqlalchemy import create_engine, inspect
# from sqlalchemy.orm import sessionmaker
# from sqlalchemy.pool import QueuePool
# from sqlalchemy.sql import text

# log = logging.getLogger(__name__)

# # --- Conexión / flags ---
# DATABASE_URL = (env("DATABASE_URL", default=None) or "").strip()
# if not DATABASE_URL:
#     raise RuntimeError("Falta la variable de entorno DATABASE_URL.")

# ALLOW_SQL_EXPLAIN: bool = env("ALLOW_SQL_EXPLAIN", default=True, cast=bool)
# ALLOW_EXPLAIN_ANALYZE: bool = env("ALLOW_EXPLAIN_ANALYZE", default=False, cast=bool)
# ALLOW_SQL_VALUES: bool = env("ALLOW_SQL_VALUES", default=True, cast=bool)
# ALLOW_SQL_CALL: bool = env("ALLOW_SQL_CALL", default=False, cast=bool)

# engine = create_engine(
#     DATABASE_URL,
#     connect_args={"sslmode": "require"},
#     poolclass=QueuePool,
#     pool_size=5,
#     max_overflow=10,
#     pool_pre_ping=True,
# )
# # Nota: mantenemos el nombre 'Session' por compatibilidad externa.
# Session = sessionmaker(bind=engine)

# # --- Esquema con caché ---
# _CACHE_ESQUEMA: Dict[Tuple[Tuple[str, ...], Tuple[str, ...]], Dict[str, Any]] = {}


# # ========================= Utilidades de esquema ==============================

# def _normalizar_secuencia(seq: Optional[List[str]]) -> Tuple[str, ...]:
#     """Normaliza una lista de cadenas: quita espacios, descarta vacíos y ordena para usarla como clave de caché."""
#     if not seq:
#         return tuple()
#     return tuple(sorted({s.strip() for s in seq if s and s.strip()}))


# def obtener_esquema_json(
#     esquemas: Optional[List[str]] = None,
#     tablas: Optional[List[str]] = None,
#     max_tablas: int = 50,
#     max_columnas: int = 2000,
# ) -> Dict[str, Any]:
#     """
#     Obtiene la descripción JSON del esquema (esquema(s)/tabla(s)/columnas) con caché.

#     Args:
#         esquemas: Lista de esquemas a incluir. Si None, se listan todos los esquemas visibles.
#         tablas: Lista de nombres de tablas a filtrar (opcional).
#         max_tablas: Límite máximo de tablas a incluir.
#         max_columnas: Límite máximo de columnas totales a incluir.

#     Returns:
#         Diccionario con clave "tables": lista de objetos {schema, table, fq_name, columns}.
#     """
#     key = (_normalizar_secuencia(esquemas), _normalizar_secuencia(tablas))
#     if key in _CACHE_ESQUEMA:
#         return _CACHE_ESQUEMA[key]

#     inspector = inspect(engine)
#     esquemas_elegidos = list(key[0]) if key[0] else inspector.get_schema_names()

#     tablas_salida: List[Dict[str, Any]] = []
#     total_columnas = 0

#     for sch in esquemas_elegidos:
#         nombres = inspector.get_table_names(schema=sch)
#         if key[1]:
#             nombres = [t for t in nombres if t in key[1]]
#         for t in nombres:
#             cols_meta = inspector.get_columns(t, schema=sch)
#             cols = []
#             for c in cols_meta:
#                 cols.append(
#                     {
#                         "name": c["name"],
#                         "type": str(c["type"]),
#                         "nullable": bool(c.get("nullable", True)),
#                     }
#                 )
#             tablas_salida.append(
#                 {
#                     "schema": sch,
#                     "table": t,
#                     "fq_name": f'{sch}."{t}"',
#                     "columns": cols,
#                 }
#             )
#             total_columnas += len(cols)
#             if len(tablas_salida) >= max_tablas or total_columnas >= max_columnas:
#                 break
#         if len(tablas_salida) >= max_tablas or total_columnas >= max_columnas:
#             break

#     resultado = {"tables": tablas_salida}
#     _CACHE_ESQUEMA[key] = resultado
#     return resultado


# def refrescar_cache_esquema() -> None:
#     """Limpia completamente la caché del esquema."""
#     _CACHE_ESQUEMA.clear()


# # ========================= Limpieza de SQL ====================================

# # Elimina fences ```sql ... ``` y ``` en general.
# _RE_BLOQUES_CODIGO = re.compile(
#     r"^\s*```(?:sql|postgresql)?\s*|\s*```\s*$", re.IGNORECASE | re.MULTILINE
# )


# def _quitar_bloques_codigo(s: str) -> str:
#     return _RE_BLOQUES_CODIGO.sub("", s or "")


# def _quitar_comentarios_sql(s: str) -> str:
#     """Quita comentarios -- línea y /* bloque */."""
#     s = re.sub(r"--.*?$", "", s, flags=re.MULTILINE)
#     s = re.sub(r"/\*.*?\*/", "", s, flags=re.DOTALL)
#     return s


# def limpiar_sql(sql: str) -> str:
#     """
#     Limpia y normaliza SQL de entrada:
#     - Quita fences markdown y comentarios.
#     - Quita prefijos 'sql:' o 'query:' si los hubiera.
#     - Quita ';' final.
#     """
#     s = sql or ""
#     s = _quitar_bloques_codigo(s)
#     s = _quitar_comentarios_sql(s)
#     s = s.strip()
#     s = re.sub(r"^(sql|query)\s*:\s*", "", s, flags=re.IGNORECASE).strip()
#     if s.endswith(";"):
#         s = s[:-1].strip()
#     log.debug("[database.limpiar_sql] IN: %r", sql)
#     log.debug("[database.limpiar_sql] OUT: %r", s)
#     return s


# # ========================= Macros (expansión) =================================

# _RE_NUMERIC_CLEAN = re.compile(
#     r"NUMERIC_CLEAN\(\s*([^)]+?)\s*\)", re.IGNORECASE | re.DOTALL
# )


# def expandir_numeric_clean(sql: str) -> str:
#     """
#     Expande la macro NUMERIC_CLEAN(expr) a SQL Postgres robusto que:
#     - Normaliza formatos US/EU, miles/decimales, y símbolos extraños.
#     - Devuelve numeric; usa 0 como fallback si queda cadena vacía.
#     """
#     def repl(m: re.Match) -> str:
#         expr = (m.group(1) or "").strip()
#         s = f"TRIM({expr})"
#         return f"""
#         (
#           COALESCE(
#             NULLIF(
#               CASE
#                 WHEN {s} IS NULL OR {s} = '' THEN NULL
#                 WHEN {s} ~ '^[0-9]{{1,3}}(,[0-9]{{3}})+(\\.[0-9]+)?$'
#                   THEN REPLACE({s}, ',', '')
#                 WHEN {s} ~ '^[0-9]{{1,3}}(\\.[0-9]{{3}})+(,[0-9]+)?$'
#                   THEN REPLACE(REPLACE({s}, '.', ''), ',', '.')
#                 WHEN {s} ~ '^[0-9]+,[0-9]+$'
#                   THEN REPLACE({s}, ',', '.')
#                 WHEN {s} ~ '^[0-9]+\\.[0-9]{{3}}$'
#                   THEN REPLACE({s}, '.', '')
#                 WHEN {s} ~ '^[0-9.]+$' AND LENGTH({s})-LENGTH(REPLACE({s},'.','')) > 1
#                   THEN REGEXP_REPLACE({s}, '\\.(?=.*\\.)', '', 'g')
#                 WHEN {s} ~ '[0-9],[0-9]' AND {s} ~ '[0-9]\\.[0-9]'
#                   THEN CASE
#                          WHEN {s} ~ ',\\d+\\s*$' THEN REPLACE(REPLACE({s}, '.', ''), ',', '.')
#                          ELSE REPLACE({s}, ',', '')
#                        END
#                 ELSE REGEXP_REPLACE(REPLACE({s}, ',', '.'), '[^0-9.]', '', 'g')
#               END,
#               ''
#             )::numeric,
#             0
#           )
#         )
#         """
#     return _RE_NUMERIC_CLEAN.sub(repl, sql or "")


# _RE_DATE_PARSE = re.compile(r"DATE_PARSE\(\s*([^)]+?)\s*\)", re.IGNORECASE | re.DOTALL)


# def expandir_date_parse(sql: str) -> str:
#     """
#     Expande la macro DATE_PARSE(expr) a un CASE que detecta patrones comunes y devuelve DATE.
#     Soporta: YYYY-MM-DD, DD/MM/YYYY, DD-MM-YYYY, DD.MM.YYYY (trimeando el texto).
#     """
#     def repl(m: re.Match) -> str:
#         expr = (m.group(1) or "").strip()
#         col = expr
#         return (
#             "("
#             "CASE "
#             f"WHEN TRIM({col}) ~ '^\\s*\\d{{4}}-\\d{{2}}-\\d{{2}}' "
#             f"THEN to_date(SUBSTRING(TRIM({col}) FROM '(\\d{{4}}-\\d{{2}}-\\d{{2}})'), 'YYYY-MM-DD') "
#             f"WHEN TRIM({col}) ~ '^\\s*\\d{{1,2}}/\\d{{1,2}}/\\d{{4}}' "
#             f"THEN to_date(SUBSTRING(TRIM({col}) FROM '(\\d{{1,2}}/\\d{{1,2}}/\\d{{4}})'), 'DD/MM/YYYY') "
#             f"WHEN TRIM({col}) ~ '^\\s*\\d{{1,2}}-\\d{{1,2}}-\\d{{4}}' "
#             f"THEN to_date(SUBSTRING(TRIM({col}) FROM '(\\d{{1,2}}-\\d{{1,2}}-\\d{{4}})'), 'DD-MM-YYYY') "
#             f"WHEN TRIM({col}) ~ '^\\s*\\d{{1,2}}\\.\\d{{1,2}}\\.\\d{{4}}' "
#             f"THEN to_date(SUBSTRING(TRIM({col}) FROM '(\\d{{1,2}}\\.\\d{{1,2}}\\.\\d{{4}})'), 'DD.MM.YYYY') "
#             "ELSE NULL "
#             "END"
#             ")"
#         )
#     return _RE_DATE_PARSE.sub(repl, sql or "")


# def expandir_macros(sql: str) -> str:
#     """Aplica expansiones de macros soportadas (NUMERIC_CLEAN, DATE_PARSE)."""
#     s = sql or ""
#     s2 = expandir_numeric_clean(s)
#     s3 = expandir_date_parse(s2)
#     if s3 != s:
#         log.debug("[database.expandir_macros] macros expandido.")
#     return s3


# # ========================= Clasificación / Seguridad ==========================

# _RE_EXPLAIN = re.compile(r"^\s*explain\b", re.IGNORECASE)
# _RE_EXPLAIN_ANALYZE = re.compile(r"^\s*explain\b.*\banalyze\b", re.IGNORECASE | re.DOTALL)
# _RE_VALUES = re.compile(r"^\s*values\s*\(", re.IGNORECASE)
# _RE_SELECT = re.compile(r"^\s*(WITH\b.+\bSELECT|SELECT)\b", re.IGNORECASE | re.DOTALL)


# def es_solo_values(sql: str) -> bool:
#     """Indica si el SQL es únicamente un bloque VALUES(...)."""
#     return bool(_RE_VALUES.match(sql or ""))


# def es_explain(sql: str) -> bool:
#     """Indica si el SQL inicia con EXPLAIN."""
#     return bool(_RE_EXPLAIN.match(sql or ""))


# def desenvolver_explain(sql: str) -> str:
#     """Quita el prefijo EXPLAIN y sus opciones para obtener la consulta interna."""
#     if not es_explain(sql):
#         return sql
#     s = sql.strip()
#     s = re.sub(r"^\s*explain\b(?:\s+\w+(?:\s+\w+)*)*\s*", "", s, flags=re.IGNORECASE)
#     return s.strip()


# _RE_OPCIONES_EXPLAIN = re.compile(r"^\s*explain\s*\((?P<opts>[^)]*)\)\s*", re.IGNORECASE | re.DOTALL)


# def _sanear_explain(sql: str, permitir_analyze: bool) -> str:
#     """Quita opciones/ANALYZE si no está permitido por configuración."""
#     s = sql or ""
#     if not es_explain(s):
#         return s
#     if permitir_analyze:
#         return s
#     m = _RE_OPCIONES_EXPLAIN.match(s)
#     if m:
#         return _RE_OPCIONES_EXPLAIN.sub("EXPLAIN ", s, count=1)
#     return re.sub(r"^\s*explain\s+analyze\b", "EXPLAIN", s, flags=re.IGNORECASE)


# def sanear_explain(sql: str) -> str:
#     """Sanitiza EXPLAIN según flags globales."""
#     return _sanear_explain(sql, permitir_analyze=ALLOW_EXPLAIN_ANALYZE)


# _RE_LITERAL_SIMPLE = re.compile(r"('([^']|'')*')", re.DOTALL)
# _RE_LITERAL_DOLAR = re.compile(r"(\$\$.*?\$\$)", re.DOTALL)


# def _enmascarar_literales_cadena(sql: str) -> str:
#     """
#     Reemplaza literales (simples y $$...$$) por placeholders
#     para evitar falsos positivos al detectar palabras prohibidas.
#     """
#     s = sql or ""
#     s = _RE_LITERAL_DOLAR.sub("$$''$$", s)
#     s = _RE_LITERAL_SIMPLE.sub("''", s)
#     return s


# _patrones_base_prohibidos = [
#     r"\bDROP\b", r"\bDELETE\b", r"\bTRUNCATE\b", r"\bALTER\b",
#     r"\bINSERT\b", r"\bUPDATE\b", r"\bCREATE\b", r"\bMERGE\b",
#     r"\bVACUUM\b", r"\bCOPY\b", r"\bGRANT\b", r"\bREVOKE\b",
# ]
# if not ALLOW_SQL_CALL:
#     _patrones_base_prohibidos.append(r"\bCALL\b")
# _PATRONES_PROHIBIDOS = [re.compile(pat, re.IGNORECASE) for pat in _patrones_base_prohibidos]


# def _contiene_prohibidos(sql: str) -> Optional[str]:
#     """Devuelve el patrón prohibido encontrado, o None si no hay coincidencias."""
#     s = _enmascarar_literales_cadena(sql or "")
#     for pat in _PATRONES_PROHIBIDOS:
#         if pat.search(s):
#             return pat.pattern
#     return None


# def es_select_seguro(sql: str) -> bool:
#     """
#     Verifica que el SQL sea solo-lectura permitido:
#     - VALUES (si está permitido).
#     - EXPLAIN (sin ANALYZE si no está permitido) sobre un SELECT/CTE.
#     - SELECT/CTE puro.
#     Y que no contenga palabras prohibidas.
#     """
#     s = sql or ""

#     if es_solo_values(s):
#         bad = _contiene_prohibidos(s)
#         return ALLOW_SQL_VALUES and (bad is None)

#     if es_explain(s):
#         if not ALLOW_SQL_EXPLAIN:
#             return False
#         if _RE_EXPLAIN_ANALYZE.match(s) and not ALLOW_EXPLAIN_ANALYZE:
#             return False
#         inner = desenvolver_explain(s)
#         bad = _contiene_prohibidos(inner)
#         return (_RE_SELECT.match(inner or "") is not None) and (bad is None)

#     if not _RE_SELECT.match(s or ""):
#         return False

#     bad = _contiene_prohibidos(s)
#     return bad is None


# def forzar_limit(sql: str, limite_por_defecto: int = 100, limite_maximo: int = 1000) -> str:
#     """Asegura un LIMIT por defecto y recorta LIMT excesivos al máximo permitido."""
#     m = re.search(r"\blimit\s+(\d+)\b", sql, re.IGNORECASE)
#     if m:
#         n = int(m.group(1))
#         if n > limite_maximo:
#             sql = re.sub(r"\blimit\s+\d+\b", f"LIMIT {limite_maximo}", sql, flags=re.IGNORECASE)
#         return sql
#     return f"{sql.rstrip()} LIMIT {limite_por_defecto}"


# # =========================
# # ✅ Filtro y calificación de tablas
# # =========================
# # Ignora "FROM" dentro de funciones como SUBSTRING(... FROM 'regex') y solo capta
# # cláusulas FROM/JOIN reales. Heurística: no debe iniciar con comilla simple.
# _RE_CLAUSULA_FROM_JOIN = re.compile(
#     r"""
#     (?<!\w)                 # no parte de otra palabra
#     \b(from|join)\b         # palabra clave
#     \s+                     # espacios
#     (?!')                   # evita FROM seguido de comilla simple (caso SUBSTRING ... FROM '...')
#     (?P<tbl>
#         (?:"[^"]+"|\w+)                     # "tabla" o tabla
#         (?:\s*\.\s*(?:"[^"]+"|\w+))?        # opcional schema.tabla
#     )
#     """,
#     re.IGNORECASE | re.VERBOSE,
# )

# _NO_ES_TABLA = {"lateral", "unnest", "generate_series", "values"}


# def _normalizar_token(s: str) -> str:
#     """Normaliza cadenas para comparaciones insensibles a espacios y mayúsculas."""
#     return re.sub(r"\s+", "", (s or "").strip().lower())


# def _construir_mapa_tablas(permitidos_fqn: List[str]) -> Dict[str, str]:
#     """
#     Construye un mapa de nombre_de_tabla -> FQN ('schema."tabla"') a partir de la allow-list.
#     """
#     m: Dict[str, str] = {}
#     for f in permitidos_fqn:
#         schema, _, table = f.partition(".")
#         table_name = table.replace('"', "").strip()
#         key = table_name.lower()
#         if key not in m:
#             m[key] = f'{schema.strip()}."{table_name}"'
#     return m


# _RE_DEFINICION_CTE = re.compile(r'(?P<name>"[^"]+"|\w+)\s+AS\s*\(', re.IGNORECASE)


# def _recopilar_nombres_cte(sql: str) -> List[str]:
#     """Recupera nombres de CTE definidos en un WITH ... AS (...)."""
#     names: List[str] = []
#     s = sql or ""
#     if not re.search(r"^\s*with\b", s, re.IGNORECASE):
#         return names
#     for m in _RE_DEFINICION_CTE.finditer(s):
#         nm = (m.group("name") or "").strip().strip('"').strip().lower()
#         if nm:
#             names.append(nm)
#     return names


# def _extraer_tablas_referenciadas(sql: str) -> List[str]:
#     """Extrae los tokens de tabla detectados en FROM/JOIN (posibles schema.tabla o tabla)."""
#     refs: List[str] = []
#     for m in _RE_CLAUSULA_FROM_JOIN.finditer(sql or ""):
#         tbl = (m.group("tbl") or "").strip()
#         if tbl:
#             refs.append(tbl)
#     return refs


# def _primera_ref_no_permitida(sql: str, permitidos_fqn: List[str]) -> Optional[str]:
#     """
#     Verifica referencias de tablas contra la allow-list. Devuelve el primer detalle no permitido o None.
#     Mejora mensajes para errores precisos.
#     """
#     if not sql or not permitidos_fqn:
#         return "sql/allowed vacío"

#     s = desenvolver_explain(sql) if es_explain(sql) else (sql or "")
#     allowed_set = {_normalizar_token(a) for a in permitidos_fqn if a and a.strip()}
#     mapa_tablas = _construir_mapa_tablas(permitidos_fqn)
#     nombres_cte = set(_recopilar_nombres_cte(s))

#     refs = _extraer_tablas_referenciadas(s)
#     if not refs:
#         return "no se detectaron FROM/JOIN"

#     for r in refs:
#         r_clean = (r or "").strip()
#         if not r_clean:
#             continue

#         head = _normalizar_token(r_clean.split("(")[0]).strip('"')
#         if head in _NO_ES_TABLA:
#             continue

#         # Caso sin schema explícito
#         if "." not in r_clean:
#             name = r_clean.strip().strip('"').lower()
#             if name in nombres_cte:
#                 continue

#             fqn_norm = mapa_tablas.get(name)
#             if not fqn_norm:
#                 return f"tabla no encontrada en allow-list: {r_clean}"
#             if _normalizar_token(fqn_norm) not in allowed_set:
#                 return f"tabla fuera de allow-list: {r_clean} -> {fqn_norm}"
#             continue

#         # Caso con schema.tabla
#         parts = [p.strip().strip('"') for p in r_clean.split(".")]
#         if len(parts) == 2:
#             schema_n, table_n = parts[0].lower(), parts[1]
#             fqn_norm = f'{schema_n}."{table_n}"'
#             if _normalizar_token(fqn_norm) not in allowed_set:
#                 return f"FQN fuera de allow-list: {r_clean} -> {fqn_norm}"
#         else:
#             return f"token schema.tabla inválido: {r_clean}"

#     return None


# def restringir_a_tablas_permitidas(sql: str, permitidos_fqn: List[str]) -> bool:
#     """True si todas las tablas referenciadas pertenecen a la allow-list."""
#     return _primera_ref_no_permitida(sql, permitidos_fqn) is None


# _RE_CALIFICAR_FROM_JOIN = re.compile(
#     r'\b(from|join)\s+("?[A-Za-z0-9_ ]+"?)(?!\s*\.)', re.IGNORECASE
# )


# def calificar_tablas(sql: str, permitidos_fqn: List[str]) -> str:
#     """
#     Califica automáticamente nombres de tabla sin schema usando la allow-list,
#     respetando CTEs y funciones (unnest, generate_series, etc.).
#     """
#     if not sql or not permitidos_fqn:
#         return sql
#     if es_solo_values(sql) or es_explain(sql):
#         return sql

#     nombres_cte = set(_recopilar_nombres_cte(sql))
#     mapa_tablas = _construir_mapa_tablas(permitidos_fqn)

#     def repl(match: re.Match) -> str:
#         kw = match.group(1)
#         raw_name = (match.group(2) or "").strip()
#         name_unquoted = raw_name.replace('"', "").strip()

#         if name_unquoted.lower() in nombres_cte:
#             return match.group(0)

#         head = _normalizar_token(name_unquoted.split("(")[0]).strip('"')
#         if head in _NO_ES_TABLA:
#             return match.group(0)

#         fqn = mapa_tablas.get(name_unquoted.lower())
#         if fqn:
#             return f"{kw} {fqn}"
#         return match.group(0)

#     return _RE_CALIFICAR_FROM_JOIN.sub(repl, sql)


# # ========================= Ejecución ==========================================

# async def consultar(
#     sql_query: str,
#     permitidos_fqn: List[str],
#     limite_por_defecto: int = 100,
#     limite_maximo: int = 1000,
# ) -> List[Dict[str, Any]]:
#     """
#     Ejecuta una consulta solo-lectura de forma segura:
#     - Limpia SQL, expande macros, sanitiza EXPLAIN, califica tablas.
#     - Verifica tipo y palabras prohibidas.
#     - Aplica LIMIT por defecto o recorte si excede máximo.
#     - Devuelve filas como lista de dicts.
#     """
#     log.debug("[database.consultar] raw=%r", sql_query)

#     sql_query = limpiar_sql(sql_query)
#     log.debug("[database.consultar] after clean=%r", sql_query)

#     sql_query = expandir_macros(sql_query)

#     sql_query = sanear_explain(sql_query)
#     log.debug("[database.consultar] after explain sanitize=%r", sql_query)

#     sql_query = calificar_tablas(sql_query, permitidos_fqn)
#     log.debug("[database.consultar] after qualify=%r", sql_query)

#     if not es_select_seguro(sql_query):
#         raise ValueError("Solo se permiten consultas de lectura (SELECT/CTE, EXPLAIN sin ANALYZE, VALUES).")

#     val_sql = desenvolver_explain(sql_query) if es_explain(sql_query) else sql_query

#     bad = _primera_ref_no_permitida(val_sql, permitidos_fqn)
#     if (not es_solo_values(sql_query)) and bad:
#         # Error con detalle preciso del token que rompe la allow-list
#         raise ValueError(f"La consulta referencia tablas no permitidas según el esquema actual. Detalle: {bad}")

#     if (not es_solo_values(sql_query)) and (not es_explain(sql_query)):
#         sql_final = forzar_limit(val_sql, limite_por_defecto=limite_por_defecto, limite_maximo=limite_maximo)
#     else:
#         sql_final = sql_query

#     log.debug("[database.consultar] final SQL=%r", sql_final)

#     with Session() as session:
#         statement = text(sql_final)
#         result = session.execute(statement)
#         return [dict(row._mapping) for row in result]


# def limpiar_recursos() -> None:
#     """Libera conexiones del pool."""
#     engine.dispose()

# src/database.py
# -*- coding: utf-8 -*-
"""
Módulo: database
----------------
Capa de acceso a BD + guardrails de seguridad para ejecutar consultas SQL generadas por LLM.

Objetivo:
- Introspección de esquema (para alimentar al LLM).
- Limpieza/normalización de SQL.
- Validación de seguridad (solo lectura).
- Allow-list de tablas referenciadas (FROM/JOIN).
- Aplicación de límite por defecto:
  - Postgres: LIMIT
  - SQL Server (Azure SQL): TOP(N)

Notas:
- En MSSQL se desactivan macros Postgres (NUMERIC_CLEAN/DATE_PARSE) para evitar sintaxis inválida.
- `consultar()` es síncrona y devuelve list[dict].
"""

from typing import Any, Dict, List, Optional, Tuple
import logging
import re

from decouple import config as env
from sqlalchemy import create_engine, inspect
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import QueuePool
from sqlalchemy.sql import text

log = logging.getLogger(__name__)

# ----------------------------- Configuración base -----------------------------

DATABASE_URL = (env("DATABASE_URL", default=None) or "").strip()
if not DATABASE_URL:
    raise RuntimeError("Falta la variable de entorno DATABASE_URL.")

DB_DIALECT = (env("DB_DIALECT", default="postgresql") or "").strip().lower()


def es_mssql() -> bool:
    """True si el dialecto/URL indica SQL Server (Azure SQL)."""
    return DB_DIALECT.startswith("mssql") or DATABASE_URL.lower().startswith("mssql")


ALLOW_SQL_EXPLAIN: bool = env("ALLOW_SQL_EXPLAIN", default=True, cast=bool)
ALLOW_EXPLAIN_ANALYZE: bool = env("ALLOW_EXPLAIN_ANALYZE", default=False, cast=bool)
ALLOW_SQL_VALUES: bool = env("ALLOW_SQL_VALUES", default=True, cast=bool)
ALLOW_SQL_CALL: bool = env("ALLOW_SQL_CALL", default=False, cast=bool)

_engine_kwargs = dict(
    poolclass=QueuePool,
    pool_size=5,
    max_overflow=10,
    pool_pre_ping=True,
)

# SQLAlchemy engine
if es_mssql():
    engine = create_engine(DATABASE_URL, **_engine_kwargs)
else:
    engine = create_engine(DATABASE_URL, connect_args={"sslmode": "require"}, **_engine_kwargs)

Session = sessionmaker(bind=engine)

# ----------------------------- Caché de esquema ------------------------------

_CACHE_ESQUEMA: Dict[Tuple[Tuple[str, ...], Tuple[str, ...]], Dict[str, Any]] = {}


def _norm_lista(seq: Optional[List[str]]) -> Tuple[str, ...]:
    """Normaliza lista (strip, sin vacíos, ordenada) para clave de caché."""
    if not seq:
        return tuple()
    return tuple(sorted({s.strip() for s in seq if s and s.strip()}))


def obtener_esquema_json(
    esquemas: Optional[List[str]] = None,
    tablas: Optional[List[str]] = None,
    max_tablas: int = 50,
    max_columnas: int = 2000,
) -> Dict[str, Any]:
    """
    Devuelve esquema en JSON para alimentar al LLM.
    Estructura:
      {"tables":[{"schema":..,"table":..,"fq_name":..,"columns":[...]}]}

    fq_name:
      - MSSQL: [schema].[table]
      - Postgres: schema."table"
    """
    key = (_norm_lista(esquemas), _norm_lista(tablas))
    if key in _CACHE_ESQUEMA:
        return _CACHE_ESQUEMA[key]

    inspector = inspect(engine)
    esquemas_elegidos = list(key[0]) if key[0] else inspector.get_schema_names()

    tablas_salida: List[Dict[str, Any]] = []
    total_cols = 0

    for sch in esquemas_elegidos:
        nombres = inspector.get_table_names(schema=sch)
        if key[1]:
            nombres = [t for t in nombres if t in key[1]]

        for t in nombres:
            cols_meta = inspector.get_columns(t, schema=sch)
            cols = [
                {"name": c["name"], "type": str(c["type"]), "nullable": bool(c.get("nullable", True))}
                for c in cols_meta
            ]

            tablas_salida.append(
                {
                    "schema": sch,
                    "table": t,
                    "fq_name": (f"[{sch}].[{t}]" if es_mssql() else f'{sch}."{t}"'),
                    "columns": cols,
                }
            )

            total_cols += len(cols)
            if len(tablas_salida) >= max_tablas or total_cols >= max_columnas:
                break

        if len(tablas_salida) >= max_tablas or total_cols >= max_columnas:
            break

    out = {"tables": tablas_salida}
    _CACHE_ESQUEMA[key] = out
    return out


def invalidar_cache_esquema() -> None:
    """Limpia caché de esquema."""
    _CACHE_ESQUEMA.clear()


# Alias legacy (por si tu código antiguo los usa)
get_schema_json = obtener_esquema_json
invalidate_schema_cache = invalidar_cache_esquema

# ----------------------------- Limpieza SQL ----------------------------------

_RE_COMENTARIOS = re.compile(r"(--.*?$)|(/\*.*?\*/)", re.MULTILINE | re.DOTALL)
_RE_ESPACIOS = re.compile(r"\s+")


def limpiar_sql(sql: str) -> str:
    """Elimina comentarios y normaliza espacios (sin cambiar semántica)."""
    s = (sql or "")
    s = _RE_COMENTARIOS.sub(" ", s)
    s = s.strip().strip(";")
    s = _RE_ESPACIOS.sub(" ", s)
    return s


clean_sql = limpiar_sql  # alias legacy

# ----------------------------- Macros (Postgres) -----------------------------

_RE_NUMERIC_CLEAN = re.compile(r"\bNUMERIC_CLEAN\(([^)]+)\)", re.IGNORECASE)
_RE_DATE_PARSE = re.compile(r"\bDATE_PARSE\(([^)]+)\)", re.IGNORECASE)


def expandir_numeric_clean(sql: str) -> str:
    """Macro Postgres NUMERIC_CLEAN(x). En MSSQL se desactiva vía expandir_macros()."""
    def repl(m: re.Match) -> str:
        col = m.group(1).strip()
        return (
            "("
            f"NULLIF(REGEXP_REPLACE(REPLACE(REPLACE(TRIM({col}), '.', ''), ',', '.'), '[^0-9\\.-]', '', 'g'), '')::numeric"
            ")"
        )
    return _RE_NUMERIC_CLEAN.sub(repl, sql or "")


def expandir_date_parse(sql: str) -> str:
    """Macro Postgres DATE_PARSE(x). En MSSQL se desactiva vía expandir_macros()."""
    def repl(m: re.Match) -> str:
        col = m.group(1).strip()
        return (
            "("
            "CASE "
            f"WHEN TRIM({col}) ~ '^\\d{{4}}-\\d{{1,2}}-\\d{{1,2}}' THEN to_date(SUBSTRING(TRIM({col}) FROM '(\\d{{4}}-\\d{{1,2}}-\\d{{1,2}})'), 'YYYY-MM-DD') "
            f"WHEN TRIM({col}) ~ '^\\d{{1,2}}/\\d{{1,2}}/\\d{{4}}' THEN to_date(SUBSTRING(TRIM({col}) FROM '(\\d{{1,2}}/\\d{{1,2}}/\\d{{4}})'), 'DD/MM/YYYY') "
            f"WHEN TRIM({col}) ~ '^\\d{{1,2}}\\.\\d{{1,2}}\\.\\d{{4}}' THEN to_date(SUBSTRING(TRIM({col}) FROM '(\\d{{1,2}}\\.\\d{{1,2}}\\.\\d{{4}})'), 'DD.MM.YYYY') "
            "ELSE NULL "
            "END"
            ")"
        )
    return _RE_DATE_PARSE.sub(repl, sql or "")


def expandir_macros(sql: str) -> str:
    """
    Expande macros si aplica.

    Importante:
    - En SQL Server se desactiva porque las macros están escritas en sintaxis Postgres.
    """
    if es_mssql():
        return sql or ""
    s = sql or ""
    s2 = expandir_numeric_clean(s)
    s3 = expandir_date_parse(s2)
    if s3 != s:
        log.debug("[database.expandir_macros] macros expandido.")
    return s3


expand_macros = expandir_macros  # alias legacy

# ----------------------------- Seguridad -------------------------------------

_RE_EXPLAIN = re.compile(r"^\s*explain\b", re.IGNORECASE)
_RE_EXPLAIN_ANALYZE = re.compile(r"^\s*explain\b.*\banalyze\b", re.IGNORECASE | re.DOTALL)
_RE_VALUES = re.compile(r"^\s*values\s*\(", re.IGNORECASE)
_RE_SELECT = re.compile(r"^\s*(WITH\b.+\bSELECT|SELECT)\b", re.IGNORECASE | re.DOTALL)


def es_explain(sql: str) -> bool:
    return _RE_EXPLAIN.match(sql or "") is not None


def es_explain_analyze(sql: str) -> bool:
    return _RE_EXPLAIN_ANALYZE.match(sql or "") is not None


def es_solo_values(sql: str) -> bool:
    return _RE_VALUES.match(sql or "") is not None


def _token_prohibido(sql: str) -> Optional[str]:
    s = (sql or "").lower()
    prohibidos = [
        "insert", "update", "delete", "drop", "alter", "create", "truncate",
        "grant", "revoke", "commit", "rollback", "call", "execute", "exec",
    ]
    for p in prohibidos:
        if re.search(rf"\b{re.escape(p)}\b", s):
            return p
    return None


def sanear_explain(sql: str) -> str:
    """Valida flags para EXPLAIN/ANALYZE."""
    s = (sql or "").strip()
    if not es_explain(s):
        return s

    if not ALLOW_SQL_EXPLAIN:
        raise ValueError("EXPLAIN está deshabilitado por configuración.")

    if es_explain_analyze(s) and not ALLOW_EXPLAIN_ANALYZE:
        raise ValueError("EXPLAIN ANALYZE está deshabilitado por configuración.")

    return s


def desenvolver_explain(sql: str) -> str:
    """Quita EXPLAIN para evaluar allowlist."""
    s = (sql or "").strip()
    if not es_explain(s):
        return s
    return re.sub(r"^\s*explain\b", "", s, flags=re.IGNORECASE).strip()


def es_select_seguro(sql: str) -> bool:
    """
    Acepta:
    - SELECT / WITH...SELECT
    - VALUES(...) si está permitido
    - EXPLAIN(...) (sin ANALYZE si no está permitido)
    Rechaza cualquier verbo DDL/DML.
    """
    s = (sql or "").strip()
    if not s:
        return False

    if es_explain(s):
        if not ALLOW_SQL_EXPLAIN:
            return False
        if es_explain_analyze(s) and not ALLOW_EXPLAIN_ANALYZE:
            return False
        inner = desenvolver_explain(s)
        return (_RE_SELECT.match(inner or "") is not None) and (_token_prohibido(inner) is None)

    if es_solo_values(s):
        return bool(ALLOW_SQL_VALUES) and (_token_prohibido(s) is None)

    if not _RE_SELECT.match(s):
        return False

    return _token_prohibido(s) is None


# ----------------------------- Límite por defecto ----------------------------

def _forzar_top_mssql(sql: str, n: int) -> str:
    """Inserta TOP(n) (o recorta) en SQL Server."""
    s = (sql or "").strip()

    m_top = re.search(r"^\s*select\s+(distinct\s+)?top\s*\(?\s*(\d+)\s*\)?\s+", s, re.IGNORECASE)
    if m_top:
        actual = int(m_top.group(2))
        if actual > n:
            s = re.sub(
                r"^\s*select\s+(distinct\s+)?top\s*\(?\s*\d+\s*\)?\s+",
                lambda mm: ("SELECT " + (mm.group(1) or "") + f"TOP ({n}) "),
                s,
                flags=re.IGNORECASE,
            )
        return s

    if re.match(r"^\s*with\b", s, re.IGNORECASE):
        def _ins(match: re.Match) -> str:
            return f"{match.group(0)}TOP ({n}) "

        s2, cnt = re.subn(r"\bselect\s+distinct\s+", _ins, s, count=1, flags=re.IGNORECASE)
        if cnt == 0:
            s2, _ = re.subn(r"\bselect\s+", _ins, s, count=1, flags=re.IGNORECASE)
        return s2

    s2, cnt = re.subn(r"^\s*select\s+distinct\s+", f"SELECT DISTINCT TOP ({n}) ", s, count=1, flags=re.IGNORECASE)
    if cnt == 0:
        s2, _ = re.subn(r"^\s*select\s+", f"SELECT TOP ({n}) ", s, count=1, flags=re.IGNORECASE)
    return s2


def forzar_limit(sql: str, limite_por_defecto: int = 100, limite_maximo: int = 1000) -> str:
    """Aplica límite por defecto según dialecto."""
    if es_mssql():
        n = min(max(int(limite_por_defecto), 1), int(limite_maximo))
        return _forzar_top_mssql(sql, n)

    m = re.search(r"\blimit\s+(\d+)\b", sql, re.IGNORECASE)
    if m:
        n = int(m.group(1))
        if n > limite_maximo:
            sql = re.sub(r"\blimit\s+\d+\b", f"LIMIT {limite_maximo}", sql, flags=re.IGNORECASE)
        return sql

    return f"{sql.rstrip()} LIMIT {limite_por_defecto}"


# ----------------------------- Allow-list de tablas ---------------------------

_RE_FROM_JOIN = re.compile(
    r"""
    (?<!\w)
    (?:from|join)\s+
    (?!')                           # evita SUBSTRING(... FROM '...')
    (?P<tabla>
        (?:\[[^\]]+\]|\w+)          # [dbo] o dbo
        (?:\.(?:\[[^\]]+\]|\w+))?   # .[Table] o .Table
        (?:\.(?:\[[^\]]+\]|\w+))?   # opcional (db.schema.table)
        (?:\s+(?:as\s+)?\w+)?       # alias opcional
    )
    """,
    re.IGNORECASE | re.VERBOSE,
)


def _normalizar_ref(raw: str) -> str:
    """Convierte [dbo].[X] / dbo.X / dbo."X" -> dbo.x (sin alias)."""
    s = (raw or "").strip()
    s = re.sub(r"\s+(?:as\s+)?\w+$", "", s, flags=re.IGNORECASE).strip()
    s = s.replace('"', "")
    s = s.replace("[", "").replace("]", "")
    s = re.sub(r"\s+", "", s)
    parts = s.split(".")
    if len(parts) >= 2:
        return f"{parts[-2]}.{parts[-1]}".lower()
    return s.lower()


def _primera_no_permitida(sql: str, permitidos_fqn: List[str]) -> Optional[str]:
    permitidos = {p.lower() for p in (permitidos_fqn or [])}
    for m in _RE_FROM_JOIN.finditer(sql or ""):
        raw = m.group("tabla")
        ref = _normalizar_ref(raw)
        if ref and ref not in permitidos:
            return f"No permitido: {ref} (raw={raw})"
    return None


def restringir_a_tablas_permitidas(sql: str, permitidos_fqn: List[str]) -> bool:
    s = limpiar_sql(sql)
    inner = desenvolver_explain(s) if es_explain(s) else s
    return _primera_no_permitida(inner, permitidos_fqn) is None


def calificar_tablas(sql: str, permitidos_fqn: List[str]) -> str:
    """
    Si el SQL usa FROM TablaSinSchema, intenta anteponer schema según allow-list.
    - MSSQL: FROM [schema].[Tabla]
    - Postgres: FROM schema."Tabla"
    """
    if not permitidos_fqn:
        return sql

    s = sql or ""
    permitidos = [p.lower() for p in permitidos_fqn]
    esquemas = sorted({p.split(".")[0] for p in permitidos if "." in p})

    def repl(m: re.Match) -> str:
        kw = m.group(1)
        tabla = m.group(2)
        raw = m.group(0)

        if "." in tabla or "[" in tabla or '"' in tabla:
            return raw

        for sch in esquemas:
            cand = f"{sch}.{tabla}".lower()
            if cand in permitidos:
                return f"{kw} [{sch}].[{tabla}]" if es_mssql() else f'{kw} {sch}."{tabla}"'
        return raw

    return re.sub(r"\b(from|join)\s+([A-Za-z_]\w*)\b", repl, s, flags=re.IGNORECASE)


qualify_tables = calificar_tablas  # alias legacy


# ----------------------------- Ejecución -------------------------------------

def consultar(
    sql_query: str,
    permitidos_fqn: List[str],
    limite_por_defecto: int = 100,
    limite_maximo: int = 1000,
) -> List[Dict[str, Any]]:
    """
    Ejecuta SQL (solo lectura) aplicando:
    - limpieza
    - macros (solo Postgres)
    - saneo explain
    - calificación de tablas
    - allow-list
    - límite por defecto

    Returns:
        Lista de filas como dict.
    """
    log.debug("[database.consultar] raw=%r", sql_query)

    sql_query = limpiar_sql(sql_query)
    sql_query = expandir_macros(sql_query)
    sql_query = sanear_explain(sql_query)
    sql_query = calificar_tablas(sql_query, permitidos_fqn)

    if not es_select_seguro(sql_query):
        raise ValueError("Solo se permiten consultas de lectura (SELECT/CTE, EXPLAIN permitido, VALUES).")

    val_sql = desenvolver_explain(sql_query) if es_explain(sql_query) else sql_query

    bad = _primera_no_permitida(val_sql, permitidos_fqn)
    if (not es_solo_values(sql_query)) and bad:
        raise ValueError(f"La consulta referencia tablas no permitidas. Detalle: {bad}")

    if (not es_solo_values(sql_query)) and (not es_explain(sql_query)):
        sql_final = forzar_limit(val_sql, limite_por_defecto=limite_por_defecto, limite_maximo=limite_maximo)
    else:
        sql_final = sql_query

    log.debug("[database.consultar] final=%r", sql_final)

    with Session() as session:
        result = session.execute(text(sql_final))
        rows = result.mappings().all()
        return [dict(r) for r in rows]


query = consultar  # alias legacy