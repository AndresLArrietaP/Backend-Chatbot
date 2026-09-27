# Marcha alfa 2026-09-23 — primera prueba DIRECTA por gerencia

**Quién probó:** el ingeniero **triólogo**, con la cuenta de Confiabilidad recién habilitada, en Teams.
Es la primera vez que las pruebas **no** las corre el dev. Resultado: el sistema respondió — no hubo caídas —
y lo que salió fueron **14 observaciones de formato, dato y nomenclatura**.

> Backlog con el plan de ataque: [../copilot/PENDIENTES.md](../copilot/PENDIENTES.md) → sección **RONDA 23/09**.

## Lo que funcionó
`/barridodet` (Antapaccay y Antamina) · `/rankingacum` · `/rankinggraf` · `/ultimo` (MT LH, motor, hidráulico) ·
`/diagcompleto` · `/tendencia` · `/tendenciadet` · `/tendenciametal` · `/grafica` · `/historial*` · `/acumulados`.
Los módulos nuevos de esta semana (`/rankinggraf`, incipiente) se comportaron bien.

## Los 2 «errores» que aparecieron
| Síntoma | Veredicto |
|---|---|
| `/ultimo` no devolvía datos | **No era un bug.** El chat se había abierto desde una cuenta personal en vez de desde Copilot Studio con la cuenta de Confiabilidad. |
| `/diagnostico 3160` → «No encontré datos» | **Sí es un fallo**, y fue el único. Pero el módulo está marcado para **eliminarse**: `/diagcompleto` lo reemplaza. Revisar la causa antes de borrarlo, por si es compartida. |

## Las 14 observaciones
Están mapeadas una a una — con dónde se arregla cada una — en la tabla del backlog. Resumen por naturaleza:

- **4** son renombres o recortes de texto (`SMR`, `T. muestra`, `Nº fuera de límite`, subtítulo de `/acumulados`).
- **1** es un **dato incorrecto**: Σvida.
- **5** son el **formato por componente** (grupos, orden, nulos, límites) — el bloque grande.
- **2** son módulos que heredan ese formato (`/diagcompleto`, `/condicionmt`).
- **2** son análisis y recomendaciones (prompt y pie de correo).

## Los dos archivos que entregó el triólogo
Ambos en `docs/gerencia/`, y ambos ya analizados y volcados al repo:

| Archivo | Qué define | Volcado en |
|---|---|---|
| `Requerimientos Analisis Aceite 1.xlsx` | el **formato** (orden y agrupación de parámetros) por componente: MT, RD, SH, MODI | [FORMATO_POR_COMPONENTE.md](../arquitectura/FORMATO_POR_COMPONENTE.md) |
| `LIMITES CONDENATORIOS 1.xlsm` | los **límites** completos (64 filas × ~40 parámetros) | [LIMITES_FALLBACK.md](../arquitectura/LIMITES_FALLBACK.md) + `DDL_vw_LimitesFallback.sql` (524 filas) |

### Dos hallazgos del análisis de esos archivos
1. **Los aditivos tienen el límite invertido.** 46 de los 47 pares con `LP > LC` son aditivos (`P`, `Zn`, `Ca`,
   `Mg`, `B`) y `TBN`: el aditivo se **agota**, la alerta es por **debajo**. Hoy los evaluamos al revés.
2. **Cuajone y Toquepala no están en el archivo de límites.** Su «sin límites cargados» es real, no un hueco
   de la BD, y el fallback **no** lo resuelve. Es pregunta para gerencia.

## Nota operativa
El chat de prueba se abre **desde Copilot Studio**. La cuenta de Confiabilidad pasa a ser compartida; no se
prueba desde cuentas personales (de ahí el falso error de `/ultimo`).
