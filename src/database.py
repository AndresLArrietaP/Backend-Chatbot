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

# ---------------------------------------
# Conexión
# ---------------------------------------
DATABASE_URL = (env("DATABASE_URL", default=None) or "").strip()
if not DATABASE_URL:
    raise RuntimeError("Falta la variable de entorno DATABASE_URL.")

# Flags de seguridad (ajustables por .env)
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

# ---------------------------------------
# Introspección de esquema con caché
# ---------------------------------------
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

# ---------------------------------------
# Limpieza
# ---------------------------------------
_CODE_FENCE_RE = re.compile(r"^\s*```(?:sql|postgresql)?\s*|\s*```\s*$", re.IGNORECASE | re.MULTILINE)

def _strip_code_fences(s: str) -> str:
    return _CODE_FENCE_RE.sub("", s or "")

def _strip_sql_comments(s: str) -> str:
    s = re.sub(r"--.*?$", "", s, flags=re.MULTILINE)
    s = re.sub(r"/\*.*?\*/", "", s, flags=re.DOTALL)
    return s

def clean_sql(sql: str) -> str:
    """
    Normaliza SQL:
      - quita fences de código
      - quita comentarios
      - quita prefijos tipo 'SQL:' o 'Query:'
      - quita ';' final
      - trim
    """
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

# ---------------------------------------
# Clasificación / Seguridad
# ---------------------------------------
_EXPLAIN_RE = re.compile(r"^\s*explain\b", re.IGNORECASE)
_EXPLAIN_ANALYZE_RE = re.compile(r"^\s*explain\b.*\banalyze\b", re.IGNORECASE | re.DOTALL)
_VALUES_RE = re.compile(r"^\s*values\s*\(", re.IGNORECASE)
_SELECT_RE = re.compile(r"^\s*(WITH\b.+\bSELECT|SELECT)\b", re.IGNORECASE | re.DOTALL)

def is_values_only(sql: str) -> bool:
    return bool(_VALUES_RE.match(sql or ""))

def is_explain(sql: str) -> bool:
    return bool(_EXPLAIN_RE.match(sql or ""))

def unwrap_explain(sql: str) -> str:
    """ Quita el encabezado EXPLAIN y devuelve el SELECT interno. """
    if not is_explain(sql):
        return sql
    s = sql.strip()
    s = re.sub(r"^\s*explain\b(?:\s+\w+(?:\s+\w+)*)*\s*", "", s, flags=re.IGNORECASE)
    return s.strip()

# --- Ignorar literales de texto al buscar tokens prohibidos ---
_SINGLE_QUOTED_RE = re.compile(r"('([^']|'')*')", re.DOTALL)
_DOLLAR_QUOTED_RE = re.compile(r"(\$\$.*?\$\$)", re.DOTALL)  # simplificado para $$...$$

def _mask_string_literals(sql: str) -> str:
    """
    Reemplaza literales de texto por comillas vacías para evitar falsos positivos:
    '... DROP ...' dentro de un string NO debe bloquear.
    """
    s = sql or ""
    s = _DOLLAR_QUOTED_RE.sub("$$''$$", s)  # conserva delimitadores
    s = _SINGLE_QUOTED_RE.sub("''", s)
    return s

# ⚠️ Tokens peligrosos como palabras completas (no subcadenas)
#    (no bloqueamos REPLACE para no interferir con REGEXP_REPLACE)
_base_forbidden = [
    r"\bDROP\b", r"\bDELETE\b", r"\bTRUNCATE\b", r"\bALTER\b",
    r"\bINSERT\b", r"\bUPDATE\b", r"\bCREATE\b", r"\bMERGE\b",
    r"\bVACUUM\b", r"\bCOPY\b", r"\bGRANT\b", r"\bREVOKE\b",
]
if not ALLOW_SQL_CALL:
    _base_forbidden.append(r"\bCALL\b")

_FORBIDDEN_PATTERNS = [re.compile(pat, re.IGNORECASE) for pat in _base_forbidden]

def _contains_forbidden(sql: str) -> Optional[str]:
    """
    Devuelve el patrón que matcheó (para debug) o None si está limpio.
    Ignora literales de texto.
    """
    s = _mask_string_literals(sql or "")
    for pat in _FORBIDDEN_PATTERNS:
        if pat.search(s):
            return pat.pattern
    return None

def find_forbidden_tokens(sql: str) -> List[str]:
    """
    Útil para /debug: lista los patrones que matchean.
    """
    hits: List[str] = []
    s = _mask_string_literals(sql or "")
    for pat in _FORBIDDEN_PATTERNS:
        if pat.search(s):
            hits.append(pat.pattern)
    return hits

