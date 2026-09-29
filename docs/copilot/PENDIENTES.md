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

# ▶▶ PLAN DE MAÑANA (29/09) — **todo el SQL primero, Copilot al final**

> Orden pedido por Andrés: **(1)** SQL completo con sus pruebas —deterministas o de rendimiento según el
> caso— y **(2)** recién entonces Copilot Studio y todo lo que arrastre.
> ⚠ Franco espera la presentación interna el **viernes 02/10, 19:30**.

---

# FASE 1 · SQL

Cada paso dice si el DDL **ya está escrito** o **hay que escribirlo**, y con qué bloque se prueba.
⚑ Antes de cada despliegue: `python tools/check_ddl.py`. Después: **BLOQUE 89** (smoke).

> **El verificador ahora trae un radar de CTE**: cuenta cuántas veces se referencia cada CTE dentro de
> su vista, ignorando comentarios. Es informativo, no falla — pero es **siempre el primer sitio donde
> mirar** cuando una vista va lenta. Hoy ya apunta a las otras deudas:
> `vw_DiagnosticoMD.unpv ×5` · `vw_ObservadosBarridoMD.fila ×3` · `vw_CondicionMT_MD.unpv ×3` ·
> `vw_TendenciaMD.rowcte/limcte/obslast ×2` ← **explica los ~35 s de `/tendencia`**.

| # | Qué | DDL | Prueba | Tipo |
|---|---|---|---|---|
| **1** | ~~Consolidar `base` en `vw_DiagnosticoMD`~~ | ⏸ **APARCADO** — corrección ✅, rendimiento ✗ | **148** · **149** | rendimiento |
| **2** | **L3** · `(todos)` = modelos con límites (9 sitios) | ✅ **CERRADO** (150, todo verde) | **150** | determinista + rendimiento |
| **2b** | **L5** · avisar cuando el modelo **no tiene límites** | ✅ **CERRADO** (151, coste cero) | **151** | determinista |
| **3** | **L4** · `/ranking` gana `‹modelo›` | ✅ **SQL CERRADO** (152) — el resto es Copilot | **152** | determinista |
| **4** | **C** · `Acum` con «En uso» + `CM` por componente | ✅ **CERRADO** (154) | **154** | determinista + rendimiento |
| **5** | **J** · triage: 5 columnas por familia | ✅ **CERRADO** (155, todo verde) | **155** | determinista |
| **5b** | **M** · ¿«fuera de límite = observado» para **todo** parámetro? | 🔑 **medido (156): la decisión ya estaba en el código** | **156** · **157** | decisión |
| **5c** | **N** · enchufar `Inf` en el triage | ✍ **escribir** — cierra E0 de raíz | **157.1** | determinista |
| **5d** | **G0** · el `0` no es una medición — 9 guardas | ✅ **escrito** — falta ver | **159** | determinista |
| **5e** | **P** · las ruedas de Antapaccay → **Carlos** | ✅ **RESUELTO en diagnóstico** (158.4): es otro aceite | **158.4** | dato |
| **5f** | **G1** · la inversión sale del **grupo**, no del dato — **bug mío del bloque D** | ✅ **escrito** — falta ver | **160** | determinista |
| **5g** | **R** · 347 componentes con `ISO` sin medir → **Carlos** | ⏸ **no es SQL** — es medición que falta | **159.2** | dato |
| **6** | **B** · `/tendencia` sin tabla de límites | ✍ escribir | visual | determinista |
| **7** | **E** · encabezado de muestra en `/diagcompleto` y `/condicionmt` | ✍ escribir | visual | determinista |
| **8** | **A** · `/grafica` absorbe `/tendenciametal` | ✍ escribir | visual | determinista |

**El orden importa:** el **1** primero porque hasta que `vw_DiagnosticoMD` no baje de 7 scans, cualquier
medición posterior sobre esa cadena miente. El **4** antes que **G** (acumulados por componente depende de
él). El **8** cambia la firma de un comando, así que arrastra Copilot y va al final del SQL.

## Notas por paso

**1 · Consolidar `base`** — ✅ **escrito el 29/09, falta la medición (BLOQUE 148).**
`base` pasa de **6 referencias a 1**: solo `unpv` la lee. CTE nuevo `comp` (1 fila por
equipo+componente) del que salen `hdr_all`, `hdr_obs` y `g`; `obsmetals` y `obsmet` también
derivan de `unpv`.

📌 **Arregla de paso un bug latente:** `obsmetals` decidía la marca por su cuenta con un `CONCAT` de
18 `CASE … LIKE '%:C%'` — un **tercer mecanismo de marcado**, y solo miraba 18 de los 31 parámetros.
Un observado nuevo (`Mo`, `ISO>4/6/14`, `TAN`, `Hollin`…) **nunca** habría aparecido en la columna
`Observados`. Ahora la marca se lee de la **celda que se imprime**: una sola fuente de verdad, la
lección del bloque E3.

🔴 **Y una advertencia que hay que tener presente al medir:** los CTE de SQL Server **no se
materializan**. `unpv` queda referenciado **5 veces**, así que si el optimizador no hace *spool*, cada
referencia re-deriva `unpv` → vuelve a leer `base` → podríamos seguir en ~5 scans. **Mover las lecturas
de `base` a `unpv` no garantiza nada por sí solo.** Si el 148 no baja el `Scan count`, el siguiente
paso es **fusionar pasadas**: `row_all`+`row_obs` en una, `hdr_all`+`hdr_obs`+`g` en otra,
`obsmetals`+`obsmet` en otra → `unpv` bajaría de 5 referencias a 3.

### 🔴 Resultado del BLOQUE 148 (29/09): **no bajó, y hay que decidir**

`LaboratoryData` sigue en **7 scans · 76 928 lecturas** — idéntico. La advertencia se cumplió: los CTE no
se materializan y `unpv` quedaba referenciado 5 veces.
✅ **Lo que sí bajó muchísimo:** `[Eqpcare].[lc]` de **2 185 scans / 52 440 lecturas** a **17 / 408**,
por la simplificación de `vw_LimitesPorComponente` del 28/09.

**Y destapó un bug que introduje yo.** `Observados` devolvía los **31** parámetros en vez de los marcados:
filtré con `cell LIKE N'%🟥%'`, y los cuadros de color son **caracteres suplementarios** (U+1F7E5/U+1F7E8)
— en UTF-16 son un par *surrogate*, y el `LIKE` con una collation no-`_SC` no los trata como un carácter,
así que el patrón matchea de más. **Corregido**: cada tupla lleva el valor **crudo** y se filtra por
`':C'`/`':P'`, que es ASCII. Mismo patrón que el bloque E4.
> ⚑ **Regla nueva: nunca un emoji dentro de un `LIKE`.** Para decidir se usa la marca ASCII; el emoji es
> solo presentación.

### ⏸ Veredicto (BLOQUE 149): **corrección sí, rendimiento no. Aparcado.**

✅ **`Observados` quedó exacto** y cuadra 1:1 con la tabla:
`MT LH: PQ, ISO>6 · MT RH: Zn, ISO>6, ISO>14 · RD LH: Ca, Zn, P, Mg, Na · RD RH: Ca, Zn, P, Mg, Na,
ISO>4, ISO>6`. Fíjate en que ahí hay **`ISO>4/6/14` y `P`**: observados que **antes nunca salían**, porque
`obsmetals` solo miraba 18 de los 31 parámetros. Ese era el bug latente.

