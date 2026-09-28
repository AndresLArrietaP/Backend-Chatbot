# Pendientes KomfIA — backlog único · foco: **ronda 28/09 (Carlos + Franco)**

> **Este es EL backlog.** Si algo está pendiente, está aquí. Nadie más lista pendientes.
> Reescrito limpio el **2026-09-28**: se retiró el historial de rondas ya cerradas (vive en git y en
> [../BITACORA.md](../BITACORA.md)) y quedó **solo lo que sigue abierto**.
> Config canónica → [CONFIG_TEMAS](CONFIG_TEMAS.md) · [CONFIG_FLUJOS](CONFIG_FLUJOS.md) · [CONFIG_PROMPTS](CONFIG_PROMPTS.md) · [CONFIG_COMANDOS](CONFIG_COMANDOS.md) · [CONFIG_TIMEOUT](CONFIG_TIMEOUT.md)
> Formato y límites → [FORMATO_POR_COMPONENTE](../arquitectura/FORMATO_POR_COMPONENTE.md) · [LIMITES_FALLBACK](../arquitectura/LIMITES_FALLBACK.md) · [ESQUEMA_BD](../arquitectura/ESQUEMA_BD.md)
> Pruebas → [../pruebas/PRUEBAS_ALFA_COMANDOS.md](../pruebas/PRUEBAS_ALFA_COMANDOS.md)

**Reglas permanentes:** (1) auditar TODO el sistema **antes** de cambiar · (2) editar un comando = editar su
módulo completo (descripción + tema + nodos + flujo + vista) · (3) nunca escribir SQL sin cruzar
`../arquitectura/ESQUEMA_BD.xlsx` · (4) SQL de prueba → `VALIDACION_SSMS.sql` en bloques numerados y
**optimizados** · (5) rendimiento: **aislar y medir antes de teorizar**, y medir con el operador de
producción (`LIKE '%x%'`) · (6) tras desplegar DDL, correr el **BLOQUE 89** (smoke test).

---

# ▶ EMPIEZA AQUÍ

## Dónde estamos

La ronda del **23/09** (Carlos, 14 observaciones, módulos «Por Equipo») está **cerrada**: los 7 bloques
desplegados, verificados en SSMS y probados en Teams.

La ronda del **28/09** es **más grande** y cambia el foco a **«Por Flota»** — más los módulos por equipo que
volvieron a salir. ⚠ **Compromiso:** Franco pidió la presentación interna «final» para el **viernes 02/10,
19:30**. Con ese plazo, no entra todo: el orden de abajo está puesto para que lo que se vea el viernes sea
lo que más se nota.

## 🔑 La raíz de media ronda: los límites SÍ están en la base

Carlos repitió cinco veces «acá no sale el límite» — fósforo, viscosidad, código de limpieza ISO, TAN. Lo
di por «falta cargarlo en `lc`». **Era nuestro.**

`[Eqpcare].[lc]` tiene **38 parámetros** con su par LP/LC. `vw_LimitesPorComponente` — la vista que los
lleva a la fundación — lee **16**. Nunca se mapearon los otros **22**:

```
FOSFORO · BORO · BARIO · CADMIO · VANADIO · OXI · SULF · NIT · HOLLIN · MOLIBDENO
ISO 4um · ISO 6um · ISO 14um · Glycol · H20 · VISC40 · AW% · TAN · Diesel
PLATA · ANTIMONIO · LITIO        (+ de TBN solo se lee el LP, nunca el LC)
```

De una sola causa salen **todos** los «—» que señaló en `/ultimo 3195 mtlh`: `P`, `B`, `Mo`, `Agua`,
`ISO>4`, `ISO>6`, `ISO>14`, `V40`. No falta dato: falta leerlo.

📌 **Corrige una conclusión mía del 24/09.** El BLOQUE 102 declaró `vw_LimitesFallback` descartada porque
`lc` «tiene exactamente las mismas 64 filas» que el Excel. Las **filas** sí — son proyecto+componente+modelo.
Las **columnas** no las miré.

## 🔴 Y un hallazgo de la marcha que es más grave que el pedido

