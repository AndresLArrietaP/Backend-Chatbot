# config.py
# -*- coding: utf-8 -*-
"""
Módulo: config
--------------
Carga de configuración de la aplicación desde variables de entorno (.env)
y registro de conexiones dinámicas a bases de datos.

Uso:
    from config import config as perfiles
    configuracion = perfiles.get("development")

Perfiles disponibles:
    - development (predeterminado)

Extensión futura:
    - Agregar ProductionConfig / StagingConfig según necesidad.
"""

from __future__ import annotations

import os
from decouple import config as env


# ==============================================================================
#  Carga dinámica de conexiones adicionales (prefijo DB_CONN_)
# ==============================================================================

def cargar_conexiones_desde_entorno(prefix: str = "DB_CONN_") -> dict[str, str]:
    """
    Lee variables de entorno con el prefijo dado y construye un registro
    de conexiones { nombre_corto: dsn }.

    Ejemplo de variable de entorno:
        DB_CONN_REPORTES=mssql+pymssql://user:pass@server/db

    Args:
        prefix: Prefijo de las variables a leer (default "DB_CONN_").

    Returns:
        Dict con { nombre: dsn } para cada variable encontrada.
    """
    conexiones: dict[str, str] = {}
    for clave, valor in os.environ.items():
        if not clave.startswith(prefix):
            continue
        nombre = clave[len(prefix):].strip().lower()
        if nombre and valor:
            conexiones[nombre] = valor
    return conexiones


# ==============================================================================
#  Clase base de configuración
# ==============================================================================

class Config:
    """
    Configuración base de la aplicación.

    Todos los valores se leen desde variables de entorno mediante python-decouple.
    Los defaults garantizan que la app arranque en entorno local sin .env completo.
    """

    # --- Metadatos de la aplicación ---
    APP_NAME: str    = env("APP_NAME", default="NL→SQL API")
    DEBUG: bool      = env("DEBUG", default=False, cast=bool)
    APP_PROFILE: str = env("APP_PROFILE", default="development")

    # --- CORS y proxy público (ngrok / Render) ---
    ALLOW_ORIGINS: str   = env("ALLOW_ORIGINS", default="*")
    PUBLIC_BASE_URL: str = env("PUBLIC_BASE_URL", default="")

    # --- Seguridad de API (opcional, no obligatoria aún) ---
    API_KEY: str = env("API_KEY", default="")

    # --- Proveedor LLM activo ---
    LLM_PROVIDER: str = env("LLM_PROVIDER", default="gemini").lower()

    # --- Gemini (proveedor principal) ---
    GOOGLE_API_KEY: str | None    = env("GOOGLE_API_KEY", default=None)
    GEMINI_MODEL: str             = env("GEMINI_MODEL", default="gemini-2.5-flash")
    GEMINI_MODEL_ANSWER: str      = env("GEMINI_MODEL_ANSWER", default="gemini-2.5-pro")

    # --- OpenAI (proveedor alternativo) ---
    OPENAI_API_KEY: str | None = env("OPENAI_API_KEY", default=None)
    OPENAI_MODEL: str          = env("OPENAI_MODEL", default="gpt-4o")

    # --- Conexiones dinámicas (DB_CONN_*) ---
    # Carga automática de DSNs adicionales (ej: DB_CONN_REPORTES=mssql+pymssql://...)
    CONNECTIONS: dict[str, str] = cargar_conexiones_desde_entorno()
    DEFAULT_CONNECTION: str | None = env("DEFAULT_CONNECTION", default=None)
    # Si no se definió DEFAULT_CONNECTION, usa la primera conexión dinámica cargada
    if not DEFAULT_CONNECTION and CONNECTIONS:
        DEFAULT_CONNECTION = next(iter(CONNECTIONS.keys()))

    # --- Esquemas de introspección ---
    ALLOWED_SCHEMAS: list[str] = [
        s.strip()
        for s in env("ALLOWED_SCHEMAS", default="public").split(",")
        if s.strip()
    ]
    TARGET_SCHEMAS: str = env("TARGET_SCHEMAS", default="public")

    # --- Dialecto y límites de consulta ---
    DB_DIALECT: str      = env("DB_DIALECT", default="postgresql")
    MAX_ROWS_DEFAULT: int = env("MAX_ROWS_DEFAULT", default=100, cast=int)
    MAX_ROWS_HARD: int    = env("MAX_ROWS_HARD", default=2000, cast=int)
    MAX_SCHEMA_TABLES: int   = env("MAX_SCHEMA_TABLES", default=50, cast=int)
    MAX_SCHEMA_COLUMNS: int  = env("MAX_SCHEMA_COLUMNS", default=2000, cast=int)

    # --- Seguridad SQL (solo lectura) ---
    ALLOW_SQL_EXPLAIN: bool     = env("ALLOW_SQL_EXPLAIN", default=True, cast=bool)
    ALLOW_EXPLAIN_ANALYZE: bool = env("ALLOW_EXPLAIN_ANALYZE", default=False, cast=bool)
    ALLOW_SQL_VALUES: bool      = env("ALLOW_SQL_VALUES", default=True, cast=bool)
    ALLOW_SQL_CALL: bool        = env("ALLOW_SQL_CALL", default=False, cast=bool)

    # --- Contexto conversacional en memoria ---
    CONTEXTO_CHAT_TTL_MINUTOS: int     = env("CONTEXTO_CHAT_TTL_MINUTOS", default=45, cast=int)
    CONTEXTO_CHAT_MAX_TURNOS: int      = env("CONTEXTO_CHAT_MAX_TURNOS", default=8, cast=int)
    CONTEXTO_CHAT_MAX_CARACTERES: int  = env("CONTEXTO_CHAT_MAX_CARACTERES", default=5000, cast=int)

    # --- Esquema relevante para el prompt del LLM ---
    ESQUEMA_RELEVANTE_ACTIVO: bool      = env("ESQUEMA_RELEVANTE_ACTIVO", default=True, cast=bool)
    ESQUEMA_RELEVANTE_MAX_TABLAS: int   = env("ESQUEMA_RELEVANTE_MAX_TABLAS", default=18, cast=int)

    # --- Opciones de respuesta analítica ---
    GENERAR_RESPUESTA_TEXTO: bool        = env("GENERAR_RESPUESTA_TEXTO", default=True, cast=bool)
    INCLUIR_ANALISIS_RESULTADO: bool     = env("INCLUIR_ANALISIS_RESULTADO", default=True, cast=bool)
    INCLUIR_SUGERENCIAS_GRAFICO: bool    = env("INCLUIR_SUGERENCIAS_GRAFICO", default=True, cast=bool)


# ==============================================================================
#  Perfil de desarrollo
# ==============================================================================

class DevelopmentConfig(Config):
    """
    Perfil de desarrollo: activa DEBUG y permite recargas automáticas de uvicorn.
    """
    DEBUG = True


# ==============================================================================
#  Aliases de compatibilidad y registro de perfiles
# ==============================================================================

Configuracion = Config
ConfiguracionDesarrollo = DevelopmentConfig

# Registro de perfiles disponibles (usado en index.py)
config = {
    "development": DevelopmentConfig,
}

configuraciones = config