❌ **`LaboratoryData` sigue en 7 scans · 76 936 lecturas.** El conteo de referencias a un CTE **no es la
palanca**: la cadena se re-deriva igual. La única cura real sería **reescribir la vista anidando derived
tables** (una derived table anidada se evalúa una vez) — reescritura completa.

**Decisión: aparcado hasta después del 02/10.** 12-20 s **no bloquea** (el conector muere a los 120 s) y
los pasos **2-8** son los que Carlos y Franco van a **ver**. La deuda queda medida y con la cura escrita.

**Lo que sí se llevó el paso 1, y no es poco:** dos bugs cerrados (uno latente, uno mío) y `[Eqpcare].[lc]`
de **2 185 scans / 52 440 lecturas** a **17 / 408**.

**2 · L3** — ✅ **escrito el 29/09 (BLOQUE 150).** Las dos comprobaciones previas se hicieron:
**(a)** los 9 sitios exponen `Proyecto` — verificado uno a uno, incluidos los dos que leen un CTE `base`
propio (`vw_TriageMD` y `vw_UltimoMetalFlotaMD`); **(b)** la medición va en el 150.6.

⛔ **Lo que NO se tocó, a propósito:** la fila **por-modelo**. Si el usuario nombra un modelo, sale
aunque no tenga límites. Solo cambia el **default**. Es la salvaguarda de
[[komfia_barrido_modelo_duplicacion]], que avisa de que colapsar el rollup rompe ese caso.

📌 `vw_ModeloConLimites` pasa a leer `[Eqpcare].[lc]` **directo** (64 filas, sin agregados) en vez de
`vw_LimitesPorComponente`, que es un `GROUP BY` de 60+ agregados: esto se evalúa **por fila** en vistas de
flota y no queremos re-derivar ese agregado cada vez.

**Criterio:** `/triage mt antapaccay` deja de mostrar `### 930E · 18 equipos (0 obs)`; **nombrar** `930E`
sigue devolviendo sus equipos; y `/barrido antapaccay` sigue diciendo **18 equipos**.

**3 · L4** — ✅ **En SQL no había nada que construir.** Al abrirlo: `vw_RankingMD` **ya** expone `Modelo`
(el `ModeloG` del rollup) y el flujo `MD_ranking` **ya** filtra por él
(`AND Modelo LIKE ''%‹modelo›%''`, en [CONFIG_FLUJOS](CONFIG_FLUJOS.md)). Lo único que falta es que el
**comando** lo pase: su firma es `/ranking ‹proj› ‹comp› ‹metal› [top]`, sin modelo.
⇒ **L4 es enteramente Copilot** (firma + dispatcher + tarjeta). Va a la Fase 2, C3/C4.

📌 **Y H3 debería estar cerrado de rebote por L3.** Los equipos `3110…3118` que se colaban en
`/ranking antapaccay mtlh PQ 20` son **930E**, y el `(todos)` nuevo ya no los incluye. Lo comprueba el
**152.1**.

🔴 **Lo que sí se arregló en SQL: un tope silencioso.** `vw_RankingMD` cortaba en `WHERE pos <= 20`, y el
flujo filtra además por el `top` que pide el usuario. Resultado: pedir **top 30 devolvía 20** y nadie lo
decía. El corte sube a **50** — el techo real lo pone el flujo, y 50 filas por
(proyecto, modelo, componente, metal) es trivial.

**4 · C** — ✅ **escrito el 29/09 (BLOQUE 154).** `vw_AcumuladoVida` lee `[Oil].[LaboratoryData]`
**directo**, sin la fundación y **sin la ventana de 12 meses** — que era la causa de fondo: el «Σvida»
viejo eran 12 meses, no la vida del componente.

**La fórmula, validada al decimal dos veces:** `ComponentStatus = 'En uso'` (con u minúscula) +
`CM IN ('ADI','C')` en Motor de Tracción, **todos** los CM en Motor.
→ `CA3195 MT LH Fe = 3 718,6` y `CA3160 MT Fe = 6 785,4`, **la cifra del bloque B**.

**Las cuatro reglas, tal como las dictó Carlos:**

| Componente | `CM` que suma | ¿Acotado al componente instalado? |
|---|---|---|
| **Motor de Tracción** | `ADI` y `C` | ✅ sí (`ComponentStatus = 'En uso'`) |
| **Motor** | **todos** | ✅ sí |
| **Rueda delantera** | solo `C` | ❌ no — ver abajo |
| **Sistema hidráulico** | solo `C` | ❌ no |

🔴 **Corrección del 29/09 — casi pierdo dos de las cuatro reglas.** El 153.2 midió que
`ComponentStatus` **no existe** en rueda ni hidráulico, y con ese dato concluí que ahí no se podía
calcular el `Acum`. **Era una conclusión mía, no lo que dijo Carlos** — él sí dio la regla para esos dos.
Andrés lo señaló. Ahora entran, aplicando `CM = 'C'` **sin** el filtro de «en uso»: exigirlo los dejaría
en cero y perderíamos un acumulado que el área **sí** pidió.

⛔ **Y eso hay que decírselo a Carlos:** en rueda e hidráulico el acumulado **no está acotado al
componente instalado**, porque la base no registra cuál es. Es el acumulado de todas las muestras `C` del
equipo en ese compartimiento. En MT y Motor **sí** está acotado.

⛔ **Mando final, transmisión, caja de giro, damper y PTO se quedan sin `Acum`**: para esos no hay regla
del área *y* además no tienen `ComponentStatus`. Salen `—`, y el pie ahora dice que **`—` no es cero**.

📌 Solo se calculan los **8 metales de desgaste** (los únicos que el display muestra); calcular los 18
sería pagar de más.

### ✅ Resultado del BLOQUE 154 (29/09): **C cerrado**

| | |
|---|---|
| **Las dos cifras** | `CA3160 MT LH Fe = 6 785,4` (la del bloque B) · `CA3195 MT LH Fe = 3 718,6` |
| **Cobertura** | **228 componentes** con `Acum`: Rueda 97 · Tracción 53 · Hidráulico 51 · Motor 27 |
| **Aislamiento** | solo los 8 de desgaste; los otros 15 parámetros salen `—` |
| **Coste** | `vw_AcumuladoVida` sola: **852 ms · 1 scan**. Barata |

📌 **Con las dos reglas que yo había dejado fuera, la cobertura era 80. La corrección recuperó 148
componentes** — rueda e hidráulico.

### 🔴 Una pregunta para Carlos que salió del 154.2b

Cuántas muestras `C` sostienen el acumulado, en Antapaccay:

| Componente | Componentes | Mín | Máx | Promedio |
|---|---|---|---|---|
| **Rueda** | 54 | 14 | 36 | **20** ✅ sólido |
| **Hidráulico** | 32 | **1** | 10 | **6** ⚠ flojo |

En hidráulico hay componentes con **una sola muestra `C`**: ahí el «acumulado» es literalmente el valor de
esa muestra. El número existe y la regla es la que él pidió, pero **dice poco**.
⛔ No lo cambio por mi cuenta — es criterio del área. **Preguntar.**

### ⏱ Y `/tendencia` sigue en 37 s, pero no es por esto

`vw_AcumuladoVida` sola cuesta **852 ms**. `/tendencia` estaba en ~35 s **antes** de esta ronda, así que
el `Acum` **no lo empeoró**. La deuda está identificada por el radar:
`vw_TendenciaMD.rowcte ×2 · limcte ×2 · obslast ×2`. Mismo saco que `vw_DiagnosticoMD`, después del 02/10.

