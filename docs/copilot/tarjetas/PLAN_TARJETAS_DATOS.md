# PLAN — Datos de los módulos en Tarjetas Adaptables (no solo texto)

Objetivo: que la salida de cada módulo/tópico (hoy una tabla **markdown** en el chat) se muestre como **tarjeta adaptable**
con tabla real, color por celda y mejor diseño. Estado: **PLAN** (2026-09-17). Ver [CONFIG_COMANDOS.md](../CONFIG_COMANDOS.md).

## Cómo se "conecta" la data a una tarjeta (2 arquitecturas)
Una Adaptive Card necesita **datos estructurados** (JSON), no un blob markdown. Hay 2 caminos:

**A) La VISTA arma el card-JSON** (igual que hoy arma el `MD`, pero en vez de markdown emite el JSON de la tarjeta/sus filas).
- El flujo devuelve ese JSON y el nodo de tarjeta lo renderiza. **Reusa el patrón que ya dominamos** (STRING_AGG en la vista).
- ⚠ Armar JSON en T-SQL es más frágil (comillas, escapes, `\n`) → se mitiga con **generador + validación** (como hicimos con las vistas MD) y usando `STRING_ESCAPE(x,'json')` para el texto de cada celda.

**B) El FLUJO devuelve FILAS estructuradas + la tarjeta usa templating (`$data`)**
- La tarjeta lleva un template: una `TableRow` con `"$data": "${filas}"` que se **repite por cada fila**; las celdas bindean `${Equipo}`, `${Fe}`, etc.
- Más limpio y mantenible, PERO depende de que **Copilot Studio soporte el repeat `$data`** en su nodo de tarjeta (⚠ A VERIFICAR; el soporte de templating en Copilot es parcial). El flujo tendría que devolver el resultset como arreglo (no como MD).

**Recomendación:** **piloto con A** (reusa lo conocido; no depende de features inciertas). Si al verificar, Copilot soporta bien `$data` → migrar a **B** (más escalable). En ambos, la lógica/semáforo/límites siguen viviendo en la VISTA.

## Qué SÍ y qué NO se puede (personalización — honesto)
- ✅ **Color de fondo POR CELDA:** `TableCell.style` = `attention` (rojo) · `warning` (ámbar) · `good` (verde) · `accent`.
  → semáforo REAL por celda (mejor que el emoji 🟥/🟨 actual). Es la mejora visual más grande y factible.
- ✅ Encabezados, secciones, íconos, negritas, columnas con ancho relativo, footers (como en `/comandos`).
- ✅ Contenedores con fondo (`Container style:"emphasis"`), FactSet para pares clave-valor.
- ⛔ **Celdas COMBINADAS (colspan/rowspan): NO** — el elemento `Table` de Adaptive Cards no las soporta. Los bosquejos
  Excel con merges **no se replican tal cual**; se APROXIMAN con secciones + sub-tablas + `ColumnSet` anidados (no una grilla arbitraria).
- ⚠ **Tamaño:** una tarjeta en Teams ~**28 KB**; una flota grande (100+ filas) puede no caber → paginar / resumir / “ver más”.
- ⚠ Markdown dentro de celdas es limitado; los `‹...›` se borran (usar guillemets, ya aprendido).

## Implicación arquitectónica
Hoy las vistas devuelven `MD` (markdown). Para tarjetas, la vista devolvería el **card-JSON** (opción A) o el **resultset** (opción B).
- Mantener **AMBAS salidas un tiempo**: `MD` (fallback texto, canales sin cards) + `card` (preferida). El tópico elige según canal.
- Migrar **por módulo**, no todos de golpe.

## Piloto propuesto (1 módulo, medir antes de escalar)
Elegir uno acotado y de alto valor:
- **Candidato 1 — Acumulados de un equipo (28):** pocas filas (7 metales), ideal para probar color por celda y layout.
- **Candidato 2 — Triage / Barrido resumen:** más filas y semáforo → prueba el color-por-celda a escala + el límite de tamaño.
Entregable del piloto: 1 vista que emita card-JSON (opción A) + el nodo de tarjeta + medición (se ve bien, cabe, color OK) →
con eso decidimos el patrón definitivo y el roll-out por módulos.

## A verificar en Copilot Studio (antes de construir)
1. ¿El nodo de tarjeta soporta **templating `$data`** (repeat de filas)? → decide A vs B.
2. ¿Se puede pasar un **JSON largo** desde el flujo al nodo de tarjeta como variable? (tamaño / escape).
3. Render de `TableCell.style` (colores) en el **test de Copilot** y en **Teams** (pueden diferir).
4. Límite real de tamaño de tarjeta en el canal objetivo (Teams).

## Orden sugerido
1. Verificar (1-4). 2. Piloto opción A en Acumulados-equipo. 3. Evaluar diseño/tamaño. 4. Definir patrón. 5. Roll-out por módulo (MD como fallback).
