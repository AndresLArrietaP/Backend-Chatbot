# Config canónica — COMANDOS (atajos deterministas a los módulos) · PLAN (por implementar)

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
/condicion <equipo>                          → 02 Condición MT
/diagnostico <equipo>                        → 03 Diagnóstico equipo
/diagcompleto <equipo>                        → 04 Diagnóstico completo
/tendencia <equipo> <componente>             → 05 Tendencia (paso 1)
/tendenciadet <equipo> <componente>          → 06 Tendencia detalle
/tendenciametal <equipo> <metal>             → 08 Tendencia de un metal (todos los comp)
/grafica <equipo> <componente> <metal>       → 09 Gráfica de un metal
/historial <equipo> <componente>             → 11 Historial de componente
/historialeq <equipo>                        → 12 Historial general del equipo
/historialmetal <equipo> <metal> [componente]→ 13/14 Historial de un metal (equipo / componente)
/acumulados <equipo>                         → 28 Acumulados de un equipo (motor diésel)

POR-FLOTA
/barrido <proyecto> [modelo]                 → 16 Barrido resumen
/barridodet <proyecto> [modelo]              → 17 Barrido detalle
/triage <componente> <proyecto> [modelo]     → 19 Triage de un componente en la flota
/incipiente <proyecto>                       → 20 Tendencia incipiente
/conteo <proyecto> [modelo]                  → 21 Conteo de flota
/ranking <proyecto> <componente> <metal> [top]      → 22 Ranking de un metal
/metalflota <proyecto> <componente> <metal(es)> [modelo] → 25 Último por metal en la flota  (metales: coma-sin-espacio Fe,Cu)
/historialflota <proyecto>                   → 15 Historial de observados de flota
/rankingacum <proyecto>                      → 27 Ranking de acumulados (motor diésel)

META
/comandos  ó  /ayuda                         → lista de comandos
```
> Posicional. Si un parámetro requerido falta, el tema destino lo **pide en el chat** (comportamiento ya existente).
> ⚠ **`/metalflota` pasa 4 inputs al Tema 25** (proyecto, modelo, compartimiento, parametros) — mapear `modelo=If(p4="","(todos)",p4)`.

## Cobertura de temas (re-auditoría 2026-09-05)
| Tema | Comando | Tema | Comando |
|---|---|---|---|
| 01 Último comp. | `/ultimo` | 15 Historial flota | `/historialflota` |
| 02 Condición MT | `/condicion` | 16 Barrido resumen | `/barrido` |
| 03 Diagnóstico | `/diagnostico` | 17 Barrido detalle | `/barridodet` |
| 04 Diag. completo | `/diagcompleto` | 18 Barrido filtrado | — *(variante: "solo críticos" como follow-up del barrido)* |
| 05 Tendencia p1 | `/tendencia` | 19 Triage | `/triage` |
| 06 Tendencia det. | `/tendenciadet` | 20 Incipiente | `/incipiente` |
| 07 Tend. relevantes | — *(continuación de 05/06)* | 21 Conteo | `/conteo` |
| 08 Tend. de un metal | `/tendenciametal` | 22 Ranking | `/ranking` |
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
> "Se activa SOLO cuando el mensaje empieza con una BARRA pegada a un comando conocido (sin espacio): `/barrido`,
> `/triage`, `/ultimo`, `/tendencia`, `/acumulados`, `/rankingacum`, `/comandos`… Ejecuta el atajo directo al módulo.
> ⛔ NO si es lenguaje natural aunque contenga `/` (ej. «/ ¿qué equipos…?» con espacio tras la barra) → eso es una consulta normal."

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
```
> ⚠ Verificar en el editor que la columna de `Split` se llame **`Value`** (si no, ajustar `.Value`).

### 3) Nodo Condición en cascada (Switch por `Topic.cmd`) → setea inputs y «Redirigir a otro tema»
Por cada rama: `Topic.cmd = "/xxx"` → mapear los inputs del tema destino y redirigir. Defaults con `If(p="","default",p)`:

