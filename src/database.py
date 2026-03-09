# # src/database.py
# # -*- coding: utf-8 -*-
# """
# Módulo: database
# ----------------
# Herramientas de acceso a BD (SQLAlchemy) + guardrails para ejecutar consultas SQL
# generadas por un LLM de forma segura.

# Objetivos:
# - Introspección de esquema (para alimentar al LLM).
# - Limpieza/normalización robusta de SQL (incluye fences markdown).
# - Validación de seguridad: solo lectura (SELECT/CTE), EXPLAIN opcional, VALUES opcional.
# - Allow-list de tablas: la consulta solo puede tocar tablas presentes en el esquema permitido.
# - Calificación automática: si el LLM escribe FROM Tabla, se intenta convertir a schema.Tabla permitido.
# - Límite por defecto:
#   - Postgres: LIMIT
#   - SQL Server (Azure SQL): TOP(N)

# Compatibilidad:
# - Se mantienen alias antiguos en inglés: get_schema_json, clean_sql, expand_macros, query, etc.
# - Se mantiene Session y engine como antes.
# """

# from __future__ import annotations

# from typing import Any, Dict, List, Optional, Tuple, Set
# import logging
# import re
# import warnings

# from sqlalchemy.exc import SAWarning
# from decouple import config as env
# from sqlalchemy import create_engine, inspect
# from sqlalchemy.orm import sessionmaker
# from sqlalchemy.pool import QueuePool
# from sqlalchemy.sql import text

# log = logging.getLogger(__name__)

# warnings.filterwarnings(
#     "ignore",
#     message=r".*Did not recognize type 'sysname'.*",
#     category=SAWarning,
# )

# # =============================================================================
# # Configuración / Engine
# # =============================================================================

# DATABASE_URL = (env("DATABASE_URL", default=None) or "").strip()
# if not DATABASE_URL:
#     raise RuntimeError("Falta la variable de entorno DATABASE_URL.")

# DB_DIALECT = (env("DB_DIALECT", default="postgresql") or "").strip().lower()


# def es_mssql() -> bool:
#     """True si el dialecto/URL indica SQL Server (Azure SQL)."""
#     return DB_DIALECT.startswith("mssql") or DATABASE_URL.lower().startswith("mssql")


# ALLOW_SQL_EXPLAIN: bool = env("ALLOW_SQL_EXPLAIN", default=True, cast=bool)
# ALLOW_EXPLAIN_ANALYZE: bool = env("ALLOW_EXPLAIN_ANALYZE", default=False, cast=bool)
# ALLOW_SQL_VALUES: bool = env("ALLOW_SQL_VALUES", default=True, cast=bool)
# ALLOW_SQL_CALL: bool = env("ALLOW_SQL_CALL", default=False, cast=bool)

# _engine_kwargs = dict(
#     poolclass=QueuePool,
#     pool_size=5,
#     max_overflow=10,
#     pool_pre_ping=True,
# )

# # SQLAlchemy engine: Postgres usa sslmode, MSSQL no.
# if es_mssql():
#     engine = create_engine(DATABASE_URL, **_engine_kwargs)
# else:
#     engine = create_engine(DATABASE_URL, connect_args={"sslmode": "require"}, **_engine_kwargs)

# Session = sessionmaker(bind=engine)

# # =============================================================================
# # Esquema con caché
# # =============================================================================

# _CACHE_ESQUEMA: Dict[Tuple[Tuple[str, ...], Tuple[str, ...]], Dict[str, Any]] = {}


# def _normalizar_secuencia(seq: Optional[List[str]]) -> Tuple[str, ...]:
#     """Normaliza lista (strip, sin vacíos, ordenada) para clave de caché."""
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
#     Obtiene descripción JSON del esquema con caché.
#     Devuelve: {"tables":[{"schema","table","fq_name","columns":[...]}]}

#     fq_name:
#       - MSSQL: [schema].[table]
#       - Postgres: schema."table"
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
#                 tipo = str(c.get("type", ""))

#                 # Normalización MSSQL: sysname ≈ NVARCHAR(128)
#                 if tipo.lower() == "sysname":
#                     tipo = "NVARCHAR(128)"

#                 cols.append(
#                     {
#                         "name": c.get("name"),
#                         "type": tipo,
#                         "nullable": bool(c.get("nullable", True)),
#                     }
#                 )

#             fq_name = f"[{sch}].[{t}]" if es_mssql() else f'{sch}."{t}"'

#             tablas_salida.append(
#                 {"schema": sch, "table": t, "fq_name": fq_name, "columns": cols}
#             )

#             total_columnas += len(cols)
#             if len(tablas_salida) >= max_tablas or total_columnas >= max_columnas:
#                 break

#         if len(tablas_salida) >= max_tablas or total_columnas >= max_columnas:
#             break

#     resultado = {"tables": tablas_salida}
#     _CACHE_ESQUEMA[key] = resultado
#     return resultado


# def invalidar_cache_esquema() -> None:
#     """Limpia completamente la caché del esquema."""
#     _CACHE_ESQUEMA.clear()


# # Alias legacy
# get_schema_json = obtener_esquema_json
# invalidate_schema_cache = invalidar_cache_esquema
# refrescar_cache_esquema = invalidar_cache_esquema  # compat con tu versión vieja

# # =============================================================================
# # Limpieza de SQL (robusta)
# # =============================================================================

# _RE_BLOQUES_CODIGO = re.compile(
#     r"^\s*```(?:sql|postgresql|tsql|mssql)?\s*|\s*```\s*$",
#     re.IGNORECASE | re.MULTILINE,
# )


# def _quitar_bloques_codigo(s: str) -> str:
#     """Quita fences markdown ```sql ... ```."""
#     return _RE_BLOQUES_CODIGO.sub("", s or "")


# def _quitar_comentarios_sql(s: str) -> str:
#     """Quita comentarios -- línea y /* bloque */."""
#     s = re.sub(r"--.*?$", "", s, flags=re.MULTILINE)
#     s = re.sub(r"/\*.*?\*/", "", s, flags=re.DOTALL)
#     return s


# _RE_ESPACIOS = re.compile(r"\s+")


# def limpiar_sql(sql: str) -> str:
#     """
#     Limpia SQL de entrada:
#     - Quita fences markdown y comentarios.
#     - Quita prefijos 'sql:' o 'query:'.
#     - Quita ';' final.
#     - Colapsa espacios.
#     """
#     s = sql or ""
#     s = _quitar_bloques_codigo(s)
#     s = _quitar_comentarios_sql(s)
#     s = s.strip()
#     s = re.sub(r"^(sql|query)\s*:\s*", "", s, flags=re.IGNORECASE).strip()
#     if s.endswith(";"):
#         s = s[:-1].strip()
#     s = _RE_ESPACIOS.sub(" ", s)
#     log.debug("[database.limpiar_sql] IN=%r OUT=%r", (sql or "")[:300], s[:300])
#     return s


# # Alias legacy
# clean_sql = limpiar_sql

# # =============================================================================
# # Macros (NUMERIC_CLEAN, DATE_PARSE)
# # - En Postgres: se expanden
# # - En MSSQL: se desactivan
# # =============================================================================

# _RE_NUMERIC_CLEAN = re.compile(r"NUMERIC_CLEAN\(\s*([^)]+?)\s*\)", re.IGNORECASE | re.DOTALL)
# _RE_DATE_PARSE = re.compile(r"DATE_PARSE\(\s*([^)]+?)\s*\)", re.IGNORECASE | re.DOTALL)


# def expandir_numeric_clean(sql: str) -> str:
#     """Expande NUMERIC_CLEAN(expr) a SQL Postgres robusto (solo Postgres)."""
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


# def expandir_date_parse(sql: str) -> str:
#     """Expande DATE_PARSE(expr) a un CASE en Postgres (solo Postgres)."""
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
#     """Expande macros soportadas (solo Postgres). En MSSQL se desactiva."""
#     if es_mssql():
#         return sql or ""
#     s = sql or ""
#     s2 = expandir_numeric_clean(s)
#     s3 = expandir_date_parse(s2)
#     if s3 != s:
#         log.debug("[database.expandir_macros] macros expandido.")
#     return s3


# # Alias legacy
# expand_macros = expandir_macros

# # =============================================================================
# # Seguridad / Clasificación
# # =============================================================================

# _RE_EXPLAIN = re.compile(r"^\s*explain\b", re.IGNORECASE)
# _RE_EXPLAIN_ANALYZE = re.compile(r"^\s*explain\b.*\banalyze\b", re.IGNORECASE | re.DOTALL)
# _RE_VALUES = re.compile(r"^\s*values\s*\(", re.IGNORECASE)
# _RE_SELECT = re.compile(r"^\s*(WITH\b.+\bSELECT|SELECT)\b", re.IGNORECASE | re.DOTALL)

# _RE_LITERAL_SIMPLE = re.compile(r"('([^']|'')*')", re.DOTALL)
# _RE_LITERAL_DOLAR = re.compile(r"(\$\$.*?\$\$)", re.DOTALL)


# def es_solo_values(sql: str) -> bool:
#     """Indica si el SQL es únicamente un bloque VALUES(...)."""
#     return bool(_RE_VALUES.match(sql or ""))


# def es_explain(sql: str) -> bool:
#     """Indica si el SQL inicia con EXPLAIN."""
#     return bool(_RE_EXPLAIN.match(sql or ""))


# def desenvolver_explain(sql: str) -> str:
#     """Quita el prefijo EXPLAIN para evaluar allow-list."""
#     s = (sql or "").strip()
#     if not es_explain(s):
#         return s
#     return re.sub(r"^\s*explain\b", "", s, flags=re.IGNORECASE).strip()


# def sanear_explain(sql: str) -> str:
#     """Valida flags para EXPLAIN/ANALYZE."""
#     s = (sql or "").strip()
#     if not es_explain(s):
#         return s

#     if not ALLOW_SQL_EXPLAIN:
#         raise ValueError("EXPLAIN está deshabilitado por configuración.")

#     if _RE_EXPLAIN_ANALYZE.match(s) and not ALLOW_EXPLAIN_ANALYZE:
#         raise ValueError("EXPLAIN ANALYZE está deshabilitado por configuración.")

#     return s


# def _enmascarar_literales(sql: str) -> str:
#     """Reemplaza literales por placeholders para evitar falsos positivos al detectar palabras prohibidas."""
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

# _PATRONES_PROHIBIDOS = [re.compile(p, re.IGNORECASE) for p in _patrones_base_prohibidos]


# def _contiene_prohibidos(sql: str) -> Optional[str]:
#     """Devuelve el patrón prohibido encontrado, o None."""
#     s = _enmascarar_literales(sql or "")
#     for pat in _PATRONES_PROHIBIDOS:
#         if pat.search(s):
#             return pat.pattern
#     return None


