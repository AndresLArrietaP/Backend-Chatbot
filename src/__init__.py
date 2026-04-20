# src/__init__.py
# -*- coding: utf-8 -*-
"""
Módulo: src.__init__
--------------------
Constructor de la aplicación FastAPI (ASGI).

Responsabilidades:
- Instanciar la app con el perfil de configuración recibido.
- Inyectar `settings` en `app.state.settings` para su uso en rutas.
- Configurar CORS en base a `ALLOW_ORIGINS`.
- Montar el router principal de la API (`src.main.router`).
- Exponer OpenAPI consistente y, si aplica, fijar `servers` con `PUBLIC_BASE_URL`
  (útil con túneles como ngrok).

Arquitectura:
index.py -> init_app(config) -> app.include_router(src.main.router)
"""

import asyncio
import logging
from typing import Type, List

import anyio
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.openapi.utils import get_openapi

from . import main as api

log = logging.getLogger(__name__)


def init_app(configuration: Type) -> FastAPI:
    """
    Construye y devuelve la aplicación FastAPI usando la clase de configuración indicada.

    Args:
        configuration: Clase de configuración (ej. DevelopmentConfig). Debe instanciarse sin argumentos.

    Returns:
        Instancia FastAPI lista para ejecutar.
    """
    settings = configuration()

    app = FastAPI(
        title=settings.APP_NAME,
        description="Convierte lenguaje natural a SQL, consulta la BD y devuelve respuesta.",
        version="0.1.0",
    )

    # Exponer settings globalmente
    app.state.settings = settings

    # --------------------- CORS ---------------------
    allow_raw = (settings.ALLOW_ORIGINS or "*")
    allow_origenes: List[str] = [o.strip() for o in allow_raw.split(",") if o.strip()] or ["*"]

    app.add_middleware(
        CORSMiddleware,
        allow_origins=allow_origenes,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # ------------------- Router ---------------------
    app.include_router(api.router)

    # ------------------- Startup: DB warmup ---------
    @app.on_event("startup")
    async def _warmup_db_on_startup() -> None:
        """
        Calienta el pool de conexiones y el caché de esquema al arrancar.
        Corre en background para no bloquear el startup; si falla, el primer
        request real pagará el cold-start (degradación graceful).
        """
        async def _bg() -> None:
            from decouple import config as env_cfg
            from . import database

            # 1. Pool de conexiones: query mínima → Azure SQL compila plan base
            # abandon_on_cancel=False: el warmup debe completarse aunque tarde;
            # si se cancelara prematuramente, el primer request real pagaría el cold-start.
            try:
                await anyio.to_thread.run_sync(database.warmup_connection, abandon_on_cancel=False)
            except Exception as exc:
                log.warning("[startup] warmup conexión falló: %s", exc)

            # 2. Caché de esquema: la primera llamada real no tendrá que esperar la introspección
            try:
                target_schemas = [
                    s.strip()
                    for s in (env_cfg("TARGET_SCHEMAS", default="public") or "").split(",")
                    if s.strip()
                ]
                max_tablas = env_cfg("MAX_SCHEMA_TABLES", default=80, cast=int)
                max_cols = env_cfg("MAX_SCHEMA_COLUMNS", default=4000, cast=int)
                await anyio.to_thread.run_sync(
                    lambda: database.obtener_esquema_json(
                        esquemas=target_schemas,
                        tablas=None,
                        max_tablas=max_tablas,
                        max_columnas=max_cols,
                    ),
                    abandon_on_cancel=False,
                )
                log.info("[startup] Caché de esquema pre-cargado.")
            except Exception as exc:
                log.warning("[startup] warmup esquema falló: %s", exc)

        asyncio.create_task(_bg())

    # ------------------- OpenAPI servers (ngrok) ----
    public_base_url = (settings.PUBLIC_BASE_URL or "").strip()

    def custom_openapi():
        if app.openapi_schema:
            return app.openapi_schema

        openapi_schema = get_openapi(
            title=settings.APP_NAME,
            version="0.1.0",
            description="Convierte lenguaje natural a SQL, consulta la BD y devuelve respuesta.",
            routes=app.routes,
        )

        if public_base_url:
            openapi_schema["servers"] = [{"url": public_base_url}]

        app.openapi_schema = openapi_schema
        return app.openapi_schema

    app.openapi = custom_openapi
    return app