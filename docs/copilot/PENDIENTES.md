# Pendientes KomfIA — backlog único · foco: **ronda 23/09 (Carlos)**

> **Este es EL backlog.** Si algo está pendiente, está aquí. Actualizado 2026-09-24.
> Config canónica → [CONFIG_TEMAS](CONFIG_TEMAS.md) · [CONFIG_FLUJOS](CONFIG_FLUJOS.md) · [CONFIG_PROMPTS](CONFIG_PROMPTS.md) · [CONFIG_COMANDOS](CONFIG_COMANDOS.md) · [CONFIG_TIMEOUT](CONFIG_TIMEOUT.md)
> **Formato y límites (nuevo, 24/09)** → [FORMATO_POR_COMPONENTE](../arquitectura/FORMATO_POR_COMPONENTE.md) · [LIMITES_FALLBACK](../arquitectura/LIMITES_FALLBACK.md)
> Pruebas → [../pruebas/PRUEBAS_ALFA_COMANDOS.md](../pruebas/PRUEBAS_ALFA_COMANDOS.md) · Marchas → [../pruebas/MARCHA_ALFA_0918.md](../pruebas/MARCHA_ALFA_0918.md) · [../pruebas/MARCHA_ALFA_0923.md](../pruebas/MARCHA_ALFA_0923.md)

**Reglas permanentes:** (1) auditar TODO el sistema **antes** de cambiar · (2) editar un comando = editar su
módulo completo (descripción + tema + nodos + flujo + vista) · (3) nunca escribir SQL sin cruzar
`docs/arquitectura/ESQUEMA_BD.xlsx` · (4) SQL de prueba → `VALIDACION_SSMS.sql` en bloques numerados ·
(5) rendimiento: **aislar y medir antes de teorizar** · (6) tras desplegar DDL, correr el **BLOQUE 89**
(smoke test: un `CREATE VIEW` se guarda aunque su cuerpo sea inválido).

---

## ▶ EMPIEZA AQUÍ · estado al cierre del **25/09**

### Lo hecho el 24 y el 25/09 — todo desplegado, validado y probado en Teams

**A** ✅ los 27 renombres + el bug del componente pegado (`mtlh`) · **C** ✅ formato por componente en las 4
vistas, aditivos con límite invertido, filas completas del Excel · **D1** ✅ `/diagcompleto` con las 31 filas
· **D2** ✅ `/condicionmt` con las 23 de la hoja MT · **E** ✅ completo (E0·E1·E2·E3·E4 + prompt) ·
**F** ✅ **F4, F3 y F1 verificados** — Σvida con nº de muestras, contexto en las gráficas y el módulo de
tendencia fusionado de **91 a 65 líneas**.

✅ **Lo último del día abrió dos cosas más (E3 y E4) y se cerraron el mismo día**, las dos de la familia de
siempre: algo que dice una cosa y la tabla de al lado dice otra. **E3 era el de fondo** — había **dos
mecanismos de marcado** conviviendo y daban respuestas distintas para el mismo valor.

**Lo que se arregló por el camino, que no estaba en las 14 observaciones:**

| | |
|---|---|
| **3 fallos silenciosos** | el sistema decía «no encontré datos» y el dato existía: componente pegado · muestra sin componente (66) · **equipo sano** (206 de 306) |
| **E0** · el contador mentía | «0 de 2 observados» con una celda en rojo. Ahora cuenta **lo que la tabla pinta**; 119 de 1 284 componentes estaban así |
| **E2** · el correo | faltaba **entero** en `vw_UltimoAnalisisMD`; no era aleatorio |
| **Rendimiento** | `vw_DiagnosticoMD` 3 941 → **2 418 ms**. ⚠ Los scans bajaron de 5 a **4, no a 1** — queda margen, anotado en D |

⚠ **Y dos veces me comí mi propia regla:** una consulta de validación que leía 3 vistas MD enteras tardó
**12 minutos** sin devolver nada. Las validaciones **filtran por equipo**, siempre; y lo que es un literal de
la definición se mira en `sys.sql_modules`, no ejecutando la vista.

### 🏁 RONDA 23/09 CERRADA · **entregada a Carlos para pruebas** — 25/09

📧 **KomfIA notificado a Carlos el 25/09** para que vuelva a probar los módulos **Por equipo**.
⏳ **Estamos esperando su feedback.** Cuando llegue, entra como una ronda nueva — igual que la del 23/09.

⚠ **Y lo de «Por flota» no está revisado.** Esta ronda cubrió último análisis, condición MT, diagnóstico,
tendencia, gráfica, historial y acumulados. **Barrido, triage, conteo, rankings y tendencia incipiente
NO pasaron por la revisión con el área**; ese feedback vendrá después, y conviene tenerlo previsto porque
son los módulos más pesados.

### Estado al 25/09, cierre del día

Los **7 bloques** (A·B·C·D·E·F·G) desplegados, verificados en SSMS y probados en Teams.

| # | Qué queda | Estado |
|---|---|---|
| **1** | 📧 **Bloque B** — el universo de `Σvida`: el **6 785.39** no se reproduce con ningún criterio | ⛔ **BLOQUEADO**: falta la respuesta de **Carlos**. La pregunta está redactada abajo |
| **2** | 🟡 **Optimizar el resto de flujos** como se hizo con `/triage` | pendiente, **no urgente** — ver abajo |
| **3** | ❓ **3 de las 4 fórmulas** de componente (`comp1`, `comp2`, `comp3`) | sin confirmar; **nada roto**, pero el sistema depende de una sola red |
| **4** | ⏳ **G2 modo B** y **G3** | backlog que abrí yo, **no** era parte del pedido |
| **5** | ⏳ **C4** — el desajuste `730E-` vs `730E` (BLOQUE 103) | viene del bloque C, sin cerrar |

#### 🟡 2 · Optimizar el resto de flujos — lo que enseñó `/triage`

`vw_TriageMD` pasó de **113 780 ms a 860 ms** (132×) y, sobre todo, **dejó de variar**. Dos palancas, y las
dos se pueden repetir en otras vistas:

1. **El anti-patrón nº1:** un CTE referenciado 2 veces con un `JOIN` entre sus ramas. Se quita agregando
   **sobre la misma fila** (`OUTER APPLY`) en vez de en una rama paralela.
2. **Traducir en el flujo, no en el `WHERE`.** Una expresión que el optimizador no resuelve como constante
   impide empujar el filtro y la vista se construye entera.

**Candidatas, por lo medido esta ronda:**

| Vista | Coste hoy | Nota |
|---|---|---|
| `vw_TendenciaMD` (el módulo fusionado) | **~35 s** con el operador real | es el más usado |
| `vw_TendenciaMetalMD` | **~30 s** | |
| `vw_TendenciaGraficoMD` | ~21 s | |
| `vw_DiagnosticoMD` | ~2,4 s con `=` | los scans bajaron 5→4, **no a 1** |

⚠ **Antes de tocar ninguna, medir con el operador de producción** (`LIKE '%x%'`), no con `=`. Es la
lección que costo dos regresiones esta ronda.

---

### 📋 Tablero — estado al 25/09### 📋 Tablero — estado al 25/09, 12:00

| Paso | Qué | Estado |
|---|---|---|
| **1** | El prompt de análisis | ✅ **pegado y verificado** — contrasté el que pegaste contra el archivo: trae **las 7 reglas** últimas |
| **2** | Fórmula de componente en las 4 variables | 🟡 **1 de 4 confirmada** (`Topic.comp`, exacta). Faltan `comp1`, `comp2`, `comp3` |
| **3** | `MD_metal` sin la entrada `columna` | ✅ **ya estaba** (4 entradas en tu captura del flujo) |
| **4** | `/diagnostico` → alias del 04 + desactivar el 03 | ✅ **cerrado** |
| **5** | La familia tendencia (fusión) | ✅ hecho y probado |
| **6** | `/grafica` y gráficas de observados | ✅ hecho y probado |
| **7** | Los 3 archivos y la tarjeta | ✅ cerrado, tarjeta pegada |
| **8** | Las 9 pruebas | ✅ **9 de 9 en verde (25/09)** → 🏁 **BLOQUE F CERRADO** |
| **8.5** | `/triage` y `/incipiente` | ✅ **arreglados** — la traducción de vocabulario se movió a dos «Redactar» en el flujo |
| **9** | `/incipiente` — configuración | ✅ **ya estaba hecha** (el 9.6 corrió entero). Solo faltaba el vocabulario, que es el 8.5 |

✅ **`Topic.comp` confirmada el 25/09** — la pegaste y coincide **exacta** con la § canónica, con
`Topic.resto2` en los **dos** sitios. Cubre `/ultimo` `/tendencia` `/tendenciadet` `/historial`.

🟡 **Faltan las otras tres, y cada una cubre comandos distintos:**

| Variable | `<ORIGEN>` | Comandos que se quedan sin la capa 1 si falta |
|---|---|---|
| `Topic.comp3` | `Topic.resto3` | `/historialmetal` |
| `Topic.comp1` | `Topic.p1` | `/triage` (el componente va **primero**) |
| `Topic.comp2` | `Topic.p2` | `/grafica` `/metalflota` `/incipiente` |

⚠ **No se puede confirmar probando.** Tus pruebas con `mtlh` pasan, pero hay **dos** capas que resuelven el
componente pegado y con una basta: la fórmula del dispatcher (ésta) y el `REPLACE(compAbbr,' ','')` de los
flujos, que ya está y cubre los dos caminos. **Se verifica abriendo la variable, no escribiendo en Teams.**
⚠ **No es urgente** — nada está roto. Pero mientras falte, esos comandos dependen de **una sola red**.

⛔ **Dos reglas que ya nos mordieron, para tenerlas delante todo el rato:**
1. **Nunca se borra un nodo Condición** de «00 Comandos». Es una cadena de `if` anidados: cada nodo lleva
   en su `else` a **todos** los que vienen después. Si un comando cambia, se **re-apunta**.
2. Al agregar una **segunda condición** a un nodo, Copilot las junta con **«Cumple TODAS»** por defecto y
   entonces **no entra ninguna**. Hay que cambiarlo a **«Cumple CUALQUIERA»**.
   ✅ *En el PASO 5 no hizo falta: ya había dos nodos separados y bastó con re-apuntar uno.*

---

#### PASO 1 · El prompt de análisis — **5 minutos, y es lo que más se nota**

1. Copilot Studio → **Herramientas** → el Prompt **`Análisis de aceite`**.
2. Borrar TODAS las instrucciones y pegar el bloque de código de
   [`prompts/analisis_prompts.md`](prompts/analisis_prompts.md).
3. Donde dice `{tabla}`, insertar la **variable** `tabla` (no escribir el texto: usar el selector).
4. **Guardar** y **publicar**.

✅ **Es UN solo prompt para todos los módulos** — no hay que tocar tema por tema.
⚠ **Conocimientos: ninguno.** Con Knowledge alucina (inventó un «Cr crítico» inexistente).
⚠ Es un nodo **Solicitud / AI Builder**, NO «Crear respuestas generativas».

**Prueba inmediata:** `/ultimo 3160 rdrh` → el `Ca` debe describirse **bajo/agotado**, no «alto».

---

#### PASO 2 · Fórmula de componente en las **4** variables

En **«00 Comandos»**, en el nodo **Establecer valor de variable** de cada una. Es **la misma fórmula** en
las cuatro; lo único que cambia es `<ORIGEN>`:

```
With( { c: Lower(Substitute(Substitute(Trim(<ORIGEN>), " ", ""), "-", "")) },
  With( { lado: If( EndsWith(c,"lh"), " LH", If( EndsWith(c,"rh"), " RH", "" ) ) },
    If( IsBlank(c), "",
        StartsWith(c,"mt")   || IsMatch(c,".*tracc.*"), Trim("MT" & lado),
        StartsWith(c,"rd")   || IsMatch(c,".*rueda.*"), Trim("RD" & lado),
        IsMatch(c,".*hidr.*")|| c = "sh",               "Sist. Hidr.",
        IsMatch(c,"^motor(diesel|diésel)?$"),            "Motor",
        Trim(<ORIGEN>) ) ) )
```

| Variable | Reemplazar `<ORIGEN>` por | Comandos que la usan |
|---|---|---|
| `Topic.comp` | `Topic.resto2` | `/ultimo` `/tendencia` `/tendenciadet` `/historial` |
| `Topic.comp3` | `Topic.resto3` | `/historialmetal` |
| `Topic.comp2` | `Topic.p2` | `/grafica` `/metalflota` |

🔴 **CORRECCIÓN (25/09): `/triage` y `/incipiente` NO llevan la fórmula.** Yo los había metido en esta
tabla y **rompió los dos** (pruebas d y h del PASO 9). Filtran por **`CompTipo`** (`TRACCION`, `HIDRAULICO`)
y la fórmula normaliza a **`compAbbr`** (`MT`, `Sist. Hidr.`): son dos vocabularios distintos.

| Comando | `compartimiento` recibe |
|---|---|
| `/triage` | `Topic.p1` **crudo** — ⛔ nunca `Topic.comp1` con fórmula |
| `/incipiente` | `Topic.resto2` **crudo** — ⛔ nunca `Topic.comp2` con fórmula |

⚠ `CONFIG_FLUJOS.md` ya lo decía («`MD_triage` y `MD_incipiente` filtran por `CompTipo` con palabra
natural»). La § canónica de `CONFIG_COMANDOS.md` lo contradecía. **Corregido en los dos.**

⚠ **`<ORIGEN>` aparece DOS veces** en la fórmula (arriba en el `Trim` y abajo en el `else` final).
Reemplazar **las dos**.
⚠ **Los de un solo token también la necesitan:** un token no puede tener espacio, pero **sí** puede venir
pegado — `/grafica 3160 mtlh PQ` fallaba por lo mismo.
⚠ Cierra el `mtlh` por el camino de **comandos**. El de **lenguaje natural** ya quedó cubierto en los
flujos con `REPLACE(compAbbr,' ','')` — son **dos capas** para **dos caminos**, y hacen falta las dos.

**Prueba:** `/ultimo 3160 mtlh` y `/ultimo 3160 mt lh` → la misma respuesta. Y `/grafica 3160 mtlh Fe`.

---

#### ✅ PASO 3 · `MD_metal` sin la entrada `columna` — **ya estaba**

✅ **Confirmado en tu captura del flujo (25/09):** `MD_metal` tiene **4** entradas — `parametro`, `vista`,
`equipo`, `compartimiento` — y el `query_sql` ya usa **`MD` literal**. No hay nada que hacer.

⚠ **Por qué:** los 4 temas que lo usan pasan siempre `columna=MD`. Si alguna vez llega vacía, la query
queda `SELECT  AS MD` → error de sintaxis. Un parámetro que nunca varía no aporta y sí resta.

**Prueba:** `/tendenciametal 3160 Fe` y `/grafica 3160 mtlh Fe`.

---

#### PASO 4 · `/diagnostico` — ✅ **ya hecho el 24/09**, queda un remate

✅ **Verificado en Teams:** `/diagnostico 3160` devuelve el diagnóstico completo, y «diagnóstico del 3160»
y «cómo está el equipo 3160» también — el nodo está re-apuntado al **04** y su descripción ya absorbió los
disparadores del 03.

**Lo único que puede quedar:**
1. **Desactivar el Tema 03** (… → Desactivar). ⛔ No borrarlo.
2. Antes, comprobar que ningún «Ir a otro tema» apunte al 03.

⚠ Si el 03 ya está desactivado, este paso **no tiene nada** y se salta.

---

#### ✅ PASO 5 · La familia tendencia — **HECHO Y PROBADO (25/09)**

✅ **Buena noticia, y corrige lo que yo mismo había escrito:** en «00 Comandos» **ya existen dos nodos
separados**, `cmd = "/tendencia"` → Tema **05** y `cmd = "/tendenciadet"` → Tema **06**, y los dos pasan las
**mismas** entradas (`equipo` = `Topic.p1`, `compartimiento` = `Topic.comp`).

⇒ **No hay que agregar ninguna segunda condición, y por tanto la trampa del «Cumple CUALQUIERA» aquí NO
aplica.** Basta con **re-apuntar un desplegable**.

---

**5.1 · El dispatcher — un solo cambio**

En «00 Comandos», nodo `cmd es igual a "/tendencia"` → dentro, el nodo **Tema** → cambiar
`05 Tendencia (paso 1)` por **`06 Tendencia detalle`**.

- ⛔ **No se toca el nodo Condición**, no se borra nada.
- ✅ El nodo de `/tendenciadet` **se queda como está**: ya apunta al 06.
- ✅ Las entradas no cambian: los dos nodos ya pasan `equipo` y `compartimiento`.

**Resultado:** los dos comandos caen en el mismo tema. `/tendenciadet` queda como alias sin hacer nada más.

---

**5.2 · Tema 06 — renombrar y re-describir**

1. **Nombre del tema:** de `06 Tendencia detalle` a **`06 Tendencia`**. Es cosmético pero importa: el
   orquestador muestra el nombre y el 05 va a desaparecer.
2. **Descripción** (pestaña Detalles → Descripción). Pegar esta, **590** UTF-16, margen 434:

> TENDENCIA de UN componente de un equipo: cómo han evolucionado sus últimas muestras — contexto (horómetro, horas del componente, tipo de muestra, lubricante) y la matriz de TODOS los parámetros × fechas con sus límites. «tendencia del MT LH del CA3177», «cómo ha evolucionado el hidráulico del X», «las últimas muestras del \<componente>», «detalle de la tendencia del X», «la matriz de metales del \<componente>». Rellena equipo y compartimiento. ⛔ NO si nombran un metal (→ Tendencia de un metal / Gráfica), NO el último puntual (→ Último análisis), NO la bitácora completa (→ Historial).

3. ⛔ **No tocar sus nodos.** Ya tiene la Acción (`MD_equipo_comp` · `vista=vw_TendenciaMD` · `columna=MD`)
   y el nodo de análisis. La vista ya devuelve el contexto dentro del `MD`.

⚠ **Por qué la descripción es lo único que importa:** el orquestador rutea **solo** por descripción. Si el
06 no absorbe los disparadores del 05 («cómo ha evolucionado», «las últimas muestras del…»), esas frases
caen al fallback en cuanto desactives el 05.

---

**5.3 · Tema 05 — desactivar**

1. **Antes:** comprobar que ningún «Ir a otro tema» apunte al 05. (El del dispatcher ya lo moviste en 5.1.)
2. `…` → **Desactivar**. ⛔ **No borrarlo** — como el 23 y el 24.

⚠ **En este orden.** Si desactivas antes de re-apuntar, `/tendencia` se queda sin destino.

---

**5.4 · Tema NUEVO «Tendencia resumen estadístico»**

Es el que recibe la continuación. **Lo más rápido es duplicar el Tema 07 (Tendencia relevantes)**, que hace
exactamente lo mismo cambiando una sola cosa.

| Campo | Valor |
|---|---|
| Nombre | `Tendencia resumen estadístico` |
| Entradas | `equipo` (string) · `compartimiento` (string) |
| Acción | flujo **`MD_equipo_comp`** |
| `vista` | `vw_TendenciaMD` |
| `columna` | 🔴 **`MD_Estadistica`** ← lo único que cambia respecto del 07 |
| `equipo` | la variable `equipo` del tema |
| `compartimiento` | la variable `compartimiento` del tema |

**Nodos**, en orden:
1. **Acción** → el flujo.
2. **Mensaje** → `{md}`.
3. **Condición** → «`md` está en blanco» → Mensaje *«No encontré datos para esa consulta…»*.
4. **Finalizar tema actual**.

⛔ **SIN nodo de análisis.** Es una tabla determinista de promedios y σ; el prompt no añade nada y solo
gasta tiempo. (El 07 sí lo lleva porque habla de parámetros fuera de límite.)

**Descripción** — **462** UTF-16, margen 562:

> RESUMEN ESTADÍSTICO de la tendencia de UN componente: promedio, desviación σ, Σvida y nº de veces fuera de límite, parámetro por parámetro. Normalmente como CONTINUACIÓN tras ver la tendencia. «el resumen estadístico», «dame el promedio y la desviación», «las estadísticas de esa tendencia», «resumen estadístico del MT LH del X». Toma equipo y compartimiento del contexto. ⛔ NO la matriz por fechas (→ Tendencia) ni solo los observados (→ Tendencia relevantes).

✅ **No hace falta flujo nuevo ni vista nueva ni comando.** `MD_equipo_comp` ya tiene la entrada `columna`,
`MD_Estadistica` ya existe en `vw_TendenciaMD`, y es una continuación: se llega por lenguaje natural, como
el 07 y el 10.

---

**5.5 · Probar F antes de seguir**

| # | Escribir | Esperado |
|---|---|---|
| 1 | `/tendencia 3160 mtlh` | contexto **y** matriz en una sola respuesta, ~65 líneas |
| 2 | `/tendenciadet 3160 mtlh` | **exactamente lo mismo** |
| 3 | «el resumen estadístico» justo después | la tabla de Prom · σ · Σvida · Nº fuera |
| 4 | «cómo ha evolucionado el MT LH del 3160» | cae en el 06, **no** en el fallback |
| 5 | 🔴 **`/grafica 3160 mtlh Fe`** | responde, y con el subtítulo `*Mod. … · Lubric. … · SMR …*` |
| 6 | `/tendenciametal 3160 Fe` | responde (comparte el `else` con los de arriba) |

🔴 **La 5 y la 6 son las que revelan un error de estructura.** `/grafica` y `/tendenciametal` cuelgan del
`else` de los nodos que tocaste. Si algo se rompió, se nota ahí — no en `/tendencia`.

---

#### ✅ PASO 5.6 · REGRESIÓN — `/tendenciametal` se pasaba de 2 minutos · **arreglada (25/09)**

**El primer fallo de producción en mucho tiempo, y es mío.**

`/tendenciametal 3160 Fe` → `FlowActionTimedOut`. En Power Automate: *«Ejecutar una consulta SQL (V2):
the server did not respond within the timeout limit»*, a los **2 m 0 s** exactos — el tope del conector.

⚠ **`/grafica 3160 mtlh Fe` sí responde**, y usa **el mismo flujo** `MD_metal`. La diferencia está en la
vista: `/grafica` lee `vw_TendenciaGraficoMD` (**un** componente) y `/tendenciametal` lee
`vw_TendenciaMetalMD` (**los 6**). O sea: el camino común está bien; lo que se cayó es lo pesado.

**Qué se tocó hoy en ese camino.** `vw_TendenciaMetalMD` lee `vw_TendenciaElemento`, y a esa vista le
entraron tres cambios: **F4.1** (`NmAcum`), **F4.2** (`Proyecto` en la clave de `acc`) y **F3**
(`Modelo`/`Horometro`). De las tres, **la única que cambia la estructura del plan es F4.2**: el `LEFT JOIN`
pasó a comparar contra `g.Proyecto`, que es un **`MAX()` de un `GROUP BY`**.

🔴 **Y en SSMS no se vio** porque medí con `Equipo = 'CA3160'` y **el flujo usa `LIKE '%3160%'`**.
Es la misma leccción de siempre, en otra forma: **las validaciones tienen que filtrar como filtra
producción**, y eso incluye el **operador**, no solo el valor.

**Ya revertido en el DDL.** F4.2 era **prevención sin beneficio medido** — el BLOQUE 124 dio **0
colisiones** — y costó un timeout en producción. `NmAcum` y su formato (F4.1) **se quedan**: eso sí lo
pidió Carlos.

#### ✅ Cerrado — BLOQUE 128 (25/09), y destapó otra cosa

| Query | Tiempo |
|---|---|
| La **exacta del flujo** (`LIKE '%3160%'`) | **30 419 ms** — antes **>120 s** (timeout) |
| La misma con `=` | **6 152 ms** |
| Equivalencia | `Fe 3718.7 (27)` · `PQ 1462.6 (27)` · `Cr 19.1 (27)` · `Al 4.4 (27)` — **idénticos** |
| Tamaños | `TendenciaMD` 2 976 · `TendenciaMetalMD` 1 117 · `GraficoMD` 1 178 |

✅ **El flujo ya no se cae:** 30 s contra un tope de 120 s. Y revertir no movió ningún número.

🔴 **Pero salió algo que no era de hoy: el `LIKE '%x%'` cuesta 5 veces más que el `=`.** Los **4** flujos
comparan `Equipo LIKE '%<equipo>%'`, con comodín a **ambos** lados, y eso impide cualquier búsqueda por
índice. Está así desde siempre; la regresión de F4.2 solo lo hizo visible al sumarse.

⚠ **¿Sigue en riesgo el flujo?** No de caerse — hay 4× de margen. Pero `/tendenciametal` es ahora **el
módulo más lento**, y es el que acaba de caerse: conviene darle aire, no dejarlo al filo.

**La palanca está medida y es de una línea:** quitar el comodín **final** — `LIKE '%' + '<equipo>'`. Los
códigos son `CA` + 4 dígitos y el usuario escribe los 4 dígitos o el código entero; las dos formas siguen
casando.

#### ⛔ BLOQUE 129 — la palanca del `LIKE` se **descarta** (25/09)

| | |
|---|---|
| `LIKE '%3160%'` | 30 419 ms |
| **Anclado** `LIKE '%' + '3160'` | **26 600 ms** — solo **12 %** |
| `=` | 6 152 ms |

El salto de verdad (5×) es el `=`, **no el ancla**. Y el `=` no se puede usar:

🔴 **Los códigos de equipo no son uniformes.** La consulta (3) devolvió **20 equipos que no siguen
`XX####`**: `3118`, `5103`, `6112`, `6113`… — números pelados, sin prefijo. Eso tumba también la otra idea
(normalizar el código a `CA####` en el dispatcher para comparar con `=`): rompería esos 20.

✅ **Decisión: no se toca ningún flujo.** Un 12 % no justifica editar 4 flujos con códigos heterogéneos.
Si algún día hay que ganar tiempo de verdad, la palanca es **la vista** (una sola pasada), no el `WHERE`.

#### 🔴 Y un dato que no buscaba, pero es el que importa

La consulta (4) midió `vw_TendenciaMD` **como lo llama el flujo**: **35 838 ms**, contra los **5 764 ms** que
el BLOQUE 127 midió con `=`.

⇒ **El módulo de tendencia fusionado cuesta ~35 s en producción, no 5,8 s.** Entra en el tope de 120 s y
en Teams responde — lo probaste — pero el número real es ese, y conviene tenerlo escrito.

⚠ **Es la misma lección del BLOQUE 128, otra vez:** medir con el **operador** de producción, no solo con el
valor. Todos los tiempos que fui dando en esta ronda se midieron con `=`; los de producción son mayores.

---

#### ✅ PASO 6 · `/grafica` y las gráficas de observados — **HECHO Y PROBADO (25/09)**

🔴 **No hay nada que tocar en Copilot Studio.** Lo digo explícito porque es raro y da desconfianza:
`vw_TendenciaGraficoMD` y `vw_TendenciaGraficoObsMD` cambiaron **solo su columna `MD`**. Los temas **09** y
**10** siguen con los mismos nodos, el mismo flujo (`MD_metal` / `MD_equipo_comp`) y las mismas entradas.

**Lo único que hay que hacer:**

1. **Desplegar `DDL_vistas.sql`** (si no lo hiciste ya al correr el BLOQUE 130).
2. **Probar en Teams** — ver las pruebas 4 y 5 del PASO 8.

**Lo opcional, y por qué lo dejo como opcional:** las descripciones de los temas 09 y 10 dicen «la curva» /
«gráfica(s)», y ahora además traen el cuadro de tendencia arriba. Se pueden afinar, pero ⚠ **con cuidado**:
si la descripción del 09 empieza a hablar de «tendencia», empieza a competir con el Tema 06 por frases como
«la tendencia del MT LH». Hoy el 09 se distingue porque **exige un metal**. Si lo tocas, mantén eso al
frente y no agregues la palabra «tendencia» al principio.

⚠ **Rendimiento, para que lo sepas antes de que alguien pregunte:** `/grafica` cuesta **~21 s** y las
gráficas de observados **~11 s** (medido con el operador real del flujo, BLOQUE 130). Está lejos de los
120 s del conector, pero no es instantáneo. La tabla de arriba no es gratis.

---

#### ✅ PASO 7 · Los 3 archivos y la tarjeta — **CERRADO (25/09)**, tarjeta pegada

✅ **Hecho el 25/09** (los tres sitios, que es la regla permanente):

| Archivo | Qué quedó |
|---|---|
| `CONFIG_COMANDOS.md` | mapa, tabla de despacho, tabla de temas y línea de ayuda — `/diagnostico` y `/tendenciadet` como **alias**, el 05 marcado como desactivado |
| `tools/gen_comandos_card.py` | `/diagcompleto` y `/tendencia` como **principales**; los dos alias salen de las tablas |
| `comandos_card.json` | **regenerado** — de 22 filas a **20** |

**Qué cambió en la tarjeta, para que sepas qué vas a ver:**
- `/diagnostico` y `/tendenciadet` **ya no ocupan fila**: son el mismo módulo y ocupaban espacio útil.
- En su lugar, una línea al pie: *«También funcionan **/diagnostico** (= /diagcompleto) y **/tendenciadet**
  (= /tendencia).»*
- Descripciones al día: `/diagcompleto` → «Diagnóstico del equipo: todos sus componentes» · `/tendencia` →
  «Tendencia de un componente: contexto + parámetros × fechas».

✅ **Dos filas menos importan:** las Adaptive Cards **no tienen scroll**.
✅ **Tarjeta pegada el 25/09.** Queda comprobarla con `/comandos` en la prueba 9 del PASO 8.

⚠ **Para la próxima vez que se toque:** va en un nodo **«Enviar un mensaje»**, no en el de pregunta ·
placeholders `‹ ›` **nunca** `< >` (la Adaptive Card se come lo que parece etiqueta HTML) · y las cards
**no tienen scroll**: si crece, se **pagina**.

---

