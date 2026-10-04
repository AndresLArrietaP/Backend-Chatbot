# KomfIA — Pruebas de alfa · **set completo, versión 03-oct-2026**

Cada prueba va **emparejada**: la consulta en **lenguaje natural** y su **`/comando`** equivalente. Los dos
caminos deben dar **el mismo resultado**; el comando no cambia la lógica, solo dispara el tema con
parámetros explícitos.

> ⚠ **Esta versión reemplaza la del 25-sep.** Entre medias entró la ronda del **28/09** (Carlos + gerencia,
> módulos **por flota**) y los pedidos del 01/10. Lo que sigue es lo que KomfIA hace **hoy**.

**Lo que cambió respecto del set anterior:**

| Antes | Ahora |
|---|---|
| `/barrido` (resumen por equipo) · `/conteo` | **`/panel`** — cómo está la mina. `/barrido` y `/conteo` son **alias** |
| `/tendenciametal ‹eq› ‹metal›` | **retirado** → `/grafica ‹eq› ‹comp› ‹metal›` (responde con un mensaje que lo indica) |
| `/ranking ‹proj› ‹comp› ‹metal› [top]` | + **`[modelo]`**: `/ranking Antapaccay tracción Fe 980 5` |
| un comando incompleto respondía «No encontré datos» | **pregunta lo que falta** (equipo, componente, metal) — 11 módulos |
| solo `3160` o `CA3160` | también **`T3160`** (código de Cummins) |
| `/tendencia` y `/grafica`: dos tablas con las mismas fechas | **una sola tabla**; en `/grafica` el metal va **primero** |
| historial con «Met. Obs.» | las **5 familias** del formato con su valor: `Fe (232.6) 🟥` |
| triage con «Metales Obs.» | **5 columnas por familia** (Desgaste · Aditivos · Contaminación · Salud · Cód. Limpieza) |
| 20 comandos | **18** |
| **(03/10)** `/ultimo` y `/tendencia` sin límite en P, B, V100 ni ISO | **los 30 parámetros con su límite**; viscosidad como banda (`70.1–85.7`); ISO **entero** |
| **(03/10)** `/incipiente ‹proj› [comp]` | + **`[modelo]`** · categoría **🟥/🟨 cruzó** · límites por modelo |
| **(03/10)** `/historialmetal … P` traía P, PQ y Pb | solo el metal pedido |
| **(03/10)** `/triage 3195` → «No encontré datos» | lleva al **diagnóstico** de ese equipo |

---

## Antes de probar

1. **DDL desplegado** — `docs/arquitectura/DDL_vistas.sql` corrido entero en SSMS.
2. **Prompt `Análisis de aceite`** (`docs/copilot/prompts/analisis_prompts.md`) y herramienta **`Formato`**
   (`formateo_fallback.md`), los dos **sin conocimiento**.
3. **Instrucciones** de la central y de KomfIA SQL pegadas (`docs/copilot/KomfIA_central_MD.docx`, `KomfIA_SQL_MD.docx`).
4. **Tarjeta `/comandos`** pegada: **18 comandos**, con `/panel` en la sección de flota.
5. **Temas desactivados:** 03, 05, 08, 21, 23 y 24.
6. Al revisar capturas: **mirar la insignia «Generado por la IA»** antes de creerse una tabla.

---

## N0 · Base

| # | Lenguaje natural | Comando | Esperado |
|---|---|---|---|
| 1 | ¿Cuántos equipos 980E tiene Antapaccay? | `/panel Antapaccay 980` | panel de la mina: equipos · observados · por componente · dónde empezar |
| 1b | *(el mismo, con los nombres viejos)* | `/conteo Antapaccay 980` · `/barrido Antapaccay 980` | **idéntico a #1** — alias |

## N1 · Estado actual de un componente

