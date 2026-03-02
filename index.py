# index.py
# -*- coding: utf-8 -*-
"""
Módulo: index
--------------
Punto de entrada de la aplicación FastAPI (ASGI).
Selecciona el perfil de configuración y construye la app con `init_app`.
"""

from config import config as perfiles
from src import init_app

# Selecciona el perfil
configuracion = perfiles["development"]

# Construye la app FastAPI (ASGI)
app = init_app(configuracion)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("index:app", host="127.0.0.1", port=5000, reload=True)

