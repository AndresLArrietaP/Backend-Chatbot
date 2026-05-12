# Backend Analítico SQL — KomfIA (KMMP)

API REST que recibe preguntas en lenguaje natural (español), las convierte a SQL mediante un modelo de lenguaje (LLM), ejecuta las consultas contra Azure SQL Server y devuelve los resultados enriquecidos con análisis estadístico. Integrado con **Microsoft Copilot Studio** como herramienta de consulta conversacional para análisis de aceite de equipos mineros.

---

## Requisitos previos

- Python 3.12
- Acceso a la base de datos Azure SQL Server (credenciales en `.env`)
- Clave de API de Google AI Studio (Gemini) o OpenAI
- Git

---

## Instalación local

```bash
# 1. Clonar el repositorio
git clone <url-del-repositorio>
cd Backend-Chatbot

# 2. Crear y activar el entorno virtual
python -m venv venv

# Windows
venv\Scripts\activate

# macOS / Linux
source venv/bin/activate

# 3. Instalar dependencias
pip install -r requirements.txt
```

---

## Configuración

Crear un archivo `.env` en la raíz del proyecto:

```env
# ── Base de datos ──────────────────────────────────────────────────────────────
DATABASE_URL=mssql+pymssql://USUARIO:CONTRASEÑA@SERVIDOR/BASE_DE_DATOS
DB_DIALECT=mssql
TARGET_SCHEMAS=dbo,Oil,Eqpcare,report,general,module,Mine,Invertex
ALLOWED_SCHEMAS=dbo,Oil,Eqpcare,report,general,module,Mine,Invertex

# ── LLM (modelo de lenguaje) ───────────────────────────────────────────────────
LLM_PROVIDER=gemini                          # gemini | openai
GOOGLE_API_KEY=AIza...                       # clave de Google AI Studio
OPENAI_API_KEY=sk-...                        # solo si LLM_PROVIDER=openai

GEMINI_MODEL=gemini-2.5-flash
GEMINI_MODEL_CANDIDATES=gemini-2.5-flash,gemini-2.5-flash-lite

# ── Timeouts (valores recomendados para pruebas locales) ───────────────────────
DB_QUERY_TIMEOUT=60
REQUEST_TIMEOUT=180
RETRY_TIME_BUDGET=150
MAX_SQL_RETRIES_TOTAL=1
LLM_PER_MODEL_TIMEOUT=45.0
LLM_TOTAL_TIMEOUT=90.0
SQL_MAX_OUTPUT_TOKENS=8000

# ── Respuesta ──────────────────────────────────────────────────────────────────
GENERAR_RESPUESTA_TEXTO=false
INCLUIR_ANALISIS_RESULTADO=true
INCLUIR_SUGERENCIAS_GRAFICO=true
INCLUIR_CHART_URL=false

# ── Contexto conversacional ────────────────────────────────────────────────────
CONTEXTO_CHAT_TTL_MINUTOS=45
CONTEXTO_CHAT_MAX_TURNOS=8
CONTEXTO_CHAT_PERSISTIR_ARCHIVO=true

# ── Servidor ───────────────────────────────────────────────────────────────────
APP_PROFILE=development
PORT=5000
```

> El archivo `.env` nunca se sube al repositorio. Cada desarrollador mantiene su propia copia local.

---

## Arranque del servidor

```bash
# Opción 1 — script directo
python index.py

# Opción 2 — uvicorn con hot-reload (recomendado en desarrollo)
uvicorn index:app --host 127.0.0.1 --port 5000 --reload
```

El servidor queda disponible en `http://127.0.0.1:5000`.  
La documentación interactiva (Swagger UI) en `http://127.0.0.1:5000/docs`.

---

## Endpoints disponibles

| Método | Ruta | Descripción |
|--------|------|-------------|
| `GET`  | `/health` | Healthcheck básico |
| `GET`  | `/llm/ping` | Verifica disponibilidad del LLM |
| `GET`  | `/llm/models` | Lista modelos disponibles |
| `GET`  | `/chat/context/{session_id}` | Recupera historial de conversación |
| `GET`  | `/schema` | Esquema de la BD (cacheado en memoria) |
| `POST` | `/schema/refresh` | Fuerza recarga del caché de esquema |
| `POST` | `/human_query` | **Endpoint principal**: NL → SQL → resultado |
| `POST` | `/sql` | Ejecución directa de SQL (solo lectura) |

### Parámetros de `/human_query`

```json
{
  "human_query":             "string — consulta en lenguaje natural (requerido)",
  "session_id":              "string — ID de sesión para memoria conversacional",
  "execute":                 true,
  "incluir_respuesta_texto": false,
  "reset_contexto":          false,
  "limit":                   200,
  "modo_debug":              false
}
```

---

## Flujo interno de una consulta

