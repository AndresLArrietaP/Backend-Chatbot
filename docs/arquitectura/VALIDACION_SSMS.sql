/* ============================================================================
   KomfIA — ÍNDICE DE VALIDACIÓN EN SSMS
   166 bloques · índice regenerado el 25/09/2026; bloques 136-143 añadidos el 28/09.
   Ctrl+F sobre 'BLOQUE N' para saltar. Están en orden numérico.
   Los RESULTADOS de cada corrida quedan comentados justo debajo de su bloque.
   ----------------------------------------------------------------------------

   ── Fundación, vistas MD y módulos (hasta el 18/09)
     BLOQUE 0    ¿Existen las 13 vistas? (deben aparecer las 13)
     BLOQUE 1    COBERTURA DE LÍMITES
     BLOQUE 2    Componentes que el CASE NO reconoce (caen en 'OTRO')
     BLOQUE 3    Qué hay realmente cargado en lc (lo que el área SÍ subió)
     BLOQUE 4    BARRIDO PASO 1 (RESUMEN) — idéntico al que genera KomfIA
     BLOQUE 5    BARRIDO PASO 2 (DETALLE consolidado) — idéntico al de KomfIA
     BLOQUE 6    DETALLE DE UN EQUIPO (fuente de la matriz por-equipo)
     BLOQUE 7    Conteo de flota (paso previo típico)
     BLOQUE 8    DETERMINISMO (desempate por LaboratoryDataId en fechas empatadas)
     BLOQUE 9    LATENCIA del PASO 2 (mira "elapsed time" en la pestaña Messages)
     BLOQUE 10   ESCALABILIDAD: probar OTRO proyecto/modelo
     BLOQUE 11   Hor. Comp. (HsCc): ver si el componente trae horas reales o NULL
     BLOQUE 12   VERIFICACIÓN DEL GUARD 'OTRO' (tras re-correr DDL_vistas.sql)
     BLOQUE 13   DIAGNÓSTICO POR EQUIPO (nueva vista vw_UltimoAnalisisFlota)
     BLOQUE 14   TENDENCIA POR ELEMENTO (nueva vista vw_TendenciaElemento)
     BLOQUE 15   HISTORIAL muestra por muestra (nueva vista vw_HistorialMuestra)
     BLOQUE 16   MARCADORES DE CHIP (:C / :P) en vistas pre-formateadas
     BLOQUE 17   DIAGNÓSTICO POR EQUIPO (nueva vista vw_DiagnosticoEquipo)
     BLOQUE 18   Hor. Comp. en tendencia/historial + TENDENCIA DE UN ELEMENTO
     BLOQUE 19   HISTORIAL: 5 variantes (todas sobre vw_HistorialMuestra + Mets_Obs)
     BLOQUE 20   HISTORIAL OBSERVADOS DE FLOTA (vista vw_HistorialFlotaObs, agregado)
     BLOQUE 21   HorasComponente en vw_UltimoAnalisisAceite y vw_EstadoActualMT
     BLOQUE 22   VALIDAR LA FUNDACIÓN tras los cambios de perf (re-correr DDL primero)
     BLOQUE 23   DEDUP POR FECHA en rn_recencia (re-correr DDL primero)
     BLOQUE 24   CA3174 SIN LÍMITES (LP/LC) NI Hor.Comp. (marcha 2026-06-27)
     BLOQUE 25   SPARK (sparkline pre-computado en vw_TendenciaElemento) (2026-06-29)
     BLOQUE 26   SCOPE diagnóstico + filtro de proyecto del triage (marcha 2026-06-30)
     BLOQUE 27   DIAGNÓSTICO: NumCompObs/NumCompTotal YA son columnas de la vista
     BLOQUE 28   ACUMULADO de vida por metal en vw_TendenciaElemento (pedido gerencia 2026-07-10)
     BLOQUE 29   GRÁFICO de tendencia MÁS GRANDE + baseline visible (pedido gerencia 2026-07-10)
     BLOQUE 30   DETALLE del barrido con AMBOS límites (LP y LC) (pedido gerencia 2026-07-13)
     BLOQUE 31   CUADRO DE LÍMITES en el barrido desde PASO 1 (pedido 2026-07-15)
     BLOQUE 32   vw_ObservadosBarridoMD (TIER 2 copia verbatim del "detalle de todos")
     BLOQUE 33   (sin encabezado propio — buscar 'BLOQUE 33' en el cuerpo)
     BLOQUE 34   vw_ObservadosResumenMD (PASO 1 del barrido, columna MD)
     BLOQUE 35   barrido filtrado (MD_Criticos / MD_Precaucion)
     BLOQUE 36   vw_DiagnosticoMD (diagnóstico 1 equipo)
     BLOQUE 37   vw_Recomendaciones + bloque determinístico en DiagnosticoMD
     BLOQUE 38   vw_UltimoAnalisisMD (filtro por compAbbr, como el flujo)
     BLOQUE 39   vw_CondicionMT_MD (firma equipo, flujo MD_equipo)
     BLOQUE 40   vw_TendenciaP1MD (firma equipo+compAbbr, flujo MD_equipo_comp)
     BLOQUE 41   vw_TendenciaMD (detalle; firma equipo+compAbbr, flujo MD_equipo_comp)
     BLOQUE 42   vw_TendenciaGraficoMD (tabla del metal + gráfico ASCII combinados)
     BLOQUE 43   vw_TendenciaGraficoObsMD (default: gráficas de observados; firma equipo+compAbbr)
     BLOQUE 44   vw_TendenciaMetalMD (firma equipo+parametro, flujo MD_metal comp vacío)
     BLOQUE 45   vw_HistorialMD (firma equipo+compAbbr, flujo MD_equipo_comp)
     BLOQUE 46   vw_HistorialMetalMD (firma equipo+compAbbr+parametro, flujo MD_metal)
     BLOQUE 47   vw_HistorialEquipoMD (equipo) + vw_HistorialFlotaMD (proyecto)
     BLOQUE 48   vw_HistorialMetalEquipoMD (firma equipo+parametro, flujo MD_metal comp=todos)
     BLOQUE 49   vw_TriageMD EVOLUCIONADO (base ligera; flujo MD_triage: proyecto+modelo+compartimiento)
     BLOQUE 50   CORROBORAR límites gerencia (Limites.xlsx, 07/08/26) vs [Eqpcare].[lc]
     BLOQUE 51   VALIDAR fix Pb/Sn LC (crítico) tras re-correr la cadena
     BLOQUE 52   VALIDAR Pb/Sn LC en BARRIDO (vw_ObservadosFlota)
     BLOQUE 53   VALIDAR salud (V100/viscosidad) en la fundación
     BLOQUE 54   #6b salud V100 (viscosidad) informativa en barrido detalle
     BLOQUE 55   #14 vw_TendenciaIncipienteMD (firma proyecto, flujo MD_flota modelo=todos)
     BLOQUE 56   Barrido: (todos) sin modelo Y por-modelo especifico (duplicacion)
     BLOQUE 57   Triage recos: solo metales de la tabla (sin Calcio/Zinc informativos)
     BLOQUE 58   Historial INCLUYE DDI (unico topico con DDI; vw_MuestrasHistorial + rn_hist)
     BLOQUE 59   vw_ConteoFlotaMD (Conteo; flujo MD_flota; proyecto + modelo)
     BLOQUE 60   vw_RankingMD (formato largo; el flujo MD_ranking arma la tabla con pos<=top)
     BLOQUE 61   Tendencia con Grado (lubricante) + horas comp
     BLOQUE 62   vw_TendenciaMetalFlotaMD (Gap1; flujo MD_metal_flota; proyecto+CompTipo+Metal)
     BLOQUE 63   vw_CondicionCompMD (Gap2; flujo MD_metal_flota sin parametro; proyecto+CompTipo)

   ── P4, P5 y ranking gráfico
     BLOQUE 64   vw_UltimoMetalFlotaMD (Ultimo analisis en barrido por metal; 1..N metales)
     BLOQUE 65   vw_AcumuladosFlotaMD (wrapper del Ranking de Atencion / acumulados motor diesel)
     BLOQUE 66   vw_AcumuladosEquipoMD (acumulados de 1 equipo; flujo MD_acumequipo)
     BLOQUE 67   VERIFICACION acumulados: KomfIA vs vista cruda vs dashboard
     BLOQUE 68   Formato de tablas en Teams + ausencia del rotulo "inf"
     BLOQUE 69   Rendimiento del barrido de flota (regresion)
     BLOQUE 70   Determinismo de Met_Obs
     BLOQUE 71   P4 (historial + RANGO): vista de filas y prototipo del flujo
     BLOQUE 72   P4 paso 4: query del flujo MD_historial (validar ANTES de armar el flujo)
     BLOQUE 73   INVENTARIO REAL de componentes (para normalizar el comando, P4 paso 7.b)
     BLOQUE 74   P4 paso 8.1: query GENERICO del flujo (encabezado desde la vista)
     BLOQUE 75   P4 paso 8.2: equivalencia de las 4 vistas *FilasMD restantes
     BLOQUE 76   Localizar la PRIMERA diferencia (Temas 12 y 15 del BLOQUE 75)
     BLOQUE 77   DESCARTADO (21/09) - la regla del rombo NO existe
     BLOQUE 78   P5 paso 3.b: no-determinismo de Pos en los acumulados (4o caso de la familia)
     BLOQUE 79   P5: verificar que los 11 equipos INTERVENIDOS existen tal cual en la data
     BLOQUE 80   P5: determinismo de vw_AcumuladosFlotaMD (correr DESPUES del fix del desempate)
     BLOQUE 81   P5: probar vw_RankingGrafMD (alineacion, marcas, rombos, tamano)
     BLOQUE 82   P5 ajuste post-Teams (22/09): rotulos de columna + estado abreviado
     BLOQUE 83   P3 paso 1: hasta donde se puede abrir /incipiente (proyectos y componentes)
     BLOQUE 84   P3 paso 1.b: calibrar la regla POR METAL (el 0.5*LP se rompe con metales de LP chico)

   ── P3 incipiente y arranque de la ronda 23/09
     BLOQUE 85   P3: vw_TendenciaIncipienteMD generalizada (correr DESPUES de re-desplegarla)
     BLOQUE 86   P3: fix de rendimiento de vw_TendenciaIncipienteMD (medir ANTES / DESPUES)
     BLOQUE 87   P2: validar que Sigma-vida es lo que decimos que es
     BLOQUE 88   P1 (NO correr todavia): los 3 arreglos de Sigma-vida, para cuando se toque tendencia
     BLOQUE 89   Chequeo de vistas ROTAS (metadatos, NO ejecuta las vistas)
     BLOQUE 90   RONDA 23/09 (bloque B): cazar el 6 785.39 de Sigma-vida
     BLOQUE 91   RONDA 23/09 (bloque C4): el JOIN de limites ignora el MODELO
     BLOQUE 92   RONDA 23/09 bloque A: verificar los renombres de texto
     BLOQUE 93   BUG del componente PEGADO (mtlh) - capa SQL
     BLOQUE 94   P2/bloque B: Sigma-vida contra el historico COMPLETO (sin la ventana de 12 meses)
     BLOQUE 95   P2/bloque B: que corte produce EXACTAMENTE 6 785.39
     BLOQUE 96   P2/bloque B: ULTIMO intento sistematico antes de preguntar
     BLOQUE 97   P2/bloque B: buscar 6 785.39 en TODOS los metales, no solo Fe
     BLOQUE 98   Control: ¿la coincidencia del BLOQUE 97 es real o es ruido?
     BLOQUE 99   bloque B (parte que NO depende de la respuesta): Sigma-vida solo en desgaste
     BLOQUE 100  Bloque C paso 2: que parametros tiene REALMENTE cada tipo de componente

   ── Ronda 23/09 · bloques C y D
     BLOQUE 101  Verificar el caso del Fosforo antes de llamarlo falso positivo
     BLOQUE 102  C4 REPLANTEADO: [Eqpcare].[lc] YA ES el Excel; el problema es el EMPAREJAMIENTO
     BLOQUE 103  C4: arreglar el desajuste de texto del modelo (lo unico que depende de nosotros)
     BLOQUE 104  C1/C2: desplegar vw_FormatoParametro y comprobar que dice lo que debe
     BLOQUE 105  C1/C2: enganchar vw_TendenciaElemento al formato (1er consumidor de 4)
     BLOQUE 106  Re-verificar vw_TendenciaMD tras el fix de encabezados
     BLOQUE 107  C: el formato COMPLETO del Excel (incluye lo que la BD no mide)
     BLOQUE 108  C: vw_UltimoAnalisisMD pasa al formato (era la unica SIN mapa)
     BLOQUE 109  Que CompTipo se quedaron SIN formato (regresion del BLOQUE 108)
     BLOQUE 110  Que son realmente las 66 filas sin tabla
     BLOQUE 111  Muestras sin componente: que lo DIGAN en vez de fallar en silencio
     BLOQUE 112  D2: vw_CondicionMT_MD pasa al formato (hoja MT)
     BLOQUE 113  D1: /diagcompleto con el formato CRUZADO (union de las 4 hojas)
     BLOQUE 114  D1: la causa del fallo de /diagnostico, ANTES de borrarlo
     BLOQUE 115  El equipo SANO deja de fallar en silencio (causa real del fallo de /diagnostico)
     BLOQUE 116  DIAGNOSTICO de rendimiento de vw_DiagnosticoMD
     BLOQUE 117  Optimizacion de vw_DiagnosticoMD: 4 lecturas de la fundacion -> 1

   ── Ronda 23/09 · bloque E (análisis, contadores y dirección del límite)
     BLOQUE 118  E0: el contador del encabezado contradice las celdas marcadas
     BLOQUE 119  E2: el correo de contacto faltaba en /ultimo
     BLOQUE 120  E0 aplicado: el contador ahora sale de las celdas que se pintan
     BLOQUE 121  E3: el MISMO valor sale marcado en /ultimo y SIN marcar en /diagcompleto
     BLOQUE 122  E3 y E4 aplicados

   ── Ronda 23/09 · bloque F (familia tendencia)
     BLOQUE 123  F1: cuanto pesaria la tendencia FUSIONADA (medir ANTES de construirla)
     BLOQUE 124  F4: Svida con el numero de muestras, y la clave completa
     BLOQUE 125  F3: las graficas llevan contexto
     BLOQUE 126  F1: el modulo de tendencia FUSIONADO
     BLOQUE 127  F1: quitar la lectura doble de vw_TendenciaP1MD
     BLOQUE 128  REGRESION: /tendenciametal se paso de 2 min (FlowActionTimedOut, 25/09)
     BLOQUE 129  la palanca que quedo a la vista: anclar el LIKE del equipo
     BLOQUE 130  F3 REDEFINIDO: el cuadro de /tendencia ARRIBA de la grafica

   ── Rendimiento, regresiones y cierre
     BLOQUE 131  /triage da FlowActionTimedOut tras el fix de CompTipo (25/09)
     BLOQUE 132  los otros dos predicados de los flujos: Proyecto y Modelo
     BLOQUE 133  vw_TriageMD reestructurada (25/09)
     BLOQUE 134  G2 modo A: los dos fallos silenciosos que quedaban
     BLOQUE 135  comprobar el CA3175 antes de llamarlo error (25/09)

   ── Ronda 28/09 (Carlos + Franco) — reconocimiento
     BLOQUE 136  ComponentStatus: que valores tiene y cual es el "En Uso"
     BLOQUE 137  REPRODUCIR el acumulado de Carlos: CA3195 MT LH Fe = 3718.6
     BLOQUE 138  los 22 limites que lc SI tiene y la fundacion NO lee
     BLOQUE 139  COBERTURA de limites por proyecto/componente/modelo
     BLOQUE 140  H3/H4: el scope del ranking y el parametro Hollin
     BLOQUE 141  las columnas *_Acum de la tabla: atajo para el bloque C?
     BLOQUE 142  D7.3: de los 13 valores "nuevos", cuales traen dato de verdad
     BLOQUE 143  D2 desplegada: vw_LimitesPorComponente con los 31 parametros
     BLOQUE 144  D3 desplegada: la fundacion con los 13 valores nuevos (+ MEDIR)
     BLOQUE 145  REGRESION 6 MIN en /diagcompleto tras D3 -- aislar capa por capa
     BLOQUE 146  CURA de la regresion: unpv de vw_DiagnosticoMD reestructurado
     BLOQUE 147  BLOQUE L: donde se pierde el filtro de <modelo>
     BLOQUE 148  PASO 1: vw_DiagnosticoMD consolidada -- MEDIR los scans
     BLOQUE 149  PASO 1: re-medicion tras el fix del raw
     BLOQUE 150  PASO 2 (L3): '(todos)' = los modelos con limites cargados
     BLOQUE 151  PASO 2b (L5): avisar cuando el modelo NO tiene limites
     BLOQUE 152  PASO 3 (L4): el ranking y el <modelo> -- H3 y el tope silencioso
     BLOQUE 153  PASO 4 (C): reconocimiento ANTES de escribir el Acum
     BLOQUE 154  PASO 4 (C): el Acum desplegado
     BLOQUE 155  PASO 5 (J): el triage pasa a 5 COLUMNAS por familia
     BLOQUE 156  DECISION: 'fuera de limite = observado' para TODO parametro
     BLOQUE 157  La bandera 'Inf' YA existe + dos bloques que huelen a limite
     BLOQUE 158  El cero bajo limite invertido, y el ISO6 de Antapaccay MT
     BLOQUE 159  G0 desplegado: el 0 no es una medicion (9 guardas)
     BLOQUE 160  G1: la inversion se deduce del GRUPO, no del dato
     BLOQUE 161  G2: compAbbr nunca puede salir NULL (el MD venia vacio)
     BLOQUE 162  PASO 5c (N): el contador del triage sale de las celdas
     BLOQUE 163  PASO 6 (B): /tendencia sin la tabla de limites
     BLOQUE 164  Rehacer las dos comprobaciones del 163 que no probaban nada
     BLOQUE 165  B2: el aviso se dispara por los limites QUE HACEN FALTA
   ============================================================================ */

/* ============================================================================
   KomfIA — VALIDACIÓN EN SSMS  (bd_kmmp_osconfiabilidad, Azure SQL)
   Corre cada BLOQUE por separado (selecciona y F5). Son SOLO lecturas.
   Objetivo: probar las 13 vistas, el barrido/diagnóstico/tendencia/historial, y — sobre todo — diagnosticar la
   COBERTURA de [Eqpcare].[lc], que es el único cuello para escalar a otros
   proyectos / modelos / componentes.
   Requisito previo: haber corrido DDL_vistas.sql (F5) y DDL_indices.sql.
   ============================================================================ */


/* ----------------------------------------------------------------------------
   BLOQUE 0 — ¿Existen las 13 vistas? (deben aparecer las 13)
   ---------------------------------------------------------------------------- */
SELECT s.name AS esquema, v.name AS vista, v.modify_date
FROM sys.views v JOIN sys.schemas s ON s.schema_id = v.schema_id
WHERE v.name IN (
    'vw_LimitesPorComponente','vw_MuestrasEstado','vw_MuestrasRankeadas',
    'vw_UltimoAnalisisAceite','vw_EstadoActualMT','vw_ObservadosFlota',
    'vw_ObservadosResumen','vw_ObservadosDetalle',
    'vw_UltimoAnalisisFlota','vw_TendenciaElemento','vw_HistorialMuestra','vw_DiagnosticoEquipo',
    'vw_HistorialFlotaObs')
ORDER BY v.name;
GO

/* ============================================================================
   BLOQUE 1  ★ EL MÁS IMPORTANTE ★  — COBERTURA DE LÍMITES
   Cruza las combinaciones (Proyecto × Modelo × CompTipo) que TIENEN muestras
   recientes contra las que TIENEN límites en lc.
   - 'SIN LIMITES EN lc'  => ese componente NUNCA disparará observado (falso
     negativo silencioso). Es lo que el área debe cargar.
   - 'OK' => tiene al menos un límite cargado.
   ============================================================================ */
WITH combos AS (
    SELECT DISTINCT Proyecto, Modelo, CompTipo
    FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK)
    WHERE EsDDI = 0 AND rn_recencia = 1
)
SELECT
    c.Proyecto, c.Modelo, c.CompTipo,
    CASE WHEN l.CompTipo IS NULL THEN '>>> SIN LIMITES EN lc <<<' ELSE 'OK' END AS Cobertura,
    l.Fe_LP, l.Fe_LC, l.Cu_LP, l.Cu_LC, l.PQ_LP, l.PQ_LC, l.TBN_LP
FROM combos c
LEFT JOIN [dbo].[vw_LimitesPorComponente] l
       ON l.ProyKey   = UPPER(LTRIM(RTRIM(c.Proyecto)))
      AND l.ModeloKey = UPPER(LTRIM(RTRIM(c.Modelo)))
      AND l.CompTipo  = c.CompTipo
ORDER BY Cobertura DESC, c.Proyecto, c.Modelo, c.CompTipo;
GO


/* ----------------------------------------------------------------------------
   BLOQUE 2 — Componentes que el CASE NO reconoce (caen en 'OTRO')
   Si aparece algo aquí, ese Compartimiento no matchea lc y necesita un WHEN
   nuevo en el CASE (en vw_LimitesPorComponente Y vw_MuestrasEstado, idénticos).
   ---------------------------------------------------------------------------- */
SELECT DISTINCT Compartimiento, CompTipo
FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK)
WHERE CompTipo = 'OTRO'
ORDER BY Compartimiento;
GO


/* ----------------------------------------------------------------------------
   BLOQUE 3 — Qué hay realmente cargado en lc (lo que el área SÍ subió)
   Útil para detectar el typo '730E-' y modelos/componentes faltantes.
   ---------------------------------------------------------------------------- */
SELECT ProyKey, ModeloKey, CompTipo,
       Fe_LP, Fe_LC, Cu_LP, Cu_LC, PQ_LP, PQ_LC, Cr_LP, Cr_LC,
       Si_LP, Si_LC, Pb_LP, Sn_LP, TBN_LP
FROM [dbo].[vw_LimitesPorComponente] WITH (NOLOCK)
ORDER BY ProyKey, ModeloKey, CompTipo;
GO

-- (3b) Valores crudos de lc, por si hay que ver COMPONENTE/Proyecto/MODELO tal cual:
SELECT DISTINCT [Proyecto], [MODELO], [COMPONENTE]
FROM [Eqpcare].[lc] WITH (NOLOCK)
ORDER BY [Proyecto], [MODELO], [COMPONENTE];
GO


/* ----------------------------------------------------------------------------
   BLOQUE 4 — BARRIDO PASO 1 (RESUMEN) — idéntico al que genera KomfIA
   ---------------------------------------------------------------------------- */
SELECT * FROM [dbo].[vw_ObservadosResumen] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%'
ORDER BY NumCrit DESC, NumPrec DESC;
GO


/* ----------------------------------------------------------------------------
   BLOQUE 5 — BARRIDO PASO 2 (DETALLE consolidado) — idéntico al de KomfIA
   Revisa la columna Detalle: 'Cu=24.2(LC4.0):C · Ca=...:C inf'
   ---------------------------------------------------------------------------- */
SELECT * FROM [dbo].[vw_ObservadosDetalle] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%'
ORDER BY NumCrit DESC, Equipo, Compartimiento;
GO


/* ----------------------------------------------------------------------------
   BLOQUE 6 — DETALLE DE UN EQUIPO (fuente de la matriz por-equipo)
   ---------------------------------------------------------------------------- */
SELECT * FROM [dbo].[vw_ObservadosDetalle] WITH (NOLOCK)
WHERE Equipo = 'CA3177'
ORDER BY NumCrit DESC, Compartimiento;
GO


/* ----------------------------------------------------------------------------
   BLOQUE 7 — Conteo de flota (paso previo típico)
   ---------------------------------------------------------------------------- */
SELECT COUNT(ME.[Id]) AS Total, MP.[Name] AS Proyecto, EF.[Model] AS Modelo
FROM [Mine].[MiningEquipment] ME WITH (NOLOCK)
JOIN [Mine].[EquipmentFleet] EF ON EF.[Id] = ME.[EquipmentFleetId]
JOIN [Mine].[MiningProject]  MP ON MP.[Id] = ME.[MiningProjectId]
WHERE MP.[Name] LIKE '%Antapaccay%'
GROUP BY MP.[Name], EF.[Model];
GO


/* ----------------------------------------------------------------------------
   BLOQUE 8 — DETERMINISMO (desempate por LaboratoryDataId en fechas empatadas)
   rn_recencia=1 debe ser estable entre corridas.
   ---------------------------------------------------------------------------- */
SELECT FechaMuestreo, LaboratoryDataId, Fe_ppm, Indice_PQ, rn_recencia
FROM [dbo].[vw_MuestrasRankeadas] WITH (NOLOCK)
WHERE Equipo = 'CA3177' AND Compartimiento LIKE '%TRACCION%LH'
ORDER BY rn_recencia;
GO


/* ----------------------------------------------------------------------------
   BLOQUE 9 — LATENCIA del PASO 2 (mira "elapsed time" en la pestaña Messages)
   Si se acerca a decenas de segundos en un proyecto, conviene acotar a modelo.
   ---------------------------------------------------------------------------- */
SET STATISTICS TIME ON;
SELECT * FROM [dbo].[vw_ObservadosDetalle] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%'
ORDER BY NumCrit DESC, Equipo, Compartimiento;
SET STATISTICS TIME OFF;
GO


/* ----------------------------------------------------------------------------
   BLOQUE 10 — ESCALABILIDAD: probar OTRO proyecto/modelo
   0 filas puede significar (a) ninguno observado, o (b) sin límites en lc.
   Para distinguir, cruza SIEMPRE con el BLOQUE 1.
   Cambia el filtro a tu gusto:
   ---------------------------------------------------------------------------- */
SELECT * FROM [dbo].[vw_ObservadosResumen] WITH (NOLOCK)
WHERE Proyecto LIKE '%Cerro Verde%'
ORDER BY NumCrit DESC, NumPrec DESC;
GO

-- (10b) Toda la flota observada por proyecto (panorama global, 1 fila por proyecto):
SELECT Proyecto, COUNT(*) AS EquiposObservados,
       SUM(NumCrit) AS TotalCriticos, SUM(NumPrec) AS TotalPrecauciones
FROM [dbo].[vw_ObservadosResumen] WITH (NOLOCK)
GROUP BY Proyecto
ORDER BY EquiposObservados DESC;
GO


/* ----------------------------------------------------------------------------
   BLOQUE 11 — Hor. Comp. (HsCc): ver si el componente trae horas reales o NULL
   NULL en HorasComponente => ese tipo de componente no está mapeado en el CASE
   de HsCc (no rompe; usa Hor. Aceite como respaldo).
   ---------------------------------------------------------------------------- */
SELECT Equipo, Compartimiento, HorasComponente, HorasDeAceite, Estado_General
FROM [dbo].[vw_ObservadosDetalle] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%'
ORDER BY CASE WHEN HorasComponente IS NULL THEN 0 ELSE 1 END, Equipo;
GO


/* ----------------------------------------------------------------------------
   BLOQUE 12 — VERIFICACIÓN DEL GUARD 'OTRO'  (tras re-correr DDL_vistas.sql)
   El guard hace que un componente NO reconocido (CompTipo='OTRO') no reciba
   límites → nunca dispara observado.
   ---------------------------------------------------------------------------- */

-- (12a) PRUEBA PRINCIPAL: por CompTipo, cuántas muestras hay, cuántas SIN límites
--       y cuántas observadas. Para 'OTRO' => sin_limites = muestras  Y  observados = 0.
SELECT
    CompTipo,
    COUNT(*) AS muestras,
    SUM(CASE WHEN Fe_LP IS NULL AND Cu_LP IS NULL AND PQ_LP IS NULL THEN 1 ELSE 0 END) AS sin_limites,
    SUM(CASE WHEN Estado_General <> 'OK' THEN 1 ELSE 0 END) AS observados
FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK)
WHERE EsDDI = 0 AND rn_recencia = 1
GROUP BY CompTipo
ORDER BY CompTipo;
GO

-- (12b) PRUEBA NEGATIVA: ningún componente 'OTRO' debe tener límite asignado ni
--       estar observado. DEBE devolver 0 FILAS si el guard funciona.
SELECT TOP 50 Equipo, Proyecto, Modelo, Compartimiento, CompTipo,
       Fe_LP, Cu_LP, PQ_LP, Estado_General
FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK)
WHERE CompTipo = 'OTRO' AND EsDDI = 0 AND rn_recencia = 1
  AND (Fe_LP IS NOT NULL OR Cu_LP IS NOT NULL OR PQ_LP IS NOT NULL
       OR Estado_General <> 'OK');
GO

-- (12c) Los componentes raros (Damper, Diferencial, Caja Giro, PTO…) NO deben
--       aparecer en el barrido. DEBE devolver 0 FILAS.
SELECT DISTINCT Compartimiento
FROM [dbo].[vw_ObservadosDetalle] WITH (NOLOCK)
WHERE Compartimiento NOT LIKE '%TRACCION%'
  AND Compartimiento NOT LIKE '%HIDRAUL%'
  AND Compartimiento NOT LIKE '%RUEDA%'
  AND Compartimiento NOT LIKE '%MANDO%'
  AND Compartimiento NOT LIKE '%TRANSMISION%'
  AND Compartimiento NOT LIKE '%MOTOR%';
GO


/* ----------------------------------------------------------------------------
   BLOQUE 13 — DIAGNÓSTICO POR EQUIPO (nueva vista vw_UltimoAnalisisFlota)
   Todos los componentes de UN equipo, su última muestra (no-DDI), con Hor. Comp.
   real. Es la fuente de la tabla ancha del diagnóstico.
   ---------------------------------------------------------------------------- */

-- (13a) Fuente del diagnóstico (lo que consumirá KomfIA para la tabla ancha).
--       Debe traer las ~6 filas de componentes del equipo, con HorasComponente.
SELECT Equipo, Proyecto, Modelo, Compartimiento, FechaMuestreo,
       Horometro, HorasDeAceite, HorasComponente, CM, Estado_General,
       Fe_ppm, Fe_LP, Fe_LC, Indice_PQ, PQ_LP, PQ_LC, Cr_ppm, Cr_LP, Cr_LC,
       Ni_ppm, Ni_LP, Ni_LC, Cu_ppm, Cu_LP, Cu_LC, Pb_ppm, Pb_LP, Sn_ppm, Sn_LP,
       Al_ppm, Al_LP, Al_LC, Si_ppm, Si_LP, Si_LC, Ca_ppm, Ca_LP, Ca_LC,
       Zn_ppm, Zn_LP, Zn_LC, K_ppm, K_LP, K_LC, B_ppm, P_ppm, Mg_ppm, Mg_LP, Mg_LC,
       V100, TBN, TBN_LP
FROM [dbo].[vw_UltimoAnalisisFlota] WITH (NOLOCK)
WHERE Equipo = 'CA3171'
ORDER BY Compartimiento;
GO

-- (13b) Comprobación de NO-regresión: el diagnóstico (todos los componentes) debe
--       tener >= filas que el barrido del mismo equipo (solo observados).
SELECT 'diagnostico_todos' AS fuente, COUNT(*) AS filas
FROM [dbo].[vw_UltimoAnalisisFlota] WITH (NOLOCK) WHERE Equipo = 'CA3177'
UNION ALL
SELECT 'barrido_observados', COUNT(*)
FROM [dbo].[vw_ObservadosDetalle] WITH (NOLOCK) WHERE Equipo = 'CA3177';
GO

-- (13c) Hor. Comp. por componente del equipo (NULL = ese componente no mapeó en HsCc;
--       el formato usará Hor. Ace. como respaldo y lo encabezará como tal).
SELECT Compartimiento, FechaMuestreo, HorasComponente, HorasDeAceite, Cond_Area, Estado_General
FROM [dbo].[vw_UltimoAnalisisFlota] WITH (NOLOCK)
WHERE Equipo = 'CA3171'
ORDER BY Compartimiento;
GO


/* ----------------------------------------------------------------------------
   BLOQUE 14 — TENDENCIA POR ELEMENTO (nueva vista vw_TendenciaElemento)
   1 fila por parámetro, con d1..d6 (6 valores cronológicos + chip embebido) y
   f1..f6 (fechas). PASO 2 de tendencia: el central solo PINTA d1..d6.
   ---------------------------------------------------------------------------- */

-- (14a) PASO 2 por defecto: SOLO parámetros relevantes (~4-8 filas chiquititas).
SELECT Parametro, Grupo, LP, LC, d1,d2,d3,d4,d5,d6,
       f1,f2,f3,f4,f5,f6, Prom, Sigma, Tendencia, NVecesObs, Inf
FROM [dbo].[vw_TendenciaElemento] WITH (NOLOCK)
WHERE Equipo='CA3198' AND Compartimiento LIKE '%TRACCION%' AND Compartimiento LIKE '%RH'
  AND EsRelevante = 1
ORDER BY Orden;
GO

-- (14b) Matriz COMPLETA (los 17 parámetros): la MISMA query SIN "AND EsRelevante = 1".
SELECT Parametro, Grupo, LP, LC, d1, d6, Prom, Sigma, NVecesObs, EsRelevante, Tendencia
FROM [dbo].[vw_TendenciaElemento] WITH (NOLOCK)
WHERE Equipo='CA3198' AND Compartimiento LIKE '%TRACCION%RH'
ORDER BY Orden;
GO

-- (14c) Sanidad: d1=más antigua, d6=la última; f1..f6 en orden cronológico ascendente.
SELECT Parametro, f1, f6, d1, d6, Tendencia
FROM [dbo].[vw_TendenciaElemento] WITH (NOLOCK)
WHERE Equipo='CA3198' AND Compartimiento LIKE '%TRACCION%RH' AND Parametro IN ('Fe','PQ')
ORDER BY Orden;
GO


/* ----------------------------------------------------------------------------
   BLOQUE 15 — HISTORIAL muestra por muestra (nueva vista vw_HistorialMuestra)
   1 fila por muestra (INCLUYE DDI), últimos 2 meses (horneados en la vista), params pre-formateados con
   chip. El central pinta la tabla con FechaMuestreo DESC (cantidad de datos, sin
   estadística). LIGERA: ventana 2 meses + columnas chip (no LP/LC).
   ---------------------------------------------------------------------------- */

-- (15a) Historial de un componente (lo que consumirá KomfIA, descendente).
--       La VISTA ya hornea la ventana de 2 meses → SELECT * sin filtro de fecha = liviano.
SELECT * FROM [dbo].[vw_HistorialMuestra] WITH (NOLOCK)
WHERE Equipo='CA3198' AND Compartimiento LIKE '%TRACCION%LH'
ORDER BY FechaMuestreo DESC;
GO

-- (15b) Cuántas muestras devuelve por componente (debe ser acotado, ~2 meses):
SELECT Compartimiento, COUNT(*) AS muestras_2m,
       SUM(CASE WHEN EsDDI=1 THEN 1 ELSE 0 END) AS ddi,
       MIN(FechaMuestreo) AS desde, MAX(FechaMuestreo) AS hasta
FROM [dbo].[vw_HistorialMuestra] WITH (NOLOCK)
WHERE Equipo='CA3198'
GROUP BY Compartimiento
ORDER BY Compartimiento;
GO

-- (15c) Latencia (mira elapsed time): debe ser baja por la ventana de 2 meses.
SET STATISTICS TIME ON;
SELECT * FROM [dbo].[vw_HistorialMuestra] WITH (NOLOCK)
WHERE Equipo='CA3198' AND Compartimiento LIKE '%TRACCION%LH'
ORDER BY FechaMuestreo DESC;
SET STATISTICS TIME OFF;
GO

/* ----------------------------------------------------------------------------
   BLOQUE 16 — MARCADORES DE CHIP (:C / :P) en vistas pre-formateadas
   Tras re-correr DDL_vistas.sql: historial y tendencia ya NO usan emoji, usan
   marcador texto ':C' (>LC) / ':P' (>LP) — robusto a encoding. El central mapea
   :C->rojo, :P->amarillo, sufijo ' inf'=informativo. DEBEN verse ':C'/':P', NUNCA '🟥'/'🟨'.
   ---------------------------------------------------------------------------- */
-- (16a) Historial: las columnas de metales fuera de umbral deben traer ':C'/':P' (no emoji)
SELECT TOP 20 Fec=FechaMuestreo, CM, Fe, PQ, Cr, Cu, Si, Zn
FROM [dbo].[vw_HistorialMuestra] WITH (NOLOCK)
WHERE Equipo='CA3160' AND Compartimiento LIKE '%HIDRAUL%'
ORDER BY FechaMuestreo DESC;
GO

-- (16b) Tendencia: d1..d6 deben traer ':C'/':P' pegados al valor (ej '244.7:C')
SELECT Parametro, d1, d2, d3, d4, d5, d6
FROM [dbo].[vw_TendenciaElemento] WITH (NOLOCK)
WHERE Equipo='CA3198' AND Compartimiento LIKE '%TRACCION%RH' AND EsRelevante=1
ORDER BY Orden;
GO

/* ----------------------------------------------------------------------------
   BLOQUE 17 — DIAGNÓSTICO POR EQUIPO (nueva vista vw_DiagnosticoEquipo)
   Pre-formateada: 1 fila/componente con cada param ya chip-marcado (:C/:P).
   El central pivota componente x param y solo pinta -> no se corta.
   ---------------------------------------------------------------------------- */
SELECT Compartimiento, FechaMuestreo, HorasComponente, CM, Estado_General,
       Fe, PQ, Cr, Cu, Si, Ca, Zn, Na, V100, TBN
FROM [dbo].[vw_DiagnosticoEquipo] WITH (NOLOCK)
WHERE Equipo='CA3177' ORDER BY Compartimiento;
GO
-- (17b) Debe traer las ~6 filas de componentes; los críticos con ':C', informativos con ':C inf'.


/* ----------------------------------------------------------------------------
   BLOQUE 18 — Hor. Comp. en tendencia/historial + TENDENCIA DE UN ELEMENTO
   ---------------------------------------------------------------------------- */

-- (18a) HorasComponente ahora presente en tendencia (rankeadas) e historial:
SELECT Equipo, Compartimiento, FechaMuestreo, Horometro, HorasDeAceite, HorasComponente
FROM [dbo].[vw_MuestrasRankeadas] WITH (NOLOCK)
WHERE Equipo='CA3198' AND Compartimiento LIKE '%TRACCION%LH' AND rn_recencia<=8
ORDER BY FechaMuestreo DESC;
GO

-- (18b) TENDENCIA DE UN ELEMENTO (ej. Sodio) en TODOS los componentes de un equipo
--       1 fila por componente, d1..d6 = 6 valores cronológicos (chip), f1..f6 = fechas.
SELECT Compartimiento, Parametro, LP, LC, d1,d2,d3,d4,d5,d6, f1,f6, Tendencia, Inf
FROM [dbo].[vw_TendenciaElemento] WITH (NOLOCK)
WHERE Equipo='CA3174' AND Parametro='Na'
ORDER BY Compartimiento;
GO


/* ----------------------------------------------------------------------------
   BLOQUE 19 — HISTORIAL: 5 variantes (todas sobre vw_HistorialMuestra + Mets_Obs)
   Cronologico (FechaMuestreo DESC), ventana 2 meses horneada en la vista.
   ---------------------------------------------------------------------------- */

-- (19.1) GENERAL del equipo: todas las muestras del equipo (cualquier comp.), Met.Obs + Comp.
SELECT Compartimiento, FechaMuestreo, Horometro, HorasDeAceite, CM, Estado_General, Mets_Obs
FROM [dbo].[vw_HistorialMuestra] WITH (NOLOCK)
WHERE Equipo='CA3171'
ORDER BY FechaMuestreo DESC, Compartimiento;
GO

-- (19.2) UN METAL en el equipo: el valor del metal por muestra (todos los comp.)
SELECT Compartimiento, FechaMuestreo, Horometro, HorasDeAceite, CM, Estado_General, Fe
FROM [dbo].[vw_HistorialMuestra] WITH (NOLOCK)
WHERE Equipo='CA3171'
ORDER BY FechaMuestreo DESC, Compartimiento;
GO

-- (19.3) UN METAL en UN COMPONENTE: valor del metal + Hor. Comp. por muestra
SELECT FechaMuestreo, Horometro, HorasDeAceite, HorasComponente, CM, Estado_General, Fe
FROM [dbo].[vw_HistorialMuestra] WITH (NOLOCK)
WHERE Equipo='CA3171' AND Compartimiento LIKE '%TRACCION%LH'
ORDER BY FechaMuestreo DESC;
GO

-- (19.4) UN COMPONENTE: Met.Obs + Hor. Comp. por muestra de ese componente
SELECT FechaMuestreo, Horometro, HorasDeAceite, HorasComponente, CM, Estado_General, Mets_Obs
FROM [dbo].[vw_HistorialMuestra] WITH (NOLOCK)
WHERE Equipo='CA3171' AND Compartimiento LIKE '%TRACCION%LH'
ORDER BY FechaMuestreo DESC;
GO

-- (19.5) OBSERVADOS EN FLOTA: muestras observadas del proyecto/modelo (el central agrupa por fecha)
SELECT FechaMuestreo, Equipo, Compartimiento, CM, Mets_Obs
FROM [dbo].[vw_HistorialMuestra] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%' AND Mets_Obs IS NOT NULL
ORDER BY FechaMuestreo DESC, Equipo, Compartimiento;
GO


/* ----------------------------------------------------------------------------
   BLOQUE 20 — HISTORIAL OBSERVADOS DE FLOTA (vista vw_HistorialFlotaObs, agregado)
   1 fila por fecha (30 días), liviano y rápido (sin subconsulta de Hor.Comp).
   Mira "elapsed time": debe ser MUCHO menor que el vw_HistorialMuestra fleet-wide.
   ---------------------------------------------------------------------------- */
SET STATISTICS TIME ON;
SELECT * FROM [dbo].[vw_HistorialFlotaObs] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%'
ORDER BY FechaMuestreo DESC;
SET STATISTICS TIME OFF;
GO


/* ----------------------------------------------------------------------------
   BLOQUE 21 — HorasComponente en vw_UltimoAnalisisAceite y vw_EstadoActualMT
   Fix BadGateway "Invalid column name HorasComponente": ambas se rebasaron sobre
   vw_MuestrasRankeadas (que la calcula). Estas dos consultas deben ejecutar SIN error
   y traer la columna HorasComponente con valor (o NULL si HsCc no cubre el componente).
   ---------------------------------------------------------------------------- */
SELECT Equipo, Compartimiento, FechaMuestreo, HorasDeAceite, HorasComponente, CM, Estado_General
FROM [dbo].[vw_UltimoAnalisisAceite] WITH (NOLOCK)
WHERE Equipo = 'CA3171' AND Compartimiento LIKE '%TRACCION%LH';
GO

SELECT TOP 10 Equipo, Compartimiento, FechaMuestreo, HorasDeAceite, HorasComponente, Fe_ppm, Estado_General
FROM [dbo].[vw_EstadoActualMT] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%'
ORDER BY Fe_ppm DESC;
GO

/* ============================================================================
   BLOQUE 22 — VALIDAR LA FUNDACIÓN tras los cambios de perf (re-correr DDL primero)
   1) ventana 12 meses en vw_MuestrasEstado  2) HorasComponente vía JOIN pre-rankeado.
   Corre las 4; cada una 2 veces (usa la 2ª, warm).
   ============================================================================ */

-- 22.1  COBERTURA: ¿la ventana de 12m dejó fuera algún equipo que SÍ debería verse?
--       Lista equipos cuya ÚLTIMA muestra es > 12 meses (ya NO aparecen en estado actual).
--       Si solo salen equipos viejos / dados de baja → la ventana es segura. Si sale uno
--       que esperabas activo → avísame y subimos la ventana.
SELECT ME.[Code] AS Equipo, MP.[Name] AS Proyecto, MAX(LD.[FechaMuestreo]) AS UltimaMuestra
FROM [Oil].[LaboratoryData] LD WITH (NOLOCK)
JOIN [Mine].[MiningEquipment] ME ON ME.[Id] = LD.[MiningEquipmentId]
JOIN [Mine].[MiningProject]  MP ON MP.[Id] = ME.[MiningProjectId]
GROUP BY ME.[Code], MP.[Name]
HAVING MAX(LD.[FechaMuestreo]) < DATEADD(MONTH, -12, GETDATE())
ORDER BY UltimaMuestra DESC;
GO

-- 22.2  PISO Y TAMAÑO: la más antigua debe ser ~hoy-12m y las filas MUCHO menos que 104165.
SELECT COUNT(*) AS Filas, MIN(FechaMuestreo) AS MasAntigua, MAX(FechaMuestreo) AS MasReciente,
       COUNT(DISTINCT MiningEquipmentId) AS Equipos
FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK);
GO

-- 22.3  HorasComponente (JOIN) sale con valor y SIN error en estado actual MT.
SELECT TOP 10 Equipo, Compartimiento, FechaMuestreo, HorasDeAceite, HorasComponente, Fe_ppm, Estado_General
FROM [dbo].[vw_EstadoActualMT] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%'
ORDER BY Fe_ppm DESC;
GO

-- 22.4  LATENCIA post-cambio (warm). Compara «elapsed time» con DIAGNOSTICO_LATENCIA:
--       L2.2 último de 1 equipo (antes ~5s) y L5 rn=1 fleet-wide (antes 6.4s, HsCc 2112 escaneos).
SET STATISTICS TIME ON;
SELECT * FROM [dbo].[vw_UltimoAnalisisAceite] WITH (NOLOCK)
WHERE Equipo='CA3171' AND Compartimiento LIKE '%TRACCION%LH';
SELECT Equipo, Compartimiento, HorasComponente
FROM [dbo].[vw_MuestrasRankeadas] WITH (NOLOCK) WHERE rn_recencia = 1;
SET STATISTICS TIME OFF;
GO

/* ============================================================================
   BLOQUE 23 — DEDUP POR FECHA en rn_recencia (re-correr DDL primero)
   Antes: muestras del mismo día consumían ranking -> tendencia mostraba "3 de 6".
   Ahora rn_recencia cuenta FECHAS distintas (keeper = mayor LaboratoryDataId/día).
   ============================================================================ */
-- 23.1 rn=1 sigue dando 1 fila por equipo+compartimiento (la última fecha). NO debe duplicar.
SELECT Equipo, Compartimiento, COUNT(*) AS filas_rn1
FROM [dbo].[vw_MuestrasRankeadas] WITH (NOLOCK)
WHERE rn_recencia = 1
GROUP BY Equipo, Compartimiento
HAVING COUNT(*) > 1;   -- debe devolver 0 filas
GO
-- 23.2 Tendencia: las 6 deben ser FECHAS DISTINTAS (sin 19-Jun repetido).
SELECT rn_recencia, FechaMuestreo, Horometro, CM
FROM [dbo].[vw_MuestrasRankeadas] WITH (NOLOCK)
WHERE Equipo='CA3171' AND Compartimiento LIKE '%TRACCION%LH' AND rn_recencia <= 6
ORDER BY rn_recencia;   -- 6 filas, 6 fechas distintas, sin huecos
GO
-- 23.3 Historial SIGUE viendo TODAS las muestras (incluye mismo día) — no se perdió nada.
SELECT FechaMuestreo, CM, Fe FROM [dbo].[vw_HistorialMuestra] WITH (NOLOCK)
WHERE Equipo='CA3171' AND Compartimiento LIKE '%TRACCION%LH'
ORDER BY FechaMuestreo DESC;   -- puede haber 2+ del mismo día (correcto)
GO

/* ============================================================================
   BLOQUE 24 — CA3174 SIN LÍMITES (LP/LC) NI Hor.Comp. (marcha 2026-06-27)
   Síntoma: "tendencia del Fe del CA3174 MT RH" devolvió valores pero LP/LC y
   HorasComponente en blanco. LP/LC viene de [lc]; Hor.Comp. de [HsCc]. Que AMBOS
   fallen juntos apunta a una peculiaridad de CA3174 (Modelo/Proyecto/Compartimiento
   que no cruza). Correr de 24.1 a 24.5 para aislar la causa.
   ---------------------------------------------------------------------------- */
GO
-- 24.1 ¿Cómo se ve CA3174 en la FUNDACIÓN? (Proyecto/Modelo/Compartimiento/CompTipo reales)
--      Esperado: Proyecto='Antapaccay', Modelo='980E', CompTipo='TRACCION'.
SELECT DISTINCT Equipo, Proyecto, Modelo, Compartimiento, CompTipo
FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK)
WHERE Equipo='CA3174' AND Compartimiento LIKE '%TRACCION%'
ORDER BY Compartimiento;
GO
-- 24.2 ¿Existe la fila de límites para ese Proyecto×Modelo×CompTipo?
--      Si Fe_LP sale NULL/!=200 o no hay fila → la combinación de CA3174 NO está en lc.
SELECT ProyKey, ModeloKey, CompTipo, Fe_LP, Fe_LC
FROM [dbo].[vw_LimitesPorComponente] WITH (NOLOCK)
WHERE ProyKey LIKE '%ANTAPACCAY%' AND CompTipo='TRACCION';
GO
-- 24.3 ¿Resuelve LP/LC en el ESTADO ACTUAL (triage) de CA3174? (ahí antes sí salía)
SELECT Equipo, Compartimiento, FechaMuestreo, Fe_ppm, Fe_LP, Fe_LC, Estado_General, HorasComponente
FROM [dbo].[vw_EstadoActualMT] WITH (NOLOCK)
WHERE Equipo='CA3174';
GO
-- 24.4 La query EXACTA que falló: tendencia Fe del CA3174 MT RH.
--      Mira si LP/LC/HorasComponente vienen poblados o NULL.
SELECT Equipo, Compartimiento, Parametro, LP, LC, HorasComponente, CM, d1,d2,d3,d4,d5,d6
FROM [dbo].[vw_TendenciaElemento] WITH (NOLOCK)
WHERE Equipo='CA3174' AND Compartimiento LIKE '%TRACCION%' AND Compartimiento LIKE '%RH' AND Parametro='Fe';
GO
-- 24.5 ¿HsCc tiene a CA3174 (o 'T3174') con el SISTEMA mapeado? (origen de Hor.Comp.)
--      Si no aparece WHEEL MOTOR RH → HorasComponente NULL es esperado (gap HsCc).
SELECT [EQUIPO], [SISTEMA], [SMR ULTIMO SERVICIO], [HORAS DE TRABAJO ACUMULADO ], [FECHA]
FROM [Eqpcare].[HsCc] WITH (NOLOCK)
WHERE ([EQUIPO]='CA3174' OR [EQUIPO]='T3174')
ORDER BY [SISTEMA], [FECHA] DESC;
GO

/* ============================================================================
   BLOQUE 25 — SPARK (sparkline pre-computado en vw_TendenciaElemento) (2026-06-29)
   Solución al gráfico RE-PEDIDO que se regeneraba mal: la vista ahora trae una
   columna Spark (▁▂▃▄▅▆▇█, 1 char por muestra d1..d6 cronológica, normalizada al
   rango de la propia serie). El central solo la IMPRIME/COPIA (no regenera ASCII).
   Validar que: (a) el Motor del CA3165 Cu dibuja la subida 4.0->6.8 y la caída
   final; (b) las series planas salen '▄▄▄▄▄▄'; (c) <6 muestras → '·' en huecos.
   ---------------------------------------------------------------------------- */
GO
-- 25.1 Spark de Cu en CA3165 por componente (Motor debe verse ascendente con caída; planos = barras bajas/iguales)
SELECT Compartimiento, Parametro, d1, d2, d3, d4, d5, d6, Spark, Tendencia, EsRelevante
FROM [dbo].[vw_TendenciaElemento] WITH (NOLOCK)
WHERE Equipo='CA3165' AND Parametro='Cu'
ORDER BY Compartimiento;
GO
-- 25.2 No rompe consumidores existentes: d1..d6 + LP/LC + Spark juntos (detalle por elemento de un equipo)
SELECT Parametro, LP, LC, d1, d2, d3, d4, d5, d6, Spark, Prom, Sigma
FROM [dbo].[vw_TendenciaElemento] WITH (NOLOCK)
WHERE Equipo='CA3171' AND Compartimiento LIKE '%TRACCION%LH' AND EsRelevante=1
ORDER BY Orden;
GO
-- 25.3 Edge: equipo/parámetro con <6 muestras → Spark con '·' en los huecos (no debe dar error)
SELECT TOP 20 Equipo, Compartimiento, Parametro, d1, d2, d3, d4, d5, d6, Spark
FROM [dbo].[vw_TendenciaElemento] WITH (NOLOCK)
WHERE d3 IS NULL OR d1 IS NULL
ORDER BY Equipo, Compartimiento, Orden;
GO
-- 25.4 Conteo de columnas / que la vista compila y Spark no es NULL cuando hay >=1 muestra
SELECT COUNT(*) AS Filas, SUM(CASE WHEN Spark IS NULL THEN 1 ELSE 0 END) AS SparkNulos
FROM [dbo].[vw_TendenciaElemento] WITH (NOLOCK) WHERE Equipo='CA3165';
GO

-- 25.5 Grafico AISLADO en vw_TendenciaGrafico (1 componente): vertical, × a la altura, líneas LC/LP
SELECT Grafico
FROM [dbo].[vw_TendenciaGrafico] WITH (NOLOCK)
WHERE Equipo='CA3165' AND Parametro='Cu' AND Compartimiento='MOTOR';
GO
-- 25.6 Grafico Cr MT LH CA3171 (vw_TendenciaGrafico) + 25.7: vw_TendenciaElemento YA es ligera (SIN Grafico)
SELECT Grafico FROM [dbo].[vw_TendenciaGrafico] WITH (NOLOCK)
WHERE Equipo='CA3171' AND Compartimiento LIKE '%TRACCION%LH' AND Parametro='Cr';
GO
-- 25.7 Confirmar que vw_TendenciaElemento ya NO trae Grafico (columnas ligeras + Spark)
SELECT TOP 1 * FROM [dbo].[vw_TendenciaElemento] WITH (NOLOCK) WHERE Equipo='CA3165' AND Parametro='Cu';
GO

/* ============================================================================
   BLOQUE 26 — SCOPE diagnóstico + filtro de proyecto del triage (marcha 2026-06-30)
   Dos hallazgos de la marcha: (A) «Diagnóstico del CA3177» trajo los 6 componentes
   (SELECT * sin AND Estado_General<>'OK') → payload → SystemError. El DEFAULT debe ser
   SOLO observados. (C) «Triage MT de Antapaccay» filtró por Modelo '%980E%' (sin
   Proyecto) → coló HT321 de ANTAMINA (también 980E). Por proyecto = SIEMPRE Proyecto.
   Estos son fixes de INSTRUCCIÓN (las vistas están bien); abajo, queries de referencia.
   ---------------------------------------------------------------------------- */
GO
-- 26.1 Diagnóstico DEFAULT (solo observados) = filas ligeras; vs TODOS (6 comp) = pesado
SELECT 'observados' AS modo, COUNT(*) AS comps
FROM [dbo].[vw_DiagnosticoEquipo] WITH (NOLOCK) WHERE Equipo='CA3177' AND Estado_General<>'OK'
UNION ALL
SELECT 'todos', COUNT(*) FROM [dbo].[vw_DiagnosticoEquipo] WITH (NOLOCK) WHERE Equipo='CA3177';
GO
-- 26.2 Triage por MODELO (mal: cuela otros proyectos 980E) vs por PROYECTO (correcto)
SELECT DISTINCT Proyecto, COUNT(*) AS mt_obs
FROM [dbo].[vw_EstadoActualMT] WITH (NOLOCK)
WHERE Modelo LIKE '%980E%' AND Estado_General <> 'OK'
GROUP BY Proyecto;   -- ⚠ si aparece Antamina u otro, confirma la fuga de C
GO
SELECT COUNT(*) AS mt_obs_antapaccay
FROM [dbo].[vw_EstadoActualMT] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Estado_General <> 'OK';   -- el correcto
GO


/* ----------------------------------------------------------------------------
   BLOQUE 27 — DIAGNÓSTICO: NumCompObs/NumCompTotal YA son columnas de la vista
   (marcha 2026-07-08). Hallazgo: el agente generó un CTE con CROSS JOIN para
   "calcular" los conteos: SELECT d.*, c.NumCompTotal, c.NumCompObs FROM Diag d
   CROSS JOIN Counts c ... — pero Diag = SELECT * FROM vw_DiagnosticoEquipo, que
   YA expone NumCompTotal/NumCompObs (window PARTITION BY Equipo, pre-filtro).
   Resultado: NOMBRES DE COLUMNA DUPLICADOS en el result set → Power Automate no
   serializa el JSON → {"respuesta":""} vacío → el central dijo "todos OK" (falso).
   El reintento con la forma SIMPLE (abajo) funcionó. Fix de INSTRUCCIÓN
   (KomfIA_SQL P21): "NumCompObs/Total YA en la vista → NO recalcular vía CTE/JOIN".
   La vista NO cambia. Abajo: (27.1) confirma que las columnas ya vienen; (27.2)
   la query CORRECTA; (27.3) demuestra el duplicado que rompe el JSON.
   ---------------------------------------------------------------------------- */
GO
-- 27.1 Las columnas de conteo YA existen en la vista (1 fila/comp; conteo por equipo)
SELECT Compartimiento, Estado_General, NumCompObs, NumCompTotal
FROM [dbo].[vw_DiagnosticoEquipo] WITH (NOLOCK) WHERE Equipo='CA3177' ORDER BY Compartimiento;
GO
-- 27.2 QUERY CORRECTA (simple): observados + conteos, SIN CTE. Debe traer NumComp* poblados.
SELECT * FROM [dbo].[vw_DiagnosticoEquipo] WITH (NOLOCK)
WHERE Equipo='CA3177' AND Estado_General<>'OK' ORDER BY Compartimiento;
GO
-- 27.3 DEMOSTRACIÓN del bug: d.* ya trae NumCompTotal/NumCompObs; añadir c.NumComp* los
--      DUPLICA. En SSMS corre (columnas repetidas visibles); vía OData/JSON del flujo,
--      las claves duplicadas colapsan el objeto → respuesta vacía. NO usar esta forma.
WITH Diag AS (SELECT * FROM [dbo].[vw_DiagnosticoEquipo] WITH (NOLOCK) WHERE Equipo='CA3177'),
     Counts AS (SELECT COUNT(*) AS NumCompTotal,
                       SUM(CASE WHEN Estado_General<>'OK' THEN 1 ELSE 0 END) AS NumCompObs FROM Diag)
SELECT d.*, c.NumCompTotal, c.NumCompObs      -- ⚠ NumCompTotal/NumCompObs DUPLICADAS (ya en d.*)
FROM Diag d CROSS JOIN Counts c
WHERE d.Estado_General<>'OK' ORDER BY d.Compartimiento;
GO


/* ----------------------------------------------------------------------------
   BLOQUE 28 — ACUMULADO de vida por metal en vw_TendenciaElemento (pedido gerencia 2026-07-10)
   Nuevo: columnas Acumulado (Σ del ppm del metal en TODAS las muestras no-DDI del
   componente) y NmAcum (nº de muestras sumadas). vw_MuestrasRankeadas ya filtra
   EsDDI=0, así que el acumulado suma solo muestras de monitoreo (no las post-dializado).
   Es un PROXY de exposición/desgaste acumulado, NO masa real (ppm=concentración).
   ⚠ Solo tiene sentido para metales de desgaste; para V100/TBN la Σ no es interpretable.
   Re-correr DDL_vistas.sql (vw_TendenciaElemento) ANTES de este bloque.
   Validar: (28.1) Acumulado/NmAcum poblados y coherentes; (28.2) NmAcum >= 6 (hay más
   historia que las 6 mostradas); (28.3) el acumulado NO cambia d1..d6/Prom/Sigma (siguen
   sobre las 6 últimas); (28.4) que NmAcum = nº real de muestras no-DDI del componente.
   ---------------------------------------------------------------------------- */
GO
-- 28.1 Cr del MT LH del CA3171: tendencia (6) + acumulado de vida
SELECT Compartimiento, Parametro, d1,d2,d3,d4,d5,d6, Prom, Sigma, Acumulado, NmAcum
FROM [dbo].[vw_TendenciaElemento] WITH (NOLOCK)
WHERE Equipo='CA3171' AND Compartimiento LIKE '%TRACCION%' AND Compartimiento LIKE '%LH' AND Parametro='Cr';
GO
-- 28.2 Cu de todos los componentes del CA3171: cada fila trae su Σ de vida del Cu
SELECT Compartimiento, Parametro, Prom, Sigma, NVecesObs, Acumulado, NmAcum
FROM [dbo].[vw_TendenciaElemento] WITH (NOLOCK)
WHERE Equipo='CA3171' AND Parametro='Cu' ORDER BY Compartimiento;
GO
-- 28.4 Contraste: NmAcum debe igualar el nº de muestras no-DDI del componente en la base rankeada
SELECT COUNT(*) AS muestras_noDDI_reales
FROM [dbo].[vw_MuestrasRankeadas] WITH (NOLOCK)
WHERE Equipo='CA3171' AND Compartimiento LIKE '%TRACCION%' AND Compartimiento LIKE '%LH';   -- comparar vs NmAcum de 28.1
GO


/* ----------------------------------------------------------------------------
   BLOQUE 29 — GRÁFICO de tendencia MÁS GRANDE + baseline visible (pedido gerencia 2026-07-10)
   vw_TendenciaGrafico regenerada: 12 niveles de alto (antes 7) y 9 de ancho por columna
   (antes 7). Las líneas LP (------) y LC (······) se dibujan a lo ancho completo y con más
   resolución vertical → la baseline horizontal se ve clara y grande. Misma consulta (1 comp).
   Re-correr DDL_vistas.sql (vw_TendenciaElemento primero — es su base — y vw_TendenciaGrafico).
   Validar en SSMS con resultado a TEXTO (Ctrl+T) para ver el multi-línea alineado.
   ---------------------------------------------------------------------------- */
GO
-- 29.1 Gráfico del Cr del MT LH del CA3171 (debe verse alto 12, ancho 9, con LC/LP a lo ancho)
SELECT Grafico FROM [dbo].[vw_TendenciaGrafico] WITH (NOLOCK)
WHERE Equipo='CA3171' AND Compartimiento LIKE '%TRACCION%LH%' AND Parametro='Cr';
GO
-- 29.2 Gráfico del Cu del Motor del CA3165 (otro componente/metal)
SELECT Grafico FROM [dbo].[vw_TendenciaGrafico] WITH (NOLOCK)
WHERE Equipo='CA3165' AND Compartimiento='MOTOR' AND Parametro='Cu';
GO


/* ----------------------------------------------------------------------------
   BLOQUE 30 — DETALLE del barrido con AMBOS límites (LP y LC) (pedido gerencia 2026-07-13)
   vw_ObservadosFlota.Detalle pasa de mostrar el límite CRUZADO ('Cu=7.7(LC4):C') a mostrar
   AMBOS ('Cu=7.7(LP3/LC4):C'), para precaución y crítico. Pb/Sn/TBN no tienen LC → solo LP.
   Robusto a NULL (ISNULL) → nunca desaparece la entrada del metal. Solo cambia el STRING
   Detalle; NumCrit/NumPrec/Mets_Obs/Infs_Obs y las demás vistas NO cambian.
   Re-correr DDL_vistas.sql (vw_ObservadosFlota → vw_ObservadosDetalle son la misma base).
   ---------------------------------------------------------------------------- */
GO
-- 30.1 Detalle de Antapaccay 980E: cada metal debe verse 'Metal=valor(LPx/LCy):sev'
SELECT Equipo, Compartimiento, NumCrit, NumPrec, Detalle
FROM [dbo].[vw_ObservadosDetalle] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%'
ORDER BY NumCrit DESC, Equipo, Compartimiento;
GO
-- 30.2 Precauciones (NumCrit=0 AND NumPrec>0): confirmar que el límite (LP) sale en el Detalle
SELECT Equipo, Compartimiento, Detalle
FROM [dbo].[vw_ObservadosDetalle] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%' AND NumCrit=0 AND NumPrec>0
ORDER BY Equipo, Compartimiento;
GO


/* ----------------------------------------------------------------------------
   BLOQUE 31 — CUADRO DE LÍMITES en el barrido desde PASO 1 (pedido 2026-07-15)
   Para que la matriz de límites (componente×metal, LP/LC) aparezca YA en la primera
   consulta de barrido (resumen), vw_ObservadosResumen ahora expone la columna Limites
   ("Comp: metal LP/LC" de los componentes observados del equipo). Se apoya en LimObs,
   nueva columna ligera de vw_ObservadosFlota (límites de los metales observados, sin
   valores ni chips). El central UNE por (comp, metal) para armar la matriz.
   Re-correr DDL_vistas.sql (vw_ObservadosFlota ANTES de vw_ObservadosResumen).
   ---------------------------------------------------------------------------- */
GO
-- 31.1 Resumen de Antapaccay: cada equipo trae Comp_Obs, Met_Obs y ahora Limites
SELECT Equipo, NumCrit, NumPrec, Comp_Obs, Met_Obs, Limites
FROM [dbo].[vw_ObservadosResumen] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%'
ORDER BY NumCrit DESC, NumPrec DESC;
GO
-- 31.2 LimObs por equipo+componente en la flota (límites de los metales observados)
SELECT Equipo, Compartimiento, Mets_Obs, LimObs
FROM [dbo].[vw_ObservadosFlota] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%'
ORDER BY Equipo, Compartimiento;
GO

/* ============================================================================
   BLOQUE 32 — vw_ObservadosBarridoMD (TIER 2 copia verbatim del "detalle de todos")
   Objetivo: confirmar que la vista entrega el bloque markdown YA armado y las cifras.
   ⚠ Ver el texto completo: Query > Query Options > Results > Grid/Text >
      "Maximum Characters Retrieved" súbelo (p.ej. 65535). Con Ctrl+T (modo texto)
      se lee mejor el markdown multilínea.
   ---------------------------------------------------------------------------- */
-- 32.1  Cifras + largo del bloque (1 fila por Proyecto+Modelo)
SELECT Proyecto, Modelo, NumEquipos, NumEquiposCriticos, NumEquiposSoloPrecau,
       LEN(DetalleTodosMD) AS LargoMD
FROM [dbo].[vw_ObservadosBarridoMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%';

-- 32.2  El bloque markdown pre-armado (esto es lo que el central imprimiría VERBATIM)
SELECT DetalleTodosMD
FROM [dbo].[vw_ObservadosBarridoMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%';
GO

/* ============================================================================
   BLOQUE 34 — vw_ObservadosResumenMD (PASO 1 del barrido, columna MD)
   ⚠ Sube "Maximum Characters Retrieved" para ver el bloque completo.
   ---------------------------------------------------------------------------- */
SELECT Proyecto, Modelo, NumEquipos, NumCriticos, NumSoloPrecau, LEN(MD) AS LargoMD
FROM [dbo].[vw_ObservadosResumenMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%';

SELECT MD
FROM [dbo].[vw_ObservadosResumenMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%';
GO

/* ============================================================================
   BLOQUE 35 — barrido filtrado (MD_Criticos / MD_Precaucion)
   ---------------------------------------------------------------------------- */
SELECT MD_Criticos   FROM [dbo].[vw_ObservadosBarridoMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%';
SELECT MD_Precaucion FROM [dbo].[vw_ObservadosBarridoMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%';
GO

/* ===== BLOQUE 36 — vw_DiagnosticoMD (diagnóstico 1 equipo) ===== */
SELECT Equipo, NumCompObs, NumCompTotal, LEN(MD) AS LargoMD, LEN(MD_Completo) AS LargoCompleto
FROM [dbo].[vw_DiagnosticoMD] WITH (NOLOCK) WHERE Equipo='CA3177';
SELECT MD          FROM [dbo].[vw_DiagnosticoMD] WITH (NOLOCK) WHERE Equipo='CA3177';
SELECT MD_Completo FROM [dbo].[vw_DiagnosticoMD] WITH (NOLOCK) WHERE Equipo='CA3177';
GO

-- ==== BLOQUE 37 — vw_Recomendaciones + bloque determinístico en DiagnosticoMD ====
SELECT * FROM [dbo].[vw_Recomendaciones];
SELECT Observados, Recomendaciones FROM [dbo].[vw_DiagnosticoMD] WITH (NOLOCK) WHERE Equipo='CA3177';
GO

-- ==== BLOQUE 38 — vw_UltimoAnalisisMD (filtro por compAbbr, como el flujo) ====
SELECT Observados, Recomendaciones, MD FROM [dbo].[vw_UltimoAnalisisMD] WITH (NOLOCK)
WHERE Equipo LIKE '%CA3171%' AND compAbbr LIKE '%MT LH%';
GO

-- ==== BLOQUE 39 — vw_CondicionMT_MD (firma equipo, flujo MD_equipo) ====
SELECT Observados, Recomendaciones, MD FROM [dbo].[vw_CondicionMT_MD] WITH (NOLOCK)
WHERE Equipo LIKE '%CA3177%';
GO

-- ==== BLOQUE 40 — vw_TendenciaP1MD (firma equipo+compAbbr, flujo MD_equipo_comp) ====
SELECT MD FROM [dbo].[vw_TendenciaP1MD] WITH (NOLOCK)
WHERE Equipo LIKE '%CA3177%' AND compAbbr LIKE '%MT LH%';
GO

-- ==== BLOQUE 41 — vw_TendenciaMD (detalle; firma equipo+compAbbr, flujo MD_equipo_comp) ====
SELECT Observados, Recomendaciones, MD FROM [dbo].[vw_TendenciaMD] WITH (NOLOCK)
WHERE Equipo LIKE '%CA3171%' AND compAbbr LIKE '%MT LH%';   -- MD = matriz COMPLETA (default)
SELECT MD_Relevantes FROM [dbo].[vw_TendenciaMD] WITH (NOLOCK)
WHERE Equipo LIKE '%CA3171%' AND compAbbr LIKE '%MT LH%';   -- opt-in: solo fuera de umbral
GO

-- ==== BLOQUE 42 — vw_TendenciaGraficoMD (tabla del metal + gráfico ASCII combinados) ====
SELECT MD FROM [dbo].[vw_TendenciaGraficoMD] WITH (NOLOCK)
WHERE Equipo LIKE '%CA3171%' AND compAbbr LIKE '%MT LH%' AND Parametro='Cr';
GO

-- ==== BLOQUE 43 — vw_TendenciaGraficoObsMD (default: gráficas de observados; firma equipo+compAbbr) ====
SELECT MD FROM [dbo].[vw_TendenciaGraficoObsMD] WITH (NOLOCK)
WHERE Equipo LIKE '%CA3171%' AND compAbbr LIKE '%MT LH%';   -- debe traer Cr y Zn
SELECT MD FROM [dbo].[vw_TendenciaGraficoObsMD] WITH (NOLOCK)
WHERE Equipo LIKE '%CA3177%' AND compAbbr LIKE '%MT LH%';   -- sin observados -> mensaje
GO

-- ==== BLOQUE 44 — vw_TendenciaMetalMD (firma equipo+parametro, flujo MD_metal comp vacío) ====
SELECT MD FROM [dbo].[vw_TendenciaMetalMD] WITH (NOLOCK)
WHERE Equipo LIKE '%CA3171%' AND compAbbr LIKE '%%' AND Parametro='Cu';
GO

-- ==== BLOQUE 45 — vw_HistorialMD (firma equipo+compAbbr, flujo MD_equipo_comp) ====
SELECT MD FROM [dbo].[vw_HistorialMD] WITH (NOLOCK)
WHERE Equipo LIKE '%CA3171%' AND compAbbr LIKE '%MT LH%';
GO

-- ==== BLOQUE 46 — vw_HistorialMetalMD (firma equipo+compAbbr+parametro, flujo MD_metal) ====
SELECT MD FROM [dbo].[vw_HistorialMetalMD] WITH (NOLOCK)
WHERE Equipo LIKE '%CA3171%' AND compAbbr LIKE '%MT LH%' AND Parametro='Cr';
GO

-- ==== BLOQUE 47 — vw_HistorialEquipoMD (equipo) + vw_HistorialFlotaMD (proyecto) ====
SELECT MD FROM [dbo].[vw_HistorialEquipoMD] WITH (NOLOCK) WHERE Equipo LIKE '%CA3171%';
SELECT MD FROM [dbo].[vw_HistorialFlotaMD]  WITH (NOLOCK) WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%todos%';
GO

-- ==== BLOQUE 48 — vw_HistorialMetalEquipoMD (firma equipo+parametro, flujo MD_metal comp=todos) ====
SELECT MD FROM [dbo].[vw_HistorialMetalEquipoMD] WITH (NOLOCK)
WHERE Equipo LIKE '%CA3171%' AND compAbbr LIKE '%todos%' AND Parametro='Cu';
GO

/* ==== BLOQUE 49 — vw_TriageMD EVOLUCIONADO (base ligera; flujo MD_triage: proyecto+modelo+compartimiento) ====
   Evolucion 2026-08-19: cualquier CompTipo, TODOS los equipos (obs o no), metales con valor entre parentesis,
   agrupado por modelo (en '(todos)' cada modelo lleva sub-titulo ### <modelo>). Recos solo TRACCION.
   Base: vw_MuestrasRankeadas rn=1 (1 pasada) — mas ligera que la version anterior (leia vw_DiagnosticoEquipo). */
-- (a) MT de toda la flota, sin modelo -> sale por modelo con sub-titulos:
SELECT Recomendaciones, MD FROM [dbo].[vw_TriageMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antamina%' AND Modelo LIKE '%todos%'
  AND CompTipo COLLATE Latin1_General_CI_AI LIKE '%traccion%';
GO
-- (b) Ruedas de un modelo especifico -> tabla unica de ese modelo (como '¿que ruedas estan observadas?'):
SELECT MD FROM [dbo].[vw_TriageMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antamina%' AND Modelo LIKE '%980E%'
  AND CompTipo COLLATE Latin1_General_CI_AI LIKE '%rueda%';
GO
-- Verifica: salen TODOS (🟩 OK incluidos), criticos/precaucion arriba, metales tipo 'Fe(199.0) · Cr(29.0)'.
-- PERF: comparar elapsed vs la version anterior (deberia bajar; base = rankeadas rn=1, 1 pasada).

-- ==== BLOQUE 50 — CORROBORAR límites gerencia (Limites.xlsx, 07/08/26) vs [Eqpcare].[lc] ====
--      ⚠ Limites.xlsx se retiró el 27/09/26 (queda en el historial de git, commit aa2a534).
--      La fuente oficial de límites es hoy docs/gerencia/LIMITES CONDENATORIOS 1.xlsm → ver
--      LIMITES_FALLBACK.md + DDL_vw_LimitesFallback.sql. Este bloque se conserva como origen
--      del hallazgo «Pb y Sn sí tienen LC crítico».
-- Origen gerencia = matriz Proyecto x Componente x Modelo, ~60 parámetros (Fe,Al,Cu,Pb,Sn,Cr,Ni,Si,
-- Na,K,Zn,P,B,Ca,Mg,PQ,TBN,Visc,ISO...). HALLAZGO: Pb/Sn SÍ tienen LC (Antapaccay MT: Pb LC=5, Sn LC=5).
-- Objetivo: (a) ver qué columnas/valores tiene realmente Eqpcare.lc; (b) detectar faltantes vs gerencia.
GO
-- 50.1 Columnas reales de [Eqpcare].[lc] (¿existen [PLOMO - LC], [ESTAÑO - LC], [TIPO], [MODELO]?)
SELECT ORDINAL_POSITION, COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA='Eqpcare' AND TABLE_NAME='lc'
ORDER BY ORDINAL_POSITION;
GO
-- 50.2 Límites de Motor de Tracción por proyecto (contrastar 1:1 con Limites.xlsx filas MT)
--      Antapaccay MT: Fe 200/230, Pb 3/5, Sn 3/5, Cu 10/15, Cr 2/3, Ni 2/3, Si 75/80, PQ 130/150
SELECT [Proyecto], [COMPONENTE],
       [FIERRO - LP],[FIERRO - LC],[PLOMO - LP],[PLOMO - LC],[ESTAÑO - LP],[ESTAÑO - LC],
       [COBRE - LP],[COBRE - LC],[CROMO - LP],[CROMO - LC],[NIQUEL - LP],[NIQUEL - LC],
       [SILICIO - LP],[SILICIO - LC],[PQ - LP],[PQ - LC],[TBN - LP],[TBN - LC]
FROM [Eqpcare].[lc] WITH (NOLOCK)
WHERE [COMPONENTE] LIKE '%TRACCION%'
ORDER BY [Proyecto], [COMPONENTE];
GO
-- 50.3 ¿Eqpcare.lc trae [PLOMO - LC] / [ESTAÑO - LC] poblados? (si NULL/ausente → falta cargar del Excel)
--      Si estas columnas NO existen: la fundación vw_MuestrasEstado NO puede derivar Pb_LC/Sn_LC.
SELECT [Proyecto], [COMPONENTE], [PLOMO - LP], [PLOMO - LC], [ESTAÑO - LP], [ESTAÑO - LC]
FROM [Eqpcare].[lc] WITH (NOLOCK)
WHERE [COMPONENTE] LIKE '%TRACCION%' AND [Proyecto]='ANTAPACCAY';
GO
-- 50.4 Vista fundación: ¿expone Pb_LC / Sn_LC? (hoy NO — solo Pb_LP/Sn_LP). Confirmar el gap.
SELECT TOP 1 * FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK)
WHERE Compartimiento LIKE '%TRACCION%';   -- inspeccionar columnas Pb_/Sn_ en el grid
GO

-- ==== BLOQUE 51 — VALIDAR fix Pb/Sn LC (crítico) tras re-correr la cadena ====
-- ORDEN de re-corrida en SSMS (dependencias): 1) vw_LimitesPorComponente  2) vw_MuestrasEstado
-- 3) (vw_MuestrasRankeadas hereda por me.*)  4) vw_TendenciaElemento  5) las *MD (último, historial-metal).
GO
-- 51.1 La fundación ya expone Pb_LC / Sn_LC y marca crítico (Antapaccay MT: Pb LC=5, Sn LC=5)
SELECT TOP 20 Equipo, Compartimiento, Pb_ppm, Pb_LP, Pb_LC, Estado_Pb, Sn_ppm, Sn_LP, Sn_LC, Estado_Sn
FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK)
WHERE Compartimiento LIKE '%TRACCION%' AND Proyecto='Antapaccay'
  AND (Pb_ppm > Pb_LP OR Sn_ppm > Sn_LP)
ORDER BY Pb_ppm DESC;
GO
-- 51.2 ¿Algún MT con Pb o Sn CRÍTICO (>LC) ahora? (antes: imposible, LC no existía)
SELECT Proyecto, Equipo, Compartimiento, Pb_ppm, Pb_LC, Estado_Pb, Sn_ppm, Sn_LC, Estado_Sn
FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK)
WHERE Estado_Pb='CRITICO' OR Estado_Sn='CRITICO';
GO
-- 51.3 Último análisis de un MT: la tabla ya trae LC de Pb/Sn (no '—') y chip si supera
SELECT MD FROM [dbo].[vw_UltimoAnalisisMD] WITH (NOLOCK)
WHERE Equipo LIKE '%CA3163%' AND compAbbr LIKE '%MT RH%';   -- CA3163 tenía Pb,Zn observados en triage
GO

-- ==== BLOQUE 52 — VALIDAR Pb/Sn LC en BARRIDO (vw_ObservadosFlota) ====
-- Re-correr en orden: vw_ObservadosFlota -> vw_ObservadosResumen -> vw_ObservadosResumenMD / vw_ObservadosBarridoMD.
GO
-- 52.1 ¿Mets_Obs ahora incluye Pb:C / Sn:C donde el ppm supera LC?
SELECT TOP 20 Equipo, Compartimiento, NumCrit, NumPrec, Mets_Obs
FROM [dbo].[vw_ObservadosFlota] WITH (NOLOCK)
WHERE Proyecto='Antapaccay' AND Compartimiento LIKE '%TRACCION%'
  AND (Mets_Obs LIKE '%Pb:C%' OR Mets_Obs LIKE '%Sn:C%')
ORDER BY NumCrit DESC;
GO
-- 52.2 Barrido resumen de Antapaccay 980E (los Pb/Sn crít deben contar en 🔴 Crít, no en 🟡 Prec)
SELECT MD FROM [dbo].[vw_ObservadosResumenMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%';
GO

-- ==== BLOQUE 53 — VALIDAR salud (V100/viscosidad) en la fundación ====
-- Re-correr: vw_LimitesPorComponente -> vw_MuestrasEstado. V100 fuera de rango [LCI,LCS] = CRITICO.
GO
-- 53.1 ¿Estado_V100 marca crítico/precaución donde V100 sale del rango? (Antapaccay MT: LCI=70.1 LCS=85.7)
SELECT TOP 30 Proyecto, Equipo, Compartimiento, V100, V100_LCI, V100_LCS, Estado_V100, Estado_General
FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK)
WHERE Estado_V100 IN ('CRITICO','PRECAUCION')
ORDER BY Estado_V100, Proyecto, Equipo;
GO
-- 53.2 IMPACTO: ¿cuántos componentes NUEVOS pasan a observado SOLO por V100?
--      (Estado_General<>OK pero ningún metal de desgaste fuera — el disparo es la viscosidad)
SELECT COUNT(*) AS SoloPorV100
FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK)
WHERE rn_recencia=1 AND Estado_V100<>'OK'
  AND Fe_ppm<=ISNULL(Fe_LP,9999) AND Cr_ppm<=ISNULL(Cr_LP,9999) AND Cu_ppm<=ISNULL(Cu_LP,9999)
  AND Pb_ppm<=ISNULL(Pb_LP,9999) AND Sn_ppm<=ISNULL(Sn_LP,9999);
GO

-- ==== BLOQUE 54 — #6b salud V100 (viscosidad) informativa en barrido detalle ====
SELECT Modelo, MD FROM [dbo].[vw_ObservadosBarridoMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%';   -- busca ' V100=' en el MD (chip salud en equipos ya observados)
GO
SELECT
  SUM(CASE WHEN Estado_General <> 'OK' THEN 1 ELSE 0 END) AS Observados_totales,
  SUM(CASE WHEN Estado_General <> 'OK' AND Estado_V100 IN ('CRITICO','PRECAUCION') THEN 1 ELSE 0 END) AS Con_V100_salud,
  SUM(CASE WHEN Estado_General =  'OK' AND Estado_V100 IN ('CRITICO','PRECAUCION') THEN 1 ELSE 0 END) AS Solo_V100_excluidos
FROM [dbo].[vw_ObservadosFlota] WITH (NOLOCK) WHERE Proyecto LIKE '%Antapaccay%';
GO

-- ==== BLOQUE 55 — #14 vw_TendenciaIncipienteMD (firma proyecto, flujo MD_flota modelo=todos) ====
-- FIX gerencia 2026-08-14: baseline = promedio de las 6 PREVIAS (rn 2..7), SIN el ultimo (rn 1); total 7 muestras.
-- + tabla 'Limites de referencia (ppm)' aparte (LP/LC de los metales incipientes), como en Tendencia.
SELECT Observados, Recomendaciones, MD FROM [dbo].[vw_TendenciaIncipienteMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%todos%';
GO

-- ==== BLOQUE 56 — Barrido: (todos) sin modelo Y por-modelo especifico (duplicacion) ====
SELECT Modelo, MD FROM [dbo].[vw_ObservadosBarridoMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%todos%';
GO
SELECT Modelo, MD FROM [dbo].[vw_ObservadosBarridoMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980%';
GO
SELECT DISTINCT Modelo FROM [dbo].[vw_ObservadosResumenMD] WITH (NOLOCK) WHERE Proyecto LIKE '%Antapaccay%';
GO

-- ==== BLOQUE 57 — Triage recos: solo metales de la tabla (sin Calcio/Zinc informativos) ====
SELECT MD, Recomendaciones FROM [dbo].[vw_TriageMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%todos%';
GO

-- ==== BLOQUE 58 — Historial INCLUYE DDI (unico topico con DDI; vw_MuestrasHistorial + rn_hist) ====
SELECT TOP 15 Equipo, Compartimiento, FechaMuestreo, CM, EsDDI, rn_hist
FROM [dbo].[vw_MuestrasHistorial] WITH (NOLOCK)
WHERE Equipo LIKE '%CA3171%' AND Compartimiento LIKE '%TRACCION%LH' ORDER BY rn_hist;
GO
SELECT MD FROM [dbo].[vw_HistorialMD] WITH (NOLOCK)
WHERE Equipo LIKE '%CA3171%' AND compAbbr = 'MT LH';   -- las vistas MD filtran por compAbbr
GO

-- ==== BLOQUE 59 — vw_ConteoFlotaMD (Conteo; flujo MD_flota; proyecto + modelo) ====
SELECT Modelo, MD FROM [dbo].[vw_ConteoFlotaMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%todos%';
GO
-- por-modelo: cambia '%todos%' por '%980%' (o el modelo real del proyecto)

-- ==== BLOQUE 60 — vw_RankingMD (formato largo; el flujo MD_ranking arma la tabla con pos<=top) ====
SELECT MAX(HeaderMD) + NCHAR(10) + STRING_AGG(Fila, NCHAR(10)) WITHIN GROUP (ORDER BY pos) AS MD
FROM [dbo].[vw_RankingMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%todos%'
  AND CompTipo COLLATE Latin1_General_CI_AI LIKE '%traccion%' AND Metal LIKE '%Fe%' AND pos <= 5;
GO
-- cambia 'pos <= 5' por 10 para top 10; cambia Metal/CompTipo para otros rankings

-- ==== BLOQUE 61 — Tendencia con Grado (lubricante) + horas comp ====
SELECT MD FROM [dbo].[vw_TendenciaMetalMD] WITH (NOLOCK)
WHERE Equipo LIKE '%CA3170%' AND Parametro='Fe';       -- tabla trae Grado + Hrs C. por componente
GO
SELECT MD FROM [dbo].[vw_TendenciaP1MD] WITH (NOLOCK)
WHERE Equipo LIKE '%CA3170%' AND compAbbr='MT LH';     -- info general incluye fila Grado
GO

-- ==== BLOQUE 62 — vw_TendenciaMetalFlotaMD (Gap1; flujo MD_metal_flota; proyecto+CompTipo+Metal) ====
SELECT MD FROM [dbo].[vw_TendenciaMetalFlotaMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%todos%'
  AND CompTipo COLLATE Latin1_General_CI_AI LIKE '%traccion%' AND Metal LIKE '%Fe%';
GO
-- '¿como evoluciono el Fe en los MT de la flota?' -> dirección por equipo. Cambia Metal/CompTipo.

-- ==== BLOQUE 63 — vw_CondicionCompMD (Gap2; flujo MD_metal_flota sin parametro; proyecto+CompTipo) ====
SELECT MD FROM [dbo].[vw_CondicionCompMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%todos%'
  AND CompTipo COLLATE Latin1_General_CI_AI LIKE '%hidraul%';
GO
-- '¿que sistemas hidraulicos necesitan atencion?' -> equipos con hidraulico observado. Cambia CompTipo.

-- ==== BLOQUE 64 — vw_UltimoMetalFlotaMD (Ultimo analisis en barrido por metal; 1..N metales) ====
-- 1 metal (como '¿ultimo analisis de hierro de todos los MT en Antamina?'):
SELECT MD FROM [dbo].[vw_UltimoMetalFlotaMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antamina%' AND Modelo LIKE '%todos%'
  AND CompTipo COLLATE Latin1_General_CI_AI LIKE '%traccion%'
  AND CHARINDEX(',' + Metal + ',', ',' + 'Fe' + ',') > 0
ORDER BY MetalOrden;
GO
-- N metales (como 'hierro y cobre y cromo de los MT'): el flujo hace STRING_AGG -> 1 tabla por metal.
SELECT STRING_AGG(MD, NCHAR(10)+NCHAR(10)) WITHIN GROUP (ORDER BY MetalOrden) AS MD
FROM [dbo].[vw_UltimoMetalFlotaMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antamina%' AND Modelo LIKE '%todos%'
  AND CompTipo COLLATE Latin1_General_CI_AI LIKE '%traccion%'
  AND CHARINDEX(',' + Metal + ',', ',' + 'Fe,Cu,Cr' + ',') > 0;
GO
-- Por modelo especifico (Modelo LIKE '%980E%' en vez de '%todos%'); ordena por valor desc dentro de cada metal.
-- Informativos (Ca/Zn/K/Na/Mg/B/P/V100) salen con 'inf' sin chip; TBN inverso (🟨 si < LP).
-- SIN columna "Estado" (el chip del valor ya lo indica; conteo observados/criticos en el encabezado).
-- El semaforo juzga contra el LP/LC de REFERENCIA del grupo cuando el limite propio de la fila es NULL
-- (evita falsos "OK" en valores altos de equipos sin limite cargado). CM se mantiene (aun sin data en Antamina).
-- ⚠️ junto al valor = metal en 0.0 (muestra no-DDI, posible falso positivo; el area lo revisa aparte).
-- Recomendaciones: el view la llena SOLO si CompTipo=TRACCION y el metal salio observado (verbatim vw_Recomendaciones);
-- el flujo agrega con cabecera MT (ver BLOQUE del flujo). Verificar que en no-MT / sin observados venga NULL:
SELECT Metal, CompTipo, Recomendaciones FROM [dbo].[vw_UltimoMetalFlotaMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antamina%' AND Modelo LIKE '%todos%' AND CompTipo COLLATE Latin1_General_CI_AI LIKE '%traccion%'
  AND CHARINDEX(',' + Metal + ',', ',' + 'Fe,Cu' + ',') > 0;
GO

-- ==== BLOQUE 65 — vw_AcumuladosFlotaMD (wrapper del Ranking de Atencion / acumulados motor diesel) ====
-- Fuente: vw_RankingHistorico (ULTIMA foto por equipo; reemplazo vigente, aplica lixiviacion de Cu = cuadra con el dashboard).
-- Requiere que vw_RankingHistorico exista en la BD (dashboard PBI). Alcance: Antapaccay motor diesel.
SELECT MD FROM [dbo].[vw_AcumuladosFlotaMD] WITH (NOLOCK) WHERE Proyecto LIKE '%Antapaccay%';
GO
-- Verifica: tabla ordenada por Ranking desc, # = posicion, metales Acum + H.Motor/H.Metal + Estado.
-- Estado por score (limites 60/65/70): <60 Monitoreo, 60-65 Atencion, 65-70 Alerta, >=70 Critico.
-- Sanity: comparar orden/valores/Estado contra el dashboard (vw_RankingAtencion en su propio .sql).

-- ==== BLOQUE 66 — vw_AcumuladosEquipoMD (acumulados de 1 equipo; flujo MD_acumequipo) ====
SELECT MD FROM [dbo].[vw_AcumuladosEquipoMD] WITH (NOLOCK) WHERE Equipo LIKE '%CA3197%';
GO
-- Verifica: linea de contexto (serie, horas motor/metal, ranking, estado) + tabla Metal|Acumulado (7 metales).

-- ==== BLOQUE 67 — VERIFICACION acumulados: KomfIA vs vista cruda vs dashboard ====
-- La ULTIMA foto cruda de vw_RankingHistorico (lo que KomfIA envuelve). Debe COINCIDIR fila a fila con
-- vw_AcumuladosFlotaMD (BLOQUE 65). Si KomfIA == esta vista PERO != dashboard PBI -> el PBI esta DESFASADO
-- (modo import sin refrescar): la diferencia son muestras NUEVAS (mas horas, +1-2 ppm) que la vista viva ya
-- tiene. Cambios de metal / lixiviacion Cu / RP YA estan en vw_RankingHistorico (KomfIA los hereda; no se tocan).
WITH ult AS (
    SELECT rh.*, ROW_NUMBER() OVER (PARTITION BY rh.[N° Int.] ORDER BY rh.Fecha DESC, rh.[Horas Motor Actual] DESC) AS rn
    FROM [dbo].[vw_RankingHistorico] rh
)
SELECT [N° Int.], Fecha, Serie, [Horas Motor Actual], [Horas Motor Metal],
       [Fe Acum],[Cr Acum],[Pb Acum],[Cu Acum],[Na Acum],[K Acum],[Si Acum],[Ranking]
FROM ult WHERE rn = 1 ORDER BY [Ranking] DESC;
GO
-- Interpretacion: si un equipo (ej CA3175) sale con +63 h y +2 ppm Fe respecto al dashboard, es una muestra
-- nueva -> refrescar el PBIX. CA3197 ya coincidia exacto (no tenia muestra nueva). No hay bug de logica.


-- ==== BLOQUE 68 — Formato de tablas en Teams + ausencia del rotulo "inf" ====
-- Regresion del lote 2026-09-19. Re-correr tras CUALQUIER cambio de las vistas MD.
-- (1) Markdown exige una LINEA EN BLANCO antes de una tabla. Si el "**encabezado**" va pegado con un solo
--     salto, Teams NO la reconoce y la vuelca como muro de texto. Verificar con Ctrl+T (salida a texto):
--     cada seccion "**COMPONENTE** (n equipos)" y cada "**Limites de referencia (ppm)**" debe tener una
--     linea vacia antes de su tabla.
SELECT DetalleTodosMD FROM [dbo].[vw_ObservadosBarridoMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo = N'(todos)';
GO
SELECT MD FROM [dbo].[vw_ObservadosResumenMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo = N'(todos)';
GO
SELECT MD FROM [dbo].[vw_TendenciaIncipienteMD] WITH (NOLOCK) WHERE Proyecto LIKE '%Antapaccay%';
GO
-- (2) ANTI-"inf": el rotulo de Ca/Zn/K/Na/Mg se elimino de TODAS las vistas (siguen con su chip y sin
--     alterar el Estado). Estas 2 columnas son el origen: si ahi no esta, no puede salir en ningun MD.
--     ⚠ Filtrar SIEMPRE: sin filtro se materializa el MD de todos los proyectos y la consulta se cuelga.
SELECT 'vw_ObservadosFlota.Detalle' AS Origen,
       SUM(CASE WHEN Detalle  LIKE '%' + CHAR(32) + 'inf%' THEN 1 ELSE 0 END) AS con_inf
FROM [dbo].[vw_ObservadosFlota] WITH (NOLOCK) WHERE Proyecto LIKE '%Antapaccay%'
UNION ALL
SELECT 'vw_HistorialMuestra.Mets_Obs',
       SUM(CASE WHEN Mets_Obs LIKE '%' + CHAR(32) + 'inf%' THEN 1 ELSE 0 END)   -- OJO: Mets_Obs (con s)
FROM [dbo].[vw_HistorialMuestra] WITH (NOLOCK) WHERE Equipo LIKE '%CA3177%';
GO
-- Esperado: con_inf = 0 en ambas.

-- ==== BLOQUE 69 — Rendimiento del barrido de flota (regresion) ====
-- HISTORIA (2026-09-19): el barrido tardaba 6:21. Se descartaron con mediciones tres hipotesis -- cache frio
-- (2 pasadas identicas), el LEFT JOIN a HsCc (HsCc=332 filas, y el optimizador ni lo usa en ResumenMD) y el
-- numero de referencias a la fundacion (un candidato que las redujo NO mejoro). El cuello real se encontro
-- AISLANDO por mitades: tabla-por-equipo = 2 s vs cuadro-de-limites = 33 s. Dentro de esa mitad, el CTE
-- 'obsf' se referenciaba dos veces (compsev + metrows) y el JOIN entre ambas ramas caia en NESTED LOOPS:
-- la fundacion se re-ejecutaba 257 veces (LaboratoryData 25 286 005 lecturas).
-- FIX: 'sev' por FUNCION DE VENTANA sobre una sola referencia (CTE obsf2), eliminando compsev y su JOIN.
--      Aplicado a vw_ObservadosResumenMD y vw_ObservadosBarridoMD.
--      ⚠ El sev se calcula ANTES del filtro por metal: el WHERE precede a las funciones de ventana.
-- RESULTADO: vista completa 367 918 ms -> 19 470 ms (~20x) | CPU 79 406 -> 4 391 ms |
--            LaboratoryData 257 scans/25 286 005 lecturas -> 14 scans/576 527 | salida IDENTICA (EXCEPT = 0).
-- REGLA GENERAL APRENDIDA: un CTE pesado referenciado 2 veces + JOIN entre sus dos ramas = nested loops que
--   re-expanden la fundacion. Sustituir el JOIN por una funcion de ventana sobre UNA sola referencia.
-- MARGEN RESTANTE (opcional): quedan 14 scans; el 2o camino a la fundacion (r <- vw_ObservadosResumen, con
--   'tabla' y 'cnt' referenciando 'r') se podria consolidar. No urgente: ya estamos lejos del timeout.
SET STATISTICS IO ON; SET STATISTICS TIME ON;
GO
SELECT LEN(MD) AS len_md FROM [dbo].[vw_ObservadosResumenMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo = N'(todos)';
GO
SELECT LEN(DetalleTodosMD) AS len_det FROM [dbo].[vw_ObservadosBarridoMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo = N'(todos)';
GO
SET STATISTICS IO OFF; SET STATISTICS TIME OFF;
GO
-- Esperado: SEGUNDOS y [Oil].[LaboratoryData] con scan count BAJO (~14, nunca 257). Si vuelve a subir,
-- buscar un CTE referenciado 2 veces con un JOIN entre sus ramas (el patron de arriba).

-- ==== BLOQUE 70 — Determinismo de Met_Obs ====
-- vw_ObservadosResumen armaba Met_Obs con STRING_AGG(...) WITHIN GROUP (ORDER BY NumCrit DESC) SIN desempate:
-- con componentes empatados en NumCrit el orden lo decidia el PLAN, asi que la MISMA consulta podia renderizar
-- distinto entre ejecuciones. Corregido anadiendo ", Compartimiento". De los 25 STRING_AGG del DDL era el unico
-- sin desempate (el resto ordena por ord/Orden/Equipo/rn).
-- (a) Equipos con empate (los que exponian el problema): Antamina tiene varios con 4-5 componentes empatados.
SELECT TOP 10 Proyecto, Equipo, NumCrit, COUNT(*) AS comps_empatados
FROM [dbo].[vw_ObservadosFlota] WITH (NOLOCK)
WHERE Estado_General <> 'OK'
GROUP BY Proyecto, Equipo, NumCrit
HAVING COUNT(*) > 1
ORDER BY comps_empatados DESC, Proyecto, Equipo;
GO
-- (b) El orden de Met_Obs debe ser ESTABLE entre ejecuciones: correr 2 veces y comparar el hash.
SELECT CONVERT(varchar(64), HASHBYTES('SHA2_256', STRING_AGG(CONVERT(nvarchar(max), Equipo + '=' + ISNULL(Met_Obs,'')), '|')
       WITHIN GROUP (ORDER BY Equipo)), 2) AS hash_metobs
FROM [dbo].[vw_ObservadosResumen] WITH (NOLOCK) WHERE Proyecto LIKE '%Antamina%';
GO
-- Esperado: el MISMO hash en cada ejecucion.

-- ==== BLOQUE 71 — P4 (historial + RANGO): vista de filas y prototipo del flujo ====
-- CONTEXTO: las vistas *MD concatenan el markdown DENTRO (STRING_AGG), asi que el flujo no puede filtrar
-- muestras por fecha; y CREATE FUNCTION esta DENEGADO en esta BD (Msg 262, solo vistas + lectura).
-- SOLUCION: vw_HistorialFilasMD expone 1 fila por muestra con el rowMD ya armado; el FLUJO dedicado
-- (MD_historial) hace el filtro de fecha + TOP + STRING_AGG y antepone el encabezado.
-- Correr DESPUES de aplicar DDL_vistas.sql.

-- (1) SANIDAD: la vista de filas responde y trae lo esperado (1 fila por muestra).
SELECT TOP 20 Equipo, compAbbr, rn_hist, FechaMuestreo, rowMD
FROM [dbo].[vw_HistorialFilasMD] WITH (NOLOCK)
WHERE Equipo LIKE '%CA3176%' AND compAbbr LIKE '%MT LH%'
ORDER BY rn_hist;
GO

-- (2) MEDICION para fijar el TOPE (no estimarlo): chars por fila reales y cuanto ocuparia N filas.
-- Referencias ya medidas: barrido completo Antapaccay = 2 028 chars; techo de canal Teams ~28 KB.
SELECT
    COUNT(*)                                   AS filas_disponibles,
    AVG(LEN(rowMD))                            AS chars_por_fila_prom,
    MAX(LEN(rowMD))                            AS chars_por_fila_max,
    AVG(LEN(rowMD)) * 200                      AS estimado_200_filas,
    AVG(LEN(rowMD)) * 500                      AS estimado_500_filas
FROM [dbo].[vw_HistorialFilasMD] WITH (NOLOCK)
WHERE Equipo LIKE '%CA3176%' AND compAbbr LIKE '%MT LH%';
GO
-- Criterio: el tope elegido x chars_por_fila_max debe quedar MUY por debajo de 28 000. Ajustar el 200 con esto.

-- (3) EQUIVALENCIA — prototipo EXACTO de lo que hara el flujo, comparado contra la vista actual.
-- Sin filtro de fecha y con TOP 12 debe dar EXACTAMENTE el mismo MD que vw_HistorialMD.
DECLARE @equipo nvarchar(50) = N'CA3176';
DECLARE @comp   nvarchar(50) = N'MT LH';
DECLARE @desde  date         = '1900-01-01';   -- vacio = sin limite de fecha
DECLARE @tope   int          = 12;             -- el tope de hoy, para poder comparar
WITH sel AS (
    SELECT TOP (@tope) Equipo, compAbbr, rn_hist, rowMD
    FROM [dbo].[vw_HistorialFilasMD] WITH (NOLOCK)
    WHERE Equipo LIKE '%' + @equipo + '%'
      AND compAbbr LIKE '%' + @comp + '%'
      AND FechaMuestreo >= @desde
    ORDER BY rn_hist
),
arm AS (
    SELECT MAX(Equipo) AS Equipo, MAX(compAbbr) AS compAbbr, COUNT(*) AS N,
           STRING_AGG(rowMD, NCHAR(10)) WITHIN GROUP (ORDER BY rn_hist) AS bodyMD
    FROM sel
),
nuevo AS (
    SELECT CAST(
        N'**Historial — ' + Equipo + N' · ' + compAbbr + N'** · ' + CAST(N AS nvarchar(10)) + N' muestras (recientes arriba)' + NCHAR(10) + NCHAR(10)
      + N'| Fecha | Horóm. | Hor. Aci. | Met. Obs. | Hrs Comp | CM | Estado |' + NCHAR(10)
      + N'|---|---|---|---|---|---|---|' + NCHAR(10) + bodyMD
    AS nvarchar(max)) AS MD FROM arm
),
actual AS (
    SELECT MD FROM [dbo].[vw_HistorialMD] WITH (NOLOCK)
    WHERE Equipo LIKE '%' + @equipo + '%' AND compAbbr LIKE '%' + @comp + '%'
)
SELECT
    LEN(a.MD) AS len_actual, LEN(n.MD) AS len_nuevo,
    CONVERT(varchar(64), HASHBYTES('SHA2_256', a.MD), 2) AS hash_actual,
    CONVERT(varchar(64), HASHBYTES('SHA2_256', n.MD), 2) AS hash_nuevo,
    CASE WHEN HASHBYTES('SHA2_256', a.MD) = HASHBYTES('SHA2_256', n.MD)
         THEN 'IDENTICO ✅' ELSE 'DIFIERE ❌' END AS veredicto
FROM actual a CROSS JOIN nuevo n;
GO
-- Esperado: IDENTICO. Si difiere, comparar los MD a ojo (Ctrl+T): el rowMD debe ser byte a byte el mismo.

-- (4) EL RANGO FUNCIONA — misma consulta variando solo @desde y @tope.
--     «2 anios» debe traer MAS de 12 filas (si hay historia); «14 dias» debe traer MENOS.
DECLARE @eq nvarchar(50) = N'CA3176', @cp nvarchar(50) = N'MT LH';
SELECT v.etiqueta,
       (SELECT COUNT(*) FROM [dbo].[vw_HistorialFilasMD] WITH (NOLOCK)
         WHERE Equipo LIKE '%'+@eq+'%' AND compAbbr LIKE '%'+@cp+'%'
           AND FechaMuestreo >= v.desde) AS filas_en_rango
FROM (VALUES
    (N'14 dias',  DATEADD(DAY,  -14, CAST(GETDATE() AS date))),
    (N'5 meses',  DATEADD(MONTH, -5, CAST(GETDATE() AS date))),
    (N'2 anios',  DATEADD(YEAR,  -2, CAST(GETDATE() AS date))),
    (N'sin rango', CAST('1900-01-01' AS date))
) v(etiqueta, desde);
GO
-- Esperado: creciente de arriba a abajo. Si «2 anios» ya da mas de 12, el rango APORTA (hoy se perdian).

-- (5) PIE DE RECORTE — el flujo debe poder decir si corto. Devuelve total del rango vs mostradas.
DECLARE @eq2 nvarchar(50) = N'CA3176', @cp2 nvarchar(50) = N'MT LH', @tope2 int = 12;
SELECT COUNT(*) AS total_en_rango,
       CASE WHEN COUNT(*) > @tope2
            THEN N'_Mostrando las ' + CAST(@tope2 AS nvarchar(10)) + N' mas recientes de ' + CAST(COUNT(*) AS nvarchar(10)) + N' en el rango._'
            ELSE N'(sin recorte)' END AS pie
FROM [dbo].[vw_HistorialFilasMD] WITH (NOLOCK)
WHERE Equipo LIKE '%'+@eq2+'%' AND compAbbr LIKE '%'+@cp2+'%';
GO
-- Contrato: NUNCA cortar en silencio. Si total_en_rango > tope, el flujo anexa ese pie al MD.

-- ---- (6) RE-MEDIR tras el fix de rendimiento de vw_HistorialFilasMD (2026-09-20) ----
-- RESULTADOS DE LA 1a VERSION (tope 500, CTE obs con CROSS APPLY + GROUP BY + LEFT JOIN):
--   (1) TOP 20 con rowMD ....... 3m 25s
--   (2) AVG(LEN(rowMD)) ........ 5m 22s
--   (5) COUNT(*) (sin rowMD) ... 6 s     <-- misma vista, mismo filtro: la diferencia es COMPUTAR rowMD
--   -> el costo era armar rowMD, no leer. Mismo anti-patron del barrido (CTE + JOIN entre ramas),
--      amplificado x40 por subir el tope de 12 a 500.
-- FIX: obsList fila a fila con STUFF(CONCAT(...)), sin GROUP BY ni JOIN. Tope 200 (medido: 59 chars/fila max).
-- Correr estas 3 y comparar contra los tiempos de arriba:
SET STATISTICS TIME ON;
GO
-- (6a) debe bajar de 3m25s a segundos
SELECT TOP 20 Equipo, compAbbr, rn_hist, FechaMuestreo, rowMD
FROM [dbo].[vw_HistorialFilasMD] WITH (NOLOCK)
WHERE Equipo LIKE '%CA3176%' AND compAbbr LIKE '%MT LH%'
ORDER BY rn_hist;
GO
-- (6b) debe bajar de 5m22s a segundos
SELECT COUNT(*) AS filas, AVG(LEN(rowMD)) AS chars_prom, MAX(LEN(rowMD)) AS chars_max
FROM [dbo].[vw_HistorialFilasMD] WITH (NOLOCK)
WHERE Equipo LIKE '%CA3176%' AND compAbbr LIKE '%MT LH%';
GO
SET STATISTICS TIME OFF;
GO
-- (6c) ⚠ RE-VERIFICAR EQUIVALENCIA: se reescribio como se arma la lista de metales, asi que hay que
--      confirmar de nuevo que el MD sigue siendo IDENTICO. Volver a correr la parte (3) de este bloque.
--      Esperado: veredicto = IDENTICO (hash EE8BFA522F2C7B649EF5D2C66A90691CFF73C47AB5EDF0D2209BAFFB849F53A3).

-- (6d) Control de borde: filas SIN ningun metal fuera de limite deben mostrar '—' (no vacio),
--      y filas con VARIOS deben listarlos separados por ', ' en el orden Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si.
SELECT TOP 10 rn_hist, FechaMuestreo, rowMD
FROM [dbo].[vw_HistorialFilasMD] WITH (NOLOCK)
WHERE Equipo LIKE '%CA3176%' AND compAbbr LIKE '%MT LH%'
  AND rowMD LIKE '%,%'          -- filas con 2+ metales observados
ORDER BY rn_hist;
GO
-- Referencia de la corrida anterior: rn_hist=18 (07-Mar-26) mostraba 'Fe, PQ'. Debe seguir igual.

-- ==== BLOQUE 72 — P4 paso 4: query del flujo MD_historial (validar ANTES de armar el flujo) ====
-- Es EXACTAMENTE el SQL que ejecutara el flujo, con los 4 parametros como DECLARE.
-- Nota de diseno: el total del rango se saca con COUNT(*) OVER () en la MISMA pasada, para NO
-- referenciar vw_HistorialFilasMD dos veces (leccion del barrido: 2 referencias + JOIN = nested loops).

-- ---- (1) SIN RANGO y tope 12 -> debe dar EXACTAMENTE el MD de vw_HistorialMD ----
DECLARE @equipo nvarchar(50) = N'CA3176';
DECLARE @comp   nvarchar(50) = N'MT LH';
DECLARE @desde  nvarchar(20) = N'1900-01-01';
DECLARE @tope   int          = 12;
WITH f AS (
    SELECT Equipo, compAbbr, rn_hist, rowMD, COUNT(*) OVER () AS Tot
    FROM [dbo].[vw_HistorialFilasMD] WITH (NOLOCK)
    WHERE Equipo LIKE '%' + @equipo + '%'
      AND compAbbr COLLATE Latin1_General_CI_AI LIKE '%' + @comp + '%'
      AND FechaMuestreo >= @desde
),
sel AS (SELECT TOP (@tope) * FROM f ORDER BY rn_hist),
nuevo AS (
    SELECT
        N'**Historial — ' + MAX(Equipo) + N' · ' + MAX(compAbbr) + N'** · ' + CAST(COUNT(*) AS nvarchar(10)) + N' muestras (recientes arriba)' + NCHAR(10) + NCHAR(10)
      + N'| Fecha | Horóm. | Hor. Aci. | Met. Obs. | Hrs Comp | CM | Estado |' + NCHAR(10)
      + N'|---|---|---|---|---|---|---|' + NCHAR(10)
      + STRING_AGG(rowMD, NCHAR(10)) WITHIN GROUP (ORDER BY rn_hist)
      + CASE WHEN MAX(Tot) > COUNT(*)
             THEN NCHAR(10) + NCHAR(10) + N'_Mostrando las ' + CAST(COUNT(*) AS nvarchar(10)) + N' más recientes de ' + CAST(MAX(Tot) AS nvarchar(10)) + N' en el rango._'
             ELSE N'' END AS MD
    FROM sel
),
actual AS (
    SELECT MD FROM [dbo].[vw_HistorialMD] WITH (NOLOCK)
    WHERE Equipo LIKE '%' + @equipo + '%' AND compAbbr LIKE '%' + @comp + '%'
)
SELECT LEN(a.MD) AS len_actual, LEN(n.MD) AS len_nuevo, LEN(n.MD) - LEN(a.MD) AS delta,
       CASE WHEN LEFT(n.MD, LEN(a.MD)) = a.MD THEN 'CUERPO IDENTICO ✅' ELSE 'DIFIERE ❌' END AS cuerpo,
       SUBSTRING(n.MD, LEN(a.MD) + 1, 200) AS sufijo_anadido
FROM actual a CROSS JOIN nuevo n;
GO
-- ⚠ CORREGIDO 20/09: la 1a version comparaba el hash COMPLETO y daba "DIFIERE" — pero NO era un bug:
--    con tope 12 y 42 muestras disponibles el PIE DE RECORTE se dispara (correctamente), asi que el MD
--    nuevo = MD de hoy + pie. La diferencia medida fue de 53 chars = exactamente el pie
--    («_Mostrando las 12 mas recientes de 42 en el rango._» = 51 + 2 saltos).
-- Por eso ahora se compara el CUERPO (prefijo) y se muestra aparte el sufijo anadido.
-- Esperado: cuerpo = CUERPO IDENTICO, y sufijo_anadido = el pie de recorte.
-- Eso prueba las DOS cosas: que reproduce la salida de hoy Y que ahora avisa lo que antes callaba.

-- ---- (2) CON RANGO «2 anios» y tope 200 -> debe traer 42 filas y SIN pie de recorte ----
DECLARE @eq2 nvarchar(50) = N'CA3176', @cp2 nvarchar(50) = N'MT LH', @tope2 int = 200;
DECLARE @desde2 nvarchar(20) = CONVERT(nvarchar(10), DATEADD(YEAR, -2, CAST(GETDATE() AS date)), 23);
WITH f AS (
    SELECT Equipo, compAbbr, rn_hist, rowMD, COUNT(*) OVER () AS Tot
    FROM [dbo].[vw_HistorialFilasMD] WITH (NOLOCK)
    WHERE Equipo LIKE '%' + @eq2 + '%'
      AND compAbbr COLLATE Latin1_General_CI_AI LIKE '%' + @cp2 + '%'
      AND FechaMuestreo >= @desde2
),
sel AS (SELECT TOP (@tope2) * FROM f ORDER BY rn_hist)
SELECT COUNT(*) AS filas_mostradas, MAX(Tot) AS total_en_rango, LEN(
        N'**Historial — ' + MAX(Equipo) + N' · ' + MAX(compAbbr) + N'** · ' + CAST(COUNT(*) AS nvarchar(10)) + N' muestras (recientes arriba)' + NCHAR(10) + NCHAR(10)
      + N'| Fecha | Horóm. | Hor. Aci. | Met. Obs. | Hrs Comp | CM | Estado |' + NCHAR(10)
      + N'|---|---|---|---|---|---|---|' + NCHAR(10)
      + STRING_AGG(rowMD, NCHAR(10)) WITHIN GROUP (ORDER BY rn_hist)) AS len_md
FROM sel;
GO
-- Esperado: filas_mostradas = total_en_rango = 42, y len_md comodamente bajo 28 000.

-- ---- (3) CON RANGO «2 anios» pero tope 12 -> debe aparecer el PIE DE RECORTE ----
DECLARE @eq3 nvarchar(50) = N'CA3176', @cp3 nvarchar(50) = N'MT LH', @tope3 int = 12;
DECLARE @desde3 nvarchar(20) = CONVERT(nvarchar(10), DATEADD(YEAR, -2, CAST(GETDATE() AS date)), 23);
WITH f AS (
    SELECT Equipo, compAbbr, rn_hist, rowMD, COUNT(*) OVER () AS Tot
    FROM [dbo].[vw_HistorialFilasMD] WITH (NOLOCK)
    WHERE Equipo LIKE '%' + @eq3 + '%'
      AND compAbbr COLLATE Latin1_General_CI_AI LIKE '%' + @cp3 + '%'
      AND FechaMuestreo >= @desde3
),
sel AS (SELECT TOP (@tope3) * FROM f ORDER BY rn_hist)
SELECT
    STRING_AGG(rowMD, NCHAR(10)) WITHIN GROUP (ORDER BY rn_hist)
  + CASE WHEN MAX(Tot) > COUNT(*)
         THEN NCHAR(10) + NCHAR(10) + N'_Mostrando las ' + CAST(COUNT(*) AS nvarchar(10)) + N' más recientes de ' + CAST(MAX(Tot) AS nvarchar(10)) + N' en el rango._'
         ELSE N'' END AS cuerpo_con_pie
FROM sel;
GO
-- Esperado (Ctrl+T): 12 filas y al final «_Mostrando las 12 más recientes de 42 en el rango._»

-- ==== BLOQUE 73 — INVENTARIO REAL de componentes (para normalizar el comando, P4 paso 7.b) ====
-- Motivo: el CASE de compAbbr de las vistas SOLO mapea TRACCION LH/RH, RUEDA LH/RH, HIDRAUL y MOTOR.
-- TODO lo demas cae al ELSE y compAbbr se queda con el Compartimiento COMPLETO. Antes de escribir la
-- normalizacion del dispatcher hay que saber QUE componentes existen de verdad y como quedan.

-- (1) INVENTARIO COMPLETO: cada Compartimiento real, su CompTipo, el compAbbr que calculan las vistas,
--     y si el CASE lo cubre o cae al ELSE. Ordenado por los NO cubiertos primero.
SELECT
    Compartimiento,
    CompTipo,
    CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH'
         WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH'
         WHEN Compartimiento LIKE '%RUEDA%LH'    THEN N'RD LH'
         WHEN Compartimiento LIKE '%RUEDA%RH'    THEN N'RD RH'
         WHEN Compartimiento LIKE '%HIDRAUL%'    THEN N'Sist. Hidr.'
         WHEN Compartimiento = 'MOTOR'           THEN N'Motor'
         ELSE Compartimiento END                          AS compAbbr_calculado,
    CASE WHEN Compartimiento LIKE '%TRACCION%LH' OR Compartimiento LIKE '%TRACCION%RH'
           OR Compartimiento LIKE '%RUEDA%LH'    OR Compartimiento LIKE '%RUEDA%RH'
           OR Compartimiento LIKE '%HIDRAUL%'    OR Compartimiento = 'MOTOR'
         THEN 'cubierto' ELSE '>>> CAE AL ELSE <<<' END   AS cobertura,
    COUNT(*)                        AS muestras,
    COUNT(DISTINCT Equipo)          AS equipos,
    COUNT(DISTINCT Proyecto)        AS proyectos,
    MIN(FechaMuestreo)              AS desde,
    MAX(FechaMuestreo)              AS hasta
FROM [dbo].[vw_MuestrasHistorial] WITH (NOLOCK)
GROUP BY Compartimiento, CompTipo
ORDER BY cobertura DESC, muestras DESC;
GO
-- Leer asi: todo lo que diga «CAE AL ELSE» es un componente que HOY el comando no puede nombrar en corto
-- (hay que escribir su nombre completo). Con esa lista se completa la normalizacion del paso 7.b.

-- (2) Los CompTipo que existen (esto es lo que usan triage/ranking/metalflota, que SI aceptan la palabra natural).
SELECT CompTipo, COUNT(DISTINCT Compartimiento) AS variantes_compartimiento, COUNT(*) AS muestras
FROM [dbo].[vw_MuestrasHistorial] WITH (NOLOCK)
GROUP BY CompTipo
ORDER BY muestras DESC;
GO

-- (3) Que componentes tiene CADA proyecto (por si Antamina/Cerro Verde/Toromocho traen tipos que Antapaccay no).
SELECT Proyecto, Compartimiento, COUNT(DISTINCT Equipo) AS equipos
FROM [dbo].[vw_MuestrasHistorial] WITH (NOLOCK)
GROUP BY Proyecto, Compartimiento
ORDER BY Proyecto, equipos DESC;
GO
-- ⚠ Ojo a variantes con typo (ya se conocia «MOTORO DE TRACCION RH» en Antamina): si aparecen, la
-- normalizacion debe tolerarlas (el LIKE '%TRACC%' las agarra, un '=' exacto no).

-- ==== BLOQUE 74 — P4 paso 8.1: query GENERICO del flujo (encabezado desde la vista) ====
-- La vista *FilasMD ahora expone TituloMD + SufijoMD + ColsMD, asi que UN solo flujo sirve a los 5 temas.
-- Este es el SQL generico con los 7 parametros. Debe dar EL MISMO cuerpo que el BLOQUE 72.
DECLARE @equipo nvarchar(50) = N'CA3176';
DECLARE @comp   nvarchar(50) = N'MT LH';
DECLARE @param  nvarchar(50) = N'';
DECLARE @proy   nvarchar(50) = N'';
DECLARE @desde  nvarchar(20) = N'1900-01-01';
DECLARE @tope   int          = 12;
WITH f AS (
    SELECT Equipo, compAbbr, Parametro, Proyecto, rn, TituloMD, SufijoMD, ColsMD, Fila,
           COUNT(*) OVER () AS Tot
    FROM [dbo].[vw_HistorialFilasMD] WITH (NOLOCK)
    WHERE Equipo   LIKE '%' + @equipo + '%'
      AND compAbbr COLLATE Latin1_General_CI_AI LIKE '%' + @comp + '%'
      AND Parametro LIKE '%' + @param + '%'
      AND Proyecto  LIKE '%' + @proy  + '%'
      AND FechaMuestreo >= @desde
),
sel AS (SELECT TOP (@tope) * FROM f ORDER BY rn),
nuevo AS (
    SELECT MAX(TituloMD) + CAST(COUNT(*) AS nvarchar(10)) + MAX(SufijoMD) + NCHAR(10) + NCHAR(10)
         + MAX(ColsMD) + NCHAR(10)
         + STRING_AGG(Fila, NCHAR(10)) WITHIN GROUP (ORDER BY rn)
         + CASE WHEN MAX(Tot) > COUNT(*)
                THEN NCHAR(10) + NCHAR(10) + N'_Mostrando las ' + CAST(COUNT(*) AS nvarchar(10)) + N' más recientes de ' + CAST(MAX(Tot) AS nvarchar(10)) + N' en el rango._'
                ELSE N'' END AS MD
    FROM sel
),
actual AS (
    SELECT MD FROM [dbo].[vw_HistorialMD] WITH (NOLOCK)
    WHERE Equipo LIKE '%' + @equipo + '%' AND compAbbr LIKE '%' + @comp + '%'
)
SELECT LEN(a.MD) AS len_actual, LEN(n.MD) AS len_nuevo, LEN(n.MD) - LEN(a.MD) AS delta,
       CASE WHEN LEFT(n.MD, LEN(a.MD)) = a.MD THEN 'CUERPO IDENTICO ✅' ELSE 'DIFIERE ❌' END AS cuerpo,
       SUBSTRING(n.MD, LEN(a.MD) + 1, 200) AS sufijo_anadido
FROM actual a CROSS JOIN nuevo n;
GO
-- Esperado: CUERPO IDENTICO y sufijo = el pie de recorte (delta 53, igual que en el BLOQUE 72).
-- Si sale DIFIERE, el problema esta en TituloMD/SufijoMD/ColsMD de la vista, no en el flujo.

-- ==== BLOQUE 75 — P4 paso 8.2: equivalencia de las 4 vistas *FilasMD restantes ====
-- Cada una debe reproducir el CUERPO de su vista *MD actual cuando se usa su tope original y sin rango.
-- Topes originales: Equipo/MetalEquipo/Flota = 24 (grn) · Metal = 12 (rn_hist).
-- Esperado en las 4: CUERPO IDENTICO (el sufijo sera el pie de recorte, porque ahora hay mas filas).

-- (1) Tema 12 — vw_HistorialEquipoFilasMD vs vw_HistorialEquipoMD
DECLARE @eq nvarchar(50) = N'CA3176';
WITH f AS (SELECT *, COUNT(*) OVER () AS Tot FROM [dbo].[vw_HistorialEquipoFilasMD] WITH (NOLOCK) WHERE Equipo LIKE '%'+@eq+'%'),
sel AS (SELECT TOP (24) * FROM f ORDER BY rn),
nuevo AS (SELECT MAX(TituloMD) + CAST(COUNT(*) AS nvarchar(10)) + MAX(SufijoMD) + NCHAR(10)+NCHAR(10) + MAX(ColsMD) + NCHAR(10) + STRING_AGG(Fila, NCHAR(10)) WITHIN GROUP (ORDER BY rn) AS MD FROM sel),
actual AS (SELECT MD FROM [dbo].[vw_HistorialEquipoMD] WITH (NOLOCK) WHERE Equipo LIKE '%'+@eq+'%')
SELECT 'Tema 12' AS tema, LEN(a.MD) AS len_actual, LEN(n.MD) AS len_nuevo,
       CASE WHEN n.MD = a.MD THEN 'IDENTICO ✅' ELSE 'DIFIERE ❌' END AS veredicto
FROM actual a CROSS JOIN nuevo n;
GO

-- (2) Tema 15 — vw_HistorialFlotaFilasMD vs vw_HistorialFlotaMD
DECLARE @pr nvarchar(50) = N'Antapaccay';
WITH f AS (SELECT *, COUNT(*) OVER () AS Tot FROM [dbo].[vw_HistorialFlotaFilasMD] WITH (NOLOCK) WHERE Proyecto LIKE '%'+@pr+'%'),
sel AS (SELECT TOP (24) * FROM f ORDER BY rn),
nuevo AS (SELECT MAX(TituloMD) + CAST(COUNT(*) AS nvarchar(10)) + MAX(SufijoMD) + NCHAR(10)+NCHAR(10) + MAX(ColsMD) + NCHAR(10) + STRING_AGG(Fila, NCHAR(10)) WITHIN GROUP (ORDER BY rn) AS MD FROM sel),
actual AS (SELECT MD FROM [dbo].[vw_HistorialFlotaMD] WITH (NOLOCK) WHERE Proyecto LIKE '%'+@pr+'%')
SELECT 'Tema 15' AS tema, LEN(a.MD) AS len_actual, LEN(n.MD) AS len_nuevo,
       CASE WHEN n.MD = a.MD THEN 'IDENTICO ✅' ELSE 'DIFIERE ❌' END AS veredicto
FROM actual a CROSS JOIN nuevo n;
GO

-- (3) Tema 14 — vw_HistorialMetalFilasMD vs vw_HistorialMetalMD (metal EN un componente; tope 12)
DECLARE @eq3 nvarchar(50) = N'CA3176', @cp3 nvarchar(50) = N'MT LH', @mt3 nvarchar(20) = N'Fe';
WITH f AS (SELECT *, COUNT(*) OVER () AS Tot FROM [dbo].[vw_HistorialMetalFilasMD] WITH (NOLOCK)
           WHERE Equipo LIKE '%'+@eq3+'%' AND compAbbr LIKE '%'+@cp3+'%' AND Parametro = @mt3),
sel AS (SELECT TOP (12) * FROM f ORDER BY rn),
nuevo AS (SELECT MAX(TituloMD) + CAST(COUNT(*) AS nvarchar(10)) + MAX(SufijoMD) + NCHAR(10)+NCHAR(10) + MAX(ColsMD) + NCHAR(10) + STRING_AGG(Fila, NCHAR(10)) WITHIN GROUP (ORDER BY rn) AS MD FROM sel),
actual AS (SELECT MD FROM [dbo].[vw_HistorialMetalMD] WITH (NOLOCK) WHERE Equipo LIKE '%'+@eq3+'%' AND compAbbr LIKE '%'+@cp3+'%' AND Parametro = @mt3)
SELECT 'Tema 14' AS tema, LEN(a.MD) AS len_actual, LEN(n.MD) AS len_nuevo,
       CASE WHEN n.MD = a.MD THEN 'IDENTICO ✅' ELSE 'DIFIERE ❌' END AS veredicto
FROM actual a CROSS JOIN nuevo n;
GO

-- (4) Tema 13 — vw_HistorialMetalEquipoFilasMD vs vw_HistorialMetalEquipoMD (metal en TODOS los comp.)
DECLARE @eq4 nvarchar(50) = N'CA3176', @mt4 nvarchar(20) = N'Fe';
WITH f AS (SELECT *, COUNT(*) OVER () AS Tot FROM [dbo].[vw_HistorialMetalEquipoFilasMD] WITH (NOLOCK)
           WHERE Equipo LIKE '%'+@eq4+'%' AND Parametro = @mt4),
sel AS (SELECT TOP (24) * FROM f ORDER BY rn),
nuevo AS (SELECT MAX(TituloMD) + CAST(COUNT(*) AS nvarchar(10)) + MAX(SufijoMD) + NCHAR(10)+NCHAR(10) + MAX(ColsMD) + NCHAR(10) + STRING_AGG(Fila, NCHAR(10)) WITHIN GROUP (ORDER BY rn) AS MD FROM sel),
actual AS (SELECT MD FROM [dbo].[vw_HistorialMetalEquipoMD] WITH (NOLOCK) WHERE Equipo LIKE '%'+@eq4+'%' AND Parametro = @mt4)
SELECT 'Tema 13' AS tema, LEN(a.MD) AS len_actual, LEN(n.MD) AS len_nuevo,
       CASE WHEN n.MD = a.MD THEN 'IDENTICO ✅' ELSE 'DIFIERE ❌' END AS veredicto
FROM actual a CROSS JOIN nuevo n;
GO
-- Si alguna DIFIERE: comparar los dos MD con Ctrl+T. Lo mas probable es el ORDEN de los metales de
-- «Met. Obs.» (ahora fijo Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si) o un espacio en TituloMD/SufijoMD.

-- ==== BLOQUE 76 — Localizar la PRIMERA diferencia (Temas 12 y 15 del BLOQUE 75) ====
-- Mismo LEN, distinto contenido => casi seguro es ORDEN, no datos. Esto lo confirma mostrando el
-- primer caracter que difiere y su contexto en ambos lados.
-- (1) Tema 12
DECLARE @eq nvarchar(50) = N'CA3176';
WITH f AS (SELECT * FROM [dbo].[vw_HistorialEquipoFilasMD] WITH (NOLOCK) WHERE Equipo LIKE '%'+@eq+'%'),
sel AS (SELECT TOP (24) * FROM f ORDER BY rn),
nuevo AS (SELECT MAX(TituloMD) + CAST(COUNT(*) AS nvarchar(10)) + MAX(SufijoMD) + NCHAR(10)+NCHAR(10) + MAX(ColsMD) + NCHAR(10) + STRING_AGG(Fila, NCHAR(10)) WITHIN GROUP (ORDER BY rn) AS MD FROM sel),
actual AS (SELECT MD FROM [dbo].[vw_HistorialEquipoMD] WITH (NOLOCK) WHERE Equipo LIKE '%'+@eq+'%'),
nums AS (SELECT TOP (4000) ROW_NUMBER() OVER (ORDER BY (SELECT 1)) AS p FROM sys.all_objects)
SELECT TOP 1 'Tema 12' AS tema, nums.p AS primera_dif,
       SUBSTRING(a.MD, CASE WHEN nums.p > 60 THEN nums.p-60 ELSE 1 END, 120) AS contexto_ACTUAL,
       SUBSTRING(n.MD, CASE WHEN nums.p > 60 THEN nums.p-60 ELSE 1 END, 120) AS contexto_NUEVO
FROM actual a CROSS JOIN nuevo n CROSS JOIN nums
WHERE nums.p <= LEN(a.MD) AND SUBSTRING(a.MD, nums.p, 1) <> SUBSTRING(n.MD, nums.p, 1)
ORDER BY nums.p;
GO
-- (2) Tema 15
DECLARE @pr nvarchar(50) = N'Antapaccay';
WITH f AS (SELECT * FROM [dbo].[vw_HistorialFlotaFilasMD] WITH (NOLOCK) WHERE Proyecto LIKE '%'+@pr+'%'),
sel AS (SELECT TOP (24) * FROM f ORDER BY rn),
nuevo AS (SELECT MAX(TituloMD) + CAST(COUNT(*) AS nvarchar(10)) + MAX(SufijoMD) + NCHAR(10)+NCHAR(10) + MAX(ColsMD) + NCHAR(10) + STRING_AGG(Fila, NCHAR(10)) WITHIN GROUP (ORDER BY rn) AS MD FROM sel),
actual AS (SELECT MD FROM [dbo].[vw_HistorialFlotaMD] WITH (NOLOCK) WHERE Proyecto LIKE '%'+@pr+'%'),
nums AS (SELECT TOP (4000) ROW_NUMBER() OVER (ORDER BY (SELECT 1)) AS p FROM sys.all_objects)
SELECT TOP 1 'Tema 15' AS tema, nums.p AS primera_dif,
       SUBSTRING(a.MD, CASE WHEN nums.p > 60 THEN nums.p-60 ELSE 1 END, 120) AS contexto_ACTUAL,
       SUBSTRING(n.MD, CASE WHEN nums.p > 60 THEN nums.p-60 ELSE 1 END, 120) AS contexto_NUEVO
FROM actual a CROSS JOIN nuevo n CROSS JOIN nums
WHERE nums.p <= LEN(a.MD) AND SUBSTRING(a.MD, nums.p, 1) <> SUBSTRING(n.MD, nums.p, 1)
ORDER BY nums.p;
GO
-- Si el contexto muestra los MISMOS metales en distinto orden (ej. «Si, Fe» vs «Fe, Si») -> es el
-- no-determinismo del STRING_AGG original (sin WITHIN GROUP ORDER BY). La version nueva es la CORRECTA.
-- Si muestra metales DISTINTOS o valores distintos -> es un bug real y hay que pararse a revisarlo.

-- RESULTADO BLOQUE 76 (20/09) — NO era el orden de los metales: era el ORDEN DE LAS FILAS.
--   Tema 12 pos 367: misma fecha 11-Sep-26, ACTUAL sigue con «MT LH» y NUEVO con «RD RH».
--   Tema 15 pos 196: misma fecha 17-Sep-26, ACTUAL «CA3178 Motor» y NUEVO «CA3198 Sist. Hidr.».
--   Causa: ROW_NUMBER() OVER (... ORDER BY FechaMuestreo DESC) SIN desempate -> con varias muestras en la
--   MISMA fecha, el numero asignado depende del plan. 3a aparicion del mismo patron (Met_Obs, obsList, y ahora
--   ROW_NUMBER). Afectaba TAMBIEN a las vistas originales: su salida nunca fue estable.
-- FIX aplicado en las 6 ventanas (vistas nuevas Y originales):
--   PARTITION BY Equipo   ORDER BY FechaMuestreo DESC, Compartimiento, LaboratoryDataId
--   PARTITION BY Proyecto ORDER BY FechaMuestreo DESC, Equipo, Compartimiento, LaboratoryDataId
-- => RE-CORRER EL BLOQUE 75: ahora vieja y nueva usan el MISMO desempate, deben dar IDENTICO las 4.
-- Regla general (ya en la skill): toda ventana ROW_NUMBER/STRING_AGG necesita un ultimo criterio UNICO.


-- ==== BLOQUE 77 - DESCARTADO (21/09) - la regla del rombo NO existe ====
-- RESULTADO: el rombo del dashboard es MANUAL. Esta escrito a mano dentro del DAX del PBI: cuando un
-- equipo es intervenido, se agrega ese camion a la logica. No hay patron que descubrir en los datos,
-- asi que este bloque NO se corre. Se replica en SQL con un CTE 'interv' de VALUES dentro de la vista
-- (BD de solo lectura: no podemos crear tabla). Ver docs/copilot/PENDIENTES.md (P5).
-- Se conserva el query solo como registro de lo que se descarto.
-- ==== BLOQUE 77 (historico) - candidatos de regla del rombo ====
-- Objetivo: el dashboard "Ranking de Atencion" pinta un rombo sobre ALGUNAS barras. Antes de dibujar
-- la grafica ASCII hay que saber QUE lo dispara. NO inventar el criterio.
-- Se listan los equipos de la ultima foto con las horas y 3 candidatos de regla, en el mismo orden
-- (Ranking DESC) de la grafica, para contrastar 1 a 1 contra la captura del PBI.
WITH base AS (
    SELECT z.* FROM (
        SELECT rh.*, ROW_NUMBER() OVER (PARTITION BY rh.[N° Int.] ORDER BY rh.Fecha DESC, rh.[Horas Motor Actual] DESC) AS _rn
        FROM [dbo].[vw_RankingHistorico] rh
    ) z WHERE z._rn = 1
)
SELECT
    ROW_NUMBER() OVER (ORDER BY b.[Ranking] DESC, b.[N° Int.]) AS Pos,
    b.[N° Int.]              AS Equipo,
    b.[Serie],
    b.[Fecha],
    b.[Horas Motor Actual]   AS HMotor,
    b.[Horas Motor Metal]    AS HMetal,
    CAST(b.[Horas Motor Metal] * 1.0 / NULLIF(b.[Horas Motor Actual], 0) AS decimal(5,3)) AS RatioMetalMotor,
    b.[Ranking],
    CASE WHEN b.[Horas Motor Metal] < b.[Horas Motor Actual] THEN N'SI' ELSE N'no' END AS Cand_A_metal_menor,
    CASE WHEN b.[Horas Motor Metal] * 1.0 / NULLIF(b.[Horas Motor Actual], 0) < 0.5 THEN N'SI' ELSE N'no' END AS Cand_B_ratio_bajo,
    CASE WHEN b.[Horas Motor Metal] < 5000 THEN N'SI' ELSE N'no' END AS Cand_C_metal_menor_5000
FROM base b
ORDER BY b.[Ranking] DESC, b.[N° Int.];
-- COMO LEERLO: marcar en la captura del dashboard que equipos llevan rombo y comparar con las 3 columnas
-- Cand_*. La regla correcta es la que coincide EXACTO en los 27. Si ninguna coincide -> preguntar a gerencia
-- que representa el rombo en el PBI (es barato y evita adivinar).

-- ==== BLOQUE 78 — P5 paso 3.b: no-determinismo de Pos en los acumulados (4o caso de la familia) ====
-- vw_AcumuladosFlotaMD numera con ROW_NUMBER() OVER (ORDER BY [Ranking] DESC) SIN desempate.
-- Si hay Ranking empatados, la posicion puede cambiar entre ejecuciones (y la tabla y la grafica
-- podrian contradecirse). Esto DICE si el empate existe hoy.
WITH base AS (
    SELECT z.* FROM (
        SELECT rh.*, ROW_NUMBER() OVER (PARTITION BY rh.[N° Int.] ORDER BY rh.Fecha DESC, rh.[Horas Motor Actual] DESC) AS _rn
        FROM [dbo].[vw_RankingHistorico] rh
    ) z WHERE z._rn = 1
)
SELECT b.[Ranking], COUNT(*) AS Equipos_empatados,
       STRING_AGG(CONVERT(nvarchar(max), b.[N° Int.]), N', ') WITHIN GROUP (ORDER BY b.[N° Int.]) AS Cuales
FROM base b
GROUP BY b.[Ranking]
HAVING COUNT(*) > 1
ORDER BY b.[Ranking] DESC;
-- RESULTADO (21/09): 1 fila -> Ranking 24.15 EMPATADO entre CA3162 y CA3178 (posiciones 10 y 11).
--   El bug NO es teorico: hoy mismo /rankingacum puede devolver esos dos equipos intercambiados entre
--   ejecuciones. 4a aparicion de la familia (Met_Obs, obsList, ROW_NUMBER por fecha, y ahora Pos).
-- FIX: en vw_AcumuladosFlotaMD -> ORDER BY r.[Ranking] DESC, r.[N° Int.]
-- Re-correr este bloque despues del fix NO cambia nada (el empate sigue existiendo); lo que se valida
-- es que dos ejecuciones seguidas de vw_AcumuladosFlotaMD devuelvan el MD identico (EXCEPT = 0 filas).


-- ==== BLOQUE 79 - P5: verificar que los 11 equipos INTERVENIDOS existen tal cual en la data ====
-- La lista es MANUAL (espejo del DAX del PBI). En el DAX van sin prefijo (3196); aqui el Equipo es 'CA3196'.
-- Si un codigo no casa, el rombo simplemente NO se pinta y NADIE se entera -> por eso se verifica.
WITH interv AS (
    SELECT * FROM (VALUES
        (N'CA3161'),(N'CA3165'),(N'CA3166'),(N'CA3168'),(N'CA3175'),(N'CA3180'),
        (N'CA3193'),(N'CA3194'),(N'CA3195'),(N'CA3196'),(N'CA3197')
    ) v(Equipo)
),
base AS (
    SELECT z.* FROM (
        SELECT rh.*, ROW_NUMBER() OVER (PARTITION BY rh.[N° Int.] ORDER BY rh.Fecha DESC, rh.[Horas Motor Actual] DESC) AS _rn
        FROM [dbo].[vw_RankingHistorico] rh
    ) z WHERE z._rn = 1
)
SELECT i.Equipo,
       CASE WHEN b.[N° Int.] IS NULL THEN N'NO EXISTE en la ultima foto' ELSE N'ok' END AS Estado,
       b.[Ranking]
FROM interv i
LEFT JOIN base b ON b.[N° Int.] = i.Equipo
ORDER BY Estado DESC, i.Equipo;
-- Esperado: 11 filas, TODAS 'ok'. Cualquier 'NO EXISTE' = codigo mal copiado o equipo fuera de la flota.
-- RESULTADO (21/09): 11 filas, TODAS 'ok'. La lista del DAX casa 1:1 con la data. Rankings de los
--   intervenidos: CA3161 12.22 - CA3165 3.59 - CA3166 20.12 - CA3168 15.43 - CA3175 11.54 - CA3180 16.44
--   CA3193 11.88 - CA3194 6.97 - CA3195 7.42 - CA3196 23.83 - CA3197 8.97 (ninguno en zona de alerta).

-- ==== BLOQUE 80 - P5: determinismo de vw_AcumuladosFlotaMD (correr DESPUES del fix del desempate) ====
-- El empate 24.15 (CA3162 / CA3178) hace que el orden pueda cambiar entre ejecuciones. Tras aplicar
-- ORDER BY r.[Ranking] DESC, r.[N° Int.], dos lecturas seguidas deben dar EXACTAMENTE el mismo MD.
DECLARE @a nvarchar(max) = (SELECT TOP 1 MD FROM [dbo].[vw_AcumuladosFlotaMD] WHERE Proyecto LIKE N'%Antapaccay%');
DECLARE @b nvarchar(max) = (SELECT TOP 1 MD FROM [dbo].[vw_AcumuladosFlotaMD] WHERE Proyecto LIKE N'%Antapaccay%');
SELECT CASE WHEN HASHBYTES('SHA2_256', @a) = HASHBYTES('SHA2_256', @b) THEN N'IDENTICO (ok)' ELSE N'DIFIERE (bug vivo)' END AS Determinismo,
       LEN(@a) AS Largo,
       CHARINDEX(N'CA3162', @a) AS PosCA3162,
       CHARINDEX(N'CA3178', @a) AS PosCA3178;
-- Esperado tras el fix: IDENTICO, y CA3162 SIEMPRE antes que CA3178 (desempate alfabetico del empate 24.15).
-- RESULTADO (21/09): IDENTICO (ok). Largo 3407. PosCA3162 = 1460 < PosCA3178 = 1570 -> el desempate manda
--   y el orden del empate 24.15 quedo estable. Bug cerrado.


-- ==== BLOQUE 81 - P5: probar vw_RankingGrafMD (alineacion, marcas, rombos, tamano) ====
-- (1) La grafica completa tal como la vera el usuario. Copiar el MD a un editor MONOESPACIADO:
--     las 3 marcas | deben quedar en columna bajo las etiquetas 60 / 65 / 70.
SELECT MD FROM [dbo].[vw_RankingGrafMD] WHERE Proyecto LIKE N'%Antapaccay%';

-- (2) Tamano y conteos. NInterv debe ser 11 y N los equipos de la flota.
SELECT LEN(MD) AS Largo_MD,
       LEN(MD) - LEN(REPLACE(MD, NCHAR(10), N'')) + 1 AS Lineas,
       LEN(MD) - LEN(REPLACE(MD, N'◆', N'')) AS Rombos
FROM [dbo].[vw_RankingGrafMD] WHERE Proyecto LIKE N'%Antapaccay%';
-- Esperado: Rombos = 12 = 11 filas + 1 del subtitulo (la leyenda lleva su propio ◆). Largo_MD muy por
-- debajo de 28000 (limite del mensaje de Teams).
-- RESULTADO (21/09): Largo_MD 2480, Lineas 34 (27 equipos + titulo + subtitulo + blanco + 2 de cabecera
--   del eje + 2 del fence), Rombos 12. Todo correcto.
-- (3) RESULTADO: FilasHistorico 2212, Largo_Tabla 3407, Largo_Grafica 2480 -> la grafica pesa MENOS que la
--   tabla: ~9% del techo del canal. Hay margen de sobra si mas adelante se agregan columnas.
-- (4) RESULTADO: IDENTICO (ok).
-- NOTA: el 'Warning: Null value is eliminated by an aggregate' viene de los acumulados de
--   vw_RankingHistorico, no de estas vistas. No descarta filas: el subtitulo reporta 27 equipos y la tabla
--   /rankingacum tambien lista 27.

-- (3) Que la grafica y la tabla hablen de lo MISMO: mismo equipo en la posicion 1 y mismo conteo.
SELECT (SELECT COUNT(*) FROM [dbo].[vw_RankingHistorico]) AS FilasHistorico,
       (SELECT LEN(MD) FROM [dbo].[vw_AcumuladosFlotaMD] WHERE Proyecto LIKE N'%Antapaccay%') AS Largo_Tabla,
       (SELECT LEN(MD) FROM [dbo].[vw_RankingGrafMD]     WHERE Proyecto LIKE N'%Antapaccay%') AS Largo_Grafica;

-- (4) Determinismo de la grafica: dos lecturas seguidas deben ser identicas.
DECLARE @g1 nvarchar(max) = (SELECT TOP 1 MD FROM [dbo].[vw_RankingGrafMD] WHERE Proyecto LIKE N'%Antapaccay%');
DECLARE @g2 nvarchar(max) = (SELECT TOP 1 MD FROM [dbo].[vw_RankingGrafMD] WHERE Proyecto LIKE N'%Antapaccay%');
SELECT CASE WHEN HASHBYTES('SHA2_256', @g1) = HASHBYTES('SHA2_256', @g2) THEN N'IDENTICO (ok)' ELSE N'DIFIERE' END AS Determinismo;


-- ==== BLOQUE 82 - P5 ajuste post-Teams (22/09): rotulos de columna + estado abreviado ====
-- Feedback del render real en Teams: las cifras de H.Metal y de estado salian SIN rotulo (el estado era
-- solo el circulo de color). Cambios en vw_RankingGrafMD:
--   (a) los titulos de columna viajan en la MISMA linea de los ticks (no chocan: Equipo 1-6, ticks 43/46/49,
--       Rank 56-59, H.Metal 62-68, Estado 72-77);
--   (b) cada fila lleva la abreviatura del estado (Mon./Ate./Ale./Cri.) ANTES del chip -> ancho fijo 4, no
--       descuadra, y el emoji queda al final donde su ancho variable no afecta a nada;
--   (c) el subtitulo explica las abreviaturas y las dos columnas de horas;
--   (d) 22/09 (2a pasada): se agrega H.Motor junto a H.Metal -- el grafico solo traia H.Metal y las dos
--       hacen falta para leer el desgaste (H.Metal << H.Motor = metal cambiado hace poco).
-- La fila pasa de 71 a 83 caracteres. Re-desplegar la vista y re-correr el BLOQUE 81.
SELECT MD FROM [dbo].[vw_RankingGrafMD] WHERE Proyecto LIKE N'%Antapaccay%';
-- Esperado (copiar a un editor MONOESPACIADO):
--                                          60 65 70
-- Equipo                                    v  v  v      Rank  H.Motor H.Metal Estado
-- CA3177 [barra]                             |  |     62.19    11592   11592 Ate. [chip]
-- CA3171 [barra]                          |  |  |     50.50    16309    9236 Mon. [chip]
-- CA3196 [barra]                          |  |  |     23.83 <> 16731    1960 Mon. [chip]
-- Verificar: 'Rank' termina donde terminan las cifras, cada H.* sobre su columna, 'Estado' sobre Mon./Ate.
SELECT LEN(MD) AS Largo_MD FROM [dbo].[vw_RankingGrafMD] WHERE Proyecto LIKE N'%Antapaccay%';
-- Esperado: ~2900 (subio desde 2480 por rotulos, abreviaturas y la columna H.Motor). Lejos de 28000.
-- RESULTADO (22/09): Largo_MD 2878, Lineas 34, Rombos 12, determinismo IDENTICO. Grafica 2878 vs tabla 3407
--   -> la grafica sigue pesando menos. Render confirmado en Teams: rotulos sobre su columna, las 3 marcas
--   alineadas, H.Motor y H.Metal legibles. P5 CERRADO.


-- ==== BLOQUE 83 - P3 paso 1: hasta donde se puede abrir /incipiente (proyectos y componentes) ====
-- Hallazgo de la auditoria: vw_TendenciaIncipienteMD NO esta atada a Antapaccay (agrupa por Proyecto).
-- La unica restriccion real es el WHERE Compartimiento LIKE '%TRACCION%'. Antes de abrirla hay que saber
-- que combinaciones proyecto x componente tienen MATERIA PRIMA: >=3 muestras por equipo y LP definido.
-- (1) Universo evaluable: cuantos equipos por proyecto y tipo de componente llegan a 3+ muestras con LP.
WITH s AS (
    SELECT Proyecto, CompTipo, Compartimiento, Equipo, rn_recencia, Fe_LP
    FROM [dbo].[vw_MuestrasRankeadas] WITH (NOLOCK)
    WHERE EsDDI = 0 AND rn_recencia <= 7
)
SELECT s.Proyecto, s.CompTipo,
       COUNT(DISTINCT s.Equipo + N'|' + s.Compartimiento) AS Equipos_comp,
       SUM(CASE WHEN s.rn_recencia = 1 AND s.Fe_LP IS NOT NULL THEN 1 ELSE 0 END) AS Con_LP_Fe,
       COUNT(*) AS Muestras
FROM s
GROUP BY s.Proyecto, s.CompTipo
HAVING COUNT(DISTINCT s.Equipo + N'|' + s.Compartimiento) >= 3
ORDER BY s.Proyecto, Equipos_comp DESC;
-- COMO LEERLO: 'Con_LP_Fe' = 0 significa que ese componente NO tiene limites cargados -> la regla
-- 'ult >= 0.5*LP' nunca dispara y el modulo devolveria siempre 0. Esos NO se abren (se dice por que).

-- (2) La misma regla de incipiente, pero SIN el filtro de traccion: cuantos saldrian por proyecto+componente.
-- Es la simulacion de "abrir el modulo" antes de tocar la vista.
WITH s AS (
    SELECT Proyecto, Equipo, Compartimiento, CompTipo, rn_recencia,
           p.metal, CAST(p.Valor AS decimal(18,2)) AS Valor, CAST(p.LP AS decimal(18,2)) AS LP
    FROM [dbo].[vw_MuestrasRankeadas] WITH (NOLOCK)
    CROSS APPLY (VALUES
        (N'Fe',Fe_ppm,Fe_LP),(N'PQ',Indice_PQ,PQ_LP),(N'Cr',Cr_ppm,Cr_LP),(N'Ni',Ni_ppm,Ni_LP),
        (N'Cu',Cu_ppm,Cu_LP),(N'Pb',Pb_ppm,Pb_LP),(N'Sn',Sn_ppm,Sn_LP),(N'Al',Al_ppm,Al_LP),(N'Si',Si_ppm,Si_LP)
    ) p(metal, Valor, LP)
    WHERE EsDDI = 0 AND rn_recencia <= 7
),
agg AS (
    SELECT Proyecto, Equipo, Compartimiento, CompTipo, metal,
        MAX(CASE WHEN rn_recencia = 1 THEN Valor END) AS ult,
        MAX(CASE WHEN rn_recencia = 1 THEN LP END)    AS LP,
        AVG(CASE WHEN rn_recencia BETWEEN 2 AND 7 THEN Valor END) AS prom_prev,
        SUM(CASE WHEN rn_recencia BETWEEN 2 AND 7 AND Valor IS NOT NULL THEN 1 ELSE 0 END) AS n_prev
    FROM s GROUP BY Proyecto, Equipo, Compartimiento, CompTipo, metal
)
SELECT Proyecto, CompTipo,
       COUNT(DISTINCT Equipo + N'|' + Compartimiento) AS Equipos_incipientes,
       COUNT(*) AS Metales_disparados
FROM agg
WHERE n_prev >= 2 AND ult > 0 AND prom_prev > 0 AND LP IS NOT NULL
  AND ult <= LP AND ult >= 0.5 * LP AND ult >= prom_prev * 1.4
GROUP BY Proyecto, CompTipo
ORDER BY Equipos_incipientes DESC;
-- COMO LEERLO: esto dice si abrir el modulo APORTA. Si un componente sale con cientos de equipos, la regla
-- del 40% es demasiado laxa PARA ESE componente y habria que calibrarla antes de exponerlo.
--
-- RESULTADOS (22/09) -------------------------------------------------------------------------------
-- (1) LIMITES CARGADOS (Con_LP_Fe / Equipos_comp):
--     Antamina    TRACCION 132/388 - RUEDA 128/129 - HIDRAULICO 66/158 - MOTOR 66/158
--     Antapaccay  RUEDA 54/72 - TRACCION 54/72 - HIDRAULICO 36/48 - MOTOR 36/48 - MANDO 18/26
--                 TRANSMISION 5/8 - OTRO 0/25
--     Cerro Verde TRACCION 16/128 - RUEDA 16/20 - HIDRAULICO 8/64 - MOTOR 8/64
--     Toromocho   TRACCION 20/20 - RUEDA 18/18 - MOTOR 10/12 - HIDRAULICO 10/10 - OTRO 0/3
--     Cuajone     0 en TODOS      |  Toquepala   0 en TODOS
--   => Cuajone y Toquepala NO tienen limites cargados: el modulo SIEMPRE devolveria 0 para ellos.
--      Cerro Verde solo tiene limites en el 12% de su flota de traccion (16 de 128).
--   => El denominador del titulo ("X de N MT") cuenta equipos SIN limites, que nunca pudieron dispararse.
--      Hay que separar universo EVALUABLE de universo total (ver P3 paso 3.b).
-- (2) INCIPIENTES SIMULADOS (equipos por proyecto x componente):
--     Antamina    TRACCION 52 - RUEDA 44 - MOTOR 40 - HIDRAULICO 13
--     Antapaccay  HIDRAULICO 13 - MOTOR 13 - TRACCION 11 - RUEDA 10 - TRANSMISION 1 - MANDO 1
--     Toromocho   MOTOR 8 - TRACCION 7 - RUEDA 4 - HIDRAULICO 1
--     Cerro Verde RUEDA 7 - MOTOR 4 - HIDRAULICO 2 - TRACCION 1
--     Cuajone / Toquepala: ninguno (coherente con (1), no con que esten sanos)
--   => Volumen manejable salvo Antamina TRACCION (52 filas en un mensaje). Ver P3 paso 3.c (tope + pie).


-- ==== BLOQUE 84 - P3 paso 1.b: calibrar la regla POR METAL (el 0.5*LP se rompe con metales de LP chico) ====
-- Sintoma visto en /incipiente Antamina: filas disparadas por 'Ni 0.1 -> 0.7 (+483%)' o 'Cr 0.5 -> 0.7 (+56%)'.
-- Con LP(Ni)=1.0 y LP(Cr)=1.0, la mitad del limite es 0.5 ppm, que es el suelo de resolucion del laboratorio:
-- cualquier lectura de traza pasa el filtro y el % explota. El mismo umbral que funciona para Fe (LP 233)
-- produce ruido para los metales de traza. Esto mide cuanto pesa cada metal y con que magnitudes REALES.
WITH s AS (
    SELECT Proyecto, Equipo, Compartimiento, CompTipo, rn_recencia,
           p.metal, CAST(p.Valor AS decimal(18,2)) AS Valor, CAST(p.LP AS decimal(18,2)) AS LP
    FROM [dbo].[vw_MuestrasRankeadas] WITH (NOLOCK)
    CROSS APPLY (VALUES
        (N'Fe',Fe_ppm,Fe_LP),(N'PQ',Indice_PQ,PQ_LP),(N'Cr',Cr_ppm,Cr_LP),(N'Ni',Ni_ppm,Ni_LP),
        (N'Cu',Cu_ppm,Cu_LP),(N'Pb',Pb_ppm,Pb_LP),(N'Sn',Sn_ppm,Sn_LP),(N'Al',Al_ppm,Al_LP),(N'Si',Si_ppm,Si_LP)
    ) p(metal, Valor, LP)
    WHERE EsDDI = 0 AND rn_recencia <= 7
),
agg AS (
    SELECT Proyecto, Equipo, Compartimiento, CompTipo, metal,
        MAX(CASE WHEN rn_recencia = 1 THEN Valor END) AS ult,
        MAX(CASE WHEN rn_recencia = 1 THEN LP END)    AS LP,
        AVG(CASE WHEN rn_recencia BETWEEN 2 AND 7 THEN Valor END) AS prom_prev,
        SUM(CASE WHEN rn_recencia BETWEEN 2 AND 7 AND Valor IS NOT NULL THEN 1 ELSE 0 END) AS n_prev
    FROM s GROUP BY Proyecto, Equipo, Compartimiento, CompTipo, metal
),
disp AS (
    SELECT *, ult - prom_prev AS salto
    FROM agg
    WHERE n_prev >= 2 AND ult > 0 AND prom_prev > 0 AND LP IS NOT NULL
      AND ult <= LP AND ult >= 0.5 * LP AND ult >= prom_prev * 1.4
)
SELECT metal,
       COUNT(*)                                        AS Veces,
       MIN(LP)                                         AS LP_min,
       MAX(LP)                                         AS LP_max,
       CAST(AVG(salto) AS decimal(18,2))               AS Salto_prom_ppm,
       CAST(MIN(salto) AS decimal(18,2))               AS Salto_min_ppm,
       CAST(AVG(salto / NULLIF(LP,0)) AS decimal(6,3)) AS Salto_como_fraccion_del_LP,
       SUM(CASE WHEN salto < 1.0 THEN 1 ELSE 0 END)    AS Saltos_menores_a_1ppm
FROM disp
GROUP BY metal
ORDER BY Veces DESC;
-- COMO LEERLO: la columna clave es 'Saltos_menores_a_1ppm'. Un metal cuyas alertas son casi todas saltos
-- de menos de 1 ppm NO esta midiendo desgaste, esta midiendo ruido del laboratorio.
-- Opciones de calibracion a decidir CON el tecnico (no inventarlas aqui):
--   (a) exigir un salto minimo absoluto por metal (ej. >= 2 ppm para metales de LP <= 5);
--   (b) exigir que el promedio previo tampoco sea traza (prom_prev >= 0.25 * LP);
--   (c) excluir del modulo los metales de traza (Ni, Cr, Sn) y dejarlo en Fe / PQ / Si / Cu / Pb / Al.
--
-- RESULTADO (22/09) -- metal / Veces / LP_min-LP_max / Salto_prom / Salto/LP / Saltos <1ppm:
--   Si 73  5.0-40.0   8.25  0.305    0/73     Fe 34  6.0-233.0  32.44  0.310    0/34
--   Al 69  1.5-10.0   0.88  0.352   50/69     Cu 32  1.0-19.0    1.23  0.387   18/32
--   Cr 54  0.2- 2.0   0.31  0.437   53/54     PQ 24  3.0-166.0  25.89  0.344    3/24
--   Ni 15  1.0- 2.0   0.42  0.379   14/15     Pb 12  2.0-  3.0   1.03  0.422    6/12
--   Sn  3  3.0- 3.0   1.76  0.587    0/3
--   TOTAL 316 disparos, de los cuales 144 (46%) son saltos menores a 1 ppm.
-- LECTURA: 'Salto_como_fraccion_del_LP' es casi igual en TODOS los metales (0.30-0.59) -> una regla
--   relativa al LP NO discrimina. El que separa senal de ruido es el SALTO ABSOLUTO: Cr (53/54), Ni (14/15)
--   y Al (50/69) disparan casi siempre con saltos sub-ppm, mientras Fe, Si y Sn no lo hacen NUNCA.
-- DECISION: se adopta un PISO UNICO de 1 ppm -- 'AND (ult - prom_prev) >= 1.0'. Una sola linea, sin
--   listas de metales ni umbrales por metal (nada que se desactualice). Efecto medido sobre los 316:
--   elimina 144 (46%) de ruido, conserva el 100% de Fe / Si / Sn, 21 de 24 PQ. Y es explicable a gerencia:
--   'una variacion menor a 1 ppm es el suelo de resolucion del laboratorio, no desgaste'.


-- ==== BLOQUE 85 - P3: vw_TendenciaIncipienteMD generalizada (correr DESPUES de re-desplegarla) ====
-- Cambios: filtro por CompTipo (cualquier componente) + piso de 1 ppm + denominador honesto
-- (evaluables vs sin limites) + tope de 25 filas con pie + tildes.
-- (1) NO-REGRESION del caso de hoy. Debe seguir saliendo el mismo universo de MT de Antapaccay,
--     pero SIN las filas de ruido (Cr/Ni/Al con saltos sub-ppm) y con el denominador corregido.
SELECT MD FROM [dbo].[vw_TendenciaIncipienteMD]
WHERE Proyecto LIKE N'%Antapaccay%' AND CompTipo COLLATE Latin1_General_CI_AI LIKE N'%traccion%';

-- (2) El caso que motivo el tope: Antamina traccion (eran 52 filas).
SELECT MD FROM [dbo].[vw_TendenciaIncipienteMD]
WHERE Proyecto LIKE N'%Antamina%' AND CompTipo COLLATE Latin1_General_CI_AI LIKE N'%traccion%';
-- Esperado: <=25 filas + pie '_Mostrando 25 de N, los de mayor variacion._', y el titulo diciendo
-- 'de 132 evaluados' (NO 388) + la linea '256 sin limites cargados: no evaluados.'

-- (3) El caso honesto: un proyecto SIN limites cargados.
SELECT MD FROM [dbo].[vw_TendenciaIncipienteMD]
WHERE Proyecto LIKE N'%Cuajone%' AND CompTipo COLLATE Latin1_General_CI_AI LIKE N'%traccion%';
-- Esperado: 'sin limites cargados' + el aviso de que NO significa que esten sanos.
-- (mismo chequeo para Toquepala)

-- (4) Componentes nuevos.
SELECT MD FROM [dbo].[vw_TendenciaIncipienteMD]
WHERE Proyecto LIKE N'%Antapaccay%' AND CompTipo COLLATE Latin1_General_CI_AI LIKE N'%hidraulico%';

-- (5) Panorama: cuantas filas queda por proyecto x componente, y cuanto pesa cada MD.
SELECT Proyecto, CompTipo, LEN(MD) AS Largo_MD,
       LEN(MD) - LEN(REPLACE(MD, NCHAR(10), N'')) + 1 AS Lineas
FROM [dbo].[vw_TendenciaIncipienteMD]
ORDER BY Largo_MD DESC;
-- Esperado: ningun MD cerca de 28000. Si alguno se dispara, bajar el tope de 25.

-- (6) RENDIMIENTO: la vista ahora recorre TODOS los componentes, no solo traccion (~4x filas).
--     Medir forzando la proyeccion (COUNT(*) no sirve: elimina las columnas calculadas).
SET STATISTICS IO ON; SET STATISTICS TIME ON;
SELECT MAX(LEN(MD)) FROM [dbo].[vw_TendenciaIncipienteMD];
SET STATISTICS IO OFF; SET STATISTICS TIME OFF;
-- Referencia: la version anterior (solo traccion) respondia rapido. Si esto se va a decenas de segundos,
-- revisar 'scan count' de LaboratoryData antes de tocar nada mas.
--
-- RESULTADOS (22/09):
--   (1) Antapaccay TRACCION: 6 de 54 evaluados, 18 sin limites. Sin ruido sub-ppm. OK.
--   (2) Antamina TRACCION: 45 de 132 evaluados (eran 52: el piso de 1 ppm quito 7), 256 sin limites,
--       'Mostrando 25 de 45, los de mayor variacion.' Titulo correcto. OK.
--   (3) Cuajone: 'sin limites cargados' + el aviso. OK.
--   (4) Antapaccay HIDRAULICO: 9 de 36 evaluados, 12 sin limites. OK.
--   (5) Panorama: 32 combinaciones, Largo_MD maximo 2174 (Antamina TRACCION). Nadie cerca de 28000. OK.
--   (6) RENDIMIENTO: MALO -> elapsed 172539 ms (2:52), CPU 36563 ms, LaboratoryData 66 scans / 90024 lecturas,
--       Workfile 163 scans / 1592 physical reads. Diagnostico: ANTI-PATRON Nº1. El CTE 's' estaba referenciado
--       3 veces (agg, univ, lims) y ademas 'lims' lo filtraba con un EXISTS CORRELACIONADO contra 'inc',
--       que re-ejecuta agg -> s por cada fila. Al pasar de solo-TRACCION a todos los componentes, ese coste
--       se multiplico. FIX en el DDL (ver BLOQUE 86): 'lims' sale de 'inc' (ya trae LP/LC) y 'univ' sale de
--       'agg' -> la fundacion se expande una sola vez.


-- ==== BLOQUE 86 - P3: fix de rendimiento de vw_TendenciaIncipienteMD (medir ANTES / DESPUES) ====
-- (1) ANTES de re-desplegar: guardar la salida actual para comparar. Sin esto no hay como probar que el
--     fix no cambio nada. (Las tablas # viven en tempdb; no requieren permisos sobre la BD.)
IF OBJECT_ID('tempdb..#inc_antes') IS NOT NULL DROP TABLE #inc_antes;
SELECT Proyecto, CompTipo, MD, HASHBYTES('SHA2_256', MD) AS h
INTO #inc_antes
FROM [dbo].[vw_TendenciaIncipienteMD];
SELECT COUNT(*) AS Filas_guardadas FROM #inc_antes;   -- esperado: 32

-- (2) AHORA re-desplegar vw_TendenciaIncipienteMD desde DDL_vistas.sql (version con el fix) y seguir aqui.

-- (3) EQUIVALENCIA: el fix es de rendimiento, la salida debe ser IDENTICA.
SELECT COUNT(*) AS Difieren
FROM #inc_antes a
FULL JOIN [dbo].[vw_TendenciaIncipienteMD] n
       ON n.Proyecto = a.Proyecto AND n.CompTipo = a.CompTipo
WHERE a.Proyecto IS NULL OR n.Proyecto IS NULL
   OR HASHBYTES('SHA2_256', n.MD) <> a.h;
-- Esperado: 0. Cualquier otra cosa = el fix cambio la salida -> revisar antes de seguir.

-- (4) RENDIMIENTO del camino REAL de produccion: el flujo SIEMPRE filtra por proyecto + componente.
--     Este es el numero que importa, no el de la vista entera.
SET STATISTICS IO ON; SET STATISTICS TIME ON;
SELECT MAX(LEN(MD)) FROM [dbo].[vw_TendenciaIncipienteMD]
WHERE Proyecto LIKE N'%Antamina%' AND CompTipo COLLATE Latin1_General_CI_AI LIKE N'%traccion%';
SET STATISTICS IO OFF; SET STATISTICS TIME OFF;
-- Mirar 'scan count' de [Oil].[LaboratoryData]. Objetivo: que baje claramente de los 66 scans / 90024
-- lecturas medidos antes. Si el filtrado ya respondia rapido, igual sirve como linea base.

-- (5) RENDIMIENTO de la vista entera (las 32 combinaciones) - comparable contra los 172539 ms de antes.
SET STATISTICS IO ON; SET STATISTICS TIME ON;
SELECT MAX(LEN(MD)) FROM [dbo].[vw_TendenciaIncipienteMD];
SET STATISTICS IO OFF; SET STATISTICS TIME OFF;
-- Si sigue en minutos, NO seguir tocando a ciegas: partir la vista por mitades y cronometrar cada una
-- (metodo que funciono con el barrido), en vez de acumular hipotesis.
--
-- RESULTADOS (22/09) -- el fix funciono:
--   (1) 32 filas guardadas.  (3) Difieren = 0 -> salida IDENTICA, el fix es solo de rendimiento.
--   (4) Camino real (Antamina + traccion): 8 023 ms, CPU 1 844 ms, LaboratoryData 3 scans / 4 092 lecturas.
--   (5) Vista entera: 11 657 ms (antes 172 539 ms) -> ~15x mas rapida. LaboratoryData 66 scans -> 3,
--       90 024 lecturas -> 4 092 (22x menos). Confirmado: el cuello era el EXISTS correlacionado.


-- ==== BLOQUE 87 - P2: validar que Sigma-vida es lo que decimos que es ====
-- QUE DICE EL DDL HOY (vw_TendenciaMD, CTE 'acc'): Acumulado = SUM(ppm del metal) sobre TODAS las muestras
-- no-DDI de ese Equipo+Compartimiento, agrupado por Equipo+Compartimiento. Es decir: la suma del metal a lo
-- largo de toda la historia registrada del componente. Coincide con la definicion acordada
-- ("vida del metal DENTRO del componente"), pero hay 3 cosas que hay que comprobar con datos, no de memoria.

-- (1) Que marca un cambio: inventario de valores de CM y cuantas muestras tiene cada uno.
SELECT CM, COUNT(*) AS Muestras, MIN(FechaMuestreo) AS Desde, MAX(FechaMuestreo) AS Hasta
FROM [dbo].[vw_MuestrasRankeadas] WITH (NOLOCK)
GROUP BY CM ORDER BY Muestras DESC;
-- Sirve para saber si existe alguna marca de CAMBIO DE COMPONENTE (no de aceite). Si no la hay, Sigma-vida
-- no puede resetear y eso hay que DECIRLO en la salida, no dejarlo implicito.

-- (2) La historia completa de un caso concreto, con la suma corriendo al lado.
--     Asi se ve exactamente que esta sumando Sigma-vida y si hay un salto que delate un componente nuevo.
SELECT FechaMuestreo, CM, Grado, HorasDeAceite, Horometro, Fe_ppm,
       SUM(Fe_ppm) OVER (ORDER BY FechaMuestreo, LaboratoryDataId ROWS UNBOUNDED PRECEDING) AS Fe_acumulado_corrido
FROM [dbo].[vw_MuestrasRankeadas] WITH (NOLOCK)
WHERE Equipo = 'CA3176' AND Compartimiento LIKE '%TRACCION%LH' AND EsDDI = 0
ORDER BY FechaMuestreo, LaboratoryDataId;
-- Mirar: (a) cuantos anios abarca; (b) si el Horometro se reinicia en algun punto (=equipo/componente nuevo);
-- (c) si el ultimo valor de la columna corrida coincide con el Sigma-vida que muestra /tendenciadet.

-- (3) El contraste directo: lo que dice la vista vs la suma cruda.
SELECT te.Equipo, te.Parametro, te.Acumulado AS Sigma_vida_vista, x.SumaCruda, x.NMuestras
FROM [dbo].[vw_TendenciaElemento] te
CROSS APPLY (
    SELECT CAST(SUM(m.Fe_ppm) AS decimal(18,1)) AS SumaCruda, COUNT(m.Fe_ppm) AS NMuestras
    FROM [dbo].[vw_MuestrasRankeadas] m WITH (NOLOCK)
    WHERE m.Equipo = te.Equipo AND m.Compartimiento LIKE '%TRACCION%LH' AND m.EsDDI = 0
) x
WHERE te.Equipo = 'CA3176' AND te.Parametro = 'Fe';
-- Esperado: Sigma_vida_vista = SumaCruda. Si difieren, el DDL no computa lo que documentamos.

-- (4) RIESGO: 'acc' agrupa por Equipo+Compartimiento SIN Proyecto. Si un mismo codigo de equipo existiera
--     en dos proyectos, sus muestras se sumarian juntas y Sigma-vida quedaria inflado.
SELECT Equipo, COUNT(DISTINCT Proyecto) AS Proyectos, STRING_AGG(CONVERT(nvarchar(max), Proyecto), N', ') WITHIN GROUP (ORDER BY Proyecto) AS Cuales
FROM (SELECT DISTINCT Equipo, Proyecto FROM [dbo].[vw_MuestrasRankeadas] WITH (NOLOCK)) z
GROUP BY Equipo
HAVING COUNT(DISTINCT Proyecto) > 1
ORDER BY Proyectos DESC, Equipo;
-- Esperado: 0 filas. Si sale alguno, hay que agregar Proyecto al GROUP BY de 'acc' (y a su JOIN).

-- (5) Cuanta historia esta resumiendo Sigma-vida, por componente. Un numero que suma 40 muestras de 6 anios
--     no significa lo mismo que uno que suma 5: la salida deberia decir sobre cuantas muestras va.
SELECT TOP 20 Equipo, Compartimiento, COUNT(*) AS NMuestras,
       MIN(FechaMuestreo) AS Desde, MAX(FechaMuestreo) AS Hasta,
       DATEDIFF(month, MIN(FechaMuestreo), MAX(FechaMuestreo)) AS Meses
FROM [dbo].[vw_MuestrasRankeadas] WITH (NOLOCK)
WHERE EsDDI = 0
GROUP BY Equipo, Compartimiento
ORDER BY COUNT(*) DESC;
-- La vista ya calcula NmAcum (nº de muestras del acumulado) pero NO lo muestra. Candidato de fix barato:
-- exponerlo junto a Sigma-vida para que el numero sea interpretable.


-- RESULTADOS BLOQUE 87 (22/09) -- P2 / Sigma-vida ---------------------------------------------------
-- (1) CM tiene 27 valores distintos y NINGUNO sirve como marca de cambio de componente: NULL 16944,
--     M 4111, N 3314, Y 2004, C 1033, MUESTREO 1001, MONI 936, ADI 921, PM1..PM50, NO, SI, CAMBIO 73,
--     PrePM, RELLENO 10, nan 4, CONDICION 4, DIALIZADO 2. Son sobre todo codigos de mantenimiento.
--     => Sigma-vida NO PUEDE resetear por componente: no hay dato que lo permita. Hay que DECIRLO.
--     ⚠ HALLAZGO COLATERAL: EsDDI se calcula con CM IN ('DDI','DIALIZADO','RELLENO+DIALIZADO'), pero en
--       los datos solo existe 'DIALIZADO' (2 muestras). 'DDI' y 'RELLENO+DIALIZADO' NO aparecen, y si
--       aparece 'ADI' con 921. El filtro anti-DDI esta descartando 2 muestras de 33 000. Revisar si
--       'ADI' deberia entrar (es otro termino del glosario, NO asumir que es un typo de DDI).
--     ⚠ Todo el historico va de 2025-09-24 a 2026-09-21: la BD tiene ~12 meses, no anios.
-- (2) CA3176 MT LH: 26 muestras, Horometro 29 693 -> 36 449 SIEMPRE creciente (ningun reinicio = ningun
--     componente nuevo en la ventana). Cambio de Grado (M-SHC GEAR 680 -> SHELL OMALA S4 GXV 680) el
--     2025-11-01: es cambio de ACEITE, no de componente. Suma corrida final de Fe = 3 207.03.
-- (3) Sigma_vida_vista mostro 6 valores (255.9 / 3207.0 / 2810.4 / 243.8 / 493.9 / 67.8) contra una
--     SumaCruda unica de 3207.0. NO es un bug: mi consulta no filtro el compartimiento del lado de
--     vw_TendenciaElemento, asi que devolvio los 6 componentes del equipo. El que corresponde a MT LH
--     es 3207.0 y COINCIDE EXACTO con la suma cruda de 26 muestras. DEFINICION CONFIRMADA.
--     (test corregido abajo, con el filtro que faltaba)
-- (4) Colision de codigos entre proyectos: 0 filas. No hay riesgo hoy; igual se agrego Proyecto al
--     GROUP BY de 'acc' porque agrupar identidades sin su clave completa es fragil.
-- (5) Volumen del acumulado: hasta 110 muestras en 12 meses (CA3165 MOTOR). Un numero que suma 110
--     muestras no se lee igual que uno que suma 5 -> por eso Sigma-vida ahora muestra el nº entre parentesis.

-- ==== BLOQUE 88 - P1 (NO correr todavia): los 3 arreglos de Sigma-vida, para cuando se toque tendencia ====
-- ESTADO (22/09): los cambios de DDL que verificaba este bloque fueron REVERTIDOS a pedido del usuario.
-- Razon: viven en las vistas de tendencia (vw_TendenciaMD / vw_TendenciaElemento / vw_TendenciaMetalMD),
-- que son las que P1 va a reescribir al fusionar /tendencia con /tendenciadet. Tocarlas ahora solo
-- generaria conflicto. P2 queda CERRADO como validacion: Sigma-vida computa lo que debe (3207.0 = 3207.0
-- sobre 26 muestras en CA3176 MT LH). Los 3 arreglos quedan ANOTADOS para aplicarse DENTRO de P1:
--   (a) mostrar el nº de muestras junto a Sigma-vida  -> '3207.0 (26)' + encabezado 'Σvida (nº m.)'.
--       NmAcum ya existe en vw_TendenciaElemento; OJO: vw_TendenciaMetalMD lee de un CTE con lista
--       EXPLICITA de columnas y hay que agregarla ahi tambien (fue el Msg 207 del 22/09).
--   (b) agregar Proyecto al GROUP BY de 'acc' y a su JOIN (hoy 0 colisiones, pero la clave esta incompleta).
--   (c) documentar que Sigma-vida NO resetea en cambio de componente, a diferencia de /rankingacum.
-- Las consultas de abajo quedan listas para ese momento.
-- (1) El test (3) del BLOQUE 87, ahora BIEN escrito: filtrando el componente en AMBOS lados.
SELECT te.Equipo, te.Compartimiento, te.Parametro,
       te.Acumulado AS Sigma_vida_vista, te.NmAcum AS N_muestras_vista,
       x.SumaCruda, x.NMuestras
FROM [dbo].[vw_TendenciaElemento] te
CROSS APPLY (
    SELECT CAST(SUM(m.Fe_ppm) AS decimal(18,1)) AS SumaCruda, COUNT(m.Fe_ppm) AS NMuestras
    FROM [dbo].[vw_MuestrasRankeadas] m WITH (NOLOCK)
    WHERE m.Equipo = te.Equipo AND m.Compartimiento = te.Compartimiento AND m.EsDDI = 0
) x
WHERE te.Equipo = 'CA3176' AND te.Parametro = 'Fe';
-- Esperado: una fila por componente, y en TODAS Sigma_vida_vista = SumaCruda y N_muestras_vista = NMuestras.
-- Para MT LH debe decir 3207.0 y 26.

-- (2) Que el nuevo formato se vea: Sigma-vida ahora se imprime como '3207.0 (26)'.
SELECT MD FROM [dbo].[vw_TendenciaMD] WHERE Equipo = 'CA3176' AND compAbbr = 'MT LH';
-- Verificar en la tabla: encabezado 'Σvida (nº m.)' y celdas con el numero de muestras entre parentesis.

-- (3) No-regresion del JOIN: al agregar Proyecto a 'acc', ninguna fila debe quedarse sin acumulado.
SELECT COUNT(*) AS Filas, SUM(CASE WHEN Acumulado IS NULL THEN 1 ELSE 0 END) AS Sin_acumulado,
       SUM(CASE WHEN NmAcum IS NULL THEN 1 ELSE 0 END) AS Sin_conteo
FROM [dbo].[vw_TendenciaElemento];
-- Esperado: Sin_acumulado y Sin_conteo en 0 (salvo V100/TBN, que por diseño no acumulan: Orden 17 y 18).


-- ==== BLOQUE 89 - Chequeo de vistas ROTAS (metadatos, NO ejecuta las vistas) ====
-- Por que existe: un CREATE VIEW se guarda aunque su cuerpo sea invalido (columna inexistente); el error
-- recien salta cuando ALGUIEN la consulta, o sea en produccion. Paso el 22/09 con 'NmAcum'.
-- ⚠ LA PRIMERA VERSION DE ESTE BLOQUE ESTABA MAL: recorria las vistas con un cursor haciendo
--   'SELECT TOP 0 *' sobre cada una. Eso EJECUTA la vista (compilar y abrir el plan de las pesadas cuesta
--   minutos) y colgo SSMS. Reemplazada por sp_describe_first_result_set, que solo RESUELVE las columnas:
--   valida exactamente lo mismo (que la vista compile y sus columnas existan) sin tocar una sola fila.
SELECT v.name AS Vista, d.error_message AS Error
FROM sys.views v
OUTER APPLY sys.dm_exec_describe_first_result_set(
        N'SELECT * FROM [dbo].' + QUOTENAME(v.name), NULL, 0) d
WHERE SCHEMA_NAME(v.schema_id) = 'dbo'
  AND v.name LIKE 'vw_%'
  AND d.error_message IS NOT NULL
ORDER BY v.name;
-- Esperado: 0 filas. Cualquier fila = esa vista esta rota y su Error dice por que.
-- Corre en segundos. ⚠ Valida que COMPILEN, no que devuelvan lo correcto: para eso estan los bloques
-- de equivalencia por HASHBYTES.


-- ==== BLOQUE 90 - RONDA 23/09 (bloque B): cazar el 6 785.39 de Sigma-vida ====
-- Gerencia: para Fe en CA3160 MT LH la tabla muestra 3 718.7 y deberia decir 6 785.39.
-- Pista: vw_MuestrasRankeadas termina en WHERE EsDDI = 0; vw_MuestrasHistorial es la MISMA base SIN
-- ese filtro (por eso el historial si muestra filas DDI). ⛔ No tocar la vista hasta que un SUM de
-- EXACTAMENTE 6785.39.
-- (1) Los tres universos posibles, lado a lado.
SELECT N'sin DDI (lo que hace hoy)' AS Universo,
       CAST(SUM(Fe_ppm) AS decimal(18,2)) AS SumaFe, COUNT(Fe_ppm) AS NMuestras
FROM [dbo].[vw_MuestrasRankeadas] WITH (NOLOCK)
WHERE Equipo = 'CA3160' AND Compartimiento LIKE '%TRACCION%LH'
UNION ALL
SELECT N'TODAS (con DDI)',
       CAST(SUM(Fe_ppm) AS decimal(18,2)), COUNT(Fe_ppm)
FROM [dbo].[vw_MuestrasHistorial] WITH (NOLOCK)
WHERE Equipo = 'CA3160' AND Compartimiento LIKE '%TRACCION%LH'
UNION ALL
SELECT N'solo DDI',
       CAST(SUM(Fe_ppm) AS decimal(18,2)), COUNT(Fe_ppm)
FROM [dbo].[vw_MuestrasHistorial] WITH (NOLOCK)
WHERE Equipo = 'CA3160' AND Compartimiento LIKE '%TRACCION%LH' AND EsDDI = 1;
-- Esperado: que 'TODAS' de 6785.39.
--
-- RESULTADO (24/09): NO cuadra, y por eso el bloque valio la pena.
--   sin DDI (lo que hace hoy) = 3 718.70 / 27 muestras
--   TODAS (con DDI)           = 4 994.66 / 45 muestras
--   solo DDI                  = 1 275.96 / 18 muestras
--   El esperado 6 785.39 es MAYOR que el total de TODAS -> ningun subconjunto de estas vistas lo produce.
--   El DDI explicaba parte de la diferencia, pero NO toda.
-- CAUSA REAL (encontrada leyendo la fundacion, vw_MuestrasEstado):
--   WHERE LD.[FechaMuestreo] >= DATEADD(MONTH, -12, GETDATE())
--   La fundacion ventana a 12 MESES por rendimiento (comentario del DDL: 'rankea sobre 1 año en vez de 9').
--   => Sigma-vida NO es la vida del componente: es 'lo acumulado en los ultimos 12 meses'. El area suma
--      TODO el historico. Ese es el gap. Ver BLOQUE 94.

-- (2) Si (1) no cuadra: el detalle muestra por muestra, para ver que se esta sumando de mas o de menos.
SELECT FechaMuestreo, CM, EsDDI, Fe_ppm,
       SUM(Fe_ppm) OVER (ORDER BY FechaMuestreo, LaboratoryDataId ROWS UNBOUNDED PRECEDING) AS Corrido
FROM [dbo].[vw_MuestrasHistorial] WITH (NOLOCK)
WHERE Equipo = 'CA3160' AND Compartimiento LIKE '%TRACCION%LH'
ORDER BY FechaMuestreo, LaboratoryDataId;

-- ==== BLOQUE 91 - RONDA 23/09 (bloque C4): el JOIN de limites ignora el MODELO ====
-- El Excel de gerencia tiene la clave Proyecto + Componente + MODELO (Cerro Verde trae valores distintos
-- para 980E y 730E-10). Nuestro JOIN a [Eqpcare].[lc] es solo por COMPONENTE. Esto dice si eso ya esta
-- mezclando limites de un modelo con equipos de otro.
-- (1) Que columnas tiene lc y si incluye modelo.
SELECT TOP 5 * FROM [Eqpcare].[lc];
-- (2) Cuantas filas hay por proyecto+componente: si hay mas de una, el JOIN sin modelo es ambiguo.
SELECT [PROYECTO], [COMPONENTE], COUNT(*) AS Filas
FROM [Eqpcare].[lc]
GROUP BY [PROYECTO], [COMPONENTE]
HAVING COUNT(*) > 1
ORDER BY Filas DESC;
-- Esperado: 0 filas. Si sale alguna, el limite aplicado depende del plan -> hay que desambiguar por modelo.
-- ⚠ Ajustar los nombres de columna de lc a los reales antes de correr (ver resultado de (1)).


-- ==== BLOQUE 92 - RONDA 23/09 bloque A: verificar los renombres de texto ====
-- Cambios aplicados en DDL_vistas.sql (27 sustituciones, ninguna toca datos ni logica):
--   A1  'Horom.' / 'Horometro' / ' - Hor. '  ->  'SMR'          (el horometro del EQUIPO)
--       ⛔ 'Hor.Comp.' NO se toco: son las horas del COMPONENTE, es otra cosa.
--   A2  'CM'  ->  'T. muestra'  (encabezados)  y  ' - CM x'  ->  ' - T. muestra x'  (linea de contexto)
--   A3  'Nº fuera'  ->  'Nº fuera de limite'
--   A4  /acumulados y /rankingacum: el titulo corta en 'N equipos'. Se quito '(por desgaste acumulado
--       ponderado)' y todo el subtitulo con la formula y las bandas.
--       ⚠ En /rankinggraf la formula SE QUEDA: ahi es la leyenda de la grafica, no relleno.
-- (1) Smoke test primero: ninguna vista debe quedar rota (es el ritual tras cada despliegue).
SELECT v.name AS Vista, d.error_message AS Error
FROM sys.views v
OUTER APPLY sys.dm_exec_describe_first_result_set(N'SELECT * FROM [dbo].' + QUOTENAME(v.name), NULL, 0) d
WHERE SCHEMA_NAME(v.schema_id) = 'dbo' AND v.name LIKE 'vw_%' AND d.error_message IS NOT NULL
ORDER BY v.name;
-- Esperado: 0 filas.

-- (2) Que NO quede ningun rotulo viejo en ninguna salida MD. Este es el chequeo que importa.
-- ⚠ CORREGIDO 24/09: la primera version ponia Equipo en vistas que no lo tienen (vw_ObservadosResumenMD,
--    vw_ObservadosBarridoMD, vw_CondicionCompMD y vw_AcumuladosFlotaMD son de FLOTA: su clave es Proyecto)
--    -> Msg 207 'Invalid column name Equipo'. Columnas cruzadas contra docs/arquitectura/ESQUEMA_BD.xlsx.
WITH mds AS (
    SELECT 'vw_UltimoAnalisisMD'   AS Vista, MD FROM [dbo].[vw_UltimoAnalisisMD]  WHERE Equipo='CA3160' AND compAbbr='MT LH'
    UNION ALL SELECT 'vw_TendenciaMD',        MD FROM [dbo].[vw_TendenciaMD]      WHERE Equipo='CA3160' AND compAbbr='MT LH'
    UNION ALL SELECT 'vw_TendenciaMetalMD',   MD FROM [dbo].[vw_TendenciaMetalMD] WHERE Equipo='CA3160' AND Parametro='Fe'
    UNION ALL SELECT 'vw_HistorialMD',        MD FROM [dbo].[vw_HistorialMD]      WHERE Equipo='CA3160' AND compAbbr='MT LH'
    UNION ALL SELECT 'vw_ObservadosResumenMD',MD             FROM [dbo].[vw_ObservadosResumenMD] WHERE Proyecto LIKE '%Antapaccay%'
    UNION ALL SELECT 'vw_ObservadosBarridoMD',DetalleTodosMD FROM [dbo].[vw_ObservadosBarridoMD] WHERE Proyecto LIKE '%Antapaccay%'
    UNION ALL SELECT 'vw_CondicionCompMD',    MD             FROM [dbo].[vw_CondicionCompMD]     WHERE Proyecto LIKE '%Antapaccay%'
    UNION ALL SELECT 'vw_AcumuladosFlotaMD',  MD             FROM [dbo].[vw_AcumuladosFlotaMD]   WHERE Proyecto LIKE '%Antapaccay%'
)
SELECT Vista,
       CASE WHEN MD LIKE N'%Hor' + NCHAR(243) + N'm%'  THEN N'QUEDA Horom' ELSE N'' END
     + CASE WHEN MD LIKE N'%| CM |%'                   THEN N' QUEDA |CM|' ELSE N'' END
     + CASE WHEN MD LIKE N'%' + NCHAR(183) + N' CM %'  THEN N' QUEDA ·CM' ELSE N'' END
     + CASE WHEN MD LIKE N'%N' + NCHAR(186) + N' fuera |%' THEN N' QUEDA Nº fuera' ELSE N'' END AS Restos,
       CASE WHEN MD LIKE N'%SMR%' THEN N'SMR ok' ELSE N'-' END AS TieneSMR,
       CASE WHEN MD LIKE N'%T. muestra%' THEN N'T.muestra ok' ELSE N'-' END AS TieneTmuestra
FROM mds
ORDER BY Vista;
-- Esperado: columna 'Restos' VACIA en todas. (No todas tienen SMR o T. muestra: '-' es normal; lo que no
-- puede haber es un rotulo viejo.)

-- (3) A4 al ojo: el titulo debe cortar en 'N equipos' y la tabla arrancar tras una linea en blanco.
SELECT LEFT(MD, 220) AS Cabecera FROM [dbo].[vw_AcumuladosFlotaMD] WHERE Proyecto LIKE '%Antapaccay%';
-- Esperado: '**Ranking de Atención — Motor Diésel · Antapaccay** · 27 equipos' + linea en blanco + tabla.
-- ⛔ Si la linea en blanco se pierde, Teams vuelca la tabla como texto (es el bug P0 de la ronda anterior).

-- (4) No-regresion de /rankinggraf: ahi la formula SI debe seguir.
SELECT CASE WHEN MD LIKE N'%Pb%0.68%' THEN N'ok, la formula sigue' ELSE N'REGRESION: se perdio la leyenda' END AS Chequeo
FROM [dbo].[vw_RankingGrafMD] WHERE Proyecto LIKE '%Antapaccay%';


-- ==== BLOQUE 93 - BUG del componente PEGADO (mtlh) - capa SQL ====
-- Sintoma (24/09, prueba del usuario): '/ultimo 3160 mt lh' funciona y '/ultimo 3160 mtlh' responde
-- 'No encontre datos para esa consulta', que suena a 'ese equipo no tiene muestras'. Bug silencioso.
-- Causa: compAbbr es 'MT LH' CON espacio; con 'mtlh' el LIKE no casa y devuelve 0 filas.
-- Se arregla en DOS capas, porque hay DOS caminos de entrada:
--   1. Comando  -> normalizacion del dispatcher (CONFIG_COMANDOS, §Formula canonica): colapsa espacios
--                  ANTES de decidir, asi 'mtlh' y 'traccion lh' terminan ambos en 'MT LH'.
--   2. Lenguaje natural -> el tema llena 'compartimiento' directo y esa formula NO corre. Por eso los
--                  flujos MD_equipo_comp y MD_metal comparan sin espacios (CONFIG_FLUJOS).
-- Esto valida la capa 2, que es la que se puede probar en SSMS.
-- (1) Como se comporta HOY el LIKE tal cual (el que esta en el flujo antes del fix).
SELECT N'mt lh' AS Entrada, COUNT(*) AS Filas FROM [dbo].[vw_UltimoAnalisisMD] WHERE Equipo='CA3160' AND compAbbr LIKE '%mt lh%'
UNION ALL
SELECT N'mtlh', COUNT(*) FROM [dbo].[vw_UltimoAnalisisMD] WHERE Equipo='CA3160' AND compAbbr LIKE '%mtlh%';
-- Esperado ANTES del fix: 'mt lh' = 1 y 'mtlh' = 0. Esa asimetria ES el bug.

-- (2) Con la comparacion sin espacios, las dos formas deben dar lo mismo.
SELECT N'mt lh' AS Entrada, COUNT(*) AS Filas FROM [dbo].[vw_UltimoAnalisisMD]
WHERE Equipo='CA3160' AND REPLACE(compAbbr,' ','') LIKE '%' + REPLACE('mt lh',' ','') + '%'
UNION ALL
SELECT N'mtlh', COUNT(*) FROM [dbo].[vw_UltimoAnalisisMD]
WHERE Equipo='CA3160' AND REPLACE(compAbbr,' ','') LIKE '%' + REPLACE('mtlh',' ','') + '%'
UNION ALL
SELECT N'MT-LH', COUNT(*) FROM [dbo].[vw_UltimoAnalisisMD]
WHERE Equipo='CA3160' AND REPLACE(compAbbr,' ','') LIKE '%' + REPLACE('MT-LH',' ','') + '%';
-- Esperado: 1, 1 y... 'MT-LH' sigue en 0 (el guion no lo quita el SQL, lo quita la formula del dispatcher).
-- Es correcto: cada capa cubre lo suyo. El guion llega normalizado desde el comando.

-- (3) Que la tolerancia NO afloje de mas: 'mt' suelto debe seguir trayendo LH y RH (2 filas), y un
--     componente no abreviado debe seguir casando por su nombre completo.
SELECT N'mt (sin lado)' AS Entrada, COUNT(*) AS Filas FROM [dbo].[vw_UltimoAnalisisMD]
WHERE Equipo='CA3160' AND REPLACE(compAbbr,' ','') LIKE '%' + REPLACE('mt',' ','') + '%'
UNION ALL
SELECT N'mando final lh', COUNT(*) FROM [dbo].[vw_UltimoAnalisisMD]
WHERE REPLACE(compAbbr,' ','') LIKE '%' + REPLACE('mando final lh',' ','') + '%';
-- Esperado: 'mt' = 2 (LH y RH). 'mando final lh' > 0 en los proyectos que lo tienen (Antapaccay).
--
-- RESULTADOS (24/09) -- BLOQUE 92 y 93, todo OK:
--   92(2): 22 filas, columna 'Restos' VACIA en todas. SMR y T. muestra presentes donde corresponde.
--   93(1): 'mt lh' = 1 y 'mtlh' = 0  -> la asimetria confirmada: ESE era el bug.
--   93(2): 'mt lh' = 1, 'mtlh' = 1, 'MT-LH' = 0  -> exactamente lo previsto. El guion NO lo resuelve el SQL
--          (solo quita espacios); lo normaliza la formula del dispatcher. Cada capa cubre lo suyo.
--   93(3): 'mt' (sin lado) = 2 y 'mando final lh' = 12 -> la tolerancia NO aflojo de mas.
--   En Copilot: /ultimo 3160 mtlh, /tendenciadet 3160 mtlh, /grafica 3160 mtlh PQ y por lenguaje natural
--   ('el ultimo analisis del 3160 mtlh') responden; '/tendenciadet 3161 mt rh' (separado) sigue igual.
--   => BLOQUE A CERRADO (24/09).


-- ==== BLOQUE 94 - P2/bloque B: Sigma-vida contra el historico COMPLETO (sin la ventana de 12 meses) ====
-- Hipotesis: el area suma TODA la vida registrada; nuestras vistas solo ven 12 meses porque la fundacion
-- filtra por rendimiento. Esto va a la tabla base, sin ninguna vista de por medio.
-- (1) Los cuatro universos, para aislar cuanto aporta cada filtro.
WITH raw AS (
    SELECT LD.[Fe_ppm], LD.[FechaMuestreo],
           CASE WHEN LD.[CM] IN ('DDI','DIALIZADO','RELLENO+DIALIZADO') THEN 1 ELSE 0 END AS EsDDI
    FROM [Oil].[LaboratoryData] LD WITH (NOLOCK)
    INNER JOIN [Mine].[MiningEquipment] ME ON ME.[Id] = LD.[MiningEquipmentId]
    WHERE ME.[Code] = 'CA3160' AND LD.[Compartimiento] LIKE '%TRACCION%LH'
)
SELECT N'1. historico COMPLETO, con DDI'   AS Universo, CAST(SUM(Fe_ppm) AS decimal(18,2)) AS SumaFe, COUNT(*) AS N,
       MIN(FechaMuestreo) AS Desde, MAX(FechaMuestreo) AS Hasta FROM raw
UNION ALL
SELECT N'2. historico COMPLETO, sin DDI',  CAST(SUM(Fe_ppm) AS decimal(18,2)), COUNT(*), MIN(FechaMuestreo), MAX(FechaMuestreo) FROM raw WHERE EsDDI = 0
UNION ALL
SELECT N'3. 12 meses, con DDI',            CAST(SUM(Fe_ppm) AS decimal(18,2)), COUNT(*), MIN(FechaMuestreo), MAX(FechaMuestreo) FROM raw WHERE FechaMuestreo >= DATEADD(MONTH,-12,GETDATE())
UNION ALL
SELECT N'4. 12 meses, sin DDI (= hoy)',    CAST(SUM(Fe_ppm) AS decimal(18,2)), COUNT(*), MIN(FechaMuestreo), MAX(FechaMuestreo) FROM raw WHERE FechaMuestreo >= DATEADD(MONTH,-12,GETDATE()) AND EsDDI = 0;
-- El universo que de 6 785.39 define el criterio del area. Esperado: el (1) o el (2).
--
-- RESULTADO (24/09): NINGUNO de los cuatro da 6 785.39.
--   1. historico COMPLETO, con DDI = 23 179.64 / 271 muestras (2020-09-27 -> 2026-09-16)
--   2. historico COMPLETO, sin DDI = 18 372.32 / 192
--   3. 12 meses, con DDI          =  4 994.66 /  45
--   4. 12 meses, sin DDI (= hoy)  =  3 718.70 /  27
--   El esperado cae ENTRE la ventana de 12 meses y el historico completo -> no es ni una cosa ni la otra.
--   Ver BLOQUE 95: en vez de adivinar el criterio, se busca QUE corte produce exactamente ese numero.
-- (2) RESULTADO: 111 998 muestras totales, 33 285 en la ventana de 12 meses; historico 2017-02-24 -> 2026-09-24.
--   La ventana descarta ~70% del historico: para Sigma-vida no es un detalle, es estructural.
-- (3) RESULTADO: 933 ms, 1 364 lecturas logicas, 1 scan de LaboratoryData, 2 215 grupos.
--   => Calcular el acumulado SIN ventana es BARATO. El diseño propuesto (CTE propio sin ventana, dejando
--      el resto de la fundacion ventanada) es viable; falta solo saber el universo correcto.
-- ⛔ Si NINGUNO da 6785.39, no seguir tocando: preguntar al Carlos con QUE lo calculo (puede venir de
--    otra herramienta con otro corte, u otro componente).

-- (2) Cuanta historia nos estamos perdiendo, a nivel sistema (no solo este equipo).
SELECT COUNT(*) AS Muestras_totales,
       SUM(CASE WHEN LD.[FechaMuestreo] >= DATEADD(MONTH,-12,GETDATE()) THEN 1 ELSE 0 END) AS En_ventana_12m,
       MIN(LD.[FechaMuestreo]) AS Mas_antigua, MAX(LD.[FechaMuestreo]) AS Mas_reciente
FROM [Oil].[LaboratoryData] LD WITH (NOLOCK);
-- Contexto para decidir: si el historico es MUCHO mayor que la ventana, sacar Sigma-vida de la fundacion
-- ventanada es estructuralmente incorrecto, no un detalle.

-- (3) El costo de NO ventanar, medido (la ventana existe por rendimiento: hay que saber que cuesta quitarla
--     SOLO para el acumulado). Suma por equipo+compartimiento de todo el historico.
SET STATISTICS IO ON; SET STATISTICS TIME ON;
SELECT COUNT(*) FROM (
    SELECT ME.[Code], LD.[Compartimiento], SUM(LD.[Fe_ppm]) AS s
    FROM [Oil].[LaboratoryData] LD WITH (NOLOCK)
    INNER JOIN [Mine].[MiningEquipment] ME ON ME.[Id] = LD.[MiningEquipmentId]
    GROUP BY ME.[Code], LD.[Compartimiento]
) z;
SET STATISTICS IO OFF; SET STATISTICS TIME OFF;
-- Si esto responde rapido, el acumulado puede salir de un CTE propio SIN ventana, dejando el resto de la
-- fundacion ventanada como esta. Es el diseño que menos toca y no degrada lo demas.


-- ==== BLOQUE 95 - P2/bloque B: que corte produce EXACTAMENTE 6 785.39 ====
-- Ninguno de los 4 universos del BLOQUE 94 lo da. En vez de seguir proponiendo criterios, se busca el corte
-- al reves: acumulando hacia atras desde la muestra mas reciente, hasta llegar a 6 785.39.
-- (1) Suma corriendo hacia atras. La fila donde 'AcumDesdeElFinal' se acerca a 6785.39 marca la FECHA
--     de corte que uso el area (candidata: un cambio de componente o de aceite).
WITH raw AS (
    SELECT LD.[FechaMuestreo], LD.[CM], LD.[Fe_ppm], LD.[Horometro], LD.[HorasDeAceite], LD.[LaboratoryDataId],
           CASE WHEN LD.[CM] IN ('DDI','DIALIZADO','RELLENO+DIALIZADO') THEN 1 ELSE 0 END AS EsDDI
    FROM [Oil].[LaboratoryData] LD WITH (NOLOCK)
    INNER JOIN [Mine].[MiningEquipment] ME ON ME.[Id] = LD.[MiningEquipmentId]
    WHERE ME.[Code] = 'CA3160' AND LD.[Compartimiento] LIKE '%TRACCION%LH'
)
SELECT TOP 120 FechaMuestreo, CM, EsDDI, Fe_ppm, Horometro, HorasDeAceite,
       CAST(SUM(Fe_ppm) OVER (ORDER BY FechaMuestreo DESC, LaboratoryDataId DESC ROWS UNBOUNDED PRECEDING) AS decimal(18,2)) AS AcumDesdeElFinal_conDDI
FROM raw
ORDER BY FechaMuestreo DESC, LaboratoryDataId DESC;
-- Mirar: (a) en que fecha AcumDesdeElFinal pasa por ~6785; (b) si el Horometro se REINICIA cerca de ahi
-- (= componente nuevo); (c) si esa fila tiene un CM distinto (cambio de aceite).

-- (2) Y la version sin DDI, por si el criterio del area excluye dializados.
WITH raw AS (
    SELECT LD.[FechaMuestreo], LD.[Fe_ppm], LD.[Horometro], LD.[LaboratoryDataId]
    FROM [Oil].[LaboratoryData] LD WITH (NOLOCK)
    INNER JOIN [Mine].[MiningEquipment] ME ON ME.[Id] = LD.[MiningEquipmentId]
    WHERE ME.[Code] = 'CA3160' AND LD.[Compartimiento] LIKE '%TRACCION%LH'
      AND LD.[CM] NOT IN ('DDI','DIALIZADO','RELLENO+DIALIZADO')
)
SELECT TOP 120 FechaMuestreo, Fe_ppm, Horometro,
       CAST(SUM(Fe_ppm) OVER (ORDER BY FechaMuestreo DESC, LaboratoryDataId DESC ROWS UNBOUNDED PRECEDING) AS decimal(18,2)) AS AcumDesdeElFinal_sinDDI
FROM raw
ORDER BY FechaMuestreo DESC, LaboratoryDataId DESC;

-- (3) OTRA POSIBILIDAD: que 6 785.39 no sea de este par equipo+componente. Se busca en toda la BD que
--     combinacion da ese numero. Si aparece una sola, el misterio se acaba sin preguntar nada.
--     (El BLOQUE 94 midio 933 ms para este GROUP BY completo, asi que es barato.)
SELECT ME.[Code] AS Equipo, LD.[Compartimiento],
       CAST(SUM(LD.[Fe_ppm]) AS decimal(18,2)) AS SumaFe_historico, COUNT(*) AS N
FROM [Oil].[LaboratoryData] LD WITH (NOLOCK)
INNER JOIN [Mine].[MiningEquipment] ME ON ME.[Id] = LD.[MiningEquipmentId]
GROUP BY ME.[Code], LD.[Compartimiento]
HAVING ABS(SUM(LD.[Fe_ppm]) - 6785.39) < 1.0
ORDER BY Equipo;
-- Esperado: 0 filas (entonces es un corte temporal, ver (1)) o 1-2 filas (entonces era otro componente
-- u otro equipo, y el numero estaba bien pero mal atribuido).
--
-- RESULTADOS BLOQUE 95 (24/09): el numero NO aparece por ningun lado.
--   (1) con DDI  -> 6 785.39 cae ENTRE dos muestras: 2025-04-17 = 6 699.42 y 2025-04-16 = 6 816.04.
--   (2) sin DDI  -> tambien cae entre dos: 2024-10-04 = 6 699.32 y 2024-09-19 = 6 809.32.
--       => NO hay fecha de corte que lo produzca. Si fuera 'desde tal fecha', caeria EXACTO en una fila.
--   (3) busqueda en toda la BD -> 0 filas: ningun par equipo+compartimiento suma 6 785.39 en su historico.
--   Ademas: el Horometro baja de forma monotona (43 600 -> 13 127) sin reinicios, asi que en esta ventana
--   NO hubo cambio de componente -> la hipotesis 'desde la instalacion' es igual al historico completo
--   (18 372 sin DDI / 23 179 con DDI), que tampoco es.
--   Confirmado de paso: 3 718.70 aparece exacto en la corrida sin DDI al llegar a 2025-10-06 = la ventana
--   de 12 meses. Nuestro numero actual esta bien calculado; lo que se discute es QUE universo sumar.

-- ==== BLOQUE 96 - P2/bloque B: ULTIMO intento sistematico antes de preguntar ====
-- Quedan dos familias de hipotesis sin probar: (a) que el area sume solo cierto TIPO de muestra,
-- (b) que use una ventana distinta de 12 meses. Esto cubre las dos de una vez.
-- (1) Cuanto aporta cada tipo de muestra (CM) en todo el historico. Si alguna combinacion da 6 785.39,
--     el criterio era 'solo estas muestras'.
WITH raw AS (
    SELECT LD.[CM], LD.[Fe_ppm], LD.[FechaMuestreo]
    FROM [Oil].[LaboratoryData] LD WITH (NOLOCK)
    INNER JOIN [Mine].[MiningEquipment] ME ON ME.[Id] = LD.[MiningEquipmentId]
    WHERE ME.[Code] = 'CA3160' AND LD.[Compartimiento] LIKE '%TRACCION%LH'
)
SELECT ISNULL(CM, N'(nulo)') AS TipoMuestra, COUNT(*) AS N,
       CAST(SUM(Fe_ppm) AS decimal(18,2)) AS SumaFe,
       CAST(SUM(SUM(Fe_ppm)) OVER (ORDER BY SUM(Fe_ppm) DESC ROWS UNBOUNDED PRECEDING) AS decimal(18,2)) AS AcumuladoCorrido
FROM raw GROUP BY CM ORDER BY SumaFe DESC;
-- Mirar si algun SumaFe individual, o alguna suma de 2-3 tipos, da 6 785.39.

-- (2) La misma suma para varias ventanas. Si alguna da 6 785.39, el criterio era esa ventana.
WITH raw AS (
    SELECT LD.[Fe_ppm], LD.[FechaMuestreo],
           CASE WHEN LD.[CM] IN ('DDI','DIALIZADO','RELLENO+DIALIZADO') THEN 1 ELSE 0 END AS EsDDI
    FROM [Oil].[LaboratoryData] LD WITH (NOLOCK)
    INNER JOIN [Mine].[MiningEquipment] ME ON ME.[Id] = LD.[MiningEquipmentId]
    WHERE ME.[Code] = 'CA3160' AND LD.[Compartimiento] LIKE '%TRACCION%LH'
), v AS (
    SELECT * FROM (VALUES (12),(18),(24),(30),(36),(48),(60)) x(Meses)
)
SELECT v.Meses,
       CAST(SUM(CASE WHEN r.FechaMuestreo >= DATEADD(MONTH,-v.Meses,GETDATE()) THEN r.Fe_ppm END) AS decimal(18,2)) AS ConDDI,
       CAST(SUM(CASE WHEN r.FechaMuestreo >= DATEADD(MONTH,-v.Meses,GETDATE()) AND r.EsDDI=0 THEN r.Fe_ppm END) AS decimal(18,2)) AS SinDDI
FROM v CROSS JOIN raw r GROUP BY v.Meses ORDER BY v.Meses;
-- Esperado: alguna celda = 6 785.39.
--
-- RESULTADOS BLOQUE 96 (24/09): tampoco.
--   (1) Por tipo de muestra (historico completo): ADI 9 339.12 (80) - M 6 492.93 (89) - DDI 4 807.32 (79)
--       - C 2 540.27 (23). Total 23 179.64. Ninguna suma ni combinacion de ellas da 6 785.39
--       (M solo es 6 492.93, la mas cercana, y le faltan 292.46 que no corresponden a ningun otro tipo).
--   (2) Por ventana:  12m 4 994.66 / 3 718.70 | 18m 6 973.03 / 5 070.85 | 24m 9 308.64 / 6 699.32
--                     30m 11 782.64 / 8 740.32 | 36m 14 274.64 / 10 472.32 | 48m 18 057.64 / 13 683.32
--                     60m 20 586.64 / 15 779.32      (ConDDI / SinDDI)
--       El objetivo queda encajonado entre 18m-conDDI (6 973.03) y 24m-sinDDI (6 699.32), pero el BLOQUE 95
--       ya probo que ningun corte por fecha lo produce.
-- => Descartadas CON DATOS las 4 familias: ventana temporal, tipo de muestra, otro componente, y
--    'desde la instalacion'. Falta una sola cosa por descartar: que no sea Fe. Ver BLOQUE 97.

-- ==== BLOQUE 97 - P2/bloque B: buscar 6 785.39 en TODOS los metales, no solo Fe ====
-- Todo lo anterior busco Fe. Si el numero existe en la BD para OTRO parametro (o para otro equipo con otro
-- parametro), esto lo encuentra. Es la prueba decisiva: o aparece, o el numero no sale de nuestra data.
-- Costo esperado: pocos segundos (el GROUP BY completo de Fe tardo 933 ms; aqui son 18 parametros).
WITH raw AS (
    SELECT ME.[Code] AS Equipo, LD.[Compartimiento], LD.[FechaMuestreo],
           CASE WHEN LD.[CM] IN ('DDI','DIALIZADO','RELLENO+DIALIZADO') THEN 1 ELSE 0 END AS EsDDI,
           p.Parametro, p.Valor
    FROM [Oil].[LaboratoryData] LD WITH (NOLOCK)
    INNER JOIN [Mine].[MiningEquipment] ME ON ME.[Id] = LD.[MiningEquipmentId]
    CROSS APPLY (VALUES
        ('Fe',LD.[Fe_ppm]),('PQ',LD.[Indice_PQ]),('Cr',LD.[Cr_ppm]),('Ni',LD.[Ni_ppm]),('Cu',LD.[Cu_ppm]),
        ('Pb',LD.[Pb_ppm]),('Sn',LD.[Sn_ppm]),('Al',LD.[Al_ppm]),('Si',LD.[Si_ppm]),('Ca',LD.[Ca_ppm]),
        ('Zn',LD.[Zn_ppm]),('Na',LD.[Na_ppm]),('K',LD.[K_ppm]),('Mg',LD.[Mg_ppm]),('B',LD.[B_ppm]),
        ('P',LD.[P_ppm]),('TBN',LD.[TBN]),('V100',LD.[V100])
    ) p(Parametro, Valor)
)
SELECT N'historico completo, con DDI' AS Universo, Equipo, Compartimiento, Parametro,
       CAST(SUM(Valor) AS decimal(18,2)) AS Suma, COUNT(Valor) AS N
FROM raw GROUP BY Equipo, Compartimiento, Parametro
HAVING ABS(SUM(Valor) - 6785.39) < 0.51
UNION ALL
SELECT N'historico completo, sin DDI', Equipo, Compartimiento, Parametro,
       CAST(SUM(Valor) AS decimal(18,2)), COUNT(Valor)
FROM raw WHERE EsDDI = 0 GROUP BY Equipo, Compartimiento, Parametro
HAVING ABS(SUM(Valor) - 6785.39) < 0.51
UNION ALL
SELECT N'12 meses, sin DDI (universo actual)', Equipo, Compartimiento, Parametro,
       CAST(SUM(Valor) AS decimal(18,2)), COUNT(Valor)
FROM raw WHERE EsDDI = 0 AND FechaMuestreo >= DATEADD(MONTH,-12,GETDATE())
GROUP BY Equipo, Compartimiento, Parametro
HAVING ABS(SUM(Valor) - 6785.39) < 0.51
ORDER BY Universo, Equipo;
-- Si aparece 1 fila -> ahi esta el origen (probablemente otro parametro del mismo MT LH, o el mismo Fe de
--   otro equipo): el numero era correcto y estaba mal atribuido.
-- Si aparecen 0 filas -> el 6 785.39 NO sale de [Oil].[LaboratoryData] con ninguna combinacion razonable.
--   En ese punto se PREGUNTA, y se pregunta con esta evidencia: no es que no buscamos.
--
-- RESULTADO (24/09): 1 fila, pero NO es el origen:
--   historico completo, sin DDI | CM402 | MOTOR DE TRACCION RH | Si | 6 785.03 | 144 muestras
--   Difiere en TODO: equipo (CM402, no CA3160), lado (RH, no LH), parametro (Si, no Fe) y valor
--   (6 785.03, no 6 785.39; entro por la tolerancia de +-0.51). Sospecha: coincidencia estadistica.
--   Se verifica en el BLOQUE 98 antes de descartarlo -- no se descarta 'a ojo'.

-- ==== BLOQUE 98 - Control: ¿la coincidencia del BLOQUE 97 es real o es ruido? ====
-- Con ~2 215 pares equipo+compartimiento x 18 parametros hay ~40 000 sumas. Encontrar UNA a menos de 0.5
-- de un numero cualquiera puede ser lo esperable, no un hallazgo. Test de falsacion: se repite la MISMA
-- busqueda con objetivos ARBITRARIOS. Si tambien devuelven ~1 fila cada uno, el hallazgo del 97 es ruido.
WITH raw AS (
    SELECT ME.[Code] AS Equipo, LD.[Compartimiento], p.Parametro, p.Valor
    FROM [Oil].[LaboratoryData] LD WITH (NOLOCK)
    INNER JOIN [Mine].[MiningEquipment] ME ON ME.[Id] = LD.[MiningEquipmentId]
    CROSS APPLY (VALUES
        ('Fe',LD.[Fe_ppm]),('PQ',LD.[Indice_PQ]),('Cr',LD.[Cr_ppm]),('Ni',LD.[Ni_ppm]),('Cu',LD.[Cu_ppm]),
        ('Pb',LD.[Pb_ppm]),('Sn',LD.[Sn_ppm]),('Al',LD.[Al_ppm]),('Si',LD.[Si_ppm]),('Ca',LD.[Ca_ppm]),
        ('Zn',LD.[Zn_ppm]),('Na',LD.[Na_ppm]),('K',LD.[K_ppm]),('Mg',LD.[Mg_ppm]),('B',LD.[B_ppm]),
        ('P',LD.[P_ppm]),('TBN',LD.[TBN]),('V100',LD.[V100])
    ) p(Parametro, Valor)
    WHERE LD.[CM] NOT IN ('DDI','DIALIZADO','RELLENO+DIALIZADO')
), sumas AS (
    SELECT Equipo, Compartimiento, Parametro, SUM(Valor) AS s
    FROM raw GROUP BY Equipo, Compartimiento, Parametro
), objetivos AS (
    SELECT * FROM (VALUES
        (6785.39, N'el objetivo real'),
        (6123.45, N'control arbitrario 1'),
        (7412.88, N'control arbitrario 2'),
        (5934.17, N'control arbitrario 3'),
        (8250.62, N'control arbitrario 4')
    ) v(Objetivo, Etiqueta)
)
SELECT o.Etiqueta, o.Objetivo,
       COUNT(s.s) AS Coincidencias_a_menos_de_0_51,
       MIN(ABS(s.s - o.Objetivo)) AS Distancia_minima
FROM objetivos o
LEFT JOIN sumas s ON ABS(s.s - o.Objetivo) < 0.51
GROUP BY o.Etiqueta, o.Objetivo
ORDER BY o.Etiqueta;
-- Si los 4 controles tambien traen 1 coincidencia cada uno -> el hallazgo del 97 es RUIDO y hay que
--   descartarlo: 6 785.39 no sale de esta BD. -> PREGUNTAR al Carlos.
-- Si SOLO el objetivo real trae coincidencia y los controles 0 -> entonces si merece una segunda mirada.

-- (2) Densidad de sumas alrededor de 6 785: cuantas caen en +-50. Da la magnitud del ruido de un vistazo.
WITH raw AS (
    SELECT ME.[Code] AS Equipo, LD.[Compartimiento], p.Parametro, p.Valor
    FROM [Oil].[LaboratoryData] LD WITH (NOLOCK)
    INNER JOIN [Mine].[MiningEquipment] ME ON ME.[Id] = LD.[MiningEquipmentId]
    CROSS APPLY (VALUES
        ('Fe',LD.[Fe_ppm]),('PQ',LD.[Indice_PQ]),('Si',LD.[Si_ppm]),('Ca',LD.[Ca_ppm]),('Zn',LD.[Zn_ppm]),
        ('P',LD.[P_ppm]),('B',LD.[B_ppm]),('Cu',LD.[Cu_ppm]),('Cr',LD.[Cr_ppm]),('Al',LD.[Al_ppm])
    ) p(Parametro, Valor)
    WHERE LD.[CM] NOT IN ('DDI','DIALIZADO','RELLENO+DIALIZADO')
), sumas AS (
    SELECT SUM(Valor) AS s FROM raw GROUP BY Equipo, Compartimiento, Parametro
)
SELECT COUNT(*) AS Sumas_totales,
       SUM(CASE WHEN ABS(s - 6785.39) < 50 THEN 1 ELSE 0 END) AS En_mas_menos_50,
       SUM(CASE WHEN ABS(s - 6785.39) < 5  THEN 1 ELSE 0 END) AS En_mas_menos_5
FROM sumas;
-- Si hay decenas en +-50, encontrar una en +-0.5 es pura casualidad.
--
-- RESULTADO BLOQUE 98 (24/09): el hallazgo del 97 es RUIDO. Confirmado.
--   control arbitrario 1 (6 123.45) -> 0 coincidencias
--   control arbitrario 2 (7 412.88) -> 0
--   control arbitrario 3 (5 934.17) -> 2 coincidencias, distancia minima 0.170  <-- MAS cerca que el real
--   control arbitrario 4 (8 250.62) -> 0
--   el objetivo real    (6 785.39) -> 1 coincidencia, distancia minima 0.360
--   => 2 de 5 numeros (uno de ellos INVENTADO) encontraron pareja, y el inventado encontro una MEJOR.
--      La coincidencia de CM402/Si no distingue señal de ruido: se descarta.
--   Densidad: 13 620 sumas, 8 caen en +-50 de 6 785 y 2 en +-5.
-- CONCLUSION DE LA INVESTIGACION (bloques 90, 94, 95, 96, 97, 98):
--   6 785.39 NO se reproduce desde [Oil].[LaboratoryData] con ninguna combinacion de: ventana temporal
--   (12 a 60 meses), tipo de muestra (CM), equipo/componente, parametro (los 18), ni 'desde la instalacion'.
--   Nuestro 3 718.70 esta BIEN CALCULADO para su universo (12 meses sin DDI) -- eso quedo verificado.
--   Lo que falta es saber QUE universo quiere el area. -> PREGUNTAR. No seguir midiendo.


-- ==== BLOQUE 99 - bloque B (parte que NO depende de la respuesta): Sigma-vida solo en desgaste ====
-- Pedido: 'Sigma-vida SOLO para met. de desgaste'. Hoy sale tambien en contaminantes y aditivos.
-- Cambio: la celda muestra '—' salvo para Fe, PQ, Cr, Ni, Cu, Pb, Sn, Al.
-- ⚠ Se condiciona por PARAMETRO, no por el grupo actual de la vista, a proposito: el grupo cambia en el
--    bloque C (Si pasa a contaminacion, Ca/Zn a aditivos segun componente). Atarlo al grupo obligaria a
--    rehacerlo; atarlo al metal sobrevive a ese cambio.
-- (1) Smoke test tras desplegar.
SELECT v.name AS Vista, d.error_message AS Error
FROM sys.views v
OUTER APPLY sys.dm_exec_describe_first_result_set(N'SELECT * FROM [dbo].' + QUOTENAME(v.name), NULL, 0) d
WHERE SCHEMA_NAME(v.schema_id) = 'dbo' AND v.name LIKE 'vw_%' AND d.error_message IS NOT NULL
ORDER BY v.name;

-- (2) Que los de desgaste conserven su numero y el resto muestre '—'.
SELECT MD FROM [dbo].[vw_TendenciaMD] WHERE Equipo = 'CA3160' AND compAbbr = 'MT LH';
-- Esperado en la columna Σvida: Fe 3718.7 / PQ 1462.6 / Cr 19.1 / Ni 5.8 / Cu 17.5 / Pb 11.9 / Sn 5.4 /
--   Al 4.4 con valor; y Si, Ca, Zn, K, Na, B, P, Mg, V100, TBN con '—'.
-- ⛔ Ojo: los valores siguen siendo los de la ventana de 12 meses. Eso NO se toca hasta que el area
--    responda de donde sale su 6 785.39 (ver bloques 90-98).

-- (3) Lo mismo en la vista por metal: con un metal de desgaste trae Σvida, con uno que no, '—'.
SELECT N'Fe (desgaste)' AS Caso, MD FROM [dbo].[vw_TendenciaMetalMD] WHERE Equipo='CA3160' AND Parametro='Fe'
UNION ALL
SELECT N'Si (contaminante)', MD FROM [dbo].[vw_TendenciaMetalMD] WHERE Equipo='CA3160' AND Parametro='Si';


-- ==== BLOQUE 100 - Bloque C paso 2: que parametros tiene REALMENTE cada tipo de componente ====
-- El Excel de gerencia define 4 formatos (MT, RD, SH, MODI) con 23-27 parametros cada uno, pero varios no
-- existen en la BD (V40, TAN, Oxidacion, Sulfatacion, Nitracion, Mo, Agua, Hollin, Diesel, Refrigerante,
-- ISO 4/6/14). Antes de escribir el mapa de formato conviene saber QUE se puede llenar: crear filas que
-- siempre saldran vacias es fabricar ruido, y el pedido justamente es CORTAR las filas sin dato.
-- (1) Cobertura real: por CompTipo, cuantas muestras tienen dato en cada parametro (ultimos 12 meses).
WITH s AS (
    SELECT CompTipo, p.Parametro, p.Valor
    FROM [dbo].[vw_MuestrasRankeadas] WITH (NOLOCK)
    CROSS APPLY (VALUES
        ('Fe',Fe_ppm),('PQ',Indice_PQ),('Cr',Cr_ppm),('Ni',Ni_ppm),('Cu',Cu_ppm),('Pb',Pb_ppm),
        ('Sn',Sn_ppm),('Al',Al_ppm),('Si',Si_ppm),('Ca',Ca_ppm),('Zn',Zn_ppm),('Na',Na_ppm),
        ('K',K_ppm),('Mg',Mg_ppm),('B',B_ppm),('P',P_ppm),('TBN',TBN),('V100',V100)
    ) p(Parametro, Valor)
    WHERE rn_recencia = 1
)
SELECT Parametro,
    SUM(CASE WHEN CompTipo='TRACCION'   AND Valor IS NOT NULL THEN 1 ELSE 0 END) AS MT,
    SUM(CASE WHEN CompTipo='RUEDA'      AND Valor IS NOT NULL THEN 1 ELSE 0 END) AS RD,
    SUM(CASE WHEN CompTipo='HIDRAULICO' AND Valor IS NOT NULL THEN 1 ELSE 0 END) AS SH,
    SUM(CASE WHEN CompTipo='MOTOR'      AND Valor IS NOT NULL THEN 1 ELSE 0 END) AS MODI
FROM s GROUP BY Parametro ORDER BY Parametro;
-- COMO LEERLO: un 0 en una columna = ese parametro NO se mide en ese componente -> en el mapa de formato
-- no deberia existir esa fila (o existir y cortarse por C3, pero es mejor no crearla).

-- (2) El otro lado: cuantos LIMITES hay por CompTipo y parametro. Un parametro con dato pero SIN limite
--     se muestra con '—' (correcto), pero conviene saber cuantos son antes de decidir C3.
WITH s AS (
    SELECT CompTipo, p.Parametro, p.LP
    FROM [dbo].[vw_MuestrasRankeadas] WITH (NOLOCK)
    CROSS APPLY (VALUES
        ('Fe',Fe_LP),('PQ',PQ_LP),('Cr',Cr_LP),('Ni',Ni_LP),('Cu',Cu_LP),('Pb',Pb_LP),('Sn',Sn_LP),
        ('Al',Al_LP),('Si',Si_LP),('Ca',Ca_LP),('Zn',Zn_LP),('Na',Na_LP),('K',K_LP),('Mg',Mg_LP),('TBN',TBN_LP)
    ) p(Parametro, LP)
    WHERE rn_recencia = 1
)
SELECT Parametro,
    SUM(CASE WHEN CompTipo='TRACCION'   AND LP IS NOT NULL THEN 1 ELSE 0 END) AS MT_conLP,
    SUM(CASE WHEN CompTipo='RUEDA'      AND LP IS NOT NULL THEN 1 ELSE 0 END) AS RD_conLP,
    SUM(CASE WHEN CompTipo='HIDRAULICO' AND LP IS NOT NULL THEN 1 ELSE 0 END) AS SH_conLP,
    SUM(CASE WHEN CompTipo='MOTOR'      AND LP IS NOT NULL THEN 1 ELSE 0 END) AS MODI_conLP
FROM s GROUP BY Parametro ORDER BY Parametro;

-- (3) C2 - cuantas alertas FALSAS estamos mostrando hoy por el sentido invertido de los aditivos.
--     Un aditivo por ENCIMA de su limite hoy se marca como fuera de limite; deberia marcarse por DEBAJO.
SELECT p.Parametro,
       SUM(CASE WHEN p.Valor > p.LP THEN 1 ELSE 0 END) AS Hoy_marcados_por_ARRIBA_falsos,
       SUM(CASE WHEN p.Valor < p.LP THEN 1 ELSE 0 END) AS Deberian_marcarse_por_ABAJO
FROM [dbo].[vw_MuestrasRankeadas] WITH (NOLOCK)
CROSS APPLY (VALUES
    ('Ca',Ca_ppm,Ca_LP),('Zn',Zn_ppm,Zn_LP),('Mg',Mg_ppm,Mg_LP),('P',P_ppm,NULL),('TBN',TBN,TBN_LP)
) p(Parametro, Valor, LP)
WHERE rn_recencia = 1 AND p.Valor IS NOT NULL AND p.LP IS NOT NULL
GROUP BY p.Parametro ORDER BY p.Parametro;
-- Da la magnitud del problema C2: cuantas celdas cambian de estado al corregir el sentido.
-- ⚠ 'P' va con LP NULL a proposito: hoy el mapa le tiene 240 HARDCODEADO en vez de leer s.P_LP. Confirmar
--    con el Excel (MT Antapaccay: P LP=280 / LC=240) antes de tocarlo.

-- RESULTADOS BLOQUE 100 (24/09):
-- (1) TODOS los 18 parametros tienen dato en los 4 tipos de componente (MT ~640-654, RD ~249-267,
--     SH ~262-297, MODI ~275-302). Ningun 0 -> no se puede podar el formato por 'no se mide aqui';
--     el corte de filas vacias (C3) tiene que ser POR MUESTRA, no por componente.
-- (2) Los LIMITES si son especificos por componente, y eso importa para el formato:
--     TBN -> solo MODI (103); MT/RD/SH en 0.    Mg -> solo RD (88) y SH (18).
--     Zn  -> MT 186, RD 88, SH 18, MODI 0.      Ca -> MT 186, RD 88, SH 18, MODI 0.
--     Sn  -> MODI 0.   Fe/Cr/Cu/Si -> cobertura pareja en los 4.
-- (3) MAGNITUD DE C2 -- y corrige la lectura inicial:
--     Ca 63 por arriba / 223 por ABAJO    Zn 44 / 214    Mg 35 / 64    TBN 101 / 1
--     ⚠ Ca, Zn y Mg tienen Inf=1 en el mapa: HOY NO SE JUZGAN. Entonces el problema NO es que marquemos
--       falsos criticos con ellos, es que ~500 muestras con el aditivo AGOTADO (223 Ca + 214 Zn + 64 Mg
--       por debajo de su limite) no se marcan en absoluto. El sintoma es SILENCIO, no falsa alarma.
--     TBN ya tiene Inv=1 y su reparto 101/1 es coherente.

-- ==== BLOQUE 101 - Verificar el caso del Fosforo antes de llamarlo falso positivo ====
-- En /tendenciadet 3161 MT RH el P aparece con 1 marca de 'fuera de limite' y el analisis lo explica como
-- 'valor critico 997.0 ppm, muy por encima del limite (240)'. Con Inv=1 eso seria al reves.
-- Dos posibilidades, y NO son la misma cosa:
--   (a) la marca es CORRECTA (una muestra cayo por DEBAJO de 240) y lo que esta mal es el TEXTO del
--       analisis -> el arreglo va en el PROMPT (bloque E), no en la vista;
--   (b) la marca es incorrecta -> el arreglo va en la vista (bloque C2).
-- ⚠ CORREGIDO 24/09: vw_TendenciaElemento NO tiene compAbbr (si tiene Compartimiento y CompTipo)
--    -> Msg 207. Columnas cruzadas contra docs/arquitectura/ESQUEMA_BD.xlsx.
SELECT te.Equipo, te.Compartimiento, te.Parametro, te.LP, te.Inf,
       te.d1, te.d2, te.d3, te.d4, te.d5, te.d6, te.NVecesObs
FROM [dbo].[vw_TendenciaElemento] te
WHERE te.Equipo = 'CA3161' AND te.Compartimiento LIKE '%TRACCION%RH' AND te.Parametro IN ('P','Zn','Ca');
-- Si algun d1..d6 esta por DEBAJO del LP -> caso (a): la marca esta bien y falla la explicacion.
-- Si TODOS estan por encima y aun asi NVecesObs > 0 -> caso (b): falla la vista.

-- (2) El dato crudo, por si el 997 que cita el analisis existe o se lo invento.
SELECT TOP 8 FechaMuestreo, P_ppm, Zn_ppm, Ca_ppm, CM
FROM [dbo].[vw_MuestrasRankeadas] WITH (NOLOCK)
WHERE Equipo = 'CA3161' AND Compartimiento LIKE '%TRACCION%RH'
ORDER BY FechaMuestreo DESC;
-- ⚠ Si 997 no aparece en ninguna fila, el problema es el PROMPT inventando cifras -> bloque E.
--
-- RESULTADO (24/09) -- RESUELTO, y es el caso (a):
--   El 997.040 SI existe: 2026-09-17, CM=ADI. El analisis NO invento la cifra. Descartada esa sospecha.
--   Las 6 muestras de la ventana y su P: 05-Jun 262.06 | 27-Jun 290.81 | 16-Jul 293.78 |
--   10-Aug 210.18 | 26-Aug 332.93 | 17-Sep 997.04.
--   Con LP=240 e Inv=1, la UNICA por debajo es 210.18 (10-Aug) -> NVecesObs = 1. COINCIDE con lo mostrado.
--   => LA VISTA ESTA BIEN. La marca corresponde a la muestra BAJA, que es lo correcto para un aditivo.
--      Lo que falla es el TEXTO del analisis, que atribuye la marca al 997 'muy por encima del limite'.
--      Es exactamente al reves. -> El arreglo va en el BLOQUE E (prompt), NO en C2.
--   ⚠ Leccion: el sintoma 'sale una marca rara' apuntaba a la vista y era el prompt. Sin este bloque
--      habriamos 'arreglado' una vista que funcionaba.


-- ==== BLOQUE 102 - C4 REPLANTEADO: [Eqpcare].[lc] YA ES el Excel; el problema es el EMPAREJAMIENTO ====
-- Hallazgo del BLOQUE 91 (24/09): lc tiene las MISMAS columnas y los MISMOS valores que la hoja BD_LC del
-- Excel de gerencia (FIERRO - LP, ..., MODELO, TIPO). O sea que los limites NO faltan en la BD: ya estan.
-- Y vw_LimitesPorComponente SI agrupa por Proyecto + MODELO + CompTipo, o sea que el modelo tampoco se
-- estaba ignorando. Entonces, por que Cerro Verde TRACCION solo tenia LP en 16 de 128 equipos (BLOQUE 83)?
-- HIPOTESIS: el modelo NO EMPAREJA como texto entre EquipmentFleet.Model y lc.MODELO.
-- (1) Los dos vocabularios de modelo, lado a lado.
SELECT N'lc (limites)' AS Origen, UPPER(LTRIM(RTRIM([MODELO]))) AS Modelo, COUNT(*) AS Filas
FROM [Eqpcare].[lc] GROUP BY UPPER(LTRIM(RTRIM([MODELO])))
UNION ALL
SELECT N'EquipmentFleet (equipos)', UPPER(LTRIM(RTRIM(EF.[Model]))), COUNT(*)
FROM [Mine].[EquipmentFleet] EF GROUP BY UPPER(LTRIM(RTRIM(EF.[Model])))
ORDER BY Modelo, Origen;
-- Si un modelo aparece en un origen y no en el otro (o escrito distinto: '730E-10' vs '730E10' vs '730E'),
-- ese es el motivo de los limites 'faltantes'. No falta el dato: no se encuentra.

-- (2) Que combinaciones REALES de la flota se quedan sin fila de limites. Esta es la lista de trabajo.
WITH flota AS (
    SELECT DISTINCT
        UPPER(LTRIM(RTRIM(MP.[Name])))  AS ProyKey,
        UPPER(LTRIM(RTRIM(EF.[Model]))) AS ModeloKey,
        CASE
            WHEN LD.[Compartimiento] LIKE '%TRACCION%'    THEN 'TRACCION'
            WHEN LD.[Compartimiento] LIKE '%HIDRAUL%'     THEN 'HIDRAULICO'
            WHEN LD.[Compartimiento] LIKE '%RUEDA%'       THEN 'RUEDA'
            WHEN LD.[Compartimiento] LIKE '%MANDO%'       THEN 'MANDO'
            WHEN LD.[Compartimiento] LIKE '%TRANSMISION%' THEN 'TRANSMISION'
            WHEN LD.[Compartimiento] LIKE '%MOTOR%'       THEN 'MOTOR'
            ELSE 'OTRO' END AS CompTipo
    FROM [Oil].[LaboratoryData] LD WITH (NOLOCK)
    INNER JOIN [Mine].[MiningEquipment] ME ON ME.[Id] = LD.[MiningEquipmentId]
    INNER JOIN [Mine].[MiningProject]   MP ON MP.[Id] = ME.[MiningProjectId]
    INNER JOIN [Mine].[EquipmentFleet]  EF ON EF.[Id] = ME.[EquipmentFleetId]
    WHERE LD.[FechaMuestreo] >= DATEADD(MONTH,-12,GETDATE())
)
SELECT f.ProyKey, f.ModeloKey, f.CompTipo,
       CASE WHEN l.ProyKey IS NULL THEN N'SIN LIMITES' ELSE N'ok' END AS Estado
FROM flota f
LEFT JOIN [dbo].[vw_LimitesPorComponente] l
       ON l.ProyKey = f.ProyKey AND l.ModeloKey = f.ModeloKey AND l.CompTipo = f.CompTipo
ORDER BY Estado DESC, f.ProyKey, f.ModeloKey, f.CompTipo;
-- Cada fila 'SIN LIMITES' es una combinacion de la flota viva sin limite aplicable. Mirarlas con (1) al
-- lado dice si es un problema de ESCRITURA del modelo (se arregla normalizando el emparejamiento) o si de
-- verdad gerencia nunca cargo esos limites (ahi si hace falta el fallback, o preguntar).

-- (3) Sanidad: cuantas filas tiene lc frente a las 64 del Excel.
SELECT COUNT(*) AS Filas_lc, COUNT(DISTINCT [Proyecto]) AS Proyectos, COUNT(DISTINCT [MODELO]) AS Modelos
FROM [Eqpcare].[lc];
-- Si da ~64 y los mismos proyectos, entonces vw_LimitesFallback es REDUNDANTE y NO hay que desplegarla:
-- el trabajo de C4 pasa a ser arreglar el emparejamiento, no cargar datos.
-- RESULTADOS BLOQUE 102 (24/09) -- concluyente:
-- (3) lc tiene EXACTAMENTE 64 filas, 5 proyectos, 7 modelos == las 64 filas del Excel.
--     => vw_LimitesFallback seria una COPIA EXACTA. No aporta ni una fila. SE DESCARTA (no desplegar).
-- (1) Vocabularios de modelo: lc tiene 7 ('730E-', 980E, D475A, D65ROC, PC1250, PV351, WE2350) y
--     EquipmentFleet ~32. Hay DOS causas distintas de 'sin limites', y conviene no confundirlas:
--     (a) DESAJUSTE DE TEXTO: lc dice '730E-' y la flota dice '730E'. Mismo modelo, escrito distinto
--         -> Cerro Verde 730E queda sin limites AUNQUE EL DATO EXISTE. Esto lo arreglamos nosotros.
--     (b) AUSENCIA REAL: 930E, HD1500, WA900, PC7000, WD900... no estan en lc en absoluto, y
--         CUAJONE/TOQUEPALA no tienen NINGUNA fila (ni con 980E, que si existe para otros proyectos).
--         Esto NO lo arregla el fallback: el Excel tampoco los tiene. Es carga pendiente de gerencia.
-- (2) 45 combinaciones de la flota viva SIN LIMITES contra 25 'ok'.

-- ==== BLOQUE 103 - C4: arreglar el desajuste de texto del modelo (lo unico que depende de nosotros) ====
-- (1) El valor EXACTO de MODELO en ambos lados, con delimitadores, para ver que estamos emparejando.
SELECT DISTINCT N'[' + [MODELO] + N']' AS Modelo_lc_exacto, LEN([MODELO]) AS Largo
FROM [Eqpcare].[lc] ORDER BY Modelo_lc_exacto;

SELECT DISTINCT N'[' + EF.[Model] + N']' AS Modelo_flota_exacto, LEN(EF.[Model]) AS Largo
FROM [Mine].[EquipmentFleet] EF
WHERE EF.[Model] LIKE '730%' OR EF.[Model] LIKE '980%'
ORDER BY Modelo_flota_exacto;
-- Confirmar si es un guion de mas, un sufijo ('730E-10') o espacios.

-- (2) Cuanto RECUPERA normalizar el emparejamiento. Se mide ANTES de tocar la vista.
--     Normalizacion propuesta: quedarse con el prefijo anterior al primer '-'.
WITH flota AS (
    SELECT DISTINCT UPPER(LTRIM(RTRIM(MP.[Name]))) AS ProyKey,
           UPPER(LTRIM(RTRIM(EF.[Model]))) AS ModeloFlota,
           CASE WHEN LD.[Compartimiento] LIKE '%TRACCION%' THEN 'TRACCION'
                WHEN LD.[Compartimiento] LIKE '%HIDRAUL%'  THEN 'HIDRAULICO'
                WHEN LD.[Compartimiento] LIKE '%RUEDA%'    THEN 'RUEDA'
                WHEN LD.[Compartimiento] LIKE '%MANDO%'    THEN 'MANDO'
                WHEN LD.[Compartimiento] LIKE '%TRANSMISION%' THEN 'TRANSMISION'
                WHEN LD.[Compartimiento] LIKE '%MOTOR%'    THEN 'MOTOR' ELSE 'OTRO' END AS CompTipo
    FROM [Oil].[LaboratoryData] LD WITH (NOLOCK)
    INNER JOIN [Mine].[MiningEquipment] ME ON ME.[Id] = LD.[MiningEquipmentId]
    INNER JOIN [Mine].[MiningProject]   MP ON MP.[Id] = ME.[MiningProjectId]
    INNER JOIN [Mine].[EquipmentFleet]  EF ON EF.[Id] = ME.[EquipmentFleetId]
    WHERE LD.[FechaMuestreo] >= DATEADD(MONTH,-12,GETDATE())
), lim AS (
    SELECT DISTINCT ProyKey, ModeloKey, CompTipo FROM [dbo].[vw_LimitesPorComponente]
)
SELECT
    SUM(CASE WHEN EXISTS (SELECT 1 FROM lim l
                          WHERE l.ProyKey = f.ProyKey AND l.ModeloKey = f.ModeloFlota AND l.CompTipo = f.CompTipo)
             THEN 1 ELSE 0 END) AS Emparejan_HOY,
    SUM(CASE WHEN EXISTS (SELECT 1 FROM lim l
                          WHERE l.ProyKey = f.ProyKey AND l.CompTipo = f.CompTipo
                            AND LEFT(l.ModeloKey, CHARINDEX('-', l.ModeloKey + '-') - 1)
                              = LEFT(f.ModeloFlota, CHARINDEX('-', f.ModeloFlota + '-') - 1))
             THEN 1 ELSE 0 END) AS Emparejarian_NORMALIZANDO,
    COUNT(*) AS Total_combinaciones
FROM flota f;
-- Si 'Emparejarian_NORMALIZANDO' sube claramente, el fix vale y va en vw_LimitesPorComponente.
-- Si sube poco, NO tocar una vista que funciona por un caso aislado.

-- (3) LA LISTA PARA GERENCIA: que limites faltan DE VERDAD (ya descontado el desajuste de texto).
--     Es lo unico que nosotros no podemos resolver, y para ellos es accionable tal cual.
WITH flota AS (
    SELECT DISTINCT UPPER(LTRIM(RTRIM(MP.[Name]))) AS Proyecto,
           UPPER(LTRIM(RTRIM(EF.[Model]))) AS Modelo,
           CASE WHEN LD.[Compartimiento] LIKE '%TRACCION%' THEN 'TRACCION'
                WHEN LD.[Compartimiento] LIKE '%HIDRAUL%'  THEN 'HIDRAULICO'
                WHEN LD.[Compartimiento] LIKE '%RUEDA%'    THEN 'RUEDA'
                WHEN LD.[Compartimiento] LIKE '%MANDO%'    THEN 'MANDO'
                WHEN LD.[Compartimiento] LIKE '%TRANSMISION%' THEN 'TRANSMISION'
                WHEN LD.[Compartimiento] LIKE '%MOTOR%'    THEN 'MOTOR' ELSE 'OTRO' END AS CompTipo,
           ME.[Code] AS Equipo
    FROM [Oil].[LaboratoryData] LD WITH (NOLOCK)
    INNER JOIN [Mine].[MiningEquipment] ME ON ME.[Id] = LD.[MiningEquipmentId]
    INNER JOIN [Mine].[MiningProject]   MP ON MP.[Id] = ME.[MiningProjectId]
    INNER JOIN [Mine].[EquipmentFleet]  EF ON EF.[Id] = ME.[EquipmentFleetId]
    WHERE LD.[FechaMuestreo] >= DATEADD(MONTH,-12,GETDATE())
)
SELECT f.Proyecto, f.Modelo, f.CompTipo, COUNT(DISTINCT f.Equipo) AS Equipos_afectados
FROM flota f
WHERE NOT EXISTS (
    SELECT 1 FROM [dbo].[vw_LimitesPorComponente] l
    WHERE l.ProyKey = f.Proyecto AND l.CompTipo = f.CompTipo
      AND LEFT(l.ModeloKey, CHARINDEX('-', l.ModeloKey + '-') - 1)
        = LEFT(f.Modelo, CHARINDEX('-', f.Modelo + '-') - 1))
GROUP BY f.Proyecto, f.Modelo, f.CompTipo
ORDER BY Equipos_afectados DESC, f.Proyecto, f.Modelo;
-- Ordenado por equipos afectados: la primera fila es la que deja mas flota sin evaluar.


-- ==== BLOQUE 104 - C1/C2: desplegar vw_FormatoParametro y comprobar que dice lo que debe ====
-- Archivo: docs/arquitectura/DDL_vw_FormatoParametro.sql (120 filas: 4 formatos x ~17-18 parametros).
-- Es SOLO una tabla de referencia: no cambia ninguna salida todavia. Se despliega primero y se verifica,
-- y recien despues se engancha en las vistas (paso siguiente de C).
-- (1) Que el formato coincida con el Excel, componente por componente.
SELECT CompTipo, Grupo, COUNT(*) AS Parametros,
       STRING_AGG(Parametro, ', ') WITHIN GROUP (ORDER BY Orden) AS EnOrden
FROM [dbo].[vw_FormatoParametro]
GROUP BY CompTipo, Grupo, GrupoOrden
ORDER BY CompTipo, GrupoOrden;
-- Esperado (contra las hojas del Excel):
--   TRACCION  Aditivos: P, B          |  Contaminacion: Si, Na, K, Ca, Zn, Mg   <- Ca/Zn CONTAMINANTES
--   RUEDA     Aditivos: Ca, Zn, P, Mg, B  |  Contaminacion: Si, Na, K           <- Ca/Zn ADITIVOS
--   HIDRAULICO  igual que RUEDA
--   MOTOR     Salud: V100, TBN        |  Aditivos: Ca, Zn, P, Mg, B
--   Desgaste en los 4: Fe, PQ, Cr, Ni, Cu, Pb, Sn, Al (RUEDA/HIDRAULICO ponen Al tercero).

-- (2) EL CRUCE QUE IMPORTA: que el sentido del limite que trae el DATO coincida con el grupo del FORMATO.
--     Un aditivo deberia venir con LP > LC (se agota) y un contaminante con LP < LC.
SELECT f.CompTipo, f.Grupo, f.Parametro,
       SUM(CASE WHEN l.LP > l.LC THEN 1 ELSE 0 END) AS Filas_INVERTIDAS,
       SUM(CASE WHEN l.LP < l.LC THEN 1 ELSE 0 END) AS Filas_normales,
       CASE WHEN f.Grupo = 'Aditivos'      AND SUM(CASE WHEN l.LP > l.LC THEN 1 ELSE 0 END) = 0 THEN N'⚠ aditivo SIN limite invertido'
            WHEN f.Grupo = 'Contaminacion' AND SUM(CASE WHEN l.LP > l.LC THEN 1 ELSE 0 END) > 0 THEN N'⚠ contaminante CON limite invertido'
            ELSE N'ok' END AS Coherencia
FROM [dbo].[vw_FormatoParametro] f
JOIN (
    SELECT CompTipo, p.Parametro, p.LP, p.LC
    FROM [dbo].[vw_LimitesPorComponente]
    CROSS APPLY (VALUES
        ('Fe',Fe_LP,Fe_LC),('Cr',Cr_LP,Cr_LC),('Ni',Ni_LP,Ni_LC),('Cu',Cu_LP,Cu_LC),('Pb',Pb_LP,Pb_LC),
        ('Sn',Sn_LP,Sn_LC),('Al',Al_LP,Al_LC),('Si',Si_LP,Si_LC),('Ca',Ca_LP,Ca_LC),('Zn',Zn_LP,Zn_LC),
        ('Na',Na_LP,Na_LC),('K',K_LP,K_LC),('Mg',Mg_LP,Mg_LC),('PQ',PQ_LP,PQ_LC)
    ) p(Parametro, LP, LC)
    WHERE p.LP IS NOT NULL AND p.LC IS NOT NULL
) l ON l.CompTipo = f.CompTipo AND l.Parametro = f.Parametro
GROUP BY f.CompTipo, f.Grupo, f.Parametro
HAVING SUM(CASE WHEN l.LP > l.LC THEN 1 ELSE 0 END) > 0 OR f.Grupo = 'Aditivos'
ORDER BY Coherencia DESC, f.CompTipo, f.Parametro;
-- Esperado: todo 'ok'. Cualquier ⚠ es una contradiccion entre los dos Excel de gerencia y hay que
-- preguntarla ANTES de cambiar como se evalua el estado. ⛔ No resolverla por nuestra cuenta.

-- (3) Cobertura: parametros que el formato pide para un componente pero que ese componente nunca trae.
SELECT f.CompTipo, f.Parametro
FROM [dbo].[vw_FormatoParametro] f
WHERE NOT EXISTS (
    SELECT 1 FROM [dbo].[vw_TendenciaElemento] te
    WHERE te.CompTipo = f.CompTipo AND te.Parametro = f.Parametro)
ORDER BY f.CompTipo, f.Parametro;
-- Esperado: 0 filas (el BLOQUE 100 mostro que los 18 parametros tienen dato en los 4 componentes).
-- Si sale alguno, es una fila de formato que nunca se va a llenar: quitarla del mapa.
--
-- RESULTADOS BLOQUE 104 (24/09):
-- (1) El formato coincide con el Excel, componente por componente. TRACCION: Aditivos = P, B y
--     Contaminacion = Si, Na, K, Ca, Zn, Mg (Ca/Zn CONTAMINANTES). RUEDA/HIDRAULICO/MANDO/TRANSMISION/
--     OTRO: Aditivos = Ca, Zn, P, Mg, B. MOTOR: Salud = V100, TBN. Desgaste = 8 en los 4.
-- (3) 0 filas: ningun parametro del formato se queda sin dato. El mapa no tiene filas muertas.
-- (2) EL CRUCE, y da una conclusion de diseño distinta a la que yo esperaba:
--     ok en Aditivos de HIDRAULICO (Ca, Mg, Zn) y RUEDA (Ca, Mg, Zn) -> el grupo y el dato coinciden.
--     ⚠ OTRO / Contaminacion / K y Na: 1 fila invertida de 3.
--     Ademas, con recuento mixto pero sin marcar (mi CASE no cubria 'Desgaste'):
--       OTRO Al 1/3, OTRO Cr 1/1, OTRO Cu 1/2, TRACCION Pb 1/3.
--     DIAGNOSTICO de esas rarezas (revisado contra el Excel original):
--       - En el archivo de gerencia hay UNA sola inversion no-aditiva: CERRO VERDE / MOTOR DE TRACCION LH
--         / 980E / Pb LP=2 LC=1. Es el typo ya conocido (el RH trae 1/2). Explica 'TRACCION Pb 1/3'.
--       - Las de 'OTRO' NO son del archivo: las fabrica vw_LimitesPorComponente, que colapsa componentes
--         distintos (PTO, DAMPER, CAJA GIRO, COMPRESOR...) en 'OTRO' y agrega con MIN(). El LP puede venir
--         de un componente y el LC de otro -> inversion artificial.
--         ⚠ INOFENSIVO EN PRODUCCION: el DDL ya excluye 'OTRO' del join de limites ('AND m.CompTipo <>
--         ''OTRO''', guard anti-colision). Nunca se aplica ese limite a nadie.
-- => DECISION DE DISEÑO: Inv NO se deriva de 'LP > LC'. Se deduce del GRUPO (Aditivos + TBN), que es
--    estable y no importa ni el typo del archivo ni el artefacto de 'OTRO'. El cruce con el dato queda
--    como AUDITORIA, que es justo para lo que sirvio: encontro los dos defectos.


-- ==== BLOQUE 105 - C1/C2: enganchar vw_TendenciaElemento al formato (1er consumidor de 4) ====
-- Cambio en DDL_vistas.sql: el CTE 'u' de vw_TendenciaElemento ya NO lleva su propia lista de
-- (Grupo, Orden, Inf, Inv). Ahora hace INNER JOIN a vw_FormatoParametro por CompTipo + Parametro.
-- Consecuencias esperadas, y hay que verlas las tres:
--   (a) El ORDEN y los GRUPOS cambian y pasan a depender del componente (etiquetas del Excel:
--       Salud / Aditivos / Contaminacion / Desgaste, en vez de Salud / Adit. / Contam. / Met. Desg.).
--   (b) En RUEDA/HIDRAULICO/MOTOR, Ca/Zn/Mg dejan de ser informativos y se juzgan INVERTIDOS
--       (alerta cuando el aditivo BAJA). En TRACCION siguen como contaminantes informativos.
--   (c) El INNER JOIN filtra: un parametro que el formato no incluya para ese componente desaparece.
-- (1) Smoke test primero.
SELECT v.name AS Vista, d.error_message AS Error
FROM sys.views v
OUTER APPLY sys.dm_exec_describe_first_result_set(N'SELECT * FROM [dbo].' + QUOTENAME(v.name), NULL, 0) d
WHERE SCHEMA_NAME(v.schema_id) = 'dbo' AND v.name LIKE 'vw_%' AND d.error_message IS NOT NULL
ORDER BY v.name;

-- (2) Que NO se haya perdido ni ganado ningun parametro por componente.
SELECT CompTipo, COUNT(DISTINCT Parametro) AS Parametros,
       STRING_AGG(CONVERT(nvarchar(max), Parametro), ', ') WITHIN GROUP (ORDER BY Orden) AS EnOrden
FROM (SELECT DISTINCT CompTipo, Parametro, Orden FROM [dbo].[vw_TendenciaElemento]) z
GROUP BY CompTipo ORDER BY CompTipo;
-- Esperado: TRACCION 17, RUEDA 17, HIDRAULICO 17, MOTOR 18, y el orden del Excel.

-- (3) (b) EL CAMBIO DE FONDO: cuantas alertas NUEVAS aparecen por aditivo agotado, y donde.
--     Antes del cambio eran 0 (Ca/Zn/Mg eran informativos en todos los componentes).
-- ⚠ CORREGIDO 24/09: vw_TendenciaElemento expone Inf pero NO Inv (es interno del CTE). Se lee de
--    vw_FormatoParametro, que es donde vive. Columnas cruzadas contra docs/arquitectura/ESQUEMA_BD.xlsx.
SELECT te.CompTipo, te.Parametro, COUNT(*) AS Equipos_con_aditivo_bajo
FROM [dbo].[vw_TendenciaElemento] te
JOIN [dbo].[vw_FormatoParametro] f ON f.CompTipo = te.CompTipo AND f.Parametro = te.Parametro
WHERE f.Inv = 1 AND f.Inf = 0 AND te.NVecesObs > 0 AND te.Parametro IN ('Ca','Zn','Mg')
GROUP BY te.CompTipo, te.Parametro ORDER BY Equipos_con_aditivo_bajo DESC;
-- El BLOQUE 100 estimo ~500 muestras con el aditivo por debajo. Aqui se ve cuantos EQUIPOS quedan
-- marcados y en que componentes. ⚠ Si el numero es enorme, conviene avisar al area antes de publicarlo:
-- pasar de 0 alertas a cientos de un dia para otro necesita contexto, no es un bug pero lo parece.

-- (4) NO-REGRESION de traccion: ahi Ca/Zn siguen siendo contaminantes informativos, no deben marcar.
SELECT COUNT(*) AS Deberia_ser_0
FROM [dbo].[vw_FormatoParametro]
WHERE CompTipo = 'TRACCION' AND Parametro IN ('Ca','Zn','Mg') AND Inv = 1;

-- (5) La salida real, para mirarla con ojos: el mismo equipo de siempre.
SELECT MD FROM [dbo].[vw_TendenciaMD] WHERE Equipo = 'CA3160' AND compAbbr = 'MT LH';
-- Verificar: grupos en orden Salud / Aditivos / Contaminacion / Desgaste, con los parametros del Excel
-- para TRACCION (Aditivos = P, B; Contaminacion = Si, Na, K, Ca, Zn, Mg; Desgaste = los 8).
--
-- RESULTADOS BLOQUE 105 (24/09):
--   (1) smoke test 0 filas.  (2) TRACCION 17 / RUEDA 17 / HIDRAULICO 17 / MOTOR 18, en el orden del Excel.
--   (3) y (4) fallaron: 'Invalid column name Inv' -> vw_TendenciaElemento expone Inf pero NO Inv.
--       Corregido arriba leyendo Inv de vw_FormatoParametro.
--   (5) 🔴 BUG ENCONTRADO Y CORREGIDO: los encabezados de grupo salian DESCOLOCADOS
--       (P y B bajo '**Salud**', Fe bajo '**Contaminacion**', '**Desgaste**' dos veces).
--       Causa: vw_TendenciaMD emitia el encabezado en POSICIONES FIJAS ('Orden IN (1,9,14,17)'), que
--       correspondian al mapa viejo de 18 parametros iguales para todos los componentes. Con el formato
--       por componente esos cortes ya no existen.
--       Fix: el encabezado se emite en la PRIMERA FILA DE CADA GRUPO
--       (ROW_NUMBER() OVER (PARTITION BY Equipo, Compartimiento, Grupo ORDER BY Orden) = 1).
--       ⚠ Los otros 3 sitios con 'IN (1,9,14,17)' (vw_DiagnosticoMD x2, vw_CondicionMT_MD) leen de
--         vw_DiagnosticoEquipo, que TODAVIA tiene el mapa viejo: ahi la condicion sigue siendo correcta.
--         Hay que cambiarlos EN LA MISMA PASADA en que se los enganche al formato, no antes.

-- ==== BLOQUE 106 - Re-verificar vw_TendenciaMD tras el fix de encabezados ====
SELECT MD FROM [dbo].[vw_TendenciaMD] WHERE Equipo = 'CA3160' AND compAbbr = 'MT LH';
-- Esperado para TRACCION, en este orden y con estos encabezados:
--   **Salud**          V100
--   **Aditivos**       P, B
--   **Contaminacion**  Si, Na, K, Ca, Zn, Mg
--   **Desgaste**       Fe, PQ, Cr, Ni, Cu, Pb, Sn, Al
-- ⛔ Ningun grupo repetido y ningun parametro bajo el grupo equivocado.

-- (2) Y un componente con OTRO formato, para ver que el orden cambia de verdad segun el componente.
SELECT MD FROM [dbo].[vw_TendenciaMD] WHERE Equipo = 'CA3160' AND compAbbr = 'Sist. Hidr.';
-- Esperado (HIDRAULICO): **Aditivos** Ca, Zn, P, Mg, B  |  **Contaminacion** Si, Na, K
--   y en Desgaste el Al va TERCERO (Fe, PQ, Al, Cr, Ni, Cu, Pb, Sn), como en su hoja del Excel.


-- ==== BLOQUE 107 - C: el formato COMPLETO del Excel (incluye lo que la BD no mide) ====
-- Pedido del usuario (24/09): 'todos esos campos han de aparecer, como minimo en MT'. vw_FormatoParametro
-- pasa de 120 a 175 filas: ahora lista los 23/25/25/27 parametros de las 4 hojas, tambien los que no
-- tenemos (V40, TAN, Oxidacion, Sulfatacion, Nitracion, Mo, Agua, Hollin, Diesel, Refrigerante, ISO 4/6/14).
-- Esos salen con '—': su ausencia tambien es informacion para el area.
-- El CTE 'u' de vw_TendenciaElemento ahora recorre el FORMATO (INNER JOIN) y busca el valor con OUTER
-- APPLY, en vez de recorrer los valores. Ese es el 'if else' por componente: lo decide la vista de formato.
-- (1) Smoke test.
SELECT v.name AS Vista, d.error_message AS Error
FROM sys.views v
OUTER APPLY sys.dm_exec_describe_first_result_set(N'SELECT * FROM [dbo].' + QUOTENAME(v.name), NULL, 0) d
WHERE SCHEMA_NAME(v.schema_id) = 'dbo' AND v.name LIKE 'vw_%' AND d.error_message IS NOT NULL
ORDER BY v.name;

-- (2) El formato, ahora completo y contrastable contra las hojas del Excel una por una.
SELECT CompTipo, Grupo, COUNT(*) AS N,
       STRING_AGG(Parametro + CASE WHEN Disponible = 0 THEN N'*' ELSE N'' END, ', ')
           WITHIN GROUP (ORDER BY Orden) AS EnOrden
FROM [dbo].[vw_FormatoParametro]
GROUP BY CompTipo, Grupo, GrupoOrden ORDER BY CompTipo, GrupoOrden;
-- (* = la BD no lo mide). Esperado por hoja: TRACCION 23 | RUEDA 25 | HIDRAULICO 25 | MOTOR 27.

-- (3) Que la tabla real muestre TODAS las filas del formato, con '—' en las que no tenemos.
SELECT MD FROM [dbo].[vw_TendenciaMD] WHERE Equipo = 'CA3160' AND compAbbr = 'MT LH';
-- Esperado (hoja MT, 23 filas):
--   **Salud**            V100, V40*
--   **Aditivos**         P, B
--   **Contaminacion**    Si, Na, K, Ca, Zn, Mg, Mo*, Agua*
--   **Desgaste**         Fe, PQ, Cr, Ni, Cu, Pb, Sn, Al
--   **Codigo Limpieza**  ISO>4*, ISO>6*, ISO>14*
-- Las marcadas * deben aparecer con '—' en todas las fechas.

-- (4) Y el motor diesel, que es el formato mas largo (27).
SELECT MD FROM [dbo].[vw_TendenciaMD] WHERE Equipo = 'CA3160' AND compAbbr = 'Motor';
-- Esperado: Salud con V100, V40*, TBN, Oxidacion*, Sulfatacion*, Nitracion*; Contaminacion con
-- Si, Na, K, Hollin*, Diesel*, Agua*, Refrigerante*; y SIN Codigo Limpieza (su hoja no lo tiene).

-- (5) Tamaño: la tabla crece de 17 a 23-27 filas. Confirmar que no se acerca al techo del canal.
SELECT compAbbr, LEN(MD) AS Largo_MD FROM [dbo].[vw_TendenciaMD] WHERE Equipo = 'CA3160' ORDER BY Largo_MD DESC;
-- Muy lejos de 28 000 = ok. Si algun componente se dispara, hay que decidir si las filas sin dato se
-- muestran igual (pedido actual) o se cortan (C3). Son criterios OPUESTOS y conviene zanjarlo con el area.


-- ==== BLOQUE 108 - C: vw_UltimoAnalisisMD pasa al formato (era la unica SIN mapa) ====
-- Su tabla estaba hardcodeada fila por fila (15 filas + 4 encabezados de grupo escritos a mano).
-- Ahora la genera vw_FormatoParametro igual que la tendencia: mismos grupos, mismo orden, mismas filas.
-- Y el chip respeta el sentido del limite: con Inv=1 (aditivos y TBN) la alerta es por DEBAJO.
-- (1) Smoke test.
SELECT v.name AS Vista, d.error_message AS Error
FROM sys.views v
OUTER APPLY sys.dm_exec_describe_first_result_set(N'SELECT * FROM [dbo].' + QUOTENAME(v.name), NULL, 0) d
WHERE SCHEMA_NAME(v.schema_id) = 'dbo' AND v.name LIKE 'vw_%' AND d.error_message IS NOT NULL
ORDER BY v.name;

-- (2) El mismo caso de siempre: debe traer las 23 filas de la hoja MT, no las 15 de antes.
SELECT MD FROM [dbo].[vw_UltimoAnalisisMD] WHERE Equipo = 'CA3160' AND compAbbr = 'MT LH';
-- Esperado: Salud (V100, V40—) / Aditivos (P, B) / Contaminacion (Si, Na, K, Ca, Zn, Mg, Mo—, Agua—) /
--   Desgaste (Fe, PQ, Cr, Ni, Cu, Pb, Sn, Al) / Codigo Limpieza (ISO>4—, ISO>6—, ISO>14—).
-- ⚠ Comparar con la captura anterior: Zn 40.2 debe SEGUIR en rojo (en TRACCION es contaminante, sube = malo).

-- (3) Y un componente donde Zn/Ca SI son aditivos: ahi el chip cambia de sentido.
SELECT MD FROM [dbo].[vw_UltimoAnalisisMD] WHERE Equipo = 'CA3160' AND compAbbr = 'Sist. Hidr.';
-- Esperado: Ca/Zn/Mg bajo **Aditivos**, y su chip aparece cuando el valor esta por DEBAJO del limite.
-- ⛔ Si un aditivo alto sale en rojo, el sentido quedo sin invertir.

-- (4) Que ningun equipo se haya quedado sin tabla por el LEFT JOIN nuevo.
SELECT COUNT(*) AS Filas, SUM(CASE WHEN MD LIKE '%| Fe |%' THEN 0 ELSE 1 END) AS Sin_tabla
FROM [dbo].[vw_UltimoAnalisisMD];
-- Esperado: Sin_tabla = 0.
--
-- RESULTADO (24/09): 1 687 filas, Sin_tabla = 66  -> REGRESION introducida por el cambio.
--   Antes la tabla era hardcodeada y salia siempre; ahora depende de que el CompTipo del equipo exista
--   en vw_FormatoParametro. 66 filas no encuentran formato. Ver BLOQUE 109.

-- ==== BLOQUE 109 - Que CompTipo se quedaron SIN formato (regresion del BLOQUE 108) ====
-- (1) Los CompTipo que existen en los datos vs los que cubre el mapa de formato.
SELECT ISNULL(a.CompTipo, N'(NULL)') AS CompTipo_en_datos,
       COUNT(*) AS Filas,
       CASE WHEN EXISTS (SELECT 1 FROM [dbo].[vw_FormatoParametro] f WHERE f.CompTipo = a.CompTipo)
            THEN N'ok' ELSE N'SIN FORMATO' END AS Estado
FROM [dbo].[vw_UltimoAnalisisAceite] a
GROUP BY a.CompTipo
ORDER BY Estado DESC, Filas DESC;
-- El mapa cubre TRACCION, RUEDA, HIDRAULICO, MOTOR, MANDO, TRANSMISION y OTRO. Si aparece un CompTipo
-- distinto (o NULL), ese es el hueco.

-- (2) Que componentes reales hay detras de esas filas, para saber que formato les corresponde.
SELECT a.CompTipo, a.Compartimiento, COUNT(*) AS Filas
FROM [dbo].[vw_UltimoAnalisisAceite] a
WHERE NOT EXISTS (SELECT 1 FROM [dbo].[vw_FormatoParametro] f WHERE f.CompTipo = a.CompTipo)
GROUP BY a.CompTipo, a.Compartimiento
ORDER BY Filas DESC;
-- ⚠ Si son los Compartimiento NULL / 'nan' / 'M' que ya conociamos (~1 641 muestras de calidad de dato),
--    la respuesta correcta NO es inventarles un formato: es que la fila quede sin tabla y se note.
--    Pero entonces el mensaje tiene que DECIRLO, no devolver una tabla vacia sin explicacion.
--
-- RESULTADOS BLOQUE 109 (24/09): la hipotesis del CompTipo faltante ERA FALSA.
--   (1) Los 7 CompTipo tienen formato: TRACCION 654, MOTOR 307, HIDRAULICO 304, RUEDA 285, OTRO 101,
--       MANDO 28, TRANSMISION 8 = 1 687. Todos 'ok'.
--   (2) 0 filas sin formato.
-- ⚠ Y hay que corregir algo que di por hecho: dije 'regresion introducida por el cambio' SIN medir el
--   antes. No lo verifique. El candidato real es otro: si Compartimiento es NULL, compAbbr queda NULL y
--   el titulo lo concatena SIN ISNULL -> toda la cadena MD se vuelve NULL. Eso ya pasaba ANTES del cambio.
--   Ver BLOQUE 110: primero se comprueba QUE son esas 66 filas, y si son preexistentes o no.

-- ==== BLOQUE 110 - Que son realmente las 66 filas sin tabla ====
-- (1) ¿Es MD NULL, o es una tabla que existe pero sin la fila de Fe?
SELECT SUM(CASE WHEN MD IS NULL THEN 1 ELSE 0 END)                         AS MD_nulo,
       SUM(CASE WHEN MD IS NOT NULL AND MD NOT LIKE '%| Fe |%' THEN 1 ELSE 0 END) AS MD_sin_Fe,
       COUNT(*) AS Total
FROM [dbo].[vw_UltimoAnalisisMD];
-- Si MD_nulo = 66, la causa es la concatenacion con un NULL, no el formato.

-- (2) Quienes son. Si Compartimiento es NULL, compAbbr queda NULL y arrastra toda la cadena.
SELECT TOP 20 Equipo, Proyecto, Compartimiento, compAbbr,
       CASE WHEN MD IS NULL THEN N'MD NULO' ELSE N'ok' END AS Estado
FROM [dbo].[vw_UltimoAnalisisMD]
WHERE MD IS NULL OR MD NOT LIKE '%| Fe |%'
ORDER BY Proyecto, Equipo;

-- (3) ¿Es PREEXISTENTE? La misma condicion sobre una vista que NO toque: si vw_DiagnosticoEquipo tiene
--     las mismas filas con Compartimiento nulo, el problema venia de antes y no lo trajo el formato.
SELECT COUNT(*) AS Filas_con_Compartimiento_nulo
FROM [dbo].[vw_UltimoAnalisisAceite]
WHERE Compartimiento IS NULL OR LTRIM(RTRIM(Compartimiento)) IN ('', 'nan', 'M');
-- Si este numero es ~66, queda claro que es calidad de dato preexistente y NO una regresion.
--
-- RESULTADOS BLOQUE 110 (24/09) -- CONFIRMADO: NO es regresion, es calidad de dato PREEXISTENTE.
--   (1) MD_nulo = 66, MD_sin_Fe = 0, Total = 1 687.
--       Que MD_sin_Fe sea 0 prueba que el enganche al formato funciona en las 1 621 filas validas:
--       ninguna tabla quedo incompleta. Las 66 son MD NULO, otra cosa.
--   (2) Las 66 tienen Compartimiento NULL y compAbbr NULL: HT338 (Antamina), 3104/3105/CA3164
--       (Antapaccay) y K-301..K-316 (Cerro Verde). Son equipos con muestras sin componente registrado.
--   (3) 74 filas con Compartimiento NULL/''/'nan'/'M'. La diferencia con 66 son las 8 que traen 'nan'
--       o 'M': ESAS no son NULL, asi que compAbbr toma ese texto y la tabla si se arma (con 'nan' de
--       nombre de componente, feo pero no nulo). Solo los NULL puros anulan la cadena.
-- CAUSA: el titulo concatena u.compAbbr SIN ISNULL. En T-SQL basta un NULL en una concatenacion para
--   anular TODO el resultado. Preexistente: el titulo nunca estuvo protegido.
-- ⛔ Falla en SILENCIO: MD nulo -> el flujo responde 'no encontre datos', que suena a 'ese equipo no tiene
--   muestras' cuando en realidad la muestra existe y lo que falta es el componente. Mismo patron que el
--   bug del 'mtlh'. Se arregla con un mensaje explicito (ver BLOQUE 111).


-- ==== BLOQUE 111 - Muestras sin componente: que lo DIGAN en vez de fallar en silencio ====
-- Cambio en vw_UltimoAnalisisMD: si Compartimiento es NULL, el MD deja de ser NULL y pasa a decir
-- 'Esta muestra no tiene componente registrado en la base, asi que no se puede evaluar.'
-- No inventa datos ni formato: solo explica por que no hay tabla.
-- (1) Smoke test.
SELECT v.name AS Vista, d.error_message AS Error
FROM sys.views v
OUTER APPLY sys.dm_exec_describe_first_result_set(N'SELECT * FROM [dbo].' + QUOTENAME(v.name), NULL, 0) d
WHERE SCHEMA_NAME(v.schema_id) = 'dbo' AND v.name LIKE 'vw_%' AND d.error_message IS NOT NULL
ORDER BY v.name;

-- (2) Ya no debe quedar ningun MD nulo, y las tablas validas no se tocan.
SELECT SUM(CASE WHEN MD IS NULL THEN 1 ELSE 0 END)                                 AS MD_nulo,
       SUM(CASE WHEN MD LIKE '%no tiene **componente** registrado%' THEN 1 ELSE 0 END) AS Con_mensaje,
       SUM(CASE WHEN MD LIKE '%| Fe |%' THEN 1 ELSE 0 END)                         AS Con_tabla,
       COUNT(*) AS Total
FROM [dbo].[vw_UltimoAnalisisMD];
-- Esperado: MD_nulo = 0, Con_mensaje = 66, Con_tabla = 1 621, Total = 1 687.

-- (3) Como se ve uno de esos casos.
SELECT TOP 1 Equipo, MD FROM [dbo].[vw_UltimoAnalisisMD]
WHERE Compartimiento IS NULL ORDER BY Equipo;

-- (4) NO-REGRESION: el caso normal sigue igual que en el BLOQUE 108.
SELECT MD FROM [dbo].[vw_UltimoAnalisisMD] WHERE Equipo = 'CA3160' AND compAbbr = 'MT LH';


-- ==== BLOQUE 112 - D2: vw_CondicionMT_MD pasa al formato (hoja MT) ====
-- La tabla de /condicionmt es parametros x (MT LH, MT RH). Al ser SOLO traccion, el formato es inequivoco:
-- la hoja MT del Excel. Pasa de 18 filas propias a las 23 de la hoja, con el mismo orden y grupos que
-- /ultimo -- que es lo que pidio Carlos ('mismo formato que /ultimo').
-- Tambien se corrigio su encabezado de grupo: era 'ord IN (1,9,14,17)' (posiciones fijas del mapa viejo)
-- y ahora es la primera fila de cada grupo.
-- (1) Smoke test.
SELECT v.name AS Vista, d.error_message AS Error
FROM sys.views v
OUTER APPLY sys.dm_exec_describe_first_result_set(N'SELECT * FROM [dbo].' + QUOTENAME(v.name), NULL, 0) d
WHERE SCHEMA_NAME(v.schema_id) = 'dbo' AND v.name LIKE 'vw_%' AND d.error_message IS NOT NULL
ORDER BY v.name;

-- (2) La tabla, con los dos lados del MT.
SELECT MD FROM [dbo].[vw_CondicionMT_MD] WHERE Equipo = 'CA3160';
-- Esperado: columnas 'MT LH | MT RH' y las 23 filas de la hoja MT, en este orden:
--   **Salud**            V100, V40—
--   **Aditivos**         P, B
--   **Contaminacion**    Si, Na, K, Ca, Zn, Mg, Mo—, Agua—
--   **Desgaste**         Fe, PQ, Cr, Ni, Cu, Pb, Sn, Al
--   **Codigo Limpieza**  ISO>4—, ISO>6—, ISO>14—
-- ⛔ Ningun grupo repetido, y ningun parametro bajo el grupo equivocado.

-- (3) Que coincida con /ultimo para el MISMO componente: es el pedido textual ('mismo formato que /ultimo').
SELECT N'/ultimo MT LH' AS Fuente, MD FROM [dbo].[vw_UltimoAnalisisMD] WHERE Equipo='CA3160' AND compAbbr='MT LH'
UNION ALL
SELECT N'/condicionmt', MD FROM [dbo].[vw_CondicionMT_MD] WHERE Equipo='CA3160';
-- Las filas y su orden deben ser IGUALES en las dos. Cambian las columnas (una trae LP/LC/Valor y la otra
-- compara LH vs RH), pero la lista de parametros y los grupos no.

-- (4) Que ningun equipo con MT se haya quedado sin tabla.
-- ⚠ CORREGIDO 24/09: la version anterior barria TODA la vista (sin WHERE) y tardo 6:32. Estas vistas se
--    construyen POR EQUIPO; el flujo siempre filtra por uno. Un scan completo no mide nada util y cuesta
--    minutos. Se valida sobre una MUESTRA de equipos.
SELECT Equipo, CASE WHEN MD LIKE '%| Fe |%' THEN N'ok' ELSE N'SIN TABLA' END AS Estado
FROM [dbo].[vw_CondicionMT_MD]
WHERE Equipo IN ('CA3160','CA3161','CA3176','CA3177','HT300','HT305')
ORDER BY Equipo;
-- Esperado: 'ok' en todos.


-- ==== BLOQUE 113 - D1: /diagcompleto con el formato CRUZADO (union de las 4 hojas) ====
-- vw_DiagnosticoMD es parametros x COMPONENTES, asi que no puede seguir el formato de un solo componente.
-- Usa el CompTipo '(CRUZADO)' de vw_FormatoParametro: 31 filas = union de las 4 hojas del Excel.
-- Solo 4 parametros cambian de grupo entre hojas (Ca, Mg, Mo, Zn: Contaminacion en MT, Aditivos en las
-- otras 3) y aqui van como ADITIVOS, con un pie que lo aclara. Aprobado por el usuario.
-- ⚠ El Inv/Inf del formato CRUZADO no evalua nada: las celdas ya vienen con su estado desde
--    vw_DiagnosticoEquipo, calculado POR COMPONENTE. Aqui el formato solo ordena y agrupa.
-- Ademas se corrigieron sus 2 encabezados de grupo ('ord IN (1,9,14,17)' -> primera fila de cada grupo).
-- Con esto ya NO queda ningun sitio con posiciones fijas en todo el DDL.
-- (1) Smoke test.
SELECT v.name AS Vista, d.error_message AS Error
FROM sys.views v
OUTER APPLY sys.dm_exec_describe_first_result_set(N'SELECT * FROM [dbo].' + QUOTENAME(v.name), NULL, 0) d
WHERE SCHEMA_NAME(v.schema_id) = 'dbo' AND v.name LIKE 'vw_%' AND d.error_message IS NOT NULL
ORDER BY v.name;

-- (2) La variante COMPLETA (la que usa /diagcompleto).
SELECT MD_Completo FROM [dbo].[vw_DiagnosticoMD] WHERE Equipo = 'CA3160';
-- Esperado: 31 filas de parametro x 6 columnas de componente, en este orden:
--   **Salud**            V100, V40—, TAN—, TBN, Oxidacion—, Sulfatacion—, Nitracion—
--   **Aditivos**         Ca, Zn, P, Mg, Mo—, B
--   **Contaminacion**    Si, Na, K, Hollin—, Diesel—, Agua—, Refrigerante—
--   **Desgaste**         Fe, PQ, Cr, Ni, Al, Cu, Pb, Sn
--   **Codigo Limpieza**  ISO>4—, ISO>6—, ISO>14—
-- Y al final el pie: 'Ca, Mg, Mo y Zn se listan como aditivos; en Motor de Traccion son contaminantes.'
-- ⛔ Ningun grupo repetido. ⚠ Comparar los VALORES con la captura anterior: no deben haber cambiado, solo
--    el orden y la agrupacion. El estado de cada celda se calcula aguas arriba y no se toco.

-- (3) La variante de solo OBSERVADOS (la otra salida de la misma vista).
SELECT MD FROM [dbo].[vw_DiagnosticoMD] WHERE Equipo = 'CA3160';

-- (4) Tamaño: pasa de 18 a 31 filas y puede tener hasta 6-7 columnas.
-- ⚠ CORREGIDO 24/09: sin WHERE esto tardaba >12 min y hubo que cancelarlo. Se mide sobre una muestra.
SELECT Equipo, LEN(MD_Completo) AS Largo_Completo, LEN(MD) AS Largo_Obs,
       CASE WHEN MD_Completo LIKE '%| Fe |%' THEN N'ok' ELSE N'SIN TABLA' END AS Estado
FROM [dbo].[vw_DiagnosticoMD]
WHERE Equipo IN ('CA3160','CA3161','CA3176','CA3177','HT300','HT305')
ORDER BY Largo_Completo DESC;
-- El techo del canal es ~28 000. Con 31 filas x 6-7 columnas deberia rondar los 2 000-3 000.

-- ==== BLOQUE 114 - D1: la causa del fallo de /diagnostico, ANTES de borrarlo ====
-- Fue el UNICO comando que fallo de verdad en la ronda del 23/09 ('/diagnostico 3160' -> 'No encontre
-- datos'), y /diagcompleto con el mismo equipo si respondia. Al borrar el tema el sintoma desaparece,
-- pero si la causa es compartida la arrastramos sin enterarnos. Esto la aisla.
-- (1) Las dos salidas de la MISMA vista para ese equipo: si MD viene NULL y MD_Completo no, el problema
--     es la variante de observados, no el equipo.
SELECT Equipo,
       CASE WHEN MD IS NULL THEN N'NULO' ELSE N'ok (' + CAST(LEN(MD) AS nvarchar(10)) + N' chars)' END AS Variante_observados,
       CASE WHEN MD_Completo IS NULL THEN N'NULO' ELSE N'ok (' + CAST(LEN(MD_Completo) AS nvarchar(10)) + N' chars)' END AS Variante_completa,
       NumCompObs, NumCompTotal
FROM [dbo].[vw_DiagnosticoMD] WHERE Equipo = 'CA3160';
-- HIPOTESIS: con NumCompObs = 0 (ningun componente observado) la variante MD se queda sin filas y el
-- STRING_AGG devuelve NULL -> MD NULL -> el flujo responde 'no encontre datos'. Seria el mismo patron que
-- las 66 filas del BLOQUE 110: falla en silencio en vez de decir 'este equipo no tiene observados'.
--
-- RESULTADO (24/09): CONFIRMADO. CA3160 -> Variante_observados = NULO, Variante_completa = ok (1 675
--   chars), NumCompObs = 0, NumCompTotal = 6.
--   El fallo de /diagnostico NO era un bug de ese comando: es el mismo patron silencioso de siempre.
--   Un equipo SANO (0 observados) produce MD NULL y el flujo responde 'no encontre datos', que suena a
--   'ese equipo no existe' cuando en realidad la respuesta correcta es 'no tiene ningun componente
--   observado' -- que es justo lo que el usuario queria saber.
--   ⛔ Y no es exclusivo de /diagnostico: CUALQUIER modulo que lea esa variante lo hereda.
--   FIX aplicado en el DDL (ver BLOQUE 115).

-- (2) Cuantos equipos estan en esa situacion (no es solo el 3160).
-- ⚠ CORREGIDO 24/09: sin WHERE tardaba minutos. NumCompObs sale de vw_DiagnosticoEquipo, que es mucho
--    mas barata que armar el MD de cada equipo: se cuenta ahi y no sobre la vista MD.
SELECT SUM(CASE WHEN NumObs = 0 THEN 1 ELSE 0 END) AS Equipos_sin_observados, COUNT(*) AS Total
FROM (
    SELECT Equipo, SUM(CASE WHEN Estado_General <> 'OK' THEN 1 ELSE 0 END) AS NumObs
    FROM [dbo].[vw_DiagnosticoEquipo] GROUP BY Equipo
) z;
-- Si los dos numeros coinciden, la causa esta confirmada y NO es exclusiva de /diagnostico: cualquier
-- modulo que lea esa variante hereda el problema. Eso es justamente lo que habia que saber antes de borrar.


-- ==== BLOQUE 115 - El equipo SANO deja de fallar en silencio (causa real del fallo de /diagnostico) ====
-- Antes: 0 componentes observados -> tabla vacia -> STRING_AGG NULL -> MD NULL -> 'no encontre datos'.
-- Ahora: dice '_Ninguno de sus N componentes tiene parametros fuera de limite._'
-- Es la respuesta que el usuario estaba pidiendo, y es el 3er caso del mismo patron en esta ronda
-- (componente pegado 'mtlh', muestras sin componente, y ahora equipo sano).
-- (1) Smoke test.
SELECT v.name AS Vista, d.error_message AS Error
FROM sys.views v
OUTER APPLY sys.dm_exec_describe_first_result_set(N'SELECT * FROM [dbo].' + QUOTENAME(v.name), NULL, 0) d
WHERE SCHEMA_NAME(v.schema_id) = 'dbo' AND v.name LIKE 'vw_%' AND d.error_message IS NOT NULL
ORDER BY v.name;

-- (2) El caso que fallaba: CA3160 tiene 0 observados de 6 componentes.
SELECT Equipo, NumCompObs, NumCompTotal,
       CASE WHEN MD IS NULL THEN N'SIGUE NULO' ELSE N'ok' END AS Variante_observados, MD
FROM [dbo].[vw_DiagnosticoMD] WHERE Equipo = 'CA3160';
-- Esperado: 'ok' y el texto 'Ninguno de sus 6 componentes tiene parametros fuera de limite.'

-- (3) NO-REGRESION: un equipo que SI tiene observados debe seguir mostrando su tabla.
SELECT Equipo, NumCompObs, LEN(MD) AS Largo_Obs, LEN(MD_Completo) AS Largo_Completo
FROM [dbo].[vw_DiagnosticoMD]
WHERE Equipo IN ('CA3161','CA3176','CA3177','HT300','HT305')
ORDER BY Equipo;
-- Esperado: los que tengan NumCompObs > 0 traen su tabla; los de 0 traen el mensaje (mas corto).


-- ==== BLOQUE 116 - DIAGNOSTICO de rendimiento de vw_DiagnosticoMD ====
-- SINTOMA medido (24/09): 1 equipo -> 9 s. 5-6 equipos -> 6-7 min y hubo que cancelar.
-- Eso NO es lineal (6 equipos deberian ser ~54 s): es la firma de que el filtro por equipo NO baja hasta
-- la fundacion y la vista se construye para TODA la flota antes de filtrar.
-- ⛔ Metodo: medir antes de teorizar. Nada de proponer fixes hasta que los scan count señalen al culpable.
-- ⚠ Correr cada punto POR SEPARADO y anotar el tiempo.

-- (1) LINEA BASE: la vista FUENTE, sin armar markdown. Si esta ya es lenta, el problema no es el formato.
SET STATISTICS IO ON; SET STATISTICS TIME ON;
SELECT COUNT(*) FROM [dbo].[vw_DiagnosticoEquipo] WHERE Equipo = 'CA3160';
SET STATISTICS IO OFF; SET STATISTICS TIME OFF;

-- (2) UN equipo, vista completa. Referencia: ~9 s medidos.
SET STATISTICS IO ON; SET STATISTICS TIME ON;
SELECT LEN(MD_Completo) FROM [dbo].[vw_DiagnosticoMD] WHERE Equipo = 'CA3160';
SET STATISTICS IO OFF; SET STATISTICS TIME OFF;
-- Anotar 'scan count' de [Oil].[LaboratoryData]. Con 1 equipo deberia ser bajo.

-- (3) DOS equipos. Si el tiempo se DISPARA (no se duplica), el filtro dejo de bajar: ahi esta el problema.
SET STATISTICS IO ON; SET STATISTICS TIME ON;
SELECT Equipo, LEN(MD_Completo) FROM [dbo].[vw_DiagnosticoMD] WHERE Equipo IN ('CA3160','CA3161');
SET STATISTICS IO OFF; SET STATISTICS TIME OFF;
-- COMPARAR (3) contra (2): si (2)=9 s y (3)=varios minutos, el IN() cambia el plan y mata el pushdown.
-- Si (3) ~ 18 s, el problema aparece mas adelante y hay que subir a 3-4 equipos.

-- (4) El mismo equipo por la OTRA variante (solo observados), para ver si el coste esta en una rama.
SET STATISTICS IO ON; SET STATISTICS TIME ON;
SELECT LEN(MD) FROM [dbo].[vw_DiagnosticoMD] WHERE Equipo = 'CA3161';
SET STATISTICS IO OFF; SET STATISTICS TIME OFF;

-- (5) ¿Cuantas veces se referencia la fundacion? Las dos variantes (MD y MD_Completo) se calculan SIEMPRE
--     aunque se pida una sola columna: cada una arma su hdr, sus rows y su body sobre unpv.
--     Esto mide el coste de pedir UNA sola columna vs las dos.
SET STATISTICS TIME ON;
SELECT LEN(MD_Completo) FROM [dbo].[vw_DiagnosticoMD] WHERE Equipo = 'CA3176';
SELECT LEN(MD) + LEN(MD_Completo) FROM [dbo].[vw_DiagnosticoMD] WHERE Equipo = 'CA3176';
SET STATISTICS TIME OFF;
-- Si pedir las dos cuesta lo mismo que pedir una, SQL Server ya calcula ambas -> la vista paga el doble
-- siempre. Seria un candidato claro: separar las variantes en dos vistas.

-- ⚠ QUE SE ESPERA APRENDER, y que NO hay que hacer todavia:
--   - Si (1) ya es lento -> el cuello viene de aguas arriba y el formato no tiene nada que ver.
--   - Si (2) es rapido y (3) se dispara -> es el pushdown del filtro: se ataca ahi.
--   - Si (5) muestra que ambas variantes se calculan siempre -> separar la vista en dos.
--   ⛔ No tocar nada hasta tener estos numeros. El barrido nos enseño que 3 hipotesis razonables pueden
--      caerse seguidas y que lo unico que decide es el scan count.
--
-- RESULTADOS BLOQUE 116 (24/09) -- culpable localizado:
--   (1) vw_DiagnosticoEquipo, 1 equipo:  522 ms | LaboratoryData 1 scan / 1 364 lecturas
--   (2) vw_DiagnosticoMD MD_Completo:   3 941 ms | LaboratoryData 5 scans / 23 628   <-- 17x mas lecturas
--   (3) 2 equipos:                      3 953 ms | LaboratoryData 5 scans / 25 950
--   (4) variante MD (observados):       4 508 ms | LaboratoryData 7 scans / 9 548,
--                                        pero MiningProject 21 278 y EquipmentFleet 21 283 lecturas (!)
--   (5) pedir 1 columna 3 897 ms | pedir las 2: 8 030 ms
-- LECTURAS:
--   a) La vista FUENTE es rapida (522 ms, 1 scan). El coste esta en el armado del markdown, no aguas arriba.
--   b) La fundacion se re-expande ~5 veces: 1 scan -> 5-7 scans y 17x lecturas. Es el ANTI-PATRON Nº1
--      (el mismo del barrido): vw_DiagnosticoMD referencia [vw_DiagnosticoEquipo] 4 VECES, mas los CTE
--      derivados (base, unpv, hdr_all, hdr_obs, row_all, row_obs, obsdet...). Los CTE no se materializan.
--   c) 2 equipos cuesta LO MISMO que 1 (3 941 vs 3 953 ms): el coste es casi FIJO -> el filtro por equipo
--      NO baja hasta la fundacion. Por eso 6 equipos con IN() se disparo a minutos: cambia el plan.
--   d) ✅ BUENA NOTICIA: pedir una sola columna cuesta la mitad que pedir las dos (3 897 vs 8 030), o sea
--      que el optimizador SI elimina la variante no usada. En PRODUCCION el flujo pide UNA -> no se paga
--      doble. La hipotesis de 'separar la vista en dos' queda DESCARTADA.
--   e) ⚠ Es PREEXISTENTE: las 4 referencias y los CTE derivados ya estaban; el cambio de formato solo
--      sustituyo un CROSS APPLY de 18 filas por un JOIN de 31. No introdujo referencias nuevas.
-- CANDIDATO DE FIX (a medir aislado antes de aplicar, como se hizo con el barrido):
--   reducir las 4 referencias a UNA: materializar las filas del equipo una sola vez en un CTE y derivar
--   de ahi hdr/rows/obs con funciones de ventana, en vez de volver a leer la vista fuente cada vez.
--   ⛔ No aplicar sin medir el candidato por separado: el barrido enseño que un candidato razonable puede
--      empeorar (430 s) y encima cambiar la salida.


-- ==== BLOQUE 117 - Optimizacion de vw_DiagnosticoMD: 4 lecturas de la fundacion -> 1 ====
-- Diagnostico (BLOQUE 116): la vista referenciaba [vw_DiagnosticoEquipo] 4 VECES (base, unpv, obsmetals,
-- obsmet). Los CTE no se materializan -> la fundacion se re-ejecutaba en cada referencia: 1 scan -> 5-7.
-- APLICADO en DDL_vistas.sql: 'base' trae ahora todas las columnas (d.*) y es la UNICA lectura; los otros
-- tres CTE leen de 'base'. Misma medicina que llevo el barrido de 6:21 a 19,5 s.
-- (1) Smoke test.
SELECT v.name AS Vista, d.error_message AS Error
FROM sys.views v
OUTER APPLY sys.dm_exec_describe_first_result_set(N'SELECT * FROM [dbo].' + QUOTENAME(v.name), NULL, 0) d
WHERE SCHEMA_NAME(v.schema_id) = 'dbo' AND v.name LIKE 'vw_%' AND d.error_message IS NOT NULL
ORDER BY v.name;

-- (2) La medicion. Comparar contra los numeros de ANTES (BLOQUE 116, mismo equipo):
--     3 941 ms | LaboratoryData 5 scans / 23 628 lecturas.
SET STATISTICS IO ON; SET STATISTICS TIME ON;
SELECT LEN(MD_Completo) FROM [dbo].[vw_DiagnosticoMD] WHERE Equipo = 'CA3161';
SET STATISTICS IO OFF; SET STATISTICS TIME OFF;
-- Objetivo: 'scan count' de LaboratoryData claramente menor y el tiempo abajo de 1-2 s.

-- (3) EQUIVALENCIA: la salida no puede haber cambiado. Se compara contra lo ya visto.
SELECT MD_Completo FROM [dbo].[vw_DiagnosticoMD] WHERE Equipo = 'CA3160';
-- Debe ser IDENTICA a la del BLOQUE 113: 31 filas, 5 grupos en orden, el pie de Ca/Mg/Mo/Zn,
-- y los mismos valores (V100 76.4 | 78.4 | 23.6 | 24.2 | 14.3 | 6.1 en la primera fila).
SELECT Equipo, NumCompObs, LEN(MD) AS Largo_Obs, LEN(MD_Completo) AS Largo_Completo
FROM [dbo].[vw_DiagnosticoMD] WHERE Equipo IN ('CA3160','CA3161','CA3176');
-- CA3160 debe seguir con el mensaje de equipo sano (Largo_Obs corto, ~120) y MD_Completo ~1 675.
-- ⛔ Si algo difiere, revertir: el cambio es de rendimiento, no puede mover ni un caracter.
--
-- RESULTADOS BLOQUE 117 (24/09) -- mejora REAL pero PARCIAL:
--   ANTES:   3 941 ms | CPU 687 ms | LaboratoryData 5 scans / 23 628 lecturas
--   DESPUES: 2 418 ms | CPU 797 ms | LaboratoryData 4 scans / 22 264 lecturas
--   => -39% de tiempo. Y con 3 equipos: 26 s (antes 5-6 equipos no terminaban en 6-7 min).
--   EQUIVALENCIA: salida identica (CA3160 1 675 / CA3161 1 666 / CA3176 922+1 682, mismos valores).
-- ⚠ LECTURA HONESTA: los scans bajaron 5 -> 4, NO a 1. El motivo es el mismo mecanismo de siempre:
--   'base' tambien es un CTE, y los CTE no se materializan. Al hacer que unpv/obsmetals/obsmet lean de
--   'base', la re-ejecucion no desaparecio: se MOVIO un nivel arriba. Ahora se re-ejecuta 'base' (que es
--   1 lectura de la fundacion) en vez de la vista entera con sus JOINs, y por eso igual se gano 39%.
-- PARA BAJAR DE AHI habria que reestructurar a UNA sola pasada con funciones de ventana (lo que se hizo
--   en el barrido), no solo redirigir referencias. Es un cambio mas grande y mas riesgoso.
-- DECISION: se toma la mejora. 2,4 s por equipo es aceptable para /diagcompleto y la escalabilidad ya no
--   se rompe con varios equipos. Queda anotado que hay margen si alguna vez molesta.

-- ==== BLOQUE 118 - E0: el contador del encabezado contradice las celdas marcadas ====
-- SINTOMA (visto en produccion 24/09): '/condicionmt 3161' imprime "0 de 2 observados" y en la misma
-- tabla el Zn de MT RH sale 70.7 con marca ROJA.
-- CAUSA LEIDA EN EL DDL (no hace falta medirla, esta en el codigo):
--   * la MARCA de la celda viene de Estado_<metal> -> cubre los 23 parametros de la hoja MT.
--   * el CONTADOR viene de Estado_General, que en la fundacion solo mira 9 de desgaste
--     (Fe, Cr, Ni, Cu, Si, Al, Pb, Sn, PQ) + TBN por debajo de su LP.
--     => Zn, Ca, Na, K, Mg y V100 marcan la celda pero NO cuentan como 'observado'.
-- Lo que hay que medir es CUANTO PASA, porque Estado_General lo usan tambien triage, barrido y conteo.

-- (1) Cuantos equipo+componente estan 'OK' para el contador y tienen al menos una celda marcada.
--     Agregado: no devuelve filas grandes.
WITH d AS (
    SELECT Equipo, Compartimiento, Estado_General, Zn, Ca, Na, K, Mg
    FROM [dbo].[vw_DiagnosticoEquipo]
), m AS (
    SELECT Equipo, Compartimiento, Estado_General,
        CASE WHEN Zn LIKE '%:C%' OR Zn LIKE '%:P%' THEN 1 ELSE 0 END AS mZn,
        CASE WHEN Ca LIKE '%:C%' OR Ca LIKE '%:P%' THEN 1 ELSE 0 END AS mCa,
        CASE WHEN Na LIKE '%:C%' OR Na LIKE '%:P%' THEN 1 ELSE 0 END AS mNa,
        CASE WHEN K  LIKE '%:C%' OR K  LIKE '%:P%' THEN 1 ELSE 0 END AS mK,
        CASE WHEN Mg LIKE '%:C%' OR Mg LIKE '%:P%' THEN 1 ELSE 0 END AS mMg
    FROM d
)
SELECT
    COUNT(*)                                                                AS Total_comp,
    SUM(CASE WHEN Estado_General = 'OK' THEN 1 ELSE 0 END)                  AS Dice_OK,
    SUM(CASE WHEN Estado_General = 'OK' AND (mZn+mCa+mNa+mK+mMg) > 0 THEN 1 ELSE 0 END) AS OK_pero_marcado,
    SUM(mZn) AS Marca_Zn, SUM(mCa) AS Marca_Ca, SUM(mNa) AS Marca_Na, SUM(mK) AS Marca_K, SUM(mMg) AS Marca_Mg
FROM m;
-- LECTURA:
--   'OK_pero_marcado' ALTO  -> la contradiccion es sistematica y hay que decidir (opciones abajo).
--   'OK_pero_marcado' BAJO  -> es un caso aislado; se puede dejar y solo aclararlo en el encabezado.

-- (2) Que metal la causa mas, y en que proyecto: define si el problema es de un contaminante concreto.
WITH d AS (
    SELECT Proyecto, Equipo, Compartimiento, Estado_General, Zn, Ca, Na, K, Mg
    FROM [dbo].[vw_DiagnosticoEquipo] WHERE Estado_General = 'OK'
)
SELECT Proyecto, mm.metal, COUNT(*) AS Componentes, COUNT(DISTINCT Equipo) AS Equipos
FROM d
CROSS APPLY (VALUES (N'Zn',Zn),(N'Ca',Ca),(N'Na',Na),(N'K',K),(N'Mg',Mg)) mm(metal, val)
WHERE mm.val LIKE '%:C%' OR mm.val LIKE '%:P%'
GROUP BY Proyecto, mm.metal
ORDER BY Componentes DESC;

-- (3) El caso concreto de la ronda, para tenerlo de referencia.
SELECT Equipo, Compartimiento, Estado_General, Zn, Ca, Na, K, Mg, Fe, PQ
FROM [dbo].[vw_DiagnosticoEquipo]
WHERE Equipo = 'CA3161' AND Compartimiento LIKE '%TRACCION%';
-- Esperado: MT RH con Zn '70.7:C' y Estado_General 'OK'.

-- DECISION QUE HABILITA ESTE BLOQUE (no la tomo yo, cambia numeros que ya vio gerencia):
--   (a) CONSERVADORA: dejar Estado_General como esta y cambiar solo el TEXTO del encabezado
--       ("0 de 2 con desgaste observado"), para que deje de contradecir la tabla. Riesgo casi nulo.
--   (b) AMPLIAR Estado_General a los contaminantes con limite real (Zn, Ca, Na, K, Mg).
--       ⚠ ALCANCE GRANDE: mueve los conteos de TRIAGE, BARRIDO y CONTEO DE FLOTA a la vez. El numero de
--       'observados' de cada mina sube de golpe, igual que paso al invertir los aditivos (181 equipos).
--       Si se elige (b), avisar al Carlos ANTES de publicar, no despues.

-- ==== BLOQUE 119 - E2: el correo de contacto faltaba en /ultimo ====
-- HALLADO LEYENDO EL DDL (24/09): de las 5 vistas que arman '**🔧 Recomendaciones Tecnicas**',
-- cuatro cerraban con el parrafo de monitoreo + confiabilidad.operaciones@kmmp.com.pe y
-- vw_UltimoAnalisisMD NO tenia NI el parrafo NI el correo. Por eso salia en unas respuestas y en otras no.
-- YA CORREGIDO en DDL_vistas.sql. Esto solo lo verifica tras desplegar.
SELECT Equipo, Compartimiento,
       CASE WHEN Recomendaciones LIKE '%confiabilidad.operaciones@kmmp.com.pe%' THEN 'SI' ELSE 'NO' END AS Trae_correo,
       CASE WHEN Recomendaciones LIKE '%tapones magn%' THEN 'SI' ELSE 'NO' END AS Trae_cierre,
       LEN(Recomendaciones) AS Largo
FROM [dbo].[vw_UltimoAnalisisMD]
WHERE Equipo IN ('CA3160','CA3161','CA3177') AND Compartimiento LIKE '%TRACCION%';
-- Esperado: 'SI' en las dos columnas para las filas CON recomendaciones.
-- ⚠ Las filas SIN recomendaciones ('Sin parametros de Motor de Traccion fuera de limite...') van con 'NO'
--   a proposito: ahi no hay nada que escalar, y el mensaje de fallback no lleva correo en NINGUNA vista.

-- RESULTADOS BLOQUE 119 (24/09) -- E2 CERRADO:
--   CA3160/CA3161/CA3177 MT LH+RH -> las filas con recomendacion real (largo 919) traen SI/SI.
--   Las de largo 127 son el mensaje de fallback ('Sin parametros ... fuera de limite'): van sin correo
--   a proposito, en todas las vistas.

-- (2) Barrido de las 5 vistas -- SIN EJECUTARLAS.
-- ⛔ La primera version de esta consulta leia vw_UltimoAnalisisMD + vw_CondicionMT_MD + vw_DiagnosticoMD
--    ENTERAS (sin filtro de equipo) para mirar un texto fijo. vw_DiagnosticoMD cuesta ~2,4 s por equipo:
--    por ~306 equipos son ~12 min, que es exactamente lo que tardo sin devolver nada.
--    El correo es un LITERAL de la definicion de la vista: se comprueba en los metadatos, sin ejecutar
--    ni una fila. Misma leccion que el BLOQUE 89 (smoke test con cursor -> colgo SSMS).
SELECT o.name AS Vista,
       (LEN(m.definition) - LEN(REPLACE(m.definition, N'Recomendaciones T', N''))) / LEN(N'Recomendaciones T') AS Bloques,
       (LEN(m.definition) - LEN(REPLACE(m.definition, N'kmmp.com.pe', N'')))       / LEN(N'kmmp.com.pe')       AS Correos
FROM sys.sql_modules m
JOIN sys.objects o ON o.object_id = m.object_id
WHERE m.definition LIKE N'%Recomendaciones T%'
ORDER BY o.name;
-- ESPERADO: 'Correos' = 1 en LAS CINCO vistas (vw_DiagnosticoMD, vw_UltimoAnalisisMD, vw_CondicionMT_MD,
--   vw_TendenciaMD, vw_TriageMD). 'Bloques' es mayor porque cuenta tambien los mensajes de fallback
--   (1 en Triage, 2 en el resto, 3 en Tendencia), y esos NO llevan correo a proposito.
-- Una vista con Correos = 0 es una que se quedo atras. Instantaneo: son metadatos.

-- ==== BLOQUE 120 - E0 aplicado: el contador ahora sale de las celdas que se pintan ====
-- QUE CAMBIO:
--   vw_CondicionMT_MD -> el contador y la lista de observados salen de unpv.marcada (la misma celda que
--     se imprime). De paso desaparecio la lista propia de 13 metales que tenia obsdet.
--   vw_DiagnosticoMD  -> 'CompMarcado' se calcula en 'base' (la unica lectura de la fundacion, para no
--     agregar referencias al CTE y no perder el BLOQUE 117) y reemplaza a Estado_General en las 3
--     variantes de 'solo observados' + el contador del encabezado.
-- ⛔ vw_TriageMD, el barrido y el conteo de flota NO se tocaron: siguen con Estado_General, asi que los
--    numeros que ya vio gerencia no se mueven. Eso es una decision aparte (ver PENDIENTES E0).

-- ⚠ CORREGIDO ANTES DE QUE FUNCIONARA (24/09): 'Msg 207 Invalid column name raw' en vw_CondicionMT_MD.
--   La lista v(Parametro, cell, raw) declara la columna, pero el SELECT de adentro del OUTER APPLY
--   seguia siendo 'SELECT v.cell': lo que no se proyecta ahi no existe afuera. Ahora es
--   'SELECT v.cell, v.raw'. Declarar la columna en la lista de alias no la expone por si sola.

-- (1) EL CASO DE LA RONDA. Antes: '0 de 2 observados' con el Zn de MT RH en rojo.
SELECT LEFT(MD, 90) AS Encabezado, Observados FROM [dbo].[vw_CondicionMT_MD] WHERE Equipo = 'CA3161';
-- ESPERADO: '1 de 2 observados' y Observados = 'MT RH: Zn'.

-- (2) Que no se haya roto lo que ya estaba bien: un equipo con desgaste de verdad.
SELECT LEFT(MD, 90) AS Encabezado, Observados FROM [dbo].[vw_CondicionMT_MD] WHERE Equipo = 'CA3177';

-- (3) Un equipo sin ninguna marca debe seguir diciendo que esta sano (no 'no encontre datos').
SELECT Equipo, Observados, LEN(Recomendaciones) AS LargoReco, LEFT(MD, 90) AS Encabezado
FROM [dbo].[vw_CondicionMT_MD] WHERE Equipo IN ('CA3160','CA3161','CA3176','CA3177');

-- (4) DIAGNOSTICO: el encabezado, el mensaje de equipo sano y la variante de observados.
--     ⚠ CA3160 tenia Zn 40.2 y Na 7.5/6.8 marcados y el contador decia 0: el mensaje '(ninguno fuera de
--     limite)' era FALSO. Ahora debe contarlos.
SELECT Equipo, NumCompObs, NumCompTotal, LEN(MD) AS Largo_Obs, LEN(MD_Completo) AS Largo_Completo
FROM [dbo].[vw_DiagnosticoMD] WHERE Equipo IN ('CA3160','CA3161');
-- ESPERADO: CA3160 con NumCompObs > 0 (antes 0) y la variante MD con tabla de verdad (antes ~120 chars
-- con el mensaje de equipo sano).

-- (5) RENDIMIENTO: el cambio no puede costar lo que gano el BLOQUE 117 (2 418 ms, 4 scans).
SET STATISTICS IO ON; SET STATISTICS TIME ON;
SELECT LEN(MD_Completo) FROM [dbo].[vw_DiagnosticoMD] WHERE Equipo = 'CA3161';
SET STATISTICS IO OFF; SET STATISTICS TIME OFF;
-- ESPERADO: mismo orden de magnitud (~2,4 s / 4 scans de LaboratoryData). 'CompMarcado' es una expresion
-- dentro de 'base', no una lectura nueva: si el tiempo se dispara, algo se re-expandio y hay que mirarlo.

-- (6) EL TAMANO DEL CAMBIO, para saber que se le dice al Carlos.
--     Cuantos equipos pasan de '0 observados' a tener al menos uno en MT.
SELECT COUNT(*) AS Equipos_MT, SUM(CASE WHEN NumCompObs > 0 THEN 1 ELSE 0 END) AS Con_observados
FROM (SELECT Equipo, COUNT(DISTINCT CASE WHEN CompMarcado = 1 THEN Compartimiento END) AS NumCompObs
      FROM (SELECT Equipo, Compartimiento,
                   CASE WHEN CONCAT(Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si,Ca,Zn,K,Na,Mg,B,P,V100,TBN) LIKE '%:C%'
                          OR CONCAT(Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si,Ca,Zn,K,Na,Mg,B,P,V100,TBN) LIKE '%:P%'
                        THEN 1 ELSE 0 END AS CompMarcado
            FROM [dbo].[vw_DiagnosticoEquipo]) z
      GROUP BY Equipo) y;
-- Comparar contra el conteo viejo (Estado_General) para tener la cifra exacta del aviso.

-- RESULTADOS BLOQUE 120 (24/09) -- E0 CERRADO, y sin costo:
-- (1) CA3161 -> '1 de 2 observados' + Observados 'MT RH: Zn'.  (antes: '0 de 2' con el Zn en rojo)
-- (2) CA3177 -> '1 de 2 observados' + 'MT LH: Zn'.  No se rompio nada de lo que ya funcionaba.
-- (3) CA3160 'MT LH: Zn' | CA3161 'MT RH: Zn' | CA3176 'MT LH: Ca, Zn, Fe' | CA3177 'MT LH: Zn'.
--     ⚠ HONESTO: ninguno de los 4 quedo sin marca, asi que esta consulta NO llego a probar el mensaje
--     de equipo sano. Hay que repetirla con un equipo sin ninguna marca antes de darlo por verificado.
-- (4) DIAGNOSTICO: CA3160 NumCompObs 3 de 6 (antes 0) y su variante de observados paso de ~120 chars
--     (el mensaje '(ninguno fuera de limite)', que era FALSO) a 1 099 de tabla real. CA3161 igual: 3 de 6.
--     MD_Completo quedo EN 1 675 y 1 666 -> identico al BLOQUE 117: la tabla completa no se movio.
-- (5) RENDIMIENTO: LaboratoryData 4 scans / 22 264 lecturas == exactamente lo del BLOQUE 117.
--     CPU 656 ms. El elapsed de 2 891 ms incluye 1 830 ms de compilacion (primera corrida tras el
--     CREATE OR ALTER). 'CompMarcado' no agrego ni una lectura, que era la apuesta al ponerlo en 'base'.
-- (6) EL TAMANO DEL CAMBIO: 111 de 306 equipos tienen al menos un componente observado.
--     Antes eran 100 (BLOQUE 114: '206 sin observados de 306'). => +11 equipos, ~4% de la flota.
--     Es la cifra para el aviso al Carlos, y es MUCHO menor de lo que sugerian los 119 componentes:
--     casi todos esos componentes pertenecian a equipos que YA tenian otro componente observado.

-- ==== BLOQUE 121 - E3: el MISMO valor sale marcado en /ultimo y SIN marcar en /diagcompleto ====
-- SINTOMA (25/09, CA3160 RD RH, mismo equipo y mismo componente en los dos modulos):
--   /ultimo 3160 rdrh -> Ca 176.3 CRITICO | Zn 1.6 CRITICO | Mg 2.3 CRITICO | Na 6.8 CRITICO
--   /diagcompleto 3160, columna RD RH -> Ca 176.3 sin marca | Zn 1.6 sin marca | Mg 2.3 sin marca
--   (el Na 6.8 SI sale marcado en los dos: es contaminante, no invertido)
-- CAUSA: hay DOS mecanismos de marcado distintos conviviendo.
--   vw_UltimoAnalisisMD  -> calcula la marca con vw_FormatoParametro.Inv: en 'Aditivos' la alerta es
--                           por DEBAJO. En RD RH el Ca tiene LP 2080 / LC 1560 (invertidos) y vale
--                           176.3 -> critico. CORRECTO.
--   vw_DiagnosticoMD     -> usa el sufijo ':C'/':P' que trae Estado_<metal> de la fundacion, y ese
--                           esta escrito SOLO como 'por encima' (Ca_ppm > Ca_LC). 176.3 > 1560 es
--                           falso -> no marca. INCORRECTO para los aditivos.
-- ⚠ En MOTOR DE TRACCION no se nota porque ahi Ca/Zn/Mg son CONTAMINANTES: 'por encima' es lo correcto.
--    El desacuerdo aparece en rueda, mando, transmision, hidraulico y motor.

-- (1) EL CASO, lado a lado. Es la prueba de que no es una impresion.
SELECT 'ultimo' AS Modulo, Parametro = '(ver MD)', MD
FROM [dbo].[vw_UltimoAnalisisMD] WHERE Equipo = 'CA3160' AND Compartimiento LIKE '%RUEDA%RH';
SELECT Equipo, Compartimiento, Ca, Zn, Mg, Na, Estado_General
FROM [dbo].[vw_DiagnosticoEquipo] WHERE Equipo = 'CA3160';
-- En la 2a: Ca/Zn/Mg de RD RH deben salir SIN ':C' aunque esten fuera de limite por abajo.

-- (2) EL TAMANO. Cuantos componentes tienen un aditivo por DEBAJO de su LC y la fundacion no lo marca.
--     Solo donde el limite esta invertido (LP > LC), que es como el Excel define a los aditivos.
SELECT d.CompTipo, mm.metal,
       COUNT(*) AS Componentes, COUNT(DISTINCT d.Equipo) AS Equipos
FROM [dbo].[vw_MuestrasRankeadas] d
CROSS APPLY (VALUES
        (N'Ca', d.Ca_ppm, d.Ca_LP, d.Ca_LC),
        (N'Zn', d.Zn_ppm, d.Zn_LP, d.Zn_LC),
        (N'Mg', d.Mg_ppm, d.Mg_LP, d.Mg_LC)
) mm(metal, val, lp, lc)
WHERE d.rn_recencia = 1
  AND d.CompTipo <> 'TRACCION'          -- en MT son contaminantes: ahi 'por encima' es lo correcto
  AND mm.lp > mm.lc                     -- limite invertido = aditivo
  AND mm.val < mm.lc                    -- por debajo del LC = deberia ser critico
GROUP BY d.CompTipo, mm.metal
ORDER BY Componentes DESC;
-- LECTURA: es el numero de celdas que /diagcompleto y /condicionmt estan dejando SIN marcar hoy.

-- DECISION (no la tomo yo, toca la fundacion y por tanto a triage/barrido/conteo):
--   (a) Arreglarlo en la FUNDACION: que Estado_<metal> respete la direccion segun el componente.
--       Es el arreglo de raiz y lo hereda todo. ⚠ Mueve los conteos de flota, como el aviso de E0.
--   (b) Arreglarlo solo en vw_DiagnosticoMD: que calcule la marca con valores + limites + Inv, igual
--       que vw_UltimoAnalisisMD, en vez de leer el sufijo. Acotado, pero deja DOS mecanismos vivos.
-- ⚠ Va junto con la pregunta al Carlos: es el mismo tema que los 181 equipos de los aditivos.

-- RESULTADOS BLOQUE 121 (25/09) -- confirmado y ACOTADO:
--   (2) CA3160: RUEDA DELANTERA LH y RH traen Ca 171.3/176.3, Zn 0.3/1.6 y Mg 1.2/2.3 SIN ':C',
--       mientras el Na SI sale '7.5:C' / '6.8:C'. Es exactamente la prediccion: el Na no esta
--       invertido y los otros tres si.
--   (3) EL ALCANCE ES CHICO Y ESTA EN UN SOLO SITIO: 53 componentes / 27 equipos, y SOLO en RUEDA,
--       para Ca, Zn y Mg. En hidraulico y motor los valores estan por encima del LC invertido, asi
--       que no hay desacuerdo. => arreglarlo NO es un cambio masivo.

-- ==== BLOQUE 122 - E3 y E4 aplicados ====
-- E3: Estado_Ca / Estado_Zn / Estado_Mg en vw_MuestrasEstado ahora miran la DIRECCION del limite.
--     La regla no es una lista de componentes: es 'LP > LC' -> limite invertido -> la alerta es por
--     DEBAJO. Asi lo define el Excel del area, y asi ya lo leia vw_UltimoAnalisisMD via Inv.
--     ⛔ Solo esos 3 metales. NO se generaliza a todos: el BLOQUE 104 encontro un LP/LC invertido por
--     TYPEO en Pb (CERRO VERDE MT LH 980E, LP=2 LC=1), y derivarlo de los datos lo daría por aditivo.
-- E4: el pie de recomendaciones distingue 3 casos (MT sin hallazgos / MT con hallazgos / NO-MT) en
--     vw_UltimoAnalisisMD y en vw_DiagnosticoMD.

-- (1) EL CASO: las mismas 6 filas del BLOQUE 121 (2). Ahora RD LH/RH deben traer ':C' en Ca/Zn/Mg.
SELECT Equipo, Compartimiento, Ca, Zn, Mg, Na, Estado_General
FROM [dbo].[vw_DiagnosticoEquipo] WHERE Equipo = 'CA3160';

-- (2) LOS DOS MODULOS DE ACUERDO. Es la prueba que cierra E3.
SELECT MD FROM [dbo].[vw_UltimoAnalisisMD]
WHERE Equipo = 'CA3160' AND Compartimiento LIKE '%RUEDA%RH';
SELECT MD_Completo FROM [dbo].[vw_DiagnosticoMD] WHERE Equipo = 'CA3160';
-- En la columna RD RH de la 2a, el Ca 176.3, el Zn 1.6 y el Mg 2.3 deben salir MARCADOS,
-- igual que en la 1a. Si uno marca y el otro no, E3 sigue vivo.

-- (3) E4: el pie ya no niega los hallazgos cuando el componente no es MT.
SELECT Compartimiento, LEFT(Recomendaciones, 200) AS Pie
FROM [dbo].[vw_UltimoAnalisisMD]
WHERE Equipo = 'CA3160' AND (Compartimiento LIKE '%RUEDA%' OR Compartimiento LIKE '%TRACCION%');
-- ESPERADO: en RUEDA, el texto de 'solo estan definidas para Motor de Traccion'; en TRACCION, el de
-- siempre. ⛔ Nunca 'sin parametros fuera de limite' debajo de una tabla que tiene marcas.

-- (4) EL NUEVO TAMANO DEL AVISO. Antes de E3 eran 111 de 306 (BLOQUE 120).
SELECT COUNT(*) AS Equipos, SUM(CASE WHEN NumCompObs > 0 THEN 1 ELSE 0 END) AS Con_observados
FROM (SELECT Equipo, COUNT(DISTINCT CASE WHEN CompMarcado = 1 THEN Compartimiento END) AS NumCompObs
      FROM (SELECT Equipo, Compartimiento,
                   CASE WHEN CONCAT(Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si,Ca,Zn,K,Na,Mg,B,P,V100,TBN) LIKE '%:C%'
                          OR CONCAT(Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si,Ca,Zn,K,Na,Mg,B,P,V100,TBN) LIKE '%:P%'
                        THEN 1 ELSE 0 END AS CompMarcado
            FROM [dbo].[vw_DiagnosticoEquipo]) z
      GROUP BY Equipo) y;
-- Los 27 equipos de RUEDA del BLOQUE 121 se suman aqui (menos los que ya contaban por otra cosa).
-- Es la cifra final para el aviso al Carlos.

-- (5) NO se movio lo de la flota: Estado_General sigue SIN mirar Ca/Zn/Mg, asi que triage, barrido y
--     conteo de flota dan lo mismo que antes. Se comprueba, no se supone.
SELECT Estado_General, COUNT(*) AS Componentes
FROM [dbo].[vw_DiagnosticoEquipo] GROUP BY Estado_General ORDER BY Componentes DESC;
-- ESPERADO: 'OK' ~1 284 de 1 621, igual que en el BLOQUE 118.

-- RESULTADOS BLOQUE 122 (25/09) -- E3 y E4 CERRADOS:
-- (1) CA3160: RUEDA DELANTERA LH y RH ahora traen 'Ca 171.3:C / 176.3:C', 'Zn 0.3:C / 1.6:C' y
--     'Mg 1.2:C / 2.3:C'. Antes salian sin marca. MT LH sigue con 'Zn 40.2:C' (contaminante, por
--     encima): la direccion se decide sola segun el limite, sin lista de componentes.
-- (2) LOS DOS MODULOS DE ACUERDO: en /diagcompleto la columna RD RH marca Ca, Zn y Mg igual que
--     /ultimo 3160 rdrh. E3 cerrado.
-- (3) E4: en RUEDA sale 'Las recomendaciones tecnicas hoy solo estan definidas para Motor de
--     Traccion...'; en MT LH la recomendacion real de Zinc y en MT RH el mensaje de siempre.
--     Los 3 casos, cada uno en su sitio.
-- (4) ⚠ EL AVISO NO CRECE: siguen 111 de 306 equipos con algun componente observado, IGUAL que en el
--     BLOQUE 120. Los 27 equipos de RUEDA ya contaban por el Na, que si estaba marcado.
--     => corrige lo que yo habia anticipado: dije que la cifra subiria y no subio.
-- (5) Estado_General intacto: OK 1 284 / CRITICO 230 / PRECAUCION 107 = los mismos 1 621 del BLOQUE
--     118. Triage, barrido y conteo de flota no se movieron, como debia ser.
-- ==== BLOQUE 123 - F1: cuanto pesaria la tendencia FUSIONADA (medir ANTES de construirla) ====
-- El modulo fusionado (05 + 06) imprimiria 4 tablas seguidas: contexto (Campo x fechas) + matriz
-- (Par x 6 fechas + Svida + Spark) + limites (Par|LP|LC) + resumen estadistico.
-- Y la matriz CRECIO con el bloque C: de 18 parametros fijos a 23 en MT.
-- ⛔ Filtrar SIEMPRE por equipo: estas vistas cuestan por equipo (leccion del BLOQUE 119).

-- ⛔ LAS VISTAS ...MD NO EXPONEN 'Compartimiento'. Su contrato de salida es
--    (Equipo, compAbbr, Observados, Recomendaciones, MD[, MD_Relevantes]) -> se filtra por
--    compAbbr = 'MT LH' / 'MT RH' / 'RD LH' / 'Sist. Hidr.' ...
--    'Compartimiento' solo existe aguas arriba: vw_TendenciaElemento, vw_MuestrasRankeadas,
--    vw_DiagnosticoEquipo, vw_UltimoAnalisisMD. Confundirlos da Msg 207 (van 5 en la ronda).

-- (1) Lo que pesa hoy cada pieza, por separado.
SELECT 'P1 (contexto)' AS Pieza, LEN(MD) AS Chars
FROM [dbo].[vw_TendenciaP1MD] WHERE Equipo = 'CA3161' AND compAbbr = 'MT RH'
UNION ALL
SELECT 'Detalle (matriz+limites+stats)', LEN(MD)
FROM [dbo].[vw_TendenciaMD] WHERE Equipo = 'CA3161' AND compAbbr = 'MT RH'
UNION ALL
SELECT 'Relevantes (solo fuera de limite)', LEN(MD_Relevantes)
FROM [dbo].[vw_TendenciaMD] WHERE Equipo = 'CA3161' AND compAbbr = 'MT RH';
-- La SUMA de las dos primeras es lo que pesaria el modulo fusionado.

-- (2) El caso PEOR. ⛔ LA VERSION ANTERIOR DE ESTA CONSULTA NO TERMINABA (>7 min): pedia
--     vw_TendenciaMD para 5 equipos SIN filtrar componente = 5 x 6 = 30 renders completos.
--     Estas vistas cuestan por equipo Y por componente; filtrar solo por equipo no alcanza.
--     (2a) La estructura NO hace falta ejecutarla: el numero de filas de la matriz lo fija el
--     FORMATO. Instantaneo, 175 filas.
SELECT CompTipo, COUNT(*) AS Parametros
FROM [dbo].[vw_FormatoParametro] GROUP BY CompTipo ORDER BY Parametros DESC;
-- El CompTipo con mas parametros es el caso peor de la matriz. Con eso se elige QUE medir.

--     (2b) Y se confirma con UN solo render, del componente que gano arriba.
SELECT compAbbr, LEN(MD) AS Chars FROM [dbo].[vw_TendenciaMD]
WHERE Equipo = 'CA3160' AND compAbbr = 'MT LH';

-- (3) Cuantas filas tendria la respuesta fusionada (legibilidad, que es el riesgo real).
SELECT
    (LEN(a.MD) - LEN(REPLACE(a.MD, CHAR(10), ''))) AS Lineas_contexto,
    (LEN(b.MD) - LEN(REPLACE(b.MD, CHAR(10), ''))) AS Lineas_detalle,
    (LEN(a.MD) - LEN(REPLACE(a.MD, CHAR(10), ''))) + (LEN(b.MD) - LEN(REPLACE(b.MD, CHAR(10), ''))) AS Lineas_total
FROM [dbo].[vw_TendenciaP1MD] a
JOIN [dbo].[vw_TendenciaMD]  b ON b.Equipo = a.Equipo AND b.compAbbr = a.compAbbr
WHERE a.Equipo = 'CA3161' AND a.compAbbr = 'MT RH';
-- LECTURA:
--   El techo del canal de Teams (~28 000 chars) NO va a ser el problema.
--   El problema es la LEGIBILIDAD: 4 tablas seguidas en un movil.
--   Si 'Lineas_total' pasa de ~60, la palanca es dejar el RESUMEN ESTADISTICO como continuacion,
--   no recortar la matriz (esa es justo la que pidio Carlos completa).

-- RESULTADOS BLOQUE 99 (25/09) -- por fin corrido, y CORRECTO:
--   vw_TendenciaMD (CA3160 MT LH): Svida trae numero SOLO en Fe 3718.7, PQ 1462.6, Cr 19.1, Ni 5.8,
--   Cu 17.5, Pb 11.9, Sn 5.4, Al 4.4. Todo lo demas (V100, V40, P, B, Si, Na, K, Ca, Zn, Mg, Mo,
--   Agua, ISO) sale con '-'. El resumen estadistico dice lo mismo, y vw_TendenciaMetalMD tambien:
--   Fe (desgaste) con Svida por componente, Si (contaminante) con '-' en los seis.

-- RESULTADOS BLOQUE 123 (25/09) -- la fusion CABE de sobra, pero es LARGA:
--   (2a) Parametros por formato: (CRUZADO) 31 | MOTOR 27 | OTRO/RUEDA/HIDRAULICO/MANDO/
--        TRANSMISION 25 | TRACCION 23.  ⚠ MT es el MAS CHICO, no el peor: la medicion de (1) y
--        (3) se hizo sobre MT RH, o sea el CASO COMODO. MOTOR tiene 4 parametros mas, que en las
--        3 tablas son ~12 lineas mas -> del orden de 103 lineas, no 91. La decision no cambia:
--        refuerza sacar el resumen estadistico.
--   (2b) Un render de MT LH = 3 152 chars, coherente con los 3 155 de (1).
--   (1) P1 contexto 649 + Detalle 3 155 = ~3 800 chars el modulo fusionado. Relevantes 421.
--       El techo del canal (~28 000) ni se roza: sobra un factor 7.
--   (3) 11 lineas de contexto + 80 de detalle = 91 LINEAS. Ese SI es el problema.
-- DECISION QUE HABILITA: 91 lineas es mucho para un movil, y el criterio escrito era ~60.
--   El detalle son 3 tablas: matriz (~29) + limites (~19) + resumen estadistico (~26).
--   => sacar el RESUMEN ESTADISTICO del bloque y dejarlo como continuacion baja a ~65 lineas,
--      sin tocar la matriz, que es justo lo que Carlos pidio COMPLETO.
--   ⛔ No recortar la matriz ni los limites: son el dato y su referencia.

-- ==== BLOQUE 124 - F4: Svida con el numero de muestras, y la clave completa ====
-- QUE CAMBIO (todo en SQL, nada en Copilot):
--   F4.1 la celda pasa de '3718.7' a '3718.7 (26)' y el encabezado de 'Svida' a 'Svida (n m.)'.
--        4 celdas y 5 encabezados, en vw_TendenciaMD y vw_TendenciaMetalMD.
--        ⚠ La trampa anotada se cumplio: vw_TendenciaMetalMD lee un CTE con LISTA EXPLICITA de
--        columnas; sin agregar NmAcum ahi, la vista compila y revienta al consultarla (Msg 207).
--   F4.2 'Proyecto' entra en la clave de 'acc' (sa -> acc -> LEFT JOIN). Hoy 0 colisiones, pero dos
--        minas con el mismo codigo de equipo sumarian juntas.
--   F4.3 nota al pie del resumen estadistico: Svida NO se reinicia al cambiar el componente, a
--        diferencia de /rankingacum. Son dos acumulados distintos con el mismo nombre coloquial.

-- ⛔ LAS VISTAS ...MD NO EXPONEN 'Compartimiento'. Su contrato de salida es
--    (Equipo, compAbbr, Observados, Recomendaciones, MD[, MD_Relevantes]) -> se filtra por
--    compAbbr = 'MT LH' / 'MT RH' / 'RD LH' / 'Sist. Hidr.' ...
--    'Compartimiento' solo existe aguas arriba: vw_TendenciaElemento, vw_MuestrasRankeadas,
--    vw_DiagnosticoEquipo, vw_UltimoAnalisisMD. Confundirlos da Msg 207 (van 5 en la ronda).

-- (1) LA TRAMPA PRIMERO. Si esto revienta, es NmAcum fuera del CTE de lista explicita.
SELECT TOP 1 LEN(MD) FROM [dbo].[vw_TendenciaMetalMD] WHERE Equipo = 'CA3160' AND Parametro = 'Fe';
-- Esperado: un numero. ⛔ 'Invalid column name NmAcum' = falta agregarlo en el SELECT del CTE.

-- (2) EL FORMATO NUEVO, en el modulo principal.
SELECT MD FROM [dbo].[vw_TendenciaMD]
WHERE Equipo = 'CA3160' AND compAbbr = 'MT LH';
-- Esperado: 'Fe | ... | 3718.7 (26) | ...', encabezado 'Svida (n m.)', y al final la nota de que no
-- se reinicia. El '-' de los que no son desgaste se queda SIN '(n)': no hay nada que sumar.

-- (3) Que el numero de muestras sea creible: comparar con las muestras reales del componente.
SELECT COUNT(*) AS Muestras_no_DDI
FROM [dbo].[vw_MuestrasRankeadas]
WHERE Equipo = 'CA3160' AND Compartimiento LIKE '%TRACCION%LH' AND EsDDI = 0;
-- Debe coincidir con el '(n)' que salga en Fe. Si no coincide, el acumulado no suma lo que dice.
-- ⚠ Puede diferir por parametro: NmAcum cuenta valores NO NULOS de ESE parametro, no filas.

-- (4) F4.2: que agregar Proyecto a la clave no cambio ningun numero (0 colisiones esperadas).
SELECT Equipo, Compartimiento, Parametro, Acumulado, NmAcum
FROM [dbo].[vw_TendenciaElemento]
WHERE Equipo = 'CA3160' AND Compartimiento LIKE '%TRACCION%LH' AND Parametro IN ('Fe','PQ','Cr','Al');
-- Esperado: Fe 3718.7 igual que en el BLOQUE 99. Si cambio, habia colision y hay que mirarla.

-- (5) La otra variante y el modulo por metal, para que no se quede uno atras.
SELECT LEN(MD_Relevantes) AS Rel FROM [dbo].[vw_TendenciaMD]
WHERE Equipo = 'CA3160' AND compAbbr = 'MT LH';
SELECT MD FROM [dbo].[vw_TendenciaMetalMD] WHERE Equipo = 'CA3160' AND Parametro = 'Fe';
-- En el de metal, la columna Svida del resumen tambien debe traer '(n)'.

-- RESULTADOS BLOQUE 124 (25/09) -- F4 CERRADO, los 3 arreglos:
-- (1) La trampa evitada: vw_TendenciaMetalMD devuelve 1 117, no 'Invalid column name NmAcum'.
-- (2) La matriz sale con 'Svida (n m.)' y '3718.7 (27)', '1462.6 (27)', '19.1 (27)'... y al final la
--     nota de que no se reinicia. Los que no son desgaste siguen con '-' y SIN '(n)'.
-- (3) Muestras no-DDI del componente = 27 == el '(27)' de la celda. El acumulado suma lo que dice.
-- (4) F4.2 sin efectos: Fe 3718.7 / PQ 1462.6 / Cr 19.1 / Al 4.4, identicos al BLOQUE 99.
--     Agregar Proyecto a la clave no movio ningun numero => 0 colisiones, como se esperaba.
-- (5) MD_Relevantes 419 y el modulo por metal tambien con '(n)': MT LH 3718.7 (27), MT RH 3794.4 (27),
--     RD LH 452.9 (21), RD RH 498.6 (21), Motor 266.6 (88), Sist. Hidr. 72.0 (21).
--     ⚠ DATO INTERESANTE: el Motor lleva 88 muestras contra 21-27 de los demas. El '(n)' no es
--     decorativo: dice que esas Svida NO son comparables entre componentes.

-- ==== BLOQUE 125 - F3: las graficas llevan contexto ====
-- ⛔ Las vistas ...MD se filtran por compAbbr, NUNCA por Compartimiento (ver BLOQUE 123).
-- QUE CAMBIO:
--   vw_TendenciaElemento expone ahora 'Modelo' y 'Horometro' (venian de la fundacion via me.*; se
--     arrastran por s -> u -> v -> g, y 'v' es SELECT u.* asi que no hubo que tocarlo).
--   vw_TendenciaGraficoMD y vw_TendenciaGraficoObsMD imprimen un SUBTITULO de contexto igual al de
--     /ultimo: Mod. / Lubric. / SMR / Hor.Comp. / rango de fechas.
--   vw_TendenciaGraficoObsMD: su 'base' pasa de DISTINCT a GROUP BY para sacar ese contexto de la
--     MISMA lectura. ⛔ Un DISTINCT + otra referencia a la vista habrian sido dos pasadas.

-- (1) Primero lo que se toco aguas arriba: que vw_TendenciaElemento siga entera y traiga las 2 columnas.
SELECT TOP 3 Equipo, Compartimiento, Parametro, Modelo, Horometro, Grado, HorasComponente, f1, f6
FROM [dbo].[vw_TendenciaElemento]
WHERE Equipo = 'CA3160' AND Compartimiento LIKE '%TRACCION%LH';
-- Esperado: Modelo '980E' y Horometro con valor. ⛔ Si aqui falla, no seguir: lo leen 6 modulos.

-- (2) La grafica de UN metal, con su encabezado nuevo.
SELECT MD FROM [dbo].[vw_TendenciaGraficoMD]
WHERE Equipo = 'CA3160' AND compAbbr = 'MT LH' AND Parametro = 'Fe';
-- Esperado, bajo el titulo: '*Mod. 980E - Lubric. SHELL OMALA S4 GXV 680 - SMR ... - Hor.Comp. ... -
-- 25-Jul a 15-Sep*', y despues la tabla y el bloque ``` con la curva.

-- (3) Las graficas de observados, mismo encabezado.
SELECT MD FROM [dbo].[vw_TendenciaGraficoObsMD]
WHERE Equipo = 'CA3160' AND compAbbr = 'MT LH';

-- (4) EL CASO QUE SUELE ROMPERSE: un componente SIN metales observados. El contexto debe salir IGUAL,
--     y debajo el mensaje de que no hay nada que graficar. ⛔ Si el MD sale NULL, es el patron de
--     fallo silencioso otra vez (bloque G).
SELECT compAbbr, LEN(MD) AS Chars, LEFT(MD, 220) AS Cabecera
FROM [dbo].[vw_TendenciaGraficoObsMD] WHERE Equipo = 'CA3160';
-- Esperado: una fila por componente del equipo, TODAS con Chars > 0.

-- (5) Que no se rompio nada de lo que ya usaba vw_TendenciaElemento (son 6 modulos).
SELECT 'TendenciaMD' AS Vista, LEN(MD) AS Chars FROM [dbo].[vw_TendenciaMD]
WHERE Equipo = 'CA3160' AND compAbbr = 'MT LH'
UNION ALL SELECT 'TendenciaMetalMD', LEN(MD) FROM [dbo].[vw_TendenciaMetalMD]
WHERE Equipo = 'CA3160' AND Parametro = 'Fe'
UNION ALL SELECT 'TendenciaP1MD', LEN(MD) FROM [dbo].[vw_TendenciaP1MD]
WHERE Equipo = 'CA3160' AND compAbbr = 'MT LH';
-- Esperado: TendenciaMD ~3 152 y TendenciaMetalMD ~1 117, los mismos del BLOQUE 124. Si cambiaron,
-- agregar columnas movio algo que no debia.

-- RESULTADOS BLOQUE 125 (25/09) -- F3 CERRADO:
-- (1) vw_TendenciaElemento trae Modelo '980E' y Horometro 43600 sin romperse.
-- (2) /grafica Fe MT LH: '*Mod. 980E - Lubric. SHELL OMALA S4 GXV 680 - SMR 43600 - Hor.Comp. 16571 -
--     25-Jul a 15-Sep*' bajo el titulo, y despues la tabla y la curva.
-- (3) Graficas de observados: mismo subtitulo.
-- (4) LOS 6 COMPONENTES CON TEXTO, ninguno NULL: Motor 254 | MT LH 1 713 | MT RH 2 512 | RD LH 4 046 |
--     RD RH 4 837 | Sist. Hidr. 255. Los dos cortos (Motor, Sist. Hidr.) son los que NO tienen metales
--     observados: conservan el contexto y explican por que no hay grafica. Sin fallo silencioso.
-- (5) Sin efectos colaterales: TendenciaMD 3 152 y TendenciaMetalMD 1 117, identicos al BLOQUE 124.
--     (TendenciaP1MD 642 es de CA3160 MT LH; los 649 del BLOQUE 123 eran de CA3161 MT RH.)

-- ==== BLOQUE 126 - F1: el modulo de tendencia FUSIONADO ====
-- ⛔ Filtrar por compAbbr, nunca por Compartimiento.
-- QUE CAMBIO:
--   vw_TendenciaP1MD gana la columna 'MD_Contexto': su mismo encabezado y su tabla, SIN la pregunta
--     de cierre. Es lo que embebe el modulo fusionado; asi la logica del contexto vive en UN sitio.
--   vw_TendenciaMD.MD = contexto (embebido) + matriz + limites + nota. El RESUMEN ESTADISTICO salio
--     a la columna nueva 'MD_Estadistica' (mismo patron que MD_Relevantes: una columna, no un modulo).
--     Razon medida (BLOQUE 123): 91 lineas en MT, ~103 en MOTOR; sacarlo baja a ~65.
--   ⚠ Hay un LEFT JOIN nuevo a vw_TendenciaP1MD. Es una lectura mas: la consulta (4) la mide.

-- (1) EL MODULO FUSIONADO. Es la prueba del pedido de gerencia.
SELECT MD FROM [dbo].[vw_TendenciaMD] WHERE Equipo = 'CA3160' AND compAbbr = 'MT LH';
-- Esperado, en este orden: titulo 'Tendencia - CA3160 - MT LH - ultimas 6 muestras' | tabla
-- Campo x fechas (SMR, Hrs Aceite, Hrs Comp, CM, Estado, Grado) | 'Detalle por parametro' + matriz |
-- limites | nota de Svida | la oferta del resumen estadistico y la grafica.
-- ⛔ NO debe aparecer el resumen estadistico aqui.

-- (2) LA CONTINUACION.
SELECT MD_Estadistica FROM [dbo].[vw_TendenciaMD] WHERE Equipo = 'CA3160' AND compAbbr = 'MT LH';

-- (3) EL TAMANO, contra el objetivo de ~65 lineas.
SELECT compAbbr,
       LEN(MD) AS Chars_MD,
       (LEN(MD) - LEN(REPLACE(MD, CHAR(10), ''))) AS Lineas_MD,
       (LEN(MD_Estadistica) - LEN(REPLACE(MD_Estadistica, CHAR(10), ''))) AS Lineas_Est
FROM [dbo].[vw_TendenciaMD] WHERE Equipo = 'CA3160' AND compAbbr = 'MT LH';
-- Esperado: Lineas_MD ~65 (antes 91 con MT, el componente mas chico).
-- ⚠ Medir tambien MOTOR, que es el caso peor (27 parametros):
SELECT compAbbr, (LEN(MD) - LEN(REPLACE(MD, CHAR(10), ''))) AS Lineas_MD
FROM [dbo].[vw_TendenciaMD] WHERE Equipo = 'CA3160' AND compAbbr = 'Motor';

-- (4) RENDIMIENTO: el LEFT JOIN a P1 es una lectura mas. Antes de F1, /tendenciadet de 1 componente
--     costaba lo que costara; aqui se mide si la fusion lo empeoro de forma notable.
SET STATISTICS IO ON; SET STATISTICS TIME ON;
SELECT LEN(MD) FROM [dbo].[vw_TendenciaMD] WHERE Equipo = 'CA3160' AND compAbbr = 'MT LH';
SET STATISTICS IO OFF; SET STATISTICS TIME OFF;
-- Si el tiempo se va a decenas de segundos, la alternativa es duplicar la logica del contexto dentro
-- de vw_TendenciaMD (mas rapido, peor de mantener). Medir antes de decidir.

-- (5) QUE NO SE ROMPIO NADA: las otras dos columnas y el resto de la familia.
SELECT LEN(MD_Relevantes) AS Rel FROM [dbo].[vw_TendenciaMD]
WHERE Equipo = 'CA3160' AND compAbbr = 'MT LH';
SELECT LEN(MD) AS P1 FROM [dbo].[vw_TendenciaP1MD] WHERE Equipo = 'CA3160' AND compAbbr = 'MT LH';
SELECT LEN(MD_Contexto) AS Ctx FROM [dbo].[vw_TendenciaP1MD] WHERE Equipo = 'CA3160' AND compAbbr = 'MT LH';
-- Esperado: Rel ~419 y P1 642 (BLOQUE 125). Ctx debe ser P1 menos la pregunta de cierre (~90 chars).

-- (6) EL CASO SIN CONTEXTO: si P1 no tuviera fila, el MD NO puede salir NULL (regla del bloque G).
SELECT compAbbr, LEN(MD) AS Chars FROM [dbo].[vw_TendenciaMD] WHERE Equipo = 'CA3160';
-- Esperado: una fila por componente, TODAS con Chars > 0.

-- RESULTADOS BLOQUE 126 (25/09) -- F1 SALE, y el objetivo de tamano se cumplio CLAVADO:
-- (1) El MD fusionado imprime, en orden: titulo + tabla de contexto (SMR/Hrs Aceite/Hrs Comp/CM/
--     Estado/Grado) + 'Detalle por parametro' + matriz + limites + nota + la oferta de continuar.
--     ⛔ El resumen estadistico YA NO aparece ahi. Correcto.
-- (2) MD_Estadistica sale con su propio titulo y su tabla.
-- (3) EL TAMANO: MT LH 2 976 chars / 65 LINEAS (venia de 91) y la estadistica 28 aparte.
--     Y MOTOR tambien 65 lineas -- el caso 'peor' por numero de parametros no es peor en lineas,
--     porque su tabla de limites es mas corta. Objetivo ~65: cumplido.
-- (5) Sin danos: MD_Relevantes 419 y P1 642, iguales al BLOQUE 125. MD_Contexto 554 = 642 menos la
--     pregunta de cierre, que es exactamente lo que se queria separar.
-- (6) Los 6 componentes con texto: Motor 3 123 | MT LH 2 976 | MT RH 2 985 | RD LH 3 131 |
--     RD RH 3 167 | Sist. Hidr. 2 988. Ninguno NULL.
-- 🔴 (4) EL COSTO: 6 519 ms | CPU 1 250 ms | LaboratoryData 8 scans / 27 014 lecturas.
--     6,5 s por componente es alto para el modulo que mas se usa. La causa no es la fusion en si:
--     vw_TendenciaP1MD leia la fundacion DOS VECES (su 'base' y su 'unpv'), y al embeberla esas dos
--     lecturas entraron en vw_TendenciaMD. Es el anti-patron del BLOQUE 117 otra vez.

-- ==== BLOQUE 127 - F1: quitar la lectura doble de vw_TendenciaP1MD ====
-- ⛔ Filtrar por compAbbr, nunca por Compartimiento.
-- QUE CAMBIO: 'base' se lleva las 6 columnas de contexto (Horometro, HorasDeAceite, HorasComponente,
--   CM, Grado, Estado_General) y 'unpv' pasa de 'FROM vw_MuestrasRankeadas d JOIN base b' a 'FROM base b'.
--   Una sola lectura de la fundacion en vez de dos. No cambia NI UN caracter de la salida.

-- (1) EQUIVALENCIA PRIMERO: la salida no puede moverse. Se compara con el BLOQUE 126.
SELECT LEN(MD) AS P1, LEN(MD_Contexto) AS Ctx FROM [dbo].[vw_TendenciaP1MD]
WHERE Equipo = 'CA3160' AND compAbbr = 'MT LH';
-- Esperado EXACTO: P1 = 642 y Ctx = 554. ⛔ Si cambia un caracter, revertir: esto es rendimiento.

SELECT LEN(MD) AS Fusionado, (LEN(MD) - LEN(REPLACE(MD, CHAR(10), ''))) AS Lineas
FROM [dbo].[vw_TendenciaMD] WHERE Equipo = 'CA3160' AND compAbbr = 'MT LH';
-- Esperado EXACTO: 2 976 chars y 65 lineas.

-- (2) LA MEDICION. Comparar contra el BLOQUE 126: 6 519 ms | 8 scans / 27 014 lecturas.
SET STATISTICS IO ON; SET STATISTICS TIME ON;
SELECT LEN(MD) FROM [dbo].[vw_TendenciaMD] WHERE Equipo = 'CA3160' AND compAbbr = 'MT LH';
SET STATISTICS IO OFF; SET STATISTICS TIME OFF;
-- Objetivo: 'scan count' de LaboratoryData por debajo de 8 y el tiempo claramente menor.
-- ⚠ La primera corrida tras un CREATE OR ALTER incluye la compilacion: correrla DOS veces y quedarse
--   con la segunda, como en el BLOQUE 120.

-- (3) Y el modulo suelto, que tambien gana: /tendencia por si solo.
SET STATISTICS IO ON; SET STATISTICS TIME ON;
SELECT LEN(MD) FROM [dbo].[vw_TendenciaP1MD] WHERE Equipo = 'CA3160' AND compAbbr = 'MT LH';
SET STATISTICS IO OFF; SET STATISTICS TIME OFF;

-- (4) Que ningun componente se quedo sin texto tras el cambio.
SELECT compAbbr, LEN(MD) AS Chars FROM [dbo].[vw_TendenciaMD] WHERE Equipo = 'CA3160';
-- Esperado: los mismos 6 tamanos del BLOQUE 126 (3 123 / 2 976 / 2 985 / 3 131 / 3 167 / 2 988).

-- RESULTADOS BLOQUE 127 (25/09) -- equivalencia PERFECTA, mejora PARCIAL:
-- (1) P1 642 y Ctx 554; fusionado 2 976 chars / 65 lineas. EXACTOS, no se movio un caracter.
-- (4) Los 6 componentes con los mismos tamanos: 3 123 / 2 976 / 2 985 / 3 131 / 3 167 / 2 988.
-- (2) ANTES: 6 519 ms | 8 scans / 27 014 lecturas.  DESPUES: 5 764 ms | 7 scans / 25 650. => -12%.
-- (3) vw_TendenciaP1MD suelto: 1 571 ms | CPU 235 ms | 2 scans / 2 728 lecturas.
-- ⚠ LECTURA HONESTA: esperaba bajar de 8 a 6 scans y solo bajo a 7. El motivo es el de siempre: dentro
--   de P1, 'base' TAMBIEN es un CTE y lo referencian 'unpv', 'hdr' y 'meta'. Quitar la lectura explicita
--   de vw_MuestrasRankeadas en 'unpv' elimino UNA, pero 'base' se sigue re-ejecutando.
-- PARA BAJAR DE AHI habria que reestructurar P1 a UNA sola pasada con funciones de ventana, como se hizo
--   en el barrido. Es un cambio mayor para un modulo que ya responde.
-- DECISION: se toma la mejora y se cierra F en SQL. 5,8 s por componente es aceptable (el barrido de
--   flota se acepto en 19,5 s y /diagcompleto en 2,4 s con 6 componentes). Queda anotado el margen.

-- ==== BLOQUE 128 - REGRESION: /tendenciametal se paso de 2 min (FlowActionTimedOut, 25/09) ====
-- SINTOMA EN PRODUCCION: '/tendenciametal 3160 Fe' -> el flujo MD_metal muere a los 2 m 0 s exactos
--   ('Ejecutar una consulta SQL (V2)': the server did not respond within the timeout limit).
--   ⚠ '/grafica 3160 mtlh Fe' SI responde, y usa EL MISMO flujo. La diferencia esta en la vista:
--   /grafica -> vw_TendenciaGraficoMD (UN componente) | /tendenciametal -> vw_TendenciaMetalMD (los 6).
-- QUE CAMBIO HOY EN ESE CAMINO: vw_TendenciaMetalMD lee vw_TendenciaElemento, y a esa vista se le
--   toco (a) F4.1 NmAcum, (b) F4.2 'Proyecto' en la clave de 'acc', (c) F3 columnas Modelo/Horometro.
--   De las tres, la unica que cambia la ESTRUCTURA del plan es (b): el LEFT JOIN pasó a comparar
--   contra g.Proyecto, que es un MAX() de un GROUP BY.
-- ⚠ Y en SSMS no se vio porque se median con 'Equipo = ''CA3160''' -- el flujo usa LIKE '%3160%'.

-- (1) REPRODUCIR EL FALLO CON LA QUERY EXACTA DEL FLUJO. ⛔ No con '=' : con LIKE, como en produccion.
SET STATISTICS TIME ON;
SELECT MD, Observados, Recomendaciones
FROM [dbo].[vw_TendenciaMetalMD]
WHERE Equipo LIKE '%3160%'
  AND REPLACE(compAbbr,' ','') LIKE '%' + REPLACE('todos',' ','') + '%'
  AND Parametro = 'Fe';
SET STATISTICS TIME OFF;
-- Si esto tarda >100 s, el timeout del conector (2 min) es consecuencia, no causa.

-- (2) LA MISMA, con '=' en el equipo: separa 'el LIKE' de 'la vista'.
SET STATISTICS TIME ON;
SELECT MD FROM [dbo].[vw_TendenciaMetalMD] WHERE Equipo = 'CA3160' AND Parametro = 'Fe';
SET STATISTICS TIME OFF;
-- Si (2) vuela y (1) no, el problema es el LIKE bloqueando el pushdown -> se arregla en el FLUJO.
-- Si las DOS tardan, el problema es la vista -> es la regresion de hoy.

-- (3) TRAS DESPLEGAR LA REVERSION de F4.2 ('Proyecto' fuera de la clave de 'acc'), repetir (1).
--     Objetivo: que (1) baje a segundos.

-- (4) EQUIVALENCIA: revertir F4.2 no puede mover ningun numero (se midieron 0 colisiones).
SELECT Equipo, Compartimiento, Parametro, Acumulado, NmAcum
FROM [dbo].[vw_TendenciaElemento]
WHERE Equipo = 'CA3160' AND Compartimiento LIKE '%TRACCION%LH' AND Parametro IN ('Fe','PQ','Cr','Al');
-- Esperado EXACTO (BLOQUE 124): Fe 3718.7 (27) | PQ 1462.6 (27) | Cr 19.1 (27) | Al 4.4 (27).

-- (5) Y que lo demas sigue igual: los tamanos del BLOQUE 126/127.
SELECT 'TendenciaMD' AS Vista, LEN(MD) AS Chars FROM [dbo].[vw_TendenciaMD]
WHERE Equipo = 'CA3160' AND compAbbr = 'MT LH'
UNION ALL SELECT 'TendenciaMetalMD', LEN(MD) FROM [dbo].[vw_TendenciaMetalMD]
WHERE Equipo = 'CA3160' AND Parametro = 'Fe'
UNION ALL SELECT 'GraficoMD', LEN(MD) FROM [dbo].[vw_TendenciaGraficoMD]
WHERE Equipo = 'CA3160' AND compAbbr = 'MT LH' AND Parametro = 'Fe';
-- Esperado: TendenciaMD 2 976 y TendenciaMetalMD 1 117.

-- (6) SI (2) TAMBIEN VUELA TRAS LA REVERSION pero (1) sigue lento, el arreglo va en el FLUJO:
--     cambiar 'Equipo LIKE ''%<equipo>%''' por una comparacion anclada. El codigo real es 'CA' + 4
--     digitos y el usuario escribe los 4 digitos, asi que basta con anclar el final:
--        WHERE Equipo LIKE '%' + '<equipo>'   -- sin el % final
--     ⚠ Cambia los 4 flujos si se aplica; probar primero SOLO en MD_metal.
SET STATISTICS TIME ON;
SELECT MD FROM [dbo].[vw_TendenciaMetalMD]
WHERE Equipo LIKE '%' + '3160' AND Parametro = 'Fe';
SET STATISTICS TIME OFF;

-- RESULTADOS BLOQUE 128 (25/09) -- la regresion esta ARREGLADA, y de paso salio OTRA cosa:
-- (1) Query EXACTA del flujo (LIKE '%3160%'):  30 419 ms | CPU 5 906 ms.  Antes: >120 s (timeout).
--     => El flujo YA NO se cae: 30 s contra un tope de 120 s.
-- (2) La misma con '=':                         6 152 ms | CPU 1 141 ms.
--     => 🔴 EL 'LIKE ''%x%''' CUESTA 5 VECES MAS QUE EL '='. Eso NO es de hoy: es como estan escritos
--        los 4 flujos desde siempre. La regresion de F4.2 solo lo hizo visible al sumarse.
-- (4) EQUIVALENCIA OK: Fe 3718.7 (27) | PQ 1462.6 (27) | Cr 19.1 (27) | Al 4.4 (27). Revertir no movio
--     ningun numero, como debia ser (0 colisiones medidas).
-- (5) Tamanos intactos: TendenciaMD 2 976 | TendenciaMetalMD 1 117 | GraficoMD 1 178.

-- ==== BLOQUE 129 - la palanca que quedo a la vista: anclar el LIKE del equipo ====
-- POR QUE: los 4 flujos comparan 'Equipo LIKE ''%<equipo>%''', con comodin a AMBOS lados. Eso impide
--   cualquier busqueda por indice. El BLOQUE 128 lo midio: 30 s contra 6 s.
--   Los codigos son 'CA' + 4 digitos y el usuario escribe los 4 digitos o el codigo entero, asi que
--   basta con quitar el comodin FINAL: 'LIKE ''%'' + <equipo>' (termina en).
-- ⛔ NO tocar los 4 flujos de golpe. Medir, y aplicar primero SOLO en MD_metal, que es el que se cayo.

-- (1) LA MEDICION, sobre la vista que se cayo.
SET STATISTICS TIME ON;
SELECT MD FROM [dbo].[vw_TendenciaMetalMD] WHERE Equipo LIKE '%' + '3160' AND Parametro = 'Fe';
SET STATISTICS TIME OFF;
-- Comparar con los 30 419 ms de LIKE '%3160%' y los 6 152 ms de '='. Si se acerca al '=', la palanca sirve.

-- (2) CORRECCION: que devuelva LO MISMO escriba el usuario los 4 digitos o el codigo entero.
SELECT '4 digitos' AS Forma, COUNT(*) AS Filas FROM [dbo].[vw_TendenciaMetalMD]
WHERE Equipo LIKE '%' + '3160' AND Parametro = 'Fe'
UNION ALL
SELECT 'codigo entero', COUNT(*) FROM [dbo].[vw_TendenciaMetalMD]
WHERE Equipo LIKE '%' + 'CA3160' AND Parametro = 'Fe'
UNION ALL
SELECT 'comodin a ambos lados (hoy)', COUNT(*) FROM [dbo].[vw_TendenciaMetalMD]
WHERE Equipo LIKE '%3160%' AND Parametro = 'Fe';
-- Esperado: las TRES con el mismo numero de filas. Si la anclada devuelve menos, hay codigos con sufijo
-- y NO se puede anclar: se queda como esta.

-- (3) ⚠ EL CASO QUE ROMPERIA EL ANCLAJE: codigos de equipo que no terminen en los 4 digitos.
SELECT TOP 20 Equipo FROM [dbo].[vw_DiagnosticoEquipo]
WHERE Equipo NOT LIKE '[A-Z][A-Z][0-9][0-9][0-9][0-9]'
GROUP BY Equipo ORDER BY Equipo;
-- Si sale VACIO, todos son 'XX####' y anclar es seguro. Si sale algo, mirarlo antes de tocar el flujo.

-- (4) El otro modulo pesado, para saber cuanto gana el resto si se generaliza.
SET STATISTICS TIME ON;
SELECT LEN(MD) FROM [dbo].[vw_TendenciaMD] WHERE Equipo LIKE '%3160%' AND compAbbr = 'MT LH';
SELECT LEN(MD) FROM [dbo].[vw_TendenciaMD] WHERE Equipo LIKE '%' + '3160' AND compAbbr = 'MT LH';
SET STATISTICS TIME OFF;
-- Compararlas entre si y con los 5 764 ms del BLOQUE 127 (que se midio con '=').

-- RESULTADOS BLOQUE 129 (25/09) -- la palanca NO vale la pena. Se DESCARTA anclar el LIKE.
-- (1) vw_TendenciaMetalMD:  LIKE '%3160%' 30 419 ms | anclado 26 600 ms | '=' 6 152 ms.
--     => anclar gana solo un 12%. El salto de verdad (5x) es el '=', no el ancla.
-- (2) Las tres formas devuelven 1 fila: son equivalentes. El anclaje seria CORRECTO, pero no rinde.
-- (3) 🔴 Y los codigos NO son uniformes: 20 equipos NO siguen 'XX####' -- salen '3118', '5103', '6112',
--     '6113'... o sea numeros pelados sin prefijo. Eso descarta tambien la otra idea (normalizar el
--     codigo a 'CA####' en el dispatcher para poder comparar con '='): romperia esos 20.
-- (4) 🔴 EL DATO IMPORTANTE, y no era el que buscaba: vw_TendenciaMD con LIKE cuesta 35 838 ms
--     (anclado 34 528 ms) contra los 5 764 ms que midio el BLOQUE 127 con '='.
--     => El modulo de tendencia fusionado cuesta ~35 s EN PRODUCCION, no 5,8 s. Entra en el tope de
--     120 s del conector y en Teams responde, pero el numero real es ese.
--     ⚠ Es la MISMA leccion del BLOQUE 128: medir con el operador de produccion, no solo con el valor.
-- DECISION: no se toca ningun flujo. 12% no justifica editar 4 flujos con codigos heterogeneos.
--   Si algun dia hay que ganar tiempo de verdad, la palanca es la vista (una sola pasada), no el WHERE.

-- ==== BLOQUE 130 - F3 REDEFINIDO: el cuadro de /tendencia ARRIBA de la grafica ====
-- ⛔ AQUI SE MIDE CON 'LIKE', COMO EL FLUJO. Es la leccion de los BLOQUES 128 y 129: medir con '=' dio
--    numeros 5x optimistas y escondio una regresion hasta que revento en produccion.
-- QUE CAMBIO: el subtitulo de una linea (Mod./Lubric./SMR...) se reemplaza por el CUADRO ENTERO de
--   /tendencia, embebido de p1.MD_Contexto. Va en vw_TendenciaGraficoMD y en vw_TendenciaGraficoObsMD.
--   Cada una gana un LEFT JOIN a vw_TendenciaP1MD -> una lectura mas. Eso es lo que hay que vigilar.

-- (1) LA SALIDA: /grafica con el cuadro arriba.
SELECT MD FROM [dbo].[vw_TendenciaGraficoMD]
WHERE Equipo LIKE '%3160%' AND compAbbr = 'MT LH' AND Parametro = 'Fe';
-- Esperado, en orden: 'Tendencia - CA3160 - MT LH - ultimas 6 muestras' | la tabla Campo x fechas
-- (SMR, Hrs Aceite, Hrs Comp, CM, Estado, Grado) | '**Grafica de Fe**' | la fila del parametro |
-- los limites | el bloque ``` con la curva.

-- (2) EL COSTO, con el operador de produccion. ⚠ Correr DOS veces y quedarse con la segunda.
SET STATISTICS TIME ON;
SELECT LEN(MD) FROM [dbo].[vw_TendenciaGraficoMD]
WHERE Equipo LIKE '%3160%' AND compAbbr = 'MT LH' AND Parametro = 'Fe';
SET STATISTICS TIME OFF;
-- 🔴 EL UMBRAL: el conector muere a los 120 s. Si esto pasa de ~60 s, NO se despliega tal cual y hay
--    que embeber la tabla sin pasar por P1. Referencia: vw_TendenciaMD con LIKE cuesta ~35 s.

-- (3) Las graficas de observados, igual.
SELECT MD FROM [dbo].[vw_TendenciaGraficoObsMD] WHERE Equipo LIKE '%3160%' AND compAbbr = 'MT LH';
SET STATISTICS TIME ON;
SELECT LEN(MD) FROM [dbo].[vw_TendenciaGraficoObsMD] WHERE Equipo LIKE '%3160%' AND compAbbr = 'MT LH';
SET STATISTICS TIME OFF;

-- (4) EL CASO SIN GRAFICAS: un componente sin metales observados debe seguir mostrando el cuadro y
--     explicando que no hay nada que graficar. ⛔ Ninguno puede salir NULL.
SELECT compAbbr, LEN(MD) AS Chars FROM [dbo].[vw_TendenciaGraficoObsMD] WHERE Equipo LIKE '%3160%';
-- Esperado: 6 filas, todas con Chars > 0. Motor y Sist. Hidr. son los que no tienen observados.

-- (5) Que no se rompio el resto de la familia (los tamanos conocidos).
SELECT 'TendenciaMD' AS Vista, LEN(MD) AS Chars FROM [dbo].[vw_TendenciaMD]
WHERE Equipo LIKE '%3160%' AND compAbbr = 'MT LH'
UNION ALL SELECT 'TendenciaMetalMD', LEN(MD) FROM [dbo].[vw_TendenciaMetalMD]
WHERE Equipo LIKE '%3160%' AND Parametro = 'Fe';
-- Esperado: 2 976 y 1 117.

-- RESULTADOS BLOQUE 130 (25/09) -- F3 redefinido: SALE, y con margen:
-- (1) /grafica Fe MT LH imprime, en orden: 'Tendencia - CA3160 - MT LH - ultimas 6 muestras' | la tabla
--     Campo x fechas (SMR, Hrs Aceite, Hrs Comp, CM, Estado, Grado) | '**Grafica de Fe**' | la fila del
--     parametro | los limites | la curva. Es exactamente lo que se pidio.
-- (2) COSTO con el operador de produccion (LIKE): 21 506 ms | CPU 4 032 ms. Umbral era 60 s => PASA,
--     y con holgura frente a los 120 s del conector. Es MENOS que vw_TendenciaMD (~35 s).
-- (3) Graficas de observados: mismo cuadro arriba. 11 001 ms.
-- (4) LOS 6 COMPONENTES CON TEXTO, ninguno NULL: Motor 714 | MT LH 2 158 | MT RH 2 963 | RD LH 4 475 |
--     RD RH 5 286 | Sist. Hidr. 696. Los dos cortos son los que NO tienen metales observados: conservan
--     el cuadro y explican que no hay nada que graficar.
-- (5) Sin danos: TendenciaMD 2 976 y TendenciaMetalMD 1 117.
-- ⚠ Nota: el LEFT JOIN a P1 se temia por lo de /tendenciametal, pero aqui NO duele: 21 s. La diferencia
--   es que las vistas de grafica trabajan sobre UN componente, no sobre los seis.
-- => EL SQL DEL BLOQUE F QUEDA CERRADO. Lo que falta es Copilot.

-- ==== BLOQUE 131 - /triage da FlowActionTimedOut tras el fix de CompTipo (25/09) ====
-- QUE SE SABE:
--   * /incipiente Antapaccay hidraulico YA FUNCIONA (11 de 36, Sistemas Hidraulicos) -> el CASE traduce bien.
--   * /triage traccion Antapaccay -> FlowActionTimedOut. En el trigger se ve 'text = MT', o sea que la
--     formula SI se aplica a /triage (traccion -> MT) y el CASE lo mapea a TRACCION. La traduccion es
--     correcta; lo que no aguanta es el TIEMPO.
-- ⚠ OJO CON LA CONCLUSION FACIL: antes del fix, /triage devolvia 'no encontre datos' AL INSTANTE porque
--   'CompTipo LIKE ''%MT%''' no casaba con nada. Nunca llego a hacer el trabajo. O sea que ESTA ES LA
--   PRIMERA VEZ que se mide el triage de verdad desde que se toco la fundacion (E3, 25/09).
--   => Hay DOS hipotesis y hay que separarlas ANTES de tocar nada.

-- (1) HIPOTESIS A: el CASE rompe el pushdown del filtro. Query tal como la tiene el flujo AHORA.
SET STATISTICS TIME ON;
SELECT MD, Observados, Recomendaciones
FROM dbo.vw_TriageMD v
CROSS APPLY (VALUES ('MT')) x(c)
WHERE v.Proyecto LIKE '%Antapaccay%'
  AND v.Modelo LIKE '%(todos)%'
  AND v.CompTipo = CASE
      WHEN x.c COLLATE Latin1_General_CI_AI LIKE '%tracc%'    OR x.c LIKE 'MT%' THEN 'TRACCION'
      WHEN x.c COLLATE Latin1_General_CI_AI LIKE '%rueda%'    OR x.c LIKE 'RD%' THEN 'RUEDA'
      WHEN x.c COLLATE Latin1_General_CI_AI LIKE '%hidr%'     OR x.c LIKE 'SH'  THEN 'HIDRAULICO'
      WHEN x.c COLLATE Latin1_General_CI_AI LIKE '%mando%'    THEN 'MANDO'
      WHEN x.c COLLATE Latin1_General_CI_AI LIKE '%transmis%' THEN 'TRANSMISION'
      WHEN x.c COLLATE Latin1_General_CI_AI LIKE '%motor%'    THEN 'MOTOR'
      ELSE x.c END;
SET STATISTICS TIME OFF;

-- (2) HIPOTESIS B: el triage es lento de por si. La MISMA consulta con el valor ya resuelto.
SET STATISTICS TIME ON;
SELECT MD, Observados, Recomendaciones
FROM dbo.vw_TriageMD v
WHERE v.Proyecto LIKE '%Antapaccay%' AND v.Modelo LIKE '%(todos)%' AND v.CompTipo = 'TRACCION';
SET STATISTICS TIME OFF;

-- LECTURA, y decide el arreglo:
--   (2) RAPIDA y (1) LENTA  -> es el CASE: rompe el pushdown. El arreglo NO va en SQL sino en el FLUJO:
--       se normaliza ANTES con una accion 'Redactar' y la query queda 'CompTipo = ''<normalizado>'''.
--       (Ver la nota en CONFIG_FLUJOS: expresion 'if(contains(toLower(...)))' anidada.)
--   (1) y (2) LAS DOS LENTAS -> el CASE es inocente y vw_TriageMD es lento de por si. Entonces esto NO
--       es una regresion del fix: es la primera vez que el triage llega a ejecutarse desde el BLOQUE 122
--       (E3 toco Estado_Ca/Zn/Mg en la fundacion, que triage lee). Se mide el margen y se decide aparte.

-- (3) Si las dos son lentas: cuanto cuesta la vista SIN ningun filtro de componente, para ver si el
--     problema es el volumen o el filtro.
SET STATISTICS TIME ON;
SELECT COUNT(*) FROM dbo.vw_TriageMD WHERE Proyecto LIKE '%Antapaccay%';
SET STATISTICS TIME OFF;

-- (4) Y la comparacion que dice si E3 tuvo que ver: el mismo triage por RUEDA, que E3 SI toco
--     (Ca/Zn/Mg invertidos viven en rueda), contra TRACCION, que E3 no cambio.
SET STATISTICS TIME ON;
SELECT LEN(MD) FROM dbo.vw_TriageMD
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%(todos)%' AND CompTipo = 'RUEDA';
SET STATISTICS TIME OFF;

-- RESULTADOS BLOQUE 131 (25/09) -- HIPOTESIS A CONFIRMADA, y con un margen brutal:
-- (1) Con el CASE dentro del WHERE: >15 MINUTOS (abortada).
-- (2) Con CompTipo = 'TRACCION' literal: 4 103 ms | CPU 937 ms. Devuelve el triage completo
--     (4 de 72 observados, 2 criticos; 980E 54 equipos + 930E 18).
-- => ~230x. El CASE impide empujar el filtro dentro de la vista: se construyen los 6 CompTipo y se
--    filtra al final. La traduccion era correcta (MT -> TRACCION); lo que mata es DONDE se hace.
-- (3) COUNT(*) de la vista para Antapaccay = 29 filas en 1 227 ms -> la vista NO es lenta de por si.
-- ⚠ (4) RUEDA con literal seguia corriendo a los 2:48. NO concluyente: el servidor venia de la consulta
--    de 15 min. Repetir en frio antes de sacar conclusiones sobre RUEDA.
-- ⛔ vw_TriageMD NO necesita optimizacion: 4 s con el filtro bien puesto. El problema era el predicado.

-- ==== BLOQUE 132 - los otros dos predicados de los flujos: Proyecto y Modelo ====
-- POR QUE: el usuario observa que "las vistas a veces van bien y a veces se lentean". La causa mas probable
--   es que los 4 flujos comparan con 'LIKE ''%x%''' (comodin a AMBOS lados). Eso (a) impide usar indices y
--   (b) le da al optimizador una estimacion de cardinalidad pesima, asi que el plan que se cachea puede
--   ser bueno o malo casi por azar -> la misma consulta va rapida un dia y lenta otro.
-- Aqui se mide cuanto se gana resolviendo tambien Proyecto y Modelo en el flujo, como se hizo con CompTipo.
-- ⚠ Correr cada par SEGUIDO y en frio. Y repetir dos veces: la primera paga compilacion.

-- (1) PROYECTO: comodin vs igualdad.
SET STATISTICS TIME ON;
SELECT LEN(MD) FROM dbo.vw_TriageMD WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%(todos)%' AND CompTipo = 'TRACCION';
SELECT LEN(MD) FROM dbo.vw_TriageMD WHERE Proyecto = 'Antapaccay'      AND Modelo LIKE '%(todos)%' AND CompTipo = 'TRACCION';
SET STATISTICS TIME OFF;

-- (2) MODELO: comodin vs igualdad. '(todos)' es un literal fijo que pone el tema, no lo escribe el usuario.
SET STATISTICS TIME ON;
SELECT LEN(MD) FROM dbo.vw_TriageMD WHERE Proyecto = 'Antapaccay' AND Modelo LIKE '%(todos)%' AND CompTipo = 'TRACCION';
SELECT LEN(MD) FROM dbo.vw_TriageMD WHERE Proyecto = 'Antapaccay' AND Modelo = '(todos)'      AND CompTipo = 'TRACCION';
SET STATISTICS TIME OFF;

-- (3) Los nombres de proyecto que existen, para saber si '=' es viable (igual que se hizo con los equipos).
SELECT DISTINCT Proyecto FROM dbo.vw_TriageMD ORDER BY Proyecto;
-- Si son 5-6 nombres limpios, el flujo puede resolverlos con un 'Redactar' y comparar con '='.
-- ⛔ Si hay variantes con espacios o mayusculas distintas, NO: se queda el LIKE.

-- (4) RUEDA en frio, que quedo sin medir por el arrastre de la consulta de 15 min.
SET STATISTICS TIME ON;
SELECT LEN(MD) FROM dbo.vw_TriageMD WHERE Proyecto = 'Antapaccay' AND Modelo = '(todos)' AND CompTipo = 'RUEDA';
SET STATISTICS TIME OFF;
-- Si RUEDA tarda MUCHO mas que TRACCION con el mismo filtro, entonces si hay algo en la vista que mirar
-- (y el sospechoso seria E3, que cambio Estado_Ca/Zn/Mg y esos viven en rueda).

-- RESULTADOS BLOQUE 132 (25/09) -- confirman que la vista SI estaba mal, no solo el predicado:
-- (1) Proyecto LIKE '%Antapaccay%' -> 113 780 ms | Proyecto = 'Antapaccay' -> 62 494 ms.
--     🔴 Y la MISMA consulta habia dado 4 103 ms en el BLOQUE 131. Eso es lo que el usuario venia
--     describiendo: "van bien, luego se lentean, luego normal". No es percepcion: es el plan, que con
--     estimaciones pesimas sale bueno o malo casi por azar. El '=' ayuda (62 vs 114 s) pero NO arregla.
-- (3) Proyectos: Antamina, Antapaccay, Cerro Verde, Cuajone, Toquepala, Toromocho. 6 nombres limpios
--     => comparar con '=' es viable (se puede resolver en el flujo, como CompTipo).
-- (4) RUEDA en frio: 61 022 ms. Mismo orden que TRACCION => NO es cosa de E3 ni de un componente.
-- CONCLUSION: el problema de fondo es la VISTA, no el WHERE. Eso habilita el BLOQUE 133.

-- ==== BLOQUE 133 - vw_TriageMD reestructurada (25/09) ====
-- QUE CAMBIO (ninguna linea de formato; es rendimiento):
--   1. 'met' ELIMINADA. Los metales observados se agregan con OUTER APPLY dentro de 'rows_', sobre la
--      MISMA fila. Antes 'rows_' leia 'mg' y le hacia LEFT JOIN a 'met', que TAMBIEN salia de 'mg':
--      el anti-patron nº1 (CTE referenciado 2x + JOIN entre sus ramas -> nested loops), el mismo que
--      mato al barrido (6:21 -> 19,5 s).
--   2. 'obs' queda SOLO para las recomendaciones y filtra CompTipo='TRACCION' EN EL ORIGEN.
--   3. 'lbl' ELIMINADA: era un CTE que re-leia 'body' solo para poner una etiqueta -> ahora es un CASE.

-- (1) EQUIVALENCIA PRIMERO. ⛔ Si un solo caracter cambia, se revierte: esto es rendimiento.
SELECT LEN(MD) AS Largo, LEFT(MD, 120) AS Cabecera
FROM dbo.vw_TriageMD WHERE Proyecto = 'Antapaccay' AND Modelo = '(todos)' AND CompTipo = 'TRACCION';
-- Esperado: la misma cabecera del BLOQUE 131: 'Triage Motores de Traccion - Antapaccay - 4 de 72
-- observados (2 criticos)'. Y el MD con las secciones '### 980E - 54 equipos (4 obs)' y '### 930E - 18'.

-- (2) EL TIEMPO, con el predicado tal como queda el flujo ahora (CompTipo literal).
--     ⚠ Correr DOS VECES y quedarse con la segunda: la primera paga compilacion.
SET STATISTICS IO ON; SET STATISTICS TIME ON;
SELECT LEN(MD) FROM dbo.vw_TriageMD WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%(todos)%' AND CompTipo = 'TRACCION';
SET STATISTICS IO OFF; SET STATISTICS TIME OFF;
-- REFERENCIAS a batir: 113 780 ms (BLOQUE 132) y los 4 103 ms del caso afortunado (BLOQUE 131).
-- El objetivo NO es solo bajar la media: es que DEJE DE VARIAR. Mirar tambien 'scan count' de
-- LaboratoryData: si baja, es que ya no se re-ejecuta la fundacion por cada rama.

-- (3) ESTABILIDAD, que es lo que de verdad se persigue. Cuatro combinaciones seguidas.
SET STATISTICS TIME ON;
SELECT LEN(MD) FROM dbo.vw_TriageMD WHERE Proyecto = 'Antapaccay' AND Modelo = '(todos)' AND CompTipo = 'TRACCION';
SELECT LEN(MD) FROM dbo.vw_TriageMD WHERE Proyecto = 'Antapaccay' AND Modelo = '(todos)' AND CompTipo = 'RUEDA';
SELECT LEN(MD) FROM dbo.vw_TriageMD WHERE Proyecto = 'Antamina'   AND Modelo = '(todos)' AND CompTipo = 'TRACCION';
SELECT LEN(MD) FROM dbo.vw_TriageMD WHERE Proyecto = 'Antapaccay' AND Modelo = '(todos)' AND CompTipo = 'HIDRAULICO';
SET STATISTICS TIME OFF;
-- Lo que se busca: cuatro tiempos PARECIDOS. Si uno se dispara, el problema sigue vivo.

-- (4) Que las recomendaciones no se perdieron al filtrar TRACCION en el origen.
SELECT Proyecto, CompTipo, LEN(Recomendaciones) AS LargoReco
FROM dbo.vw_TriageMD
WHERE Proyecto = 'Antapaccay' AND Modelo = '(todos)' AND CompTipo IN ('TRACCION','RUEDA');
-- Esperado: TRACCION con texto (Fe/PQ y Cr, con la lista de equipos) y RUEDA en NULL, como antes.

-- (5) Que el modelo concreto sigue funcionando (la rama que NO es '(todos)').
SELECT LEN(MD) FROM dbo.vw_TriageMD WHERE Proyecto = 'Antapaccay' AND Modelo = '980E' AND CompTipo = 'TRACCION';
-- Esperado: texto, y SIN los sub-titulos '### 980E' (esos solo salen en '(todos)').

-- RESULTADOS BLOQUE 133 (25/09) -- la reestructuracion de vw_TriageMD: 132x y, sobre todo, ESTABLE:
-- (1) EQUIVALENCIA: 5 438 chars y la misma cabecera ('4 de 72 observados (2 criticos)', '### 980E -
--     54 equipos (4 obs)'). No se movio un caracter.
-- (2) 860 ms | CPU 171 ms | 🔴 LaboratoryData: 1 SCAN / 1 364 lecturas.
--     Antes: 113 780 ms. => 132x. Y el scan count de 1 es LA PRUEBA de que la fundacion ya no se
--     re-ejecuta por cada rama: era exactamente el anti-patron nº1.
-- (3) ESTABILIDAD, que era el objetivo real: 1 040 / 972 / 1 098 / 940 ms en cuatro combinaciones
--     distintas. Antes la MISMA consulta daba 4 s, 62 s o 114 s segun el plan que tocara.
-- (4) Recomendaciones intactas: TRACCION 676, RUEDA NULL.
-- (5) Modelo concreto (980E): 4 372 chars, sin los sub-titulos '###'. Correcto.

-- ==== BLOQUE 134 - G2 modo A: los dos fallos silenciosos que quedaban ====
-- COMO SE ENCONTRARON: barriendo las 30 vistas '...MD' y buscando columnas de cuerpo que vengan de un
-- LEFT JOIN y se usen SIN ISNULL. De 12 candidatas, 10 ya estaban protegidas (CASE WHEN ... IS NOT NULL).
-- Quedaban DOS de verdad:
--   1. vw_TendenciaMD: 'lb.bodyMD' (tabla de limites). Si el componente NO tiene limites cargados, viene
--      NULL y ANULA TODO EL MD -> /tendencia responde 'no encontre datos' con un equipo que SI tiene
--      muestras. ⚠ Hay 45 combinaciones proyecto+modelo sin limites (BLOQUE 102): Cuajone y Toquepala
--      enteros entre ellas.
--   2. vw_ObservadosBarridoMD: 'ca.Secciones' y 'pa.Secciones'. Sin criticos (o sin precauciones) el MD
--      se anula -> '/barrido solo los criticos' dice 'no encontre datos' cuando la respuesta correcta es
--      'ninguno esta critico', que es una BUENA noticia.

-- (1) EL CASO DE LOS LIMITES. Un componente de un proyecto SIN limites cargados.
--     Primero, encontrar uno de verdad:
SELECT TOP 5 Proyecto, Equipo, Compartimiento
FROM [dbo].[vw_TendenciaElemento]
WHERE LP IS NULL AND Proyecto IN ('Cuajone','Toquepala')
GROUP BY Proyecto, Equipo, Compartimiento ORDER BY Proyecto, Equipo;
-- Con uno de esos, comprobar que el MD ya NO sale NULL:
-- SELECT compAbbr, LEN(MD) AS Chars, RIGHT(MD, 320) AS Cierre
-- FROM [dbo].[vw_TendenciaMD] WHERE Equipo = '<el de arriba>';
-- ESPERADO: Chars > 0 y el texto '_Sin limites (LP/LC) cargados ... ⚠ Esto no significa que esten
-- dentro de limite._' donde antes iba la tabla de limites.

-- (2) NO-REGRESION: un componente que SI tiene limites debe salir exactamente igual que antes.
SELECT LEN(MD) AS Chars FROM [dbo].[vw_TendenciaMD] WHERE Equipo = 'CA3160' AND compAbbr = 'MT LH';
-- ESPERADO EXACTO: 2 976 (BLOQUE 127). ⛔ Si cambio, el CASE nuevo se colo donde no debia.

-- (3) EL BARRIDO SIN CRITICOS. Buscar una flota que no tenga ninguno:
SELECT Proyecto, Modelo, NumEquipos, NumEquiposCriticos, NumEquiposSoloPrecau
FROM [dbo].[vw_ObservadosBarridoMD] ORDER BY NumEquiposCriticos, Proyecto;
-- Con la primera fila de NumEquiposCriticos = 0:
-- SELECT LEN(MD_Criticos) AS Chars, LEFT(MD_Criticos, 300) AS Texto
-- FROM [dbo].[vw_ObservadosBarridoMD] WHERE Proyecto = '<proy>' AND ISNULL(Modelo,'') = '<modelo>';
-- ESPERADO: Chars > 0 y el mensaje 'Ningun equipo de esta flota esta en estado critico...'.

-- (4) NO-REGRESION del barrido: una flota QUE SI tiene criticos.
SELECT TOP 1 Proyecto, Modelo, LEN(MD) AS Todos, LEN(MD_Criticos) AS Criticos, LEN(MD_Precaucion) AS Precau
FROM [dbo].[vw_ObservadosBarridoMD] WHERE NumEquiposCriticos > 0 ORDER BY NumEquiposCriticos DESC;
-- ESPERADO: los tres con texto, y el de criticos SIN el mensaje nuevo.

-- (5) Barrido general de NULOS, que es lo que de verdad cierra G2 modo A.
SELECT 'TendenciaMD'   AS Vista, SUM(CASE WHEN MD IS NULL THEN 1 ELSE 0 END) AS Nulos, COUNT(*) AS Filas
FROM [dbo].[vw_TendenciaMD] WHERE Equipo IN ('CA3160','CA3161','CA3176','CA3177')
UNION ALL
SELECT 'BarridoMD_Criticos', SUM(CASE WHEN MD_Criticos IS NULL THEN 1 ELSE 0 END), COUNT(*)
FROM [dbo].[vw_ObservadosBarridoMD]
UNION ALL
SELECT 'BarridoMD_Precaucion', SUM(CASE WHEN MD_Precaucion IS NULL THEN 1 ELSE 0 END), COUNT(*)
FROM [dbo].[vw_ObservadosBarridoMD];
-- ESPERADO: Nulos = 0 en las tres.

-- ==== BLOQUE 135 - comprobar el CA3175 antes de llamarlo error (25/09) ====
-- SINTOMA: '/diagcompleto 3175' marca Ca 185.5/200.3, Zn 0.6/4.3, Mg 0.3/0.1 en RD LH y RD RH, Na 7.0/6.7
--   y PQ 3.4 en Motor. Antes de tocar nada hay que ver si el DATO es asi.
-- ⚠ Ojo con el reflejo: en rueda los aditivos van INVERTIDOS (alerta por DEBAJO), asi que un Ca de 185.5
--   contra un LC de ~1560 SI es una alerta legitima. Lo que hay que confirmar es el VALOR y el LIMITE.

-- (1) El dato crudo del equipo, componente por componente.
SELECT Compartimiento, Ca_ppm, Ca_LP, Ca_LC, Zn_ppm, Zn_LP, Zn_LC, Mg_ppm, Mg_LP, Mg_LC,
       Na_ppm, Na_LP, Na_LC, Indice_PQ, PQ_LP, PQ_LC, FechaMuestreo
FROM [dbo].[vw_MuestrasRankeadas]
WHERE Equipo = 'CA3175' AND rn_recencia = 1
ORDER BY Compartimiento;
-- LECTURA: para RD LH/RH, si Ca_LP > Ca_LC el limite esta INVERTIDO y un valor por DEBAJO del LC es
-- alerta correcta. Si Ca_LP < Ca_LC, entonces la marca esta mal y hay que mirar el fix E3.

-- (2) Como lo esta evaluando la fundacion (el sufijo ':C'/':P' es lo que pinta la celda).
SELECT Compartimiento, Ca, Zn, Mg, Na, PQ, Estado_General
FROM [dbo].[vw_DiagnosticoEquipo] WHERE Equipo = 'CA3175' ORDER BY Compartimiento;

-- (3) Y el contraste que zanja la duda: el MISMO equipo en /ultimo, que calcula la marca por otro
--     camino (el formato con Inv). Los dos tienen que decir lo mismo.
SELECT compAbbr, LEFT(MD, 600) AS Cabecera
FROM [dbo].[vw_UltimoAnalisisMD] WHERE Equipo = 'CA3175' AND compAbbr LIKE 'RD%';
-- Si /ultimo y /diagcompleto coinciden, NO hay error: el equipo tiene los aditivos agotados en las
-- ruedas y eso es exactamente lo que el bloque E3 vino a destapar.

-- RESULTADOS BLOQUE 135 (25/09) -- NO HAY ERROR: el CA3175 tiene los aditivos agotados de verdad.
-- (1) El dato crudo, RUEDA DELANTERA LH y RH:
--       Ca 185.47 / 200.29  con LP 2080 y LC 1560  -> LP > LC, limite INVERTIDO. 185 << 1560 = CRITICO.
--       Zn   0.64 /   4.25  con LP  960 y LC  720  -> idem.
--       Mg   0.34 /   0.11  con LP   12 y LC    9  -> idem.
--       Na   7.02 /   6.68  con LP    4 y LC    5  -> NO invertido: 7.02 > 5 = CRITICO por arriba.
--       MOTOR: PQ 3.4 con LP 3 y LC 4 -> PRECAUCION. Correcto.
-- (2) La fundacion lo marca igual: 'Ca 185.5:C', 'Zn 0.6:C', 'Mg 0.3:C', 'Na 7.0:C', 'PQ 3.4:P'.
-- (3) Y /ultimo, que calcula la marca por OTRO camino (el formato con Inv), dice EXACTAMENTE lo mismo:
--     RD LH -> Ca 2080/1560/185.5 marcado | Zn 960/720/0.6 marcado | Mg 12/9/0.3 marcado | Na 4/5/7.0 marcado.
-- => Los dos mecanismos coinciden. El equipo tiene el aceite de las dos ruedas delanteras con el paquete
--    de aditivos practicamente agotado (Ca al 12% de su minimo). Es EXACTAMENTE lo que el bloque E3 vino
--    a destapar: antes esas alertas no salian porque se juzgaban al reves.
-- ⚠ Vale la pena comentarselo a Carlos: no es un falso positivo, es un hallazgo.


/* ============================================================================
   RONDA 28/09 — bloques 136-140. Reconocimiento ANTES de tocar nada.
   ⛔ Todos filtran por equipo/proyecto y NINGUNO lee una vista *MD entera:
      es la leccion de los bloques 119(2), 123(2) y 134(5) (12 min sin devolver).
   ============================================================================ */

-- ==== BLOQUE 136 - ComponentStatus: que valores tiene y cual es el "En Uso" ====
-- POR QUE: Carlos dio el metodo del acumulado de vida y empieza por "filtrar lo que esta en uso".
--   La columna existe y jamas la usamos: [Oil].[LaboratoryData].[ComponentStatus] (varchar).
--   Sin saber sus valores exactos no se puede escribir el filtro. Barato: GROUP BY sobre una sola
--   columna, sin JOIN y sin window.
SELECT LD.[ComponentStatus], COUNT(*) AS Filas,
       MIN(LD.[FechaMuestreo]) AS Desde, MAX(LD.[FechaMuestreo]) AS Hasta
FROM [Oil].[LaboratoryData] LD WITH (NOLOCK)
GROUP BY LD.[ComponentStatus]
ORDER BY Filas DESC;
GO
-- 136.2 Lo mismo pero SOLO del componente de referencia, para ver como se reparte dentro de un
--       componente concreto (el que Carlos uso de ejemplo).
SELECT LD.[ComponentStatus], LD.[CM], COUNT(*) AS Filas,
       MIN(LD.[FechaMuestreo]) AS Desde, MAX(LD.[FechaMuestreo]) AS Hasta,
       CAST(SUM(LD.[Fe_ppm]) AS decimal(18,1)) AS SumaFe
FROM [Oil].[LaboratoryData] LD WITH (NOLOCK)
JOIN [Mine].[MiningEquipment] ME WITH (NOLOCK) ON ME.[Id] = LD.[MiningEquipmentId]
WHERE ME.[Code] = 'CA3195' AND LD.[Compartimiento] LIKE '%TRACCION%LH'
GROUP BY LD.[ComponentStatus], LD.[CM]
ORDER BY LD.[ComponentStatus], Filas DESC;
GO
-- 136.3 Universo de valores de CM por tipo de componente (para confirmar ADI/C/M/MONI/PM/DDI).
--       Confirma la regla que dio Carlos: MT suma ADI+C, Rueda solo C, MODI todos, SH solo C.
SELECT CASE WHEN LD.[Compartimiento] LIKE '%TRACCION%'    THEN 'TRACCION'
            WHEN LD.[Compartimiento] LIKE '%RUEDA%'       THEN 'RUEDA'
            WHEN LD.[Compartimiento] LIKE '%HIDRAUL%'     THEN 'HIDRAULICO'
            WHEN LD.[Compartimiento] LIKE 'MOTOR%'        THEN 'MOTOR'
            ELSE 'OTRO' END AS CompTipo,
       LD.[CM], COUNT(*) AS Filas
FROM [Oil].[LaboratoryData] LD WITH (NOLOCK)
JOIN [Mine].[MiningEquipment] ME WITH (NOLOCK) ON ME.[Id] = LD.[MiningEquipmentId]
JOIN [Mine].[MiningProject]   MP WITH (NOLOCK) ON MP.[Id] = ME.[MiningProjectId]
WHERE MP.[Name] LIKE '%Antapaccay%'
GROUP BY CASE WHEN LD.[Compartimiento] LIKE '%TRACCION%'    THEN 'TRACCION'
              WHEN LD.[Compartimiento] LIKE '%RUEDA%'       THEN 'RUEDA'
              WHEN LD.[Compartimiento] LIKE '%HIDRAUL%'     THEN 'HIDRAULICO'
              WHEN LD.[Compartimiento] LIKE 'MOTOR%'        THEN 'MOTOR'
              ELSE 'OTRO' END, LD.[CM]
ORDER BY CompTipo, Filas DESC;
GO


-- ==== BLOQUE 137 - REPRODUCIR el acumulado de Carlos: CA3195 MT LH Fe = 3718.6 ====
-- POR QUE: es el bloque B de la ronda 23/09, que llevaba bloqueado desde el 25/09 porque la cifra
--   no salia con ningun criterio. Carlos dio el metodo: En Uso + CM por componente + TODA la vida.
--   Hoy la vista muestra 5124.2 (38 muestras) porque (a) no filtra ComponentStatus, (b) no filtra CM
--   y (c) la fundacion ventanea a 12 MESES -> lo que hoy llamamos "Sigma vida" son 12 meses.
-- ⚠ Ajustar el literal de ComponentStatus con lo que devuelva el BLOQUE 136.1.
DECLARE @EnUso nvarchar(50) = N'En Uso';   -- <== poner aqui el valor real de 136.1
SELECT COUNT(*)                              AS Muestras,
       CAST(SUM(LD.[Fe_ppm]) AS decimal(18,1)) AS SumaFe,
       MIN(LD.[FechaMuestreo])               AS Desde,
       MAX(LD.[FechaMuestreo])               AS Hasta
FROM [Oil].[LaboratoryData] LD WITH (NOLOCK)
JOIN [Mine].[MiningEquipment] ME WITH (NOLOCK) ON ME.[Id] = LD.[MiningEquipmentId]
WHERE ME.[Code] = 'CA3195'
  AND LD.[Compartimiento] LIKE '%TRACCION%LH'
  AND LD.[ComponentStatus] = @EnUso
  AND LD.[CM] IN ('ADI','C');           -- regla de MOTOR DE TRACCION
GO
-- 137.2 Las mismas filas, una por una, para cuadrar 1:1 contra la tabla dinamica de Carlos.
--       TOP acotado: un componente en uso no deberia pasar de unas decenas de muestras.
SELECT TOP (200) LD.[FechaMuestreo], LD.[CM], LD.[ComponentStatus],
       LD.[Fe_ppm], LD.[Indice_PQ], LD.[Cr_ppm], LD.[Horometro], LD.[HorasDeAceite]
FROM [Oil].[LaboratoryData] LD WITH (NOLOCK)
JOIN [Mine].[MiningEquipment] ME WITH (NOLOCK) ON ME.[Id] = LD.[MiningEquipmentId]
WHERE ME.[Code] = 'CA3195'
  AND LD.[Compartimiento] LIKE '%TRACCION%LH'
  AND LD.[ComponentStatus] = N'En Uso'
ORDER BY LD.[FechaMuestreo] DESC;
GO
-- 137.3 CUANTO CUESTA leer toda la vida (sin la ventana de 12 meses). Es el riesgo del bloque C:
--       el GROUP BY va sobre 9 anos. Mirar "elapsed time" y "logical reads" en Messages.
--       Si esto es caro, la vista dedicada vw_AcumuladoVida NO se cablea sin resolverlo antes.
SET STATISTICS IO ON; SET STATISTICS TIME ON;
SELECT ME.[Code] AS Equipo, LD.[Compartimiento],
       CAST(SUM(LD.[Fe_ppm]) AS decimal(18,1)) AS Fe_Acum, COUNT(*) AS Muestras
FROM [Oil].[LaboratoryData] LD WITH (NOLOCK)
JOIN [Mine].[MiningEquipment] ME WITH (NOLOCK) ON ME.[Id] = LD.[MiningEquipmentId]
JOIN [Mine].[MiningProject]   MP WITH (NOLOCK) ON MP.[Id] = ME.[MiningProjectId]
WHERE MP.[Name] LIKE '%Antapaccay%'
  AND LD.[ComponentStatus] = N'En Uso'
  AND LD.[Compartimiento] LIKE '%TRACCION%'
  AND LD.[CM] IN ('ADI','C')
GROUP BY ME.[Code], LD.[Compartimiento];
SET STATISTICS IO OFF; SET STATISTICS TIME OFF;
GO


-- ==== BLOQUE 138 - Los 22 limites que [Eqpcare].[lc] SI tiene y la fundacion NO lee ====
-- POR QUE: es la raiz del bloque D. vw_LimitesPorComponente mapea 16 de los 38 parametros de lc.
--   Esto muestra, para el caso que Carlos miro en pantalla, que el dato ESTA.
SELECT [Proyecto], [COMPONENTE], [MODELO],
       [FOSFORO - LP], [FOSFORO - LC],           -- P, invertido (LP 280 > LC 240)
       [BORO - LP], [BORO - LC],
       [MOLIBDENO - LP], [MOLIBDENO - LC],
       [TAN - LP], [TAN - LC],
       [ISO 4um - LP], [ISO 4um - LC], [ISO 6um - LP], [ISO 6um - LC],
       [ISO 14um - LP], [ISO 14um - LC],
       [VISC - LPI], [VISC - LCI], [VISC - LPS], [VISC - LCS],       -- los 4 niveles de V100
       [VISC40 - LPI], [VISC40 - LCI], [VISC40 - LPS], [VISC40 - LCS],
       [H20 - LP], [H20 - LC], [HOLLIN - LP], [HOLLIN - LC],
       [TBN - LP], [TBN - LC]                     -- de TBN hoy solo se lee el LP
FROM [Eqpcare].[lc] WITH (NOLOCK)
WHERE [Proyecto] LIKE '%ANTAPACCAY%' AND [COMPONENTE] LIKE '%TRACCION%';
GO
-- 138.2 Lo mismo para el MOTOR de Antapaccay (donde Carlos dijo que SI van los 4 niveles de
--       viscosidad, y donde el codigo de limpieza NO se mide).
SELECT [Proyecto], [COMPONENTE], [MODELO],
       [VISC - LPI], [VISC - LCI], [VISC - LPS], [VISC - LCS],
       [ISO 4um - LP], [ISO 6um - LP], [ISO 14um - LP],
       [HOLLIN - LP], [HOLLIN - LC], [OXI - LP], [SULF - LP], [NIT - LP],
       [TBN - LP], [TBN - LC], [TAN - LP], [TAN - LC]
FROM [Eqpcare].[lc] WITH (NOLOCK)
WHERE [Proyecto] LIKE '%ANTAPACCAY%' AND [COMPONENTE] LIKE 'MOTOR%'
  AND [COMPONENTE] NOT LIKE '%TRACCION%';
GO


-- ==== BLOQUE 139 - COBERTURA: cuantos de los 38 parametros trae cada proyecto/componente/modelo ====
-- POR QUE: antes de mapear los 22 hay que saber cuales estan realmente cargados y cuales vienen NULL.
--   Un parametro sin fila NO es lo mismo que un parametro que no se mide en ese componente: hoy los
--   dos se pintan '—' y se confunden. Tabla chica (64 filas): barato.
SELECT [Proyecto], [COMPONENTE], [MODELO],
       CASE WHEN [FOSFORO - LP]  IS NULL THEN 0 ELSE 1 END
     + CASE WHEN [BORO - LP]     IS NULL THEN 0 ELSE 1 END
     + CASE WHEN [MOLIBDENO - LP]IS NULL THEN 0 ELSE 1 END
     + CASE WHEN [TAN - LP]      IS NULL THEN 0 ELSE 1 END
     + CASE WHEN [ISO 4um - LP]  IS NULL THEN 0 ELSE 1 END
     + CASE WHEN [ISO 6um - LP]  IS NULL THEN 0 ELSE 1 END
     + CASE WHEN [ISO 14um - LP] IS NULL THEN 0 ELSE 1 END
     + CASE WHEN [VISC - LPI]    IS NULL THEN 0 ELSE 1 END
     + CASE WHEN [VISC40 - LPI]  IS NULL THEN 0 ELSE 1 END
     + CASE WHEN [H20 - LP]      IS NULL THEN 0 ELSE 1 END
     + CASE WHEN [HOLLIN - LP]   IS NULL THEN 0 ELSE 1 END
     + CASE WHEN [OXI - LP]      IS NULL THEN 0 ELSE 1 END
     + CASE WHEN [SULF - LP]     IS NULL THEN 0 ELSE 1 END
     + CASE WHEN [NIT - LP]      IS NULL THEN 0 ELSE 1 END AS DeLos14NuevosRelevantes,
       CASE WHEN [TBN - LC] IS NULL THEN 'sin LC' ELSE 'con LC' END AS TBN
FROM [Eqpcare].[lc] WITH (NOLOCK)
ORDER BY [Proyecto], [COMPONENTE], [MODELO];
GO


-- ==== BLOQUE 140 - H3/H4: el scope del ranking y el parametro Hollin ====
-- H3: /ranking antapaccay mtlh PQ 20 mezclo equipos 3114..3118 (sin limites) con los CA####.
--     Ver que son y de que proyecto/modelo cuelgan.
SELECT ME.[Code] AS Equipo, MP.[Name] AS Proyecto, EF.[Model] AS Modelo, COUNT(*) AS Muestras
FROM [Mine].[MiningEquipment] ME WITH (NOLOCK)
JOIN [Mine].[MiningProject]   MP WITH (NOLOCK) ON MP.[Id] = ME.[MiningProjectId]
LEFT JOIN [Mine].[EquipmentFleet] EF WITH (NOLOCK) ON EF.[Id] = ME.[EquipmentFleetId]
LEFT JOIN [Oil].[LaboratoryData]  LD WITH (NOLOCK) ON LD.[MiningEquipmentId] = ME.[Id]
WHERE ME.[Code] IN ('3114','3115','3116','3117','3118','6114','6116','8108')
GROUP BY ME.[Code], MP.[Name], EF.[Model]
ORDER BY Proyecto, Equipo;
GO
-- H4: el fallback dijo que "Hollin no esta en la base". Comprobar las dos caras:
--     (a) el LIMITE existe en lc  (b) existe o no la COLUMNA de valor en LaboratoryData.
SELECT [Proyecto], [COMPONENTE], [MODELO], [HOLLIN - LP], [HOLLIN - LC]
FROM [Eqpcare].[lc] WITH (NOLOCK)
WHERE [HOLLIN - LP] IS NOT NULL;
GO
SELECT c.name AS Columna, t.name AS Tipo
FROM sys.columns c JOIN sys.types t ON t.user_type_id = c.user_type_id
WHERE c.object_id = OBJECT_ID('[Oil].[LaboratoryData]')
  AND (c.name LIKE '%ollin%' OR c.name LIKE '%oot%' OR c.name LIKE '%TAN%'
       OR c.name LIKE '%ISO%' OR c.name LIKE '%V40%' OR c.name LIKE '%Agua%'
       OR c.name LIKE '%H2%' OR c.name LIKE '%Mo[_]%')
ORDER BY c.name;
GO


-- ==== BLOQUE 141 - Las columnas *_Acum de la tabla: atajo para el bloque C? ====
-- POR QUE: [Oil].[LaboratoryData] trae Fe_Acum, Cr_Acum, Pb_Acum, Cu_Acum, Sn_Acum, Al_Acum y Si_Acum
--   -- acumulados YA CALCULADOS que nunca miramos. Carlos dijo "el campo esta calculado en el BI y no
--   esta en la base de datos"; puede que sea esto, o su origen.
-- SI Fe_Acum de la ultima muestra En Uso del CA3195 MT LH da 3718.6 -> el bloque C se reduce a LEER UNA
--   COLUMNA en vez de sumar 9 anos de historia, y desaparece el riesgo de rendimiento de 137.3.
-- CORRER ESTO ANTES QUE EL BLOQUE C.
SELECT TOP (20) LD.[FechaMuestreo], LD.[CM], LD.[ComponentStatus],
       LD.[Fe_ppm], LD.[Fe_Acum], LD.[Cr_Acum], LD.[Pb_Acum], LD.[Cu_Acum],
       LD.[Sn_Acum], LD.[Al_Acum], LD.[Si_Acum],
       LD.[HorasComponenteParcial], LD.[HorasComponenteAcumulado], LD.[ComponentSerialNumber]
FROM [Oil].[LaboratoryData] LD WITH (NOLOCK)
JOIN [Mine].[MiningEquipment] ME WITH (NOLOCK) ON ME.[Id] = LD.[MiningEquipmentId]
WHERE ME.[Code] = 'CA3195' AND LD.[Compartimiento] LIKE '%TRACCION%LH'
ORDER BY LD.[FechaMuestreo] DESC;
GO
-- 141.2 Que tan poblada esta la columna? Si viene NULL en la mayoria, no sirve de atajo.
SELECT COUNT(*) AS Filas,
       SUM(CASE WHEN LD.[Fe_Acum]      IS NULL THEN 0 ELSE 1 END) AS ConFeAcum,
       SUM(CASE WHEN LD.[ComponentStatus] IS NULL THEN 0 ELSE 1 END) AS ConStatus,
       SUM(CASE WHEN LD.[ComponentSerialNumber] IS NULL THEN 0 ELSE 1 END) AS ConSerie,
       SUM(CASE WHEN LD.[HorasComponenteAcumulado] IS NULL THEN 0 ELSE 1 END) AS ConHrsAcum
FROM [Oil].[LaboratoryData] LD WITH (NOLOCK)
JOIN [Mine].[MiningEquipment] ME WITH (NOLOCK) ON ME.[Id] = LD.[MiningEquipmentId]
JOIN [Mine].[MiningProject]   MP WITH (NOLOCK) ON MP.[Id] = ME.[MiningProjectId]
WHERE MP.[Name] LIKE '%Antapaccay%';
GO
-- 141.3 Si Fe_Acum sirve: cuadra con la suma manual del BLOQUE 137? Los dos numeros, lado a lado.
SELECT ult.[Fe_Acum] AS AcumDeLaColumna,
       (SELECT CAST(SUM(x.[Fe_ppm]) AS decimal(18,1))
        FROM [Oil].[LaboratoryData] x WITH (NOLOCK)
        WHERE x.[MiningEquipmentId] = ult.[MiningEquipmentId]
          AND x.[Compartimiento] = ult.[Compartimiento]
          AND x.[ComponentStatus] = ult.[ComponentStatus]
          AND x.[CM] IN ('ADI','C')) AS SumaManual
FROM (SELECT TOP (1) LD.*
      FROM [Oil].[LaboratoryData] LD WITH (NOLOCK)
      JOIN [Mine].[MiningEquipment] ME WITH (NOLOCK) ON ME.[Id] = LD.[MiningEquipmentId]
      WHERE ME.[Code] = 'CA3195' AND LD.[Compartimiento] LIKE '%TRACCION%LH'
      ORDER BY LD.[FechaMuestreo] DESC) ult;
GO


-- ==== BLOQUE 142 - D7.3: de los 13 valores "nuevos", cuales traen dato de verdad ====
-- POR QUE: FORMATO_POR_COMPONENTE decia que estos 13 no estaban en la BD. Si estan (columnas con otro
--   nombre). Pero "existe la columna" no es "hay dato": antes de agregar 13 filas al formato hay que
--   saber cuales vienen siempre vacias, para no llenar la tabla de guiones.
-- Se mide por COMPONENTE, porque la respuesta cambia (ISO no se mide en el motor de Antapaccay; el TAN
--   no se mide en MT; el PQ no se mide en hidraulico...).
SELECT CASE WHEN LD.[Compartimiento] LIKE '%TRACCION%' THEN 'TRACCION'
            WHEN LD.[Compartimiento] LIKE '%RUEDA%'    THEN 'RUEDA'
            WHEN LD.[Compartimiento] LIKE '%HIDRAUL%'  THEN 'HIDRAULICO'
            WHEN LD.[Compartimiento] LIKE 'MOTOR%'     THEN 'MOTOR'
            ELSE 'OTRO' END AS CompTipo,
       COUNT(*) AS Muestras,
       SUM(CASE WHEN LD.[Viscosidad40] IS NULL THEN 0 ELSE 1 END) AS V40,
       SUM(CASE WHEN LD.[TAN]          IS NULL THEN 0 ELSE 1 END) AS TAN,
       SUM(CASE WHEN LD.[Oxidacion]    IS NULL THEN 0 ELSE 1 END) AS Oxi,
       SUM(CASE WHEN LD.[Sulfatacion]  IS NULL THEN 0 ELSE 1 END) AS Sulf,
       SUM(CASE WHEN LD.[Nitracion]    IS NULL THEN 0 ELSE 1 END) AS Nit,
       SUM(CASE WHEN LD.[Mo_ppm]       IS NULL THEN 0 ELSE 1 END) AS Mo,
       SUM(CASE WHEN LD.[Agua]         IS NULL THEN 0 ELSE 1 END) AS Agua,
       SUM(CASE WHEN LD.[Hollin]       IS NULL THEN 0 ELSE 1 END) AS Hollin,
       SUM(CASE WHEN LD.[Diesel]       IS NULL THEN 0 ELSE 1 END) AS Diesel,
       SUM(CASE WHEN LD.[Refrigerante] IS NULL THEN 0 ELSE 1 END) AS Refrig,
       SUM(CASE WHEN LD.[Iso4406_4]    IS NULL THEN 0 ELSE 1 END) AS ISO4,
       SUM(CASE WHEN LD.[Iso4406_6]    IS NULL THEN 0 ELSE 1 END) AS ISO6,
       SUM(CASE WHEN LD.[Iso4406_14]   IS NULL THEN 0 ELSE 1 END) AS ISO14
FROM [Oil].[LaboratoryData] LD WITH (NOLOCK)
JOIN [Mine].[MiningEquipment] ME WITH (NOLOCK) ON ME.[Id] = LD.[MiningEquipmentId]
JOIN [Mine].[MiningProject]   MP WITH (NOLOCK) ON MP.[Id] = ME.[MiningProjectId]
WHERE MP.[Name] LIKE '%Antapaccay%'
  AND LD.[FechaMuestreo] >= DATEADD(MONTH, -12, GETDATE())   -- misma ventana que la fundacion
GROUP BY CASE WHEN LD.[Compartimiento] LIKE '%TRACCION%' THEN 'TRACCION'
              WHEN LD.[Compartimiento] LIKE '%RUEDA%'    THEN 'RUEDA'
              WHEN LD.[Compartimiento] LIKE '%HIDRAUL%'  THEN 'HIDRAULICO'
              WHEN LD.[Compartimiento] LIKE 'MOTOR%'     THEN 'MOTOR'
              ELSE 'OTRO' END
ORDER BY CompTipo;
GO
-- 142.2 Lo mismo para Antamina, que mide cosas distintas (las dos viscosidades, por ejemplo).
--       Confirma la regla de Carlos: "va a depender de la mina".
SELECT COUNT(*) AS Muestras,
       SUM(CASE WHEN LD.[V100]         IS NULL THEN 0 ELSE 1 END) AS V100,
       SUM(CASE WHEN LD.[Viscosidad40] IS NULL THEN 0 ELSE 1 END) AS V40,
       SUM(CASE WHEN LD.[TAN]          IS NULL THEN 0 ELSE 1 END) AS TAN,
       SUM(CASE WHEN LD.[Iso4406_4]    IS NULL THEN 0 ELSE 1 END) AS ISO4
FROM [Oil].[LaboratoryData] LD WITH (NOLOCK)
JOIN [Mine].[MiningEquipment] ME WITH (NOLOCK) ON ME.[Id] = LD.[MiningEquipmentId]
JOIN [Mine].[MiningProject]   MP WITH (NOLOCK) ON MP.[Id] = ME.[MiningProjectId]
WHERE MP.[Name] LIKE '%Antamina%'
  AND LD.[FechaMuestreo] >= DATEADD(MONTH, -12, GETDATE());
GO
-- 142.3 El Refrigerante: se mapea a 'Glycol - LP/LC' de lc? Ver si alguno de los dos trae algo.
SELECT TOP (20) LD.[Refrigerante], LD.[GLYCOL], LD.[PorcentajeGlicol_cinta], LD.[Compartimiento]
FROM [Oil].[LaboratoryData] LD WITH (NOLOCK)
WHERE LD.[Refrigerante] IS NOT NULL OR LD.[GLYCOL] IS NOT NULL;
GO

-- RESULTADOS BLOQUES 136-142 (28/09) -- la ronda de reconocimiento del bloque D.
-- =============================================================================
-- 141 -- EL ATAJO *_Acum NO EXISTE. DESCARTADO.
--   Fe_Acum, Cr_Acum, Pb_Acum, Cu_Acum, Sn_Acum, Al_Acum, Si_Acum vienen NULL en
--   TODAS las filas: 141.2 dio ConFeAcum = 0 sobre 36 832 filas de Antapaccay.
--   Las columnas existen en la tabla pero nadie las llena. => el acumulado hay que
--   calcularlo, como estaba previsto.
--
-- 141.3 -- ✅ EL METODO DE CARLOS ES EXACTO: SumaManual = 3718.6, su cifra al decimal.
--   Criterio: ComponentStatus = 'En uso'  +  CM IN ('ADI','C')  +  TODA la historia
--   (sin la ventana de 12 meses). El bloque C tiene su formula validada.
--   ⚠ Ojo al literal: es 'En uso' (u minuscula), no 'En Uso'.
--
-- 141.2 -- ⚠ ComponentStatus solo esta poblado en 15 879 de 36 832 filas = 43%.
--   ComponentSerialNumber tiene la MISMA cobertura (15 879) y en el CA3195 MT LH
--   vale 'WX2104W058T' -- identifica la instalacion concreta, es mas preciso aun
--   que el status. HorasComponenteAcumulado: 15 854 (y HorasComponenteParcial = 0
--   siempre, no sirve).
--   => para el 57% sin status NO se puede calcular el acumulado con este criterio.
--   Decision: mostrar '—', nunca un numero calculado con otro criterio.
--
-- 142.1 -- QUE SE MIDE DE VERDAD EN ANTAPACCAY (12 meses). Confirma a Carlos en todo:
--   CompTipo    Muestras  V40  TAN   Oxi  Sulf  Nit   Mo   Agua  Hollin Diesel Refrig ISO4  ISO6 ISO14
--   HIDRAULICO      855     0  848   848   248  248   850   848    248     0      0    806   805   761
--   MOTOR          3287     0  519  3273  3273 3277  3273  3273   3273     0      0    439   439   439
--   RUEDA          1165     0 1144  1144   367  367  1144  1144    367     0      0   1080  1080  1041
--   TRACCION       2815     0  902   904   899  899  2812   904    899     0      0   2639  2644  2599
--   OTRO            859     0  831   833   194  194   841   833    194     0      0    751   753   737
--   * V40 = 0 en TODO Antapaccay  -> "aca en Antapaccay solo miden con la 100". CONFIRMADO.
--   * ISO en MOTOR = 439/3287 (13%) -> "en Antapaccay el motor no bota codigo de limpieza". CONFIRMADO.
--     En los otros componentes 92-95%.
--   * TAN alto en RUEDA (98%) e HIDRAULICO (99%), bajo en MOTOR (16%) y TRACCION (32%).
--     "el TAN sale para las ruedas y para el hidraulico; el MT no lo mide". CONFIRMADO.
--   * Hollin/Sulf/Nit ~100% en MOTOR (que es donde el formato los pide) y ~30% en el resto.
--   * Diesel y Refrigerante = 0 en TODO. No se miden. (142.3: Refrigerante NULL, GLYCOL 0.000,
--     PorcentajeGlicol_cinta NULL -> el mapeo Refrigerante->Glycol no aporta nada.)
--
-- 142.2 -- ANTAMINA mide distinto, tal cual dijo Carlos:
--   Muestras 16 106 | V100 15 857 | V40 15 834 | TAN 0 | ISO4 15 787
--   => Antamina SI mide las dos viscosidades y NO mide TAN. Antapaccay al reves.
--   ⛔ Por lo tanto 'Disponible' NO puede ser una constante por CompTipo: depende de la MINA.
--      La fila se decide POR FILA con la regla D5 (sin valor y sin limite -> no sale).
--
-- 138.1 -- ANTAPACCAY / MOTOR DE TRACCION LH y RH / 980E, columnas que hoy no leemos:
--   FOSFORO   LP 280.00  LC 240.00   <- invertido, tal cual dijo Carlos
--   ISO 6um   LP  19.00  LC  20.00
--   ISO 14um  LP  16.00  LC  19.00
--   VISC      LPI NULL   LCI 70.10   LPS NULL   LCS 85.70
--     ✅ "para el MT lo unico que tenemos es limite critico, no trabaja con el precautorio".
--        CONFIRMADO: los dos LC estan, los dos LP vienen NULL.
--   BORO, MOLIBDENO, TAN, ISO 4um, VISC40, H20, HOLLIN, TBN: todos NULL en MT.
--   LH y RH traen valores IDENTICOS -> el MIN/MAX del GROUP BY no cambia nada en la practica.
--
-- 138.2 -- ANTAPACCAY / MOTOR, los 3 modelos:
--   980E    VISC LPI 13.50 LCI 13.00 LPS 16.00 LCS 16.50  <- ✅ LOS CUATRO NIVELES
--   PC1250  VISC todo NULL     D475A  VISC todo NULL
--   HOLLIN  980E 0.40/0.50 | PC1250 1.00/1.50 | D475A 1.00/1.50
--   OXI     980E 7.00 | PC1250 0.20 | D475A 0.20
--   SULF    980E 3.00 | PC1250 20.00 | D475A NULL
--   NIT     980E 9.00 | PC1250 NULL | D475A 20.00
--   TBN     980E LP 6.00 LC 5.00 (invertido) | PC1250 7.00/NULL | D475A 7.00/NULL
--   ISO 4/6/14: NULL en los 3 -> coherente con 142.1 (el motor no mide ISO).
--   => "para el MT solo dos niveles, para el motor diesel los cuatro" CONFIRMADO CON EL DATO.
--
-- 139 -- COBERTURA de los 14 nuevos por proyecto/componente/modelo (64 filas):
--   Antapaccay MOTOR 980E 6 · D475A 3 · PC1250 3   |  MT LH/RH 3  |  RD LH/RH 5  |  SH 4
--   Antamina   MOTOR 5 · MT LH 5 · MT RH 6 · RD 4 · SH 4
--   Cerro Verde MOTOR 730E- = 0 (ademas del desajuste de texto 730E- vs 730E, bloque C4)
--   Componentes chicos (CAJA GIRO, DAMPER, MANDO FINAL, PTO, TRANSMISION) = 2
--   TBN con LC: SOLO en MOTOR (5 filas de 64). Coherente: "el TBN mayormente es el motor nada mas".
--   ⚠ Aparece QUELLAVECO (20 filas), que esta FUERA del alcance de KomfIA.
-- =============================================================================


-- ==== BLOQUE 143 - D2 desplegada: vw_LimitesPorComponente con los 31 parametros ====
-- CORRER JUSTO DESPUES de desplegar la vista. Un CREATE VIEW se guarda aunque su cuerpo sea
-- invalido y revienta recien al consultarla (ley 5) -- esto es su smoke test.
-- 143.1 Smoke: la vista responde y trae las columnas nuevas.
SELECT TOP (5) ProyKey, ModeloKey, CompTipo, P_LP, P_LC, ISO6_LP, ISO6_LC, TBN_LP, TBN_LC
FROM [dbo].[vw_LimitesPorComponente];
GO
-- 143.2 El caso que Carlos miro en pantalla: MT de Antapaccay 980E.
--   ESPERADO (bloque 138.1): P 280/240 · ISO6 19/20 · ISO14 16/19 · V100_LCI 70.10 · V100_LCS 85.70
--   y V100_LPI / V100_LPS en NULL (en MT solo hay criticos).
SELECT ProyKey, ModeloKey, CompTipo,
       P_LP, P_LC, B_LP, Mo_LP, TAN_LP,
       ISO4_LP, ISO4_LC, ISO6_LP, ISO6_LC, ISO14_LP, ISO14_LC,
       V100_LPI, V100_LCI, V100_LPS, V100_LCS,
       V40_LPI, V40_LCI, V40_LPS, V40_LCS,
       Agua_LP, Hollin_LP, TBN_LP, TBN_LC
FROM [dbo].[vw_LimitesPorComponente]
WHERE ProyKey = 'ANTAPACCAY' AND CompTipo = 'TRACCION' AND ModeloKey = '980E';
GO
-- 143.3 El MOTOR de Antapaccay, que SI debe traer los 4 niveles de viscosidad.
--   ESPERADO (bloque 138.2): 980E -> LPI 13.50 · LCI 13.00 · LPS 16.00 · LCS 16.50
--   ⚠ Ojo: LPI 13.50 > LCI 13.00. Es correcto: en un piso, el precautorio va POR ENCIMA del
--     critico (se alerta antes de llegar al critico, bajando). No es un typo.
SELECT ProyKey, ModeloKey, CompTipo, V100_LPI, V100_LCI, V100_LPS, V100_LCS,
       Hollin_LP, Hollin_LC, Oxi_LP, Sulf_LP, Nit_LP, TBN_LP, TBN_LC
FROM [dbo].[vw_LimitesPorComponente]
WHERE ProyKey = 'ANTAPACCAY' AND CompTipo = 'MOTOR'
ORDER BY ModeloKey;
GO
-- 143.4 NO REGRESION: los 16 limites que ya se leian antes deben dar EXACTAMENTE lo mismo.
--   Si alguno cambio, el MIN/MAX nuevo movio algo que no debia.
SELECT ProyKey, ModeloKey, CompTipo, Fe_LP, Fe_LC, PQ_LP, PQ_LC, Cr_LP, Cr_LC,
       Ca_LP, Ca_LC, Zn_LP, Zn_LC, Mg_LP, Mg_LC, TBN_LP
FROM [dbo].[vw_LimitesPorComponente]
WHERE ProyKey IN ('ANTAPACCAY','ANTAMINA')
ORDER BY ProyKey, CompTipo, ModeloKey;
GO
-- ⚠ 143.5 Las vistas que dependen de esta siguen vivas? (la fundacion la consume con LEFT JOIN)
SELECT TOP (3) Equipo, Compartimiento, Fe_ppm, Fe_LP, Fe_LC, Estado_General
FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK)
WHERE Equipo = 'CA3195' AND Compartimiento LIKE '%TRACCION%LH';
GO


-- ==== BLOQUE 144 - D3 desplegada: la fundacion con los 13 valores nuevos ====
-- ⛔ DESPLIEGUE: correr DDL_vistas.sql ENTERO y de corrido. vw_MuestrasRankeadas y
--    vw_MuestrasHistorial hacen 'SELECT me.*' y SQL Server CONGELA la lista de columnas al
--    crear la vista: si no se re-crean, las 13 columnas nuevas no llegan a ningun modulo.
-- 144.1 SMOKE (ley 5: un CREATE VIEW se guarda aunque su cuerpo sea invalido).
SELECT TOP (3) Equipo, Compartimiento, FechaMuestreo,
       P_ppm, P_LP, P_LC, Estado_P,
       ISO4, ISO6, ISO14, ISO6_LP, ISO6_LC, Estado_ISO6,
       V100, V100_LPI, V100_LCI, V100_LPS, V100_LCS, Estado_V100,
       V40, TAN, Mo_ppm, Agua, Hollin, TBN, TBN_LP, TBN_LC, Estado_TBN
FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK)
WHERE Equipo = 'CA3195' AND Compartimiento LIKE '%TRACCION%LH'
ORDER BY FechaMuestreo DESC;
GO
-- 144.2 QUE LAS COLUMNAS NUEVAS LLEGARON a las derivadas (si esto falla, no se re-crearon).
SELECT TOP (1) Equipo, Estado_P, Estado_ISO6, Estado_V40, HorasComponente
FROM [dbo].[vw_MuestrasRankeadas] WITH (NOLOCK) WHERE Equipo = 'CA3195';
GO
-- 144.3 NO REGRESION del semaforo. Estado_General NO se toco en D3 (los parametros nuevos
--   todavia NO disparan el estado general; encenderlos es un paso aparte y medido, como se
--   hizo con V100 el 07/08). Estos conteos deben dar LO MISMO que antes del despliegue.
SELECT Estado_General, COUNT(*) AS Componentes
FROM [dbo].[vw_MuestrasRankeadas] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND rn_recencia = 1
GROUP BY Estado_General ORDER BY Componentes DESC;
GO
-- 144.4 EL CASO DE UN SOLO EXTREMO no debe disparar nada. ANTAMINA HIDRAULICO trae
--   P_LP NULL / P_LC 600 (bloque 143.1): sin los dos extremos no se puede saber la direccion,
--   asi que Estado_P tiene que salir 'OK' en TODAS. Si aparece un CRITICO aqui, la regla fallo.
SELECT Estado_P, COUNT(*) AS Filas, MIN(P_ppm) AS MinP, MAX(P_ppm) AS MaxP
FROM [dbo].[vw_MuestrasRankeadas] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antamina%' AND Compartimiento LIKE '%HIDRAUL%' AND rn_recencia = 1
GROUP BY Estado_P;
GO
-- 144.5 ⚠ MEDIR. La fundacion paso de ~18 a 31 parametros y la lee TODO el sistema.
--   Con el operador de PRODUCCION (LIKE), nunca con '=' (ley 3: 5x de diferencia).
--   Referencias de la ronda anterior: vw_TriageMD 860 ms · vw_DiagnosticoMD 2 418 ms.
--   Correr 2 veces y usar la 2a (warm).
SET STATISTICS TIME ON; SET STATISTICS IO ON;
SELECT MD FROM [dbo].[vw_TriageMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%todos%' AND CompTipo = 'TRACCION';
GO
SELECT MD FROM [dbo].[vw_DiagnosticoMD] WITH (NOLOCK) WHERE Equipo LIKE '%3195%';
GO
SET STATISTICS TIME OFF; SET STATISTICS IO OFF;
GO
-- CRITERIO: si el triage se va por encima de ~2 s, D3 hay que replantearlo -- los 13
-- parametros nuevos se proyectan en una vista aparte que solo consuman las 4 vistas de
-- formato, y la fundacion se queda como estaba.


-- ==== BLOQUE 145 - REGRESION: /diagcompleto paso de 2.4 s a ~6 min tras D3 ====
-- CONTEXTO (28/09): el bloque 144.5 tardo 6:15. El TRIAGE salio rapido; el que se colgo fue
--   vw_DiagnosticoMD. La fundacion sumo 13 parametros (valor + limites + estado): ~50 columnas.
-- ⛔ NO TEORIZAR. La ronda del barrido tumbo 3 hipotesis antes de dar con la buena. Esto mide
--   capa por capa, de abajo hacia arriba, y la primera que se dispare es la culpable.
-- ⚠ SIEMPRE con LIKE, como el flujo. Con '=' los numeros salen 5x optimistas (ley 3).
-- Correr cada una DOS veces y anotar la 2a (warm). Anotar "elapsed time" y "logical reads".
SET STATISTICS TIME ON; SET STATISTICS IO ON;
GO
-- 145.1 CAPA 1 - la fundacion, un equipo. Referencia: era instantanea.
SELECT COUNT(*) FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK) WHERE Equipo LIKE '%3195%';
GO
-- 145.2 CAPA 2 - la fundacion + HorasComponente (el JOIN a HsCc).
SELECT COUNT(*) FROM [dbo].[vw_MuestrasRankeadas] WITH (NOLOCK) WHERE Equipo LIKE '%3195%';
GO
-- 145.3 CAPA 3 - vw_UltimoAnalisisFlota. SOSPECHOSA PRINCIPAL: es de FLOTA y D3 la ensancho
--   ~50 columnas. Si el salto esta aqui, la cura es no arrastrar los 13 nuevos hasta arriba.
SELECT COUNT(*) FROM [dbo].[vw_UltimoAnalisisFlota] WITH (NOLOCK) WHERE Equipo LIKE '%3195%';
GO
-- 145.4 CAPA 4 - vw_DiagnosticoEquipo (arma las celdas con marca).
SELECT COUNT(*) FROM [dbo].[vw_DiagnosticoEquipo] WITH (NOLOCK) WHERE Equipo LIKE '%3195%';
GO
-- 145.5 CAPA 5 - vw_DiagnosticoMD. Aqui estaba el 2 418 ms de la ronda anterior.
SELECT LEFT(MD, 80) FROM [dbo].[vw_DiagnosticoMD] WITH (NOLOCK) WHERE Equipo LIKE '%3195%';
GO
-- 145.6 CONTROL - el triage, que ayer salio rapido. Si sigue rapido, el problema NO es la
--   fundacion en si: es como la consume la cadena del diagnostico. Referencia: 860 ms.
SELECT LEFT(MD, 80) FROM [dbo].[vw_TriageMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%todos%' AND CompTipo = 'TRACCION';
GO
SET STATISTICS TIME OFF; SET STATISTICS IO OFF;
GO
/* COMO LEER EL RESULTADO
   - Si el salto esta en 145.3 -> es el ANCHO subiendo por una vista de flota. Cura: los 13
     parametros nuevos salen de la fundacion y van a una vista aparte, unida por
     LaboratoryDataId, que solo consuman las 4 vistas de formato.
   - Si el salto esta en 145.4/145.5 -> es la cadena del diagnostico, no la fundacion. Mirar
     si algun CTE se referencia 2 veces con JOIN entre sus ramas (anti-patron nº1, el que
     curo el triage: 113 780 ms -> 860 ms).
   - Si 145.1/145.2 ya son lentas -> es la fundacion. Ahi la palanca es el window de 'calc',
     que hoy arrastra TODAS las columnas: se calcula sobre las claves y se re-une despues.
   - Si TODAS son rapidas y solo el bloque 144.5 era lento -> era el SET STATISTICS IO sobre
     una consulta que devuelve un MD gigante. Volver a medir sin IO. */


-- RESULTADOS BLOQUE 145 (28/09) -- DIAGNOSTICO CERRADO, la fundacion estaba SANA.
--   145.1 vw_MuestrasEstado      252 filas ·     2 ms · LaboratoryData  1 scan ·         19 lecturas
--   145.2 vw_MuestrasRankeadas   219 filas · rapido
--   145.3 vw_UltimoAnalisisFlota   6 filas · rapido
--   145.4 vw_DiagnosticoEquipo     6 filas · rapido
--   145.5 vw_DiagnosticoMD                · 348 185 ms · LaboratoryData 431 scans · 11 910 696 lecturas
--   145.6 vw_TriageMD (control)          ·   1 091 ms · LaboratoryData  1 scan  ·      1 365 lecturas
-- => El problema NO era el ancho de la fundacion (D3): era el unpivot de vw_DiagnosticoMD.
--    431 scans de la tabla base para pintar 6 componentes. El triage hace 1.

-- ==== BLOQUE 146 - CURA: el unpivot de vw_DiagnosticoMD lee 'base' UNA vez ====
-- QUE ESTABA MAL:
--     FROM base b
--     INNER JOIN vw_FormatoParametro f ON f.CompTipo='(CRUZADO)'    <- cartesiano base x 31
--     OUTER APPLY (SELECT v.cell FROM (VALUES ...31...) v WHERE v.Parametro = f.Parametro)
--   Por cada par (fila de base x fila del catalogo) se construia la tabla de 31 tuplas ENTERA
--   y se filtraba DENTRO del apply: 6 x 31 = 186 applies, y cada uno re-derivaba 'base', que
--   cuelga de una cadena de 4 vistas hasta [Oil].[LaboratoryData].
--   Con 18 parametros dolia (4 scans, medido el 25/09); con 31 exploto (431).
-- QUE QUEDO: se expande base UNA vez a sus 31 filas y DESPUES se une el catalogo.
--     FROM base b
--     CROSS APPLY (VALUES ...31...) v(Parametro, cell)
--     INNER JOIN vw_FormatoParametro f ON f.CompTipo='(CRUZADO)' AND f.Parametro = v.Parametro
-- Es el unpivot de siempre, y es la misma cura que curo el triage (ley 2).
-- 146.1 LA MEDICION QUE IMPORTA. Objetivo: volver a ~2.4 s y, sobre todo, a POCOS SCANS.
--   Mirar 'Scan count' de [Oil].[LaboratoryData]: tiene que bajar de 431 a un digito.
SET STATISTICS TIME ON; SET STATISTICS IO ON;
SELECT LEFT(MD, 80) FROM [dbo].[vw_DiagnosticoMD] WITH (NOLOCK) WHERE Equipo LIKE '%3195%';
GO
SET STATISTICS TIME OFF; SET STATISTICS IO OFF;
GO
-- 146.2 QUE NO SE PERDIO NINGUNA FILA. El INNER JOIN nuevo une catalogo y celdas por nombre:
--   si un parametro del catalogo no estuviera en la lista de celdas, su fila desapareceria
--   SIN RUIDO (antes salia con guion). Deben verse los 31 parametros del formato.
--   ⚑ Esto tambien lo vigila 'python tools/check_ddl.py' antes de desplegar.
SELECT MD FROM [dbo].[vw_DiagnosticoMD] WITH (NOLOCK) WHERE Equipo LIKE '%3195%';
GO
-- Contar a mano sobre el MD: Salud 7 (V100,V40,TAN,TBN,Oxidacion,Sulfatacion,Nitracion) +
-- Aditivos 6 (Ca,Zn,P,Mg,Mo,B) + Contaminacion 7 (Si,Na,K,Hollin,Diesel,Agua,Refrigerante) +
-- Desgaste 8 (Fe,PQ,Cr,Ni,Al,Cu,Pb,Sn) + Codigo Limpieza 3 = 31 filas.
-- 146.3 Y QUE LOS VALORES NUEVOS YA SALGAN (antes todos con guion aunque el dato existia):
--   en el CA3195 MT LH, Mo debe mostrar ~2.2 y los ISO deben traer numero.

-- RESULTADOS BLOQUE 146 (28/09) -- la cura funciono, y destapo la causa de fondo.
--   ANTES (145.5): 348 185 ms · LaboratoryData 431 scans · 11 910 696 lecturas
--   AHORA (146.1):  12 152 ms · LaboratoryData   7 scans ·     76 928 lecturas
--   => 29x mas rapido, 61x menos scans, 155x menos lecturas.
--   146.2: las 31 filas del formato salen COMPLETAS y CON DATO. Mo 3.5/7.9/0.0/6.5,
--     ISO>4 22/23/20/23, ISO>6 20/21/18/21, ISO>14 16/17/13/14, TAN, Oxidacion, Hollin,
--     Agua con valor. V40, Diesel y Refrigerante en guion, que es correcto: Antapaccay no
--     los mide (bloque 142.1). D queda FUNCIONALMENTE CERRADO.
--
-- ⚠ PERO SIGUE A 12 s CONTRA LOS 2 418 ms DE REFERENCIA, y la causa quedo a la vista:
--   'base' se referencia SIETE VECES en vw_DiagnosticoMD (lineas 21, 31, 72, 77, 108, 132,
--   142) y LaboratoryData tiene EXACTAMENTE 7 scans. Uno por referencia. Es el anti-patron
--   nº1 (ley 2) a escala: cada CTE que lee 'base' re-deriva la cadena de 4 vistas entera.
--   Los 2 185 scans de [Eqpcare].[lc] son consecuencia de lo mismo (7 x ~312).
--   Esto NO lo introdujo D: el 25/09 ya se habian medido 4 scans y quedo anotado como
--   "margen". D solo lo hizo visible.
--   CURA PENDIENTE: consolidar las 7 lecturas en 1, agregando sobre la misma fila con
--   window functions / OUTER APPLY en vez de en CTEs paralelos. Es la misma cura que llevo
--   vw_TriageMD de 113 780 ms a 860 ms. Es una reestructuracion de verdad: se mide antes,
--   se hace de una y se vuelve a medir. -> BLOQUE 147 cuando se ataque.


-- ==== BLOQUE 147 - BLOQUE L: donde se pierde el filtro de <modelo> ====
-- EL SINTOMA (marcha 28/09): '/barrido antapaccay d475' y '/barrido antapaccay 980' devolvieron
--   EXACTAMENTE la misma tabla, los mismos 18 equipos. Y en '/barridodet antapaccay 980' la tabla
--   verbatim traia todos los equipos y DEBAJO el nodo de analisis la volvia a dibujar "filtrada".
-- ⛔ ANTES DE TOCAR 7 VISTAS hay que saber si el SQL filtra o no. Son dos bugs distintos con la
--   misma cara, y la cura no se parece en nada:
--     (a) el SQL no filtra            -> se arregla en las vistas / el predicado
--     (b) el SQL filtra y no le llega -> se arregla en Copilot (dispatcher -> tema -> flujo)
-- El flujo compara con LIKE, asi que aqui se mide igual (ley 3).

-- 147.1 EL MISMO PREDICADO DEL FLUJO, con tres modelos distintos. Si las tres filas de abajo
--   traen un MD de LARGO DISTINTO, el SQL SI filtra -> el bug es (b), esta en Copilot.
SELECT '1-d475' AS Caso, LEN(MD) AS LargoMD, LEFT(MD, 90) AS Inicio
FROM [dbo].[vw_ObservadosResumenMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%d475%'
UNION ALL
SELECT '2-980', LEN(MD), LEFT(MD, 90)
FROM [dbo].[vw_ObservadosResumenMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980%'
UNION ALL
SELECT '3-(todos)', LEN(MD), LEFT(MD, 90)
FROM [dbo].[vw_ObservadosResumenMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%todos%';
GO
-- 147.2 Lo mismo en el DETALLE, que es donde se vio la tabla duplicada.
SELECT '1-d475' AS Caso, LEN(MD) AS LargoMD
FROM [dbo].[vw_ObservadosBarridoMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%d475%'
UNION ALL
SELECT '2-980', LEN(MD)
FROM [dbo].[vw_ObservadosBarridoMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980%';
GO
-- 147.3 QUE VALORES DE Modelo EXPONE la vista para Antapaccay. Si '(todos)' esta ahi como una
--   fila mas, el predicado LIKE '%980%' NO puede traerla: '(todos)' no contiene '980'.
--   Si alguna fila trae un modelo que contiene el texto de otro, ahi hay colision.
SELECT DISTINCT Modelo FROM [dbo].[vw_ObservadosResumenMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' ORDER BY Modelo;
GO
-- 147.4 EL INSUMO DEL REDISENO DE '(todos)': que modelos tiene el proyecto en la FLOTA y
--   cuales tienen limites cargados. Los que salgan con TieneLimites=0 son los que Carlos NO
--   quiere ver en el '(todos)' por defecto (D11T y 797F, segun la marcha).
SELECT DISTINCT
       EF.[Model] AS Modelo,
       CASE WHEN EXISTS (SELECT 1 FROM [dbo].[vw_ModeloConLimites] ml
                         WHERE ml.ProyKey = UPPER(LTRIM(RTRIM(MP.[Name])))
                           AND ml.ModeloKey = UPPER(LTRIM(RTRIM(EF.[Model]))))
            THEN 1 ELSE 0 END AS TieneLimites,
       COUNT(DISTINCT ME.[Code]) AS Equipos
FROM [Mine].[MiningEquipment] ME WITH (NOLOCK)
JOIN [Mine].[MiningProject]  MP WITH (NOLOCK) ON MP.[Id] = ME.[MiningProjectId]
JOIN [Mine].[EquipmentFleet] EF WITH (NOLOCK) ON EF.[Id] = ME.[EquipmentFleetId]
WHERE MP.[Name] LIKE '%Antapaccay%'
GROUP BY EF.[Model], MP.[Name]
ORDER BY TieneLimites DESC, Equipos DESC;
GO
-- 147.5 Smoke de la vista nueva.
SELECT ProyKey, ModeloKey FROM [dbo].[vw_ModeloConLimites] ORDER BY ProyKey, ModeloKey;
GO
/* COMO LEER EL RESULTADO
   - 147.1/147.2 dan LARGOS DISTINTOS -> el SQL filtra bien. El bug es de Copilot: o el
     dispatcher no parsea p2, o el tema no mapea 'modelo' al flujo, o el flujo no lo usa.
     Se comprueba en el tema 16/17: 'modelo' tiene que ser ENTRADA mapeada, no un valor fijo.
   - 147.1/147.2 dan el MISMO largo -> el SQL no filtra, y ahi si hay que tocar las vistas.
   - 147.4 dice que modelos se quedan fuera del '(todos)' nuevo. Si un modelo con muchos
     equipos sale con TieneLimites=0, conviene avisarlo en la respuesta en vez de esconderlo. */

-- RESULTADOS BLOQUE 147 (28/09) -- VEREDICTO: ES EL CASO (b). EL SQL FILTRA BIEN.
--   147.1 vw_ObservadosResumenMD, mismo predicado del flujo, tres modelos:
--       d475    -> LargoMD   728 · "1 equipos con >=1 componente observado"
--       980     -> LargoMD 2 397 · "16 equipos"
--       (todos) -> LargoMD 2 601 · "18 equipos"
--   147.2 vw_ObservadosBarridoMD: d475 -> 399 · 980 -> 3 708.
--   => Tres largos y tres conteos DISTINTOS. La vista filtra por modelo sin problema.
--      El bug NO esta en el SQL: el modelo no le esta llegando. Se arregla en COPILOT.
--      ⛔ Tocar las 9 vistas con rollup no habria arreglado nada.
--
--   147.3 Modelos que expone la vista para Antapaccay: (todos) · 980E · D475A · PC1250.
--     '(todos)' es UNA FILA MAS, y por eso LIKE '%980%' nunca puede traerla: no contiene '980'.
--     Confirma que el filtrado es automatico EN CUANTO llegue el parametro.
--
--   147.4 LA FLOTA REAL DE ANTAPACCAY -- 6 modelos, 48 equipos:
--       980E     limites=SI  27 equipos
--       D475A    limites=SI   5
--       PC1250   limites=SI   4
--       930E     limites=NO   9   <- sale en el triage como "### 930E · 18 equipos (0 obs)"
--       HD1500   limites=NO   2
--       WA900    limites=NO   1
--     ⚠ CORRIJO lo que escribi el 28/09: dije que los modelos sin limites eran D11T y 797F.
--       NO. Son 930E, HD1500 y WA900, y suman 12 equipos. D11T y 797F no existen en Antapaccay
--       (lo que devolvio /conteo con esos textos hay que revisarlo aparte -- ver H3).
--     Son EXACTAMENTE los que Carlos no quiere ver por defecto: salen todos en verde porque no
--     hay con que evaluarlos, y ensucian la tabla.
--
--   147.5 vw_ModeloConLimites: 10 pares. ANTAMINA 1 · ANTAPACCAY 3 · CERRO VERDE 2 ·
--     QUELLAVECO 3 · TOROMOCHO 1. ⚠ Quellaveco esta FUERA del alcance de KomfIA (ver
--     LIMITES_FALLBACK.md): inofensivo mientras nadie lo consulte, pero anotado.


-- ==== BLOQUE 148 - PASO 1: vw_DiagnosticoMD consolidada. LO QUE SE MIDE ES EL SCAN COUNT ====
-- QUE CAMBIO: 'base' pasa de 6 referencias a 1 (solo unpv la lee). hdr_all, hdr_obs y g ahora
--   salen de un CTE nuevo 'comp' derivado de unpv; obsmetals y obsmet tambien salen de unpv.
-- ⚠ NO ES AUTOMATICO QUE MEJORE, y hay que decirlo: los CTE de SQL Server no se materializan.
--   'unpv' queda referenciado 5 veces, y si el optimizador NO hace spool, cada referencia
--   re-deriva unpv -> vuelve a leer base -> podriamos seguir en ~5 scans. Por eso esto se mide
--   ANTES de seguir reestructurando: si ya bajo, cualquier cambio extra es churn.
-- REFERENCIAS: antes del paso 1 -> 12 152 ms · LaboratoryData 7 scans · 76 928 lecturas.
--              objetivo de la ronda -> 2 418 ms (lo que costaba antes del bloque D).
-- ⛔ Con LIKE, como el flujo (ley 3). Correr DOS veces y usar la 2a (warm).
SET STATISTICS TIME ON; SET STATISTICS IO ON;
SELECT LEFT(MD, 80) FROM [dbo].[vw_DiagnosticoMD] WITH (NOLOCK) WHERE Equipo LIKE '%3195%';
GO
SET STATISTICS TIME OFF; SET STATISTICS IO OFF;
GO
-- 148.2 QUE NO CAMBIO NADA DE LO QUE SE VE. Mismo equipo, las 31 filas y los mismos valores.
SELECT MD FROM [dbo].[vw_DiagnosticoMD] WITH (NOLOCK) WHERE Equipo LIKE '%3195%';
GO
-- 148.3 ⚑ EL EFECTO SECUNDARIO QUE HAY QUE MIRAR CON LUPA: 'Observados'.
--   obsmetals ya no decide la marca por su cuenta (un CONCAT de 18 CASE ... LIKE '%:C%'): ahora
--   la lee de la CELDA que se imprime. Son dos cambios en uno:
--     (a) una sola fuente de verdad -- la leccion del bloque E3;
--     (b) pasa de mirar 18 parametros a mirar los 31, asi que AHORA SI pueden aparecer
--         observados nuevos (Mo, ISO>4/6/14, TAN, Hollin...) que antes nunca salian.
--   => Si esta columna trae MAS metales que antes, NO es un bug: es el arreglo.
SELECT Equipo, Observados FROM [dbo].[vw_DiagnosticoMD] WITH (NOLOCK)
WHERE Equipo LIKE '%3195%';
GO
-- 148.4 Y que el encabezado siga cuadrando con la tabla ("X de N componentes observados").
--   g ahora cuenta sobre 'comp' (1 fila por componente) en vez de COUNT(DISTINCT) sobre base.
--   Tiene que dar lo MISMO: 4 de 6 para el CA3195.
SELECT Equipo, NumCompObs, NumCompTotal FROM [dbo].[vw_DiagnosticoMD] WITH (NOLOCK)
WHERE Equipo LIKE '%3195%';
GO

-- RESULTADOS BLOQUE 148 (29/09) -- la consolidacion NO bajo los scans, y destapo un bug mio.
--   148.1  LaboratoryData: 7 scans · 76 928 lecturas  = EXACTAMENTE IGUAL que antes del paso 1.
--          (elapsed 20 856 ms en esa corrida, pero las lecturas son identicas: el tiempo de una
--          sola corrida en este tier varia mucho, la metrica fiable son las lecturas.)
--          ✅ Lo que SI bajo, y mucho: [Eqpcare].[lc] de 2 185 scans / 52 440 lecturas a
--          17 / 408. Eso viene de simplificar vw_LimitesPorComponente (quitar el CASE-sobre-
--          agregado) el 28/09.
--   => CONFIRMA LA ADVERTENCIA: mover las lecturas de 'base' a 'unpv' no sirve por si solo.
--      Los CTE no se materializan, y 'unpv' quedaba referenciado 5 veces.
--
--   148.2  ✅ La tabla no cambio: 31 filas, mismos valores, mismas marcas.
--   148.4  ✅ NumCompObs 4 / NumCompTotal 6. Sin regresion.
--
--   148.3  🔴 BUG INTRODUCIDO POR MI. 'Observados' devolvia los 31 parametros en vez de los
--          marcados. CAUSA: filtre con  cell LIKE N'%<cuadro de color>%'. Los cuadros son
--          caracteres SUPLEMENTARIOS (U+1F7E5 / U+1F7E8): en UTF-16 son un par surrogate, y el
--          LIKE con una collation no-_SC no los trata como UN caracter -> el patron matchea de
--          mas y pasan todas las filas.
--          CURA: no buscar el emoji. Cada tupla del CROSS APPLY lleva ahora el valor CRUDO y se
--          filtra por ':C' / ':P', que es ASCII puro. Es el mismo patron del bloque E4 sobre
--          vw_CondicionMT_MD. De paso obsmetals y obsmet se fusionaron en un solo CTE 'obs'
--          (unpv baja de 5 a 4 referencias).
--   ⚑ REGLA: NUNCA usar un emoji dentro de un LIKE. Para decidir se usa la marca ASCII; el
--     emoji es solo presentacion.

-- ==== BLOQUE 149 - re-medicion tras el fix del raw ====
-- 149.1 'Observados' tiene que traer SOLO los marcados. Para el CA3195: MT LH -> PQ (233.2 es
--   lo unico rojo ahi) y MT RH -> Zn. Si vuelven a salir los 31, el filtro sigue mal.
SELECT Equipo, Observados FROM [dbo].[vw_DiagnosticoMD] WITH (NOLOCK) WHERE Equipo LIKE '%3195%';
GO
-- 149.2 Que la tabla y el encabezado sigan intactos.
SELECT Equipo, NumCompObs, NumCompTotal, LEN(MD) AS LargoMD
FROM [dbo].[vw_DiagnosticoMD] WITH (NOLOCK) WHERE Equipo LIKE '%3195%';
GO
-- 149.3 Scan count otra vez. Referencia: 7 scans · 76 928 lecturas.
SET STATISTICS TIME ON; SET STATISTICS IO ON;
SELECT LEFT(MD, 80) FROM [dbo].[vw_DiagnosticoMD] WITH (NOLOCK) WHERE Equipo LIKE '%3195%';
GO
SET STATISTICS TIME OFF; SET STATISTICS IO OFF;
GO
/* SI SIGUE EN 7 SCANS: el conteo de referencias no es la palanca -- la cadena de CTE se
   re-deriva igual. La unica cura real seria REESCRIBIR la vista anidando derived tables en
   vez de encadenar CTE referenciados (una derived table anidada se evalua una vez). Eso es una
   reescritura completa, y con la fecha del viernes encima conviene decidirlo a conciencia:
   12-20 s no es bonito pero NO bloquea (el conector muere a los 120 s), mientras que los pasos
   2-8 del plan son los que Carlos y Franco van a VER. */

-- RESULTADOS BLOQUE 149 (29/09) -- el fix del raw funciona; el rendimiento NO se movio.
--   149.1 ✅ Observados del CA3195, ahora SOLO los marcados y cuadra 1:1 con la tabla:
--       MT LH: PQ, ISO>6 · MT RH: Zn, ISO>6, ISO>14 · RD LH: Ca, Zn, P, Mg, Na
--       RD RH: Ca, Zn, P, Mg, Na, ISO>4, ISO>6
--     ⚑ Fijarse en que ahi hay ISO>4/6/14 y P: son observados que ANTES NUNCA SALIAN, porque
--       obsmetals solo miraba 18 de los 31 parametros. Ese era el bug latente del paso 1.
--   149.2 ✅ NumCompObs 4 / NumCompTotal 6 / MD de 1 604 caracteres. Sin regresion.
--   149.3 ❌ LaboratoryData sigue en 7 scans · 76 936 lecturas. (lc en 17 / 408, que es lo bueno
--       que quedo de la simplificacion del 28/09.) elapsed 15 259 ms.
--
-- VEREDICTO DEL PASO 1: mejoro la CORRECCION (un bug latente y uno introducido, los dos
--   cerrados), no el rendimiento. El conteo de referencias a un CTE no es la palanca: la cadena
--   se re-deriva igual. La unica cura real seria reescribir la vista anidando derived tables.
--   ⏸ APARCADO a proposito hasta despues de la presentacion del 02/10: 12-20 s no bloquea (el
--   conector muere a los 120 s) y los pasos 2-8 son los que se VEN. Deuda medida y con cura escrita.


-- ==== BLOQUE 150 - PASO 2 (L3): '(todos)' = los modelos CON LIMITES ====
-- QUE CAMBIO: los 9 sitios que expandian con CROSS APPLY (VALUES (Modelo),(N'(todos)')) ahora
--   solo emiten la fila '(todos)' si ese proyecto+modelo tiene fila en [Eqpcare].[lc].
--   La fila POR-MODELO no se toca: si el usuario nombra un modelo, sale igual aunque no tenga
--   limites. Solo cambia el DEFAULT.
-- POR QUE (bloque 147.4): Antapaccay tiene 6 modelos y solo 3 con limites. Los otros 12 equipos
--   (930E, HD1500, WA900) salen TODOS en verde porque no hay con que evaluarlos.

-- 150.1 SMOKE de la vista de apoyo. Ahora lee lc DIRECTO (64 filas, sin agregados).
SELECT ProyKey, ModeloKey FROM [dbo].[vw_ModeloConLimites] ORDER BY ProyKey, ModeloKey;
GO
-- 150.2 ⭐ LA PRUEBA QUE IMPORTA: el triage por defecto ya NO debe traer la seccion del 930E.
--   ANTES el MD incluia "### 930E · 18 equipos (0 obs)". Ahora no deberia aparecer.
SELECT CASE WHEN MD LIKE '%930E%'   THEN 'SIGUE SALIENDO 930E'   ELSE 'ok: sin 930E'   END AS Chk930,
       CASE WHEN MD LIKE '%HD1500%' THEN 'SIGUE SALIENDO HD1500' ELSE 'ok: sin HD1500' END AS ChkHD,
       CASE WHEN MD LIKE '%WA900%'  THEN 'SIGUE SALIENDO WA900'  ELSE 'ok: sin WA900'  END AS ChkWA,
       LEN(MD) AS LargoMD
FROM [dbo].[vw_TriageMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%todos%' AND CompTipo = 'TRACCION';
GO
-- 150.3 ⭐ Y QUE NOMBRAR UN MODELO SIN LIMITES SIGA FUNCIONANDO. Esto es lo que NO se puede
--   romper: la fila por-modelo nunca se quita. Debe devolver el 930E, con sus equipos.
SELECT LEN(MD) AS LargoMD, LEFT(MD, 120) AS Inicio
FROM [dbo].[vw_TriageMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%930E%' AND CompTipo = 'TRACCION';
GO
-- 150.4 NO REGRESION del barrido. El resumen contaba 18 equipos observados con '(todos)'.
--   Los 12 equipos sin limites no tenian ningun observado, asi que deberia seguir en 18.
--   Si baja, hay que entender por que antes de darlo por bueno.
SELECT '(todos)' AS Caso, LEN(MD) AS LargoMD, LEFT(MD, 100) AS Inicio
FROM [dbo].[vw_ObservadosResumenMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%todos%'
UNION ALL
SELECT '980', LEN(MD), LEFT(MD, 100)
FROM [dbo].[vw_ObservadosResumenMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980%';
GO
-- 150.5 EL CONTEO tambien cambia de universo por defecto: antes sumaba los 6 modelos.
SELECT LEFT(MD, 150) FROM [dbo].[vw_ConteoFlotaMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%todos%';
GO
-- 150.6 ⚠ MEDIR. El EXISTS se evalua POR FILA en vistas de flota. La vista de apoyo son 64
--   filas sin agregados, deberia ser gratis -- pero esta ronda ya pago 6 minutos por dar algo
--   por gratis. Referencia del triage: 860 ms / 1 scan (antes de esta ronda), 1 091 ms el 28/09.
SET STATISTICS TIME ON; SET STATISTICS IO ON;
SELECT LEFT(MD, 80) FROM [dbo].[vw_TriageMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%todos%' AND CompTipo = 'TRACCION';
GO
SELECT LEFT(MD, 80) FROM [dbo].[vw_ObservadosBarridoMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%todos%';
GO
SET STATISTICS TIME OFF; SET STATISTICS IO OFF;
GO

-- RESULTADOS BLOQUE 150 (29/09) -- L3 correcto y SIN coste. Todo verde.
--   150.1 ✅ vw_ModeloConLimites: 10 pares. ANTAMINA 980E · ANTAPACCAY 980E/D475A/PC1250 ·
--         CERRO VERDE 730E-/980E · QUELLAVECO D65ROC/PV351/WE2350 · TOROMOCHO 980E.
--   150.2 ✅ El triage por defecto ya no trae 930E, HD1500 ni WA900. MD de 4 397 chars.
--   150.3 ✅ Y NOMBRAR un modelo sin limites SIGUE FUNCIONANDO, que era lo que no se podia
--         romper: "Triage Motores de Traccion - Antapaccay · 930E · 0 de 18 observados
--         (0 criticos)", MD de 1 095 chars. No divaga ni cae al fallback.
--   150.4 ✅ Sin regresion en el barrido: (todos) 2 601 chars / 18 equipos · 980 2 397 / 16.
--         Identico a lo medido el 28/09 (bloque 147.1).
--   150.5 ✅ El conteo cambia de universo, como debe: 36 equipos (27+5+4, los 3 modelos con
--         limites) en vez de 48. 18 observados · 7 criticos · 11 precaucion · 18 sin novedad.
--   150.6 ✅ EL EXISTS NO COSTO NADA:
--         triage  -> LaboratoryData 1 scan · 1 365 lecturas · 1 373 ms   (28/09: 1/1 365/1 091)
--         barrido -> LaboratoryData 5 scans · 91 055 lecturas · 7 370 ms
--         [Eqpcare].[lc]: 2 scans/337 en el triage, 10/424 en el barrido. Barato.
--
-- ⚠ PERO EL 150.3 DEJA UNA FRASE ENGAÑOSA, y es un fallo silencioso de los nuestros:
--   "930E · 0 de 18 observados (0 criticos)" NO significa que esos 18 esten sanos. Significa
--   que NO HAY LIMITES con que evaluarlos. Decir "0 observados" cuando no hay con que medir es
--   exactamente la familia de fallos que venimos cerrando toda la ronda.
--   -> L5: cuando el modelo consultado no tiene limites, DECIRLO en el encabezado. No se
--      restringe nada (sigue saliendo), pero deja de dar un verde tranquilizador.
--   ⚑ 'vw_ObservadosBarridoMD' aparece con 5 scans de LaboratoryData: su CTE 'fila' se lee 3
--      veces (radar de check_ddl). Es la misma deuda del diagnostico, anotada, no urgente.


-- ==== BLOQUE 151 - PASO 2b (L5): avisar cuando el modelo NO tiene limites ====
-- POR QUE: el bloque 150.3 dejo "Antapaccay · 930E · 0 de 18 observados (0 criticos)". Eso NO
--   significa que los 18 esten sanos: significa que no hay limites con que evaluarlos. Es la
--   misma familia de fallos silenciosos de toda la ronda, y encima da un verde tranquilizador
--   sobre 18 equipos que nadie miro.
-- QUE SE HIZO: 7 encabezados (triage, barrido resumen, las 4 variantes de barridodet y conteo)
--   anaden una linea SOLO cuando el modelo pedido no tiene fila en [Eqpcare].[lc].
--   ⛔ No se restringe NADA: el modelo sigue saliendo entero, con todos sus equipos.

-- 151.1 ⭐ El caso: pedir 930E tiene que traer la tabla Y el aviso.
SELECT CASE WHEN MD LIKE '%no tiene l%mites cargados%' THEN 'ok: avisa' ELSE 'FALTA EL AVISO' END AS Chk,
       LEN(MD) AS LargoMD, LEFT(MD, 220) AS Inicio
FROM [dbo].[vw_TriageMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%930E%' AND CompTipo = 'TRACCION';
GO
-- 151.2 ⭐ Y EL CONTRARIO, que es lo que no se puede romper: un modelo CON limites NO debe
--   traer el aviso, ni '(todos)' tampoco.
SELECT '980E' AS Caso,
       CASE WHEN MD LIKE '%no tiene l%mites cargados%' THEN 'MAL: avisa de mas' ELSE 'ok: sin aviso' END AS Chk
FROM [dbo].[vw_TriageMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%' AND CompTipo = 'TRACCION'
UNION ALL
SELECT '(todos)',
       CASE WHEN MD LIKE '%no tiene l%mites cargados%' THEN 'MAL: avisa de mas' ELSE 'ok: sin aviso' END
FROM [dbo].[vw_TriageMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%todos%' AND CompTipo = 'TRACCION';
GO
-- 151.3 Las otras tres vistas que llevan el aviso.
SELECT 'barrido'  AS Vista, CASE WHEN MD LIKE '%no tiene l%mites cargados%' THEN 'ok: avisa' ELSE 'FALTA' END AS Chk
FROM [dbo].[vw_ObservadosResumenMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%930E%'
UNION ALL
SELECT 'barridodet', CASE WHEN MD LIKE '%no tiene l%mites cargados%' THEN 'ok: avisa' ELSE 'FALTA' END
FROM [dbo].[vw_ObservadosBarridoMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%930E%'
UNION ALL
SELECT 'conteo', CASE WHEN MD LIKE '%no tiene l%mites cargados%' THEN 'ok: avisa' ELSE 'FALTA' END
FROM [dbo].[vw_ConteoFlotaMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%930E%';
GO
-- ⚠ Si alguna de las tres devuelve 0 FILAS en vez de 'FALTA', no es que no avise: es que esa
--   vista no tiene fila para ese modelo (p.ej. el barrido solo lista equipos OBSERVADOS, y el
--   930E no tiene ninguno). Eso es correcto y no hay nada que arreglar ahi.
-- 151.4 Coste: el NOT EXISTS se evalua una vez por fila del RESULTADO (una por proyecto+modelo+
--   comptipo), no por equipo. Referencia del triage: 1 scan · 1 365 lecturas · 1 373 ms.
SET STATISTICS TIME ON; SET STATISTICS IO ON;
SELECT LEFT(MD, 80) FROM [dbo].[vw_TriageMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%todos%' AND CompTipo = 'TRACCION';
GO
SET STATISTICS TIME OFF; SET STATISTICS IO OFF;
GO

-- RESULTADOS BLOQUE 151 (29/09) -- L5 correcto y sin coste.
--   151.1 ✅ "ok: avisa". MD de 1 198 chars (antes 1 095: el aviso son ~103). Se ve asi:
--         **Triage Motores de Traccion - Antapaccay · 930E** · 0 de 18 observados (0 criticos)
--         ⚠ **930E no tiene limites cargados** para este proyecto: los equipos salen **sin
--           evaluar**, no sanos.
--   151.2 ✅ 980E "ok: sin aviso" y (todos) "ok: sin aviso". No avisa de mas.
--   151.3 ⚠ Solo devolvio 1 fila: conteo "ok: avisa". barrido y barridodet NO devolvieron fila.
--         Es EXACTAMENTE lo anticipado en la nota del bloque: esas vistas solo listan equipos
--         OBSERVADOS y el 930E no tiene ninguno. No es que no avisen: es que no hay fila.
--   151.4 ✅ Coste CERO: LaboratoryData 1 scan · 1 365 lecturas · 1 224 ms (antes 1 373 ms).
--         lc en 2 scans / 337. El NOT EXISTS se evalua una vez por fila del resultado.
--
-- ⚑ PERO EL 151.3 DEJA UN PENDIENTE ACOTADO (modo B de fallo silencioso):
--   '/barrido antapaccay 930E' no devolvera NINGUNA fila -> el tema mostrara "no encontre
--   datos", cuando la verdad es "ese modelo no tiene equipos observados, y ademas no tiene
--   limites con que evaluarlos". ISNULL no sirve aqui: hay que EMITIR la fila.
--   ⛔ No se toca ahora: cambiar la cardinalidad de vw_ObservadosResumenMD afecta a todos los
--   proyectos sin observados, y ahi "ninguno observado" es una BUENA noticia legitima. Se
--   resuelve mejor en el tema (mensaje sin-data que distinga los dos casos). Anotado en
--   PENDIENTES como L6.


-- ==== BLOQUE 152 - PASO 3 (L4): el ranking, <modelo> y H3 ====
-- HALLAZGO AL ABRIRLO: vw_RankingMD YA expone 'Modelo' (el ModeloG del rollup) y el flujo
--   MD_ranking YA filtra por el:  AND Modelo LIKE ''%<modelo>%''  (CONFIG_FLUJOS).
--   Lo unico que falta es que el COMANDO lo pase: su firma es /ranking <proj> <comp> <metal>
--   [top], sin modelo. => L4 es enteramente COPILOT. En SQL no habia nada que construir.
-- Y COMO L3 YA ESTA: el rollup '(todos)' ya no incluye 930E, asi que H3 (los equipos
--   3114..3118 colandose en el ranking de PQ) deberia estar cerrado DE REBOTE. Se comprueba.

-- 152.1 ⭐ H3: el ranking de PQ en MT de Antapaccay, por defecto. Los 3110..3118 son 930E.
--   Si ya no aparecen, L3 cerro H3 sin tocar el ranking.
SELECT CASE WHEN MD LIKE '%311%' THEN 'SIGUEN LOS 311x' ELSE 'ok: sin equipos 930E' END AS Chk,
       LEN(MD) AS LargoMD, LEFT(MD, 300) AS Inicio
FROM (
    SELECT MAX(HeaderMD) + NCHAR(10) + STRING_AGG(Fila, NCHAR(10)) WITHIN GROUP (ORDER BY pos) AS MD
    FROM [dbo].[vw_RankingMD] WITH (NOLOCK)
    WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%todos%'
      AND CompTipo COLLATE Latin1_General_CI_AI LIKE '%TRACCION%'
      AND Metal LIKE '%PQ%' AND pos <= 20
) z;
GO
-- 152.2 Y que pedir un modelo concreto funcione, que es para lo que L4 agrega el parametro.
SELECT '980E' AS Caso, COUNT(*) AS Filas FROM [dbo].[vw_RankingMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%'
  AND CompTipo COLLATE Latin1_General_CI_AI LIKE '%TRACCION%' AND Metal LIKE '%PQ%'
UNION ALL
SELECT '930E', COUNT(*) FROM [dbo].[vw_RankingMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%930E%'
  AND CompTipo COLLATE Latin1_General_CI_AI LIKE '%TRACCION%' AND Metal LIKE '%PQ%';
GO
-- 152.3 EL TOPE SILENCIOSO. La vista cortaba en pos <= 20 y el flujo filtra por el top que
--   pide el usuario: pedir "top 30" devolvia 20 y NADIE lo decia. Ahora la vista corta en 50.
--   Esto tiene que devolver mas de 20 posiciones donde la flota de lo suficiente.
SELECT Proyecto, Modelo, CompTipo, Metal, MAX(pos) AS PosMax, COUNT(*) AS Filas
FROM [dbo].[vw_RankingMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%todos%'
  AND CompTipo COLLATE Latin1_General_CI_AI LIKE '%TRACCION%' AND Metal LIKE '%Fe%'
GROUP BY Proyecto, Modelo, CompTipo, Metal;
GO

-- RESULTADOS BLOQUE 152 (29/09) -- L4 cerrado en SQL y H3 cerrado DE REBOTE.
--   152.1 ✅ "ok: sin equipos 930E". El ranking de PQ en MT de Antapaccay ahora sale limpio:
--         1 CA3195 233.2 (130/150) 🟥 · 2 CA3178 120.4 · 3 CA3165 94.8 · 4 CA3161 94.6 · 5 CA3179 90.8
--         Todos CA#### y todos CON limites. Comparar con la marcha del 28/09, donde salian
--         3117 163.8 (—/—), 3114 145.0 (—/—), 3116 118.4 (—/—), 3115 76.6, 3118 71.6.
--         => H3 se cerro sin tocar el ranking: fue consecuencia de L3.
--   152.2 ✅ Pedir un modelo concreto funciona, incluso uno SIN limites: 980E -> 27 filas,
--         930E -> 9 filas. Confirma que no restringimos nada.
--   152.3 ✅ El tope silencioso ya no corta: PosMax 27 / 27 filas (antes la vista cortaba en 20).


-- ==== BLOQUE 153 - PASO 4 (C): reconocimiento ANTES de escribir el Acum ====
-- Carlos dio la regla de CM para CUATRO componentes:
--     MT -> ADI y C   |   Rueda -> solo C   |   MODI -> todos   |   Sist. Hidraulico -> solo C
-- Y la formula esta VALIDADA AL DECIMAL para MT (bloque 137.3: 3 718,6).
-- ⛔ PERO NO HAY REGLA para MANDO FINAL, TRANSMISION, CAJA GIRO, DAMPER ni PTO. Y no hay
--    verificacion para rueda ni hidraulico: la unica cifra que dio Carlos es de MT.
--    Escribir la vista suponiendo una regla para los demas seria inventar. Esto lo mide.

-- 153.1 ⭐ QUE COMPONENTES TIENE CADA MODELO. Andres apunta que mando final y transmision son
--   de tractores (D475A) y excavadoras (PC1250), no de los camiones 980E/930E. Con dato.
SELECT EF.[Model] AS Modelo,
       CASE WHEN LD.[Compartimiento] LIKE '%TRACCION%'    THEN 'TRACCION'
            WHEN LD.[Compartimiento] LIKE '%RUEDA%'       THEN 'RUEDA'
            WHEN LD.[Compartimiento] LIKE '%HIDRAUL%'     THEN 'HIDRAULICO'
            WHEN LD.[Compartimiento] LIKE '%MANDO%'       THEN 'MANDO'
            WHEN LD.[Compartimiento] LIKE '%TRANSMISION%' THEN 'TRANSMISION'
            WHEN LD.[Compartimiento] LIKE 'MOTOR%'        THEN 'MOTOR'
            ELSE 'OTRO' END AS CompTipo,
       COUNT(DISTINCT ME.[Code]) AS Equipos, COUNT(*) AS Muestras
FROM [Oil].[LaboratoryData] LD WITH (NOLOCK)
JOIN [Mine].[MiningEquipment] ME WITH (NOLOCK) ON ME.[Id] = LD.[MiningEquipmentId]
JOIN [Mine].[MiningProject]   MP WITH (NOLOCK) ON MP.[Id] = ME.[MiningProjectId]
JOIN [Mine].[EquipmentFleet]  EF WITH (NOLOCK) ON EF.[Id] = ME.[EquipmentFleetId]
WHERE MP.[Name] LIKE '%Antapaccay%'
GROUP BY EF.[Model],
       CASE WHEN LD.[Compartimiento] LIKE '%TRACCION%'    THEN 'TRACCION'
            WHEN LD.[Compartimiento] LIKE '%RUEDA%'       THEN 'RUEDA'
            WHEN LD.[Compartimiento] LIKE '%HIDRAUL%'     THEN 'HIDRAULICO'
            WHEN LD.[Compartimiento] LIKE '%MANDO%'       THEN 'MANDO'
            WHEN LD.[Compartimiento] LIKE '%TRANSMISION%' THEN 'TRANSMISION'
            WHEN LD.[Compartimiento] LIKE 'MOTOR%'        THEN 'MOTOR'
            ELSE 'OTRO' END
ORDER BY Modelo, CompTipo;
GO

-- 153.2 ⭐ QUE PASA CON CADA REGLA, componente por componente. Cuantas muestras 'En uso'
--   sobreviven a cada criterio. Si para un componente la regla deja 0 o 2 muestras, esa regla
--   NO sirve ahi y hay que preguntar en vez de suponer.
SELECT CASE WHEN LD.[Compartimiento] LIKE '%TRACCION%'    THEN 'TRACCION'
            WHEN LD.[Compartimiento] LIKE '%RUEDA%'       THEN 'RUEDA'
            WHEN LD.[Compartimiento] LIKE '%HIDRAUL%'     THEN 'HIDRAULICO'
            WHEN LD.[Compartimiento] LIKE '%MANDO%'       THEN 'MANDO'
            WHEN LD.[Compartimiento] LIKE '%TRANSMISION%' THEN 'TRANSMISION'
            WHEN LD.[Compartimiento] LIKE 'MOTOR%'        THEN 'MOTOR'
            ELSE 'OTRO' END AS CompTipo,
       COUNT(*)                                                 AS EnUso_Todas,
       SUM(CASE WHEN LD.[CM] IN ('ADI','C') THEN 1 ELSE 0 END)  AS Regla_MT_AdiC,
       SUM(CASE WHEN LD.[CM] = 'C'          THEN 1 ELSE 0 END)  AS Regla_SoloC,
       COUNT(DISTINCT LD.[ComponentSerialNumber])               AS Series
FROM [Oil].[LaboratoryData] LD WITH (NOLOCK)
JOIN [Mine].[MiningEquipment] ME WITH (NOLOCK) ON ME.[Id] = LD.[MiningEquipmentId]
JOIN [Mine].[MiningProject]   MP WITH (NOLOCK) ON MP.[Id] = ME.[MiningProjectId]
WHERE MP.[Name] LIKE '%Antapaccay%' AND LD.[ComponentStatus] = N'En uso'
GROUP BY CASE WHEN LD.[Compartimiento] LIKE '%TRACCION%'    THEN 'TRACCION'
              WHEN LD.[Compartimiento] LIKE '%RUEDA%'       THEN 'RUEDA'
              WHEN LD.[Compartimiento] LIKE '%HIDRAUL%'     THEN 'HIDRAULICO'
              WHEN LD.[Compartimiento] LIKE '%MANDO%'       THEN 'MANDO'
              WHEN LD.[Compartimiento] LIKE '%TRANSMISION%' THEN 'TRANSMISION'
              WHEN LD.[Compartimiento] LIKE 'MOTOR%'        THEN 'MOTOR'
              ELSE 'OTRO' END
ORDER BY CompTipo;
GO

-- 153.3 ⭐ EL ACUMULADO QUE SALDRIA, con cada regla, en un caso de RUEDA y uno de HIDRAULICO.
--   La unica cifra verificada es la de MT (3 718,6). Esto ensena si las otras reglas dan un
--   numero razonable o un disparate. Comparar la columna de la regla de Carlos con 'Todas'.
SELECT ME.[Code] AS Equipo, LD.[Compartimiento],
       COUNT(*) AS MuestrasEnUso,
       CAST(SUM(LD.[Fe_ppm]) AS decimal(18,1)) AS Fe_Todas,
       CAST(SUM(CASE WHEN LD.[CM] IN ('ADI','C') THEN LD.[Fe_ppm] END) AS decimal(18,1)) AS Fe_AdiC,
       CAST(SUM(CASE WHEN LD.[CM] = 'C'          THEN LD.[Fe_ppm] END) AS decimal(18,1)) AS Fe_SoloC
FROM [Oil].[LaboratoryData] LD WITH (NOLOCK)
JOIN [Mine].[MiningEquipment] ME WITH (NOLOCK) ON ME.[Id] = LD.[MiningEquipmentId]
WHERE ME.[Code] IN ('CA3195','CA3175') AND LD.[ComponentStatus] = N'En uso'
  AND (LD.[Compartimiento] LIKE '%RUEDA%' OR LD.[Compartimiento] LIKE '%HIDRAUL%'
       OR LD.[Compartimiento] LIKE '%TRACCION%LH')
GROUP BY ME.[Code], LD.[Compartimiento]
ORDER BY ME.[Code], LD.[Compartimiento];
GO

-- 153.4 CUANTO SE PIERDE por no tener ComponentStatus. El 43% de las filas lo trae (bloque
--   141.2); lo que importa es cuantos COMPONENTES se quedarian sin acumulado.
SELECT COUNT(*) AS ComponentesConMuestra,
       SUM(CASE WHEN ConStatus > 0 THEN 1 ELSE 0 END) AS ConAcumulado,
       SUM(CASE WHEN ConStatus = 0 THEN 1 ELSE 0 END) AS SinAcumulado
FROM (
    SELECT ME.[Code] AS Equipo, LD.[Compartimiento],
           SUM(CASE WHEN LD.[ComponentStatus] = N'En uso' THEN 1 ELSE 0 END) AS ConStatus
    FROM [Oil].[LaboratoryData] LD WITH (NOLOCK)
    JOIN [Mine].[MiningEquipment] ME WITH (NOLOCK) ON ME.[Id] = LD.[MiningEquipmentId]
    JOIN [Mine].[MiningProject]   MP WITH (NOLOCK) ON MP.[Id] = ME.[MiningProjectId]
    WHERE MP.[Name] LIKE '%Antapaccay%'
    GROUP BY ME.[Code], LD.[Compartimiento]
) z;
GO

-- 153.5 ⚠ EL COSTE de leer TODA la historia (sin la ventana de 12 meses), que es lo que exige
--   el Acum. Es el riesgo de diseno del bloque C. Mirar 'elapsed' y 'logical reads'.
SET STATISTICS TIME ON; SET STATISTICS IO ON;
SELECT ME.[Code] AS Equipo, LD.[Compartimiento],
       CAST(SUM(LD.[Fe_ppm]) AS decimal(18,1)) AS Fe_Acum
FROM [Oil].[LaboratoryData] LD WITH (NOLOCK)
JOIN [Mine].[MiningEquipment] ME WITH (NOLOCK) ON ME.[Id] = LD.[MiningEquipmentId]
WHERE LD.[ComponentStatus] = N'En uso' AND LD.[CM] IN ('ADI','C')
GROUP BY ME.[Code], LD.[Compartimiento];
GO

-- RESULTADOS BLOQUE 153 (29/09) -- reveladores. Cambian el diseno del Acum y cierran el
-- bloque B de la ronda 23/09, que llevaba bloqueado desde el 25/09.
--
-- 153.1 ✅ LOS COMPONENTES SON SIMETRICOS POR TIPO DE MAQUINA. Confirma la intuicion de Andres:
--       CAMIONES (930E, 980E)          -> TRACCION · RUEDA · MOTOR · HIDRAULICO
--       TRACTOR / EXCAVADORA / CARGADOR
--       (D475A, HD1500, PC1250, WA900) -> MANDO · TRANSMISION · MOTOR · HIDRAULICO
--       MANDO y TRANSMISION NO EXISTEN en 930E ni 980E. TRACCION y RUEDA no existen en los otros.
--       Motor e hidraulico los comparten todos. (PC1250 no tiene TRANSMISION: es excavadora.)
--
-- 153.2 🔴 EL HALLAZGO QUE CAMBIA EL DISENO: solo devolvio DOS filas.
--       CompTipo    EnUso_Todas  Regla_AdiC  Regla_SoloC  Series
--       MOTOR            2 272         515         515        27
--       TRACCION         2 906       1 390         265        53
--       => 'ComponentStatus = En uso' SOLO EXISTE PARA MOTOR Y MOTOR DE TRACCION.
--          Para RUEDA, HIDRAULICO, MANDO y TRANSMISION no hay NI UNA fila con ese estado.
--       ⇒ NO HAY QUE INVENTAR NINGUNA REGLA para mando/transmision/caja giro/damper/PTO:
--         el problema no era que faltara la regla, es que no hay componente instalado que
--         seguir. La pregunta a Carlos se desvanece sola.
--       ⇒ En MOTOR, AdiC == SoloC == 515: no hay muestras 'ADI' en el motor (no se dializa).
--         Y Carlos dijo "en el motor sumas TODO" -> ahi la regla es 2 272, no 515.
--
-- 153.3 ✅ LA FORMULA DE MT, CONFIRMADA POR SEGUNDA VEZ:
--       CA3195 MT LH · 62 muestras 'En uso' · Todas 6 941,3 · AdiC 3 718,6 · SoloC 805,5
--       CA3175 MT LH · 39 muestras          · Todas 3 497,6 · AdiC 1 877,9 · SoloC 568,8
--       3 718,6 = la cifra de Carlos, al decimal.
--       Y NO devolvio filas de RUEDA ni HIDRAULICO para esos equipos: confirma el 153.2.
--
-- 153.4 ⚠ COBERTURA: 306 componentes con muestra · 80 con acumulado · 226 SIN.
--       Solo el 26% puede tener Acum, y son exactamente los 27 motores + 53 MT del 153.2.
--       Los 226 restantes van con '—'. NO es una limitacion nuestra: no hay dato de que
--       componente esta instalado. Y '—' NO es cero: hay que decirlo en el pie.
--
-- 153.5 ⭐⭐ AQUI ESTABA EL BLOQUE B DE LA RONDA 23/09:
--       CA3160 · MOTOR DE TRACCION · Fe_Acum = 6 785,4
--       La cifra de Carlos era 6 785,39. Llevaba BLOQUEADA desde el 25/09: se probaron
--       ventanas de 12 a 60 meses, todos los tipos de muestra y los 18 parametros, y el
--       veredicto fue "no se reproduce con ningun criterio, hay que preguntar".
--       Era ComponentStatus='En uso' + CM IN ('ADI','C') sobre TODA la historia.
--       => BLOQUE B: CERRADO.
--       La consulta global devolvio 80 filas (27 MOTOR + 53 MT) sin coste aparente.
--
-- DISENO QUE SALE DE AQUI (bloque C):
--   1. vw_AcumuladoVida lee [Oil].[LaboratoryData] directo, sin la fundacion y sin la ventana
--      de 12 meses, y SOLO para los dos componentes que tienen ComponentStatus:
--          MOTOR DE TRACCION -> CM IN ('ADI','C')      MOTOR -> todos los CM
--   2. Solo se calculan los 8 metales de DESGASTE (Fe, PQ, Cr, Ni, Cu, Pb, Sn, Al), que son
--      los unicos que el display muestra hoy. Calcular los 18 seria pagar de mas.
--   3. vw_TendenciaElemento la consume con LEFT JOIN y el resto sale '—'.
--   4. Renombre 'Σvida' -> 'Acum' y fuera el '(nº de muestras)'.


-- ==== BLOQUE 154 - PASO 4 (C): el Acum desplegado ====
-- QUE CAMBIO: los CTE 'sa' y 'acc' de vw_TendenciaElemento (que sumaban sobre la fundacion, o
--   sea sobre 12 MESES) se reemplazan por la vista dedicada vw_AcumuladoVida, que lee
--   [Oil].[LaboratoryData] directo, SIN ventana, con ComponentStatus='En uso' y el CM que
--   corresponde a cada componente. Fuera el '(nº de muestras)'. 'Σvida' pasa a llamarse 'Acum'.

-- 154.1 ⭐ SMOKE + LAS DOS CIFRAS VERIFICADAS. Tienen que salir 3 718,6 y 6 785,4.
SELECT Equipo, Compartimiento, Parametro, Acumulado
FROM [dbo].[vw_AcumuladoVida]
WHERE (Equipo = 'CA3195' AND Compartimiento LIKE '%TRACCION%LH' AND Parametro = 'Fe')
   OR (Equipo = 'CA3160' AND Compartimiento LIKE '%TRACCION%'   AND Parametro = 'Fe')
ORDER BY Equipo, Compartimiento;
GO
-- 154.2 COBERTURA. CORREGIDO el 29/09: Carlos SI dio regla para rueda e hidraulico (solo C) y
--   yo la habia descartado al ver que esos componentes no tienen [ComponentStatus]. Ahora entran,
--   sin ese filtro. Deben salir MT, MOTOR, RUEDA e HIDRAULICO. MANDO y TRANSMISION no (para esos
--   no hay regla del area).
SELECT CASE WHEN Compartimiento LIKE '%TRACCION%' THEN 'TRACCION'
            WHEN Compartimiento LIKE '%RUEDA%'    THEN 'RUEDA'
            WHEN Compartimiento LIKE '%HIDRAUL%'  THEN 'HIDRAULICO'
            WHEN Compartimiento LIKE 'MOTOR%'     THEN 'MOTOR'
            ELSE 'OTRO -- NO DEBERIA SALIR' END AS CompTipo,
       COUNT(DISTINCT Equipo + '|' + Compartimiento) AS Componentes,
       COUNT(*) AS Filas
FROM [dbo].[vw_AcumuladoVida]
GROUP BY CASE WHEN Compartimiento LIKE '%TRACCION%' THEN 'TRACCION'
              WHEN Compartimiento LIKE '%RUEDA%'    THEN 'RUEDA'
              WHEN Compartimiento LIKE '%HIDRAUL%'  THEN 'HIDRAULICO'
              WHEN Compartimiento LIKE 'MOTOR%'     THEN 'MOTOR'
              ELSE 'OTRO -- NO DEBERIA SALIR' END;
GO
-- 154.2b CUANTAS MUESTRAS SOSTIENEN el acumulado de rueda e hidraulico. Si el promedio es de
--   2-3 muestras, el numero existe pero dice poco, y eso hay que consultarlo con Carlos.
SELECT CompTipo, COUNT(*) AS Componentes,
       MIN(nMuestras) AS Min_, MAX(nMuestras) AS Max_, AVG(nMuestras) AS Prom_
FROM (
    SELECT CASE WHEN LD.[Compartimiento] LIKE '%RUEDA%' THEN 'RUEDA' ELSE 'HIDRAULICO' END AS CompTipo,
           ME.[Code] AS Equipo, LD.[Compartimiento], COUNT(*) AS nMuestras
    FROM [Oil].[LaboratoryData] LD WITH (NOLOCK)
    JOIN [Mine].[MiningEquipment] ME WITH (NOLOCK) ON ME.[Id] = LD.[MiningEquipmentId]
    JOIN [Mine].[MiningProject]   MP WITH (NOLOCK) ON MP.[Id] = ME.[MiningProjectId]
    WHERE MP.[Name] LIKE '%Antapaccay%' AND LD.[CM] = 'C'
      AND (LD.[Compartimiento] LIKE '%RUEDA%' OR LD.[Compartimiento] LIKE '%HIDRAUL%')
    GROUP BY ME.[Code], LD.[Compartimiento]
) z GROUP BY CompTipo;
GO
-- 154.3 ⭐ QUE LLEGUE A vw_TendenciaElemento. El Fe del CA3195 MT LH debe traer 3 718,6, y el
--   resto de parametros (Si, Ca, Zn...) debe venir NULL: solo se calculan los 8 de desgaste.
SELECT Parametro, Acumulado
FROM [dbo].[vw_TendenciaElemento] WITH (NOLOCK)
WHERE Equipo = 'CA3195' AND Compartimiento LIKE '%TRACCION%LH'
ORDER BY CASE WHEN Acumulado IS NULL THEN 1 ELSE 0 END, Parametro;
GO
-- 154.4 ⭐ COMO SE VE. La cabecera debe decir 'Acum' (no 'Σvida (nº m.)'), el numero debe salir
--   SIN parentesis, y el pie debe explicar que '—' no es cero.
SELECT MD FROM [dbo].[vw_TendenciaMD] WITH (NOLOCK)
WHERE Equipo LIKE '%3195%' AND compAbbr LIKE '%MT LH%';
GO
-- 154.5 ⭐ LA RUEDA DEL CA3175. Ahora SI debe traer un numero (regla: solo C), pero DISTINTO del
--   de antes: el viejo sumaba todas las muestras de 12 meses, el nuevo solo las 'C' de toda la
--   historia. Si sale un guion, es que ese equipo no tiene ninguna muestra 'C' en la rueda.
SELECT MD FROM [dbo].[vw_TendenciaMD] WITH (NOLOCK)
WHERE Equipo LIKE '%3175%' AND compAbbr LIKE '%RD LH%';
GO
-- 154.6 ⚠ MEDIR. vw_AcumuladoVida lee TODA la historia (9 anos) sin ventana, y ahora cuelga de
--   /tendencia y /tendenciametal. Referencias: /tendencia ~35 s y /tendenciametal ~30 s ANTES
--   de esta ronda (esos numeros ya eran malos: ver el radar de CTE de check_ddl).
--   Con LIKE, como el flujo. Correr 2 veces, usar la 2a.
SET STATISTICS TIME ON; SET STATISTICS IO ON;
SELECT LEFT(MD, 80) FROM [dbo].[vw_TendenciaMD] WITH (NOLOCK)
WHERE Equipo LIKE '%3195%' AND compAbbr LIKE '%MT LH%';
GO
SELECT COUNT(*) FROM [dbo].[vw_AcumuladoVida];
GO
SET STATISTICS TIME OFF; SET STATISTICS IO OFF;
GO
/* SI 154.6 SE DISPARA: la salida es materializar el acumulado por otra via (una tabla que el
   area refresque, o acotar vw_AcumuladoVida a los equipos del proyecto consultado). NO se
   vuelve a la formula vieja: esa daba un numero que no era el que pedia el area. */

-- RESULTADOS BLOQUE 154 (29/09) -- el Acum funciona. C CERRADO.
--   154.1 ✅ LAS DOS CIFRAS VERIFICADAS, al decimal:
--         CA3160 MT LH Fe = 6 785,4   <- la cifra del bloque B de la ronda 23/09
--         CA3160 MT RH Fe = 7 385,6
--         CA3195 MT LH Fe = 3 718,6   <- la que dio Carlos el 28/09
--   154.2 ✅ COBERTURA, con las CUATRO reglas: 228 componentes con Acum
--         TRACCION 53 · RUEDA 97 · HIDRAULICO 51 · MOTOR 27     (1 813 filas en total)
--         Ni una fila de 'OTRO': mando y transmision no entran, como debe ser.
--         ⚑ Con las dos reglas que yo habia dejado fuera eran 80. La correccion de Andres
--           recupero 148 componentes.
--   154.2b ⚠ CUANTAS MUESTRAS SOSTIENEN EL ACUMULADO (Antapaccay, muestras 'C'):
--         RUEDA       54 componentes · min 14 · max 36 · promedio 20   -> solido
--         HIDRAULICO  32 componentes · min  1 · max 10 · promedio  6   -> FLOJO
--         🔴 En hidraulico hay componentes con UNA sola muestra 'C': ahi el "acumulado" es
--         literalmente el valor de esa muestra. El numero existe y la regla es la que pidio el
--         area, pero dice poco. -> PREGUNTA PARA CARLOS, no cambio unilateral.
--   154.3 ✅ Llega a vw_TendenciaElemento y solo en los 8 de desgaste. CA3195 MT LH:
--         Fe 3 718,6 · PQ 2 489,0 · Cu 38,0 · Cr 19,5 · Ni 10,3 · Al 7,5 · Sn 4,1 · Pb 3,5
--         Los otros 15 parametros (Si, Ca, Zn, K, Na, Mg, B, P, V100, V40, TAN, Mo, Agua,
--         ISO>4/6/14) vienen NULL -> salen '—'. Exactamente lo disenado.
--   154.4 ✅ La cabecera dice 'Acum' (no 'Σvida (nº m.)'), el numero sale SIN parentesis y el
--         pie explica el criterio por componente y que '—' no es cero.
--   154.5 ✅ LA RUEDA DEL CA3175 YA TRAE ACUM (era el caso de la correccion):
--         Fe 687,8 · PQ 366,4 · Cu 29,2 · Al 19,7 · Ni 3,1 · Pb 1,5 · Cr 1,3 · Sn 0,2
--   154.6 RENDIMIENTO:
--         vw_AcumuladoVida SOLA -> 1 813 filas · 1 scan · 18 212 lecturas · 852 ms. BARATA.
--         /tendencia CA3195 MT LH -> 6 scans · 41 878 lecturas · 37 009 ms.
--         ⚠ 37 s. Pero /tendencia ya venia en ~35 s ANTES de esta ronda: el Acum NO lo empeoro,
--         y la vista nueva por si sola cuesta 852 ms. La deuda es otra y esta identificada por
--         el radar de check_ddl: vw_TendenciaMD.rowcte x2 · limcte x2 · obslast x2.
--         Va al mismo saco que vw_DiagnosticoMD, despues de la presentacion del 02/10.


-- ==== BLOQUE 155 - PASO 5 (J): el triage pasa a 5 COLUMNAS por familia ====
-- ⚑ REHECHO el 29/09. Primero lo implemente prefijando la familia DENTRO de la celda
--    ("Desgaste: Fe(232.6) · Contaminacion: Si(8.1)"). Andres aclaro que el diseno que tenia en
--    mente eran COLUMNAS: las dos de hoy ('Metales Obs.' y 'Salud') se reemplazan por CINCO.
-- LA TABLA PASA DE 8 A 11 COLUMNAS:
--    Equipo | Comp | Grado | Estado | Desgaste | Aditivos | Contaminacion | Salud | Cod. Limpieza | Hrs Comp | Ult.
-- La familia de cada parametro sale de vw_FormatoParametro (DEPENDE DEL COMPONENTE: el Ca es
--    contaminante en MT y aditivo en el resto), con fallback a '(CRUZADO)' para MANDO y
--    TRANSMISION, que no estan en el formato por-componente.
-- El triage pasa de mirar 9 parametros a mirar 30, y cada uno sale CON SU VALOR: la columna
--    Salud mostraba 'V100' a secas, sin numero (lo noto Andres en la captura).

-- 155.1 ⭐ COMO SE VE. Triage MT de Antapaccay: 11 columnas y los observados repartidos.
SELECT LEFT(MD, 1800) AS Inicio
FROM [dbo].[vw_TriageMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%todos%' AND CompTipo = 'TRACCION';
GO
-- 155.2 ⭐ V100 CON VALOR. El CA3163 y el CA3177 tenian V100 critico sin numero. Ahora la
--   columna Salud debe decir algo como 'V100(22.1) 🟥'.
SELECT LEFT(MD, 2500) AS Inicio
FROM [dbo].[vw_TriageMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%todos%' AND CompTipo = 'TRACCION';
GO
-- 155.3 ⭐ EL REPARTO EN VARIAS FAMILIAS. En MODI el CA3196 tenia Al(2.1) y Si(6.8): Al va a
--   Desgaste y Si a Contaminacion, en columnas distintas.
SELECT LEFT(MD, 1500) AS Inicio
FROM [dbo].[vw_TriageMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%todos%' AND CompTipo = 'MOTOR';
GO
-- 155.4 ⚠ EL FALLBACK. MANDO y TRANSMISION no estan en el formato por-componente. Deben seguir
--   mostrando sus parametros, tomando la familia de '(CRUZADO)'. Si las 5 columnas salen
--   vacias donde antes habia metales, el fallback no funciono.
SELECT CompTipo, LEFT(MD, 900) AS Inicio
FROM [dbo].[vw_TriageMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%todos%' AND CompTipo IN ('MANDO','TRANSMISION');
GO
-- 155.5 NO REGRESION DEL CONTADOR. Estado_General NO se toco, asi que el "X de N observados"
--   tiene que dar lo MISMO. Referencia del 28/09: Antapaccay TRACCION -> 6 de 54 (3 criticos).
--   ⚑ OJO: ahora pueden aparecer filas 🟢 CON algo marcado en Aditivos, Salud o Cod. Limpieza.
--   NO es un bug: esas familias se muestran pero todavia no disparan el estado, y el pie de la
--   tabla lo dice explicitamente. Si se quiere que disparen, es decision del area (misma
--   decision que quedo abierta en el bloque D).
SELECT LEFT(MD, 120) AS Cabecera
FROM [dbo].[vw_TriageMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%todos%' AND CompTipo = 'TRACCION';
GO
-- 155.6 COSTE. base pasa de ~30 a ~75 columnas y el VALUES de 9 a 30 parametros, con un TOP 1
--   contra vw_FormatoParametro por parametro observado. Referencia: 1 scan · 1 365 lecturas ·
--   1 723 ms. Lo que NO puede pasar es que suba el Scan count.
SET STATISTICS TIME ON; SET STATISTICS IO ON;
SELECT LEFT(MD, 80) FROM [dbo].[vw_TriageMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%todos%' AND CompTipo = 'TRACCION';
GO
SET STATISTICS TIME OFF; SET STATISTICS IO OFF;
GO
-- 155.7 ⚠ ANCHO. La tabla pasa de 8 a 11 columnas. En Teams el markdown no scrollea en
--   horizontal: hay que MIRAR si entra. Si no entra, la palanca NO es comprimir sino decidir
--   que columna sobra (candidata: 'Grado', que se repite en todas las filas de una misma flota).
SELECT LEN(MD) AS LargoMD FROM [dbo].[vw_TriageMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%todos%' AND CompTipo = 'TRACCION';
GO

-- RESULTADOS BLOQUE 155 (29/09) -- las 5 columnas funcionan. J CERRADO EN LO TECNICO,
-- pero ABRE una decision de diseno que se mide en el BLOQUE 156 (leerlo antes de seguir).
--
-- 155.1/155.2 ⭐ V100 YA SALE CON SU VALOR. Era la observacion de Andres sobre la captura
--   anterior: la columna Salud mostraba 'V100' a secas. Ahora: CA3163 MT LH -> V100(63.5) 🟨.
--
-- 155.3 ⭐ EL REPARTO EN FAMILIAS ES CORRECTO. MODI, CA3196:
--     Desgaste Al(2.1) | Contaminacion Si(6.8), Hollin(0.4) | Salud Sulfatacion(3.2), Nitracion(9.1)
--   Tres familias distintas en tres columnas distintas, cada una con su valor. Y el Hollin cayo
--   en Contaminacion, no en Salud: eso lo decidio vw_FormatoParametro, no una lista mia.
--
-- 155.4 ✅ EL FALLBACK '(CRUZADO)' FUNCIONA. MANDO 8108 -> Fe(288.3) en Desgaste; 8109 ->
--   ISO>6(23.0) en Cod. Limpieza. Sin el fallback esos parametros habrian desaparecido sin ruido
--   (MANDO y TRANSMISION no estan en el formato por-componente).
--
-- 155.5 ✅ SIN REGRESION DEL CONTADOR. Antapaccay TRACCION sigue en "6 de 54 observados
--   (3 criticos)", identico al 28/09. Estado_General no se toco.
--
-- 155.6 COSTE ACEPTABLE. LaboratoryData: Scan count 1 · 18 211 lecturas. Elapsed 2 387 ms
--   (antes ~1 723 ms). Sube ~660 ms por los ~20 parametros extra y los 30 TOP 1 contra
--   vw_FormatoParametro, pero NO aparecio ningun scan nuevo, que era la condicion. Worktable
--   scan count 1 537 = el pivote MAX(CASE...), esperado.
--
-- 155.7 ✅ ANCHO. LargoMD = 6 258 chars, muy por debajo de los ~28 000 de Teams. El limite de
--   canal no es el problema; lo que hay que MIRAR en Teams es si 11 columnas entran sin cortarse.
--
-- ⚑ "Warning: Null value is eliminated by an aggregate or other SET operation."
--   Es BENIGNO y esperado: el MAX(CASE WHEN GrupoOrden = ...) devuelve NULL para las familias sin
--   marcas. No hay que silenciarlo con SET ANSI_WARNINGS OFF -- eso apagaria avisos que si
--   importan en otras vistas.
--
-- 🔴 LO QUE ESTE BLOQUE DEJA A LA VISTA, Y QUE ES EL VERDADERO TEMA:
--   En la captura hay filas 🟢 con Zn y ISO>6 marcados. El pie de la tabla lo explica, pero la
--   explicacion es un PARCHE: el contador mira 9 metales y la tabla muestra 30. Andres planteo la
--   politica del area -- "fuera de su limite (si lo tiene) = observado", del Fe al ISO -- que es
--   la cura de fondo y ya es como cuenta /condicionmt. Antes de implementarla hay que saber a
--   cuantos equipos marca: ver BLOQUE 156.


-- ==== BLOQUE 156 - DECISION: "fuera de limite = observado" para TODO parametro ====
-- LA PREGUNTA DE ANDRES (29/09): la politica del area es que CUALQUIER parametro fuera de su
--   limite (si lo tiene) deja el componente observado, del Fe al ISO. Hoy Estado_General solo
--   mira 9 metales de desgaste + TBN, asi que el triage cuenta una cosa y la tabla muestra otra.
--
-- ⚑ ESTO NO ES UNA VALIDACION, ES UNA MEDICION PREVIA. No toca ninguna vista. Decide el diseno
--   ANTES de escribirlo, que es mas barato que escribirlo y descubrirlo.
--
-- POR QUE IMPORTA MEDIRLO. En la captura del 29/09 el Zn sale marcado en casi todas las filas de
--   980E MT (40, 45, 70, 57, 194, 100) y el ISO>6 tambien. Si esos disparan, el triage puede
--   pasar de "6 de 54" a "~50 de 54". Un triage que marca al 90% NO prioriza nada, que es lo
--   contrario de para que existe. La regla es correcta; el riesgo es de CANTIDAD.
--
-- PRECEDENTE A FAVOR DE LA REGLA: vw_CondicionMTMD ya cuenta asi desde el BLOQUE 118 ("el
--   contador sale de las celdas marcadas, no de Estado_General"): eran 119 componentes con el
--   encabezado contradiciendo a la tabla. El inconsistente es el TRIAGE, no la propuesta.

-- 156.1 ⭐ LA CIFRA QUE DECIDE. Por proyecto x tipo de componente: cuantos observados HOY
--   (Estado_General, 9 metales + TBN) contra cuantos con la REGLA NUEVA (cualquier Estado_*).
--   Si Nuevo/Total pasa de ~60%, el triage deja de discriminar y hay que replantear el formato.
SELECT Proyecto, CompTipo,
       COUNT(*)                                                      AS Total,
       SUM(CASE WHEN Estado_General <> 'OK' THEN 1 ELSE 0 END)       AS Hoy,
       SUM(CASE WHEN nMarcas > 0 THEN 1 ELSE 0 END)                  AS Nuevo,
       SUM(CASE WHEN nCrit   > 0 THEN 1 ELSE 0 END)                  AS Nuevo_solo_criticos,
       CAST(100.0 * SUM(CASE WHEN nMarcas > 0 THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0) AS decimal(5,1)) AS PctNuevo
FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK)
CROSS APPLY (
    SELECT SUM(CASE WHEN e.est IN ('CRITICO','PRECAUCION') THEN 1 ELSE 0 END) AS nMarcas,
           SUM(CASE WHEN e.est = 'CRITICO' THEN 1 ELSE 0 END)                 AS nCrit
    FROM (VALUES (Estado_Fe),(Estado_PQ),(Estado_Cr),(Estado_Ni),(Estado_Cu),(Estado_Pb),
                 (Estado_Sn),(Estado_Al),(Estado_Si),(Estado_Ca),(Estado_Zn),(Estado_Mg),
                 (Estado_K),(Estado_Na),(Estado_B),(Estado_P),(Estado_Mo),
                 (Estado_V100),(Estado_V40),(Estado_TAN),(Estado_TBN),
                 (Estado_Oxi),(Estado_Sulf),(Estado_Nit),
                 (Estado_Agua),(Estado_Hollin),(Estado_Diesel),
                 (Estado_ISO4),(Estado_ISO6),(Estado_ISO14)) e(est)
) k
WHERE rn_recencia = 1 AND CompTipo <> 'OTRO'
GROUP BY Proyecto, CompTipo
ORDER BY Proyecto, CompTipo;
GO

-- 156.2 ⭐ QUIEN APORTA LAS MARCAS. El ranking de culpables. Si uno o dos parametros explican
--   casi todo el salto, la conversacion con Carlos no es "ampliamos el triage" sino "revisemos
--   ESE limite". Sospechosos por la captura: Zn e ISO6 en TRACCION.
SELECT b.CompTipo, v.Parametro,
       SUM(CASE WHEN v.est = 'CRITICO'    THEN 1 ELSE 0 END) AS Criticos,
       SUM(CASE WHEN v.est = 'PRECAUCION' THEN 1 ELSE 0 END) AS Precauciones,
       COUNT(*)                                              AS Componentes
FROM [dbo].[vw_MuestrasEstado] b WITH (NOLOCK)
CROSS APPLY (VALUES
    (N'Fe',b.Estado_Fe),(N'PQ',b.Estado_PQ),(N'Cr',b.Estado_Cr),(N'Ni',b.Estado_Ni),
    (N'Cu',b.Estado_Cu),(N'Pb',b.Estado_Pb),(N'Sn',b.Estado_Sn),(N'Al',b.Estado_Al),
    (N'Si',b.Estado_Si),(N'Ca',b.Estado_Ca),(N'Zn',b.Estado_Zn),(N'Mg',b.Estado_Mg),
    (N'K',b.Estado_K),(N'Na',b.Estado_Na),(N'B',b.Estado_B),(N'P',b.Estado_P),(N'Mo',b.Estado_Mo),
    (N'V100',b.Estado_V100),(N'V40',b.Estado_V40),(N'TAN',b.Estado_TAN),(N'TBN',b.Estado_TBN),
    (N'Oxidacion',b.Estado_Oxi),(N'Sulfatacion',b.Estado_Sulf),(N'Nitracion',b.Estado_Nit),
    (N'Agua',b.Estado_Agua),(N'Hollin',b.Estado_Hollin),(N'Diesel',b.Estado_Diesel),
    (N'ISO4',b.Estado_ISO4),(N'ISO6',b.Estado_ISO6),(N'ISO14',b.Estado_ISO14)
) v(Parametro, est)
WHERE b.rn_recencia = 1 AND b.CompTipo <> 'OTRO' AND b.Proyecto LIKE '%Antapaccay%'
  AND v.est IN ('CRITICO','PRECAUCION')
GROUP BY b.CompTipo, v.Parametro
ORDER BY b.CompTipo, COUNT(*) DESC;
GO

-- 156.3 ⚠ EL SOSPECHOSO Nº1: el Zn en Motor de Traccion. Ahi el Zn NO es aditivo sino
--   CONTAMINANTE (alerta por arriba). La pregunta es si el LP esta bien puesto: si el 80% de la
--   flota lo pasa, o la flota entera esta contaminada o el limite esta mal. Esto NO lo decide el
--   SQL -- lo decide Carlos -- pero con la distribucion al lado la conversacion dura 2 minutos.
SELECT TOP 40 Equipo, Compartimiento, Modelo,
       CAST(Zn_ppm AS decimal(18,1)) AS Zn, Zn_LP, Zn_LC, Estado_Zn
FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK)
WHERE rn_recencia = 1 AND CompTipo = 'TRACCION' AND Proyecto LIKE '%Antapaccay%'
ORDER BY Zn_ppm DESC;
GO

-- 156.4 EL OTRO SOSPECHOSO: los codigos ISO. Mismo criterio.
SELECT TOP 40 Equipo, Compartimiento, ISO4, ISO6, ISO14,
       ISO4_LP, ISO6_LP, ISO14_LP, Estado_ISO4, Estado_ISO6, Estado_ISO14
FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK)
WHERE rn_recencia = 1 AND CompTipo = 'TRACCION' AND Proyecto LIKE '%Antapaccay%'
ORDER BY ISO6 DESC;
GO

/* COMO SE LEE EL 156.1, Y QUE SE HACE CON CADA RESULTADO:

   Nuevo/Total  hasta ~40%  -> La propuesta de Andres se implementa TAL CUAL: Estado_General pasa
                               a mirar todo, el triage imprime SOLO los observados (como /barrido)
                               y <modelo> filtra la flota. La tabla se acorta y las 11 columnas
                               caben: el problema de ancho del 155.7 se resuelve de paso.

   Nuevo/Total  40% a 60%   -> Igual, pero el orden de la tabla manda: criticos primero, luego
                               precauciones, y tope de filas con aviso de recorte.

   Nuevo/Total  mas de 60%  -> NO volver atras: SEPARAR LAS DOS PREGUNTAS. El triage nacio para
                               contestar "que se esta danando" (los 9 metales). Si "que esta
                               fuera de limite" marca a casi todos, son dos preguntas distintas y
                               necesitan dos indicadores, no uno. Opciones, en orden:
                                 a) Que solo los CRITICOS de las familias nuevas disparen el
                                    estado (la columna Nuevo_solo_criticos del 156.1 ya lo mide).
                                 b) Dos contadores en el encabezado: "6 danados · 48 con desvio".
                                 c) Revisar el limite del parametro que el 156.2 senale, si uno
                                    solo explica el salto.
*/

-- RESULTADOS BLOQUE 156 (29/09) -- la medicion valio la pena: la cifra cae en el tercer tramo
-- de la tabla de lectura, y ADEMAS descubre que la decision ya estaba tomada en el codigo.
--
-- 156.1 LA CIFRA. Hoy -> Nuevo (crudo), por proyecto x componente:
--   Antamina    HIDRAULICO  158 |  50 ->  62 (39,2%)     Antapaccay HIDRAULICO  48 |  5 ->  6 (12,5%)
--   Antamina    MOTOR       158 |   4 ->  19 (12,0%)     Antapaccay MANDO       26 |  1 ->  2 ( 7,7%)
--   Antamina    RUEDA       129 | 103 -> 122 (94,6%) ⚠   Antapaccay MOTOR       48 |  6 -> 17 (35,4%)
--   Antamina    TRACCION    388 |  77 -> 131 (33,8%)     Antapaccay RUEDA       72 |  6 -> 54 (75,0%) ⚠
--   Cerro Verde RUEDA        20 |  14 ->  15 (75,0%) ⚠   Antapaccay TRACCION    72 |  6 -> 50 (69,4%) ⚠
--   Cerro Verde TRACCION    128 |  16 ->  16 (12,5%)     Toromocho  RUEDA       18 | 18 -> 18 ( 100%) ⚠
--   Cuajone y Toquepala: 0 observados en todo (ninguna muestra reciente con marca).
--   Toromocho  TRACCION      20 |  20 ->  20 ( 100%) ⚠
--   ⇒ La prediccion se cumplio: Antapaccay TRACCION pasa de 6 a 50. Tramo ">60%" de la tabla de
--     lectura del 156 -> NO implementar la regla cruda.
--
-- 156.2 QUIEN APORTA LAS MARCAS (Antapaccay). Aqui esta todo:
--   RUEDA:    Na 54c · Mg 54c · Zn 54c · Ca 54c · P 34c/5p · ISO6 2c/8p · ISO4 1c/4p · Fe 1c/3p
--   TRACCION: ISO6 38c/10p · Zn 15c/2p · Ca 4c · P 3p · ISO14 3p · Fe 2c/1p · V100 2c · PQ/Cr/Pb 1
--   MOTOR:    Oxidacion 9c · Si 2c/1p · Al 2p · K 1c/1p · Cu 1c · PQ/Nitracion/Hollin/Sulfat. 1p
--   ⇒ CUATRO parametros con EXACTAMENTE 54 componentes criticos cada uno no son 216 hallazgos:
--     son UN defecto sistematico. Ver 157.2.
--
-- 156.3 EL Zn EN MT. Antapaccay 980E: Zn_LP=18 / Zn_LC=25, valores de 4,6 a 194,8 -> 17 marcados.
--   ⚠ Y el 930E tiene Zn_LP y Zn_LC en NULL: ese modelo NO tiene limites cargados, asi que sale
--     'OK' pase lo que pase (3115 con Zn=125,8 sale OK). Es el caso L5 otra vez, ahora en un
--     parametro suelto.
--
-- 156.4 EL HUECO DE LOS ISO. ⚠ ISO4_LP es NULL en TODAS las filas, con ISO4 entre 23 y 28.
--   ISO6_LP=19 e ISO14_LP=16 si estan. O sea: el canal de 4 um -- el que SIEMPRE sale mas sucio,
--   por definicion de la escala -- no tiene limite y calla; el de 6 um grita en 48 de 72.
--   Eso no describe la limpieza del aceite, describe una carga incompleta de [Eqpcare].[lc].
--   (Los 930E tampoco tienen ISO6_LP/ISO14_LP: mismo agujero que el Zn.)
--
-- 🔑 EL HALLAZGO QUE CAMBIA EL PLAN. Al revisar vw_FormatoParametro para contestar una pregunta
--   de Andres sobre las familias, aparecio que la decision ya estaba tomada:
--       "Inf = 1 -> parametro INFORMATIVO: se muestra pero no dispara estado. Se conserva el
--        criterio vigente (K, Na, B, y Ca/Zn/Mg cuando son CONTAMINANTES, o sea en TRACCION)."
--   El triage del BLOQUE 155 IGNORA esa bandera. Por eso el Zn sale marcado en media flota de MT.
--   Aplicando Inf a los numeros de arriba: en TRACCION se caen Zn (17) y Ca (4); en RUEDA se cae
--   Na (54). NO se caen Ca/Zn/Mg/P de RUEDA (ahi Inf=0, son aditivos de verdad) ni el ISO6.
--   ⇒ La politica de Carlos no necesita un matiz inventado: el matiz existe. Continua en BLOQUE 157.
--
-- ✅ DE PASO, RESPUESTA A LA PREGUNTA DE ANDRES: si, el formato respeta la variacion por
--   componente, y su memoria es mas completa que la de CLAUDE.md. Cabecera de vw_FormatoParametro:
--   "Solo 4 parametros cambian de grupo entre hojas -- Ca, Mg, Mo y Zn: Contaminacion en MT y
--   Aditivos en las otras tres". Los cuatro que nombro, Mo incluido. CLAUDE.md solo listaba
--   Ca/Zn/Mg: corregido el 29/09.


-- ==== BLOQUE 157 - La bandera 'Inf' YA existe, y dos bloques que huelen a limite ====
-- EL HALLAZGO DEL 156: la decision que ibamos a tomar desde cero YA ESTA TOMADA en el codigo.
--   vw_FormatoParametro tiene Inf: "Inf = 1 -> parametro INFORMATIVO: se muestra pero no dispara
--   estado. Se conserva el criterio vigente (K, Na, B, y Ca/Zn/Mg cuando son CONTAMINANTES, o sea
--   en TRACCION)". El triage que escribi en el BLOQUE 155 la IGNORA: por eso el Zn sale marcado
--   en media flota de MT, donde el area ya decidio que se muestre pero no cuente.
--   => La politica de Carlos ("fuera de limite = observado") no necesita un matiz inventado:
--      el matiz existe, se llama Inf, y solo hay que enchufarlo.
--
-- LO QUE EL 156 DEJO EN PIE, y que Inf NO explica:
--   (1) RUEDA: Ca, Zn y Mg criticos en 54 de 54 componentes de Antapaccay. Son aditivos con
--       limite INVERTIDO -> critico = POR DEBAJO del piso. Que 54 ruedas agoten TRES aditivos a
--       la vez no pasa. Y no es solo Antapaccay: Antamina 94,6% · Toromocho 100% · Cerro Verde
--       75%. Cuatro proyectos con el mismo patron = un limite escrito para otro aceite.
--   (2) TRACCION ISO6: 48 de 72 (38 criticos) con ISO6_LP = 19 y valores 21-26. Y en el 156.4 se
--       ve que ISO4_LP es NULL en TODAS las filas mientras el ISO4 vale 23-28: el canal de 4 um
--       -- el mas sucio siempre -- no tiene limite y calla, y el de 6 um grita. Eso no es una
--       lectura del aceite, es una carga incompleta en [Eqpcare].[lc].

-- 157.1 ⭐ LA CIFRA REAL: el 156.1 otra vez, pero RESPETANDO Inf.
--   Compara tres numeros por componente: hoy (9 metales), la regla nueva CRUDA (lo que medimos en
--   el 156) y la regla nueva CON Inf. La diferencia entre las dos ultimas es cuanto ruido mete
--   ignorar una bandera que ya existia.
SELECT b.Proyecto, b.CompTipo,
       COUNT(DISTINCT b.LaboratoryDataId)                                              AS Total,
       COUNT(DISTINCT CASE WHEN b.Estado_General <> 'OK' THEN b.LaboratoryDataId END)  AS Hoy,
       COUNT(DISTINCT CASE WHEN v.est IN ('CRITICO','PRECAUCION') THEN b.LaboratoryDataId END)
                                                                                       AS Nuevo_crudo,
       COUNT(DISTINCT CASE WHEN v.est IN ('CRITICO','PRECAUCION') AND f.Inf = 0 THEN b.LaboratoryDataId END)
                                                                                       AS Nuevo_con_Inf,
       CAST(100.0 * COUNT(DISTINCT CASE WHEN v.est IN ('CRITICO','PRECAUCION') AND f.Inf = 0 THEN b.LaboratoryDataId END)
            / NULLIF(COUNT(DISTINCT b.LaboratoryDataId),0) AS decimal(5,1))            AS PctConInf
FROM [dbo].[vw_MuestrasEstado] b WITH (NOLOCK)
CROSS APPLY (VALUES
    (N'Fe',b.Estado_Fe),(N'PQ',b.Estado_PQ),(N'Cr',b.Estado_Cr),(N'Ni',b.Estado_Ni),
    (N'Cu',b.Estado_Cu),(N'Pb',b.Estado_Pb),(N'Sn',b.Estado_Sn),(N'Al',b.Estado_Al),
    (N'Si',b.Estado_Si),(N'Ca',b.Estado_Ca),(N'Zn',b.Estado_Zn),(N'Mg',b.Estado_Mg),
    (N'K',b.Estado_K),(N'Na',b.Estado_Na),(N'B',b.Estado_B),(N'P',b.Estado_P),(N'Mo',b.Estado_Mo),
    (N'V100',b.Estado_V100),(N'V40',b.Estado_V40),(N'TAN',b.Estado_TAN),(N'TBN',b.Estado_TBN),
    (N'Oxidacion',b.Estado_Oxi),(N'Sulfatacion',b.Estado_Sulf),(N'Nitracion',b.Estado_Nit),
    (N'Agua',b.Estado_Agua),(N'Hollin',b.Estado_Hollin),(N'Diesel',b.Estado_Diesel),
    (N'ISO>4',b.Estado_ISO4),(N'ISO>6',b.Estado_ISO6),(N'ISO>14',b.Estado_ISO14)
) v(Parametro, est)
LEFT JOIN [dbo].[vw_FormatoParametro] f
       ON f.Parametro = v.Parametro AND f.CompTipo = b.CompTipo
WHERE b.rn_recencia = 1 AND b.CompTipo <> 'OTRO'
GROUP BY b.Proyecto, b.CompTipo
ORDER BY b.Proyecto, b.CompTipo;
GO

-- 157.2 ⭐ EL BLOQUE DE RUEDA, DESARMADO. Por proyecto y MODELO: cuantas ruedas, cuantas criticas
--   por aditivo, y el rango de valores contra el limite. Si el minimo y el maximo de la flota
--   caen los DOS por debajo del LC, el limite no separa nada: no distingue una rueda sana de una
--   gastada, porque las reprueba a todas.
SELECT Proyecto, Modelo,
       COUNT(*) AS Ruedas,
       MIN(Ca_LC) AS Ca_LC, CAST(MIN(Ca_ppm) AS decimal(18,1)) AS Ca_min, CAST(MAX(Ca_ppm) AS decimal(18,1)) AS Ca_max,
       MIN(Zn_LC) AS Zn_LC, CAST(MIN(Zn_ppm) AS decimal(18,1)) AS Zn_min, CAST(MAX(Zn_ppm) AS decimal(18,1)) AS Zn_max,
       MIN(Mg_LC) AS Mg_LC, CAST(MIN(Mg_ppm) AS decimal(18,1)) AS Mg_min, CAST(MAX(Mg_ppm) AS decimal(18,1)) AS Mg_max,
       SUM(CASE WHEN Estado_Ca='CRITICO' THEN 1 ELSE 0 END) AS Ca_crit,
       SUM(CASE WHEN Estado_Zn='CRITICO' THEN 1 ELSE 0 END) AS Zn_crit,
       SUM(CASE WHEN Estado_Mg='CRITICO' THEN 1 ELSE 0 END) AS Mg_crit
FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK)
WHERE rn_recencia = 1 AND CompTipo = 'RUEDA'
GROUP BY Proyecto, Modelo
ORDER BY Proyecto, Modelo;
GO

-- 157.3 ⭐ EL HUECO DE LOS ISO. Cuantos componentes TIENEN limite en cada canal, por proyecto x
--   componente. Si ISO4 sale con 0 limites cargados y ISO6 con todos, esta confirmado que el
--   problema es la carga de [Eqpcare].[lc] y no la limpieza del aceite.
SELECT Proyecto, CompTipo, COUNT(*) AS Componentes,
       SUM(CASE WHEN ISO4_LP  IS NOT NULL THEN 1 ELSE 0 END) AS ISO4_con_LP,
       SUM(CASE WHEN ISO6_LP  IS NOT NULL THEN 1 ELSE 0 END) AS ISO6_con_LP,
       SUM(CASE WHEN ISO14_LP IS NOT NULL THEN 1 ELSE 0 END) AS ISO14_con_LP,
       SUM(CASE WHEN Estado_ISO4  IN ('CRITICO','PRECAUCION') THEN 1 ELSE 0 END) AS ISO4_obs,
       SUM(CASE WHEN Estado_ISO6  IN ('CRITICO','PRECAUCION') THEN 1 ELSE 0 END) AS ISO6_obs,
       SUM(CASE WHEN Estado_ISO14 IN ('CRITICO','PRECAUCION') THEN 1 ELSE 0 END) AS ISO14_obs
FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK)
WHERE rn_recencia = 1 AND CompTipo <> 'OTRO'
GROUP BY Proyecto, CompTipo
ORDER BY Proyecto, CompTipo;
GO

-- 157.4 ⚠ AUDITORIA DE 'Disponible'. La cabecera de vw_FormatoParametro dice que V40, TAN,
--   Oxidacion, Sulfatacion, Nitracion, Mo, Agua, Hollin, Diesel, Refrigerante e ISO 4/6/14 "no
--   tienen fuente en [Oil].[LaboratoryData]" y por eso van con Disponible = 0. El BLOQUE D
--   (28/09) ENCONTRO 13 de esas columnas y las enchufo. La bandera quedo DESFASADA: por eso el
--   155.3 mostro Hollin(0.4) y Sulfatacion(3.2), y por eso el 156.2 conto 9 Oxidacion criticos en
--   MOTOR -- de un parametro que el formato sigue declarando inexistente.
--   Esto lista cuantos datos reales hay de cada uno. Todo lo que devuelva > 0 filas con dato
--   tiene que pasar a Disponible = 1.
SELECT 'V40' AS Parametro, COUNT(V40) AS ConDato, COUNT(*) AS Filas FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK) WHERE rn_recencia = 1
UNION ALL SELECT 'TAN',        COUNT(TAN),         COUNT(*) FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK) WHERE rn_recencia = 1
UNION ALL SELECT 'Oxidacion',  COUNT(Oxidacion),   COUNT(*) FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK) WHERE rn_recencia = 1
UNION ALL SELECT 'Sulfatacion',COUNT(Sulfatacion), COUNT(*) FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK) WHERE rn_recencia = 1
UNION ALL SELECT 'Nitracion',  COUNT(Nitracion),   COUNT(*) FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK) WHERE rn_recencia = 1
UNION ALL SELECT 'Mo',         COUNT(Mo_ppm),      COUNT(*) FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK) WHERE rn_recencia = 1
UNION ALL SELECT 'Agua',       COUNT(Agua),        COUNT(*) FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK) WHERE rn_recencia = 1
UNION ALL SELECT 'Hollin',     COUNT(Hollin),      COUNT(*) FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK) WHERE rn_recencia = 1
UNION ALL SELECT 'Diesel',     COUNT(Diesel),      COUNT(*) FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK) WHERE rn_recencia = 1
UNION ALL SELECT 'ISO4',       COUNT(ISO4),        COUNT(*) FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK) WHERE rn_recencia = 1
UNION ALL SELECT 'ISO6',       COUNT(ISO6),        COUNT(*) FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK) WHERE rn_recencia = 1
UNION ALL SELECT 'ISO14',      COUNT(ISO14),       COUNT(*) FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK) WHERE rn_recencia = 1;
GO

/* QUE SE DECIDE CON ESTO, Y EN QUE ORDEN:

   PRIMERO, y es gratis: enchufar Inf en el triage. No es un criterio nuevo -- es el que el area
   ya fijo. Un parametro con Inf = 1 se SIGUE MOSTRANDO en su columna (Andres quiere ver el
   valor) pero NO entra al contador. Eso cierra el bug E0 de raiz, sin pie de tabla que lo
   explique y sin pedirle nada a nadie.

   SEGUNDO, y es de Carlos, no nuestro: los dos bloques del 157.2 y 157.3.
     - Si el 157.2 muestra que el maximo de Ca/Zn/Mg de una flota entera esta por debajo del LC,
       ese limite no separa nada y hay que corregirlo en LIMITES CONDENATORIOS 1.xlsm. NO se
       parchea en SQL: el SQL esta leyendo bien un dato mal cargado.
     - Si el 157.3 confirma ISO4 sin limite y ISO6 con limite, es la misma historia en el otro
       extremo: falta carga, no sobra suciedad.

   TERCERO: con esos dos bloques resueltos, recien ahi la cifra de "cuantos quedan observados"
   es real y se puede elegir el formato del triage (solo observados + <modelo>). Elegirlo AHORA
   seria dimensionarlo con 54 falsos positivos dentro.

   ⛔ NO tocar Estado_General todavia. Mientras el limite de RUEDA este mal, ampliarlo convertiria
   un error de carga en 122 equipos "observados" en Antamina, y eso llega a gerencia como si
   fuera una crisis de flota.
*/
-- RESULTADOS BLOQUE 157 (29/09) -- 'Inf' ayuda menos de lo que esperaba, pero el 157.2 es
-- concluyente y CORRIGE una afirmacion mia sobre los ISO.
--
-- 157.1 'Inf' SOLO NO ALCANZA. Nuevo_crudo -> Nuevo_con_Inf:
--   Antamina TRACCION   131 -> 94 (24,2%)   ⭐ la mejora grande
--   Antamina MOTOR       19 -> 16           Toromocho MOTOR   4 -> 0
--   Antapaccay TRACCION  50 -> 48 (66,7%)   Antapaccay MOTOR 17 -> 15
--   Antapaccay RUEDA     54 -> 54  (SIN CAMBIO: ahi Ca/Zn/Mg son aditivos con Inf=0)
--   Antamina RUEDA      122 -> 122 (94,6%)  Toromocho RUEDA/TRACCION 18/20 -> 18/20 (100%)
--   ⇒ Inf limpia el ruido del Zn/Ca en MT (era real: -37 en Antamina) pero NO toca los dos
--     bloques grandes. Sigue siendo necesario, no suficiente.
--
-- 157.2 ⭐⭐ LA PRUEBA. RUEDA, Ca/Zn/Mg contra su LC, por proyecto y modelo:
--   Proyecto    Modelo  Ruedas  Ca_LC   Ca_min  Ca_max | Zn_LC  Zn_min Zn_max | crit
--   Antapaccay  980E      54    1560.0   154.2   228.7 | 720.0    0.0   15.2  | 54/54/54  ⛔
--   Cerro Verde 980E      16    1864.0  3496.0  3951.0 | 682.0 1080.0 1246.0  |  0/ 0/ 0
--   Toromocho   980E      18    1720.8  2470.0  3224.0 | 757.2   NULL   NULL  |  0/ 0/ 0
--   Toquepala   980E      22     NULL   2189.0  2752.0 |  NULL  1016.0 1244.0 |  0/ 0/ 0
--   Antamina    980E     128    2250.0     0.0  4264.2 | 661.0    0.0 1328.6  | 104/104/104 ⚠
--   ⛔ ANTAPACCAY: el MAXIMO de la flota entera (Ca 228,7) esta 6,8x POR DEBAJO del piso critico
--      (1560). En Zn: maximo 15,2 contra un piso de 720 -> 47x. Un limite que reprueba al 100% de
--      la flota, con el mejor equipo a un orden de magnitud del umbral, NO SEPARA NADA: no
--      distingue una rueda sana de una gastada porque las reprueba a todas.
--      Y el resto de proyectos corre Ca 2000-4000 en la misma posicion. Antapaccay reporta ~200.
--      Eso no es un aditivo agotado: es OTRO ACEITE, u otra base de reporte. El limite (1560) es
--      coherente con el aceite de los OTROS proyectos, no con el de Antapaccay.
--      ⇒ PREGUNTA PARA CARLOS: que aceite llevan las ruedas de Antapaccay. No se parchea en SQL:
--        el SQL esta leyendo bien un limite que no corresponde a ese aceite.
--   ⚠ ANTAMINA es OTRO problema, no el mismo: Ca_min = 0.0 y Ca_max = 4264 (mezcla). Ahi el
--      culpable son los CEROS -> ver 158.1.
--
-- 157.3 🔴 CORRECCION MIA. Dije que el ISO4 sin limite era "carga incompleta de lc". ES FALSO, y
--   el dato estaba en NUESTRO archivo: el BLOQUE 138.1 ya registro que en Antapaccay / MT / 980E
--   el Excel trae ISO 6um LP 19 / LC 20 e ISO 14um LP 16 / LC 19, y el ISO 4um viene NULL A
--   PROPOSITO, junto con Boro, Molibdeno, TAN, VISC40, H2O, Hollin y TBN. Asi define el area el MT.
--   ⇒ El 48 de 72 del ISO6 en Antapaccay MT es REAL, medido contra el limite del area.
--   ⚠ Y explica el reparto 38 criticos / 10 precauciones: con LP 19 y LC 20 la banda de
--     precaucion es de UN SOLO PUNTO, y en la escala ISO 4406 cada punto es el DOBLE de
--     particulas. No hay banda intermedia donde caer: o estas dentro, o estas critico.
--   ⚠ PERO queda una rareza que si hay que mirar: Antapaccay MT observa 48 de 54 con limite (89%)
--     mientras Cerro Verde MT observa 0 de 16 y Toromocho 0 de 20. O Antapaccay corre mucho mas
--     sucio, o sus limites son mas estrictos que los de los demas. Ver 158.3.
--
-- 157.4 'Disponible' ESTA DESFASADO EN LOS 12. Sobre 1 687 componentes recientes:
--   V40 1238 · TAN 184 · Oxidacion 1371 · Sulfatacion 1249 · Nitracion 1244 · Mo 1598
--   Agua 1364 · Hollin 1252 · Diesel 905 · ISO4 1177 · ISO6 1186 · ISO14 1187
--   Los doce tienen dato. Pero ⛔ NO basta con ponerlos en 1: el BLOQUE 142.2 ya concluyo que
--   'Disponible' NO PUEDE SER UNA CONSTANTE POR CompTipo porque DEPENDE DE LA MINA (Antapaccay
--   no mide V40 y si TAN; Antamina al reves). La bandera esta mal planteada, no solo desactualizada.
--   ⇒ Como NADIE la consume hoy (grep: solo se declara y se proyecta), la decision correcta es
--     dejarla documentada como NO USABLE y decidir por fila con la regla D5 (sin valor y sin
--     limite -> no sale), que es lo que el 142.2 ya habia resuelto. No inventar un tercer criterio.


-- ==== BLOQUE 158 - El cero bajo limite invertido, y por que Antapaccay MT sale tan sucio ====
-- 158.1 ⭐ EL BUG QUE INTRODUJE EN EL BLOQUE D. Estado_TBN lleva la guarda 'TBN > 0' en tres
--   sitios del DDL (lineas 713, 851, 881): un TBN de 0 significa NO MEDIDO, no 'base agotada'.
--   Los aditivos que agregue el 28/09 (Ca, Zn, Mg, P, B, Mo) NO llevan esa guarda. Bajo un limite
--   INVERTIDO un 0 es indistinguible de una catastrofe: 0 < LC siempre.
--   Esto cuenta cuantos criticos de RUEDA son exactamente eso.
SELECT Proyecto, Modelo, COUNT(*) AS Ruedas,
       SUM(CASE WHEN Ca_ppm = 0 THEN 1 ELSE 0 END) AS Ca_cero,
       SUM(CASE WHEN Zn_ppm = 0 THEN 1 ELSE 0 END) AS Zn_cero,
       SUM(CASE WHEN Mg_ppm = 0 THEN 1 ELSE 0 END) AS Mg_cero,
       SUM(CASE WHEN Estado_Ca = 'CRITICO' THEN 1 ELSE 0 END)                  AS Ca_crit_hoy,
       SUM(CASE WHEN Estado_Ca = 'CRITICO' AND Ca_ppm > 0 THEN 1 ELSE 0 END)   AS Ca_crit_con_guarda,
       SUM(CASE WHEN Estado_Zn = 'CRITICO' THEN 1 ELSE 0 END)                  AS Zn_crit_hoy,
       SUM(CASE WHEN Estado_Zn = 'CRITICO' AND Zn_ppm > 0 THEN 1 ELSE 0 END)   AS Zn_crit_con_guarda
FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK)
WHERE rn_recencia = 1 AND CompTipo IN ('RUEDA','HIDRAULICO','MOTOR','MANDO','TRANSMISION')
GROUP BY Proyecto, Modelo
HAVING SUM(CASE WHEN Estado_Ca = 'CRITICO' THEN 1 ELSE 0 END) > 0
    OR SUM(CASE WHEN Estado_Zn = 'CRITICO' THEN 1 ELSE 0 END) > 0
ORDER BY Proyecto, Modelo;
GO

-- 158.2 EL CERO, VISTO DE CERCA. Si un mismo equipo trae Ca = 0 y a la vez Fe y Si con valores
--   normales, el 0 no es quimica: es una columna que el laboratorio no reporto en esa muestra.
SELECT TOP 30 Equipo, Compartimiento, Modelo, FechaMuestreo,
       CAST(Ca_ppm AS decimal(18,1)) AS Ca, CAST(Zn_ppm AS decimal(18,1)) AS Zn,
       CAST(Mg_ppm AS decimal(18,1)) AS Mg, CAST(Fe_ppm AS decimal(18,1)) AS Fe,
       CAST(Si_ppm AS decimal(18,1)) AS Si, Grado
FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK)
WHERE rn_recencia = 1 AND CompTipo = 'RUEDA' AND Proyecto LIKE '%Antamina%'
  AND Ca_ppm = 0
ORDER BY Fe_ppm DESC;
GO

-- 158.3 ⭐ POR QUE ANTAPACCAY MT SALE AL 89% Y CERRO VERDE AL 0%. Los limites de ISO6 lado a
--   lado. Si los LP/LC son iguales entre proyectos, Antapaccay corre de verdad mas sucio y la
--   cifra es una noticia, no un defecto. Si son distintos, es la carga.
SELECT Proyecto, Modelo, CompTipo, COUNT(*) AS Componentes,
       MIN(ISO6_LP) AS ISO6_LP, MIN(ISO6_LC) AS ISO6_LC,
       MIN(ISO6) AS ISO6_min, MAX(ISO6) AS ISO6_max,
       CAST(AVG(ISO6) AS decimal(18,1)) AS ISO6_prom,
       SUM(CASE WHEN Estado_ISO6 IN ('CRITICO','PRECAUCION') THEN 1 ELSE 0 END) AS Obs
FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK)
WHERE rn_recencia = 1 AND CompTipo = 'TRACCION' AND ISO6 IS NOT NULL
GROUP BY Proyecto, Modelo, CompTipo
ORDER BY Proyecto, Modelo;
GO

-- 158.4 ⭐ LA PREGUNTA DE LAS RUEDAS DE ANTAPACCAY, EN UNA TABLA. Si el Grado del aceite es
--   distinto al de los otros proyectos, el misterio del 157.2 se resuelve solo: no es el aditivo
--   el que se agoto, es otro aceite con otro paquete.
SELECT Proyecto, Modelo, Grado, COUNT(*) AS Ruedas,
       CAST(AVG(Ca_ppm) AS decimal(18,1)) AS Ca_prom,
       CAST(AVG(Zn_ppm) AS decimal(18,1)) AS Zn_prom,
       CAST(AVG(Mg_ppm) AS decimal(18,1)) AS Mg_prom,
       MIN(Ca_LC) AS Ca_LC
FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK)
WHERE rn_recencia = 1 AND CompTipo = 'RUEDA'
GROUP BY Proyecto, Modelo, Grado
ORDER BY Proyecto, Modelo, Grado;
GO

/* LO QUE SALE DE AQUI:
   - 158.1/158.2 -> si los ceros explican Antamina, la cura es NUESTRA y es una linea por
     aditivo: la misma guarda '> 0' que Estado_TBN ya tiene. No es una decision del area.
   - 158.3 -> si los limites de ISO6 son iguales entre proyectos, el 89% de Antapaccay es un
     HALLAZGO que el area querra ver, no un defecto que tapar.
   - 158.4 -> si el Grado de las ruedas de Antapaccay es otro, el 157.2 queda explicado y la
     correccion va al archivo de limites, con nombre y apellido.
*/


-- RESULTADOS BLOQUE 158 (29/09) -- el 158.4 cierra la pregunta de las ruedas, y el 158.1 me
-- DESMIENTE en la causa que le habia atribuido a Antamina.
--
-- 158.4 ⭐⭐ LA RESPUESTA, Y ESTABA EN LA BD TODO EL TIEMPO. Grado del aceite de las ruedas:
--   Antamina    980E  Mobiltrans HD 60         125 ruedas   Ca 2823.5  Zn  860.3   (LC 2250)
--   Cerro Verde 980E  Mobiltrans HD 50          16 ruedas   Ca 3690.6  Zn 1172.2   (LC 1864)
--   Cerro Verde 730E  Mobiltrans HD 50           4 ruedas   Ca 3798.3  Zn 1190.8
--   Toromocho   980E  MOBILTRANS HD50           18 ruedas   Ca 2832.3  Zn   NULL   (LC 1720.8)
--   Antapaccay  980E  SHELL SPIRAX S5 CFD M 60  54 ruedas   Ca  189.1  Zn    3.9   (LC 1560) ⛔
--   ⇒ TODOS corren Mobiltrans HD. Antapaccay corre SHELL SPIRAX. No es el mismo producto ni la
--     misma quimica: Zn de 3,9 contra 860-1190 en el resto. El limite Ca_LC = 1560 se escribio
--     para un Mobiltrans, y esas ruedas no llevan Mobiltrans.
--     NO HAY NADA QUE ARREGLAR EN SQL: el limite hay que actualizarlo al aceite que de verdad
--     usan, en LIMITES CONDENATORIOS 1.xlsm. Con el Grado al lado, la correccion tiene nombre.
--   ⚠ De paso: Antapaccay 930E trae Grado = 'nan' LITERAL (la cadena, no NULL). Es el bug 'nan'
--     ya conocido, aqui en otra columna.
--
-- 158.1 🔴 ME DESMIENTE. Yo atribui el 104/128 de Antamina a los ceros. FALSO:
--   Antamina   980E  260 comp · Ca_cero 28 · Ca_crit_hoy 164 -> con_guarda 164  (NO MUEVE)
--   Antapaccay 980E  108 comp · Zn_cero  6 · Zn_crit_hoy  54 -> con_guarda  48  (-6)
--   ⇒ Los 28 ceros de Antamina no estaban contados como criticos (caen en componentes sin limite
--     de Ca). La guarda '> 0' corrige 6 casos reales en Antapaccay y NADA en Antamina.
--     La guarda SIGUE SIENDO CORRECTA -- un 0 no es una medicion, y Estado_TBN ya la tenia --
--     pero NO es la explicacion de Antamina. Eso queda abierto: ver 159.4.
--
-- 158.2 LOS CEROS, DE CERCA. Las filas de Antamina con Ca = 0 traen TAMBIEN Zn, Mg, Fe y Si en
--   0.0, con Grado 'Mobiltrans HD 60' y fechas de septiembre. No es una columna que falte: es la
--   MUESTRA ENTERA en cero. Un registro creado sin resultados de laboratorio.
--
-- 158.3 ⭐⭐ Y AQUI ESTA LO GRAVE, QUE NO ERA LO QUE BUSCABA. ISO6 en Motor de Traccion:
--   Proyecto    Modelo  ISO6_LP  ISO6_LC  min  max  prom   Obs
--   Antamina     930E    NULL     NULL      0   25  16.8     0
--   Antamina     980E    19.0     20.0      0   24  10.6    31
--   Antapaccay   930E    NULL     NULL     18   26  21.2     0
--   Antapaccay   980E    19.0     20.0     18   25  21.1    48
--   Cerro Verde  930E    NULL     NULL      0    0   0.0     0   ⛔
--   * LOS LIMITES SON IDENTICOS (19/20) entre Antamina 980E y Antapaccay 980E. Asi que la
--     diferencia NO es de criterio.
--   * PERO el promedio no se puede comparar: Antamina tiene min = 0 y Antapaccay min = 18. Los
--     ceros de Antamina HUNDEN su promedio a 10,6. Su distribucion real esta mucho mas arriba.
--   * ⛔ Cerro Verde 930E: min 0, max 0, prom 0,0 en los tres canales. Figuraba con "0
--     observados" y yo lo lei como flota limpia. NO ESTA LIMPIA: NO ESTA MEDIDA.
--   ⇒ ESTE es el hallazgo de la ronda. Bajo un limite NORMAL el 0 no fabrica un falso positivo:
--     fabrica un FALSO NEGATIVO, y encima invisible. Un componente sin medir se lee igual que uno
--     impecable. Es el modo de fallo silencioso de la ley 5, en una variante nueva.


-- ==== BLOQUE 159 - G0 desplegado: el 0 no es una medicion ====
-- QUE CAMBIO en vw_MuestrasEstado (9 guardas, todas marcadas /* G0 */ en el DDL):
--   (A) Los 6 aditivos (Ca, Zn, Mg, B, P, Mo) devuelven 'SIN DATO' cuando el valor es 0 Y el
--       limite esta INVERTIDO. Solo en ese ramo: para un CONTAMINANTE un 0 es una lectura valida
--       ("no hay contaminacion") y ahi no se toca nada.
--   (B) Los 3 canales ISO devuelven 'SIN DATO' cuando el codigo es 0. Un codigo ISO 4406 de 0 es
--       fisicamente imposible (<=0,01 particulas/ml): es la marca de "no reportado".
-- Estado_General NO se toco.

-- 159.1 ⭐ EL EFECTO EN LOS ADITIVOS. Contra el 158.1: Antapaccay debe bajar de 54 a 48 criticos
--   de Zn; Antamina no se mueve (sus ceros caian en componentes sin limite).
SELECT Proyecto, Modelo, COUNT(*) AS Componentes,
       SUM(CASE WHEN Estado_Ca = 'CRITICO'  THEN 1 ELSE 0 END) AS Ca_crit,
       SUM(CASE WHEN Estado_Zn = 'CRITICO'  THEN 1 ELSE 0 END) AS Zn_crit,
       SUM(CASE WHEN Estado_Mg = 'CRITICO'  THEN 1 ELSE 0 END) AS Mg_crit,
       SUM(CASE WHEN Estado_Ca = 'SIN DATO' THEN 1 ELSE 0 END) AS Ca_sindato,
       SUM(CASE WHEN Estado_Zn = 'SIN DATO' THEN 1 ELSE 0 END) AS Zn_sindato
FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK)
WHERE rn_recencia = 1 AND CompTipo IN ('RUEDA','HIDRAULICO','MOTOR','MANDO','TRANSMISION')
GROUP BY Proyecto, Modelo
ORDER BY Proyecto, Modelo;
GO

-- 159.2 ⭐⭐ EL EFECTO EN LOS ISO, QUE ES EL QUE IMPORTA. 'ISO6_cero_antes' son los componentes
--   que hasta hoy salian OK sin haberse medido. Cerro Verde 930E MT deberia pasar de "todo OK" a
--   "todo SIN DATO": el 158.3 mostro min=0 y max=0.
SELECT Proyecto, CompTipo, COUNT(*) AS Componentes,
       SUM(CASE WHEN ISO6 = 0 THEN 1 ELSE 0 END)                AS ISO6_cero,
       SUM(CASE WHEN Estado_ISO6 = 'SIN DATO' THEN 1 ELSE 0 END) AS ISO6_sindato,
       SUM(CASE WHEN Estado_ISO6 = 'OK' THEN 1 ELSE 0 END)       AS ISO6_ok,
       SUM(CASE WHEN Estado_ISO6 IN ('CRITICO','PRECAUCION') THEN 1 ELSE 0 END) AS ISO6_obs
FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK)
WHERE rn_recencia = 1 AND CompTipo <> 'OTRO'
GROUP BY Proyecto, CompTipo
ORDER BY Proyecto, CompTipo;
GO

-- 159.3 NO REGRESION. Estado_General no mira ninguno de los 9 parametros tocados, asi que el
--   triage tiene que dar EXACTAMENTE lo mismo: Antapaccay TRACCION "6 de 54 observados
--   (3 criticos)". Si se movio, algo se rompio en otra parte.
SELECT LEFT(MD, 120) AS Cabecera
FROM [dbo].[vw_TriageMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%todos%' AND CompTipo = 'TRACCION';
GO

-- 159.4 ⭐ LO QUE SIGUE SIN EXPLICACION. Antamina RUEDA 980E: 104 de 128 criticos de Ca, con un
--   promedio de flota (2823,5) que esta POR ENCIMA del piso critico (2250). Un promedio arriba y
--   el 81% abajo solo pasa si la distribucion tiene dos grupos. Esto los separa.
SELECT Grado,
       CASE WHEN Ca_ppm IS NULL THEN 'sin dato'
            WHEN Ca_ppm = 0     THEN '0 (no medido)'
            WHEN Ca_ppm < 1000  THEN '1 - 999'
            WHEN Ca_ppm < 2250  THEN '1000 - 2249 (bajo el LC)'
            WHEN Ca_ppm < 3000  THEN '2250 - 2999'
            ELSE '3000 o mas' END AS Banda,
       COUNT(*) AS Ruedas,
       CAST(MIN(Ca_ppm) AS decimal(18,1)) AS Ca_min,
       CAST(MAX(Ca_ppm) AS decimal(18,1)) AS Ca_max
FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK)
WHERE rn_recencia = 1 AND CompTipo = 'RUEDA' AND Proyecto LIKE '%Antamina%'
GROUP BY Grado,
       CASE WHEN Ca_ppm IS NULL THEN 'sin dato'
            WHEN Ca_ppm = 0     THEN '0 (no medido)'
            WHEN Ca_ppm < 1000  THEN '1 - 999'
            WHEN Ca_ppm < 2250  THEN '1000 - 2249 (bajo el LC)'
            WHEN Ca_ppm < 3000  THEN '2250 - 2999'
            ELSE '3000 o mas' END
ORDER BY Grado, Banda;
GO

-- 159.5 SMOKE TEST OBLIGATORIO (ley 5: un CREATE VIEW con columnas invalidas SE GUARDA y revienta
--   recien al consultarla). Todas las vistas que cuelgan de vw_MuestrasEstado.
SELECT TOP 1 'MuestrasEstado' AS Vista, Equipo FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK) WHERE rn_recencia = 1;
SELECT TOP 1 'TriageMD'       AS Vista, LEFT(MD,60) AS x FROM [dbo].[vw_TriageMD]       WITH (NOLOCK);
SELECT TOP 1 'DiagnosticoMD'  AS Vista, LEFT(MD,60) AS x FROM [dbo].[vw_DiagnosticoMD]  WITH (NOLOCK);
-- 🔴 AQUI ESCRIBI MAL EL NOMBRE (no existe vw_CondicionMTMD, es vw_CondicionMT_MD) y el lote
--    SE CORTO: las dos lineas de abajo nunca corrieron. Smoke test completo en el 160.5.
SELECT TOP 1 'CondicionMT_MD' AS Vista, LEFT(MD,60) AS x FROM [dbo].[vw_CondicionMT_MD] WITH (NOLOCK);
SELECT TOP 1 'UltimoAnalisisMD' AS Vista, LEFT(MD,60) AS x FROM [dbo].[vw_UltimoAnalisisMD] WITH (NOLOCK);
SELECT TOP 1 'ObservadosBarridoMD' AS Vista, LEFT(MD,60) AS x FROM [dbo].[vw_ObservadosBarridoMD] WITH (NOLOCK);
GO

/* ⚠ LO QUE G0 NO ARREGLA, Y NO DEBE PARECER QUE ARREGLA:
   - Las ruedas de Antapaccay (157.2 / 158.4) son un LIMITE que no corresponde al aceite. G0 no
     las toca y no debe tocarlas: esos valores (Ca 154-228) son mediciones REALES de un Shell
     Spirax. El arreglo va al archivo de limites, no al SQL.
   - Antamina RUEDA sigue sin explicacion (159.4).
   - Un componente que pasa a 'SIN DATO' NO es una buena noticia: significa que llevamos tiempo
     dandolo por limpio sin medirlo. Si el 159.2 devuelve numeros grandes, eso es un dato para
     Carlos tanto como los limites. */


-- RESULTADOS BLOQUE 159 (29/09) -- G0 hizo exactamente lo medido, el 159.2 da la cifra del fallo
-- silencioso, y el 159.4 RESUELVE Antamina: era un bug mio, y estaba advertido en este archivo.
--
-- 159.1 ✅ G0 EN LOS ADITIVOS, CLAVADO A LA PREDICCION:
--   Antapaccay 980E  Zn_crit 54 -> 48 (los 6 ceros)  ·  Mg_crit 54 -> 41 (los 13 ceros)
--                    Ca_crit 54 -> 54 (no tenia ceros)
--   Antamina   980E  164/166/166 SIN MOVERSE, tal cual dije: sus ceros caian en componentes sin
--                    limite de Ca. Ningun otro proyecto tiene criticos de aditivo.
--   ⚠ Antapaccay 930E: 18 de 36 en 'SIN DATO' de Ca y Zn -- ese modelo no trae ni valores ni
--     limites. Es el hueco de siempre del 930E, ahora visible en vez de disfrazado de OK.
--
-- 159.2 ⭐⭐ LA CIFRA DEL FALLO SILENCIOSO. Componentes con ISO6 = 0, que hasta hoy salian 'OK':
--   Antamina MOTOR     158 de 158 (!)    Antamina TRACCION  92 de 388
--   Antamina RUEDA      65 de 129        Antamina HIDRAULICO 28 de 158
--   Cerro Verde          3 · Antapaccay   1
--   ⇒ 347 COMPONENTES venian leyendose como "codigo de limpieza dentro de limite" SIN UNA SOLA
--     MEDICION. Los 158 motores de Antamina al completo. No es que estuvieran limpios: es que
--     nadie los midio, y el 0 los hacia indistinguibles de los limpios de verdad.
--   ⚠ Esto NO es una victoria de G0: es la cuenta de lo que llevabamos tiempo dando por bueno.
--     Va a Carlos igual que los limites.
--   (El resto de 'SIN DATO' del 159.2 son NULL, que ya se trataban bien: Cerro Verde TRACCION
--    tiene 128 sin dato de los cuales solo 2 eran ceros -- los otros 126 nunca tuvieron valor.)
--
-- 159.3 ✅ SIN REGRESION. "6 de 54 observados (3 criticos)", identico. Estado_General no se toco.
--
-- 159.4 ⭐⭐ ANTAMINA RESUELTO, Y ERA UN BUG MIO. Distribucion del Ca en las ruedas de Antamina:
--   Mobiltrans HD 60 · 3000 o mas      102 ruedas   Ca 3 006,2 - 4 264,2
--   Mobiltrans HD 60 · 0 (no medido)    23 ruedas
--   Mobiltrans HD 60 · 1 - 999           1 rueda    Ca 47,9
--   Mobiltrans HD 30 · 3000 o mas        1 · HD 30 · 0 (no medido) 1 · NULL · 3000 o mas 1
--   ⛔ 102 ruedas ENTRE 3 006 Y 4 264 ppm contra un LC de 2 250, y salian CRITICAS. Solo hay una
--      forma de que eso pase: el CASE cayendo al ramo de CONTAMINANTE y reprobandolas por tener
--      DEMASIADO calcio. En una rueda el Ca es un ADITIVO y 3 000 ppm es lo normal -- Cerro Verde
--      corre 3 690, Toromocho 2 832, y ninguno sale critico porque ahi el par LP/LC SI viene
--      invertido. 164 falsos criticos de un solo parametro.
--   🔴 Y ESTABA ADVERTIDO EN ESTE MISMO ARCHIVO. La cabecera de vw_FormatoParametro, con el
--      BLOQUE 104 detras: "Inv = 1 -> limite INVERTIDO. Se deduce del GRUPO, no del dato.
--      ⛔ NO derivarlo de 'LP > LC' aunque el dato lo respalde en general -- el archivo de gerencia
--      trae un typo y el bucket 'OTRO' produce inversiones artificiales al colapsar componentes
--      distintos con MIN()." En el bloque D escribi exactamente lo que ese aviso prohibe.
--
-- 159.5 🔴 MI SMOKE TEST ESTABA MAL ESCRITO. 'dbo.vw_CondicionMTMD' no existe: es
--   vw_CondicionMT_MD. Y lo grave no es el Msg 208 -- es que el lote SE CORTO AHI, asi que
--   vw_UltimoAnalisisMD y vw_BarridoMD NUNCA SE PROBARON. Un smoke test incompleto se lee como
--   aprobado. Corregido y completado en el 160.5.


-- ==== BLOQUE 160 - G1: la inversion se deduce del GRUPO, no del dato ====
-- QUE CAMBIO: nueva vista vw_InvPorComponente (7 filas, el Inv del formato pivotado) + UN LEFT
--   JOIN en vw_MuestrasEstado + los 6 CASE de aditivos pasan de 'lim.X_LP > lim.X_LC' a
--   'inv.X_Inv = 1'. La direccion es una propiedad del GRUPO, no del par de numeros cargado.
-- Estado_General NO se toco. G0 (las 9 guardas del 0) se mantiene.

-- 160.1 ⭐ LA EVIDENCIA, PARA QUE QUEDE ESCRITA. Como viene el par LP/LC de cada proyecto y que
--   dice el formato. Donde 'Par_invertido' = 0 y 'Formato_Inv' = 1, ahi estaba el falso critico.
SELECT b.Proyecto, b.CompTipo, COUNT(*) AS Componentes,
       MIN(b.Ca_LP) AS Ca_LP, MIN(b.Ca_LC) AS Ca_LC,
       MAX(CASE WHEN b.Ca_LP > b.Ca_LC THEN 1 ELSE 0 END) AS Par_invertido,
       MAX(i.Ca_Inv)                                      AS Formato_Inv
FROM [dbo].[vw_MuestrasEstado] b WITH (NOLOCK)
LEFT JOIN [dbo].[vw_InvPorComponente] i ON i.CompTipo = b.CompTipo
WHERE b.rn_recencia = 1 AND b.CompTipo = 'RUEDA' AND b.Ca_LC IS NOT NULL
GROUP BY b.Proyecto, b.CompTipo
ORDER BY b.Proyecto;
GO

-- 160.2 ⭐ EL EFECTO. Contra el 159.1: Antamina 980E debe pasar de 164/166/166 a CERO o casi.
--   Antapaccay 980E NO debe moverse de 54/48/41 -- ese si es real: es el Shell Spirax (158.4).
SELECT Proyecto, Modelo, COUNT(*) AS Componentes,
       SUM(CASE WHEN Estado_Ca = 'CRITICO' THEN 1 ELSE 0 END) AS Ca_crit,
       SUM(CASE WHEN Estado_Zn = 'CRITICO' THEN 1 ELSE 0 END) AS Zn_crit,
       SUM(CASE WHEN Estado_Mg = 'CRITICO' THEN 1 ELSE 0 END) AS Mg_crit
FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK)
WHERE rn_recencia = 1 AND CompTipo IN ('RUEDA','HIDRAULICO','MOTOR','MANDO','TRANSMISION')
GROUP BY Proyecto, Modelo
ORDER BY Proyecto, Modelo;
GO

-- 160.3 ⚠ LA OTRA DIRECCION, QUE NO SE PUEDE ROMPER. En MOTOR DE TRACCION el Ca/Zn/Mg son
--   CONTAMINANTES (Inv = 0): la alerta es por ARRIBA. El CA3165 con Zn 194,8 contra LC 25 tiene
--   que SEGUIR saliendo critico. Si G1 lo apago, invertimos el error en vez de arreglarlo.
SELECT TOP 15 Equipo, Compartimiento, Modelo,
       CAST(Zn_ppm AS decimal(18,1)) AS Zn, Zn_LP, Zn_LC, Estado_Zn
FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK)
WHERE rn_recencia = 1 AND CompTipo = 'TRACCION' AND Proyecto LIKE '%Antapaccay%'
ORDER BY Zn_ppm DESC;
GO

-- 160.4 COBERTURA DEL JOIN. Si algun CompTipo real no tiene fila en vw_InvPorComponente, su Inv
--   llega NULL, 'inv.X_Inv = 1' da falso y el aditivo se juzga como contaminante EN SILENCIO
--   (ley 5, modo A). Esto tiene que devolver CERO filas.
SELECT DISTINCT b.CompTipo
FROM [dbo].[vw_MuestrasEstado] b WITH (NOLOCK)
LEFT JOIN [dbo].[vw_InvPorComponente] i ON i.CompTipo = b.CompTipo
WHERE b.rn_recencia = 1 AND i.CompTipo IS NULL;
GO

-- 160.5 SMOKE TEST COMPLETO Y CON LOS NOMBRES BIEN (el del 159.5 se corto en la 4a linea y dejo
--   dos vistas sin probar). Cada SELECT va suelto a proposito: si uno falla, los demas corren.
SELECT TOP 1 'MuestrasEstado'   AS Vista, Equipo        AS x FROM [dbo].[vw_MuestrasEstado]   WITH (NOLOCK) WHERE rn_recencia = 1;
SELECT TOP 1 'InvPorComponente' AS Vista, CompTipo      AS x FROM [dbo].[vw_InvPorComponente] WITH (NOLOCK);
SELECT TOP 1 'TriageMD'         AS Vista, LEFT(MD,60)   AS x FROM [dbo].[vw_TriageMD]         WITH (NOLOCK);
SELECT TOP 1 'DiagnosticoMD'    AS Vista, LEFT(MD,60)   AS x FROM [dbo].[vw_DiagnosticoMD]    WITH (NOLOCK);
SELECT TOP 1 'CondicionMT_MD'   AS Vista, LEFT(MD,60)   AS x FROM [dbo].[vw_CondicionMT_MD]   WITH (NOLOCK);
SELECT TOP 1 'CondicionCompMD'  AS Vista, LEFT(MD,60)   AS x FROM [dbo].[vw_CondicionCompMD]  WITH (NOLOCK);
SELECT TOP 1 'UltimoAnalisisMD' AS Vista, LEFT(MD,60)   AS x FROM [dbo].[vw_UltimoAnalisisMD] WITH (NOLOCK);
SELECT TOP 1 'ObservadosBarridoMD' AS Vista, LEFT(MD,60) AS x FROM [dbo].[vw_ObservadosBarridoMD] WITH (NOLOCK);
SELECT TOP 1 'ObservadosResumenMD' AS Vista, LEFT(MD,60) AS x FROM [dbo].[vw_ObservadosResumenMD] WITH (NOLOCK);
SELECT TOP 1 'TendenciaMD'      AS Vista, LEFT(MD,60)   AS x FROM [dbo].[vw_TendenciaMD]      WITH (NOLOCK);
SELECT TOP 1 'HistorialMD'      AS Vista, LEFT(MD,60)   AS x FROM [dbo].[vw_HistorialMD]      WITH (NOLOCK);
SELECT TOP 1 'RankingMD'        AS Vista, LEFT(HeaderMD,60) AS x FROM [dbo].[vw_RankingMD]   WITH (NOLOCK);  -- contrato *FilasMD: HeaderMD, no MD
GO

-- 160.6 NO REGRESION DEL TRIAGE. Estado_General sigue sin mirar ninguno de estos parametros:
--   "6 de 54 observados (3 criticos)".
SELECT LEFT(MD, 120) AS Cabecera
FROM [dbo].[vw_TriageMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%todos%' AND CompTipo = 'TRACCION';
GO

-- RESULTADOS BLOQUE 160 (29/09) -- G1 CONFIRMADO en los cuatro controles. Y el 160.1 muestra que
-- el mecanismo era todavia mas tonto de lo que supuse.
--
-- 160.1 ⭐⭐ LA EVIDENCIA. Como viene el par LP/LC del Ca en RUEDA:
--   Proyecto     Comp   Ca_LP     Ca_LC    Par_invertido   Formato_Inv
--   Antamina     RUEDA  NULL      2250.00        0              1      ⛔
--   Antapaccay   RUEDA  2080.00   1560.00        1              1
--   Cerro Verde  RUEDA  2486.00   1864.00        1              1
--   Toromocho    RUEDA  2294.40   1720.80        1              1
--   ⛔ EL Ca_LP DE ANTAMINA ES NULL. No era un typo ni una inversion artificial: era un LP que no
--      se cargo. Y 'NULL > 2250' no da falso, da NULL -> el CASE cae al ELSE y el aditivo se
--      juzga como contaminante. Deducir la direccion del dato no sobrevive a un NULL, y eso es
--      exactamente por lo que el formato manda deducirla del GRUPO.
--
-- 160.2 ✅ EL EFECTO, CLAVADO. Antamina 980E: 164/166/166 -> 1/1/0. Antapaccay 980E se queda en
--   54/48/41, que es lo correcto: ese SI es real, es el Shell Spirax del 158.4. Ningun otro
--   proyecto tiene criticos de aditivo. 164 falsos criticos eliminados de un parametro.
--
-- 160.3 ✅ LA OTRA DIRECCION AGUANTA. CA3165 (Zn 194,8 contra LP 18 / LC 25) sigue CRITICO, y los
--   930E con limites NULL siguen OK. G1 no invirtio el error: en MT el Ca/Zn/Mg siguen siendo
--   contaminantes y alertan por arriba.
--
-- 160.4 ✅ CERO FILAS. Ningun CompTipo se queda sin fila en vw_InvPorComponente, asi que no hay
--   ningun aditivo juzgandose como contaminante en silencio.
--
-- 160.6 ✅ SIN REGRESION. "6 de 54 observados (3 criticos)".
--
-- 160.5 🔴 Y OTRA VEZ EL SMOKE TEST, CON DOS ERRORES MIOS MAS:
--   * 'vw_BarridoMD' NO EXISTE. Las vistas de barrido son vw_ObservadosBarridoMD y
--     vw_ObservadosResumenMD. Me lo invente por segunda vez.
--   * 'LEFT(MD,60) FROM vw_RankingMD' -> Msg 207: vw_RankingMD sigue el contrato *FilasMD y
--     expone HeaderMD + Fila, NO una columna MD.
--   ⇒ Van DOS RONDAS seguidas escribiendo mal los nombres, asi que la cura no es volver a
--     escribirlos con mas cuidado: es que el verificador los compruebe. tools/check_ddl.py ahora
--     lee VALIDACION_SSMS.sql y delata (a) toda vista que no exista en el DDL y (b) toda peticion
--     de la columna MD a una vista que no la proyecta. Probado en negativo: muerde con los dos.
--   ⚠ Afinado para NO gritar en falso: ignora los comentarios, y si la sentencia se define su
--     propio 'AS MD' (una subconsulta que arma el MD y la de fuera lo mide) no la delata. Ese
--     falso positivo me hizo "corregir" el BLOQUE 152.1, que era correcto, y romperlo. Revertido.
--     Un control que grita en falso se termina ignorando, y entonces no sirve para nada.

/* ⚑ SI EL 160.2 NO BAJA ANTAMINA A CERO, G1 NO ES LA CAUSA Y HAY QUE REVERTIRLO (git), no
   insistir. La hipotesis es fuerte pero es una hipotesis: 102 ruedas entre 3 006 y 4 264 contra
   un LC de 2 250 solo se explican por el ramo de contaminante, y el formato dice que ahi el Ca es
   aditivo. Si el numero no se mueve, me equivoque en donde. */


-- RESULTADOS BLOQUE 160.5 (29/09) -- el smoke test corrio COMPLETO por primera vez, las 11 vistas,
-- y encontro algo. Para eso sirve.
--   ✅ MuestrasEstado (HT303) · InvPorComponente (HIDRAULICO) · TriageMD · DiagnosticoMD ·
--      CondicionMT_MD · CondicionCompMD · UltimoAnalisisMD · ObservadosBarridoMD ·
--      ObservadosResumenMD · TendenciaMD · RankingMD (HeaderMD).
--   ⛔ HistorialMD devolvio NULL. El MD entero, nulo.


-- ==== BLOQUE 161 - G2: compAbbr nunca puede salir NULL ====
-- LA CAUSA (modo A de la ley 5): en SQL Server UN SOLO OPERANDO NULL ANULA TODA LA CONCATENACION.
--   compAbbr se calculaba con un CASE cuyo ELSE devolvia Compartimiento tal cual, y Compartimiento
--   PUEDE ser NULL (el bug 'nan' ya conocido). Una fila asi forma su propio grupo en el GROUP BY,
--   MAX(compAbbr) da NULL, y la vista entera devuelve MD = NULL -> el tema imprime "no encontre
--   datos" y nadie sabe por que. Es el fallo silencioso perfecto: no hay error, hay vacio.
-- LA CURA: ISNULL(Compartimiento, N'(sin componente)') en los 19 sitios donde se calcula compAbbr.
--   La fila pasa a VERSE, etiquetada, en vez de tumbar el mensaje.
-- ⚑ POR QUE SOLO ESTE Y NO LOS 22. Una auditoria de las 24 vistas que arman MD encontro operandos
--   sin ISNULL en 22 de ellas, pero casi todos son claves de GROUP BY o STRING_AGG sobre grupos
--   con filas: no pueden ser NULL. Poner 22 ISNULL a ciegas es ruido que tapa el que si importa.
--   Se corrige el que tiene evidencia -- compAbbr -- y el 161.1 mide si queda alguno mas.

-- 161.1 ⭐ LA RAIZ. Cuantas muestras recientes traen Compartimiento NULL, y de que equipos.
--   Estas son las que tumbaban el MD.
SELECT Proyecto, COUNT(*) AS Muestras, COUNT(DISTINCT Equipo) AS Equipos,
       MIN(FechaMuestreo) AS Desde, MAX(FechaMuestreo) AS Hasta
FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK)
WHERE Compartimiento IS NULL
GROUP BY Proyecto
ORDER BY COUNT(*) DESC;
GO

-- 161.2 ⭐ QUE LA CURA FUNCIONE. HistorialMD ya no puede devolver NULL. Antes: 'HistorialMD NULL'.
SELECT TOP 5 Equipo, compAbbr, LEFT(MD, 70) AS Inicio
FROM [dbo].[vw_HistorialMD] WITH (NOLOCK)
WHERE compAbbr = N'(sin componente)';
GO

-- 161.3 ⚠ Y QUE NO QUEDE NINGUNA OTRA CON MD NULL.
-- 🔴 LA PRIMERA VERSION DE ESTE BLOQUE TARDO 11 MINUTOS, y es culpa mia: filtraba por
--    'compAbbr = N''(sin componente)''. compAbbr es una COLUMNA CALCULADA (un CASE), asi que el
--    predicado NO BAJA: SQL Server tiene que materializar la vista *MD ENTERA -- armar el markdown
--    de todos los equipos y componentes -- y recien despues filtrar. Es la ley 3 otra vez, ahora en
--    una consulta de prueba en vez de en una vista.
--    ⇒ REGLA: una vista *MD se filtra SIEMPRE por columna REAL (Equipo, Proyecto, Compartimiento,
--      CompTipo). Nunca por compAbbr ni por nada derivado de un CASE.
--    El 161.4, que hace TOP 1 sobre las mismas vistas, tarda 2 segundos: el TOP corta el render.
-- Los 5 equipos salen del 161.2. Filtrando por Equipo el predicado SI baja.
SELECT 'HistorialMD' AS Vista, COUNT(*) AS Filas, SUM(CASE WHEN MD IS NULL THEN 1 ELSE 0 END) AS MD_nulos
FROM [dbo].[vw_HistorialMD] WITH (NOLOCK)
WHERE Equipo IN (N'3104', N'3105', N'CA3164', N'HT338', N'K-301')
UNION ALL
SELECT 'UltimoAnalisisMD', COUNT(*), SUM(CASE WHEN MD IS NULL THEN 1 ELSE 0 END)
FROM [dbo].[vw_UltimoAnalisisMD] WITH (NOLOCK)
WHERE Equipo IN (N'3104', N'3105', N'CA3164', N'HT338', N'K-301')
UNION ALL
SELECT 'TriageMD', COUNT(*), SUM(CASE WHEN MD IS NULL THEN 1 ELSE 0 END)
FROM [dbo].[vw_TriageMD] WITH (NOLOCK) WHERE Proyecto LIKE '%Antapaccay%' AND CompTipo = 'TRACCION';
GO

-- 161.4 SMOKE TEST otra vez -- la misma lista del 160.5. Ninguna puede volver NULL.
SELECT TOP 1 'MuestrasEstado'   AS Vista, Equipo        AS x FROM [dbo].[vw_MuestrasEstado]   WITH (NOLOCK) WHERE rn_recencia = 1;
SELECT TOP 1 'InvPorComponente' AS Vista, CompTipo      AS x FROM [dbo].[vw_InvPorComponente] WITH (NOLOCK);
SELECT TOP 1 'TriageMD'         AS Vista, LEFT(MD,60)   AS x FROM [dbo].[vw_TriageMD]         WITH (NOLOCK);
SELECT TOP 1 'DiagnosticoMD'    AS Vista, LEFT(MD,60)   AS x FROM [dbo].[vw_DiagnosticoMD]    WITH (NOLOCK);
SELECT TOP 1 'CondicionMT_MD'   AS Vista, LEFT(MD,60)   AS x FROM [dbo].[vw_CondicionMT_MD]   WITH (NOLOCK);
SELECT TOP 1 'CondicionCompMD'  AS Vista, LEFT(MD,60)   AS x FROM [dbo].[vw_CondicionCompMD]  WITH (NOLOCK);
SELECT TOP 1 'UltimoAnalisisMD' AS Vista, LEFT(MD,60)   AS x FROM [dbo].[vw_UltimoAnalisisMD] WITH (NOLOCK);
SELECT TOP 1 'ObservadosBarridoMD' AS Vista, LEFT(MD,60) AS x FROM [dbo].[vw_ObservadosBarridoMD] WITH (NOLOCK);
SELECT TOP 1 'ObservadosResumenMD' AS Vista, LEFT(MD,60) AS x FROM [dbo].[vw_ObservadosResumenMD] WITH (NOLOCK);
SELECT TOP 1 'TendenciaMD'      AS Vista, LEFT(MD,60)   AS x FROM [dbo].[vw_TendenciaMD]      WITH (NOLOCK);
SELECT TOP 1 'HistorialMD'      AS Vista, LEFT(MD,60)   AS x FROM [dbo].[vw_HistorialMD]      WITH (NOLOCK);
SELECT TOP 1 'RankingMD'        AS Vista, LEFT(HeaderMD,60) AS x FROM [dbo].[vw_RankingMD]    WITH (NOLOCK);
GO

-- RESULTADOS BLOQUE 161 (29/09) -- G2 CONFIRMADO, y el 161.1 destapa un agujero de carga grande.
--
-- 161.1 ⛔ 1 597 MUESTRAS SIN COMPONENTE, y NO estan repartidas:
--   Cerro Verde  1 579 muestras · 62 equipos · 01-Mar-2026 a 17-Ago-2026
--   Antapaccay      16 muestras ·  3 equipos · 20-Dic-2025 a 22-Sep-2026
--   Antamina         2 muestras ·  1 equipo  · 03-Abr-2026
--   ⇒ Cerro Verde tiene SEIS MESES de carga sin componente en 62 equipos. Eso no es una anomalia
--     suelta: es sistematico, y explica por que ese proyecto se comporta raro en varios modulos.
--     Va a Carlos, del mismo saco que los 347 ISO sin medir del 159.2 y que el limite de las
--     ruedas de Antapaccay. El SQL ya no miente; la carga sigue incompleta.
--
-- 161.2 ✅ LA CURA FUNCIONA. Donde antes salia NULL ahora sale el historial completo y etiquetado:
--   "**Historial - 3104 · (sin componente)** · 6 muestras (recientes arriba)".
--   Los 5 equipos: 3104, 3105, CA3164, HT338, K-301.
--
-- 161.3 ✅ CERO NULOS en las tres vistas (HistorialMD 66 filas, UltimoAnalisisMD 66, TriageMD 3).
--   🔴 Pero tardo 11 MINUTOS por como lo escribi: ver la nota del bloque. Reescrito.
--
-- 161.4 ✅ SMOKE TEST COMPLETO EN 2 SEGUNDOS. Las 12 vistas responden y HistorialMD ya no es NULL.

/* ⚑ SI EL 161.1 DEVUELVE MUCHAS FILAS, la etiqueta '(sin componente)' es un parche correcto pero
   no la solucion: significa que hay muestras cargadas sin componente y eso es un dato para
   Carlos, del mismo saco que los 347 ISO sin medir del 159.2. El SQL deja de mentir; la carga
   sigue incompleta. */


-- ==== BLOQUE 162 - PASO 5c (N): el contador del triage sale de las celdas ====
-- QUE CAMBIO en vw_TriageMD (y SOLO ahi):
--   El chip 🟥/🟨/🟢 y el "X de N observados" YA NO salen de Estado_General. Salen de las MISMAS
--   celdas que se imprimen, contando solo los parametros con Inf = 0. Es el mismo arreglo que
--   vw_CondicionMT_MD lleva desde el BLOQUE 118.
--   ⇒ E0 CERRADO DE RAIZ: el contador y la tabla leen lo mismo, no pueden contradecirse. El pie
--     sigue existiendo, pero ya no justifica una contradiccion -- nombra en prosa los parametros
--     que el area declaro INFORMATIVOS y que se ven sin contar.
--   ⛔ Los Inf=1 se imprimen EXACTAMENTE IGUAL, con su valor y sin ninguna marca. La regla esta en
--     la cabecera de vw_FormatoParametro y no se negocia.
-- Estado_General NO se toco: sigue igual para /barrido, /ranking y todo lo demas. Ver 162.4.

-- 162.1 ⭐ EL NUMERO NUEVO. Antes: "6 de 54 observados (3 criticos)".
--   ⚠ VA A SUBIR, y mucho. El 157.1 midio 48 de 72 con Inf respetado, y el 156.2 dice de donde
--   sale: ISO>6 marca 48 de los 54 componentes que tienen limite. Eso NO es un error -- es lo que
--   el area configuro (ISO>6 tiene Inf=0 en TRACCION) contra el limite que el area cargo
--   (LP 19 / LC 20, BLOQUE 138.1). Pero hay que verlo antes de que lo vea Carlos.
SELECT LEFT(MD, 130) AS Cabecera
FROM [dbo].[vw_TriageMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%todos%' AND CompTipo = 'TRACCION';
GO

-- 162.2 ⭐⭐ QUE EL CONTADOR DIGA LA VERDAD. Se cuenta sobre la FUNDACION cuantos componentes
--   tienen al menos un parametro que CUENTA (Inf = 0) fuera de limite, y ese numero tiene que ser
--   EXACTAMENTE el que imprime el encabezado del 162.1. Si no coinciden, el contador sigue
--   mirando otra cosa que la tabla y E0 no se cerro.
--   (Contar aqui y no sobre el MD es a proposito: filtrar una vista *MD por columna calculada
--    cuesta 11 minutos -- corolario de la ley 3, aprendido en el BLOQUE 161.3.)
SELECT b.Modelo,
       COUNT(*)                                    AS Componentes,
       SUM(CASE WHEN k.peor < 3 THEN 1 ELSE 0 END) AS Observados,
       SUM(CASE WHEN k.peor = 1 THEN 1 ELSE 0 END) AS Criticos
FROM [dbo].[vw_MuestrasRankeadas] b WITH (NOLOCK)
CROSS APPLY (
    SELECT MIN(CASE WHEN ff.Inf = 0 AND v.est = 'CRITICO' THEN 1
                    WHEN ff.Inf = 0 AND v.est = 'PRECAUCION' THEN 2 ELSE 3 END) AS peor
    FROM (VALUES
        (N'Fe',b.Estado_Fe),(N'PQ',b.Estado_PQ),(N'Cr',b.Estado_Cr),(N'Ni',b.Estado_Ni),
        (N'Cu',b.Estado_Cu),(N'Pb',b.Estado_Pb),(N'Sn',b.Estado_Sn),(N'Al',b.Estado_Al),
        (N'Si',b.Estado_Si),(N'Ca',b.Estado_Ca),(N'Zn',b.Estado_Zn),(N'Mg',b.Estado_Mg),
        (N'K',b.Estado_K),(N'Na',b.Estado_Na),(N'B',b.Estado_B),(N'P',b.Estado_P),(N'Mo',b.Estado_Mo),
        (N'V100',b.Estado_V100),(N'V40',b.Estado_V40),(N'TAN',b.Estado_TAN),(N'TBN',b.Estado_TBN),
        (N'Oxidacion',b.Estado_Oxi),(N'Sulfatacion',b.Estado_Sulf),(N'Nitracion',b.Estado_Nit),
        (N'Agua',b.Estado_Agua),(N'Hollin',b.Estado_Hollin),(N'Diesel',b.Estado_Diesel),
        (N'ISO>4',b.Estado_ISO4),(N'ISO>6',b.Estado_ISO6),(N'ISO>14',b.Estado_ISO14)
    ) v(Parametro, est)
    CROSS APPLY (
        SELECT TOP 1 f.Inf FROM [dbo].[vw_FormatoParametro] f
        WHERE f.Parametro = v.Parametro AND f.CompTipo IN (b.CompTipo, N'(CRUZADO)')
        ORDER BY CASE WHEN f.CompTipo = b.CompTipo THEN 0 ELSE 1 END
    ) ff
    WHERE v.est IN ('CRITICO','PRECAUCION')
) k
WHERE b.rn_recencia = 1 AND b.CompTipo = 'TRACCION' AND b.Proyecto LIKE '%Antapaccay%'
GROUP BY b.Modelo
ORDER BY b.Modelo;
GO

-- 162.2b ⭐ QUIEN APORTA EL SALTO. Si un solo parametro explica casi todas las marcas nuevas, la
--   conversacion con Carlos no es sobre el triage sino sobre ESE parametro. Sospechoso: ISO>6.
SELECT v.Parametro, ff.Inf,
       SUM(CASE WHEN v.est = 'CRITICO' THEN 1 ELSE 0 END)    AS Criticos,
       SUM(CASE WHEN v.est = 'PRECAUCION' THEN 1 ELSE 0 END) AS Precauciones
FROM [dbo].[vw_MuestrasRankeadas] b WITH (NOLOCK)
CROSS APPLY (VALUES
    (N'Fe',b.Estado_Fe),(N'PQ',b.Estado_PQ),(N'Cr',b.Estado_Cr),(N'Ni',b.Estado_Ni),
    (N'Cu',b.Estado_Cu),(N'Pb',b.Estado_Pb),(N'Sn',b.Estado_Sn),(N'Al',b.Estado_Al),
    (N'Si',b.Estado_Si),(N'Ca',b.Estado_Ca),(N'Zn',b.Estado_Zn),(N'Mg',b.Estado_Mg),
    (N'K',b.Estado_K),(N'Na',b.Estado_Na),(N'B',b.Estado_B),(N'P',b.Estado_P),(N'Mo',b.Estado_Mo),
    (N'V100',b.Estado_V100),(N'V40',b.Estado_V40),(N'TAN',b.Estado_TAN),(N'TBN',b.Estado_TBN),
    (N'Oxidacion',b.Estado_Oxi),(N'Sulfatacion',b.Estado_Sulf),(N'Nitracion',b.Estado_Nit),
    (N'Agua',b.Estado_Agua),(N'Hollin',b.Estado_Hollin),(N'Diesel',b.Estado_Diesel),
    (N'ISO>4',b.Estado_ISO4),(N'ISO>6',b.Estado_ISO6),(N'ISO>14',b.Estado_ISO14)
) v(Parametro, est)
CROSS APPLY (
    SELECT TOP 1 f.Inf FROM [dbo].[vw_FormatoParametro] f
    WHERE f.Parametro = v.Parametro AND f.CompTipo IN (b.CompTipo, N'(CRUZADO)')
    ORDER BY CASE WHEN f.CompTipo = b.CompTipo THEN 0 ELSE 1 END
) ff
WHERE b.rn_recencia = 1 AND b.CompTipo = 'TRACCION' AND b.Proyecto LIKE '%Antapaccay%'
  AND v.est IN ('CRITICO','PRECAUCION')
GROUP BY v.Parametro, ff.Inf
ORDER BY COUNT(*) DESC;
GO

-- 162.3 ⭐ QUE LOS INFORMATIVOS SIGAN VIENDOSE, CON SU VALOR Y SIN ETIQUETA. En MT el Zn es
--   Inf=1: el CA3165 (Zn 194,8) tiene que aparecer en la columna Contaminacion como 'Zn(194.8) 🟥'
--   y aun asi NO contar. Si la fila salio 🟢 con el Zn marcado, ESO ES LO CORRECTO ahora -- y el
--   pie de la tabla lo explica. Lo que NO puede aparecer por ningun lado es un '(inf)'.
SELECT LEFT(MD, 2200) AS Inicio
FROM [dbo].[vw_TriageMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%todos%' AND CompTipo = 'TRACCION';
GO

-- 162.4 ⚠⚠ LO QUE ESTE CAMBIO ROMPE, Y HAY QUE SABERLO. El triage ya cuenta con las celdas, pero
--   /barrido, /barridodet y /ranking SIGUEN contando con Estado_General. Durante un rato van a
--   dar numeros distintos para la misma flota, que es exactamente el sintoma del BLOQUE 122 ("el
--   mismo valor, dos modulos, dos respuestas"). Esto mide el desfase.
--   ⇒ No se arregla hoy A PROPOSITO: tocar Estado_General mientras el limite de las ruedas de
--     Antapaccay siga mal (Shell Spirax, BLOQUE 158.4) convertiria 54 falsos criticos en 54
--     equipos "observados" en TODOS los modulos a la vez.
SELECT b.Proyecto, b.CompTipo, COUNT(*) AS Componentes,
       SUM(CASE WHEN b.Estado_General <> 'OK' THEN 1 ELSE 0 END) AS Cuenta_Estado_General,
       SUM(CASE WHEN k.peor < 3 THEN 1 ELSE 0 END)               AS Cuenta_Triage_nuevo
FROM [dbo].[vw_MuestrasRankeadas] b WITH (NOLOCK)
CROSS APPLY (
    SELECT MIN(CASE WHEN ff.Inf = 0 AND v.est = 'CRITICO' THEN 1
                    WHEN ff.Inf = 0 AND v.est = 'PRECAUCION' THEN 2 ELSE 3 END) AS peor
    FROM (VALUES
        (N'Fe',b.Estado_Fe),(N'PQ',b.Estado_PQ),(N'Cr',b.Estado_Cr),(N'Ni',b.Estado_Ni),
        (N'Cu',b.Estado_Cu),(N'Pb',b.Estado_Pb),(N'Sn',b.Estado_Sn),(N'Al',b.Estado_Al),
        (N'Si',b.Estado_Si),(N'Ca',b.Estado_Ca),(N'Zn',b.Estado_Zn),(N'Mg',b.Estado_Mg),
        (N'K',b.Estado_K),(N'Na',b.Estado_Na),(N'B',b.Estado_B),(N'P',b.Estado_P),(N'Mo',b.Estado_Mo),
        (N'V100',b.Estado_V100),(N'V40',b.Estado_V40),(N'TAN',b.Estado_TAN),(N'TBN',b.Estado_TBN),
        (N'Oxidacion',b.Estado_Oxi),(N'Sulfatacion',b.Estado_Sulf),(N'Nitracion',b.Estado_Nit),
        (N'Agua',b.Estado_Agua),(N'Hollin',b.Estado_Hollin),(N'Diesel',b.Estado_Diesel),
        (N'ISO>4',b.Estado_ISO4),(N'ISO>6',b.Estado_ISO6),(N'ISO>14',b.Estado_ISO14)
    ) v(Parametro, est)
    CROSS APPLY (
        SELECT TOP 1 f.Inf FROM [dbo].[vw_FormatoParametro] f
        WHERE f.Parametro = v.Parametro AND f.CompTipo IN (b.CompTipo, N'(CRUZADO)')
        ORDER BY CASE WHEN f.CompTipo = b.CompTipo THEN 0 ELSE 1 END
    ) ff
    WHERE v.est IN ('CRITICO','PRECAUCION')
) k
WHERE b.rn_recencia = 1 AND b.CompTipo <> 'OTRO'
GROUP BY b.Proyecto, b.CompTipo
ORDER BY b.Proyecto, b.CompTipo;
GO

-- 162.5 COSTE. El MIN(...) va DENTRO del agregado que ya existia, asi que no hay pasada nueva.
--   Referencia del 155.6: Scan count 1 sobre LaboratoryData, ~2 387 ms. No puede subir el Scan.
SET STATISTICS TIME ON; SET STATISTICS IO ON;
SELECT LEFT(MD, 80) FROM [dbo].[vw_TriageMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%todos%' AND CompTipo = 'TRACCION';
GO
SET STATISTICS TIME OFF; SET STATISTICS IO OFF;
GO

-- 162.6 SMOKE. El triage se toco entero: chip, orden de filas, secciones y contador.
SELECT TOP 1 'TriageMD'       AS Vista, LEFT(MD,60) AS x FROM [dbo].[vw_TriageMD]      WITH (NOLOCK);
SELECT TOP 1 'CondicionMT_MD' AS Vista, LEFT(MD,60) AS x FROM [dbo].[vw_CondicionMT_MD] WITH (NOLOCK);
GO

-- RESULTADOS BLOQUE 162 (29/09) -- 5c FUNCIONA, y el 162.2b deja la decision en UN parametro.
--
-- 162.1 / 162.2 ✅ E0 CERRADO Y VERIFICADO. El encabezado dice "48 de 54 observados (41 criticos)"
--   y la cuenta independiente sobre la fundacion da EXACTAMENTE 54 componentes / 48 observados /
--   41 criticos en 980E (y 18/0/0 en 930E, que no tiene limites). El contador y la tabla ya no
--   pueden discrepar porque leen lo mismo.
--
-- 162.2b ⭐⭐ EL SALTO ES UN SOLO PARAMETRO. Marcas en Antapaccay MT:
--   Parametro  Inf  Criticos  Precauciones
--   ISO>6       0      38         10        <- 48. ES EL TRIAGE ENTERO.
--   Zn          1      15          2        <- no cuenta (informativo), y se ve igual
--   Ca          1       4          0        <- no cuenta
--   Fe          0       2          1     V100 0  2  0     PQ 0  1  0
--   P           0       0          3     ISO>14 0  0  3   Pb/Cr 0  0  1
--   ⇒ Sin el ISO>6 el triage marcaria ~9 de 54. CON el, 48 de 54. El 89% de la flota.
--   ⇒ La decision ya no es "como rehacemos el triage": es "el codigo de limpieza cuenta o no".
--     Y desde 5c eso es UN VALOR en vw_FormatoParametro (ISO>4/6/14 -> Inf = 1), no una vista.
--
-- 162.3 ✅ LOS INFORMATIVOS SE VEN, CON SU VALOR Y SIN ETIQUETA. CA3165: 'Zn(194.8) 🟥' en la
--   columna Contaminacion, y la fila sale 🟨 (no 🟥) porque el Zn no cuenta. Ni un '(inf)' a la
--   vista. El pie de la tabla lo explica una vez, en prosa.
--
-- 162.4 ⚠⚠ EL DESFASE ENTRE MODULOS, MEDIDO. Estado_General -> triage nuevo:
--   Antapaccay RUEDA     4 ->  54  ⛔ (los 50 nuevos son los falsos criticos del Shell Spirax)
--   Antapaccay TRACCION  6 ->  48     Antapaccay MOTOR    6 -> 15
--   Antamina   RUEDA   103 -> 121     Antamina TRACCION  77 -> 88   Antamina MOTOR 4 -> 16
--   Antamina   HIDRAULICO 50 -> 58    Cerro Verde y Toromocho: sin cambio o +1
--   🔴 AVISO QUE ME DEBO A MI MISMO: en el BLOQUE 159 escribi "no tocar Estado_General todavia,
--      convertiria 54 falsos criticos en 54 observados". 5c no toco Estado_General, pero SI
--      cambio el contador del triage -- y en /triage de ruedas de Antapaccay eso es exactamente
--      lo que pasa: 4 -> 54, y ~50 son el limite de Mobiltrans aplicado a un Shell Spirax.
--      Antes estaban OCULTOS; ahora se ven. Es mas honesto, pero el viernes alguien puede leerlo
--      como 54 ruedas rotas. ⇒ El limite de las ruedas pasa de "hay que corregirlo" a URGENTE.
--
-- 162.5 COSTE. Elapsed 3 056 ms (antes 2 387). Scan count 1 sobre LaboratoryData, sin scans
--   nuevos: el MIN(...) entra en el agregado que ya existia. Worktable 1 537, igual que antes.
--
-- 162.6 ✅ SMOKE. TriageMD ("Sistemas Hidraulicos - Antamina · 58 de 66") y CondicionMT_MD, bien.

/* ⇒ RECOMENDACION, Y EL PORQUE. Poner ISO>4/6/14 en Inf = 1 (se siguen VIENDO con su valor, dejan
   de contar). No es por comodidad; son tres razones, y la tercera es la que decide:
     1. El codigo de limpieza es una CAUSA, no un DANO. Un aceite sucio anticipa desgaste; no es
        desgaste. El triage contesta "que se esta danando".
     2. La banda no tiene resolucion: LP 19 / LC 20 es UN punto, y en la escala ISO 4406 cada
        punto DUPLICA las particulas. Un parametro que solo sabe decir "bien" o "critico", sin
        nada en medio, no puede ordenar una cola de atencion.
     3. Marca 48 de 54. Una senal que se enciende en el 89% de la flota no lleva informacion: no
        distingue a quien atender primero, que es lo unico que el triage tiene que hacer.
   Es decision del area, no nuestra -- pero ahora cuesta un valor y se revierte igual de barato. */

/* ⭐ LO QUE ESTE PASO DESBLOQUEA, Y ES LO MEJOR QUE TIENE:
   Ahora que el contador LEE la bandera Inf, cambiar QUE cuenta es editar UN VALOR en
   vw_FormatoParametro -- no reescribir una vista. Si Carlos ve el 162.1 y decide que el codigo de
   limpieza no deberia disparar el triage, es poner ISO>4/6/14 en Inf = 1 y volver a desplegar.
   La conversacion pasa de "hay que rehacer el triage" a "que cuenta y que no", que es la que el
   area sabe contestar. */


-- ==== BLOQUE 163 - PASO 6 (B): /tendencia sin la tabla de limites ====
-- QUE CAMBIO: fuera 'limcte', 'limbody' y 'limbody_rel'. En su lugar 'limflag', que solo CUENTA si
--   hay algun limite cargado. La tabla «Límites de referencia (ppm)» desaparece de las dos salidas.
-- POR QUE ES CORRECTO QUITARLA: cada celda de la tabla de valores YA trae su semaforo (':C' -> 🟥,
--   ':P' -> 🟨). El LP/LC repetido abajo no anadia nada que no se viera ya.
-- ⚠ LO QUE NO SE PODIA PERDER: el aviso de «sin limites cargados» vivia PEGADO a esa tabla, y son
--   45 combinaciones proyecto+modelo las que lo necesitan (BLOQUE 102). Sobrevive como LINEA de
--   texto. Sin el, un componente sin limites se lee igual que uno en regla: fallo silencioso.
-- ⭐ BONUS DE RENDIMIENTO: 'limcte' leia 'te' dos veces mas (limbody + limbody_rel). El radar de
--   tools/check_ddl.py ya no lo lista; en vw_TendenciaMD solo quedan rowcte x2 y obslast x2.

-- 163.1 ⭐ LA SALIDA NORMAL. Un componente CON limites (CA3160 es 980E de Antapaccay): tiene que
--   salir la tabla de valores con sus 🟥/🟨 y NINGUNA tabla de limites debajo.
SELECT LEFT(MD, 1800) AS Inicio
FROM [dbo].[vw_TendenciaMD] WITH (NOLOCK)
WHERE Equipo = N'CA3160';
GO

-- 163.2 ⭐⭐ QUE EL AVISO SOBREVIVA. Los 930E de Antapaccay (3110..3118) no tienen limites
--   cargados -- se vio en el 156.3 (Zn_LP/Zn_LC NULL) y en el 158.3 (ISO6_LP NULL).
--   Aqui TIENE que aparecer la linea «⚠ Sin límites (LP/LC) cargados». Si no aparece, volvimos a
--   meter un fallo silencioso y hay que revertir.
--   (Se filtra por Equipo, que es columna REAL: corolario de la ley 3, BLOQUE 161.3.)
SELECT Equipo, compAbbr, LEFT(MD, 1500) AS Inicio
FROM [dbo].[vw_TendenciaMD] WITH (NOLOCK)
WHERE Equipo IN (N'3115', N'3117');
GO

-- 163.3 ⭐ LA SALIDA DE RELEVANTES, Y UN FALLO QUE YA ESTABA. Sin limites cargados NADA puede ser
--   'relevante', asi que la vista afirmaba «opera en condicion normal» de un componente que nadie
--   pudo evaluar. Ahora distingue los dos casos: sin limites dice que NO SE PUEDE SABER.
SELECT Equipo, compAbbr, LEFT(MD_Relevantes, 700) AS Relevantes
FROM [dbo].[vw_TendenciaMD] WITH (NOLOCK)
WHERE Equipo IN (N'3115', N'CA3160');
GO

-- 163.4 COSTE. /tendencia venia en ~37 s y la causa esta identificada (rowcte x2, limcte x2,
--   obslast x2). Quitar limcte se lleva DOS de esas seis lecturas. No arregla el tema -- eso es
--   despues del 02/10 -- pero tiene que BAJAR, no subir.
SET STATISTICS TIME ON; SET STATISTICS IO ON;
SELECT LEFT(MD, 80) FROM [dbo].[vw_TendenciaMD] WITH (NOLOCK) WHERE Equipo = N'CA3160';
GO
SET STATISTICS TIME OFF; SET STATISTICS IO OFF;
GO

-- 163.5 SMOKE. Las tres columnas de la vista tienen que responder, ninguna NULL.
SELECT TOP 1 'MD' AS Col, LEFT(MD,50) AS x FROM [dbo].[vw_TendenciaMD] WITH (NOLOCK) WHERE Equipo = N'CA3160'
UNION ALL
SELECT 'MD_Estadistica', LEFT(MD_Estadistica,50) FROM [dbo].[vw_TendenciaMD] WITH (NOLOCK) WHERE Equipo = N'CA3160'
UNION ALL
SELECT 'MD_Relevantes', LEFT(MD_Relevantes,50) FROM [dbo].[vw_TendenciaMD] WITH (NOLOCK) WHERE Equipo = N'CA3160';
GO

/* ⚑ LO QUE HAY QUE MIRAR CON LOS OJOS, NO CON EL SQL: que la tabla de valores se siga entendiendo
   SIN los limites al lado. El semaforo dice QUE esta fuera, pero ya no dice DE CUANTO. Si en la
   marcha alguien pregunta "fuera de cuanto", la respuesta no es devolver la tabla: es que el
   numero del limite vaya en la MISMA celda, y eso es un cambio distinto que hay que pedir. */


-- RESULTADOS BLOQUE 163 (29/09) -- B funciona en lo visible, pero DOS de mis comprobaciones
-- estaban mal disenadas y UNA prediccion mia fallo. Por orden:
--
-- 163.1 ✅ LA TABLA DE LIMITES YA NO ESTA, y la de valores conserva su semaforo por celda. Se ve
--   la cabecera (Campo/SMR/Hrs Aceite/Hrs Comp/CM/Estado/Grado), el detalle agrupado por familia
--   (Salud · Aditivos · Contaminacion · Desgaste · Codigo Limpieza), el Acum y el Spark.
--
-- 163.2 ⚠ NO CONCLUYENTE, Y ES CULPA DEL TEST. Puse el aviso DESPUES del cuerpo de la tabla y
--   luego lo busque con LEFT(MD, 1500): el corte cae antes del aviso, asi que no se ve ni cuando
--   esta. Un test que no puede fallar tampoco puede aprobar. Rehecho en el 164.1 con CHARINDEX.
--
-- 163.3 ⚠ Y AQUI ME EQUIVOQUE DE EQUIPO. Para 3115 sale «opera en condicion normal», o sea que
--   'limflag' encontro limites: ese componente SI tiene alguno cargado. Yo lo elegi creyendo que
--   los 930E no tenian ninguno, pero lo que se midio en el 156.3 y el 158.3 es que les faltan el
--   Zn y los ISO -- no que no tengan nada. El caso que hay que probar es un componente con CERO
--   limites, y el 164.2 lo busca en vez de suponerlo.
--   (El cambio en si esta bien: CA3160 MT LH y MT RH muestran sus relevantes con Zn, Fe, Cr, Pb.)
--
-- 163.4 🔴 MI PREDICCION FALLO. Dije "tiene que BAJAR". NO bajo: 43 047 ms para UN equipo, con
--   Scan count 21 sobre LaboratoryData y 533 lecturas fisicas en Workfile (esta volcando a
--   tempdb). Quitar limcte se llevo dos lecturas de 'te' del papel, pero el coste no estaba ahi:
--   esta en rowcte x2 y obslast x2, que siguen. Aprendido otra vez: el radar de CTE dice DONDE
--   mirar, no cuanto se ahorra. Lo unico que se puede afirmar es que no se rompio nada.
--   ⚠ 43 s con el conector muriendo a los 120 s deja poco margen. Sigue aparcado para despues del
--     02/10, pero ya no es "una vista lenta": es la mas cara del sistema.
--
-- 163.5 ✅ SMOKE. Las tres columnas (MD, MD_Estadistica, MD_Relevantes) responden, ninguna NULL.
--
-- ⚑ DE PASO, DOS COSAS QUE SE VEN EN LAS CAPTURAS Y NO SON DE ESTE PASO:
--   * 'Grado | nan | nan | — | — |' en los 3115 -- el bug 'nan' otra vez, ahora en Grado.
--   * '· ultimas 1 muestras' -- concordancia. Cosmetico, pero se lee mal.


-- RESULTADOS BLOQUE 164 (29/09) -- las tres primeras concluyentes; la cuarta la deje comentada y
-- con 'XXXX', o sea que volvio a no probar nada. Rehecha arriba.
--
-- 164.1 ✅ CHARINDEX funciona y el corte ya no estorba. ConAviso = 0 en los 18 componentes de
--   CA3160, 3115 y 3117. Para CA3160 es lo correcto (tiene limites). Para 3115/3117 tambien:
--   el 163.3 ya habia mostrado que SI tienen algunos. El caso de verdad estaba en otro lado.
--
-- 164.2 ✅ AHI ESTAN. Antamina 930E: HT079, HT080, HT081, HT082 -- MOTOR, MOTOR DE TRACCION LH/RH
--   y SISTEMA HIDRAULICO, sin un solo limite.
--   ⚠ Y DE REGALO, UN TYPO EN LA BD: 'MOTORO DE TRACCION RH'. Es un Compartimiento distinto de
--     'MOTOR DE TRACCION RH', asi que ese componente se cuenta APARTE en todo el sistema. Pasa el
--     LIKE '%TRACCION%' (por eso no habia reventado), pero duplica el componente. Para Carlos.
--
-- 164.3 ⛔⛔ LA DIMENSION REAL, Y ES LA MAS GRANDE DE LA RONDA:
--   Antamina    930E   441        Antapaccay 930E    54       Antapaccay WA900     7
--   Cerro Verde 930E   216        Cerro Verde 730E   12       Toquepala  PC7000    5
--   Cuajone     980E    72        Antapaccay HD1500  10       Toromocho  WD900     2
--   Toquepala   980E    66
--   ⇒ 885 COMPONENTES SIN NINGUN LIMITE CARGADO. Y como Estado_General usa ISNULL(LC, 9999), esos
--     885 salen 'OK' -- verdes -- pase lo que pase con sus valores. No estan sanos: no estan
--     evaluados. Mismo modo de fallo que los 347 ISO en cero, pero a nivel de COMPONENTE ENTERO.
--   ⚑ Matiz honesto: L5 ya cubre esto en /triage y /barrido, que avisan cuando el MODELO no tiene
--     limites. Lo que faltaba era el aviso a nivel de COMPONENTE en /tendencia -- y es justo el
--     que B estuvo a punto de borrar. Conservarlo no era una precaucion teorica: son 885.
--
-- 164.4 🔴 NO PROBO NADA (comentado + 'XXXX'). Tercera vez que escribo una comprobacion que no
--   puede fallar. Rehecha con HT079/HT080, y con un 164.5 que distingue "el aviso no sale" de
--   "ese equipo no llega a la vista".

-- ==== BLOQUE 164 - Rehacer las dos comprobaciones que no probaban nada ====

-- 164.1 ⭐ EL AVISO, BUSCADO DONDE ESTA. CHARINDEX no depende de donde caiga el corte.
--   'ConAviso' = 1 significa que el MD lleva la linea «Sin límites (LP/LC) cargados».
--   Un componente CON limites (CA3160) debe dar 0; uno SIN limites, 1.
SELECT Equipo, compAbbr,
       CASE WHEN CHARINDEX(N'Sin límites (LP/LC) cargados', MD) > 0 THEN 1 ELSE 0 END AS ConAviso,
       LEN(MD) AS LargoMD
FROM [dbo].[vw_TendenciaMD] WITH (NOLOCK)
WHERE Equipo IN (N'CA3160', N'3115', N'3117')
ORDER BY Equipo, compAbbr;
GO

-- 164.2 ⭐⭐ BUSCAR UN COMPONENTE CON CERO LIMITES, en vez de suponer cual. Se pregunta a la
--   fundacion, que es barata, y no a la vista *MD (corolario de la ley 3).
--   Los 8 parametros de desgaste son los que SIEMPRE deberian tener limite: si ni uno solo lo
--   tiene, ese componente no se puede evaluar en absoluto.
SELECT TOP 20 Proyecto, Modelo, Equipo, Compartimiento
FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK)
WHERE rn_recencia = 1 AND CompTipo <> 'OTRO'
  AND Fe_LP IS NULL AND Fe_LC IS NULL AND Cr_LP IS NULL AND Cr_LC IS NULL
  AND Cu_LP IS NULL AND Cu_LC IS NULL AND Pb_LP IS NULL AND Pb_LC IS NULL
  AND Al_LP IS NULL AND Al_LC IS NULL AND Si_LP IS NULL AND Si_LC IS NULL
ORDER BY Proyecto, Equipo;
GO

-- 164.3 CUANTOS SON, por proyecto y modelo. Esto da la dimension real del aviso: si son pocos, el
--   aviso casi nunca se ve; si son muchos, es una linea que va a leer mucha gente.
SELECT Proyecto, Modelo, COUNT(*) AS ComponentesSinNingunLimite
FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK)
WHERE rn_recencia = 1 AND CompTipo <> 'OTRO'
  AND Fe_LP IS NULL AND Fe_LC IS NULL AND Cr_LP IS NULL AND Cr_LC IS NULL
  AND Cu_LP IS NULL AND Cu_LC IS NULL AND Pb_LP IS NULL AND Pb_LC IS NULL
  AND Al_LP IS NULL AND Al_LC IS NULL AND Si_LP IS NULL AND Si_LC IS NULL
GROUP BY Proyecto, Modelo
ORDER BY COUNT(*) DESC;
GO

-- 164.4 🔴 ESTE LO DEJE COMENTADO Y CON 'XXXX' DE PLANTILLA, asi que devolvio 0 filas y no probo
--   nada -- el mismo error del 163.2 por tercera vez. Rehecho con equipos REALES del 164.2.
--   HT079..HT082 son 930E de Antamina SIN NINGUN limite cargado.
--   ESPERADO: ConAviso = 1, y en MD_Relevantes el texto «no se puede decir si hay parametros
--   fuera de umbral» (NO «opera en condicion normal», que seria mentir sobre algo no evaluado).
SELECT Equipo, compAbbr,
       CASE WHEN CHARINDEX(N'Sin límites (LP/LC) cargados', MD) > 0 THEN 1 ELSE 0 END AS ConAviso,
       LEFT(MD_Relevantes, 220) AS Relevantes
FROM [dbo].[vw_TendenciaMD] WITH (NOLOCK)
WHERE Equipo IN (N'HT079', N'HT080');
GO
-- 164.5 ⚠ SI EL 164.4 DEVUELVE 0 FILAS no es que falle el aviso: es que esos equipos no llegan a
--   vw_TendenciaElemento. Esto lo distingue, para no volver a confundir "no sale" con "no existe".
SELECT TOP 5 Equipo, Compartimiento, COUNT(*) AS FilasEnTendencia
FROM [dbo].[vw_TendenciaElemento] WITH (NOLOCK)
WHERE Equipo IN (N'HT079', N'HT080')
GROUP BY Equipo, Compartimiento;
GO


-- RESULTADOS BLOQUE 164.4/164.5 (29/09) -- 🔴 EL AVISO NO SALTABA, Y LA CAUSA VENIA DE ANTES.
--   HT079 y HT080 (930E de Antamina, CERO limites de desgaste) dieron ConAviso = 0, y
--   MD_Relevantes dijo «Sin parametros fuera de umbral - el componente opera en condicion
--   normal». Justo la afirmacion que yo di por corregida en el 163.
--   164.5 descarto la otra explicacion: esos equipos SI llegan a vw_TendenciaElemento (HT079
--   MOTOR con 27 filas, MT LH/RH con 23). O sea que el problema era el aviso, no el alcance.
--   CAUSA: 'limflag' preguntaba "¿tiene ALGUN limite?", y estos componentes tienen alguno suelto
--   (un V100, un TBN) aunque no tengan NI UNO de los metales de desgaste.
--   ⚑ Y NO ERA UNA REGRESION MIA: el aviso original usaba la misma condicion (limbody NULL solo
--     si ningun parametro tenia limite). Lo que hice en B fue conservar fielmente un aviso que
--     casi nunca se disparaba. Conservarlo estuvo bien; darlo por bueno sin probarlo, no.


-- ==== BLOQUE 165 - B2: el aviso se dispara por los limites QUE HACEN FALTA ====
-- QUE CAMBIO: 'limflag' gana 'nLimDesgaste' -- cuantos de los 9 parametros que decide
--   Estado_General (Fe, PQ, Cr, Ni, Cu, Pb, Sn, Al, Si) tienen limite. El aviso salta cuando ese
--   numero es 0, no cuando no hay ningun limite en absoluto.
-- POR QUE ESOS 9: son exactamente los que mira Estado_General. Sin ellos el semaforo verde no
--   significa nada, que es el problema de los 885 componentes del BLOQUE 164.3.
-- El texto tambien cambia: dice «para los metales de desgaste» y «el estado no se puede evaluar».

-- 165.1 ⭐⭐ LA PRUEBA QUE FALTABA. HT079/HT080 tienen que dar ConAviso = 1, y MD_Relevantes tiene
--   que decir «no se puede decir», NO «opera en condicion normal».
SELECT Equipo, compAbbr,
       CASE WHEN CHARINDEX(N'Sin límites (LP/LC) cargados', MD) > 0 THEN 1 ELSE 0 END AS ConAviso,
       LEFT(MD_Relevantes, 240) AS Relevantes
FROM [dbo].[vw_TendenciaMD] WITH (NOLOCK)
WHERE Equipo IN (N'HT079', N'HT080');
GO

-- 165.2 ⚠ Y QUE NO SE DISPARE DE MAS. CA3160 tiene limites de desgaste: ConAviso = 0 y sus
--   relevantes como antes. Si aqui sale 1, el aviso pasa a ser ruido y no se lee mas.
SELECT Equipo, compAbbr,
       CASE WHEN CHARINDEX(N'Sin límites (LP/LC) cargados', MD) > 0 THEN 1 ELSE 0 END AS ConAviso
FROM [dbo].[vw_TendenciaMD] WITH (NOLOCK)
WHERE Equipo IN (N'CA3160', N'3115', N'3117')
ORDER BY Equipo, compAbbr;
GO

-- 165.3 ⭐ EL TYPO 'MOTORO DE TRACCION RH', DIMENSIONADO. Andres pregunta si depurarlo o dejarlo.
--   La respuesta depende de CUANTA data cuelga de el y de si convive con el nombre correcto en el
--   MISMO equipo -- si convive, ese camion muestra TRES motores de traccion en vez de dos.
SELECT ME.[Code] AS Equipo,
       SUM(CASE WHEN LD.[Compartimiento] = N'MOTORO DE TRACCION RH' THEN 1 ELSE 0 END) AS ConTypo,
       SUM(CASE WHEN LD.[Compartimiento] = N'MOTOR DE TRACCION RH'  THEN 1 ELSE 0 END) AS Correcto,
       MIN(CASE WHEN LD.[Compartimiento] = N'MOTORO DE TRACCION RH' THEN LD.[FechaMuestreo] END) AS TypoDesde,
       MAX(CASE WHEN LD.[Compartimiento] = N'MOTORO DE TRACCION RH' THEN LD.[FechaMuestreo] END) AS TypoHasta
FROM [Oil].[LaboratoryData] LD
INNER JOIN [Mine].[MiningEquipment] ME ON ME.[Id] = LD.[MiningEquipmentId]
WHERE LD.[Compartimiento] IN (N'MOTORO DE TRACCION RH', N'MOTOR DE TRACCION RH')
GROUP BY ME.[Code]
HAVING SUM(CASE WHEN LD.[Compartimiento] = N'MOTORO DE TRACCION RH' THEN 1 ELSE 0 END) > 0
ORDER BY ConTypo DESC;
GO

-- 165.4 ¿HAY MAS TYPOS ASI? Si 'MOTORO' no es el unico, normalizar a mano uno por uno es perder
--   el tiempo: seria una lista de sinonimos, y eso ya es otra decision.
SELECT LD.[Compartimiento], COUNT(*) AS Muestras, COUNT(DISTINCT ME.[Code]) AS Equipos
FROM [Oil].[LaboratoryData] LD
INNER JOIN [Mine].[MiningEquipment] ME ON ME.[Id] = LD.[MiningEquipmentId]
GROUP BY LD.[Compartimiento]
ORDER BY COUNT(*) DESC;
GO

/* SOBRE EL TYPO, MI RECOMENDACION (con el 165.3 delante, no antes):
   NO normalizarlo en SQL, salvo que el 165.3 muestre que convive con el nombre correcto en los
   mismos equipos. Razones:
   - Si se normaliza en la vista, el sintoma desaparece y la carga lo SIGUE metiendo. El error se
     vuelve invisible, que es como se acumulan los otros cinco que van a Carlos.
   - Fusionar historiales es irreversible de facto: si alguna vez ese nombre correspondiera a otra
     cosa, ya no habria como separarlos.
   - El coste del error hoy es VISIBLE (un componente de mas en la lista), no silencioso. Los
     errores visibles se arreglan; los silenciosos se heredan.
   ⇒ Si el 165.3 muestra que SI convive en el mismo equipo, cambia la cosa: ahi el camion aparece
     con tres motores de traccion y eso ya engana al que lo lee. En ese caso si vale una
     normalizacion, pero DECLARADA en el codigo y con fecha, no silenciosa. */