Revisando las capturas del 28/09, `/barridodet antapaccay 980` imprimió **la tabla verbatim con todos los
equipos** (incluidos `6116` D475A y `8108` PC1250) y **debajo, el nodo de análisis volvió a dibujar la
tabla** bajo el título *«Filtrado para modelo 980E — se excluyen 6116 (D475A) y 8108 (PC1250)»*.

**El filtro de modelo lo está haciendo el LLM, no el SQL.** Eso es romper la **ley 1** (ningún LLM toca la
tabla) y explica por qué el modelo «filtra raro»: a veces filtra, a veces no, y nunca es el mismo resultado.
`/barrido antapaccay d475` y `/barrido antapaccay 980` devolvieron **exactamente la misma tabla**, los
mismos 18 equipos — ahí el parámetro se acepta y **se ignora**. → **Bloque L**.

## 📋 Los pasos, en orden

| Orden | Bloque | Qué | Por qué ahí | Tamaño |
|---|---|---|---|---|
| **1** | **D** | Mapear los 22 límites que faltan | Raíz. Desbloquea lo que se ve en pantalla en casi todos los módulos | grande |
| **2** | **L** | `‹modelo›` obligatorio y que filtre **en el SQL** | Transversal (barrido · barridodet · ranking · triage) y hoy está roto de la peor forma | medio |
| **3** | **C** | `Acum` (antes «Σvida»): En Uso + `CM` por componente | Cierra el único bloqueo que venía de la ronda anterior | medio |
| **4** | **J** | Triage: agrupar los metales por familia | Barato y el triage es lo que más se mira | chico |
| **5** | **K** | `/incipiente`: descripción + verificar NO-DDI | Barato; es sobre todo redacción | chico |
| **6** | **A** | `/grafica` absorbe `/tendenciametal` | Un comando menos y es lo que más pidió | medio |
| **7** | **B** | `/tendencia`: fuera la tabla de límites | Una línea | chico |
| **8** | **E** | Encabezado de muestra en `/diagcompleto` y `/condicionmt` | | chico |
| **9** | **F** | Historial: todos los parámetros del formato | Grande y con decisión de formato de por medio | grande |
| **10** | **I** | `/barrido`: ¿otro uso o se desactiva? | **Decisión suya**, no fix | — |
| **11** | **G** | Acumulados por componente + renombres | Depende de **C** | medio |
| **12** | **H** | Bugs sueltos | | chico |

> **Para el viernes 02/10 realista:** del 1 al 8. **F** e **I** son de después, y **G** depende de **C**.

---

# Los bloques

## 🅳 Bloque D — los 22 parámetros de límite que nunca se leyeron  ⭐ RAÍZ

**Qué hacer:** ampliar `vw_LimitesPorComponente` con los 22 pares que faltan y propagarlos a la tabla de
parámetros de cada vista. Aditivo, SQL puro.

**Lo que Carlos precisó de cada uno (audio 09.14):**

- **Fósforo (`P`) es INVERSO** — `LP 280 / LC 240`. Parte de un número y se vigila que **no caiga**. Ya
  está en la lista `Inv`, pero sin límite mapeado nunca se evaluó.
- **Viscosidad: cuatro niveles, no dos** — `LC inferior · LP inferior · LP superior · LC superior`. Parte
  con un valor y puede irse para arriba o para abajo; se vigila que se mantenga **en la banda entre los
  precautorios**.
  ⚠ **No es igual por componente:** en **MT solo existe el crítico** (así está en el manual); en **motor
  diésel van los cuatro**. Personalizar por componente, no aplicar los 4 a todo.
- **V100 vs V40** — la misma medida a 100 °C y a 40 °C. 100 °C para motores, 40 °C para aceites
  industriales. **Antapaccay solo mide V100; Antamina mide las dos.** Depende de la mina → mostrar la que
  tenga dato, nunca asumir.
- **Código de limpieza ISO 4/6/14** — contador de partículas por tamaño (4, 6, 14 micras). El número es
  **adimensional y logarítmico**: cada punto **duplica** las partículas (20 ≈ 40 000 → 21 ≈ 80 000). En
  Antapaccay **el motor no lo mide**; el resto sí.
- **TAN vs TBN** — el TBN mide reserva alcalina (**solo motor**); el TAN mide acidificación. En Antapaccay
  el TAN sale en **ruedas e hidráulico**, no en MT. En otras minas puede medirse en todo.
