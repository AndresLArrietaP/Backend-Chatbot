# Config canónica — FLUJOS (Power Automate)

> **Familia CONFIG** — lo que está aplicado en Copilot Studio:
> [CONFIG_TEMAS](CONFIG_TEMAS.md) (temas/tópicos) · [CONFIG_FLUJOS](CONFIG_FLUJOS.md) (Power Automate) ·
> [CONFIG_COMANDOS](CONFIG_COMANDOS.md) (atajos `/`) · [CONFIG_PROMPTS](CONFIG_PROMPTS.md) (nodos de IA) ·
> [CONFIG_TIMEOUT](CONFIG_TIMEOUT.md) (reintentos y cortes).
> Backlog único: [PENDIENTES](PENDIENTES.md). Historia del proyecto: [../BITACORA.md](../BITACORA.md).

**Reglas:** query FIJO por flujo (nunca cambia); solo cambia el valor de la entrada `vista` desde cada tema.
Toda vista `*MD` expone `MD`(+variantes)/`Observados`/`Recomendaciones`. Cada salida usa
`if(empty(outputs('Ejecutar_una_consulta_SQL_(V2)')?['body/resultsets/Table1']), '', first(outputs('Ejecutar_una_consulta_SQL_(V2)')?['body/resultsets/Table1'])?['Col'])`
(evita el BadGateway con 0 filas → devuelve `''` → el tema muestra el mensaje sin-data).

## 4 flujos reutilizables (retirar el legacy `Barrido_Detalle`, H2)

| Flujo | Entradas | Query fijo (query_sql) |
|---|---|---|
| **MD_equipo** | `vista`,`equipo`,`columna` | `SELECT ⟦columna⟧ AS MD, Observados, Recomendaciones FROM ⟦vista⟧ WHERE Equipo LIKE '%⟦equipo⟧%'` |
| **MD_equipo_comp** | `vista`,`equipo`,`compartimiento`,`columna` | `SELECT ⟦columna⟧ AS MD, Observados, Recomendaciones FROM ⟦vista⟧ WHERE Equipo LIKE '%⟦equipo⟧%' AND REPLACE(compAbbr,' ','') LIKE '%' + REPLACE('⟦compartimiento⟧',' ','') + '%'` |
| **MD_metal** | `vista`,`equipo`,`compartimiento`,`parametro` — **sin `columna`** | `SELECT MD, Observados, Recomendaciones FROM ⟦vista⟧ WHERE Equipo LIKE '%⟦equipo⟧%' AND REPLACE(compAbbr,' ','') LIKE '%' + REPLACE('⟦compartimiento⟧',' ','') + '%' AND Parametro='⟦parametro⟧'` |
| **MD_flota** | `vista`,`proyecto`,`modelo`,`columna` | `SELECT ⟦columna⟧ AS MD, Observados, Recomendaciones FROM ⟦vista⟧ WHERE Proyecto LIKE '%⟦proyecto⟧%' AND Modelo LIKE '%⟦modelo⟧%'` |

> ⚠ **`MD_metal` NO tiene entrada `columna` — y no debe tenerla (corregido 24/09).** La tabla decía que sí,
> pero el flujo real siempre tuvo 4 entradas. Los **4** temas que lo usan pasan `columna=MD` — siempre el
> mismo valor — y las 4 vistas que consulta (`vw_TendenciaMetalMD`, `vw_TendenciaGraficoMD`,
> `vw_HistorialMetalEquipoMD`, `vw_HistorialMetalMD`) exponen una columna llamada literalmente `MD`.
> Un parámetro que nunca varía no aporta y sí resta: si llega vacío, la query queda `SELECT  AS MD` → error
> de sintaxis. Por eso va **`MD` literal** en el `concat`.
> ⛔ Los demás flujos **sí** conservan `columna`: `MD_flota` la necesita de verdad (barrido filtrado usa
> `MD_Criticos` / `MD_Precaucion` / `DetalleTodosMD`).

