# Config canónica — PROMPTS (AI Builder / nodo Solicitud)

Parte de la config. Ver [CONFIG_FLUJOS.md](CONFIG_FLUJOS.md), [CONFIG_TEMAS.md](CONFIG_TEMAS.md).

## Prompt ÚNICO universal: `Análisis de aceite`
- **Tipo:** Solicitud (AI Builder / prompt), NO "Crear respuestas generativas" (retrieval, que alucina/cuelga).
- **Modelo:** GPT-4.1 mini (rápido, ~0.2 créditos). Suficiente.
- **Sin conocimiento** (0 orígenes). Lee SOLO `{tabla}`.
- **Entrada:** `tabla` (Texto) — descripción: "Tabla markdown ya armada del módulo (columna MD); único insumo del análisis."
- **Salida:** record `predictionOutput` → imprimir **`{analisis.text}`** (no el record).
- **Instrucciones:** las del prompt universal en **`docs/copilot/prompts/analisis_prompts.md`** (reconoce si la
  tabla es vertical / matriz de componentes / tendencia por fechas; 🟥=crítico, 🟨=precaución, inf=informativo
  elevado no crítico, — / · =sin dato; máx 4-5 viñetas gerenciales; si nada fuera de límite lo dice; no inventa).
- **Se usa en los temas:** Último análisis, Condición MT, Diagnóstico, Tendencia detalle, Tendencia relevantes,
  Tendencia de un metal, Triage MT. (Los "sin análisis" no lo incluyen.)

## Prompts NUEVOS (evaluar — ver ROADMAP)
- **Tendencia incipiente (#14):** probablemente **NO hace falta** un prompt aparte — el universal ya interpreta
  tendencias (sube/baja/pico, desviación del promedio). Reusar el universal con la vista `vw_TendenciaIncipienteMD`.
- Si a futuro se agregan tarjetas adaptables, el contenido lo sigue armando la vista (`MD`); el prompt no cambia.

> Regla: **1 prompt universal** para todo análisis; el `{md}` lleva la estructura y el modelo la interpreta.
> No crear prompts por módulo (lección: se probó y era redundante).
