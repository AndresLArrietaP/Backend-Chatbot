# Config canónica — Flujos, Temas y Prompt (aplicar en Copilot Studio)

Fuente de verdad tras la auditoría ([AUDITORIA_KOMFIA_2026-08.md](AUDITORIA_KOMFIA_2026-08.md)).
**Reglas:** `vista` y `columna` van **fijas en la Acción** (NUNCA como Entrada del modelo) salvo donde se
indique; el modelo solo llena `equipo/compartimiento/parametro/proyecto/modelo`. Toda vista expone
`MD`(+variantes)/`Observados`/`Recomendaciones`. Tras cada Acción: **Condición** `md está en blanco` →
**Mensaje** "No encontré datos para esa consulta — verifica que el equipo/proyecto exista o tenga muestras." →
Fin. Los flujos ya llevan `if(empty(...Table1),'',first(...)?['Col'])` en cada salida.

## 1) FLUJOS reutilizables (4 — retirar el legacy `Barrido_Detalle`)
Todos: query FIJO; solo cambia el valor de `vista`. Salidas `md`/`observados`/`recomendaciones` con
`if(empty(...))`. **Descripciones de salida (todas):** `md`="Bloque markdown ya armado; imprimir tal cual." ·
`observados`="Componente:metales observados; insumo del análisis (NULL si no aplica)." ·
`recomendaciones`="Bloque verbatim de recomendaciones + cierre; imprimir tal cual (NULL si no aplica)."

| Flujo | Entradas (desc) | Query fijo |
|---|---|---|
| **MD_equipo** | `vista`,`equipo`,`columna` | `SELECT ⟦columna⟧ AS MD, Observados, Recomendaciones FROM ⟦vista⟧ WHERE Equipo LIKE '%⟦equipo⟧%'` |
| **MD_equipo_comp** | `vista`,`equipo`,`compartimiento`,`columna` | `... WHERE Equipo LIKE '%⟦equipo⟧%' AND compAbbr LIKE '%⟦compartimiento⟧%'` |
| **MD_metal** | `vista`,`equipo`,`compartimiento`,`parametro`,`columna` | `... WHERE Equipo LIKE '%⟦equipo⟧%' AND compAbbr LIKE '%⟦compartimiento⟧%' AND Parametro='⟦parametro⟧'` — **agregar salidas observados/recomendaciones (contrato, H3)** |
| **MD_flota** | `vista`,`proyecto`,`modelo`,`columna` | `... WHERE Proyecto LIKE '%⟦proyecto⟧%' AND Modelo LIKE '%⟦modelo⟧%'` |

**Descripción de entradas (todas las que aplican):** `vista`="Vista *MD a consultar (se fija por tema)." ·
`equipo`="Código de equipo (ej. CA3177)." · `compartimiento`="Componente abreviado: MT LH/MT RH/RD LH/RD RH/
Sist. Hidr./Motor. Traduce apodos. `todos`=todos los componentes." · `parametro`="Símbolo del metal: Fe, Cu,
Cr, Pb, Sn, Si, Zn… Traduce cobre→Cu." · `proyecto`="Proyecto/mina (ej. Antapaccay)." · `modelo`="Modelo (ej.
980E); `todos`=todos los modelos." · `columna`="Variante de la vista (se fija por tema; ej. MD, MD_Completo,
MD_Relevantes, DetalleTodosMD, MD_Criticos, MD_Precaucion)."

## 2) PROMPT (AI Builder / Solicitud) — ÚNICO universal
`Análisis de aceite` (Modelo GPT-4.1 mini). **1 entrada** `tabla` (Texto) = `{md}`; salida record →
imprimir `{analisis.text}`. Instrucciones = `docs/copilot/prompts/analisis_prompts.md` (prompt universal).
Sin conocimiento. Se usa en: último, condición, diagnóstico, tendencia detalle, tendencia de un metal, triage.

## 3) TEMAS (descripción de trigger + Entradas del modelo + Acción)
Nodos estándar con análisis: **Acción**(flujo)→**Mensaje** `{md}`→**Acción** Prompt(`tabla={md}`)→**Mensaje**
`{analisis.text}`→**Mensaje** `{recomendaciones}`→**Condición sin-data**→**Finalizar**. Los "sin análisis"
omiten los 2 nodos de Solicitud/análisis.

