# Config canónica — COMANDOS (atajos deterministas a los módulos) · PLAN (por implementar)

> **Familia CONFIG** — lo que está aplicado en Copilot Studio:
> [CONFIG_TEMAS](CONFIG_TEMAS.md) (temas/tópicos) · [CONFIG_FLUJOS](CONFIG_FLUJOS.md) (Power Automate) ·
> [CONFIG_COMANDOS](CONFIG_COMANDOS.md) (atajos `/`) · [CONFIG_PROMPTS](CONFIG_PROMPTS.md) (nodos de IA) ·
> [CONFIG_TIMEOUT](CONFIG_TIMEOUT.md) (reintentos y cortes).
> Backlog único: [PENDIENTES](PENDIENTES.md). Historia del proyecto: [../BITACORA.md](../BITACORA.md).

Ver [CONFIG_TEMAS.md](CONFIG_TEMAS.md), [CONFIG_FLUJOS.md](CONFIG_FLUJOS.md), [CONFIG_PROMPTS.md](CONFIG_PROMPTS.md).
Estado: **EN PRODUCCIÓN** (2026-09-05) — dispatcher funcionando en el test de Copilot. Pendiente: menú Teams.

## Idea
Un **comando** = atajo directo a un módulo con **parámetros explícitos**, saltándose la orquestación por
descripción (cero ambigüedad de ruteo, respuesta inmediata). Para el **ingeniero que ya sabe qué quiere**.
La conversación natural sigue igual (los temas por descripción no se tocan); el comando es una **vía rápida paralela**.

## Sintaxis (prefijo `/` + módulo + parámetros posicionales)  ·  componente = tracción/hidráulico/rueda/mando/transmisión/motor
```
POR-EQUIPO
/ultimo <equipo> <componente>                → 01 Último análisis de componente
/condicionmt <equipo>                        → 02 Condición MT   (antes /condicion; ver §alias)
/diagcompleto <equipo>                       → 04 Diagnóstico completo   (alias: /diagnostico)
/tendencia <equipo> <componente>             → 06 Tendencia             (alias: /tendenciadet)
/tendenciametal                              → ⛔ retirado (30/09): mensaje que manda a /grafica
/grafica <equipo> <componente> <metal>       → 09 Gráfica de un metal
/historial <equipo> <componente> [rango]     → 11 Historial de componente  (rango: «2 años», «5 meses», «14 días»)
/historialeq <equipo> [rango]                → 12 Historial general del equipo
/historialmetal <equipo> <metal> [comp] [rango] → 13/14 Historial de un metal (equipo / componente)
/acumulados <equipo>                         → 28 Acumulados de un equipo (motor diésel)

POR-FLOTA
/panel <proyecto> [modelo]                   → 16 Panel de flota (I, 02/10) · alias: /barrido, /conteo
/barridodet <proyecto> [modelo]              → 17 Barrido detalle
/triage <componente> <proyecto> [modelo]     → 19 Triage de un componente en la flota
/incipiente <proyecto> [componente] [modelo] → 20 Tendencia incipiente (comp default: tracción; modelo default: (todos))
/ranking <proyecto> <componente> <metal> [modelo] [top] → 22 Ranking de un metal
/metalflota <proyecto> <componente> <metal(es)> [modelo] → 25 Último por metal en la flota  (metales: coma-sin-espacio Fe,Cu)
/historialflota <proyecto> [rango]           → 15 Historial de observados de flota
/rankingacum <proyecto>                      → 27 Ranking de acumulados (motor diésel)
/rankinggraf <proyecto>                      → 29 Ranking gráfico (mismas cifras, en barras)

META
/comandos  ó  /ayuda                         → lista de comandos
```
> Posicional. Si un parámetro requerido falta, el tema destino lo **pide en el chat** (comportamiento ya existente).

## § Diccionario CANÓNICO de componentes (inventario real, BLOQUE 73 · 2026-09-20)

**Regla:** documentamos los nombres CORTOS (lo que ve el usuario en `/comandos` y `/ayuda`), pero el
dispatcher **tolera variantes**. Si no reconoce una variante, **pasa el texto tal cual** — y eso funciona,
porque para todo lo no-abreviado `compAbbr` **es** el nombre completo.

### A · Los 6 ABREVIADOS (únicos donde `compAbbr` ≠ `Compartimiento` → hay que traducir)
| El usuario escribe (cualquiera) | Se envía | `Compartimiento` real | Muestras |
|---|---|---|---|
| `MT LH` · `tracción LH` · `motor de tracción LH` | **`MT LH`** | MOTOR DE TRACCION LH | 6 677 |
| `MT RH` · `tracción RH` | **`MT RH`** | MOTOR DE TRACCION RH (+ typo `MOTORO DE TRACCION RH`) | 6 437 + 209 |
| `RD LH` · `rueda LH` · `rueda delantera LH` | **`RD LH`** | RUEDA DELANTERA LH | 2 167 |
| `RD RH` · `rueda RH` | **`RD RH`** | RUEDA DELANTERA RH | 2 157 |
| `Hidr` · `hidráulico` · `SH` | **`Sist. Hidr.`** | SISTEMA HIDRAULICO | 4 643 |
| `Motor` · `motor diésel` | **`Motor`** | MOTOR | 8 145 |