> 🔴 **Comparación de componente insensible a espacios (24/09).** `MD_equipo_comp` y `MD_metal` comparan
> con `REPLACE(compAbbr,' ','')` contra `REPLACE(‹compartimiento›,' ','')`. **Por qué:** `compAbbr` es `MT LH`
> **con espacio**, y el usuario escribe `mtlh` → `LIKE '%mtlh%'` daba **0 filas** y el agente respondía
> «No encontré datos», que suena a «no hay muestras». Bug silencioso.
> ⚠ Esta capa es **necesaria además** de la normalización del dispatcher
> ([CONFIG_COMANDOS §Fórmula canónica](CONFIG_COMANDOS.md)): por **lenguaje natural** el tema llena
> `compartimiento` directamente y la fórmula del dispatcher **no corre**. Las dos capas cubren los dos caminos.
> 🔴 **(04/10) Falta el `comp_key` en estos dos** (ya está en `MD_historial`). Por comando no hace falta: el Tema 00
> normaliza. Por **lenguaje natural** sí: «el último del hidráulico del 3195» llega como `hidráulico` o `hidr&#225;ulico`
> y `LIKE '%hidraulico%'` no casa con `Sist.Hidr.` → «No encontré datos». Pasos en cada flujo (`MD_equipo_comp`: temas
> 01 · 06 · 07 · 10 — `MD_metal`: tema 09):
> 1. Redactar nuevo **`comp_key`** antes del SQL, con esta expresión (cada `‹compartimiento›` = la **ficha** de esa entrada):
>    `if(equals(trim(coalesce(‹compartimiento›,'')),'%'),'%',if(contains(toLower(replace(coalesce(‹compartimiento›,''),' ','')),'hid'),'Hidr',if(or(startsWith(toLower(replace(coalesce(‹compartimiento›,''),' ','')),'mt'),contains(toLower(replace(coalesce(‹compartimiento›,''),' ','')),'tracc')),concat('MT',if(endsWith(toLower(replace(coalesce(‹compartimiento›,''),' ','')),'rh'),'RH',if(endsWith(toLower(replace(coalesce(‹compartimiento›,''),' ','')),'lh'),'LH',''))),if(or(startsWith(toLower(replace(coalesce(‹compartimiento›,''),' ','')),'rd'),contains(toLower(replace(coalesce(‹compartimiento›,''),' ','')),'rueda')),concat('RD',if(endsWith(toLower(replace(coalesce(‹compartimiento›,''),' ','')),'rh'),'RH',if(endsWith(toLower(replace(coalesce(‹compartimiento›,''),' ','')),'lh'),'LH',''))),if(contains(toLower(replace(coalesce(‹compartimiento›,''),' ','')),'motor'),'Motor',replace(coalesce(‹compartimiento›,''),' ',''))))))`
> 2. En el Query, el tramo `'%' + REPLACE('‹compartimiento›',' ','') + '%'` pasa a **`'%‹comp_key›%'`** (la ficha de la
>    salida del Redactar). El resto del Query no cambia.
> 3. Probar el flujo a mano con `hidráulico`, `mtlh` y `MT LH`: los tres deben dar fila.
> ⚠ `MD_triage` y `MD_incipiente` no usan ESE replace porque filtran por `CompTipo`, no por `compAbbr`
> — pero necesitan **el suyo**: ver la § FIX CANÓNICO de arriba. Dejarlos sin normalizar costó los dos
> comandos el 25/09.

## Descripción de ENTRADAS (una línea, lista para pegar)
- `vista` — "Vista *MD a consultar (la fija cada tema; ej. vw_DiagnosticoMD)."
- `equipo` — "Código de equipo (ej. CA3177)."
- `compartimiento` — "Componente abreviado: MT LH / MT RH / RD LH / RD RH / Sist. Hidr. / Motor. Traduce apodos. `todos` = todos los componentes."
- `parametro` — "Símbolo del metal/parámetro: Fe, Cu, Cr, Pb, Sn, Si, Zn, PQ… Traduce cobre→Cu, hierro→Fe."
- `proyecto` — "Proyecto/mina (ej. Antapaccay)."
- `modelo` — "Modelo de equipo (ej. 980E); `todos` = todos los modelos."
- `columna` — "Variante/columna de la vista (la fija cada tema; ej. MD, MD_Completo, MD_Relevantes, DetalleTodosMD, MD_Criticos, MD_Precaucion)."

## Descripción de SALIDAS (una línea, lista para pegar)
- `md` — "Bloque markdown ya armado; se imprime tal cual."
- `observados` — "Componente:metales observados; insumo del análisis (NULL si no aplica)."
- `recomendaciones` — "Bloque verbatim de recomendaciones + cierre; se imprime tal cual (NULL si no aplica)."

> **H3:** `MD_metal` hoy solo mapea la salida `md`. Para uniformar el contrato, agregar también las salidas
> `observados` y `recomendaciones` (vienen NULL en sus vistas). Menor, pero deja los 4 flujos idénticos.

## N4 · El equipo `T3160` (código de Cummins) — en los 5 flujos que reciben `equipo` (02/10)

`MD_equipo` · `MD_equipo_comp` · `MD_metal` · `MD_historial` · `MD_acumequipo`. Dos «Redactar» antes del SQL,
mismo patrón que el componente (ley 3: traducir es del flujo):

1. **`eq in`** — `trim(coalesce(` + ficha **equipo** + `,''))`
2. **`eq`** — texto plano:
```
if(and(startsWith(toUpper(outputs('eq_in')),'T'), greaterOrEquals(length(outputs('eq_in')),5), contains('0123456789', slice(outputs('eq_in'),1,2))), slice(outputs('eq_in'),1), outputs('eq_in'))
```
3. En la consulta, la ficha **equipo** se cambia por la salida de **`eq`** (en un `concat`: `outputs('eq')`).

Regla del BLOQUE 176.3: se quita la `T` solo si sigue un dígito y el código tiene ≥5 caracteres →
`T3160` → `3160` → `CA3160`; `T1`, `T11`, `HT079` intactos. ⚠ `slice` y no `substring`: `substring` revienta
con textos cortos o vacíos (el historial de flota llama a `MD_historial` con equipo vacío), `slice` devuelve `''`.

