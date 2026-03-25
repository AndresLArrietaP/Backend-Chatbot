# index.py
# -*- coding: utf-8 -*-
"""
Módulo: index
-------------
Punto de entrada ASGI de la aplicación FastAPI.

Flujo de arranque:
    1. Lee APP_PROFILE desde el entorno (.env).
    2. Selecciona la clase de configuración correspondiente (ej. DevelopmentConfig).
    3. Construye la app FastAPI vía init_app(configuracion).
    4. Si se ejecuta directamente, lanza uvicorn con host/puerto desde el .env.

Arranque en desarrollo:
    python index.py
    uvicorn index:app --host 127.0.0.1 --port 5000 --reload

Arranque en producción (Render):
    uvicorn index:app --host 0.0.0.0 --port $PORT
"""

from decouple import config as env

from config import config as perfiles
from src import init_app


# Selecciona el perfil activo; cae a "development" si no existe el perfil indicado
perfil_activo = env("APP_PROFILE", default="development").strip().lower()
configuracion = perfiles.get(perfil_activo, perfiles["development"])

# Instancia de la aplicación FastAPI (referenciada por uvicorn como "index:app")
app = init_app(configuracion)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "index:app",
        host=env("HOST", default="127.0.0.1"),
        port=env("PORT", default=5000, cast=int),
        reload=env("DEBUG", default=True, cast=bool),
    )