### B · Los NO abreviados (se escriben TAL CUAL; `compAbbr` = nombre completo → ya funcionan)
`MANDO FINAL LH/RH` · `MANDO FINAL DELANTERO LH/RH` · `MANDO FINAL POSTERIOR LH/RH` · `TRANSMISION` ·
`DAMPER` · `PTO` · `PTO LH/RH` · `CAJA GIRO FRONT` · `CAJA GIRO REAR` · `DIFERENCIAL DELANTERO` ·
`DIFERENCIAL POSTERIOR` · `FRENO` · `MOTOR DIESEL LH/RH` · `REDUCTOR DE GIRO LH/RH` ·
`REDUCTOR DE GIRO POSTERIOR` · `REDUCTOR DE TRASLADO LH/RH`
> Ojo al reparto por proyecto: **Toquepala** concentra REDUCTOR/PTO LH-RH/MOTOR DIESEL LH-RH y **Antapaccay**
> MANDO FINAL/TRANSMISION/DAMPER/CAJA GIRO/DIFERENCIAL/FRENO. Antamina, Cerro Verde, Cuajone y Toromocho
> solo tienen los 6 abreviados.

### C · ⚠ Trampa: `motor` NO siempre es `Motor`
`MOTOR DE TRACCION *` y `MOTOR DIESEL LH/RH` **también** contienen la palabra «motor». Por eso la regla de
`Motor` debe excluir `tracc` y `diesel/diésel`, y evaluarse DESPUÉS de las de tracción.

### D · ⚠ Datos sucios detectados (no es tema de comandos, pero conviene saberlo)
`Compartimiento` **NULL** = 1 595 muestras / 66 equipos / 3 proyectos · `'nan'` = 45 / 7 equipos ·
`'M'` = 1. Son ~1 641 muestras sin componente utilizable. Registrado aparte, no se arregla desde KomfIA.

### § Alias de comandos renombrados (24/09)
| Nombre nuevo | Alias que sigue funcionando | Hasta cuándo |
|---|---|---|
| `/condicionmt` | `/condicion` | **decidir** — ver abajo |
| `/tendencia` | `/tendenciadet` | alias — los dos van al Tema 06 fusionado (25/09) |
| `/diagcompleto` | `/diagnostico` | alias — los dos van al Tema 04 (24/09) |

⚠ **Por qué un alias y no un corte seco:** quien memorizó `/condicion` se queda sin respuesta si desaparece
de un día para otro, y el síntoma es el mensaje genérico de comando no reconocido. La rama del dispatcher
acepta **los dos** nombres y apunta al mismo Tema 02.
⛔ Cuando se retire el alias, avisarlo en `/comandos` antes, no después.

### § FÓRMULA CANÓNICA de normalización de componente (2026-09-24) — **úsala en TODOS**

🔴 **Bug que la originó (24/09):** `/ultimo 3160 mt lh` funcionaba y **`/ultimo 3160 mtlh` no**.
La normalización anterior reconocía «tracción LH» y «MT LH», pero **no la forma pegada**: `mtlh` no caía en
ninguna regla, se enviaba tal cual, y `compAbbr` es `MT LH` **con espacio** → `LIKE '%mtlh%'` → **0 filas**.
Y el mensaje era «No encontré datos», que suena a «ese equipo no tiene muestras»: **un bug silencioso**.

**El arreglo de fondo:** normalizar sobre el texto **sin espacios, sin guiones y en minúscula**, de modo que
`MT LH`, `mtlh`, `Mt-Lh`, `motor de traccion LH` y `tracción lh` colapsen todos a lo mismo **antes** de decidir.

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

**Dónde va `<ORIGEN>`** — en **todos** los lugares donde entra un componente, no solo en los de cola:

| Variable | `<ORIGEN>` | Comandos |
|---|---|---|
| `Topic.comp` | `Topic.resto2` | `/ultimo` `/tendencia` `/tendenciadet` `/historial` |
| `Topic.comp3` | `Topic.resto3` | `/historialmetal` |
| `Topic.comp2` *(nuevo)* | `Topic.p2` | `/grafica` `/metalflota` (va **en medio**) |

🔴 **`/triage` y `/incipiente` quedan FUERA de esta fórmula (corregido 25/09).** Filtran por
**`CompTipo`** (`TRACCION` / `RUEDA` / `HIDRAULICO` / `MANDO`…), y la fórmula normaliza a **`compAbbr`**
(`MT LH` / `Sist. Hidr.`…). Aplicarla ahí convierte `tracción` en `MT` y `hidráulico` en `Sist. Hidr.`,
y `CompTipo LIKE '%MT%'` devuelve **0 filas**. Rompió los dos comandos el 25/09.
⇒ `/triage` recibe `Topic.p1` **crudo** y `/incipiente` recibe `Topic.resto2` **crudo**.
⚠ Es lo que ya decía [CONFIG_FLUJOS.md](CONFIG_FLUJOS.md): *«`MD_triage` y `MD_incipiente` filtran por
`CompTipo` con palabra natural, sin lado»*.

⚠ **Los de un solo token también la necesitan.** Un token no puede tener espacio, pero **sí puede venir
pegado**: `/grafica 3160 mtlh PQ` fallaba por lo mismo. Por eso la fórmula se aplica a los cuatro.

**Por qué esta forma y no una lista de variantes:** una lista hay que ampliarla cada vez que alguien escribe
distinto (`mtlh`, `MT-LH`, `mt  lh`…). Colapsar espacios y comparar por **contenido** (`tracc`, `rueda`,
`hidr`) cubre las variantes que ni se nos ocurrieron. El `else` final devuelve el texto **tal cual**, que es
lo correcto para los ~27 componentes no abreviados (`MANDO FINAL LH`, `TRANSMISION`…), donde `compAbbr`
**es** el nombre completo.

