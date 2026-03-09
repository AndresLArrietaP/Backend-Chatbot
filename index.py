# index.py
# -*- coding: utf-8 -*-
"""
Módulo: index
-------------
Punto de entrada de la aplicación FastAPI (ASGI).
"""

from decouple import config as env

from config import config as perfiles
from src import init_app


perfil_activo = env("APP_PROFILE", default="development").strip().lower()
configuracion = perfiles.get(perfil_activo, perfiles["development"])

app = init_app(configuracion)

if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "index:app",
        host=env("HOST", default="127.0.0.1"),
        port=env("PORT", default=5000, cast=int),
        reload=env("DEBUG", default=True, cast=bool),
    )
