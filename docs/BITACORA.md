# BITÁCORA de KomfIA — consolidado histórico

> **Qué es este documento.** La historia completa del proyecto, de su primer commit a hoy, contada por
> hitos. No es un backlog (eso es [copilot/PENDIENTES.md](copilot/PENDIENTES.md)) ni una guía de
> configuración (eso es la familia `CONFIG_*`). Es el documento que responde *«¿por qué el sistema es
> así y no de otra manera?»* — y que evita volver a pagar lecciones ya pagadas.
>
> **Cómo se armó.** Cruzando las **fechas** de los 346 commits del repositorio (2026-02-13 → 2026-09-27)
> con los documentos de cada etapa, las actas de gerencia y las notas de las marchas de prueba. Cada
> afirmación con fecha está anclada a un commit o a un documento fechado.
>
> **Última actualización:** 2026-09-27.

---

## KomfIA en una frase

Un asistente que responde en lenguaje natural preguntas sobre **análisis de aceite de flotas mineras**
de KMMP — «¿qué motores de tracción de Antapaccay están observados?», «¿cómo viene el hierro del
CA3171?» — leyendo la base de datos de confiabilidad `bd_kmmp_osconfiabilidad` (Azure SQL) y
devolviendo tablas con semáforo, límites reales del área y una lectura analítica.

Lo que cambió tres veces no fue **qué** hace, sino **quién** lo hace: primero un backend Python, luego
un agente de IA que escribía SQL, hoy la propia base de datos.

---

## Línea de tiempo de una ojeada

| Hito | Fechas | Qué era el sistema | Cómo terminó |
|---|---|---|---|
| **1 · API REST en Python** | 2026-02-13 → 2026-06-06 | FastAPI + Gemini traducían la pregunta a SQL; Copilot Studio lo llamaba como herramienta | Murió por dos cosas: ~25 expresiones regulares frágiles y el **timeout de 240 s** de Copilot Studio |
| **2 · Multiagente (SQL + vistas)** | 2026-06-13 → 2026-07-24 | Un sub-agente («KomfIA SQL») escribía el SQL; **vistas** de SQL Server hacían el cálculo; el central presentaba | Funcionó, pero cada respuesta pasaba por **dos LLM** → lento y no determinista |
| **3 · Tópicos determinísticos (Tier 2)** | 2026-08-02 → hoy | La **vista devuelve el markdown ya armado** y el tópico lo imprime *verbatim*. Sin LLM en la ruta de render | Vivo. 47 vistas, 28 tópicos (25 activos), 20 comandos `/` |
| **4 · Tarjetas con datos** | planificado | Adaptive Cards mostrando los datos de los módulos, no solo el menú | [copilot/tarjetas/PLAN_TARJETAS_DATOS.md](copilot/tarjetas/PLAN_TARJETAS_DATOS.md) |

**Volumen de trabajo por mes** (commits): feb 19 · mar 35 · abr 37 · may 29 · jun 59 · jul 26 · ago 129 ·
sep 12. Los dos picos cuentan la historia: **junio** es el pivote a vistas, **agosto** es la migración a
tópicos determinísticos.

---

# HITO 1 · La API REST en Python

**2026-02-13 → 2026-06-06 · 122 commits · hoy archivado en [`../legado/01-python-api/`](../legado/01-python-api/)**

### Qué era

```
Usuario (Teams / Copilot Studio)
   → herramienta HTTP  POST /human_query
      → src/main.py        (router, heurísticas, reintentos de SQL)
      → src/llm.py         (~25 regex de dominio + paths SQL directos en Python)
      → Gemini Flash       (pregunta → SQL)         ← o OpenAI como respaldo
      → src/database.py    (valida que sea SELECT, ejecuta en Azure SQL)
      → src/analitica.py   (estadísticas, sugerencia de gráfico, recomendaciones MT)
      → src/contexto_chat.py (memoria de sesión con TTL)
   ← JSON enriquecido
```

Desplegado en **Render**, expuesto a Copilot Studio con un `openapi_copilot_studio.json`, y en desarrollo
a través de un túnel **ngrok** (`PUBLIC_BASE_URL` reescribía el OpenAPI). Dos proveedores de LLM
intercambiables por variable de entorno, con *hedging* en paralelo entre modelos de Gemini.

