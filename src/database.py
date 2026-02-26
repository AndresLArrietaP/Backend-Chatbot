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
                cols.append(
                    {
                        "name": c["name"],
                        "type": str(c["type"]),
                        "nullable": bool(c.get("nullable", True)),
                    }
                )
            out_tables.append(
                {
                    "schema": sch,
                    "table": t,
                    "fq_name": f'{sch}."{t}"',
                    "columns": cols,
                }
            )
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

_CODE_FENCE_RE = re.compile(
    r"^\s*```(?:sql|postgresql)?\s*|\s*```\s*$", re.IGNORECASE | re.MULTILINE
)


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

_NUMERIC_CLEAN_MACRO = re.compile(
    r"NUMERIC_CLEAN\(\s*([^)]+?)\s*\)", re.IGNORECASE | re.DOTALL
)


def expand_numeric_clean(sql: str) -> str:
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
    return _NUMERIC_CLEAN_MACRO.sub(repl, sql or "")


_DATE_PARSE_MACRO = re.compile(r"DATE_PARSE\(\s*([^)]+?)\s*\)", re.IGNORECASE | re.DOTALL)


def expand_date_parse(sql: str) -> str:
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
    return _DATE_PARSE_MACRO.sub(repl, sql or "")


def expand_macros(sql: str) -> str:
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


_EXPLAIN_OPTIONS_RE = re.compile(r"^\s*explain\s*\((?P<opts>[^)]*)\)\s*", re.IGNORECASE | re.DOTALL)


def _sanitize_explain(sql: str, allow_analyze: bool) -> str:
    s = sql or ""
    if not is_explain(s):
        return s
    if allow_analyze:
        return s
    m = _EXPLAIN_OPTIONS_RE.match(s)
    if m:
        return _EXPLAIN_OPTIONS_RE.sub("EXPLAIN ", s, count=1)
    return re.sub(r"^\s*explain\s+analyze\b", "EXPLAIN", s, flags=re.IGNORECASE)


def sanitize_explain(sql: str) -> str:
    return _sanitize_explain(sql, allow_analyze=ALLOW_EXPLAIN_ANALYZE)


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


def is_safe_select(sql: str) -> bool:
    s = sql or ""

    if is_values_only(s):
        bad = _contains_forbidden(s)
        return ALLOW_SQL_VALUES and (bad is None)

    if is_explain(s):
        if not ALLOW_SQL_EXPLAIN:
            return False
        if _EXPLAIN_ANALYZE_RE.match(s) and not ALLOW_EXPLAIN_ANALYZE:
            return False
        inner = unwrap_explain(s)
        bad = _contains_forbidden(inner)
        return (_SELECT_RE.match(inner or "") is not None) and (bad is None)

    if not _SELECT_RE.match(s or ""):
        return False

    bad = _contains_forbidden(s)
    return bad is None


def enforce_limit(sql: str, default_limit: int = 100, max_limit: int = 1000) -> str:
    m = re.search(r"\blimit\s+(\d+)\b", sql, re.IGNORECASE)
    if m:
        n = int(m.group(1))
        if n > max_limit:
            sql = re.sub(r"\blimit\s+\d+\b", f"LIMIT {max_limit}", sql, flags=re.IGNORECASE)
        return sql
    return f"{sql.rstrip()} LIMIT {default_limit}"


# =========================
# ✅ FIX REAL DEL PROBLEMA
# =========================

# 1) Ignorar "FROM" dentro de funciones como SUBSTRING(... FROM 'regex')
#    y solo capturar FROM/JOIN reales (cláusulas).
# Heurística: requiere que lo que siga parezca un identificador de tabla (no comilla simple).
_FROM_JOIN_CLAUSE_RE = re.compile(
    r"""
    (?<!\w)                 # no parte de otra palabra
    \b(from|join)\b         # keyword
    \s+                     # espacios
    (?!')                   # <-- IMPORTANTE: si empieza con comilla simple, es SUBSTRING... FROM '...'
    (?P<tbl>
        (?:"[^"]+"|\w+)     # "tabla" o tabla
        (?:\s*\.\s*(?:"[^"]+"|\w+))?   # opcional schema.tabla
    )
    """,
    re.IGNORECASE | re.VERBOSE,
)

_NOT_A_TABLE = {"lateral", "unnest", "generate_series", "values"}


def _normalize_token(s: str) -> str:
    return re.sub(r"\s+", "", (s or "").strip().lower())


def _build_table_map(allowed_fqn: List[str]) -> Dict[str, str]:
    m: Dict[str, str] = {}
    for f in allowed_fqn:
        schema, _, table = f.partition(".")
        table_name = table.replace('"', "").strip()
        key = table_name.lower()
        if key not in m:
            m[key] = f'{schema.strip()}."{table_name}"'
    return m


_CTE_DEF_RE = re.compile(r'(?P<name>"[^"]+"|\w+)\s+AS\s*\(', re.IGNORECASE)