⚠ **El orden de las ramas importa:** `tracc` y `rueda` van **antes** que `motor`, porque
`MOTOR DE TRACCION LH` contiene la palabra «motor». La rama de `Motor` usa `^...$` (coincidencia exacta)
justo para no tragarse `motordetraccionlh`.

### § Compartimiento de cola — `resto2` / `resto3` y su normalización (2026-09-20)
El compartimiento puede ser **compuesto** («tracción LH») y va al final, así que se toma como **cola de tokens**,
no como un token suelto. Hay dos casos según cuántos parámetros lo preceden:

| Comando | Precede | Variable de cola | Normalizada |
|---|---|---|---|
| `/ultimo` `/tendencia` `/tendenciadet` `/grafica` `/historial` | equipo | `Topic.resto2` | `Topic.comp` |
| `/historialmetal` | equipo + metal | **`Topic.resto3`** | **`Topic.comp3`** |

```
Topic.resto3 = If( CountRows(Topic.toks) >= 4,
                   Trim(Concat(LastN(Topic.toks, CountRows(Topic.toks) - 3), Value, " ")), "" )
```
`Topic.comp3` = la MISMA fórmula de normalización de `Topic.comp` (ver §Diccionario), pero sobre
`Lower(Trim(Topic.resto3))`.

⚠ **Y la Condición que decide Tema 13 vs 14 pasa a mirar `Topic.resto3 está en blanco`**, no `p3`.
Con `p3` se rompía el compartimiento compuesto (se quedaba solo con «tracción» y perdía «LH») — era el
**Ajuste B** del set de pruebas.
⛔ **No uses `Topic.comp` en `/historialmetal`**: `resto2` ahí incluiría el metal («Fe tracción LH»), y sin
componente («/historialmetal CA3171 Fe») devolvería «Fe» como compartimiento.

### § Rango — se extrae POR PATRÓN, no por posición (2026-09-20)
⚠ **Por qué no es posicional:** `/historial` mapea `comp = resto2` (TODO lo que va tras el equipo, para que
«tracción LH» llegue completo). Un `[rango]` al final se lo tragaría `resto2` y volvería el bug del componente
compuesto. Por eso el rango se **detecta y se quita del texto ANTES** del parseo, y `toks`/`cmd`/`p1..p4`/
`resto1`/`resto2` siguen exactamente igual.

En el nodo de parseo del tema «00 Comandos», **antes** de `Topic.toks`:
```
Topic.txt0  = Trim(System.Activity.Text)
Topic.rango = If( IsMatch(Topic.txt0, "(?i).*\s\d+\s*(a(ñ|n)os?|mes(es)?|d(í|i)as?)\s*$"),
                  Trim(Match(Topic.txt0, "(?i)\d+\s*(a(ñ|n)os?|mes(es)?|d(í|i)as?)\s*$").FullMatch), "" )
Topic.txt   = If( Topic.rango = "", Topic.txt0,
                  Trim(Left(Topic.txt0, Len(Topic.txt0) - Len(Topic.rango))) )
```
y `Topic.toks` pasa de `Split(Trim(System.Activity.Text)," ")` a **`Split(Topic.txt," ")`**.

✅ **Seguro para el resto de comandos:** el patrón exige la palabra de unidad (años/meses/días), así que
`/ranking Antapaccay tracción Fe 5` NO matchea (el «5» va solo) y `/barrido Antapaccay 980E` tampoco.
En los comandos sin rango, `Topic.rango` simplemente no se mapea.

El tema destino convierte `rango` → fecha `yyyy-MM-dd` con Power Fx (ver `PENDIENTES.md` paso 5.2) y se la
pasa al flujo `MD_historial` como `desde`. **Hoy solo lo consume el Tema 11**; los Temas 12/13/14/15 entran
en la 2.ª tanda (paso 8).
> ⚠ **`/metalflota` pasa 4 inputs al Tema 25** (proyecto, modelo, compartimiento, parametros) — mapear `modelo=If(p4="","(todos)",p4)`.

## Cobertura de temas (re-auditoría 2026-09-05)
| Tema | Comando | Tema | Comando |
|---|---|---|---|
| 01 Último comp. | `/ultimo` | 15 Historial flota | `/historialflota` |
| 02 Condición MT | `/condicionmt` | 16 Barrido resumen | `/barrido` |
| 03 Diagnóstico | `/diagnostico` | 17 Barrido detalle | `/barridodet` |
| 04 Diag. completo | `/diagcompleto` | 18 Barrido filtrado | — *(variante: "solo críticos" como follow-up del barrido)* |
| ⛔ 05 Tendencia p1 — **DESACTIVADO** | — | 19 Triage | `/triage` |
| **06 Tendencia** (fusionado) | `/tendencia` · `/tendenciadet` | 20 Incipiente | `/incipiente` |
| 07 Tend. relevantes | — *(continuación de 05/06)* | 21 Conteo | `/conteo` |
| ⛔ 08 Tend. de un metal — **DESACTIVADO** (30/09) | — *(`/tendenciametal` → mensaje a `/grafica`)* | 22 Ranking | `/ranking` |
| 09 Gráfica | `/grafica` | 23/24 flota | — *(DESACTIVADOS; los cubre el fallback)* |
| 10 Gráficas obs. | — *(continuación de 09)* | 25 Metal en flota | `/metalflota` |
| 11 Historial comp. | `/historial` | 26 Ayuda/Glosario | — *(NL; `/comandos` da la ayuda de comandos)* |
| 12 Historial equipo | `/historialeq` | 27 Ranking acum. | `/rankingacum` |
| 13/14 Historial metal | `/historialmetal` | 28 Acumulados eq. | `/acumulados` |
> **Sin comando (a propósito):** 07/10 (continuaciones que se piden tras su tema base), 18 (filtro del barrido),
> 23/24 (desactivados), 26 (conceptual, va por lenguaje natural). Todo lo demás tiene su comando.

