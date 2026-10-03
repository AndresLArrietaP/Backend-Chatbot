> 🗄 **ARCHIVADO el 03/10/2026.** Ronda 01-02/10: C5 (la receta en 11 temas), H6, L6, H2, N3, N4 y el retoque
> de `/tendenciametal`. **No es el backlog**: el vivo es [../PENDIENTES.md](../PENDIENTES.md). El mapa de
> propagación (5.1b) sigue vivo allá.

# ▶ EMPIEZA AQUÍ — viernes 02/10

> ⚠ **Presentación interna con Franco: hoy, 19:30.** Lo de abajo está ordenado para que lo que se vea sea lo
> que más se nota. El PASO 5 es Copilot puro; el PASO 6 es una conversación con Carlos.

## Dónde quedamos (01/10, noche)

| Paso | Qué | Estado | Verificado en Teams |
|---|---|---|---|
| **C1** | `‹modelo›` llega al flujo (temas 16/17/18/21) | ✅ | `/barrido antapaccay 980` → 10 · `d475` → 6116 · «solo los críticos» → solo CA · conteo sin duplicar |
| **C2** | El fallback y el análisis no dibujan tablas | ✅ | La central no añade resúmenes; el fallback responde con 🔎 y viñetas |
| **BLOQUE 188** | Barrido de Antamina: Ca/Zn/Mg salían 🟥 en el 100 % | ✅ | El barrido lee `Estado_*` de la fundación; el triage pinta 🟨 |
| **C3** | `/grafica` absorbe `/tendenciametal` · `/ranking` con modelo · descripciones | ✅ | `/grafica 3160 mt lh Fe` · `/ranking antapaccay tracción Fe 980 5` · incipiente por NL |
| **C4** | Tarjeta de **19** comandos | ✅ | `/comandos` |
| **Receta** | El tema pregunta lo que falta | ✅ **solo Tema 09** | `/grafica 3160 Fe` pregunta el componente · `3160 mtlh` el metal |

---

## PASO 5 · **C5** — paso a paso

### 5.1 · La receta «el tema pregunta lo que falta» en los otros temas ⭐ **primero**

Cura de una vez el **N2** (el «No encontré datos» que sale antes de la respuesta) y el **H1**.
✅ **Tema 22 Ranking terminado (02/10)** — `/ranking` → `traccion` → `Fe` = top 10 de Fe en tracción, con
ejecución correcta del flujo. **Es la plantilla:** copiar sus bloques a cada tema de la tabla.
La receta son **6 piezas** y las 6 tienen que estar → [CONFIG_TEMAS § Receta](CONFIG_TEMAS.md): `Blank()` en el
Tema 00 · Condición `Len(Trim(...)) = 0` + Pregunta · «Guardar como» la misma variable · «Se debe solicitar»
desmarcado · Interrupciones desmarcadas · «sin entidad» ≠ Remitir.
⚠ Revisar también el **Tema 09**: funciona, pero aún no tiene las piezas 4-6 verificadas.

**Orden sugerido** — primero los que más se usan y el que cierra el H1:

| # | Tema | Comando | Bloques a agregar (en este orden) | Prueba |
|---|---|---|---|---|
| ✅ | **22 Ranking** | `/ranking` | compartimiento · parametro (proyecto con default) | hecho 02/10 |
| ✅ | **01 Último análisis** | `/ultimo` | equipo · compartimiento | hecho 02/10 |
| ✅ | **06 Tendencia** | `/tendencia` | equipo · compartimiento | hecho 02/10 |
| ✅ | **11 Historial componente** | `/historial` | equipo · compartimiento | hecho 02/10 — preguntas ANTES de los «Establecer valor» de `rango`; `5 meses` sigue filtrando |
| ✅ | **13 y 14 Historial de un metal** | `/historialmetal` | 13: equipo · parametro — 14: equipo · compartimiento · parametro | hecho 02/10 |
| ✅ | **25 Metal en flota** | `/metalflota` | parametros (+ defaults en la Acción) | hecho 02/10 |
| ✅ | **02 Condición MT** | `/condicionmt` | equipo | hecho 02/10 |
| ✅ | **04 Diagnóstico completo** | `/diagcompleto` | equipo | hecho 02/10 |
| ✅ | **12 Historial equipo** | `/historialeq` | equipo | hecho 02/10 — `rango` sigue filtrando (`5 meses`) |
| ✅ | **28 Acumulados equipo** | `/acumulados` | equipo | hecho 02/10 |

**Textos de las preguntas** (los mismos en todos los temas):
- equipo → «¿De qué equipo? Por ejemplo: 3160 o CA3160»
- compartimiento → «¿De qué componente? Por ejemplo: MT LH, MT RH, RD LH, Hidr, Motor»
- parametro → «¿Qué metal? Escribe el símbolo: Fe, Cu, Cr, Pb, Si, PQ…»
- parametros (25) → «¿Qué metal o metales? Símbolos separados por coma: Fe,Cu»
- proyecto (22) → «¿De qué mina? Por ejemplo: Antapaccay, Antamina»

