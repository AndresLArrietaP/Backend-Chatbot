# src/database.py
from typing import Any, List, Dict, Optional, Tuple
from decouple import config as env
import re
import logging

from sqlalchemy import create_engine, inspect
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import QueuePool
from sqlalchemy.sql import text

logger = logging.getLogger(__name__)

# --- conexión / flags ---
DATABASE_URL = (env("DATABASE_URL", default=None) or "").strip()
if not DATABASE_URL:
    raise RuntimeError("Falta la variable de entorno DATABASE_URL.")

ALLOW_SQL_EXPLAIN: bool = env("ALLOW_SQL_EXPLAIN", default=True, cast=bool)
ALLOW_EXPLAIN_ANALYZE: bool = env("ALLOW_EXPLAIN_ANALYZE", default=False, cast=bool)
ALLOW_SQL_VALUES: bool = env("ALLOW_SQL_VALUES", default=True, cast=bool)
ALLOW_SQL_CALL: bool = env("ALLOW_SQL_CALL", default=False, cast=bool)

engine = create_engine(
    DATABASE_URL,
    connect_args={"sslmode": "require"},
    poolclass=QueuePool,
    pool_size=5,
    max_overflow=10,
    pool_pre_ping=True,
)
Session = sessionmaker(bind=engine)

# --- esquema con caché ---
_SCHEMA_CACHE: Dict[Tuple[Tuple[str, ...], Tuple[str, ...]], Dict[str, Any]] = {}

def _norm_seq(seq: Optional[List[str]]) -> Tuple[str, ...]:
    if not seq:
        return tuple()
    return tuple(sorted({s.strip() for s in seq if s and s.strip()}))

def get_schema_json(
    schemas: Optional[List[str]] = None,
    tables: Optional[List[str]] = None,
    max_tables: int = 50,
    max_columns: int = 2000,
) -> Dict[str, Any]:
    key = (_norm_seq(schemas), _norm_seq(tables))
    if key in _SCHEMA_CACHE:
        return _SCHEMA_CACHE[key]

    inspector = inspect(engine)
    chosen_schemas = list(key[0]) if key[0] else inspector.get_schema_names()

    out_tables: List[Dict[str, Any]] = []
    col_count = 0

    for sch in chosen_schemas:
        tnames = inspector.get_table_names(schema=sch)
        if key[1]:
            tnames = [t for t in tnames if t in key[1]]
        for t in tnames:
            cols_meta = inspector.get_columns(t, schema=sch)
            cols = []
            for c in cols_meta:
                cols.append({
                    "name": c["name"],
                    "type": str(c["type"]),
                    "nullable": bool(c.get("nullable", True)),
                })
            out_tables.append({
                "schema": sch,
                "table": t,
                "fq_name": f'{sch}."{t}"',
                "columns": cols,
            })
            col_count += len(cols)
            if len(out_tables) >= max_tables or col_count >= max_columns:
                break
        if len(out_tables) >= max_tables or col_count >= max_columns:
            break

    result = {"tables": out_tables}
    _SCHEMA_CACHE[key] = result
    return result

def refresh_schema_cache() -> None:
    _SCHEMA_CACHE.clear()

# -------- Limpieza --------

_CODE_FENCE_RE = re.compile(r"^\s*```(?:sql|postgresql)?\s*|\s*```\s*$", re.IGNORECASE | re.MULTILINE)

def _strip_code_fences(s: str) -> str:
    return _CODE_FENCE_RE.sub("", s or "")

def _strip_sql_comments(s: str) -> str:
    s = re.sub(r"--.*?$", "", s, flags=re.MULTILINE)
    s = re.sub(r"/\*.*?\*/", "", s, flags=re.DOTALL)
    return s

def clean_sql(sql: str) -> str:
    s = sql or ""
    s = _strip_code_fences(s)
    s = _strip_sql_comments(s)
    s = s.strip()
    s = re.sub(r"^(sql|query)\s*:\s*", "", s, flags=re.IGNORECASE).strip()
    if s.endswith(";"):
        s = s[:-1].strip()
    logger.debug("[database.clean_sql] IN: %r", sql)
    logger.debug("[database.clean_sql] OUT: %r", s)
    return s