## Flujo `MD_ranking` (dedicado — Ranking; honra el top N)
Vista FIJA `vw_RankingMD` (formato largo: 1 fila por posición). El flujo ARMA la tabla y filtra `pos <= top`.
**5 entradas** (todas Texto): `proyecto`, `modelo`, `compartimiento`, `parametro`, `top` (opcional; vacío → 10).
Query (pégalo como expresión `fx`; cada nombre en ‹› = ficha de contenido dinámico de esa entrada):
```
concat('SELECT MAX(HeaderMD) + NCHAR(10) + STRING_AGG(Fila, NCHAR(10)) WITHIN GROUP (ORDER BY pos) AS MD, CAST(NULL AS nvarchar(max)) AS Observados, CAST(NULL AS nvarchar(max)) AS Recomendaciones FROM dbo.vw_RankingMD WHERE Proyecto LIKE ''%', ‹proyecto›, '%'' AND Modelo LIKE ''%', ‹modelo›, '%'' AND CompTipo COLLATE Latin1_General_CI_AI LIKE ''%', ‹compartimiento›, '%'' AND Metal LIKE ''%', ‹parametro›, '%'' AND pos <= ', if(empty(‹top›),'10',‹top›))
```
**(02/10) Traducción del componente:** antes del SQL, los dos Redactar `comp_in` / `comp_tipo` (ver «Cómo queda»
más abajo, los mismos de `MD_triage`), y en el query `CompTipo = '‹comp_tipo›'` en vez del `LIKE`. Sin esto, el
orquestador manda `hidr&#225;ulico` (entidad HTML) o `mt` y no casa nada.
Query tal como queda en el editor (sintaxis de Power Automate: las entradas son `triggerBody()?['text_N']`):
```
concat('SELECT MAX(HeaderMD) + NCHAR(10) + STRING_AGG(Fila, NCHAR(10)) WITHIN GROUP (ORDER BY pos) AS MD, CAST(NULL AS nvarchar(max)) AS Observados, CAST(NULL AS nvarchar(max)) AS Recomendaciones FROM dbo.vw_RankingMD WHERE Proyecto LIKE ''%', triggerBody()?['text_2'], '%'' AND Modelo LIKE ''%', triggerBody()?['text_3'], '%'' AND CompTipo = ''', outputs('comp_tipo'), ''' AND Metal LIKE ''%', triggerBody()?['text_5'], '%'' AND pos <= ', if(empty(triggerBody()?['text']),'10',triggerBody()?['text']))
```
⚠ **Las tres comillas** alrededor de `outputs('comp_tipo')`: sin ellas el SQL queda `CompTipo = TRACCION` o
`CompTipo =  AND` → `Incorrect syntax near the keyword 'AND'` (medido 02/10).
⚠ `comp_in` se arma con la **ficha** `compartimiento` de Contenido dinámico, no escribiendo `text_N` a mano.
Salidas: `md` (=`first(...)?['MD']`), `observados` (NULL), `recomendaciones` (NULL).
En el Tema 22: la Acción fija nada de vista/columna (el query ya apunta a vw_RankingMD); la IA llena
`proyecto`, `compartimiento`, `parametro`, `top`; `modelo` = `(todos)` por defecto.
**Descripciones de entradas:** proyecto="Proyecto/mina." · modelo="Modelo; (todos) si no lo nombran." ·
compartimiento="Tipo de componente (tracción/hidráulico/rueda/mando/transmisión/motor)." ·
parametro="Metal (Fe, Cu, Cr, Ni, Pb, Sn, Al, Si, PQ)." · top="Cuántos equipos mostrar; vacío = 10."


## Flujos DEDICADOS de gap-fillers (vista FIJA en el query → SIN scramble de fichas)
Como el ranking: la vista va HARDCODEADA en el `concat` → solo hay fichas de VALOR (no de identificador), que no se desordenan. Cada `‹x›` = ficha de contenido dinámico de esa entrada, insertada EN ORDEN.

### Flujo `MD_tendmetalflota` (Tema 23) — entradas: proyecto, modelo, compartimiento, parametro
```
concat('SELECT MD, Observados, Recomendaciones FROM dbo.vw_TendenciaMetalFlotaMD WHERE Proyecto LIKE ''%', ‹proyecto›, '%'' AND Modelo LIKE ''%', ‹modelo›, '%'' AND CompTipo COLLATE Latin1_General_CI_AI LIKE ''%', ‹compartimiento›, '%'' AND Metal LIKE ''%', ‹parametro›, '%''')
```

## § FIX CANÓNICO — normalizar a `CompTipo` **en el flujo, no en el SQL** (v2, 2026-09-25)

🔴 **La v1 metía el `CASE` dentro de la consulta. NO SIRVE.** Medido (BLOQUE 131):

| Query | Tiempo |
|---|---|
| Con el `CASE` dentro | **>15 min** (hubo que abortarla) |
| Con `CompTipo = 'TRACCION'` literal | **4 103 ms** |

⇒ **~230× de diferencia.** El motivo: `v.CompTipo = CASE WHEN x.c … END` **no es una constante** para el
optimizador — depende de una fila del `CROSS APPLY` —, así que **el filtro no se puede empujar dentro de la
vista**. La vista construye los 6 tipos de componente y filtra al final.

⚠ **La lección, que ya nos costó dos veces hoy:** una expresión en el `WHERE` que el optimizador no puede
resolver como constante **cambia el plan entero**, no solo añade trabajo. Igual que el `MAX()` en el `JOIN`
de F4.2 esta mañana.

⇒ **La traducción se hace ANTES, en Power Automate.** El SQL se queda con una comparación literal, que es
justo la forma rápida.

### Cómo queda — dos acciones «Redactar» + una línea en la query

**1 · «Redactar», renómbralo `comp_in`** — normaliza el texto de entrada. Es la única donde insertas la
ficha del parámetro:

```
toLower(trim(⟦compartimiento⟧))
```

**2 · «Redactar», renómbralo `comp_tipo`** — traduce al vocabulario de la vista. Es **texto plano**, se
copia y pega tal cual, sin insertar fichas:

```
if(contains(outputs('comp_in'),'tracc'),'TRACCION',if(startsWith(outputs('comp_in'),'mt'),'TRACCION',if(contains(outputs('comp_in'),'rueda'),'RUEDA',if(startsWith(outputs('comp_in'),'rd'),'RUEDA',if(contains(outputs('comp_in'),'hidr'),'HIDRAULICO',if(equals(outputs('comp_in'),'sh'),'HIDRAULICO',if(contains(outputs('comp_in'),'mando'),'MANDO',if(contains(outputs('comp_in'),'transmis'),'TRANSMISION',if(contains(outputs('comp_in'),'motor'),'MOTOR',outputs('comp_in'))))))))))
```

⚠ **El orden importa:** `tracc` va **antes** que `motor`, porque `MOTOR DE TRACCION` contiene «motor».
⚠ **Acentos resueltos por construcción:** las claves (`tracc`, `hidr`, `rueda`, `mando`, `transmis`) no
llevan tilde, así que `tracción` e `hidráulico` casan igual.
⚠ **El `else` devuelve el texto tal cual** → si llega algo irreconocible, la query da **0 filas** y el tema
muestra su mensaje de sin-datos. ⛔ No se defaultea a tracción en silencio.

**3 · El campo `Query/query`** — igual que antes, cambiando **una línea**:

`MD_incipiente`:
```
SELECT MD, Observados, Recomendaciones
FROM dbo.vw_TendenciaIncipienteMD
WHERE Proyecto LIKE '%⟦proyecto⟧%'
  AND CompTipo = '⟦comp_tipo⟧'
```

`MD_triage`:
```
SELECT MD, Observados, Recomendaciones
FROM dbo.vw_TriageMD
WHERE Proyecto LIKE '%⟦proyecto⟧%'
  AND Modelo LIKE '%⟦modelo⟧%'
  AND CompTipo = '⟦comp_tipo⟧'
```

⛔ **Sin `CROSS APPLY`, sin `CASE`, sin `COLLATE`.** La query vuelve a ser tan simple como era — y por eso
vuelve a tardar 4 s.

✅ **Sigue sin haber que tocar el dispatcher:** da igual que llegue `MT`, `tracción`, `TRACCION` o
`Sist. Hidr.`; lo resuelve `comp_tipo`.

#### ⚠ Las tres cosas que pueden salir mal al montarlo, y cómo se ven

| Qué | Síntoma | Cómo se comprueba |
|---|---|---|
| La ficha del `Query` sale de **`comp in`** en vez de **`comp tipo`** | `CompTipo = 'mt'` → **0 filas** → «no encontré datos» | pasa el ratón por la ficha: debe decir el **segundo** Redactar |
| El nombre del Redactar lleva espacio (`comp in`) y la expresión dice `outputs('comp_in')` | la expresión devuelve vacío → `CompTipo = ''` → 0 filas | Power Automate usa `_` internamente, así que **normalmente casa**; si no, renombra los Redactar **sin espacio** |
| El orden de los `if` | `tracción` acaba en `MOTOR` | ver que `tracc` aparece **antes** que `motor` en la expresión |

⛔ **Los tres fallan igual de silenciosos: 0 filas y «no encontré datos».** Por eso el flujo se prueba
**desde Power Automate** (Probar → Manualmente), donde se ve la salida de cada Redactar, antes de ir a Teams.
✅ **Y sigue cubriendo el lenguaje natural**, que no pasa por el dispatcher.

### Regla general — dónde va cada cosa

> **Traducir vocabularios es trabajo del flujo. Filtrar es trabajo del SQL.**
> Si la traducción se mete en el `WHERE`, el optimizador deja de poder empujar el filtro y la vista se
> construye entera.

| Bug | Vocabulario | Dónde se defendió | Coste de equivocarse |
|---|---|---|---|
| `mtlh` → 0 filas (24/09) | `compAbbr` | `REPLACE` en el `WHERE` de `MD_equipo_comp` | ninguno: `REPLACE` sobre una **columna** ya impedía el índice de todos modos |
| `hidráulico` → 0 filas (25/09) | `CompTipo` | **«Redactar» en el flujo**, no en el `WHERE` | el `CASE` en SQL costó **>15 min** contra 4 s |

---

### Flujo `MD_incipiente` (Tema 20 — Tendencia incipiente) — entradas: proyecto, compartimiento
> ✅ **Verificado en el editor (02/10):** lleva los Redactar `comp in`/`comp tipo` y la consulta real es
> `CompTipo = '‹comp_tipo›'` (§ FIX CANÓNICO). El `concat` con `LIKE` de abajo es la versión anterior.
Misma forma que `MD_triage` pero sobre `vw_TendenciaIncipienteMD`. `compartimiento` = palabra BASE
(tracción/rueda/motor/hidráulico/mando/transmisión), default `tracción`.
> 🔴 **(03/10) Entra `modelo`** — la vista nueva (BLOQUE 194) da **una fila por modelo** más `(todos)`, como el
> triage. Sin filtro de modelo el flujo tomaría una fila cualquiera con `first()`. Pasos, **antes** de desplegar el DDL:
> 1. Entrada nueva **`modelo`** (Texto). Descripción: «Modelo (980E, 930E…); (todos) si no lo nombran.»
> 2. En el `Query`, después del `CompTipo`: `AND Modelo LIKE '%‹modelo›%'` — en el editor:
>    `' AND Modelo LIKE ''%', if(empty(triggerBody()?['text_N']),'todos',triggerBody()?['text_N']), '%'''`
>    (`text_N` = la ficha de la entrada `modelo`; insértala desde Contenido dinámico, no la escribas a mano).
> 3. Tema 20: entrada `modelo` («Se debe solicitar» desmarcado, sin entidad → vacío) y pasarla al flujo.
>    Desde el Tema 00 llega ya resuelta ([CONFIG_COMANDOS](CONFIG_COMANDOS.md), fila `/incipiente`).
> Con la vista vieja (`Modelo='(todos)'` fijo) el filtro `todos` devuelve lo mismo que hoy: se puede montar ya.
```
concat('SELECT MD, Observados, Recomendaciones FROM dbo.vw_TendenciaIncipienteMD WHERE Proyecto LIKE ''%', ‹proyecto›, '%'' AND CompTipo COLLATE Latin1_General_CI_AI LIKE ''%', ‹compartimiento›, '%''')
```
> **Deuda conocida:** `MD_triage` y `MD_incipiente` tienen la MISMA forma y solo cambian de vista. Se podrían
> fusionar en uno con entrada `vista` (como `MD_flota`). No se hizo ahora para no tocar el Tema 19, que funciona.