### Sub-hitos

| Fecha | Sub-hito |
|---|---|
| **13/02** | Primer commit. |
| **16/02** | «FASTAPI funciona». |
| **18-19/02** | La API key funciona y **la IA genera SQL** por primera vez. Empieza el ciclo «MEJORAR PROMPT». |
| **22-27/02** | Consistenciado; gráficas; `EXPLAIN`. **27/02: primeras pruebas en KMMP.** |
| **02-03/03** | «BACKEND FUNCIONAL» → «BACKEND PARA AGENTE»: se reorienta de API genérica a backend de un agente. |
| **04/03** | **Primer test contra Azure SQL.** |
| **05/03** | **Primera versión con data de producción.** Empieza la pelea real con los JOINs del esquema. |
| **07-09/03** | CTE / window functions / `COALESCE`; continuidad conversacional. «BACKEND LISTO». |
| **24/03** | **A producción, con frontend web.** (Sí: hubo un frontend propio antes de que todo viviera en Teams.) |
| **26/03 → 04/04** | **La guerra del timeout de 240 s** (ver abajo). |
| **19/04 → 06/06** | Versionado disciplinado: `0.3.1` … `0.6.8`. El nombre **KomfIA** aparece en los mensajes de commit desde la `0.4.0` (06/05). |
| **22/05** | Marcha blanca con partes interesadas. Se confirman los límites reales de `[Eqpcare].[lc]` y se descubre que Cuajone no tiene límites cargados. |
| **26/05** | **Comparación KomfIA (Python) vs «TEST SQL V2»** — el flujo de Power Automate del área de TI que ejecuta SQL directo contra Azure. 10 consultas cada uno. El backend Python no salió ganando. Este es el punto de inflexión que hizo pensable el pivote. |
| **05/06** | Documento de decisión arquitectónica: se abandona el camino Python. |
| **06/06** | `0.6.8` — último commit que toca `src/`. |

### La guerra del timeout de 240 s (26/03 → 04/04) — 10 commits seguidos

Copilot Studio corta una herramienta HTTP a los **240 segundos**. Consultas de 40-60 s en Azure SQL, más
el LLM, más un segundo LLM para redactar la respuesta, se pasaban. Se intentó, en orden:

1. Pre-filtro de fecha en el CTE y ventana de −3 años.
2. `asyncio.wait_for` por llamada a BD.
3. `asyncio.shield` + propagar `HTTPException 408`.
4. Timeout a nivel Python + log del SQL en Render.
5. **La cura real:** `anyio.to_thread.run_sync(..., abandon_on_cancel=True)`.

El punto 5 merece recordarse porque es una lección general: el `run_in_threadpool` de FastAPI usa
`cancellable=False`, así que al vencer el timeout **esperaba a que el hilo de la base de datos terminara**,
bloqueando el event loop — la respuesta HTTP nunca salía antes de los 240 s. Con `abandon_on_cancel=True`
el hilo se abandona y el 408 sale en milisegundos.

En paralelo se recortaron los prompts (~80 % en triage), se subió `SQL_MAX_OUTPUT_TOKENS` a 8000 porque
3400 truncaba los CTE con 4+ JOINs, y se apagó por defecto `GENERAR_RESPUESTA_TEXTO` (Copilot ya tiene su
propio LLM: la segunda llamada a Gemini Pro costaba ~30 s de nada).

### Por qué se abandonó

El documento del **05/06** (conservado en
[`../legado/02-copilot-multiagente/PLAN_PIVOTE_MULTIAGENTE.md`](../legado/02-copilot-multiagente/PLAN_PIVOTE_MULTIAGENTE.md))
nombra la causa raíz sin rodeos: **no era código mal escrito, era la arquitectura**. Los tres bugs
reportados ese día eran el mismo bug con tres caras:

| Síntoma | Causa |
|---|---|
| «tendencia del MT RH» devolvía 24 meses de promedios | `MT RH` no matcheaba ningún regex → caía al LLM con una pista contradictoria |
| `Cr = 3.95` con `LC = 3` no alertaba | El Flash de Copilot leyó «Alerta MT: Fe y PQ primero» como «solo mira Fe» |
| Las recomendaciones no salían | El backend **sí** las generaba; el Flash las descartaba |