#### ✅ PASO 8 · Probar — **9 de 9 en verde (25/09)** · 🏁 **F CERRADO**

| # | Escribir | Esperado | Qué confirma |
|---|---|---|---|
| 1 | `/tendencia 3160 mtlh` | cuadro de contexto **+** matriz, ~65 líneas | la fusión (PASO 5) |
| 2 | `/tendenciadet 3160 mtlh` | **exactamente lo mismo** | el alias |
| 3 | «el resumen estadístico» justo después | tabla Prom · σ · Σvida · Nº fuera | el tema nuevo con `MD_Estadistica` |
| 4 | `/grafica 3160 mtlh Fe` | **el cuadro de tendencia arriba**, luego «Gráfica de Fe» y la curva | el PASO 6 |
| 5 | «la gráfica» tras una tendencia | gráficas de los observados, **con el cuadro arriba** | el tema 10 |
| 6 | 🔴 `/tendenciametal 3160 Fe` | responde (no `FlowActionTimedOut`) | **la regresión de hoy sigue arreglada** |
| 7 | «cómo ha evolucionado el MT LH del 3160» | cae en el 06, **no** en el fallback | que el 06 absorbió los disparadores del 05 |
| 8 | Un componente sin observados, p. ej. `/grafica 3160 motor Fe` | responde con el cuadro y explica | que no hay fallo silencioso |
| 9 | `/comandos` | la tarjeta con los nombres nuevos | el PASO 7 |

✅ **Las 9 pasaron el 25/09**, incluida la **6** (`/tendenciametal`) — la regresión sigue arreglada — y la
**9**, con la tarjeta nueva mostrando `/diagcompleto` y `/tendencia` y sin las filas de los alias.

🏁 **BLOQUE F CERRADO**, SQL y Copilot.

#### ⚠ Dos desviaciones respecto de lo que yo había escrito — las dos para mejor

1. **El tema del resumen estadístico SÍ lleva análisis.** Yo había dicho «sin análisis, es una tabla de
   promedios». Con él sale algo que la tabla sola no dice: *«Zn es el parámetro más volátil: promedio 44.6
   con σ = 77.6 (dispersión enorme frente al pico de 200.6)»* y *«PQ tendencia ascendente estable…
   generación constante de partículas ferrosas finas»*. **Me equivocaba: la σ y el nº de muestras sí dan
   para leer.** Queda con análisis.
2. **`/grafica` también responde con análisis** (*«el Fe del Motor está completamente controlado…»*), y
   ayuda. Tampoco se toca.

⚠ `CONFIG_TEMAS.md` decía «SIN análisis» para el tema nuevo — **corregido** para que el documento diga lo
que el sistema hace.

---

#### ✅ PASO 8.5 · `/triage` y `/incipiente` — **ARREGLADOS y probados en Teams (25/09)**

🔴 **Confirmado con tu prueba:** `/incipiente Antapaccay hidraulico` **sin tilde** también falla ⇒ no es
el acento, es la fórmula convirtiendo `hidraulico` en `Sist. Hidr.`.

➡ **El arreglo completo, con el SQL listo para pegar, está en la § FIX CANÓNICO de
[`CONFIG_FLUJOS.md`](CONFIG_FLUJOS.md).** En resumen:

- ⛔ **No** se arregla en el dispatcher. Se arregla **en los dos flujos**, con un `CROSS APPLY` + `CASE`
  que traduce lo que llegue (`hidráulico`, `Sist. Hidr.`, `SH`, `MT LH`, `tracción`…) a `CompTipo`.
- ✅ Así queda cubierto **el camino de lenguaje natural también**, que no pasa por el dispatcher — y ese
  es el motivo de fondo por el que el parche mínimo no basta.
- ✅ Y **no hay que tocar `Topic.comp1` ni `Topic.comp2`**: da igual lo que manden.

**Probar después:** `/triage tracción Antapaccay` · `/incipiente Antapaccay hidraulico` ·
`/incipiente Antapaccay hidráulico` · `/incipiente Antapaccay mando final` · y en lenguaje natural
«qué hidráulicos se están disparando en Antapaccay».

---

#### PASO 9 · `/incipiente` — ⛔ **no es de F**, viene de P3

⚠ **Antes de hacer nada: comprobar si ya está.** En `PENDIENTES` hay dos afirmaciones que se contradicen —
la sección de P3 dice «COPILOT STUDIO ✅ hecho y probado (23/09)» y dos líneas más abajo «lo que falta es
probar en el chat». No se puede resolver desde el repo. **Míralo en Copilot Studio:**

| Comprobar | Dónde | Si ya está |
|---|---|---|
| ¿Existe el flujo **`MD_incipiente`**? | Power Automate | salta 9.1 |
| ¿El **Tema 20** tiene la entrada `compartimiento`? | Tema 20 → Detalles | salta 9.2 |
| ¿Su Acción apunta a `MD_incipiente`? | Tema 20 → nodo Acción | salta 9.3 |
| ¿Su descripción habla de **cualquier componente**, no solo de MT? | Tema 20 → Descripción | salta 9.4 |

**El atajo de un minuto:** escribe **`/incipiente Antapaccay hidráulico`**.
- Si responde con el título **«Sistemas Hidráulicos»** → está todo hecho, ve directo a **9.6**.
- Si responde hablando de **Motores de Tracción** → falta al menos la descripción y el mapeo.
- Si no responde o pide datos → falta el flujo o la entrada.

---

**9.1 · Crear el flujo `MD_incipiente`** (Power Automate)

Clónalo de **`MD_triage`**, que es la misma forma, y cámbiale **dos** cosas: quítale la entrada `modelo` y
reemplaza el `concat`. **Entradas: `proyecto`, `compartimiento`** (texto, las dos).

```
concat('SELECT MD, Observados, Recomendaciones FROM dbo.vw_TendenciaIncipienteMD WHERE Proyecto LIKE ''%', ‹proyecto›, '%'' AND CompTipo COLLATE Latin1_General_CI_AI LIKE ''%', ‹compartimiento›, '%''')
```

- ⛔ **Sin `modelo`:** la vista expone `Modelo='(todos)'` fijo; pedir un modelo real daría **0 filas**.
- ⚠ **El `COLLATE Latin1_General_CI_AI` no es decorativo:** es lo que hace que «tracción» (con tilde) case
  con `TRACCION` (sin tilde) en la columna. Sin eso, el acento rompe el `LIKE`.
- **Salidas:** las de siempre — `md`, `observados`, `recomendaciones`.
- Descripciones de entrada, listas para pegar:
  - `proyecto` — "Proyecto/mina (ej. Antapaccay)."
  - `compartimiento` — "Componente en palabra base: tracción / rueda / motor / hidráulico / mando / transmisión. Acepta lenguaje natural; default tracción."

**9.2 · Tema 20: agregar la entrada `compartimiento` y GUARDAR**

- Entrada nueva `compartimiento` (texto), con la descripción de arriba.
- 🔴 **Guardar el tema AQUÍ, antes de seguir.** Hasta que no se guarda, el resto del agente **no ve** la
  entrada nueva, y el paso 9.5 falla con un error que no dice eso.
- ⛔ **No** la pongas como pregunta al usuario: tiene default y se fija en la Acción.

**9.3 · Tema 20: apuntar la Acción al flujo nuevo**

| Entrada del flujo | Valor |
|---|---|
| `proyecto` | `Topic.proyecto` |
| `compartimiento` | `If(IsBlank(Topic.compartimiento), "tracción", Topic.compartimiento)` |

⛔ **El resto de nodos no se toca.** El tema ya es **CON análisis**: Acción → Mensaje `{md}` → Prompt
`Análisis de aceite` → Mensaje `{analisis.text}` → Condición «`md` está en blanco» → mensaje sin-datos →
Finalizar.

**9.4 · Tema 20: pegar la descripción nueva** (**712** UTF-16, margen 312)

La actual dice «Motores de Tracción» fijo y **ya no es cierto** desde P3.

> Equipos de una flota cuyo componente se DISPARÓ respecto a su propio promedio histórico (subida ≥40% sobre la media de sus 6 muestras previas) SIN superar todavía el límite — alerta TEMPRANA, aún no observados. Cualquier componente: tracción, rueda, motor, hidráulico… «tendencia incipiente en Antapaccay», «qué MT están subiendo sin pasar el límite», «qué ruedas se están disparando antes de la alarma», «desgaste incipiente de \<mina>», «cuáles han variado de su comportamiento promedio por ahora sin sobrepasar los límites». Rellena proyecto y compartimiento (default tracción). Muestra el EQUIPO + parámetros (prom→últ, +%). ⛔ NO los ya fuera de límite (→ Triage / Barrido) ni un equipo puntual (→ Tendencia).

**9.5 · Dispatcher «00 Comandos»: el 2º parámetro**

1. 🔴 Abre el nodo «Ir a otro tema» de la rama `/incipiente` y **re-selecciona el Tema 20** — cámbialo a otro
   tema y vuelve. Así toma el esquema **con la entrada nueva**. Si no lo haces, avisa
   *«No se encuentra el enlace Input…»*, que no dice nada sobre la causa real.
2. Mapea:
   - `proyecto` = `If(Topic.p1="","Antapaccay",Topic.p1)`
   - `compartimiento` = `If(Topic.resto2="","tracción",Topic.resto2)`
   ⚠ **`resto2`, no `p2`**: así «mando final» o «caja de giro» (dos palabras) llegan **completas**, igual que
   en `/ultimo` y `/tendencia`.

**9.6 · Probar** — los números salen del **BLOQUE 85**, ya corrido: si el chat muestra otra cosa, el
problema está en el flujo o el mapeo, **no en el SQL**.

| # | Escribir | Esperado |
|---|---|---|
| a | `/incipiente Antapaccay` | **6 de 54** evaluados · 18 sin límites |
| b | `/incipiente` (sin nada) | igual que (a) — default Antapaccay + tracción |
| c | `/incipiente Antamina` | **45 de 132** · «Mostrando 25 de 45» |
| d | `/incipiente Antapaccay hidráulico` | **9 de 36** · título «Sistemas Hidráulicos» |
| e | `/incipiente Antapaccay mando final` | 🔴 que `resto2` pase **las dos palabras**, no solo «mando» |
| f | `/incipiente Cuajone` | «sin límites cargados» + el aviso. ⛔ **No** «ninguno observado» |
| g | «qué ruedas se están disparando en Antamina» | rutea al Tema 20 por lenguaje natural |
| h | `/triage tracción Antapaccay` | **no-regresión**: el Tema 19 sigue igual (comparten forma de flujo) |

🔴 **La (f) es la que más importa.** «Sin límites cargados» y «ninguno observado» **no son lo mismo**, y
confundirlos es el patrón de fallo silencioso que perseguimos toda la ronda.

#### 🟡 Resultados del 9.6 (25/09) — **6 de 8 bien, y dos hallazgos que importan**

| # | Resultado |
|---|---|
| a | **5 de 54** · 18 sin límites — esperaba 6; los datos se movieron desde el 22/09 |
| b | ✅ igual que (a): el **default** funciona |
| c | **44 de 132** · «Mostrando 25 de 44» — esperaba 45, misma deriva |
| d | 🔴 **FALLA** — `hidráulico` no devuelve nada |
| e | ✅ **1 de 18 · Mandos Finales** — `resto2` pasa **las dos palabras** |
| f | ✅ Cuajone: «sin límites cargados… ⚠ esto **no** significa que estén sanos» |
| g | ✅ «qué ruedas se están disparando en Antamina» → **23 de 128 · Ruedas Delanteras** |
| h | 🔴 **FALLA** — `/triage tracción Antapaccay` → «No encontré datos» |

### 🔴 (d) y (h) son **el mismo bug**, y lo causó el PASO 2

**Dos convenciones distintas conviven en el sistema, y la fórmula de componente solo sirve para una:**

| Convención | Valores | Quién la usa |
|---|---|---|
| **`compAbbr`** | `MT LH` · `RD RH` · `Sist. Hidr.` · `Motor` | `/ultimo` `/tendencia` `/historial` `/grafica` |
| **`CompTipo`** | `TRACCION` · `RUEDA` · `HIDRAULICO` · `MANDO` | 🔴 **`/triage` y `/incipiente`** |

La **fórmula normaliza a `compAbbr`**. Si se aplica a `/triage` o `/incipiente`:
- `tracción` → **`MT`** → `CompTipo LIKE '%MT%'` → **0 filas** → eso es la (h).
- `hidráulico` → **`Sist. Hidr.`** → `CompTipo LIKE '%Sist. Hidr.%'` → **0 filas** → eso es la (d).
- `rueda` → `RD`… pero (g) funcionó porque entró por **lenguaje natural**, donde la fórmula **no corre**.
- `mando final` → cae en el `else`, sale **tal cual**, y por eso (e) funcionó.

✅ **Todo encaja.** Y `CONFIG_FLUJOS.md` ya lo decía: *«⛔ `MD_triage` y `MD_incipiente` no lo necesitan:
filtran por `CompTipo` con palabra natural»*. **Mi tabla del PASO 2 lo contradecía** — metí
`/triage` y `/incipiente` en la lista de la fórmula. El error es mío.

#### El arreglo, en «00 Comandos»

⛔ **`Topic.comp1` y `Topic.comp2` NO deben llevar la fórmula** — o, si la llevan porque otros comandos la
necesitan, **`/triage` y `/incipiente` no deben leer esas variables**:

| Comando | Qué debe recibir `compartimiento` |
|---|---|
| `/triage` | `Topic.p1` **crudo** (o `resto`), no `Topic.comp1` |
| `/incipiente` | `Topic.resto2` **crudo**, no `Topic.comp2` |
| `/grafica` · `/metalflota` | `Topic.comp2` **con** fórmula — esos sí filtran por `compAbbr` |

🔴 **`/grafica` y `/incipiente` comparten `Topic.comp2` y necesitan cosas OPUESTAS.** Si comparten
variable, hay que **separarlas**: deja `Topic.comp2` con fórmula para `/grafica` y `/metalflota`, y en la
rama de `/incipiente` mapea `compartimiento` directo desde `Topic.resto2`.

**La prueba que lo confirma en 10 segundos:** `/incipiente Antapaccay hidraulico` (**sin tilde**).
- Sigue fallando → es la fórmula (`Sist. Hidr.`), como digo aquí.
- Funciona → entonces es la **tilde** y el problema es el `COLLATE` del flujo, no la fórmula.

### ⚠ Y un tercer defecto, más chico pero de la familia de siempre

En la (f), el módulo dice correctamente *«sin límites cargados… esto **no** significa que estén sanos»* y
**justo debajo** el análisis añade *«Todos los parámetros están dentro de límite; sin observaciones»*.
**Se contradicen en la misma respuesta.**

✅ **Arreglado en el prompt:** regla nueva — si el bloque no trae tabla o dice que no se puede evaluar, el
análisis **no** puede decir que todo está dentro de límite; responde en una línea que no se pudo evaluar y
por qué. **Hay que re-pegar el prompt.**

### 📧 Lo que hay que preguntarle al Carlos (2 cosas, van juntas)
1. **Σvida:** el 6 785.39 no se reproduce con ningún criterio — ver bloque B, la pregunta está redactada.
2. **Aviso antes de publicar:** dos saltos de número que no son bugs pero lo parecen — al invertir los
   aditivos aparecen **181 equipos** con el aditivo agotado donde había **0 alertas**, y al contar por
   celda marcada (**E0**) los equipos con algún componente observado pasan de **100 a 111** de 306.

---

# 🔥 RONDA 23/09 — feedback dCarlos · **foco actual**

**Contexto:** primera prueba **directa por gerencia**, no por el dev. El ingeniero Carlos recibió la cuenta
de Confiabilidad y probó KomfIA en Teams. Salieron 14 observaciones. Plazo de trabajo: esta semana.

> **Dónde se arregla casi todo:** en las **VISTAS**. Desde Tier 2 el tema imprime el `MD` verbatim, así que
> renombrar una columna, reordenar parámetros o cortar filas **es SQL, no Copilot**. Solo 4 de los 14 ítems
> tocan Copilot Studio.

> **⚠ Nota operativa (no es un ítem):** el chat de Teams se abre **desde Copilot Studio**, y la cuenta de
> Confiabilidad ahora es compartida. El error de `/ultimo` que apareció en la ronda **no era un bug**: era
> haber lanzado el chat desde una cuenta personal. Queda dicho para no volver a diagnosticarlo como falla.

## Mapa: las 14 observaciones → dónde se arreglan

| # | Observación | Se arregla en | Bloque |
|---|---|---|---|
| 1 | `SMR` en vez de `Horómetro`/`Hor.` | vista (texto) | **A** |
| 2 | `CM` → `Tipo de muestra` / `T. muestra` | vista (texto) | **A** |
| 3 | `N° fuera` → `N° fuera de límite` | vista (texto) | **A** |
| 4 | `/acumulados`: cortar el texto tras «27 camiones» | vista (texto) | **A** |
| 5 | Σvida: sale 3 718, debe ser **6 785.39**, y solo para metales de desgaste | vista (**dato**) | **B** |
| 6 | `Si` como contaminante (y `Al`) | vista (formato) | **C** |
| 7 | `Ca` y `Zn` como aditivo | vista (formato **+ sentido del límite**) | **C** |
| 8 | Orden de parámetros según componente | vista (formato) | **C** |
| 9 | Parámetros con nulos → cortar la fila | vista (formato) | **C** |
| 10 | Completar límites desde el Excel | vista (**datos nuevos**) | **C** |
| 11 | `/diagcompleto` con formato nuevo entero + retirar `/diagnostico` (→ **alias**, sin borrar nada) | vista + tema | **D** |
| 12 | `/condicion` → `/condicionmt`, mismo formato que `/ultimo` | vista + tema + comando | **D** |
| 13 | Análisis centrado en lo observado | **prompt** | **E** |
| 14 | En algunas recomendaciones no sale el correo | vista de recomendaciones | **E** |
| — | Encabezado de `/tendencia` en `/grafica` | **va con P1** | **F** |
| — | `/acumulados` sin nada se confunde con `/rankingacum` | ruteo (descripciones) | **G** |

## Orden de ataque
No es orden de importancia (todas importan), es orden de **dependencia y de costo**:

**A** (texto suelto, 1 pasada) → **B** (un dato mal, ya visto por gerencia) → **C** (el bloque grande: formato
por componente + límites) → **D** (los dos módulos que heredan el formato de C) → **E** (prompt y
recomendaciones, independientes) → **F** (P1) → **G** (ruteo, al final, cuando ya no cambien los módulos).

⚠ **C antes que D** no es negociable: `/diagcompleto` y `/condicionmt` **heredan** el formato que define C.
Hacer D primero significa hacerlo dos veces.

---

## ✅ 🅰 Bloque A — CERRADO (24/09) · desplegado y probado en Teams

**27 sustituciones**, ninguna toca datos ni lógica: es texto literal dentro de las vistas MD.

| | Cambio | Sustituciones | Vistas afectadas |
|---|---|---|---|
| **A1** | `Horóm.` / `Horómetro` / `· Hor.` → **`SMR`** | 12 | las 8 de historial, `vw_ObservadosResumenMD`, `vw_TendenciaP1MD`, `vw_UltimoMetalFlotaMD`, `vw_UltimoAnalisisMD` |
| **A2** | `CM` → **`T. muestra`** | 13 | historial, barrido detalle, resumen, `vw_CondicionCompMD`, `vw_UltimoAnalisisMD`, `vw_UltimoMetalFlotaMD` |
| **A3** | `Nº fuera` → **`Nº fuera de límite`** | 2 | `vw_TendenciaMD`, `vw_TendenciaMetalMD` |
| **A4** | `/acumulados`: el título corta en «N equipos» | 1 | `vw_AcumuladosFlotaMD` |

### Las dos trampas que había (y por qué no hice un reemplazo global)
1. **`Hor.Comp.` NO es el horómetro.** Son las **horas del componente**: aparece 6 veces y **no se tocó**.
   Un `replace` de «Hor.» se las hubiera llevado por delante.
2. **La fórmula del ranking se queda en `/rankinggraf`.** Ahí no es relleno: es la **leyenda de la gráfica**.
   Solo se quitó de `/acumulados` y `/rankingacum`, que es donde gerencia la señaló como irrelevante.
   ⚠ El subtítulo de **`vw_AcumuladosEquipoMD`** (Serie · horas · ranking · estado) **se mantuvo**: no tiene
   ponderaciones, es contexto del equipo. Si también sobra, decirlo y sale en una línea.

### Paso a paso
1. **Desplegar** `DDL_vistas.sql` (las vistas del bloque A; o el archivo entero, es `CREATE OR ALTER`).
2. **BLOQUE 92 · (1)** — smoke test. Debe dar **0 filas**. Es el ritual tras cada despliegue: un `CREATE VIEW`
   se guarda aunque su cuerpo sea inválido.
3. **BLOQUE 92 · (2)** — el chequeo que importa: barre 8 vistas y avisa si quedó algún rótulo viejo.
   Esperado: la columna `Restos` **vacía** en todas.
4. **BLOQUE 92 · (3)** — la cabecera de `/acumulados`: debe cortar en «27 equipos» y dejar **línea en blanco**
   antes de la tabla. ⛔ Si se pierde esa línea, Teams vuelca la tabla como texto (el bug P0 de la ronda pasada).
5. **BLOQUE 92 · (4)** — no-regresión: en `/rankinggraf` la fórmula **sigue**.
6. En Teams: `/ultimo 3160 mtlh` · `/tendenciadet 3160 mtlh` · `/barridodet Antapaccay` · `/rankingacum Antapaccay`.
   Mirar que diga **SMR** y **T. muestra**, y que `Hor.Comp.` siga intacto donde corresponde.

> Los renombres en sí **no tocan Copilot Studio**: el `MD` se imprime verbatim. Lo que sí lo toca es el
> **A5**, que apareció probando este bloque.

### A5 · 🔴 Bug del componente PEGADO (`mtlh`) — encontrado el 24/09 probando A
`/ultimo 3160 mt lh` funciona y **`/ultimo 3160 mtlh` responde «No encontré datos para esa consulta»**, que
suena a «ese equipo no tiene muestras». **Bug silencioso**: no falla, miente.

**Causa:** `compAbbr` es `MT LH` **con espacio**. La normalización del dispatcher reconocía «MT LH» y
«tracción LH» pero **no la forma pegada**, así que `mtlh` viajaba tal cual → `LIKE '%mtlh%'` → 0 filas.

**Se arregla en DOS capas, porque hay dos caminos de entrada:**

| Capa | Dónde | Cubre | Estado |
|---|---|---|---|
| 1 · Normalización del dispatcher | «00 Comandos» (Power Fx) | el camino **comando** | ⏳ pegar fórmula |
| 2 · Comparación sin espacios | flujos `MD_equipo_comp` y `MD_metal` | el camino **lenguaje natural** | ⏳ editar 2 flujos |

⚠ **La capa 2 no es redundante:** por lenguaje natural («el último del 3160 mtlh») el tema llena
`compartimiento` directo y la fórmula del dispatcher **no corre**. Con una sola capa el bug sobrevive por el
otro camino.

**Qué hacer:**
1. **Capa 1** — [CONFIG_COMANDOS §Fórmula canónica](CONFIG_COMANDOS.md): colapsa espacios y guiones **antes**
   de decidir, así `mtlh`, `MT-LH`, `mt  lh` y `traccion lh` terminan todos en `MT LH`.
   ⚠ Aplicarla a las **4** variables, no solo a las de cola: `Topic.comp` (resto2), `Topic.comp3` (resto3),
   y las nuevas `Topic.comp1` (`/triage`, componente primero) y `Topic.comp2` (`/grafica`, `/metalflota`,
   `/incipiente`, componente en medio). Un token suelto no tiene espacios, pero **sí puede venir pegado**:
   `/grafica 3160 mtlh PQ` fallaba por lo mismo.
2. **Capa 2** — [CONFIG_FLUJOS](CONFIG_FLUJOS.md): en `MD_equipo_comp` y `MD_metal`, comparar
   `REPLACE(compAbbr,' ','')` contra `REPLACE(‹compartimiento›,' ','')`.
   ⛔ `MD_triage` y `MD_incipiente` **no** lo necesitan: filtran por `CompTipo` con palabra natural.
3. **BLOQUE 93** en SSMS valida la capa 2 y, de paso, que la tolerancia **no afloje de más** (`mt` solo debe
   seguir trayendo LH y RH; los componentes no abreviados deben seguir casando por su nombre completo).
4. En Teams: `/ultimo 3160 mtlh` · `/ultimo 3160 mt lh` · `/tendenciadet 3160 mtlh` · `/grafica 3160 mtlh PQ` ·
   y en lenguaje natural «el último análisis del 3160 mtlh».

**✅ Resultados (24/09):**
- **92(2):** 22 filas, columna `Restos` **vacía en todas**. `SMR` y `T. muestra` donde corresponde.
- **93(1):** `mt lh` = 1 y `mtlh` = **0** — la asimetría confirmada: **ese** era el bug.
- **93(2):** `mt lh` = 1, `mtlh` = **1**, `MT-LH` = 0 — exactamente lo previsto: el guión no lo quita el SQL,
  lo normaliza el dispatcher. **Cada capa cubre lo suyo.**
- **93(3):** `mt` sin lado = **2** y `mando final lh` = **12** → la tolerancia **no aflojó de más**.
- **Teams:** `/ultimo 3160 mtlh` · `/tendenciadet 3160 mtlh` · `/grafica 3160 mtlh PQ` · y en lenguaje natural
  «el último análisis del 3160 mtlh» → **todas responden**. `/tendenciadet 3161 mt rh` (separado) sin regresión.

**Corrección de paso:** `MD_metal` **no lleva entrada `columna`** — mi tabla decía que sí, el flujo real siempre
tuvo 4. Los 4 temas que lo usan pasaban el mismo valor y las 4 vistas exponen una columna llamada `MD`, así que
va **literal** en el `concat`. Un parámetro que nunca varía solo agrega un modo de fallo (`SELECT  AS MD`).
Corregido en `CONFIG_FLUJOS` y en las 4 filas de `CONFIG_TEMAS`.

## ✅ 🅱 Bloque B — CERRADO hasta donde se podía · ⚠ **bloqueado por 1 pregunta**

> # 📧 LA PREGUNTA PARA EL TRIÓLOGO
> **«Para el Fe del MT LH del CA3160 nos da 3 718.70 sumando los últimos 12 meses sin muestras dializadas,
> y 18 372.32 sumando todo el histórico desde 2020. Probamos todas las ventanas (12, 18, 24, 30, 36, 48 y 60
> meses), todos los tipos de muestra (ADI, M, DDI, C), los 18 parámetros y todos los equipos de la base, y
> 6 785.39 no aparece. ¿Con qué herramienta y qué criterio lo calculaste — desde cuándo acumulas y qué
> muestras incluyes?»**
>
> ✅ Hecho: Σvida ya sale **solo en metales de desgaste** (BLOQUE 99 verificado).
> ⏳ Falta solo: **qué universo sumar**. Cuando llegue la respuesta, el cambio es de **una línea** — está
> medido que quitar la ventana solo para el acumulado cuesta **933 ms**.

**Lo que dijo gerencia:** para Fe en **CA3160 MT LH** la tabla muestra **3 718.7** y debería decir **6 785.39**.
Además, Σvida **solo debe aparecer en metales de desgaste** (hoy sale también en contaminantes y aditivos).

### Paso 1 ✅ — BLOQUE 90: la hipótesis del DDI se cayó, y por eso sirvió

| Universo | Suma Fe | Muestras |
|---|---|---|
| sin DDI (lo que hace hoy) | 3 718.70 | 27 |
| TODAS (con DDI) | 4 994.66 | 45 |
| solo DDI | 1 275.96 | 18 |

**El esperado 6 785.39 es MAYOR que el total con DDI incluido.** Ningún subconjunto de estas vistas lo
produce. El DDI explicaba **parte** de la diferencia, no toda.

### Paso 2 ✅ — 🔴 La causa real: la fundación está ventanada a 12 meses
En `vw_MuestrasEstado`, de donde cuelga todo:
```sql
WHERE LD.[FechaMuestreo] >= DATEADD(MONTH, -12, GETDATE())
```
Está ahí **por rendimiento** — el propio comentario del DDL lo dice: *«la fundación rankea sobre 1 año en
vez de 9»*. Perfecto para último análisis, tendencia (6 muestras) e historial (2 meses).
**Pero Σvida no es eso.** Σvida dice ser la **vida del componente** y en realidad es
**«lo acumulado en los últimos 12 meses»**. El área suma todo el histórico: ahí está el gap.

⚠ **Y corrige algo que yo di por cierto el 22/09:** anoté que «la BD cubre ~12 meses». **Falso.** La BD tiene
~9 años; lo que cubre 12 meses es **la vista**. Volví a medir sobre algo ya filtrado — el mismo error que con
`EsDDI`. Regla: cuando un número no cuadra, **leer el `WHERE` de la fundación antes de teorizar**.

### Paso 3 ✅ — BLOQUE 94: la ventana explica el tamaño del problema, pero **no da el número**

| Universo (CA3160 MT LH, Fe) | Suma | Muestras | Desde |
|---|---|---|---|
| histórico COMPLETO, con DDI | **23 179.64** | 271 | 2020-09-27 |
| histórico COMPLETO, sin DDI | **18 372.32** | 192 | |
| 12 meses, con DDI | 4 994.66 | 45 | |
| 12 meses, sin DDI (**= hoy**) | 3 718.70 | 27 | |

🔴 **Ninguno da 6 785.39.** El esperado cae **entre** la ventana de 12 meses y el histórico completo:
no es ni una cosa ni la otra. Así que el criterio del área **no es «todo el histórico»** — hay un corte.

**Dos cosas que sí quedaron probadas, y son útiles igual:**
- **La ventana descarta ~70% del histórico:** 111 998 muestras totales vs 33 285 en 12 meses; la BD arranca en
  **2017-02-24**, no en 2025. Para Σvida eso es estructural, no un detalle.
