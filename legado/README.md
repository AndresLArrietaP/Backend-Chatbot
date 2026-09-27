# legado/ — lo que KomfIA fue y ya no es

Nada de esta carpeta está en uso. Se conserva porque **explica de dónde salió el sistema actual** y porque
parte del conocimiento de dominio que hoy vive en las vistas SQL se escribió primero acá.

La historia completa, con fechas: [`../docs/BITACORA.md`](../docs/BITACORA.md).

```
legado/
├── 01-python-api/            Hito 1 · 2026-02-13 → 2026-06-06
├── 02-copilot-multiagente/   Hito 2 · 2026-06-13 → 2026-07-24
└── generadores/              los scripts que produjeron los .docx de ambos hitos
```

---

## 01-python-api/ — la API REST (Hito 1)

El backend FastAPI que recibía la pregunta, la convertía a SQL con Gemini (OpenAI como respaldo), la
ejecutaba en Azure SQL y devolvía JSON enriquecido. Desplegado en **Render**, expuesto a Copilot Studio con
`openapi_copilot_studio.json`, y en desarrollo vía túnel ngrok.

| Archivo | Qué era |
|---|---|
| `index.py` · `config.py` | entrada y configuración por variables de entorno |
| `src/main.py` (93 KB) | endpoints + la lógica de reintentos de SQL |
| `src/llm.py` (135 KB) | **la causa del pivote**: ~25 heurísticas regex de dominio + generadores de SQL en Python |
| `src/database.py` | introspección de esquema, validación de seguridad (solo `SELECT`/CTE), ejecución |
| `src/analitica.py` | estadísticas, sugerencia de gráfico, recomendaciones de Motor de Tracción |
| `src/contexto_chat.py` | memoria conversacional por sesión con TTL |
| `src/providers/` | clientes de Gemini (con *hedging* en paralelo) y OpenAI |
| `test/` | 3 scripts sueltos (conexión a Azure, Gemini, OpenAI) — no pytest |
| `openapi_copilot_studio.json` | el contrato que Copilot Studio consumía como herramienta |
| `.cache/contexto_chat.json` | último estado persistido de la memoria de sesión |

**Qué se portó de aquí a las vistas SQL:** el `CROSS JOIN` de límites con `ISNULL(LP, 9999)` como fallback
seguro, la exclusión de muestras DDI, los textos de recomendaciones de MT, la validación de SQL y la lista
real de columnas de `[Oil].[LaboratoryData]`.

**Si hiciera falta correrlo** (no debería): necesita `venv/` y `.env`, que siguen en la raíz del repositorio
porque están fuera de control de versiones. Las rutas de los comandos del README original ya no coinciden:
hay que ejecutarlo desde esta carpeta.

---

## 02-copilot-multiagente/ — instrucciones y conocimientos previos al Tier 2 (Hito 2)

La etapa en que un sub-agente («KomfIA SQL», Claude Sonnet 4.6) escribía el SQL y el central pintaba la
tabla. Funcionaba, pero cada respuesta pasaba por **dos LLM** — lento y no determinista.

| Archivo | Qué era | Reemplazado por |
|---|---|---|
| `KomfIA_central.docx` | instrucción del orquestador (≤ 8000 caracteres) | `docs/copilot/KomfIA_central_MD.docx` |
| `KomfIA_SQL.docx` | instrucción del sub-agente generador de SQL | `docs/copilot/KomfIA_SQL_MD.docx` |
| `knowledge/Recomendaciones_MT.docx` | recomendaciones como Conocimiento del central | columna `Recomendaciones` de las vistas |
| `knowledge/Esquema_y_Patrones_SQL.docx` | esquema + patrones de SQL Server que el LLM erraba | versión `_MD`, hoy solo de referencia |
| `knowledge/Formatos_de_Respuesta.docx` | plantillas de presentación (matriz vertical, semáforo) | la columna `MD` de cada vista |
| `PLAN_PIVOTE_MULTIAGENTE.md` / `.docx` | **el documento de decisión del 2026-06-05** que cerró el Hito 1 | — |
| `PRUEBAS_ALFA_PRODUCCION.docx` | el primer banco formal: 28 consultas en lenguaje natural (22/06) | `docs/pruebas/PRUEBAS_ALFA_COMANDOS.md` |

⚠ El agente **no tiene ningún Conocimiento cargado hoy, y es deliberado**: con Knowledge alucina (inventó un
«Cr crítico» inexistente en `CA3177`). Ver [`../docs/copilot/knowledge/README.md`](../docs/copilot/knowledge/README.md).

`PLAN_PIVOTE_MULTIAGENTE.md` vale una lectura aunque esté archivado: es el diagnóstico de por qué los
parches sobre las heurísticas regex no convergían.

---

## generadores/ — los scripts que producían los .docx

Todos **obsoletos**. Los `.docx` que quedan vivos (`docs/copilot/*_MD.docx`) se editan **directo**: son la
fuente de verdad, y regenerarlos perdería las ediciones a mano. Así lo dice también el `.gitignore`.

| Script | Producía | Por qué está acá |
|---|---|---|
| `generar_instrucciones.py` | `KomfIA_central.docx`, `KomfIA_SQL.docx` | los `.docx` se editaron a mano y divergieron del script |
| `generar_conocimiento.py` | `knowledge/*.docx` | ídem; y hoy no se carga Knowledge |
| `generar_formatos.py` | `Formatos_de_Respuesta.docx` | el formato lo arma ahora la columna `MD` de la vista |
| `generar_documentacion.py` | `DocumentacionTecnica_BackendChatbot.docx` | documentaba el backend Python (está en `01-python-api/docs/`) |
| `generar_plan_pivote.py` | `PLAN_PIVOTE_MULTIAGENTE.docx` | el plan ya se ejecutó |
| `generar_ppt_confia.py` | `CONFIA_Presentacion_Gerencia.pptx` | presentación de una etapa anterior |
| `generar_seguimiento_pedidos.py` | `SEGUIMIENTO_Pedidos_partes_interesadas.docx` | el seguimiento vive hoy en el acta (editada vía XML) |
| `agregar_comparativa.py` | — | editaba un `.docx` que ya no existe |

El único generador vivo es [`../tools/gen_comandos_card.py`](../tools/gen_comandos_card.py), que produce la
Adaptive Card de `/comandos`.
