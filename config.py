# config.py
import os
from decouple import config as env


def load_connections_from_env(prefix: str = "DB_CONN_") -> dict[str, str]:
    """
    Lee todas las variables de entorno que empiecen por DB_CONN_
    y construye un registro con nombre -> DSN.
    Ejemplos en .env:
      DB_CONN_primary=postgresql+psycopg2://user:pass@host:port/db
      DB_CONN_analytics=postgresql+psycopg2://user:pass@host:port/db2
    """
    conns: dict[str, str] = {}
    for k, v in os.environ.items():
        if k.startswith(prefix):
            name = k[len(prefix):].strip().lower()
            if name and v:
                conns[name] = v
    return conns


class Config:
    APP_NAME = env("APP_NAME", default="NL→SQL API")
    DEBUG = env("DEBUG", default=False, cast=bool)

    # OpenAPI / CORS / Servers (para ngrok u otro proxy público)
    ALLOW_ORIGINS = env("ALLOW_ORIGINS", default="*")
    PUBLIC_BASE_URL = env("PUBLIC_BASE_URL", default="")

    
    # --- Gemini (Google AI Studio) ---
    GOOGLE_API_KEY = env("GOOGLE_API_KEY", default=None)
    GEMINI_MODEL = env("GEMINI_MODEL", default="gemini-1.5-flash")


    # OpenAI
    OPENAI_API_KEY = env("OPENAI_API_KEY", default=None)
    OPENAI_MODEL = env("OPENAI_MODEL", default="gpt-4o")

    # Conexiones dinámicas
    CONNECTIONS = load_connections_from_env()  # dict[name]=DSN
    DEFAULT_CONNECTION = env("DEFAULT_CONNECTION", default=None)
    if not DEFAULT_CONNECTION and CONNECTIONS:
        # toma la primera disponible si no se define
        DEFAULT_CONNECTION = next(iter(CONNECTIONS.keys()))

    # Alcance por defecto de introspección (se puede sobreescribir por query)
    # Coma-separado; tipicamente "public"
    ALLOWED_SCHEMAS = [s.strip() for s in env("ALLOWED_SCHEMAS", default="public").split(",")]

    # Límite de filas por defecto
    MAX_ROWS_DEFAULT = env("MAX_ROWS_DEFAULT", default=100, cast=int)
    MAX_ROWS_HARD = env("MAX_ROWS_HARD", default=2000, cast=int)


class DevelopmentConfig(Config):
    DEBUG = True


config = {
    "development": DevelopmentConfig,
    # "production": ProductionConfig,  # si luego quieres añadir otro perfil
}