- **PQ** — en hidráulico y transmisión normalmente **no se mide**; lo sacan esporádicamente cuando la
  muestra viene con particulado concentrado. Que no salga no es un hueco.

**La regla que ordena todo esto:** un parámetro puede **no medirse** en un componente, y eso es distinto de
**no tener límite cargado**. Hoy los dos se pintan `—` y se confunden. Hay que distinguirlos.

⚠ **Carlos va a tocar la base:** va a **eliminar los límites de aditivos en las ruedas** («no tiene mucho
sentido»), recargando desde el externo. `lc` va a cambiar bajo nuestros pies → el mapeo debe ser
**data-driven** (sin fila, sin límite), nunca una lista fija.

**Verificación:** BLOQUES **138** y **139**.

---

## 🅻 Bloque L — el parámetro `‹modelo›`  ⭐ TRANSVERSAL Y HOY ROTO

**L1 · Hoy no filtra en el SQL — filtra el LLM.** Ver el hallazgo de arriba. Mientras siga así no hay
determinismo posible: es la ley 1. La cura es que el predicado de modelo viva en el `WHERE` de la vista/flujo
y que el nodo de análisis **no vuelva a dibujar la tabla** (eso ya está prohibido en el prompt universal:
hay que revisar por qué se lo saltó).

**L2 · El modelo pasa a OBLIGATORIO** en los módulos de flota. Hoy es opcional con default `(todos)`, y en
flota mixta eso suma peras con manzanas: los límites del 980E no son los del D475A.

**L3 · «Salieron tablas duplicadas».** Ya conocido: las vistas de flota exponen **las filas por-modelo Y un
rollup `(todos)`** vía `CROSS APPLY (VALUES …)`. Si el predicado deja pasar los dos, cada equipo sale dos
veces. ⛔ **Colapsar a solo `(todos)` rompe** el caso en que sí nombran un modelo — la cura no es quitar el
rollup, es que el predicado sea exacto y excluyente.

**L4 · Alcance real de la flota.** Él dice «además del 980E, se ven los tractores y auxiliares, D475 y
PC1250, principalmente esos 3».
⚠ **Corrijo con lo que devolvió su propia marcha:** Antapaccay tiene al menos **cinco** modelos con datos —
`980E`, `D475A`, `PC1250`, **`D11T`** y **`797F`** (los dos últimos salieron en sus propios `/conteo`). Y el
archivo de límites solo cubre **980E, D475A y PC1250**: `D11T` y `797F` **no tienen límites**. Cuando se los
pidan hay que decirlo, no devolver una tabla muda.

---

## 🅲 Bloque C — `Acum`: «En Uso» + `CM` por componente  ⭐ CIERRA EL BLOQUEO DE LA RONDA ANTERIOR

📌 **Renombre pedido: «Σvida» pasa a llamarse `Acum`.** Es lo que es — un acumulado — y «vida» daba a
entender la vida completa del componente, que es justo lo que no era. Toca las cabeceras de
`vw_TendenciaElemento`, `vw_TendenciaMD`, `vw_TendenciaMetalMD` y `vw_TendenciaGrafico*MD`.

El 25/09 esto quedó bloqueado porque la cifra de Carlos (**6 785,39**) no se reproducía con ningún criterio.
Ahora dio el método completo:

**1 · Filtrar por «En Uso».** Existe: **`[Oil].[LaboratoryData].[ComponentStatus]`** — está en la tabla
viva y **nunca la usamos** (`grep` en `DDL_vistas.sql`: 0 apariciones). Marca las muestras del componente
**actualmente instalado**. Es lo que convierte «suma de muestras» en «acumulado del componente».
> Corrige [[komfia_esddi_filtro_no_opera]]: `CM` no marca el cambio de componente, pero **`ComponentStatus` sí**.

**2 · Filtrar `CM`, distinto por componente:**

| Componente | `CM` que suma |
|---|---|
| **Motor de Tracción** | `ADI` y `C` |
| **Rueda delantera** | solo `C` |
| **Motor diésel (MODI)** | **todos** |
| **Sistema hidráulico** | solo `C` |