## DECISIÓN (2026-08-24): canal = Microsoft Teams (+ probar en el test de Copilot)
Plan que sirve en AMBOS — se construye la próxima sesión, en este orden:
1. **Dispatcher de texto `/`** (núcleo, canal-agnóstico): funciona **ya en el chat de prueba de Copilot** y en Teams.
   Es el handler que parsea y redirige. Con esto se prueba todo sin depender del canal.
2. **`/comandos` con botones de respuesta rápida**: menú descubrible (click-para-ejecutar) — sensación Discord en cualquier canal.
3. **Teams — command list en el manifiesto de la app**: hace los comandos **descubribles** en el menú del bot de Teams
   (al abrir la lista de comandos); al elegir uno envía el texto del comando → lo maneja el MISMO dispatcher. (El
   autocompletado as-you-type puro depende de Teams; el menú de comandos ya da la lista.)
> Así: probamos en el test de Copilot (dispatcher), y en Teams sumamos el menú del manifiesto. El «Comando» activity
> trigger nativo queda como opción a explorar; el dispatcher por mensaje es lo que corre en ambos sin fricción.

## Mecanismo en Copilot Studio (a confirmar en la herramienta)
**Un solo tema «Comando»** que parsea y **redirige** al tema correcto:
1. **Disparo:** descripción anclada a mensajes que empiezan con `/` (ej. «Se activa cuando el mensaje empieza con `/`
   (un comando): `/barrido`, `/triage`, `/acumulados`…»). ⚠ En el modelo de agente el ruteo es por DESCRIPCIÓN; **hay que
   VERIFICAR** que el orquestador mande los `/…` a este tema. Si no es fiable → plan B (abajo).
2. **Parseo (Power Fx):** `Split(System.Activity.Text, " ")` → tabla de tokens. `cmd = First(...).Value` (ej. `/barrido`);
   los demás tokens = parámetros. Guardar en variables del tema.
3. **Switch por `cmd`** (nodo Condición en cascada o «Ir a…»): setea las entradas del tema destino desde los tokens y
   **Redirige a ese tema** («Redirigir a otro tema», pasando las entradas). El tema destino ejecuta su flujo normal.
4. **`/comandos` / `/ayuda`** → nodo Mensaje con la lista (texto fijo, como el glosario).
5. **Comando desconocido** (`/xyz`) → Mensaje «Comando no reconocido. Escribe `/comandos` para ver la lista.»

### Plan B si el disparo por `/` no rutea fiable
- Meter el parseo en el **fallback** (KomfIA SQL / intención desconocida): si `StartsWith(Activity.Text,"/")` → parsear y
  redirigir; si no → comportamiento normal del fallback. Así CUALQUIER `/…` se captura sí o sí.

## HALLAZGO (2026-08-24): autocompletado `/` = feature del CANAL, no de Copilot
- El popup tipo **Discord** (teclear `/` → lista de comandos + parámetros) lo da el **canal** (Discord/Slack/Teams),
  NO el chat web/prueba de Copilot Studio. El iframe/web NO lo trae nativo.
- Copilot Studio SÍ tiene el trigger **«Se produce una actividad» → tipo «Comando»** (Bot Framework `command` activity),
  pero esa actividad es **programática** (la envía el host/canal), no el `/` tecleado con menú. Es el **HANDLER**, no la UX.
- **Dos capas independientes:** (UX) el menú `/` lo pone el canal · (HANDLER) el trigger «Comando» o un dispatcher de texto.
- **Camino recomendado ya (cualquier canal):** dispatcher de texto `/` (parsea → redirige) + un `/comandos` con
  **botones de respuesta rápida** (menú descubrible, click-para-ejecutar) → sensación Discord sin depender del canal.
- **Autocompletado real:** solo publicando en **Teams** (comandos en el manifiesto) o Discord/Slack (su integración) →
  ahí se usa el trigger «Comando» nativo. Depende de EN QUÉ CANAL viven los ingenieros (a definir).

## A investigar/confirmar en Copilot Studio (próxima sesión)
- ¿El orquestador rutea de forma fiable los mensajes que empiezan con `/` a un tema por su descripción? (si no → Plan B).
- **«Redirigir a otro tema»** pasando **entradas** (inputs) al tema destino — confirmar que se pueden setear.
- **Power Fx `Split`/`First`/`Index`** sobre `System.Activity.Text` disponible en los nodos del tema.
- ¿Existe un **trigger de comando** nativo / «activity received» que simplifique esto? (la nota «Comando» vino de esa idea).

## Cobertura (todos los módulos, incluido Acumulados)
Cada comando mapea 1:1 a un tema existente (arriba). Se incluyen los nuevos: `/metalflota` (25), `/acumulados` (28),
`/rankingacum` (27), `/triage` (19 evolucionado). Nada nuevo de lógica: los comandos **reusan** los temas/flujos ya hechos.

