# tools/ — Generadores de documentación

Scripts que producen los entregables de `docs/`. No forman parte del runtime del backend;
se ejecutan manualmente cuando hay que actualizar un documento. El TEXTO fuente de cada
documento vive dentro de su script (son la fuente de verdad).

Ejecutar desde la raíz del proyecto con el intérprete del venv:

```bash
python tools/generar_instrucciones.py    # → docs/copilot/KomfIA_central.docx + KomfIA_SQL.docx
python tools/generar_conocimiento.py     # → docs/copilot/knowledge/*.docx (3 documentos)
python tools/generar_plan_pivote.py      # → docs/arquitectura/PLAN_PIVOTE_MULTIAGENTE.docx (desde el .md)
python tools/generar_documentacion.py    # → docs/arquitectura/DocumentacionTecnica_BackendChatbot.docx
python tools/generar_ppt_confia.py       # → docs/gerencia/CONFIA_Presentacion_Gerencia.pptx
```

| Script | Salida | Notas |
|---|---|---|
| `generar_instrucciones.py` | `docs/copilot/KomfIA_central.docx`, `KomfIA_SQL.docx` | ⚠️ DESFASADO: las instrucciones son v2.5/v2 hand-edited (matriz vertical, semáforo, Ca/Zn/K/Mg). Los .docx son la fuente canónica; editar el .docx directamente, NO regenerar. |
| `generar_conocimiento.py` | `docs/copilot/knowledge/*.docx` | ⚠️ DESFASADO: los .docx fueron editados a mano (vistas v3.2, DDI asimétrico). Los .docx son la fuente canónica; NO regenerar sin portar esas ediciones. Editar el .docx directamente. |
| `generar_formatos.py` | `docs/copilot/knowledge/Formatos_de_Respuesta.docx` | Plantillas de presentación (matriz vertical + semáforo) con respuestas-modelo completas y anti-ejemplo. Fuente del FORMATO de salida; escalable (agregar tipo de consulta = agregar plantilla). |
| `generar_plan_pivote.py` | `docs/arquitectura/PLAN_PIVOTE_MULTIAGENTE.docx` | Renderiza el `.md` fuente a Word. El `.md` es la fuente única. |
| `generar_documentacion.py` | `docs/arquitectura/DocumentacionTecnica_BackendChatbot.docx` | Documentación técnica del backend. |
| `generar_ppt_confia.py` | `docs/gerencia/CONFIA_Presentacion_Gerencia.pptx` | Presentación ejecutiva para gerencia. |
| `agregar_comparativa.py` | — | ⚠️ OBSOLETO: editaba un docx que ya no existe. No usar. |

Dependencias: `python-docx`, `python-pptx` (en el venv). Si faltan:
`pip install python-docx python-pptx`.