Sentido físico: se cuenta la muestra **antes** del dializado (`ADI`), no la de después (`DDI`), que mediría
aceite ya filtrado.

**3 · Quitar el «(nº de muestras)»** del display: queda solo el acumulado.

🔴 **El obstáculo, y hay que decirlo antes de tocar nada:** hoy el acumulado se calcula sobre
`vw_MuestrasRankeadas` → la fundación → **`WHERE FechaMuestreo >= DATEADD(MONTH,-12,…)`**. O sea que **lo
que hoy llamamos «Σvida» son 12 meses**. Por eso nunca iba a cuadrar. Para cuadrar hay que leer **toda la
historia** con el filtro de `ComponentStatus`, y eso choca con la razón de ser de esa ventana (**ley 2/3**).

**Diseño propuesto:** vista **dedicada** `vw_AcumuladoVida` que lea `[Oil].[LaboratoryData]` **directo**
(sin la fundación, sin window functions), filtre `ComponentStatus` + `CM` por componente y agrupe por
equipo+compartimiento+parámetro. `vw_TendenciaElemento` la consume con `LEFT JOIN`. Un `GROUP BY` sin
ventana es barato; **medir antes de cablear** (BLOQUE 137.3 lo mide).

**Objetivo:** `CA3195 · MT LH · Fe` = **3 718,6**. Hoy la vista dice **5 124,2 (38)**. BLOQUES **136** y **137**.

---

## 🅹 Bloque J — Triage: las filas de grupo

«Está casi impecable»; falta que los metales observados digan a qué familia pertenecen. Pide las
agrupaciones **Salud · Aditivos · Contaminación · Desgaste · Código de limpieza** — las del formato oficial
que ya usan `/ultimo`, `/condicionmt` y `/diagcompleto`.

⚠ **Detalle de diseño:** en el triage los metales van **dentro de una celda** (`Metales Obs.`), no en filas
propias, así que no puede ser una fila de grupo como en las otras tablas. Dos formas:
**(a)** prefijar dentro de la celda — `Desgaste: Fe(231.8) · Aditivos: Ca(54.0)`; cabe, no cambia la
estructura. **(b)** una columna por familia — ensancha una tabla que ya tiene 54 filas.
**Recomiendo (a)**, con el orden del formato, no alfabético.

📌 Ya van **cuatro** módulos a los que aplica el formato de `Requerimientos Analisis Aceite 1.xlsx` fuera de
los que se pensaron al principio. Conviene asumir que **aplica a todos**.

---

## 🅺 Bloque K — `/incipiente`: el CA3195 y la descripción

**El caso:** el `MT LH` del `CA3195` tiene `PQ = 233.2`, real y alto, y **no salió** en `/incipiente`.

🔎 **Lo revisé: es correcto por diseño, no es un bug.** `/incipiente` es **alerta temprana**: lista los que
subieron ≥40 % sobre la media de las 6 previas **y todavía no superan el LP**. El `PQ` del 3195 vale 233.2
con `LP 130 / LC 150`: no viene subiendo hacia el límite, **ya lo pasó**. Su sitio es `/triage` y
`/barrido`, donde en efecto sale 🟥.

**Entonces el arreglo es el que él mismo pidió: la descripción.** Hoy dice *«Última muestra vs. el promedio
de las 6 anteriores… los que subieron ≥40 % y ya están en la mitad superior del límite (≥50 % del LP), sin
superarlo todavía»*. Correcto pero se lee como jerga. Debe decir **qué entra, qué no, y dónde está lo que no
entra**:

> «Equipos que **todavía no pasan el límite** pero vienen subiendo fuerte. Si un parámetro **ya superó el
> límite**, no aparece aquí: sale en `/triage` y en `/barrido`.»

**K2 · Lo que sí hay que verificar:** «considera NO DDI». La media de las 6 previas debe salir **solo de
muestras de monitoreo**. Una `DDI` (aceite ya dializado) baja la media artificialmente e **infla el % de
subida** → falsos incipientes. Comprobar de qué vista cuelga `vw_TendenciaIncipienteMD`: si lee
`vw_MuestrasHistorial` (que **sí** incluye DDI) en vez de `vw_MuestrasRankeadas`, ahí está.