def _collect_cte_names(sql: str) -> List[str]:
    names: List[str] = []
    s = sql or ""
    if not re.search(r"^\s*with\b", s, re.IGNORECASE):
        return names
    for m in _CTE_DEF_RE.finditer(s):
        nm = (m.group("name") or "").strip().strip('"').strip().lower()
        if nm:
            names.append(nm)
    return names


def _extract_referenced_tables(sql: str) -> List[str]:
    refs: List[str] = []
    for m in _FROM_JOIN_CLAUSE_RE.finditer(sql or ""):
        tbl = (m.group("tbl") or "").strip()
        if tbl:
            refs.append(tbl)
    return refs


def _first_disallowed_ref(sql: str, allowed_fqn: List[str]) -> Optional[str]:
    if not sql or not allowed_fqn:
        return "sql/allowed vacío"

    s = unwrap_explain(sql) if is_explain(sql) else (sql or "")
    allowed_set = {_normalize_token(a) for a in allowed_fqn if a and a.strip()}
    table_map = _build_table_map(allowed_fqn)
    cte_names = set(_collect_cte_names(s))

    refs = _extract_referenced_tables(s)
    if not refs:
        return "no se detectaron FROM/JOIN"

    for r in refs:
        r_clean = (r or "").strip()
        if not r_clean:
            continue

        head = _normalize_token(r_clean.split("(")[0]).strip('"')
        if head in _NOT_A_TABLE:
            continue

        if "." not in r_clean:
            name = r_clean.strip().strip('"').lower()
            if name in cte_names:
                continue

            fqn_norm = table_map.get(name)
            if not fqn_norm:
                return f"tabla no encontrada en allow-list: {r_clean}"
            if _normalize_token(fqn_norm) not in allowed_set:
                return f"tabla fuera de allow-list: {r_clean} -> {fqn_norm}"
            continue

        parts = [p.strip().strip('"') for p in r_clean.split(".")]
        if len(parts) == 2:
            schema_n, table_n = parts[0].lower(), parts[1]
            fqn_norm = f'{schema_n}."{table_n}"'
            if _normalize_token(fqn_norm) not in allowed_set:
                return f"FQN fuera de allow-list: {r_clean} -> {fqn_norm}"
        else:
            return f"token schema.tabla inválido: {r_clean}"

    return None


def restrict_to_allowed_tables(sql: str, allowed_fqn: List[str]) -> bool:
    return _first_disallowed_ref(sql, allowed_fqn) is None


_FROM_JOIN_RE_QUALIFY = re.compile(
    r'\b(from|join)\s+("?[A-Za-z0-9_ ]+"?)(?!\s*\.)', re.IGNORECASE
)


def qualify_tables(sql: str, allowed_fqn: List[str]) -> str:
    if not sql or not allowed_fqn:
        return sql
    if is_values_only(sql) or is_explain(sql):
        return sql

    cte_names = set(_collect_cte_names(sql))
    table_map = _build_table_map(allowed_fqn)

    def repl(match: re.Match) -> str:
        kw = match.group(1)
        raw_name = (match.group(2) or "").strip()
        name_unquoted = raw_name.replace('"', "").strip()

        if name_unquoted.lower() in cte_names:
            return match.group(0)

        head = _normalize_token(name_unquoted.split("(")[0]).strip('"')
        if head in _NOT_A_TABLE:
            return match.group(0)

        fqn = table_map.get(name_unquoted.lower())
        if fqn:
            return f"{kw} {fqn}"
        return match.group(0)

    return _FROM_JOIN_RE_QUALIFY.sub(repl, sql)


# -------- Ejecución --------
async def query(
    sql_query: str,
    allowed_fqn: List[str],
    default_limit: int = 100,
    max_limit: int = 1000,
) -> List[Dict[str, Any]]:
    logger.debug("[database.query] raw=%r", sql_query)

    sql_query = clean_sql(sql_query)
    logger.debug("[database.query] after clean=%r", sql_query)

    sql_query = expand_macros(sql_query)

    sql_query = sanitize_explain(sql_query)
    logger.debug("[database.query] after explain sanitize=%r", sql_query)

    sql_query = qualify_tables(sql_query, allowed_fqn)
    logger.debug("[database.query] after qualify=%r", sql_query)

    if not is_safe_select(sql_query):
        raise ValueError("Solo se permiten consultas de lectura (SELECT/CTE, EXPLAIN sin ANALYZE, VALUES).")

    val_sql = unwrap_explain(sql_query) if is_explain(sql_query) else sql_query

    bad = _first_disallowed_ref(val_sql, allowed_fqn)
    if (not is_values_only(sql_query)) and bad:
        # ✅ ahora el error te dirá EXACTAMENTE qué token está rompiendo
        raise ValueError(f"La consulta referencia tablas no permitidas según el esquema actual. Detalle: {bad}")

    if (not is_values_only(sql_query)) and (not is_explain(sql_query)):
        sql = enforce_limit(val_sql, default_limit=default_limit, max_limit=max_limit)
    else:
        sql = sql_query

    logger.debug("[database.query] final SQL=%r", sql)

    with Session() as session:
        statement = text(sql)
        result = session.execute(statement)
        return [dict(row._mapping) for row in result]


def cleanup() -> None:
    engine.dispose()