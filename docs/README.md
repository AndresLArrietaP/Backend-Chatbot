# docs/ — Documentación del proyecto

Entregables organizados por audiencia. Los `.docx`/`.pptx` se generan desde `tools/`
(ver `tools/README.md`).

```
docs/
├── copilot/                          # Todo lo que se pega/sube a Copilot Studio (solo .docx)
│   ├── KomfIA_central.docx           ← instrucción del agente orquestador KomfIA
│   ├── KomfIA_SQL.docx               ← instrucción del sub-agente KomfIA SQL
│   └── knowledge/                    ← documentos de Conocimiento (subir como archivos)
│       ├── Recomendaciones_MT.docx     → KomfIA Central
│       ├── Esquema_y_Patrones_SQL.docx → KomfIA SQL
│       └── Formatos_de_Respuesta.docx  ← plantillas de presentación (matriz vertical + semáforo) → KomfIA Central
├── arquitectura/                     # Diseño, hoja de ruta y DDL
│   ├── PLAN_PIVOTE_MULTIAGENTE.md / .docx
│   ├── DocumentacionTecnica_BackendChatbot.docx
│   ├── DDL_indices.sql               ← índices a crear en la BD
│   ├── DDL_vistas.sql                ← TODAS las vistas (12): cadena v3.2 + barrido + diagnóstico/tendencia/historial pre-formateados (vw_UltimoAnalisisFlota/DiagnosticoEquipo/TendenciaElemento/HistorialMuestra) + Sodio. Correr de corrido (F5)
│   └── VALIDACION_SSMS.sql           ← scripts de prueba en SSMS (12 vistas, barrido/diagnóstico/tendencia, COBERTURA de lc). Solo lecturas
└── gerencia/
    └── CONFIA_Presentacion_Gerencia.pptx
```

## Qué documento usar

| Necesito… | Documento |
|---|---|
| Instrucción del agente orquestador (pegar en Copilot) | `copilot/KomfIA_central.docx` |
| Instrucción del sub-agente generador de SQL (pegar en Copilot) | `copilot/KomfIA_SQL.docx` |
| Documentos de Conocimiento (subir como archivos al agente) | `copilot/knowledge/*.docx` |
| Crear los índices / vistas en la base de datos | `arquitectura/DDL_indices.sql` · `arquitectura/DDL_vistas.sql` |
| Entender el pivote a multiagente | `arquitectura/PLAN_PIVOTE_MULTIAGENTE.md` (o `.docx`) |
| Entender la arquitectura del backend | `arquitectura/DocumentacionTecnica_BackendChatbot.docx` |
| Presentar el proyecto a gerencia | `gerencia/CONFIA_Presentacion_Gerencia.pptx` |

> En `copilot/` el texto de las instrucciones va en bloque de código/cita (monoespaciado), pensado
> para copiarse y pegarse tal cual. Regenerar: `python tools/generar_instrucciones.py`
> (instrucciones) y `python tools/generar_conocimiento.py` (knowledge).
