# src/database.py
from typing import Any, List, Dict, Optional, Tuple
from decouple import config as env
import re

from sqlalchemy import create_engine, inspect
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import QueuePool
from sqlalchemy.sql import text

# Recorta espacios accidentales y valida presencia
DATABASE_URL = (env("DATABASE_URL", default=None) or "").strip()
if not DATABASE_URL:
    raise RuntimeError("Falta la variable de entorno DATABASE_URL.")

# Fuerza SSL con Supabase (recomendado)
# Nota: también puedes añadir ?sslmode=require al DSN en .env
engine = create_engine(
    DATABASE_URL,
    connect_args={"sslmode": "require"},
    poolclass=QueuePool,
    pool_size=5,
    max_overflow=10,
    pool_pre_ping=True,
)
Session = sessionmaker(bind=engine)

# -------- Esquema dinámico con caché --------
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
    """
    Devuelve un JSON con las tablas/columnas disponibles.
    - schemas: lista de esquemas a incluir (default: todos los visibles, aunque conviene pasar ["public"]).
    - tables:  lista de nombres de tabla (sin esquema) para enfocar (opcional).
    - max_tables/max_columns: límites para no reventar /docs ni al LLM.
    """
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
                "fq_name": f'{sch}."{t}"',  # para Postgres; informativo y útil para validación
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

# -------- Seguridad básica --------
_SELECT_RE = re.compile(r"^\s*(WITH\b.+\bSELECT|SELECT)\b", re.IGNORECASE | re.DOTALL)
_FORBIDDEN_TOKENS = [";", "--", "/*", "*/", "DROP", "INSERT", "UPDATE", "DELETE", "ALTER", "TRUNCATE"]

def is_safe_select(sql: str) -> bool:
    if not _SELECT_RE.match(sql or ""):
        return False
    s = (sql or "").lower()
    return not any(tok.lower() in s for tok in _FORBIDDEN_TOKENS)

def enforce_limit(sql: str, default_limit: int = 100, max_limit: int = 1000) -> str:
    # Si ya trae LIMIT, respétalo pero no permitas exceder max_limit
    m = re.search(r"\blimit\s+(\d+)\b", sql, re.IGNORECASE)
    if m:
        n = int(m.group(1))
        if n > max_limit:
            sql = re.sub(r"\blimit\s+\d+\b", f"LIMIT {max_limit}", sql, flags=re.IGNORECASE)
        return sql
    return f"{sql.rstrip()} LIMIT {default_limit}"

def restrict_to_allowed_tables(sql: str, allowed_fqn: List[str]) -> bool:
    # Chequeo simple: requiere que aparezca al menos una tabla permitida.
    # Nota: esto es heurístico; si luego necesitas un parser real, se cambia.
    s = sql or ""
    return any(fqn in s for fqn in allowed_fqn)

async def query(
    sql_query: str,
    allowed_fqn: List[str],
    default_limit: int = 100,
    max_limit: int = 1000,
) -> List[Dict[str, Any]]:
    if not is_safe_select(sql_query):
        raise ValueError("Solo se permiten consultas SELECT (sin DDL/DML).")

    if not restrict_to_allowed_tables(sql_query, allowed_fqn):
        raise ValueError("La consulta referencia tablas no permitidas según el esquema actual.")

    sql = enforce_limit(sql_query, default_limit=default_limit, max_limit=max_limit)

    with Session() as session:
        statement = text(sql)
        result = session.execute(statement)
        return [dict(row._mapping) for row in result]

def cleanup() -> None:
    engine.dispose()