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
| **10** | **I** | `/barrido` → **Panel de flota**, absorbiendo `/conteo` | Decidido el 28/09; es módulo nuevo, no retoque | grande |
| **11** | **G** | Acumulados por componente + renombres | Depende de **C** | medio |
| **12** | **H** | Bugs sueltos | | chico |

> **Para el viernes 02/10 realista:** del 1 al 8. **F** e **I** son de después (los dos son construir algo
> nuevo, no retocar), y **G** depende de **C**.

---

# Los bloques

## 🅳 Bloque D — los límites que faltan  ⭐ RAÍZ · **ABIERTO 28/09**

### En una frase

**El dato está. No lo leemos.** Ni los límites ni, resulta, la mitad de los valores.

### El mapa completo, tras auditar la BD

| | Qué hay | Qué usamos |
|---|---|---|
| **Límites** — `[Eqpcare].[lc]` | **38 parámetros** con su par LP/LC | **16** |
| **Valores** — `[Oil].[LaboratoryData]` | **107 columnas** | 18 parámetros |
| **Formato** — `Requerimientos Analisis Aceite 1.xlsx` | **31 parámetros** distintos entre los 4 componentes | 18 |

🔴 **Y una corrección a nuestra propia documentación.**
[FORMATO_POR_COMPONENTE.md](../arquitectura/FORMATO_POR_COMPONENTE.md) cierra diciendo: *«Parámetros que el
formato pide y **no tenemos** en la BD: V40 · TAN · Oxidacion · Sulfatacion · Nitracion · Mo · Agua ·
Hollin · Diesel · Refrigerante · ISO4/6/14»*. **Los 13 existen.** Nunca se cruzaron contra el esquema:

| El formato pide | Columna real |  | El formato pide | Columna real |
|---|---|---|---|---|
| `V40` | `Viscosidad40` | | `Agua` | `Agua` |
| `TAN` | `TAN` | | `Hollin` | `Hollin` |
| `Oxidacion` | `Oxidacion` | | `Diesel` | `Diesel` |
| `Sulfatacion` | `Sulfatacion` | | `Refrigerante` | `Refrigerante` |
| `Nitracion` | `Nitracion` | | `ISO4` · `ISO6` · `ISO14` | `Iso4406_4` · `_6` · `_14` |
| `Mo` | `Mo_ppm` | | | |

⇒ **No hay ningún parámetro del formato sin dato ni sin límite.** Lo que hay es un mapeo a medias, en las
dos puntas. Esto no cambia el plan, lo **amplía**: D deja de ser «poner los límites» y pasa a ser
**completar las 31 filas del formato, con su valor y su límite**.

📌 **Y un hallazgo lateral que puede simplificar el bloque C:** la tabla trae
`Fe_Acum · Cr_Acum · Pb_Acum · Cu_Acum · Sn_Acum · Al_Acum · Si_Acum` — **columnas de acumulado ya
calculadas**. Carlos dijo «el campo está calculado en el BI y no está en la base de datos»; puede que sea
justo esto, o su origen. Si `Fe_Acum` de la última muestra en uso del `CA3195 MT LH` da **3 718,6**, el
bloque C se reduce a **leer una columna** en vez de sumar 9 años. → **BLOQUE 141**, correr antes que C.

### ✅ Quién arregla qué

**Lo nuestro es leer y mostrar.** Lo que falte o esté mal *dentro* de `lc` lo regula **Carlos**, y ya dijo
que lo hace — p.ej. va a **eliminar los límites de aditivos en las ruedas** («no tiene mucho sentido»).
**No es nuestra tarea ni nos bloquea.** Dos consecuencias:

- El mapeo es **data-driven**: sin fila en `lc`, no hay límite. Nunca una lista fija.
- Lo que **notemos** se **reporta**, no se corrige por cuenta propia. Hoy en esa lista: el `Pb LP=2 LC=1`
  de **Cerro Verde MT LH** (invertido sin ser aditivo → parece typo), el desajuste **`730E-` vs `730E`** y
  los aditivos de rueda que él ya va a quitar.

---

## El paso a paso

### D1 · Corregir el inventario  ·  *20 min · sin riesgo*

Reescribir el cierre de `FORMATO_POR_COMPONENTE.md` con la tabla de arriba: los 13 existen y estos son sus
nombres reales. **Es el mapa del que salen todos los pasos siguientes**; si queda mal, todo lo demás
hereda el error.

