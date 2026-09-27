# Marcha alfa 2026-09-18 — 1ª prueba VIVA con gerencia (MS Teams)

**Registro de la marcha.** Los pedidos que salieron de aquí viven en el backlog único:
[../copilot/PENDIENTES.md](../copilot/PENDIENTES.md). Este documento solo deja constancia de qué se probó,
qué falló y cómo se resolvió.

## Contexto
- **18/09/2026**, primeras pruebas alfa **con gerencia** en **MS Teams**, versión de desarrollo (el chat era
  visible solo para Andrés). Se probó **por comandos** (`/…`), no por lenguaje natural.
- Módulos ejercitados: `/barridodet`, `/tendencia`, `/tendenciadet`, `/incipiente`, `/historial`,
  `/rankingacum`, `/grafica`, `/comandos`.

## Hallazgos y resolución

### 1. Tablas rotas en Teams → RESUELTO (19/09)
`/barridodet` y los cuadros «Límites de referencia» salían como un **muro de texto**, mientras que tendencia,
historial y rankingacum sí renderizaban bien.
**Causa raíz:** markdown exige una **línea en blanco antes de una tabla**; esos bloques pegaban el
`**encabezado**` a la tabla con un solo `NCHAR(10)`, así que Teams no la reconocía. Corregido en 6 puntos del DDL.
**Regresión:** `VALIDACION_SSMS.sql` BLOQUE 68.

### 2. Rótulo «inf» → ELIMINADO (19/09)
Pedido del usuario: la clasificación «inf» de Ca/Zn/K/Na/Mg «nunca fue válida». Eliminada de **todas** las
vistas y del conocimiento `Formatos_de_Respuesta`. Esos metales siguen mostrando su chip 🟥/🟨 y **siguen sin
alterar el Estado**; solo desapareció la etiqueta.

### 3. Rendimiento del barrido: 6:21 → 19,5 s → RESUELTO (19/09)
Se descartaron con mediciones tres hipótesis (caché frío, el `LEFT JOIN` a `HsCc`, el nº de referencias a la
fundación). El cuello se encontró **aislando por mitades**: tabla-por-equipo 2 s vs cuadro-de-límites 33 s.
Dentro de esa mitad, un CTE referenciado dos veces + `JOIN` entre sus ramas caía en *nested loops* y
re-ejecutaba la fundación **257 veces**. **Fix:** `sev` por función de ventana sobre una sola referencia.
`Oil.LaboratoryData`: 257 scans/25,3 M lecturas → 14 scans/576 K. Salida idéntica (`EXCEPT` = 0).
**Regresión:** BLOQUE 69.

### 4. `Met_Obs` no determinista → CORREGIDO (19/09)
Se ordenaba con `ORDER BY NumCrit DESC` **sin desempate**: con componentes empatados (hay equipos con 5) el
orden lo decidía el plan, así que **la misma consulta renderizaba distinto entre ejecuciones**. Añadido
`, Compartimiento`. Era el único de los 25 `STRING_AGG` del DDL sin desempate. **Regresión:** BLOQUE 70.

### 5. Componente compuesto en comandos → CORREGIDO (18/09)
`/tendenciadet 3177 MT RH` devolvía **LH**: el `Split(" ")` mandaba `RH` a un parámetro que el tema ignoraba.
Fix con variables `resto1`/`resto2` que unen la cola de tokens. Ver [PRUEBAS_ALFA_COMANDOS.md](PRUEBAS_ALFA_COMANDOS.md).

## Pedidos de gerencia que salieron de la sesión
Cinco, todos con su decisión ya tomada por el usuario y priorizados **P4 → P5 → P3 → P1 → P2**:
historial con rango · `/rankinggraf` · personalizar incipiente · fusionar tendencia+detalle con resumen
gerencial · validar Σvida. **Detalle y plan → [../copilot/PENDIENTES.md](../copilot/PENDIENTES.md).**