### Flujo `MD_limites` (Tema 30 — `/limites`, `/limitesc`; R12, 03/10) — entradas: proyecto, compartimiento, modelo, columna
**Se arma copiando `MD_incipiente`** (··· → Guardar como): ya trae `proyecto`, `compartimiento`, `modelo` y los Redactar
`comp in` / `comp tipo`. Se agrega la entrada **`columna`** (Texto: «MD o MD_Completo; la fija el tema.») y el `Query` queda:
```
SELECT ‹columna› AS MD, Observados, Recomendaciones
FROM dbo.vw_LimitesMD
WHERE Proyecto LIKE '%‹proyecto›%'
  AND CompTipo = '‹comp tipo›'
  AND Modelo LIKE '%‹modelo›%'
```
`(todos)` llega igual por `comp tipo` (el `else` de la traducción devuelve el texto tal cual) y casa con la fila resumen.
Reintentos = **Ninguno**. Salidas: `md` = `first(...)?['MD']`, `observados`, `recomendaciones` (NULL).
⚠ `‹columna›` va **sin comillas** (es un nombre de columna); como solo puede ser `MD` o `MD_Completo` (lo fija el tema),
no hay inyección posible desde el chat.

### Flujo `MD_triage` (Tema 19 EVOLUCIONADO) — entradas: proyecto, modelo, compartimiento
> ✅ **Verificado en el editor (02/10):** lleva los Redactar `comp in`/`comp tipo` y la consulta real es
> `CompTipo = '‹comp_tipo›'` (§ FIX CANÓNICO). El `concat` con `LIKE` de abajo es la versión anterior.
Triage generalizado: cualquier componente, TODOS los equipos (obs o no), agrupado por modelo. `compartimiento` = palabra BASE (tracción/hidráulico/rueda/mando/transmisión/motor); default `tracción`. `modelo` lo llena la IA (honra el nombrado; `(todos)` si no) — en `(todos)` la vista agrupa por modelo con sub-títulos; con modelo, tabla única de ese modelo.
```
concat('SELECT MD, Observados, Recomendaciones FROM dbo.vw_TriageMD WHERE Proyecto LIKE ''%', ‹proyecto›, '%'' AND Modelo LIKE ''%', ‹modelo›, '%'' AND CompTipo COLLATE Latin1_General_CI_AI LIKE ''%', ‹compartimiento›, '%''')
```
Salidas: `md`=`first(...)?['MD']`, `observados` (NULL), **`recomendaciones`**=`first(...)?['Recomendaciones']` (solo llena en TRACCION; NULL en otros comp → el tema la oculta con Condición «no está en blanco»). En la Acción: `compartimiento` default `tracción`; `modelo` IA/(todos). ⚠ ⛔ NO hardcodear `modelo=(todos)` (ignora el modelo pedido).

### Flujo `MD_acumflota` (Tema 27 — Ranking de acumulados) — entradas: proyecto
Envuelve `vw_AcumuladosFlotaMD` (que envuelve el Ranking de Atención del dashboard; motor diésel Antapaccay).
```
concat('SELECT MD, Observados, Recomendaciones FROM dbo.vw_AcumuladosFlotaMD WHERE Proyecto LIKE ''%', ‹proyecto›, '%''')
```
Salidas: `md`=`first(...)?['MD']`, `observados`/`recomendaciones` (NULL). Alcance: Antapaccay motor diésel.

### Flujo `MD_acumequipo` (Tema 28 — Acumulados de un equipo) — entradas: equipo
```
concat('SELECT MD, Observados, Recomendaciones FROM dbo.vw_AcumuladosEquipoMD WHERE Equipo LIKE ''%', ‹equipo›, '%''')
```
Salidas: `md`=`first(...)?['MD']`, `observados`/`recomendaciones` (NULL). Alcance: Antapaccay motor diésel (equipos CA31xx).

### Flujo `MD_condcomp` (Tema 24) — entradas: proyecto, modelo, compartimiento
```
concat('SELECT MD, Observados, Recomendaciones FROM dbo.vw_CondicionCompMD WHERE Proyecto LIKE ''%', ‹proyecto›, '%'' AND Modelo LIKE ''%', ‹modelo›, '%'' AND CompTipo COLLATE Latin1_General_CI_AI LIKE ''%', ‹compartimiento›, '%''')
```