---

**5 · J** — ✅ **escrito el 29/09 (BLOQUE 155).** ⚑ **Rehecho**: primero lo implementé prefijando la
familia dentro de la celda; el diseño que Andrés tenía en mente eran **columnas**.

**La tabla pasa de 8 a 11 columnas.** `Metales Obs.` y `Salud` se reemplazan por **cinco**:

```
Equipo | Comp | Grado | Estado | Desgaste | Aditivos | Contaminación | Salud | Cód. Limpieza | Hrs Comp | Últ.
```

El triage pasa de mirar **9 parámetros a 30**, y cada uno sale **con su valor** — la columna `Salud`
mostraba `V100` a secas, sin número.

📌 **La familia no se escribe a mano: sale de `vw_FormatoParametro`.** Importa, porque **depende del
componente** — el `Ca` es contaminante en Motor de Tracción y aditivo en el resto. Con fallback a
`(CRUZADO)` para `MANDO` y `TRANSMISION`, que no están en el formato por-componente: sin él sus
parámetros desaparecerían **sin ruido**.

### ✅ Resultado del BLOQUE 155 (29/09): **J cerrado**

`V100(63.5) 🟨` — ya sale con su número. El reparto en familias es correcto: `CA3196` pone `Al` en
Desgaste, `Si` y `Hollin` en Contaminación y `Sulfatacion`+`Nitracion` en Salud, **tres columnas
distintas**. El fallback `(CRUZADO)` funciona (`MANDO 8108 → Fe(288.3)`). Contador **sin regresión**:
sigue en «6 de 54 (3 críticos)». Coste: **Scan count 1**, 2 387 ms (antes ~1 723 ms) — sube por los 20
parámetros extra, pero **ningún scan nuevo**, que era la condición. `LargoMD` 6 258 « 28 000 de Teams.

El `Warning: Null value is eliminated by an aggregate` es **benigno**: el `MAX(CASE…)` del pivote
devuelve NULL para las familias sin marcas. No silenciarlo con `SET ANSI_WARNINGS OFF` — apagaría avisos
que sí importan en otras vistas.

---

## 🔴 5b · M — la pregunta que abrió J, y que es la de fondo

Andrés, viendo el resultado: *«la política que se maneja ahora es que para todos los parámetros a medir,
si sale fuera de sus límites (si tiene), está observado, desde el hierro o plomo hasta los ISO»*. Y con
eso, que el triage **liste solo los observados**, filtrando por `‹modelo›`, como `/barrido` pero con otro
formato.

**Qué mira el triage hoy, literal** ([`DDL_vistas.sql:693`](../arquitectura/DDL_vistas.sql)): `Estado_General`
solo evalúa **9 parámetros y medio** — `Fe`, `Cr`, `Ni`, `Cu`, `Si`, `Al`, `Pb`, `Sn`, `PQ` sobre LC
(crítico) o LP (precaución), más `TBN` por debajo. Y eso **tiene sentido**: esos nueve son metal que
*salió de una pieza*. El triage contesta una sola pregunta — **¿qué componente se está dañando?** — y por
eso se llama triage. Lo que **no** contesta es si el aceite está bien: Zn agotado, ISO alto, agua, TAN,
oxidación son **salud del lubricante**, causas y no daños.

⇒ **El triage es un detector de daño, no de desvío.** Lo que lo rompió fue J: las 5 columnas ponen el
desvío **al lado** del daño, y el contador y la tabla pasan a hablar de cosas distintas.

**A favor de la política de Carlos, y es fuerte:** el resto del sistema **ya cuenta así**.
`vw_CondicionMTMD` lo cambió en el BLOQUE 118 — *«el contador sale de las celdas marcadas, no de
Estado_General»* — y eran **119 componentes** con el encabezado contradiciendo a la tabla. El
inconsistente es **el triage**, no la propuesta. Y si solo se imprimen los observados, la tabla se acorta
y las 11 columnas caben: resuelve el ancho de paso.

**⚠ El riesgo no es de lógica, es de CANTIDAD.** En la captura del 29/09 el `Zn` sale marcado en casi
todas las filas de 980E MT (40, 45, 70, 57, 194, 100) y el `ISO>6` también. Si esos disparan, el triage
pasa de «6 de 54» a algo cercano a «**50 de 54**». **Un triage que marca al 90 % no prioriza nada**, que
es lo contrario de para qué existe. Y abre una pregunta que no es de SQL: ¿ese `Zn` en MT es real, o el
límite está mal puesto?

⇒ **BLOQUE 156 — medir antes de escribir.** No toca ninguna vista. Da, por proyecto × componente, cuántos
saldrían observados con la regla nueva, qué parámetro aporta las marcas, y la distribución de `Zn` e
`ISO` contra su límite. La lectura está escrita **dentro del bloque**:

| `Nuevo / Total` | Qué se hace |
|---|---|
| hasta ~40 % | La propuesta **tal cual**: `Estado_General` mira todo, el triage imprime **solo observados**, `‹modelo›` filtra. |
| 40–60 % | Igual, pero el **orden** manda: críticos primero, y tope de filas con aviso de recorte. |
| más de 60 % | **No volver atrás: separar las dos preguntas.** (a) que solo los **críticos** de las familias nuevas disparen; (b) dos contadores: «6 dañados · 48 con desvío»; (c) revisar el límite que el 156.2 señale. |

Esto **también cierra D**, que quedó abierta con exactamente la misma pregunta.

### 🔑 Resultado del BLOQUE 156 (29/09): la decisión **ya estaba tomada en el código**

La predicción se cumplió casi exacta: **Antapaccay TRACCION pasa de 6 a 50** (de 72) = **69,4 %**.
Tramo «más de 60 %» de la tabla de arriba, en cuatro proyectos: Antamina RUEDA **94,6 %**, Toromocho
RUEDA y TRACCION **100 %**, Cerro Verde RUEDA **75 %**.

Pero al revisar `vw_FormatoParametro` para contestar una pregunta de Andrés sobre las familias, apareció
lo que importa — su propia cabecera:

> *`Inf = 1` → parámetro **INFORMATIVO: se muestra pero no dispara estado**. Se conserva el criterio
> vigente (`K`, `Na`, `B`, y `Ca`/`Zn`/`Mg` cuando son **contaminantes**, o sea en TRACCION).*

**El triage del 155 ignora esa bandera.** Por eso el `Zn` sale marcado en media flota de MT: ahí el área
**ya decidió** que se muestre pero no cuente. ⇒ La política de Carlos **no necesita un matiz inventado**:
el matiz existe, se llama `Inf`, y solo hay que enchufarlo. Aplicado a los números: en TRACCION se caen
`Zn` (17) y `Ca` (4); en RUEDA se cae `Na` (54).

### 🔴 Lo que `Inf` NO explica: dos bloques que huelen a límite mal cargado

**RUEDA — `Ca`, `Zn` y `Mg` críticos en 54 de 54.** Son aditivos con límite **invertido**: crítico = *por
debajo del piso*. Que 54 ruedas agoten **tres** aditivos a la vez no pasa. Y se repite en cuatro
proyectos. **Cuatro parámetros con exactamente 54 componentes críticos cada uno no son 216 hallazgos: son
un defecto sistemático.**