| # | Lenguaje natural | Comando | Esperado |
|---|---|---|---|
| 2 | ¿Cómo están los motores de tracción del CA3161? | `/condicionmt 3161` | los dos MT lado a lado, **23 filas** de la hoja MT, en ~1-2 s |
| 3 | Último análisis del MT LH del CA3160 | `/ultimo 3160 mt lh` | tabla `Par. \| LP \| LC \| Valor` con las 23 filas |
| 3b | *(el mismo, pegado)* | `/ultimo 3160 mtlh` | **idéntico a #3** |
| 3c | *(código de Cummins)* | `/ultimo T3160 mt lh` | **idéntico a #3** — encuentra el CA3160 |
| 4 | Último análisis de la rueda delantera derecha del CA3160 | `/ultimo 3160 rdrh` | 🔴 los **aditivos** (`Ca`, `Zn`, `Mg`) marcados por estar **bajo** su límite |

## N2 · Diagnóstico del equipo completo

| # | Lenguaje natural | Comando | Esperado |
|---|---|---|---|
| 5 | Diagnóstico del CA3160 | `/diagcompleto 3160` | **SMR (horómetro)** bajo el título · grupo **Muestra** (Fec. últ. · H. Comp. · T. muestra) · matriz de 31 parámetros × componentes · pie de `Ca`/`Mg`/`Mo`/`Zn` |
| 5b | ¿Cómo está el equipo 3160? | `/diagnostico 3160` | **lo mismo** — alias |

## N3 · Universo de un tipo de componente (flota)

| # | Lenguaje natural | Comando | Esperado |
|---|---|---|---|
| 6 | ¿Qué motores de tracción de Antapaccay están observados? | `/triage tracción Antapaccay` | todos los equipos, críticos primero, **5 columnas por familia** con valor y chip 🟥/🟨, en ~3 s |
| 6b | *(la mina primero)* | `/triage antapaccay` | **igual que #6** — sin componente, toma tracción |
| 7 | ¿Qué sistemas hidráulicos de Antapaccay se están disparando? | `/incipiente Antapaccay hidráulico` | alerta temprana: los que suben **sin** pasar el límite |
| 8 | Top 5 de hierro en los MT de los 980E de Antapaccay | `/ranking Antapaccay tracción Fe 980 5` | ranking descendente, solo 980E |
| 8b | Top 5 de cobre en el hidráulico de Antapaccay | `/ranking Antapaccay hidráulico Cu 5` | ranking del hidráulico (acepta `hidráulico`, `hidr`, `tracción`, `mt`…) |
| 8c | Último hierro y cobre de los MT de Antapaccay | `/metalflota Antapaccay tracción Fe,Cu` | **una** tabla por metal, de mayor a menor |

## N4 · Tendencia (multi-muestra)

