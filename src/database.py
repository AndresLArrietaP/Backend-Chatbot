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

# --- conexión / flags (tu configuración actual) ---
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

# -------- Limpieza y expansión de macros --------

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

# # --- Macro: NUMERIC_CLEAN("Col") -> expansión segura y bien parentizada ---
# _NUMERIC_CLEAN_MACRO = re.compile(r'NUMERIC_CLEAN\(\s*(".*?")\s*\)', re.IGNORECASE | re.DOTALL)

# def expand_numeric_clean(sql: str) -> str:
#     """
#     Expande NUMERIC_CLEAN("Col") a una expresión robusta que:
#       - Normaliza ',' -> '.' (cubre casos US y EU)
#       - Convierte '(123)' en '-123'
#       - Elimina todo lo no numérico salvo '.' y '-'
#       - Conserva SÓLO el último '.' como separador decimal
#       - Castea a numeric y aplica COALESCE(..., 0)
#     """
#     def repl(m: re.Match) -> str:
#         col = m.group(1)  # incluye comillas: "Col"
#         # Nota: usamos cadenas SQL con escapes dobles para que Postgres reciba
#         #       los backslashes correctos en los patrones regex.
#         return (
#             "("
#             "COALESCE("
#                 "NULLIF("
#                     "REGEXP_REPLACE("
#                         "REGEXP_REPLACE("
#                             f"REGEXP_REPLACE(REPLACE(TRIM({col}), ',', '.'), '^\\((.*)\\)$', '-\\\\1'), "
#                             "'[^0-9\\\\.\\\\-]', '', 'g'"
#                         "), "
#                         "'\\\\.(?=.*\\\\.)', '', 'g'"
#                     "), "
#                     "''"
#                 ")::numeric, "
#                 "0"
#             ")"
#             ")"
#         )
#     out = _NUMERIC_CLEAN_MACRO.sub(repl, sql or "")
#     if out != sql:
#         logger.debug("[database.expand_numeric_clean] macro expanded.")
#     return out

# --- Macro: NUMERIC_CLEAN("Col") -> expansión robusta con heurística miles ---
_NUMERIC_CLEAN_MACRO = re.compile(r'NUMERIC_CLEAN\(\s*(".*?")\s*\)', re.IGNORECASE | re.DOTALL)

def expand_numeric_clean(sql: str) -> str:
    """
    Expande NUMERIC_CLEAN("Col") a una expresión robusta que:
      - Si tiene miles con coma (ej: 12,345 o 12,345,678.90): quita comas.
      - Si tiene miles con punto y coma decimal (ej: 1.234,56): quita puntos, coma->punto.
      - En otros casos: coma->punto.
      - Convierte '(123)' en '-123'.
      - Elimina todo lo no [0-9 . -].
      - Conserva solo el ÚLTIMO '.' como decimal.
      - ::numeric y COALESCE(...,0).
    """
    def repl(m: re.Match) -> str:
        col = m.group(1)  # incluye comillas: "Col"

        # Normaliza paréntesis negativos sobre el TRIM(col)
        neg = (
            f"REGEXP_REPLACE(TRIM({col}), '^\\((.*)\\)$', '-\\\\1')"
        )

        # Patron 1: miles con COMA (p.ej. 12,345 o 12,345,678.90)
        pat_comma_thousands = f"TRIM({col}) ~ '^\\s*-?\\d{{1,3}}(,\\d{{3}})+(\\.\\d+)?\\s*$'"

        # Patron 2: miles con PUNTO y coma DECIMAL (p.ej. 1.234,56)
        pat_dot_thousands_comma_decimal = f"TRIM({col}) ~ '^\\s*-?\\d{{1,3}}(\\.\\d{{3}})+(,\\d+)?\\s*$'"

        # CASE para normalizar coma/punto según patrones
        case_normalize = (
            "("
            "CASE "
                f"WHEN {pat_comma_thousands} "
                f"THEN REGEXP_REPLACE({neg}, ',', '', 'g') "
                f"WHEN {pat_dot_thousands_comma_decimal} "
                f"THEN REPLACE(REGEXP_REPLACE({neg}, '\\\\.', '', 'g'), ',', '.') "
                f"ELSE REPLACE({neg}, ',', '.') "
            "END"
            ")"
        )

        # Limpieza de caracteres no numéricos
        clean_non_numeric = (
            f"REGEXP_REPLACE({case_normalize}, '[^0-9\\\\.\\\\-]', '', 'g')"
        )

        # Mantener solo el ÚLTIMO punto como decimal
        keep_last_dot = (
            f"REGEXP_REPLACE({clean_non_numeric}, '\\\\.(?=.*\\\\.)', '', 'g')"
        )

        # Ensamblado final con ::numeric y COALESCE
        return (
            "("
            "COALESCE("
                f"NULLIF({keep_last_dot}, '' )::numeric, "
                "0"
            ")"
            ")"
        )

    out = _NUMERIC_CLEAN_MACRO.sub(repl, sql or "")
    if out != sql:
        logger.debug("[database.expand_numeric_clean] macro expanded (robust).")
    return out
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

def restrict_to_allowed_tables(sql: str, allowed_fqn: List[str]) -> bool:
    """
    Devuelve True SOLO si **todas** las tablas referenciadas en FROM/JOIN
    pertenecen al conjunto permitido.
    """
    if not sql or not allowed_fqn:
        return False
    if is_values_only(sql):
        return True

    s = unwrap_explain(sql) if is_explain(sql) else sql

    allowed_set = {a.strip().lower() for a in allowed_fqn}
    table_map = _build_table_map(allowed_fqn)

    refs = _extract_referenced_tables(s)
    if not refs:
        # Si no detectamos tablas (consulta trivial), negar por seguridad.
        return False

    for r in refs:
        r_clean = r.strip()
        if "." in r_clean:
            # Puede venir como schema."table" o schema.table o "schema"."table"
            # Normalizamos: schema sin comillas + "table" con comillas
            parts = [p.strip().strip('"') for p in r_clean.split(".")]
            if len(parts) == 2:
                schema_n = parts[0].lower()
                table_n = parts[1]
                fqn_norm = f'{schema_n}."{table_n}"'
                if fqn_norm.lower() not in allowed_set:
                    return False
            else:
                # Formato raro -> rechazamos
                return False
        else:
            # No cualificada: buscamos en el map
            table_n = r_clean.strip().strip('"')
            fqn_norm = table_map.get(table_n.lower())
            if not fqn_norm or fqn_norm.lower() not in allowed_set:
                return False

    return True

# --- Cualificación (igual que antes, mantenemos) ---
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

    # 0.25) expandir macros (NUMERIC_CLEAN)
    sql_query = expand_numeric_clean(sql_query)
    logger.debug("[database.query] after expand numeric macro=%r", sql_query)

    # 0.5) cualificación auto (no para EXPLAIN/VALUES)
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