**TRACCION — `ISO6` en 48 de 72** con `ISO6_LP = 19` y valores 21-26. Y el 156.4 enseña que **`ISO4_LP` es
NULL en todas las filas** con `ISO4` entre 23 y 28: el canal de **4 µm** —el que siempre sale más sucio,
por definición de la escala— **no tiene límite y calla**; el de 6 µm grita. Eso no describe la limpieza
del aceite, describe una **carga incompleta de `[Eqpcare].[lc]`**.

⚠ Y un tercero, de paso: los **930E no tienen** `Zn_LP`/`Zn_LC` ni `ISO6_LP`/`ISO14_LP`. Salen `OK` pase
lo que pase — `3115` con `Zn = 125,8` sale verde. Es **L5 otra vez**, ahora a nivel de parámetro suelto.

### El orden, y por qué importa

1. **`Inf` en el triage** — gratis, y cierra **E0 de raíz**: sin pie de tabla que lo explique y sin
   pedirle nada a nadie. El parámetro `Inf=1` **se sigue viendo** en su columna (Andrés quiere el valor)
   pero no entra al contador.
2. **Los dos bloques van a Carlos**, no a SQL. El SQL está leyendo **bien** un dato **mal cargado**; se
   corrige en `LIMITES CONDENATORIOS 1.xlsm`.
3. **Recién ahí** se elige el formato del triage (solo observados + `‹modelo›`). Elegirlo ahora sería
   dimensionarlo con 54 falsos positivos dentro.

⛔ **No tocar `Estado_General` todavía.** Mientras el límite de RUEDA esté mal, ampliarlo convierte un
error de carga en **122 equipos «observados» en Antamina** — y eso llega a gerencia como una crisis de
flota que no existe.

### 🧹 Deuda destapada: `Disponible` quedó desfasado

`vw_FormatoParametro` declara `Disponible = 0` para `V40`, `TAN`, `Oxidacion`, `Sulfatacion`, `Nitracion`,
`Mo`, `Agua`, `Hollin`, `Diesel` e `ISO 4/6/14` — *«no tienen fuente en `Oil.LaboratoryData`»*. **El
bloque D encontró 13 de esas columnas y las enchufó.** Por eso el 155.3 mostró `Hollin(0.4)` y
`Sulfatacion(3.2)`, y el 156.2 contó **9 `Oxidacion` críticos** en MOTOR — de un parámetro que el formato
sigue declarando inexistente. **BLOQUE 157.4** lo mide; todo lo que tenga dato pasa a `Disponible = 1`.

### ✅ Y la respuesta a la pregunta de Andrés sobre las familias

Sí, el formato respeta la variación por componente, y su memoria resultó **más completa que `CLAUDE.md`**:

> *«Solo **4 parámetros** cambian de grupo entre hojas — **Ca, Mg, Mo y Zn**: Contaminación en MT y
> Aditivos en las otras tres.»*

Los cuatro que nombró, **`Mo` incluido**. `CLAUDE.md` solo listaba `Ca`/`Zn`/`Mg` — corregido el 29/09.

---

## ⛔ REGLA PERMANENTE — `Inf` nunca se escribe al lado del dato

Andrés lo reiteró el 29/09, justo antes de que implementara `Inf`: *«en el pasado ponías visualmente al
lado del metal la etiqueta `(inf)` y quedamos que no vuelva a pasar JAMÁS»*.

**`Inf` es un criterio de conteo, no una etiqueta visible.** Un parámetro con `Inf = 1` se muestra
**exactamente igual** que los demás —su nombre y su valor— y lo único que cambia es que **no entra al
contador**. Nunca `(inf)`, `inf` ni `(informativo)` pegado al parámetro. Si hay que explicar por qué el
contador no cuadra con lo que se ve, va en el **pie** de la tabla, una vez, en prosa.

Escrita en el DDL en **dos sitios**: la cabecera de `vw_FormatoParametro` y el `OUTER APPLY` del triage,
que es donde se va a implementar.

## Resultado del BLOQUE 157 (29/09)

### `Inf` es necesario pero **no suficiente**

`Nuevo_crudo → Nuevo_con_Inf`: Antamina TRACCION **131 → 94** (la mejora grande, era ruido real de
`Zn`/`Ca`); Antapaccay TRACCION 50 → **48**; Antapaccay RUEDA 54 → **54** *sin cambio* (ahí `Ca`/`Zn`/`Mg`
son aditivos con `Inf=0`). Limpia el ruido de MT y **no toca los dos bloques grandes**.

### 🔴 Me corrijo: el `ISO4` **no** era carga incompleta

Dije que lo era. **El dato estaba en nuestro propio archivo**: el BLOQUE 138.1 ya registró que en
Antapaccay / MT / 980E el Excel trae `ISO 6um LP 19 / LC 20` e `ISO 14um LP 16 / LC 19`, y el **`ISO 4um`
viene NULL a propósito**, junto con Boro, Molibdeno, TAN, VISC40, H2O, Hollín y TBN. Así define el área el
MT. ⇒ **El 48 de 72 del `ISO6` es real.**

Y explica el reparto 38 críticos / 10 precauciones: con `LP 19` y `LC 20` la banda de precaución es de
**un solo punto**, y en la escala ISO 4406 cada punto es **el doble** de partículas. No hay banda
intermedia donde caer. Queda una rareza que sí hay que mirar (**158.3**): Antapaccay MT observa 48 de 54
(89 %) mientras Cerro Verde observa 0 de 16 y Toromocho 0 de 20.

### ⭐⭐ 157.2 — la prueba, y es concluyente

| Proyecto | Modelo | Ruedas | `Ca_LC` | `Ca` de la flota | críticos |
|---|---|---|---|---|---|
| **Antapaccay** | 980E | 54 | **1560** | **154 – 228** | **54 / 54** |
| Cerro Verde | 980E | 16 | 1864 | 3496 – 3951 | 0 |
| Toromocho | 980E | 18 | 1721 | 2470 – 3224 | 0 |
| Toquepala | 980E | 22 | — | 2189 – 2752 | 0 |
| Antamina | 980E | 128 | 2250 | **0** – 4264 | 104 |

**El mejor equipo de Antapaccay está 6,8× por debajo del piso crítico** (en `Zn`: máximo 15,2 contra un
piso de 720, **47×**). Un límite que reprueba al 100 % de la flota con el mejor equipo a un orden de
magnitud del umbral **no separa nada**. Y los demás proyectos corren `Ca` 2000-4000 en la misma posición;
Antapaccay reporta ~200. **Eso no es un aditivo agotado: es otro aceite, u otra base de reporte.**

⇒ **P · pregunta para Carlos:** qué aceite llevan las ruedas de Antapaccay. **No se parchea en SQL** — el
SQL está leyendo bien un límite que no corresponde a ese aceite. El **158.4** le pone el `Grado` al lado.

### 🔴 O · Antamina es **otro** problema, y es un bug mío del bloque D

`Ca_min = 0.0` con `Ca_max = 4264`. **Bajo un límite invertido, un `0` es indistinguible de una
catástrofe** — `0 < LC` siempre. Y `Estado_TBN` **ya lleva** la guarda `TBN > 0` en tres sitios del DDL
(713, 851, 881): un TBN de 0 significa *no medido*, no *base agotada*. Los aditivos que agregué el 28/09
(`Ca`, `Zn`, `Mg`, `P`, `B`, `Mo`) **no la llevan**. Es una línea por aditivo, la cura es nuestra y no
necesita a nadie. **BLOQUE 158.1** lo mide antes de tocarlo.

### 🧹 `Disponible`: mal planteado, no solo desactualizado

