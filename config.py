# -*- coding: utf-8 -*-
"""
Módulo: config
--------------
Carga de configuración de la aplicación desde variables de entorno
y utilidades para administrar conexiones dinámicas a bases de datos.
"""

from __future__ import annotations

import os
from decouple import config as env


def cargar_conexiones_desde_entorno(prefix: str = "DB_CONN_") -> dict[str, str]:
    """
    Lee todas las variables de entorno que empiecen por `prefix` y construye
    un registro con nombre -> DSN.
    """
    conexiones: dict[str, str] = {}
    for clave, valor in os.environ.items():
        if not clave.startswith(prefix):
            continue
        nombre = clave[len(prefix):].strip().lower()
        if nombre and valor:
            conexiones[nombre] = valor
    return conexiones


class Config:
    """Configuración base de la aplicación."""

    # Metadatos / app
    APP_NAME = env("APP_NAME", default="NL→SQL API")
    DEBUG = env("DEBUG", default=False, cast=bool)
    APP_PROFILE = env("APP_PROFILE", default="development")

    # OpenAPI / CORS / proxy público
    ALLOW_ORIGINS = env("ALLOW_ORIGINS", default="*")
    PUBLIC_BASE_URL = env("PUBLIC_BASE_URL", default="")

    # Seguridad futura (opcional, hoy no obligatoria)
    API_KEY = env("API_KEY", default="")

    # Gemini
    LLM_PROVIDER = env("LLM_PROVIDER", default="gemini").lower()
    GOOGLE_API_KEY = env("GOOGLE_API_KEY", default=None)
    GEMINI_MODEL = env("GEMINI_MODEL", default="gemini-3-flash")
    GEMINI_MODEL_ANSWER = env("GEMINI_MODEL_ANSWER", default="gemini-3-pro")

    # OpenAI
    OPENAI_API_KEY = env("OPENAI_API_KEY", default=None)
    OPENAI_MODEL = env("OPENAI_MODEL", default="gpt-4o")

    # Conexiones dinámicas
    CONNECTIONS = cargar_conexiones_desde_entorno()
    DEFAULT_CONNECTION = env("DEFAULT_CONNECTION", default=None)
    if not DEFAULT_CONNECTION and CONNECTIONS:
        DEFAULT_CONNECTION = next(iter(CONNECTIONS.keys()))

    # Alcance por defecto de introspección
    ALLOWED_SCHEMAS = [s.strip() for s in env("ALLOWED_SCHEMAS", default="public").split(",") if s.strip()]
    TARGET_SCHEMAS = env("TARGET_SCHEMAS", default="public")

    # Dialecto y límites
    DB_DIALECT = env("DB_DIALECT", default="postgresql")
    MAX_ROWS_DEFAULT = env("MAX_ROWS_DEFAULT", default=100, cast=int)
    MAX_ROWS_HARD = env("MAX_ROWS_HARD", default=2000, cast=int)
    MAX_SCHEMA_TABLES = env("MAX_SCHEMA_TABLES", default=50, cast=int)
    MAX_SCHEMA_COLUMNS = env("MAX_SCHEMA_COLUMNS", default=2000, cast=int)

    # Seguridad SQL opcional
    ALLOW_SQL_EXPLAIN = env("ALLOW_SQL_EXPLAIN", default=True, cast=bool)
    ALLOW_EXPLAIN_ANALYZE = env("ALLOW_EXPLAIN_ANALYZE", default=False, cast=bool)
    ALLOW_SQL_VALUES = env("ALLOW_SQL_VALUES", default=True, cast=bool)
    ALLOW_SQL_CALL = env("ALLOW_SQL_CALL", default=False, cast=bool)

    # Contexto conversacional en memoria
    CONTEXTO_CHAT_TTL_MINUTOS = env("CONTEXTO_CHAT_TTL_MINUTOS", default=45, cast=int)
    CONTEXTO_CHAT_MAX_TURNOS = env("CONTEXTO_CHAT_MAX_TURNOS", default=8, cast=int)
    CONTEXTO_CHAT_MAX_CARACTERES = env("CONTEXTO_CHAT_MAX_CARACTERES", default=5000, cast=int)

    # Selección de esquema relevante
    ESQUEMA_RELEVANTE_ACTIVO = env("ESQUEMA_RELEVANTE_ACTIVO", default=True, cast=bool)
    ESQUEMA_RELEVANTE_MAX_TABLAS = env("ESQUEMA_RELEVANTE_MAX_TABLAS", default=18, cast=int)

    # Respuesta analítica y gráficas sugeridas
    GENERAR_RESPUESTA_TEXTO = env("GENERAR_RESPUESTA_TEXTO", default=True, cast=bool)
    INCLUIR_ANALISIS_RESULTADO = env("INCLUIR_ANALISIS_RESULTADO", default=True, cast=bool)
    INCLUIR_SUGERENCIAS_GRAFICO = env("INCLUIR_SUGERENCIAS_GRAFICO", default=True, cast=bool)


class DevelopmentConfig(Config):
    """Perfil de desarrollo."""

    DEBUG = True


Configuracion = Config
ConfiguracionDesarrollo = DevelopmentConfig

config = {
    "development": DevelopmentConfig,
}

configuraciones = config