---

## 🅰 Bloque A — `/grafica` absorbe `/tendenciametal`

**Por qué:** «no le veo sentido tener la tendencia del PQ de todos los elementos cuando lo que quiero
analizar es un elemento en particular» + «para no tener tantos comandos».

**Firma nueva:** `/grafica ‹equipo› ‹componente› ‹metal›`, los tres **obligatorios**.
`/tendenciametal` se **desactiva** (⛔ no se borra el nodo — ley 8).

**La tabla que pidió, de arriba abajo:**

1. **Encabezado de campos × las 6 fechas** — el que ya existe (SMR · Hrs Aceite · Hrs Comp · CM · Estado ·
   Grado). De aquí se «sobreentienden» grado, horas de componente y última muestra: por eso las columnas
   equivalentes del viejo `/tendenciametal` **sobran**.
2. **Bajo ese mismo encabezado, las filas del metal elegido**: su valor en cada fecha, y `Acum`, `Prom`,
   `σ` y `Nº fuera de límite` **repartidos en las mismas 6 columnas**, para ver cómo fue cambiando cada
   indicador muestra a muestra.
3. **Límites de referencia** como **texto** en una línea (`LP 130.0 · LC 150.0`), no como tabla.
4. **La gráfica ASCII.**
5. **Sin `Spark`** — la gráfica lo reemplaza.

⚠ **Decisión abierta (la planteó él):** «raro de ver, pero es eso o quitarlos». Un `Prom` o un `σ` que
cambian columna a columna son **acumulados móviles** y se leen mal en 6 columnas.
**Mi recomendación:** `Acum` **sí** como fila de 6 columnas (es acumulativo por naturaleza); `Prom`, `σ` y
`Nº fuera de límite` **una sola vez**, en la línea de texto junto a los límites. Se pueden prototipar las
dos y que elija viendo.

---

## 🅱 Bloque B — `/tendencia`: fuera la tabla de límites

Literal: «en tendencia quito los límites». Molesta porque la matriz ya trae muchos parámetros y la tabla de
abajo repite a lo ancho. Se quita de `vw_TendenciaMD`.
⚠ **No** se quita de `/grafica` (bloque A), donde queda como línea de texto.
⚠ En `/barrido` **también** se quita, pero ahí los límites deben **reaparecer junto a su valor** → bloque I.

---

## 🅴 Bloque E — encabezado de muestra en `/diagcompleto` y `/condicionmt`

Hoy solo `/ultimo` lo tiene:
`Mod. 980E · Lubric. SHELL OMALA S4 GXV 680 · SMR 36279 · Hor.Comp. 8491 · T. muestra ADI · 26-Sep-26`

Pedido: «añadirle como encabezado los datos — aceite, el SMR, horas del componente, la fecha, asociada a
esa muestra».

⚠ **Detalle a resolver antes de construir, que él no mencionó:** en esas dos tablas hay **varios
componentes**, cada uno con **su** fecha, su grado y sus horas. Un encabezado único mentiría. Opciones:
**(a)** filas de encabezado **dentro** de la matriz, una por campo, con una columna por componente —
coherente con la tabla que ya existe; **(b)** un encabezado por componente sobre su columna.
**(a) es la que encaja.**

⛔ Lo que **no** quiere: columnas de límite en esas dos tablas («todavía se entiende que se está observando»).

---

## 🅵 Bloque F — Historial: todos los parámetros del formato

**Lo que falta:** hoy el historial muestra solo `Met. Obs.` (los observados). Debe traer **todos los
parámetros del formato**, y —esto es lo nuevo— **variando según el componente**: no son los mismos para
`MT`, `RD`, `SH` y `MODI`. Es el mismo formato por componente de
[FORMATO_POR_COMPONENTE](../arquitectura/FORMATO_POR_COMPONENTE.md), en su orden: salud → aditivos →
contaminación → desgaste → código de limpieza.

**Orientación de la tabla — nos dieron libertad:**

| | Filas | Columnas | A favor | En contra |
|---|---|---|---|---|
| **Horizontal** | parámetros | **fechas** | es el formato del Excel que él pasó; se lee igual que `/tendencia` | con rango largo (2 años) se va a lo ancho y **las tarjetas no tienen scroll** (ley 9) |
| **Vertical** (actual) | **fechas** | parámetros | crece hacia abajo, que sí scrollea en Teams | ~25 columnas de parámetros es mucho igual |

