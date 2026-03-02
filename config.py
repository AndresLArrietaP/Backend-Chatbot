
# config.py
# -*- coding: utf-8 -*-
"""
Módulo: config
--------------
Carga de configuración de la aplicación desde variables de entorno
y utilidades para administrar conexiones dinámicas a bases de datos.

Cambios:
- Funciones y comentarios en español.
- Docstrings claros.
- Se mantiene la clase `Config` y el dict `config` para compatibilidad.
- Se añaden alias en español/inglés cuando aplica (sin romper integraciones existentes).
"""

import os
from decouple import config as env


def cargar_conexiones_desde_entorno(prefix: str = "DB_CONN_") -> dict[str, str]:
    """
    Lee todas las variables de entorno que empiecen por `prefix` (por defecto, DB_CONN_)
    y construye un registro con nombre -> DSN.

    Ejemplos en .env:
      DB_CONN_primary=postgresql+psycopg2://user:pass@host:port/db
      DB_CONN_analytics=postgresql+psycopg2://user:pass@host:port/db2

    Args:
        prefix: Prefijo de las variables de entorno a considerar.

    Returns:
        dict[str, str]: Mapa nombre_conexion -> DSN
    """
    conns: dict[str, str] = {}
    for k, v in os.environ.items():
        if k.startswith(prefix):
            name = k[len(prefix):].strip().lower()
            if name and v:
                conns[name] = v
    return conns


class Config:
    """
    Configuración base de la aplicación.
    Lee valores desde variables de entorno y define valores por defecto.
    """

    # Metadatos / app
    APP_NAME = env("APP_NAME", default="NL→SQL API")
    DEBUG = env("DEBUG", default=False, cast=bool)

    # OpenAPI / CORS / Servers (para ngrok u otro proxy público)
    ALLOW_ORIGINS = env("ALLOW_ORIGINS", default="*")
    PUBLIC_BASE_URL = env("PUBLIC_BASE_URL", default="")

    # --- Gemini (Google AI Studio) ---
    LLM_PROVIDER = env("LLM_PROVIDER", default="gemini").lower()
    GOOGLE_API_KEY = env("GOOGLE_API_KEY", default=None)
    GEMINI_MODEL = env("GEMINI_MODEL", default="gemini-1.5-flash")
    GEMINI_MODEL_ANSWER = env("GEMINI_MODEL_ANSWER", default=None)

    # --- OpenAI ---
    OPENAI_API_KEY = env("OPENAI_API_KEY", default=None)
    OPENAI_MODEL = env("OPENAI_MODEL", default="gpt-4o")

    # Conexiones dinámicas
    CONNECTIONS = cargar_conexiones_desde_entorno()  # dict[name]=DSN
    DEFAULT_CONNECTION = env("DEFAULT_CONNECTION", default=None)
    if not DEFAULT_CONNECTION and CONNECTIONS:
        # Toma la primera disponible si no se define explícitamente
        DEFAULT_CONNECTION = next(iter(CONNECTIONS.keys()))

    # Alcance por defecto de introspección (se puede sobreescribir por query)
    # Coma-separado; típicamente "public"
    ALLOWED_SCHEMAS = [s.strip() for s in env("ALLOWED_SCHEMAS", default="public").split(",")]

    # Alias para compatibilidad con tu main.py
    TARGET_SCHEMAS = env("TARGET_SCHEMAS", default="public")

    # Dialecto DB y límites
    DB_DIALECT = env("DB_DIALECT", default="postgresql")
    MAX_ROWS_DEFAULT = env("MAX_ROWS_DEFAULT", default=100, cast=int)
    MAX_ROWS_HARD = env("MAX_ROWS_HARD", default=2000, cast=int)

    # Límites de introspección
    MAX_SCHEMA_TABLES = env("MAX_SCHEMA_TABLES", default=50, cast=int)
    MAX_SCHEMA_COLUMNS = env("MAX_SCHEMA_COLUMNS", default=2000, cast=int)

    # Seguridad SQL opcional (reflejo de lo que lee database.py)
    ALLOW_SQL_EXPLAIN = env("ALLOW_SQL_EXPLAIN", default=True, cast=bool)
    ALLOW_EXPLAIN_ANALYZE = env("ALLOW_EXPLAIN_ANALYZE", default=False, cast=bool)
    ALLOW_SQL_VALUES = env("ALLOW_SQL_VALUES", default=True, cast=bool)
    ALLOW_SQL_CALL = env("ALLOW_SQL_CALL", default=False, cast=bool)


class DevelopmentConfig(Config):
    """Perfil de desarrollo (activa DEBUG)."""
    DEBUG = True

# Alias de clase (si en algún lugar prefieres nombre en español)
Configuracion = Config
ConfiguracionDesarrollo = DevelopmentConfig

# Diccionario de perfiles (mantener clave 'development' existente)
config = {
    "development": DevelopmentConfig,
    # "production": ProductionConfig,  # si luego quieres añadir otro perfil
}

# Alias en español del diccionario de perfiles
configuraciones = config