## BUILD — paso a paso (tema «Comandos», probar en el test de Copilot)

### Diagrama del tema (cómo debe quedar el lienzo)
```
        ┌────────────────────────────────────────────┐
        │ DESENCADENADOR: «El agente elige»           │
        │ descripción anclada a "/" (comandos)        │
        └───────────────────────┬────────────────────┘
                                ▼
             ┌───────────────────────────────────────┐
             │ CONDICIÓN  (gate NO-invasivo)          │
             │ IsMatch(Trim(System.Activity.Text),    │
             │         "^/[A-Za-z]")   ← barra PEGADA │
             │         a una letra (no "/ pregunta")  │
             └───────┬───────────────────────┬────────┘
               Verdadero                    Falso
                     │                        │
                     ▼                        ▼
                     │                «Finalizar tema actual»  (red de seguridad;
                     │                casi nunca cae aquí si el disparador está bien anclado)
                     ▼
        ┌────────────────────────────────────────────┐
        │ ESTABLECER VARIABLE  toks = Split(Trim(txt)," ")│
        │ ESTABLECER VARIABLE  cmd  = Lower(First(toks).Value)│
        │ ESTABLECER VARIABLE  p1,p2,p3,p4 = Index(toks,n).Value│
        └───────────────────────┬────────────────────┘
                                ▼
        ┌────────────────────────────────────────────┐
        │ CONDICIÓN (cascada: 1 rama por comando)     │
        │                                            │
        │  cmd="/barrido"     → «Ir a tema» 16  (proyecto,modelo) │
        │  cmd="/triage"      → «Ir a tema» 19  (comp,proyecto,modelo)│
        │  cmd="/ultimo"      → «Ir a tema» 01  (equipo,comp)     │
        │  cmd="/tendencia"   → «Ir a tema» 05  (equipo,comp)     │
        │  cmd="/acumulados"  → «Ir a tema» 28  (equipo)          │
        │  cmd="/rankingacum" → «Ir a tema» 27  (proyecto)        │
        │  cmd="/rankinggraf" → «Ir a tema» 29  (proyecto)        │
        │  cmd="/metalflota"  → «Ir a tema» 25  (proyecto,modelo,comp,metales ← 4)│
        │  … (resto de la tabla de mapeo)                        │
        │  cmd="/comandos"    → «Mensaje» (lista de comandos)     │
        │  (ninguna coincide) → «Mensaje» "no reconocí /…" + Fin  │
        │  (protección NL = el DISPARADOR, no esta rama)          │
        └────────────────────────────────────────────┘
```
> Cada rama = un nodo **Condición** (`Topic.cmd = "/xxx"`) y dentro **«Ir a otro tema»** (Administración de temas)
> eligiendo el tema concreto y mapeando sus entradas desde p1..p4. ⛔ NO usar «Reconocer la intención» (pide UserInput).

### 0) Crear el tema
Nuevo tema → nombre **`00 Comandos`**. Desencadenador → **«El agente elige»** (la 1ª opción; la misma clase que
los demás temas — convive limpio, no intercepta todo). ⛔ NO uses «Se recibe un mensaje» (se dispara en CADA mensaje;
solo es Plan B si «El agente elige» no rutea los `/`). «Se produce una actividad»/«Se invoca» = eventos/botones de Teams (después).
Pega esta **descripción** (anclada a la BARRA PEGADA a una palabra-comando, no a cualquier `/`):
> **(02/10, 612 UTF-16)** — reescrita porque el orquestador mandaba `/barrido` al 17 y `/conteo` al 21 sin pasar por aquí:
> "⚑ TODO mensaje que EMPIEZA con una BARRA pegada a una palabra (/panel, /barrido, /barridodet, /conteo, /triage, /ranking, /ultimo, /tendencia, /grafica, /historial, /acumulados, /comandos…) viene AQUÍ y SOLO AQUÍ, aunque el comando se llame igual que otro tema: este tema lee los parámetros y lo despacha a su módulo. Nunca lo mandes directo a Panel, Barrido detalle, Conteo, Triage, Ranking ni a ningún otro tema. «/barrido Antapaccay 980», «/conteo Antamina», «/triage rueda Antamina», «/tendencia CA3177 MT LH». ⛔ NO si es lenguaje natural aunque contenga / (ej. «/ ¿qué equipos…?» con espacio tras la barra)."

### 1) Nodo Condición — GATE no-invasivo (1º nodo)
Condición (Power Fx): `IsMatch(Trim(System.Activity.Text), "^/[A-Za-z]")`  ← barra **pegada a una letra**.
- **Falso** (barra con espacio «/ ¿qué…?», barra sola) → **«Finalizar tema actual»** (red de seguridad; casi nunca cae aquí).
- **Verdadero** → sigue al parseo.
> ⚠ **La protección REAL es el DISPARADOR** (paso 0): al estar anclado a `/comando`, el orquestador NO manda NL a este
> tema, así que «/ ¿qué equipos…?» va a su módulo normal y ni entra aquí. Dentro del tema NO existe forma limpia de
> "devolver el mensaje a NL"; por eso ⛔ NO se usan «Varios temas relacionados» / «Restablecer conversación»
> (borra contexto) / «Transferir conversación» (escala a humano) — ninguno re-rutea como lenguaje natural.

