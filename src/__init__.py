"""# src/__init__.py
from typing import Type, List
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.openapi.utils import get_openapi

from . import main as api  # APIRouter con tus endpoints


def init_app(configuration: Type) -> FastAPI:
    settings = configuration()  # instancia de tu config

    app = FastAPI(
        title=settings.APP_NAME,
        description="Convierte lenguaje natural a SQL, consulta la BD y devuelve respuesta.",
        version="0.1.0",
    )

    # CORS
    allow_origins: List[str] = [o.strip() for o in (settings.ALLOW_ORIGINS or "*").split(",")]
    app.add_middleware(
        CORSMiddleware,
        allow_origins=allow_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Monta rutas desde src/main.py
    app.include_router(api.router)

    # ----- OpenAPI 'servers' dinámico (para ngrok u otra URL pública) -----
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

    app.openapi = custom_openapi  # asigna generador custom

    return app"""
    
# src/__init__.py
from typing import Type, List
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.openapi.utils import get_openapi

from . import main as api

def init_app(configuration: Type) -> FastAPI:
    settings = configuration()

    app = FastAPI(
        title=settings.APP_NAME,
        description="Convierte lenguaje natural a SQL, consulta la BD y devuelve respuesta.",
        version="0.1.0",
    )
    app.state.settings = settings  # <<-- importante

    allow_origins: List[str] = [o.strip() for o in (settings.ALLOW_ORIGINS or "*").split(",")]
    app.add_middleware(
        CORSMiddleware,
        allow_origins=allow_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(api.router)

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