- **Quitar la ventana solo para el acumulado es barato:** el `GROUP BY` sobre todo el histórico corrió en
  **933 ms** (1 scan, 1 364 lecturas, 2 215 grupos). El diseño propuesto es viable; falta el universo.

### Paso 4 ✅ — BLOQUE 95: **no hay fecha de corte que produzca 6 785.39**

| Hipótesis | Resultado |
|---|---|
| Un corte por fecha (con DDI) | ❌ cae **entre** dos muestras: 2025-04-17 = 6 699.42 · 2025-04-16 = 6 816.04 |
| Un corte por fecha (sin DDI) | ❌ también entre dos: 2024-10-04 = 6 699.32 · 2024-09-19 = 6 809.32 |
| Es otro equipo/componente | ❌ **0 filas** en toda la BD suman 6 785.39 |
| «Desde la instalación del componente» | ❌ el horómetro baja monotónico (43 600 → 13 127), **sin reinicios**: no hubo cambio de componente, así que equivale al histórico completo (18 372 / 23 179) |

**Si el criterio fuera «desde tal fecha», el número caería EXACTO en una fila.** No cae. Eso descarta de un
golpe toda la familia de hipótesis temporales.

✅ **Confirmado de paso:** 3 718.70 aparece exacto en la corrida al llegar a 2025-10-06 — justo la ventana de
12 meses. **Nuestro número está bien calculado**; lo que se discute es **qué universo sumar**, no el cálculo.

### Paso 5 ✅ — BLOQUE 96: tampoco es el tipo de muestra ni otra ventana

**Por tipo de muestra** (histórico completo): `ADI` 9 339.12 · `M` 6 492.93 · `DDI` 4 807.32 · `C` 2 540.27.
Ninguna suma sola ni combinada da 6 785.39 — `M` es la más cercana y le faltan **292.46**, que no
corresponden a ningún otro tipo.

**Por ventana** (ConDDI / SinDDI): 12m 4 994.66 / 3 718.70 · **18m 6 973.03** / 5 070.85 · 24m 9 308.64 /
**6 699.32** · 30m 11 782.64 / 8 740.32 · 36m 14 274.64 / 10 472.32 · 48m · 60m.
El objetivo queda **encajonado** entre 18m-conDDI y 24m-sinDDI — parece cerca, pero el paso 4 ya probó que
**ningún corte por fecha lo produce**.

### Paso 6 ⚠ — BLOQUE 97 devolvió **1 fila, pero no es el origen**

```
historico completo, sin DDI | CM402 | MOTOR DE TRACCION RH | Si | 6 785.03 | 144
```
**Difiere en todo lo que importa:** equipo (**CM402**, no CA3160) · lado (**RH**, no LH) · parámetro
(**Si**, no Fe) · y el valor es **6 785.03**, no 6 785.39 — entró solo por mi tolerancia de ±0.51.

Gerencia dijo explícitamente «el **Fe** del **MT LH** del **3160**». Que la única coincidencia en toda la BD
sea otro equipo, otro lado y otro metal es señal de **casualidad**, no de origen.

### Paso 7 ✅ — BLOQUE 98: **era ruido**, confirmado

| Objetivo | Coincidencias | Distancia mínima |
|---|---|---|
| control arbitrario 1 (6 123.45) | 0 | — |
| control arbitrario 2 (7 412.88) | 0 | — |
| **control arbitrario 3 (5 934.17)** | **2** | **0.170** |
| control arbitrario 4 (8 250.62) | 0 | — |
| el objetivo real (6 785.39) | 1 | 0.360 |

**Un número que me inventé encontró dos parejas, y más cerca que el real.** 2 de 5 objetivos tuvieron
coincidencia. A esta tolerancia los números arbitrarios también encuentran pareja → el CM402/Si **no
distingue señal de ruido** y queda descartado. (Densidad: 13 620 sumas, 8 en ±50 y 2 en ±5 de 6 785.)

### 🔴 Veredicto de la investigación (bloques 90 · 94 · 95 · 96 · 97 · 98)
**6 785.39 no se reproduce desde `[Oil].[LaboratoryData]`** con ninguna combinación de: ventana temporal
(12 a 60 meses) · tipo de muestra · equipo/componente · los 18 parámetros · «desde la instalación».
Y quedó verificado que **nuestro 3 718.70 está bien calculado** para su universo (12 meses sin DDI).
Lo que falta es saber **qué universo quiere el área**. → **Preguntar. Dejar de medir.**

**La pregunta, con la evidencia:**
> «Para el Fe del MT LH del CA3160 nos da **3 718.70** sumando los últimos 12 meses sin dializadas, y
> **18 372.32** sumando todo el histórico desde 2020. Probamos todas las ventanas (12 a 60 meses), todos los
> tipos de muestra y los 18 parámetros, y **6 785.39 no aparece en la base**. ¿Con qué herramienta y qué
> criterio lo calculaste?»

### ✅ Lo que SÍ se cerró de B, sin esperar respuesta
- **Σvida solo en metales de desgaste** ✅ **desplegado y verificado** (BLOQUE 99, 25/09) — `—` en todo lo que no sea
  `Fe · PQ · Cr · Ni · Cu · Pb · Sn · Al` — está en los **4** sitios del DDL y ya se desplegó con todo lo
  demás. ⚠ El **BLOQUE 99** quedó sin correr como verificación aparte: se comprueba de paso en F4.
  ⚠ Se condiciona **por parámetro, no por el grupo actual**, a propósito: el grupo cambia en el bloque C
  (`Si` pasa a contaminación, `Ca`/`Zn` a aditivos según componente). Atarlo al grupo obligaría a rehacerlo.
- **`Nº fuera` → `Nº fuera de límite`** ✅ salió con el bloque A.
- Y quedó probado que **quitar la ventana solo para el acumulado cuesta 933 ms**: cuando llegue la respuesta,
  el cambio es de **una línea**, no un rediseño.

**Queda pendiente solo el universo de la suma**, bloqueado por la pregunta de arriba.

### ⚠ Convivencia con el bloque F (P1)
Todo esto vive en `vw_TendenciaMD` / `vw_TendenciaElemento` / `vw_TendenciaMetalMD`, que **F reescribe**.
Por eso el 22/09 revertimos. Ahora se hace igual, pero **quirúrgico**: cambiar de dónde sale `acc` y blanquear
celdas son ediciones que F conserva. ⛔ No aprovechar para tocar el formato de esas tablas: eso es F.

## ✅ 🅲 Bloque C — formato por componente · **CERRADO (24/09)** · ⚠ salvo **C4** (BLOQUE 103, el `730E-`)

**Fuentes de gerencia (ya volcadas):**
[FORMATO_POR_COMPONENTE.md](../arquitectura/FORMATO_POR_COMPONENTE.md) ·
[LIMITES_FALLBACK.md](../arquitectura/LIMITES_FALLBACK.md) + `DDL_vw_LimitesFallback.sql` (524 límites).

### 🔴 Reconocimiento (24/09): el mapa de parámetros está **duplicado en 4 sitios**
Esto es lo que condiciona todo el bloque. Hoy el orden y la agrupación viven, por separado, en:

| # | Dónde | Cómo | Dificultad |
|---|---|---|---|
| 1 | `vw_TendenciaElemento` (L598) | `CROSS APPLY (VALUES …)` con `Parametro, Grupo, Orden, Inf, Inv` | la buena: un solo bloque |
| 2 | `vw_DiagnosticoMD` (L1284) | **copia** de la misma lista | idem |
| 3 | `vw_CondicionMT_MD` (L1532) | **copia** de la misma lista | idem |
| 4 | `vw_UltimoAnalisisMD` (L1490) | 🔴 **sin mapa: fila por fila, hardcodeada** en la concatenación | la peor |

⛔ **Hacer 4 veces el mismo cambio es garantizar que se desincronicen.** Ya pasó: son 3 copias de una lista
que debería ser una. Y el 4º caso ni siquiera tiene lista.

### ✅ `vw_FormatoParametro` — **DESPLEGADA Y VERIFICADA (24/09)**
Vive en **`DDL_vistas.sql`** (consolidada ahí, no en un archivo suelto) · **120 filas**, 4 formatos × 17-18
parámetros, con columna **`Inv`**.
Solo incluye los parámetros que **existen** en la BD — el Excel también pide V40, TAN, Oxidación,
Sulfatación, Nitración, Mo, Agua, Hollín, Diésel, Refrigerante e ISO 4/6/14, que no tenemos: **no se
inventan filas vacías**.
⚠ `MANDO`, `TRANSMISION` y `OTRO` no tienen hoja propia: usan el formato de `RUEDA` (son cajas de
engranajes). **Supuesto nuestro**, marcado en la vista — confirmar cuando haya ocasión.

### 🟢 C2 se resuelve solo: el sentido del límite **se deriva del dato**
Los dos Excel **se validan entre sí**, componente por componente:

| | MT | RD | SH | MODI |
|---|---|---|---|---|
| Ca | normal 4/4 | **INVERTIDO 6/6** | **INVERTIDO 2/2** | — |
| Zn | normal 4/4 | **INVERTIDO 6/6** | **INVERTIDO 2/2** | — |
| P | **INVERTIDO 8/8** | **INVERTIDO 6/6** | **INVERTIDO 2/2** | — |
| Mg | — | **INVERTIDO 6/6** | **INVERTIDO 2/2** | — |
| TBN | — | — | — | **INVERTIDO 4/4** |
| Si · Na · K · Fe | normal | normal | normal | normal |

En **MT**, `Ca` y `Zn` vienen con `LP < LC` — y la hoja MT los clasifica como **contaminantes**.
En **RD/SH** vienen con `LP > LC` — y sus hojas los clasifican como **aditivos**. Cero contradicciones.

⚠ **Pero NO se deriva del dato — y el BLOQUE 104 mostró por qué.** Propuse calcular `Inv = LP > LC`;
el cruce contra los datos reales encontró **dos defectos que esa regla importaría**:
- **Un typo en el archivo de gerencia:** `CERRO VERDE / MOTOR DE TRACCION LH / 980E / Pb LP=2 LC=1`
  (el RH trae 1/2). Es la única inversión no-aditiva de todo el Excel.
- **Inversiones artificiales en `OTRO`:** `vw_LimitesPorComponente` colapsa PTO, DAMPER, CAJA GIRO,
  COMPRESOR… en un solo bucket y agrega con `MIN()`, así que el LP puede venir de un componente y el LC de
  otro. ✅ **Inofensivo en producción**: el DDL ya excluye `OTRO` del join de límites (guard anti-colisión).

→ **`Inv` se deduce del GRUPO** (`Aditivos` + `TBN`), que es estable y no hereda ninguno de los dos defectos.
El cruce con el dato queda como **auditoría**, que es exactamente para lo que sirvió.

### El resto del diseño: que los 4 sitios lean la vista
Crear `vw_FormatoParametro` con `(CompTipo, Parametro, Grupo, Orden, Inv)` — ~100 filas `VALUES`, los 4
formatos del Excel (MT · RD · SH · MODI). Los consumidores hacen `JOIN` por `CompTipo + Parametro` en vez de
llevar su propia lista.
**Por qué así:** es exactamente el mismo patrón que ya funcionó con `vw_LimitesFallback` — datos de gerencia
como `VALUES` en una vista, porque la BD es de solo lectura. Y deja el formato en **un** lugar auditable.

### C1 · Grupos y orden dejan de ser fijos
- `Si` → **Contaminación** en los 4 (hoy está en «Met. Desg.»). ✅ coincide con el pedido.
- `Ca`/`Zn` → **Aditivos** en RD/SH/MODI, pero **Contaminación** en MT. Hoy son «Contam.» siempre.
- Se suma un 5º grupo, **Código Limpieza** (ISO 4/6/14), que hoy no existe.
- ✅ **`Al` es Desgaste** — confirmado por el usuario (24/09): **los dos Excel son definitivos**.
  `Si` sí se mueve a Contaminación; `Al` se queda. **No hay pregunta que hacer aquí.**

### C2 · 🔴 Los aditivos tienen el límite INVERTIDO — y ya hace daño
En el Excel, 46 de 47 pares con `LP > LC` son aditivos (`P`, `Zn`, `Ca`, `Mg`, `B`) y `TBN`: el aditivo se
**agota**, la alerta es por **debajo**.

> ✅ **RESUELTO (BLOQUE 101) — y no era C2.** Yo había dicho que el `P` de `/tendenciadet 3161 mt rh` era un
> «falso crítico». **Me equivoqué dos veces**, y medirlo lo aclaró:
> - El `997.040` **existe** (2026-09-17, CM=ADI). El análisis **no** inventó la cifra — sospecha descartada.
> - Las 6 muestras: 262.06 · 290.81 · 293.78 · **210.18** · 332.93 · 997.04. Con `LP=240` e `Inv=1`, la
>   única por **debajo** es 210.18 → `NVecesObs = 1`. **La vista está bien**: marca la muestra baja, que es
>   lo correcto para un aditivo.
> - Lo que falla es el **texto del análisis**, que atribuye la marca al 997 «muy por encima del límite».
>   Exactamente al revés. → **va al bloque E (prompt), no a C2.**
>
> ⚠ **Lección:** el síntoma «sale una marca rara» apuntaba a la vista y era el prompt. Sin este bloque
> habríamos «arreglado» una vista que funcionaba — y roto lo único que sí estaba bien.

**Lo que hay hoy en el mapa** (mismo `CROSS APPLY`): `Inv=1` solo en **P** y **TBN**; `Ca`, `Zn`, `Mg`, `B`,
`K`, `Na` tienen `Inf=1` (informativo: **no se juzgan**). El mecanismo **ya existe**, solo está mal repartido.
⚠ Y `P` trae **`LP=240` hardcodeado** en vez de `s.P_LP` — el Excel dice 280/240 para MT Antapaccay.

### 🔴 La magnitud de C2, medida (BLOQUE 100): el síntoma es **silencio**, no falsa alarma

| Aditivo | Por encima del límite | **Por DEBAJO (= agotado)** |
|---|---|---|
| Ca | 63 | **223** |
| Zn | 44 | **214** |
| Mg | 35 | **64** |
| TBN | 101 | 1 |

Como `Ca`, `Zn` y `Mg` son `Inf=1`, **hoy no se juzgan en absoluto**. Así que no estamos marcando falsos
críticos con ellos: estamos **callando ~500 muestras con el aditivo agotado**. Un aditivo que se agota es
justamente lo que Carlos quiere ver, y es lo único que no le mostramos.
*(`TBN` ya tiene `Inv=1`; su reparto 101/1 es coherente.)*

### Dato para el formato (BLOQUE 100): los límites **sí** son por componente
`TBN` solo tiene límites en **MODI** (103; MT/RD/SH en 0) · `Mg` solo en **RD** y **SH** · `Ca`/`Zn` en
MT/RD/SH pero **0 en MODI** · `Sn` **0 en MODI**. Encaja con que el formato sea por componente.
⚠ En cambio **todos los parámetros tienen DATO en los 4 componentes** (ningún 0): por eso **C3 tiene que
cortar por muestra, no por componente** — no se puede podar el formato de antemano.

### C3 · Parámetros con nulos → cortar la fila
Si no hay valor, la fila no se imprime. ⚠ Decidir el caso **«hay valor pero no hay límite»** (hoy sale con `—`):
eso **no** es nulo y probablemente se queda — se ve en `/ultimo` (B, P, Mg, V100 con `— — valor`).

### C4 · Límites — ✅ **RESUELTO EL DIAGNÓSTICO (24/09)** · y el fallback se descarta

**`[Eqpcare].[lc]` tiene EXACTAMENTE 64 filas, 5 proyectos y 7 modelos: es el Excel, completo.**
→ `vw_LimitesFallback` sería una **copia exacta**. No aporta **ni una fila** de cobertura.
**⛔ Descartada — no desplegarla.** El archivo queda en el repo con ese aviso en la cabecera, solo como
respaldo por si `lc` alguna vez diverge del Excel.

> Tu criterio («priorizar la BD, el Excel como fallback confiable») **es el correcto**. Lo que cambia es que,
> con estos datos, **no hay nada que rellenar**: el Excel no tiene ni un límite que la BD no tenga.

**Hay DOS causas distintas de «sin límites», y no conviene confundirlas** (45 combinaciones de la flota viva
sin límites contra 25 con límites):

| Causa | Ejemplo | ¿Quién lo resuelve? |
|---|---|---|
| **(a) Desajuste de texto** | `lc` dice **`730E-`** y la flota dice **`730E`** → Cerro Verde 730E se queda sin límites **aunque el dato existe** | **nosotros**, normalizando el emparejamiento |
| **(b) Ausencia real** | `930E`, `HD1500`, `WA900`, `PC7000`, `WD900`… no están en `lc`. Y **Cuajone/Toquepala no tienen ninguna fila**, ni con 980E | **gerencia**: hay que cargarlos |

**(a) explica el misterio de Cerro Verde:** el BLOQUE 83 decía «TRACCION 16 de 128 con LP». No faltaban
límites — los equipos 730E no encontraban su fila por un guion.

### Qué hacer con C4 — **BLOQUE 103**
1. Ver el valor **exacto** de `MODELO` en ambos lados (con delimitadores): ¿un guión de más, un sufijo
   `730E-10`, espacios?
2. **Medir cuánto recupera** normalizar (prefijo antes del primer `-`) **antes** de tocar la vista.
   ⛔ Si sube poco, no se toca `vw_LimitesPorComponente` por un caso aislado.
3. **La lista para gerencia:** qué límites faltan de verdad, ordenada por **equipos afectados**. Eso es
   entregable tal cual — la primera fila es la que deja más flota sin evaluar.

⚠ Esa lista es el tercer tema para la conversación con el área, junto con Σvida y el `Al`.

### Orden de ataque dentro de C · estado al 24/09

| # | Paso | Estado |
|---|---|---|
| 1 | **BLOQUE 91** — ¿el JOIN mezcla modelos? | ✅ replanteó C4 |
| 2 | **BLOQUE 100** — parámetros y límites por componente | ✅ C3 corta **por muestra**; C2 son ~500 silencios |
| 3 | **BLOQUE 101** — ¿el `P` es bug de vista o de prompt? | ✅ **del prompt** → se fue al bloque E |
| 4 | **BLOQUE 102** — ¿el modelo empareja? | ✅ `lc` **es** el Excel (64 filas) → fallback **descartado** |
| 5 | **BLOQUE 103** — normalizar el modelo (`730E-` vs `730E`) | ⏳ |
| 6 | **BLOQUE 104** — `vw_FormatoParametro` | ✅ desplegada y verificada: formato = Excel, 0 filas muertas, y el cruce encontró 2 defectos de dato |
| 7 | Enganchar el formato · **1/4** `vw_TendenciaElemento` | ✅ hecho · 🔴 destapó un bug de encabezados, **corregido** → **BLOQUE 106** |
| 7.b | Enganchar · **2/2 de C**: `vw_UltimoAnalisisMD` (era el hardcodeado) | ✅ hecho → **BLOQUE 108** |
| 7.c | `vw_DiagnosticoMD` y `vw_CondicionMT_MD` | ➡ **no son de C: son D1 y D2** |
| 8 | **C3** — filas sin dato | ✅ **zanjado (24/09)**: las filas del Excel van **siempre**, con `—` |
| 9 | **BLOQUE 103** — normalizar `730E-` → `730E` (**C4**) | ⏳ |

### ✅ **BLOQUE 105** — se validó el 1er consumidor antes de tocar los otros 3 (y valdría la pena repetirlo)
`vw_TendenciaElemento` ya no lleva su propia lista: hace `INNER JOIN vw_FormatoParametro` por
`CompTipo + Parametro`. Tres consecuencias, y hay que ver las tres:
1. **Orden y grupos por componente**, con las etiquetas del Excel (`Salud` / `Aditivos` / `Contaminacion` /
   `Desgaste`, en vez de `Adit.` / `Contam.` / `Met. Desg.`).
2. **En RUEDA/HIDRAULICO/MOTOR, `Ca`/`Zn`/`Mg` dejan de ser informativos y se juzgan invertidos.**
   En TRACCION siguen como contaminantes informativos, tal como manda su hoja.
3. El `INNER JOIN` **filtra**: un parámetro fuera del formato de ese componente desaparece de la tabla.

### 🔴 Bug que destapó el enganche (24/09) — ya corregido
El render salió con los **encabezados de grupo descolocados**: `P` y `B` bajo **Salud**, `Fe` bajo
**Contaminación**, y **Desgaste** dos veces.

**Causa:** `vw_TendenciaMD` emitía el encabezado en **posiciones fijas** — `Orden IN (1,9,14,17)` — que
correspondían al mapa viejo de 18 parámetros **iguales para todos los componentes**. Con el formato por
componente esos cortes dejaron de existir, pero el orden de los parámetros sí salió bien: era solo dónde se
inyectaba el título.

**Fix:** el encabezado se emite en la **primera fila de cada grupo**
(`ROW_NUMBER() OVER (PARTITION BY Equipo, Compartimiento, Grupo ORDER BY Orden) = 1`), que es correcto para
cualquier formato presente y futuro.

⚠ **Hay 3 sitios más con el mismo `IN (1,9,14,17)`** (`vw_DiagnosticoMD` ×2, `vw_CondicionMT_MD`). Leen de
`vw_DiagnosticoEquipo`, que **todavía tiene el mapa viejo**, así que ahí la condición **sigue siendo
correcta**. ⛔ Cambiarlos ahora los rompería: van **en la misma pasada** en que se los enganche al formato.

⚠ **Y dos errores míos en el propio bloque de validación:** `vw_TendenciaElemento` expone `Inf` pero **no
`Inv`** (es interno del CTE) — las consultas (3) y (4) fallaron con `Msg 207`. Corregidas leyendo `Inv` de
`vw_FormatoParametro`. Es la cuarta vez que me pasa lo mismo: **cruzar columnas contra el schema antes de
escribir, no después del error**.

⚠ **La consulta (3) del bloque es la que hay que mirar con cuidado.** Hoy hay **0** alertas por aditivo
agotado; después habrá tantas como muestras por debajo del límite (el BLOQUE 100 estimó ~500). Pasar de 0 a
cientos de un día para otro **no es un bug, pero lo parece**: conviene avisar al área antes de publicarlo.

⚠ **`P` conserva su `LP=240` hardcodeado** — a propósito. `vw_MuestrasRankeadas` no expone `P_LP`/`P_LC`
(ni los de `B`), así que no hay de dónde leerlo; el Excel dice `P LP=280 / LC=240`, o sea que hoy estamos
usando el LC como LP. Cambiarlo ahora sería mover alertas sin poder validarlas → **ítem propio de C**:
pasar `P` y `B` por la cadena de límites (`lc` → `vw_LimitesPorComponente` → `vw_MuestrasEstado`).

### ✅ Formato COMPLETO (24/09) — «todos esos campos han de aparecer»
`vw_FormatoParametro` pasa de **120 a 175 filas**: ahora lista los **23 / 25 / 25 / 27** parámetros de las 4
hojas, **incluidos los que la BD no mide** (`V40`, `TAN`, `Oxidacion`, `Sulfatacion`, `Nitracion`, `Mo`,
`Agua`, `Hollin`, `Diesel`, `Refrigerante`, `ISO>4/6/14`), marcados con `Disponible = 0`.
Esos salen con **`—`** en vez de desaparecer: su ausencia también es información, y así la tabla es fiel
a la hoja.

**El «if/else» que pedías es la propia vista de formato.** `vw_TendenciaElemento` ahora **recorre el
formato** (`INNER JOIN`) y busca el valor con `OUTER APPLY`, en vez de recorrer los valores. Quién va y
quién no lo decide **una sola tabla**, por componente.
→ **BLOQUE 107** lo valida, hoja por hoja.

### ✅ C3 ZANJADO (24/09) — **las filas del Excel van siempre**
Regla del usuario, textual: *«si hay 0, pues hay 0; si no hay nada o null, un guión. Pero las filas que
vimos en el Excel van sí o sí»*.

→ **No se corta ninguna fila que el Excel liste.** `0` se muestra como `0`; ausente o nulo, `—`.
⛔ Queda descartado el `WHERE Disponible = 1` y cualquier poda por nulos. El pedido original del 23/09
(«parámetros con nulos, cortar fila») se resuelve así: la tabla es **el formato**, no lo que haya llegado.

✅ **Verificado (BLOQUE 107):** TRACCION 23 filas · RUEDA/HIDRAULICO/MANDO/OTRO/TRANSMISION 25 · MOTOR 27,
con `V40`, `Mo`, `Agua`, `ISO>4/6/14`, `Hollin`, `Diesel`, `Refrigerante` en `—`.
**Tamaño:** 2 761 a 3 017 caracteres según componente — ~10% del techo del canal. Sin riesgo.
### ✅ Las 66 filas sin tabla — verificado: **no era regresión mía**
Dije que era «una regresión introducida por el cambio» **sin medir el antes**. Lo verifiqué y era falso.

| Comprobación (BLOQUE 110) | Resultado |
|---|---|
| ¿Tablas incompletas? | **`MD_sin_Fe = 0`** — el enganche al formato funciona en las **1 621** filas válidas |
| ¿Qué son las 66? | **`MD` nulo**, todas con `Compartimiento NULL` |
| ¿Quiénes? | HT338 (Antamina) · 3104, 3105, CA3164 (Antapaccay) · K-301…K-316 (Cerro Verde) |
| ¿Preexistente? | **Sí.** 74 filas con `Compartimiento` nulo/`nan`/`M`; las 8 de diferencia traen `'nan'` o `'M'`, que **no** son NULL y sí arman tabla |

**Causa:** el título concatena `u.compAbbr` **sin `ISNULL`**. En T-SQL basta un `NULL` en una concatenación
para anular **todo** el resultado. El título nunca estuvo protegido — esto venía de antes.

**✅ Arreglado igual, porque fallaba en silencio.** `MD` nulo hacía que el flujo respondiera «no encontré
datos», que suena a «ese equipo no tiene muestras» cuando la muestra **existe** y lo que falta es el
componente. Mismo patrón que el bug del `mtlh`. Ahora dice:
> _Esta muestra no tiene **componente** registrado en la base, así que no se puede evaluar._

No inventa dato ni formato: explica por qué no hay tabla. → **BLOQUE 111** para validar.

### ⚠ Nota de método (24/09): las validaciones deben filtrar como filtra producción
Escribí consultas de validación que barrían **toda** una vista MD (`FROM vw_DiagnosticoMD` sin `WHERE`).
Tardaron **6:32** y **>12 min** (hubo que cancelarlas). Estas vistas se construyen **por equipo** y el flujo
siempre filtra por uno: un scan completo no mide nada útil y cuesta minutos de la sesión.
→ Corregidas para usar una **muestra de equipos**. Y para contar sobre toda la flota, ir a la vista **barata**
(`vw_DiagnosticoEquipo`), no a la que arma el markdown.

## ✅ 🅳 Bloque D — **SQL CERRADO y probado en Teams (24/09)** · queda lo de Copilot (alias de `/diagnostico`)

C dejó listas `vw_FormatoParametro`, la inversión de aditivos y el criterio de filas. D aplica todo eso a
los dos módulos que faltan, **y cada uno tiene su propio problema de diseño**.

---

### ✅ D1 · `/diagcompleto` — **desplegado y probado en Teams (24/09)** · ⛔ el borrado del 03 quedó **descartado**

**El problema de diseño y cómo quedó:** `vw_DiagnosticoMD` es **parámetros × componentes** (una columna por
componente del equipo), así que no puede seguir el formato de uno solo. Lo medí:

| | |
|---|---|
| Parámetros en la **unión** de las 4 hojas | **31** |
| Que **cambian de grupo** según el componente | **4** (`Ca`, `Mg`, `Mo`, `Zn`) |
| Que **no** cambian | **27** |

✅ **Aprobado (24/09):** esos 4 van como **Aditivos** — su grupo en 3 de las 4 hojas y en 4 de las 6 columnas
de un camión típico — con un pie en la tabla:
> _`Ca`, `Mg`, `Mo` y `Zn` se listan como aditivos; en Motor de Tracción son contaminantes._

**Implementado:**
- Nuevo `CompTipo = '(CRUZADO)'` en `vw_FormatoParametro` con esas 31 filas. **No es un orden aparte
  inventado en la vista**: vive en la misma tabla de formato, auditable junto al resto.
- `vw_DiagnosticoMD` lo consume; sus **2** encabezados de grupo pasan de `ord IN (1,9,14,17)` a
  «primera fila de cada grupo». ✅ **Ya no queda ningún sitio con posiciones fijas en todo el DDL.**
- Pie agregado en las **dos** variantes (completa y solo-observados).
- ⚠ El `Inv`/`Inf` del formato cruzado **no evalúa nada**: las celdas ya llegan con su estado desde
  `vw_DiagnosticoEquipo`, calculado **por componente**. Aquí el formato solo ordena y agrupa — por eso poner
  `Ca`/`Zn` bajo Aditivos no cambia cómo se juzgan en las columnas de tracción.

✅ **Verificado (BLOQUE 113):** la tabla sale con las 31 filas, los 5 grupos en orden y el pie. Los valores
no cambiaron — solo el orden y la agrupación, como debía ser.

### 🔴 Antes de tocar `/diagnostico`: **BLOQUE 114**
Fue el **único** comando que falló de verdad en la ronda (`/diagnostico 3160` → «no encontré datos»),
mientras `/diagcompleto` con el **mismo equipo** sí respondía. Borrar el tema hace desaparecer el síntoma,
pero si la causa es compartida la arrastramos sin enterarnos.

**Mi hipótesis:** las dos salidas vienen de la **misma vista**. La variante de *solo observados* se queda sin
filas cuando el equipo no tiene ninguno → el `STRING_AGG` devuelve `NULL` → `MD` nulo → el flujo responde
«no encontré datos». Sería **el mismo patrón** que las 66 filas del BLOQUE 110 y que el bug del `mtlh`:
falla en silencio en vez de decir «este equipo no tiene componentes observados».