Los doce parámetros tienen dato (sobre 1 687 componentes: `Mo` 1598, `Oxidacion` 1371, `Agua` 1364,
`ISO14` 1187…). Pero ⛔ **no basta con ponerlos en 1**: el BLOQUE 142.2 ya concluyó que `Disponible` **no
puede ser una constante por `CompTipo` porque depende de la MINA** — Antapaccay no mide `V40` y sí `TAN`;
Antamina al revés. Como **nadie la consume** (solo se declara y se proyecta), lo correcto es documentarla
como **no usable** y decidir por fila con la regla D5 (*sin valor y sin límite → no sale*), que es lo que
el 142.2 ya había resuelto. **No inventar un tercer criterio.**

---

## ⭐⭐ Resultado del BLOQUE 158: las ruedas de Antapaccay llevan **otro aceite**

El dato estaba en la BD todo el tiempo, en la columna `Grado`:

| Proyecto | Grado | Ruedas | `Ca_prom` | `Zn_prom` | `Ca_LC` |
|---|---|---|---|---|---|
| Antamina 980E | Mobiltrans HD 60 | 125 | 2823 | 860 | 2250 |
| Cerro Verde 980E | Mobiltrans HD 50 | 16 | 3691 | 1172 | 1864 |
| Toromocho 980E | MOBILTRANS HD50 | 18 | 2832 | — | 1721 |
| **Antapaccay 980E** | **SHELL SPIRAX S5 CFD M 60** | **54** | **189** | **3,9** | **1560** |

Todos corren **Mobiltrans HD**; Antapaccay corre **Shell Spirax**. No es el mismo producto ni la misma
química: `Zn` de **3,9 contra 860-1190**. El límite se escribió para un Mobiltrans y esas ruedas no llevan
Mobiltrans. ⇒ **No hay nada que arreglar en SQL**: el límite se actualiza en `LIMITES CONDENATORIOS 1.xlsm`,
y ahora la corrección tiene nombre y apellido. *(De paso: Antapaccay 930E trae `Grado = 'nan'` literal — el
bug `nan` conocido, en otra columna.)*

### 🔴 Y el 158.1 me desmiente

Atribuí el 104/128 de Antamina a los ceros. **Falso:** `Ca_crit` 164 → **164** con la guarda. Los 28 ceros
de Antamina no estaban contados (caen en componentes sin límite de `Ca`). La guarda corrige **6 casos
reales en Antapaccay y ninguno en Antamina**. Sigue siendo correcta —un `0` no es una medición, y
`Estado_TBN` ya la tenía— pero **no explica Antamina**, que queda abierto en **Q / 159.4**.

### ⭐⭐ Lo grave, que no era lo que buscaba

**BLOQUE 158.3** — `ISO6` en Motor de Tracción, con los límites **idénticos** (19/20) entre Antamina 980E y
Antapaccay 980E. Pero **Cerro Verde 930E: `min 0`, `max 0`, `prom 0,0`** en los tres canales. Figuraba con
«0 observados» y lo leí como flota limpia. **No está limpia: no está medida.**

⇒ Bajo un límite **normal**, el `0` no fabrica un falso positivo: **fabrica un falso negativo, e invisible**.
Un componente sin medir se lee igual que uno impecable. Es un **tercer modo de fallo silencioso**, y ya está
escrito como tal en la ley 5 de `CLAUDE.md`.

## ✅ G0 desplegado — 9 guardas (BLOQUE 159)

- **6 aditivos** (`Ca`, `Zn`, `Mg`, `B`, `P`, `Mo`): `= 0 → 'SIN DATO'`, **solo en el ramo invertido**. Para
  un *contaminante* un `0` es una lectura válida («no hay contaminación») y ahí no se toca nada.
- **3 canales ISO**: `= 0 → 'SIN DATO'`. Un código ISO 4406 de `0` es físicamente imposible (≤0,01
  partículas/ml).
- `Estado_General` **no se tocó** → el triage debe dar exactamente lo mismo (**159.3**).

⚠ **Un componente que pasa a `SIN DATO` no es una buena noticia**: significa que llevamos tiempo dándolo por
limpio sin medirlo. Si el **159.2** devuelve números grandes, eso va a Carlos tanto como los límites.

---

## Resultado del BLOQUE 159 — G0 clavado, y Antamina resuelto

**G0 hizo exactamente lo medido.** Antapaccay `Zn` 54 → **48** (los 6 ceros), `Mg` 54 → **41** (los 13),
`Ca` 54 → 54 (no tenía ceros). Antamina **sin moverse**, tal cual estaba previsto. Triage **idéntico**.

### ⭐⭐ La cifra del fallo silencioso: **347 componentes**

Venían leyéndose como «código de limpieza dentro de límite» **sin una sola medición** — `ISO6 = 0` salía
`OK`. Entre ellos **los 158 motores de Antamina, al completo**. No es que estuvieran limpios: es que nadie
los midió, y el `0` los hacía indistinguibles de los limpios de verdad.

⚠ **Esto no es una victoria de G0**: es la cuenta de lo que veníamos dando por bueno. Va a Carlos igual
que los límites. *(El resto de `SIN DATO` del 159.2 son NULL, que ya se trataban bien.)*

### 🔴 159.4 — Antamina era un bug mío, y estaba advertido en este mismo archivo

| Grado | Banda | Ruedas | `Ca` |
|---|---|---|---|
| Mobiltrans HD 60 | **3000 o más** | **102** | 3 006 – 4 264 |
| Mobiltrans HD 60 | 0 (no medido) | 23 | — |

**102 ruedas entre 3 006 y 4 264 ppm contra un `LC` de 2 250, y salían críticas.** Solo hay una forma: el
`CASE` cayendo al ramo de **contaminante** y reprobándolas por tener *demasiado* calcio. En una rueda el
`Ca` es un **aditivo** y 3 000 ppm es lo normal — Cerro Verde corre 3 690 y Toromocho 2 832, y no salen
críticos porque ahí el par `LP`/`LC` **sí** viene invertido. **164 falsos críticos de un solo parámetro.**

Y la cabecera de `vw_FormatoParametro` ya lo advertía, con el BLOQUE 104 detrás:

> *`Inv = 1` → límite INVERTIDO. Se deduce del **GRUPO**, no del dato. ⛔ **NO derivarlo de `LP > LC`**
> aunque el dato lo respalde en general — el archivo de gerencia trae un typo y el bucket `OTRO` produce
> inversiones artificiales al colapsar componentes distintos con `MIN()`.*

En el bloque D escribí exactamente lo que ese aviso prohíbe.

### 🔴 159.5 — mi smoke test estaba mal escrito, y eso es peor que el error

`dbo.vw_CondicionMTMD` no existe (es `vw_CondicionMT_MD`). Lo grave no es el `Msg 208`: **el lote se cortó
ahí**, así que `vw_UltimoAnalisisMD` y `vw_BarridoMD` **nunca se probaron**. *Un smoke test incompleto se
lee como aprobado.* Corregido, y el **160.5** cubre **11 vistas** con cada `SELECT` suelto, para que un
fallo no tape a los que siguen.

## ✅ G1 desplegado (BLOQUE 160)

Nueva vista **`vw_InvPorComponente`** (7 filas, el `Inv` del formato pivotado) + **un** `LEFT JOIN` en
`vw_MuestrasEstado` + los 6 `CASE` pasan de `lim.X_LP > lim.X_LC` a **`inv.X_Inv = 1`**. `Estado_General`
sin tocar; `G0` se mantiene.