### Último análisis de componente · con análisis
- **Desc:** "Último análisis de aceite de UN componente. «último análisis del MT LH del CA3177», «cómo salió el hidráulico del X». Rellena `equipo`,`compartimiento`. ⛔ NO para el equipo completo (Diagnóstico) ni la flota."
- **Entradas:** `equipo`,`compartimiento`. **Acción:** `MD_equipo_comp`, `vista=vw_UltimoAnalisisMD`, `columna=MD`.

### Condición MT · con análisis
- **Desc:** "Estado de los Motores de Tracción (MT LH y RH) de UN equipo. «condición del MT del X», «cómo están los motores de tracción del X». Rellena `equipo`. ⛔ NO otro componente ni flota."
- **Entradas:** `equipo`. **Acción:** `MD_equipo`, `vista=vw_CondicionMT_MD`, `columna=MD`.

### Diagnóstico equipo · con análisis
- **Desc:** "ESTADO ACTUAL de TODOS los componentes de UN equipo (matriz componentes×parámetros). «diagnóstico del CA3177», «cómo está el equipo X», «último análisis general del X». ⛔ NO historial (Historial), un componente (Último), ni flota (Barrido/Triage)."
- **Entradas:** `equipo`. **Acción:** `MD_equipo`, `vista=vw_DiagnosticoMD`, `columna=MD` (fija; `MD_Completo` solo si piden «todos los metales/completo» → entonces sí exponer `columna` con esa descripción).

### Tendencia paso 1 · sin análisis
- **Desc:** "Evolución de las últimas muestras de UN componente, SIN nombrar metal. «tendencia del MT LH del X», «cómo ha evolucionado el hidráulico del X». Rellena `equipo`,`compartimiento`. ⛔ NO si nombran un metal (Tendencia de un metal)."
- **Entradas:** `equipo`,`compartimiento`. **Acción:** `MD_equipo_comp`, `vista=vw_TendenciaP1MD`, `columna=MD`. Cierra ofreciendo detalle/gráfica.

### Tendencia detalle · con análisis
- **Desc:** "Detalle de la tendencia de UN componente: metales×fechas + LP/LC + Σvida + Spark + Resumen estadístico. Tras la tendencia general, «detalle por elemento», «la matriz de metales», «muéstrame todos los parámetros». Rellena `equipo`,`compartimiento`. ⛔ NO si nombran un metal."
- **Entradas:** `equipo`,`compartimiento`. **Acción:** `MD_equipo_comp`, `vista=vw_TendenciaMD`, `columna=MD`.

### Tendencia relevantes · con análisis
- **Desc:** "Solo los parámetros fuera de umbral de la tendencia de UN componente (tabla si hay, mensaje si no). «solo los relevantes de la tendencia del X», «los observados de la tendencia». Rellena `equipo`,`compartimiento`."
- **Entradas:** `equipo`,`compartimiento`. **Acción:** `MD_equipo_comp`, `vista=vw_TendenciaMD`, `columna=MD_Relevantes`.

### Tendencia de un metal · con análisis
- **Desc:** "Tendencia de UN metal en TODOS los componentes de un equipo (tabla rápida + resumen estadístico). «tendencia del cobre del X», «cómo ha variado el Fe del X». Rellena `equipo`,`parametro`. ⛔ NO si nombran componente (eso es metal-en-componente / gráfico)."
- **Entradas:** `equipo`,`parametro`. **Acción:** `MD_metal`, `vista=vw_TendenciaMetalMD`, `compartimiento=todos`, `columna=MD`.

### Gráfica de un metal · sin análisis
- **Desc:** "Gráfica de tendencia de UN metal ESPECÍFICO en UN componente (tabla del metal + gráfico ASCII). «gráfica del Cromo del MT LH del X», «la curva del Fe del hidráulico del X». Rellena `equipo`,`compartimiento`,`parametro`."
- **Entradas:** `equipo`,`compartimiento`,`parametro`. **Acción:** `MD_metal`, `vista=vw_TendenciaGraficoMD`, `columna=MD`.

### Gráficas de observados · sin análisis
- **Desc:** "Gráfica(s) de los metales OBSERVADOS de un componente, SIN nombrar metal. «la gráfica», «las gráficas», «ahora la gráfica», «la gráfica de ello». Toma `equipo`,`compartimiento` del contexto. NO preguntar metal."
- **Entradas:** `equipo`,`compartimiento`. **Acción:** `MD_equipo_comp`, `vista=vw_TendenciaGraficoObsMD`, `columna=MD`.