# def es_select_seguro(sql: str) -> bool:
#     """Verifica solo-lectura permitido (VALUES/EXPLAIN/SELECT) y sin palabras prohibidas."""
#     s = (sql or "").strip()
#     if not s:
#         return False

#     if es_solo_values(s):
#         return bool(ALLOW_SQL_VALUES) and (_contiene_prohibidos(s) is None)

#     if es_explain(s):
#         if not ALLOW_SQL_EXPLAIN:
#             return False
#         if _RE_EXPLAIN_ANALYZE.match(s) and not ALLOW_EXPLAIN_ANALYZE:
#             return False
#         inner = desenvolver_explain(s)
#         return (_RE_SELECT.match(inner or "") is not None) and (_contiene_prohibidos(inner) is None)

#     if not _RE_SELECT.match(s):
#         return False

#     return _contiene_prohibidos(s) is None


# # =============================================================================
# # Límite por defecto (LIMIT vs TOP)
# # =============================================================================

# def _forzar_top_mssql(sql: str, n: int) -> str:
#     """Inserta/recorta TOP(n) en SQL Server sin romper CTEs/ventanas."""
#     s = (sql or "").strip()

#     # Si ya existe TOP al inicio del SELECT principal simple, recortar si excede
#     m_top = re.search(
#         r"^\s*select\s+(distinct\s+)?top\s*\(?\s*(\d+)\s*\)?\s+",
#         s,
#         re.IGNORECASE,
#     )
#     if m_top:
#         actual = int(m_top.group(2))
#         if actual > n:
#             s = re.sub(
#                 r"^\s*select\s+(distinct\s+)?top\s*\(?\s*\d+\s*\)?\s+",
#                 lambda mm: ("SELECT " + (mm.group(1) or "") + f"TOP ({n}) "),
#                 s,
#                 flags=re.IGNORECASE,
#             )
#         return s

#     # MUY IMPORTANTE:
#     # Si la query empieza con WITH (CTE), NO insertar TOP en el primer SELECT interno.
#     # Eso rompe ROW_NUMBER / PARTITION BY / ventanas y cambia la semántica.
#     if re.match(r"^\s*with\b", s, re.IGNORECASE):
#         log.debug(
#             "[database._forzar_top_mssql] Query con WITH detectada; "
#             "no se inserta TOP automáticamente para no romper CTE/ventanas."
#         )
#         return s

#     # SELECT normal
#     s2, cnt = re.subn(
#         r"^\s*select\s+distinct\s+",
#         f"SELECT DISTINCT TOP ({n}) ",
#         s,
#         count=1,
#         flags=re.IGNORECASE,
#     )
#     if cnt == 0:
#         s2, _ = re.subn(
#             r"^\s*select\s+",
#             f"SELECT TOP ({n}) ",
#             s,
#             count=1,
#             flags=re.IGNORECASE,
#         )
#     return s2


# def forzar_limit(sql: str, limite_por_defecto: int = 100, limite_maximo: int = 1000) -> str:
#     """
#     Asegura un límite por defecto y recorta límites excesivos.
#     - MSSQL: usa TOP(N) y elimina LIMIT residual.
#     - Postgres: usa LIMIT.
#     """
#     s = (sql or "").strip()

#     if es_mssql():
#         # borrar LIMIT final si aparece (errores del LLM)
#         s = re.sub(r"\s+LIMIT\s+\d+\s*$", "", s, flags=re.IGNORECASE).strip()

#         m_lim = re.search(r"\bLIMIT\s+(\d+)\b", sql or "", re.IGNORECASE)
#         n = int(m_lim.group(1)) if m_lim else int(limite_por_defecto)
#         n = min(max(n, 1), int(limite_maximo))
#         return _forzar_top_mssql(s, n)

#     # Postgres
#     m = re.search(r"\blimit\s+(\d+)\b", s, re.IGNORECASE)
#     if m:
#         n = int(m.group(1))
#         if n > limite_maximo:
#             s = re.sub(r"\blimit\s+\d+\b", f"LIMIT {limite_maximo}", s, flags=re.IGNORECASE)
#         return s

#     return f"{s.rstrip()} LIMIT {limite_por_defecto}"


# # =============================================================================
# # ✅ Allow-list + calificación avanzada (con CTEs)
# # =============================================================================

# _RE_CLAUSULA_FROM_JOIN = re.compile(
#     r"""
#     (?<!\w)
#     \b(from|join)\b
#     \s+
#     (?!')
#     (?P<tbl>
#         (?:\[[^\]]+\]|\w+|\"[^\"]+\")
#         (?:\s*\.\s*(?:\[[^\]]+\]|\w+|\"[^\"]+\"))?
#     )
#     """,
#     re.IGNORECASE | re.VERBOSE,
# )

# _NO_ES_TABLA = {"lateral", "unnest", "generate_series", "values"}


# def _normalizar_token(s: str) -> str:
#     if not s:
#         return ""
#     s = s.strip().lower()
#     s = s.replace("[", "").replace("]", "").replace('"', "")
#     s = re.sub(r"\s+", "", s)
#     return s


# def _construir_mapa_tablas(permitidos_fqn: List[str]) -> Dict[str, str]:
#     """Mapa table_name -> fqn_formateado."""
#     m: Dict[str, str] = {}
#     for f in permitidos_fqn or []:
#         if not f or "." not in f:
#             continue
#         schema, table = f.split(".", 1)
#         schema = schema.strip()
#         table = table.strip()
#         table_clean = table.replace('"', "").replace("[", "").replace("]", "").strip()
#         key = table_clean.lower()
#         if key in m:
#             continue
#         if es_mssql():
#             m[key] = f"[{schema}].[{table_clean}]"
#         else:
#             m[key] = f'{schema}."{table_clean}"'
#     return m


# _RE_DEFINICION_CTE = re.compile(r'(?P<name>"[^"]+"|\w+)\s+AS\s*\(', re.IGNORECASE)


# def _recopilar_nombres_cte(sql: str) -> List[str]:
#     names: List[str] = []
#     s = sql or ""
#     if not re.search(r"^\s*with\b", s, re.IGNORECASE):
#         return names
#     for m in _RE_DEFINICION_CTE.finditer(s):
#         nm = (m.group("name") or "").strip().strip('"').strip().lower()
#         if nm:
#             names.append(nm)
#     return names


# def _extraer_refs_tablas(sql: str) -> List[str]:
#     refs: List[str] = []
#     for m in _RE_CLAUSULA_FROM_JOIN.finditer(sql or ""):
#         tbl = (m.group("tbl") or "").strip()
#         if tbl:
#             refs.append(tbl)
#     return refs


# def _primera_ref_no_permitida(sql: str, permitidos_fqn: List[str]) -> Optional[str]:
#     if not sql or not permitidos_fqn:
#         return "sql/allowed vacío"

#     s = desenvolver_explain(sql) if es_explain(sql) else (sql or "")
#     allowed_set = {_normalizar_token(a) for a in permitidos_fqn if a and a.strip()}
#     mapa_tablas = _construir_mapa_tablas(permitidos_fqn)
#     nombres_cte = set(_recopilar_nombres_cte(s))

#     refs = _extraer_refs_tablas(s)
#     if not refs:
#         return "no se detectaron FROM/JOIN"

#     for r in refs:
#         r_clean = (r or "").strip()
#         if not r_clean:
#             continue

#         head = _normalizar_token(r_clean.split("(")[0]).strip('"')
#         if head in _NO_ES_TABLA:
#             continue

#         if "." not in r_clean:
#             name = _normalizar_token(r_clean)
#             if name in nombres_cte:
#                 continue
#             fqn_fmt = mapa_tablas.get(name)
#             if not fqn_fmt:
#                 return f"tabla no encontrada en allow-list: {r_clean}"
#             if _normalizar_token(fqn_fmt) not in allowed_set:
#                 return f"tabla fuera de allow-list: {r_clean} -> {fqn_fmt}"
#             continue

#         parts = [p.strip().strip('"').strip("[]") for p in r_clean.split(".")]
#         if len(parts) != 2:
#             return f"token schema.tabla inválido: {r_clean}"

#         schema_n = parts[0].strip().lower()
#         table_n = parts[1].strip()

#         fqn_fmt = f"[{schema_n}].[{table_n}]" if es_mssql() else f'{schema_n}."{table_n}"'
#         if _normalizar_token(fqn_fmt) not in allowed_set:
#             return f"FQN fuera de allow-list: {r_clean} -> {fqn_fmt}"

#     return None


# def restringir_a_tablas_permitidas(sql: str, permitidos_fqn: List[str]) -> bool:
#     s = limpiar_sql(sql)
#     inner = desenvolver_explain(s) if es_explain(s) else s
#     return _primera_ref_no_permitida(inner, permitidos_fqn) is None


# _RE_CALIFICAR_FROM_JOIN = re.compile(
#     r'\b(from|join)\s+("?[A-Za-z0-9_ ]+"?)(?!\s*\.)',
#     re.IGNORECASE,
# )


# def calificar_tablas(sql: str, permitidos_fqn: List[str]) -> str:
#     """Califica nombres de tabla sin schema usando la allow-list."""
#     if not sql or not permitidos_fqn:
#         return sql
#     if es_solo_values(sql) or es_explain(sql):
#         return sql

#     nombres_cte = set(_recopilar_nombres_cte(sql))
#     mapa_tablas = _construir_mapa_tablas(permitidos_fqn)

#     def repl(match: re.Match) -> str:
#         kw = match.group(1)
#         raw_name = (match.group(2) or "").strip()
#         name_unquoted = raw_name.replace('"', "").replace("[", "").replace("]", "").strip()
#         name_low = name_unquoted.lower()

#         if name_low in nombres_cte:
#             return match.group(0)

#         head = _normalizar_token(name_unquoted.split("(")[0]).strip('"')
#         if head in _NO_ES_TABLA:
#             return match.group(0)

#         fqn = mapa_tablas.get(name_low)
#         if fqn:
#             return f"{kw} {fqn}"
#         return match.group(0)

#     return _RE_CALIFICAR_FROM_JOIN.sub(repl, sql)


# qualify_tables = calificar_tablas  # legacy

# # =============================================================================
# # ✅ Auto-LEFT JOIN por FKs nullable (FIX definitivo para alias [T1]/[T2])
# # =============================================================================

# # Identificadores MSSQL y alias (permite [T1], [ComponentId], dbo, [dbo].[Table], etc.)
# _ALIAS = r"(?:\[[^\]]+\]|\w+)"
# _IDENT = r"(?:\[[^\]]+\]|\w+|\"[^\"]+\")"