En la Acción: `modelo=(todos)`; la IA llena proyecto/compartimiento(/parametro). Salidas: `md`=`first(outputs('Ejecutar_una_consulta_SQL_(V2)')?['body/resultsets/Table1'])?['MD']`, `observados` (NULL), `recomendaciones` (NULL).
⚠ **`compartimiento` = la palabra BASE del tipo** (tracción, hidráulico, rueda, mando, transmisión, motor) — ⛔ NUNCA la abreviatura (MT LH, Sist. Hidr., RD LH); el `COLLATE` ya tolera tildes/mayúsculas.

### Flujo `MD_ultmetalflota` (Tema 25 — Último análisis por metal en la flota) — entradas: proyecto, modelo, compartimiento, parametros
Es el ÚNICO flujo que **agrega N tablas en una** (`STRING_AGG`): el usuario puede pedir 1 metal o varios («hierro y cobre», «silicio, hierro y cromo») y la vista trae **1 fila por metal** → el flujo las une → **una tabla por metal**. Los metales van en `parametros` como **lista separada por comas** (`Fe` o `Fe,Cu,Cr`); el filtro `CHARINDEX(',' + Metal + ',', ',' + ‹parametros› + ',')` selecciona los pedidos sin `STRING_SPLIT`.
```
concat('SELECT STRING_AGG(MD, NCHAR(10)+NCHAR(10)) WITHIN GROUP (ORDER BY MetalOrden) AS MD, CAST(NULL AS nvarchar(max)) AS Observados, CASE WHEN MAX(Recomendaciones) IS NULL THEN CAST(NULL AS nvarchar(max)) ELSE N''**🔧 Recomendaciones Técnicas (Motores de Tracción)**'' + NCHAR(10) + STRING_AGG(Recomendaciones, NCHAR(10)) WITHIN GROUP (ORDER BY MetalOrden) END AS Recomendaciones FROM dbo.vw_UltimoMetalFlotaMD WHERE Proyecto LIKE ''%', ‹proyecto›, '%'' AND Modelo LIKE ''%', ‹modelo›, '%'' AND CompTipo COLLATE Latin1_General_CI_AI LIKE ''%', ‹compartimiento›, '%'' AND CHARINDEX('','' + Metal + '','', '','' + ''', ‹parametros›, ''' + '','') > 0')
```
En la Acción: la IA llena `proyecto`, **`modelo`** (honra el que nombre el usuario; default `(todos)` SOLO si no lo nombran — NUNCA vacío), `compartimiento` (default `tracción`) y `parametros` (el/los metal(es) en símbolo, separados por coma). ⛔ NO hardcodear `modelo=(todos)`: ignora el modelo pedido y mezcla equipos de otros modelos sin límites. Salidas: `md`=`first(...)?['MD']`, `observados` (NULL), **`recomendaciones`**=`first(...)?['Recomendaciones']` (⚠ el view solo la llena si `CompTipo=TRACCION` y el metal salió observado → NULL para no-MT o sin observados; el tema la muestra bajo Condición «no está en blanco»).
**(02/10) Traducción del componente, igual que `MD_ranking`:** Redactar `comp_in`/`comp_tipo` antes del SQL y
`' AND CompTipo = ''', outputs('comp_tipo'), ''' AND CHARINDEX(` en vez del `LIKE`. Medido: la rama `/metalflota`
del Tema 00 pasa `Topic.comp2`, que convierte «tracción» en **`MT`** → `CompTipo LIKE '%MT%'` = 0 filas → `md`
vacío → el análisis imprime «-» (un `•` suelto) y el orquestador **vuelve a llamar al tema** por su cuenta
(dos ejecuciones del flujo por consulta).
⚠ `parametros` = **símbolos** separados por coma SIN espacios ideal (`Fe,Cu`), pero el `CHARINDEX` con el wrap de comas tolera 1 o N. ⚠ `compartimiento` = palabra BASE (tracción/hidráulico/…), NUNCA la abreviatura. ⚠ `modelo` DEBE ir `(todos)` por defecto (no vacío): un `modelo` vacío haría `LIKE '%%'` y traería las filas por-modelo Y la `(todos)` → duplicación.
### Flujo `MD_historial` (P4 — Historial con RANGO; sirve a los Temas 11/12/13/14/15) — 7 entradas
`vista` · `equipo` · `compartimiento` · `parametro` · `proyecto` · `desde` · `tope`

**Por qué es dedicado y por qué es GENÉRICO.** Las vistas `*MD` concatenan el markdown dentro (`STRING_AGG`),
así que el flujo no puede filtrar muestras por fecha; y no se puede parametrizar una vista (`CREATE FUNCTION`
**denegado**, Msg 262). → Las vistas `*FilasMD` exponen **1 fila por muestra** con el `Fila` ya armado **y el
encabezado partido** (`TituloMD` + `SufijoMD` + `ColsMD`), y este flujo concatena. Como el encabezado viene de
la vista, **el mismo flujo sirve a las 5 variantes**: solo cambia la entrada `vista`.
Mismo patrón que `MD_ranking`, que ya expone `HeaderMD` y deja que el flujo lo concatene.

- **Contrato de las vistas `*FilasMD`:** `Equipo` · `compAbbr` · `Parametro` · `Proyecto` · `FechaMuestreo` ·
  `rn` · `TituloMD` · `SufijoMD` · `ColsMD` · `Fila`. Donde no aplique, constante vacía (así el `WHERE`
  genérico nunca falla).