**El patrón:** cada frase nueva («MT RH» vs «motor de tracción», con o sin tilde) era un regex nuevo — una
cola infinita de bugs. Y aun cuando el regex acertaba, el modelo de Copilot arruinaba la interpretación.
Se estaba peleando contra el modelo, no contra el código.

### Qué sobrevive de este hito

El código está archivado, no borrado, porque **el conocimiento de dominio se portó desde aquí**:

- el patrón `CROSS JOIN` de límites con `ISNULL(LP, 9999)` como fallback seguro,
- la exclusión de muestras DDI,
- los textos de recomendaciones de Motor de Tracción (`_recomendaciones_mt`),
- la validación de seguridad de SQL (solo `SELECT`/CTE, allowlist de tablas, tope de filas),
- y la lista de columnas reales de `[Oil].[LaboratoryData]`.

Todo eso vive hoy dentro de las vistas y de `DDL_vistas.sql`. El resto (heurísticas regex, generadores de
SQL en Python, gestión de contexto, hedging de LLM) quedó sin uso.

> ⚠ **El backend Python está inutilizado desde junio de 2026.** No participa en ninguna respuesta. Su
> código está además *desfasado* respecto de las vistas actuales: no sirve como referencia de lógica de
> negocio, solo como registro histórico.

---

# HITO 2 · Multiagente: el SQL sale del Python y entra a la base

**2026-06-13 → 2026-07-24 · ~85 commits · artefactos retirados en [`../legado/02-copilot-multiagente/`](../legado/02-copilot-multiagente/)**

### Qué era

```
Usuario (Teams)
   → KomfIA Central          (orquestador; instrucción ≤ 8000 caracteres)
      → sub-agente «KomfIA SQL»   (Claude Sonnet 4.6: pregunta → SQL)
         → flujo «TEST SQL V2»     (Power Automate; ejecuta el SQL en Azure SQL)
            → vistas vw_*           ← ¡el cálculo pesado ya vive acá!
      ← KomfIA Central presenta la tabla + recomendaciones (Conocimientos)
```

Dos cosas cambiaron de raíz:

1. **El cálculo bajó a la base de datos.** En vez de que Python armara el SQL a mano, se crearon **vistas**
   (`vw_MuestrasEstado` como *fundación*, y encima `vw_ObservadosResumen`, `vw_DiagnosticoEquipo`,
   `vw_TendenciaElemento`, `vw_HistorialMuestra`, …). El agente ya no inventaba lógica de negocio:
   consultaba una vista que ya tenía los límites, el semáforo y el desempate resueltos.
2. **Ya no había servidor propio.** Sin Render, sin ngrok, sin API key nuestra: Copilot Studio + Power
   Automate + Azure SQL. El ejecutor era **TEST SQL V2**, el flujo del área de TI — la misma pieza que en
   mayo había ganado la comparación contra el backend.

> 📌 **Aclaración de nombres.** El plan del 05/06 evaluó dos variantes: **A** = backend propio con un
> modelo fuerte, **B** = todo dentro de Copilot Studio. Se implementó la **B**. En las notas posteriores se
> la llamó «Ruta A» con el sentido de *«la ruta que no pasa por el backend Python»*. Son la misma cosa;
> las dos etiquetas aparecen en documentos de la época.

### Sub-hitos