# -------- Macros --------

# NUMERIC_CLEAN: heurística de miles/decimales + casos mixtos
_NUMERIC_CLEAN_MACRO = re.compile(r'NUMERIC_CLEAN\(\s*(".*?")\s*\)', re.IGNORECASE | re.DOTALL)

def expand_numeric_clean(sql: str) -> str:
    """
    NUMERIC_CLEAN("Col") -> ::numeric robusto sin usar CTE dentro de expresiones.
      - US: 1,234.56
      - EU: 1.234,56
      - Enteros con miles: 114,303 / 114.303
      - Mixtos: 114,303.000
      - Caso especial: '0.284' (punto como miles) -> 284
      - Fallback: quita todo salvo dígitos y punto
    """
    def repl(m: re.Match) -> str:
        col = m.group(1)
        s = f"TRIM({col})"
        return f"""
        (
          COALESCE(
            NULLIF(
              CASE
                WHEN {s} IS NULL OR {s} = '' THEN NULL

                -- US: 1,234.56  -> quitar comas
                WHEN {s} ~ '^[0-9]{{1,3}}(,[0-9]{{3}})+(\\.[0-9]+)?$'
                  THEN REPLACE({s}, ',', '')

                -- EU: 1.234,56  -> quitar puntos de miles, coma -> punto
                WHEN {s} ~ '^[0-9]{{1,3}}(\\.[0-9]{{3}})+(,[0-9]+)?$'
                  THEN REPLACE(REPLACE({s}, '.', ''), ',', '.')

                -- Solo coma decimal (sin puntos)
                WHEN {s} ~ '^[0-9]+,[0-9]+$'
                  THEN REPLACE({s}, ',', '.')

                -- Entero con un punto 'X.XXX' -> quita el punto (era miles)
                WHEN {s} ~ '^[0-9]+\\.[0-9]{{3}}$'
                  THEN REPLACE({s}, '.', '')

                -- Múltiples puntos -> deja solo el último (decimal real)
                WHEN {s} ~ '^[0-9.]+$' AND LENGTH({s})-LENGTH(REPLACE({s},'.','')) > 1
                  THEN REGEXP_REPLACE({s}, '\\.(?=.*\\.)', '', 'g')

                -- Mezclas coma+punto: asume el último como decimal
                WHEN {s} ~ '[0-9],[0-9]' AND {s} ~ '[0-9]\\.[0-9]'
                  THEN CASE
                         WHEN {s} ~ ',\\d+\\s*$' THEN REPLACE(REPLACE({s}, '.', ''), ',', '.')
                         ELSE REPLACE({s}, ',', '')
                       END

                -- Fallback: limpiar todo salvo dígitos y punto (unificar coma->punto)
                ELSE REGEXP_REPLACE(REPLACE({s}, ',', '.'), '[^0-9.]', '', 'g')
              END,
              ''
            )::numeric,
            0
          )
        )
        """
    return _NUMERIC_CLEAN_MACRO.sub(repl, sql or "")

# DATE_PARSE: parseo robusto de TEXT->DATE (formatos mixtos)
_DATE_PARSE_MACRO = re.compile(r'DATE_PARSE\(\s*(".*?")\s*\)', re.IGNORECASE | re.DOTALL)

def expand_date_parse(sql: str) -> str:
    """
    Expande DATE_PARSE("Col") a una expresión CASE que intenta varios formatos:
      - YYYY-MM-DD (con o sin hora/sufijo)
      - DD/MM/YYYY
      - DD-MM-YYYY
      - DD.MM.YYYY
    Si no matchea, devuelve NULL.
    """
    def repl(m: re.Match) -> str:
        col = m.group(1)  # "Col"
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
    return _DATE_PARSE_MACRO.sub(repl, sql or "")

def expand_macros(sql: str) -> str:
    """Aplica todas las macros soportadas en orden seguro."""
    s = sql or ""
    s2 = expand_numeric_clean(s)
    s3 = expand_date_parse(s2)
    if s3 != s:
        logger.debug("[database.expand_macros] macros expanded.")
    return s3

# -------- Clasificación / Seguridad --------