- **`desde`** = fecha `yyyy-MM-dd` que calcula el TEMA desde el rango pedido. Vacío → `1900-01-01`.
- **`tope`** = máximo de filas. Vacío → **200** (medido: 59 chars/fila máx → ~11 800 chars, bajo los ~28 000).
- El **total del rango** sale con `COUNT(*) OVER ()` en la MISMA pasada: ⛔ no referenciar la vista dos veces.
- Si `tope` recorta, se anexa el pie «_Mostrando las N más recientes de M en el rango._». ⛔ Nunca en silencio.
- El título se parte en `TituloMD` + `SufijoMD` porque **el conteo depende del rango** y lo pone el flujo.

Query (expresión `fx`; cada `‹x›` = ficha de contenido dinámico, EN ORDEN) — ⚠ **versión anterior al 03/10**: la vigente
(con `comp_key` y el metal sin comodines) es la de «Tal como queda en el editor», más abajo:
```
concat('WITH f AS (SELECT Equipo, compAbbr, Parametro, Proyecto, rn, TituloMD, SufijoMD, ColsMD, Fila, COUNT(*) OVER () AS Tot FROM dbo.', ‹vista›, ' WITH (NOLOCK) WHERE Equipo LIKE ''%', ‹equipo›, '%'' AND compAbbr COLLATE Latin1_General_CI_AI LIKE ''%', ‹compartimiento›, '%'' AND Parametro LIKE ''%', ‹parametro›, '%'' AND Proyecto LIKE ''%', ‹proyecto›, '%'' AND FechaMuestreo >= ''', if(empty(‹desde›),'1900-01-01',‹desde›), '''), sel AS (SELECT TOP (', if(empty(‹tope›),'200',‹tope›), ') * FROM f ORDER BY rn) SELECT MAX(TituloMD) + CAST(COUNT(*) AS nvarchar(10)) + MAX(SufijoMD) + NCHAR(10) + NCHAR(10) + MAX(ColsMD) + NCHAR(10) + STRING_AGG(Fila, NCHAR(10)) WITHIN GROUP (ORDER BY rn) + CASE WHEN MAX(Tot) > COUNT(*) THEN NCHAR(10) + NCHAR(10) + N''_Mostrando las '' + CAST(COUNT(*) AS nvarchar(10)) + N'' más recientes de '' + CAST(MAX(Tot) AS nvarchar(10)) + N'' en el rango._'' ELSE N'''' END AS MD, CAST(NULL AS nvarchar(max)) AS Observados, CAST(NULL AS nvarchar(max)) AS Recomendaciones FROM sel')
```
**Salidas:** `md` = `first(...)?['MD']` · `observados` (NULL) · `recomendaciones` (NULL).

**Qué pasa cada tema.** ⚠ Las 7 entradas del flujo son **obligatorias**: lo que no aplica NO se deja en
blanco, se escribe el literal **`%`** (el SQL arma `LIKE '%' + ‹valor› + '%'`, así que `%` da `LIKE '%%%'`
= no filtra). ⛔ No poner `""`, ni un espacio, ni `(todos)`.
| Tema | vista | equipo | compartimiento | parametro | proyecto |
|---|---|---|---|---|---|
| 11 Historial componente | `vw_HistorialFilasMD` | ✔ | ✔ | `%` | `%` |
| 12 Historial equipo | `vw_HistorialEquipoFilasMD` | ✔ | `%` | `%` | `%` |
| 13 Historial metal (equipo) | `vw_HistorialMetalEquipoFilasMD` | ✔ | `%` | ✔ | `%` |
| 14 Historial metal en comp. | `vw_HistorialMetalFilasMD` | ✔ | ✔ | ✔ | `%` |
| 15 Historial observados flota | `vw_HistorialFlotaFilasMD` | `%` | `%` | `%` | ✔ |

**Descripciones de entradas (listas para pegar):**
- `vista` = "Vista de filas a consultar (vw_HistorialFilasMD, vw_HistorialEquipoFilasMD, …). La fija el tema."
- `equipo` = "Código del equipo (ej. CA3177). Escribir % si no aplica."
- `compartimiento` = "Componente abreviado (MT LH, MT RH, RD LH, RD RH, Sist. Hidr., Motor) o el nombre completo. Escribir % si no aplica."
- `parametro` = "Metal (Fe, Cu, Cr…). Escribir % si no aplica."
- `proyecto` = "Proyecto/mina. Escribir % si no aplica."
- `desde` = "Fecha inicial yyyy-MM-dd que calcula el tema desde el rango pedido. Vacío = sin límite."
- `tope` = "Máximo de filas. Escribir 200 (la entrada es obligatoria, no admite vacío)."

⚠ `compAbbr` lleva `COLLATE Latin1_General_CI_AI` para tolerar acentos y mayúsculas.