| Fecha | Sub-hito |
|---|---|
| **13/06** | Primer commit de `docs/`: vistas + `VALIDACION_SSMS.sql` + instrucciones de Copilot. Nace la disciplina de que **todo SQL de prueba va numerado a un solo archivo**. |
| **14-17/06** | Módulos: diagnóstico por equipo (tabla ancha), `vw_UltimoAnalisisFlota`, tendencia en 2 pasos, Sodio (Na) y V100. |
| **15-21/06** | **Historial**, y sus 5 variantes. Aparece el problema del *corte de render*: tablas de 18 metales se truncaban → se proyectan solo las columnas de la variante, nunca `SELECT *`. |
| **22/06** | Set de **28 consultas de prueba alfa-producción** (el primer banco de pruebas formal). |
| **23/06** | Ronda de latencia: ventana de **12 meses** en la fundación, `HorasComponente` vía JOIN a `HsCc` pre-rankeado (no subconsulta correlacionada), y nace `DIAGNOSTICO_LATENCIA.sql`. |
| **25-27/06** | Marcha blanca 2. La instrucción central se recorta a < 8000. **Continuidad = reúso solo del último turno** (un caso mostró datos obsoletos de `CA3174`). Diccionario escalable de apodos de componentes. |
| **28-29/06** | Saga del **gráfico ASCII**: se regeneraba mal al re-pedirlo → primero «copia exacta del turno anterior», luego la cura de fondo — **pre-computarlo en la vista** (`Grafico`, `Spark`). Primera vez que se aplica la idea de «que lo calcule el SQL, no el modelo». |
| **30/06 - 01/07** | Marcha alfa: **anti-alucinación**. Los ejemplos de las instrucciones usaban códigos de equipo reales (`CA3171`) y el modelo los devolvía como si fueran datos → se erradican a favor de `CAxxxx`. Y los «esqueletos» de tabla se rellenaban con *placeholders* en vez de datos → toda tabla **re-delega** al SQL. |
| **10/07** | **1ª reunión con gerencia. KomfIA aprobado; Antamina entra al alcance.** Cinco pedidos: matriz de barrido, acumulado Σvida, gráfico más grande, velocidad, exportar a PDF/Excel. Ese mismo día: matriz por componente, Σvida por metal, gráfico de 12×9, y el primer script de índices. |
| **13-23/07** | Ronda del barrido: ambos límites (LP **y** LC) por metal, cuadro de límites como matriz componente×metal, filtro del detalle por palabra («solo»), y la cura del multi-query — **el detalle es UNA sola delegación**. |
| **14-15/07** | Banco de preguntas y respuestas en Excel para las pruebas alfa (con espacio para capturas). |
| **24/07** | **Hallazgo:** Copilot mide las instrucciones en **UTF-16**, y los emojis astrales cuentan 2. El central «de 8000» eran en realidad 8015 → rechazado al guardar. Se recorta a 7960. |

### Por qué se cambió otra vez

Funcionaba, pero cada respuesta pasaba por **dos LLM**: el sub-agente escribía el SQL y el central pintaba
la tabla. Eso traía tres problemas que no se arreglan con prompts:

- **Lentitud.** Una consulta simple (un conteo, un ranking) tardaba 30-45 s: el hijo emitía JSON y el padre
  lo copiaba. Dos llamadas de LLM para algo que es un `SELECT COUNT(*)`.
- **No determinismo.** Tres corridas de la misma pregunta daban tres tablas distintas.
- **Cortes.** Si el payload era grande, el render se truncaba o devolvía `SystemError` / `BadGateway`.

La conclusión fue la misma que en el hito 1, un nivel más arriba: **mientras un LLM esté en la ruta de
render, la salida no es determinista.** Había que sacarlo.

---

# HITO 3 · Tópicos determinísticos (Tier 2) — el sistema actual

**2026-08-02 → hoy · ~140 commits**

### La idea, en una línea

> **La vista devuelve el markdown ya armado; el tópico lo imprime tal cual.** Ningún LLM toca la tabla.

Eso es «Tier 2». El primer caso fue `vw_ObservadosBarridoMD` el **02/08**: en vez de devolver filas para que
alguien las pinte, la vista devuelve una columna `MD` con la tabla markdown completa, y el tópico la imprime
*verbatim*. La consecuencia práctica es enorme: **renombrar una columna o reordenar parámetros es trabajo de
SQL, no de Copilot**, y la misma pregunta da siempre la misma respuesta.

### Arquitectura actual

