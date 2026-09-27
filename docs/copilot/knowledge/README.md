# knowledge/ — Conocimientos (Knowledge) de Copilot Studio

⛔ **Hoy el agente NO tiene ningún Conocimiento cargado, y es deliberado.**

Con Knowledge activo el agente **alucina**: el caso que cerró la discusión fue un «Cr crítico» inventado en
`CA3177 MT LH` cuando ese equipo no tenía nada fuera de límite. El nodo de análisis y el central leen SOLO
la tabla que les llega (`{md}`); cualquier fuente extra reintroduce ese comportamiento y además colisiona
con las instrucciones (los «baches» de la auditoría de agosto).

Estos dos `.docx` se conservan como **referencia** del formato y del esquema, no como entregable:

| Archivo | Qué contiene | Vigencia |
|---|---|---|
| `Esquema_y_Patrones_SQL_MD.docx` | Esquema de la BD y patrones de SQL Server que el LLM generaba mal | Referencia (05/08/26) |
| `Formatos_de_Respuesta_MD.docx` | Plantillas de presentación: matriz vertical, semáforo, anti-ejemplos | Referencia (19/09/26) |

Los equivalentes de la etapa anterior (sin `_MD`) y `Recomendaciones_MT.docx` están en
[`../../../legado/02-copilot-multiagente/knowledge/`](../../../legado/02-copilot-multiagente/knowledge/).

**Si alguna vez se vuelve a cargar Knowledge**, la única forma acotada que se evaluó es un solo documento
«Glosario y contexto de dominio» (apodos de componentes, tipos de aceite por proyecto, notas operativas)
como fuente de **un nodo puntual** — nunca del central ni del nodo de análisis. Hoy no hay ninguna intención
que lo necesite: el glosario vive dentro del prompt del Tema 26 (`../prompts/ayuda_glosario.md`).