**Mi recomendación:** **horizontal**, por dos razones concretas — (1) es el formato que el área ya usa y
reconoce, y (2) el nº de parámetros es **fijo por componente** (entre 18 y 25), mientras que el nº de fechas
lo elige el usuario con `‹rango›`. Poner en columnas lo variable y en filas lo fijo es exactamente al revés
de lo que conviene: con `2 años` la tabla horizontal explota a lo ancho y **no hay scroll**.
→ **Corrijo mi propia recomendación:** conviene **vertical** (fechas en filas), que es como está hoy,
**y** limitar el nº de parámetros al del componente. Se construyen las dos y elige viendo; pero si hay que
apostar, la que sobrevive a `/historial 3195 mtlh 2 años` es la vertical.

**F2 · Historial de flota, dos retoques finos:**
- El metal debe llevar **su valor al lado**: `Fe` → `Fe(231.8)`, como ya hace el triage.
- Los nombres de componente **en MAYÚSCULA** (`MANDO FINAL LH`, no `Mando Final LH`) — criterio formal del
  área.

Aplica a las 5 variantes: `/historial`, `/historialmetal`, `/historialflota` y las de equipo.

---

## 🅸 Bloque I — `/barrido`: el único módulo al que no le vieron sentido

Literal: es el único comando que no les cuadró, **porque ya existe `/barridodet`**. Preguntaron si se le
puede dar otro uso o valor, y si no, **desactivarlo**.

**Mi lectura:** los dos responden casi lo mismo con distinto zoom. `/barrido` da una fila por equipo;
`/barridodet` el detalle por componente. Con 18 equipos observados el resumen **no es un paso previo**, es
una segunda lectura de lo mismo.

| | Qué sería `/barrido` | A favor | En contra |
|---|---|---|---|
| **(a) Panel de flota** | Deja de listar equipos: **estado de la mina de una ojeada** — cuántos equipos, observados y críticos **por componente y por modelo**, y qué metal domina | Ocupa un lugar que hoy no ocupa nadie; es lo primero que mira un gerente | Módulo nuevo, no un retoque. Se solapa con `/conteo` |
| **(b) Paso 1 acotado** | Resumen pero solo críticos, top N, y cierra invitando a `/barridodet` | Barato | Es lo que ya intenta ser |
| **(c) Desactivarlo** | `/barridodet` pasa a llamarse `/barrido` | Un comando menos, cero ambigüedad | Se pierde la vista rápida en flotas grandes (Antamina, 66 equipos) |

**Mi recomendación: (a), fusionando `/conteo` dentro** — `/conteo` ya da equipos/observados/críticos por
componente, que es la mitad del panel. Dos comandos tibios se vuelven uno útil. ⚠ **Lo decide él.**

**Lo que es fix y va igual, decida lo que decida:**
- **quitar la tabla de límites del pie**, y
- **que los límites salgan junto a su valor**, como en `/ultimo` → depende del **bloque D**;
- **`‹modelo›` obligatorio y filtrando en el SQL** → **bloque L**.

---

## 🅶 Bloque G — Acumulados y ranking · depende de **C**

- **`/acumulados` necesita componente.** Hoy es solo motor diésel (envuelve el dashboard *Ranking de
  Atención*). Quiere también **MT**, ruedas e hidráulico: «hay acumulado de MT, hay acumulado de ruedas».
  Con **C** resuelto, sale de la misma fórmula.
- **Renombre:** el ranking de acumulados de motor diésel debería llamarse por lo que es →
  **`/rankingmod`** (propuesta de Carlos, o `rmod`), liberando `/rankingacum`.
- ⚠ **Acumulados solo existe para Antapaccay.** Es correcto, pero debe decirlo la **descripción del tema**,
  no un aviso al final (ver **H7**).

---

## 🅷 Bloque H — bugs sueltos de la marcha del 28/09