**Criterio de terminado:** en cada tema, el comando a secas pregunta **todo** lo que falta, en orden, y
**nunca** aparece «No encontré datos» antes de la pregunta. Con todo completo, responde directo.
⚠ Si algo sale raro: el **historial de ejecuciones del flujo** muestra la consulta con los valores que
llegaron. Mirarlo antes de teorizar (así se encontró la trampa 4).

**✅ 5.1 CERRADO (02/10): los 11 temas tienen la receta.** Ver el mapa de abajo para lo que puede rebrotar.

### 5.2 · H6 — `/triage mtrh antapaccay 980` sale con columnas descuadradas — ✅ **CERRADO (02/10)**: sale alineado; lo curó J (5 columnas, 29/09)

Solo esa variante (`mtrh` pegado). Traer la captura y el `md` del historial del flujo `MD_triage`: ver si el
descuadre está en la tabla (vista) o en un mensaje que se coló entre filas.

### 5.3 · L6 — «0 observados» se lee como error — ✅ **CERRADO (02/10)** en temas 16 y 17: «No hay equipos observados con esos criterios…»

`/barrido antapaccay 930E` no devuelve filas porque el 930E no tiene observados (y además no tiene límites):
el tema dice «No encontré datos». Se arregla **en el tema**, no en SQL (cambiar la cardinalidad de la vista
afecta a todas las flotas sanas): el mensaje sin-datos de los temas de flota pasa a *«No hay equipos
observados con esos criterios. Si el modelo no tiene límites cargados, sus equipos no se pueden evaluar.»*
*(Origen: BLOQUE 151.)*

### 5.4 · H2 — `/ayuda` responde dos cosas distintas — ✍ **arreglo escrito (02/10)**

Medido: la **tarjeta es idéntica** las dos veces; lo que varía es la línea que la central agrega debajo. La regla
de CIERRES de la central ahora dice «tras la tarjeta de /comandos o /ayuda, NADA» → pegar la central de nuevo.

Aleatoriedad abierta desde el 17/09. Mirar en el Tema 00 si `/ayuda` va a la tarjeta (`/comandos`) **y**
el orquestador además dispara el Tema 26 (Ayuda/Glosario). Si es eso: `/ayuda` → solo la tarjeta, y el
glosario queda para las preguntas en lenguaje natural.

### 5.5 · N3 — `/triage` entra por el tema 19 directo, no por el Tema 00 — ✍ **reinterpretado y escrito (02/10)**

⚠ **Volvió (02/10, con el panel):** `/barrido antapaccay 980` → 17 y `/conteo antamina` → 21, **directo**, sin el 00. El
orquestador empareja la palabra del comando con la descripción de un tema, y la central decía «lo resuelve SIEMPRE
**su tema**» (lo leía como «el que se llama igual»). Cura en 4 textos: descripción del **00** («TODO mensaje con «/»
viene AQUÍ y SOLO aquí»), del **16** y **17** («un mensaje con «/» → 00 Comandos»; 17 solo con DETALLE), y la
**central** («va SIEMPRE al tema «00 Comandos»»). + desactivar el **21**.
✅ **N3 CERRADO (02/10):** `/barrido 980`, `/conteo antamina` y `/barridodet` pasan por el **00**; el lenguaje natural
«barrido de…» y «cuántos…» va al 16 y «detalle del barrido…» al 17.

La raíz era otra: `/triage antapaccay` (mina primero) mandaba `CompTipo = 'antapaccay'` → 0 filas → «No encontré
datos» + una ayuda improvisada por la IA. Arreglo: el Tema 00 reconoce si `p1` es componente o mina
(`esComp1`) → [CONFIG_COMANDOS](CONFIG_COMANDOS.md), fila `/triage`.

El mapa de actividad lo mostró: el orquestador elige el tema por su descripción antes de que el Tema 00
lea el `/`. Funciona, pero se salta los defaults del comando. Mirar si la descripción del 00 ancla bien
«mensaje que empieza con `/`».

### 5.6 · N4 — `T3160` (código de Cummins) no encuentra el camión — ✅ **CERRADO (02/10)**

Redactar `eq in`/`eq` en los 5 flujos por equipo ([CONFIG_FLUJOS § N4](CONFIG_FLUJOS.md)). Verificado en Teams:
`/ultimo T3160 mt lh` · `/condicionmt T3160` · `/grafica T3160 mt lh Fe` · `/historial T3160 mt lh` ·
`/acumulados T3162` → todos al CA correspondiente; `/ultimo 3161 mt lh` sin cambios.
✅ `/historialflota antapaccay` (equipo vacío) responde normal.

<details><summary>Plan original</summary>


Probado en SQL (BLOQUE 176.3): quitar la `T` **solo si le siguen 4+ dígitos** → `T3160` → `CA3160`;
`T1`/`T11`/`HT079` quedan intactos. **Falta ponerlo en los flujos por equipo** (`MD_equipo`,
`MD_equipo_comp`, `MD_metal`), como acción **Redactar** antes de la consulta (ley 3: traducir es del flujo).

</details>

### 5.7 · Retoque — el mensaje de `/tendenciametal` muestra `**` literales — ✅ **CERRADO (02/10)**

Dejarlo en texto plano: *«/tendenciametal se unió a /grafica. Usa /grafica ‹equipo› ‹componente› ‹metal›,
por ejemplo /grafica 3160 mt lh Fe.»*

---