# _RE_FROM_JOIN_ALIAS = re.compile(
#     rf"""
#     \b(from|join)\s+
#     (?P<table>{_IDENT}(?:\s*\.\s*{_IDENT})?)         # dbo.Table o [dbo].[Table] o Table
#     (?:\s+as\s+(?P<alias>{_ALIAS})|\s+(?P<alias2>{_ALIAS}))?
#     """,
#     re.IGNORECASE | re.VERBOSE,
# )

# _RE_JOIN_ON2 = re.compile(
#     rf"""
#     (?P<jtype>\binner\s+join\b|\bleft\s+join\b|\bjoin\b)\s+
#     (?P<table>{_IDENT}(?:\s*\.\s*{_IDENT})?)         # dbo.Table o [dbo].[Table] o Table
#     (?:\s+as\s+(?P<alias>{_ALIAS})|\s+(?P<alias2>{_ALIAS}))?
#     \s+on\s+
#     (?P<left>{_ALIAS}\s*\.\s*{_IDENT})\s*=\s*(?P<right>{_ALIAS}\s*\.\s*{_IDENT})
#     """,
#     re.IGNORECASE | re.VERBOSE,
# )


# def _strip_ident(s: str) -> str:
#     return (s or "").strip().strip("[]").strip('"').strip()


# def _schema_nullable_map(esquema_json: Dict[str, Any]) -> Dict[Tuple[str, str], bool]:
#     mp: Dict[Tuple[str, str], bool] = {}
#     for tb in (esquema_json.get("tables") or []):
#         tname = (tb.get("table") or "").strip().lower()
#         for c in (tb.get("columns") or []):
#             cname = (c.get("name") or "").strip().lower()
#             if tname and cname:
#                 mp[(tname, cname)] = bool(c.get("nullable", True))
#     return mp


# def _alias_to_table_map(sql: str, esquema_json: Dict[str, Any]) -> Dict[str, str]:
#     known_tables: Set[str] = {(t.get("table") or "").strip().lower() for t in (esquema_json.get("tables") or []) if t.get("table")}
#     alias_map: Dict[str, str] = {}

#     for m in _RE_FROM_JOIN_ALIAS.finditer(sql or ""):
#         raw_table = m.group("table") or ""
#         alias = (m.group("alias") or m.group("alias2") or "").strip()
#         if not alias:
#             continue

#         # tabla sin schema
#         t = raw_table.replace('"', "")
#         t = t.replace("[", "").replace("]", "")
#         t = t.split(".")[-1].strip().lower()

#         a = _strip_ident(alias).lower()
#         if t in known_tables:
#             alias_map[a] = t

#     return alias_map


# def _col_from_ref(ref: str) -> Tuple[str, str]:
#     # ref: [T2].[ComponentId] o T2.ComponentId
#     a, c = ref.split(".", 1)
#     a = _strip_ident(a).lower()
#     c = _strip_ident(c).lower()
#     return a, c


# def preferir_left_join_por_nullable(sql: str, esquema_json: Dict[str, Any]) -> str:
#     """
#     Reescribe JOIN/INNER JOIN -> LEFT JOIN cuando el lado FK usado en el ON
#     sea nullable según schema_json.

#     Soporta aliases tipo [T1], [T2] y columnas en brackets.

#     Nota:
#     - Esto NO cambia el ON, solo el tipo de JOIN.
#     - Si ya es LEFT JOIN, lo deja intacto.
#     """
#     if not sql or not esquema_json:
#         return sql

#     # feature flag opcional (por si deseas apagarlo rápido)
#     if env("SQL_AUTO_LEFT_JOIN_NULLABLE", default=True, cast=bool) is False:
#         return sql

#     nullable_map = _schema_nullable_map(esquema_json)
#     alias_map = _alias_to_table_map(sql, esquema_json)

#     def repl(m: re.Match) -> str:
#         jtype = (m.group("jtype") or "").lower()
#         if "left join" in jtype:
#             return m.group(0)

#         left_ref = (m.group("left") or "").replace(" ", "")
#         right_ref = (m.group("right") or "").replace(" ", "")

#         aL, cL = _col_from_ref(left_ref)
#         aR, cR = _col_from_ref(right_ref)

#         tL = alias_map.get(aL)
#         tR = alias_map.get(aR)

#         is_nullable_L = bool(tL and (nullable_map.get((tL, cL)) is True))
#         is_nullable_R = bool(tR and (nullable_map.get((tR, cR)) is True))

#         if is_nullable_L or is_nullable_R:
#             original = m.group(0)
#             changed = re.sub(r"\b(inner\s+join|join)\b", "LEFT JOIN", original, count=1, flags=re.IGNORECASE)

#             if changed != original:
#                 log.debug(
#                     "[database.preferir_left_join_por_nullable] %s -> LEFT JOIN (nullable: %s.%s=%s, %s.%s=%s)",
#                     (m.group("table") or "").strip(),
#                     tL, cL, is_nullable_L,
#                     tR, cR, is_nullable_R,
#                 )
#             return changed

#         return m.group(0)

#     return _RE_JOIN_ON2.sub(repl, sql)

# def _split_sql_top_level(s: str) -> List[str]:
#     """
#     Divide una lista SQL por comas de nivel superior.
#     Ejemplo:
#       a, COALESCE(b,c), SUM(d)  ->  ["a", "COALESCE(b,c)", "SUM(d)"]
#     """
#     if not s:
#         return []

#     partes: List[str] = []
#     actual: List[str] = []
#     profundidad = 0

#     for ch in s:
#         if ch == "(":
#             profundidad += 1
#             actual.append(ch)
#         elif ch == ")":
#             profundidad = max(0, profundidad - 1)
#             actual.append(ch)
#         elif ch == "," and profundidad == 0:
#             item = "".join(actual).strip()
#             if item:
#                 partes.append(item)
#             actual = []
#         else:
#             actual.append(ch)

#     item = "".join(actual).strip()
#     if item:
#         partes.append(item)

#     return partes


# _RE_RELACION_ALIAS_ORDEN = re.compile(
#     rf"""
#     \b(?P<kind>from|left\s+join|inner\s+join|join)\s+
#     (?P<table>{_IDENT}(?:\s*\.\s*{_IDENT})?)     
#     (?:\s+as\s+(?P<alias>{_ALIAS})|\s+(?P<alias2>{_ALIAS}))?
#     """,
#     re.IGNORECASE | re.VERBOSE,
# )


# def _extraer_relaciones_query(sql: str, esquema_json: Dict[str, Any]) -> List[Dict[str, Any]]:
#     """
#     Extrae relaciones en orden:
#       FROM tabla alias
#       JOIN tabla alias
#     """
#     conocidas = {
#         (t.get("table") or "").strip().lower()
#         for t in (esquema_json.get("tables") or [])
#         if t.get("table")
#     }

#     relaciones: List[Dict[str, Any]] = []

#     for idx, m in enumerate(_RE_RELACION_ALIAS_ORDEN.finditer(sql or "")):
#         raw_table = (m.group("table") or "").replace("[", "").replace("]", "").replace('"', "")
#         table_name = raw_table.split(".")[-1].strip().lower()

#         alias_raw = (m.group("alias") or m.group("alias2") or "").strip()
#         alias_name = _strip_ident(alias_raw).lower() if alias_raw else table_name

#         if table_name in conocidas and alias_name:
#             relaciones.append(
#                 {
#                     "order": idx,
#                     "kind": (m.group("kind") or "").lower(),
#                     "alias": alias_name,
#                     "table": table_name,
#                 }
#             )

#     return relaciones


# def _columnas_texto_tabla(esquema_json: Dict[str, Any], table_name: str) -> List[str]:
#     out: List[str] = []
#     tname = (table_name or "").strip().lower()

#     for tb in (esquema_json.get("tables") or []):
#         if (tb.get("table") or "").strip().lower() != tname:
#             continue
#         for col in (tb.get("columns") or []):
#             cname = (col.get("name") or "").strip()
#             ctype = (col.get("type") or "").lower()
#             if cname and any(x in ctype for x in ["char", "text", "varchar", "nvarchar", "string", "clob"]):
#                 out.append(cname)
#         break

#     return out


# def _puntuar_columna_texto_descriptiva(nombre_columna: str) -> int:
#     """
#     Heurística genérica para preferir columnas descriptivas como fallback.
#     """
#     n = (nombre_columna or "").strip().lower()
#     score = 0

#     # muy buenas
#     if any(x in n for x in ["name", "nombre"]):
#         score += 100
#     if any(x in n for x in ["description", "descripcion", "desc"]):
#         score += 80

#     # buenas
#     if any(x in n for x in ["compart", "component", "equipment", "system", "sistema", "model", "modelo", "type", "tipo", "position", "project", "customer", "client", "cliente", "category", "categoria"]):
#         score += 60

#     # útiles, pero menos
#     if any(x in n for x in ["code", "codigo"]):
#         score += 40

#     # malas para agrupar
#     if any(x in n for x in ["observ", "recommend", "detail", "path", "mail", "email", "phone", "telefono"]):
#         score -= 20

#     # normalmente no deben usarse como etiqueta
#     if any(x in n for x in ["id", "date", "fecha", "time", "hora", "count", "total", "avg", "sum", "metric", "value", "flag"]):
#         score -= 60

#     if n.endswith("id"):
#         score -= 100

#     return score


# def _parse_alias_col_expr(expr: str) -> Optional[Tuple[str, str, str]]:
#     """
#     Parsea expresiones exactas tipo:
#       c.ComponentName
#       [c].[ComponentName]
#       c.[ComponentName]
#       [c].ComponentName

#     Retorna:
#       (alias_lower, col_lower, col_original)
#     """
#     m = re.match(
#         rf"^\s*(?P<a>{_ALIAS})\s*\.\s*(?P<c>{_IDENT})\s*$",
#         expr or "",
#         flags=re.IGNORECASE,
#     )
#     if not m:
#         return None

#     alias_raw = _strip_ident(m.group("a")).lower()
#     col_raw = _strip_ident(m.group("c"))
#     return alias_raw, col_raw.lower(), col_raw


# def _patron_alias_col(alias_norm: str, col_raw: str) -> str:
#     """
#     Regex para matchear:
#       c.Col
#       c.[Col]
#       [c].Col
#       [c].[Col]
#     """
#     a = re.escape(alias_norm)
#     c = re.escape(col_raw)
#     return (
#         rf"(?:\[\s*{a}\s*\]|\b{a}\b)\s*\.\s*"
#         rf"(?:\[\s*{c}\s*\]|\b{c}\b)"
#     )