| `cmd` | Redirige a | Inputs a pasar (desde p1..p4) |
|---|---|---|
| `/ultimo` | 01 Último análisis | equipo=p1 · compartimiento=p2 |
| `/condicion` | 02 Condición MT | equipo=p1 |
| `/diagnostico` | 03 Diagnóstico | equipo=p1 |
| `/diagcompleto` | 04 Diagnóstico completo | equipo=p1 |
| `/tendencia` | 05 Tendencia p1 | equipo=p1 · compartimiento=p2 |
| `/tendenciadet` | 06 Tendencia detalle | equipo=p1 · compartimiento=p2 |
| `/tendenciametal` | 08 Tendencia de un metal | equipo=p1 · parametro=p2 |
| `/grafica` | 09 Gráfica | equipo=p1 · compartimiento=p2 · parametro=p3 |
| `/historial` | 11 Historial componente | equipo=p1 · compartimiento=p2 |
| `/historialeq` | 12 Historial equipo | equipo=p1 |
| `/historialmetal` | 13/14 Historial de un metal | equipo=p1 · parametro=p2 · compartimiento=p3 (vacío→13; con comp→14) |
| `/acumulados` | 28 Acumulados equipo | equipo=p1 |
| `/barrido` | 16 Barrido resumen | proyecto=`If(p1="","Antapaccay",p1)` · modelo=`If(p2="","(todos)",p2)` |
| `/barridodet` | 17 Barrido detalle | proyecto=`If(p1="","Antapaccay",p1)` · modelo=`If(p2="","(todos)",p2)` |
| `/triage` | 19 Triage | compartimiento=`If(p1="","tracción",p1)` · proyecto=`If(p2="","Antapaccay",p2)` · modelo=`If(p3="","(todos)",p3)` |
| `/incipiente` | 20 Tendencia incipiente | proyecto=`If(p1="","Antapaccay",p1)` |
| `/conteo` | 21 Conteo | proyecto=`If(p1="","Antapaccay",p1)` · modelo=`If(p2="","(todos)",p2)` |
| `/ranking` | 22 Ranking | proyecto=p1 · compartimiento=p2 · parametro=p3 · top=`If(p4="","10",p4)` |
| `/metalflota` | 25 Último por metal flota | proyecto=`If(p1="","Antapaccay",p1)` · compartimiento=`If(p2="","tracción",p2)` · parametros=p3 · **modelo=`If(p4="","(todos)",p4)`** ⟵ 4º input |
| `/historialflota` | 15 Historial obs. flota | proyecto=`If(p1="","Antapaccay",p1)` |
| `/rankingacum` | 27 Ranking acumulados | proyecto=`If(p1="","Antapaccay",p1)` |
| `/comandos` ó `/ayuda` | (nodo Mensaje, ver 4) | — |
| (ninguna coincide) | **«Ir a otro tema» → Conversación** | — (era NL con `/`, no un comando) |

> ⚠ **Tema 25 (`/metalflota`) tiene 4 entradas** (proyecto, modelo, compartimiento, parametros): mapea las 4, con `modelo=If(p4="","(todos)",p4)`.
> Si un input requerido va vacío (equipo en los por-equipo), el tema destino lo **pide en el chat** (ya existente).

### 4) `/comandos` y `/ayuda` → nodo Mensaje con **TARJETA ADAPTABLE** (tabla completa)
**Opción A (recomendada, visual): Adaptive Card.** En la rama `cmd="/comandos"` (y `="/ayuda"`) → nodo **«Mensaje»**
→ **«…» → Agregar tarjeta adaptable** → pega el JSON de **`docs/copilot/tarjetas/comandos_card.json`** (tabla
Por-equipo + Por-flota, 21 comandos, versión 1.5). Así el usuario ve la tabla completa aunque aún falten comandos por
cablear (la tarjeta ya los lista todos). ⚠ Ajusta si tu canal soporta ≤1.4 (el `Table` es 1.5; en Teams va bien).
**Opción B (texto plano, fallback):**
```
**Comandos** (escribe `/` + módulo + parámetros). Componente = tracción/hidráulico/rueda/mando/transmisión/motor.
POR-EQUIPO:  /ultimo <eq> <comp> · /condicion <eq> · /diagnostico <eq> · /diagcompleto <eq>
             /tendencia <eq> <comp> · /tendenciadet <eq> <comp> · /tendenciametal <eq> <metal>
             /grafica <eq> <comp> <metal> · /historial <eq> <comp> · /historialeq <eq>
             /historialmetal <eq> <metal> [comp] · /acumulados <eq>
POR-FLOTA:   /barrido <proj> [modelo] · /barridodet <proj> [modelo] · /triage <comp> <proj> [modelo]
             /incipiente <proj> · /conteo <proj> [modelo] · /ranking <proj> <comp> <metal> [top]
             /metalflota <proj> <comp> <metal(es)> [modelo] · /historialflota <proj> · /rankingacum <proj>
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