### Historial general del equipo · sin análisis
- **Desc:** "REGISTRO CRONOLÓGICO de UN equipo: todas las muestras de TODOS sus componentes por fecha. «historial del CA3171», «bitácora del equipo X», «las muestras del X en el tiempo». Rellena `equipo`. ⛔ NO estado actual (Diagnóstico)."
- **Entradas:** `equipo`. **Acción:** `MD_equipo`, `vista=vw_HistorialEquipoMD`, `columna=MD`.

### Historial (de un componente) · sin análisis
- **Desc:** "Bitácora cronológica de UN componente de un equipo. «historial del MT LH del X», «bitácora del hidráulico del X». Rellena `equipo`,`compartimiento`. ⛔ NO si nombran metal."
- **Entradas:** `equipo`,`compartimiento`. **Acción:** `MD_equipo_comp`, `vista=vw_HistorialMD`, `columna=MD`.

### Historial de un metal (en el equipo) · sin análisis
- **Desc:** "Historial cronológico de UN metal en TODOS los componentes de un equipo. «historial del Fe del CA3171», «cómo ha venido el cobre en el equipo X». Rellena `equipo`,`parametro`. ⛔ NO si nombran componente."
- **Entradas:** `equipo`,`parametro`. **Acción:** `MD_metal`, `vista=vw_HistorialMetalEquipoMD`, `compartimiento=todos`, `columna=MD`.

### Historial de un metal en un componente · sin análisis
- **Desc:** "Historial cronológico de UN metal en UN componente específico. «historial del Cromo del MT LH del X», «cómo ha venido el Fe del hidráulico del X». Rellena `equipo`,`compartimiento`,`parametro`."
- **Entradas:** `equipo`,`compartimiento`,`parametro`. **Acción:** `MD_metal`, `vista=vw_HistorialMetalMD`, `columna=MD`.

### Historial de observados de flota · sin análisis
- **Desc:** "Historial de análisis OBSERVADOS recientes de toda una flota/mina. «historial de observados de Antapaccay», «qué se ha observado en la flota de X». Rellena `proyecto`."
- **Entradas:** `proyecto`. **Acción:** `MD_flota`, `vista=vw_HistorialFlotaMD`, `modelo=todos`, `columna=MD`.

### Barrido resumen · sin análisis
- **Desc:** "Flota COMPLETA de una MINA/proyecto (VARIOS equipos), resumen. «barrido de Antapaccay», «la flota de X», «todos los equipos de X». Rellena `proyecto`,`modelo`. ⛔ NO un equipo (Diagnóstico) ni MT observados (Triage)."
- **Entradas:** `proyecto`,`modelo`. **Acción:** `MD_flota`, `vista=vw_ObservadosResumenMD`, `columna=MD` (FIJA — quitar de Entradas, H1).

### Barrido detalle · sin análisis (consolidar a MD_flota, H2)
- **Desc:** "Detalle del barrido de una flota, agrupado por componente (todos, críticos arriba). «detalle de todos», «el detalle del barrido», «completo». Rellena `proyecto`,`modelo`."
- **Entradas:** `proyecto`,`modelo`. **Acción:** `MD_flota`, `vista=vw_ObservadosBarridoMD`, `columna=DetalleTodosMD` (FIJA). ⛔ Retirar el flujo legacy `Barrido_Detalle`.

### Barrido filtrado · sin análisis
- **Desc:** "Detalle del barrido SOLO de un tipo: críticos o precauciones. «solo los críticos», «solo las precauciones», «los críticos del barrido». Rellena `proyecto`,`modelo` y `columna` (críticos→`MD_Criticos`, precauciones→`MD_Precaucion`)."
- **Entradas:** `proyecto`,`modelo`,`columna` (**sí Entrada**, el modelo la infiere). **Acción:** `MD_flota`, `vista=vw_ObservadosBarridoMD`.

### Triage MT · con análisis
- **Desc:** "Motores de Tracción OBSERVADOS de una flota, críticos arriba (caso de uso principal). «MT observados de Antapaccay», «qué motores de tracción necesitan atención en X». Rellena `proyecto`. ⛔ NO un equipo (Condición) ni otros componentes."
- **Entradas:** `proyecto`. **Acción:** `MD_flota`, `vista=vw_TriageMD`, `modelo=todos`, `columna=MD`.