```
Usuario (Teams)
   ├── escribe «/triage antapaccay»            → Tema 00 Comandos (cascada de condiciones Power Fx)
   └── escribe en lenguaje natural             → KomfIA Central (orquestador: rutea POR DESCRIPCIÓN)
        ↓
   Tema NN  (28 temas; 25 activos)
        ├── Acción → uno de los 4 flujos reutilizables (MD_equipo, MD_flota, MD_metal, MD_ranking)
        │              + flujos dedicados (MD_triage, MD_incipiente, MD_acumflota, …)
        │       └── Ejecutar consulta SQL (V2) → vista vw_*MD  →  columnas MD / Observados / Recomendaciones
        ├── Mensaje  {md}                       ← se imprime VERBATIM
        ├── Solicitud «Análisis de aceite»      ← prompt universal, SIN conocimiento; solo lee {md}
        ├── Mensaje  {analisis.text}
        └── Mensaje  {recomendaciones}          ← deterministas, de la vista
   ↓
   Sin tema que aplique → sub-agente «KomfIA SQL» (fallback: SELECT simple, formatea su salida)
```

Piezas y su documento canónico:

| Pieza | Dónde se configura |
|---|---|
| 47 vistas (`vw_*`, `*_MD`) | [arquitectura/DDL_vistas.sql](arquitectura/DDL_vistas.sql) |
| 28 temas + descripciones de ruteo | [copilot/CONFIG_TEMAS.md](copilot/CONFIG_TEMAS.md) |
| 4 flujos reutilizables + dedicados | [copilot/CONFIG_FLUJOS.md](copilot/CONFIG_FLUJOS.md) |
| 20 comandos `/` + tarjeta | [copilot/CONFIG_COMANDOS.md](copilot/CONFIG_COMANDOS.md) · [copilot/tarjetas/](copilot/tarjetas/) |
| Prompts (análisis universal, ayuda, fallback) | [copilot/CONFIG_PROMPTS.md](copilot/CONFIG_PROMPTS.md) · [copilot/prompts/](copilot/prompts/) |
| Reintentos y cortes | [copilot/CONFIG_TIMEOUT.md](copilot/CONFIG_TIMEOUT.md) |
| Pruebas | [arquitectura/VALIDACION_SSMS.sql](arquitectura/VALIDACION_SSMS.sql) (136 bloques) · [pruebas/](pruebas/) |

### Sub-hitos