| | Qué pasó | Nota |
|---|---|---|
| **H1** | **`/ranking` a secas** respondió literalmente **«Tas a una»** | Basura. Sin parámetros debe pedirlos o mandar a `/comandos` |
| **H2** | **`/ayuda`** respondió dos cosas distintas seguidas: primero «indica específicamente qué concepto…», luego la tabla completa | La aleatoriedad del 17/09 **no está cerrada** |
| **H3** | `/ranking antapaccay mtlh PQ 20` mezcló equipos **`3114`…`3118`** sin límites junto a los `CA####` | Probable `‹modelo›` → puede cerrarse con **L** |
| **H4** | `/ranking antapaccay motor hollin 20` → «alta demanda», y al reintentar dijo que `Hollín` no existe | **Sí existe**: `HOLLIN - LP/LC` está en `lc`. La respuesta era falsa → **D** |
| **H5** | `/conteo antapaccay d475` lista un componente llamado **`nan`** | Viene de un `Compartimiento` nulo |
| **H6** | `/triage mtrh antapaccay 980` salió con columnas descuadradas (`Salud`, `Hrs Comp`) | Solo en la variante `mtrh`; con `mt` sale bien |
| **H7** | `/rankingacum antamina` devolvió **la tabla de Antapaccay** y debajo el aviso de que Antamina no tiene datos | Contradictorio: imprime una tabla que no corresponde |

---

# Heredado de la ronda 23/09 — lo que sigue abierto

| | Qué | Estado |
|---|---|---|
| **1** | ~~El universo del `Σvida`~~ | ✅ **RESUELTO** por el bloque **C**: Carlos dio el método (En Uso + `CM` por componente) |
| **2** | **Optimizar el resto de flujos** como se hizo con `/triage` | 🟡 no urgente. `vw_TendenciaMD` **~35 s** y `vw_TendenciaMetalMD` **~30 s** con el operador real. Las dos palancas ya probadas: quitar el CTE referenciado 2× con `JOIN` entre ramas, y traducir en el flujo y no en el `WHERE` |
| **3** | **3 de las 4 fórmulas** de componente (`comp1`, `comp2`, `comp3`) sin confirmar | ❓ nada roto, pero el sistema depende de una sola red |
| **4** | **C4** — el desajuste `730E-` vs `730E` en `lc` (BLOQUE 103) | ⏳ Cerro Verde 730E se queda sin límites aunque el dato existe |
| **5** | **G2 modo B** y **G3** | ⏳ backlog que abrí yo, **no** era parte del pedido |

# Backlog de fondo — ni urgente ni pedido

- **Tarjetas adaptables con datos** de los módulos → [tarjetas/PLAN_TARJETAS_DATOS.md](tarjetas/PLAN_TARJETAS_DATOS.md). Techo conocido: **sin scroll**, la palanca es paginar.
- **Gráfico ASCII opcional en Historial** (no por defecto), acotado a variantes con serie limpia.
- **Consultas compuestas** (heredado de la auditoría de agosto).
- **Preguntas simples = respuesta directa**: basta 1 mensaje con la cifra; no forzar la tabla completa.
- **`V100`:** hoy es display-only. Con el bloque **D** pasa a tener sus 4 niveles; entonces habrá que decidir
  si dispara `Estado_General` (hoy **no**, porque los límites solo estaban aterrizados en Antapaccay).

---

# ❓ Preguntas abiertas — bloquean parte del trabajo

1. **El último punto del primer mensaje quedó cortado** (termina en «`-`»). ¿Qué faltaba?
2. **Bloque A:** ¿`Prom` / `σ` / `Nº fuera de límite` como filas de 6 columnas, o una sola vez como texto?
3. **Bloque I:** `/barrido` → ¿**(a)** panel de flota fusionando `/conteo`, **(b)** paso 1 acotado, o
   **(c)** desactivarlo?
4. **Bloque F:** ¿horizontal o vertical? (mi apuesta: **vertical**, por el rango largo y la falta de scroll).
5. **`‹modelo›` obligatorio: ¿en cuáles exactamente?** Confirmado barrido/barridodet/ranking. ¿También
   `/triage`, `/conteo`, `/incipiente`, `/metalflota`, `/historialflota`?
6. **¿Cuándo toca Carlos los límites de aditivos en ruedas?** Para no medir contra un `lc` que cambia.