_EXPLAIN_RE = re.compile(r"^\s*explain\b", re.IGNORECASE)
_EXPLAIN_ANALYZE_RE = re.compile(r"^\s*explain\b.*\banalyze\b", re.IGNORECASE | re.DOTALL)
_VALUES_RE = re.compile(r"^\s*values\s*\(", re.IGNORECASE)
_SELECT_RE = re.compile(r"^\s*(WITH\b.+\bSELECT|SELECT)\b", re.IGNORECASE | re.DOTALL)

def is_values_only(sql: str) -> bool:
    return bool(_VALUES_RE.match(sql or ""))

def is_explain(sql: str) -> bool:
    return bool(_EXPLAIN_RE.match(sql or ""))

def unwrap_explain(sql: str) -> str:
    if not is_explain(sql):
        return sql
    s = sql.strip()
    s = re.sub(r"^\s*explain\b(?:\s+\w+(?:\s+\w+)*)*\s*", "", s, flags=re.IGNORECASE)
    return s.strip()

# --- EXPLAIN sanitization: quitar ANALYZE (y otras) si no está permitido ---
_EXPLAIN_OPTIONS_RE = re.compile(r'^\s*explain\s*\((?P<opts>[^)]*)\)\s*', re.IGNORECASE | re.DOTALL)

def _sanitize_explain(sql: str, allow_analyze: bool) -> str:
    """
    Si es EXPLAIN y allow_analyze=False:
      - Si trae opciones (ANALYZE, BUFFERS, TIMING, COSTS...), las elimina dejando EXPLAIN simple.
      - Si trae 'ANALYZE' explícito (con o sin opciones), lo quita.
    Devuelve el SQL saneado.
    """
    s = sql or ""
    if not is_explain(s):
        return s

    if allow_analyze:
        return s  # no tocar

    # 1) Si es del tipo EXPLAIN ( ... ) SELECT ...
    m = _EXPLAIN_OPTIONS_RE.match(s)
    if m:
        # Reemplazamos EXPLAIN (opciones) por EXPLAIN simple
        s2 = _EXPLAIN_OPTIONS_RE.sub("EXPLAIN ", s, count=1)
        return s2

    # 2) Si es EXPLAIN ANALYZE SELECT ...  -> quitar ANALYZE
    s2 = re.sub(r'^\s*explain\s+analyze\b', 'EXPLAIN', s, flags=re.IGNORECASE)
    return s2

def sanitize_explain(sql: str) -> str:
    """Wrapper público para saneo de EXPLAIN según ALLOW_EXPLAIN_ANALYZE (.env)."""
    return _sanitize_explain(sql, allow_analyze=ALLOW_EXPLAIN_ANALYZE)

# Tokens peligrosos como palabras completas (ignorando literales)
_SINGLE_QUOTED_RE = re.compile(r"('([^']|'')*')", re.DOTALL)
_DOLLAR_QUOTED_RE = re.compile(r"(\$\$.*?\$\$)", re.DOTALL)

def _mask_string_literals(sql: str) -> str:
    s = sql or ""
    s = _DOLLAR_QUOTED_RE.sub("$$''$$", s)
    s = _SINGLE_QUOTED_RE.sub("''", s)
    return s

_base_forbidden = [
    r"\bDROP\b", r"\bDELETE\b", r"\bTRUNCATE\b", r"\bALTER\b",
    r"\bINSERT\b", r"\bUPDATE\b", r"\bCREATE\b", r"\bMERGE\b",
    r"\bVACUUM\b", r"\bCOPY\b", r"\bGRANT\b", r"\bREVOKE\b",
]
if not ALLOW_SQL_CALL:
    _base_forbidden.append(r"\bCALL\b")
_FORBIDDEN_PATTERNS = [re.compile(pat, re.IGNORECASE) for pat in _base_forbidden]

def _contains_forbidden(sql: str) -> Optional[str]:
    s = _mask_string_literals(sql or "")
    for pat in _FORBIDDEN_PATTERNS:
        if pat.search(s):
            return pat.pattern
    return None

def find_forbidden_tokens(sql: str) -> List[str]:
    hits: List[str] = []
    s = _mask_string_literals(sql or "")
    for pat in _FORBIDDEN_PATTERNS:
        if pat.search(s):
            hits.append(pat.pattern)
    return hits