# def _usuario_pide_estricto_consulta(consulta_humana: str) -> bool:
#     q = (consulta_humana or "").lower()
#     pistas = [
#         "solo coincidencias",
#         "solo matching",
#         "excluir null",
#         "sin null",
#         "no null",
#         "solo donde exista",
#         "solo donde haya",
#         "únicamente los que tengan",
#         "solo los que tengan",
#         "estricto",
#         "exactamente",
#         "obligatorio",
#     ]
#     return any(p in q for p in pistas)


# def _elegir_fallbacks_genericos(
#     sql: str,
#     esquema_json: Dict[str, Any],
#     relaciones: List[Dict[str, Any]],
#     alias_objetivo: str,
#     col_objetivo_lower: str,
# ) -> List[str]:
#     """
#     Elige hasta 2 columnas de texto descriptivas de tablas YA presentes en el query.
#     No inventa tablas. Sí puede usar columnas del schema aunque no estén en SELECT.
#     """
#     target_rel = next((r for r in relaciones if r["alias"] == alias_objetivo), None)
#     target_order = target_rel["order"] if target_rel else 10**9

#     # Preferimos tablas anteriores al alias objetivo: fact table y puente
#     candidatas_rel = [r for r in relaciones if r["alias"] != alias_objetivo and r["order"] < target_order]
#     if not candidatas_rel:
#         candidatas_rel = [r for r in relaciones if r["alias"] != alias_objetivo]

#     candidatos: List[Tuple[int, int, str]] = []

#     for rel in candidatas_rel:
#         alias = rel["alias"]
#         table = rel["table"]
#         kind = rel["kind"]

#         bonus_kind = 0
#         if kind == "from":
#             bonus_kind = 50
#         elif "inner" in kind or kind == "join":
#             bonus_kind = 40
#         elif "left" in kind:
#             bonus_kind = 20

#         for col in _columnas_texto_tabla(esquema_json, table):
#             if col.lower() == col_objetivo_lower:
#                 continue

#             score = _puntuar_columna_texto_descriptiva(col) + bonus_kind
#             if score <= 0:
#                 continue

#             expr = f"[{alias}].[{col}]"
#             candidatos.append((score, rel["order"], expr))

#     candidatos.sort(key=lambda x: (-x[0], x[1], x[2].lower()))

#     out: List[str] = []
#     seen = set()
#     for _, _, expr in candidatos:
#         k = expr.lower()
#         if k not in seen:
#             out.append(expr)
#             seen.add(k)
#         if len(out) >= 2:
#             break

#     return out


# def hacer_groupby_nullsafe_mssql(
#     sql: str,
#     esquema_json: Dict[str, Any],
#     consulta_humana: str = "",
# ) -> str:
#     """
#     Reescritura determinística para MSSQL:

#     Caso objetivo:
#     - LEFT JOIN a una dimensión nullable/opcional
#     - GROUP BY sobre campo del lado derecho
#     - Resultado termina en grupo NULL o puede perder semántica

#     Regla:
#     - Si el usuario pidió estricto -> WHERE dim IS NOT NULL
#     - Si no -> COALESCE(dim, fallback1, fallback2)
#              + WHERE COALESCE(...) <> ''
#              + GROUP BY la misma expresión
#     """
#     s = (sql or "").strip()
#     if not s or not es_mssql():
#         return s

#     if " group by " not in f" {s.lower()} ":
#         return s

#     if " left join " not in f" {s.lower()} ":
#         return s

#     relaciones = _extraer_relaciones_query(s, esquema_json)
#     if not relaciones:
#         return s

#     left_aliases = {r["alias"] for r in relaciones if "left" in r["kind"]}
#     if not left_aliases:
#         return s

#     mg = re.search(
#         r"\bgroup\s+by\s+(?P<g>.+?)(?=\border\s+by\b|\bhaving\b|$)",
#         s,
#         flags=re.IGNORECASE | re.DOTALL,
#     )
#     if not mg:
#         return s

#     group_chunk = mg.group("g").strip()
#     exprs = _split_sql_top_level(group_chunk)

#     target_idx = None
#     target_alias = None
#     target_col_lower = None
#     target_col_raw = None

#     for idx, expr in enumerate(exprs):
#         parsed = _parse_alias_col_expr(expr)
#         if not parsed:
#             continue
#         a_low, c_low, c_raw = parsed
#         if a_low in left_aliases:
#             target_idx = idx
#             target_alias = a_low
#             target_col_lower = c_low
#             target_col_raw = c_raw
#             break

#     if target_idx is None or not target_alias or not target_col_lower or not target_col_raw:
#         return s

#     dim_expr = f"[{target_alias}].[{target_col_raw}]"

#     if _usuario_pide_estricto_consulta(consulta_humana):
#         filtro_estricto = f"{dim_expr} IS NOT NULL"

#         if re.search(r"\bwhere\b", s, flags=re.IGNORECASE):
#             s = re.sub(
#                 r"\bwhere\b",
#                 f"WHERE {filtro_estricto} AND",
#                 s,
#                 count=1,
#                 flags=re.IGNORECASE,
#             )
#         else:
#             s = re.sub(
#                 r"\bgroup\s+by\b",
#                 f"WHERE {filtro_estricto} GROUP BY",
#                 s,
#                 count=1,
#                 flags=re.IGNORECASE,
#             )
#         return s

#     fallbacks = _elegir_fallbacks_genericos(
#         sql=s,
#         esquema_json=esquema_json,
#         relaciones=relaciones,
#         alias_objetivo=target_alias,
#         col_objetivo_lower=target_col_lower,
#     )

#     if not fallbacks:
#         # fallback mínimo: filtrar null/blank para no devolver el grupo nulo
#         filtro_min = f"COALESCE(LTRIM(RTRIM(CAST({dim_expr} AS NVARCHAR(4000)))), '') <> ''"
#         if re.search(r"\bwhere\b", s, flags=re.IGNORECASE):
#             s = re.sub(
#                 r"\bwhere\b",
#                 f"WHERE {filtro_min} AND",
#                 s,
#                 count=1,
#                 flags=re.IGNORECASE,
#             )
#         else:
#             s = re.sub(
#                 r"\bgroup\s+by\b",
#                 f"WHERE {filtro_min} GROUP BY",
#                 s,
#                 count=1,
#                 flags=re.IGNORECASE,
#             )
#         return s

#     expr_coalesce = f"COALESCE({dim_expr}, {', '.join(fallbacks)})"

#     # 1) Reescribir GROUP BY
#     exprs[target_idx] = expr_coalesce
#     new_group_chunk = ", ".join(exprs)
#     s = s[:mg.start("g")] + new_group_chunk + s[mg.end("g"):]

#     # 2) Reescribir SELECT para que la dimensión proyectada coincida con el GROUP BY
#     ms = re.search(
#         r"^\s*select\s+(?P<body>.+?)\bfrom\b",
#         s,
#         flags=re.IGNORECASE | re.DOTALL,
#     )
#     if ms:
#         body = ms.group("body")
#         pat_dim = _patron_alias_col(target_alias, target_col_raw)

#         body_new = re.sub(
#             pat_dim + r"(?:\s+as\s+(?:\[[^\]]+\]|\w+))?",
#             f"{expr_coalesce} AS [{target_col_raw}]",
#             body,
#             count=1,
#             flags=re.IGNORECASE,
#         )

#         if body_new != body:
#             s = s[:ms.start("body")] + body_new + s[ms.end("body"):]

#     # 3) Evitar grupo vacío / null total
#     filtro = f"COALESCE(LTRIM(RTRIM(CAST({expr_coalesce} AS NVARCHAR(4000)))), '') <> ''"
#     if re.search(r"\bwhere\b", s, flags=re.IGNORECASE):
#         s = re.sub(
#             r"\bwhere\b",
#             f"WHERE {filtro} AND",
#             s,
#             count=1,
#             flags=re.IGNORECASE,
#         )
#     else:
#         s = re.sub(
#             r"\bgroup\s+by\b",
#             f"WHERE {filtro} GROUP BY",
#             s,
#             count=1,
#             flags=re.IGNORECASE,
#         )

#     log.debug("[database.hacer_groupby_nullsafe_mssql] SQL reescrita con COALESCE.")
#     return s

# # =============================================================================
# # Ejecución
# # =============================================================================

# def consultar(
#     sql_query: str,
#     permitidos_fqn: List[str],
#     limite_por_defecto: int = 100,
#     limite_maximo: int = 1000,
# ) -> List[Dict[str, Any]]:
#     """
#     Ejecuta consulta solo-lectura de forma segura:
#     - Limpia SQL
#     - Expande macros (solo Postgres)
#     - Sanitiza EXPLAIN
#     - Califica tablas
#     - Valida lectura y allow-list
#     - Aplica límite por defecto (TOP/LIMIT)
#     """
#     log.debug("[database.consultar] raw=%r", (sql_query or "")[:500])

#     sql_query = limpiar_sql(sql_query)
#     sql_query = expandir_macros(sql_query)
#     sql_query = sanear_explain(sql_query)
#     sql_query = calificar_tablas(sql_query, permitidos_fqn)

#     if not es_select_seguro(sql_query):
#         raise ValueError("Solo se permiten consultas de lectura (SELECT/CTE, EXPLAIN permitido, VALUES).")

#     val_sql = desenvolver_explain(sql_query) if es_explain(sql_query) else sql_query

#     bad = _primera_ref_no_permitida(val_sql, permitidos_fqn)
#     if (not es_solo_values(sql_query)) and bad:
#         raise ValueError(f"La consulta referencia tablas no permitidas. Detalle: {bad}")

#     if (not es_solo_values(sql_query)) and (not es_explain(sql_query)):
#         sql_final = forzar_limit(val_sql, limite_por_defecto=limite_por_defecto, limite_maximo=limite_maximo)
#     else:
#         sql_final = sql_query

#     log.debug("[database.consultar] final=%r", sql_final[:800])

#     with Session() as session:
#         result = session.execute(text(sql_final))
#         rows = result.mappings().all()
#         return [dict(r) for r in rows]


# # Alias legacy
# query = consultar


# def limpiar_recursos() -> None:
#     """Libera conexiones del pool."""
#     engine.dispose()

