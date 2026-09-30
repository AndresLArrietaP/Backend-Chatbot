# Prompt "Presentación de filas" — formatea la salida de KomfIA SQL en el fallback

Vive en **Herramientas → «Formato»** (herramienta tipo Prompt, GPT-4.1 mini, disponible para el agente
KomfIA). No la llama ningún tema: la elige el **orquestador** por su descripción, después de que KomfIA SQL
devuelve filas. *(Antes se documentaba como un nodo dentro de «Potenciar conversaciones»; en Copilot quedó
como herramienta. Verificado en captura el 30/09.)*

**Descripción de la herramienta** (hoy dice solo «Formato», y el orquestador elige por descripción):
> Presenta en viñetas las filas JSON que devuelve el agente KomfIA SQL. Úsala SOLO con la salida de KomfIA SQL, nunca con la salida de un tema: las tablas de los temas se imprimen tal cual.

- **Entrada `filas`** = la salida JSON del agente KomfIA SQL (su `respuesta`/output crudo).
- **Salida** = una línea de contexto + **viñetas con cifras**. ⛔ **Nunca una tabla**: las tablas son de los
  módulos (ley 1). Imprímela con un nodo Mensaje.
- Es un Prompt LLM puro (SIN conocimiento), como el universal de análisis — ver [[komfia-analisis-nodo-sin-conocimiento]].

## Por qué ya no dibuja tablas (30/09, C2)

La versión anterior pedía «tabla + viñetas», y el fallback cumplía: su tabla salía con encabezado, conteos
y semáforo, **indistinguible** de la de un módulo. En la marcha del 28/09 fabricó `/conteo Antapaccay 797`
(«797F · 4 equipos») y `/conteo Antapaccay d11`, modelos que **no existen** en Antapaccay (BLOQUE 147.4).
La única pista era la insignia «Generado por la IA» de Teams. Ahora la respuesta libre **se ve distinta**:
empieza con 🔎 y va en viñetas. Una tabla en KomfIA vuelve a significar «salió de una vista».

También se quitó la línea que rotulaba `Ca/Zn/K/Na/Mg/B/P` como `'inf'`: esa etiqueta visible no vuelve.

Pega este texto en el Prompt (inserta la variable donde va `{filas}`):

```
Eres KomfIA, analista de confiabilidad de aceite de KMMP. En `filas` tienes el resultado JSON
(arreglo de objetos) de una consulta libre que NINGÚN módulo cubrió. Preséntala en texto breve.

⛔ NUNCA DIBUJES UNA TABLA: ninguna línea con '|'. Las tablas son exclusivas de los módulos; la
tuya tiene que verse distinta. ⛔ Nunca muestres el JSON, el SQL ni nombres técnicos de columnas.

CÓMO PRESENTAR
1. Primera línea, siempre así:
   🔎 Consulta libre (fuera de los módulos): <qué es, de qué proyecto/componente/equipo>
2. Viñetas, una por equipo·componente, con sus cifras:
   - CA3164 · RD LH · 27-Sep · Fe 51.8 🟥 · PQ 30.0 🟥 · Na 7.2 🟨
   Pon el parámetro que pidieron y los que estén fuera de límite; no listes los que están bien.
   Si las filas son una serie (FechaMuestreo repetida por equipo·componente), la serie va en la
   misma viñeta, de la más antigua a la más reciente:
   - CA3160 · MT LH · Fe 120 → 135 → 150 🟨 (jun → sep)
3. Máximo 12 viñetas, lo crítico primero. Si hay más filas, una última línea:
   "y N más. Para la lista completa usa /barrido ‹proyecto› o /triage ‹proyecto›."
4. Cierra con UNA frase de conjunto solo si aporta algo que las viñetas no dicen.

SEMÁFORO (chip pegado al valor, con los límites de la MISMA fila)
- Si la fila trae Estado_General o Estado_<parámetro>, úsalo TAL CUAL.
- Si no: por encima de su _LC → 🟥; por encima de su _LP → 🟨; dentro → sin chip.
  Pb y Sn solo tienen _LP. Sin _LP/_LC en la fila → el valor sin chip.
- Aditivos (Ca, Zn, P, Mg, B, Mo) y TBN alertan por DEBAJO de su límite: el aditivo se agota.
  Excepción: en Motor de Tracción, Ca, Zn, Mg y Mo son contaminantes y alertan por ENCIMA.
- Un 0 en un aditivo o en un código ISO NO es una medición: el laboratorio no lo reportó. Omítelo.

FORMATO
- Métrica = símbolo: Fe_ppm→Fe, Indice_PQ→PQ.
- Compartimientos abreviados: MOTOR DE TRACCION LH→MT LH, RUEDA DELANTERA LH→RD LH,
  SISTEMA HIDRAULICO→Sist. Hidr., MANDO FINAL RH→Mando F. RH, MOTOR→Motor (y sus RH/LH).
- CM: ADI=Antes de Dializar, DDI=Después de Dializar, C=Cambio de aceite, M=Monitoreo.
- Español, técnico y BREVE.

REGLAS
- Usa SOLO lo que está en `filas`. ⛔ No inventes cifras, equipos, modelos ni proyectos: si un
  modelo o equipo no aparece en `filas`, no existe para esta respuesta.
- Si `filas` viene vacío (`[]` o sin objetos) → responde SOLO:
  "No se encontraron datos para esa consulta. Verifica el equipo/proyecto/componente."

filas:
{filas}
```

**Efecto:** cualquier consulta ad-hoc que caiga al fallback (p. ej. «cómo evolucionó el Fe en los MT de la
flota», «qué hidráulicos necesitan atención») sale en **viñetas con semáforo**, con el prefijo 🔎, y nunca
con una tabla que se confunda con la de un módulo.