| Fecha | Sub-hito |
|---|---|
| **02-04/08** | Nace Tier 2 con el barrido. Spec del render determinístico. |
| **05/08** | **Plan maestro de migración** y la regla de **handoff limpio**: cuando un módulo pasa a tópico, se retira del central — si no, viejo y nuevo colisionan. Se crean copias `_MD` dejando las vistas originales intactas. |
| **06-07/08** | Los **8 módulos** migran en dos días: diagnóstico, último análisis, condición MT, tendencia (paso 1, detalle, un metal, gráfico), historial (5 variantes), triage MT. Aparece el **contrato fijo** de toda vista: `MD` / `Observados` / `Recomendaciones`. |
| **07/08** | **Un solo prompt de análisis, universal.** Antes había uno por módulo; el `{md}` ya trae la estructura y el modelo la reconoce. Y una regla que se ganó con sangre: el nodo va **SIN conocimiento** — con Knowledge inventó un «Cr crítico» inexistente en `CA3177`. |
| **07-08/08** | Feedback de gerencia sobre límites (`Limites.xlsx`): **Pb y Sn sí tienen LC crítico** (se creía que no) → se propaga a barrido y triage. V100/viscosidad entra como informativo (no dispara `Estado_General`: los límites de viscosidad solo están aterrizados en Antapaccay). Y `V100 = 0` pasa a ser SIN DATO, no crítico — eran 196 falsos positivos. |
| **08/08** | La configuración se separa en la **familia `CONFIG_*`** (temas / flujos / prompts, luego comandos y timeout). Descripciones de tema numeradas y finales. |
| **09/08** | **El central se adelgaza a orquestador puro.** Conteo (21) y Ranking (22) pasan a temas deterministas, relevando al fallback. Tendencia incipiente (20) — pedido de gerencia: MT que se desviaron de su promedio **sin** superar límite. Se eliminan hardcodes tipo «Antapaccay = 980E». |
| **10-12/08** | **El orquestador rutea SOLO por descripción.** El fallback competía con los temas («barrido… de cada motor de tracción» caía al fallback y devolvía JSON crudo) → su descripción se reescribe por lo que **NO** hace. El fallback pasa a `SELECT` simple (pre-agregar daba `BadGateway`), formatea su propia salida y **nunca se niega** (negarse dispara «Remitir a un superior»). Default Antapaccay, intuitivo y no restrictivo. |
| **15/08** | Tema 25 (último análisis por metal en la flota), Tema 26 (**Ayuda/Glosario**, tipo Prompt sin SQL — hogar de las preguntas conceptuales). Los límites de referencia salen de la matriz a una **tabla aparte**, por pedido de gerencia. |
| **19/08** | Ronda de latencia L8 y el **anti-patrón nº 1**: leer `vw_DiagnosticoEquipo` **dos veces** en la misma vista. Se cura en triage y en barrido leyendo la fundación una sola vez. Nace `CONFIG_TIMEOUT.md` (3 capas: sin reintentos + `PT100S` + tema de Error). |
| **22-23/08** | Módulo **Acumulados** (temas 27/28): envuelve las vistas del dashboard «Ranking de Atención». Se envuelve `vw_RankingHistorico` (última foto), **no** `vw_RankingAtencion`. |
| **23/08 - 05/09** | **Comandos `/`**. Hallazgo: el autocompletado de `/` es del canal (Teams/Discord), no de Copilot → el tema «00 Comandos» es un handler programático: `IsMatch(^/[A-Za-z])` como compuerta no invasiva, parseo en Power Fx y cascada de «Ir a otro tema». El `else` debe ser Mensaje + Finalizar: «Ir a Conversación» no re-rutea a NL. |
| **15-17/09** | **Adaptive Card de `/comandos`**. Dos trampas: la tarjeta necesitaba `Action.Submit` pero eso bloqueaba la conversación → se manda como «Enviar un mensaje»; y los placeholders `<proyecto>` desaparecían (markdown los borra como etiqueta HTML) → se usan `‹ ›`. Se versiona el generador `tools/gen_comandos_card.py`. |
| **18/09** | **1ª alfa viva con gerencia** (Teams de desarrollo). Formato de tablas, rendimiento y determinismo quedan **resueltos**; salen 5 pedidos nuevos. |
| **23/09** | **Ronda de feedback de Carlos** (analista de aceite del área): 14 observaciones sobre los módulos «Por Equipo». |
| **25-27/09** | Se cierran los **7 bloques A-G** de esa ronda. Lo más visible: `vw_TriageMD` pasa de **113.780 ms a 860 ms** con una sola lectura de la fundación, y deja de ser inestable. Los contadores y las marcas de toda la app derivan ahora de **una sola fuente de verdad**. |

### Estado hoy (27/09/2026)

- **Notificado a Carlos** para nuevas pruebas en los módulos «Por Equipo». El feedback de «Por Flota» vendrá
  después.
- **Único pendiente de fondo de la ronda:** el bloque **B** — la cifra Σvida de **6 785,39** no es
  reproducible con ningún criterio (se probaron ventanas de 12 a 60 meses, todos los tipos de muestra y los
  18 parámetros; el histórico completo desde 2020 da 18 372,32). Está a la espera de que Carlos diga sobre
  qué universo la calculó.
- **Rendimiento parcial:** `vw_TendenciaMD` (~35 s) y `vw_TendenciaMetalMD` (~30 s) medidos con el operador
  de producción son los siguientes candidatos al mismo tratamiento que el triage.

---

# HITO 4 · Lo que viene

**Tarjetas adaptables con datos**, no solo el menú de comandos: ver
[copilot/tarjetas/PLAN_TARJETAS_DATOS.md](copilot/tarjetas/PLAN_TARJETAS_DATOS.md) (arquitecturas A/B,
límites reales, piloto y verificaciones). El techo conocido: **las Adaptive Cards no tienen scroll**, así
que la palanca no es «caber más» sino **paginar**.

---

# Las leyes que el proyecto pagó caro

Esta sección es el verdadero valor de la bitácora: siete reglas que costaron días y que se violan con
facilidad si nadie las escribió.

