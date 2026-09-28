# avance-semanal/ — un reporte por semana y por proyecto

## Qué es y para qué sirve

Un `.md` corto por **semana** y por **proyecto**, con frontmatter YAML, que cuenta qué se avanzó. Tiene tres
consumidores:

1. **La automatización con Claude** — el frontmatter (`proyecto`, `semana_inicio`, `magnitud`,
   `responsables`) es lo que se lee de forma programática; el cuerpo es lo que se resume.
2. **El acta de gerencia** — `../gerencia/ACTA DE REUNION_PROYECTOS DE DESARROLLO CONFIABILIDAD.xlsx`, que se
   presenta cada viernes. El avance semanal es el insumo; el acta es la salida.
3. **Una automatización aparte en Claude Desktop**, que también lee esta carpeta como fuente.

⚠ Por el punto 3, la carpeta **no se reorganiza ni se renombra sin avisar**: hay algo fuera de este
repositorio que depende de su ruta y de su formato.

Por eso **se escribe todas las semanas, aunque el avance sea mínimo o nulo**: una semana sin archivo es un
hueco en la serie, y la automatización no distingue «no pasó nada» de «nadie lo escribió». Para eso está
`magnitud: nula`.

## Por qué INVERTEX está acá

Porque el **acta es una sola** y cubre los dos proyectos, y la automatización los lee juntos. INVERTEX tiene
su propio repositorio (`Invertex-Analytics-Ultra`), pero su reporte semanal vive acá, al lado del de KomfIA,
para que la serie quede completa en un solo lugar. Si algún día se separan, se separan los dos: el acta
primero.

## Convención de nombres

```
AAAA-MM-DD_PROYECTO.md      ← la fecha es el LUNES de la semana
2026-09-14_KOMFIA.md
2026-09-14_INVERTEX.md
```

El `_KOMFIA` era implícito hasta el 27/09/26 (el archivo se llamaba `2026-09-14.md`); ahora los dos llevan
sufijo, para que ordenen juntos y no haya un proyecto «por defecto».

## Cómo se escribe uno

Copiar [`_PLANTILLA.md`](_PLANTILLA.md), renombrar con el lunes de la semana y el proyecto, y llenar.
Reglas cortas:

- **Frontmatter completo.** `magnitud` es `nula` · `minima` · `media` · `grande` — es el campo que la
  automatización usa para decidir cuánto espacio le da en el acta.
- **Un ítem = un avance**, cada uno con su **Estado**: `hecho` · `en progreso` · `planeado` · `pendiente`.
- **Decir dónde quedó**: archivo tocado, versión, commit o «desplegado en Copilot Studio».
- **Los pendientes no se listan acá**: van a [`../copilot/PENDIENTES.md`](../copilot/PENDIENTES.md). Acá solo
  se los menciona como estado de un avance.

## Serie

| Semana | KomfIA | INVERTEX |
|---|---|---|
| 2026-09-14 → 09-20 | [`2026-09-14_KOMFIA.md`](2026-09-14_KOMFIA.md) (media) | [`2026-09-14_INVERTEX.md`](2026-09-14_INVERTEX.md) (grande) |
| 2026-09-21 → 09-27 | — falta | — falta |

> El ritual arrancó el 14/09/26. Lo anterior a esa fecha no tiene reporte semanal: para esas semanas la
> fuente es [`../BITACORA.md`](../BITACORA.md) y el historial de commits.