### 2) Nodo «Establecer valor de variable» × parseo (Power Fx)
Crear variables de tema (Texto) y setear:
```
Topic.txt    = Trim(System.Activity.Text)
Topic.toks   = Split(Topic.txt, " ")            // tabla; columna = "Value"
Topic.cmd    = Lower(First(Topic.toks).Value)   // ej. "/barrido"
Topic.p1     = If(CountRows(Topic.toks) >= 2, Index(Topic.toks, 2).Value, "")
Topic.p2     = If(CountRows(Topic.toks) >= 3, Index(Topic.toks, 3).Value, "")
Topic.p3     = If(CountRows(Topic.toks) >= 4, Index(Topic.toks, 4).Value, "")
Topic.p4     = If(CountRows(Topic.toks) >= 5, Index(Topic.toks, 5).Value, "")
// RESTO (une los tokens de cola) — para componentes COMPUESTOS: "MT RH", "tracción RH", "rueda delantera LH"
Topic.resto1 = If(CountRows(Topic.toks) >= 2, Trim(Concat(LastN(Topic.toks, CountRows(Topic.toks) - 1), Value, " ")), "")  // todo tras el /comando
Topic.resto2 = If(CountRows(Topic.toks) >= 3, Trim(Concat(LastN(Topic.toks, CountRows(Topic.toks) - 2), Value, " ")), "")  // todo tras p1 (equipo)
```
> ⚠ Verificar en el editor que la columna de `Split` se llame **`Value`** (si no, ajustar `.Value`).
> ⚠ **Componente COMPUESTO (bug 18/09):** `/tendenciadet 3177 MT RH` → el split mete `RH` en `p3` y el tema tomaba
> `comp="MT"` (perdía el lado → caía a LH). **FIX:** cuando el compartimiento es el ÚLTIMO parámetro, pásale **`resto2`**
> (todo lo que viene tras el equipo), no `p2`. Así `comp="MT RH"`, `"tracción RH"`, `"rueda delantera LH"` llegan completos.

### 3) Nodo Condición en cascada (Switch por `Topic.cmd`) → setea inputs y «Redirigir a otro tema»
Por cada rama: `Topic.cmd = "/xxx"` → mapear los inputs del tema destino y redirigir. Defaults con `If(p="","default",p)`:

| `cmd` | Redirige a | Inputs a pasar (desde p1..p4) |
|---|---|---|
| `/ultimo` | 01 Último análisis | equipo=p1 · compartimiento=**resto2** ⟵ comp compuesto |
| `/condicionmt` · alias `/condicion` | 02 Condición MT | equipo=p1 |
| `/diagnostico` · **alias de `/diagcompleto`** | 04 Diagnóstico completo | equipo=p1 |
| `/diagcompleto` | 04 Diagnóstico completo | equipo=p1 |
| `/tendencia` · **alias `/tendenciadet`** | **06 Tendencia** (fusionado 25/09) | equipo=p1 · compartimiento=**resto2** ⟵ comp compuesto |

| `/tendenciametal` | ⛔ **retirado (30/09)** — la rama se queda (ley 8); su «Ir a tema 08» se cambia por un **Mensaje**: «`/tendenciametal` se unió a `/grafica`: usa `/grafica ‹equipo› ‹componente› ‹metal›`.» | — |
| `/grafica` | 09 Gráfica | equipo=p1 · **parametro = el ÚLTIMO token** · **compartimiento = lo de en medio** (admite `mt lh`) — fórmulas en §`/grafica` |
| `/historial` | 11 Historial componente | equipo=p1 · compartimiento=**resto2** · **rango=`Topic.rango`** (extraído por patrón, ver §Rango) |
| `/historialeq` | 12 Historial equipo | equipo=p1 · **rango=`Topic.rango`** |
| `/historialmetal` | 13/14 Historial de un metal | equipo=p1 · parametro=p2 · compartimiento=**`Topic.comp3`** · **rango=`Topic.rango`** · la Condición 13-vs-14 pasa a mirar **`Topic.resto3` está en blanco** (ya no `p3`) |
| `/acumulados` | 28 Acumulados equipo | equipo=p1 |
| `/panel` · alias `/barrido`, `/conteo` | **16 Panel de flota** | proyecto=`If(p1="","Antapaccay",p1)` · modelo=`If(p2="","(todos)",p2)` — UNA Condición con las tres (`cmd = /barrido` **CUALQUIERA** `/panel` · `/conteo`, ley 8). La Condición vieja de `/conteo` queda inalcanzable: **no se borra** |
| `/barridodet` | 17 Barrido detalle | proyecto=`If(p1="","Antapaccay",p1)` · modelo=`If(p2="","(todos)",p2)` |
| `/triage` | 19 Triage | **acepta la mina primero** (02/10): `Topic.esComp1 = IsMatch(Lower(Topic.p1), "^(mt|tracc|rd|rueda|hidr|sh|motor|mando|transm).*")` · compartimiento=`If(esComp1, p1, "tracción")` · proyecto=`If(esComp1, If(p2="","Antapaccay",p2), If(p1="","Antapaccay",p1))` · modelo=`If(esComp1, If(p3="","(todos)",p3), If(p2="","(todos)",p2))` — `/triage antapaccay` mandaba `CompTipo = 'antapaccay'` · **(03/10) con un EQUIPO** (`/triage 3195 antapaccay`, visto en la presentación): Condición al inicio de la rama, `IsMatch(Topic.p1, "(?i)(ca|t)?\d{4}")` → Mensaje «El triage es de la flota; para un equipo es el diagnóstico. Te muestro el del {Topic.p1}.» → **Ir a tema 03 Diagnóstico** (equipo = `Topic.p1`) → Finalizar. El `else` sigue como está. Hoy salía «No encontré datos» y la IA improvisaba la ayuda |
| `/incipiente` | 20 Tendencia incipiente | **modelo (03/10)**, mismo patrón que `/triage`: `Topic.esComp2 = IsMatch(Lower(Topic.p2), "^(mt|tracc|rd|rueda|hidr|sh|motor|mando|transm).*")` · proyecto=`If(p1="","Antapaccay",p1)` · compartimiento=`If(Topic.esComp2, Topic.p2, "tracción")` · modelo=`If(Topic.esComp2, If(IsMatch(Topic.p3, ".*\d.*"), Topic.p3, If(IsMatch(Topic.p4, ".*\d.*"), Topic.p4, "(todos)")), If(Topic.p2 = "", "(todos)", Topic.p2))` — un modelo siempre lleva un dígito y un componente nunca, así que `antapaccay 980`, `antapaccay mtlh` y `antapaccay mt lh 980` caen bien. Antes `980` llegaba como componente → «Sin datos suficientes» |
| `/conteo` | **16 Panel de flota** (alias desde el 02/10; antes 21) | proyecto=`If(p1="","Antapaccay",p1)` · modelo=`If(p2="","(todos)",p2)` — en el nodo «Tema» de la rama solo cambia el destino |
| `/ranking` | 22 Ranking | proyecto=p1 · compartimiento=p2 · parametro=p3 · **modelo y top desde p4/p5** — fórmulas en §`/ranking` |
| `/metalflota` | 25 Último por metal flota | proyecto=`If(p1="","Antapaccay",p1)` · compartimiento=`If(p2="","tracción",p2)` · parametros=p3 · **modelo=`If(p4="","(todos)",p4)`** ⟵ 4º input |
| `/historialflota` | 15 Historial obs. flota | proyecto=`If(p1="","Antapaccay",p1)` · **rango=`Topic.rango`** |
| `/rankingacum` | 27 Ranking acumulados | proyecto=`If(p1="","Antapaccay",p1)` |
| `/rankinggraf` | 29 Ranking gráfico | proyecto=`If(p1="","Antapaccay",p1)` |
| `/comandos` ó `/ayuda` | (nodo Mensaje, ver 4) | — |
| (ninguna coincide) | **«Ir a otro tema» → Conversación** | — (era NL con `/`, no un comando) |