### D2 · Ampliar `vw_LimitesPorComponente`  ·  *la pieza clave*

Hoy mapea 16 parámetros de `lc`. Pasa a mapear los **31 del formato**.

⚠ **Y hay una trampa en cómo agrega.** La vista hace `GROUP BY ProyKey, ModeloKey, CompTipo`, o sea que
colapsa `MOTOR DE TRACCION LH` y `RH` en un solo `TRACCION`, y resuelve el choque con **`MIN()`**. Para un
límite normal, `MIN` = el más estricto: correcto. **Para un límite invertido, el más estricto es `MAX`** —
por eso `TBN_LP` ya usa `MAX`.

🔴 **Pero `Ca_LP`, `Zn_LP` y `Mg_LP` usan `MIN` y son invertidos** en Rueda, Hidráulico y Motor Diésel. Es
un bug latente que nadie había mirado. La regla queda:

> **invertido → `MAX` · normal → `MIN`**, y la dirección se decide **por parámetro y por componente**
> (`Ca`/`Zn`/`Mg` son aditivos en RD/SH/MODI pero contaminantes en MT).

### D3 · Llevar los 13 valores que faltan a la fundación  ·  ⚠ *el paso de riesgo*

`vw_MuestrasEstado` hoy proyecta 18 parámetros. Hay que sumarle los 13: `Viscosidad40`, `TAN`,
`Oxidacion`, `Sulfatacion`, `Nitracion`, `Mo_ppm`, `Agua`, `Hollin`, `Diesel`, `Refrigerante`,
`Iso4406_4/_6/_14` — más sus LP/LC y su `Estado_*`.

⚠ **Es la vista más caliente del sistema: la lee todo.** Pasa de ~18 a ~31 parámetros, y cada uno suma su
valor, dos límites y un estado. **Medir antes y después, con el operador de producción** (ley 3). Si el
coste sube, la salida es proyectar los 13 nuevos en una vista aparte que solo consuman las 4 vistas de
formato, no la fundación entera.

### D4 · La viscosidad, que es el caso raro  ·  *nada de esto existe hoy*

Carlos fue explícito: la viscosidad **no tiene 2 límites, tiene 4** — `LC inferior · LP inferior ·
LP superior · LC superior`. Parte de un valor y puede irse para arriba **o** para abajo; se vigila que se
mantenga **dentro de la banda**. `lc` ya los trae: `VISC - LPI/LCI/LPS/LCS` y `VISC40 - LPI/LCI/LPS/LCS`.

```
valor < LCI  → 🟥 crítico (bajo)      LCI ≤ valor < LPI → 🟨 precaución (bajo)
LPI ≤ valor ≤ LPS → OK
LPS < valor ≤ LCS → 🟨 precaución (alto)   valor > LCS → 🟥 crítico (alto)
```

⚠ **Y no aplica igual a todos:** en **MT solo existe el crítico** («así está establecido en el manual»);
en **motor diésel van los cuatro**. Se resuelve solo si el mapeo es data-driven: si `lc` no trae `LPI`
para ese componente, ese nivel no se evalúa. **No hardcodear la excepción.**

📌 Hoy `V100` es **display-only** y no dispara `Estado_General` (se apagó el 07/08 porque los límites solo
estaban aterrizados en Antapaccay). Con D4 ya hay límites de verdad → **volver a encenderlo**, pero
después de medir cuántas alertas nuevas aparecen (el 07/08, `V100=0` generó 196 falsos positivos; hay que
comprobar que `V100=0` siga tratándose como SIN DATO).

### D5 · Distinguir «no se mide» de «sin límite»  ·  *lo que hoy confunde*

Hoy los dos casos se pintan `—` y no se distinguen. Carlos señaló los dos en la misma pantalla. Tres
estados, tres símbolos:

| Caso | Valor | Límite | Se muestra |
|---|---|---|---|
| **No se mide** en ese componente (`PQ` en hidráulico, `ISO` en motor de Antapaccay) | ∅ | ∅ | la fila **no sale** |
| **Sin límite cargado** (`D11T`, `797F`, Cuajone) | hay | ∅ | el valor, y en el límite `s/l` |
| **Sin dato en esta muestra** | ∅ | hay | `·` en el valor, **el límite visible** |