🔴 **(03/10) Componente pegado: `/historial 3195 MTLH` → «No encontré datos».** `compAbbr` es `MT LH` con
espacio y el `LIKE '%MTLH%'` no casa (el «6 meses» del caso de la presentación no tenía la culpa). Es el bug del
24/09 que se curó en `MD_equipo_comp` y nunca llegó aquí. Cura = **traducir en el flujo** (ley 3), un Redactar
**`comp_key`** antes del SQL (cada `‹compartimiento›` = la ficha de la entrada):
```
if(equals(trim(coalesce(‹compartimiento›,'')),'%'),'%',if(contains(toLower(replace(‹compartimiento›,' ','')),'hid'),'Hidr',if(or(startsWith(toLower(replace(‹compartimiento›,' ','')),'mt'),contains(toLower(replace(‹compartimiento›,' ','')),'tracc')),concat('MT',if(endsWith(toLower(replace(‹compartimiento›,' ','')),'rh'),'RH',if(endsWith(toLower(replace(‹compartimiento›,' ','')),'lh'),'LH',''))),if(or(startsWith(toLower(replace(‹compartimiento›,' ','')),'rd'),contains(toLower(replace(‹compartimiento›,' ','')),'rueda')),concat('RD',if(endsWith(toLower(replace(‹compartimiento›,' ','')),'rh'),'RH',if(endsWith(toLower(replace(‹compartimiento›,' ','')),'lh'),'LH',''))),if(contains(toLower(replace(‹compartimiento›,' ','')),'motor'),'Motor',replace(‹compartimiento›,' ',''))))))
```
y en el `Query` el filtro de componente pasa a comparar **sin espacios** contra esa salida:
`... AND REPLACE(compAbbr,'' '','''') COLLATE Latin1_General_CI_AI LIKE ''%', outputs('comp_key'), '%'' AND ...`
Casos: `MTLH` · `mt lh` · `MOTOR DE TRACCION LH` → `MTLH` · `hidráulico` · `hidr&#225;ulico` · `Sist. Hidr.` → `Hidr`
(casa con `Sist.Hidr.`) · `rueda rh` · `rdrh` → `RDRH` · `motor` → `Motor` (no casa con `MTLH`) · `%` → `%`.
⚠ `mt` y `tracc` van **antes** que `motor` (MOTOR DE TRACCION contiene «motor»).
🔴 **(03/10) Y el metal se compara SIN comodines** (`Parametro LIKE 'P'`, no `'%P%'`): con `%` alrededor, `/historialmetal … P` traía P, PQ y Pb mezclados, y `B` traía Pb (BLOQUE 196.1). Cuando no aplica llega `%`, que sigue valiendo «todos».

**Tal como queda en el editor** (`text_2` = la entrada `compartimiento`, `text_5` = `parametro`):
Redactar **`comp_key`** (nombre sin espacio):
```
if(equals(trim(coalesce(triggerBody()?['text_2'],'')),'%'),'%',if(contains(toLower(replace(coalesce(triggerBody()?['text_2'],''),' ','')),'hid'),'Hidr',if(or(startsWith(toLower(replace(coalesce(triggerBody()?['text_2'],''),' ','')),'mt'),contains(toLower(replace(coalesce(triggerBody()?['text_2'],''),' ','')),'tracc')),concat('MT',if(endsWith(toLower(replace(coalesce(triggerBody()?['text_2'],''),' ','')),'rh'),'RH',if(endsWith(toLower(replace(coalesce(triggerBody()?['text_2'],''),' ','')),'lh'),'LH',''))),if(or(startsWith(toLower(replace(coalesce(triggerBody()?['text_2'],''),' ','')),'rd'),contains(toLower(replace(coalesce(triggerBody()?['text_2'],''),' ','')),'rueda')),concat('RD',if(endsWith(toLower(replace(coalesce(triggerBody()?['text_2'],''),' ','')),'rh'),'RH',if(endsWith(toLower(replace(coalesce(triggerBody()?['text_2'],''),' ','')),'lh'),'LH',''))),if(contains(toLower(replace(coalesce(triggerBody()?['text_2'],''),' ','')),'motor'),'Motor',replace(coalesce(triggerBody()?['text_2'],''),' ',''))))))
```
Query:
```
concat('WITH f AS (SELECT Equipo, compAbbr, Parametro, Proyecto, rn, TituloMD, SufijoMD, ColsMD, Fila, COUNT(*) OVER () AS Tot FROM dbo.', triggerBody()?['text'], ' WITH (NOLOCK) WHERE Equipo LIKE ''%', outputs('eq'), '%'' AND REPLACE(compAbbr,'' '','''') COLLATE Latin1_General_CI_AI LIKE ''%', outputs('comp_key'), '%'' AND Parametro LIKE ''', triggerBody()?['text_5'], ''' AND Proyecto LIKE ''%', triggerBody()?['text_3'], '%'' AND FechaMuestreo >= ''', if(empty(triggerBody()?['text_4']),'1900-01-01',triggerBody()?['text_4']), '''), sel AS (SELECT TOP (', if(empty(triggerBody()?['text_6']),'200',triggerBody()?['text_6']), ') * FROM f ORDER BY rn) SELECT MAX(TituloMD) + CAST(COUNT(*) AS nvarchar(10)) + MAX(SufijoMD) + NCHAR(10) + NCHAR(10) + MAX(ColsMD) + NCHAR(10) + STRING_AGG(Fila, NCHAR(10)) WITHIN GROUP (ORDER BY rn) + CASE WHEN MAX(Tot) > COUNT(*) THEN NCHAR(10) + NCHAR(10) + N''_Mostrando las '' + CAST(COUNT(*) AS nvarchar(10)) + N'' más recientes de '' + CAST(MAX(Tot) AS nvarchar(10)) + N'' en el rango._'' ELSE N'''' END AS MD, CAST(NULL AS nvarchar(max)) AS Observados, CAST(NULL AS nvarchar(max)) AS Recomendaciones FROM sel')
```
⚑ El mismo Redactar sirve a `MD_equipo_comp` y `MD_metal`, que hoy toleran `mtlh` pero no `hidráulico` ni la
entidad HTML: ver el mapa 5.1b de [PENDIENTES](PENDIENTES.md).
⚠ Validado en SSMS antes de armarlo: **BLOQUE 72** (versión Tema 11) y **BLOQUE 74** (versión genérica).
