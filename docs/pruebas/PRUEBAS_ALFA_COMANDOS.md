# KomfIA — Pruebas de alfa · **set completo, versión 25-sep-2026**

Cada prueba va **emparejada**: la consulta en **lenguaje natural** y su **`/comando`** equivalente. Los dos
caminos deben dar **el mismo resultado**; el comando no cambia la lógica, solo dispara el tema con
parámetros explícitos.

> ⚠ **Esta versión reemplaza la del 18-sep.** Entre medias entró la ronda de feedback del 23/09 (bloques
> A–G), que cambió nombres de comandos, fusionó módulos y reescribió el formato de las tablas. Lo que
> sigue es lo que KomfIA hace **hoy**, no lo que hacía.

**Lo que cambió respecto del set anterior, en una tabla:**

| Antes | Ahora |
|---|---|
| `/condicion` | **`/condicionmt`** (`/condicion` sigue como alias) |
| `/diagnostico` + `/diagcompleto` | **`/diagcompleto`** (`/diagnostico` es alias del mismo) |
| `/tendencia` + `/tendenciadet` | **`/tendencia`** — un solo módulo (`/tendenciadet` es alias) |
| tablas de 18 parámetros fijos | **el formato del Excel por componente** (23 en MT, 25-27 en el resto, 31 en la matriz cruzada) |

---

## Antes de probar

1. **DDL desplegado** — `docs/arquitectura/DDL_vistas.sql` corrido entero en SSMS.
2. **Prompt `Análisis de aceite`** pegado (`docs/copilot/prompts/analisis_prompts.md`), **sin conocimiento**.
3. **Tarjeta `/comandos`** pegada, con `/tendencia` y `/diagcompleto` como principales.
4. **Temas 03 y 05 desactivados** (absorbidos por el 04 y el 06).

---

## N0 · Base

| # | Lenguaje natural | Comando | Esperado |
|---|---|---|---|
| 1 | ¿Cuántos equipos 980E tiene Antapaccay? | `/conteo Antapaccay 980E` | conteo de flota, con desglose por componente |

## N1 · Estado actual de un componente

| # | Lenguaje natural | Comando | Esperado |
|---|---|---|---|
| 2 | ¿Cómo están los motores de tracción del CA3161? | `/condicionmt 3161` | los dos MT lado a lado, **23 filas** de la hoja MT |
| 3 | Último análisis del MT LH del CA3160 | `/ultimo 3160 mt lh` | tabla `Par. \| LP \| LC \| Valor` con las 23 filas |
| 3b | *(el mismo, pegado)* | `/ultimo 3160 mtlh` | **idéntico a #3** — la normalización de componente |
| 4 | Último análisis de la rueda delantera derecha del CA3160 | `/ultimo 3160 rdrh` | 🔴 los **aditivos** (`Ca`, `Zn`, `Mg`) marcados por estar **bajo** su límite |

## N2 · Diagnóstico del equipo completo

| # | Lenguaje natural | Comando | Esperado |
|---|---|---|---|
| 5 | Diagnóstico del CA3160 | `/diagcompleto 3160` | matriz **parámetros × componentes**, 31 filas, con el pie de `Ca`/`Mg`/`Mo`/`Zn` |
| 5b | ¿Cómo está el equipo 3160? | `/diagnostico 3160` | **lo mismo** — el alias y los disparadores absorbidos |

## N3 · Universo de un tipo de componente (flota)

| # | Lenguaje natural | Comando | Esperado |
|---|---|---|---|
| 6 | ¿Qué motores de tracción de Antapaccay están observados? | `/triage tracción Antapaccay` | todos los equipos, críticos primero, en **~5 s** |
| 7 | ¿Qué sistemas hidráulicos de Antapaccay se están disparando? | `/incipiente Antapaccay hidráulico` | alerta temprana: los que suben sin pasar el límite |
| 8 | Top 5 de hierro en los MT de Antapaccay | `/ranking Antapaccay tracción Fe 5` | ranking descendente |

## N4 · Tendencia (multi-muestra) — **el módulo fusionado**

