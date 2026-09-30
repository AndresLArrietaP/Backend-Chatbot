# Config canónica — PROMPTS (AI Builder / nodo Solicitud)

> **Familia CONFIG** — lo que está aplicado en Copilot Studio:
> [CONFIG_TEMAS](CONFIG_TEMAS.md) (temas/tópicos) · [CONFIG_FLUJOS](CONFIG_FLUJOS.md) (Power Automate) ·
> [CONFIG_COMANDOS](CONFIG_COMANDOS.md) (atajos `/`) · [CONFIG_PROMPTS](CONFIG_PROMPTS.md) (nodos de IA) ·
> [CONFIG_TIMEOUT](CONFIG_TIMEOUT.md) (reintentos y cortes).
> Backlog único: [PENDIENTES](PENDIENTES.md). Historia del proyecto: [../BITACORA.md](../BITACORA.md).

Parte de la config. Ver [CONFIG_FLUJOS.md](CONFIG_FLUJOS.md), [CONFIG_TEMAS.md](CONFIG_TEMAS.md).

## Prompt ÚNICO universal: `Análisis de aceite`
- **Tipo:** Solicitud (AI Builder / prompt), NO "Crear respuestas generativas" (retrieval, que alucina/cuelga).
- **Modelo:** GPT-4.1 mini (rápido, ~0.2 créditos). Suficiente.
- **Sin conocimiento** (0 orígenes). Lee SOLO `{tabla}`.
- **Entrada:** `tabla` (Texto) — descripción: "Tabla markdown ya armada del módulo (columna MD); único insumo del análisis."
- **Salida:** record `predictionOutput` → imprimir **`{analisis.text}`** (no el record).
- **Instrucciones:** las del prompt universal en **`docs/copilot/prompts/analisis_prompts.md`** (reconoce si la
  tabla es vertical / matriz de componentes / tendencia por fechas; 🟥=crítico, 🟨=precaución, el grupo manda
  la dirección, — =sin dato; máx 5 viñetas; si nada fuera de límite lo dice; no inventa; ⛔ nunca redibuja
  ni filtra la tabla).
- **Se usa en los temas:** Último análisis, Condición MT, Diagnóstico, Tendencia detalle, Tendencia relevantes,
  Tendencia de un metal, Triage MT. (Los "sin análisis" no lo incluyen.)

## Prompt 2: `Ayuda KomfIA` (Tema 26 — Ayuda / Glosario)
- **Tipo:** Solicitud (AI Builder), **sin conocimiento** — el glosario va DENTRO del prompt.
- **Modelo:** GPT-4.1 mini.
- **Entrada:** `pregunta` (Texto) = el mensaje del usuario (ej. `System.Activity.Text`).
- **Salida:** imprimir **`{ayuda.text}`**.
- **Instrucciones:** texto completo en **`docs/copilot/prompts/ayuda_glosario.md`** (glosario CM/LP/LC/semáforo/
  metales/componentes/módulos + qué puede preguntar; responde breve; ⛔ no inventa cifras y reencamina las
  consultas de datos reales a su módulo).
- **Tema:** SIN flujo/SQL (Disparo → Solicitud → Mensaje → Finalizar). Hogar de las consultas simples/conceptuales.

## Prompt 3: `Formato` (fallback — Herramientas → «Formato», la elige el orquestador)
- **Tipo:** Solicitud (AI Builder), **sin conocimiento**. Va tras el agente KomfIA SQL.
- **Entrada:** `filas` (Texto) = la salida JSON de KomfIA SQL.
- **Instrucciones:** **`docs/copilot/prompts/formateo_fallback.md`**. Desde el 30/09 (C2) responde en **viñetas
  con prefijo 🔎**, nunca con tabla: una tabla en KomfIA significa «salió de una vista».
- Las instrucciones de los dos agentes van en **`KomfIA_central_MD.docx`** y **`KomfIA_SQL_MD.docx`**, con el
  mismo contrato (viñetas, sin tabla; un comando `/` sin datos no se completa con el fallback).

## Prompts NUEVOS (evaluar — ver ROADMAP)
- **Tendencia incipiente (#14):** probablemente **NO hace falta** un prompt aparte — el universal ya interpreta
  tendencias (sube/baja/pico, desviación del promedio). Reusar el universal con la vista `vw_TendenciaIncipienteMD`.
- Si a futuro se agregan tarjetas adaptables, el contenido lo sigue armando la vista (`MD`); el prompt no cambia.

> Regla: **1 prompt universal** para todo análisis; el `{md}` lleva la estructura y el modelo la interpreta.
> No crear prompts por módulo (lección: se probó y era redundante).