def is_safe_select(sql: str) -> bool:
    """
    Permitimos lectura segura:
      - SELECT / WITH ... SELECT
      - (opcional) EXPLAIN ... SELECT (sin ANALYZE por defecto)
      - (opcional) VALUES (...)
    Rechazamos si aparecen tokens peligrosos (palabras completas, ignorando strings).
    """
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

def restrict_to_allowed_tables(sql: str, allowed_fqn: List[str]) -> bool:
    """
    Acepta referencias:
      - FQN:   public."Tabla"  /  public.Tabla
      - no FQN: "Tabla"  /  Tabla
    Para EXPLAIN, valida el SELECT interno. Para VALUES, no exige tablas.
    """
    if not sql or not allowed_fqn:
        return False

    if is_values_only(sql):
        return True

    s = sql
    if is_explain(s):
        s = unwrap_explain(s)

    patterns = []
    for fqn in allowed_fqn:
        schema, _, table = fqn.partition(".")
        schema = schema.strip().strip('"').lower()
        table_unquoted = table.strip().replace('"', "")

        # 1) FQN con comillas exacto
        patterns.append(rf'{re.escape(schema)}\s*\.\s*"{re.escape(table_unquoted)}"')
        # 2) FQN sin comillas
        patterns.append(rf'{re.escape(schema)}\s*\.\s*{re.escape(table_unquoted)}')
        # 3) Solo tabla con comillas
        patterns.append(rf'"{re.escape(table_unquoted)}"')
        # 4) Solo tabla sin comillas
        patterns.append(rf'\b{re.escape(table_unquoted)}\b')

    for pat in patterns:
        if re.search(pat, s, flags=re.IGNORECASE):
            return True
    return False

# --- (Opcional) Auto-cualificación de tablas no calificadas ---
def _build_table_map(allowed_fqn: List[str]) -> Dict[str, str]:
    m: Dict[str, str] = {}
    for f in allowed_fqn:
        schema, _, table = f.partition(".")
        table_name = table.replace('"', '').strip()
        key = table_name.lower()
        if key not in m:
            m[key] = f'{schema.strip()}."{table_name}"'
    return m

_FROM_JOIN_RE = re.compile(r'\b(from|join)\s+("?[A-Za-z0-9_ ]+"?)(?!\s*\.)', re.IGNORECASE)

def qualify_tables(sql: str, allowed_fqn: List[str]) -> str:
    """
    Si detecta FROM/JOIN con tabla no cualificada, la reemplaza por su FQN.
    Heurístico. No se aplica a EXPLAIN/VALUES.
    """
    if not sql or not allowed_fqn:
        return sql
    if is_values_only(sql) or is_explain(sql):
        return sql

    table_map = _build_table_map(allowed_fqn)

    def repl(match: re.Match) -> str:
        kw = match.group(1)  # FROM o JOIN
        raw_name = match.group(2).strip()  # "Tabla" o Tabla
        name_unquoted = raw_name.replace('"', '').strip()
        fqn = table_map.get(name_unquoted.lower())
        if fqn:
            return f"{kw} {fqn}"
        return match.group(0)

    return _FROM_JOIN_RE.sub(repl, sql)

# ---------------------------------------
# Ejecución
# ---------------------------------------
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

    # 0.5) cualificación auto (no para EXPLAIN/VALUES)
    sql_query = qualify_tables(sql_query, allowed_fqn)
    logger.debug("[database.query] after qualify=%r", sql_query)

    # 1) seguridad (respetando EXPLAIN/VALUES)
    if not is_safe_select(sql_query):
        raise ValueError("Solo se permiten consultas de lectura (SELECT/CTE, EXPLAIN sin ANALYZE, VALUES).")

    # Para validación de tablas, si EXPLAIN validar sobre el SELECT interno
    val_sql = unwrap_explain(sql_query) if is_explain(sql_query) else sql_query

    if not is_values_only(sql_query) and not restrict_to_allowed_tables(val_sql, allowed_fqn):
        raise ValueError("La consulta referencia tablas no permitidas según el esquema actual.")

    # 2) límite (solo para SELECT/CTE normales)
    if (not is_values_only(sql_query)) and (not is_explain(sql_query)):
        sql = enforce_limit(val_sql, default_limit=default_limit, max_limit=max_limit)
    else:
        sql = sql_query  # EXPLAIN/VALUES: no modificamos

    logger.debug("[database.query] final SQL=%r", sql)

    # 3) ejecutar
    with Session() as session:
        statement = text(sql)
        result = session.execute(statement)
        return [dict(row._mapping) for row in result]

def cleanup() -> None:
    engine.dispose()