### ✅ CONFIRMADO (BLOQUE 114) — y no era un bug de `/diagnostico`
```
CA3160 | Variante_observados: NULO | Variante_completa: ok (1 675 chars) | NumCompObs 0 | NumCompTotal 6
```
**Un equipo SANO rompía el comando.** Con 0 componentes observados, la variante se queda sin filas, el
`STRING_AGG` devuelve `NULL`, el `MD` entero se anula y el flujo responde «no encontré datos» — que suena a
«ese equipo no existe» cuando la respuesta correcta era **«no tiene ningún componente observado»**, que es
justo lo que se estaba preguntando.

⚠ **Y no era exclusivo de `/diagnostico`:** cualquier módulo que lea esa variante lo hereda. Borrar el tema
habría hecho desaparecer el síntoma **dejando la causa viva**. Por eso valía la pena mirar antes.

✅ **Arreglado y verificado (BLOQUE 115):** `CA3160` ahora responde
_«Ninguno de sus 6 componentes tiene parámetros fuera de límite.»_ en 9 s, en vez de `NULL`.
Y el conteo barato dio **206 equipos sin observados de 306**: dos tercios de la flota estaban expuestos a
este fallo, no un caso aislado.

🔴 **Tercer caso del mismo patrón en esta ronda**, y conviene verlo junto:
| Caso | Síntoma | Realidad |
|---|---|---|
| Componente pegado (`mtlh`) | «no encontré datos» | el componente existía, no casaba el texto |
| Muestras sin componente (66) | «no encontré datos» | la muestra existía, faltaba el componente |
| **Equipo sano** | «no encontré datos» | **el equipo está bien** |
→ Vale la pena **barrer el resto de módulos** buscando el mismo patrón, en vez de esperar a que gerencia lo
encuentre. Lo anoté para el bloque G.

### ⛔ `/diagnostico` **NO se borra** — regla nueva del 24/09, aprendida en caliente

**El dispatcher «00 Comandos» es una cadena de `if` anidados, no una lista de ramas.** Cada nodo Condición
lleva en su rama **else** a **todas** las condiciones que vienen después. Borrar el nodo de `/diagnostico` no
quita una rama: se lleva `/tendencia`, `/grafica` y todo lo que cuelga debajo. El usuario lo intentó y
**tuvo que revertirlo**.

⛔ **Regla permanente:** en «00 Comandos» **nunca se borra un nodo Condición**. Si un comando deja de tener
sentido, se le **cambia el destino** o se **reutiliza el nombre** — el nodo se queda donde está.

### ✅ Lo que SÍ se hace con `/diagnostico`

**1. ✅ HECHO — el Tema 04 absorbe los disparadores del 03.**
Era el único paso urgente y sigue siéndolo con o sin borrado: la **descripción** es lo único con lo que el
orquestador rutea el lenguaje natural. Sin traspasarla, «diagnóstico del CA3177» cae al fallback.
Descripción unificada del **04** (**461** UTF-16, margen 563), ya pegada:

> DIAGNÓSTICO de UN equipo: el estado actual de TODOS sus componentes en una matriz componentes × parámetros, con todos los parámetros (también los que están OK). «diagnóstico del CA3177», «diagnóstico completo del X», «cómo está el equipo X», «último análisis general del X», «todos los metales del equipo X», «la matriz completa del X». Rellena equipo. ⛔ NO cronológico (→ Historial), NO un solo componente (→ Último análisis), NO la flota (→ Barrido / Triage).

⚠ Y quitarle al 04 el ⛔ que apuntaba al 03 («NO solo observados»): ese destino deja de usarse.

**2. Desactivar el Tema 03** (no borrarlo), como ya están el **23** y el **24**.

**3. El nodo `cmd="/diagnostico"` se queda — se le cambia el destino a `04 Diagnóstico completo`.**
Es **un desplegable**, no una edición de estructura: cero riesgo para la cadena de `else`. Y deja
`/diagnostico` funcionando como **alias** de `/diagcompleto` — el mismo criterio que ya se aplicó con
`/condicion` → `/condicionmt`, donde también se decidió no cortar en seco lo que alguien memorizó.

⚠ **Verificar antes:** si el nodo apunta a un tema **desactivado**, el comando se queda sin destino. Por eso
el paso 3 (re-apuntar) va **antes** del paso 2 (desactivar), no después.

**4. Los 3 archivos de comandos:** `/diagnostico` **no se quita** — pasa a figurar como **alias** de
`/diagcompleto` en `CONFIG_COMANDOS.md`, `gen_comandos_card.py` y `comandos_card.json` regenerado.
Mismo tratamiento que `/condicion`.

**5. Re-pegar la tarjeta** en el nodo de `/comandos` (una sola vez, con todo lo demás acumulado).

**6. `CONFIG_TEMAS.md`:** marcar el 03 como **desactivado** con su motivo y la fecha; dejar la descripción
unificada solo en el 04. ⛔ No borrar la fila: un tema desactivado sigue existiendo y hay que poder
reconstruir por qué.

**7. Consecuencia en el SQL** (no urgente): la columna **`MD`** de `vw_DiagnosticoMD` queda **sin uso** —
era la variante de solo-observados que consumía el 03; el 04 usa `MD_Completo`.
✅ No hay que borrarla: el optimizador **elimina la columna no pedida** (medido en el BLOQUE 116: pedir una
cuesta la mitad que pedir las dos). Queda como código muerto documentado.
⚠ Y ahora hay una razón más para no tocarla: si el 03 se **desactiva** en vez de borrarse, puede volver.

**8. Probar:** `/diagcompleto 3160` · `/diagnostico 3160` (**debe responder igual que `/diagcompleto`**, no
decir que no reconoce el comando) · y en lenguaje natural **«diagnóstico del 3160»** y **«cómo está el
equipo 3160»** — estas dos son la prueba de que el paso 1 se hizo bien.
⚠ Y una prueba que antes no hacía falta: **`/tendencia` y `/grafica` deben seguir funcionando**. Son los que
cuelgan del `else` de `/diagnostico` y los que se perderían si alguien vuelve a borrar el nodo.

### ⚠ Temas desactivados — **23 y 24**, sin rumbo desde hace tiempo

| Tema | Qué hacía |
|---|---|
| **23** Tendencia de un metal en la flota | dirección ↑↓→ de UN metal en un tipo de componente, equipo por equipo |
| **24** Condición de un componente en la flota | qué equipos tienen ese componente observado, críticos primero |

Están **desactivados y los cubre el fallback** (así consta en `CONFIG_COMANDOS.md`). Nunca tuvieron comando
propio. Un tema desactivado no molesta, pero tampoco se audita solo: hay que decidir si se reactivan con un
sentido claro o se retiran del mapa.

⚠ **Inconsistencia detectada al verificarlo (24/09):** `CONFIG_TEMAS.md` los sigue listando con su
descripción completa, **sin marca de desactivados**, mientras `CONFIG_COMANDOS.md` sí lo dice. Marcado ya en
`CONFIG_TEMAS`. ✅ **El Tema 02 está activo** — lo confirmé antes de tocar nada: D2 (`/condicionmt`) no
corre peligro.

### ✅ `vw_DiagnosticoMD` — diagnosticado (BLOQUE 116) y **optimizado** (BLOQUE 117)

| Medición (1 equipo) | Tiempo | `LaboratoryData` |
|---|---|---|
| Vista **fuente** `vw_DiagnosticoEquipo` | **522 ms** | 1 scan / 1 364 lecturas |
| `vw_DiagnosticoMD` · `MD_Completo` | 3 941 ms | **5 scans / 23 628** |
| Con **2** equipos | 3 953 ms | 5 scans / 25 950 |
| Variante `MD` (observados) | 4 508 ms | 7 scans / 9 548 |

**Cuatro lecturas, y dos cambian el plan:**

1. **La fuente es rápida** (522 ms, 1 scan). El coste está en armar el markdown, no aguas arriba.
2. 🔴 **La fundación se re-expande ~5 veces**: de 1 scan a 5-7 y **17× más lecturas**. Es el
   **anti-patrón nº1**, el mismo del barrido: `vw_DiagnosticoMD` referencia `vw_DiagnosticoEquipo`
   **4 veces**, más los CTE derivados. Los CTE **no se materializan**: cada referencia lo vuelve a calcular.
3. **2 equipos cuesta lo mismo que 1** (3 941 vs 3 953 ms) → el coste es casi **fijo**: el filtro por equipo
   no baja hasta la fundación. Por eso 6 equipos con `IN()` se disparó a minutos — cambia el plan.
4. ✅ **Hipótesis descartada:** pedir una columna cuesta la mitad que pedir las dos (3 897 vs 8 030 ms), o sea
   que el optimizador **sí** elimina la variante no usada. En producción el flujo pide una → **no se paga
   doble**. Separar la vista en dos no aportaría nada.

✅ **Y es preexistente:** las 4 referencias y los CTE derivados ya estaban. Mi cambio de formato sustituyó
un `CROSS APPLY` de 18 filas por un `JOIN` de 31; **no agregó referencias**. (Ahora sí lo puedo afirmar.)

### ✅ Aplicado (BLOQUE 117) — mejora real, y el margen que queda

| | Antes | Después |
|---|---|---|
| 1 equipo | 3 941 ms | **2 418 ms** (−39 %) |
| `LaboratoryData` | 5 scans / 23 628 | **4 scans / 22 264** |
| 3 equipos | *no terminaba* | **26 s** |
| Salida | | **idéntica** (CA3160 1 675 · CA3161 1 666 · CA3176 922 + 1 682) |

⚠ **Lectura honesta: los scans bajaron de 5 a 4, no a 1.** El motivo es el mismo mecanismo de siempre:
`base` **también es un CTE**, y los CTE no se materializan. Al hacer que `unpv`/`obsmetals`/`obsmet` lean de
`base`, la re-ejecución **no desapareció: se movió un nivel arriba**. Ahora se re-ejecuta `base` — que es
**una** lectura de la fundación — en vez de la vista entera con sus JOINs, y de ahí sale el 39 %.

**Bajar de ahí** exigiría reestructurar a **una sola pasada con funciones de ventana** (lo que se hizo en el
barrido), no solo redirigir referencias. Es un cambio mayor y más riesgoso.

✅ **Se toma la mejora y se cierra.** 2,4 s por equipo es aceptable para `/diagcompleto`, y la escalabilidad
ya no se rompe con varios equipos — que era lo que preocupaba. Queda anotado el margen por si alguna vez
vuelve a molestar.

### ✅ D2 · `/condicion` → `/condicionmt` — **CERRADO (24/09)**: desplegado y probado en Teams con los dos nombres

**Qué vista era:** `vw_CondicionMT_MD` (Tema 02, flujo `MD_equipo`). Lo verifiqué en `CONFIG_TEMAS` en vez
de asumirlo: la otra candidata, `vw_CondicionCompMD`, es una tabla de **flota** y no intervenía.

**Ventaja que trae este caso:** al ser **solo tracción**, el formato es inequívoco — la hoja MT. No tiene la
ambigüedad de D1.

| | |
|---|---|
| Vista | pasa de 18 filas propias a las **23 de la hoja MT**, mismo orden y grupos que `/ultimo` |
| Encabezados | `ord IN (1,9,14,17)` → **primera fila de cada grupo** (mismo bug que en la tendencia) |
| Comando | `/condicionmt`, con **alias `/condicion`** que sigue funcionando |
| Sincronizado | `CONFIG_COMANDOS` · `gen_comandos_card.py` · `comandos_card.json` · descripción del tema (**462** UTF-16 medidos el 24/09, margen 562 — el 534/536 que figuraba era de una versión previa) |

**Sobre el alias:** decidí **no cortar `/condicion` en seco**. Quien lo memorizó se queda sin respuesta de un
día para otro, y el síntoma es el mensaje genérico de comando no reconocido — otra falla que parece un bug.
La rama del dispatcher acepta los dos nombres y apunta al mismo Tema 02. ⛔ Cuando se retire el alias,
avisarlo en `/comandos` **antes**, no después.

**Te toca — no es solo «cambiarle el nombre».** En el repo ya está todo (vista, 3 archivos de comandos,
descripción). Lo que falta está **fuera** del repo:

**1. SQL:** confirmar que `vw_CondicionMT_MD` quedó desplegada y correr el **BLOQUE 112**. Su consulta (3) es
la que cierra el pedido: compara `/condicionmt` contra `/ultimo` del mismo componente — **las filas y su
orden deben ser idénticos**.

**2. Dispatcher «00 Comandos», nodo `cmd = /condicion`:** ⛔ no se borra ni se reemplaza. Se le agrega
**«Nueva condición»** `cmd es igual a /condicionmt`.
🔴 **La trampa:** al agregar la segunda condición, Copilot las junta con **«Cumple TODAS»** por defecto.
Así **ningún** comando entra (`cmd` no puede ser dos cosas a la vez). Hay que cambiarlo a
**«Cumple CUALQUIERA» (Or)**. Si después de esto `/condicion` deja de responder, es esto.

**3. Tema 02:** pegar la descripción nueva (la de `CONFIG_TEMAS.md`, 462 UTF-16).
⚠ El resto del tema **no se toca**: misma entrada (`equipo`), mismo flujo (`MD_equipo`), misma vista.

**4. Re-pegar la tarjeta** — al final, junto con todo lo demás acumulado.

### Orden sugerido
✅ **D2 hecho.** Sigue **D1**, con la decisión de los 4 parámetros (`Ca`, `Mg`, `Mo`, `Zn` como **Aditivos**
en la tabla cruzada, con pie aclaratorio) **ya aprobada por el usuario el 24/09**.

## ✅ 🅴 Bloque E — análisis y recomendaciones · **CERRADO (25/09)** · E0 · E1 · E2 · E3 · E4

No toca ninguna vista de datos: el prompt de análisis, un añadido literal en una vista de recomendaciones,
y un hallazgo nuevo que apareció al mirar las capturas.

| | Estado |
|---|---|
| **E0** contador vs celdas marcadas | ✅ **CERRADO** — desplegado y verificado (BLOQUES 118 y 120); sin costo de rendimiento |
| **E1 + E1.b** prompt reescrito | 🟡 escrito en `prompts/analisis_prompts.md` — **lo único que queda de E**: pegarlo en Copilot |
| **E2** correo en recomendaciones | ✅ **cerrado** — faltaba entero en `vw_UltimoAnalisisMD`; verificado en el BLOQUE 119 |
| **E3** el mismo valor marcado en un módulo y no en otro | ✅ **arreglado** en la fundación — 53 comp. / 27 equipos, solo RUEDA (BLOQUES 121 y 122) |
| **E4** el pie de recomendaciones fuera de MT | ✅ **arreglado** — 3 casos en vez de 2, en las 2 vistas |

---

### ✅ E0 · El encabezado decía **0 observados** con una celda **roja** debajo — **ARREGLADO (24/09)**

`/condicionmt 3161` imprimía **«0 de 2 observados»** y dos filas más abajo el `Zn` de MT RH salía
**70.7 🟥**. Las dos cosas salían de la **misma vista**.

| | De dónde salía | Qué cubre |
|---|---|---|
| La **marca** de la celda | `Estado_<metal>` | los **23** parámetros de la hoja MT |
| El **contador** | `Estado_General` | **9** de desgaste (`Fe Cr Ni Cu Si Al Pb Sn PQ`) + `TBN` |

**Y la exclusión era deliberada.** En `vw_MuestrasEstado`, sobre `Ca`/`Zn`/`Na`/`K`/`Mg`, hay un comentario:
*«CONTAMINANTES nuevos (informativos: NO entran a Estado_General hasta validación del área)»*.
Esa validación **ya llegó**: es el Excel de límites dCarlos, el mismo con el que se hizo el bloque C.

#### Lo que midió el BLOQUE 118

| | |
|---|---|
| Componentes en total | **1 621** |
| Que el contador da por **OK** | **1 284** |
| 🔴 **OK pero con una celda marcada** | **119** — el **9 %** de los «sanos» |

Por metal y proyecto: **Antapaccay `Na`** 50 componentes / 26 equipos · **Antamina** `Mg` 31, `Zn` 31, `Ca` 31
(25 equipos) · Antapaccay `Ca` 18 · Cerro Verde `Ca`/`Mg`/`Zn` 7 c/u · Toromocho 4 de cada uno.
**No era un caso aislado.** Y el `CA3161` salió exactamente como se predijo: `Zn = '70.7:C'` con
`Estado_General = 'OK'`.

#### Cómo quedó — dinámico, sin listas paralelas

El contador **deja de tener criterio propio**: cuenta lo que la tabla pinta. Si aparece una marca, cuenta;
si el formato cambia, el contador cambia solo. No hay ninguna lista nueva que mantener.

| Vista | Cómo |
|---|---|
| `vw_CondicionMT_MD` | el contador y la lista de observados salen de `unpv.marcada` — **la misma celda que se imprime**. De paso **desapareció** la lista propia de 13 metales que tenía `obsdet` y que no coincidía con las 23 filas del formato |
| `vw_DiagnosticoMD` | `CompMarcado` se calcula **dentro de `base`**, la única lectura de la fundación, y reemplaza a `Estado_General` en las **3** variantes de «solo observados» + el contador |

⚠ **Por qué en `base` y no en un CTE nuevo:** un CTE más referenciado 3 veces habría devuelto los scans
que ganó el BLOQUE 117. Como expresión dentro de `base` **no lee nada nuevo**. El BLOQUE 120 (5) lo mide.

🔴 **Un falso «equipo sano» que esto destapa:** el `CA3160` tenía `Zn` 40.2 y `Na` 7.5/6.8 marcados y el
contador decía **0** → `/diagcompleto` respondía *«(ninguno fuera de límite)»*. Era **falso**, y es el mismo
mensaje de equipo sano que agregamos en el BLOQUE 115. Ahora los cuenta.

#### ⚠ Lo que **no** se tocó, y por qué

`vw_TriageMD`, el **barrido** y el **conteo de flota** siguen con `Estado_General`. Los números que gerencia
ya vio **no se mueven**. Ampliar `Estado_General` en la fundación es una decisión aparte y de alcance mayor:

- Cambiaría de golpe los observados de **todas** las minas en **todos** los módulos de flota.
- ⚠ Y no es un `include` y ya: fuera de Motor de Tracción, `Ca`, `Mg` y `Zn` son **aditivos** — ahí la
  alerta es por **debajo**, y `Estado_Ca` está escrito como *«por encima»*. Meterlo tal cual generaría
  falsas alarmas en hidráulicos, mandos y ruedas.
- Va con la pregunta al Carlos, junto con el aviso de los 181 equipos de los aditivos.

#### ✅ Verificado — BLOQUE 120 (24/09)

| | Antes | Ahora |
|---|---|---|
| `/condicionmt 3161` | «0 de 2 observados» con el `Zn` en rojo | **«1 de 2»** · `MT RH: Zn` |
| `/diagcompleto 3160` · observados | `NumCompObs` **0** → *«(ninguno fuera de límite)»*, **falso** | **3 de 6** · tabla real de 1 099 chars |
| `MD_Completo` | 1 675 / 1 666 chars | **idéntico** — la tabla completa no se movió |
| `LaboratoryData` | 4 scans / 22 264 lecturas | **4 scans / 22 264** — ni una lectura de más |

✅ **La apuesta de poner `CompMarcado` en `base` salió bien:** lecturas idénticas a las del BLOQUE 117.
(El *elapsed* de 2 891 ms trae 1 830 ms de compilación por ser la primera corrida tras el `CREATE OR ALTER`;
la CPU fue de 656 ms.)

📧 **La cifra para Carlos: +11 equipos.** Pasan de **100** a **111** de 306 con al menos un componente
observado. Mucho menos de lo que sugerían los 119 componentes del BLOQUE 118: casi todos caían en equipos que
**ya** tenían otro componente observado.

⚠ **Una prueba que NO llegó a hacerse:** la consulta (3) buscaba confirmar que un equipo **sin ninguna marca**
sigue diciendo que está sano. Los 4 equipos que usé (`CA3160` `CA3161` `CA3176` `CA3177`) resultaron tener
marca, así que ese camino quedó sin ejercitar. Repetirla con un equipo limpio antes de darla por verificada.

---

### ✅ E1 + E1.b · Prompt de análisis reescrito — `docs/copilot/prompts/analisis_prompts.md`

**Cuatro fallas medidas en la ronda, cada una con su regla nueva:**

| Falla | Regla nueva |
|---|---|
| 🔴 Explicaba una marca **al revés** (el `P` a 210.18, marcado por estar **bajo** su LP de 240, descrito como *«muy por encima del límite»*) | **El GRUPO manda:** en **Aditivos** y `TBN` la alerta es por **debajo** |
| Comentaba parámetros **sin marca** (*«el fósforo está alto en MT RH (997.0)»* — no estaba marcado) | Solo se comentan celdas 🟥/🟨 |
| Trataba los `—` como hallazgo (*«no hay datos de limpieza ISO, no se puede evaluar»*) | `—` **no es un hallazgo**: no se menciona |
| **3 corridas del mismo equipo → 3 análisis distintos** (la última ni mencionó el `Ca`) | Estructura rígida: **una viñeta por parámetro marcado, en el orden de la tabla**, sin intro ni cierre |

**Sobre el grupo — por qué no basta con listar los metales:** `Ca`, `Mg`, `Mo` y `Zn` son **aditivos** en casi
todos los componentes y **contaminantes** en Motor de Tracción. El prompt manda mirar **el grupo en el que la
tabla los pone**, y reconocer el pie de la matriz cruzada («_en Motor de Tracción son contaminantes_») para
leer por **encima** en las columnas MT.

**También se eliminó** la línea vieja sobre parámetros «inf» (*«un 🟥 sobre Zn/Ca/Na/Mg = elevado, NO falla
crítica»*): `Inf` ya no se imprime en las tablas, y esa línea era la que producía el *«como aditivo no se
considera crítico»*.

⚠ **Regla que se mantiene:** el nodo va **sin conocimiento**. Con Knowledge alucina (inventó un «Cr crítico»
que no existía). Es un nodo **Solicitud/AI Builder**, no «Crear respuestas generativas».

#### ⭯ Segunda pasada (25/09) — probado en Teams

✅ **Las direcciones salen bien:** el `P` como *«precaución, bajo límite»* y el `Zn` como *«crítico, alto»*.
Y los parámetros sin marca y los `—` ya **no** se mencionan.

🔴 **Pero falló en la matriz cruzada:** `/diagcompleto 3160` dijo *«Zn en MT LH, 40.2, crítico, **bajo
límite (aditivo)**»*. Ahí el `Zn` está bajo **Aditivos** y el pie que avisa de la excepción no bastó.
⚠ En `/ultimo` y `/condicionmt` el mismo `Zn` **sí** salió bien — ahí está bajo Contaminación. El fallo era
**solo de la tabla cruzada**, que es donde vive la excepción. Dos arreglos, uno en cada lado:

| Dónde | Qué |
|---|---|
| **La vista** (`vw_DiagnosticoMD`, sus 2 variantes) | el pie ahora **dice la dirección**: «_en las columnas de Motor de Tracción son contaminantes: ahí la alerta es por **encima** del límite_» |
| **El prompt** | regla nueva **«la excepción manda sobre el grupo»**, con ese mismo caso (`Zn 40.2` en MT LH) como ejemplo |

#### ⭯ El análisis se quedó corto — corregido

Salía telegráfico: *«Zn en MT RH, 70.7, crítico, alto»* y nada más. Se perdió lo que sí gustaba antes
(«tendencia al alza», «`Cu` sistémico»). Ahora **cada viñeta lleva dato + lectura**:

- **Columnas = fechas** → la dirección de la serie. *«salta de 6.4 a 114.0 y baja a 70.7, pero sigue sobre
  el límite»*, *«pico aislado»*, *«viene al alza desde junio»*.
- **El mismo parámetro en varios componentes** → una sola viñeta y se llama **sistémico**.
- **Cuánto se pasa** del límite cuando hay LP/LC. *«casi el triple del LC»*, *«apenas por encima del LP»*.
- Y **una** frase de cierre, solo si aporta algo que ninguna viñeta dijo.

⚠ **El esqueleto sigue fijo** (una viñeta por marca, en el orden de la tabla) a propósito: es lo que evita
volver a las 3 corridas con 3 análisis distintos. La riqueza entra **dentro** de cada viñeta, no en la
estructura.

**Te toca:** desplegar el DDL otra vez (cambió el pie de `vw_DiagnosticoMD`) y **re-pegar el prompt**.
Es **un solo prompt** para todos los módulos — no hay que tocar cada tema.

---

### ✅ E2 · El correo faltaba en `/ultimo` — **arreglado en el DDL**

No era aleatorio ni dependía del prompt. De las **5** vistas que arman el bloque de recomendaciones,
**cuatro** cerraban con el párrafo de monitoreo + el correo y **una no tenía ninguno de los dos**:

| Vista | Párrafo de cierre + correo |
|---|---|
| `vw_DiagnosticoMD` · `vw_CondicionMT_MD` · `vw_TendenciaMD` · `vw_TriageMD` | ✅ |
| **`vw_UltimoAnalisisMD`** | ❌ **faltaba entero** |

Por eso salía en unas respuestas y en otras no, según el módulo. Agregado el mismo texto literal que las
otras cuatro — un `+` en la concatenación, sin tocar lógica.

⚠ **El mensaje de fallback** («Sin parámetros de Motor de Tracción fuera de límite…») **no lleva correo en
ninguna vista**, y así se queda: si no hay nada que escalar, no hay a quién escribirle.

✅ **Verificado (BLOQUE 119):** en `CA3160`/`CA3161`/`CA3177` las filas con recomendación real (919 chars)
traen el cierre y el correo. Las de 127 son el mensaje de fallback y van sin correo, en todas las vistas.

⚠ **Y la consulta (2) había que reescribirla:** leía las 3 vistas MD **enteras** para mirar un texto fijo
— 12 minutos sin devolver nada, porque `vw_DiagnosticoMD` cuesta ~2,4 s por equipo × ~306 equipos. El
correo es un **literal de la definición**: ahora se comprueba en `sys.sql_modules`, sin ejecutar una sola
fila. Misma lección que el BLOQUE 89 y que la nota de método del bloque C — y la volví a pisar.

---

### ✅ E3 · El MISMO valor salía **marcado** en `/ultimo` y **sin marcar** en `/diagcompleto` — arreglado (25/09)

`CA3160`, rueda delantera derecha, los dos módulos, el mismo día:

| Parámetro | LP | LC | Valor | `/ultimo 3160 rdrh` | `/diagcompleto 3160` col. RD RH |
|---|---|---|---|---|---|
| `Ca` | 2 080 | 1 560 | 176.3 | 🟥 crítico | **sin marca** |
| `Zn` | 960 | 720 | 1.6 | 🟥 crítico | **sin marca** |
| `Mg` | 12 | 9 | 2.3 | 🟥 crítico | **sin marca** |
| `Na` | 4 | 5 | 6.8 | 🟥 crítico | 🟥 crítico |

El `Na` coincide y los otros tres no. Eso señala la causa exacta: **el `Na` no está invertido y los otros sí.**

**Hay dos mecanismos de marcado conviviendo:**

| Vista | Cómo marca | Resultado |
|---|---|---|
| `vw_UltimoAnalisisMD` | con `vw_FormatoParametro.Inv` — en **Aditivos** la alerta es por **debajo** | ✅ correcto |
| `vw_DiagnosticoMD` · `vw_CondicionMT_MD` | con el sufijo `:C`/`:P` de `Estado_<metal>`, escrito **solo como «por encima»** | ❌ se le escapan los aditivos agotados |

⚠ **Por eso no lo habíamos visto:** en **Motor de Tracción**, `Ca`, `Zn` y `Mg` son **contaminantes**, y ahí
«por encima» es lo correcto. El desacuerdo solo aparece en **rueda, mando, transmisión, hidráulico y motor**
— y todas las pruebas de esta ronda fueron sobre MT.

⚠ **Y es el mismo tema que E0**, un nivel más abajo: allá el **contador** no coincidía con las celdas; acá son
las **celdas de dos módulos** las que no coinciden entre sí.

**BLOQUE 121** mide cuántas celdas quedan sin marcar hoy y deja las dos opciones:
- **(a) En la fundación** — que `Estado_<metal>` respete la dirección según el componente. Es el arreglo de
  raíz y lo hereda todo. ⚠ Mueve los conteos de flota, igual que el aviso de E0.
- **(b) Solo en `vw_DiagnosticoMD`** — que calcule la marca con valores + límites + `Inv`, como
  `vw_UltimoAnalisisMD`. Acotado, pero deja **dos mecanismos vivos**, que es justo lo que causó esto.

#### ✅ Medido y **arreglado** el 25/09

**BLOQUE 121 lo acotó, y resultó chico:** **53 componentes / 27 equipos**, y **solo en RUEDA**, para `Ca`,
`Zn` y `Mg`. En hidráulico y motor los valores están por encima del LC invertido, así que ahí no hay
desacuerdo. ⇒ arreglarlo **no** era un cambio masivo, así que se hizo **(a)**, el de raíz.

**Cómo:** `Estado_Ca`, `Estado_Zn` y `Estado_Mg` en `vw_MuestrasEstado` miran la **dirección del límite**.
Y la dirección no se decide con una lista de componentes: **si `LP > LC`, el límite está invertido**. Así lo
define el Excel del área, y así ya lo leía `vw_UltimoAnalisisMD` vía `Inv`. Un solo sitio, y lo heredan
`/diagcompleto`, `/condicionmt` y todo lo que lea la fundación.

⛔ **Solo esos 3 metales, y esto importa:** el BLOQUE 104 encontró un `LP`/`LC` invertido **por typeo** en el
`Pb` de `CERRO VERDE MT LH 980E` (LP=2, LC=1). Generalizar la regla a todos los parámetros daría ese typo por
aditivo. Se limita a los tres que el Excel sí pone en **Aditivos** fuera de MT.