| # | Lenguaje natural | Comando | Esperado |
|---|---|---|---|
| 9 | Tendencia del MT LH del CA3160 | `/tendencia 3160 mtlh` | contexto (SMR, horas, CM, estado, grado) **+** matriz × 6 fechas **+** límites |
| 9b | Detalle de la tendencia del MT LH del CA3160 | `/tendenciadet 3160 mtlh` | **idéntico a #9** |
| 10 | *(tras #9)* «el resumen estadístico» | — *(continuación)* | tabla Prom · σ · Σvida (nº m.) · Nº fuera de límite |
| 11 | ¿Cómo ha evolucionado el Fe del CA3160? | `/tendenciametal 3160 Fe` | el metal en **todos** los componentes del equipo |
| 12 | Gráfica del Fe del MT LH del CA3160 | `/grafica 3160 mtlh Fe` | **el cuadro de tendencia arriba** + la curva ASCII |
| 12b | *(tras #9)* «la gráfica de los observados» | — *(continuación)* | una curva por metal observado, con el cuadro arriba |

## N5 · Barrido de flota

| # | Lenguaje natural | Comando | Esperado |
|---|---|---|---|
| 13 | Barrido de Antapaccay | `/barrido Antapaccay` | resumen por equipo + cuadro de límites |
| 14 | *(tras #13)* «el detalle de todos» | `/barridodet Antapaccay` | detalle agrupado por componente |
| 15 | *(tras #14)* «solo los críticos» | — *(continuación)* | solo los críticos. ⚠ Si la flota no tiene ninguno, debe **decirlo**, no fallar |

## N6 · Historial (cronológico)

| # | Lenguaje natural | Comando | Esperado |
|---|---|---|---|
| 16 | Historial del MT LH del CA3160 | `/historial 3160 mtlh` | bitácora por muestra |
| 17 | Historial de todo el CA3160 | `/historialeq 3160` | todas las muestras del equipo |
| 18 | Historial del Fe del CA3160 | `/historialmetal 3160 Fe` | un metal en el tiempo |

## N7 · Acumulados (motor diésel) — **el par que se confundía**

| # | Lenguaje natural | Comando | Esperado |
|---|---|---|---|
| 19 | «acumulados» *(a secas)* | — | 🔴 el **ranking de flota** (27), no el de equipo |
| 20 | «acumulados de Antapaccay» | `/rankingacum Antapaccay` | el ranking de flota |
| 21 | «acumulados del CA3177» | `/acumulados 3177` | el **equipo** (28) |
| 22 | Ranking de acumulados en gráfica | `/rankinggraf Antapaccay` | barras ASCII con las bandas 60/65/70 |

## N8 · Continuidad y deixis

| # | Secuencia | Esperado |
|---|---|---|
| 23 | `/tendencia 3160 mtlh` → «y la gráfica» | la gráfica **del mismo** equipo y componente |
| 24 | `/diagcompleto 3160` → «y el 3161» | el diagnóstico del 3161 |
| 25 | `/rankingacum Antapaccay` → «ahora los del CA3177» | cambia de flota a equipo **sin arrastrar** el tema |

## N9 · Casos límite — **lo que debe DECIR, no fallar**

🔴 **Esta sección es la más importante del set.** Toda la ronda del 23/09 encontró el mismo patrón: el
sistema respondía «no encontré datos» cuando el dato existía. Cada fila de aquí tiene un mensaje **propio**.

| # | Caso | Comando | Mensaje esperado |
|---|---|---|---|
| 26 | Equipo **sano** (sin nada observado) | `/diagcompleto 3175` | «ninguno de sus N componentes tiene parámetros fuera de límite» |
| 27 | Proyecto **sin límites cargados** | `/incipiente Cuajone` | «sin límites cargados: no hay contra qué comparar. ⚠ Esto **no** significa que estén sanos» |
| 28 | Componente **sin límites** en la tendencia | `/tendencia <equipo de Cuajone> motor` | los valores salen, y donde iban los límites: «sin límites cargados…» |
| 29 | Flota **sin críticos** | `/barridodet …` → «solo los críticos» | «ningún equipo está en estado crítico» |
| 30 | Equipo **inexistente** | `/diagcompleto CA9999` | «no se encontraron registros» |
| 31 | Comando **mal escrito** | `/barido Antapaccay` | «no reconocí /barido. Escribe /comandos» |
| 32 | Parámetro que **no se mide** | `/grafica 3160 mtlh Mo` | ⏳ **limitación conocida** — hoy dice «no encontré datos» |

---

## ⚠ Limitaciones conocidas — lo que KomfIA **no** hace hoy

Conviene tenerlas a mano al enseñar el sistema, para no prometer de más.

| Limitación | Detalle |
|---|---|
| **Parámetros del formato que la base no mide** | `V40`, `Mo`, `Agua`, `ISO>4/6/14`, `TAN`, `Oxidación`, `Hollín`, `Diésel`, `Refrigerante`, `Nitración`, `Sulfatación`. Salen con `—` en las tablas, pero si los pides por comando, el mensaje **todavía no distingue** «no se mide» de «no hay datos» |
| **Límites por proyecto+modelo** | 45 combinaciones de la flota viva **no tienen límites** en `Eqpcare.lc` — Cuajone y Toquepala enteros. Los módulos lo dicen, pero no se puede evaluar |
| **`730E-` vs `730E`** | desajuste de texto entre `lc` y la flota: Cerro Verde 730E queda sin límites aunque el dato existe |
| **`Σvida`** | suma dentro de la **ventana de 12 meses** de la fundación, **no** la vida real del componente, y **no se reinicia** al cambiarlo. Pendiente de confirmar el criterio con Carlos |
| **Ventana de 12 meses** | la fundación rankea sobre 1 año por rendimiento: un equipo sin muestras en 12 meses **no aparece** en los módulos de estado actual |
| **Tiempos** | `/tendencia` ~35 s · `/tendenciametal` ~30 s · `/grafica` ~21 s · `/triage` ~5 s · `/diagcompleto` ~2,4 s. Todos dentro del tope de 120 s del conector, pero no son instantáneos |
| **Alcance de la ronda 23/09** | ⚠ el feedback y los arreglos fueron sobre los módulos **«Por equipo»**. Los de **«Por flota»** (barrido, triage, conteo, rankings) **no** pasaron por esa revisión — es lo próximo que va a recibir feedback |

---

## ✅ Resultados de la pasada del 25/09 — y lo que enseñó

**Todo el set pasó por comando.** Lo que falló fue **lenguaje natural**, que es donde el ruteo depende de
las descripciones y no de un atajo explícito. Cuatro observaciones y cómo quedaron:

| Observación | Veredicto |
|---|---|
| «qué hidráulicos se están disparando» caía en **triage** en vez de incipiente | 🔴 real → descripciones 19 y 20 reescritas: el 20 se queda con **todas** las frases de movimiento sin alarma |
| `/tendencia` → «y la gráfica» devolvió las gráficas de **observados** | ✅ **es el diseño**: «la gráfica» sin nombrar metal es el Tema 10. Para una sola curva hay que decir el metal |
| Historial → «acumulados» se encadenaron | ✅ la continuidad funcionó. ⚠ **Las pruebas de continuidad deben correrse por separado** o se pisan entre sí |
| `/diagcompleto 3175` marca las dos ruedas | ✅ **no es error** — comprobado en base de datos (BLOQUE 135): `Ca` 185 con mínimo 1 560, aditivos agotados de verdad |

🔴 **Lo que sí era un bug y ya está parchado:** en `/diagcompleto CA9999` y `/incipiente Cuajone` el
análisis escribía «todos los parámetros dentro de límite» **encima** del mensaje real. El prompt ahora
responde **un guion** cuando no hay tabla. ⚠ El arreglo de fondo es mover la condición «md en blanco»
**delante** del Prompt — documentado en [`CONFIG_TEMAS.md`](../copilot/CONFIG_TEMAS.md).

💡 **Y una buena:** `/grafica 3160 mtlh Mo` respondió *«Mo no registra valores en las últimas 6 muestras
— no hay datos para graficar ni límites definidos»*. Eso es el caso **32** resuelto sin haberlo
implementado: el análisis lo explica en vez de callarse.

## Estado · 25/09

📧 **Entregado a Carlos** para que vuelva a probar los módulos **Por equipo**. A la espera de feedback.
⚠ Los módulos **Por flota** (barrido, triage, conteo, rankings, incipiente) **no** pasaron por la revisión
con el área — su feedback vendrá en una sesión posterior.

## Cómo registrar la marcha

Correr en secuencia y anotar resultado + SQL del flujo por consulta en `docs/pruebas/MARCHA_ALFA_<fecha>.md`.
⚠ **Cruzar cada anomalía con su causa raíz antes de arreglarla** — en la ronda del 23/09, tres «bugs»
resultaron ser datos y dos «regresiones» resultaron ser el operador de la consulta de prueba.