⚑ La regla de Carlos: *«si bien el valor del análisis puede dar 0 o null, **el límite ha de estar ahí
visible**»* → el tercer caso es el que hoy falla y el que más se nota.

### D6 · Propagar a las 4 vistas de formato  ·  *mecánico*

`vw_UltimoAnalisisMD` · `vw_CondicionMT_MD` · `vw_DiagnosticoMD` · `vw_TendenciaMD`. Las filas ya están
definidas por el formato; lo que cambia es que ahora **tienen valor y límite**.

⚠ De la ronda anterior: el mapa de parámetros está **duplicado en 4 sitios**, y el peor es
`vw_UltimoAnalisisMD`, que lo tiene **fila por fila, hardcodeado** en la concatenación. Tocar 31
parámetros ahí a mano es pedir un `Msg 207`. **Antes de D6, unificar el mapa en una sola tabla de
parámetros** (`vw_FormatoParametro` ya existe y es el sitio). Sale más barato que hacerlo cuatro veces.

### D7 · Validar y desplegar

1. **BLOQUE 138** — el dato está en `lc` para MT y para MOTOR de Antapaccay.
2. **BLOQUE 139** — cobertura por proyecto/componente/modelo: qué trae cada uno y qué viene `NULL`.
3. **BLOQUE 142** (nuevo) — de los 13 valores «nuevos», cuáles tienen dato real y cuáles vienen vacíos
   siempre. Decide qué filas se muestran y cuáles no existen en la práctica.
4. **Medir** la fundación antes/después (ley 3, `LIKE`).
5. **BLOQUE 89** — smoke test: un `CREATE VIEW` se guarda aunque su cuerpo sea inválido (ley 5).
6. Probar en Teams: `/ultimo 3195 mtlh` debe mostrar límite en `P`, `B`, `Mo`, `Agua`, `ISO>4/6/14`, `V40`.

### Criterio de terminado

`/ultimo 3195 mtlh` sin un solo `—` en la columna de límite **salvo** donde el parámetro genuinamente no se
mide en ese componente — y en ese caso la fila no aparece. Y las 4 vistas de formato diciendo lo mismo.

### Orden y dependencias

```
D1 ─→ D2 ─→ D3 ─→ D4 ─→ D6 ─→ D7
        └─→ D5 ──────────┘
```
D1 es requisito de todo. D5 se puede hacer en paralelo a D3/D4. **D6 no empieza hasta que el mapa de
parámetros esté unificado**, o se paga cuatro veces.

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

### ✅ L5 · LA REGLA, decidida (28/09) — y sale de las vistas, como él intuía

> «Digamos que en `/barridodet` pongo Antapaccay y PC1250. **Solo esa flota** ha de salirme, no tablas
> duplicadas. Ya si no pongo nada, `/barridodet Antapaccay`, pues salen 980, D475 y PC1250.»

Eso se traduce en **una sola regla**, y es **data-driven** — no hay que listar modelos a mano en ningún
sitio, así que escala solo cuando entre otro proyecto:

| Caso | Qué sale |
|---|---|
| **Nombra un modelo** (`Antapaccay PC1250`) | **solo ese modelo**. Nada más, sin rollup |
| **No nombra modelo** (`Antapaccay`) | **todos los modelos del proyecto que tienen límites cargados** en `lc` → hoy 980E, D475A, PC1250 |
| Un modelo **sin límites** (`D11T`, `797F`) | no entra en el default; si lo nombran, sale **con el aviso** de que no tiene límites |

**Cómo se implementa sin romper lo conocido.** Hoy las vistas de flota exponen las filas **por-modelo** *y*
un rollup `(todos)` por `CROSS APPLY (VALUES …)`; el rollup es justo el que duplica.
⛔ [[komfia_barrido_modelo_duplicacion]] avisa de que **colapsar a `(todos)` rompe** cuando sí nombran un
modelo — pero eso es la dirección contraria. Lo correcto es **quitar el rollup y quedarse con las filas
por-modelo**: cada equipo aparece **una sola vez**, en la fila de su modelo, y no hay nada que duplicar.

Para que el caso «sin modelo» siga funcionando, la vista expone una columna nueva **`TieneLimites`** (0/1),
que sale de si `lc` tiene fila para ese proyecto+componente+modelo. El predicado del flujo queda:

```
AND ( Modelo LIKE '%‹modelo›%'  OR ( ‹modelo› = '' AND TieneLimites = 1 ) )
```

Una sola expresión, sin `CASE` en el `WHERE` (**ley 3**: un `CASE` ahí bloqueó el push-down y costó
4 s → +15 min). **Medir igual antes de cablear.**

⚠ **Y el prerrequisito de L1:** mientras el nodo de análisis pueda redibujar la tabla, esto no se nota.
Primero el filtro baja al SQL; después se mide.

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

### ✅ Decidido (28/09): `Acum` va como fila; los estadísticos van como **texto explicado**

`Acum` se queda como **fila repartida en las 6 columnas** (es acumulativo por naturaleza: se lee solo).

`Prom`, `σ` y `Nº fuera de límite` **salen de la tabla** y pasan a una **lista de texto debajo, detallada y
diciendo la lógica** — no un número suelto. Formato pedido:

```
· Prom.: 80.3 ppm  — media de las 6 últimas muestras de monitoreo (no cuenta las DDI)
· Desv. Est. (σ): 77.3  — cuánto se aparta de esa media; alta = valores dispersos, no una tendencia limpia
· Nº fuera de límite: 1 de 6  — muestras que superaron el LP (130.0); de esas, 1 superó el LC (150.0)
```

**Por qué así:** un `Prom` o un `σ` que cambian columna a columna son **acumulados móviles** y en 6 columnas
no se leen; en cambio dicho en una línea con su definición, el número se vuelve interpretable sin conocer
la fórmula. Es la misma idea que ya funcionó con la leyenda de `/rankinggraf`.

⚠ **Lo que hay que cuidar:** cada línea tiene que decir **sobre qué universo** está calculada (las 6
últimas, sin DDI), porque es exactamente la confusión que produjo el `Acum`.

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

### ✅ Decidido (28/09): **vertical** — se prueba al llegar

Fechas en **filas** (como está hoy) y parámetros en **columnas**, acotados a los del componente.

**La razón:** el nº de parámetros es **fijo por componente** (entre 18 y 25); el nº de fechas lo elige el
usuario con `‹rango›`. Lo variable debe crecer hacia **abajo**, que es lo único que scrollea en Teams. Con
`/historial 3195 mtlh 2 años` la versión horizontal explota a lo ancho y **no hay scroll** (ley 9).
Se prueba en vivo al llegar al bloque; si no convence, la horizontal es un `PIVOT` de distancia.

**F2 · Historial de flota, dos retoques finos:**
- El metal debe llevar **su valor al lado**: `Fe` → `Fe(231.8)`, como ya hace el triage.
- Los nombres de componente **en MAYÚSCULA** (`MANDO FINAL LH`, no `Mando Final LH`) — criterio formal del
  área.

Aplica a las 5 variantes: `/historial`, `/historialmetal`, `/historialflota` y las de equipo.

---

## 🅸 Bloque I — `/barrido` se convierte en **Panel de flota** y absorbe `/conteo`

**El diagnóstico, en sus palabras:** «como paso 1 ya vimos que esto no llega lejos, lo vimos con tendencia,
que terminó por combinarse». Es exactamente el mismo caso: `/tendencia` PASO 1 y su detalle se fusionaron
porque el paso 1 no aportaba un paso, aportaba **una segunda lectura de lo mismo**. `/barrido` está igual
respecto de `/barridodet`: fila por equipo vs. detalle por componente, y con 18 equipos observados el
resumen no adelanta nada.

### ✅ Decidido (28/09): opción (a) — panel, fusionando `/conteo`. Si no convence, se desactiva.

**La pregunta que debe responder el panel es otra que la de `/barridodet`.** `/barridodet` responde *«¿qué
le pasa a cada equipo?»*. El panel responde **«¿cómo está la mina?»** — y hoy eso no lo responde nadie:
`/conteo` da la mitad (cuántos por componente) y el barrido actual da la otra mitad mal (una lista larga).

### La salida propuesta