def is_safe_select(sql: str) -> bool:
    s = sql or ""

    if is_values_only(s):
        bad = _contains_forbidden(s)
        ok = ALLOW_SQL_VALUES and (bad is None)
        logger.debug("[database.is_safe_select] VALUES -> %s (bad=%s)", ok, bad)
        return ok

    if is_explain(s):
        if not ALLOW_SQL_EXPLAIN:
            logger.debug("[database.is_safe_select] EXPLAIN no permitido")
            return False
        if _EXPLAIN_ANALYZE_RE.match(s) and not ALLOW_EXPLAIN_ANALYZE:
            logger.debug("[database.is_safe_select] EXPLAIN ANALYZE no permitido")
            return False
        inner = unwrap_explain(s)
        bad = _contains_forbidden(inner)
        ok = (_SELECT_RE.match(inner or "") is not None) and (bad is None)
        logger.debug("[database.is_safe_select] EXPLAIN(inner) -> %s (bad=%s)", ok, bad)
        return ok

    if not _SELECT_RE.match(s or ""):
        logger.debug("[database.is_safe_select] No es SELECT/CTE")
        return False

    bad = _contains_forbidden(s)
    ok = (bad is None)
    logger.debug("[database.is_safe_select] SELECT -> %s (bad=%s)", ok, bad)
    return ok

def enforce_limit(sql: str, default_limit: int = 100, max_limit: int = 1000) -> str:
    m = re.search(r"\blimit\s+(\d+)\b", sql, re.IGNORECASE)
    if m:
        n = int(m.group(1))
        if n > max_limit:
            sql = re.sub(r"\blimit\s+\d+\b", f"LIMIT {max_limit}", sql, flags=re.IGNORECASE)
        return sql
    return f"{sql.rstrip()} LIMIT {default_limit}"

# --- utilidades de tablas referenciadas ---
_FROM_JOIN_CAPTURE = re.compile(
    r'\b(from|join)\s+((?:"[^"]+"|\w+)(?:\s*\.\s*(?:"[^"]+"|\w+))?)',
    re.IGNORECASE
)

def _build_table_map(allowed_fqn: List[str]) -> Dict[str, str]:
    m: Dict[str, str] = {}
    for f in allowed_fqn:
        schema, _, table = f.partition(".")
        table_name = table.replace('"', '').strip()
        key = table_name.lower()
        if key not in m:
            m[key] = f'{schema.strip()}."{table_name}"'
    return m

def _extract_referenced_tables(sql: str) -> List[str]:
    """
    Devuelve una lista de tokens de tabla tal como aparecen en el SQL
    (pueden venir cualificadas o no).
    """
    refs: List[str] = []
    for match in _FROM_JOIN_CAPTURE.finditer(sql or ""):
        raw = match.group(2).strip()
        refs.append(raw)
    return refs

# --- CTE support: recolectar nombres de CTE definidos en WITH ---
_CTE_FIRST_RE = re.compile(r'\bwith\s+("?[A-Za-z0-9_ ]+"?)\s+as\s*\(', re.IGNORECASE)
_CTE_NEXT_RE  = re.compile(r',\s*("?[A-Za-z0-9_ ]+"?)\s+as\s*\(', re.IGNORECASE)

def _collect_cte_names(sql: str) -> List[str]:
    """
    Devuelve los nombres de CTE (identificadores del WITH ... AS (...), incluyendo los separados por comas).
    Ej.: WITH b AS (...), t2 AS (...)  -> ['b', 't2']
    """
    names: List[str] = []
    s = sql or ""
    for m in _CTE_FIRST_RE.finditer(s):
        nm = m.group(1).strip().strip('"')
        if nm:
            names.append(nm.lower())
    for m in _CTE_NEXT_RE.finditer(s):
        nm = m.group(1).strip().strip('"')
        if nm:
            names.append(nm.lower())
    return names