> ⚠ **Tema 25 (`/metalflota`) tiene 4 entradas** (proyecto, modelo, compartimiento, parametros): mapea las 4, con `modelo=If(p4="","(todos)",p4)`.
> Si un input requerido va vacío (equipo en los por-equipo), el tema destino lo **pide en el chat** (ya existente).
> ⚠ **Componente compuesto y posición del token:** el arreglo `resto2` funciona cuando el compartimiento es lo ÚLTIMO
> (`/ultimo`, `/tendencia`, `/tendenciadet`, `/historial`). En comandos donde el compartimiento va **en medio** seguido de
> otro parámetro (`/grafica ‹eq› ‹comp› ‹metal›`, `/metalflota ‹proj› ‹comp› ‹metal(es)› [modelo]`) o **primero**
> (`/triage ‹comp› ‹proj›`), el compartimiento debe ser de **UN solo token** (ej. `tracción`, no `MT RH`) — el lado RH/LH
> ahí lo resuelve el propio tema (agrega/pregunta). Si más adelante se necesita lado en esos, se hará detección explícita del
> sufijo `RH|LH` (`IsMatch(Last(toks).Value,"(?i)^(RH|LH)$")`), no está implementado aún.

### 3b) Fórmulas de `/grafica` y `/ranking` (C3, 30/09)

**`/grafica ‹equipo› ‹componente› ‹metal›`** — el metal es siempre el ÚLTIMO token y el componente lo que
queda en medio, así `/grafica 3160 mt lh Fe` llega con `compartimiento = "mt lh"`:
```
equipo         = Topic.p1
parametro      = If(CountRows(Topic.toks) >= 4, Last(Topic.toks).Value, "")
compartimiento = If(CountRows(Topic.toks) >= 4,
                    Trim(Concat(FirstN(LastN(Topic.toks, CountRows(Topic.toks) - 2), CountRows(Topic.toks) - 3), Value, " ")),
                    Topic.p2)
```
**Ajuste (01/10):** pasar `""` cuenta como «ya respondido» y el tema **no pregunta**: corre el flujo vacío y
sale «No encontré datos» antes de la pregunta (N2). Lo que falta se pasa como **`Blank()`**, y con 3 tokens se
mira si `p2` es un metal para saber qué falta:
```
Topic.esMetal2 = IsMatch(Lower(Topic.p2), "^(fe|cu|cr|ni|pb|sn|al|si|pq|ca|zn|mg|k|na|b|p|mo|v100|v40|tbn|tan|hierro|cobre|cromo|niquel|plomo|estaño|aluminio|silicio|sodio|potasio)$")
parametro      = If(CountRows(Topic.toks) >= 4, Last(Topic.toks).Value, If(Topic.esMetal2, Topic.p2, Blank()))
compartimiento = If(CountRows(Topic.toks) >= 4,
                    Trim(Concat(FirstN(LastN(Topic.toks, CountRows(Topic.toks) - 2), CountRows(Topic.toks) - 3), Value, " ")),
                    If(Topic.esMetal2 || Topic.p2 = "", Blank(), Topic.p2))
```
`/grafica 3160 Fe` → pregunta el componente · `/grafica 3160 mtlh` → pregunta el metal.