### 1 · Mientras un LLM esté en la ruta de render, la salida no es determinista
Dos veces se intentó arreglar la variación con mejores prompts (hitos 1 y 2). Las dos fracasaron. La cura
fue estructural: sacar al modelo del render (Tier 2). El modelo sigue, pero **solo lee** la tabla ya hecha.

### 2 · Un CTE referenciado dos veces, con un JOIN entre sus ramas, es una bomba
Los CTE de SQL Server **no se materializan**: cada referencia se vuelve a ejecutar, y el JOIN entre ramas
degenera en *nested loops*. Es el anti-patrón que produjo el barrido de 6:21 y el triage de 15 minutos.
**Cura:** agregar en la misma fila con `OUTER APPLY`, o usar una función de ventana. Nunca un segundo JOIN
a lo mismo.

### 3 · Medir con el operador de producción
`= 'Antapaccay'` y `LIKE '%Antapaccay%'` difieren **5×**. El `=` es más rápido porque permite el
*predicate push-down*; el sistema usa `LIKE`. Medir con `=` escondió una regresión hasta que estalló en
producción como `FlowActionTimedOut`.

### 4 · Traducir vocabularios es trabajo del flujo; filtrar es trabajo del SQL
Se intentó normalizar «mt lh» → `TRACCION` con un `CASE` dentro del `WHERE` de la vista. El optimizador no
pudo plegarlo a una constante, se bloqueó el push-down, y la consulta pasó de **4 s a más de 15 minutos**.
La normalización se movió a una acción «Redactar» del flujo, antes de la consulta.

### 5 · Copilot rutea por descripción, y mide en UTF-16
- El orquestador elige un tema **solo** por su descripción — no por el nombre, no por ejemplos internos.
  Para desempatar temas que compiten: descripción dominante y concisa, desénfasis del competidor, y una
  línea de ruteo en el central.
- El tope de la descripción de un tema es **1024 caracteres UTF-16**; el de las instrucciones, **8000**. Los
  emojis astrales cuentan **2**. Al recortar, se quitan ejemplos antes que anclas de ruteo (`⛔…`).

### 6 · Los fallos silenciosos son de dos tipos, y solo uno se arregla con `ISNULL`
- **Modo A** — `MD` sale `NULL` porque un `LEFT JOIN` sin guardar devolvió `NULL` y concatenar `NULL` anula
  toda la cadena. Se cura envolviendo **cada celda** en `ISNULL(…, '—')`.
- **Modo B** — la consulta devuelve **0 filas** por un `INNER JOIN` o un `GROUP BY`. `ISNULL` no puede hacer
  nada: hay que corregir el JOIN.

Los dos terminan en «no encontré datos», y por eso se confunden. Y un `CREATE VIEW` con columnas inválidas
**se guarda igual** y revienta recién al consultarla: tras cada despliegue de DDL hay que correr el smoke
test.

### 7 · Hay tres vocabularios de componente y confundirlos cuesta un `Msg 207`
| Vocabulario | Ejemplo | Dónde |
|---|---|---|
| `Compartimiento` | `MOTOR DE TRACCION LH` | valor real en la BD, vistas de la fundación |
| `compAbbr` | `MT LH`, `Sist. Hidr.` | **salida** de las vistas `*_MD` — es por acá que se filtra |
| `CompTipo` | `TRACCION`, `HIDRAULICO` | triage e incipiente |

En una sola ronda se cometió el mismo `Invalid column name 'Compartimiento'` **cinco veces** consultando una
vista `_MD`. La regla: **leer el `SELECT` final de la vista antes de consultarla.**

### Y dos del dominio, que no son técnicas
- **Límites invertidos.** Los aditivos (`Ca`, `Zn`, `P`, `Mg`, `B`, `Mo`) y el `TBN` tienen `LP > LC`: la
  alerta es **por debajo**, porque el aditivo se agota. **Excepción:** en Motor de Tracción, `Ca`/`Zn`/`Mg`
  son **contaminantes** y la alerta es por encima. El grupo de la tabla manda sobre el nombre del parámetro.
- **0 filas puede ser la respuesta correcta.** El caso de uso principal del producto es preguntar por el
  universo completo de un tipo de componente y recibir **solo los observados**. Ninguno observado es un
  resultado válido, no un error.