| # | Lenguaje natural | Comando | Esperado |
|---|---|---|---|
| 9 | Tendencia del MT LH del CA3160 | `/tendencia 3160 mt lh` | **una sola tabla**: fechas arriba · grupo **Muestra** (SMR, horas, CM, estado, grado) · grupos de parámetros · Acum · Spark |
| 9b | Detalle de la tendencia del MT LH del CA3160 | `/tendenciadet 3160 mt lh` | **idéntico a #9** |
| 10 | *(tras #9)* «el resumen estadístico» | — *(continuación)* | Prom · σ · Acum · Nº fuera de límite |
| 11 | Gráfica del Fe del MT LH del CA3160 | `/grafica 3160 mt lh Fe` | **una sola tabla con la fila del Fe primero** · resumen del período · límites · curva ASCII |
| 11b | *(comando retirado)* | `/tendenciametal 3160 Fe` | mensaje: «se unió a /grafica…» con el ejemplo |
| 12 | *(tras #9)* «la gráfica de los observados» | — *(continuación)* | una curva por metal observado |

## N5 · Panel y barrido de flota

| # | Lenguaje natural | Comando | Esperado |
|---|---|---|---|
| 13 | ¿Cómo está la flota de Antapaccay? · «barrido de Antapaccay» | `/panel Antapaccay` | cabecera · por componente con «lo que más se repite» · por modelo · dónde empezar |
| 14 | *(tras #13)* «el detalle del barrido» | `/barridodet Antapaccay` | detalle equipo por equipo, agrupado por componente |
| 15 | *(tras #14)* «solo los críticos» | — *(continuación)* | solo los críticos (tema 18). ⚠ Sin críticos, debe **decirlo** |
| 15b | ¿Cuántos equipos hay en Antapaccay? | — | el **panel** (#13) |

## N6 · Historial (cronológico, vertical)

| # | Lenguaje natural | Comando | Esperado |
|---|---|---|---|
| 16 | Historial del MT LH del CA3160 en 2 meses | `/historial 3160 mt lh 2 meses` | una fila por muestra · Estado · **5 familias** con lo fuera de límite y su valor |
| 17 | Historial del CA3161 en 2 meses | `/historialeq 3161 2 meses` | lo mismo con la columna **Componente** |
| 18 | Historial del Fe del CA3160 | `/historialmetal 3160 Fe` | un metal en el tiempo (sin cambios) |
| 18b | Observados de la flota de Antapaccay en el último mes | `/historialflota Antapaccay 1 mes` | `Fe (232.6)` en Observados · componente en **MAYÚSCULAS** · **ninguna** fila con «Observados = —» |

## N7 · Acumulados (motor diésel)

| # | Lenguaje natural | Comando | Esperado |
|---|---|---|---|
| 19 | «acumulados» *(a secas)* | — | el **ranking de flota** (27), no el de equipo |
| 20 | «acumulados de Antapaccay» | `/rankingacum Antapaccay` | el ranking de flota |
| 21 | «acumulados del CA3177» | `/acumulados 3177` | el **equipo** (28) |
| 22 | Ranking de acumulados en gráfica | `/rankinggraf Antapaccay` | barras ASCII con las bandas 60/65/70 |

## N8 · Continuidad y deixis

| # | Secuencia | Esperado |
|---|---|---|
| 23 | `/tendencia 3160 mt lh` → «y la gráfica» | las gráficas **del mismo** equipo y componente |
| 24 | `/diagcompleto 3160` → «y el 3161» | el diagnóstico del 3161 |
| 25 | `/rankingacum Antapaccay` → «ahora los del CA3177» | cambia de flota a equipo **sin arrastrar** el tema |
| 25b | `/barrido antapaccay 980` → «solo los críticos» | **solo** equipos CA (conserva el modelo) |

⚠ **Correr cada secuencia por separado**: si se encadenan, la continuidad de una pisa a la siguiente.

## N9 · El sistema pregunta lo que falta — **nuevo**

Comando incompleto ⇒ **pregunta**, nunca «No encontré datos». En el panel de actividad debe verse
**00 Comandos → el tema**, y nada de «Remitir a un superior».

| # | Comando | Esperado |
|---|---|---|
| 26 | `/ranking` | pregunta el componente → `tracción` → pregunta el metal → `Fe` → top 10 |
| 27 | `/ultimo` | pregunta el equipo → `3160` → el componente → `mt lh` → último análisis |
| 28 | `/grafica 3160 Fe` | pregunta **el componente** (reconoce que `Fe` es el metal) |
| 29 | `/grafica 3160 mtlh` | pregunta **el metal** |
| 30 | `/metalflota antapaccay tracción` | pregunta los metales (`Fe,Cu`) → **una** respuesta, sin un `•` suelto delante |
| 31 | `/condicionmt` · `/diagcompleto` · `/historialeq` · `/acumulados` | preguntan el equipo |

## N10 · Casos límite — **lo que debe DECIR, no fallar**

| # | Caso | Comando | Mensaje esperado |
|---|---|---|---|
| 32 | Equipo **sano** | `/diagcompleto 3175` | «ninguno de sus N componentes tiene parámetros fuera de límite» |
| 33 | Modelo **sin límites** | `/panel Antapaccay 930E` | «930E no tiene límites cargados» y «Sin límites cargados: no hay con qué evaluar» — **no** «dentro de límites» |
| 34 | Modelo **sin observados** | `/barridodet Antapaccay 930E` | «No hay equipos observados con esos criterios…» |
| 35 | Componente **sin límites** en la tendencia | `/tendencia ‹equipo de Cuajone› motor` | los valores salen + «⚠ Sin límites (LP/LC) cargados…» |
| 36 | Equipo **inexistente** | `/diagcompleto CA9999` | «no se encontraron registros» |
| 37 | Comando **mal escrito** | `/barido Antapaccay` | «no reconocí /barido. Escribe /comandos» |
| 38 | Parámetro que **no se mide** | `/grafica 3160 mt lh Mo` | el análisis explica que no hay valores en las últimas muestras |
| 39 | Consulta **sin módulo** (fallback) | «cómo evolucionó el Fe en los MT de la flota» | respuesta en **viñetas** con prefijo **🔎** — **nunca** una tabla |

---

## N11 · Lo que se vio el 02/10 — testigo CA3195 — **nuevo 03/10**

| Consulta | Debe salir |
|---|---|
| `/ultimo 3195 mt lh` | P `280.0 · 240.0 · 290.2` sin marca (aditivo sobre su LP = sano) · V100 `— · 70.1–85.7 · 75.1` · ISO>6 `19 · 20 · 20 🟨` (enteros) · PQ 233.2 🟥 |
| `/tendencia 3195 mt lh` | fila Estado 🟥 🟢 🟥 🟢 🟥 🟥 = la del historial · ISO con valores enteros · pie de informativos |
| `/grafica 3195 mt lh ISO>6` | «(código)», marcas sin decimal, «últimas 6 muestras» |
| `/incipiente antapaccay` | **CA3195 MT LH 🟥 cruzó LC · PQ 55.1→233.2 (+323%)** primero · 5 de 54 evaluados |
| `/incipiente antapaccay 980` · `… hidr` | «980E» en el título · en hidráulicos columna **Modelo** y límites por modelo (Si 980E 9/10, D475A 30/60) |
| `/historial 3195 MTLH 6 meses` | 35 muestras (el componente pegado ya no falla) |
| `/historialmetal 3195 P mt lh` · `/historialmetal 3195 B` | solo P (título `LP 280.0 · LC 240.0`) · solo B, sin Pb |
| `/triage 3195` | una línea («el triage es de la flota…») y el diagnóstico completo del CA3195 |

---

## N12 · El flujo de uso de Carlos, encadenado — **nuevo 04/10**

Una sola conversación, en orden, siguiendo al CA3195 de la mina al metal ([CONFIG_COMANDOS](../copilot/CONFIG_COMANDOS.md) § Flujo de uso).

| # | Consulta | Debe pasar |
|---|---|---|
| 1 | `/panel antapaccay 980` | CA3195 en «Dónde empezar» (MT LH con crítico) |
| 2 | `/incipiente antapaccay` | CA3195 MT LH 🟥 cruzó LC primero |
| 3 | `/triage tracción antapaccay 980` | CA3195 entre los observados de MT |
| 3b | `/panel 3195` · `/incipiente 3195` | **pases**: diagnóstico del CA3195 · tendencia del CA3195 (pregunta el componente) |
| 4 | `/historialflota antapaccay` | rápido (~2 s de SQL) |
| 5 | `/diagcompleto 3195` | MT LH con PQ 🟥 |
| 6 | `/condicionmt 3195` | LH vs RH **con ISO, Mo, V40 y Agua** (antes «—») |
| 7 | `/ultimo 3195 mt lh` | P/B/V100/ISO con límite |
| 8 | `/tendencia 3195 mt lh` | Estado = el del historial · ISO entero |
| 9 | `/grafica 3195 mt lh PQ` | 233.2 🟥 sobre LC 150 |
| 10 | `/historial 3195 mt lh` · `/historialmetal 3195 PQ mt lh` · `/historialeq 3195` | los tres rápidos (~0,5 s de SQL tras el 200) |
| NL | «el último análisis del hidráulico del 3195» | sale la tabla (necesita el `comp_key` en `MD_equipo_comp`) |

---

## ⚠ Limitaciones conocidas — lo que KomfIA **no** hace hoy

Conviene tenerlas a mano al enseñar el sistema, para no prometer de más.

| Limitación | Detalle |
|---|---|
| **Carga y límites del área** | 885 componentes sin ningún límite (salen sin evaluar) · 347 con ISO en 0 · 1 579 muestras de Cerro Verde sin componente · Antamina sin LP de Ca/Zn/Mg · ruedas de Antapaccay con el límite de otro aceite. Detalle para Carlos en `docs/copilot/PENDIENTES.md`, PASO 6 |
| **El código ISO no cuenta igual en todos lados** | Triage, historiales y tendencia lo cuentan para el Estado; panel, barrido y conteo no (9 metales + TBN). Queda dentro del estudio de **ponderación por parámetro** |
| **`730E-` vs `730E`** | desajuste de texto entre `lc` y la flota: Cerro Verde 730E queda sin límites aunque el dato existe |
| **Ventana de 12 meses** | la fundación rankea sobre 1 año por rendimiento: un equipo sin muestras en 12 meses **no aparece** en los módulos de estado actual, y el `Acum` suma dentro de esa ventana |
| **Tiempos** (03/10, SQL sin carga) | `/historialeq` 0,5 s · `/historialflota` 1,9 s · `/incipiente` 1,9 s · `/condicionmt` ~1,4 s · `/panel` 2-3 s · `/triage` ~3 s · `/ultimo` ~9 s · `/historial` ~10 s · `/diagcompleto` 7-11 s · `/tendencia` ~19 s. ⚠ La BD tiene un tope de CPU: con varias consultas a la vez **todas** tardan más (02/10) |
| **Resumen tras los historiales** | después de `/historial*` la central agrega un resumen de varias viñetas (con cifras de la tabla, sin inventar). Pendiente de recortar a una línea |
| **Teams no hace scroll horizontal** | las tablas anchas se comprimen (ej. «Acu m»). Por eso los historiales siguen en vertical |

---

## ✅ Resultados de la ronda 30/09-02/10 — y lo que enseñó

**Todo el set de comandos se verificó en Teams.** Las lecciones, que ya están en la configuración:

| Lección | Dónde quedó |
|---|---|
| Un tema al que se llega desde `/comando` **no pregunta** lo que falta; si se deja al orquestador, pregunta con una sintaxis inventada y se lleva la conversación | receta de 6 piezas en `CONFIG_TEMAS.md` (ley 10) |
| El orquestador mandaba `/barrido` y `/conteo` directo al tema que se llamaba igual, sin pasar por el 00 | descripciones del 00/16/17 + instrucción de la central |
| La IA de respaldo dibujaba tablas indistinguibles de las reales porque **se le pedía** | prompts e instrucciones: viñetas con 🔎 |
| Un tema que responde **dos veces** (la primera vacía) = el flujo recibió un componente en otro vocabulario | todos los flujos por componente traducen (`MT` → `TRACCION`) |

## ✅ Resultados de la ronda 03/10 — y lo que enseñó

| Lección | Dónde quedó |
|---|---|
| Una vista que arma su tabla con una **lista propia** de parámetros se queda atrás cuando la base crece (los 38 límites del 29/09 no llegaron a `/ultimo`) | `/ultimo` y `/tendencia` recorren el formato completo y leen `Estado_*` |
| Una alerta temprana que descarta «lo ya observado» se pierde justo el salto que más importa | categoría «cruzó» en `/incipiente` |
| Una tabla de límites con el MAX de varios modelos contradice la fila de arriba | límites por modelo |
| La BD tiene un tope de CPU: reintentos y consultas abandonadas se apilan y todo se cae | reintentos = Ninguno; historiales con filtro abajo (`CONFIG_TIMEOUT.md`) |

## Estado · 03/10

📋 Presentado a gerencia el **02/10** (primera alfa, testigo CA3195). Lo que se vio quedó corregido y verificado en
Teams el **03/10**. Acta: filas 63-64. En estudio: ponderación por parámetro. Aparcado: `/limites`.

## Cómo registrar la marcha

Correr en secuencia y anotar resultado + SQL del flujo por consulta en `docs/pruebas/MARCHA_ALFA_<fecha>.md`.
⚠ **Cruzar cada anomalía con su causa raíz antes de arreglarla.** Tres miradas, en este orden: el **panel de
actividad** (¿entró el tema correcto?), el **historial del flujo** (¿corrió?) y la **consulta que llegó**
(¿con qué valores?).