def restrict_to_allowed_tables(sql: str, allowed_fqn: List[str]) -> bool:
    """
    Devuelve True SOLO si todas las tablas reales referenciadas en FROM/JOIN
    pertenecen al conjunto permitido. Ignora referencias a CTEs (definidos en WITH).
    """
    if not sql or not allowed_fqn:
        return False
    if is_values_only(sql):
        return True

    s = unwrap_explain(sql) if is_explain(sql) else (sql or "")

    allowed_set = {a.strip().lower() for a in allowed_fqn}
    table_map = _build_table_map(allowed_fqn)

    # Nombres de CTE definidos en este SQL
    cte_names = set(_collect_cte_names(s))

    refs = _extract_referenced_tables(s)
    if not refs:
        # No encontramos FROM/JOIN -> por seguridad, negar
        return False

    for r in refs:
        r_clean = r.strip()

        # Nombre sin cualificar
        if "." not in r_clean:
            name = r_clean.strip().strip('"').lower()
            # Si es CTE, permitido
            if name in cte_names:
                continue
            # Sino, debe mapear a una tabla física permitida
            fqn_norm = table_map.get(name)
            if not fqn_norm or fqn_norm.lower() not in allowed_set:
                return False
            continue

        # Nombre cualificado schema.table
        parts = [p.strip().strip('"') for p in r_clean.split(".")]
        if len(parts) == 2:
            schema_n, table_n = parts[0].lower(), parts[1]
            fqn_norm = f'{schema_n}."{table_n}"'
            if fqn_norm.lower() not in allowed_set:
                return False
        else:
            # Algo raro (triple punto, etc.)
            return False

    return True

# --- Cualificación ---
_FROM_JOIN_RE = re.compile(r'\b(from|join)\s+("?[A-Za-z0-9_ ]+"?)(?!\s*\.)', re.IGNORECASE)

def qualify_tables(sql: str, allowed_fqn: List[str]) -> str:
    if not sql or not allowed_fqn:
        return sql
    if is_values_only(sql) or is_explain(sql):
        return sql

    table_map = _build_table_map(allowed_fqn)

    def repl(match: re.Match) -> str:
        kw = match.group(1)
        raw_name = match.group(2).strip()
        name_unquoted = raw_name.replace('"', '').strip()
        fqn = table_map.get(name_unquoted.lower())
        if fqn:
            return f"{kw} {fqn}"
        return match.group(0)

    return _FROM_JOIN_RE.sub(repl, sql)

# -------- Ejecución --------
async def query(
    sql_query: str,
    allowed_fqn: List[str],
    default_limit: int = 100,
    max_limit: int = 1000,
) -> List[Dict[str, Any]]:
    logger.debug("[database.query] raw=%r", sql_query)

    # 0) limpieza
    sql_query = clean_sql(sql_query)
    logger.debug("[database.query] after clean=%r", sql_query)

    # 0.25) expandir macros (NUMERIC_CLEAN, DATE_PARSE)
    sql_query = expand_macros(sql_query)
    
    # 0.4) Saneador de EXPLAIN: bajar a EXPLAIN simple si ANALYZE no está permitido
    sql_query = sanitize_explain(sql_query)
    logger.debug("[database.query] after explain sanitize=%r", sql_query)

    # 0.5) cualificación automática (no para EXPLAIN/VALUES)
    sql_query = qualify_tables(sql_query, allowed_fqn)
    logger.debug("[database.query] after qualify=%r", sql_query)

    # 1) seguridad
    if not is_safe_select(sql_query):
        raise ValueError("Solo se permiten consultas de lectura (SELECT/CTE, EXPLAIN sin ANALYZE, VALUES).")

    val_sql = unwrap_explain(sql_query) if is_explain(sql_query) else sql_query

    if not is_values_only(sql_query) and not restrict_to_allowed_tables(val_sql, allowed_fqn):
        raise ValueError("La consulta referencia tablas no permitidas según el esquema actual.")

    # 2) límite (solo SELECT/CTE)
    if (not is_values_only(sql_query)) and (not is_explain(sql_query)):
        sql = enforce_limit(val_sql, default_limit=default_limit, max_limit=max_limit)
    else:
        sql = sql_query

    logger.debug("[database.query] final SQL=%r", sql)

    # 3) ejecutar
    with Session() as session:
        statement = text(sql)
        result = session.execute(statement)
        return [dict(row._mapping) for row in result]

def cleanup() -> None:
    engine.dispose()