⚑ **Si el 160.2 no baja Antamina a cero, G1 no es la causa y se revierte** (`git`), no se insiste. El
**160.3** cuida la dirección contraria: en MT el `Ca`/`Zn` son contaminantes y el `CA3165` con `Zn 194,8`
tiene que **seguir** saliendo crítico. El **160.4** comprueba que ningún `CompTipo` se quede sin fila en el
JOIN — si se queda, el aditivo se juzgaría como contaminante **en silencio**.

**6 · B** — En `vw_TendenciaMD` hay que quitar `limcte`, `limbody` y `limbody_rel`.
⚠ **Lo que NO se puede perder:** el aviso de «sin límites cargados» (45 combinaciones proyecto+modelo lo
necesitan, BLOQUE 102). Hoy vive pegado a esa tabla; al quitarla hay que **conservarlo como línea de
texto**, o volvemos a un fallo silencioso.

**7 · E** — Filas de encabezado **dentro** de la matriz (una por campo, una columna por componente): en
`/condicionmt` y `/diagcompleto` cada componente tiene **su** fecha, grado y horas, así que un encabezado
único mentiría.

**8 · A** — `Acum` como fila de 6 columnas; `Prom`, `σ` y `Nº fuera de límite` **fuera de la tabla**, como
lista de texto con su lógica. Sin `Spark`. Límites como una línea, no como tabla.

## ✅ Ya resuelto sin escribir SQL

- **K2** — `vw_TendenciaIncipienteMD` lee `vw_MuestrasRankeadas` (que ya filtra `EsDDI=0`) **y además**
  tiene su propio `WHERE EsDDI = 0`. **Doble filtro: no usa DDI.** Lo que pidió Carlos ya está; **K** se
  reduce a reescribir la descripción, que es Copilot.
- **L1** — el SQL filtra bien (BLOQUE 147). Es Copilot.

## Queda para después del viernes

**F** (historial vertical con todos los parámetros) · **I** (Panel de flota) · **G** (acumulados por
componente, depende del paso 4). Los tres son módulos nuevos, no retoques.

---

# FASE 2 · COPILOT STUDIO — detallado

> ⛔ Nada de esto se toca hasta que la Fase 1 esté desplegada y probada en SSMS.
> ⚑ Gotcha permanente: al añadir una entrada a un tema ya referenciado, **guardar el tema destino
> primero** y luego **re-seleccionarlo** en el nodo «Ir a otro tema» —cambiarlo a otro y volver a
> elegirlo— para que relea sus entradas. Si no, el mapeo no aparece.

### C1 · `‹modelo›` no llega al flujo  ⭐ el bloqueante de L

**Temas 16 (Barrido resumen) y 17 (Barrido detalle).** Mirar en este orden:

1. ¿`modelo` está como **Entrada** del tema, o quedó **fijo en la Acción**? Es el mismo patrón que
   `vista`/`columna`, que **sí** van fijas a propósito — por eso es fácil habérselo puesto igual sin querer.
2. En el Tema 00, nodo «Ir a otro tema»: ¿está mapeado `modelo ← p2`?
3. En la Acción del tema: ¿`modelo` se pasa al flujo?

**Prueba de que quedó, sin SSMS:** `/barrido antapaccay d475` → **«1 equipo»**.
`/barrido antapaccay 980` → **«16 equipos»**. Si los dos dicen **18**, sigue llegando `(todos)`.
*(Medido en el BLOQUE 147: 728 / 2 397 / 2 601 caracteres de `MD`.)*

### C2 · El fallback y el análisis **no pueden dibujar tablas**  ⭐ el más grave

Dos sitios, un solo vicio:

- **`prompts/analisis_prompts.md`** — hoy prohíbe inventar datos, pero **no prohíbe re-emitir la tabla**.
  Añadir explícito: *el análisis comenta, **nunca** re-dibuja la tabla ni una versión «filtrada» de ella*.
  (Caso: `/barridodet antapaccay 980` imprimió la tabla y debajo el análisis la volvió a dibujar.)
- **`KomfIA_SQL_MD.docx`** (el fallback) — que **no arme tablas con formato de módulo**. Cuando un comando
  no encuentre su tema, **decirlo**; no improvisar.
  (Casos medidos: `/conteo Antapaccay 797` y `/conteo Antapaccay d11` devolvieron tablas **fabricadas**
  con modelos que no existen en ese proyecto.)

### C3 · Descripciones y firmas

| Tema | Qué |
|---|---|
| **20 Incipiente** | Reescribir la descripción: «Equipos que **todavía no pasan el límite** pero vienen subiendo fuerte. Si un parámetro **ya superó el límite**, no aparece aquí: sale en `/triage` y en `/barrido`.» |
| **22 Ranking** | Firma nueva `/ranking ‹proj› ‹comp› ‹metal› [modelo] [top]` + descripción |
| **06 Gráfica** | Absorbe `/tendenciametal`: `/grafica ‹equipo› ‹componente› ‹metal›`, los tres **obligatorios** |
| **08 Tendencia de un metal** | **Desactivar** — ⛔ desactivar, **no** borrar el nodo |
| **27/28 Acumulados** | Decir en la **descripción** que solo existe para Antapaccay (hoy sale como aviso al final) |

### C4 · Los tres archivos de la tarjeta, siempre juntos

`CONFIG_COMANDOS.md` + `tools/gen_comandos_card.py` + `docs/copilot/tarjetas/comandos_card.json`.
Cambian: `/ranking` (+`modelo`), `/grafica` (3 obligatorios) y se va `/tendenciametal`.
De 20 comandos a **19**.

### C5 · Los que quedan vivos

- **H1** · `/ranking` a secas responde «Tas a una» → sin parámetros debe pedirlos o mandar a `/comandos`.
- **H2** · `/ayuda` responde dos cosas distintas → la aleatoriedad del 17/09 sigue abierta.
- **H5** · `/conteo` lista un componente `nan` (`Compartimiento` nulo) — **este es SQL**, se puede colar
  en la Fase 1 si sobra tiempo.
- **H6** · `/triage mtrh` con columnas descuadradas — solo esa variante.

---

## 🔴 PENDIENTE PUNTUAL — `vw_DiagnosticoMD` lee `base` 7 veces

> **Recordarlo en cada ronda hasta que se haga.** No bloquea, pero es deuda medida y con nombre.

`/diagcompleto` está hoy en **12,1 s** contra los **2 418 ms** de referencia. La causa está medida
(bloques 145 y 146, 28/09) y es una sola:

> **`base` se referencia SIETE veces** en `vw_DiagnosticoMD` — líneas 21, 31, 72, 77, 108, 132, 142 —
> y `[Oil].[LaboratoryData]` tiene **exactamente 7 scans**. Uno por referencia. Cada CTE que lee `base`
> re-deriva la cadena de 4 vistas entera. Los **2 185 scans** de `[Eqpcare].[lc]` son consecuencia de lo
> mismo (7 × ~312).

⚠ **No lo introdujo el bloque D.** El 25/09 ya se midieron **4 scans** y quedó anotado como «queda
margen». D solo lo hizo visible al pasar de 18 a 31 parámetros: de 4 referencias a 7, y de 2,4 s a 12.

**La cura:** consolidar las 7 lecturas en **1**, agregando sobre la misma fila con window functions /
`OUTER APPLY` en vez de en CTEs paralelos. Es exactamente la que llevó `vw_TriageMD` de **113 780 ms a
860 ms** (ley 2).

