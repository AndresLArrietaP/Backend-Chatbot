# Config canónica — COMANDOS (atajos deterministas a los módulos) · PLAN (por implementar)

Ver [CONFIG_TEMAS.md](CONFIG_TEMAS.md), [CONFIG_FLUJOS.md](CONFIG_FLUJOS.md), [CONFIG_PROMPTS.md](CONFIG_PROMPTS.md).
Estado: **DISEÑO** (2026-08-23). Se implementa la próxima sesión.

## Idea
Un **comando** = atajo directo a un módulo con **parámetros explícitos**, saltándose la orquestación por
descripción (cero ambigüedad de ruteo, respuesta inmediata). Para el **ingeniero que ya sabe qué quiere**.
La conversación natural sigue igual (los temas por descripción no se tocan); el comando es una **vía rápida paralela**.

## Sintaxis (propuesta: prefijo `/` + módulo + parámetros posicionales)
```
/barrido <proyecto> [modelo]              → Tema 16 (barrido resumen)
/barridodet <proyecto> [modelo]           → Tema 17 (barrido detalle)
/triage <compartimiento> <proyecto> [modelo]  → Tema 19 (triage evolucionado)
/ultimo <equipo> <compartimiento>         → Tema 01
/diagnostico <equipo>                     → Tema 03
/tendencia <equipo> <compartimiento>      → Tema 05
/grafica <equipo> <compartimiento> <metal>→ Tema 09
/historial <equipo> [compartimiento]      → Tema 11/12
/conteo <proyecto> [modelo]               → Tema 21
/ranking <proyecto> <compartimiento> <metal> [top]  → Tema 22 (ranking de un metal)
/metalflota <proyecto> <compartimiento> <metal(es)> → Tema 25 (último de un metal en la flota)
/acumulados <equipo>                      → Tema 28 (acumulados de un equipo)
/rankingacum <proyecto>                   → Tema 27 (ranking de acumulados)
/comandos  ó  /ayuda                      → lista de comandos
```
> Posicional = más ágil para el ingeniero. Si un parámetro falta, el tema destino lo **pide en el chat** (como ya
> hace). Alternativa robusta `clave=valor` (`/barrido proyecto=Antapaccay modelo=980E`) — evaluar si el posicional confunde.

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

## Futuro
- **Tarjetas adaptables** (Adaptive Cards) = comandos VISUALES: un botón por módulo que dispara el mismo redirect con params.
- Autocompletar/menú de comandos si Copilot lo permite.