```
POST /human_query
  │
  ├─ Recuperar contexto de sesión (TTL 45 min, máx. 8 turnos)
  ├─ ¿Se puede responder desde memoria sin nuevo SQL?
  │     → refinar (filtrar/ordenar resultado previo)
  │
  ├─ Seleccionar esquema relevante (top tablas por scoring)
  │
  ├─ Generar SQL — paths en orden de prioridad:
  │   1. historial_crudo_directo   — registros individuales por equipo/compartimiento
  │   2. ultimo_analisis_flota     — última muestra por equipo (CTE ROW_NUMBER rn=1)
  │   3. tendencia_directo         — AVG mensual 24 meses, sin LLM
  │   4. triage_directo            — última muestra vs LP/LC reales ([Eqpcare].[lc])
  │   5. ranking_directo           — top N equipos por metal (ROW_NUMBER dedup)
  │   6. LLM                       — Gemini hedge paralelo + fallback secuencial
  │
  ├─ Validar y ejecutar SQL [timeout configurable, abandon_on_cancel]
  ├─ Reintento automático si resultado incorrecto (máx. 1 en producción)
  ├─ Análisis estadístico determinístico
  └─ Respuesta JSON enriquecida
```

### Lógica de triage (caso de uso principal)

Cuando el usuario pregunta por el **estado actual** de un conjunto de componentes ("¿cuáles están observados?", "estado de los motores de tracción", "fuera de límite"):

- El sistema evalúa **únicamente la muestra más reciente** de cada equipo (`rn=1`), sin límite superior de fecha.
- Un equipo que estuvo observado el mes pasado pero tiene un análisis reciente normal → aparece como **normal**.
- Los límites LP/LC se obtienen de `[Eqpcare].[lc]` según proyecto y compartimiento.
- **0 filas no es error** — significa que ningún equipo supera sus límites en el último análisis.

---

## Estructura del proyecto

```
Backend-Chatbot/
├── index.py                        Punto de entrada; arranca uvicorn
├── config.py                       Lectura centralizada de variables de entorno
├── requirements.txt                Dependencias con versiones pinneadas
├── openapi_copilot_studio.json     Spec OpenAPI 3.0.3 para importar en Copilot Studio
├── .env                            Variables de entorno (NO versionar)
│
├── src/
│   ├── __init__.py                 Fábrica FastAPI; CORS; warmup de conexión al arranque
│   ├── main.py                     Endpoints, lógica de retry, selección de esquema
│   ├── llm.py                      Heurísticas de dominio; 5 paths directos de SQL; hints LLM
│   ├── database.py                 Introspección de esquema; validación SQL; ejecución
│   ├── analitica.py                Estadísticas, detección de tendencias, gráficos
│   ├── contexto_chat.py            Memoria conversacional por sesión (TTL + disco)
│   └── providers/
│       ├── factory.py              Selecciona proveedor LLM según LLM_PROVIDER
│       ├── gemini_client.py        Cliente Gemini: hedge paralelo + fallback secuencial
│       └── openai_client.py        Cliente OpenAI (fallback)
│
└── test/
    ├── test_conexionazure.py       Valida la conexión a Azure SQL
    ├── test_gemini.py              Prueba el proveedor Gemini
    └── test_openai.py              Prueba el proveedor OpenAI
```

---

## Scripts de prueba

```bash
python test/test_conexionazure.py   # Valida conexión a Azure SQL Server
python test/test_gemini.py          # Prueba el proveedor Gemini
python test/test_openai.py          # Prueba el proveedor OpenAI
```

---

## Seguridad SQL

El sistema aplica múltiples capas de validación antes de ejecutar cualquier SQL:

- Solo se permiten sentencias `SELECT` y CTEs (`WITH ... AS`).
- Se rechazan `INSERT`, `UPDATE`, `DELETE`, `DROP`, `EXEC` y extensiones del sistema (`xp_`).
- Todas las tablas se validan contra un allowlist por esquema.
- Las filas retornadas tienen un límite duro configurable (`MAX_ROWS_HARD`, por defecto 2000).

---

## Despliegue en Render

El proyecto corre en Render Pro (single worker). El despliegue es automático al hacer push a `master`.

**Logs de arranque saludable:**
```
[DB] warmup completado
[startup] Caché de esquema pre-cargado.
```

**Variables críticas en producción (distintas al local):**

| Variable | Local | Render | Motivo |
|----------|-------|--------|--------|
| `DB_QUERY_TIMEOUT` | `60` | `80` | Queries pesadas en Azure pueden tardar 40-60s |
| `REQUEST_TIMEOUT` | `180` | `180` | Copilot Studio tiene un hard limit de 240s |
| `GENERAR_RESPUESTA_TEXTO` | `false` | `false` | Copilot tiene su propio LLM de síntesis |

---

## Integración con Copilot Studio

- La spec `openapi_copilot_studio.json` (versión `3.0.3`) se importa directamente en Copilot Studio.
- Configurar `incluir_respuesta_texto: false` para evitar una segunda llamada al LLM (~30s extra).
- El `session_id` debe mapearse a la variable global de sesión de Copilot para mantener contexto entre turnos.
- Credenciales del conector: seleccionar "Credenciales del conector" (no "del usuario final").
- Hard timeout de Microsoft Copilot Studio: 240s (no configurable).

---

## Dependencias principales

| Paquete | Uso |
|---------|-----|
| `fastapi` | Framework web |
| `uvicorn` | Servidor ASGI |
| `sqlalchemy` | Introspección de esquema y ejecución de queries |
| `pymssql` | Conector Azure SQL Server (sin ODBC Driver requerido) |
| `google-genai` | Cliente Gemini |
| `openai` | Cliente OpenAI (fallback) |
| `python-decouple` | Variables de entorno |
| `anyio` | Cancelación verdadera de threads de BD (`abandon_on_cancel=True`) |
| `pydantic` | Validación de modelos |

> - Andrés A.