# src/database.py
# -*- coding: utf-8 -*-
"""
Módulo: database
----------------
Herramientas de acceso a BD (SQLAlchemy) + guardrails para ejecutar consultas SQL
generadas por un LLM de forma segura.

Objetivos:
- Introspección de esquema (para alimentar al LLM).
- Limpieza/normalización robusta de SQL (incluye fences markdown).
- Validación de seguridad: solo lectura (SELECT/CTE), EXPLAIN opcional, VALUES opcional.
- Allow-list de tablas: la consulta solo puede tocar tablas presentes en el esquema permitido.
- Calificación automática: si el LLM escribe FROM Tabla, se intenta convertir a schema.Tabla permitido.
- Límite por defecto:
  - Postgres: LIMIT
  - SQL Server (Azure SQL): TOP(N)

Compatibilidad:
- Se mantienen alias antiguos en inglés: get_schema_json, clean_sql, expand_macros, query, etc.
- Se mantiene Session y engine como antes.
"""

from __future__ import annotations

from typing import Any, Dict, List, Optional, Tuple, Set
import logging
import re
import warnings

from sqlalchemy.exc import SAWarning
from decouple import config as env
from sqlalchemy import create_engine, inspect
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import QueuePool
from sqlalchemy.sql import text

log = logging.getLogger(__name__)

warnings.filterwarnings(
    "ignore",
    message=r".*Did not recognize type 'sysname'.*",
    category=SAWarning,
)

# =============================================================================
# Configuración / Engine
# =============================================================================

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

# SQLAlchemy engine: Postgres usa sslmode, MSSQL no.
if es_mssql():
    engine = create_engine(DATABASE_URL, **_engine_kwargs)
else:
    engine = create_engine(DATABASE_URL, connect_args={"sslmode": "require"}, **_engine_kwargs)

Session = sessionmaker(bind=engine)

# =============================================================================
# Esquema con caché
# =============================================================================

_CACHE_ESQUEMA: Dict[Tuple[Tuple[str, ...], Tuple[str, ...]], Dict[str, Any]] = {}

TABLAS_SISTEMA_EXCLUIDAS = {"sysdiagrams"}