✅ **Y no mueve los números de flota:** `Estado_General` sigue sin mirar `Ca`/`Zn`/`Mg`, así que triage,
barrido y conteo dan lo mismo. El **BLOQUE 122 (5)** lo comprueba en vez de suponerlo.

✅ **Y el aviso al Carlos no crece**, al revés de lo que anticipé: siguen **111 de 306** equipos con algún
componente observado, los mismos del BLOQUE 120. Los 27 equipos de RUEDA **ya contaban** por el `Na`, que sí
estaba marcado. Lo que cambió es **qué** se ve dentro de cada uno, no cuántos son.

#### ✅ Verificado — BLOQUE 122 (25/09)

| Prueba | Resultado |
|---|---|
| `CA3160` RD LH / RD RH en la fundación | `Ca 171.3:C / 176.3:C` · `Zn 0.3:C / 1.6:C` · `Mg 1.2:C / 2.3:C` — antes **sin marca** |
| `CA3160` MT LH | sigue con `Zn 40.2:C` — contaminante, por **encima** |
| `/ultimo 3160 rdrh` vs `/diagcompleto 3160` | **de acuerdo**: los dos marcan `Ca`, `Zn` y `Mg` en RD RH |
| El pie (E4) | RUEDA → el mensaje nuevo · MT LH → la recomendación de Zinc · MT RH → el de siempre. Los **3** casos |
| `Estado_General` | `OK` 1 284 · `CRITICO` 230 · `PRECAUCION` 107 = los mismos 1 621 del BLOQUE 118 |

✅ **La dirección se decide sola:** el mismo `Zn` sale **por encima** en MT y **por debajo** en rueda, sin
que ninguna vista tenga una lista de componentes. Era lo que pedías: dinámico, no cableado.

### ✅ E4 · El pie de recomendaciones contradecía la tabla fuera de MT — arreglado (25/09)

En ese mismo `/ultimo 3160 rdrh`, con **4 parámetros fuera de límite** en pantalla, abajo dice:

> 🔧 Recomendaciones Técnicas — _Sin parámetros de Motor de Tracción fuera de límite — sin recomendaciones
> aplicables por ahora._

**No es falso** — `vw_Recomendaciones` solo tiene texto para Motor de Tracción, y el `om` de la vista filtra
`Compartimiento LIKE '%TRACCION%'`. Pero **leído debajo de una tabla con 4 marcas rojas parece un bug**, que es
exactamente el patrón que venimos persiguiendo toda la ronda.

✅ **Arreglado el 25/09**, en las **dos** vistas que lo mostraban:
> _Las recomendaciones técnicas hoy solo están definidas para Motor de Tracción. Este componente sí tiene
> parámetros fuera de límite — ver la tabla._

| Vista | Caso | Mensaje |
|---|---|---|
| `vw_UltimoAnalisisMD` | componente **es** MT | el de siempre |
| `vw_UltimoAnalisisMD` | componente **no** es MT | _«…solo están definidas para Motor de Tracción. Lo que esté fuera de límite en este componente aparece marcado en la tabla.»_ |
| `vw_DiagnosticoMD` | equipo sin hallazgos en MT | _«…y sus MT no tienen parámetros fuera de límite. Lo observado en los demás componentes aparece marcado en la tabla.»_ |

⚠ Son **tres** casos, no dos. El que faltaba era el tercero, y es el que hacía parecer un bug lo que no lo era.

### ⭯ Dos ajustes más del prompt (25/09, tras la última prueba)

1. 🔴 **Inventó otra marca:** *«TBN por debajo del límite en MT RH (0.0), crítico»*. Ese `0.0` **no tiene
   emoji** en la tabla. La regla ya está en el prompt (*«si el emoji no está pegado al número, la celda no
   está marcada; un 0.0 sin emoji es un valor normal»*) — **falta re-pegarlo**.
2. **Lectura temporal donde no hay tiempo:** dijo *«es un pico aislado»* sobre la matriz de **componentes**,
   que no tiene fechas. Regla nueva: «al alza», «pico aislado» y «viene subiendo» **solo** cuando las
   columnas son fechas.

✅ **Lo que sí salió bien en esa prueba:** el `Zn` de MT LH como **alto** (la excepción del pie funcionó), el
`Na` de las dos ruedas en **una sola viñeta** («_afecta al par, no a una sola rueda_»), la frase de cierre con
el patrón, y en `/ultimo` los aditivos leídos **por debajo** con su porcentaje.

---

### ⭯ Tercera pasada del prompt (25/09) — la matriz cruzada otra vez, y al revés

✅ **`/ultimo` y `/condicionmt` quedaron bien:** en `/ultimo 3160 rdrh` el `Ca` salió *«muy bajo (176.3, LC
1560): el aditivo está prácticamente agotado»* — exacto.

🔴 **Pero `/diagcompleto 3160` leyó esos mismos aditivos como «altos»:** *«Ca alto en RD LH y RD RH (171.3 y
176.3)… superan el límite»*. Es el **mismo dato** que `/ultimo` describe como agotado.

**Por qué pasó, y es culpa de mi arreglo anterior:** la matriz cruzada **no trae columnas LP/LC**, así que el
modelo no puede comprobar la dirección con los números — depende del pie. Y el pie que escribí ayer solo
decía la mitad: *«en Motor de Tracción… la alerta es por encima»*. El modelo aplicó ese «por encima» a
**todas** las filas de `Ca`/`Mg`/`Mo`/`Zn`, también en las columnas de rueda.

**Arreglado diciendo las dos direcciones, no una:**
> _`Ca`, `Mg`, `Mo` y `Zn` cambian de sentido según la columna: en **Motor de Tracción** son
> **contaminantes** y la alerta es por **ENCIMA**; en **los demás componentes** son **aditivos** y la alerta
> es por **DEBAJO** (el aditivo se agota)._

Y en el prompt, la regla equivalente con **un ejemplo de cada lado** (`Zn 40.2` en MT → alto · `Ca 176.3` en
RD RH → agotado), más el aviso de que esa tabla **no tiene LP/LC** para verificar.

**Dos cosas más de las 3 corridas:**
- La tercera **omitió el `TBN`** que las otras dos sí listaron. Regla nueva: **si hay 5 marcas salen las 5**,
  siempre las mismas.
- Describió el `TBN` como **crítico** cuando la celda es de precaución. Regla nueva: **la severidad no se
  cambia** — 🟥 es crítico y 🟨 es precaución, tal como esté en la celda.

⚠ **Lección, porque ya van dos veces con esta tabla:** la matriz cruzada es **la única** salida sin LP/LC.
Todo lo que el modelo no pueda verificar con números tiene que estar **dicho entero** en el pie — media
explicación es peor que ninguna, porque se generaliza mal.

---

### Validación de E
| # | Prueba | Esperado |
|---|---|---|
| 1 | `/tendenciadet 3161 mt rh` | el `P` se describe como **bajo/agotándose**, nunca «por encima» |
| 2 | `/condicionmt 3161` | el `Zn` (contaminante en MT) se describe como **alto**, y el `P` sin marca **no se menciona** |
| 3 | `/diagcompleto 3160` × 3 veces | las 3 corridas listan **los mismos** parámetros marcados |
| 4 | Un equipo sin nada marcado | **una** línea, sin párrafos de relleno |
| 5 | `/ultimo` con recomendaciones | el correo aparece, igual que en `/condicionmt` |
| 7 | `/condicionmt 3161` | el encabezado dice **1 de 2 observados**, no 0 |
| 8 | `/diagcompleto 3160` | ya **no** dice «(ninguno fuera de límite)»: tenía `Zn` y `Na` marcados |
| 9 | `/ultimo 3160 rdrh` vs `/diagcompleto 3160` | el `Ca`, el `Zn` y el `Mg` de RD RH salen **igual** en los dos (**E3**) |
| 10 | `/ultimo` de un componente que no es MT | el pie explica que las recomendaciones son solo de MT, **sin negar** los hallazgos (**E4**) |
| 11 | La matriz de componentes | **no** aparecen «pico aislado» ni «al alza»: ahí no hay fechas |
| 6 | Cualquier tabla con `—` | no se menciona la falta de datos |

---

## 🏁 🅵 Bloque F — P1 · la familia «tendencia» · **CERRADO DEFINITIVAMENTE (25/09)**

Era el bloque más grande que quedaba y el único pedido que gerencia repetía desde el 18/09.

**El pedido de F eran DOS cosas**, y conviene tenerlo claro porque lo demás fueron extras que salieron
por el camino:

1. **Fusionar `/tendencia` + `/tendenciadet`** — ✅ hecho y probado en Teams.
2. **El cuadro de `/tendencia` encima de `/grafica`** — ✅ hecho y verificado. (La primera versión fue un
   subtítulo de una línea; el pedido era **el cuadro entero**, y así quedó.)

**Los extras:** `Σvida` con nº de muestras (F4.1 ✅) · el resumen estadístico como continuación (✅) · y
`Proyecto` en la clave del acumulado (F4.2) — 🔴 **revertido**: causó el timeout de `/tendenciametal`.

⚠ **Lo primero que se descubrió al estudiarlo, y por eso conviene que quede escrito:** `/tendencia` **no es
un tema, son cinco** para el mismo par equipo+componente. El pedido decía «fusionar dos».

### Lo que había — y en qué quedó cada pieza

| Tema | Comando | Vista · columna | ¿Análisis? | Qué imprime |
|---|---|---|---|---|
| **05** Tendencia (paso 1) | `/tendencia` | `vw_TendenciaP1MD` · `MD` | no | ➡ **se desactiva**. Su tabla de contexto vive ahora en la columna **`MD_Contexto`**, que el módulo fusionado embebe |
| **06** Tendencia detalle | `/tendenciadet` | `vw_TendenciaMD` · `MD` | sí | ⭐ **el que sobrevive**: ahora imprime contexto + matriz + límites. El resumen estadístico salió a `MD_Estadistica` |
| **07** Tendencia relevantes | — | `vw_TendenciaMD` · `MD_Relevantes` | sí | **sin cambios** — sigue siendo la respuesta a «solo los fuera de límite» |
| — **nuevo** | — | `vw_TendenciaMD` · **`MD_Estadistica`** | no | el resumen estadístico, **como continuación**. Una columna, no un tema |
| **09** Gráfica de un metal | `/grafica` | `vw_TendenciaGraficoMD` | no | la curva de UN metal, ahora con **el cuadro de `/tendencia` encima** (F3) |
| **10** Gráficas de observados | — | `vw_TendenciaGraficoObsMD` | no | idem, **con el cuadro encima** y explicando cuando no hay nada que graficar |

---

### ✅ F1 · La fusión — **HECHA y verificada (BLOQUE 126)** · 🔴 con un costo que hubo que atacar

**Cómo quedó el módulo único** (columna `MD` de `vw_TendenciaMD`):

1. El **encabezado y la tabla de contexto** de `/tendencia` — `SMR`, `Hrs Aceite`, `Hrs Comp`, `CM`,
   `Estado`, `Grado` por muestra.
2. **Detalle por parámetro** — la matriz × 6 fechas con `Σvida (nº m.)` y `Spark`.
3. **Límites de referencia** y la nota de `Σvida`.
4. La oferta de continuar: **resumen estadístico** o **gráfica**.

✅ **El contexto se EMBEBE, no se recalcula.** `vw_TendenciaP1MD` gana una columna `MD_Contexto` (su mismo
encabezado y su tabla, sin la pregunta de cierre) y `vw_TendenciaMD` la inserta. La lógica del contexto
sigue viviendo en **un** sitio — es la misma disciplina que `vw_FormatoParametro`.

✅ **El resumen estadístico salió a `MD_Estadistica`**, una columna nueva. Mismo patrón que
`MD_Relevantes`: **una columna más, no un módulo más**. En Copilot es un `columna=MD_Estadistica` en el
flujo, nada de temas nuevos.

⚠ **`LEFT JOIN` + `ISNULL` a propósito:** si P1 no tuviera fila para ese componente, el `MD` **no puede**
quedar `NULL`. Hay un título de respaldo. La consulta (6) del bloque lo comprueba.

#### ✅ Verificado — BLOQUE 126 (25/09): el tamaño salió **clavado**

| | Antes | Ahora |
|---|---|---|
| El bloque principal | 91 líneas | **65** · 2 976 chars |
| El resumen estadístico | dentro | **28 líneas aparte** (`MD_Estadistica`) |
| `MOTOR`, el supuesto caso peor | — | **también 65 líneas** |
| Los 6 componentes | — | todos con texto: 3 123 · 2 976 · 2 985 · 3 131 · 3 167 · 2 988. **Ninguno `NULL`** |
| `MD_Relevantes` · P1 | 419 · 642 | **iguales** — nada se rompió |
| `MD_Contexto` | — | **554** = 642 menos la pregunta de cierre, justo lo que se quería separar |

💡 **`MOTOR` no resultó el caso peor.** Tiene 27 parámetros contra 23 de MT, pero su tabla de **límites es
más corta**, así que sale igual de largo. El número de parámetros no predice las líneas: hay que medir.

#### 🔴 El costo, y cómo se atacó — **BLOQUE 127**

La consulta (4) dio **6 519 ms · 8 scans de `LaboratoryData` · 27 014 lecturas**. 6,5 s por componente es
alto para el módulo que más se usa.

**Y la causa no era la fusión:** `vw_TendenciaP1MD` leía la fundación **dos veces** — su `base` y su `unpv`,
para la misma ventana de 6 muestras. Al embeber P1, esas dos lecturas entraron en `vw_TendenciaMD`.
Es el **anti-patrón del BLOQUE 117 otra vez**: un CTE no se materializa, cada referencia lo re-ejecuta.

**El arreglo:** `base` se lleva las 6 columnas de contexto (`Horometro`, `HorasDeAceite`, `HorasComponente`,
`CM`, `Grado`, `Estado_General`) y `unpv` pasa de `FROM vw_MuestrasRankeadas d JOIN base b` a **`FROM base b`**.
Una lectura en vez de dos, y **no cambia ni un carácter** de la salida.

#### ✅ Verificado — BLOQUE 127 (25/09): equivalencia **perfecta**, mejora **parcial**

| | Antes | Después |
|---|---|---|
| Tiempo | 6 519 ms | **5 764 ms** (−12 %) |
| `LaboratoryData` | 8 scans / 27 014 | **7 scans / 25 650** |
| La salida | — | **exacta**: P1 642 · Ctx 554 · fusionado 2 976 / 65 líneas · los 6 componentes idénticos |
| `/tendencia` suelto | — | **1 571 ms** · CPU 235 ms · 2 scans / 2 728 lecturas |

⚠ **Lectura honesta: esperaba 8 → 6 scans y solo bajaron a 7.** El motivo es el de siempre — dentro de P1,
`base` **también es un CTE** y lo referencian `unpv`, `hdr` y `meta`. Quitar la lectura explícita de
`vw_MuestrasRankeadas` eliminó **una**, pero `base` se sigue re-ejecutando. Es el mismo límite que en el
BLOQUE 117: la re-ejecución **se mueve un nivel arriba**, no desaparece.

**Bajar de ahí** exigiría reestructurar P1 a **una sola pasada con funciones de ventana**, como se hizo en
el barrido. Es un cambio mayor para un módulo que ya responde.

✅ **Se toma la mejora y se cierra F en SQL.** 5,8 s por componente es aceptable — el barrido de flota se
aceptó en 19,5 s y `/diagcompleto` da 6 componentes en 2,4 s. Queda anotado el margen por si molesta.

### F1 · El diseño — qué se junta y qué **no**

**Se fusionan 05 + 06.** El módulo único imprime, en este orden:
1. El **encabezado** de 05 (`**Tendencia — CA3161 · MT RH** · últimas 6 muestras`).
2. La tabla de **contexto** de 05 (`Campo × fechas`) — es lo que da sentido a los números.
3. La **matriz** de 06 (`Par × 6 fechas` + `Σvida` + `Spark`).
4. La tabla de **límites** y el **resumen estadístico** de 06.

⛔ **NO se fusionan 07 ni 10**, y conviene decir por qué para no re-discutirlo:
- **07** es la **misma vista con otra columna** (`MD_Relevantes`). Es la respuesta a *«solo los que están
  fuera de límite»*, que es una pregunta distinta, no un paso del mismo flujo. Se queda como continuación.
- **10** es la continuación **gráfica**. Meterla dentro alargaría el mensaje sin que nadie lo pidiera.

**El nombre:** el módulo fusionado se queda con **`/tendencia`**, y **`/tendenciadet` pasa a alias**.
⛔ **Su nodo del dispatcher no se borra** — arrastraría la cadena de `else` (regla del 24/09 en el bloque D).
Se le cambia el destino al tema fusionado, igual que se hizo con `/diagnostico` → `/diagcompleto`.

**Qué tema sobrevive:** el **06**, que ya tiene el nodo de análisis y la vista con las 4 tablas. El 05 se
**desactiva** (no se borra, como el 23 y el 24) y su tabla de contexto se mueve a `vw_TendenciaMD`.
⚠ Así el trabajo queda **todo en SQL**: una vista que gana una tabla al principio, y en Copilot solo se
re-apunta un nodo y se cambian dos descripciones.

#### F1.b · 🔴 Medir el payload ANTES de construirlo — **BLOQUE 123**

El módulo fusionado tendría **4 tablas seguidas**, y la matriz ya **creció** con el bloque C: de 18
parámetros fijos a **23** en MT (y hasta 31 en la cruzada).

#### ✅ Medido — BLOQUE 123 (25/09): **cabe de sobra, pero es largo**

| | Medido |
|---|---|
| Contexto (P1) | **649** chars · 11 líneas |
| Detalle (matriz + límites + estadística) | **3 155** chars · 80 líneas |
| **El módulo fusionado** | **~3 800 chars · 91 líneas** |
| Techo del canal | ~28 000 chars — **sobra un factor 7** |

✅ **El límite no es el problema.** 🔴 **Las 91 líneas sí**, y el criterio que habíamos escrito era ~60.

**Decisión:** el detalle son **3** tablas — matriz (~29 líneas) + límites (~19) + resumen estadístico (~26).
⇒ **sacar el resumen estadístico** del bloque y dejarlo como **continuación** baja a **~65 líneas**.
⛔ **No se recorta la matriz ni los límites**: son el dato y su referencia, y la matriz completa es
exactamente lo que pidió Carlos.

🔴 **Y la medición fue del caso cómodo, no del peor:** los parámetros por formato son **(CRUZADO) 31 · MOTOR 27 · RUEDA/HIDRÁULICO/MANDO/TRANSMISIÓN 25 · TRACCIÓN 23**. Medí sobre **MT**, que es **el más chico**. `MOTOR` tiene 4 parámetros más × 3 tablas ≈ **+12 líneas** → del orden de **103**, no 91. No cambia la decisión: la refuerza.

⚠ **Y el BLOQUE 123 (2) no terminaba** — pedía `vw_TendenciaMD` de 5 equipos **sin filtrar componente**:
5 × 6 = **30 renders**. Reescrito: primero la tabla de formato (instantánea) para **elegir** el caso peor, y
después **un** render de ese componente. Regla que me llevo: un bloque de validación se optimiza **al
escribirlo**, no cuando se cuelga.

---

### F2 · Resumen analítico gerencial — **ya casi no hay que hacer nada**

Era el pedido más fuerte de gerencia: *highlights + tendencia + **el porqué***.
✅ **El bloque E ya lo resolvió a nivel de prompt:** cada viñeta lleva **dato + lectura**, y para tablas con
columnas de fecha la lectura es justamente la dirección de la serie (*«viene al alza desde junio»*, *«salta
de 6.4 a 114.0 y baja a 70.7, pero sigue sobre el límite»*, *«pico aislado»*).

**Lo único que queda de F2:** que el módulo fusionado **lleve el nodo de análisis**. Sale gratis si el tema
que sobrevive es el **06**, que ya lo tiene. Si se hiciera al revés (sobrevive el 05), habría que agregarle
los 3 nodos.

---

### ✅ F3 · El cuadro de `/tendencia` **arriba de la gráfica** — rehecho y verificado (BLOQUE 130)

🔴 **Lo había entendido mal.** Puse un **subtítulo de una línea** (`*Mod. · Lubric. · SMR · Hor.Comp.*`),
y el pedido era **el mismo cuadro que muestra `/tendencia`** — la tabla `Campo × fechas` completa —
**encima de la gráfica**. Es la misma idea de la fusión, aplicada a `/grafica`.

**Cómo quedó ahora** — `/grafica 3160 mtlh Fe`:

1. `**Tendencia — CA3160 · MT LH** · últimas 6 muestras`
2. La tabla **`Campo × fechas`**: `SMR`, `Hrs Aceite`, `Hrs Comp`, `CM`, `Estado`, `Grado`
3. `**Gráfica de Fe**`
4. La fila del parámetro · los límites · el bloque con la curva

✅ **Se embebe de `p1.MD_Contexto`**, la misma columna que usa el módulo fusionado — una sola definición.
✅ Aplica igual a **`vw_TendenciaGraficoObsMD`** (las gráficas de observados).
✅ El subtítulo viejo **desaparece**: la tabla ya trae el lubricante y las horas, y con más detalle.

🔴 **Y esto hay que medirlo antes de darlo por bueno.** Cada vista de gráficas gana un `LEFT JOIN` a P1,
o sea **una lectura más** — exactamente el mecanismo que tumbó `/tendenciametal` esta mañana.

#### ✅ Verificado — BLOQUE 130 (25/09), medido **con el operador del flujo**

| Prueba | Resultado |
|---|---|
| `/grafica` | el cuadro arriba, luego «Gráfica de Fe», la fila, los límites y la curva — **el orden pedido** |
| Costo con `LIKE` | **21 506 ms** · umbral era 60 s → **pasa con holgura** |
| Gráficas de observados | mismo cuadro arriba · **11 001 ms** |
| Los 6 componentes | `Motor` 714 · `MT LH` 2 158 · `MT RH` 2 963 · `RD LH` 4 475 · `RD RH` 5 286 · `Sist. Hidr.` 696 — **ninguno `NULL`** |
| Sin daños | `TendenciaMD` 2 976 · `TendenciaMetalMD` 1 117 |

✅ **Los dos cortos (`Motor`, `Sist. Hidr.`) son los que NO tienen metales observados:** conservan el cuadro
y explican que no hay nada que graficar.

⚠ **El `LEFT JOIN` a P1 se temía por lo de `/tendenciametal`, y aquí no duele.** La diferencia es que las
vistas de gráfica trabajan sobre **un** componente, no sobre los seis. Por eso la regla no es «no agregar
joins» sino **medir cada caso con el operador de producción**.

✅ **Con esto el SQL del bloque F queda cerrado.** Lo que falta es Copilot: pasos 6, 7 y 8 de la lista.

---

### ✅ F4 — **CERRADO (25/09)**: desplegado y verificado (BLOQUE 124)

✅ **Y el BLOQUE 99 quedó corrido de paso**, que llevaba pendiente desde el bloque B: `Σvida` trae número
**solo** en `Fe 3718.7 · PQ 1462.6 · Cr 19.1 · Ni 5.8 · Cu 17.5 · Pb 11.9 · Sn 5.4 · Al 4.4`, y `—` en todo lo
demás. El resumen estadístico y `vw_TendenciaMetalMD` dicen lo mismo (`Fe` con Σ, `Si` con `—` en los seis
componentes).

| | Qué se hizo |
|---|---|
| **F4.1** | la celda pasa de `3718.7` a **`3718.7 (26)`** y el encabezado de `Σvida` a **`Σvida (nº m.)`** — **4 celdas** y **5 encabezados** entre `vw_TendenciaMD` y `vw_TendenciaMetalMD` |
| 🔴 **La trampa** | se cumplió: `vw_TendenciaMetalMD` lee un CTE con **lista explícita**. `NmAcum` agregado ahí — sin eso, la vista compila y revienta al consultarla |
| **F4.2** | `Proyecto` entra en la clave de `acc`: `sa` → `acc` → el `LEFT JOIN`. Hoy 0 colisiones, pero dos minas con el mismo código de equipo sumarían juntas |
| **F4.3** | nota al pie del resumen: **Σvida no se reinicia** al cambiar el componente, a diferencia de `/rankingacum` |

⚠ **El `—` de los que no son desgaste se queda sin `(n)`**: no hay nada que sumar, y poner `— (0)` sería ruido.

⚠ **Lo que sigue bloqueado es OTRA cosa:** el **universo** de la suma (el 6 785.39 dCarlos). F4 es el
**formato**; el universo es el bloque B y cuando llegue la respuesta es **una línea**.

#### ✅ Verificado — BLOQUE 124 (25/09)

| Prueba | Resultado |
|---|---|
| La trampa del CTE | `vw_TendenciaMetalMD` devuelve **1 117**, no `Invalid column name 'NmAcum'` |
| El formato | `3718.7 (27)` · `1462.6 (27)` · `19.1 (27)`… con encabezado `Σvida (nº m.)` y la nota al pie |
| ¿Cuadra el `(n)`? | muestras no-DDI del componente = **27** = el `(27)` de la celda |
| F4.2 sin efectos | `Fe 3718.7 · PQ 1462.6 · Cr 19.1 · Al 4.4`, **idénticos** al BLOQUE 99 → **0 colisiones** |
| El módulo por metal | `MT LH 3718.7 (27)` · `MT RH 3794.4 (27)` · `RD LH 452.9 (21)` · `Motor 266.6 (88)` |

💡 **El `(n)` resultó más útil de lo previsto:** el **Motor lleva 88 muestras** contra 21-27 de los demás.
Sin ese número, un lector compararía `Motor 266.6` con `MT LH 3718.7` como si fueran la misma escala. **No lo
son**, y ahora la tabla lo dice.

### ▶ Tu primer paso ahora

**El SQL de F está completo.** Queda **un** despliegue y **un** bloque:

1. **Desplegar `DDL_vistas.sql`** — trae el arreglo de la lectura doble de `vw_TendenciaP1MD`.
2. **Correr el BLOQUE 127.** Su **(1) va primero y es de equivalencia**: P1 debe dar **642** y el fusionado
   **2 976 chars / 65 líneas**, exactos. Si algo se movió, revertir — el cambio es de rendimiento y no puede
   tocar la salida. La **(2)** compara contra los **6 519 ms / 8 scans** del BLOQUE 126.
   ⚠ Correrla **dos veces** y quedarse con la segunda: la primera tras un `CREATE OR ALTER` paga la
   compilación (en el BLOQUE 120 fueron 1 830 ms de los 2 891).

**Y con eso F cierra en SQL.** Lo que queda de F es Copilot, detallado abajo en «Orden sugerido».

### Orden sugerido para F

| # | Paso | Dónde | Por qué en este orden |
|---|---|---|---|
| 1 | ~~**F4**~~ ✅ **CERRADO** (BLOQUE 124) | SQL | era el más acotado |
| 2 | ~~**F3**~~ ✅ **CERRADO** (BLOQUE 130): el cuadro entero, 21 s con el operador real | SQL | pasó el umbral de 60 s |
| 3 | ~~**BLOQUE 123**~~ ✅ **medido**: 91 líneas → la estadística sale del bloque | SQL | ya decidió cómo se compone F1 |
| 4 | ~~**F1**~~ ✅ **CERRADO** (BLOQUES 126 y 127) | SQL | con la medición ya en la mano |
| 5 | Copilot: re-apuntar `/tendencia`, alias `/tendenciadet`, desactivar el 05, la continuación con `columna=MD_Estadistica`, descripciones, tarjeta | Copilot | al final, como siempre |

⚠ **Los pasos 1 a 4 son SQL puro.** Se puede llegar hasta ahí sin abrir Copilot Studio, que es como se
trabajó bien los bloques C y D.

### ▶ Lo que queda de F en Copilot Studio

➡ **Está en la lista única de arriba** («COPILOT STUDIO — la lista completa»), **PASO 5**.
No se repite aquí a propósito: había dos versiones y se contradecían.

### Vistas que toca F
`vw_TendenciaMD` · `vw_TendenciaP1MD` · `vw_TendenciaElemento` · `vw_TendenciaMetalMD` ·
`vw_TendenciaGraficoMD` · `vw_TendenciaGraficoObsMD`

⚠ **`vw_TendenciaElemento` y `vw_TendenciaMD` ya se tocaron en el bloque C** (formato por componente y los
encabezados de grupo por `ROW_NUMBER`). **Releer cómo quedaron antes de editar** — no son las de la semana
pasada.

### Temas que toca F
**05** (se desactiva) · **06** (sobrevive y absorbe) · **09** y **10** (encabezado) ·
y el dispatcher, **sin borrar ningún nodo**.

### Validación de F
| # | Prueba | Esperado |
|---|---|---|
| 1 | `/tendencia 3161 mt rh` | contexto **y** matriz en una sola respuesta |
| 2 | `/tendenciadet 3161 mt rh` | responde **lo mismo** (alias) |
| 3 | El análisis de esa respuesta | menciona la **dirección** de la serie, no solo el valor |
| 4 | `/grafica 3161 mt rh Fe` | la curva llega **con encabezado** de equipo y componente |
| 5 | «la gráfica» tras una tendencia | idem en las gráficas de observados |
| 6 | `Σvida` en la matriz | sale `3207.0 (26)` y `—` en lo que no es desgaste |
| 7 | `/tendenciametal 3161 Fe` | **no** revienta con `Invalid column name 'NmAcum'` |
| 8 | Longitud de la respuesta fusionada | ✅ **65 líneas** (BLOQUE 126), de 91 |
| 9 | El resumen estadístico como continuación | llega con `columna=MD_Estadistica`, sin tema nuevo |

---

## 🏁 🅶 Bloque G — ruteo · **CERRADO (25/09)**

**Va al final a propósito:** cada módulo que cambió de nombre o de alcance en A–F pudo introducir un cruce
nuevo. Hacerlo antes obligaba a repetirlo.