```
Panel de flota — Antapaccay · 980E · D475A · PC1250 · corte 28-Sep-26
27 equipos · 18 observados (7 con crítico · 11 solo precaución) · 9 sin novedad

Por componente
| Componente            | Equipos | Observ. | 🟥 | 🟨 | Lo que más se repite |
|-----------------------|---------|---------|----|----|----------------------|
| MOTOR                 |      27 |       6 |  3 |  3 | Si en 3 equipos      |
| MOTOR DE TRACCION LH  |      27 |       4 |  2 |  2 | Fe en 2              |
| SISTEMA HIDRAULICO    |      27 |       5 |  2 |  3 | Cu en 2              |
| …                     |         |         |    |    |                      |

Por modelo            ← solo cuando NO se nombró modelo
| Modelo  | Equipos | Observ. | 🟥 | 🟨 |
| 980E    |      27 |      16 |  6 | 10 |
| D475A   |       5 |       1 |  0 |  1 |
| PC1250  |       3 |       1 |  1 |  0 |

Dónde empezar
🟥 CA3164 — 3 componentes con crítico (RD LH · Motor)
🟥 CA3169 — 2 (MT RH · Sist. Hidr.)
🟥 CA3176 — 2 (MT LH · RD RH)

→ equipo por equipo: /barridodet Antapaccay 980E
```

### Qué se construye

| Pieza | De dónde sale | Nuevo |
|---|---|---|
| Cabecera (equipos · observados · críticos · sin novedad) | ya lo calcula `vw_ObservadosResumen` | no |
| **Por componente** | **es `vw_ConteoFlotaMD` tal cual** | no |
| Columna «Lo que más se repite» | contar, por componente, en cuántos equipos aparece cada metal observado y quedarse con el primero | **sí** — es lo único nuevo |
| **Por modelo** | el mismo agregado, agrupando por `Modelo` en vez de por componente | casi |
| **Dónde empezar** | top 3 por nº de componentes con crítico; ya se ordena así en el resumen | no |

Vista nueva `vw_PanelFlotaMD`, contrato de siempre (`MD` / `Observados` / `Recomendaciones`), flujo
`MD_flota`. **Una sola lectura de la fundación** para las cuatro secciones — es el patrón que curó el
triage (**ley 2**): agregar sobre la misma fila con `OUTER APPLY`, nunca un CTE referenciado varias veces
con `JOIN` entre sus ramas.

### Qué pasa con `/conteo`

Su tabla **es** la sección «Por componente» del panel. Dos pasos, en este orden:

1. `/conteo` queda como **alias** que entra al mismo tema (igual que `/tendenciadet` → `/tendencia`).
2. Cuando esté probado, se **desactiva el tema 21** — ⛔ desactivar, **no** borrar el nodo (ley 8).

Se pasa de 2 comandos tibios a 1 útil, y `/barridodet` queda como el detalle.

### El criterio de salida

Si al verlo sigue sin aportar sobre `/barridodet`, **se desactiva `/barrido` y `/barridodet` pasa a
llamarse `/barrido`** — que era su opción (c). El panel es un intento con fecha, no un compromiso.

### Lo que va igual, decida lo que decida

- **Quitar la tabla de límites del pie.**
- **Los límites, junto a su valor** (como en `/ultimo`) → depende del **bloque D**.
- **`‹modelo›` con la regla L5** → **bloque L**.

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

# ✅ Decisiones tomadas el 28/09 — ya no hay preguntas que bloqueen

| | Se preguntó | Respuesta |
|---|---|---|
| 1 | El punto cortado del mensaje | Iba a listar los de flota. **No se perdió nada** |
| 2 | `/barrido`: ¿panel, paso 1 acotado o desactivar? | **Panel fusionando `/conteo`** — «lo de `/conteo` me interesa». Si no convence, se desactiva → **bloque I** |
| 3 | `Prom` / `σ` / `Nº fuera de límite` | **Texto en lista, detallado y diciendo la lógica** → **bloque A** |
| 4 | Historial: ¿horizontal o vertical? | **Vertical**, se prueba al llegar → **bloque F** |
| 5 | `‹modelo›`: ¿en cuáles y cómo? | **Casi obligatorio en toda la flota**, con la regla L5: nombrado → solo ese; vacío → los modelos **con límites cargados** → **bloque L** |
| 6 | Los huecos de `lc` | **No nos corresponde**: los regula Carlos. Nosotros leemos, mostramos y **reportamos** lo que notemos → **bloque D** |

**Queda una sola decisión, y es de mirar, no de responder:** al construir el panel del bloque I y el
historial vertical del bloque F, verlos y decir si se quedan.