---

# Cronología de las partes interesadas

Porque el sistema cambió tanto por feedback como por arquitectura.

| Fecha | Quién | Qué salió de ahí |
|---|---|---|
| **27/02** | KMMP | Primeras pruebas del backend. |
| **22/05** | Partes interesadas | Marcha blanca: se confirman los límites reales de `[Eqpcare].[lc]`; Cuajone sin límites cargados. |
| **26/05** | — | KomfIA (Python) vs TEST SQL V2. El backend no gana. |
| **10/07** | **Gerencia (1ª reunión)** | **Aprobado.** Antamina entra al alcance. 5 pedidos: matriz de barrido, acumulado, gráfico más grande, velocidad, PDF/Excel. |
| **17/07** | Gerencia | Revisión de pendientes. |
| **24/07** | Gerencia | Acta como registro vivo; se presenta cada viernes. |
| **07/08 y 14/08** | Gerencia | `Limites.xlsx` (Pb/Sn con LC); baseline de la tendencia incipiente = promedio de las 6 previas sin la última; límites de referencia en tabla aparte. |
| **18/09** | **Gerencia (1ª alfa viva)** | Formato, rendimiento y determinismo **resueltos**. 5 pedidos nuevos. |
| **23/09** | **Carlos** (analista de aceite del área) | 14 observaciones sobre «Por Equipo» → los 7 bloques A-G, cerrados el 27/09. Queda su respuesta sobre el universo de Σvida (bloque B). |

Registro oficial: `docs/gerencia/ACTA DE REUNION_PROYECTOS DE DESARROLLO CONFIABILIDAD.xlsx` — se
**edita vía XML directo**, nunca con openpyxl (borra el logo y los checkboxes).

---

# Notas sobre la base de datos

- **Viva:** `[Oil].[LaboratoryData]` a través de `[Mine].[MiningEquipment]` / `[Mine].[EquipmentFleet]`.
- **Congelada:** la tabla legacy `[dbo].[OilAnalysis]` se detuvo el **2025-10-20**. Ante un reporte de «data
  vieja», revisar la **fuente** antes que los filtros de fecha.
- **Solo lectura.** No hay permisos DDL/DML: `CREATE OR ALTER VIEW` y los `SELECT` sí; `CREATE FUNCTION` y
  `CREATE INDEX` requieren al DBA.
- **Esquema canónico:** `arquitectura/ESQUEMA_BD.xlsx` — 1964 filas, e **incluye las 49 vistas** `vw_*`, a
  diferencia del `schema_bd.json` que se usaba antes. Toda columna se cruza contra ese Excel antes de
  escribir SQL.
- `[Mine].[MiningEquipment]` **no** tiene columna `Model`: el modelo está en `[Mine].[EquipmentFleet].[Model]`.
- El límite del conector SQL de Power Automate es **120 s**.
- Los valores reales de `Compartimiento` son `MOTOR DE TRACCION RH/LH`, `RUEDA DELANTERA RH/LH`,
  `SISTEMA HIDRAULICO`, `MOTOR`. Para el `LIKE` siempre una palabra única (`'%TRACCION%'`), nunca una frase
  compuesta (`'%MOTOR TRACCION%'` falla: hay un «DE» en medio).

---

# Dónde está qué, hoy

```
Backend-Chatbot/
├── docs/
│   ├── BITACORA.md              ← este documento
│   ├── arquitectura/            ← SQL y diseño (lo que se despliega en la BD)
│   ├── copilot/                 ← configuración del agente + backlog único
│   ├── pruebas/                 ← set vigente + registros de marcha congelados
│   ├── gerencia/                ← actas y fuentes oficiales del área
│   └── avance-semanal/          ← un reporte por semana y por proyecto
│        └── (también alimenta una automatización propia en Claude Desktop)
├── tools/                       ← generador de la tarjeta de comandos
└── legado/                      ← hitos 1 y 2, archivados
    ├── 01-python-api/
    ├── 02-copilot-multiagente/
    └── generadores/
```

Detalle de cada carpeta en [README.md](README.md). Qué hay archivado y por qué, en
[../legado/README.md](../legado/README.md).