⚠ **Y ahora hay más candidatos que cuando se escribió:** `/tendencia` absorbió al 05, `/diagcompleto`
absorbió al 03, y hay un tema nuevo (resumen estadístico) que compite con `/tendencia` y con el 07.

---

### ✅ G1 · `/acumulados` sin nada se confundía con `/rankingacum` — **CERRADO y probado (25/09)**

**El problema, tal cual:** el orquestador rutea **solo por descripción**, y las dos decían «ACUMULADOS del
motor diésel» en la primera línea. Cuando alguien dice «acumulados» a secas, no hay nada que las separe.

**El arreglo es de descripciones y nada más.** Cada una dice ahora, **en la primera línea**, lo que la otra
no hace, y una de las dos se declara **la del caso ambiguo**:

**Tema 28 · Acumulados de un equipo** (**558** UTF-16, margen 466):

> ACUMULADOS de UN equipo concreto (motor diésel): el desgaste ACUMULADO por metal (Fe, Cr, Pb, Cu, Na, K, Si sumados en la vida del motor actual), con serie del motor, horas motor/metal, score y Estado. ⛑ **Requiere el código del equipo**: si no lo nombran, NO es este tema. «acumulados del CA3177», «cuánto Pb lleva acumulado el motor del X», «el desgaste acumulado del motor del equipo X». Rellena equipo. ⛔ NO la flota ni un ranking, ni «acumulados» a secas (→ Ranking de acumulados). NO la última muestra (→ Último análisis). Hoy: Antapaccay motor diésel.

**Tema 27 · Ranking de acumulados** (**598** UTF-16, margen 426):

> RANKING DE ACUMULADOS de una flota/mina (motor diésel): TODOS los motores ordenados por desgaste ACUMULADO ponderado (Fe, Cr, Pb, Cu, Na, K, Si), con serie, horas motor/metal y Estado (Monitoreo/Atención/Alerta/Crítico). Es el «ranking de atención» del dashboard. ⚑ **Es el tema por defecto cuando dicen «acumulados» SIN nombrar un equipo.** «acumulados», «ranking de atención de Antapaccay», «acumulados de la flota», «qué motores tienen más desgaste acumulado». Rellena proyecto. ⛔ NO un equipo nombrado (→ Acumulados de un equipo), NO la última muestra (→ Barrido). Hoy: Antapaccay motor diésel.

✅ **La clave está en dos frases**, una en cada una:
- el 28 dice **«requiere el código del equipo: si no lo nombran, NO es este tema»**;
- el 27 dice **«es el tema por defecto cuando dicen «acumulados» SIN nombrar un equipo»**.

Un desempate así — uno se descarta y el otro se declara default — es lo que funcionó con los otros pares.

⚠ **El comando `/acumulados` no cambia:** sigue yendo al 28 por el dispatcher, que **sí** trae el equipo.
El cruce era solo por **lenguaje natural**. ⛔ No hay que tocar el nodo.

#### ✅ Probado en Teams (25/09) — **5 de 5**

| Escribir | Fue a | |
|---|---|---|
| «dame acumulados» | **27 Ranking** | ✅ |
| «ahora los acumulados de Antapaccay» | **27 Ranking** | ✅ |
| «ahora acumulados del CA3177» | **28 Equipo** | ✅ |
| `/acumulados 3175` | 28 Equipo | ✅ no-regresión |
| `/rankingacum Antapaccay` | 27 Ranking | ✅ no-regresión |

✅ **Y el cambio de contexto funciona**: en la misma conversación pasó de flota a equipo y volvió, sin
arrastrar el tema anterior.

---

### ⚠ Nota de alcance — lo de abajo **NO era el pedido de G**

El pedido de G era **uno**: `/acumulados` sin argumento se confunde con `/rankingacum`. Eso está arriba y
está cerrado.

Lo que sigue (**G2** el barrido de fallos silenciosos, **G3** los parámetros que no se miden) lo abrí yo
mismo al ver el patrón repetirse. **Se quedó a medias a propósito:**
- ✅ **G2 modo A hecho:** los 2 fallos reales que quedaban están arreglados en el DDL (BLOQUE 134).
- ⏳ **G2 modo B y G3 quedan como backlog**, no como parte de esta ronda.

⚠ **Y el aviso que me llevo de esta ronda:** amplíe G por mi cuenta y eso costó tiempo y una consulta de
validación que hubo que abortar. **Lo encontrado se anota; ampliar el alcance se pregunta.**

---

### ⏳ G2 · Barrer el patrón «falla en silencio» — **backlog, no de esta ronda**

Van **3 casos** en esta ronda donde el sistema respondía «no encontré datos» y el dato existía, y los tres
aparecieron **de casualidad**:

| Caso | Realidad |
|---|---|
| Componente pegado (`mtlh`) | el componente existía, no casaba el texto |
| Muestras sin componente (66) | la muestra existía, faltaba el componente |
| Equipo sano (206 de 306) | **el equipo está bien** |

#### Hay DOS modos de fallo distintos, y se arreglan diferente

| Modo | Qué pasa | Síntoma |
|---|---|---|
| **A · `MD` NULL** | un `LEFT JOIN` trae `NULL` y **anula toda la concatenación** | el flujo recibe una fila con `md` vacío |
| **B · 0 filas** | el `INNER JOIN` o el `GROUP BY` no producen fila | el flujo recibe **nada** |

⚠ **Los dos acaban en el mismo mensaje** («no encontré datos»), y por eso se confunden. Pero el A se
arregla con `ISNULL`, y el B **no se puede arreglar con `ISNULL`**: hay que producir la fila igual, con un
mensaje que explique.

#### El barrido, ya hecho — **30 vistas `…MD`, 12 candidatas**

Estas usan una columna de cuerpo **sin `ISNULL`** en el `SELECT` final:

#### ✅ Modo A — **barrido hecho y los dos bugs reales, arreglados (25/09)**

De las 12 candidatas, **10 ya estaban protegidas** con `CASE WHEN … IS NOT NULL`. Quedaban **dos de
verdad**, y las dos son casos que un usuario encuentra sin buscarlos:

| Vista | Qué pasaba | A quién afecta |
|---|---|---|
| `vw_TendenciaMD` · `lb.bodyMD` | sin límites cargados, la tabla de límites viene `NULL` y **anula todo el MD** | 🔴 **45 combinaciones** proyecto+modelo sin límites — **Cuajone y Toquepala enteros** |
| `vw_ObservadosBarridoMD` · `ca`/`pa.Secciones` | sin críticos (o sin precauciones) el MD se anula | cualquier flota **sana**: `/barrido solo los críticos` |

⚠ **El segundo es el más perverso:** «no hay ningún crítico» es una **buena noticia**, y el sistema la
devolvía como si hubiera fallado.

**Mensajes nuevos:**
- *«Sin límites (LP/LC) cargados para este componente en este proyecto: los valores se muestran, pero no hay
  contra qué compararlos. ⚠ Esto **no** significa que estén dentro de límite.»*
- *«Ningún equipo de esta flota está en estado **crítico**. Los observados que hay son de precaución.»*

**Te toca: desplegar y correr el BLOQUE 134.** Sus (1) y (3) **buscan el caso** antes de probarlo — no
asumen que existe. Las (2) y (4) son no-regresión. La **(5)** cuenta nulos y es la que cierra el modo A.

| Vista | Modo probable |
|---|---|
| ~~`vw_CondicionMT_MD` · `vw_TendenciaMD`~~ | ✅ revisadas — `vw_TendenciaMD` arreglada; `vw_CondicionMT_MD` resultó ser **modo B** (el cuerpo va por `INNER JOIN`) |
| `vw_TendenciaP1MD` · `vw_HistorialMD` · `vw_HistorialMetalMD` · `vw_HistorialEquipoMD` · `vw_HistorialFlotaMD` · `vw_HistorialMetalEquipoMD` | **B** — sin `LEFT JOIN`: si no hay cuerpo, no hay fila |
| `vw_TriageMD` · `vw_TendenciaIncipienteMD` · `vw_TendenciaMetalFlotaMD` · `vw_CondicionCompMD` · `vw_UltimoMetalFlotaMD` · `vw_AcumuladosFlotaMD` · `vw_RankingGrafMD` | **B** |

⚠ **Candidatas, no culpables.** Varias ya están bien: `vw_TendenciaIncipienteMD` **sí** distingue «sin
límites cargados» de «ninguno observado» (lo probamos con Cuajone), y en `vw_TriageMD` la fila existe
siempre que el proyecto tenga muestras.

**La pregunta a hacerle a cada una, y es una sola:**
> **¿Qué devuelve cuando no hay nada que mostrar, y eso es distinguible de «no existe el equipo»?**

**Pasos:**
1. Empezar por las de **modo A** (`vw_CondicionMT_MD`, `vw_TendenciaMD`): son las más baratas de arreglar
   y las que más se usan.
2. Para cada una, un caso de prueba real donde el cuerpo quede vacío.
3. El mensaje tiene que decir **por qué** no hay tabla. Los tres que ya escribimos sirven de modelo:
   *«no tiene ningún componente observado»* · *«esta muestra no tiene componente registrado»* ·
   *«sin límites cargados: no hay contra qué comparar»*.
4. ⛔ **Nunca dejar el mensaje genérico** cuando se sabe la causa.

---

### ⏳ G3 · Los comandos con parámetro de METAL y los parámetros nuevos — **backlog**

Al adoptar el formato completo (bloque C) la tabla muestra parámetros que **la base no mide**. El usuario
los ve, así que los va a pedir.

**La lista exacta, sacada de `vw_FormatoParametro` (`Disponible = 0`):**

| Parámetro | En qué componentes aparece |
|---|---|
| `V40` · `Mo` · `Agua` | **todos** |
| `ISO>4` · `ISO>6` · `ISO>14` | todos menos Motor |
| `TAN` · `Oxidacion` | todos menos Motor / menos Tracción |
| `Hollin` · `Diesel` · `Refrigerante` · `Nitracion` · `Sulfatacion` | solo **Motor** |

**Comandos afectados:** `/grafica` · `/tendenciametal` · `/historialmetal` · `/ranking` · `/metalflota`.

**Los tres casos y su mensaje:**

| Caso | Qué responder |
|---|---|
| Está en el formato pero **no se mide** (`V40`, `Mo`…) | *«`V40` aparece en el formato pero **no se registra** en la base, así que no hay serie que graficar.»* |
| **No existe** ni en el formato (`Xx`) | el mensaje de siempre: no se reconoce el parámetro |
| Se mide pero **ese equipo no tiene datos** | *«no hay muestras de ese parámetro para este componente»* |

⛔ **Los tres son distintos, y hoy los tres dan «no encontré datos».** Es el mismo bug silencioso del
`mtlh`: el usuario no puede saber si se equivocó, si falta el dato o si el sistema falló.

**Dónde va:** lo más barato es **en la vista** (que devuelva la fila con el mensaje), igual que se hizo con
el equipo sano. En el tema solo haría falta si se quiere afinar el texto.

⚠ **Y hay una decisión de producto detrás:** si un parámetro no se mide **nunca**, ¿debe seguir
apareciendo en la tabla? Carlos dijo que **sí** («las filas del Excel van sí o sí»), así que la
respuesta es sí — pero entonces el sistema tiene que saber explicarlo cuando se lo pidan.

---

### Si algún día se retoma el backlog de G

| # | Paso | Por qué en este orden |
|---|---|---|
| 1 | **G3** | SQL puro, y cierra el hueco que abrió el bloque C |
| 2 | **G2 modo B** (las de flota) | más trabajo: cada vista necesita su propio mensaje |

### Validación de G
| # | Prueba | Esperado |
|---|---|---|
| 1 | `/acumulados` sin argumento | va a acumulados, no al ranking |
| 2 | «la tendencia del 3160 mt lh» | va al **06**, no a la gráfica ni al 07 |
| 3 | `/grafica 3160 mtlh Mo` | *«no se registra en la base»*, **no** «no encontré datos» |
| 4 | `/grafica 3160 mtlh Xx` | «no reconozco ese parámetro» |
| 5 | Un equipo sin muestras del metal pedido | el tercer mensaje, distinto de los dos anteriores |
| 6 | Cada vista de modo A con el cuerpo vacío | dice **por qué**, y nunca devuelve `MD` nulo |
| 7 | Repaso de los 6 pares de G1 | ninguno cae al fallback |

---

## Estado de las rondas anteriores — todas cerradas

| | Estado |
|---|---|
| **P4** Historial con rango | ✅ cerrado 21/09 |
| **P5** `/rankinggraf` | ✅ cerrado 22/09 |
| **P3** `/incipiente` generalizado | ✅ cerrado 23/09 (SQL + Copilot, probado) |
| **P2** Σvida | ⚠ se creyó cerrado el 22/09 → **reabierto**: es el bloque **B** de arriba |
| **P1** tendencia + gráfica | ➡ es el bloque **F** de arriba |

→ **Nada de las rondas viejas está en curso.** Lo único vivo es la ronda 23/09 (bloques A–G).
Las secciones de abajo se conservan como referencia de patrones ya probados, no como trabajo pendiente.

---

# ✅ P4 — Historial con parámetro RANGO · CERRADO (21/09)

> Cerrado por el usuario tras el fix del piso de año (`/historial CA3176 MT LH 999 años` → 41 muestras).
> Se conserva el paso a paso completo abajo como referencia del patrón (vistas `*FilasMD` + flujo genérico).

**Objetivo:** que el Historial y sus 5 variantes devuelvan **más filas según una ventana de fechas**
(«2 años», «5 meses», «14 días»). **Alcance de esta tanda: SOLO el rango.** El formato ancho de muchas
columnas es otra tanda (gerencia aún no entregó las columnas).

## Mapa de lo que se toca
| Tema | Nombre | Entradas hoy | Flujo · vista | Tope actual |
|---|---|---|---|---|
| 11 | Historial de componente | equipo, compartimiento | `MD_equipo_comp` · `vw_HistorialMD` | `rn_hist <= 12` |
| 12 | Historial general del equipo | equipo | `MD_equipo` · `vw_HistorialEquipoMD` | `grn <= 24` |
| 13 | Historial de un metal (equipo) | equipo, parametro | `MD_metal` · `vw_HistorialMetalEquipoMD` | `grn <= 24` |
| 14 | Historial de un metal en componente | equipo, comp, parametro | `MD_metal` · `vw_HistorialMetalMD` | `rn_hist <= 12` |
| 15 | Historial observados de flota | proyecto | `MD_flota` · `vw_HistorialFlotaMD` | `grn <= 24` |

## ⚠ Dos hallazgos del reconocimiento (20/09) que condicionan el diseño

**1. El filtro por fecha NO puede ir en el flujo.** Las vistas `*MD` devuelven **UNA fila** por
equipo/componente, con toda la tabla markdown ya concatenada dentro de `MD` (el `STRING_AGG` ocurre dentro de
la vista, y el tope `rn_hist<=12` se aplica **antes**). Cuando el flujo ve la fila, las muestras ya son un
string: su `WHERE` elige **qué equipo**, no **qué muestras**. Y una vista **no acepta parámetros**.

**2. El rango NO puede ser un parámetro posicional al final.** `/historial` usa `comp = resto2` (todo lo que
va después del equipo). Poner `[rango]` al final **rompería el fix del componente compuesto** («tracción LH»).
→ El rango se extrae **por patrón**, no por posición.

## Paso 0 — Elegir el mecanismo (BLOQUEANTE, decidir antes de tocar nada)

| | Cómo | A favor | En contra |
|---|---|---|---|
| **A · TVF** | `CREATE FUNCTION dbo.fn_HistorialMD(@equipo,@comp,@desde) RETURNS TABLE`; el flujo hace `FROM dbo.fn_…(…)` | rangos arbitrarios; SQL limpio; la vista sigue armando el MD | **no existe NI UNA función en la BD** (0 en el DDL, 0 en el schema) → **permiso sin verificar** |
| **B · Buckets preset** | `CROSS APPLY (VALUES (7),(30),(90),(180),(365),(730),(0)) v(dias)` dentro de la vista; el flujo filtra `AND Dias = ‹dias›`. Mismo patrón que `(todos)` para Modelo | cero permisos nuevos; patrón ya probado en el repo | **solo rangos preset** («5 meses» habría que redondearlo) · multiplica el trabajo de la vista ×7 ⚠ |
| **C · Vista de FILAS + agregación en flujo dedicado** ⭐ | `vw_Historial*Filas` expone **una fila por muestra** con `rowMD` ya armado + columnas de filtro; un flujo dedicado hace el `STRING_AGG` con `AND FechaMuestreo >= ‹desde›` y el `TOP` | **rangos arbitrarios**; cero permisos nuevos; respeta Tier 2 (el markdown lo arma SQL, no un LLM) | el encabezado/pie pasa al query del flujo |

**✅ RESUELTO (20/09): vamos por C.** Se probó A en SSMS y falló:
`CREATE FUNCTION permission denied in database 'bd_kmmp_osconfiabilidad'` (Msg 262). En esta BD solo tenemos
**CREATE OR ALTER VIEW + lectura** → **no hay forma de parametrizar una vista**, así que **A queda descartada
definitivamente** (no volver a proponerla) y **B** también (solo daría rangos preset).
→ **Camino: C.** Ya hay precedente de flujos dedicados con query propio (`MD_triage`, `MD_ranking`, `MD_acumflota`).

## Pasos

**1 · ~~Verificar permiso de función~~** ✅ HECHO — denegado (Msg 262). Camino confirmado: **C**.

**2 · Medir antes de fijar el tope** ✅ HECHO — **tope 200 confirmado con dato**
Medido (BLOQUE 71): **49 chars/fila prom · 59 máx** → 200 filas ≈ **11 800 chars** worst case, muy por debajo
de los ~28 000 del canal. Confirmado después de punta a punta: las **42 filas reales ocupan 2 290 chars**.

**3 · Piloto en UNA variante: Tema 11 (historial de componente)** ✅ VISTA CREADA Y VALIDADA
`vw_HistorialFilasMD` añadida a `DDL_vistas.sql`: **1 fila por muestra**, con `rowMD` **idéntico** al de
`vw_HistorialMD` (para que sin rango la salida sea byte a byte la misma) + columnas de filtro
`Equipo`, `Compartimiento`, `compAbbr`, `rn_hist`, `FechaMuestreo`. Tope interno 500 = **seguridad**; el
recorte real lo decide el flujo. Columnas cruzadas contra el schema: ninguna faltante.
**Resultados del BLOQUE 71 (20/09):**
- **Equivalencia: IDÉNTICO ✅** — `len 769 = 769` y mismo SHA-256 que `vw_HistorialMD`.
- **El rango aporta:** 14 días=1 · 5 meses=12 · **2 años=42** · sin rango=42 → hoy se perdían **30 muestras**.
- **Pie de recorte** funcionando: «_Mostrando las 12 más recientes de 42 en el rango._»
- **Tope CONFIRMADO en 200** con dato: **59 chars/fila máx** → 200 filas ≈ **11 800 chars**, muy por debajo
  de los ~28 000 del canal.
- ⚠ **Rendimiento corregido sobre la marcha:** la 1ª versión (tope 500 + CTE `obs` con `CROSS APPLY` +
  `GROUP BY` + `LEFT JOIN`) tardaba **3m25s / 5m22s**, mientras un `COUNT(*)` sobre la misma vista tardaba
  **6 s** → el costo era **computar `rowMD`**, no leer. Era el **mismo anti-patrón del barrido** (CTE + JOIN
  entre ramas), amplificado ×40 por el tope. **Fix:** `obsList` fila a fila con `STUFF(CONCAT(...))`, sin
  `GROUP BY` ni `JOIN` (patrón de `vw_ObservadosFlota.Mets_Obs`) + tope a 200. Bonus: el `STRING_AGG` original
  no tenía `WITHIN GROUP (ORDER BY)` → orden no determinista; ahora el orden está fijo.
→ **Pendiente de ti:** re-correr `DDL_vistas.sql` y el **BLOQUE 71 parte (6)** para confirmar que baja a
segundos y que la equivalencia **sigue** siendo IDÉNTICA (se reescribió cómo se arma la lista de metales).

**4 · Flujo dedicado `MD_historial`** ✅ CREADO (20/09) — 5 entradas + `concat(...)` en «Ejecutar consulta SQL (V2)»

⚠ Antes de pasar al 5, confirmar 3 cosas dentro del flujo:
- **4.a · Salidas en «Responder al agente»:** `md` = `first(body('Ejecutar_una_consulta_SQL_(V2)')?['resultsets']?['Table1'])?['MD']` ·
  `observados` = (vacío/NULL) · `recomendaciones` = (vacío/NULL). Las 3 de tipo **Texto**.
- **4.b · Reintentos = Ninguno** y **tiempo de espera `PT100S`** en la acción SQL
  (⋯ → Configuración). Sin esto, un query lento se reintenta 5× → 5-8 min ([CONFIG_TIMEOUT.md](CONFIG_TIMEOUT.md)).
- **4.c · Probar el flujo solo** (botón Probar) con: `vista=vw_HistorialFilasMD`, `equipo=CA3176`,
  `compartimiento=MT LH`, `desde=` (vacío), `tope=` (vacío). Debe devolver el MD con **42 filas** y sin pie.

---

**5 · Tema 11 «Historial de componente»** ✅ HECHO (20/09)

**5.1 · Nueva entrada del tema:** `rango` (Texto, **opcional**).
**Descripción (pegar):** *"Ventana de tiempo a consultar, tal como la diga el usuario (ej. «2 años», «5 meses»,
«14 días»). Vacío = sin límite de fecha."*

**5.2 · Nodo «Establecer valor de variable» ANTES de la Acción** — convierte el rango a fecha.
Crear `Topic.n` (Número) y `Topic.desde` (Texto):
```
Topic.n = If(IsBlank(Topic.rango) || Topic.rango = "", 0,
             Value(Match(Topic.rango, "\d+").FullMatch))
```
```
Topic.desde =
  If( Topic.n = 0, "1900-01-01",
      With( { d: If( IsMatch(Topic.rango, "(?i)a(ñ|n)o"),  DateAdd(Today(), -Topic.n, TimeUnit.Years),
                     IsMatch(Topic.rango, "(?i)mes"),      DateAdd(Today(), -Topic.n, TimeUnit.Months),
                     IsMatch(Topic.rango, "(?i)d(í|i)a"),  DateAdd(Today(), -Topic.n, TimeUnit.Days),
                     DateAdd(Today(), -100, TimeUnit.Years) ) },
            If( IsBlank(d) || Year(d) < 1900, "1900-01-01",
                Text(Year(d),"0000") & "-" & Text(Month(d),"00") & "-" & Text(Day(d),"00") ) ) )
```
⚠ Se arma la fecha con `Year/Month/Day` en vez de `Text(d,"yyyy-mm-dd")` **a propósito**: así no depende del
locale del entorno. Formato final `yyyy-MM-dd`, que es lo que espera el SQL.
⚠ **El `If(IsBlank(d) || Year(d) < 1900, …)` es el SUELO** (fix del 21/09): sin él, «999 años» cae en el año
1027 — por debajo del mínimo de fecha de Power Fx — y devolvía blanco → `desde="0000-00-00"` → **0 filas**.
Con el suelo, cualquier rango absurdo se comporta como «sin límite». Era el fallo #25 del grupo E.

**5.3 · Cambiar la Acción:** de `MD_equipo_comp` a **`MD_historial`**, mapeando:
| Entrada del flujo | Valor |
|---|---|
| `vista` | `vw_HistorialFilasMD` *(fijo en la Acción)* |
| `equipo` | `Topic.equipo` |
| `compartimiento` | `Topic.compartimiento` |
| `desde` | `Topic.desde` *(la variable del 5.2)* |
| `tope` | **`200`** ⚠ escribir el número, NO `""` |

⚠ **`tope` es entrada obligatoria del flujo**: no admite vacío. Poner literalmente **`200`**.
⛔ NO poner `""` — eso pasa la cadena de 2 comillas, `empty()` da falso y el SQL queda `TOP ("")` → error.
(El `if(empty(‹tope›),'200',‹tope›)` del flujo solo cubre el caso vacío real, que aquí no se puede dar.)

**5.4 · El resto de nodos NO cambia** (Tema 11 es **sin análisis**):
Acción → **Mensaje `{md}`** → **Condición** `md está en blanco` → Mensaje sin-data → **Finalizar**.

**5.5 · Ampliar la descripción del TEMA** para que la IA capte el rango en lenguaje natural. Añadir al final
de la descripción actual: *"Si el usuario acota el periodo («de los últimos 2 años», «en los últimos 6 meses»,
«últimos 14 días»), rellena `rango` con esa ventana tal cual la diga."*
⚠ Recordar el tope de **1024 UTF-16** de la descripción de un tema: si no entra, recortar EJEMPLOS, nunca las
anclas de ruteo.

---

**6 · Comando `/historial` — extraer el rango POR PATRÓN** ✅ HECHO (20/09)

⚠ **Esto es lo que evita romper el fix del componente compuesto.** `comp = resto2` se queda con *todo* lo que
va tras el equipo; si el rango fuera posicional al final, se lo tragaría. Por eso se **quita del texto ANTES**
del parseo que ya existe, y todo lo de abajo (`toks`, `cmd`, `p1..p4`, `resto1`, `resto2`) **sigue igual**.

**6.1 · En el nodo de parseo, ANTES de la línea actual `Topic.txt = Trim(System.Activity.Text)`**, insertar:
```
Topic.txt0  = Trim(System.Activity.Text)
```
```
Topic.rango = If( IsMatch(Topic.txt0, "(?i).*\s\d+\s*(a(ñ|n)os?|mes(es)?|d(í|i)as?)\s*$"),
                  Trim(Match(Topic.txt0, "(?i)\d+\s*(a(ñ|n)os?|mes(es)?|d(í|i)as?)\s*$").FullMatch),
                  "" )
```
**6.2 · ⚠ CORREGIDO (20/09): NO existe una variable `Topic.txt`.** En el tema real el `Split` se hace
directo sobre `System.Activity.Text` dentro de `Topic.toks`. Entonces:

**(a)** Añadir una 3.ª variable **después** de `Topic.rango`:
```
Topic.txt = If( Topic.rango = "", Topic.txt0,
                Trim(Left(Topic.txt0, Len(Topic.txt0) - Len(Topic.rango))) )
```
**(b)** Y editar la variable `Topic.toks` que YA existe, cambiando su valor de
`Split(Trim(System.Activity.Text), " ")` a:
```
Topic.toks = Split(Topic.txt, " ")
```
✅ Con eso todo lo que viene después (`cmd`, `p1..p4`, `resto1`, `resto2`) queda **sin tocar**: ya leen de
`Topic.toks`. El nodo Condición del gate sigue usando `System.Activity.Text` y tampoco cambia.
✅ **Es seguro para TODOS los comandos:** el patrón exige la palabra de unidad (años/meses/días), así que
`/ranking Antapaccay tracción Fe 5` **no** matchea (el «5» suelto no lleva unidad) y `/barrido Antapaccay 980E`
tampoco. En los comandos que no usan rango, `Topic.rango` simplemente se ignora.

**6.3 · En la cascada**, en la rama `cmd = "/historial"`, añadir el mapeo de entrada **`rango = Topic.rango`**
(además de `equipo=p1` y `comp=resto2` que ya están).

**6.4 · Sincronizar los 3 archivos de comandos** (regla permanente):
- `CONFIG_COMANDOS.md` → sintaxis `/historial ‹eq› ‹comp› [rango]` + la fila de la tabla de mapeo.
- `tools/gen_comandos_card.py` → el texto del comando.
- `tarjetas/comandos_card.json` → **regenerar** con `python tools/gen_comandos_card.py` y re-pegar la tarjeta.
- Añadir `[rango]` al glosario de la leyenda: *"rango — ventana de tiempo (ej. 2 años, 5 meses, 14 días)"*.

**Sintaxis final:** `/historial CA3171 tracción LH 2 años` · `/historialeq CA3171 6 meses`

---

**7 · Validar de punta a punta** — ✅ CORRIDO (20/09). Resultados reales:

| # | Prueba | Resultado |
|---|---|---|
| 1 | `/historial CA3176 MT LH` | **42 muestras** — ⚠ mi expectativa («12 + pie») estaba MAL: con `tope=200` y sin rango salen las 42. Es el comportamiento correcto («data completa»). |
| 2 | `/historial CA3176 MT LH 2 años` | **42** ✅ |
| 3 | `/historial CA3176 MT LH 14 días` | **1** ✅ → **el rango SÍ funciona** |
| 4 | `/historial CA3176 tracción LH 2 años` | ❌ **sin datos** — «tracción LH» no matchea `compAbbr` |
| 5 | `/barrido Antapaccay 980E` | ✅ sin regresión |
| 6 | `/ranking Antapaccay tracción Fe 5` | ✅ funciona **con «tracción»** |
| 7 | «historial del MT LH del CA3176 de los últimos 2 años» | ✅ 42 + análisis → **el desencadenador rutea bien** (queda descartada la alerta del trigger) |
| 8 | `/ultimo CA3176 tracción LH` | ❌ mismo fallo que la #4 |

**Conclusión:** el rango quedó OK. Lo que falla es el **nombre del componente en los comandos**.

## 7.b · FIX — normalizar el componente a `compAbbr` ✅ HECHO Y VALIDADO (20/09)

**Causa raíz.** Hay DOS familias de flujos y filtran por columnas distintas:
- `MD_equipo_comp` y `MD_metal` → filtran por **`compAbbr`**, cuyos valores son `MT LH`, `MT RH`, `RD LH`,
  `RD RH`, `Sist. Hidr.`, `Motor`. Por eso «tracción LH» **no** matchea.