def _normalizar_secuencia(seq: Optional[List[str]]) -> Tuple[str, ...]:
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
    Obtiene descripción JSON del esquema con caché.
    Devuelve: {"tables":[{"schema","table","fq_name","columns":[...]}]}

    fq_name:
      - MSSQL: [schema].[table]
      - Postgres: schema."table"
    """
    key = (_normalizar_secuencia(esquemas), _normalizar_secuencia(tablas))
    if key in _CACHE_ESQUEMA:
        return _CACHE_ESQUEMA[key]

    inspector = inspect(engine)
    esquemas_elegidos = list(key[0]) if key[0] else inspector.get_schema_names()

    tablas_salida: List[Dict[str, Any]] = []
    total_columnas = 0

    for sch in esquemas_elegidos:
        nombres = inspector.get_table_names(schema=sch)
        if key[1]:
            nombres = [t for t in nombres if t in key[1]]

        for t in nombres:
            if (t or "").strip().lower() in TABLAS_SISTEMA_EXCLUIDAS:
                continue

            cols_meta = inspector.get_columns(t, schema=sch)
            cols = []
            for c in cols_meta:
                tipo = str(c.get("type", ""))

                # Normalización MSSQL: sysname ≈ NVARCHAR(128)
                if tipo.lower() == "sysname":
                    tipo = "NVARCHAR(128)"

                cols.append(
                    {
                        "name": c.get("name"),
                        "type": tipo,
                        "nullable": bool(c.get("nullable", True)),
                    }
                )

            fq_name = f"[{sch}].[{t}]" if es_mssql() else f'{sch}."{t}"'

            tablas_salida.append(
                {"schema": sch, "table": t, "fq_name": fq_name, "columns": cols}
            )

            total_columnas += len(cols)
            if len(tablas_salida) >= max_tablas or total_columnas >= max_columnas:
                break

        if len(tablas_salida) >= max_tablas or total_columnas >= max_columnas:
            break

    resultado = {"tables": tablas_salida}
    _CACHE_ESQUEMA[key] = resultado
    return resultado


def invalidar_cache_esquema() -> None:
    """Limpia completamente la caché del esquema."""
    _CACHE_ESQUEMA.clear()


# Alias legacy
get_schema_json = obtener_esquema_json
invalidate_schema_cache = invalidar_cache_esquema
refrescar_cache_esquema = invalidar_cache_esquema  # compat con tu versión vieja

# =============================================================================
# Limpieza de SQL (robusta)
# =============================================================================

_RE_BLOQUES_CODIGO = re.compile(
    r"^\s*```(?:sql|postgresql|tsql|mssql)?\s*|\s*```\s*$",
    re.IGNORECASE | re.MULTILINE,
)


def _quitar_bloques_codigo(s: str) -> str:
    """Quita fences markdown ```sql ... ```."""
    return _RE_BLOQUES_CODIGO.sub("", s or "")


def _quitar_comentarios_sql(s: str) -> str:
    """Quita comentarios -- línea y /* bloque */."""
    s = re.sub(r"--.*?$", "", s, flags=re.MULTILINE)
    s = re.sub(r"/\*.*?\*/", "", s, flags=re.DOTALL)
    return s


_RE_ESPACIOS = re.compile(r"\s+")


def limpiar_sql(sql: str) -> str:
    """
    Limpia SQL de entrada:
    - Quita fences markdown y comentarios.
    - Quita prefijos 'sql:' o 'query:'.
    - Quita ';' final.
    - Colapsa espacios.
    """
    s = sql or ""
    s = _quitar_bloques_codigo(s)
    s = _quitar_comentarios_sql(s)
    s = s.strip()
    s = re.sub(r"^(sql|query)\s*:\s*", "", s, flags=re.IGNORECASE).strip()
    if s.endswith(";"):
        s = s[:-1].strip()
    s = _RE_ESPACIOS.sub(" ", s)
    log.debug("[database.limpiar_sql] IN=%r OUT=%r", (sql or "")[:300], s[:300])
    return s


# Alias legacy
clean_sql = limpiar_sql

# =============================================================================
# Macros (NUMERIC_CLEAN, DATE_PARSE)
# - En Postgres: se expanden
# - En MSSQL: se desactivan
# =============================================================================

_RE_NUMERIC_CLEAN = re.compile(r"NUMERIC_CLEAN\(\s*([^)]+?)\s*\)", re.IGNORECASE | re.DOTALL)
_RE_DATE_PARSE = re.compile(r"DATE_PARSE\(\s*([^)]+?)\s*\)", re.IGNORECASE | re.DOTALL)


def expandir_numeric_clean(sql: str) -> str:
    """Expande NUMERIC_CLEAN(expr) a SQL Postgres robusto (solo Postgres)."""
    def repl(m: re.Match) -> str:
        expr = (m.group(1) or "").strip()
        s = f"TRIM({expr})"
        return f"""
        (
          COALESCE(
            NULLIF(
              CASE
                WHEN {s} IS NULL OR {s} = '' THEN NULL
                WHEN {s} ~ '^[0-9]{{1,3}}(,[0-9]{{3}})+(\\.[0-9]+)?$'
                  THEN REPLACE({s}, ',', '')
                WHEN {s} ~ '^[0-9]{{1,3}}(\\.[0-9]{{3}})+(,[0-9]+)?$'
                  THEN REPLACE(REPLACE({s}, '.', ''), ',', '.')
                WHEN {s} ~ '^[0-9]+,[0-9]+$'
                  THEN REPLACE({s}, ',', '.')
                WHEN {s} ~ '^[0-9]+\\.[0-9]{{3}}$'
                  THEN REPLACE({s}, '.', '')
                WHEN {s} ~ '^[0-9.]+$' AND LENGTH({s})-LENGTH(REPLACE({s},'.','')) > 1
                  THEN REGEXP_REPLACE({s}, '\\.(?=.*\\.)', '', 'g')
                WHEN {s} ~ '[0-9],[0-9]' AND {s} ~ '[0-9]\\.[0-9]'
                  THEN CASE
                         WHEN {s} ~ ',\\d+\\s*$' THEN REPLACE(REPLACE({s}, '.', ''), ',', '.')
                         ELSE REPLACE({s}, ',', '')
                       END
                ELSE REGEXP_REPLACE(REPLACE({s}, ',', '.'), '[^0-9.]', '', 'g')
              END,
              ''
            )::numeric,
            0
          )
        )
        """
    return _RE_NUMERIC_CLEAN.sub(repl, sql or "")


def expandir_date_parse(sql: str) -> str:
    """Expande DATE_PARSE(expr) a un CASE en Postgres (solo Postgres)."""
    def repl(m: re.Match) -> str:
        expr = (m.group(1) or "").strip()
        col = expr
        return (
            "("
            "CASE "
            f"WHEN TRIM({col}) ~ '^\\s*\\d{{4}}-\\d{{2}}-\\d{{2}}' "
            f"THEN to_date(SUBSTRING(TRIM({col}) FROM '(\\d{{4}}-\\d{{2}}-\\d{{2}})'), 'YYYY-MM-DD') "
            f"WHEN TRIM({col}) ~ '^\\s*\\d{{1,2}}/\\d{{1,2}}/\\d{{4}}' "
            f"THEN to_date(SUBSTRING(TRIM({col}) FROM '(\\d{{1,2}}/\\d{{1,2}}/\\d{{4}})'), 'DD/MM/YYYY') "
            f"WHEN TRIM({col}) ~ '^\\s*\\d{{1,2}}-\\d{{1,2}}-\\d{{4}}' "
            f"THEN to_date(SUBSTRING(TRIM({col}) FROM '(\\d{{1,2}}-\\d{{1,2}}-\\d{{4}})'), 'DD-MM-YYYY') "
            f"WHEN TRIM({col}) ~ '^\\s*\\d{{1,2}}\\.\\d{{1,2}}\\.\\d{{4}}' "
            f"THEN to_date(SUBSTRING(TRIM({col}) FROM '(\\d{{1,2}}\\.\\d{{1,2}}\\.\\d{{4}})'), 'DD.MM.YYYY') "
            "ELSE NULL "
            "END"
            ")"
        )
    return _RE_DATE_PARSE.sub(repl, sql or "")


def expandir_macros(sql: str) -> str:
    """Expande macros soportadas (solo Postgres). En MSSQL se desactiva."""
    if es_mssql():
        return sql or ""
    s = sql or ""
    s2 = expandir_numeric_clean(s)
    s3 = expandir_date_parse(s2)
    if s3 != s:
        log.debug("[database.expandir_macros] macros expandido.")
    return s3


# Alias legacy
expand_macros = expandir_macros

# =============================================================================
# Seguridad / Clasificación
# =============================================================================

_RE_EXPLAIN = re.compile(r"^\s*explain\b", re.IGNORECASE)
_RE_EXPLAIN_ANALYZE = re.compile(r"^\s*explain\b.*\banalyze\b", re.IGNORECASE | re.DOTALL)
_RE_VALUES = re.compile(r"^\s*values\s*\(", re.IGNORECASE)
_RE_SELECT = re.compile(r"^\s*(WITH\b.+\bSELECT|SELECT)\b", re.IGNORECASE | re.DOTALL)

_RE_LITERAL_SIMPLE = re.compile(r"('([^']|'')*')", re.DOTALL)
_RE_LITERAL_DOLAR = re.compile(r"(\$\$.*?\$\$)", re.DOTALL)


def es_solo_values(sql: str) -> bool:
    """Indica si el SQL es únicamente un bloque VALUES(...)."""
    return bool(_RE_VALUES.match(sql or ""))


def es_explain(sql: str) -> bool:
    """Indica si el SQL inicia con EXPLAIN."""
    return bool(_RE_EXPLAIN.match(sql or ""))


def desenvolver_explain(sql: str) -> str:
    """Quita el prefijo EXPLAIN para evaluar allow-list."""
    s = (sql or "").strip()
    if not es_explain(s):
        return s
    return re.sub(r"^\s*explain\b", "", s, flags=re.IGNORECASE).strip()


def sanear_explain(sql: str) -> str:
    """Valida flags para EXPLAIN/ANALYZE."""
    s = (sql or "").strip()
    if not es_explain(s):
        return s

    if not ALLOW_SQL_EXPLAIN:
        raise ValueError("EXPLAIN está deshabilitado por configuración.")

    if _RE_EXPLAIN_ANALYZE.match(s) and not ALLOW_EXPLAIN_ANALYZE:
        raise ValueError("EXPLAIN ANALYZE está deshabilitado por configuración.")

    return s


def _enmascarar_literales(sql: str) -> str:
    """Reemplaza literales por placeholders para evitar falsos positivos al detectar palabras prohibidas."""
    s = sql or ""
    s = _RE_LITERAL_DOLAR.sub("$$''$$", s)
    s = _RE_LITERAL_SIMPLE.sub("''", s)
    return s


_patrones_base_prohibidos = [
    r"\bDROP\b", r"\bDELETE\b", r"\bTRUNCATE\b", r"\bALTER\b",
    r"\bINSERT\b", r"\bUPDATE\b", r"\bCREATE\b", r"\bMERGE\b",
    r"\bVACUUM\b", r"\bCOPY\b", r"\bGRANT\b", r"\bREVOKE\b",
]
if not ALLOW_SQL_CALL:
    _patrones_base_prohibidos.append(r"\bCALL\b")

_PATRONES_PROHIBIDOS = [re.compile(p, re.IGNORECASE) for p in _patrones_base_prohibidos]


def _contiene_prohibidos(sql: str) -> Optional[str]:
    """Devuelve el patrón prohibido encontrado, o None."""
    s = _enmascarar_literales(sql or "")
    for pat in _PATRONES_PROHIBIDOS:
        if pat.search(s):
            return pat.pattern
    return None


def es_select_seguro(sql: str) -> bool:
    """Verifica solo-lectura permitido (VALUES/EXPLAIN/SELECT) y sin palabras prohibidas."""
    s = (sql or "").strip()
    if not s:
        return False

    if es_solo_values(s):
        return bool(ALLOW_SQL_VALUES) and (_contiene_prohibidos(s) is None)

    if es_explain(s):
        if not ALLOW_SQL_EXPLAIN:
            return False
        if _RE_EXPLAIN_ANALYZE.match(s) and not ALLOW_EXPLAIN_ANALYZE:
            return False
        inner = desenvolver_explain(s)
        return (_RE_SELECT.match(inner or "") is not None) and (_contiene_prohibidos(inner) is None)

    if not _RE_SELECT.match(s):
        return False

    return _contiene_prohibidos(s) is None


# =============================================================================
# Límite por defecto (LIMIT vs TOP)
# =============================================================================

def _forzar_top_mssql(sql: str, n: int) -> str:
    """Inserta/recorta TOP(n) en SQL Server sin romper CTEs/ventanas."""
    s = (sql or "").strip()

    # Si ya existe TOP al inicio del SELECT principal simple, recortar si excede
    m_top = re.search(
        r"^\s*select\s+(distinct\s+)?top\s*\(?\s*(\d+)\s*\)?\s+",
        s,
        re.IGNORECASE,
    )
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

    # MUY IMPORTANTE:
    # Si la query empieza con WITH (CTE), NO insertar TOP en el primer SELECT interno.
    # Eso rompe ROW_NUMBER / PARTITION BY / ventanas y cambia la semántica.
    if re.match(r"^\s*with\b", s, re.IGNORECASE):
        log.debug(
            "[database._forzar_top_mssql] Query con WITH detectada; "
            "no se inserta TOP automáticamente para no romper CTE/ventanas."
        )
        return s

    # SELECT normal
    s2, cnt = re.subn(
        r"^\s*select\s+distinct\s+",
        f"SELECT DISTINCT TOP ({n}) ",
        s,
        count=1,
        flags=re.IGNORECASE,
    )
    if cnt == 0:
        s2, _ = re.subn(
            r"^\s*select\s+",
            f"SELECT TOP ({n}) ",
            s,
            count=1,
            flags=re.IGNORECASE,
        )
    return s2


def forzar_limit(sql: str, limite_por_defecto: int = 100, limite_maximo: int = 1000) -> str:
    """
    Asegura un límite por defecto y recorta límites excesivos.
    - MSSQL: usa TOP(N) y elimina LIMIT residual.
    - Postgres: usa LIMIT.
    """
    s = (sql or "").strip()

    if es_mssql():
        # borrar LIMIT final si aparece (errores del LLM)
        s = re.sub(r"\s+LIMIT\s+\d+\s*$", "", s, flags=re.IGNORECASE).strip()

        m_lim = re.search(r"\bLIMIT\s+(\d+)\b", sql or "", re.IGNORECASE)
        n = int(m_lim.group(1)) if m_lim else int(limite_por_defecto)
        n = min(max(n, 1), int(limite_maximo))
        return _forzar_top_mssql(s, n)

    # Postgres
    m = re.search(r"\blimit\s+(\d+)\b", s, re.IGNORECASE)
    if m:
        n = int(m.group(1))
        if n > limite_maximo:
            s = re.sub(r"\blimit\s+\d+\b", f"LIMIT {limite_maximo}", s, flags=re.IGNORECASE)
        return s

    return f"{s.rstrip()} LIMIT {limite_por_defecto}"


# =============================================================================
# ✅ Allow-list + calificación avanzada (con CTEs)
# =============================================================================

_RE_CLAUSULA_FROM_JOIN = re.compile(
    r"""
    (?<!\w)
    \b(from|join)\b
    \s+
    (?!')
    (?P<tbl>
        (?:\[[^\]]+\]|\w+|\"[^\"]+\")
        (?:\s*\.\s*(?:\[[^\]]+\]|\w+|\"[^\"]+\"))?
    )
    """,
    re.IGNORECASE | re.VERBOSE,
)

_NO_ES_TABLA = {"lateral", "unnest", "generate_series", "values"}


def _normalizar_token(s: str) -> str:
    if not s:
        return ""
    s = s.strip().lower()
    s = s.replace("[", "").replace("]", "").replace('"', "")
    s = re.sub(r"\s+", "", s)
    return s


def _construir_mapa_tablas(permitidos_fqn: List[str]) -> Dict[str, str]:
    """Mapa table_name -> fqn_formateado."""
    m: Dict[str, str] = {}
    for f in permitidos_fqn or []:
        if not f or "." not in f:
            continue
        schema, table = f.split(".", 1)
        schema = schema.strip()
        table = table.strip()
        table_clean = table.replace('"', "").replace("[", "").replace("]", "").strip()
        key = table_clean.lower()
        if key in m:
            continue
        if es_mssql():
            m[key] = f"[{schema}].[{table_clean}]"
        else:
            m[key] = f'{schema}."{table_clean}"'
    return m


_RE_DEFINICION_CTE = re.compile(r'(?P<name>"[^"]+"|\w+)\s+AS\s*\(', re.IGNORECASE)


def _recopilar_nombres_cte(sql: str) -> List[str]:
    names: List[str] = []
    s = sql or ""
    if not re.search(r"^\s*with\b", s, re.IGNORECASE):
        return names
    for m in _RE_DEFINICION_CTE.finditer(s):
        nm = (m.group("name") or "").strip().strip('"').strip().lower()
        if nm:
            names.append(nm)
    return names


def _extraer_refs_tablas(sql: str) -> List[str]:
    refs: List[str] = []
    for m in _RE_CLAUSULA_FROM_JOIN.finditer(sql or ""):
        tbl = (m.group("tbl") or "").strip()
        if tbl:
            refs.append(tbl)
    return refs


def _primera_ref_no_permitida(sql: str, permitidos_fqn: List[str]) -> Optional[str]:
    if not sql or not permitidos_fqn:
        return "sql/allowed vacío"

    s = desenvolver_explain(sql) if es_explain(sql) else (sql or "")
    allowed_set = {_normalizar_token(a) for a in permitidos_fqn if a and a.strip()}
    mapa_tablas = _construir_mapa_tablas(permitidos_fqn)
    nombres_cte = set(_recopilar_nombres_cte(s))

    refs = _extraer_refs_tablas(s)
    if not refs:
        return "no se detectaron FROM/JOIN"

    for r in refs:
        r_clean = (r or "").strip()
        if not r_clean:
            continue

        head = _normalizar_token(r_clean.split("(")[0]).strip('"')
        if head in _NO_ES_TABLA:
            continue

        if "." not in r_clean:
            name = _normalizar_token(r_clean)
            if name in nombres_cte:
                continue
            fqn_fmt = mapa_tablas.get(name)
            if not fqn_fmt:
                return f"tabla no encontrada en allow-list: {r_clean}"
            if _normalizar_token(fqn_fmt) not in allowed_set:
                return f"tabla fuera de allow-list: {r_clean} -> {fqn_fmt}"
            continue

        parts = [p.strip().strip('"').strip("[]") for p in r_clean.split(".")]
        if len(parts) != 2:
            return f"token schema.tabla inválido: {r_clean}"

        schema_n = parts[0].strip().lower()
        table_n = parts[1].strip()

        fqn_fmt = f"[{schema_n}].[{table_n}]" if es_mssql() else f'{schema_n}."{table_n}"'
        if _normalizar_token(fqn_fmt) not in allowed_set:
            return f"FQN fuera de allow-list: {r_clean} -> {fqn_fmt}"

    return None


def restringir_a_tablas_permitidas(sql: str, permitidos_fqn: List[str]) -> bool:
    s = limpiar_sql(sql)
    inner = desenvolver_explain(s) if es_explain(s) else s
    return _primera_ref_no_permitida(inner, permitidos_fqn) is None


_RE_CALIFICAR_FROM_JOIN = re.compile(
    r'\b(from|join)\s+("?[A-Za-z0-9_ ]+"?)(?!\s*\.)',
    re.IGNORECASE,
)


def calificar_tablas(sql: str, permitidos_fqn: List[str]) -> str:
    """Califica nombres de tabla sin schema usando la allow-list."""
    if not sql or not permitidos_fqn:
        return sql
    if es_solo_values(sql) or es_explain(sql):
        return sql

    nombres_cte = set(_recopilar_nombres_cte(sql))
    mapa_tablas = _construir_mapa_tablas(permitidos_fqn)

    def repl(match: re.Match) -> str:
        kw = match.group(1)
        raw_name = (match.group(2) or "").strip()
        name_unquoted = raw_name.replace('"', "").replace("[", "").replace("]", "").strip()
        name_low = name_unquoted.lower()

        if name_low in nombres_cte:
            return match.group(0)

        head = _normalizar_token(name_unquoted.split("(")[0]).strip('"')
        if head in _NO_ES_TABLA:
            return match.group(0)

        fqn = mapa_tablas.get(name_low)
        if fqn:
            return f"{kw} {fqn}"
        return match.group(0)

    return _RE_CALIFICAR_FROM_JOIN.sub(repl, sql)


qualify_tables = calificar_tablas  # legacy

# =============================================================================
# ✅ Auto-LEFT JOIN por FKs nullable (FIX definitivo para alias [T1]/[T2])
# =============================================================================

# Identificadores MSSQL y alias (permite [T1], [ComponentId], dbo, [dbo].[Table], etc.)
_ALIAS = r"(?:\[[^\]]+\]|\w+)"
_IDENT = r"(?:\[[^\]]+\]|\w+|\"[^\"]+\")"

_RE_FROM_JOIN_ALIAS = re.compile(
    rf"""
    \b(from|join)\s+
    (?P<table>{_IDENT}(?:\s*\.\s*{_IDENT})?)         # dbo.Table o [dbo].[Table] o Table
    (?:\s+as\s+(?P<alias>{_ALIAS})|\s+(?P<alias2>{_ALIAS}))?
    """,
    re.IGNORECASE | re.VERBOSE,
)

_RE_JOIN_ON2 = re.compile(
    rf"""
    (?P<jtype>\binner\s+join\b|\bleft\s+join\b|\bjoin\b)\s+
    (?P<table>{_IDENT}(?:\s*\.\s*{_IDENT})?)         # dbo.Table o [dbo].[Table] o Table
    (?:\s+as\s+(?P<alias>{_ALIAS})|\s+(?P<alias2>{_ALIAS}))?
    \s+on\s+
    (?P<left>{_ALIAS}\s*\.\s*{_IDENT})\s*=\s*(?P<right>{_ALIAS}\s*\.\s*{_IDENT})
    """,
    re.IGNORECASE | re.VERBOSE,
)


def _strip_ident(s: str) -> str:
    return (s or "").strip().strip("[]").strip('"').strip()


def _schema_nullable_map(esquema_json: Dict[str, Any]) -> Dict[Tuple[str, str], bool]:
    mp: Dict[Tuple[str, str], bool] = {}
    for tb in (esquema_json.get("tables") or []):
        tname = (tb.get("table") or "").strip().lower()
        for c in (tb.get("columns") or []):
            cname = (c.get("name") or "").strip().lower()
            if tname and cname:
                mp[(tname, cname)] = bool(c.get("nullable", True))
    return mp


def _alias_to_table_map(sql: str, esquema_json: Dict[str, Any]) -> Dict[str, str]:
    known_tables: Set[str] = {(t.get("table") or "").strip().lower() for t in (esquema_json.get("tables") or []) if t.get("table")}
    alias_map: Dict[str, str] = {}

    for m in _RE_FROM_JOIN_ALIAS.finditer(sql or ""):
        raw_table = m.group("table") or ""
        alias = (m.group("alias") or m.group("alias2") or "").strip()
        if not alias:
            continue

        # tabla sin schema
        t = raw_table.replace('"', "")
        t = t.replace("[", "").replace("]", "")
        t = t.split(".")[-1].strip().lower()

        a = _strip_ident(alias).lower()
        if t in known_tables:
            alias_map[a] = t

    return alias_map


def _col_from_ref(ref: str) -> Tuple[str, str]:
    # ref: [T2].[ComponentId] o T2.ComponentId
    a, c = ref.split(".", 1)
    a = _strip_ident(a).lower()
    c = _strip_ident(c).lower()
    return a, c


def preferir_left_join_por_nullable(sql: str, esquema_json: Dict[str, Any]) -> str:
    """
    Reescribe JOIN/INNER JOIN -> LEFT JOIN cuando el lado FK usado en el ON
    sea nullable según schema_json.

    Soporta aliases tipo [T1], [T2] y columnas en brackets.

    Nota:
    - Esto NO cambia el ON, solo el tipo de JOIN.
    - Si ya es LEFT JOIN, lo deja intacto.
    """
    if not sql or not esquema_json:
        return sql

    # feature flag opcional (por si deseas apagarlo rápido)
    if env("SQL_AUTO_LEFT_JOIN_NULLABLE", default=True, cast=bool) is False:
        return sql

    nullable_map = _schema_nullable_map(esquema_json)
    alias_map = _alias_to_table_map(sql, esquema_json)

    def repl(m: re.Match) -> str:
        jtype = (m.group("jtype") or "").lower()
        if "left join" in jtype:
            return m.group(0)

        left_ref = (m.group("left") or "").replace(" ", "")
        right_ref = (m.group("right") or "").replace(" ", "")

        aL, cL = _col_from_ref(left_ref)
        aR, cR = _col_from_ref(right_ref)

        tL = alias_map.get(aL)
        tR = alias_map.get(aR)

        is_nullable_L = bool(tL and (nullable_map.get((tL, cL)) is True))
        is_nullable_R = bool(tR and (nullable_map.get((tR, cR)) is True))

        if is_nullable_L or is_nullable_R:
            original = m.group(0)
            changed = re.sub(r"\b(inner\s+join|join)\b", "LEFT JOIN", original, count=1, flags=re.IGNORECASE)

            if changed != original:
                log.debug(
                    "[database.preferir_left_join_por_nullable] %s -> LEFT JOIN (nullable: %s.%s=%s, %s.%s=%s)",
                    (m.group("table") or "").strip(),
                    tL, cL, is_nullable_L,
                    tR, cR, is_nullable_R,
                )
            return changed

        return m.group(0)

    return _RE_JOIN_ON2.sub(repl, sql)

def _split_sql_top_level(s: str) -> List[str]:
    """
    Divide una lista SQL por comas de nivel superior.
    Ejemplo:
      a, COALESCE(b,c), SUM(d)  ->  ["a", "COALESCE(b,c)", "SUM(d)"]
    """
    if not s:
        return []

    partes: List[str] = []
    actual: List[str] = []
    profundidad = 0

    for ch in s:
        if ch == "(":
            profundidad += 1
            actual.append(ch)
        elif ch == ")":
            profundidad = max(0, profundidad - 1)
            actual.append(ch)
        elif ch == "," and profundidad == 0:
            item = "".join(actual).strip()
            if item:
                partes.append(item)
            actual = []
        else:
            actual.append(ch)

    item = "".join(actual).strip()
    if item:
        partes.append(item)

    return partes


_RE_RELACION_ALIAS_ORDEN = re.compile(
    rf"""
    \b(?P<kind>from|left\s+join|inner\s+join|join)\s+
    (?P<table>{_IDENT}(?:\s*\.\s*{_IDENT})?)     
    (?:\s+as\s+(?P<alias>{_ALIAS})|\s+(?P<alias2>{_ALIAS}))?
    """,
    re.IGNORECASE | re.VERBOSE,
)


def _extraer_relaciones_query(sql: str, esquema_json: Dict[str, Any]) -> List[Dict[str, Any]]:
    """
    Extrae relaciones en orden:
      FROM tabla alias
      JOIN tabla alias
    """
    conocidas = {
        (t.get("table") or "").strip().lower()
        for t in (esquema_json.get("tables") or [])
        if t.get("table")
    }

    relaciones: List[Dict[str, Any]] = []

    for idx, m in enumerate(_RE_RELACION_ALIAS_ORDEN.finditer(sql or "")):
        raw_table = (m.group("table") or "").replace("[", "").replace("]", "").replace('"', "")
        table_name = raw_table.split(".")[-1].strip().lower()

        alias_raw = (m.group("alias") or m.group("alias2") or "").strip()
        alias_name = _strip_ident(alias_raw).lower() if alias_raw else table_name

        if table_name in conocidas and alias_name:
            relaciones.append(
                {
                    "order": idx,
                    "kind": (m.group("kind") or "").lower(),
                    "alias": alias_name,
                    "table": table_name,
                }
            )

    return relaciones


def _columnas_texto_tabla(esquema_json: Dict[str, Any], table_name: str) -> List[str]:
    out: List[str] = []
    tname = (table_name or "").strip().lower()

    for tb in (esquema_json.get("tables") or []):
        if (tb.get("table") or "").strip().lower() != tname:
            continue
        for col in (tb.get("columns") or []):
            cname = (col.get("name") or "").strip()
            ctype = (col.get("type") or "").lower()
            if cname and any(x in ctype for x in ["char", "text", "varchar", "nvarchar", "string", "clob"]):
                out.append(cname)
        break

    return out


def _puntuar_columna_texto_descriptiva(nombre_columna: str) -> int:
    """
    Heurística genérica para preferir columnas descriptivas como fallback.
    """
    n = (nombre_columna or "").strip().lower()
    score = 0

    # muy buenas
    if any(x in n for x in ["name", "nombre"]):
        score += 100
    if any(x in n for x in ["description", "descripcion", "desc"]):
        score += 80

    # buenas
    if any(x in n for x in ["compart", "component", "equipment", "system", "sistema", "model", "modelo", "type", "tipo", "position", "project", "customer", "client", "cliente", "category", "categoria"]):
        score += 60

    # útiles, pero menos
    if any(x in n for x in ["code", "codigo"]):
        score += 40

    # malas para agrupar
    if any(x in n for x in ["observ", "recommend", "detail", "path", "mail", "email", "phone", "telefono"]):
        score -= 20

    # normalmente no deben usarse como etiqueta
    if any(x in n for x in ["id", "date", "fecha", "time", "hora", "count", "total", "avg", "sum", "metric", "value", "flag"]):
        score -= 60

    if n.endswith("id"):
        score -= 100

    return score


def _parse_alias_col_expr(expr: str) -> Optional[Tuple[str, str, str]]:
    """
    Parsea expresiones exactas tipo:
      c.ComponentName
      [c].[ComponentName]
      c.[ComponentName]
      [c].ComponentName

    Retorna:
      (alias_lower, col_lower, col_original)
    """
    m = re.match(
        rf"^\s*(?P<a>{_ALIAS})\s*\.\s*(?P<c>{_IDENT})\s*$",
        expr or "",
        flags=re.IGNORECASE,
    )
    if not m:
        return None

    alias_raw = _strip_ident(m.group("a")).lower()
    col_raw = _strip_ident(m.group("c"))
    return alias_raw, col_raw.lower(), col_raw


def _patron_alias_col(alias_norm: str, col_raw: str) -> str:
    """
    Regex para matchear:
      c.Col
      c.[Col]
      [c].Col
      [c].[Col]
    """
    a = re.escape(alias_norm)
    c = re.escape(col_raw)
    return (
        rf"(?:\[\s*{a}\s*\]|\b{a}\b)\s*\.\s*"
        rf"(?:\[\s*{c}\s*\]|\b{c}\b)"
    )


def _usuario_pide_estricto_consulta(consulta_humana: str) -> bool:
    q = (consulta_humana or "").lower()
    pistas = [
        "solo coincidencias",
        "solo matching",
        "excluir null",
        "sin null",
        "no null",
        "solo donde exista",
        "solo donde haya",
        "únicamente los que tengan",
        "solo los que tengan",
        "estricto",
        "exactamente",
        "obligatorio",
    ]
    return any(p in q for p in pistas)


def _elegir_fallbacks_genericos(
    sql: str,
    esquema_json: Dict[str, Any],
    relaciones: List[Dict[str, Any]],
    alias_objetivo: str,
    col_objetivo_lower: str,
) -> List[str]:
    """
    Elige hasta 2 columnas de texto descriptivas de tablas YA presentes en el query.
    No inventa tablas. Sí puede usar columnas del schema aunque no estén en SELECT.
    """
    target_rel = next((r for r in relaciones if r["alias"] == alias_objetivo), None)
    target_order = target_rel["order"] if target_rel else 10**9

    # Preferimos tablas anteriores al alias objetivo: fact table y puente
    candidatas_rel = [r for r in relaciones if r["alias"] != alias_objetivo and r["order"] < target_order]
    if not candidatas_rel:
        candidatas_rel = [r for r in relaciones if r["alias"] != alias_objetivo]

    candidatos: List[Tuple[int, int, str]] = []

    for rel in candidatas_rel:
        alias = rel["alias"]
        table = rel["table"]
        kind = rel["kind"]

        bonus_kind = 0
        if kind == "from":
            bonus_kind = 50
        elif "inner" in kind or kind == "join":
            bonus_kind = 40
        elif "left" in kind:
            bonus_kind = 20

        for col in _columnas_texto_tabla(esquema_json, table):
            if col.lower() == col_objetivo_lower:
                continue

            score = _puntuar_columna_texto_descriptiva(col) + bonus_kind
            if score <= 0:
                continue

            expr = f"[{alias}].[{col}]"
            candidatos.append((score, rel["order"], expr))

    candidatos.sort(key=lambda x: (-x[0], x[1], x[2].lower()))

    out: List[str] = []
    seen = set()
    for _, _, expr in candidatos:
        k = expr.lower()
        if k not in seen:
            out.append(expr)
            seen.add(k)
        if len(out) >= 2:
            break

    return out


def hacer_groupby_nullsafe_mssql(
    sql: str,
    esquema_json: Dict[str, Any],
    consulta_humana: str = "",
) -> str:
    """
    Reescritura determinística para MSSQL:

    Caso objetivo:
    - LEFT JOIN a una dimensión nullable/opcional
    - GROUP BY sobre campo del lado derecho
    - Resultado termina en grupo NULL o puede perder semántica

    Regla:
    - Si el usuario pidió estricto -> WHERE dim IS NOT NULL
    - Si no -> COALESCE(dim, fallback1, fallback2)
             + WHERE COALESCE(...) <> ''
             + GROUP BY la misma expresión
    """
    s = (sql or "").strip()
    if not s or not es_mssql():
        return s

    if " group by " not in f" {s.lower()} ":
        return s

    if " left join " not in f" {s.lower()} ":
        return s

    relaciones = _extraer_relaciones_query(s, esquema_json)
    if not relaciones:
        return s

    left_aliases = {r["alias"] for r in relaciones if "left" in r["kind"]}
    if not left_aliases:
        return s

    mg = re.search(
        r"\bgroup\s+by\s+(?P<g>.+?)(?=\border\s+by\b|\bhaving\b|$)",
        s,
        flags=re.IGNORECASE | re.DOTALL,
    )
    if not mg:
        return s

    group_chunk = mg.group("g").strip()
    exprs = _split_sql_top_level(group_chunk)

    target_idx = None
    target_alias = None
    target_col_lower = None
    target_col_raw = None

    for idx, expr in enumerate(exprs):
        parsed = _parse_alias_col_expr(expr)
        if not parsed:
            continue
        a_low, c_low, c_raw = parsed
        if a_low in left_aliases:
            target_idx = idx
            target_alias = a_low
            target_col_lower = c_low
            target_col_raw = c_raw
            break

    if target_idx is None or not target_alias or not target_col_lower or not target_col_raw:
        return s

    dim_expr = f"[{target_alias}].[{target_col_raw}]"

    if _usuario_pide_estricto_consulta(consulta_humana):
        filtro_estricto = f"{dim_expr} IS NOT NULL"

        if re.search(r"\bwhere\b", s, flags=re.IGNORECASE):
            s = re.sub(
                r"\bwhere\b",
                f"WHERE {filtro_estricto} AND",
                s,
                count=1,
                flags=re.IGNORECASE,
            )
        else:
            s = re.sub(
                r"\bgroup\s+by\b",
                f"WHERE {filtro_estricto} GROUP BY",
                s,
                count=1,
                flags=re.IGNORECASE,
            )
        return s

    fallbacks = _elegir_fallbacks_genericos(
        sql=s,
        esquema_json=esquema_json,
        relaciones=relaciones,
        alias_objetivo=target_alias,
        col_objetivo_lower=target_col_lower,
    )

    if not fallbacks:
        # fallback mínimo: filtrar null/blank para no devolver el grupo nulo
        filtro_min = f"COALESCE(LTRIM(RTRIM(CAST({dim_expr} AS NVARCHAR(4000)))), '') <> ''"
        if re.search(r"\bwhere\b", s, flags=re.IGNORECASE):
            s = re.sub(
                r"\bwhere\b",
                f"WHERE {filtro_min} AND",
                s,
                count=1,
                flags=re.IGNORECASE,
            )
        else:
            s = re.sub(
                r"\bgroup\s+by\b",
                f"WHERE {filtro_min} GROUP BY",
                s,
                count=1,
                flags=re.IGNORECASE,
            )
        return s

    expr_coalesce = f"COALESCE({dim_expr}, {', '.join(fallbacks)})"

    # 1) Reescribir GROUP BY
    exprs[target_idx] = expr_coalesce
    new_group_chunk = ", ".join(exprs)
    s = s[:mg.start("g")] + new_group_chunk + s[mg.end("g"):]

    # 2) Reescribir SELECT para que la dimensión proyectada coincida con el GROUP BY
    ms = re.search(
        r"^\s*select\s+(?P<body>.+?)\bfrom\b",
        s,
        flags=re.IGNORECASE | re.DOTALL,
    )
    if ms:
        body = ms.group("body")
        pat_dim = _patron_alias_col(target_alias, target_col_raw)

        body_new = re.sub(
            pat_dim + r"(?:\s+as\s+(?:\[[^\]]+\]|\w+))?",
            f"{expr_coalesce} AS [{target_col_raw}]",
            body,
            count=1,
            flags=re.IGNORECASE,
        )

        if body_new != body:
            s = s[:ms.start("body")] + body_new + s[ms.end("body"):]

    # 3) Evitar grupo vacío / null total
    filtro = f"COALESCE(LTRIM(RTRIM(CAST({expr_coalesce} AS NVARCHAR(4000)))), '') <> ''"
    if re.search(r"\bwhere\b", s, flags=re.IGNORECASE):
        s = re.sub(
            r"\bwhere\b",
            f"WHERE {filtro} AND",
            s,
            count=1,
            flags=re.IGNORECASE,
        )
    else:
        s = re.sub(
            r"\bgroup\s+by\b",
            f"WHERE {filtro} GROUP BY",
            s,
            count=1,
            flags=re.IGNORECASE,
        )

    log.debug("[database.hacer_groupby_nullsafe_mssql] SQL reescrita con COALESCE.")
    return s

# =============================================================================
# Ejecución
# =============================================================================

def consultar(
    sql_query: str,
    permitidos_fqn: List[str],
    limite_por_defecto: int = 100,
    limite_maximo: int = 1000,
) -> List[Dict[str, Any]]:
    """
    Ejecuta consulta solo-lectura de forma segura:
    - Limpia SQL
    - Expande macros (solo Postgres)
    - Sanitiza EXPLAIN
    - Califica tablas
    - Valida lectura y allow-list
    - Aplica límite por defecto (TOP/LIMIT)
    """
    log.debug("[database.consultar] raw=%r", (sql_query or "")[:500])

    sql_query = limpiar_sql(sql_query)
    sql_query = expandir_macros(sql_query)
    sql_query = sanear_explain(sql_query)
    sql_query = calificar_tablas(sql_query, permitidos_fqn)

    if not es_select_seguro(sql_query):
        raise ValueError("Solo se permiten consultas de lectura (SELECT/CTE, EXPLAIN permitido, VALUES).")

    val_sql = desenvolver_explain(sql_query) if es_explain(sql_query) else sql_query

    bad = _primera_ref_no_permitida(val_sql, permitidos_fqn)
    if (not es_solo_values(sql_query)) and bad:
        raise ValueError(f"La consulta referencia tablas no permitidas. Detalle: {bad}")

    if (not es_solo_values(sql_query)) and (not es_explain(sql_query)):
        sql_final = forzar_limit(val_sql, limite_por_defecto=limite_por_defecto, limite_maximo=limite_maximo)
    else:
        sql_final = sql_query

    log.debug("[database.consultar] final=%r", sql_final[:800])

    with Session() as session:
        result = session.execute(text(sql_final))
        rows = result.mappings().all()
        return [dict(r) for r in rows]


# Alias legacy
query = consultar


def limpiar_recursos() -> None:
    """Libera conexiones del pool."""
    engine.dispose()