⛔ **Pero `Blank()` solo no basta (01/10, medido):** un tema **redirigido** con «Ir a tema» NO pregunta sus
entradas vacías — eso lo hace el orquestador solo cuando él llama al tema. Con `Blank()` la Acción corre
igual y el flujo responde `FlowActionBadRequest` («el parámetro necesario … tiene un valor en blanco»).
⇒ **El Tema 09 lleva sus propias preguntas** antes de la Acción: por cada entrada obligatoria, Condición
«está en blanco» → nodo **Pregunta** (Respuesta completa del usuario) que guarda en esa misma variable.
Sirve para comando y para lenguaje natural. **Toda rama del Tema 00 que deje una entrada obligatoria vacía
necesita lo mismo en su tema destino** (revisar en C5 / N2).

**`/ranking ‹proyecto› ‹componente› ‹metal› [modelo] [top]`** — `p4` puede ser modelo o top. Regla: **1-2
dígitos = top**; cualquier otra cosa = modelo. Así `980` (3 dígitos) es modelo y `5` es top:
```
Topic.p5 = If(CountRows(Topic.toks) >= 6, Index(Topic.toks, 6).Value, "")      // variable nueva
modelo   = If(Topic.p4 = "" || IsMatch(Topic.p4, "^\d{1,2}$"), "todos", Topic.p4)
top      = If(IsMatch(Topic.p4, "^\d{1,2}$"), Topic.p4, If(IsMatch(Topic.p5, "^\d{1,2}$"), Topic.p5, "10"))
```
`/ranking antapaccay tracción Fe 5` → todos, 5 · `… Fe 980` → 980, 10 · `… Fe 980 5` → 980, 5.

### 4) `/comandos` y `/ayuda` → **«Enviar un mensaje»** con TARJETA ADAPTABLE (tabla completa)
**Opción A (recomendada): Adaptive Card en un nodo «Enviar un mensaje».** ⚠ **NO** uses el **«Nodo de tarjeta adaptable»**
(ese es la variante PREGUNTA: exige un `Action.Submit` y **BLOQUEA** el tema hasta que el usuario haga clic → invasivo).
En la rama `cmd="/comandos"` (y `="/ayuda"`) → **«Enviar un mensaje»** → dentro del mensaje **agrega una tarjeta adaptable**
→ pega el JSON de **`docs/copilot/tarjetas/comandos_card.json`** (Por-equipo + Por-flota, 21 comandos, v1.5, **SIN** botón).
Así solo se MUESTRA y el tema termina → el usuario puede lanzar otro comando enseguida. ⚠ Ajusta si el canal soporta ≤1.4.
**Opción B (texto plano, fallback):** ⚠ usa **‹ ›** para los requeridos, NO `< >` (en cards y mensajes markdown los `<x>` se leen como etiqueta HTML y **se borran** → perderías el parámetro, ej. `/barrido <proj>` salía como `/barrido`).
```
**Comandos** (escribe `/` + módulo + parámetros). Componente = tracción/hidráulico/rueda/mando/transmisión/motor.
POR-EQUIPO:  /ultimo ‹eq› ‹comp› · /condicionmt ‹eq› · /diagcompleto ‹eq›
             /tendencia ‹eq› ‹comp›
             /grafica ‹eq› ‹comp› ‹metal› · /historial ‹eq› ‹comp› [rango] · /historialeq ‹eq›
             /historialmetal ‹eq› ‹metal› [comp] · /acumulados ‹eq›
POR-FLOTA:   /panel ‹proj› [modelo] · /barridodet ‹proj› [modelo] · /triage ‹comp› ‹proj› [modelo]
             /incipiente ‹proj› [comp] [modelo] · /ranking ‹proj› ‹comp› ‹metal› [modelo] [top]
             /metalflota ‹proj› ‹comp› ‹metal(es)› [modelo] · /historialflota ‹proj› · /rankingacum ‹proj› · /rankinggraf ‹proj›
```

### 5) Rama «ninguna coincide» (comando `/xxx` no reconocido) → Mensaje + Finalizar
Como el disparador ya evita que entre NL, llegar aquí = un `/palabra` que fue intento de comando pero no está en la lista
(típico: typo `/barido`). Nodo **«Mensaje»**: `No reconocí «/…». Escribe **/comandos** para ver la lista.` → **«Finalizar tema actual»**.
> ⛔ NO uses aquí «Varios temas relacionados» / «Restablecer conversación» / «Transferir conversación» — no re-rutean a NL
> (son desambiguación / reset de contexto / escalado a humano, respectivamente).

### 6) Probar en el test de Copilot
`/comandos` → lista · `/rankingacum Antapaccay` → tema 27 · `/acumulados CA3197` → tema 28 ·
`/triage rueda Antamina` → tema 19 · `/barrido Antapaccay 980E` → tema 16. Verifica que redirige y que los inputs llegan.

### 7) Teams (después de que el dispatcher funcione)
En el manifiesto de la app de Teams, agregar un **commandList** con los mismos comandos → aparecen en el menú del bot;
al elegir uno envía el texto → lo maneja este mismo tema. (El dispatcher no cambia.)

## Futuro
- **Tarjetas adaptables** (Adaptive Cards) = comandos VISUALES: un botón por módulo que dispara el mismo redirect con params.
- Autocompletar/menú de comandos si Copilot lo permite.
