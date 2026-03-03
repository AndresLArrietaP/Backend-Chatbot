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
- Montar el router principal de la API (`src.main`).
- Exponer un esquema OpenAPI consistente y, de ser necesario, fijar `servers`
  con `PUBLIC_BASE_URL` (útil con túneles/proxies públicos como ngrok).

Notas:
- Se mantiene el nombre de la función `init_app` ya que es usada por `index.py`.
- Nombres de variables internos en español y documentación clara.
"""

from typing import Type, List
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.openapi.utils import get_openapi

from . import main as api


def init_app(configuration: Type) -> FastAPI:
    """
    Construye y devuelve la aplicación FastAPI usando la clase de configuración indicada.

    Args:
        configuration (Type): Clase de configuración (por ejemplo, `DevelopmentConfig`).
                              Debe poder instanciarse sin argumentos.

    Returns:
        FastAPI: Instancia de la aplicación ya configurada.
    """
    # Instancia de configuración (lee variables de entorno en su __init__/atributos)
    settings = configuration()

    # Crear la app con metadatos básicos
    app = FastAPI(
        title=settings.APP_NAME,
        description="Convierte lenguaje natural a SQL, consulta la BD y devuelve respuesta.",
        version="0.1.0",
    )

    # Exponer settings a toda la app (rutas, dependencias, etc.)
    app.state.settings = settings  # <<-- importante

    # --------------------- CORS ---------------------
    # Soporta una lista coma-separada o el comodín "*"
    allow_raw = (settings.ALLOW_ORIGINS or "*")
    allow_origenes: List[str] = [o.strip() for o in allow_raw.split(",") if o.strip()] or ["*"]

    app.add_middleware(
        CORSMiddleware,
        allow_origins=allow_origenes,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # ------------------- Rutas / Router -------------------
    app.include_router(api.router)

    # ------------------- OpenAPI / Servers ----------------
    public_base_url = (settings.PUBLIC_BASE_URL or "").strip()

    def custom_openapi():
        """
        Genera (o devuelve desde caché) el esquema OpenAPI:
        - Título y descripción coherentes con `settings.APP_NAME`.
        - Si `PUBLIC_BASE_URL` está presente, fija `servers` para que los clientes
          consuman la API a través de esa URL pública.
        """
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