**Cómo se hace, cuando se haga:** es una reestructuración de verdad — se mide antes, se hace de una, se
vuelve a medir. La métrica de éxito **no es el tiempo, es el `Scan count`**: tiene que bajar de 7 a 1 o 2.
Bloque de validación **147** cuando se ataque.

---

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

## 🅻 Bloque L — el parámetro `‹modelo›`  ⭐ TRANSVERSAL

### ✅ Veredicto (28/09, BLOQUE 147): **el SQL filtra bien. El bug está en Copilot.**

El mismo predicado que usa el flujo, con tres modelos:

| Consulta | Largo del `MD` | Dice |
|---|---|---|
| `Modelo LIKE '%d475%'` | **728** | «1 equipos con ≥1 componente observado» |
| `Modelo LIKE '%980%'` | **2 397** | «16 equipos» |
| `Modelo LIKE '%todos%'` | **2 601** | «18 equipos» |

Tres largos, tres conteos. **La vista filtra sin problema.** Lo mismo en el detalle (399 vs 3 708).

Y hay una razón estructural por la que tenía que ser así: `(todos)` es **una fila más** de la vista, así
que `LIKE '%980%'` **no puede** traerla — `(todos)` no contiene `980`. El filtrado es automático **en
cuanto llegue el parámetro**.

⛔ **Tocar las 9 vistas con rollup no habría arreglado nada.** Por eso el bloque 147 fue primero.

---

### ✅ L5 · Avisar cuando el modelo no tiene límites (29/09)

El BLOQUE 150.3 dejó esta frase: `Antapaccay · 930E · 0 de 18 observados (0 críticos)`.
**No significa que los 18 estén sanos** — significa que no hay límites con que evaluarlos. Es la misma
familia de fallos silenciosos de toda la ronda, y encima da un verde tranquilizador sobre 18 equipos que
nadie ha mirado.

**Qué se hizo:** **7 encabezados** —`/triage`, `/barrido`, las **4 variantes** de `/barridodet` y
`/conteo`— añaden una línea **solo** cuando el modelo pedido no tiene fila en `[Eqpcare].[lc]`:

> ⚠ **930E no tiene límites cargados** para este proyecto: los equipos salen **sin evaluar**, no sanos.

⛔ **No restringe nada.** El modelo sigue saliendo entero, con todos sus equipos. Es el criterio que pidió
Andrés: *«los límites han de estar para cuando se los necesite… pero no deben ser invasivos ni
restrictivos con el resto de flotas»*. No restringimos: **avisamos**.

📌 El `NOT EXISTS` se evalúa **una vez por fila del resultado** (una por proyecto+modelo+componente), no
por equipo. Verificado en el 151.4.

### ⏳ L6 · `/barrido` con un modelo sin observados dirá «no encontré datos»

Lo destapó el 151.3: `/barrido antapaccay 930E` **no devuelve ninguna fila**, porque esa vista solo lista
equipos **observados** y el 930E no tiene ninguno. El tema mostrará «no encontré datos», cuando la verdad
es **«ese modelo no tiene equipos observados, y además no tiene límites con que evaluarlos»**.

Es el **modo B** de fallo silencioso (0 filas por `INNER JOIN`/`GROUP BY`): `ISNULL` no sirve, hay que
**emitir** la fila.

⛔ **No se toca en SQL ahora.** Cambiar la cardinalidad de `vw_ObservadosResumenMD` afecta a **todos** los
proyectos sin observados — y ahí «ninguno observado» es una **buena noticia legítima**, no un error. Se
resuelve mejor en el **tema**, con un mensaje sin-data que distinga los dos casos. Va a la Fase 2 (C5).

### L1 · Lo que hay que arreglar, y es en Copilot Studio

**El síntoma:** `/barrido antapaccay d475` y `/barrido antapaccay 980` devolvieron la misma tabla ⇒ al
flujo le llega **siempre `(todos)`**. El dispatcher sí lo manda (`modelo = If(p2="","(todos)",p2)` está en
[CONFIG_COMANDOS](CONFIG_COMANDOS.md)), así que se pierde entre el tema y la acción.

**Dónde mirar, en este orden** — temas **16** (Barrido resumen) y **17** (Barrido detalle):

1. ¿`modelo` está como **Entrada** del tema, o quedó **fijo en la Acción**? Si está fijo, la IA nunca lo
   llena y el valor del comando se descarta. Es el mismo patrón que `vista`/`columna`, que **sí** van
   fijas a propósito — y por eso es fácil que se le haya puesto lo mismo a `modelo` sin querer.
2. En el nodo **«Ir a otro tema»** del Tema 00, ¿está mapeado `modelo ← p2`?
3. En la **Acción** del tema, ¿`modelo` se pasa al flujo, o el flujo recibe su valor por defecto?

⚑ **Gotcha conocido** ([CONFIG_TEMAS](CONFIG_TEMAS.md)): al añadir una entrada a un tema ya referenciado
hay que **guardar el tema destino primero** y luego **re-seleccionar** el tema en el nodo «Ir a otro tema»
—cambiarlo a otro y volver a elegirlo— para que relea sus entradas. Si no, el mapeo no aparece.

**Cómo comprobar que quedó**, sin SSMS: `/barrido antapaccay d475` tiene que decir **«1 equipo»** y
`/barrido antapaccay 980`, **«16 equipos»**. Si los dos dicen 18, sigue llegando `(todos)`.

### L2 · Y el otro, que es el grave: **el análisis redibuja la tabla**

En `/barridodet antapaccay 980` la tabla verbatim salió con **todos** los equipos y **debajo el nodo de
análisis la volvió a dibujar** bajo el título «*Filtrado para modelo 980E — se excluyen 6116 y 8108*».
Eso es romper la **ley 1** (ningún LLM toca la tabla) y hace que el resultado no sea reproducible.

Va en el **prompt universal** ([prompts/analisis_prompts.md](prompts/analisis_prompts.md)): ya dice que no
invente datos, pero **no dice que no puede volver a dibujar la tabla**. Hay que añadirlo explícito: el
análisis comenta, **nunca re-emite** la tabla ni una versión «filtrada» de ella.

---

### L3 · `(todos)` pasa a significar «los modelos con límites cargados»  · SQL, listo para aplicar

**Por qué, con el dato del 147.4.** La flota de Antapaccay son **6 modelos, 48 equipos**:

| Modelo | ¿Límites? | Equipos |
|---|---|---|
| `980E` | ✅ | 27 |
| `D475A` | ✅ | 5 |
| `PC1250` | ✅ | 4 |
| **`930E`** | ❌ | **9** |
| **`HD1500`** | ❌ | **2** |
| **`WA900`** | ❌ | **1** |

⚠ **Corrijo lo que dije el 28/09:** afirmé que los modelos sin límites eran `D11T` y `797F`. **No.** Son
`930E`, `HD1500` y `WA900`, y suman **12 equipos**. `D11T` y `797F` no existen en Antapaccay — lo que
devolvió `/conteo` con esos textos es otro bug, va a **H3**.

Esos 12 equipos salen **todos en verde** porque no hay con qué evaluarlos. Se ven hoy en el triage:
`### 930E · 18 equipos (0 obs)`, con `Grado —` y `Hrs Comp —`. Ruido puro.

**El cimiento ya está desplegado:** `vw_ModeloConLimites` (validada en 147.5: 10 pares).

**El patrón a aplicar** en los **9 sitios** que hoy hacen `CROSS APPLY (VALUES (X.Modelo),(N'(todos)'))`
—líneas 1472, 1615, 1672, 1691, 3039, 3248, 3297, 3376, 3448 de `DDL_vistas.sql`:

```sql
CROSS APPLY (SELECT X.Modelo AS ModeloG
             UNION ALL
             SELECT N'(todos)' WHERE EXISTS (
                 SELECT 1 FROM [dbo].[vw_ModeloConLimites] ml
                 WHERE ml.ProyKey   = UPPER(LTRIM(RTRIM(X.Proyecto)))
                   AND ml.ModeloKey = UPPER(LTRIM(RTRIM(X.Modelo))))) mg
```

Es autocontenido: **no** obliga a tocar ningún `WHERE` de las vistas.

⚠ **Antes de aplicarlo, dos comprobaciones** — y no son burocracia, son las dos formas en que esto se
rompe en silencio:
1. **Que las 9 fuentes expongan `Proyecto`.** Dos de los sitios (3039 y 3448) leen un CTE `base` propio:
   si no lo lleva, es `Msg 207` **al consultar**, no al desplegar.
2. **Medir.** Es un `EXISTS` por fila en vistas de flota. La tabla tiene 10 filas y debería ser gratis,
   pero hoy ya se pagó una regresión de 6 minutos por dar algo por gratis.

**Criterio de terminado:** `/triage mt antapaccay` deja de mostrar la sección `### 930E · 18 equipos
(0 obs)`, y `/barrido antapaccay` sigue diciendo **18 equipos** (los 12 sin límites no tenían observados,
así que el resumen no debería moverse — si se mueve, hay que entender por qué).

### L4 · `/ranking` no tiene `‹modelo›` en su firma

Hoy es `/ranking ‹proj› ‹comp› ‹metal› [top]`. Por eso `/ranking antapaccay mtlh PQ 20` mezcló equipos de
930E —sin límites, con `—/—`— junto a los `CA####` de 980E. Pasa a
`/ranking ‹proj› ‹comp› ‹metal› [modelo] [top]`, y se toca el módulo completo: descripción + tema 22 +
flujo `MD_ranking` + `vw_RankingMD` + la tarjeta + `gen_comandos_card.py`. Cierra **H3** de paso.

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

### ✅ K2 — verificado (28/09): **ya no usa DDI, y por partida doble**

Carlos pidió «considera NO DDI» porque una muestra dializada baja la media de las 6 previas y **infla el
% de subida** → falsos incipientes. Lo comprobé y **ya estaba cubierto**:

`vw_TendenciaIncipienteMD` lee **`vw_MuestrasRankeadas`**, que termina en `WHERE me.EsDDI = 0`, **y
además** tiene su propio `WHERE EsDDI = 0 AND rn_recencia <= 7`. Doble filtro.

⇒ **No hay SQL que escribir en K.** El bloque se reduce a reescribir la descripción, que es Copilot (C3).

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

## 🅷 Bloque H — los bugs sueltos, que resultaron ser **uno solo**

### 🔴 La causa común: **el fallback fabrica tablas indistinguibles de las reales**

Comparando las **insignias** de las capturas de la marcha del 28/09:

| Consulta | Insignia | Qué era |
|---|---|---|
| `/conteo antapaccay d475` | «KomfIA» | tema determinista, **dato real** |
| `/conteo Antamina 798` | «KomfIA · **Generado por la IA**» | **fabricado** |
| `/conteo Antapaccay 797` | «**Generado por la IA**» | **fabricado** |
| `/conteo Antapaccay d11` | «**Generado por la IA**» | **fabricado** |
| `/ranking antapaccay motor K 20` | «**Generado por la IA**» | fabricado |
| `/rankingacum antamina` | «**Generado por la IA**» | fabricado — devolvió la tabla de **Antapaccay** |
| `/barrido antapaccay d475` y `… 980` | sin insignia | deterministas los dos ⇒ el bug es **L1** |

**La prueba:** `/conteo Antapaccay 797` devolvía «797F · 4 equipos» y `/conteo Antapaccay d11`, «D11T ·
5 equipos» con las mismas filas que el D475A. Pero el **BLOQUE 147.4** midió que Antapaccay tiene **6
modelos** — `980E`, `D475A`, `PC1250`, `930E`, `HD1500`, `WA900`. **Ni `D11T` ni `797F` existen ahí.**

Y la tabla traía encabezado, columnas, conteos y semáforo. **Indistinguible de una real.** Es el peor
fallo de los que hemos tenido: no se cae, no avisa, y parece correcto.

> ⚑ **Regla de trabajo, desde hoy:** al revisar capturas de una marcha, **mirar la insignia antes de
> creerse una tabla**. Sin insignia = determinista. Con insignia = sospechosa hasta probar lo contrario.

**La cura NO es mejorar el prompt del fallback.** Es que **el fallback no dibuje tablas** (ley 1), y que
cuando un comando no encuentra su tema lo **diga** en vez de improvisar. Conecta con **L2**: el mismo
vicio que hace que el análisis redibuje la tabla del barrido.

### Los que quedan tras colapsar la causa común

| | Qué pasó | Estado |
|---|---|---|
| **H1** | `/ranking` a secas respondió «Tas a una» | Sin parámetros debe pedirlos o mandar a `/comandos` |
| **H2** | `/ayuda` respondió dos cosas distintas seguidas | La aleatoriedad del 17/09 sigue abierta |
| **H3** | `/ranking antapaccay mtlh PQ 20` mezcló `3114`…`3118` | ✅ **CERRADO (29/09)** por **L3**, sin tocar el ranking: esos equipos son `930E` y el `(todos)` nuevo ya no los incluye. Verificado en el 152.1 |
| **H4** | «`Hollín` no existe» | ❌ **Falso, y fabricado.** `HOLLIN - LP/LC` está en `lc` y el bloque D ya lo lee |
| **H5** | `/conteo` lista un componente `nan` | Vivo — `Compartimiento` nulo. Se ve en `/conteo antapaccay d475` (determinista) |
| **H6** | `/triage mtrh antapaccay 980` con columnas descuadradas | Vivo, solo en la variante `mtrh` |
| **H7** | `/rankingacum antamina` devolvió la tabla de Antapaccay | ✅ **Explicado**: fabricado por el fallback |

### 📌 Por qué existen esos equipos «raros» — contexto del negocio (28/09)

`797F`, `798AC` y `D11T` son **CAT**, la competencia, y **están de verdad en la base**. No es un error:
los proyectos van bajo distintos contratos —**MARC**, **LLP MARC** (Antapaccay), **LLP** (Quellaveco, Las
Bambas)— y **la mina carga la data de toda su flota**, sea Komatsu o CAT. KMMP lo sabe; puede que los
depuren más adelante.

⇒ **Un modelo sin límites suele ser un equipo que KMMP no gestiona**, no un hueco que haya que tapar.
Es el argumento de fondo de **L3**: el `(todos)` por defecto debe apoyarse en `vw_ModeloConLimites`, y si
alguien pregunta por un modelo sin límites hay que **decírselo**, no devolver una tabla muda.


# Heredado de la ronda 23/09 — lo que sigue abierto

| | Qué | Estado |
|---|---|---|
| **1** | ~~El universo del `Σvida`~~ — **el 6 785,39** | ✅ **CERRADO (29/09)**. Apareció en el BLOQUE 153.5: es el `Fe_Acum` del **CA3160 · Motor de Tracción** con `ComponentStatus='En uso'` + `CM IN ('ADI','C')` sobre **toda** la historia. Llevaba bloqueado desde el 25/09 |
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
