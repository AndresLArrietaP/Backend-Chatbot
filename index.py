# index.py
# -*- coding: utf-8 -*-
"""
Módulo: index
-------------
Punto de entrada de la aplicación FastAPI (ASGI).

- Selecciona el perfil de configuración.
- Construye la app con `src.init_app`.

Ejecución:
- En desarrollo: `uvicorn index:app --reload --port 5000`
- O `python index.py` (usa uvicorn.run interno).
"""

from config import config as perfiles
from src import init_app

# Perfil activo
configuracion = perfiles["development"]

# App FastAPI (ASGI)
app = init_app(configuracion)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("index:app", host="127.0.0.1", port=5000, reload=True)