- `MD_triage`, `MD_ranking`, `MD_condcomp`, `MD_ultmetalflota` → filtran por **`CompTipo`** (`TRACCION`,
  `HIDRAULICO`…) con `COLLATE Latin1_General_CI_AI`. Por eso `/ranking … tracción …` **sí** funciona (#6).

Por el camino NL la IA ya traduce al llenar la entrada; por el camino COMANDO el texto va **crudo**. ⛔ Las
descripciones de parámetros NO arreglan esto: solo actúan cuando la IA rellena el hueco, no en un comando.

⚠ **ANTES de escribir la normalización: correr el BLOQUE 73** (inventario real de componentes).
El `CASE` de `compAbbr` de las vistas **solo** mapea tracción LH/RH, rueda LH/RH, hidráulico y motor;
**todo lo demás cae al `ELSE`** y conserva el nombre completo (mando final, transmisión, diferencial,
caja de giro, PTO…). El borrador de abajo cubre únicamente lo mapeado → **hay que completarlo con la lista
real** que devuelva el bloque, incluidas variantes con typo (ya se conocía «MOTORO DE TRACCION RH» en Antamina).

**Fix DEFINITIVO (1 variable en «00 Comandos»)** — basado en el inventario real (BLOQUE 73).
Diccionario canónico completo en [CONFIG_COMANDOS.md](CONFIG_COMANDOS.md) §Diccionario.

🔑 **Hallazgo que simplifica todo:** de los 33 componentes reales, **solo 6 necesitan traducción** (los
abreviados, donde `compAbbr` ≠ `Compartimiento`). Para los otros 26 `compAbbr` **es** el nombre completo, así
que escribirlos tal cual **ya funciona** (`MANDO FINAL RH`, `TRANSMISION`, `PTO`, `CAJA GIRO FRONT`…).
Por eso la regla final es: **traducir los 6, y pasar todo lo demás sin tocar.**

Añadir DESPUÉS de `Topic.resto2`:
```
Topic.comp =
  With( { c: Lower(Trim(Topic.resto2)) },
    If( IsMatch(c,"(?i)(tracc|(^|\s)mt(\s|$))") && IsMatch(c,"(?i)(^|\s)lh(\s|$)"), "MT LH",
        IsMatch(c,"(?i)(tracc|(^|\s)mt(\s|$))") && IsMatch(c,"(?i)(^|\s)rh(\s|$)"), "MT RH",
        IsMatch(c,"(?i)(rueda|(^|\s)rd(\s|$))") && IsMatch(c,"(?i)(^|\s)lh(\s|$)"), "RD LH",
        IsMatch(c,"(?i)(rueda|(^|\s)rd(\s|$))") && IsMatch(c,"(?i)(^|\s)rh(\s|$)"), "RD RH",
        IsMatch(c,"(?i)(hidra|hidrá|(^|\s)sh(\s|$))"), "Sist. Hidr.",
        IsMatch(c,"(?i)motor") && !IsMatch(c,"(?i)(tracc|diesel|diésel)"), "Motor",
        Topic.resto2 ) )
```
⚠ **Las 2 trampas que resuelve** (verificadas contra el inventario):
1. **`motor` no siempre es `Motor`**: `MOTOR DE TRACCION *` y `MOTOR DIESEL LH/RH` también llevan «motor».
   Por eso la regla de `Motor` excluye `tracc|diesel` y va **después** de las de tracción.
2. **El typo ya estaba cubierto**: `MOTORO DE TRACCION RH` (209 muestras en Antamina) matchea `tracc` → `MT RH`.
   Por eso se usa `LIKE`/`IsMatch` y nunca igualdad exacta.
⚠ **Sin lado**: `/historial CA3176 MT` (sin LH/RH) cae al `ELSE` y hace `LIKE '%MT%'` → matchea **MT LH y MT RH**
   a la vez y el flujo las mezcla en una tabla. Edge conocido → pedir el lado (o resolverlo en la 2.ª tanda).

**Dónde usar `Topic.comp` en vez de `resto2`** — SOLO en las ramas que van a flujos de `compAbbr`:
`/ultimo` · `/tendencia` · `/tendenciadet` · `/grafica` · `/historial` · `/historialmetal`
⛔ **NO tocar** `/triage`, `/ranking`, `/metalflota`: van por `CompTipo` con `COLLATE CI_AI` y ya aceptan la
palabra natural (probado en la #6); normalizarlos los rompería.

**Postura adoptada (decisión 20/09):** *estrictos al documentar, tolerantes al aceptar.* En `/comandos` y
`/ayuda` se muestran los **nombres cortos** (lista limpia); por detrás se toleran las variantes; y si no se
reconoce una, **no se inventa**: pasa tal cual, que es justo lo que funciona para los 26 no-abreviados.

**✅ Re-probado (20/09):**  → «CA3176 · **MT LH** · 42 muestras» y
 → «CA3176 · **MT LH**». La #6 () sigue intacta.

**8 · Replicar a las 4 variantes restantes (Temas 12, 13, 14, 15)** — 🔨 EN CURSO

⚠ **Hallazgo (20/09): NO se puede reusar el flujo tal como está.** Las 4 vistas restantes tienen
**título Y columnas distintos**, algunos incluso dinámicos:
| Tema | Vista | Columnas de la tabla |
|---|---|---|
| 11 | `vw_HistorialMD` | `Fecha \| Horóm. \| Hor. Aci. \| Met. Obs. \| Hrs Comp \| CM \| Estado` (7) |
| 12 | `vw_HistorialEquipoMD` | `… \| Met. Obs. \| **Componente** \| CM \| Estado` (7) |
| 13 | `vw_HistorialMetalEquipoMD` | `… \| **{metal}** \| Componente \| CM \| Estado` (7, **dinámica**) |
| 14 | `vw_HistorialMetalMD` | `… \| **{metal}** \| Hrs Comp \| CM \| Estado` (7, **dinámica**) |
| 15 | `vw_HistorialFlotaMD` | `Fecha \| Equipo \| Componente \| Estado \| Observados` (**5**) |

Hoy el flujo `MD_historial` lleva el título y las columnas **hardcodeados** (sirven solo al Tema 11).

### Diseño: que la VISTA exponga el encabezado (patrón ya probado en `vw_RankingMD`)
`MD_ranking` ya hace `MAX(HeaderMD) + STRING_AGG(Fila)`. Se replica aquí, partido en dos porque el conteo
lo calcula el flujo (depende del rango):
- `TituloMD` → todo lo que va ANTES del número (ej. `**Historial — CA3176 · MT LH** · `)
- `SufijoMD` → lo que va DESPUÉS (ej. ` muestras (recientes arriba)`; en flota ` registros observados (…)`)
- `ColsMD`   → las 2 líneas de cabecera de tabla (`| Fecha | … |` + `|---|…|`)

El flujo pasa a ser:
```
MAX(TituloMD) + CAST(COUNT(*) AS nvarchar(10)) + MAX(SufijoMD) + NCHAR(10) + NCHAR(10)
+ MAX(ColsMD) + NCHAR(10) + STRING_AGG(Fila, NCHAR(10)) WITHIN GROUP (ORDER BY rn)  [+ pie si recorta]
```
→ **UN solo flujo para los 5 temas**; solo cambia la entrada `vista`.

### Contrato ÚNICO de las 5 vistas de filas
Todas exponen las MISMAS columnas (constante vacía donde no aplique, para que el `WHERE` genérico no falle):
`Equipo` · `compAbbr` · `Parametro` · `Proyecto` · `FechaMuestreo` · `rn` · `TituloMD` · `SufijoMD` · `ColsMD` · `Fila`

### Pasos
**8.1 ✅ HECHO Y VALIDADO (BLOQUE 74: CUERPO IDENTICO)** · Generalizar el Tema 11 primero (lo que ya funciona, sin romperlo):
- Añadir `TituloMD`/`SufijoMD`/`ColsMD` a `vw_HistorialFilasMD` + renombrar `rowMD`→`Fila`, `rn_hist`→`rn`,
  y agregar `Parametro` (vacío) y `Proyecto`.
- Cambiar el flujo a la versión genérica.
- ⚠ **Re-correr el BLOQUE 72** → el cuerpo debe seguir **idéntico**. Si no, parar.

**8.2 ✅ VISTAS CREADAS** — BLOQUE 75: Temas 13/14 IDENTICO; 12/15 diferían por **orden de filas**, no por datos (BLOQUE 76: misma fecha, distinto componente). Causa: `ROW_NUMBER() OVER (… ORDER BY FechaMuestreo DESC)` **sin desempate** → 3ª aparición del patrón (tras `Met_Obs` y `obsList`), y afectaba **también a las vistas originales**. Fix aplicado a las **6 ventanas** (nuevas + originales) añadiendo `, Compartimiento, LaboratoryDataId`. ✅ **RE-VALIDADO (BLOQUE 76 = 0 filas en Temas 12 y 15)**: tras el desempate no queda ni un carácter distinto. Las 5 vistas OK. · Crear las 4 vistas de filas restantes con el mismo contrato:
`vw_HistorialEquipoFilasMD` · `vw_HistorialMetalEquipoFilasMD` · `vw_HistorialMetalFilasMD` ·
`vw_HistorialFlotaFilasMD`. Copiar la lógica de su vista `*MD` actual, quitando el tope y el `STRING_AGG`.
⚠ Aplicar de entrada las 2 lecciones: **nada de CTE `obs` con `GROUP BY`+`JOIN`** (usar `STUFF(CONCAT(...))`
fila a fila) y **todo `STRING_AGG` con desempate**.

**8.3 · Apuntar los Temas 12/13/14/15 al flujo `MD_historial`** 🔨
Para CADA tema: (a) añadir entrada `rango` (Texto, opcional) · (b) copiar el nodo «Establecer valor de
variable» del Tema 11 (`Topic.n` y `Topic.desde`, idénticos) ANTES de la Acción · (c) apuntar la Acción a
`MD_historial` con el mapeo de abajo · (d) añadir a la descripción del tema la frase del 5.5.
El resto de nodos NO cambia: Acción → Mensaje `{md}` → Condición `md en blanco` → Mensaje sin-data → Finalizar.

⚠ Las **7 entradas del flujo son OBLIGATORIAS**: lo que no aplica se escribe **`%`** (da `LIKE '%%%'` = no
filtra). ⛔ nunca `""`, espacio ni `(todos)`.

| Tema | `vista` | `equipo` | `compartimiento` | `parametro` | `proyecto` | `desde` | `tope` |
|---|---|---|---|---|---|---|---|
| **11** | `vw_HistorialFilasMD` | `Topic.equipo` | `Topic.compartimiento` | `%` | `%` | `Topic.desde` | `200` |
| **12** | `vw_HistorialEquipoFilasMD` | `Topic.equipo` | `%` | `%` | `%` | `Topic.desde` | `200` |
| **13** | `vw_HistorialMetalEquipoFilasMD` | `Topic.equipo` | `%` | `Topic.parametro` | `%` | `Topic.desde` | `200` |
| **14** | `vw_HistorialMetalFilasMD` | `Topic.equipo` | `Topic.compartimiento` | `Topic.parametro` | `%` | `Topic.desde` | `200` |
| **15** | `vw_HistorialFlotaFilasMD` | `%` | `%` | `%` | `Topic.proyecto` | `Topic.desde` | `200` |

⚠ **El Tema 11 hay que RE-VISITARLO**: se configuró cuando el flujo tenía 5 entradas; al pasar a 7 necesita
`%` en `parametro` y `proyecto` o deja de funcionar.

**8.4 · Comandos** ✅ ARCHIVOS SINCRONIZADOS (mío) · 🔨 falta el mapeo en el dispatcher (tuyo)
Ya hecho en el repo: `CONFIG_COMANDOS.md` (sintaxis + tabla + §resto3/comp3), `gen_comandos_card.py` y
`comandos_card.json` regenerada con `[rango]` en los 4 comandos de historial.
**Falta en «00 Comandos»:** crear `Topic.resto3` y `Topic.comp3`, y mapear:
`/historialeq` → `rango` · `/historialflota` → `rango` · `/historialmetal` → `compartimiento=Topic.comp3`,
`rango`, y la **Condición 13-vs-14 pasa a `Topic.resto3 está en blanco`** (ya no `p3`). Re-pegar la tarjeta.

**8.5 · VALIDACIÓN FINAL DE P4** 🔨 — en el chat de prueba de Copilot

**A · El rango funciona en las 5 variantes** ✅ **10/10 OK (20/09)**
Resultados: #1 42 · #2 **1** · #3 200 · #4 **112** · #5 200 · #6 200 · #7 42 (Tema 14, con LP/LC en el título) ·
**#8 42 en MT LH** ✅ *(la prueba clave: rango + componente compuesto + ruteo 13-vs-14)* · #9 200 · #10 **150**.
⚠ **Pendiente de confirmar:** #3, #5, #6 y #9 dieron exactamente **200** = tocaron el tope → ahí **debe salir el
pie** «_Mostrando las 200 más recientes de N en el rango._». Verificar al final de esas tablas.
⚠ Las últimas pruebas se repitieron porque `/comandos` no estaba guardado con los cambios.
| # | Escribir | Esperado |
|---|---|---|
| 1 | `/historial CA3176 MT LH` | 42 filas (tope 200) |
| 2 | `/historial CA3176 MT LH 14 días` | **1** fila |
| 3 | `/historialeq CA3176` | todas las muestras del equipo (todos los componentes) |
| 4 | `/historialeq CA3176 6 meses` | **menos** filas que #3 |
| 5 | `/historialmetal CA3176 Fe` | Fe en TODOS los componentes (Tema 13) |
| 6 | `/historialmetal CA3176 Fe 2 años` | Tema 13 acotado |
| 7 | `/historialmetal CA3176 Fe MT LH` | Fe en ESE componente (Tema **14**) |
| 8 | `/historialmetal CA3176 Fe tracción LH 2 años` | ⚠ **la prueba clave**: Tema 14, lado **LH**, acotado |
| 9 | `/historialflota Antapaccay` | observados de la flota |
| 10 | `/historialflota Antapaccay 3 meses` | **menos** filas que #9 |

**B · El componente se normaliza** ✅ **5/5 OK (20/09)**
#11 `tracción LH`→**MT LH** (42) · #12 `motor de tracción RH`→**MT RH** (55) · #13 `HIDRÁULICO`→**Sist. Hidr.** (21) ·
#14 `/ultimo … rueda LH`→**RD LH** · #15 `MANDO FINAL LH` → **sin datos, y es CORRECTO**: CA3176 no tiene ese
componente (en el inventario del BLOQUE 73, MANDO FINAL aparece en ~11 equipos de Antapaccay, y en
`/historialflota` se vio con el equipo **8109**). El agente además listó los componentes que sí tiene. ✅

**C · NO-REGRESIÓN** ✅ **5/5 OK (20/09)**
#16 `/ranking … Fe 5` → 5 equipos, el «5» **no** se leyó como rango ✅ (la prueba que protegía el parseo global) ·
#17 `/barrido` 18 equipos · #18 `/triage` 5 de 72 · #19 `/tendencia` 6 muestras *(formato actual; cambia en P1)* ·
#20 `/ultimo … tracción LH` → MT LH.

**D · Lenguaje natural** ✅ **3/3 OK (20/09)**
#21 «…MT LH del 3176 de los últimos 2 años» → 42 · #22 «…equipo 3176 de los últimos 6 meses» → 113 ·
#23 «historial del Fe del 3176» → 200. El rango funciona también sin comando.

**E · Bordes** — 2/3 OK, **1 fallo real**
- #24 `/historial 9999 MT LH` → mensaje claro, sin error ✅
- **#25 `/historial CA3176 MT LH 999 años` → ❌ «no se encontraron registros»** *(debería traer TODO)*.
  **Causa:** `DateAdd(Today(), -999, TimeUnit.Years)` cae en el año **1027**, por debajo del mínimo de fecha de
  Power Fx (1900) → devuelve error/blanco → `Text(Year(d),"0000")` da `"0000"` → `desde="0000-00-00"` → 0 filas.
  **FIX (1 línea, en el 5.2 de los 5 temas):** poner un **suelo** al resultado.
  Cambiar el `Text(...)` final por:
  ```
  If( IsBlank(d) || Year(d) < 1900, "1900-01-01",
      Text(Year(d),"0000") & "-" & Text(Month(d),"00") & "-" & Text(Day(d),"00") )
  ```
- **#26 `/historial CA3176 MT` (sin lado)** → devolvió **97 muestras = 42 (LH) + 55 (RH)** con el título «MT RH».
  Es el edge conocido: `LIKE '%MT%'` matchea ambos y `MAX(TituloMD)` se queda con uno. **El agente lo explicó
  solo** («el sistema trajo ambos lados»), así que no engaña. Comportamiento **aceptado**; mejora opcional:
  que el flujo añada al pie «_Incluye N componentes_» cuando `COUNT(DISTINCT compAbbr) > 1`.

**⚠ Operativo (no es bug nuestro):** al probar en **MS Teams** salió *«Este agente no está disponible… Ha
alcanzado el límite de uso»* — **cuota de mensajes del tenant de Copilot Studio**. Riesgo a tener en cuenta
antes de una demo con gerencia; el tester de Copilot no la consume igual.

⚠ **Las que más importan:** la **#8** (rango + componente compuesto + ruteo 13-vs-14 a la vez) y la **#16**
(que el rango no se coma un número que no lo es).

### Criterio de terminado de P4
Los 5 comandos de historial aceptan rango, el componente se normaliza en todos, y sin rango ninguno cambia
respecto a hoy (salvo el pie de recorte, que es la mejora buscada).

## Criterio de terminado
`/historial CA3171 tracción LH 2 años` devuelve el histórico completo de esa ventana (no 12 filas), el
componente sigue respetando el lado LH, sin rango todo se comporta como hoy, y si se recorta por tope **se dice**.

---

---

# ✅ P5 — `/rankinggraf` · CERRADO (22/09)

> Desplegado y verificado en Teams: 27 barras, 3 bandas, 11 ◆, H.Motor + H.Metal, estado abreviado.
> `Largo_MD` 2 878 · 34 líneas · determinismo `IDENTICO`. Se conserva el paso a paso como referencia.

**Objetivo:** versión **gráfica** del `/rankingacum` (Tema 27), pidiendo gerencia que respete el dashboard PBI:
**barras por equipo**, **3 líneas de límite 60/65/70**, **rombos ◆** sobre las barras y **etiquetas de ejes**.
**Decidido (20/09): barras HORIZONTALES** (una fila por equipo — 27 equipos en vertical no se leen en chat).
Cambia la orientación, **no el contenido ni la semántica**.

## Reconocimiento hecho (21/09) — lo que ya sabemos
- **Fuente de datos:** la misma que `/rankingacum` → `vw_AcumuladosFlotaMD` parte de la **última foto por equipo**
  de `vw_RankingHistorico` (`ROW_NUMBER() PARTITION BY [N° Int.] ORDER BY Fecha DESC, [Horas Motor Actual] DESC`).
  Columnas disponibles: `N° Int.` · `Fecha` · `Serie` · `Horas Motor Actual` · `Horas Motor Metal` ·
  `Fe/Cr/Pb/Cu/Na/K/Si/Sn/Hollin Acum` · `Ranking`.
- **Bandas de Estado (ya existen en el repo):** `≥70 🟥 Crítico · ≥65 🟧 Alerta · ≥60 🟨 Atención · <60 🟢 Monitoreo`.
- **Fórmula (va en el subtítulo):** `Ranking = Pb·0.68 + Cu·0.17 + Cr·0.07 + (Fe·Na·K·Si)·0.02`.
- ✅ **NO hace falta flujo nuevo — VERIFICADO.** El Tema 27 usa hoy `MD_acumflota` (vista *hardcodeada*
  en el `concat`), pero `vw_AcumuladosFlotaMD` **ya expone** `Proyecto` · `Modelo ('(todos)')` · `CompTipo` ·
  `Observados` · `Recomendaciones` · `MD` — exactamente el contrato de **`MD_flota`**
  (`vista`,`proyecto`,`modelo`,`columna`). Basta que la vista nueva copie ese SELECT final y `MD_flota` la sirve.
- ✅ **El fence ya tiene patrón probado:** `vw_TendenciaGrafico` entrega el ASCII **crudo** en una columna y el
  consumidor lo envuelve con `N'```' + NCHAR(10) + g.Grafico + NCHAR(10) + N'```'` (DDL línea ~1802). Copiar eso.
- ✅ **Horizontal es MUCHO más simple que el ASCII actual:** `vw_TendenciaGrafico` dibuja vertical con 12
  niveles y un `CASE` por nivel. Aquí basta **`REPLICATE(N'█', n)`** por fila. Menos código y menos frágil.
- ⚠ **El ASCII va dentro de un bloque de código** (fence ```) para que Teams lo pinte monoespaciado y las
  barras queden alineadas — es como ya se renderiza `/grafica`.

## ✅ El rombo ◆ — CERRADO (21/09): lista manual, y ya la tenemos
El ◆ **no sale de los datos**: está escrito a mano en el DAX (se agrega el camión cuando el equipo es
**intervenido**). Por eso ninguna regla sobre horas/ratio podía cuadrar. ⛔ BLOQUE 77 **descartado**.

⚠ **Son dos piezas del DAX, no una** — mirar solo la primera deja la lista corta:
`Motores[Intervenido]` trae 9 (`{3196, 3168, 3166, 3180, 3194, 3165, 3161, 3193, 3175}`) y la medida
`Marca Intervenido al corte` fuerza 3 más en un `OR` (`CA3193` repetido, `CA3197`, `CA3195`).
**Unión = 11**, confirmado por el usuario. Detalle en
[../arquitectura/DEPENDENCIA_RankingAtencion.md](../arquitectura/DEPENDENCIA_RankingAtencion.md).
*(El DAX además pinta el ◆ a `max + 5%` de altura: cosmética del PBI, no dato — aquí va junto a la barra.)*

**Cómo se replica en SQL:** lista literal **dentro de la vista** (BD de solo lectura: `CREATE VIEW` ✅,
`CREATE TABLE`/`INSERT` ⛔), en un CTE marcado y fácil de editar a mano:
```sql
interv AS (   -- EQUIPOS INTERVENIDOS: lista MANUAL, espejo del DAX del PBI (al 2026-09-21).
    SELECT * FROM (VALUES
        (N'CA3161'),(N'CA3165'),(N'CA3166'),(N'CA3168'),(N'CA3175'),(N'CA3180'),
        (N'CA3193'),(N'CA3194'),(N'CA3195'),(N'CA3196'),(N'CA3197')
    ) v(Equipo)
)
```
⚠ En el DAX van **sin prefijo `CA`** (enteros); aquí el `Equipo` es `CA3196` — no copiar los números pelados.
⚠ **Deuda declarada:** lista manual copiada de otro artefacto → **se desincroniza sola** si alguien toca el DAX
y nada lo avisa. Re-contrastar al revisar el módulo Acumulados.

## Pasos

**1 · (resuelto)** La lista está arriba y en el doc de dependencia. Nada que pedir.

**2 · Escala y ancho** ✅ **DECIDIDO** (ya aplicado en la vista)
- **Dato real del PBI (captura 21/09):** el máximo es **CA3177 = 62.19** y el eje llega apenas sobre 70 para
  que quepan las 3 bandas → **escala fija 0–75** (0–80 desperdicia ancho y aprieta las marcas).
- Ancho **45** → **60 = col 36 · 65 = col 39 · 70 = col 42**, separadas por 3 caracteres. Escala **fija**, no al
  máximo del dato: si no, las bandas se moverían entre proyectos y dejarían de ser comparables.

**3 · Crear `vw_RankingGrafMD`** ✅ **HECHA, DESPLEGADA Y VALIDADA EN SSMS (21/09)** — al final de `DDL_vistas.sql`.
- Reusa el CTE `base` de `vw_AcumuladosFlotaMD` con el **mismo orden y desempate** → no puede divergir de la tabla.
- Las marcas se pintan con `STUFF` **solo donde la barra no llega**, así la barra las tapa cuando las supera
  (igual que el dashboard).
- Expone `Proyecto` · `Modelo` · `CompTipo` · `Observados` · `Recomendaciones` · `MD` → **`MD_flota` la sirve sin flujo nuevo**.
- ASCII **pre-computado en la vista**, dentro de un fence ```; el tema solo lo imprime. ⛔ Nunca regenerarlo en el LLM.
- El emoji de estado va **al final de la línea**: ocupa ancho variable y rompería la alineación si fuera antes.

Así sale (simulado con los valores reales de tu captura):
```
                                         60 65 70
                                          v  v  v
CA3177 █████████████████████████████████████ |  |     62.19    11592 h 🟨
CA3192 ███████████████████████████████████|  |  |     57.88    13525 h 🟢
CA3162 ██████████████                     |  |  |     24.15     2712 h 🟢
CA3196 ██████████████                     |  |  |     23.83 ◆   1960 h 🟢
CA3165 ██                                 |  |  |      3.59 ◆   8249 h 🟢
```
→ fila de **71 caracteres**. ⚠ Falta **confirmarlo en Teams**: es el único canal que cuenta.

**3.b · 🐛 Hallazgo del reconocimiento — 4º caso de la familia no-determinista**
`vw_AcumuladosFlotaMD` (y `vw_AcumuladosEquipoMD` por herencia del CTE `base`) tiene
`ROW_NUMBER() OVER (ORDER BY r.[Ranking] DESC)` para `Pos`, **sin desempate**: dos equipos con el mismo
`Ranking` pueden intercambiar posición entre ejecuciones. Es el mismo bug que `Met_Obs` / `obsList` /
`FechaMuestreo DESC`. **Fix (1 línea):** `ORDER BY r.[Ranking] DESC, r.[N° Int.]`.
🔴 **CONFIRMADO CON DATOS (BLOQUE 78, 21/09): el empate EXISTE HOY** — `Ranking = 24.15` en **CA3162 y
CA3178**, las posiciones **10 y 11** (se ve igual en la captura del PBI). Hoy mismo `/rankingacum` puede
devolverlos intercambiados entre una ejecución y la siguiente. ✅ **FIX APLICADO Y DESPLEGADO** (`ORDER BY r.[Ranking] DESC,
r.[N° Int.]`). BLOQUE 80 → `IDENTICO (ok)`, con CA3162 (pos. 1460) siempre antes que CA3178 (1570). **Cerrado.**

**Boceto del layout** (a afinar con el ancho real):
```
Ranking de Atención — Motor Diésel · Antapaccay · 27 equipos
Ranking = Pb·0.68 + Cu·0.17 + Cr·0.07 + (Fe·Na·K·Si)·0.02
◆ = <regla del paso 1>          🟨 60 Atención · 🟧 65 Alerta · 🟥 70 Crítico

                              60  65   70
                               ▼   ▼    ▼
CA3195 ████████████████████████████      65.4 🟧
CA3177 ██████████████████████████        62.1 🟨 ◆
CA3192 █████████████████████████         58.0 🟢
...
        H.Motor / H.Metal al pie de cada fila o en columna aparte (decidir con el ancho)
```

**4 · Tema nuevo «29 Ranking gráfico»** ✅ **HECHO (22/09)** — ruteo verificado
- Entrada: `proyecto` (default Antapaccay). Acción → **`MD_flota`** con `vista=vw_RankingGrafMD`,
  `modelo=(todos)`, `columna=MD`. Sin análisis (como Tema 27) o con el prompt universal — decidir.
- Nodos: Acción → Mensaje `{md}` → Condición `md en blanco` → Mensaje sin-data → Finalizar.
- **Descripción del tema** anclada a lo visual para que el orquestador no la confunda con `/rankingacum`:
  *"Gráfica de barras del ranking de atención del motor diésel (visual, con las bandas 60/65/70). «gráfico del
  ranking», «ranking en barras», «muéstrame el ranking gráficamente». ⛔ NO la tabla de acumulados (→ Ranking
  de acumulados) ni el acumulado de un equipo."* ⚠ Tope 1024 UTF-16.

**5 · Comando `/rankinggraf ‹proj›`** ✅ **HECHO (22/09)** — repo y Copilot
- ✅ **Ya sincronizados los 3 archivos** (regla permanente): `CONFIG_COMANDOS.md` (mapa, tabla de despacho,
  diagrama y ayuda), `tools/gen_comandos_card.py` y `comandos_card.json` regenerado (22 comandos).
- ✅ Rama en «00 Comandos» → «Ir a otro tema» 29 con `proyecto = If(p1="","Antapaccay",p1)`. Probado con
  proyecto, sin proyecto y en lenguaje natural.
- ⚠ La tarjeta va en **≈ 20 KB** de los ~28 KB del mensaje de Teams. Queda holgura para 2-3 comandos más;
  después habrá que partirla o pasar a paginado.

**6 · Validar**

✅ **Parte SQL cerrada (21/09).** BLOQUE 79 → los 11 intervenidos existen, todos `ok`. BLOQUE 80 → `IDENTICO`.
BLOQUE 81 → gráfica correcta: **2 480 caracteres, 34 líneas, 27 equipos**, marcas alineadas bajo `60 65 70`,
y dos lecturas seguidas idénticas. La gráfica pesa **menos que la tabla** (2 480 vs 3 407) — ~9% del techo del canal.
⚠ `Rombos = 12` **no es un error**: 11 filas + el ◆ de la leyenda del subtítulo.
⚠ El `Warning: Null value is eliminated by an aggregate` viene de los acumulados de `vw_RankingHistorico`,
no de estas vistas, y **no descarta filas** (27 equipos en ambas salidas).

Falta solo lo de Copilot Studio y el canal:

| # | Prueba | Esperado |
|---|---|---|
| 1 | `/rankinggraf Antapaccay` | 27 barras ordenadas desc., alineadas, con las 3 marcas — ✅ ya verificado en SSMS |
| 2 | Contar los ◆ | **11 en las filas** (+1 en la leyenda) — ✅ ya verificado |
| 3 | vs `/rankingacum Antapaccay` | ✅ mismos equipos, mismo orden y mismos valores |
| 4 | vs la **captura del PBI** | ✅ **cotejado 21/09: 1:1** en las 26 posiciones visibles — equipos, ranking (62.19 / 57.88 / 50.50 … 3.59), horas de metal y el orden del empate 24.15. La gráfica añade `CA3164` (1.04), que la tabla del PBI cortaba. ⚠ Si alguna vez difiere, sospechar **PBI sin refrescar** antes que bug propio |
| 5 | Dos corridas seguidas | **idénticas**, CA3162 antes que CA3178 — ✅ ya verificado |
| 6 | En **Teams** | ✅ **confirmado 22/09**: alineación correcta, las 3 marcas en su columna. Re-verificar tras el paso 7 |
| 7 | `/rankinggraf` (sin proyecto) | ✅ default Antapaccay |
| 8 | «muéstrame el ranking en gráfico» | ✅ rutea al 29, no al 27 |
| 9 | `/rankingacum Antapaccay` | **no-regresión**: igual que antes, salvo que el orden del empate ahora es estable |

**7 · Ajuste post-Teams (22/09)** ✅ **HECHO Y VERIFICADO EN TEAMS**
Del render real en Teams: las cifras salían **sin rótulo**, el estado era **solo el círculo de color** y
faltaba **H.Motor** (la gráfica solo traía H.Metal; las dos hacen falta — `H.Metal ≪ H.Motor` = metal
cambiado hace poco, que es justo lo que marca el ◆).
- ✅ Los **títulos de columna** viajan en la misma línea de los ticks — no chocan: `Equipo` 1-6, ticks 43/46/49,
  `Rank` 56-59, `H.Motor` 62-68, `H.Metal` 70-76, `Estado` 78-83. Sin gastar una línea extra.
- ✅ **H.Motor y H.Metal** como dos columnas de 6, separadas por 2 espacios para que los rótulos no se peguen.
- ✅ Cada fila lleva la **abreviatura del estado** (`Mon.` `Ate.` `Ale.` `Crí.`) **antes** del chip: ancho fijo 4,
  no descuadra, y el emoji queda al final, donde su ancho variable no afecta a nada.
- ✅ El subtítulo explica las abreviaturas y qué es cada columna de horas.
- La fila quedó en **83** caracteres; `Largo_MD` 2 878 (~10% del techo del canal).

```
                                         60 65 70
Equipo                                    v  v  v      Rank  H.Motor H.Metal Estado
CA3177 █████████████████████████████████████ |  |     62.19    11592   11592 Ate. 🟨
CA3171 ██████████████████████████████     |  |  |     50.50    16309    9236 Mon. 🟢
CA3196 ██████████████                     |  |  |     23.83 ◆ 16731    1960 Mon. 🟢
```

## Criterio de terminado
`/rankinggraf Antapaccay` devuelve las barras horizontales alineadas en Teams, con las 3 bandas marcadas, los ◆
según la regla confirmada y las etiquetas; los valores cuadran 1:1 con `/rankingacum`; y el Tema 27 no cambió.

## Alcance — lo que NO entra
Solo **Antapaccay / motor diésel**, igual que el módulo Acumulados hoy (`vw_RankingHistorico` es de ese alcance).

---

# ✅ P3 — `/incipiente` más allá de MT · CERRADO (23/09)

> SQL desplegado y validado (BLOQUES 83-86) **y** configuración de Copilot Studio hecha y probada por el
> usuario. El paso a paso queda abajo como referencia del patrón (filtro por `CompTipo`, denominador
> honesto, piso de ruido, tope + pie).

**Pedido de gerencia (18/09):** «documentar y personalizar más incipiente, que solo se limita a Antapaccay y MT»
· «detallar en 1 línea la tendencia con respecto al X de las Y ÚLTIMAS MUESTRAS».

## ⚠ Auditoría previa (22/09) — el diagnóstico de gerencia era medio correcto
Leí `vw_TendenciaIncipienteMD` entera antes de proponer nada, y **una de las dos limitaciones no existe**:

| Creíamos | Realidad en el DDL |
|---|---|
| Atado a **Antapaccay** | ❌ **Falso.** La vista agrupa por `Proyecto` y el flujo filtra por proyecto. `/incipiente Antamina` ya debería responder — lo que pasa es que el comando **defaultéa a Antapaccay** y nadie probó otro. **Verificar, no reescribir.** |
| Atado a **MT** | ✅ **Cierto.** `WHERE Compartimiento LIKE '%TRACCION%'` en el CTE `s`, y el `compAbbr` solo mapea MT LH/RH. |
| Faltaba decir contra qué se compara | ✅ **Cierto a medias.** La vista **ya** compara el último contra el promedio de las **6 previas** (`rn_recencia` 2..7), pero el subtítulo solo dice «su propia media»: no dice **cuántas** ni **cuál**. Es redacción, no cálculo. |
| Los límites «se cortaban» | ✅ **Ya arreglado** en P0 (línea en blanco antes de la tabla). No re-tocar. |

**Hallazgo extra (auditoría gramatical):** el texto que ve el usuario está **sin tildes** — «Motores de
Traccion», «acercandose al limite», «Ninguno - ningun Motor» — y usa `-` donde el resto del sistema usa `·`/`—`.
Desentona con las demás vistas. Se corrige en la misma pasada.

**La buena noticia:** `vw_MuestrasRankeadas` **ya expone `CompTipo`** (confirmado contra el schema canónico),
que es la columna con la que filtran `/triage`, `/ranking` y `/condcomp` aceptando lenguaje natural con
`COLLATE Latin1_General_CI_AI`. Generalizar **no** requiere inventar nada: es cambiar el `LIKE '%TRACCION%'`
por el mismo patrón que ya usan esos módulos.

## Pasos

**1 · Medir hasta dónde se puede abrir** ✅ **HECHO (BLOQUE 83, 22/09)**

**1.a · Quién tiene límites cargados** (equipos con LP / equipos totales):

| Proyecto | Con límites |
|---|---|
| **Antamina** | TRACCION 132/388 · RUEDA 128/129 · HIDRAULICO 66/158 · MOTOR 66/158 |
| **Antapaccay** | RUEDA 54/72 · TRACCION 54/72 · HIDRAULICO 36/48 · MOTOR 36/48 · MANDO 18/26 · TRANSMISION 5/8 · OTRO 0/25 |
| **Toromocho** | TRACCION 20/20 · RUEDA 18/18 · MOTOR 10/12 · HIDRAULICO 10/10 |
| **Cerro Verde** | TRACCION 16/128 · RUEDA 16/20 · HIDRAULICO 8/64 · MOTOR 8/64 |
| **Cuajone** | ⛔ **cero en todos** |
| **Toquepala** | ⛔ **cero en todos** |

→ **Cuajone y Toquepala devolverían siempre 0**, y no porque estén sanos: es que no tienen límites cargados.
Abrir el módulo a esos proyectos sin decirlo sería **peor que no tenerlo** — un «ninguno» falso tranquiliza.

**1.b · Cuántos saldrían** (equipos por proyecto × componente): Antamina TRACCION **52** · RUEDA 44 · MOTOR 40 ·
HIDRAULICO 13 · Antapaccay HIDRAULICO 13 · MOTOR 13 · TRACCION 11 · RUEDA 10 · Toromocho MOTOR 8 · TRACCION 7 ·
Cerro Verde RUEDA 7 · MOTOR 4. Volumen manejable **salvo Antamina TRACCION: 52 filas en un mensaje**.

## 🔴 Tres problemas que el paso 1 destapó (y que pesan más que el pedido original)

**A · El denominador del título miente.** `/incipiente Antamina` dice **«52 de 388 MT»**, pero solo **132** tenían
límites: los otros 256 **nunca pudieron dispararse**. El ratio real es 52 de 132. Lo mismo, peor, en Cerro Verde:
diría «1 de 128» cuando solo evalúo 16. **Fix:** el título cuenta el universo **evaluable**, y si hay equipos sin
límites lo dice («256 sin límites cargados, no evaluados»). Es honestidad del dato, no cosmética.

**B · La regla produce ruido en los metales de traza.** En la salida real de Antamina hay filas disparadas por
`Ni 0.1→0.7 (+483%)` y `Cr 0.5→0.7 (+56%)`. Con `LP(Ni)=1.0` y `LP(Cr)=1.0`, la «mitad del límite» son **0.5 ppm**,
que es el suelo de resolución del laboratorio: **cualquier lectura de traza pasa el filtro y el % explota**.
El umbral que funciona para Fe (LP 233) no sirve para un metal de LP 1. Mientras tanto, las filas buenas del mismo
reporte — `Fe 90.9→229.6` (98% del LP), `PQ 14.8→95.0` — quedan sepultadas entre el ruido.
→ **BLOQUE 84** mide cuánto pesa cada metal y con qué magnitudes reales. ⛔ **La calibración se decide con el
técnico, no la invento yo**; el bloque deja 3 opciones planteadas con su evidencia.
*Esto es, en el fondo, lo que gerencia pidió al decir «personalizar más incipiente».*

**C · 52 filas no caben cómodas.** En la captura de Teams la tabla se comprime tanto que el encabezado parte
palabras («Equi/po», «Tendenci/a») porque la columna de parámetros se come el ancho.
→ Tope de filas + pie «_mostrando N de M_», el mismo patrón ya probado en P4.

**2 · Confirmar que otros proyectos ya funcionan** ✅ **CONFIRMADO (22/09)** — `/incipiente Antamina` respondió
con sus 52 MT, tabla de límites y análisis. **La mitad del pedido de gerencia ya estaba hecha**: el módulo nunca
estuvo atado a Antapaccay. Queda **decirlo** en `/comandos` y `/ayuda` — y advertir de Cuajone/Toquepala.

## ✅ Calibración decidida con el BLOQUE 84 (22/09): **un piso de 1 ppm**

| metal | veces | LP | salto prom. | salto/LP | **saltos <1 ppm** |
|---|---|---|---|---|---|
| Si | 73 | 5–40 | 8.25 | 0.305 | **0** |
| Al | 69 | 1.5–10 | 0.88 | 0.352 | **50** |
| Cr | 54 | 0.2–2 | 0.31 | 0.437 | **53** |
| Fe | 34 | 6–233 | 32.44 | 0.310 | **0** |
| Cu | 32 | 1–19 | 1.23 | 0.387 | **18** |
| PQ | 24 | 3–166 | 25.89 | 0.344 | **3** |
| Ni | 15 | 1–2 | 0.42 | 0.379 | **14** |
| Pb | 12 | 2–3 | 1.03 | 0.422 | **6** |
| Sn | 3 | 3 | 1.76 | 0.587 | **0** |

**316 disparos, 144 (46%) con saltos menores a 1 ppm.**

Lo decisivo es la columna `salto/LP`: es **casi idéntica en todos los metales** (0.30–0.59). O sea que
**una regla relativa al LP no discrimina nada** — por eso el `0.5*LP` actual deja pasar el ruido.
El que sí separa señal de ruido es el **salto absoluto**: Cr (53 de 54), Ni (14 de 15) y Al (50 de 69)
disparan casi siempre con saltos sub-ppm, mientras Fe, Si y Sn **no lo hacen nunca**.

→ **Se adopta un piso único: `AND (ult - prom_prev) >= 1.0`.** Una sola línea. ⛔ Sin listas de metales ni
umbrales por metal, que se desactualizan y nadie mantiene. Efecto medido: **quita el 46% de ruido**,
conserva el **100% de Fe / Si / Sn** y 21 de 24 PQ. Y se explica en una frase a gerencia:
*«una variación menor a 1 ppm es el suelo de resolución del laboratorio, no desgaste».*

**3 · Vista reescrita** ✅ **HECHA, desplegada y verificada** — `DDL_vistas.sql` + **BLOQUE 85** corrido el 22/09.
Todo en una sola pasada (la anterior quedó respaldada en el scratchpad por si hay que revertir):
- **Cualquier componente:** el `WHERE Compartimiento LIKE '%TRACCION%'` sale; el filtro lo aplica el flujo
  sobre **`CompTipo`** con `COLLATE Latin1_General_CI_AI` — mismo patrón que `/triage`, que acepta lenguaje
  natural por diseño («tracción», «hidráulico») sin normalización.
- **`compAbbr` canónico:** se reusó el `CASE` idéntico al de las otras vistas, no una variante nueva.
- **Piso de 1 ppm** (arriba).
- **Denominador honesto:** el CTE `univ` separa *evaluables* (con LP) de *sin límites*. El título dice
  «N de **132** evaluados», no de 388, y agrega «_256 sin límites cargados: no evaluados._».
  Si el evaluable es **0** (Cuajone, Toquepala): mensaje explícito + «⚠ esto **no** significa que estén sanos».
  ⛔ Nunca más un «ninguno» que suene a buena noticia cuando en realidad no se midió nada.
- **Tope de 25 filas** ordenadas por severidad y luego por mayor %, con pie «_Mostrando 25 de N, los de mayor
  variación._» — lo importante nunca queda fuera del corte.
- **Bug de orden corregido:** el `STRING_AGG` ordenaba por `sev, Equipo`, y un equipo con LH **y** RH da dos
  filas con el mismo `Equipo` → empate sin desempate. Ahora ordena por el `ROW_NUMBER`, que es único.
  *(5º caso de la misma familia.)*
- **Tildes y separadores:** «Motores de Tracción», «acercándose», «límite», «ningún», y `·`/`—` como el resto.

**4 · La línea que pidió gerencia** ✅ **HECHA** (va en el subtítulo de la vista):
> _Última muestra vs. el promedio de las 6 anteriores. Se listan los que subieron ≥40% sobre ese promedio y
> ya están en la mitad superior del límite (≥50% del LP), sin superarlo todavía. Se descartan las variaciones
> menores a 1 ppm (ruido de laboratorio)._

**5 · COPILOT STUDIO** ❓ **ESTADO DUDOSO** — decía «hecho y probado (23/09)», pero dos líneas más abajo
decía que faltaba probarlo en el chat. ➡ **Se comprueba en el PASO 9 de la lista de Copilot**, que empieza
justamente por ahí. El detalle operativo vive **allí**; esto queda como historial.

> ⚠ **El orden importa.** Los pasos 5.1→5.5 van en ese orden: si creas la entrada del tema **después** de
> tocar el dispatcher, el nodo «Ir a otro tema» se queda con el esquema viejo (gotcha de P4).

### 5.1 · Crear el flujo `MD_incipiente` (Power Automate)
Clónalo de `MD_triage`, que es la misma forma, y cámbiale dos cosas: quítale la entrada `modelo` y reemplaza
el `concat`. **Entradas: `proyecto`, `compartimiento`** (texto, ambas obligatorias).
```
concat('SELECT MD, Observados, Recomendaciones FROM dbo.vw_TendenciaIncipienteMD WHERE Proyecto LIKE ''%', ‹proyecto›, '%'' AND CompTipo COLLATE Latin1_General_CI_AI LIKE ''%', ‹compartimiento›, '%''')
```
- ⛔ **Sin `modelo`:** la vista expone `Modelo='(todos)'` fijo; pedir un modelo real daría 0 filas.
- **Salidas:** las de siempre — `md`, `observados`, `recomendaciones`.
- Descripciones de entrada, listas para pegar:
  - `proyecto` — "Proyecto/mina (ej. Antapaccay)."
  - `compartimiento` — "Componente en palabra base: tracción / rueda / motor / hidráulico / mando / transmisión. Acepta lenguaje natural; default tracción."

### 5.2 · Tema 20: agregar la entrada `compartimiento` **y GUARDAR**
- Entrada nueva `compartimiento` (texto). Descripción: la de arriba.
- ⚠ **Guardar el tema AQUÍ, antes de seguir.** Hasta que no se guarda, el resto del agente no ve la entrada.
- ⛔ **No** la pongas como pregunta al usuario: tiene default, se fija en la Acción (paso 5.3).

### 5.3 · Tema 20: apuntar la Acción al flujo nuevo
Reemplaza la Acción actual por `MD_incipiente` y mapea:
| Entrada del flujo | Valor |
|---|---|
| `proyecto` | `Topic.proyecto` |
| `compartimiento` | `If(IsBlank(Topic.compartimiento), "tracción", Topic.compartimiento)` |

Resto de nodos **sin cambios** (el tema ya es CON análisis): Acción → Mensaje `{md}` → Prompt `Análisis de
aceite` (`tabla={md}`) → Mensaje `{analisis.text}` → Condición `md está en blanco` → Mensaje sin-data → Finalizar.

### 5.4 · Tema 20: pegar la descripción nueva
La actual dice «Motores de Tracción» fijo y ya no es cierto. **712 UTF-16, margen 312** sobre el tope de 1024:

> Equipos de una flota cuyo componente se DISPARÓ respecto a su propio promedio histórico (subida ≥40% sobre la media de sus 6 muestras previas) SIN superar todavía el límite — alerta TEMPRANA, aún no observados. Cualquier componente: tracción, rueda, motor, hidráulico… «tendencia incipiente en Antapaccay», «qué MT están subiendo sin pasar el límite», «qué ruedas se están disparando antes de la alarma», «desgaste incipiente de <mina>», «cuáles han variado de su comportamiento promedio por ahora sin sobrepasar los límites». Rellena proyecto y compartimiento (default tracción). Muestra el EQUIPO + parámetros (prom→últ, +%). ⛔ NO los ya fuera de límite (→ Triage / Barrido) ni un equipo puntual (→ Tendencia).

### 5.5 · Dispatcher «00 Comandos»: el 2º parámetro
1. Abre el nodo «Ir a otro tema» de la rama `/incipiente` y **re-selecciona el Tema 20** (cámbialo a otro tema
   y vuelve): así toma el esquema con la entrada nueva. Si no, avisa *«No se encuentra el enlace Input…»*.
2. Mapea:
   - `proyecto` = `If(Topic.p1="","Antapaccay",Topic.p1)`
   - `compartimiento` = `If(Topic.resto2="","tracción",Topic.resto2)`
   ← **`resto2`, no `p2`**: así «mando final» o «caja de giro» (2 palabras) llegan completos, igual que en
   `/ultimo` y `/tendencia`.

### 5.6 · Tarjeta de comandos
Re-pegar `docs/copilot/tarjetas/comandos_card.json` (ya regenerado): la fila dice `/incipiente ‹proj› [comp]`.

**6 · Validar** — SQL ✅ (BLOQUE 85, 22/09) · chat ⏳ tras el paso 5

**Lo que falta es probar en el chat, después de 5.6:**
| # | Escribir | Esperado |
|---|---|---|
| a | `/incipiente Antapaccay` | 6 de 54 evaluados · 18 sin límites · **no-regresión** |
| b | `/incipiente` (sin nada) | igual que (a): default Antapaccay + tracción |
| c | `/incipiente Antamina` | 45 de 132 · 256 sin límites · «Mostrando 25 de 45» |
| d | `/incipiente Antapaccay hidráulico` | 9 de 36 evaluados · título «Sistemas Hidráulicos» |
| e | `/incipiente Antapaccay mando final` | prueba que `resto2` pasa las **2 palabras** (no solo «mando») |
| f | `/incipiente Cuajone` | «sin límites cargados» + el aviso — ⛔ **no** «ninguno observado» |
| g | «qué ruedas se están disparando en Antamina» | rutea al Tema 20 en lenguaje natural, con comp=rueda |
| h | `/triage tracción Antapaccay` | **no-regresión**: el Tema 19 sigue igual (comparten forma de flujo) |

*(Los números de (a), (c), (d) y (f) salen del BLOQUE 85 ya corrido: si el chat muestra otra cosa, el problema
está en el flujo o el mapeo, no en el SQL.)*

**Referencia de lo ya validado en SSMS:**
| # | Prueba | Resultado |
|---|---|---|
| 1 | Antapaccay TRACCION | ✅ **6 de 54 evaluados**, 18 sin límites. Sin ruido sub-ppm |
| 2 | Antamina TRACCION | ✅ **45 de 132** (eran 52: el piso quitó 7), 256 sin límites, «_Mostrando 25 de 45_» |
| 3 | Cuajone | ✅ «sin límites cargados» + el aviso de que no significa que estén sanos |
| 4 | Antapaccay HIDRAULICO | ✅ 9 de 36 evaluados, 12 sin límites |
| 5 | Tamaño | ✅ 32 combinaciones, máximo **2 174** caracteres. Nadie cerca de 28 000 |
| 6 | Rendimiento | ✅ ver 6.b |
| 7 | En Teams | ⏳ junto con las pruebas de chat |

**6.b · ✅ Rendimiento — RESUELTO (BLOQUE 86, 22/09): 2:52 → 11,6 s**
`elapsed 172 539 ms (2:52)` · CPU 36 563 ms · `LaboratoryData` **66 scans / 90 024 lecturas** · Workfile 163 scans.
**Causa:** el CTE `s` estaba referenciado **3 veces** (`agg`, `univ`, `lims`) y además `lims` lo filtraba con un
**`EXISTS` correlacionado** contra `inc`, que re-ejecuta `agg`→`s` **por cada fila**. Al pasar de solo-TRACCION
a todos los componentes ese coste se multiplicó. Es exactamente el patrón del barrido (6:21 → 19,5 s).
**Fix:** `lims` sale de `inc` — que ya trae LP/LC, agregué `LC` a `agg` — y `univ` sale de `agg`.
La fundación se expande **una sola vez**.

**Medido, no supuesto:**
| | Antes | Después |
|---|---|---|
| Vista entera | 172 539 ms | **11 657 ms** (~15×) |
| Camino real (Antamina+tracción) | — | **8 023 ms** |
| `LaboratoryData` | 66 scans / 90 024 lecturas | **3 scans / 4 092** (22× menos) |
| Equivalencia | | **`Difieren = 0`** — salida idéntica por hash en las 32 combinaciones |

## Criterio de terminado
`/incipiente` responde por proyecto **y** por componente desde el chat, el subtítulo dice contra qué se
compara, un componente sin límites lo dice en vez de devolver 0, `mando final` llega completo, y
Antapaccay+tracción sigue dando exactamente lo de hoy (6 de 54). El Tema 19 (`/triage`) sin tocar.

---

# ⚠ P2 — Σvida: validada el 22/09, **REABIERTA el 23/09**

> 🔴 **Gerencia dice que el número no cuadra: 6 785.39, no 3 718.7** (Fe en CA3160 MT LH).
> Lo que validamos el 22/09 sigue siendo cierto — la suma coincide con su universo — pero **el universo no era
> el correcto**: `vw_MuestrasRankeadas` filtra `EsDDI = 0`. Ver **bloque B** de la ronda 23/09 arriba.
> Lo de abajo se conserva porque el método y los 3 arreglos siguen valiendo.

**Definición acordada:** Σvida = vida del metal **dentro del componente**.
**Veredicto: el DDL ya la computa bien.** `SUM(ppm)` sobre todas las muestras no-DDI del par
`Equipo+Compartimiento`. Comprobado en CA3176 MT LH: la vista dice **3 207.0** y la suma cruda de sus **26**
muestras da **3 207.0**. Coincide exacto. **P2 pedía validar, y quedó validado.**

**BLOQUE 88 (22/09) — confirmación en los 6 componentes del equipo:** vista y suma cruda coinciden en
**todos**, y el nº de muestras también: MOTOR 255.9/82 · **MT LH 3 207.0/26** · MT RH 2 810.4/40 ·
RD LH 243.8/21 · RD RH 493.9/21 · Sist. Hidr. 67.8/21. Sin diferencias.

⚠ **Dato suelto para mirar en P1** (no bloquea nada): de 30 366 filas de `vw_TendenciaElemento`, **2 030 no
tienen `Acumulado`** y **1 188 no tienen `NmAcum`**. Esperaba que fueran solo V100/TBN; el número no cuadra
del todo con eso. Vale la pena entenderlo cuando se reescriban esas vistas.

*(En el BLOQUE 87 parecía no coincidir — salían 6 valores — pero era mi consulta: no filtré el compartimiento
del lado de la vista, así que devolvía los 6 componentes del equipo.)*

## ⚠ Tres mejoras detectadas — **se aplican DENTRO de P1, no antes**
Las implementé y las **revertí** el 22/09 a pedido del usuario: viven en `vw_TendenciaMD` /
`vw_TendenciaElemento` / `vw_TendenciaMetalMD`, que son **las vistas que P1 reescribe** al fusionar
`/tendencia` con `/tendenciadet`. Tocarlas antes solo genera conflicto. Quedan aquí y en el **BLOQUE 88**:

1. **Mostrar sobre cuántas muestras va la Σ** — hay equipos con **110 muestras en 12 meses**; una Σ de 110 no
   se lee igual que una de 5. → `3207.0 (26)` + encabezado `Σvida (nº m.)`. `NmAcum` **ya existe** en
   `vw_TendenciaElemento`. ⚠ `vw_TendenciaMetalMD` lee de un CTE con **lista explícita** de columnas: hay que
   agregarla ahí también (fue el `Msg 207` del 22/09).
2. **`Proyecto` al `GROUP BY` de `acc`** — hoy 0 colisiones de código entre minas (verificado), pero agrupar
   identidades sin su clave completa es frágil.
3. **Documentar que Σvida NO resetea al cambiar el componente** — y **no puede**: `CM` tiene 27 valores y
   ninguno marca cambio de componente (`NULL` 16 944, `M`, `N`, `Y`, `C`, `MONI`, `ADI`, `PM1`…`PM50`,
   `CAMBIO` 73, `nan`…), son códigos de mantenimiento. ⚠ **`/rankingacum` sí resetea**: la misma palabra
   «acumulado» significa cosas distintas en dos módulos, y hoy está implícito.
   Riesgo bajo hoy: la BD cubre **~12 meses** (2025-09-24 a 2026-09-21) y en CA3176 MT LH el horómetro crece
   siempre (29 693 → 36 449). El cambio de `Grado` es de **aceite**, no de componente.

## 🔴 Hallazgo colateral, independiente de P1 y P2
`EsDDI` se calcula con `CM IN ('DDI','DIALIZADO','RELLENO+DIALIZADO')`, pero en los datos **solo existe
`DIALIZADO`, con 2 muestras**. `DDI` y `RELLENO+DIALIZADO` no aparecen nunca; sí aparece **`ADI` con 921**.
El filtro anti-DDI descarta 2 muestras de ~33 000: es casi un no-op, y **afecta a todas las vistas**.
⛔ No asumir que `ADI` es un typo de `DDI` — el glosario los trata como términos distintos. Preguntar al técnico.

---

# ⏸ Resto — de fondo (después de la ronda 23/09)

**P5 · `/rankinggraf`** — ⬆ **en curso, paso a paso completo arriba.**

**P3 · `/incipiente`** — ⬆ **en curso, paso a paso en la sección de abajo.**

**P1 · Fusionar `/tendencia` + `/tendenciadet`** — ⬆ **ahora es el bloque F de la ronda 23/09**
 — un solo tópico con la tabla general (6 muestras) **y** la
matriz de detalle. **Resumen analítico gerencial:** highlights + tendencia + **el PORQUÉ** de la subida/bajada.
⚠ Vigilar payload. Decidir si `/tendenciadet` queda como alias o se retira.
**Pendiente por completo — su SQL NO se ha tocado** (los cambios de Σvida se revirtieron el 22/09 justamente
para no interferir). Al entrar a P1, aplicar de paso **los 3 arreglos de Σvida** listados en la sección P2 y
listos en el **BLOQUE 88**. Vistas involucradas: `vw_TendenciaMD` · `vw_TendenciaElemento` ·
`vw_TendenciaMetalMD` · `vw_TendenciaGraficoMD` · `vw_TendenciaGraficoObsMD`.

**P2 · Validar Σvida** — ⬆ **SQL listo, ver sección abajo.**

---

# 🔧 Ajustes de comandos (del cruce con el set NL)
| ID | Qué falla | Fix |
|---|---|---|
| **A** | `/tendenciametal` no acepta componente | añadir `[comp]` opcional de cola (Tema 08) |
| **B** | `/historialmetal`: comp compuesto se parte (queda en `p3`) | unir tokens desde el 4.º — **encaja con el Paso 6 de P4** |
| **C** | «precauciones» / «matriz completa» sin comando | dejar como continuidad |
| **D** | `/condicion` no filtra lado | aceptable (usar `/ultimo` si hace falta el lado) |
| **E** | `/historialflota` no pasa modelo | añadir `[modelo]` opcional (Tema 15) |
| **F** | «último general = diagnóstico» no aplica a comando explícito | ninguno (esperado) |
| **G** | continuidad tras un comando | **verificar** que el redirect deja contexto |

**Transversal RH/LH:** el comando ya entrega «tracción LH» completo; falta que **cada tema interprete el lado**
desde su entrada (si contiene `RH`/`LH`, filtrar; si no, ambos). Temas 01, 02, 05/06, 11/14.

# 🗂 Adaptive Cards
Plan en [tarjetas/PLAN_TARJETAS_DATOS.md](tarjetas/PLAN_TARJETAS_DATOS.md). Candidatos reales: historial ancho
(P4 2ª tanda), `/rankinggraf`, barrido detalle. Límites ya establecidos: color por celda **sí**, celdas
combinadas **no**, ~28 KB, y **sin scroll** (las cards no tienen contenedor scrollable → la palanca es paginar).
Pendiente aparte: **menú nativo de Teams** (`commandList` del manifiesto).

# 🧭 Heredado de la auditoría de agosto (verificar si siguen abiertos)
`H1` quitar `columna` de las Entradas · `H2` barrido detalle → `MD_flota`, retirar `Barrido_Detalle` ·
`H3` `MD_metal` sin salidas `observados`/`recomendaciones` · `V100` límites de viscosidad por proyecto ·
**consultas compuestas** · infra: subir tier Azure **S1** (DBA).

# ✅ Cerrado (no re-abrir)
**19/09** formato de tablas en Teams · rótulo «inf» eliminado · **barrido 6:21 → 19,5 s** · determinismo de
`Met_Obs`. **18/09** comandos completos + fix del componente compuesto. **17/09** tarjeta `/comandos` ·
continuidad reforzada · aleatoriedad del mini-análisis. Todo desplegado y validado.
Regresiones: `VALIDACION_SSMS.sql` BLOQUES 68-70.
