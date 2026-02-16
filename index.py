# index.py
from config import config
from src import init_app

# Selecciona el perfil
configuration = config["development"]

# Construye la app FastAPI (ASGI)
app = init_app(configuration)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("index:app", host="127.0.0.1", port=5000, reload=True)

