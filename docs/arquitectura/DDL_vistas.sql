/* ⚠ FUENTES EXTERNAS DE GERENCIA (23/09/2026) — leer antes de tocar formato o limites:
   - Formato de las tablas (orden y agrupacion de parametros POR COMPONENTE):
       docs/arquitectura/FORMATO_POR_COMPONENTE.md
   - Limites completos (fallback cuando [Eqpcare].[lc] no tiene fila):
       docs/arquitectura/LIMITES_FALLBACK.md  +  docs/arquitectura/DDL_vw_LimitesFallback.sql
   ⚠ Los aditivos (Ca, Zn, P, Mg, B) y el TBN tienen limite INVERTIDO: la alerta es por DEBAJO. */

/* ============================================================================
   KomfIA — VISTAS (archivo único v5: cadena completa de 13 vistas; 23-jun-2026 (HorasComponente vía JOIN pre-rankeado; fundación con VENTANA 12 MESES))
   Base: bd_kmmp_osconfiabilidad (Azure SQL)

   QUÉ AGREGA (para la "matriz única" definida por el área):
   - Ca_ppm y Zn_ppm (grupo CONTAMINANTES junto a Si) con sus límites CALCIO/ZINC de [lc]
     y Estado_Ca / Estado_Zn informativos.
   - HorasA y HorasB (passthrough): candidatos a "Horas del componente" pedido por el área
     (verificar con la query al final cuál corresponde; mientras tanto no se muestran).
   IMPORTANTE: Estado_General NO cambia (Ca/Zn/B/P quedan informativos hasta que el área
   valide que deban disparar observados) → el triage actual NO se altera.

   POR QUÉ se re-crean TODAS las vistas de la cadena: las derivadas usan SELECT * y
   SQL Server CONGELA las columnas de una vista al crearla; al agregar columnas a la
   fundación hay que refrescar las derivadas (CREATE OR ALTER las re-captura).

   ORDEN DE DEPENDENCIAS (este archivo, de corrido con F5):
     1) vw_LimitesPorComponente  2) vw_MuestrasEstado  3) vw_MuestrasRankeadas
     4) vw_UltimoAnalisisAceite  5) vw_EstadoActualMT  6) vw_ObservadosFlota (barrido + HorasComponente)
     7) vw_ObservadosResumen (RESUMEN barrido, 1 fila/equipo)  8) vw_ObservadosDetalle (DETALLE barrido, ligero)
     9) vw_UltimoAnalisisFlota (DIAGNÓSTICO por equipo: vw_UltimoAnalisisAceite + Hor. Comp. de HsCc)
    10) vw_TendenciaElemento (TENDENCIA: detalle por elemento PASO 2, pre-formateado d1..d6 + chip)
    11) vw_HistorialMuestra (HISTORIAL muestra por muestra, 2 meses, pre-formateado por fila)
    12) vw_DiagnosticoEquipo (DIAGNÓSTICO por equipo, pre-formateado con chip :C/:P)
    13) vw_HistorialFlotaObs (HISTORIAL OBSERVADOS DE FLOTA, variante 5, agregado por fecha, 30 días).
   Todo CREATE OR ALTER (reversible). Junto con DDL_indices.sql cubren toda la capa de vistas.
   ============================================================================ */
GO


/* ==== vw_FormatoParametro (bloque C: QUE parametros se muestran, en que grupo y en que orden) ====
   Fuente: docs/gerencia/Requerimientos Analisis Aceite 1.xlsx (hojas MT / RD / SH / MODI), 23/09/2026.
   Antes esto vivia DUPLICADO en 4 sitios (vw_TendenciaElemento, vw_DiagnosticoMD, vw_CondicionMT_MD y,
   hardcodeado fila por fila, vw_UltimoAnalisisMD). Aqui hay UNA sola definicion.

   Se listan TODOS los parametros de cada hoja del Excel, tambien los que la BD no mide (pedido del
   usuario 24/09: 'todos esos campos han de aparecer'). Disponible = 0 marca los que no tienen fuente en
   [Oil].[LaboratoryData] (V40, TAN, Oxidacion, Sulfatacion, Nitracion, Mo, Agua, Hollin, Diesel,
   Refrigerante, ISO 4/6/14 um): la fila aparece con '—' en vez de desaparecer, porque su ausencia tambien
   es informacion para el area.

   Inv = 1 -> limite INVERTIDO: la alerta es por DEBAJO (el aditivo se agota). Se deduce del GRUPO, no del
   dato: Aditivos + TBN. ⛔ NO derivarlo de 'LP > LC' aunque el dato lo respalde en general -- el archivo de
   gerencia trae un typo (CERRO VERDE / MOTOR DE TRACCION LH / 980E: Pb LP=2 LC=1) y el bucket 'OTRO'
   produce inversiones artificiales al colapsar componentes distintos con MIN(). Derivarlo del dato
   importaria esos dos defectos; deducirlo del grupo no. (Verificado: BLOQUE 104.)

   Inf = 1 -> parametro INFORMATIVO: se muestra pero no dispara estado. Se conserva el criterio vigente
   (K, Na, B, y Ca/Zn/Mg cuando son CONTAMINANTES, o sea en TRACCION). Los mismos Ca/Zn/Mg cuando son
   ADITIVOS (RUEDA/HIDRAULICO/MOTOR/...) pasan a juzgarse con Inv=1: ese es el arreglo del bloque C2.

   ⛔⛔ REGLA PERMANENTE DE 'Inf' -- NO SE NEGOCIA, la fijo el usuario y la reitero el 29/09:
       'Inf' ES UN CRITERIO DE CONTEO, NO UNA ETIQUETA VISIBLE.
       Un parametro con Inf = 1 se muestra EXACTAMENTE IGUAL que los demas -- su nombre y su valor --
       y lo unico que cambia es que NO entra al contador de observados.
       JAMAS escribir '(inf)', 'inf', '(informativo)' ni ninguna marca al lado del parametro en una
       salida que lea una persona. Ya paso una vez, se quito, y quedo que no vuelve a pasar.
       Si hace falta explicar por que el contador no cuadra con lo que se ve, va en el PIE de la
       tabla, una sola vez, en prosa -- nunca pegado al dato.

   CompTipo '(CRUZADO)' = la UNION de los 4 formatos (31 filas), para la tabla de /diagcompleto, que es
   parametros x COMPONENTES y no puede seguir el formato de uno solo. Solo 4 parametros cambian de grupo
   entre hojas -- Ca, Mg, Mo y Zn: Contaminacion en MT y Aditivos en las otras tres -- y aqui van como
   ADITIVOS, que es su grupo en 3 de las 4 hojas y en 4 de las 6 columnas de un camion tipico. La tabla
   lleva un pie que lo aclara. Aprobado por el usuario el 24/09.
   ⚠ En '(CRUZADO)' el Inv/Inf NO se usa para evaluar: /diagcompleto pinta celdas que ya vienen con su
   estado desde vw_DiagnosticoEquipo, calculado POR COMPONENTE. Aqui el formato solo ordena y agrupa.

   ⚠ MANDO, TRANSMISION y OTRO no tienen hoja propia en el Excel: usan el formato de RUEDA (cajas de
   engranajes). SUPUESTO nuestro. 'OTRO' ademas no recibe limites aguas abajo (guard anti-colision). */
CREATE OR ALTER VIEW [dbo].[vw_FormatoParametro] AS
SELECT CompTipo, Parametro, Grupo, GrupoOrden, Orden, Inv, Inf, Disponible
FROM (VALUES
    (N'TRACCION', N'V100', N'Salud', 1, 1, 0, 0, 1),
    (N'TRACCION', N'V40', N'Salud', 1, 2, 0, 0, 0),
    (N'TRACCION', N'P', N'Aditivos', 2, 3, 1, 0, 1),
    (N'TRACCION', N'B', N'Aditivos', 2, 4, 1, 1, 1),
    (N'TRACCION', N'Si', N'Contaminacion', 3, 5, 0, 0, 1),
    (N'TRACCION', N'Na', N'Contaminacion', 3, 6, 0, 1, 1),
    (N'TRACCION', N'K', N'Contaminacion', 3, 7, 0, 1, 1),
    (N'TRACCION', N'Ca', N'Contaminacion', 3, 8, 0, 1, 1),
    (N'TRACCION', N'Zn', N'Contaminacion', 3, 9, 0, 1, 1),
    (N'TRACCION', N'Mg', N'Contaminacion', 3, 10, 0, 1, 1),
    (N'TRACCION', N'Mo', N'Contaminacion', 3, 11, 0, 0, 0),
    (N'TRACCION', N'Agua', N'Contaminacion', 3, 12, 0, 0, 0),
    (N'TRACCION', N'Fe', N'Desgaste', 4, 13, 0, 0, 1),
    (N'TRACCION', N'PQ', N'Desgaste', 4, 14, 0, 0, 1),
    (N'TRACCION', N'Cr', N'Desgaste', 4, 15, 0, 0, 1),
    (N'TRACCION', N'Ni', N'Desgaste', 4, 16, 0, 0, 1),
    (N'TRACCION', N'Cu', N'Desgaste', 4, 17, 0, 0, 1),
    (N'TRACCION', N'Pb', N'Desgaste', 4, 18, 0, 0, 1),
    (N'TRACCION', N'Sn', N'Desgaste', 4, 19, 0, 0, 1),
    (N'TRACCION', N'Al', N'Desgaste', 4, 20, 0, 0, 1),
    (N'TRACCION', N'ISO>4', N'Codigo Limpieza', 5, 21, 0, 0, 0),
    (N'TRACCION', N'ISO>6', N'Codigo Limpieza', 5, 22, 0, 0, 0),
    (N'TRACCION', N'ISO>14', N'Codigo Limpieza', 5, 23, 0, 0, 0),
    (N'RUEDA', N'V100', N'Salud', 1, 1, 0, 0, 1),
    (N'RUEDA', N'V40', N'Salud', 1, 2, 0, 0, 0),
    (N'RUEDA', N'TAN', N'Salud', 1, 3, 0, 0, 0),
    (N'RUEDA', N'Oxidacion', N'Salud', 1, 4, 0, 0, 0),
    (N'RUEDA', N'Ca', N'Aditivos', 2, 5, 1, 0, 1),
    (N'RUEDA', N'Zn', N'Aditivos', 2, 6, 1, 0, 1),
    (N'RUEDA', N'P', N'Aditivos', 2, 7, 1, 0, 1),
    (N'RUEDA', N'Mg', N'Aditivos', 2, 8, 1, 0, 1),
    (N'RUEDA', N'Mo', N'Aditivos', 2, 9, 1, 0, 0),
    (N'RUEDA', N'B', N'Aditivos', 2, 10, 1, 1, 1),
    (N'RUEDA', N'Si', N'Contaminacion', 3, 11, 0, 0, 1),
    (N'RUEDA', N'Na', N'Contaminacion', 3, 12, 0, 1, 1),
    (N'RUEDA', N'K', N'Contaminacion', 3, 13, 0, 1, 1),
    (N'RUEDA', N'Agua', N'Contaminacion', 3, 14, 0, 0, 0),
    (N'RUEDA', N'Fe', N'Desgaste', 4, 15, 0, 0, 1),
    (N'RUEDA', N'PQ', N'Desgaste', 4, 16, 0, 0, 1),
    (N'RUEDA', N'Al', N'Desgaste', 4, 17, 0, 0, 1),
    (N'RUEDA', N'Cr', N'Desgaste', 4, 18, 0, 0, 1),
    (N'RUEDA', N'Ni', N'Desgaste', 4, 19, 0, 0, 1),
    (N'RUEDA', N'Cu', N'Desgaste', 4, 20, 0, 0, 1),
    (N'RUEDA', N'Pb', N'Desgaste', 4, 21, 0, 0, 1),
    (N'RUEDA', N'Sn', N'Desgaste', 4, 22, 0, 0, 1),
    (N'RUEDA', N'ISO>4', N'Codigo Limpieza', 5, 23, 0, 0, 0),
    (N'RUEDA', N'ISO>6', N'Codigo Limpieza', 5, 24, 0, 0, 0),
    (N'RUEDA', N'ISO>14', N'Codigo Limpieza', 5, 25, 0, 0, 0),
    (N'HIDRAULICO', N'V100', N'Salud', 1, 1, 0, 0, 1),
    (N'HIDRAULICO', N'V40', N'Salud', 1, 2, 0, 0, 0),
    (N'HIDRAULICO', N'TAN', N'Salud', 1, 3, 0, 0, 0),
    (N'HIDRAULICO', N'Oxidacion', N'Salud', 1, 4, 0, 0, 0),
    (N'HIDRAULICO', N'Ca', N'Aditivos', 2, 5, 1, 0, 1),
    (N'HIDRAULICO', N'Zn', N'Aditivos', 2, 6, 1, 0, 1),
    (N'HIDRAULICO', N'P', N'Aditivos', 2, 7, 1, 0, 1),
    (N'HIDRAULICO', N'Mg', N'Aditivos', 2, 8, 1, 0, 1),
    (N'HIDRAULICO', N'Mo', N'Aditivos', 2, 9, 1, 0, 0),
    (N'HIDRAULICO', N'B', N'Aditivos', 2, 10, 1, 1, 1),
    (N'HIDRAULICO', N'Si', N'Contaminacion', 3, 11, 0, 0, 1),
    (N'HIDRAULICO', N'Na', N'Contaminacion', 3, 12, 0, 1, 1),
    (N'HIDRAULICO', N'K', N'Contaminacion', 3, 13, 0, 1, 1),
    (N'HIDRAULICO', N'Agua', N'Contaminacion', 3, 14, 0, 0, 0),
    (N'HIDRAULICO', N'Fe', N'Desgaste', 4, 15, 0, 0, 1),
    (N'HIDRAULICO', N'PQ', N'Desgaste', 4, 16, 0, 0, 1),
    (N'HIDRAULICO', N'Al', N'Desgaste', 4, 17, 0, 0, 1),
    (N'HIDRAULICO', N'Cr', N'Desgaste', 4, 18, 0, 0, 1),
    (N'HIDRAULICO', N'Ni', N'Desgaste', 4, 19, 0, 0, 1),
    (N'HIDRAULICO', N'Cu', N'Desgaste', 4, 20, 0, 0, 1),
    (N'HIDRAULICO', N'Pb', N'Desgaste', 4, 21, 0, 0, 1),
    (N'HIDRAULICO', N'Sn', N'Desgaste', 4, 22, 0, 0, 1),
    (N'HIDRAULICO', N'ISO>4', N'Codigo Limpieza', 5, 23, 0, 0, 0),
    (N'HIDRAULICO', N'ISO>6', N'Codigo Limpieza', 5, 24, 0, 0, 0),
    (N'HIDRAULICO', N'ISO>14', N'Codigo Limpieza', 5, 25, 0, 0, 0),
    (N'MOTOR', N'V100', N'Salud', 1, 1, 0, 0, 1),
    (N'MOTOR', N'V40', N'Salud', 1, 2, 0, 0, 0),
    (N'MOTOR', N'TBN', N'Salud', 1, 3, 1, 0, 1),
    (N'MOTOR', N'Oxidacion', N'Salud', 1, 4, 0, 0, 0),
    (N'MOTOR', N'Sulfatacion', N'Salud', 1, 5, 0, 0, 0),
    (N'MOTOR', N'Nitracion', N'Salud', 1, 6, 0, 0, 0),
    (N'MOTOR', N'Ca', N'Aditivos', 2, 7, 1, 0, 1),
    (N'MOTOR', N'Zn', N'Aditivos', 2, 8, 1, 0, 1),
    (N'MOTOR', N'P', N'Aditivos', 2, 9, 1, 0, 1),
    (N'MOTOR', N'Mg', N'Aditivos', 2, 10, 1, 0, 1),
    (N'MOTOR', N'Mo', N'Aditivos', 2, 11, 1, 0, 0),
    (N'MOTOR', N'B', N'Aditivos', 2, 12, 1, 1, 1),
    (N'MOTOR', N'Si', N'Contaminacion', 3, 13, 0, 0, 1),
    (N'MOTOR', N'Na', N'Contaminacion', 3, 14, 0, 1, 1),
    (N'MOTOR', N'K', N'Contaminacion', 3, 15, 0, 1, 1),
    (N'MOTOR', N'Hollin', N'Contaminacion', 3, 16, 0, 0, 0),
    (N'MOTOR', N'Diesel', N'Contaminacion', 3, 17, 0, 0, 0),
    (N'MOTOR', N'Agua', N'Contaminacion', 3, 18, 0, 0, 0),
    (N'MOTOR', N'Refrigerante', N'Contaminacion', 3, 19, 0, 0, 0),
    (N'MOTOR', N'Fe', N'Desgaste', 4, 20, 0, 0, 1),
    (N'MOTOR', N'PQ', N'Desgaste', 4, 21, 0, 0, 1),
    (N'MOTOR', N'Cr', N'Desgaste', 4, 22, 0, 0, 1),
    (N'MOTOR', N'Ni', N'Desgaste', 4, 23, 0, 0, 1),
    (N'MOTOR', N'Al', N'Desgaste', 4, 24, 0, 0, 1),
    (N'MOTOR', N'Cu', N'Desgaste', 4, 25, 0, 0, 1),
    (N'MOTOR', N'Pb', N'Desgaste', 4, 26, 0, 0, 1),
    (N'MOTOR', N'Sn', N'Desgaste', 4, 27, 0, 0, 1),
    (N'MANDO', N'V100', N'Salud', 1, 1, 0, 0, 1),
    (N'MANDO', N'V40', N'Salud', 1, 2, 0, 0, 0),
    (N'MANDO', N'TAN', N'Salud', 1, 3, 0, 0, 0),
    (N'MANDO', N'Oxidacion', N'Salud', 1, 4, 0, 0, 0),
    (N'MANDO', N'Ca', N'Aditivos', 2, 5, 1, 0, 1),
    (N'MANDO', N'Zn', N'Aditivos', 2, 6, 1, 0, 1),
    (N'MANDO', N'P', N'Aditivos', 2, 7, 1, 0, 1),
    (N'MANDO', N'Mg', N'Aditivos', 2, 8, 1, 0, 1),
    (N'MANDO', N'Mo', N'Aditivos', 2, 9, 1, 0, 0),
    (N'MANDO', N'B', N'Aditivos', 2, 10, 1, 1, 1),
    (N'MANDO', N'Si', N'Contaminacion', 3, 11, 0, 0, 1),
    (N'MANDO', N'Na', N'Contaminacion', 3, 12, 0, 1, 1),
    (N'MANDO', N'K', N'Contaminacion', 3, 13, 0, 1, 1),
    (N'MANDO', N'Agua', N'Contaminacion', 3, 14, 0, 0, 0),
    (N'MANDO', N'Fe', N'Desgaste', 4, 15, 0, 0, 1),
    (N'MANDO', N'PQ', N'Desgaste', 4, 16, 0, 0, 1),
    (N'MANDO', N'Al', N'Desgaste', 4, 17, 0, 0, 1),
    (N'MANDO', N'Cr', N'Desgaste', 4, 18, 0, 0, 1),
    (N'MANDO', N'Ni', N'Desgaste', 4, 19, 0, 0, 1),
    (N'MANDO', N'Cu', N'Desgaste', 4, 20, 0, 0, 1),
    (N'MANDO', N'Pb', N'Desgaste', 4, 21, 0, 0, 1),
    (N'MANDO', N'Sn', N'Desgaste', 4, 22, 0, 0, 1),
    (N'MANDO', N'ISO>4', N'Codigo Limpieza', 5, 23, 0, 0, 0),
    (N'MANDO', N'ISO>6', N'Codigo Limpieza', 5, 24, 0, 0, 0),
    (N'MANDO', N'ISO>14', N'Codigo Limpieza', 5, 25, 0, 0, 0),
    (N'TRANSMISION', N'V100', N'Salud', 1, 1, 0, 0, 1),
    (N'TRANSMISION', N'V40', N'Salud', 1, 2, 0, 0, 0),
    (N'TRANSMISION', N'TAN', N'Salud', 1, 3, 0, 0, 0),
    (N'TRANSMISION', N'Oxidacion', N'Salud', 1, 4, 0, 0, 0),
    (N'TRANSMISION', N'Ca', N'Aditivos', 2, 5, 1, 0, 1),
    (N'TRANSMISION', N'Zn', N'Aditivos', 2, 6, 1, 0, 1),
    (N'TRANSMISION', N'P', N'Aditivos', 2, 7, 1, 0, 1),
    (N'TRANSMISION', N'Mg', N'Aditivos', 2, 8, 1, 0, 1),
    (N'TRANSMISION', N'Mo', N'Aditivos', 2, 9, 1, 0, 0),
    (N'TRANSMISION', N'B', N'Aditivos', 2, 10, 1, 1, 1),
    (N'TRANSMISION', N'Si', N'Contaminacion', 3, 11, 0, 0, 1),
    (N'TRANSMISION', N'Na', N'Contaminacion', 3, 12, 0, 1, 1),
    (N'TRANSMISION', N'K', N'Contaminacion', 3, 13, 0, 1, 1),
    (N'TRANSMISION', N'Agua', N'Contaminacion', 3, 14, 0, 0, 0),
    (N'TRANSMISION', N'Fe', N'Desgaste', 4, 15, 0, 0, 1),
    (N'TRANSMISION', N'PQ', N'Desgaste', 4, 16, 0, 0, 1),
    (N'TRANSMISION', N'Al', N'Desgaste', 4, 17, 0, 0, 1),
    (N'TRANSMISION', N'Cr', N'Desgaste', 4, 18, 0, 0, 1),
    (N'TRANSMISION', N'Ni', N'Desgaste', 4, 19, 0, 0, 1),
    (N'TRANSMISION', N'Cu', N'Desgaste', 4, 20, 0, 0, 1),
    (N'TRANSMISION', N'Pb', N'Desgaste', 4, 21, 0, 0, 1),
    (N'TRANSMISION', N'Sn', N'Desgaste', 4, 22, 0, 0, 1),
    (N'TRANSMISION', N'ISO>4', N'Codigo Limpieza', 5, 23, 0, 0, 0),
    (N'TRANSMISION', N'ISO>6', N'Codigo Limpieza', 5, 24, 0, 0, 0),
    (N'TRANSMISION', N'ISO>14', N'Codigo Limpieza', 5, 25, 0, 0, 0),
    (N'OTRO', N'V100', N'Salud', 1, 1, 0, 0, 1),
    (N'OTRO', N'V40', N'Salud', 1, 2, 0, 0, 0),
    (N'OTRO', N'TAN', N'Salud', 1, 3, 0, 0, 0),
    (N'OTRO', N'Oxidacion', N'Salud', 1, 4, 0, 0, 0),
    (N'OTRO', N'Ca', N'Aditivos', 2, 5, 1, 0, 1),
    (N'OTRO', N'Zn', N'Aditivos', 2, 6, 1, 0, 1),
    (N'OTRO', N'P', N'Aditivos', 2, 7, 1, 0, 1),
    (N'OTRO', N'Mg', N'Aditivos', 2, 8, 1, 0, 1),
    (N'OTRO', N'Mo', N'Aditivos', 2, 9, 1, 0, 0),
    (N'OTRO', N'B', N'Aditivos', 2, 10, 1, 1, 1),
    (N'OTRO', N'Si', N'Contaminacion', 3, 11, 0, 0, 1),
    (N'OTRO', N'Na', N'Contaminacion', 3, 12, 0, 1, 1),
    (N'OTRO', N'K', N'Contaminacion', 3, 13, 0, 1, 1),
    (N'OTRO', N'Agua', N'Contaminacion', 3, 14, 0, 0, 0),
    (N'OTRO', N'Fe', N'Desgaste', 4, 15, 0, 0, 1),
    (N'OTRO', N'PQ', N'Desgaste', 4, 16, 0, 0, 1),
    (N'OTRO', N'Al', N'Desgaste', 4, 17, 0, 0, 1),
    (N'OTRO', N'Cr', N'Desgaste', 4, 18, 0, 0, 1),
    (N'OTRO', N'Ni', N'Desgaste', 4, 19, 0, 0, 1),
    (N'OTRO', N'Cu', N'Desgaste', 4, 20, 0, 0, 1),
    (N'OTRO', N'Pb', N'Desgaste', 4, 21, 0, 0, 1),
    (N'OTRO', N'Sn', N'Desgaste', 4, 22, 0, 0, 1),
    (N'OTRO', N'ISO>4', N'Codigo Limpieza', 5, 23, 0, 0, 0),
    (N'OTRO', N'ISO>6', N'Codigo Limpieza', 5, 24, 0, 0, 0),
    (N'OTRO', N'ISO>14', N'Codigo Limpieza', 5, 25, 0, 0, 0),
    (N'(CRUZADO)', N'V100', N'Salud', 1, 1, 0, 0, 1),
    (N'(CRUZADO)', N'V40', N'Salud', 1, 2, 0, 0, 0),
    (N'(CRUZADO)', N'TAN', N'Salud', 1, 3, 0, 0, 0),
    (N'(CRUZADO)', N'TBN', N'Salud', 1, 4, 1, 0, 1),
    (N'(CRUZADO)', N'Oxidacion', N'Salud', 1, 5, 0, 0, 0),
    (N'(CRUZADO)', N'Sulfatacion', N'Salud', 1, 6, 0, 0, 0),
    (N'(CRUZADO)', N'Nitracion', N'Salud', 1, 7, 0, 0, 0),
    (N'(CRUZADO)', N'Ca', N'Aditivos', 2, 8, 1, 0, 1),
    (N'(CRUZADO)', N'Zn', N'Aditivos', 2, 9, 1, 0, 1),
    (N'(CRUZADO)', N'P', N'Aditivos', 2, 10, 1, 0, 1),
    (N'(CRUZADO)', N'Mg', N'Aditivos', 2, 11, 1, 0, 1),
    (N'(CRUZADO)', N'Mo', N'Aditivos', 2, 12, 1, 0, 0),
    (N'(CRUZADO)', N'B', N'Aditivos', 2, 13, 1, 1, 1),
    (N'(CRUZADO)', N'Si', N'Contaminacion', 3, 14, 0, 0, 1),
    (N'(CRUZADO)', N'Na', N'Contaminacion', 3, 15, 0, 1, 1),
    (N'(CRUZADO)', N'K', N'Contaminacion', 3, 16, 0, 1, 1),
    (N'(CRUZADO)', N'Hollin', N'Contaminacion', 3, 17, 0, 0, 0),
    (N'(CRUZADO)', N'Diesel', N'Contaminacion', 3, 18, 0, 0, 0),
    (N'(CRUZADO)', N'Agua', N'Contaminacion', 3, 19, 0, 0, 0),
    (N'(CRUZADO)', N'Refrigerante', N'Contaminacion', 3, 20, 0, 0, 0),
    (N'(CRUZADO)', N'Fe', N'Desgaste', 4, 21, 0, 0, 1),
    (N'(CRUZADO)', N'PQ', N'Desgaste', 4, 22, 0, 0, 1),
    (N'(CRUZADO)', N'Cr', N'Desgaste', 4, 23, 0, 0, 1),
    (N'(CRUZADO)', N'Ni', N'Desgaste', 4, 24, 0, 0, 1),
    (N'(CRUZADO)', N'Al', N'Desgaste', 4, 25, 0, 0, 1),
    (N'(CRUZADO)', N'Cu', N'Desgaste', 4, 26, 0, 0, 1),
    (N'(CRUZADO)', N'Pb', N'Desgaste', 4, 27, 0, 0, 1),
    (N'(CRUZADO)', N'Sn', N'Desgaste', 4, 28, 0, 0, 1),
    (N'(CRUZADO)', N'ISO>4', N'Codigo Limpieza', 5, 29, 0, 0, 0),
    (N'(CRUZADO)', N'ISO>6', N'Codigo Limpieza', 5, 30, 0, 0, 0),
    (N'(CRUZADO)', N'ISO>14', N'Codigo Limpieza', 5, 31, 0, 0, 0)
) v(CompTipo, Parametro, Grupo, GrupoOrden, Orden, Inv, Inf, Disponible);
GO

/* ============================================================================
   vw_InvPorComponente -- G1 (29/09). 7 filas: por CompTipo, si cada aditivo lleva el limite
   INVERTIDO (la alerta es por DEBAJO porque el aditivo se agota).

   POR QUE EXISTE. En el bloque D (28/09) escribi la direccion de Ca/Zn/Mg/B/P/Mo deduciendola
   DEL DATO -- 'si lim.X_LP > lim.X_LC entonces esta invertido'. La cabecera de
   vw_FormatoParametro ya advertia, con el BLOQUE 104 detras, que eso NO se hace: el archivo de
   gerencia trae typos y el bucket 'OTRO' fabrica inversiones artificiales al colapsar
   componentes distintos con MIN(). Lei el aviso despues de que el dato me lo demostrara.

   LO QUE COSTO (BLOQUE 159.4): en Antamina las 102 ruedas con Ca entre 3 006 y 4 264 ppm salian
   CRITICAS contra un LC de 2 250. Como ahi el par LP/LC no viene invertido, el CASE caia al ramo
   de CONTAMINANTE y las reprobaba por tener DEMASIADO calcio -- cuando en una rueda el Ca es un
   ADITIVO y 3 000 ppm es exactamente lo normal (Cerro Verde corre 3 690, Toromocho 2 832).
   164 falsos criticos de un solo parametro.

   La direccion es una propiedad del GRUPO (Aditivos -> invertido), no del par de numeros que
   alguien cargo. Aqui se lee de una sola fuente: vw_FormatoParametro.
   ---------------------------------------------------------------------------- */
CREATE OR ALTER VIEW [dbo].[vw_InvPorComponente] AS
SELECT CompTipo,
       MAX(CASE WHEN Parametro = N'Ca' THEN Inv END) AS Ca_Inv,
       MAX(CASE WHEN Parametro = N'Zn' THEN Inv END) AS Zn_Inv,
       MAX(CASE WHEN Parametro = N'Mg' THEN Inv END) AS Mg_Inv,
       MAX(CASE WHEN Parametro = N'B'  THEN Inv END) AS B_Inv,
       MAX(CASE WHEN Parametro = N'P'  THEN Inv END) AS P_Inv,
       MAX(CASE WHEN Parametro = N'Mo' THEN Inv END) AS Mo_Inv
FROM [dbo].[vw_FormatoParametro]
WHERE CompTipo <> N'(CRUZADO)'
GROUP BY CompTipo;
GO

/* ----------------------------------------------------------------------------
   1) vw_LimitesPorComponente — los 31 parametros del formato (D2, 28/09)
   ----------------------------------------------------------------------------
   Antes leia 16 de los 38 pares LP/LC que trae [Eqpcare].[lc]. Los 22 que
   faltaban son justo los que Carlos senalaba como "aca no sale el limite":
   FOSFORO, BORO, MOLIBDENO, TAN, OXI, SULF, NIT, HOLLIN, H20, Diesel,
   ISO 4/6/14, VISC40 y el LC del TBN. El dato estaba; faltaba leerlo.

   REGLA DE AGREGACION (el GROUP BY colapsa LH/RH en un solo CompTipo):
     - limite NORMAL  (alerta por ARRIBA)  -> MIN = el mas estricto
     - limite INVERTIDO (alerta por DEBAJO: aditivos, TBN y los pisos de
       viscosidad LPI/LCI) -> MAX = el mas estricto
   ⚠ Ca, Zn y Mg cambian de sentido segun el componente (contaminantes en MT,
     aditivos en el resto). Ver la nota en su bloque: se agregan con MIN porque el
     bloque 138.1 midio que LH y RH traen valores IDENTICOS.
   La normalizacion de claves se hace en la subconsulta 'src' para no repetir el
   CASE de CompTipo tres veces (era el patron anterior y se prestaba a que el
   SELECT y el GROUP BY se desincronizaran).
   ---------------------------------------------------------------------------- */
CREATE OR ALTER VIEW [dbo].[vw_LimitesPorComponente] AS
SELECT
    src.ProyKey, src.ModeloKey, src.CompTipo,

    /* ---- Desgaste y contaminacion: limite normal -> MIN ---- */
    MIN(src.[FIERRO - LP])  AS Fe_LP, MIN(src.[FIERRO - LC])  AS Fe_LC,
    MIN(src.[CROMO - LP])   AS Cr_LP, MIN(src.[CROMO - LC])   AS Cr_LC,
    MIN(src.[NIQUEL - LP])  AS Ni_LP, MIN(src.[NIQUEL - LC])  AS Ni_LC,
    MIN(src.[COBRE - LP])   AS Cu_LP, MIN(src.[COBRE - LC])   AS Cu_LC,
    MIN(src.[SILICIO - LP]) AS Si_LP, MIN(src.[SILICIO - LC]) AS Si_LC,
    MIN(src.[ALUMINIO - LP])AS Al_LP, MIN(src.[ALUMINIO - LC])AS Al_LC,
    MIN(src.[POTASIO - LP]) AS K_LP,  MIN(src.[POTASIO - LC]) AS K_LC,
    MIN(src.[SODIO - LP])   AS Na_LP, MIN(src.[SODIO - LC])   AS Na_LC,
    MIN(src.[PLOMO - LP])   AS Pb_LP, MIN(src.[PLOMO - LC])   AS Pb_LC,
    MIN(src.[ESTAÑO - LP])  AS Sn_LP, MIN(src.[ESTAÑO - LC])  AS Sn_LC,
    MIN(src.[PQ - LP])      AS PQ_LP, MIN(src.[PQ - LC])      AS PQ_LC,

    /* ---- NUEVOS (D2) · normales -> MIN ---- */
    MIN(src.[TAN - LP])     AS TAN_LP,    MIN(src.[TAN - LC])     AS TAN_LC,
    MIN(src.[OXI - LP])     AS Oxi_LP,    MIN(src.[OXI - LC])     AS Oxi_LC,
    MIN(src.[SULF - LP])    AS Sulf_LP,   MIN(src.[SULF - LC])    AS Sulf_LC,
    MIN(src.[NIT - LP])     AS Nit_LP,    MIN(src.[NIT - LC])     AS Nit_LC,
    MIN(src.[HOLLIN - LP])  AS Hollin_LP, MIN(src.[HOLLIN - LC])  AS Hollin_LC,
    MIN(src.[H20 - LP])     AS Agua_LP,   MIN(src.[H20 - LC])     AS Agua_LC,
    MIN(src.[Diesel - LP])  AS Diesel_LP, MIN(src.[Diesel - LC])  AS Diesel_LC,
    MIN(src.[ISO 4um - LP]) AS ISO4_LP,   MIN(src.[ISO 4um - LC]) AS ISO4_LC,
    MIN(src.[ISO 6um - LP]) AS ISO6_LP,   MIN(src.[ISO 6um - LC]) AS ISO6_LC,
    MIN(src.[ISO 14um - LP])AS ISO14_LP,  MIN(src.[ISO 14um - LC])AS ISO14_LC,

    /* ---- Aditivos: limite INVERTIDO (la alerta es por DEBAJO) -> MAX ---- */
    MAX(src.[FOSFORO - LP])  AS P_LP,   MAX(src.[FOSFORO - LC])  AS P_LC,
    MAX(src.[BORO - LP])     AS B_LP,   MAX(src.[BORO - LC])     AS B_LC,
    MAX(src.[MOLIBDENO - LP])AS Mo_LP,  MAX(src.[MOLIBDENO - LC])AS Mo_LC,
    MAX(src.[TBN - LP])      AS TBN_LP, MAX(src.[TBN - LC])      AS TBN_LC,

    /* ---- Ca, Zn, Mg ----
       Cambian de sentido segun el componente (contaminantes en MT, aditivos en el resto),
       asi que en teoria su agregado deberia depender de eso. Se escribio primero con un
       CASE-sobre-agregado (CASE WHEN EsMT THEN MIN ELSE MAX) y se quito el 28/09 por dos
       razones: (1) el bloque 138.1 midio que LH y RH traen valores IDENTICOS, o sea que MIN
       y MAX dan lo mismo y el CASE no cambiaba ni un numero; (2) complicaba el agregado y
       obligaba a meter EsMT en el GROUP BY.
       ⚑ Si algun dia lc cargara LH y RH distintos, hay que volver a mirarlo: el sentido
       correcto esta en vw_FormatoParametro.Inv, y la fundacion ya lo deduce sola por fila
       con la regla "LP > LC -> invertido". ---- */
    MIN(src.[CALCIO - LP])   AS Ca_LP, MIN(src.[CALCIO - LC])   AS Ca_LC,
    MIN(src.[ZINC - LP])     AS Zn_LP, MIN(src.[ZINC - LC])     AS Zn_LC,
    MIN(src.[MAGNESIO - LP]) AS Mg_LP, MIN(src.[MAGNESIO - LC]) AS Mg_LC,

    /* ---- Viscosidad: es una BANDA de 4 niveles, no un limite.
       Pisos  (LPI/LCI) = alerta por DEBAJO -> MAX es el mas estricto.
       Techos (LPS/LCS) = alerta por ENCIMA -> MIN es el mas estricto.
       Medido: MT trae solo LCI/LCS (Carlos: "para el MT solo el critico, no
       trabaja con el precautorio"); el MOTOR 980E trae los cuatro. Si un nivel
       viene NULL ese nivel no se evalua: la excepcion NO se hardcodea. ---- */
    MAX(src.[VISC - LPI])   AS V100_LPI, MAX(src.[VISC - LCI])   AS V100_LCI,
    MIN(src.[VISC - LPS])   AS V100_LPS, MIN(src.[VISC - LCS])   AS V100_LCS,
    MAX(src.[VISC40 - LPI]) AS V40_LPI,  MAX(src.[VISC40 - LCI]) AS V40_LCI,
    MIN(src.[VISC40 - LPS]) AS V40_LPS,  MIN(src.[VISC40 - LCS]) AS V40_LCS
FROM (
    SELECT *,
        UPPER(LTRIM(RTRIM([Proyecto]))) AS ProyKey,
        UPPER(LTRIM(RTRIM([MODELO])))   AS ModeloKey,
        CASE
            WHEN [COMPONENTE] LIKE '%TRACCION%'    THEN 'TRACCION'
            WHEN [COMPONENTE] LIKE '%HIDRAUL%'     THEN 'HIDRAULICO'
            WHEN [COMPONENTE] LIKE '%RUEDA%'       THEN 'RUEDA'
            WHEN [COMPONENTE] LIKE '%MANDO%'       THEN 'MANDO'
            WHEN [COMPONENTE] LIKE '%TRANSMISION%' THEN 'TRANSMISION'
            WHEN [COMPONENTE] LIKE '%MOTOR%'       THEN 'MOTOR'
            ELSE 'OTRO'
        END AS CompTipo
    FROM [Eqpcare].[lc]
) src
GROUP BY src.ProyKey, src.ModeloKey, src.CompTipo;
GO


/* ==== vw_ModeloConLimites (bloque L, 28/09) ====
   Que modelos de cada proyecto tienen limites cargados en [Eqpcare].[lc].
   PARA QUE: hoy el rollup '(todos)' de las vistas de flota significa "todos los modelos".
   Carlos pidio que signifique "los modelos que el area tiene aterrizados": en Antapaccay eso
   es 980E, D475A y PC1250, y deja fuera D11T y 797F, que aparecen en la tabla sin un solo
   limite y no se pueden evaluar.
   Es DATA-DRIVEN a proposito: no hay una lista de modelos escrita en ningun sitio, asi que
   el dia que el area cargue otro proyecto o retire un modelo, esto se entera solo.
   Tabla diminuta (lc tiene 64 filas -> ~15 pares distintos): un EXISTS contra esto es gratis. */
/* ⚑ EL ROLLUP '(todos)' YA NO ES "TODOS LOS MODELOS" (L3, 29/09).
   Pasa a ser "los modelos que el area tiene aterrizados", es decir los que tienen fila en
   [Eqpcare].[lc]. Las 9 vistas de flota que expanden con CROSS APPLY consultan esta vista.
   POR QUE: medido en el bloque 147.4, Antapaccay tiene 6 modelos y solo 3 con limites:
       980E (27 eq.) · D475A (5) · PC1250 (4)   |   930E (9) · HD1500 (2) · WA900 (1)
   Los 12 sin limites salen TODOS en verde porque no hay con que evaluarlos -- se ven hoy
   como "### 930E · 18 equipos (0 obs)" en el triage. Es ruido, no salud. Y suelen ser
   equipos que KMMP no gestiona: la mina carga su flota entera, Komatsu o CAT.
   ⛔ Si el usuario NOMBRA un modelo, sale igual aunque no tenga limites: el filtro del flujo
   compara contra la fila por-modelo, que nunca se quita. Solo cambia el DEFAULT.
   Lee [Eqpcare].[lc] DIRECTO (64 filas, sin agregados) y no vw_LimitesPorComponente, que es
   un GROUP BY de 60+ agregados: esto se evalua por fila en vistas de flota. */
CREATE OR ALTER VIEW [dbo].[vw_ModeloConLimites] AS
SELECT DISTINCT UPPER(LTRIM(RTRIM([Proyecto]))) AS ProyKey,
                UPPER(LTRIM(RTRIM([MODELO])))   AS ModeloKey
FROM [Eqpcare].[lc];
GO


/* ----------------------------------------------------------------------------
   2) vw_MuestrasEstado (FUNDACIÓN) — + Ca, Zn (con Estado informativo) + HorasA/HorasB
   ---------------------------------------------------------------------------- */
CREATE OR ALTER VIEW [dbo].[vw_MuestrasEstado] AS
WITH muestras AS (
    SELECT
        ME.[Code]   AS Equipo,
        MP.[Name]   AS Proyecto,
        EF.[Model]  AS Modelo,
        UPPER(LTRIM(RTRIM(MP.[Name])))  AS ProyKey,
        UPPER(LTRIM(RTRIM(EF.[Model]))) AS ModeloKey,
        LD.[MiningEquipmentId],
        /* ⛔ V (29/09) REVERTIDO el 30/09. Aqui se normalizaba 'MOTORO DE TRACCION RH' con un
           CASE. Parecia inocuo y costo 17 MINUTOS en /condicionmt: Compartimiento es la columna
           por la que FILTRA medio sistema ('WHERE Compartimiento LIKE %TRACCION%'), y envolverla
           en un CASE la vuelve CALCULADA -> el predicado deja de bajar y hay que materializar la
           cadena entera antes de filtrar. Es la ley 3 y su corolario, que yo mismo escribi un dia
           antes. El typo se deja VISIBLE y va a Carlos, que era la recomendacion original. */
        LD.[Compartimiento],
        CASE
            WHEN LD.[Compartimiento] LIKE '%TRACCION%'    THEN 'TRACCION'
            WHEN LD.[Compartimiento] LIKE '%HIDRAUL%'     THEN 'HIDRAULICO'
            WHEN LD.[Compartimiento] LIKE '%RUEDA%'       THEN 'RUEDA'
            WHEN LD.[Compartimiento] LIKE '%MANDO%'       THEN 'MANDO'
            WHEN LD.[Compartimiento] LIKE '%TRANSMISION%' THEN 'TRANSMISION'
            WHEN LD.[Compartimiento] LIKE '%MOTOR%'       THEN 'MOTOR'
            ELSE 'OTRO'
        END AS CompTipo,
        CASE WHEN LD.[CM] IN ('DDI','DIALIZADO','RELLENO+DIALIZADO') THEN 1 ELSE 0 END AS EsDDI,
        LD.[FechaMuestreo], LD.[Horometro], LD.[HorasDeAceite],
        LD.[HorasA], LD.[HorasB],            -- candidatos a "Horas del componente" (verificar)
        LD.[CM], LD.[Grado],
        LD.[Fe_ppm], LD.[Cr_ppm], LD.[Ni_ppm], LD.[Cu_ppm], LD.[Pb_ppm], LD.[Sn_ppm],
        LD.[Si_ppm], LD.[Al_ppm], LD.[Ca_ppm], LD.[Zn_ppm], LD.[Na_ppm], LD.[K_ppm], LD.[Mg_ppm], LD.[B_ppm], LD.[P_ppm],
        LD.[Indice_PQ], LD.[TBN], LD.[V100],
        /* D3 (28/09) — los 13 parametros del formato que SIEMPRE estuvieron en la tabla y no se
           leian. FORMATO_POR_COMPONENTE los daba por inexistentes porque se llaman distinto.
           Se renombran aqui al simbolo del formato para no arrastrar dos vocabularios. */
        LD.[Viscosidad40] AS V40,
        LD.[TAN], LD.[Oxidacion], LD.[Sulfatacion], LD.[Nitracion],
        LD.[Mo_ppm], LD.[Agua], LD.[Hollin], LD.[Diesel], LD.[Refrigerante],
        LD.[Iso4406_4] AS ISO4, LD.[Iso4406_6] AS ISO6, LD.[Iso4406_14] AS ISO14,
        LD.[LaboratoryDataId]
    FROM [Oil].[LaboratoryData] LD
    INNER JOIN [Mine].[MiningEquipment] ME ON ME.[Id] = LD.[MiningEquipmentId]
    INNER JOIN [Mine].[MiningProject]   MP ON MP.[Id] = ME.[MiningProjectId]
    INNER JOIN [Mine].[EquipmentFleet]  EF ON EF.[Id] = ME.[EquipmentFleetId]
    /* VENTANA 12 MESES (perf): la fundación rankea sobre 1 año en vez de 9 → corta el full-scan
       del histórico (último de 1 equipo leía la tabla entera, el window function bloquea el pushdown
       del filtro de equipo). Cubre estado actual/último/tendencia(6 muestras)/historial(2 meses).
       Tradeoff aceptado: equipos SIN muestra en 12 meses no aparecen en vistas de estado actual
       (la flota activa se muestrea ~mensual). Para volver al histórico completo: quitar este WHERE. */
    WHERE LD.[FechaMuestreo] >= DATEADD(MONTH, -12, GETDATE())
),
calc AS (
    /* dedup por FECHA: rn_dia=1 = muestra "keeper" del día (mayor LaboratoryDataId);
       date_rank numera FECHAS DISTINTAS (1=más reciente). Así rn_recencia cuenta DÍAS (no filas)
       y las muestras del mismo día (re-tests) no consumen ranking (la tendencia mostraba "3 de 6"). */
    /* PUSHDOWN (30/09): 'Equipo' va en el PARTITION BY. SQL Server solo empuja un filtro por debajo de
       una funcion de ventana si la columna filtrada esta en el PARTITION BY; los flujos filtran por
       Equipo (= ME.Code), no por MiningEquipmentId, asi que cada consulta de UN camion rankeaba los 12
       meses de TODA la flota antes de filtrar (/diagcompleto: 7 lecturas, 76 936 paginas, contra 18 211
       del triage de flota entera). Cada Id tiene un solo Code: las particiones no cambian. */
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY Equipo, MiningEquipmentId, Compartimiento, EsDDI, CAST(FechaMuestreo AS date) ORDER BY LaboratoryDataId DESC) AS rn_dia,
        DENSE_RANK() OVER (PARTITION BY Equipo, MiningEquipmentId, Compartimiento, EsDDI ORDER BY CAST(FechaMuestreo AS date) DESC) AS date_rank
    FROM muestras
)
SELECT
    m.Equipo, m.Proyecto, m.Modelo, m.MiningEquipmentId, m.Compartimiento, m.CompTipo, m.EsDDI,
    m.FechaMuestreo, m.Horometro, m.HorasDeAceite, m.HorasA, m.HorasB, m.CM, m.Grado,

    m.Fe_ppm,  lim.Fe_LP,  lim.Fe_LC,
    CASE WHEN m.Fe_ppm IS NULL THEN 'SIN DATO'
         WHEN m.Fe_ppm > ISNULL(lim.Fe_LC,9999) THEN 'CRITICO'
         WHEN m.Fe_ppm > ISNULL(lim.Fe_LP,9999) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_Fe,

    m.Cr_ppm,  lim.Cr_LP,  lim.Cr_LC,
    CASE WHEN m.Cr_ppm IS NULL THEN 'SIN DATO'
         WHEN m.Cr_ppm > ISNULL(lim.Cr_LC,9999) THEN 'CRITICO'
         WHEN m.Cr_ppm > ISNULL(lim.Cr_LP,9999) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_Cr,

    m.Ni_ppm,  lim.Ni_LP,  lim.Ni_LC,
    CASE WHEN m.Ni_ppm IS NULL THEN 'SIN DATO'
         WHEN m.Ni_ppm > ISNULL(lim.Ni_LC,9999) THEN 'CRITICO'
         WHEN m.Ni_ppm > ISNULL(lim.Ni_LP,9999) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_Ni,

    m.Cu_ppm,  lim.Cu_LP,  lim.Cu_LC,
    CASE WHEN m.Cu_ppm IS NULL THEN 'SIN DATO'
         WHEN m.Cu_ppm > ISNULL(lim.Cu_LC,9999) THEN 'CRITICO'
         WHEN m.Cu_ppm > ISNULL(lim.Cu_LP,9999) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_Cu,

    m.Si_ppm,  lim.Si_LP,  lim.Si_LC,
    CASE WHEN m.Si_ppm IS NULL THEN 'SIN DATO'
         WHEN m.Si_ppm > ISNULL(lim.Si_LC,9999) THEN 'CRITICO'
         WHEN m.Si_ppm > ISNULL(lim.Si_LP,9999) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_Si,

    m.Al_ppm,  lim.Al_LP,  lim.Al_LC,
    CASE WHEN m.Al_ppm IS NULL THEN 'SIN DATO'
         WHEN m.Al_ppm > ISNULL(lim.Al_LC,9999) THEN 'CRITICO'
         WHEN m.Al_ppm > ISNULL(lim.Al_LP,9999) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_Al,

    /* ⛔ G0 (29/09) -- EL 0 NO ES UNA MEDICION, Y ROMPE EN LAS DOS DIRECCIONES.
       Un 0 en la BD significa casi siempre "el laboratorio no reporto esa columna", no "el valor
       es cero". Lo que hace depende del sentido del limite, y los dos casos son malos:
         · Limite INVERTIDO (aditivos): 0 < LC SIEMPRE -> fabrica un critico de la nada.
         · Limite NORMAL (ISO): 0 > LC NUNCA -> el componente sale limpio sin haberse medido.
           Este es el peor de los dos, porque es un FALLO SILENCIOSO: no se ve.
       Estado_TBN ya llevaba esta guarda desde antes ('TBN > 0', lineas ~713/851/881): un TBN de 0
       significa no medido, no base agotada. Los aditivos que entraron en el bloque D (28/09) se
       escribieron SIN ella -- descuido mio, medido en el BLOQUE 158.1.
       La guarda va SOLO en el ramo invertido: para un CONTAMINANTE un 0 si es una lectura valida
       y legitima ("no hay contaminacion"), y ahi no se toca.
       Verificado con datos: BLOQUE 158.1 y 158.3. */

    /* CONTAMINANTES nuevos (informativos: NO entran a Estado_General hasta validación del área) */
    m.Ca_ppm,  lim.Ca_LP,  lim.Ca_LC,
    /* Ca/Zn/Mg/Mo cambian de sentido segun el componente: en Motor de Traccion son CONTAMINANTES
       (alerta por ENCIMA) y en el resto son ADITIVOS (alerta por DEBAJO: el aditivo se agota).
       Sin esto, /diagcompleto dejaba SIN marcar 53 componentes de RUEDA que /ultimo SI marcaba
       -- el mismo valor, dos modulos, dos respuestas (BLOQUE 122).
       ⛔ G1 (29/09): la direccion se lee del GRUPO (vw_InvPorComponente), no del par LP/LC. En el
       bloque D la deduje del dato y costo 164 falsos criticos en las ruedas de Antamina, donde ese
       par no viene invertido y el Ca normal de 3 000 ppm se leia como exceso (BLOQUE 159.4). */
    CASE WHEN m.Ca_ppm IS NULL THEN 'SIN DATO'
         WHEN inv.Ca_Inv = 1 THEN   /* G1: del formato, NO de 'LP > LC' */
              CASE WHEN m.Ca_ppm = 0 THEN 'SIN DATO'   /* G0 */
                   WHEN m.Ca_ppm < lim.Ca_LC THEN 'CRITICO'
                   WHEN m.Ca_ppm < lim.Ca_LP THEN 'PRECAUCION' ELSE 'OK' END
         WHEN m.Ca_ppm > ISNULL(lim.Ca_LC,9999) THEN 'CRITICO'
         WHEN m.Ca_ppm > ISNULL(lim.Ca_LP,9999) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_Ca,

    m.Zn_ppm,  lim.Zn_LP,  lim.Zn_LC,
    /* Mismo criterio que en Ca: si LP > LC el limite esta invertido (aditivo). */
    CASE WHEN m.Zn_ppm IS NULL THEN 'SIN DATO'
         WHEN inv.Zn_Inv = 1 THEN   /* G1: del formato, NO de 'LP > LC' */
              CASE WHEN m.Zn_ppm = 0 THEN 'SIN DATO'   /* G0 */
                   WHEN m.Zn_ppm < lim.Zn_LC THEN 'CRITICO'
                   WHEN m.Zn_ppm < lim.Zn_LP THEN 'PRECAUCION' ELSE 'OK' END
         WHEN m.Zn_ppm > ISNULL(lim.Zn_LC,9999) THEN 'CRITICO'
         WHEN m.Zn_ppm > ISNULL(lim.Zn_LP,9999) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_Zn,
    m.K_ppm,   lim.K_LP,   lim.K_LC,
    CASE WHEN m.K_ppm IS NULL THEN 'SIN DATO'
         WHEN m.K_ppm > ISNULL(lim.K_LC,9999) THEN 'CRITICO'
         WHEN m.K_ppm > ISNULL(lim.K_LP,9999) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_K,

    m.Na_ppm,  lim.Na_LP,  lim.Na_LC,
    CASE WHEN m.Na_ppm IS NULL THEN 'SIN DATO'
         WHEN m.Na_ppm > ISNULL(lim.Na_LC,9999) THEN 'CRITICO'
         WHEN m.Na_ppm > ISNULL(lim.Na_LP,9999) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_Na,

    m.Mg_ppm,  lim.Mg_LP,  lim.Mg_LC,
    /* Mismo criterio que en Ca: si LP > LC el limite esta invertido (aditivo). */
    CASE WHEN m.Mg_ppm IS NULL THEN 'SIN DATO'
         WHEN inv.Mg_Inv = 1 THEN   /* G1: del formato, NO de 'LP > LC' */
              CASE WHEN m.Mg_ppm = 0 THEN 'SIN DATO'   /* G0 */
                   WHEN m.Mg_ppm < lim.Mg_LC THEN 'CRITICO'
                   WHEN m.Mg_ppm < lim.Mg_LP THEN 'PRECAUCION' ELSE 'OK' END
         WHEN m.Mg_ppm > ISNULL(lim.Mg_LC,9999) THEN 'CRITICO'
         WHEN m.Mg_ppm > ISNULL(lim.Mg_LP,9999) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_Mg,

    m.Pb_ppm,  lim.Pb_LP, lim.Pb_LC,
    CASE WHEN m.Pb_ppm IS NULL THEN 'SIN DATO'
         WHEN m.Pb_ppm > ISNULL(lim.Pb_LC,9999) THEN 'CRITICO'
         WHEN m.Pb_ppm > ISNULL(lim.Pb_LP,9999) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_Pb,

    m.Sn_ppm,  lim.Sn_LP, lim.Sn_LC,
    CASE WHEN m.Sn_ppm IS NULL THEN 'SIN DATO'
         WHEN m.Sn_ppm > ISNULL(lim.Sn_LC,9999) THEN 'CRITICO'
         WHEN m.Sn_ppm > ISNULL(lim.Sn_LP,9999) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_Sn,

    m.Indice_PQ, lim.PQ_LP, lim.PQ_LC,
    CASE WHEN m.Indice_PQ IS NULL THEN 'SIN DATO'
         WHEN m.Indice_PQ > ISNULL(lim.PQ_LC,9999) THEN 'CRITICO'
         WHEN m.Indice_PQ > ISNULL(lim.PQ_LP,9999) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_PQ,

    /* TBN: aditivo del motor, la alerta es por DEBAJO. Hasta el 28/09 solo se leia su LP,
       asi que nunca podia decir CRITICO. El LC existe en lc pero SOLO para MOTOR (5 de las
       64 filas): «el TBN mayormente es el motor nada mas». Con el LC ya distingue.
       ⛔ Un solo Estado_TBN, no dos: dos mecanismos de marcado para el mismo valor fue
       exactamente el bug E3 de la ronda anterior. */
    m.TBN, lim.TBN_LP, lim.TBN_LC,
    CASE WHEN m.TBN IS NULL OR m.TBN = 0 THEN 'SIN DATO'
         WHEN lim.TBN_LC IS NOT NULL AND m.TBN < lim.TBN_LC THEN 'CRITICO'
         WHEN lim.TBN_LP IS NOT NULL AND m.TBN < lim.TBN_LP THEN 'PRECAUCION'
         ELSE 'OK' END AS Estado_TBN,

    /* ================= D3 (28/09) — ADITIVOS con limite =================
       B y P se exponian como VALOR SUELTO, sin LP/LC ni estado: por eso /ultimo los
       pintaba «— —». El limite estaba en lc desde siempre (FOSFORO 280/240 invertido).

       ⚠ REGLA NUEVA — cuando solo hay UN extremo cargado NO se calcula estado.
       La fundacion deduce la direccion con «LP > LC -> invertido». Con un solo
       extremo esa comparacion da NULL y el parametro se cae por la rama de
       contaminante. Medido el 28/09 (bloque 143.1): ANTAMINA HIDRAULICO tiene
       P_LP NULL / P_LC 600 y RUEDA P_LP NULL / P_LC 636. Tratarlo como contaminante
       diria «P alto» de un aditivo, y tratarlo como aditivo marcaria CRITICA a toda
       la flota (los valores rondan 300). No se puede saber cual es: se MUESTRA el
       limite y NO se dispara. Preguntar al area. */
    m.B_ppm, lim.B_LP, lim.B_LC,
    CASE WHEN m.B_ppm IS NULL THEN 'SIN DATO'
         WHEN lim.B_LP IS NULL OR lim.B_LC IS NULL THEN 'OK'
         WHEN inv.B_Inv = 1 THEN   /* G1: del formato, NO de 'LP > LC' */
              CASE WHEN m.B_ppm = 0 THEN 'SIN DATO'   /* G0 */
                   WHEN m.B_ppm < lim.B_LC THEN 'CRITICO'
                   WHEN m.B_ppm < lim.B_LP THEN 'PRECAUCION' ELSE 'OK' END
         WHEN m.B_ppm > lim.B_LC THEN 'CRITICO'
         WHEN m.B_ppm > lim.B_LP THEN 'PRECAUCION' ELSE 'OK' END AS Estado_B,

    m.P_ppm, lim.P_LP, lim.P_LC,
    CASE WHEN m.P_ppm IS NULL THEN 'SIN DATO'
         WHEN lim.P_LP IS NULL OR lim.P_LC IS NULL THEN 'OK'
         WHEN inv.P_Inv = 1 THEN   /* G1: del formato, NO de 'LP > LC' */
              CASE WHEN m.P_ppm = 0 THEN 'SIN DATO'   /* G0 */
                   WHEN m.P_ppm < lim.P_LC THEN 'CRITICO'
                   WHEN m.P_ppm < lim.P_LP THEN 'PRECAUCION' ELSE 'OK' END
         WHEN m.P_ppm > lim.P_LC THEN 'CRITICO'
         WHEN m.P_ppm > lim.P_LP THEN 'PRECAUCION' ELSE 'OK' END AS Estado_P,

    m.Mo_ppm, lim.Mo_LP, lim.Mo_LC,
    CASE WHEN m.Mo_ppm IS NULL THEN 'SIN DATO'
         WHEN lim.Mo_LP IS NULL OR lim.Mo_LC IS NULL THEN 'OK'
         WHEN inv.Mo_Inv = 1 THEN   /* G1: del formato, NO de 'LP > LC' */
              CASE WHEN m.Mo_ppm = 0 THEN 'SIN DATO'   /* G0 */
                   WHEN m.Mo_ppm < lim.Mo_LC THEN 'CRITICO'
                   WHEN m.Mo_ppm < lim.Mo_LP THEN 'PRECAUCION' ELSE 'OK' END
         WHEN m.Mo_ppm > lim.Mo_LC THEN 'CRITICO'
         WHEN m.Mo_ppm > lim.Mo_LP THEN 'PRECAUCION' ELSE 'OK' END AS Estado_Mo,

    /* ================= D3 — SALUD y CONTAMINACION nuevas =================
       Direccion normal (la alerta es por ARRIBA) en todas estas. */
    m.TAN, lim.TAN_LP, lim.TAN_LC,
    CASE WHEN m.TAN IS NULL THEN 'SIN DATO'
         WHEN m.TAN > ISNULL(lim.TAN_LC,9999) THEN 'CRITICO'
         WHEN m.TAN > ISNULL(lim.TAN_LP,9999) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_TAN,

    m.Oxidacion, lim.Oxi_LP, lim.Oxi_LC,
    CASE WHEN m.Oxidacion IS NULL THEN 'SIN DATO'
         WHEN m.Oxidacion > ISNULL(lim.Oxi_LC,9999) THEN 'CRITICO'
         WHEN m.Oxidacion > ISNULL(lim.Oxi_LP,9999) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_Oxi,

    m.Sulfatacion, lim.Sulf_LP, lim.Sulf_LC,
    CASE WHEN m.Sulfatacion IS NULL THEN 'SIN DATO'
         WHEN m.Sulfatacion > ISNULL(lim.Sulf_LC,9999) THEN 'CRITICO'
         WHEN m.Sulfatacion > ISNULL(lim.Sulf_LP,9999) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_Sulf,

    m.Nitracion, lim.Nit_LP, lim.Nit_LC,
    CASE WHEN m.Nitracion IS NULL THEN 'SIN DATO'
         WHEN m.Nitracion > ISNULL(lim.Nit_LC,9999) THEN 'CRITICO'
         WHEN m.Nitracion > ISNULL(lim.Nit_LP,9999) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_Nit,

    m.Hollin, lim.Hollin_LP, lim.Hollin_LC,
    CASE WHEN m.Hollin IS NULL THEN 'SIN DATO'
         WHEN m.Hollin > ISNULL(lim.Hollin_LC,9999) THEN 'CRITICO'
         WHEN m.Hollin > ISNULL(lim.Hollin_LP,9999) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_Hollin,

    m.Agua, lim.Agua_LP, lim.Agua_LC,
    CASE WHEN m.Agua IS NULL THEN 'SIN DATO'
         WHEN m.Agua > ISNULL(lim.Agua_LC,9999) THEN 'CRITICO'
         WHEN m.Agua > ISNULL(lim.Agua_LP,9999) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_Agua,

    m.Diesel, lim.Diesel_LP, lim.Diesel_LC,
    CASE WHEN m.Diesel IS NULL THEN 'SIN DATO'
         WHEN m.Diesel > ISNULL(lim.Diesel_LC,9999) THEN 'CRITICO'
         WHEN m.Diesel > ISNULL(lim.Diesel_LP,9999) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_Diesel,

    /* Refrigerante: el formato lo pide en MODI, la columna existe, pero el bloque 142.3
       midio 0 filas con dato en toda la base y lc no trae su limite (el candidato era
       'Glycol', tambien vacio). Se proyecta el valor y nada mas: si algun dia lo cargan,
       la fila aparece sola. */
    m.Refrigerante,

    /* ================= D3 — CODIGO DE LIMPIEZA ISO =================
       Contador de particulas por tamano (4, 6 y 14 micras). El numero es ADIMENSIONAL y
       LOGARITMICO: cada punto que sube DUPLICA las particulas (20 ~ 40 000 -> 21 ~ 80 000).
       Direccion normal.
       ⛔ G0: un codigo ISO 4406 de 0 es FISICAMENTE IMPOSIBLE (seria <=0,01 particulas/ml). Es la
       marca de "no reportado". Como el limite es normal, un 0 sale OK y el componente se lee como
       LIMPIO sin haberse medido nunca: fallo silencioso puro. Medido en el BLOQUE 158.3 -- Cerro
       Verde 930E MT tiene min=0, max=0, prom=0,0 en los 3 canales, y por eso figuraba con "0
       observados". Eso no era limpieza, era ausencia de medicion. En Antapaccay el MOTOR no lo mide (bloque 142.1: 13% de las
       muestras) y lc no le carga limite -> la fila se cae sola por la regla D5. */
    m.ISO4, lim.ISO4_LP, lim.ISO4_LC,
    CASE WHEN m.ISO4 IS NULL OR m.ISO4 = 0 THEN 'SIN DATO'   /* G0 */
         WHEN m.ISO4 > ISNULL(lim.ISO4_LC,9999) THEN 'CRITICO'
         WHEN m.ISO4 > ISNULL(lim.ISO4_LP,9999) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_ISO4,

    m.ISO6, lim.ISO6_LP, lim.ISO6_LC,
    CASE WHEN m.ISO6 IS NULL OR m.ISO6 = 0 THEN 'SIN DATO'   /* G0 */
         WHEN m.ISO6 > ISNULL(lim.ISO6_LC,9999) THEN 'CRITICO'
         WHEN m.ISO6 > ISNULL(lim.ISO6_LP,9999) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_ISO6,

    m.ISO14, lim.ISO14_LP, lim.ISO14_LC,
    CASE WHEN m.ISO14 IS NULL OR m.ISO14 = 0 THEN 'SIN DATO'   /* G0 */
         WHEN m.ISO14 > ISNULL(lim.ISO14_LC,9999) THEN 'CRITICO'
         WHEN m.ISO14 > ISNULL(lim.ISO14_LP,9999) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_ISO14,

    /* ================= D3 — VISCOSIDAD: es una BANDA, no un limite =================
       El aceite PARTE con un valor y puede irse para arriba o para abajo; se vigila que
       se mantenga entre los precautorios. Cuatro niveles: LCI < LPI <= valor <= LPS < LCS.
       ⚠ En un PISO el precautorio va POR ENCIMA del critico (avisa antes de llegar
       bajando): medido en MOTOR 980E -> LPI 13.50 > LCI 13.00. No es un typo.
       ⚠ Que niveles existen lo dice el dato, no una lista: MT trae solo LCI/LCS
       («para el MT solo el critico, no trabaja con el precautorio») y MOTOR 980E trae
       los cuatro. Un nivel NULL simplemente no se evalua.
       V100 = 0 se trata como SIN DATO: el 07/08 generaba 196 falsos positivos. */
    m.V100, lim.V100_LPI, lim.V100_LCI, lim.V100_LPS, lim.V100_LCS,
    CASE WHEN m.V100 IS NULL OR m.V100 = 0 THEN 'SIN DATO'
         WHEN (lim.V100_LCI IS NOT NULL AND m.V100 < lim.V100_LCI) OR (lim.V100_LCS IS NOT NULL AND m.V100 > lim.V100_LCS) THEN 'CRITICO'
         WHEN (lim.V100_LPI IS NOT NULL AND m.V100 < lim.V100_LPI) OR (lim.V100_LPS IS NOT NULL AND m.V100 > lim.V100_LPS) THEN 'PRECAUCION'
         ELSE 'OK' END AS Estado_V100,

    /* V40: misma mecanica. Antapaccay NO la mide (0 muestras) y Antamina SI (15 834):
       «va a depender de la mina». La fila se cae sola donde no hay dato. */
    m.V40, lim.V40_LPI, lim.V40_LCI, lim.V40_LPS, lim.V40_LCS,
    CASE WHEN m.V40 IS NULL OR m.V40 = 0 THEN 'SIN DATO'
         WHEN (lim.V40_LCI IS NOT NULL AND m.V40 < lim.V40_LCI) OR (lim.V40_LCS IS NOT NULL AND m.V40 > lim.V40_LCS) THEN 'CRITICO'
         WHEN (lim.V40_LPI IS NOT NULL AND m.V40 < lim.V40_LPI) OR (lim.V40_LPS IS NOT NULL AND m.V40 > lim.V40_LPS) THEN 'PRECAUCION'
         ELSE 'OK' END AS Estado_V40,



    /* Estado_General: SIN CAMBIOS respecto a v3 (Ca/Zn/B/P informativos; el triage no se altera) */
    CASE
        WHEN m.Fe_ppm    > ISNULL(lim.Fe_LC,9999)
          OR m.Cr_ppm    > ISNULL(lim.Cr_LC,9999)
          OR m.Ni_ppm    > ISNULL(lim.Ni_LC,9999)
          OR m.Cu_ppm    > ISNULL(lim.Cu_LC,9999)
          OR m.Si_ppm    > ISNULL(lim.Si_LC,9999)
          OR m.Al_ppm    > ISNULL(lim.Al_LC,9999)
          OR m.Pb_ppm    > ISNULL(lim.Pb_LC,9999)
          OR m.Sn_ppm    > ISNULL(lim.Sn_LC,9999)
          OR m.Indice_PQ > ISNULL(lim.PQ_LC,9999)
        THEN 'CRITICO'
        WHEN m.Fe_ppm    > ISNULL(lim.Fe_LP,9999)
          OR m.Cr_ppm    > ISNULL(lim.Cr_LP,9999)
          OR m.Ni_ppm    > ISNULL(lim.Ni_LP,9999)
          OR m.Cu_ppm    > ISNULL(lim.Cu_LP,9999)
          OR m.Si_ppm    > ISNULL(lim.Si_LP,9999)
          OR m.Al_ppm    > ISNULL(lim.Al_LP,9999)
          OR m.Pb_ppm    > ISNULL(lim.Pb_LP,9999)
          OR m.Sn_ppm    > ISNULL(lim.Sn_LP,9999)
          OR m.Indice_PQ > ISNULL(lim.PQ_LP,9999)
          OR (lim.TBN_LP IS NOT NULL AND m.TBN > 0 AND m.TBN < lim.TBN_LP)
        THEN 'PRECAUCION'
        ELSE 'OK'
    END AS Estado_General,

    /* rn_recencia = orden por FECHA distinta (1=más reciente), solo la keeper del día;
       mismo día/re-test -> NULL (no entra a rn=1 ni rn<=6). Historial (sin filtro rn) ve TODO. */
    CASE WHEN m.EsDDI = 0 AND m.rn_dia = 1 THEN m.date_rank END AS rn_recencia,

    m.LaboratoryDataId
FROM calc m
/* G1: la direccion de los aditivos sale del formato, no del par LP/LC. Ver vw_InvPorComponente. */
LEFT JOIN [dbo].[vw_InvPorComponente] inv ON inv.CompTipo = m.CompTipo
LEFT JOIN [dbo].[vw_LimitesPorComponente] lim
    ON lim.ProyKey   = m.ProyKey
   AND lim.ModeloKey = m.ModeloKey
   AND lim.CompTipo  = m.CompTipo
   /* GUARD anti-colisión: un componente NO reconocido por el CASE cae en 'OTRO'.
      Tanto las muestras como lc colapsan varios componentes distintos (CAJA GIRO,
      PTO, DAMPER, DIFERENCIAL…) en 'OTRO', y vw_LimitesPorComponente los mezcla con
      MIN() → límite ajeno/erróneo. Mientras el área no estandarice nombres y cargue
      límites por componente real, 'OTRO' NO matchea: sin límite (ISNULL→9999) = NUNCA
      dispara observado falso. NO afecta al 980E (sus 4 componentes sí mapean). */
   AND m.CompTipo  <> 'OTRO';
GO


/* ----------------------------------------------------------------------------
   3-5) Derivadas: misma definición que v3, re-creadas para RE-CAPTURAR las
   columnas nuevas (SELECT * congela columnas al crear la vista).
   ---------------------------------------------------------------------------- */
CREATE OR ALTER VIEW [dbo].[vw_MuestrasRankeadas] AS
WITH hs AS (
    -- HsCc pre-rankeado: 1 fila (la más reciente) por EQUIPO+SISTEMA. Se escanea UNA vez
    -- (antes era subconsulta correlacionada por fila → HsCc escaneado 2112x). Alias Eq/Sis/Smr/Hta
    -- evitan ambiguedad con me.Equipo. Mapeo EQUIPO 'T####'->'CA####' y SISTEMA inglés<->compartimiento.
    SELECT [EQUIPO] AS Eq, [SISTEMA] AS Sis,
           TRY_CONVERT(decimal(12,2),[SMR ULTIMO SERVICIO])        AS Smr,
           TRY_CONVERT(decimal(12,2),[HORAS DE TRABAJO ACUMULADO ]) AS Hta,
           ROW_NUMBER() OVER (PARTITION BY [EQUIPO],[SISTEMA] ORDER BY [FECHA] DESC) AS rn
    FROM [Eqpcare].[HsCc]
)
SELECT me.*,
    CASE WHEN H.Smr IS NOT NULL AND me.Horometro >= H.Smr THEN me.Horometro - H.Smr ELSE H.Hta END AS HorasComponente
FROM [dbo].[vw_MuestrasEstado] me
LEFT JOIN hs H
  ON  H.rn = 1
  AND ( H.Eq = me.Equipo OR (H.Eq LIKE 'T[0-9]%' AND me.Equipo = 'CA'+SUBSTRING(H.Eq,2,10)) )
  AND H.Sis = CASE WHEN me.Compartimiento LIKE '%TRACCION%LH' THEN 'WHEEL MOTOR LH'
                   WHEN me.Compartimiento LIKE '%TRACCION%RH' THEN 'WHEEL MOTOR RH'
                   WHEN me.Compartimiento LIKE '%HIDRAULICO%' THEN 'HYDRAULIC'
                   WHEN me.Compartimiento LIKE '%RUEDA%LH'    THEN 'SPINDLE LH'
                   WHEN me.Compartimiento LIKE '%RUEDA%RH'    THEN 'SPINDLE RH'
                   WHEN me.Compartimiento LIKE 'MOTOR%'       THEN 'MOTOR DIESEL'
                   ELSE me.Compartimiento END
WHERE me.EsDDI = 0;
GO

/* ==== vw_MuestrasHistorial — base DDI-INCLUSIVA para historial (unico topico con DDI). ====
   = vw_MuestrasRankeadas SIN el filtro EsDDI=0, + rn_hist (recencia por MUESTRA, 1=mas reciente,
   incluye DDI). Los demas topicos NO usan esta vista (siguen en vw_MuestrasRankeadas, EsDDI=0). */
CREATE OR ALTER VIEW [dbo].[vw_MuestrasHistorial] AS
WITH hs AS (
    SELECT [EQUIPO] AS Eq, [SISTEMA] AS Sis,
           TRY_CONVERT(decimal(12,2),[SMR ULTIMO SERVICIO])        AS Smr,
           TRY_CONVERT(decimal(12,2),[HORAS DE TRABAJO ACUMULADO ]) AS Hta,
           ROW_NUMBER() OVER (PARTITION BY [EQUIPO],[SISTEMA] ORDER BY [FECHA] DESC) AS rn
    FROM [Eqpcare].[HsCc]
)
SELECT me.*,
    CASE WHEN H.Smr IS NOT NULL AND me.Horometro >= H.Smr THEN me.Horometro - H.Smr ELSE H.Hta END AS HorasComponente,
    ROW_NUMBER() OVER (PARTITION BY me.Equipo, me.Compartimiento ORDER BY me.FechaMuestreo DESC, me.LaboratoryDataId DESC) AS rn_hist
FROM [dbo].[vw_MuestrasEstado] me
LEFT JOIN hs H
  ON  H.rn = 1
  AND ( H.Eq = me.Equipo OR (H.Eq LIKE 'T[0-9]%' AND me.Equipo = 'CA'+SUBSTRING(H.Eq,2,10)) )
  AND H.Sis = CASE WHEN me.Compartimiento LIKE '%TRACCION%LH' THEN 'WHEEL MOTOR LH'
                   WHEN me.Compartimiento LIKE '%TRACCION%RH' THEN 'WHEEL MOTOR RH'
                   WHEN me.Compartimiento LIKE '%HIDRAULICO%' THEN 'HYDRAULIC'
                   WHEN me.Compartimiento LIKE '%RUEDA%LH'    THEN 'SPINDLE LH'
                   WHEN me.Compartimiento LIKE '%RUEDA%RH'    THEN 'SPINDLE RH'
                   WHEN me.Compartimiento LIKE 'MOTOR%'       THEN 'MOTOR DIESEL'
                   ELSE me.Compartimiento END;
GO

CREATE OR ALTER VIEW [dbo].[vw_UltimoAnalisisAceite] AS
-- sobre vw_MuestrasRankeadas (no vw_MuestrasEstado) para exponer HorasComponente
-- (rankeadas ya filtra EsDDI=0). rn_recencia=1 = última muestra en uso por equipo+compartimiento.
SELECT * FROM [dbo].[vw_MuestrasRankeadas] WHERE rn_recencia = 1;
GO

CREATE OR ALTER VIEW [dbo].[vw_EstadoActualMT] AS
-- sobre vw_MuestrasRankeadas para exponer HorasComponente (rankeadas ya filtra EsDDI=0).
SELECT * FROM [dbo].[vw_MuestrasRankeadas] WHERE CompTipo = 'TRACCION' AND rn_recencia = 1;
GO


/* ============================================================================
   GRUPO C — BARRIDO/OBSERVADOS (v4.2): vw_ObservadosFlota sobre vw_MuestrasEstado
   ============================================================================ */
/* ============================================================================
   KomfIA — v4.2: vw_ObservadosFlota + "Hor. Comp." REAL desde [Eqpcare].[HsCc]
   Base: bd_kmmp_osconfiabilidad (Azure SQL)

   QUÉ AGREGA respecto a v4.1 (misma lógica Mets_Obs/Infs_Obs/NumCrit/NumPrec):
   - HorasComponente: horas reales del componente al momento de la muestra =
       Horometro de la muestra − [SMR ULTIMO SERVICIO] de HsCc (último cambio).
       Si no hay SMR o sale negativo, usa [HORAS DE TRABAJO ACUMULADO ] (snapshot HsCc).
   - Cond_Area: [ESTADO SOS] de HsCc (Normal/Observado/Precaucion/Critico) — la
       condición que el propio área mantiene, útil para contrastar (no se muestra
       por defecto en los formatos; queda disponible).

   MAPEOS (verificados contra la data real de HsCc):
   - Equipo: HsCc usa 'T3174' donde ME.Code es 'CA3174' (Antapaccay 980E) → el JOIN
     acepta igualdad directa O el patrón T#### → CA####.
   - Componente: HsCc.[SISTEMA] está en inglés para 980E → WHEEL MOTOR LH/RH ↔
     MOTOR DE TRACCION LH/RH, HYDRAULIC ↔ SISTEMA HIDRAULICO, SPINDLE ↔ RUEDA
     DELANTERA, MOTOR DIESEL ↔ MOTOR. Otros (D475A en español) → igualdad directa.
   - [HORAS DE TRABAJO ACUMULADO ] lleva ESPACIO FINAL en el nombre real (no es typo).
   LEFT JOIN: si HsCc no tiene el equipo/componente, HorasComponente sale NULL y
   el formato cae a Hor. Ace. (así lo dice Formatos de Respuesta). Nada se pierde.
   ============================================================================ */
GO

CREATE OR ALTER VIEW [dbo].[vw_ObservadosFlota] AS
WITH b AS (
    SELECT
        Equipo, Proyecto, Modelo, Compartimiento, CompTipo,
        FechaMuestreo, Horometro, HorasDeAceite, CM, Grado, Estado_General,
        /* DETERMINANTES fuera de limite: "Fe:C,Cr:P"  (C=>LC condenatorio | P=>LP) */
        STUFF(CONCAT(
            CASE WHEN Fe_ppm    > ISNULL(Fe_LC,9999) THEN ',Fe:C' WHEN Fe_ppm    > ISNULL(Fe_LP,9999) THEN ',Fe:P' ELSE '' END,
            CASE WHEN Indice_PQ > ISNULL(PQ_LC,9999) THEN ',PQ:C' WHEN Indice_PQ > ISNULL(PQ_LP,9999) THEN ',PQ:P' ELSE '' END,
            CASE WHEN Cr_ppm    > ISNULL(Cr_LC,9999) THEN ',Cr:C' WHEN Cr_ppm    > ISNULL(Cr_LP,9999) THEN ',Cr:P' ELSE '' END,
            CASE WHEN Ni_ppm    > ISNULL(Ni_LC,9999) THEN ',Ni:C' WHEN Ni_ppm    > ISNULL(Ni_LP,9999) THEN ',Ni:P' ELSE '' END,
            CASE WHEN Cu_ppm    > ISNULL(Cu_LC,9999) THEN ',Cu:C' WHEN Cu_ppm    > ISNULL(Cu_LP,9999) THEN ',Cu:P' ELSE '' END,
            CASE WHEN Pb_ppm    > ISNULL(Pb_LC,9999) THEN ',Pb:C' WHEN Pb_ppm    > ISNULL(Pb_LP,9999) THEN ',Pb:P' ELSE '' END,
            CASE WHEN Sn_ppm    > ISNULL(Sn_LC,9999) THEN ',Sn:C' WHEN Sn_ppm    > ISNULL(Sn_LP,9999) THEN ',Sn:P' ELSE '' END,
            CASE WHEN Al_ppm    > ISNULL(Al_LC,9999) THEN ',Al:C' WHEN Al_ppm    > ISNULL(Al_LP,9999) THEN ',Al:P' ELSE '' END,
            CASE WHEN Si_ppm    > ISNULL(Si_LC,9999) THEN ',Si:C' WHEN Si_ppm    > ISNULL(Si_LP,9999) THEN ',Si:P' ELSE '' END,
            CASE WHEN TBN_LP IS NOT NULL AND TBN > 0 AND TBN < TBN_LP THEN ',TBN:P' ELSE '' END
        ), 1, 1, '') AS Mets_Obs,
        /* INFORMATIVOS fuera de umbral (Ca/Zn/K/Mg): se muestran, NO disparan observado */
        STUFF(CONCAT(
            CASE WHEN Ca_ppm > ISNULL(Ca_LC,9999) THEN ',Ca:C' WHEN Ca_ppm > ISNULL(Ca_LP,9999) THEN ',Ca:P' ELSE '' END,
            CASE WHEN Zn_ppm > ISNULL(Zn_LC,9999) THEN ',Zn:C' WHEN Zn_ppm > ISNULL(Zn_LP,9999) THEN ',Zn:P' ELSE '' END,
            CASE WHEN K_ppm  > ISNULL(K_LC,9999)  THEN ',K:C'  WHEN K_ppm  > ISNULL(K_LP,9999)  THEN ',K:P'  ELSE '' END,
            CASE WHEN Na_ppm > ISNULL(Na_LC,9999) THEN ',Na:C' WHEN Na_ppm > ISNULL(Na_LP,9999) THEN ',Na:P' ELSE '' END,
            CASE WHEN Mg_ppm > ISNULL(Mg_LC,9999) THEN ',Mg:C' WHEN Mg_ppm > ISNULL(Mg_LP,9999) THEN ',Mg:P' ELSE '' END,
            /* SALUD del aceite: viscosidad. Solo dispara donde los limites VISC estan aterrizados (Antapaccay); V100=0/NULL -> SIN DATO (nada). Informativo: NO cuenta como metal observado */
            CASE WHEN Estado_V100 = 'CRITICO' THEN ',V100:C' WHEN Estado_V100 = 'PRECAUCION' THEN ',V100:P' ELSE '' END
        ), 1, 1, '') AS Infs_Obs,
        ( CASE WHEN Fe_ppm    > ISNULL(Fe_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Indice_PQ > ISNULL(PQ_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Cr_ppm    > ISNULL(Cr_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Ni_ppm    > ISNULL(Ni_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Cu_ppm    > ISNULL(Cu_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Al_ppm    > ISNULL(Al_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Si_ppm    > ISNULL(Si_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Pb_ppm    > ISNULL(Pb_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Sn_ppm    > ISNULL(Sn_LC,9999) THEN 1 ELSE 0 END) AS NumCrit,
        ( CASE WHEN Fe_ppm    > ISNULL(Fe_LP,9999) AND Fe_ppm    <= ISNULL(Fe_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Indice_PQ > ISNULL(PQ_LP,9999) AND Indice_PQ <= ISNULL(PQ_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Cr_ppm    > ISNULL(Cr_LP,9999) AND Cr_ppm    <= ISNULL(Cr_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Ni_ppm    > ISNULL(Ni_LP,9999) AND Ni_ppm    <= ISNULL(Ni_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Cu_ppm    > ISNULL(Cu_LP,9999) AND Cu_ppm    <= ISNULL(Cu_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Pb_ppm    > ISNULL(Pb_LP,9999) AND Pb_ppm    <= ISNULL(Pb_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Sn_ppm    > ISNULL(Sn_LP,9999) AND Sn_ppm    <= ISNULL(Sn_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Al_ppm    > ISNULL(Al_LP,9999) AND Al_ppm    <= ISNULL(Al_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Si_ppm    > ISNULL(Si_LP,9999) AND Si_ppm    <= ISNULL(Si_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN TBN_LP IS NOT NULL AND TBN > 0 AND TBN < TBN_LP THEN 1 ELSE 0 END) AS NumPrec,
        /* Detalle pre-formateado: parámetros fuera de límite con valor(LP/LC) y severidad (:C/:P) */
        STUFF(CONCAT(
            CASE WHEN Fe_ppm>ISNULL(Fe_LC,9999) THEN ' · Fe='+CONVERT(varchar(20),CAST(Fe_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Fe_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Fe_LC AS decimal(18,1))),'')+')'+':C' WHEN Fe_ppm>ISNULL(Fe_LP,9999) THEN ' · Fe='+CONVERT(varchar(20),CAST(Fe_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Fe_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Fe_LC AS decimal(18,1))),'')+')'+':P' ELSE '' END,
            CASE WHEN Indice_PQ>ISNULL(PQ_LC,9999) THEN ' · PQ='+CONVERT(varchar(20),CAST(Indice_PQ AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(PQ_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(PQ_LC AS decimal(18,1))),'')+')'+':C' WHEN Indice_PQ>ISNULL(PQ_LP,9999) THEN ' · PQ='+CONVERT(varchar(20),CAST(Indice_PQ AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(PQ_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(PQ_LC AS decimal(18,1))),'')+')'+':P' ELSE '' END,
            CASE WHEN Cr_ppm>ISNULL(Cr_LC,9999) THEN ' · Cr='+CONVERT(varchar(20),CAST(Cr_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Cr_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Cr_LC AS decimal(18,1))),'')+')'+':C' WHEN Cr_ppm>ISNULL(Cr_LP,9999) THEN ' · Cr='+CONVERT(varchar(20),CAST(Cr_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Cr_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Cr_LC AS decimal(18,1))),'')+')'+':P' ELSE '' END,
            CASE WHEN Ni_ppm>ISNULL(Ni_LC,9999) THEN ' · Ni='+CONVERT(varchar(20),CAST(Ni_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Ni_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Ni_LC AS decimal(18,1))),'')+')'+':C' WHEN Ni_ppm>ISNULL(Ni_LP,9999) THEN ' · Ni='+CONVERT(varchar(20),CAST(Ni_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Ni_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Ni_LC AS decimal(18,1))),'')+')'+':P' ELSE '' END,
            CASE WHEN Cu_ppm>ISNULL(Cu_LC,9999) THEN ' · Cu='+CONVERT(varchar(20),CAST(Cu_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Cu_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Cu_LC AS decimal(18,1))),'')+')'+':C' WHEN Cu_ppm>ISNULL(Cu_LP,9999) THEN ' · Cu='+CONVERT(varchar(20),CAST(Cu_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Cu_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Cu_LC AS decimal(18,1))),'')+')'+':P' ELSE '' END,
            CASE WHEN Al_ppm>ISNULL(Al_LC,9999) THEN ' · Al='+CONVERT(varchar(20),CAST(Al_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Al_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Al_LC AS decimal(18,1))),'')+')'+':C' WHEN Al_ppm>ISNULL(Al_LP,9999) THEN ' · Al='+CONVERT(varchar(20),CAST(Al_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Al_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Al_LC AS decimal(18,1))),'')+')'+':P' ELSE '' END,
            CASE WHEN Si_ppm>ISNULL(Si_LC,9999) THEN ' · Si='+CONVERT(varchar(20),CAST(Si_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Si_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Si_LC AS decimal(18,1))),'')+')'+':C' WHEN Si_ppm>ISNULL(Si_LP,9999) THEN ' · Si='+CONVERT(varchar(20),CAST(Si_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Si_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Si_LC AS decimal(18,1))),'')+')'+':P' ELSE '' END,
            CASE WHEN Pb_ppm>ISNULL(Pb_LP,9999) THEN ' · Pb='+CONVERT(varchar(20),CAST(Pb_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Pb_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Pb_LC AS decimal(18,1))),'')+')'+CASE WHEN Pb_ppm>ISNULL(Pb_LC,9999) THEN ':C' ELSE ':P' END ELSE '' END,
            CASE WHEN Sn_ppm>ISNULL(Sn_LP,9999) THEN ' · Sn='+CONVERT(varchar(20),CAST(Sn_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Sn_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Sn_LC AS decimal(18,1))),'')+')'+CASE WHEN Sn_ppm>ISNULL(Sn_LC,9999) THEN ':C' ELSE ':P' END ELSE '' END,
            CASE WHEN TBN_LP IS NOT NULL AND TBN>0 AND TBN<TBN_LP THEN ' · TBN='+CONVERT(varchar(20),CAST(TBN AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(TBN_LP AS decimal(18,1))),'')+')'+':P' ELSE '' END,
            CASE WHEN Ca_ppm>ISNULL(Ca_LC,9999) THEN ' · Ca='+CONVERT(varchar(20),CAST(Ca_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Ca_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Ca_LC AS decimal(18,1))),'')+')'+':C' WHEN Ca_ppm>ISNULL(Ca_LP,9999) THEN ' · Ca='+CONVERT(varchar(20),CAST(Ca_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Ca_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Ca_LC AS decimal(18,1))),'')+')'+':P' ELSE '' END,
            CASE WHEN Zn_ppm>ISNULL(Zn_LC,9999) THEN ' · Zn='+CONVERT(varchar(20),CAST(Zn_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Zn_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Zn_LC AS decimal(18,1))),'')+')'+':C' WHEN Zn_ppm>ISNULL(Zn_LP,9999) THEN ' · Zn='+CONVERT(varchar(20),CAST(Zn_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Zn_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Zn_LC AS decimal(18,1))),'')+')'+':P' ELSE '' END,
            CASE WHEN K_ppm>ISNULL(K_LC,9999) THEN ' · K='+CONVERT(varchar(20),CAST(K_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(K_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(K_LC AS decimal(18,1))),'')+')'+':C' WHEN K_ppm>ISNULL(K_LP,9999) THEN ' · K='+CONVERT(varchar(20),CAST(K_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(K_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(K_LC AS decimal(18,1))),'')+')'+':P' ELSE '' END,
            CASE WHEN Na_ppm>ISNULL(Na_LC,9999) THEN ' · Na='+CONVERT(varchar(20),CAST(Na_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Na_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Na_LC AS decimal(18,1))),'')+')'+':C' WHEN Na_ppm>ISNULL(Na_LP,9999) THEN ' · Na='+CONVERT(varchar(20),CAST(Na_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Na_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Na_LC AS decimal(18,1))),'')+')'+':P' ELSE '' END,
            CASE WHEN Mg_ppm>ISNULL(Mg_LC,9999) THEN ' · Mg='+CONVERT(varchar(20),CAST(Mg_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Mg_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Mg_LC AS decimal(18,1))),'')+')'+':C' WHEN Mg_ppm>ISNULL(Mg_LP,9999) THEN ' · Mg='+CONVERT(varchar(20),CAST(Mg_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Mg_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Mg_LC AS decimal(18,1))),'')+')'+':P' ELSE '' END
        ),1,3,'') AS Detalle,
        STUFF(CONCAT(
            CASE WHEN Fe_ppm>ISNULL(Fe_LP,9999) THEN ' · Fe '+CONVERT(varchar(20),CAST(Fe_LP AS decimal(18,1)))+ISNULL('/'+CONVERT(varchar(20),CAST(Fe_LC AS decimal(18,1))),'') ELSE '' END,
            CASE WHEN Indice_PQ>ISNULL(PQ_LP,9999) THEN ' · PQ '+CONVERT(varchar(20),CAST(PQ_LP AS decimal(18,1)))+ISNULL('/'+CONVERT(varchar(20),CAST(PQ_LC AS decimal(18,1))),'') ELSE '' END,
            CASE WHEN Cr_ppm>ISNULL(Cr_LP,9999) THEN ' · Cr '+CONVERT(varchar(20),CAST(Cr_LP AS decimal(18,1)))+ISNULL('/'+CONVERT(varchar(20),CAST(Cr_LC AS decimal(18,1))),'') ELSE '' END,
            CASE WHEN Ni_ppm>ISNULL(Ni_LP,9999) THEN ' · Ni '+CONVERT(varchar(20),CAST(Ni_LP AS decimal(18,1)))+ISNULL('/'+CONVERT(varchar(20),CAST(Ni_LC AS decimal(18,1))),'') ELSE '' END,
            CASE WHEN Cu_ppm>ISNULL(Cu_LP,9999) THEN ' · Cu '+CONVERT(varchar(20),CAST(Cu_LP AS decimal(18,1)))+ISNULL('/'+CONVERT(varchar(20),CAST(Cu_LC AS decimal(18,1))),'') ELSE '' END,
            CASE WHEN Al_ppm>ISNULL(Al_LP,9999) THEN ' · Al '+CONVERT(varchar(20),CAST(Al_LP AS decimal(18,1)))+ISNULL('/'+CONVERT(varchar(20),CAST(Al_LC AS decimal(18,1))),'') ELSE '' END,
            CASE WHEN Si_ppm>ISNULL(Si_LP,9999) THEN ' · Si '+CONVERT(varchar(20),CAST(Si_LP AS decimal(18,1)))+ISNULL('/'+CONVERT(varchar(20),CAST(Si_LC AS decimal(18,1))),'') ELSE '' END,
            CASE WHEN Pb_ppm>ISNULL(Pb_LP,9999) THEN ' · Pb '+CONVERT(varchar(20),CAST(Pb_LP AS decimal(18,1)))+ISNULL('/'+CONVERT(varchar(20),CAST(Pb_LC AS decimal(18,1))),'') ELSE '' END,
            CASE WHEN Sn_ppm>ISNULL(Sn_LP,9999) THEN ' · Sn '+CONVERT(varchar(20),CAST(Sn_LP AS decimal(18,1)))+ISNULL('/'+CONVERT(varchar(20),CAST(Sn_LC AS decimal(18,1))),'') ELSE '' END,
            CASE WHEN TBN_LP IS NOT NULL AND TBN>0 AND TBN<TBN_LP THEN ' · TBN '+CONVERT(varchar(20),CAST(TBN_LP AS decimal(18,1))) ELSE '' END,
            CASE WHEN Ca_ppm>ISNULL(Ca_LP,9999) THEN ' · Ca '+CONVERT(varchar(20),CAST(Ca_LP AS decimal(18,1)))+ISNULL('/'+CONVERT(varchar(20),CAST(Ca_LC AS decimal(18,1))),'') ELSE '' END,
            CASE WHEN Zn_ppm>ISNULL(Zn_LP,9999) THEN ' · Zn '+CONVERT(varchar(20),CAST(Zn_LP AS decimal(18,1)))+ISNULL('/'+CONVERT(varchar(20),CAST(Zn_LC AS decimal(18,1))),'') ELSE '' END,
            CASE WHEN K_ppm>ISNULL(K_LP,9999) THEN ' · K '+CONVERT(varchar(20),CAST(K_LP AS decimal(18,1)))+ISNULL('/'+CONVERT(varchar(20),CAST(K_LC AS decimal(18,1))),'') ELSE '' END,
            CASE WHEN Na_ppm>ISNULL(Na_LP,9999) THEN ' · Na '+CONVERT(varchar(20),CAST(Na_LP AS decimal(18,1)))+ISNULL('/'+CONVERT(varchar(20),CAST(Na_LC AS decimal(18,1))),'') ELSE '' END,
            CASE WHEN Mg_ppm>ISNULL(Mg_LP,9999) THEN ' · Mg '+CONVERT(varchar(20),CAST(Mg_LP AS decimal(18,1)))+ISNULL('/'+CONVERT(varchar(20),CAST(Mg_LC AS decimal(18,1))),'') ELSE '' END
        ),1,3,'') AS LimObs,
        Fe_ppm, Fe_LP, Fe_LC, Indice_PQ, PQ_LP, PQ_LC, Cr_ppm, Cr_LP, Cr_LC, Ni_ppm, Ni_LP, Ni_LC,
        Cu_ppm, Cu_LP, Cu_LC, Pb_ppm, Pb_LP, Pb_LC, Sn_ppm, Sn_LP, Sn_LC, Al_ppm, Al_LP, Al_LC,
        Si_ppm, Si_LP, Si_LC, Ca_ppm, Ca_LP, Ca_LC, Zn_ppm, Zn_LP, Zn_LC,
        K_ppm, K_LP, K_LC, Na_ppm, Na_LP, Na_LC, Mg_ppm, Mg_LP, Mg_LC, B_ppm, P_ppm, V100, TBN, TBN_LP, Estado_V100
    FROM [dbo].[vw_MuestrasEstado]
    WHERE EsDDI = 0 AND rn_recencia = 1
),
obs AS (   /* SOLO filas con algo fuera de umbral -> el JOIN a HsCc cruza pocas filas (liviano) */
    SELECT * FROM b WHERE Mets_Obs IS NOT NULL OR Infs_Obs IS NOT NULL
),
hs AS (
    SELECT [EQUIPO], [SISTEMA], [SMR ULTIMO SERVICIO], [HORAS DE TRABAJO ACUMULADO ], [ESTADO SOS],
           ROW_NUMBER() OVER (PARTITION BY [EQUIPO], [SISTEMA] ORDER BY [FECHA] DESC) AS rn
    FROM [Eqpcare].[HsCc] WITH (NOLOCK)
)
SELECT
    obs.*,
    CASE WHEN TRY_CONVERT(decimal(12,2), H.[SMR ULTIMO SERVICIO]) IS NOT NULL
          AND obs.Horometro >= TRY_CONVERT(decimal(12,2), H.[SMR ULTIMO SERVICIO])
         THEN obs.Horometro - TRY_CONVERT(decimal(12,2), H.[SMR ULTIMO SERVICIO])
         ELSE TRY_CONVERT(decimal(12,2), H.[HORAS DE TRABAJO ACUMULADO ]) END AS HorasComponente,
    H.[ESTADO SOS] AS Cond_Area
FROM obs
LEFT JOIN hs H
  ON  H.rn = 1
  AND ( H.[EQUIPO] = obs.Equipo
        OR (H.[EQUIPO] LIKE 'T[0-9]%' AND obs.Equipo = 'CA' + SUBSTRING(H.[EQUIPO], 2, 10)) )
  AND H.[SISTEMA] = CASE
        WHEN obs.Compartimiento LIKE '%TRACCION%LH' THEN 'WHEEL MOTOR LH'
        WHEN obs.Compartimiento LIKE '%TRACCION%RH' THEN 'WHEEL MOTOR RH'
        WHEN obs.Compartimiento LIKE '%HIDRAULICO%' THEN 'HYDRAULIC'
        WHEN obs.Compartimiento LIKE '%RUEDA%LH'    THEN 'SPINDLE LH'
        WHEN obs.Compartimiento LIKE '%RUEDA%RH'    THEN 'SPINDLE RH'
        WHEN obs.Compartimiento LIKE 'MOTOR%'       THEN 'MOTOR DIESEL'
        ELSE obs.Compartimiento END;
GO


/* ----------------------------------------------------------------------------
   vw_ObservadosResumen — 1 FILA POR EQUIPO (resumen de barrido, liviano)
   Agrega los componentes observados de cada equipo (Comp_Obs) y sus metales
   (Met_Obs) → el orquestador recibe ~N filas pequeñas en vez de N×58 columnas,
   evitando que se sature o malinterprete. Para la Tabla 1 del barrido.
   El DETALLE de un equipo concreto se pide aparte a vw_ObservadosFlota WHERE Equipo=...
   ---------------------------------------------------------------------------- */
CREATE OR ALTER VIEW [dbo].[vw_ObservadosResumen] AS
SELECT
    Equipo, Proyecto, Modelo,
    SUM(NumCrit)        AS NumCrit,
    SUM(NumPrec)        AS NumPrec,
    MAX(Horometro)      AS Horometro,
    MAX(HorasDeAceite)  AS HorasDeAceite,
    MAX(FechaMuestreo)  AS FechaUltima,
    MAX(CM)             AS CM,
    STRING_AGG(Compartimiento, ' · ') WITHIN GROUP (ORDER BY NumCrit DESC, Compartimiento) AS Comp_Obs,
    -- ⚠ 2026-09-19: el desempate por Compartimiento es OBLIGATORIO. Sin el, con componentes empatados en NumCrit
    -- el orden lo decidia el PLAN -> la MISMA consulta renderizaba distinto entre ejecuciones (detectado al
    -- comparar hashes: mismo LEN, distinto hash). Alineado con el orden de Comp_Obs. Ver VALIDACION BLOQUE 75.
    STRING_AGG(NULLIF(Mets_Obs,''), ' · ') WITHIN GROUP (ORDER BY NumCrit DESC, Compartimiento) AS Met_Obs,
    -- Limites: "Comp: metal LP/LC" de los componentes observados del equipo (para el CUADRO DE LÍMITES
    -- del barrido, disponible YA en PASO 1). El central une por (comp,metal) para armar la matriz.
    STRING_AGG(NULLIF(Compartimiento + ': ' + LimObs, Compartimiento + ': '), '  |  ')
        WITHIN GROUP (ORDER BY NumCrit DESC, Compartimiento) AS Limites
FROM [dbo].[vw_ObservadosFlota]
WHERE Estado_General <> 'OK'
GROUP BY Equipo, Proyecto, Modelo;
GO


/* ----------------------------------------------------------------------------
   vw_ObservadosDetalle — DETALLE de barrido (PASO 2), LIGERO y PRE-FORMATEADO.
   1 fila por equipo+compartimiento observado. SOLO las columnas que el orquestador
   necesita para la MATRIZ compacta (formato Excel del área). NO trae metales sueltos
   (Fe_ppm, Fe_LP, Fe_LC…) a propósito: así el central NO puede armar el esqueleto de
   "último análisis" (4 grupos) — queda OBLIGADO a leer la columna Detalle y pivotar
   la matriz. Se consulta SIEMPRE con SELECT * (la vista ya recorta las columnas).
   Detalle formato (AMBOS límites): 'Cu=24.2(LP3/LC4):C · Sn=1.6(LP3):P'  — value(LP..[/LC..]):sev
   (:C=crítico >LC, :P=precaución >LP; Pb/Sn/TBN sin LC; Ca/Zn/K/Na/Mg informativos).
   ---------------------------------------------------------------------------- */
CREATE OR ALTER VIEW [dbo].[vw_ObservadosDetalle] AS
SELECT
    Equipo, Proyecto, Modelo, Compartimiento,
    FechaMuestreo, HorasComponente, HorasDeAceite, CM,
    Estado_General, NumCrit, NumPrec, Detalle
FROM [dbo].[vw_ObservadosFlota]
WHERE Estado_General <> 'OK';
GO


/* ----------------------------------------------------------------------------
   vw_UltimoAnalisisFlota — DIAGNÓSTICO POR EQUIPO (todos los componentes).
   = vw_UltimoAnalisisAceite (última muestra no-DDI por componente, TODOS los
   params + LP/LC + Estado) + "Hor. Comp." real desde HsCc (mismo mapeo que el
   barrido). REUTILIZA vw_UltimoAnalisisAceite y NO toca vw_ObservadosFlota.
   Incluye componentes OK (a diferencia del barrido). Pensada para UN equipo
   (SELECT ... WHERE Equipo='CAxxxx') → el JOIN a HsCc cruza pocas filas.
   ---------------------------------------------------------------------------- */
CREATE OR ALTER VIEW [dbo].[vw_UltimoAnalisisFlota] AS
WITH hs AS (
    SELECT [EQUIPO], [SISTEMA], [SMR ULTIMO SERVICIO], [HORAS DE TRABAJO ACUMULADO ], [ESTADO SOS],
           ROW_NUMBER() OVER (PARTITION BY [EQUIPO], [SISTEMA] ORDER BY [FECHA] DESC) AS rn
    FROM [Eqpcare].[HsCc] WITH (NOLOCK)
)
SELECT
    u.*,                               -- u ya trae HorasComponente (vw_UltimoAnalisisAceite <- vw_MuestrasRankeadas)
    H.[ESTADO SOS] AS Cond_Area        -- el JOIN a HsCc queda SOLO para Cond_Area
FROM [dbo].[vw_UltimoAnalisisAceite] u
LEFT JOIN hs H
  ON  H.rn = 1
  AND ( H.[EQUIPO] = u.Equipo
        OR (H.[EQUIPO] LIKE 'T[0-9]%' AND u.Equipo = 'CA' + SUBSTRING(H.[EQUIPO], 2, 10)) )
  AND H.[SISTEMA] = CASE
        WHEN u.Compartimiento LIKE '%TRACCION%LH' THEN 'WHEEL MOTOR LH'
        WHEN u.Compartimiento LIKE '%TRACCION%RH' THEN 'WHEEL MOTOR RH'
        WHEN u.Compartimiento LIKE '%HIDRAULICO%' THEN 'HYDRAULIC'
        WHEN u.Compartimiento LIKE '%RUEDA%LH'    THEN 'SPINDLE LH'
        WHEN u.Compartimiento LIKE '%RUEDA%RH'    THEN 'SPINDLE RH'
        WHEN u.Compartimiento LIKE 'MOTOR%'       THEN 'MOTOR DIESEL'
        ELSE u.Compartimiento END
/* Excluye muestras sin componente (Compartimiento NULL/vacío): no son un
   compartimiento real y ensucian el diagnóstico (p.ej. registros CM='PM4'). */
WHERE u.Compartimiento IS NOT NULL AND LTRIM(RTRIM(u.Compartimiento)) <> '';
GO


/* ----------------------------------------------------------------------------
   10) vw_TendenciaElemento — DETALLE POR ELEMENTO de la tendencia (PASO 2),
   PRE-FORMATEADO y LIGERO (hermana de vw_ObservadosDetalle). 1 fila por
   (Equipo, Compartimiento, Parametro) sobre las 6 últimas no-DDI:
     - d1..d6 = 6 valores cronológicos (d1=+antigua, d6=última) con chip embebido.
     - f1..f6 = las 6 fechas (encabezado de la matriz).
     - LP, LC, Prom, Sigma, Tendencia, NVecesObs, Inf, Grupo, Orden.
     - EsRelevante=1 si superó su umbral en >=1 muestra (TBN/P INVERSOS: por debajo).
   PASO 2 por defecto: WHERE EsRelevante=1 (~4-8 filas). Matriz completa: sin ese filtro.
   ---------------------------------------------------------------------------- */
/* ==== vw_AcumuladoVida (bloque C, 29/09) — el acumulado REAL del componente instalado ====
   Reemplaza al CTE 'acc', que sumaba TODAS las muestras no-DDI de la fundacion... que ventanea
   a 12 MESES. O sea que el viejo "Σvida" eran 12 meses, no la vida del componente: por eso la
   cifra de Carlos no se reproducia con ningun criterio (bloque B, ronda 23/09).

   LA FORMULA, que dio Carlos y esta VALIDADA AL DECIMAL dos veces:
     - filtrar [ComponentStatus] = 'En uso'  -> las muestras del componente ACTUALMENTE instalado
     - y el tipo de muestra segun el componente, tal como lo dicto Carlos:
           MOTOR DE TRACCION -> CM IN ('ADI','C')   (la de ANTES del dializado, no la de despues)
           MOTOR             -> todas               (el motor no se dializa)
           RUEDA DELANTERA   -> solo C
           SISTEMA HIDRAULICO-> solo C
     Verificado: CA3195 MT LH Fe = 3 718,6 (bloque 137.3 y 153.3) y CA3160 MT Fe = 6 785,4,
     que es exactamente el numero que Carlos habia dado el 23/09 (bloque 153.5).

   ⚠ EL FILTRO 'En uso' SOLO SE APLICA EN MT Y MOTOR. El bloque 153.2 midio que
   [ComponentStatus] no existe en rueda ni en hidraulico (ni una fila), asi que exigirlo ahi
   los dejaria en cero y perderiamos un acumulado que el area SI pidio. En esos dos el acumulado
   NO esta acotado al componente instalado -- hay que decirselo a Carlos.
   ⛔ MANDO FINAL, TRANSMISION, CAJA GIRO, DAMPER y PTO se quedan sin Acum: para esos Carlos no
   dio regla y ademas tampoco tienen 'En uso'. Salen '—', y '—' NO ES CERO: es "no se puede
   calcular".

   ⚠ Lee [Oil].[LaboratoryData] DIRECTO, sin la fundacion y SIN la ventana de 12 meses: el
   acumulado es de toda la vida del componente, que es justo lo que la ventana impedia.
   Solo los 8 metales de DESGASTE, que son los unicos que el display muestra. */
CREATE OR ALTER VIEW [dbo].[vw_AcumuladoVida] AS
SELECT ME.[Code] AS Equipo, LD.[Compartimiento], pa.Parametro,
       CAST(SUM(pa.Valor) AS decimal(18,1)) AS Acumulado
FROM [Oil].[LaboratoryData] LD
INNER JOIN [Mine].[MiningEquipment] ME ON ME.[Id] = LD.[MiningEquipmentId]
CROSS APPLY (VALUES
    (N'Fe', LD.[Fe_ppm]), (N'PQ', LD.[Indice_PQ]), (N'Cr', LD.[Cr_ppm]), (N'Ni', LD.[Ni_ppm]),
    (N'Cu', LD.[Cu_ppm]), (N'Pb', LD.[Pb_ppm]), (N'Sn', LD.[Sn_ppm]), (N'Al', LD.[Al_ppm])
) pa(Parametro, Valor)
WHERE pa.Valor IS NOT NULL
  AND (   /* Motor de Traccion: la muestra de ANTES del dializado, mas los cambios. */
          (LD.[Compartimiento] LIKE '%TRACCION%'
           AND LD.[ComponentStatus] = N'En uso' AND LD.[CM] IN ('ADI','C'))
          /* Motor: todo, no se dializa. */
       OR (LD.[Compartimiento] LIKE 'MOTOR%' AND LD.[Compartimiento] NOT LIKE '%TRACCION%'
           AND LD.[ComponentStatus] = N'En uso')
          /* Rueda delantera y Sistema Hidraulico: solo C.
             ⚠ SIN el filtro de 'En uso', y no por descuido: el bloque 153.2 midio que
             [ComponentStatus] NO EXISTE en estos dos componentes -- ni una sola fila. Aplicar
             el filtro los dejaria en cero y perderiamos un acumulado que el area SI pidio.
             ⛔ CONSECUENCIA QUE HAY QUE DECIRLE A CARLOS: aqui el acumulado NO esta acotado al
             componente instalado, porque la base no registra cual es. Es el acumulado de todas
             las muestras 'C' del equipo en ese compartimiento. En MT y Motor si esta acotado. */
       OR (LD.[Compartimiento] LIKE '%RUEDA%'   AND LD.[CM] = 'C')
       OR (LD.[Compartimiento] LIKE '%HIDRAUL%' AND LD.[CM] = 'C') )
GROUP BY ME.[Code], LD.[Compartimiento], pa.Parametro;
GO


CREATE OR ALTER VIEW [dbo].[vw_TendenciaElemento] AS
WITH s AS (
    SELECT Equipo, Proyecto, CompTipo, Compartimiento, FechaMuestreo, rn_recencia, HorasComponente, CM, Grado,
           Modelo, Horometro,   -- contexto para el encabezado de las graficas (F3)
           Fe_ppm, Fe_LP, Fe_LC, Indice_PQ, PQ_LP, PQ_LC, Cr_ppm, Cr_LP, Cr_LC,
           Ni_ppm, Ni_LP, Ni_LC, Cu_ppm, Cu_LP, Cu_LC, Pb_ppm, Pb_LP, Pb_LC, Sn_ppm, Sn_LP, Sn_LC,
           Al_ppm, Al_LP, Al_LC, Si_ppm, Si_LP, Si_LC, Ca_ppm, Ca_LP, Ca_LC,
           Zn_ppm, Zn_LP, Zn_LC, K_ppm, K_LP, K_LC, Na_ppm, Na_LP, Na_LC, Mg_ppm, Mg_LP, Mg_LC,
           B_ppm, P_ppm, V100, TBN, TBN_LP
    FROM [dbo].[vw_MuestrasRankeadas]
    WHERE rn_recencia <= 6
),
u AS (   /* El FORMATO (grupo, orden, Inv, Inf) ya no vive aqui: viene de vw_FormatoParametro, que es
            la unica definicion y depende del COMPONENTE. Aqui solo se desdobla el valor y sus limites. */
    SELECT s.Equipo, s.Proyecto, s.CompTipo, s.Compartimiento, s.FechaMuestreo, s.rn_recencia, s.HorasComponente, s.CM, s.Grado,
           s.Modelo, s.Horometro,
           f.Parametro, f.Grupo, f.Orden, f.Inf, f.Inv,
           CAST(p.Valor AS decimal(18,2)) AS Valor,
           CAST(p.LP AS decimal(18,2))    AS LP,
           CAST(p.LC AS decimal(18,2))    AS LC
    /* Se recorre el FORMATO (no la lista de valores): asi aparecen tambien los parametros que el Excel
       pide y la BD no mide -- salen con '—'. El OUTER APPLY busca el valor si existe. */
    FROM s
    INNER JOIN [dbo].[vw_FormatoParametro] f ON f.CompTipo = s.CompTipo
    OUTER APPLY (
        SELECT v.Valor, v.LP, v.LC
        FROM (VALUES
            ('Fe',  s.Fe_ppm,    s.Fe_LP,  s.Fe_LC),
            ('PQ',  s.Indice_PQ, s.PQ_LP,  s.PQ_LC),
            ('Cr',  s.Cr_ppm,    s.Cr_LP,  s.Cr_LC),
            ('Ni',  s.Ni_ppm,    s.Ni_LP,  s.Ni_LC),
            ('Cu',  s.Cu_ppm,    s.Cu_LP,  s.Cu_LC),
            ('Pb',  s.Pb_ppm,    s.Pb_LP,  s.Pb_LC),
            ('Sn',  s.Sn_ppm,    s.Sn_LP,  s.Sn_LC),
            ('Al',  s.Al_ppm,    s.Al_LP,  s.Al_LC),
            ('Si',  s.Si_ppm,    s.Si_LP,  s.Si_LC),
            ('Ca',  s.Ca_ppm,    s.Ca_LP,  s.Ca_LC),
            ('Zn',  s.Zn_ppm,    s.Zn_LP,  s.Zn_LC),
            ('K',   s.K_ppm,     s.K_LP,   s.K_LC),
            ('Na',  s.Na_ppm,    s.Na_LP,  s.Na_LC),
            ('B',   s.B_ppm,     NULL,     NULL),
            /* ⚠ P: LP=240 HARDCODEADO, tal como estaba. vw_MuestrasRankeadas no expone P_LP/P_LC (ni los
               de B), asi que no hay de donde leerlo. El Excel dice P LP=280 / LC=240: hoy usamos el LC
               como LP. Pasarlo por la cadena de limites es un item propio del bloque C. */
            ('P',   s.P_ppm,     240,      NULL),
            ('Mg',  s.Mg_ppm,    s.Mg_LP,  s.Mg_LC),
            ('V100',s.V100,      NULL,     NULL),
            ('TBN', s.TBN,       s.TBN_LP, NULL)
        ) v(Parametro, Valor, LP, LC)
        WHERE v.Parametro = f.Parametro
    ) p
),
v AS (
    SELECT u.*,
        CONVERT(varchar(24), CAST(u.Valor AS decimal(18,1)))
        + CASE
            WHEN u.Valor IS NULL THEN ''
            WHEN u.Inv = 1 THEN CASE WHEN u.LP IS NOT NULL AND u.Valor > 0 AND u.Valor < u.LP THEN ':P' ELSE '' END
            ELSE CASE WHEN u.Valor > ISNULL(u.LC, 999999) THEN ':C'
                      WHEN u.Valor > ISNULL(u.LP, 999999) THEN ':P' ELSE '' END
          END AS Vstr,
        CASE
            WHEN u.Valor IS NULL THEN 0
            WHEN u.Inv = 1 THEN CASE WHEN u.LP IS NOT NULL AND u.Valor > 0 AND u.Valor < u.LP THEN 1 ELSE 0 END
            ELSE CASE WHEN u.Valor > ISNULL(u.LP, 999999) THEN 1 ELSE 0 END
          END AS FueraUmbral
    FROM u
)
, g AS (
SELECT
    Equipo, Compartimiento, Parametro, Grupo, Orden, Inf,
    MAX(LP) AS LP, MAX(LC) AS LC,
    MAX(CASE WHEN rn_recencia = 1 THEN HorasComponente END) AS HorasComponente,
    MAX(CASE WHEN rn_recencia = 1 THEN Grado END) AS Grado,
    MAX(CASE WHEN rn_recencia = 1 THEN Modelo END) AS Modelo,
    MAX(CASE WHEN rn_recencia = 1 THEN Horometro END) AS Horometro,
    MAX(Proyecto) AS Proyecto, MAX(CompTipo) AS CompTipo,
    MAX(CASE WHEN rn_recencia = 1 THEN CM END) AS CM,
    MAX(CASE WHEN rn_recencia = 6 THEN Vstr END) AS d1,
    MAX(CASE WHEN rn_recencia = 5 THEN Vstr END) AS d2,
    MAX(CASE WHEN rn_recencia = 4 THEN Vstr END) AS d3,
    MAX(CASE WHEN rn_recencia = 3 THEN Vstr END) AS d4,
    MAX(CASE WHEN rn_recencia = 2 THEN Vstr END) AS d5,
    MAX(CASE WHEN rn_recencia = 1 THEN Vstr END) AS d6,
    MAX(CASE WHEN rn_recencia = 6 THEN FechaMuestreo END) AS f1,
    MAX(CASE WHEN rn_recencia = 5 THEN FechaMuestreo END) AS f2,
    MAX(CASE WHEN rn_recencia = 4 THEN FechaMuestreo END) AS f3,
    MAX(CASE WHEN rn_recencia = 3 THEN FechaMuestreo END) AS f4,
    MAX(CASE WHEN rn_recencia = 2 THEN FechaMuestreo END) AS f5,
    MAX(CASE WHEN rn_recencia = 1 THEN FechaMuestreo END) AS f6,
    CAST(AVG(Valor) AS decimal(18,1)) AS Prom,
    CAST(STDEV(Valor) AS decimal(18,1)) AS Sigma,
    /* A (29/09): sobre cuantas muestras estan hechos el Prom y el sigma. Sin este numero, un
       promedio de 2 muestras se lee igual que uno de 6 -- y la grafica los pone al lado. */
    COUNT(Valor) AS NMuestras,
    SUM(FueraUmbral) AS NVecesObs,
    CASE WHEN SUM(FueraUmbral) > 0 THEN 1 ELSE 0 END AS EsRelevante,
    CASE
        WHEN MAX(CASE WHEN rn_recencia=1 THEN Valor END) > MAX(CASE WHEN rn_recencia=6 THEN Valor END) THEN N'↑'
        WHEN MAX(CASE WHEN rn_recencia=1 THEN Valor END) < MAX(CASE WHEN rn_recencia=6 THEN Valor END) THEN N'↓'
        ELSE N'→'
    END AS Tendencia,
    MAX(CASE WHEN rn_recencia = 6 THEN Valor END) AS n1,
    MAX(CASE WHEN rn_recencia = 5 THEN Valor END) AS n2,
    MAX(CASE WHEN rn_recencia = 4 THEN Valor END) AS n3,
    MAX(CASE WHEN rn_recencia = 3 THEN Valor END) AS n4,
    MAX(CASE WHEN rn_recencia = 2 THEN Valor END) AS n5,
    MAX(CASE WHEN rn_recencia = 1 THEN Valor END) AS n6
FROM v
GROUP BY Equipo, Compartimiento, Parametro, Grupo, Orden, Inf
)
SELECT
    g.Equipo, g.Proyecto, g.CompTipo, g.Compartimiento, g.Parametro, Grupo, Orden, Inf, LP, LC, HorasComponente, CM, Grado,
    Modelo, Horometro,
    d1, d2, d3, d4, d5, d6, f1, f2, f3, f4, f5, f6, Prom, Sigma, NMuestras, NVecesObs, EsRelevante, Tendencia,
    /* Spark: mini-tendencia visual (bloques ▁▂▃▄▅▆▇█) de n1..n6 cronológicos, normalizada al rango de la
       propia serie. PRE-COMPUTADA para que el central la IMPRIMA/COPIE tal cual (no regenere ASCII).
       NULL -> '·' (sin muestra esa fecha); serie plana (mx=mn) -> '▄'. */
    CONCAT(
        CASE WHEN n1 IS NULL THEN N'·' WHEN mm.mx = mm.mn THEN N'▄' ELSE SUBSTRING(N'▁▂▃▄▅▆▇█', 1 + CAST(ROUND((n1-mm.mn)/NULLIF(mm.mx-mm.mn,0)*7, 0) AS int), 1) END,
        CASE WHEN n2 IS NULL THEN N'·' WHEN mm.mx = mm.mn THEN N'▄' ELSE SUBSTRING(N'▁▂▃▄▅▆▇█', 1 + CAST(ROUND((n2-mm.mn)/NULLIF(mm.mx-mm.mn,0)*7, 0) AS int), 1) END,
        CASE WHEN n3 IS NULL THEN N'·' WHEN mm.mx = mm.mn THEN N'▄' ELSE SUBSTRING(N'▁▂▃▄▅▆▇█', 1 + CAST(ROUND((n3-mm.mn)/NULLIF(mm.mx-mm.mn,0)*7, 0) AS int), 1) END,
        CASE WHEN n4 IS NULL THEN N'·' WHEN mm.mx = mm.mn THEN N'▄' ELSE SUBSTRING(N'▁▂▃▄▅▆▇█', 1 + CAST(ROUND((n4-mm.mn)/NULLIF(mm.mx-mm.mn,0)*7, 0) AS int), 1) END,
        CASE WHEN n5 IS NULL THEN N'·' WHEN mm.mx = mm.mn THEN N'▄' ELSE SUBSTRING(N'▁▂▃▄▅▆▇█', 1 + CAST(ROUND((n5-mm.mn)/NULLIF(mm.mx-mm.mn,0)*7, 0) AS int), 1) END,
        CASE WHEN n6 IS NULL THEN N'·' WHEN mm.mx = mm.mn THEN N'▄' ELSE SUBSTRING(N'▁▂▃▄▅▆▇█', 1 + CAST(ROUND((n6-mm.mn)/NULLIF(mm.mx-mm.mn,0)*7, 0) AS int), 1) END
    ) AS Spark,
    av.Acumulado   -- Acum = suma del metal en la vida del componente INSTALADO (vw_AcumuladoVida)
FROM g
LEFT JOIN [dbo].[vw_AcumuladoVida] av
       ON av.Equipo = g.Equipo AND av.Compartimiento = g.Compartimiento AND av.Parametro = g.Parametro
CROSS APPLY (SELECT MIN(x) AS mn, MAX(x) AS mx FROM (VALUES (n1),(n2),(n3),(n4),(n5),(n6)) t(x)) mm;
GO


/* ----------------------------------------------------------------------------
   14) vw_TendenciaGrafico — GRÁFICO de tendencia (VERTICAL, multi-línea) AISLADO.
   Hermana ligera-de-consumo de vw_TendenciaElemento: 1 fila por (Equipo,Compartimiento,
   Parametro) con SOLO la columna Grafico (pesada). Se separa para que la TABLA de
   tendencia (vw_TendenciaElemento) quede LIGERA: el Grafico (multi-línea) NO viaja
   en consultas multi-componente (evita payload/SystemError). Consultar SOLO de 1
   componente cuando se pide «el gráfico»:
     SELECT Grafico FROM vw_TendenciaGrafico WHERE Equipo='..' AND Parametro='..' AND Compartimiento LIKE '%..%'
   Lee d1..d6 de vw_TendenciaElemento (parsea el número antes del chip) → no duplica CTEs.
   ---------------------------------------------------------------------------- */
CREATE OR ALTER VIEW [dbo].[vw_TendenciaGrafico] AS
SELECT te.Equipo, te.Compartimiento, te.Parametro,
    CONCAT(
        te.Parametro, N' — ', te.Compartimiento, N' (ppm)',
        CHAR(10), N'|', CASE WHEN p.n1 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n1/b0.vtop*12,0) AS int)=12 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n1 AS decimal(18,1))),9) WHEN 12=b1.rLC THEN N'·········' WHEN 12=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n2 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n2/b0.vtop*12,0) AS int)=12 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n2 AS decimal(18,1))),9) WHEN 12=b1.rLC THEN N'·········' WHEN 12=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n3 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n3/b0.vtop*12,0) AS int)=12 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n3 AS decimal(18,1))),9) WHEN 12=b1.rLC THEN N'·········' WHEN 12=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n4 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n4/b0.vtop*12,0) AS int)=12 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n4 AS decimal(18,1))),9) WHEN 12=b1.rLC THEN N'·········' WHEN 12=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n5 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n5/b0.vtop*12,0) AS int)=12 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n5 AS decimal(18,1))),9) WHEN 12=b1.rLC THEN N'·········' WHEN 12=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n6 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n6/b0.vtop*12,0) AS int)=12 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n6 AS decimal(18,1))),9) WHEN 12=b1.rLC THEN N'·········' WHEN 12=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN 12=b1.rLC THEN N' LC '+CONVERT(varchar(12),CAST(te.LC AS decimal(18,1))) WHEN 12=b1.rLP THEN N' LP '+CONVERT(varchar(12),CAST(te.LP AS decimal(18,1))) ELSE N'' END,
        CHAR(10), N'|', CASE WHEN p.n1 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n1/b0.vtop*12,0) AS int)=11 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n1 AS decimal(18,1))),9) WHEN 11=b1.rLC THEN N'·········' WHEN 11=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n2 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n2/b0.vtop*12,0) AS int)=11 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n2 AS decimal(18,1))),9) WHEN 11=b1.rLC THEN N'·········' WHEN 11=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n3 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n3/b0.vtop*12,0) AS int)=11 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n3 AS decimal(18,1))),9) WHEN 11=b1.rLC THEN N'·········' WHEN 11=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n4 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n4/b0.vtop*12,0) AS int)=11 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n4 AS decimal(18,1))),9) WHEN 11=b1.rLC THEN N'·········' WHEN 11=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n5 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n5/b0.vtop*12,0) AS int)=11 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n5 AS decimal(18,1))),9) WHEN 11=b1.rLC THEN N'·········' WHEN 11=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n6 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n6/b0.vtop*12,0) AS int)=11 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n6 AS decimal(18,1))),9) WHEN 11=b1.rLC THEN N'·········' WHEN 11=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN 11=b1.rLC THEN N' LC '+CONVERT(varchar(12),CAST(te.LC AS decimal(18,1))) WHEN 11=b1.rLP THEN N' LP '+CONVERT(varchar(12),CAST(te.LP AS decimal(18,1))) ELSE N'' END,
        CHAR(10), N'|', CASE WHEN p.n1 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n1/b0.vtop*12,0) AS int)=10 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n1 AS decimal(18,1))),9) WHEN 10=b1.rLC THEN N'·········' WHEN 10=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n2 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n2/b0.vtop*12,0) AS int)=10 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n2 AS decimal(18,1))),9) WHEN 10=b1.rLC THEN N'·········' WHEN 10=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n3 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n3/b0.vtop*12,0) AS int)=10 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n3 AS decimal(18,1))),9) WHEN 10=b1.rLC THEN N'·········' WHEN 10=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n4 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n4/b0.vtop*12,0) AS int)=10 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n4 AS decimal(18,1))),9) WHEN 10=b1.rLC THEN N'·········' WHEN 10=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n5 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n5/b0.vtop*12,0) AS int)=10 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n5 AS decimal(18,1))),9) WHEN 10=b1.rLC THEN N'·········' WHEN 10=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n6 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n6/b0.vtop*12,0) AS int)=10 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n6 AS decimal(18,1))),9) WHEN 10=b1.rLC THEN N'·········' WHEN 10=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN 10=b1.rLC THEN N' LC '+CONVERT(varchar(12),CAST(te.LC AS decimal(18,1))) WHEN 10=b1.rLP THEN N' LP '+CONVERT(varchar(12),CAST(te.LP AS decimal(18,1))) ELSE N'' END,
        CHAR(10), N'|', CASE WHEN p.n1 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n1/b0.vtop*12,0) AS int)=9 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n1 AS decimal(18,1))),9) WHEN 9=b1.rLC THEN N'·········' WHEN 9=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n2 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n2/b0.vtop*12,0) AS int)=9 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n2 AS decimal(18,1))),9) WHEN 9=b1.rLC THEN N'·········' WHEN 9=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n3 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n3/b0.vtop*12,0) AS int)=9 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n3 AS decimal(18,1))),9) WHEN 9=b1.rLC THEN N'·········' WHEN 9=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n4 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n4/b0.vtop*12,0) AS int)=9 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n4 AS decimal(18,1))),9) WHEN 9=b1.rLC THEN N'·········' WHEN 9=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n5 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n5/b0.vtop*12,0) AS int)=9 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n5 AS decimal(18,1))),9) WHEN 9=b1.rLC THEN N'·········' WHEN 9=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n6 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n6/b0.vtop*12,0) AS int)=9 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n6 AS decimal(18,1))),9) WHEN 9=b1.rLC THEN N'·········' WHEN 9=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN 9=b1.rLC THEN N' LC '+CONVERT(varchar(12),CAST(te.LC AS decimal(18,1))) WHEN 9=b1.rLP THEN N' LP '+CONVERT(varchar(12),CAST(te.LP AS decimal(18,1))) ELSE N'' END,
        CHAR(10), N'|', CASE WHEN p.n1 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n1/b0.vtop*12,0) AS int)=8 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n1 AS decimal(18,1))),9) WHEN 8=b1.rLC THEN N'·········' WHEN 8=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n2 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n2/b0.vtop*12,0) AS int)=8 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n2 AS decimal(18,1))),9) WHEN 8=b1.rLC THEN N'·········' WHEN 8=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n3 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n3/b0.vtop*12,0) AS int)=8 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n3 AS decimal(18,1))),9) WHEN 8=b1.rLC THEN N'·········' WHEN 8=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n4 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n4/b0.vtop*12,0) AS int)=8 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n4 AS decimal(18,1))),9) WHEN 8=b1.rLC THEN N'·········' WHEN 8=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n5 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n5/b0.vtop*12,0) AS int)=8 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n5 AS decimal(18,1))),9) WHEN 8=b1.rLC THEN N'·········' WHEN 8=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n6 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n6/b0.vtop*12,0) AS int)=8 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n6 AS decimal(18,1))),9) WHEN 8=b1.rLC THEN N'·········' WHEN 8=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN 8=b1.rLC THEN N' LC '+CONVERT(varchar(12),CAST(te.LC AS decimal(18,1))) WHEN 8=b1.rLP THEN N' LP '+CONVERT(varchar(12),CAST(te.LP AS decimal(18,1))) ELSE N'' END,
        CHAR(10), N'|', CASE WHEN p.n1 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n1/b0.vtop*12,0) AS int)=7 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n1 AS decimal(18,1))),9) WHEN 7=b1.rLC THEN N'·········' WHEN 7=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n2 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n2/b0.vtop*12,0) AS int)=7 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n2 AS decimal(18,1))),9) WHEN 7=b1.rLC THEN N'·········' WHEN 7=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n3 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n3/b0.vtop*12,0) AS int)=7 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n3 AS decimal(18,1))),9) WHEN 7=b1.rLC THEN N'·········' WHEN 7=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n4 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n4/b0.vtop*12,0) AS int)=7 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n4 AS decimal(18,1))),9) WHEN 7=b1.rLC THEN N'·········' WHEN 7=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n5 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n5/b0.vtop*12,0) AS int)=7 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n5 AS decimal(18,1))),9) WHEN 7=b1.rLC THEN N'·········' WHEN 7=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n6 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n6/b0.vtop*12,0) AS int)=7 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n6 AS decimal(18,1))),9) WHEN 7=b1.rLC THEN N'·········' WHEN 7=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN 7=b1.rLC THEN N' LC '+CONVERT(varchar(12),CAST(te.LC AS decimal(18,1))) WHEN 7=b1.rLP THEN N' LP '+CONVERT(varchar(12),CAST(te.LP AS decimal(18,1))) ELSE N'' END,
        CHAR(10), N'|', CASE WHEN p.n1 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n1/b0.vtop*12,0) AS int)=6 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n1 AS decimal(18,1))),9) WHEN 6=b1.rLC THEN N'·········' WHEN 6=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n2 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n2/b0.vtop*12,0) AS int)=6 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n2 AS decimal(18,1))),9) WHEN 6=b1.rLC THEN N'·········' WHEN 6=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n3 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n3/b0.vtop*12,0) AS int)=6 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n3 AS decimal(18,1))),9) WHEN 6=b1.rLC THEN N'·········' WHEN 6=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n4 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n4/b0.vtop*12,0) AS int)=6 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n4 AS decimal(18,1))),9) WHEN 6=b1.rLC THEN N'·········' WHEN 6=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n5 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n5/b0.vtop*12,0) AS int)=6 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n5 AS decimal(18,1))),9) WHEN 6=b1.rLC THEN N'·········' WHEN 6=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n6 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n6/b0.vtop*12,0) AS int)=6 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n6 AS decimal(18,1))),9) WHEN 6=b1.rLC THEN N'·········' WHEN 6=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN 6=b1.rLC THEN N' LC '+CONVERT(varchar(12),CAST(te.LC AS decimal(18,1))) WHEN 6=b1.rLP THEN N' LP '+CONVERT(varchar(12),CAST(te.LP AS decimal(18,1))) ELSE N'' END,
        CHAR(10), N'|', CASE WHEN p.n1 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n1/b0.vtop*12,0) AS int)=5 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n1 AS decimal(18,1))),9) WHEN 5=b1.rLC THEN N'·········' WHEN 5=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n2 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n2/b0.vtop*12,0) AS int)=5 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n2 AS decimal(18,1))),9) WHEN 5=b1.rLC THEN N'·········' WHEN 5=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n3 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n3/b0.vtop*12,0) AS int)=5 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n3 AS decimal(18,1))),9) WHEN 5=b1.rLC THEN N'·········' WHEN 5=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n4 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n4/b0.vtop*12,0) AS int)=5 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n4 AS decimal(18,1))),9) WHEN 5=b1.rLC THEN N'·········' WHEN 5=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n5 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n5/b0.vtop*12,0) AS int)=5 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n5 AS decimal(18,1))),9) WHEN 5=b1.rLC THEN N'·········' WHEN 5=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n6 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n6/b0.vtop*12,0) AS int)=5 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n6 AS decimal(18,1))),9) WHEN 5=b1.rLC THEN N'·········' WHEN 5=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN 5=b1.rLC THEN N' LC '+CONVERT(varchar(12),CAST(te.LC AS decimal(18,1))) WHEN 5=b1.rLP THEN N' LP '+CONVERT(varchar(12),CAST(te.LP AS decimal(18,1))) ELSE N'' END,
        CHAR(10), N'|', CASE WHEN p.n1 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n1/b0.vtop*12,0) AS int)=4 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n1 AS decimal(18,1))),9) WHEN 4=b1.rLC THEN N'·········' WHEN 4=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n2 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n2/b0.vtop*12,0) AS int)=4 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n2 AS decimal(18,1))),9) WHEN 4=b1.rLC THEN N'·········' WHEN 4=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n3 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n3/b0.vtop*12,0) AS int)=4 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n3 AS decimal(18,1))),9) WHEN 4=b1.rLC THEN N'·········' WHEN 4=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n4 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n4/b0.vtop*12,0) AS int)=4 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n4 AS decimal(18,1))),9) WHEN 4=b1.rLC THEN N'·········' WHEN 4=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n5 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n5/b0.vtop*12,0) AS int)=4 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n5 AS decimal(18,1))),9) WHEN 4=b1.rLC THEN N'·········' WHEN 4=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n6 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n6/b0.vtop*12,0) AS int)=4 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n6 AS decimal(18,1))),9) WHEN 4=b1.rLC THEN N'·········' WHEN 4=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN 4=b1.rLC THEN N' LC '+CONVERT(varchar(12),CAST(te.LC AS decimal(18,1))) WHEN 4=b1.rLP THEN N' LP '+CONVERT(varchar(12),CAST(te.LP AS decimal(18,1))) ELSE N'' END,
        CHAR(10), N'|', CASE WHEN p.n1 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n1/b0.vtop*12,0) AS int)=3 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n1 AS decimal(18,1))),9) WHEN 3=b1.rLC THEN N'·········' WHEN 3=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n2 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n2/b0.vtop*12,0) AS int)=3 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n2 AS decimal(18,1))),9) WHEN 3=b1.rLC THEN N'·········' WHEN 3=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n3 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n3/b0.vtop*12,0) AS int)=3 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n3 AS decimal(18,1))),9) WHEN 3=b1.rLC THEN N'·········' WHEN 3=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n4 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n4/b0.vtop*12,0) AS int)=3 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n4 AS decimal(18,1))),9) WHEN 3=b1.rLC THEN N'·········' WHEN 3=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n5 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n5/b0.vtop*12,0) AS int)=3 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n5 AS decimal(18,1))),9) WHEN 3=b1.rLC THEN N'·········' WHEN 3=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n6 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n6/b0.vtop*12,0) AS int)=3 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n6 AS decimal(18,1))),9) WHEN 3=b1.rLC THEN N'·········' WHEN 3=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN 3=b1.rLC THEN N' LC '+CONVERT(varchar(12),CAST(te.LC AS decimal(18,1))) WHEN 3=b1.rLP THEN N' LP '+CONVERT(varchar(12),CAST(te.LP AS decimal(18,1))) ELSE N'' END,
        CHAR(10), N'|', CASE WHEN p.n1 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n1/b0.vtop*12,0) AS int)=2 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n1 AS decimal(18,1))),9) WHEN 2=b1.rLC THEN N'·········' WHEN 2=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n2 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n2/b0.vtop*12,0) AS int)=2 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n2 AS decimal(18,1))),9) WHEN 2=b1.rLC THEN N'·········' WHEN 2=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n3 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n3/b0.vtop*12,0) AS int)=2 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n3 AS decimal(18,1))),9) WHEN 2=b1.rLC THEN N'·········' WHEN 2=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n4 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n4/b0.vtop*12,0) AS int)=2 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n4 AS decimal(18,1))),9) WHEN 2=b1.rLC THEN N'·········' WHEN 2=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n5 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n5/b0.vtop*12,0) AS int)=2 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n5 AS decimal(18,1))),9) WHEN 2=b1.rLC THEN N'·········' WHEN 2=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n6 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n6/b0.vtop*12,0) AS int)=2 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n6 AS decimal(18,1))),9) WHEN 2=b1.rLC THEN N'·········' WHEN 2=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN 2=b1.rLC THEN N' LC '+CONVERT(varchar(12),CAST(te.LC AS decimal(18,1))) WHEN 2=b1.rLP THEN N' LP '+CONVERT(varchar(12),CAST(te.LP AS decimal(18,1))) ELSE N'' END,
        CHAR(10), N'|', CASE WHEN p.n1 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n1/b0.vtop*12,0) AS int)=1 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n1 AS decimal(18,1))),9) WHEN 1=b1.rLC THEN N'·········' WHEN 1=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n2 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n2/b0.vtop*12,0) AS int)=1 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n2 AS decimal(18,1))),9) WHEN 1=b1.rLC THEN N'·········' WHEN 1=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n3 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n3/b0.vtop*12,0) AS int)=1 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n3 AS decimal(18,1))),9) WHEN 1=b1.rLC THEN N'·········' WHEN 1=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n4 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n4/b0.vtop*12,0) AS int)=1 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n4 AS decimal(18,1))),9) WHEN 1=b1.rLC THEN N'·········' WHEN 1=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n5 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n5/b0.vtop*12,0) AS int)=1 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n5 AS decimal(18,1))),9) WHEN 1=b1.rLC THEN N'·········' WHEN 1=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n6 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n6/b0.vtop*12,0) AS int)=1 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n6 AS decimal(18,1))),9) WHEN 1=b1.rLC THEN N'·········' WHEN 1=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN 1=b1.rLC THEN N' LC '+CONVERT(varchar(12),CAST(te.LC AS decimal(18,1))) WHEN 1=b1.rLP THEN N' LP '+CONVERT(varchar(12),CAST(te.LP AS decimal(18,1))) ELSE N'' END,
        CHAR(10), N'+', CASE WHEN te.f1 IS NULL THEN N'         ' ELSE RIGHT(N'         '+CONVERT(varchar(2),DAY(te.f1)),9) END, CASE WHEN te.f2 IS NULL THEN N'         ' ELSE RIGHT(N'         '+CONVERT(varchar(2),DAY(te.f2)),9) END, CASE WHEN te.f3 IS NULL THEN N'         ' ELSE RIGHT(N'         '+CONVERT(varchar(2),DAY(te.f3)),9) END, CASE WHEN te.f4 IS NULL THEN N'         ' ELSE RIGHT(N'         '+CONVERT(varchar(2),DAY(te.f4)),9) END, CASE WHEN te.f5 IS NULL THEN N'         ' ELSE RIGHT(N'         '+CONVERT(varchar(2),DAY(te.f5)),9) END, CASE WHEN te.f6 IS NULL THEN N'         ' ELSE RIGHT(N'         '+CONVERT(varchar(2),DAY(te.f6)),9) END, N' ', CHOOSE(MONTH(te.f6), N'Jan',N'Feb',N'Mar',N'Apr',N'May',N'Jun',N'Jul',N'Aug',N'Sep',N'Oct',N'Nov',N'Dec')
    ) AS Grafico
FROM [dbo].[vw_TendenciaElemento] te
CROSS APPLY (SELECT TRY_CONVERT(decimal(18,2), LEFT(te.d1, CHARINDEX(':', te.d1+':')-1)) AS n1,
        TRY_CONVERT(decimal(18,2), LEFT(te.d2, CHARINDEX(':', te.d2+':')-1)) AS n2,
        TRY_CONVERT(decimal(18,2), LEFT(te.d3, CHARINDEX(':', te.d3+':')-1)) AS n3,
        TRY_CONVERT(decimal(18,2), LEFT(te.d4, CHARINDEX(':', te.d4+':')-1)) AS n4,
        TRY_CONVERT(decimal(18,2), LEFT(te.d5, CHARINDEX(':', te.d5+':')-1)) AS n5,
        TRY_CONVERT(decimal(18,2), LEFT(te.d6, CHARINDEX(':', te.d6+':')-1)) AS n6) p
CROSS APPLY (SELECT MIN(x) AS mn, MAX(x) AS mx FROM (VALUES (p.n1),(p.n2),(p.n3),(p.n4),(p.n5),(p.n6)) t(x)) mm
CROSS APPLY (SELECT CASE WHEN ISNULL(te.LC,0) > ISNULL(mm.mx,0) THEN te.LC ELSE mm.mx END AS vtop) b0
CROSS APPLY (SELECT CASE WHEN b0.vtop>0 AND te.LC IS NOT NULL THEN CAST(ROUND(te.LC/b0.vtop*12,0) AS int) ELSE -1 END AS rLC,
                    CASE WHEN b0.vtop>0 AND te.LP IS NOT NULL THEN CAST(ROUND(te.LP/b0.vtop*12,0) AS int) ELSE -1 END AS rLP) b1;
GO


/* ----------------------------------------------------------------------------
   11) vw_HistorialMuestra — HISTORIAL muestra por muestra (últimos 2 meses, horneados).
   1 fila por MUESTRA (INCLUYE DDI, flag EsDDI), últimos 2 MESES (ventana horneada en la vista), PRE-FORMATEADA: cada parámetro
   ya trae su chip (marcador :C >LC, :P >LP; informativos Ca/Zn/K/Mg; TBN inverso).
   A diferencia de la tendencia (params en filas, 6 fechas), aquí las FECHAS van en
   FILAS (orden descendente al consultar) y los params en columnas -> tabla "cantidad
   de datos", sin estadistica. LIGERA: ventana 2 meses + columnas chip (no LP/LC).
   Reutiliza vw_MuestrasEstado (Estado_<metal> ya calculado). Se consulta por
   Equipo + Compartimiento: SELECT * FROM vw_HistorialMuestra WHERE Equipo='..'
   AND Compartimiento LIKE '%..%' ORDER BY FechaMuestreo DESC. (la vista ya acota 2 meses)
   ---------------------------------------------------------------------------- */
CREATE OR ALTER VIEW [dbo].[vw_HistorialMuestra] AS
WITH hs AS (
    -- HsCc pre-rankeado: 1 fila (la más reciente) por EQUIPO+SISTEMA. Se escanea UNA vez
    -- (antes era subconsulta correlacionada por fila → HsCc escaneado 2112x). Alias Eq/Sis/Smr/Hta
    -- evitan ambiguedad con me.Equipo. Mapeo EQUIPO 'T####'->'CA####' y SISTEMA inglés<->compartimiento.
    SELECT [EQUIPO] AS Eq, [SISTEMA] AS Sis,
           TRY_CONVERT(decimal(12,2),[SMR ULTIMO SERVICIO])        AS Smr,
           TRY_CONVERT(decimal(12,2),[HORAS DE TRABAJO ACUMULADO ]) AS Hta,
           ROW_NUMBER() OVER (PARTITION BY [EQUIPO],[SISTEMA] ORDER BY [FECHA] DESC) AS rn
    FROM [Eqpcare].[HsCc]
)
SELECT
    Equipo, Proyecto, Modelo, Compartimiento, FechaMuestreo,
    Horometro, HorasDeAceite, CM, EsDDI, Estado_General,
    /* Met. Obs. = metales fuera de umbral de ESA muestra (determinantes + informativos),
       reusa Estado_<metal> ya calculados. Para variantes 1/4/5 del historial. */
    STUFF(CONCAT(
        CASE Estado_Fe  WHEN 'CRITICO' THEN ',Fe:C'  WHEN 'PRECAUCION' THEN ',Fe:P'  ELSE '' END,
        CASE Estado_PQ  WHEN 'CRITICO' THEN ',PQ:C'  WHEN 'PRECAUCION' THEN ',PQ:P'  ELSE '' END,
        CASE Estado_Cr  WHEN 'CRITICO' THEN ',Cr:C'  WHEN 'PRECAUCION' THEN ',Cr:P'  ELSE '' END,
        CASE Estado_Ni  WHEN 'CRITICO' THEN ',Ni:C'  WHEN 'PRECAUCION' THEN ',Ni:P'  ELSE '' END,
        CASE Estado_Cu  WHEN 'CRITICO' THEN ',Cu:C'  WHEN 'PRECAUCION' THEN ',Cu:P'  ELSE '' END,
        CASE Estado_Pb  WHEN 'PRECAUCION' THEN ',Pb:P' ELSE '' END,
        CASE Estado_Sn  WHEN 'PRECAUCION' THEN ',Sn:P' ELSE '' END,
        CASE Estado_Al  WHEN 'CRITICO' THEN ',Al:C'  WHEN 'PRECAUCION' THEN ',Al:P'  ELSE '' END,
        CASE Estado_Si  WHEN 'CRITICO' THEN ',Si:C'  WHEN 'PRECAUCION' THEN ',Si:P'  ELSE '' END,
        CASE Estado_TBN WHEN 'PRECAUCION' THEN ',TBN:P' ELSE '' END,
        CASE Estado_Ca  WHEN 'CRITICO' THEN ',Ca:C' WHEN 'PRECAUCION' THEN ',Ca:P' ELSE '' END,
        CASE Estado_Zn  WHEN 'CRITICO' THEN ',Zn:C' WHEN 'PRECAUCION' THEN ',Zn:P' ELSE '' END,
        CASE Estado_K   WHEN 'CRITICO' THEN ',K:C'  WHEN 'PRECAUCION' THEN ',K:P'  ELSE '' END,
        CASE Estado_Na  WHEN 'CRITICO' THEN ',Na:C' WHEN 'PRECAUCION' THEN ',Na:P' ELSE '' END,
        CASE Estado_Mg  WHEN 'CRITICO' THEN ',Mg:C' WHEN 'PRECAUCION' THEN ',Mg:P' ELSE '' END
    ), 1, 1, '') AS Mets_Obs,
    CONVERT(varchar(20),CAST(Fe_ppm    AS decimal(18,1))) + CASE Estado_Fe  WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Fe,
    CONVERT(varchar(20),CAST(Indice_PQ AS decimal(18,1))) + CASE Estado_PQ  WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS PQ,
    CONVERT(varchar(20),CAST(Cr_ppm    AS decimal(18,1))) + CASE Estado_Cr  WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Cr,
    CONVERT(varchar(20),CAST(Ni_ppm    AS decimal(18,1))) + CASE Estado_Ni  WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Ni,
    CONVERT(varchar(20),CAST(Cu_ppm    AS decimal(18,1))) + CASE Estado_Cu  WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Cu,
    CONVERT(varchar(20),CAST(Pb_ppm    AS decimal(18,1))) + CASE Estado_Pb  WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Pb,
    CONVERT(varchar(20),CAST(Sn_ppm    AS decimal(18,1))) + CASE Estado_Sn  WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Sn,
    CONVERT(varchar(20),CAST(Al_ppm    AS decimal(18,1))) + CASE Estado_Al  WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Al,
    CONVERT(varchar(20),CAST(Si_ppm    AS decimal(18,1))) + CASE Estado_Si  WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Si,
    CONVERT(varchar(20),CAST(Ca_ppm    AS decimal(18,1))) + CASE Estado_Ca  WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Ca,
    CONVERT(varchar(20),CAST(Zn_ppm    AS decimal(18,1))) + CASE Estado_Zn  WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Zn,
    CONVERT(varchar(20),CAST(K_ppm     AS decimal(18,1))) + CASE Estado_K   WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS K,
    CONVERT(varchar(20),CAST(Na_ppm    AS decimal(18,1))) + CASE Estado_Na  WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Na,
    CONVERT(varchar(20),CAST(Mg_ppm    AS decimal(18,1))) + CASE Estado_Mg  WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Mg,
    CONVERT(varchar(20),CAST(B_ppm     AS decimal(18,1))) AS B,
    CONVERT(varchar(20),CAST(P_ppm     AS decimal(18,1))) AS P,
    CONVERT(varchar(20),CAST(V100      AS decimal(18,1))) AS V100,
    CONVERT(varchar(20),CAST(TBN       AS decimal(18,1))) + CASE Estado_TBN WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS TBN,
    CASE WHEN H.Smr IS NOT NULL AND me.Horometro >= H.Smr THEN me.Horometro - H.Smr ELSE H.Hta END AS HorasComponente
FROM [dbo].[vw_MuestrasEstado] me
LEFT JOIN hs H
  ON  H.rn = 1
  AND ( H.Eq = me.Equipo OR (H.Eq LIKE 'T[0-9]%' AND me.Equipo = 'CA'+SUBSTRING(H.Eq,2,10)) )
  AND H.Sis = CASE WHEN me.Compartimiento LIKE '%TRACCION%LH' THEN 'WHEEL MOTOR LH'
                   WHEN me.Compartimiento LIKE '%TRACCION%RH' THEN 'WHEEL MOTOR RH'
                   WHEN me.Compartimiento LIKE '%HIDRAULICO%' THEN 'HYDRAULIC'
                   WHEN me.Compartimiento LIKE '%RUEDA%LH'    THEN 'SPINDLE LH'
                   WHEN me.Compartimiento LIKE '%RUEDA%RH'    THEN 'SPINDLE RH'
                   WHEN me.Compartimiento LIKE 'MOTOR%'       THEN 'MOTOR DIESEL'
                   ELSE me.Compartimiento END
WHERE me.Compartimiento IS NOT NULL
  AND me.FechaMuestreo >= DATEADD(MONTH, -2, GETDATE());   -- ventana 2 meses HORNEADA (a prueba de error del agente)
GO



/* ----------------------------------------------------------------------------
   12) vw_DiagnosticoEquipo — DIAGNÓSTICO por equipo, PRE-FORMATEADO (anti-corte).
   1 fila por COMPONENTE (último análisis no-DDI, TODOS los componentes incl. OK),
   con cada parámetro YA chip-marcado (:C >LC, :P >LP; informativos;
   TBN inverso). + HorasComponente (HsCc). El central solo PIVOTA componente x
   parametro y PINTA (no computa chips ni carga 58 columnas crudas) -> no se corta.
   Espejo de vw_HistorialMuestra pero sobre vw_UltimoAnalisisFlota. Consultar por
   Equipo: SELECT * FROM vw_DiagnosticoEquipo WHERE Equipo='CAxxxx' ORDER BY Compartimiento.
   ---------------------------------------------------------------------------- */
CREATE OR ALTER VIEW [dbo].[vw_DiagnosticoEquipo] AS
SELECT
    Equipo, Proyecto, Modelo, Compartimiento, CompTipo, FechaMuestreo,
    Horometro, HorasDeAceite, HorasComponente, CM, Grado, Estado_General, Cond_Area,
    -- conteos por equipo (sobre TODOS los componentes) para el encabezado «X de N observados»
    -- aunque el central filtre Estado_General<>'OK': los window se calculan antes del filtro.
    COUNT(*) OVER (PARTITION BY Equipo) AS NumCompTotal,
    SUM(CASE WHEN Estado_General <> 'OK' THEN 1 ELSE 0 END) OVER (PARTITION BY Equipo) AS NumCompObs,
    CONVERT(varchar(20),CAST(Fe_ppm    AS decimal(18,1))) + CASE Estado_Fe  WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Fe,
    CONVERT(varchar(20),CAST(Indice_PQ AS decimal(18,1))) + CASE Estado_PQ  WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS PQ,
    CONVERT(varchar(20),CAST(Cr_ppm    AS decimal(18,1))) + CASE Estado_Cr  WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Cr,
    CONVERT(varchar(20),CAST(Ni_ppm    AS decimal(18,1))) + CASE Estado_Ni  WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Ni,
    CONVERT(varchar(20),CAST(Cu_ppm    AS decimal(18,1))) + CASE Estado_Cu  WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Cu,
    CONVERT(varchar(20),CAST(Pb_ppm    AS decimal(18,1))) + CASE Estado_Pb  WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Pb,
    CONVERT(varchar(20),CAST(Sn_ppm    AS decimal(18,1))) + CASE Estado_Sn  WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Sn,
    CONVERT(varchar(20),CAST(Al_ppm    AS decimal(18,1))) + CASE Estado_Al  WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Al,
    CONVERT(varchar(20),CAST(Si_ppm    AS decimal(18,1))) + CASE Estado_Si  WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Si,
    CONVERT(varchar(20),CAST(Ca_ppm    AS decimal(18,1))) + CASE Estado_Ca  WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Ca,
    CONVERT(varchar(20),CAST(Zn_ppm    AS decimal(18,1))) + CASE Estado_Zn  WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Zn,
    CONVERT(varchar(20),CAST(K_ppm     AS decimal(18,1))) + CASE Estado_K   WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS K,
    CONVERT(varchar(20),CAST(Na_ppm    AS decimal(18,1))) + CASE Estado_Na  WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Na,
    CONVERT(varchar(20),CAST(Mg_ppm    AS decimal(18,1))) + CASE Estado_Mg  WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Mg,
    /* D6 (28/09): B y P dejan de ser valor suelto -- ahora llevan marca, porque D3 les dio
       limite. Y entran los 13 del formato que faltaban. El TBN ya distingue critico. */
    CONVERT(varchar(20),CAST(B_ppm      AS decimal(18,1))) + CASE Estado_B      WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS B,
    CONVERT(varchar(20),CAST(P_ppm      AS decimal(18,1))) + CASE Estado_P      WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS P,
    CONVERT(varchar(20),CAST(Mo_ppm     AS decimal(18,1))) + CASE Estado_Mo     WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Mo,
    CONVERT(varchar(20),CAST(TAN        AS decimal(18,1))) + CASE Estado_TAN    WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS TAN,
    CONVERT(varchar(20),CAST(Oxidacion  AS decimal(18,1))) + CASE Estado_Oxi    WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Oxidacion,
    CONVERT(varchar(20),CAST(Sulfatacion AS decimal(18,1))) + CASE Estado_Sulf   WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Sulfatacion,
    CONVERT(varchar(20),CAST(Nitracion  AS decimal(18,1))) + CASE Estado_Nit    WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Nitracion,
    CONVERT(varchar(20),CAST(Hollin     AS decimal(18,1))) + CASE Estado_Hollin WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Hollin,
    CONVERT(varchar(20),CAST(Diesel     AS decimal(18,1))) + CASE Estado_Diesel WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Diesel,
    CONVERT(varchar(20),CAST(Agua       AS decimal(18,1))) + CASE Estado_Agua   WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Agua,
    CONVERT(varchar(20),CAST(ISO4       AS decimal(18,1))) + CASE Estado_ISO4   WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS ISO4,
    CONVERT(varchar(20),CAST(ISO6       AS decimal(18,1))) + CASE Estado_ISO6   WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS ISO6,
    CONVERT(varchar(20),CAST(ISO14      AS decimal(18,1))) + CASE Estado_ISO14  WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS ISO14,
    CONVERT(varchar(20),CAST(V40        AS decimal(18,1))) + CASE Estado_V40    WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS V40,
    CONVERT(varchar(20),CAST(Refrigerante AS decimal(18,1))) AS Refrigerante,
    CONVERT(varchar(20),CAST(V100      AS decimal(18,1))) AS V100,
    Estado_V100,
    CONVERT(varchar(20),CAST(TBN       AS decimal(18,1))) + CASE Estado_TBN WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS TBN
FROM [dbo].[vw_UltimoAnalisisFlota];
GO


/* ----------------------------------------------------------------------------
   13) vw_HistorialFlotaObs — HISTORIAL DE OBSERVADOS EN FLOTA (variante 5), AGREGADO
   POR FECHA y LIGERO (solución directa, anti-timeout). 1 fila por (Proyecto,Modelo,
   Fecha): equipos/componentes/metales observados ese día (distintos). Ventana 30 días
   (más corta que el historial por-equipo: la flota completa por 2 meses se colgaba).
   NO trae los 17 params ni Hor. Comp. → no dispara la subconsulta lenta. El central
   PINTA directo (Fec | NumEquipos | Equip.Obs | Comp.Obs | Met.Obs), NO agrega él.
   ---------------------------------------------------------------------------- */
CREATE OR ALTER VIEW [dbo].[vw_HistorialFlotaObs] AS
WITH obs AS (
    SELECT Proyecto, Modelo, FechaMuestreo, Equipo, Compartimiento, Mets_Obs
    FROM [dbo].[vw_HistorialMuestra]
    WHERE Mets_Obs IS NOT NULL
      AND FechaMuestreo >= DATEADD(DAY, -30, GETDATE())
),
eq AS (
    SELECT Proyecto, Modelo, FechaMuestreo, COUNT(*) AS NumEquipos,
           STRING_AGG(Equipo, ', ') WITHIN GROUP (ORDER BY Equipo) AS Equip_Obs
    FROM (SELECT DISTINCT Proyecto, Modelo, FechaMuestreo, Equipo FROM obs) d
    GROUP BY Proyecto, Modelo, FechaMuestreo
),
cp AS (
    SELECT Proyecto, Modelo, FechaMuestreo,
           STRING_AGG(Compartimiento, ' · ') WITHIN GROUP (ORDER BY Compartimiento) AS Comp_Obs
    FROM (SELECT DISTINCT Proyecto, Modelo, FechaMuestreo, Compartimiento FROM obs) d
    GROUP BY Proyecto, Modelo, FechaMuestreo
),
mt AS (
    SELECT Proyecto, Modelo, FechaMuestreo,
           STRING_AGG(Metal, ', ') WITHIN GROUP (ORDER BY Metal) AS Met_Obs
    FROM (SELECT DISTINCT o.Proyecto, o.Modelo, o.FechaMuestreo,
                 LTRIM(LEFT(s.value, CHARINDEX(':', s.value + ':') - 1)) AS Metal
          FROM obs o CROSS APPLY STRING_SPLIT(o.Mets_Obs, ',') s) d
    GROUP BY Proyecto, Modelo, FechaMuestreo
)
SELECT eq.Proyecto, eq.Modelo, eq.FechaMuestreo, eq.NumEquipos,
       eq.Equip_Obs, cp.Comp_Obs, mt.Met_Obs
FROM eq
JOIN cp ON cp.Proyecto=eq.Proyecto AND cp.Modelo=eq.Modelo AND cp.FechaMuestreo=eq.FechaMuestreo
JOIN mt ON mt.Proyecto=eq.Proyecto AND mt.Modelo=eq.Modelo AND mt.FechaMuestreo=eq.FechaMuestreo;
GO


/* ============================================================================
   VALIDACIÓN  (queries de ejemplo; cópialas fuera de este comentario para correrlas)
   ----------------------------------------------------------------------------
   -- (A) Cadena base — Ca/Zn con límites y estado; y que el triage MT no cambió:
   SELECT Equipo, Compartimiento, Si_ppm, Ca_ppm, Ca_LP, Zn_ppm, Zn_LP, B_ppm, P_ppm, V100
   FROM [dbo].[vw_EstadoActualMT] WITH (NOLOCK) WHERE Equipo='CA3171';
   SELECT COUNT(*) FROM [dbo].[vw_EstadoActualMT] WITH (NOLOCK)
     WHERE Proyecto LIKE '%Antapaccay%' AND Estado_General <> 'OK';

   -- (B) Determinismo (desempate por LaboratoryDataId en fechas empatadas):
   SELECT FechaMuestreo, LaboratoryDataId, Fe_ppm, rn_recencia
   FROM [dbo].[vw_MuestrasRankeadas] WITH (NOLOCK)
   WHERE Equipo='CA3171' AND Compartimiento LIKE '%TRACCION%LH' ORDER BY rn_recencia;

   -- (C) Límites por MODELO (deben variar en HIDRAULICO; TRACCION por proyecto):
   SELECT ProyKey, ModeloKey, CompTipo, Fe_LP, Fe_LC, Cu_LP, Cu_LC
   FROM [dbo].[vw_LimitesPorComponente] WITH (NOLOCK)
   WHERE CompTipo IN ('TRACCION','HIDRAULICO') ORDER BY CompTipo, ProyKey, ModeloKey;

   -- (D) BARRIDO — observados de flota con horas de componente reales (HsCc):
   SELECT Equipo, Compartimiento, FechaMuestreo, Horometro, HorasDeAceite,
          HorasComponente, Cond_Area, Estado_General, Mets_Obs, Infs_Obs, NumCrit, NumPrec
   FROM [dbo].[vw_ObservadosFlota] WITH (NOLOCK)
   WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%' AND Mets_Obs IS NOT NULL
   ORDER BY NumCrit DESC, NumPrec DESC, Equipo;

   -- (E) BARRIDO PASO 2 — detalle ligero pre-formateado (lo que consume el central):
   SELECT * FROM [dbo].[vw_ObservadosDetalle] WITH (NOLOCK)
   WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%'
   ORDER BY NumCrit DESC, Equipo, Compartimiento;

   REVERTIR todo:  DROP VIEW en orden inverso (vw_HistorialFlotaObs → vw_HistorialMuestra → vw_TendenciaElemento →
   vw_UltimoAnalisisFlota → vw_ObservadosDetalle → vw_ObservadosResumen → vw_ObservadosFlota →
   vw_EstadoActualMT → vw_UltimoAnalisisAceite → vw_MuestrasRankeadas → vw_MuestrasEstado →
   vw_LimitesPorComponente).
   ============================================================================ */


/* ============================================================================
   vw_ObservadosBarridoMD — TIER 2 (render determinístico / copia verbatim).
   Pre-arma EL BLOQUE MARKDOWN del DETALLE de barrido ("detalle de todos"), el
   caso lento (~2 min de render del central con flotas grandes). En vez de que el
   LLM pivotee/escriba la tabla token por token, la VISTA la entrega YA armada y
   el central la imprime VERBATIM. 1 fila por Proyecto+Modelo.
     - DetalleTodosMD: bloque markdown completo, agrupado por componente (críticos
       primero), cada sección con su mini-tabla | Equipo | Fec. | Hor.Comp. | T. muestra |
       Est. | Observado |. Observado = columna Detalle con :C/:P → 🟥/🟨.
     - NumEquipos / NumEquiposCriticos / NumEquiposSoloPrecau: cifras para que el
       central redacte un RESUMEN corto y gerencial (pocos tokens = rápido).
   ⚠ Contiene emojis (🟥🟨): al crear la vista, ABRIR/EJECUTAR este .sql en SSMS
   desde el archivo (UTF-8), NO re-tipear ni pegar por un canal que los pierda.
   Depende de vw_ObservadosDetalle (bloque) y vw_ObservadosResumen (cifras).
   Validación: VALIDACION_SSMS.sql BLOQUE 32.
   ---------------------------------------------------------------------------- */
CREATE OR ALTER VIEW [dbo].[vw_ObservadosBarridoMD] AS
/* 30/09 -- FILTRO ABAJO (mismo patron que curo /condicionmt: 146 s -> 1,4 s, y /diagcompleto).
   La logica va en CROSS APPLY sobre [Mine].[MiningProject] y CADA lectura pesada lleva el filtro
   (Proyecto = mp.[Name]), asi que ninguna rama calcula mas que ese proyecto. Los CTE van desplegados:
   un APPLY no admite WITH y SQL Server ya los trata como macros. Misma logica y salida. Respaldo: respaldo/DDL_vistas_2026-09-30_antes_filtro_abajo.sql */
SELECT mp.[Name] AS Proyecto, x.[Modelo], x.[NumEquipos], x.[NumEquiposCriticos], x.[NumEquiposSoloPrecau], x.[Observados], x.[Recomendaciones], x.[MD], x.[DetalleTodosMD], x.[MD_Criticos], x.[MD_Precaucion]
FROM [Mine].[MiningProject] mp
CROSS APPLY (
SELECT
    ta.Proyecto, ta.Modelo,
    c.NumEquipos, c.NumEquiposCriticos, c.NumEquiposSoloPrecau,
    CAST(NULL AS nvarchar(max)) AS Observados, CAST(NULL AS nvarchar(max)) AS Recomendaciones,
    CAST(
        N'**Detalle de todos — flota observada, agrupado por componente**' + NCHAR(10) + NCHAR(10)
      + CASE WHEN ta.Modelo <> N'(todos)'
                  AND NOT EXISTS (SELECT 1 FROM [dbo].[vw_ModeloConLimites] ml
                                  WHERE ml.ProyKey   = UPPER(LTRIM(RTRIM(ta.Proyecto)))
                                    AND ml.ModeloKey = UPPER(LTRIM(RTRIM(ta.Modelo))))
             THEN N'⚠ **' + ta.Modelo + N' no tiene límites cargados** para este proyecto: los equipos salen **sin evaluar**, no sanos.' + NCHAR(10) + NCHAR(10)
             ELSE N'' END
      + ta.Secciones + NCHAR(10) + NCHAR(10) + l.LimitesMD
    AS nvarchar(max)) AS MD,
    CAST(
        N'**Detalle de todos — flota observada, agrupado por componente**' + NCHAR(10) + NCHAR(10)
      + CASE WHEN ta.Modelo <> N'(todos)'
                  AND NOT EXISTS (SELECT 1 FROM [dbo].[vw_ModeloConLimites] ml
                                  WHERE ml.ProyKey   = UPPER(LTRIM(RTRIM(ta.Proyecto)))
                                    AND ml.ModeloKey = UPPER(LTRIM(RTRIM(ta.Modelo))))
             THEN N'⚠ **' + ta.Modelo + N' no tiene límites cargados** para este proyecto: los equipos salen **sin evaluar**, no sanos.' + NCHAR(10) + NCHAR(10)
             ELSE N'' END
      + ta.Secciones + NCHAR(10) + NCHAR(10) + l.LimitesMD
    AS nvarchar(max)) AS DetalleTodosMD,
    CAST(
        N'**Detalle — SOLO CRÍTICOS — flota observada, agrupado por componente**' + NCHAR(10) + NCHAR(10)
      + CASE WHEN ta.Modelo <> N'(todos)'
                  AND NOT EXISTS (SELECT 1 FROM [dbo].[vw_ModeloConLimites] ml
                                  WHERE ml.ProyKey   = UPPER(LTRIM(RTRIM(ta.Proyecto)))
                                    AND ml.ModeloKey = UPPER(LTRIM(RTRIM(ta.Modelo))))
             THEN N'⚠ **' + ta.Modelo + N' no tiene límites cargados** para este proyecto: los equipos salen **sin evaluar**, no sanos.' + NCHAR(10) + NCHAR(10)
             ELSE N'' END
      /* Sin criticos, 'ca.Secciones' es NULL y anula el MD entero -> 'no encontre datos' cuando la
         respuesta correcta es 'no hay ninguno critico', que es una BUENA noticia. (Modo A, G2.) */
      + ISNULL(ca.Secciones, N'_Ningún equipo de esta flota está en estado **crítico**. Los observados que hay son de precaución._')
      + NCHAR(10) + NCHAR(10) + l.LimitesMD
    AS nvarchar(max))  AS MD_Criticos,
    CAST(
        N'**Detalle — SOLO PRECAUCIÓN — flota observada, agrupado por componente**' + NCHAR(10) + NCHAR(10)
      + CASE WHEN ta.Modelo <> N'(todos)'
                  AND NOT EXISTS (SELECT 1 FROM [dbo].[vw_ModeloConLimites] ml
                                  WHERE ml.ProyKey   = UPPER(LTRIM(RTRIM(ta.Proyecto)))
                                    AND ml.ModeloKey = UPPER(LTRIM(RTRIM(ta.Modelo))))
             THEN N'⚠ **' + ta.Modelo + N' no tiene límites cargados** para este proyecto: los equipos salen **sin evaluar**, no sanos.' + NCHAR(10) + NCHAR(10)
             ELSE N'' END
      + ISNULL(pa.Secciones, N'_Ningún equipo de esta flota está en **precaución**._')
      + NCHAR(10) + NCHAR(10) + l.LimitesMD
    AS nvarchar(max))  AS MD_Precaucion
FROM (
    SELECT Proyecto, Modelo,
        STRING_AGG(seccionMD, NCHAR(10)+NCHAR(10)) WITHIN GROUP (ORDER BY sev, Compartimiento) AS Secciones
    FROM (
    SELECT Proyecto, Modelo, Compartimiento, MIN(sev) AS sev,
        CAST(
            N'**' + Compartimiento + N'** (' + CAST(COUNT(*) AS nvarchar(10)) + N' equipos)' + NCHAR(10) + NCHAR(10)
          + N'| Equipo | Grado | Fec. | Hor.Comp. | Hrs Ace. | T. muestra | Est. | Observado |' + NCHAR(10)
          + N'|---|---|---|---|---|---|---|---|' + NCHAR(10)
          + STRING_AGG(filaMD, NCHAR(10)) WITHIN GROUP (ORDER BY sev, Equipo)
        AS nvarchar(max)) AS seccionMD
    FROM (
    SELECT Proyecto, Modelo, Compartimiento, sev, Equipo, Estado_General,
        CAST(
            N'| ' + Equipo
          + N' | ' + ISNULL(Grado, N'—')
          + N' | ' + ISNULL(FORMAT(FechaMuestreo, 'dd-MMM'), N'—')
          + N' | ' + ISNULL(CONVERT(nvarchar(12), HorasComponente), N'—')
          + N' | ' + ISNULL(CONVERT(nvarchar(12), CAST(HorasDeAceite AS decimal(18,0))), N'—')
          + N' | ' + ISNULL(CM, N'—')
          + N' | ' + CASE Estado_General WHEN 'CRITICO' THEN N'🟥' WHEN 'PRECAUCION' THEN N'🟨' ELSE N'' END
          + N' | ' + ISNULL(REPLACE(REPLACE(chipsCell, ':C', N' 🟥'), ':P', N' 🟨'), N'—')
          + N' |'
        AS nvarchar(max)) AS filaMD
    FROM (
    SELECT
        Proyecto, Modelo, Compartimiento, Equipo, Estado_General, Grado, FechaMuestreo, HorasComponente, HorasDeAceite, CM,
        CASE WHEN Estado_General = 'CRITICO' THEN 1 ELSE 2 END AS sev,
        STUFF(CONCAT(
            CASE WHEN Fe_ppm>ISNULL(Fe_LC,9999) THEN ' · Fe='+CONVERT(varchar(20),CAST(Fe_ppm AS decimal(18,1)))+':C' WHEN Fe_ppm>ISNULL(Fe_LP,9999) THEN ' · Fe='+CONVERT(varchar(20),CAST(Fe_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Indice_PQ>ISNULL(PQ_LC,9999) THEN ' · PQ='+CONVERT(varchar(20),CAST(Indice_PQ AS decimal(18,1)))+':C' WHEN Indice_PQ>ISNULL(PQ_LP,9999) THEN ' · PQ='+CONVERT(varchar(20),CAST(Indice_PQ AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Cr_ppm>ISNULL(Cr_LC,9999) THEN ' · Cr='+CONVERT(varchar(20),CAST(Cr_ppm AS decimal(18,1)))+':C' WHEN Cr_ppm>ISNULL(Cr_LP,9999) THEN ' · Cr='+CONVERT(varchar(20),CAST(Cr_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Ni_ppm>ISNULL(Ni_LC,9999) THEN ' · Ni='+CONVERT(varchar(20),CAST(Ni_ppm AS decimal(18,1)))+':C' WHEN Ni_ppm>ISNULL(Ni_LP,9999) THEN ' · Ni='+CONVERT(varchar(20),CAST(Ni_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Cu_ppm>ISNULL(Cu_LC,9999) THEN ' · Cu='+CONVERT(varchar(20),CAST(Cu_ppm AS decimal(18,1)))+':C' WHEN Cu_ppm>ISNULL(Cu_LP,9999) THEN ' · Cu='+CONVERT(varchar(20),CAST(Cu_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Al_ppm>ISNULL(Al_LC,9999) THEN ' · Al='+CONVERT(varchar(20),CAST(Al_ppm AS decimal(18,1)))+':C' WHEN Al_ppm>ISNULL(Al_LP,9999) THEN ' · Al='+CONVERT(varchar(20),CAST(Al_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Si_ppm>ISNULL(Si_LC,9999) THEN ' · Si='+CONVERT(varchar(20),CAST(Si_ppm AS decimal(18,1)))+':C' WHEN Si_ppm>ISNULL(Si_LP,9999) THEN ' · Si='+CONVERT(varchar(20),CAST(Si_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Pb_ppm>ISNULL(Pb_LP,9999) THEN ' · Pb='+CONVERT(varchar(20),CAST(Pb_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Sn_ppm>ISNULL(Sn_LP,9999) THEN ' · Sn='+CONVERT(varchar(20),CAST(Sn_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN TBN_LP IS NOT NULL AND TBN>0 AND TBN<TBN_LP THEN ' · TBN='+CONVERT(varchar(20),CAST(TBN AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Ca_ppm>ISNULL(Ca_LC,9999) THEN ' · Ca='+CONVERT(varchar(20),CAST(Ca_ppm AS decimal(18,1)))+':C' WHEN Ca_ppm>ISNULL(Ca_LP,9999) THEN ' · Ca='+CONVERT(varchar(20),CAST(Ca_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Zn_ppm>ISNULL(Zn_LC,9999) THEN ' · Zn='+CONVERT(varchar(20),CAST(Zn_ppm AS decimal(18,1)))+':C' WHEN Zn_ppm>ISNULL(Zn_LP,9999) THEN ' · Zn='+CONVERT(varchar(20),CAST(Zn_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN K_ppm>ISNULL(K_LC,9999) THEN ' · K='+CONVERT(varchar(20),CAST(K_ppm AS decimal(18,1)))+':C' WHEN K_ppm>ISNULL(K_LP,9999) THEN ' · K='+CONVERT(varchar(20),CAST(K_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Na_ppm>ISNULL(Na_LC,9999) THEN ' · Na='+CONVERT(varchar(20),CAST(Na_ppm AS decimal(18,1)))+':C' WHEN Na_ppm>ISNULL(Na_LP,9999) THEN ' · Na='+CONVERT(varchar(20),CAST(Na_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Mg_ppm>ISNULL(Mg_LC,9999) THEN ' · Mg='+CONVERT(varchar(20),CAST(Mg_ppm AS decimal(18,1)))+':C' WHEN Mg_ppm>ISNULL(Mg_LP,9999) THEN ' · Mg='+CONVERT(varchar(20),CAST(Mg_ppm AS decimal(18,1)))+':P' ELSE '' END,
            /* SALUD del aceite: viscosidad V100 (informativo, no dispara Estado_General; solo aparece en equipos ya observados) */
            CASE WHEN Estado_V100='CRITICO' THEN ' · V100='+CONVERT(varchar(20),CAST(V100 AS decimal(18,1)))+':C salud' WHEN Estado_V100='PRECAUCION' THEN ' · V100='+CONVERT(varchar(20),CAST(V100 AS decimal(18,1)))+':P salud' ELSE '' END
        ),1,3,'') AS chipsCell
    FROM (   -- PERF: 1 sola lectura de vw_ObservadosFlota (f + obsf2/metrows derivan de aqui)
    SELECT mg.ModeloG AS Modelo, o.Proyecto, o.Compartimiento, o.Equipo, o.Estado_General, o.Grado, o.FechaMuestreo, o.HorasComponente, o.HorasDeAceite, o.CM, o.Estado_V100, o.V100,
        o.Fe_ppm,o.Fe_LP,o.Fe_LC, o.Indice_PQ,o.PQ_LP,o.PQ_LC, o.Cr_ppm,o.Cr_LP,o.Cr_LC, o.Ni_ppm,o.Ni_LP,o.Ni_LC,
        o.Cu_ppm,o.Cu_LP,o.Cu_LC, o.Al_ppm,o.Al_LP,o.Al_LC, o.Si_ppm,o.Si_LP,o.Si_LC, o.Pb_ppm,o.Pb_LP, o.Sn_ppm,o.Sn_LP,
        o.TBN,o.TBN_LP, o.Ca_ppm,o.Ca_LP,o.Ca_LC, o.Zn_ppm,o.Zn_LP,o.Zn_LC, o.K_ppm,o.K_LP,o.K_LC, o.Na_ppm,o.Na_LP,o.Na_LC, o.Mg_ppm,o.Mg_LP,o.Mg_LC
    FROM (SELECT * FROM [dbo].[vw_ObservadosFlota] WHERE Proyecto = mp.[Name]) o CROSS APPLY (SELECT o.Modelo AS ModeloG
             UNION ALL
             SELECT N'(todos)' WHERE EXISTS (
                 SELECT 1 FROM [dbo].[vw_ModeloConLimites] ml
                 WHERE ml.ProyKey   = UPPER(LTRIM(RTRIM(o.Proyecto)))
                   AND ml.ModeloKey = UPPER(LTRIM(RTRIM(o.Modelo))))) mg
    WHERE o.Estado_General <> 'OK'
) obsf
) f
) fila
    GROUP BY Proyecto, Modelo, Compartimiento
) t_sec GROUP BY Proyecto, Modelo
) ta
JOIN (
    SELECT Proyecto, mg.ModeloG AS Modelo,
        COUNT(*) AS NumEquipos,
        SUM(CASE WHEN NumCrit > 0 THEN 1 ELSE 0 END) AS NumEquiposCriticos,
        SUM(CASE WHEN NumCrit = 0 AND NumPrec > 0 THEN 1 ELSE 0 END) AS NumEquiposSoloPrecau
    FROM (SELECT * FROM [dbo].[vw_ObservadosResumen] WHERE Proyecto = mp.[Name]) vw_ObservadosResumen CROSS APPLY (SELECT Modelo AS ModeloG
             UNION ALL
             SELECT N'(todos)' WHERE EXISTS (
                 SELECT 1 FROM [dbo].[vw_ModeloConLimites] ml
                 WHERE ml.ProyKey   = UPPER(LTRIM(RTRIM(Proyecto)))
                   AND ml.ModeloKey = UPPER(LTRIM(RTRIM(Modelo))))) mg GROUP BY Proyecto, mg.ModeloG
) c ON c.Proyecto=ta.Proyecto AND ISNULL(c.Modelo,N'')=ISNULL(ta.Modelo,N'')
JOIN (
    SELECT r.Proyecto, r.Modelo,
        CAST(
            N'**Límites de referencia (ppm)**' + NCHAR(10) + NCHAR(10)
          + N'| Componente | Metal | LP | LC |' + NCHAR(10)
          + N'|---|---|---|---|' + NCHAR(10)
          + STRING_AGG(CONVERT(nvarchar(max),
                N'| ' + r.Compartimiento + N' | ' + r.metal + N' | '
              + CONVERT(varchar(20), r.lp) + N' | ' + ISNULL(CONVERT(varchar(20), r.lc), N'—') + N' |'
            ), NCHAR(10)) WITHIN GROUP (ORDER BY r.sev, r.Compartimiento, r.ord)
        AS nvarchar(max)) AS LimitesMD
    FROM (
    SELECT DISTINCT o.Proyecto, o.Modelo, o.Compartimiento, o.sev, m.ord, m.metal, m.lp, m.lc
    FROM (   /* PERF 2026-09-19: 'sev' por FUNCION DE VENTANA. Reemplaza al CTE compsev y a su JOIN contra
   metrows, que era EL multiplicador: obsf se referenciaba 2 veces y el JOIN caia en nested loops -> la fundacion
   se re-ejecutaba 257 veces (LaboratoryData 25.2M lecturas, 6:21). Medido aislado: 33 s -> 1.5 s, y LaboratoryData
   vuelve a 1 solo scan. ⚠ El sev se calcula ANTES del filtro por metal: el WHERE precede a las funciones de
   ventana, y si se calculara despues, una fila observada solo por V100 (sin ningun m.lp) cambiaria el sev.
   Validacion: VALIDACION_SSMS BLOQUE 76 (equivalencia probada) y BLOQUE 77. */
    SELECT o.*,
        MIN(CASE WHEN o.Estado_General='CRITICO' THEN 1 ELSE 2 END)
            OVER (PARTITION BY o.Proyecto, o.Modelo, o.Compartimiento) AS sev
    FROM (   -- PERF: 1 sola lectura de vw_ObservadosFlota (f + obsf2/metrows derivan de aqui)
    SELECT mg.ModeloG AS Modelo, o.Proyecto, o.Compartimiento, o.Equipo, o.Estado_General, o.Grado, o.FechaMuestreo, o.HorasComponente, o.HorasDeAceite, o.CM, o.Estado_V100, o.V100,
        o.Fe_ppm,o.Fe_LP,o.Fe_LC, o.Indice_PQ,o.PQ_LP,o.PQ_LC, o.Cr_ppm,o.Cr_LP,o.Cr_LC, o.Ni_ppm,o.Ni_LP,o.Ni_LC,
        o.Cu_ppm,o.Cu_LP,o.Cu_LC, o.Al_ppm,o.Al_LP,o.Al_LC, o.Si_ppm,o.Si_LP,o.Si_LC, o.Pb_ppm,o.Pb_LP, o.Sn_ppm,o.Sn_LP,
        o.TBN,o.TBN_LP, o.Ca_ppm,o.Ca_LP,o.Ca_LC, o.Zn_ppm,o.Zn_LP,o.Zn_LC, o.K_ppm,o.K_LP,o.K_LC, o.Na_ppm,o.Na_LP,o.Na_LC, o.Mg_ppm,o.Mg_LP,o.Mg_LC
    FROM (SELECT * FROM [dbo].[vw_ObservadosFlota] WHERE Proyecto = mp.[Name]) o CROSS APPLY (SELECT o.Modelo AS ModeloG
             UNION ALL
             SELECT N'(todos)' WHERE EXISTS (
                 SELECT 1 FROM [dbo].[vw_ModeloConLimites] ml
                 WHERE ml.ProyKey   = UPPER(LTRIM(RTRIM(o.Proyecto)))
                   AND ml.ModeloKey = UPPER(LTRIM(RTRIM(o.Modelo))))) mg
    WHERE o.Estado_General <> 'OK'
) o
) o
    CROSS APPLY (VALUES
        (1, 'Fe', CASE WHEN Fe_ppm>ISNULL(Fe_LP,9999) THEN CAST(Fe_LP AS decimal(18,1)) END, CASE WHEN Fe_ppm>ISNULL(Fe_LP,9999) THEN CAST(Fe_LC AS decimal(18,1)) END),
        (2, 'PQ', CASE WHEN Indice_PQ>ISNULL(PQ_LP,9999) THEN CAST(PQ_LP AS decimal(18,1)) END, CASE WHEN Indice_PQ>ISNULL(PQ_LP,9999) THEN CAST(PQ_LC AS decimal(18,1)) END),
        (3, 'Cr', CASE WHEN Cr_ppm>ISNULL(Cr_LP,9999) THEN CAST(Cr_LP AS decimal(18,1)) END, CASE WHEN Cr_ppm>ISNULL(Cr_LP,9999) THEN CAST(Cr_LC AS decimal(18,1)) END),
        (4, 'Ni', CASE WHEN Ni_ppm>ISNULL(Ni_LP,9999) THEN CAST(Ni_LP AS decimal(18,1)) END, CASE WHEN Ni_ppm>ISNULL(Ni_LP,9999) THEN CAST(Ni_LC AS decimal(18,1)) END),
        (5, 'Cu', CASE WHEN Cu_ppm>ISNULL(Cu_LP,9999) THEN CAST(Cu_LP AS decimal(18,1)) END, CASE WHEN Cu_ppm>ISNULL(Cu_LP,9999) THEN CAST(Cu_LC AS decimal(18,1)) END),
        (6, 'Al', CASE WHEN Al_ppm>ISNULL(Al_LP,9999) THEN CAST(Al_LP AS decimal(18,1)) END, CASE WHEN Al_ppm>ISNULL(Al_LP,9999) THEN CAST(Al_LC AS decimal(18,1)) END),
        (7, 'Si', CASE WHEN Si_ppm>ISNULL(Si_LP,9999) THEN CAST(Si_LP AS decimal(18,1)) END, CASE WHEN Si_ppm>ISNULL(Si_LP,9999) THEN CAST(Si_LC AS decimal(18,1)) END),
        (8, 'Pb', CASE WHEN Pb_ppm>ISNULL(Pb_LP,9999) THEN CAST(Pb_LP AS decimal(18,1)) END, CAST(NULL AS decimal(18,1))),
        (9, 'Sn', CASE WHEN Sn_ppm>ISNULL(Sn_LP,9999) THEN CAST(Sn_LP AS decimal(18,1)) END, CAST(NULL AS decimal(18,1))),
        (10, 'TBN', CASE WHEN TBN_LP IS NOT NULL AND TBN>0 AND TBN<TBN_LP THEN CAST(TBN_LP AS decimal(18,1)) END, CAST(NULL AS decimal(18,1))),
        (11, 'Ca', CASE WHEN Ca_ppm>ISNULL(Ca_LP,9999) THEN CAST(Ca_LP AS decimal(18,1)) END, CASE WHEN Ca_ppm>ISNULL(Ca_LP,9999) THEN CAST(Ca_LC AS decimal(18,1)) END),
        (12, 'Zn', CASE WHEN Zn_ppm>ISNULL(Zn_LP,9999) THEN CAST(Zn_LP AS decimal(18,1)) END, CASE WHEN Zn_ppm>ISNULL(Zn_LP,9999) THEN CAST(Zn_LC AS decimal(18,1)) END),
        (13, 'K', CASE WHEN K_ppm>ISNULL(K_LP,9999) THEN CAST(K_LP AS decimal(18,1)) END, CASE WHEN K_ppm>ISNULL(K_LP,9999) THEN CAST(K_LC AS decimal(18,1)) END),
        (14, 'Na', CASE WHEN Na_ppm>ISNULL(Na_LP,9999) THEN CAST(Na_LP AS decimal(18,1)) END, CASE WHEN Na_ppm>ISNULL(Na_LP,9999) THEN CAST(Na_LC AS decimal(18,1)) END),
        (15, 'Mg', CASE WHEN Mg_ppm>ISNULL(Mg_LP,9999) THEN CAST(Mg_LP AS decimal(18,1)) END, CASE WHEN Mg_ppm>ISNULL(Mg_LP,9999) THEN CAST(Mg_LC AS decimal(18,1)) END)
    ) m(ord, metal, lp, lc)
    WHERE o.Estado_General <> 'OK' AND m.lp IS NOT NULL
) r          -- PERF: sin JOIN a compsev; 'sev' ya viene de la ventana en obsf2
    GROUP BY r.Proyecto, r.Modelo
) l ON l.Proyecto=ta.Proyecto AND ISNULL(l.Modelo,N'')=ISNULL(ta.Modelo,N'')
LEFT JOIN (
    SELECT Proyecto, Modelo,
        STRING_AGG(seccionMD, NCHAR(10)+NCHAR(10)) WITHIN GROUP (ORDER BY sev, Compartimiento) AS Secciones
    FROM (
    SELECT Proyecto, Modelo, Compartimiento, MIN(sev) AS sev,
        CAST(
            N'**' + Compartimiento + N'** (' + CAST(COUNT(*) AS nvarchar(10)) + N' equipos)' + NCHAR(10) + NCHAR(10)
          + N'| Equipo | Grado | Fec. | Hor.Comp. | Hrs Ace. | T. muestra | Est. | Observado |' + NCHAR(10)
          + N'|---|---|---|---|---|---|---|---|' + NCHAR(10)
          + STRING_AGG(filaMD, NCHAR(10)) WITHIN GROUP (ORDER BY sev, Equipo)
        AS nvarchar(max)) AS seccionMD
    FROM (
    SELECT Proyecto, Modelo, Compartimiento, sev, Equipo, Estado_General,
        CAST(
            N'| ' + Equipo
          + N' | ' + ISNULL(Grado, N'—')
          + N' | ' + ISNULL(FORMAT(FechaMuestreo, 'dd-MMM'), N'—')
          + N' | ' + ISNULL(CONVERT(nvarchar(12), HorasComponente), N'—')
          + N' | ' + ISNULL(CONVERT(nvarchar(12), CAST(HorasDeAceite AS decimal(18,0))), N'—')
          + N' | ' + ISNULL(CM, N'—')
          + N' | ' + CASE Estado_General WHEN 'CRITICO' THEN N'🟥' WHEN 'PRECAUCION' THEN N'🟨' ELSE N'' END
          + N' | ' + ISNULL(REPLACE(REPLACE(chipsCell, ':C', N' 🟥'), ':P', N' 🟨'), N'—')
          + N' |'
        AS nvarchar(max)) AS filaMD
    FROM (
    SELECT
        Proyecto, Modelo, Compartimiento, Equipo, Estado_General, Grado, FechaMuestreo, HorasComponente, HorasDeAceite, CM,
        CASE WHEN Estado_General = 'CRITICO' THEN 1 ELSE 2 END AS sev,
        STUFF(CONCAT(
            CASE WHEN Fe_ppm>ISNULL(Fe_LC,9999) THEN ' · Fe='+CONVERT(varchar(20),CAST(Fe_ppm AS decimal(18,1)))+':C' WHEN Fe_ppm>ISNULL(Fe_LP,9999) THEN ' · Fe='+CONVERT(varchar(20),CAST(Fe_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Indice_PQ>ISNULL(PQ_LC,9999) THEN ' · PQ='+CONVERT(varchar(20),CAST(Indice_PQ AS decimal(18,1)))+':C' WHEN Indice_PQ>ISNULL(PQ_LP,9999) THEN ' · PQ='+CONVERT(varchar(20),CAST(Indice_PQ AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Cr_ppm>ISNULL(Cr_LC,9999) THEN ' · Cr='+CONVERT(varchar(20),CAST(Cr_ppm AS decimal(18,1)))+':C' WHEN Cr_ppm>ISNULL(Cr_LP,9999) THEN ' · Cr='+CONVERT(varchar(20),CAST(Cr_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Ni_ppm>ISNULL(Ni_LC,9999) THEN ' · Ni='+CONVERT(varchar(20),CAST(Ni_ppm AS decimal(18,1)))+':C' WHEN Ni_ppm>ISNULL(Ni_LP,9999) THEN ' · Ni='+CONVERT(varchar(20),CAST(Ni_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Cu_ppm>ISNULL(Cu_LC,9999) THEN ' · Cu='+CONVERT(varchar(20),CAST(Cu_ppm AS decimal(18,1)))+':C' WHEN Cu_ppm>ISNULL(Cu_LP,9999) THEN ' · Cu='+CONVERT(varchar(20),CAST(Cu_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Al_ppm>ISNULL(Al_LC,9999) THEN ' · Al='+CONVERT(varchar(20),CAST(Al_ppm AS decimal(18,1)))+':C' WHEN Al_ppm>ISNULL(Al_LP,9999) THEN ' · Al='+CONVERT(varchar(20),CAST(Al_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Si_ppm>ISNULL(Si_LC,9999) THEN ' · Si='+CONVERT(varchar(20),CAST(Si_ppm AS decimal(18,1)))+':C' WHEN Si_ppm>ISNULL(Si_LP,9999) THEN ' · Si='+CONVERT(varchar(20),CAST(Si_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Pb_ppm>ISNULL(Pb_LP,9999) THEN ' · Pb='+CONVERT(varchar(20),CAST(Pb_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Sn_ppm>ISNULL(Sn_LP,9999) THEN ' · Sn='+CONVERT(varchar(20),CAST(Sn_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN TBN_LP IS NOT NULL AND TBN>0 AND TBN<TBN_LP THEN ' · TBN='+CONVERT(varchar(20),CAST(TBN AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Ca_ppm>ISNULL(Ca_LC,9999) THEN ' · Ca='+CONVERT(varchar(20),CAST(Ca_ppm AS decimal(18,1)))+':C' WHEN Ca_ppm>ISNULL(Ca_LP,9999) THEN ' · Ca='+CONVERT(varchar(20),CAST(Ca_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Zn_ppm>ISNULL(Zn_LC,9999) THEN ' · Zn='+CONVERT(varchar(20),CAST(Zn_ppm AS decimal(18,1)))+':C' WHEN Zn_ppm>ISNULL(Zn_LP,9999) THEN ' · Zn='+CONVERT(varchar(20),CAST(Zn_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN K_ppm>ISNULL(K_LC,9999) THEN ' · K='+CONVERT(varchar(20),CAST(K_ppm AS decimal(18,1)))+':C' WHEN K_ppm>ISNULL(K_LP,9999) THEN ' · K='+CONVERT(varchar(20),CAST(K_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Na_ppm>ISNULL(Na_LC,9999) THEN ' · Na='+CONVERT(varchar(20),CAST(Na_ppm AS decimal(18,1)))+':C' WHEN Na_ppm>ISNULL(Na_LP,9999) THEN ' · Na='+CONVERT(varchar(20),CAST(Na_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Mg_ppm>ISNULL(Mg_LC,9999) THEN ' · Mg='+CONVERT(varchar(20),CAST(Mg_ppm AS decimal(18,1)))+':C' WHEN Mg_ppm>ISNULL(Mg_LP,9999) THEN ' · Mg='+CONVERT(varchar(20),CAST(Mg_ppm AS decimal(18,1)))+':P' ELSE '' END,
            /* SALUD del aceite: viscosidad V100 (informativo, no dispara Estado_General; solo aparece en equipos ya observados) */
            CASE WHEN Estado_V100='CRITICO' THEN ' · V100='+CONVERT(varchar(20),CAST(V100 AS decimal(18,1)))+':C salud' WHEN Estado_V100='PRECAUCION' THEN ' · V100='+CONVERT(varchar(20),CAST(V100 AS decimal(18,1)))+':P salud' ELSE '' END
        ),1,3,'') AS chipsCell
    FROM (   -- PERF: 1 sola lectura de vw_ObservadosFlota (f + obsf2/metrows derivan de aqui)
    SELECT mg.ModeloG AS Modelo, o.Proyecto, o.Compartimiento, o.Equipo, o.Estado_General, o.Grado, o.FechaMuestreo, o.HorasComponente, o.HorasDeAceite, o.CM, o.Estado_V100, o.V100,
        o.Fe_ppm,o.Fe_LP,o.Fe_LC, o.Indice_PQ,o.PQ_LP,o.PQ_LC, o.Cr_ppm,o.Cr_LP,o.Cr_LC, o.Ni_ppm,o.Ni_LP,o.Ni_LC,
        o.Cu_ppm,o.Cu_LP,o.Cu_LC, o.Al_ppm,o.Al_LP,o.Al_LC, o.Si_ppm,o.Si_LP,o.Si_LC, o.Pb_ppm,o.Pb_LP, o.Sn_ppm,o.Sn_LP,
        o.TBN,o.TBN_LP, o.Ca_ppm,o.Ca_LP,o.Ca_LC, o.Zn_ppm,o.Zn_LP,o.Zn_LC, o.K_ppm,o.K_LP,o.K_LC, o.Na_ppm,o.Na_LP,o.Na_LC, o.Mg_ppm,o.Mg_LP,o.Mg_LC
    FROM (SELECT * FROM [dbo].[vw_ObservadosFlota] WHERE Proyecto = mp.[Name]) o CROSS APPLY (SELECT o.Modelo AS ModeloG
             UNION ALL
             SELECT N'(todos)' WHERE EXISTS (
                 SELECT 1 FROM [dbo].[vw_ModeloConLimites] ml
                 WHERE ml.ProyKey   = UPPER(LTRIM(RTRIM(o.Proyecto)))
                   AND ml.ModeloKey = UPPER(LTRIM(RTRIM(o.Modelo))))) mg
    WHERE o.Estado_General <> 'OK'
) obsf
) f
) fila WHERE Estado_General='CRITICO'
    GROUP BY Proyecto, Modelo, Compartimiento
) c_sec GROUP BY Proyecto, Modelo
) ca ON ca.Proyecto=ta.Proyecto AND ISNULL(ca.Modelo,N'')=ISNULL(ta.Modelo,N'')
LEFT JOIN (
    SELECT Proyecto, Modelo,
        STRING_AGG(seccionMD, NCHAR(10)+NCHAR(10)) WITHIN GROUP (ORDER BY sev, Compartimiento) AS Secciones
    FROM (
    SELECT Proyecto, Modelo, Compartimiento, MIN(sev) AS sev,
        CAST(
            N'**' + Compartimiento + N'** (' + CAST(COUNT(*) AS nvarchar(10)) + N' equipos)' + NCHAR(10) + NCHAR(10)
          + N'| Equipo | Grado | Fec. | Hor.Comp. | Hrs Ace. | T. muestra | Est. | Observado |' + NCHAR(10)
          + N'|---|---|---|---|---|---|---|---|' + NCHAR(10)
          + STRING_AGG(filaMD, NCHAR(10)) WITHIN GROUP (ORDER BY sev, Equipo)
        AS nvarchar(max)) AS seccionMD
    FROM (
    SELECT Proyecto, Modelo, Compartimiento, sev, Equipo, Estado_General,
        CAST(
            N'| ' + Equipo
          + N' | ' + ISNULL(Grado, N'—')
          + N' | ' + ISNULL(FORMAT(FechaMuestreo, 'dd-MMM'), N'—')
          + N' | ' + ISNULL(CONVERT(nvarchar(12), HorasComponente), N'—')
          + N' | ' + ISNULL(CONVERT(nvarchar(12), CAST(HorasDeAceite AS decimal(18,0))), N'—')
          + N' | ' + ISNULL(CM, N'—')
          + N' | ' + CASE Estado_General WHEN 'CRITICO' THEN N'🟥' WHEN 'PRECAUCION' THEN N'🟨' ELSE N'' END
          + N' | ' + ISNULL(REPLACE(REPLACE(chipsCell, ':C', N' 🟥'), ':P', N' 🟨'), N'—')
          + N' |'
        AS nvarchar(max)) AS filaMD
    FROM (
    SELECT
        Proyecto, Modelo, Compartimiento, Equipo, Estado_General, Grado, FechaMuestreo, HorasComponente, HorasDeAceite, CM,
        CASE WHEN Estado_General = 'CRITICO' THEN 1 ELSE 2 END AS sev,
        STUFF(CONCAT(
            CASE WHEN Fe_ppm>ISNULL(Fe_LC,9999) THEN ' · Fe='+CONVERT(varchar(20),CAST(Fe_ppm AS decimal(18,1)))+':C' WHEN Fe_ppm>ISNULL(Fe_LP,9999) THEN ' · Fe='+CONVERT(varchar(20),CAST(Fe_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Indice_PQ>ISNULL(PQ_LC,9999) THEN ' · PQ='+CONVERT(varchar(20),CAST(Indice_PQ AS decimal(18,1)))+':C' WHEN Indice_PQ>ISNULL(PQ_LP,9999) THEN ' · PQ='+CONVERT(varchar(20),CAST(Indice_PQ AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Cr_ppm>ISNULL(Cr_LC,9999) THEN ' · Cr='+CONVERT(varchar(20),CAST(Cr_ppm AS decimal(18,1)))+':C' WHEN Cr_ppm>ISNULL(Cr_LP,9999) THEN ' · Cr='+CONVERT(varchar(20),CAST(Cr_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Ni_ppm>ISNULL(Ni_LC,9999) THEN ' · Ni='+CONVERT(varchar(20),CAST(Ni_ppm AS decimal(18,1)))+':C' WHEN Ni_ppm>ISNULL(Ni_LP,9999) THEN ' · Ni='+CONVERT(varchar(20),CAST(Ni_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Cu_ppm>ISNULL(Cu_LC,9999) THEN ' · Cu='+CONVERT(varchar(20),CAST(Cu_ppm AS decimal(18,1)))+':C' WHEN Cu_ppm>ISNULL(Cu_LP,9999) THEN ' · Cu='+CONVERT(varchar(20),CAST(Cu_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Al_ppm>ISNULL(Al_LC,9999) THEN ' · Al='+CONVERT(varchar(20),CAST(Al_ppm AS decimal(18,1)))+':C' WHEN Al_ppm>ISNULL(Al_LP,9999) THEN ' · Al='+CONVERT(varchar(20),CAST(Al_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Si_ppm>ISNULL(Si_LC,9999) THEN ' · Si='+CONVERT(varchar(20),CAST(Si_ppm AS decimal(18,1)))+':C' WHEN Si_ppm>ISNULL(Si_LP,9999) THEN ' · Si='+CONVERT(varchar(20),CAST(Si_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Pb_ppm>ISNULL(Pb_LP,9999) THEN ' · Pb='+CONVERT(varchar(20),CAST(Pb_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Sn_ppm>ISNULL(Sn_LP,9999) THEN ' · Sn='+CONVERT(varchar(20),CAST(Sn_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN TBN_LP IS NOT NULL AND TBN>0 AND TBN<TBN_LP THEN ' · TBN='+CONVERT(varchar(20),CAST(TBN AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Ca_ppm>ISNULL(Ca_LC,9999) THEN ' · Ca='+CONVERT(varchar(20),CAST(Ca_ppm AS decimal(18,1)))+':C' WHEN Ca_ppm>ISNULL(Ca_LP,9999) THEN ' · Ca='+CONVERT(varchar(20),CAST(Ca_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Zn_ppm>ISNULL(Zn_LC,9999) THEN ' · Zn='+CONVERT(varchar(20),CAST(Zn_ppm AS decimal(18,1)))+':C' WHEN Zn_ppm>ISNULL(Zn_LP,9999) THEN ' · Zn='+CONVERT(varchar(20),CAST(Zn_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN K_ppm>ISNULL(K_LC,9999) THEN ' · K='+CONVERT(varchar(20),CAST(K_ppm AS decimal(18,1)))+':C' WHEN K_ppm>ISNULL(K_LP,9999) THEN ' · K='+CONVERT(varchar(20),CAST(K_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Na_ppm>ISNULL(Na_LC,9999) THEN ' · Na='+CONVERT(varchar(20),CAST(Na_ppm AS decimal(18,1)))+':C' WHEN Na_ppm>ISNULL(Na_LP,9999) THEN ' · Na='+CONVERT(varchar(20),CAST(Na_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Mg_ppm>ISNULL(Mg_LC,9999) THEN ' · Mg='+CONVERT(varchar(20),CAST(Mg_ppm AS decimal(18,1)))+':C' WHEN Mg_ppm>ISNULL(Mg_LP,9999) THEN ' · Mg='+CONVERT(varchar(20),CAST(Mg_ppm AS decimal(18,1)))+':P' ELSE '' END,
            /* SALUD del aceite: viscosidad V100 (informativo, no dispara Estado_General; solo aparece en equipos ya observados) */
            CASE WHEN Estado_V100='CRITICO' THEN ' · V100='+CONVERT(varchar(20),CAST(V100 AS decimal(18,1)))+':C salud' WHEN Estado_V100='PRECAUCION' THEN ' · V100='+CONVERT(varchar(20),CAST(V100 AS decimal(18,1)))+':P salud' ELSE '' END
        ),1,3,'') AS chipsCell
    FROM (   -- PERF: 1 sola lectura de vw_ObservadosFlota (f + obsf2/metrows derivan de aqui)
    SELECT mg.ModeloG AS Modelo, o.Proyecto, o.Compartimiento, o.Equipo, o.Estado_General, o.Grado, o.FechaMuestreo, o.HorasComponente, o.HorasDeAceite, o.CM, o.Estado_V100, o.V100,
        o.Fe_ppm,o.Fe_LP,o.Fe_LC, o.Indice_PQ,o.PQ_LP,o.PQ_LC, o.Cr_ppm,o.Cr_LP,o.Cr_LC, o.Ni_ppm,o.Ni_LP,o.Ni_LC,
        o.Cu_ppm,o.Cu_LP,o.Cu_LC, o.Al_ppm,o.Al_LP,o.Al_LC, o.Si_ppm,o.Si_LP,o.Si_LC, o.Pb_ppm,o.Pb_LP, o.Sn_ppm,o.Sn_LP,
        o.TBN,o.TBN_LP, o.Ca_ppm,o.Ca_LP,o.Ca_LC, o.Zn_ppm,o.Zn_LP,o.Zn_LC, o.K_ppm,o.K_LP,o.K_LC, o.Na_ppm,o.Na_LP,o.Na_LC, o.Mg_ppm,o.Mg_LP,o.Mg_LC
    FROM (SELECT * FROM [dbo].[vw_ObservadosFlota] WHERE Proyecto = mp.[Name]) o CROSS APPLY (SELECT o.Modelo AS ModeloG
             UNION ALL
             SELECT N'(todos)' WHERE EXISTS (
                 SELECT 1 FROM [dbo].[vw_ModeloConLimites] ml
                 WHERE ml.ProyKey   = UPPER(LTRIM(RTRIM(o.Proyecto)))
                   AND ml.ModeloKey = UPPER(LTRIM(RTRIM(o.Modelo))))) mg
    WHERE o.Estado_General <> 'OK'
) obsf
) f
) fila WHERE Estado_General='PRECAUCION'
    GROUP BY Proyecto, Modelo, Compartimiento
) p_sec GROUP BY Proyecto, Modelo
) pa ON pa.Proyecto=ta.Proyecto AND ISNULL(pa.Modelo,N'')=ISNULL(ta.Modelo,N'')
) x;
GO


/* ============================================================================
   vw_ObservadosResumenMD — TIER 2, PASO 1 del barrido (columna MD estándar).
   Pre-arma el bloque markdown del RESUMEN de barrido (1 fila/equipo: Crít/Prec,
   horómetros, Comp. Observados abreviados, Met. Obs. con chips) + el cuadro de
   límites. El tópico lo imprime verbatim. Calcada de vw_ObservadosResumen +
   formato. ⚠ Emojis: abrir/ejecutar el .sql desde archivo (UTF-8).
   Validación: VALIDACION_SSMS.sql BLOQUE 34.
   ---------------------------------------------------------------------------- */
CREATE OR ALTER VIEW [dbo].[vw_ObservadosResumenMD] AS
/* 30/09 -- FILTRO ABAJO (mismo patron que curo /condicionmt: 146 s -> 1,4 s, y /diagcompleto).
   La logica va en CROSS APPLY sobre [Mine].[MiningProject] y CADA lectura pesada lleva el filtro
   (Proyecto = mp.[Name]), asi que ninguna rama calcula mas que ese proyecto. Los CTE van desplegados:
   un APPLY no admite WITH y SQL Server ya los trata como macros. Misma logica y salida. Respaldo: respaldo/DDL_vistas_2026-09-30_antes_filtro_abajo.sql */
SELECT mp.[Name] AS Proyecto, x.[Modelo], x.[NumEquipos], x.[NumCriticos], x.[NumSoloPrecau], x.[Observados], x.[Recomendaciones], x.[MD]
FROM [Mine].[MiningProject] mp
CROSS APPLY (
SELECT
    t.Proyecto, t.Modelo,
    c.NumEquipos, c.NumCriticos, c.NumSoloPrecau,
    CAST(NULL AS nvarchar(max)) AS Observados, CAST(NULL AS nvarchar(max)) AS Recomendaciones,
    CAST(
        N'**Barrido Flota — ' + t.Proyecto + N' | Estado Actual (No-OK)**' + NCHAR(10)
      + N'**' + CAST(c.NumEquipos AS nvarchar(10)) + N' equipos con ≥1 componente observado — '
        + CAST(c.NumCriticos AS nvarchar(10)) + N' con CRÍTICO · '
        + CAST(c.NumSoloPrecau AS nvarchar(10)) + N' solo PRECAUCIÓN**' + NCHAR(10) + NCHAR(10)
      /* L5 (29/09): avisar si el modelo pedido no tiene limites cargados. No restringe nada
         -- el modelo sigue saliendo entero -- pero evita que "0 observados" se lea como
         "todos sanos" cuando lo que pasa es que no hay con que evaluarlos. */
      + CASE WHEN t.Modelo <> N'(todos)'
                  AND NOT EXISTS (SELECT 1 FROM [dbo].[vw_ModeloConLimites] ml
                                  WHERE ml.ProyKey   = UPPER(LTRIM(RTRIM(t.Proyecto)))
                                    AND ml.ModeloKey = UPPER(LTRIM(RTRIM(t.Modelo))))
             THEN N'⚠ **' + t.Modelo + N' no tiene límites cargados** para este proyecto: los equipos salen **sin evaluar**, no sanos.' + NCHAR(10) + NCHAR(10)
             ELSE N'' END
      + N'| Equipo | 🔴 Crít | 🟡 Prec | SMR | Últ. | T. muestra | Comp. Observados | Met. Obs. |' + NCHAR(10)
      + N'|---|---|---|---|---|---|---|---|' + NCHAR(10)
      + t.FilasMD
      + NCHAR(10) + NCHAR(10) + l.LimitesMD
      + NCHAR(10) + NCHAR(10)
      + N'_Resumen por equipo. Para el **detalle por componente** (con horas de aceite por componente, salud y todos los observados) pide **el detalle** o usa **/barridodet**._' + NCHAR(10)
      + N'_¿Profundizar? **Tendencia** de un componente · **Diagnóstico** de un equipo · **solo críticos** / **solo precauciones**._'
    AS nvarchar(max)) AS MD
FROM (
    SELECT Proyecto, Modelo,
        STRING_AGG(filaMD, NCHAR(10)) WITHIN GROUP (ORDER BY NumCrit DESC, NumPrec DESC, Equipo) AS FilasMD
    FROM (
    SELECT Proyecto, mg.ModeloG AS Modelo, Equipo, NumCrit, NumPrec, Horometro, HorasDeAceite, FechaUltima, CM, Comp_Obs, Met_Obs,
        CAST(
            N'| ' + Equipo
          + N' | ' + CAST(NumCrit AS nvarchar(10))
          + N' | ' + CAST(NumPrec AS nvarchar(10))
          + N' | ' + ISNULL(CONVERT(nvarchar(20), CAST(Horometro AS decimal(18,0))), N'—')
          + N' | ' + ISNULL(FORMAT(FechaUltima, 'dd-MMM'), N'—')
          + N' | ' + ISNULL(CM, N'—')
          + N' | ' + ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(Comp_Obs,'MOTOR DE TRACCION LH','MT LH'),'MOTOR DE TRACCION RH','MT RH'),'RUEDA DELANTERA LH','RD LH'),'RUEDA DELANTERA RH','RD RH'),'SISTEMA HIDRAULICO','Hidr'),'MOTOR','Motor'), N'—')
          + N' | ' + REPLACE(REPLACE(REPLACE(ISNULL(Met_Obs,N'—'),':C',N' 🟥'),':P',N' 🟨'),',',N' · ')
          + N' |'
        AS nvarchar(max)) AS filaMD
    FROM (SELECT * FROM [dbo].[vw_ObservadosResumen] WHERE Proyecto = mp.[Name]) vw_ObservadosResumen
    CROSS APPLY (SELECT Modelo AS ModeloG
             UNION ALL
             SELECT N'(todos)' WHERE EXISTS (
                 SELECT 1 FROM [dbo].[vw_ModeloConLimites] ml
                 WHERE ml.ProyKey   = UPPER(LTRIM(RTRIM(Proyecto)))
                   AND ml.ModeloKey = UPPER(LTRIM(RTRIM(Modelo))))) mg
) r GROUP BY Proyecto, Modelo
) t
JOIN (   -- PERF: agrega sobre r (no re-lee vw_ObservadosResumen)
    SELECT Proyecto, Modelo,
        COUNT(*) AS NumEquipos,
        SUM(CASE WHEN NumCrit > 0 THEN 1 ELSE 0 END) AS NumCriticos,
        SUM(CASE WHEN NumCrit = 0 AND NumPrec > 0 THEN 1 ELSE 0 END) AS NumSoloPrecau
    FROM (
    SELECT Proyecto, mg.ModeloG AS Modelo, Equipo, NumCrit, NumPrec, Horometro, HorasDeAceite, FechaUltima, CM, Comp_Obs, Met_Obs,
        CAST(
            N'| ' + Equipo
          + N' | ' + CAST(NumCrit AS nvarchar(10))
          + N' | ' + CAST(NumPrec AS nvarchar(10))
          + N' | ' + ISNULL(CONVERT(nvarchar(20), CAST(Horometro AS decimal(18,0))), N'—')
          + N' | ' + ISNULL(FORMAT(FechaUltima, 'dd-MMM'), N'—')
          + N' | ' + ISNULL(CM, N'—')
          + N' | ' + ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(Comp_Obs,'MOTOR DE TRACCION LH','MT LH'),'MOTOR DE TRACCION RH','MT RH'),'RUEDA DELANTERA LH','RD LH'),'RUEDA DELANTERA RH','RD RH'),'SISTEMA HIDRAULICO','Hidr'),'MOTOR','Motor'), N'—')
          + N' | ' + REPLACE(REPLACE(REPLACE(ISNULL(Met_Obs,N'—'),':C',N' 🟥'),':P',N' 🟨'),',',N' · ')
          + N' |'
        AS nvarchar(max)) AS filaMD
    FROM (SELECT * FROM [dbo].[vw_ObservadosResumen] WHERE Proyecto = mp.[Name]) vw_ObservadosResumen
    CROSS APPLY (SELECT Modelo AS ModeloG
             UNION ALL
             SELECT N'(todos)' WHERE EXISTS (
                 SELECT 1 FROM [dbo].[vw_ModeloConLimites] ml
                 WHERE ml.ProyKey   = UPPER(LTRIM(RTRIM(Proyecto)))
                   AND ml.ModeloKey = UPPER(LTRIM(RTRIM(Modelo))))) mg
) r GROUP BY Proyecto, Modelo
) c ON c.Proyecto=t.Proyecto AND ISNULL(c.Modelo,N'')=ISNULL(t.Modelo,N'')
JOIN (
    SELECT r2.Proyecto, r2.Modelo,
        CAST(
            N'**Límites de referencia (ppm)**' + NCHAR(10) + NCHAR(10)
          + N'| Componente | Metal | LP | LC |' + NCHAR(10)
          + N'|---|---|---|---|' + NCHAR(10)
          + STRING_AGG(CONVERT(nvarchar(max),
                N'| ' + r2.Compartimiento + N' | ' + r2.metal + N' | '
              + CONVERT(varchar(20), r2.lp) + N' | ' + ISNULL(CONVERT(varchar(20), r2.lc), N'—') + N' |'
            ), NCHAR(10)) WITHIN GROUP (ORDER BY r2.sev, r2.Compartimiento, r2.ord)
        AS nvarchar(max)) AS LimitesMD
    FROM (
    SELECT DISTINCT o.Proyecto, o.Modelo, o.Compartimiento, o.sev, m.ord, m.metal, m.lp, m.lc
    FROM (   /* PERF 2026-09-19: 'sev' por FUNCION DE VENTANA. Reemplaza al CTE compsev y a su JOIN contra
   metrows, que era EL multiplicador: obsf se referenciaba 2 veces y el JOIN caia en nested loops -> la fundacion
   se re-ejecutaba 257 veces (LaboratoryData 25.2M lecturas, 6:21). Medido aislado: 33 s -> 1.5 s, y LaboratoryData
   vuelve a 1 solo scan. ⚠ El sev se calcula ANTES del filtro por metal: el WHERE precede a las funciones de
   ventana, y si se calculara despues, una fila observada solo por V100 (sin ningun m.lp) cambiaria el sev.
   Validacion: VALIDACION_SSMS BLOQUE 76 (equivalencia probada) y BLOQUE 77. */
    SELECT o.*,
        MIN(CASE WHEN o.Estado_General='CRITICO' THEN 1 ELSE 2 END)
            OVER (PARTITION BY o.Proyecto, o.Modelo, o.Compartimiento) AS sev
    FROM (   -- PERF: 1 sola lectura de vw_ObservadosFlota (obsf2/metrows derivan de aqui)
    SELECT mg.ModeloG AS Modelo, o.Proyecto, o.Compartimiento, o.Estado_General,
        o.Fe_ppm,o.Fe_LP,o.Fe_LC, o.Indice_PQ,o.PQ_LP,o.PQ_LC, o.Cr_ppm,o.Cr_LP,o.Cr_LC, o.Ni_ppm,o.Ni_LP,o.Ni_LC,
        o.Cu_ppm,o.Cu_LP,o.Cu_LC, o.Al_ppm,o.Al_LP,o.Al_LC, o.Si_ppm,o.Si_LP,o.Si_LC, o.Pb_ppm,o.Pb_LP, o.Sn_ppm,o.Sn_LP,
        o.TBN,o.TBN_LP, o.Ca_ppm,o.Ca_LP,o.Ca_LC, o.Zn_ppm,o.Zn_LP,o.Zn_LC, o.K_ppm,o.K_LP,o.K_LC, o.Na_ppm,o.Na_LP,o.Na_LC, o.Mg_ppm,o.Mg_LP,o.Mg_LC
    FROM (SELECT * FROM [dbo].[vw_ObservadosFlota] WHERE Proyecto = mp.[Name]) o CROSS APPLY (SELECT o.Modelo AS ModeloG
             UNION ALL
             SELECT N'(todos)' WHERE EXISTS (
                 SELECT 1 FROM [dbo].[vw_ModeloConLimites] ml
                 WHERE ml.ProyKey   = UPPER(LTRIM(RTRIM(o.Proyecto)))
                   AND ml.ModeloKey = UPPER(LTRIM(RTRIM(o.Modelo))))) mg
    WHERE o.Estado_General <> 'OK'
) o
) o
    CROSS APPLY (VALUES
        (1, 'Fe', CASE WHEN Fe_ppm>ISNULL(Fe_LP,9999) THEN CAST(Fe_LP AS decimal(18,1)) END, CASE WHEN Fe_ppm>ISNULL(Fe_LP,9999) THEN CAST(Fe_LC AS decimal(18,1)) END),
        (2, 'PQ', CASE WHEN Indice_PQ>ISNULL(PQ_LP,9999) THEN CAST(PQ_LP AS decimal(18,1)) END, CASE WHEN Indice_PQ>ISNULL(PQ_LP,9999) THEN CAST(PQ_LC AS decimal(18,1)) END),
        (3, 'Cr', CASE WHEN Cr_ppm>ISNULL(Cr_LP,9999) THEN CAST(Cr_LP AS decimal(18,1)) END, CASE WHEN Cr_ppm>ISNULL(Cr_LP,9999) THEN CAST(Cr_LC AS decimal(18,1)) END),
        (4, 'Ni', CASE WHEN Ni_ppm>ISNULL(Ni_LP,9999) THEN CAST(Ni_LP AS decimal(18,1)) END, CASE WHEN Ni_ppm>ISNULL(Ni_LP,9999) THEN CAST(Ni_LC AS decimal(18,1)) END),
        (5, 'Cu', CASE WHEN Cu_ppm>ISNULL(Cu_LP,9999) THEN CAST(Cu_LP AS decimal(18,1)) END, CASE WHEN Cu_ppm>ISNULL(Cu_LP,9999) THEN CAST(Cu_LC AS decimal(18,1)) END),
        (6, 'Al', CASE WHEN Al_ppm>ISNULL(Al_LP,9999) THEN CAST(Al_LP AS decimal(18,1)) END, CASE WHEN Al_ppm>ISNULL(Al_LP,9999) THEN CAST(Al_LC AS decimal(18,1)) END),
        (7, 'Si', CASE WHEN Si_ppm>ISNULL(Si_LP,9999) THEN CAST(Si_LP AS decimal(18,1)) END, CASE WHEN Si_ppm>ISNULL(Si_LP,9999) THEN CAST(Si_LC AS decimal(18,1)) END),
        (8, 'Pb', CASE WHEN Pb_ppm>ISNULL(Pb_LP,9999) THEN CAST(Pb_LP AS decimal(18,1)) END, CAST(NULL AS decimal(18,1))),
        (9, 'Sn', CASE WHEN Sn_ppm>ISNULL(Sn_LP,9999) THEN CAST(Sn_LP AS decimal(18,1)) END, CAST(NULL AS decimal(18,1))),
        (10, 'TBN', CASE WHEN TBN_LP IS NOT NULL AND TBN>0 AND TBN<TBN_LP THEN CAST(TBN_LP AS decimal(18,1)) END, CAST(NULL AS decimal(18,1))),
        (11, 'Ca', CASE WHEN Ca_ppm>ISNULL(Ca_LP,9999) THEN CAST(Ca_LP AS decimal(18,1)) END, CASE WHEN Ca_ppm>ISNULL(Ca_LP,9999) THEN CAST(Ca_LC AS decimal(18,1)) END),
        (12, 'Zn', CASE WHEN Zn_ppm>ISNULL(Zn_LP,9999) THEN CAST(Zn_LP AS decimal(18,1)) END, CASE WHEN Zn_ppm>ISNULL(Zn_LP,9999) THEN CAST(Zn_LC AS decimal(18,1)) END),
        (13, 'K', CASE WHEN K_ppm>ISNULL(K_LP,9999) THEN CAST(K_LP AS decimal(18,1)) END, CASE WHEN K_ppm>ISNULL(K_LP,9999) THEN CAST(K_LC AS decimal(18,1)) END),
        (14, 'Na', CASE WHEN Na_ppm>ISNULL(Na_LP,9999) THEN CAST(Na_LP AS decimal(18,1)) END, CASE WHEN Na_ppm>ISNULL(Na_LP,9999) THEN CAST(Na_LC AS decimal(18,1)) END),
        (15, 'Mg', CASE WHEN Mg_ppm>ISNULL(Mg_LP,9999) THEN CAST(Mg_LP AS decimal(18,1)) END, CASE WHEN Mg_ppm>ISNULL(Mg_LP,9999) THEN CAST(Mg_LC AS decimal(18,1)) END)
    ) m(ord, metal, lp, lc)
    WHERE o.Estado_General <> 'OK' AND m.lp IS NOT NULL
) r2          -- PERF: sin JOIN a compsev; 'sev' ya viene de la ventana en obsf2
    GROUP BY r2.Proyecto, r2.Modelo
) l ON l.Proyecto=t.Proyecto AND ISNULL(l.Modelo,N'')=ISNULL(t.Modelo,N'')
) x;
GO


/* ============================================================================
   vw_DiagnosticoMD — TIER 2, diagnóstico de 1 equipo (columnas MD / MD_Completo).
   1 fila por componente, columna «Parámetros» uniforme (valor+chip), variantes:
   MD = solo observados («X de N»); MD_Completo = todos (OK marcados «— (OK)»). + límites.
   Calcada de vw_DiagnosticoEquipo + formato. Filtro del flujo: Equipo. ⚠ emojis: abrir .sql desde archivo.
   Validación: VALIDACION_SSMS.sql BLOQUE 36.
   ---------------------------------------------------------------------------- */
CREATE OR ALTER VIEW [dbo].[vw_DiagnosticoMD] AS
/* 30/09 -- EL FILTRO POR EQUIPO VIVE ABAJO, igual que en vw_CondicionMT_MD (BLOQUE 184: 146 s -> 1,4 s).
   Con la logica en CTEs y el filtro sobre el resultado, el optimizador calculaba TODA la flota y filtraba
   al final (~170 s por camion, BLOQUES 173-176). Un CROSS APPLY no admite WITH, asi que los 15 CTE van
   desplegados en su sitio -- es lo mismo que SQL Server hace por dentro: un CTE es una macro, no una
   tabla. Cada copia ya lleva el equipo fijado en su base (d.Equipo = me.Code), asi que las lecturas
   repetidas son de UN camion. Equipo sale de me.[Code]: el WHERE del flujo cae sobre la tabla chica.
   Misma logica y misma salida que la version con CTEs. */
SELECT me.[Code] AS Equipo, x.Proyecto, x.Modelo, x.NumCompObs, x.NumCompTotal, x.Observados, x.Recomendaciones, x.MD, x.MD_Completo
FROM [Mine].[MiningEquipment] me
CROSS APPLY (
SELECT
    g.Equipo, g.Proyecto, g.Modelo, g.NumCompObs, g.NumCompTotal, oa.Observados, ISNULL(rb.Recomendaciones, N'**🔧 Recomendaciones Técnicas**' + NCHAR(10) + N'Las recomendaciones técnicas hoy solo están definidas para Motor de Tracción, y sus MT no tienen parámetros fuera de límite. Lo observado en los demás componentes aparece marcado en la tabla.') AS Recomendaciones,
    CAST(
        N'**Diagnóstico ' + g.Equipo + N' — ' + CAST(g.NumCompObs AS nvarchar(10)) + N' de ' + CAST(g.NumCompTotal AS nvarchar(10)) + N' componentes observados**' + NCHAR(10) + NCHAR(10)
      + CASE WHEN bo.bodyMD IS NULL THEN
             /* Equipo SANO: 0 componentes observados. Antes la tabla quedaba vacia y todo el MD se volvia
                NULL -> el flujo respondia 'no encontre datos', que suena a que el equipo no existe. La
                respuesta correcta es decir que NO tiene observados: es justo lo que se pregunto. */
             N'_Ninguno de sus ' + CAST(g.NumCompTotal AS nvarchar(10)) + N' componentes tiene parámetros fuera de límite._'
        ELSE
             N'| Par. | ' + ho.cols + N' |' + NCHAR(10)
           + N'|---|' + REPLICATE(N'---|', ho.N) + NCHAR(10)
           + bo.bodyMD + NCHAR(10) + NCHAR(10) + N'_`Ca`, `Mg`, `Mo` y `Zn` cambian de sentido según la columna: en **Motor de Tracción** (MT LH / MT RH) son **contaminantes** y la alerta es por **ENCIMA** del límite; en **los demás componentes** son **aditivos** y la alerta es por **DEBAJO** (el aditivo se agota)._'
        END
    AS nvarchar(max)) AS MD,
    CAST(
        N'**Diagnóstico ' + g.Equipo + N' (completo) — ' + CAST(g.NumCompTotal AS nvarchar(10)) + N' componentes**' + NCHAR(10) + NCHAR(10)
      + N'| Par. | ' + ha.cols + N' |' + NCHAR(10)
      + N'|---|' + REPLICATE(N'---|', ha.N) + NCHAR(10)
      + ba.bodyMD + NCHAR(10) + NCHAR(10) + N'_`Ca`, `Mg`, `Mo` y `Zn` cambian de sentido según la columna: en **Motor de Tracción** (MT LH / MT RH) son **contaminantes** y la alerta es por **ENCIMA** del límite; en **los demás componentes** son **aditivos** y la alerta es por **DEBAJO** (el aditivo se agota)._'
    AS nvarchar(max)) AS MD_Completo
FROM (
    SELECT Equipo, MAX(Proyecto) AS Proyecto, MAX(Modelo) AS Modelo,
        SUM(CASE WHEN CompMarcado = 1 THEN 1 ELSE 0 END) AS NumCompObs,
        COUNT(*) AS NumCompTotal
    FROM (   /* 1 fila por equipo+componente, DERIVADA de unpv.
               Antes hdr_all, hdr_obs y g leian 'base' por su cuenta (3 lecturas de una cadena de
               4 vistas). unpv ya trae cada componente 31 veces: agrupar aqui sale gratis. */
    SELECT Equipo, Compartimiento,
           MAX(Proyecto)    AS Proyecto,
           MAX(Modelo)      AS Modelo,
           MAX(compOrd)     AS compOrd,
           MAX(compAbbr)    AS compAbbr,
           MAX(CompMarcado) AS CompMarcado
    FROM (   /* Las filas salen del formato CRUZADO (union de las 4 hojas, 31 parametros): esta tabla es
               parametros x COMPONENTES, asi que no puede seguir el formato de un solo componente. */
    SELECT b.Equipo, b.Proyecto, b.Modelo, b.Compartimiento, b.compOrd, b.compAbbr, b.CompMarcado,
           f.Orden AS ord, f.Grupo AS grp, f.Parametro AS nombre,
           v.cell,
           /* El valor CRUDO, antes de sustituir ':C'/':P' por los cuadros de color.
              ⛔ NO filtrar por el emoji: son caracteres SUPLEMENTARIOS (U+1F7E5/U+1F7E8) y el
              LIKE de SQL Server con una collation no-_SC no los trata como un solo caracter,
              asi que el patron matchea de mas. Se intento el 29/09 y 'Observados' devolvio los
              31 parametros en vez de los marcados. La marca se busca en ASCII: ':C' / ':P'.
              Mismo patron que el bloque E4 sobre vw_CondicionMT_MD. */
           v.raw
    /* ⚡ PERF (28/09) — antes esto era:
           FROM (   /* UNICA lectura de la fundacion. Antes se leia 4 veces (base, unpv, obsmetals,
                    obsmet) y los CTE de SQL Server NO se materializan: cada referencia la re-ejecutaba.
                    Medido: 1 scan de LaboratoryData en la fuente -> 5-7 en esta vista (BLOQUE 116). */
    SELECT d.*,
        /* Componente OBSERVADO = tiene al menos una celda marcada en la tabla que se imprime.
           Antes se usaba Estado_General, que solo mira 9 metales de desgaste + TBN: el encabezado
           contaba 0 mientras la tabla pintaba un Zn en rojo (BLOQUE 118). Va aqui, en la unica
           lectura de la fundacion, para no agregar referencias al CTE (BLOQUE 117). */
        CASE WHEN CONCAT(Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si,Ca,Zn,K,Na,Mg,B,P,V100,TBN,Mo,TAN,Oxidacion,Sulfatacion,Nitracion,Hollin,Diesel,Agua,ISO4,ISO6,ISO14,V40) LIKE '%:C%'
               OR CONCAT(Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si,Ca,Zn,K,Na,Mg,B,P,V100,TBN,Mo,TAN,Oxidacion,Sulfatacion,Nitracion,Hollin,Diesel,Agua,ISO4,ISO6,ISO14,V40) LIKE '%:P%' THEN 1 ELSE 0 END AS CompMarcado,
        CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN 1 WHEN Compartimiento LIKE '%TRACCION%RH' THEN 2 WHEN Compartimiento LIKE '%RUEDA%LH' THEN 3 WHEN Compartimiento LIKE '%RUEDA%RH' THEN 4 WHEN Compartimiento LIKE '%HIDRAUL%' THEN 6 WHEN Compartimiento='MOTOR' THEN 5 ELSE 9 END AS compOrd, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr
    FROM [dbo].[vw_DiagnosticoEquipo] d
    WHERE d.Equipo = me.[Code]
) b
           INNER JOIN vw_FormatoParametro f ON f.CompTipo='(CRUZADO)'   <- cartesiano base x 31
           OUTER APPLY (SELECT v.cell FROM (VALUES ...31...) v WHERE v.Parametro=f.Parametro)
       o sea: por cada (fila de base x fila del catalogo) se armaba la tabla de 31 tuplas
       ENTERA y se filtraba DENTRO del apply. 6 componentes x 31 parametros = 186 applies,
       cada uno re-derivando 'base', que cuelga de una cadena de 4 vistas.
       MEDIDO (bloque 145.5): 431 scans de [Oil].[LaboratoryData] y 11 910 696 lecturas
       logicas -> 348 s. El triage, que lee la fundacion UNA vez, hacia 1 scan y 1 365.
       AHORA: se expande base UNA vez a sus 31 filas y DESPUES se une el catalogo. Es el
       unpivot de siempre, y es la misma cura que curo el triage (ley 2). */
    FROM (   /* UNICA lectura de la fundacion. Antes se leia 4 veces (base, unpv, obsmetals,
                    obsmet) y los CTE de SQL Server NO se materializan: cada referencia la re-ejecutaba.
                    Medido: 1 scan de LaboratoryData en la fuente -> 5-7 en esta vista (BLOQUE 116). */
    SELECT d.*,
        /* Componente OBSERVADO = tiene al menos una celda marcada en la tabla que se imprime.
           Antes se usaba Estado_General, que solo mira 9 metales de desgaste + TBN: el encabezado
           contaba 0 mientras la tabla pintaba un Zn en rojo (BLOQUE 118). Va aqui, en la unica
           lectura de la fundacion, para no agregar referencias al CTE (BLOQUE 117). */
        CASE WHEN CONCAT(Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si,Ca,Zn,K,Na,Mg,B,P,V100,TBN,Mo,TAN,Oxidacion,Sulfatacion,Nitracion,Hollin,Diesel,Agua,ISO4,ISO6,ISO14,V40) LIKE '%:C%'
               OR CONCAT(Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si,Ca,Zn,K,Na,Mg,B,P,V100,TBN,Mo,TAN,Oxidacion,Sulfatacion,Nitracion,Hollin,Diesel,Agua,ISO4,ISO6,ISO14,V40) LIKE '%:P%' THEN 1 ELSE 0 END AS CompMarcado,
        CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN 1 WHEN Compartimiento LIKE '%TRACCION%RH' THEN 2 WHEN Compartimiento LIKE '%RUEDA%LH' THEN 3 WHEN Compartimiento LIKE '%RUEDA%RH' THEN 4 WHEN Compartimiento LIKE '%HIDRAUL%' THEN 6 WHEN Compartimiento='MOTOR' THEN 5 ELSE 9 END AS compOrd, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr
    FROM [dbo].[vw_DiagnosticoEquipo] d
    WHERE d.Equipo = me.[Code]
) b
    CROSS APPLY (VALUES
            (N'Fe', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Fe AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Fe),
            (N'PQ', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(PQ AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), PQ),
            (N'Cr', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Cr AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Cr),
            (N'Ni', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Ni AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Ni),
            (N'Cu', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Cu AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Cu),
            (N'Pb', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Pb AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Pb),
            (N'Sn', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Sn AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Sn),
            (N'Al', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Al AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Al),
            (N'Si', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Si AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Si),
            (N'Ca', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Ca AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Ca),
            (N'Zn', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Zn AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Zn),
            (N'K', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(K AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), K),
            (N'Na', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Na AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Na),
            (N'B', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(B AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), B),
            (N'P', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(P AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), P),
            (N'Mg', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Mg AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Mg),
            (N'V100', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(V100 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), V100),
            (N'TBN', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(TBN AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), TBN),
            (N'Mo', ISNULL(REPLACE(REPLACE(CAST(Mo AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Mo),
            (N'TAN', ISNULL(REPLACE(REPLACE(CAST(TAN AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), TAN),
            (N'Oxidacion', ISNULL(REPLACE(REPLACE(CAST(Oxidacion AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Oxidacion),
            (N'Sulfatacion', ISNULL(REPLACE(REPLACE(CAST(Sulfatacion AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Sulfatacion),
            (N'Nitracion', ISNULL(REPLACE(REPLACE(CAST(Nitracion AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Nitracion),
            (N'Hollin', ISNULL(REPLACE(REPLACE(CAST(Hollin AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Hollin),
            (N'Diesel', ISNULL(REPLACE(REPLACE(CAST(Diesel AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Diesel),
            (N'Agua', ISNULL(REPLACE(REPLACE(CAST(Agua AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Agua),
            (N'Refrigerante', ISNULL(REPLACE(REPLACE(CAST(Refrigerante AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Refrigerante),
            (N'ISO>4', ISNULL(REPLACE(REPLACE(CAST(ISO4 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), ISO4),
            (N'ISO>6', ISNULL(REPLACE(REPLACE(CAST(ISO6 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), ISO6),
            (N'ISO>14', ISNULL(REPLACE(REPLACE(CAST(ISO14 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), ISO14),
            (N'V40', ISNULL(REPLACE(REPLACE(CAST(V40 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), V40)
    ) v(Parametro, cell, raw)
    INNER JOIN [dbo].[vw_FormatoParametro] f
        ON f.CompTipo = '(CRUZADO)' AND f.Parametro = v.Parametro
) unpv
    GROUP BY Equipo, Compartimiento
) comp GROUP BY Equipo
) g
JOIN (
    SELECT Equipo, COUNT(DISTINCT Compartimiento) AS N,
        STRING_AGG(compAbbr, N' | ') WITHIN GROUP (ORDER BY compOrd) AS cols
    FROM (   /* 1 fila por equipo+componente, DERIVADA de unpv.
               Antes hdr_all, hdr_obs y g leian 'base' por su cuenta (3 lecturas de una cadena de
               4 vistas). unpv ya trae cada componente 31 veces: agrupar aqui sale gratis. */
    SELECT Equipo, Compartimiento,
           MAX(Proyecto)    AS Proyecto,
           MAX(Modelo)      AS Modelo,
           MAX(compOrd)     AS compOrd,
           MAX(compAbbr)    AS compAbbr,
           MAX(CompMarcado) AS CompMarcado
    FROM (   /* Las filas salen del formato CRUZADO (union de las 4 hojas, 31 parametros): esta tabla es
               parametros x COMPONENTES, asi que no puede seguir el formato de un solo componente. */
    SELECT b.Equipo, b.Proyecto, b.Modelo, b.Compartimiento, b.compOrd, b.compAbbr, b.CompMarcado,
           f.Orden AS ord, f.Grupo AS grp, f.Parametro AS nombre,
           v.cell,
           /* El valor CRUDO, antes de sustituir ':C'/':P' por los cuadros de color.
              ⛔ NO filtrar por el emoji: son caracteres SUPLEMENTARIOS (U+1F7E5/U+1F7E8) y el
              LIKE de SQL Server con una collation no-_SC no los trata como un solo caracter,
              asi que el patron matchea de mas. Se intento el 29/09 y 'Observados' devolvio los
              31 parametros en vez de los marcados. La marca se busca en ASCII: ':C' / ':P'.
              Mismo patron que el bloque E4 sobre vw_CondicionMT_MD. */
           v.raw
    /* ⚡ PERF (28/09) — antes esto era:
           FROM (   /* UNICA lectura de la fundacion. Antes se leia 4 veces (base, unpv, obsmetals,
                    obsmet) y los CTE de SQL Server NO se materializan: cada referencia la re-ejecutaba.
                    Medido: 1 scan de LaboratoryData en la fuente -> 5-7 en esta vista (BLOQUE 116). */
    SELECT d.*,
        /* Componente OBSERVADO = tiene al menos una celda marcada en la tabla que se imprime.
           Antes se usaba Estado_General, que solo mira 9 metales de desgaste + TBN: el encabezado
           contaba 0 mientras la tabla pintaba un Zn en rojo (BLOQUE 118). Va aqui, en la unica
           lectura de la fundacion, para no agregar referencias al CTE (BLOQUE 117). */
        CASE WHEN CONCAT(Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si,Ca,Zn,K,Na,Mg,B,P,V100,TBN,Mo,TAN,Oxidacion,Sulfatacion,Nitracion,Hollin,Diesel,Agua,ISO4,ISO6,ISO14,V40) LIKE '%:C%'
               OR CONCAT(Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si,Ca,Zn,K,Na,Mg,B,P,V100,TBN,Mo,TAN,Oxidacion,Sulfatacion,Nitracion,Hollin,Diesel,Agua,ISO4,ISO6,ISO14,V40) LIKE '%:P%' THEN 1 ELSE 0 END AS CompMarcado,
        CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN 1 WHEN Compartimiento LIKE '%TRACCION%RH' THEN 2 WHEN Compartimiento LIKE '%RUEDA%LH' THEN 3 WHEN Compartimiento LIKE '%RUEDA%RH' THEN 4 WHEN Compartimiento LIKE '%HIDRAUL%' THEN 6 WHEN Compartimiento='MOTOR' THEN 5 ELSE 9 END AS compOrd, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr
    FROM [dbo].[vw_DiagnosticoEquipo] d
    WHERE d.Equipo = me.[Code]
) b
           INNER JOIN vw_FormatoParametro f ON f.CompTipo='(CRUZADO)'   <- cartesiano base x 31
           OUTER APPLY (SELECT v.cell FROM (VALUES ...31...) v WHERE v.Parametro=f.Parametro)
       o sea: por cada (fila de base x fila del catalogo) se armaba la tabla de 31 tuplas
       ENTERA y se filtraba DENTRO del apply. 6 componentes x 31 parametros = 186 applies,
       cada uno re-derivando 'base', que cuelga de una cadena de 4 vistas.
       MEDIDO (bloque 145.5): 431 scans de [Oil].[LaboratoryData] y 11 910 696 lecturas
       logicas -> 348 s. El triage, que lee la fundacion UNA vez, hacia 1 scan y 1 365.
       AHORA: se expande base UNA vez a sus 31 filas y DESPUES se une el catalogo. Es el
       unpivot de siempre, y es la misma cura que curo el triage (ley 2). */
    FROM (   /* UNICA lectura de la fundacion. Antes se leia 4 veces (base, unpv, obsmetals,
                    obsmet) y los CTE de SQL Server NO se materializan: cada referencia la re-ejecutaba.
                    Medido: 1 scan de LaboratoryData en la fuente -> 5-7 en esta vista (BLOQUE 116). */
    SELECT d.*,
        /* Componente OBSERVADO = tiene al menos una celda marcada en la tabla que se imprime.
           Antes se usaba Estado_General, que solo mira 9 metales de desgaste + TBN: el encabezado
           contaba 0 mientras la tabla pintaba un Zn en rojo (BLOQUE 118). Va aqui, en la unica
           lectura de la fundacion, para no agregar referencias al CTE (BLOQUE 117). */
        CASE WHEN CONCAT(Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si,Ca,Zn,K,Na,Mg,B,P,V100,TBN,Mo,TAN,Oxidacion,Sulfatacion,Nitracion,Hollin,Diesel,Agua,ISO4,ISO6,ISO14,V40) LIKE '%:C%'
               OR CONCAT(Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si,Ca,Zn,K,Na,Mg,B,P,V100,TBN,Mo,TAN,Oxidacion,Sulfatacion,Nitracion,Hollin,Diesel,Agua,ISO4,ISO6,ISO14,V40) LIKE '%:P%' THEN 1 ELSE 0 END AS CompMarcado,
        CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN 1 WHEN Compartimiento LIKE '%TRACCION%RH' THEN 2 WHEN Compartimiento LIKE '%RUEDA%LH' THEN 3 WHEN Compartimiento LIKE '%RUEDA%RH' THEN 4 WHEN Compartimiento LIKE '%HIDRAUL%' THEN 6 WHEN Compartimiento='MOTOR' THEN 5 ELSE 9 END AS compOrd, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr
    FROM [dbo].[vw_DiagnosticoEquipo] d
    WHERE d.Equipo = me.[Code]
) b
    CROSS APPLY (VALUES
            (N'Fe', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Fe AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Fe),
            (N'PQ', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(PQ AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), PQ),
            (N'Cr', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Cr AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Cr),
            (N'Ni', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Ni AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Ni),
            (N'Cu', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Cu AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Cu),
            (N'Pb', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Pb AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Pb),
            (N'Sn', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Sn AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Sn),
            (N'Al', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Al AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Al),
            (N'Si', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Si AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Si),
            (N'Ca', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Ca AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Ca),
            (N'Zn', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Zn AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Zn),
            (N'K', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(K AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), K),
            (N'Na', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Na AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Na),
            (N'B', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(B AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), B),
            (N'P', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(P AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), P),
            (N'Mg', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Mg AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Mg),
            (N'V100', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(V100 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), V100),
            (N'TBN', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(TBN AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), TBN),
            (N'Mo', ISNULL(REPLACE(REPLACE(CAST(Mo AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Mo),
            (N'TAN', ISNULL(REPLACE(REPLACE(CAST(TAN AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), TAN),
            (N'Oxidacion', ISNULL(REPLACE(REPLACE(CAST(Oxidacion AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Oxidacion),
            (N'Sulfatacion', ISNULL(REPLACE(REPLACE(CAST(Sulfatacion AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Sulfatacion),
            (N'Nitracion', ISNULL(REPLACE(REPLACE(CAST(Nitracion AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Nitracion),
            (N'Hollin', ISNULL(REPLACE(REPLACE(CAST(Hollin AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Hollin),
            (N'Diesel', ISNULL(REPLACE(REPLACE(CAST(Diesel AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Diesel),
            (N'Agua', ISNULL(REPLACE(REPLACE(CAST(Agua AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Agua),
            (N'Refrigerante', ISNULL(REPLACE(REPLACE(CAST(Refrigerante AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Refrigerante),
            (N'ISO>4', ISNULL(REPLACE(REPLACE(CAST(ISO4 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), ISO4),
            (N'ISO>6', ISNULL(REPLACE(REPLACE(CAST(ISO6 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), ISO6),
            (N'ISO>14', ISNULL(REPLACE(REPLACE(CAST(ISO14 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), ISO14),
            (N'V40', ISNULL(REPLACE(REPLACE(CAST(V40 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), V40)
    ) v(Parametro, cell, raw)
    INNER JOIN [dbo].[vw_FormatoParametro] f
        ON f.CompTipo = '(CRUZADO)' AND f.Parametro = v.Parametro
) unpv
    GROUP BY Equipo, Compartimiento
) comp GROUP BY Equipo
) ha ON ha.Equipo=g.Equipo
JOIN (
    SELECT r.Equipo,
        STRING_AGG(CAST(CASE WHEN r.EsInicioGrupo = 1 THEN N'| **' + r.grp + N'** |' + REPLICATE(N' |', h.N) + NCHAR(10) ELSE N'' END + r.rowMD AS nvarchar(max)), NCHAR(10))
            WITHIN GROUP (ORDER BY r.ord) AS bodyMD
    FROM (
    SELECT Equipo, grp, ord, nombre,
        CASE WHEN ROW_NUMBER() OVER (PARTITION BY Equipo, grp ORDER BY ord) = 1 THEN 1 ELSE 0 END AS EsInicioGrupo,
        CAST(N'| ' + nombre + N' | ' + STRING_AGG(cell, N' | ') WITHIN GROUP (ORDER BY compOrd) + N' |' AS nvarchar(max)) AS rowMD
    FROM (   /* Las filas salen del formato CRUZADO (union de las 4 hojas, 31 parametros): esta tabla es
               parametros x COMPONENTES, asi que no puede seguir el formato de un solo componente. */
    SELECT b.Equipo, b.Proyecto, b.Modelo, b.Compartimiento, b.compOrd, b.compAbbr, b.CompMarcado,
           f.Orden AS ord, f.Grupo AS grp, f.Parametro AS nombre,
           v.cell,
           /* El valor CRUDO, antes de sustituir ':C'/':P' por los cuadros de color.
              ⛔ NO filtrar por el emoji: son caracteres SUPLEMENTARIOS (U+1F7E5/U+1F7E8) y el
              LIKE de SQL Server con una collation no-_SC no los trata como un solo caracter,
              asi que el patron matchea de mas. Se intento el 29/09 y 'Observados' devolvio los
              31 parametros en vez de los marcados. La marca se busca en ASCII: ':C' / ':P'.
              Mismo patron que el bloque E4 sobre vw_CondicionMT_MD. */
           v.raw
    /* ⚡ PERF (28/09) — antes esto era:
           FROM (   /* UNICA lectura de la fundacion. Antes se leia 4 veces (base, unpv, obsmetals,
                    obsmet) y los CTE de SQL Server NO se materializan: cada referencia la re-ejecutaba.
                    Medido: 1 scan de LaboratoryData en la fuente -> 5-7 en esta vista (BLOQUE 116). */
    SELECT d.*,
        /* Componente OBSERVADO = tiene al menos una celda marcada en la tabla que se imprime.
           Antes se usaba Estado_General, que solo mira 9 metales de desgaste + TBN: el encabezado
           contaba 0 mientras la tabla pintaba un Zn en rojo (BLOQUE 118). Va aqui, en la unica
           lectura de la fundacion, para no agregar referencias al CTE (BLOQUE 117). */
        CASE WHEN CONCAT(Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si,Ca,Zn,K,Na,Mg,B,P,V100,TBN,Mo,TAN,Oxidacion,Sulfatacion,Nitracion,Hollin,Diesel,Agua,ISO4,ISO6,ISO14,V40) LIKE '%:C%'
               OR CONCAT(Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si,Ca,Zn,K,Na,Mg,B,P,V100,TBN,Mo,TAN,Oxidacion,Sulfatacion,Nitracion,Hollin,Diesel,Agua,ISO4,ISO6,ISO14,V40) LIKE '%:P%' THEN 1 ELSE 0 END AS CompMarcado,
        CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN 1 WHEN Compartimiento LIKE '%TRACCION%RH' THEN 2 WHEN Compartimiento LIKE '%RUEDA%LH' THEN 3 WHEN Compartimiento LIKE '%RUEDA%RH' THEN 4 WHEN Compartimiento LIKE '%HIDRAUL%' THEN 6 WHEN Compartimiento='MOTOR' THEN 5 ELSE 9 END AS compOrd, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr
    FROM [dbo].[vw_DiagnosticoEquipo] d
    WHERE d.Equipo = me.[Code]
) b
           INNER JOIN vw_FormatoParametro f ON f.CompTipo='(CRUZADO)'   <- cartesiano base x 31
           OUTER APPLY (SELECT v.cell FROM (VALUES ...31...) v WHERE v.Parametro=f.Parametro)
       o sea: por cada (fila de base x fila del catalogo) se armaba la tabla de 31 tuplas
       ENTERA y se filtraba DENTRO del apply. 6 componentes x 31 parametros = 186 applies,
       cada uno re-derivando 'base', que cuelga de una cadena de 4 vistas.
       MEDIDO (bloque 145.5): 431 scans de [Oil].[LaboratoryData] y 11 910 696 lecturas
       logicas -> 348 s. El triage, que lee la fundacion UNA vez, hacia 1 scan y 1 365.
       AHORA: se expande base UNA vez a sus 31 filas y DESPUES se une el catalogo. Es el
       unpivot de siempre, y es la misma cura que curo el triage (ley 2). */
    FROM (   /* UNICA lectura de la fundacion. Antes se leia 4 veces (base, unpv, obsmetals,
                    obsmet) y los CTE de SQL Server NO se materializan: cada referencia la re-ejecutaba.
                    Medido: 1 scan de LaboratoryData en la fuente -> 5-7 en esta vista (BLOQUE 116). */
    SELECT d.*,
        /* Componente OBSERVADO = tiene al menos una celda marcada en la tabla que se imprime.
           Antes se usaba Estado_General, que solo mira 9 metales de desgaste + TBN: el encabezado
           contaba 0 mientras la tabla pintaba un Zn en rojo (BLOQUE 118). Va aqui, en la unica
           lectura de la fundacion, para no agregar referencias al CTE (BLOQUE 117). */
        CASE WHEN CONCAT(Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si,Ca,Zn,K,Na,Mg,B,P,V100,TBN,Mo,TAN,Oxidacion,Sulfatacion,Nitracion,Hollin,Diesel,Agua,ISO4,ISO6,ISO14,V40) LIKE '%:C%'
               OR CONCAT(Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si,Ca,Zn,K,Na,Mg,B,P,V100,TBN,Mo,TAN,Oxidacion,Sulfatacion,Nitracion,Hollin,Diesel,Agua,ISO4,ISO6,ISO14,V40) LIKE '%:P%' THEN 1 ELSE 0 END AS CompMarcado,
        CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN 1 WHEN Compartimiento LIKE '%TRACCION%RH' THEN 2 WHEN Compartimiento LIKE '%RUEDA%LH' THEN 3 WHEN Compartimiento LIKE '%RUEDA%RH' THEN 4 WHEN Compartimiento LIKE '%HIDRAUL%' THEN 6 WHEN Compartimiento='MOTOR' THEN 5 ELSE 9 END AS compOrd, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr
    FROM [dbo].[vw_DiagnosticoEquipo] d
    WHERE d.Equipo = me.[Code]
) b
    CROSS APPLY (VALUES
            (N'Fe', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Fe AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Fe),
            (N'PQ', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(PQ AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), PQ),
            (N'Cr', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Cr AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Cr),
            (N'Ni', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Ni AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Ni),
            (N'Cu', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Cu AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Cu),
            (N'Pb', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Pb AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Pb),
            (N'Sn', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Sn AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Sn),
            (N'Al', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Al AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Al),
            (N'Si', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Si AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Si),
            (N'Ca', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Ca AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Ca),
            (N'Zn', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Zn AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Zn),
            (N'K', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(K AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), K),
            (N'Na', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Na AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Na),
            (N'B', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(B AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), B),
            (N'P', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(P AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), P),
            (N'Mg', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Mg AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Mg),
            (N'V100', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(V100 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), V100),
            (N'TBN', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(TBN AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), TBN),
            (N'Mo', ISNULL(REPLACE(REPLACE(CAST(Mo AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Mo),
            (N'TAN', ISNULL(REPLACE(REPLACE(CAST(TAN AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), TAN),
            (N'Oxidacion', ISNULL(REPLACE(REPLACE(CAST(Oxidacion AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Oxidacion),
            (N'Sulfatacion', ISNULL(REPLACE(REPLACE(CAST(Sulfatacion AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Sulfatacion),
            (N'Nitracion', ISNULL(REPLACE(REPLACE(CAST(Nitracion AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Nitracion),
            (N'Hollin', ISNULL(REPLACE(REPLACE(CAST(Hollin AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Hollin),
            (N'Diesel', ISNULL(REPLACE(REPLACE(CAST(Diesel AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Diesel),
            (N'Agua', ISNULL(REPLACE(REPLACE(CAST(Agua AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Agua),
            (N'Refrigerante', ISNULL(REPLACE(REPLACE(CAST(Refrigerante AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Refrigerante),
            (N'ISO>4', ISNULL(REPLACE(REPLACE(CAST(ISO4 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), ISO4),
            (N'ISO>6', ISNULL(REPLACE(REPLACE(CAST(ISO6 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), ISO6),
            (N'ISO>14', ISNULL(REPLACE(REPLACE(CAST(ISO14 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), ISO14),
            (N'V40', ISNULL(REPLACE(REPLACE(CAST(V40 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), V40)
    ) v(Parametro, cell, raw)
    INNER JOIN [dbo].[vw_FormatoParametro] f
        ON f.CompTipo = '(CRUZADO)' AND f.Parametro = v.Parametro
) unpv GROUP BY Equipo, grp, ord, nombre
) r JOIN (
    SELECT Equipo, COUNT(DISTINCT Compartimiento) AS N,
        STRING_AGG(compAbbr, N' | ') WITHIN GROUP (ORDER BY compOrd) AS cols
    FROM (   /* 1 fila por equipo+componente, DERIVADA de unpv.
               Antes hdr_all, hdr_obs y g leian 'base' por su cuenta (3 lecturas de una cadena de
               4 vistas). unpv ya trae cada componente 31 veces: agrupar aqui sale gratis. */
    SELECT Equipo, Compartimiento,
           MAX(Proyecto)    AS Proyecto,
           MAX(Modelo)      AS Modelo,
           MAX(compOrd)     AS compOrd,
           MAX(compAbbr)    AS compAbbr,
           MAX(CompMarcado) AS CompMarcado
    FROM (   /* Las filas salen del formato CRUZADO (union de las 4 hojas, 31 parametros): esta tabla es
               parametros x COMPONENTES, asi que no puede seguir el formato de un solo componente. */
    SELECT b.Equipo, b.Proyecto, b.Modelo, b.Compartimiento, b.compOrd, b.compAbbr, b.CompMarcado,
           f.Orden AS ord, f.Grupo AS grp, f.Parametro AS nombre,
           v.cell,
           /* El valor CRUDO, antes de sustituir ':C'/':P' por los cuadros de color.
              ⛔ NO filtrar por el emoji: son caracteres SUPLEMENTARIOS (U+1F7E5/U+1F7E8) y el
              LIKE de SQL Server con una collation no-_SC no los trata como un solo caracter,
              asi que el patron matchea de mas. Se intento el 29/09 y 'Observados' devolvio los
              31 parametros en vez de los marcados. La marca se busca en ASCII: ':C' / ':P'.
              Mismo patron que el bloque E4 sobre vw_CondicionMT_MD. */
           v.raw
    /* ⚡ PERF (28/09) — antes esto era:
           FROM (   /* UNICA lectura de la fundacion. Antes se leia 4 veces (base, unpv, obsmetals,
                    obsmet) y los CTE de SQL Server NO se materializan: cada referencia la re-ejecutaba.
                    Medido: 1 scan de LaboratoryData en la fuente -> 5-7 en esta vista (BLOQUE 116). */
    SELECT d.*,
        /* Componente OBSERVADO = tiene al menos una celda marcada en la tabla que se imprime.
           Antes se usaba Estado_General, que solo mira 9 metales de desgaste + TBN: el encabezado
           contaba 0 mientras la tabla pintaba un Zn en rojo (BLOQUE 118). Va aqui, en la unica
           lectura de la fundacion, para no agregar referencias al CTE (BLOQUE 117). */
        CASE WHEN CONCAT(Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si,Ca,Zn,K,Na,Mg,B,P,V100,TBN,Mo,TAN,Oxidacion,Sulfatacion,Nitracion,Hollin,Diesel,Agua,ISO4,ISO6,ISO14,V40) LIKE '%:C%'
               OR CONCAT(Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si,Ca,Zn,K,Na,Mg,B,P,V100,TBN,Mo,TAN,Oxidacion,Sulfatacion,Nitracion,Hollin,Diesel,Agua,ISO4,ISO6,ISO14,V40) LIKE '%:P%' THEN 1 ELSE 0 END AS CompMarcado,
        CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN 1 WHEN Compartimiento LIKE '%TRACCION%RH' THEN 2 WHEN Compartimiento LIKE '%RUEDA%LH' THEN 3 WHEN Compartimiento LIKE '%RUEDA%RH' THEN 4 WHEN Compartimiento LIKE '%HIDRAUL%' THEN 6 WHEN Compartimiento='MOTOR' THEN 5 ELSE 9 END AS compOrd, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr
    FROM [dbo].[vw_DiagnosticoEquipo] d
    WHERE d.Equipo = me.[Code]
) b
           INNER JOIN vw_FormatoParametro f ON f.CompTipo='(CRUZADO)'   <- cartesiano base x 31
           OUTER APPLY (SELECT v.cell FROM (VALUES ...31...) v WHERE v.Parametro=f.Parametro)
       o sea: por cada (fila de base x fila del catalogo) se armaba la tabla de 31 tuplas
       ENTERA y se filtraba DENTRO del apply. 6 componentes x 31 parametros = 186 applies,
       cada uno re-derivando 'base', que cuelga de una cadena de 4 vistas.
       MEDIDO (bloque 145.5): 431 scans de [Oil].[LaboratoryData] y 11 910 696 lecturas
       logicas -> 348 s. El triage, que lee la fundacion UNA vez, hacia 1 scan y 1 365.
       AHORA: se expande base UNA vez a sus 31 filas y DESPUES se une el catalogo. Es el
       unpivot de siempre, y es la misma cura que curo el triage (ley 2). */
    FROM (   /* UNICA lectura de la fundacion. Antes se leia 4 veces (base, unpv, obsmetals,
                    obsmet) y los CTE de SQL Server NO se materializan: cada referencia la re-ejecutaba.
                    Medido: 1 scan de LaboratoryData en la fuente -> 5-7 en esta vista (BLOQUE 116). */
    SELECT d.*,
        /* Componente OBSERVADO = tiene al menos una celda marcada en la tabla que se imprime.
           Antes se usaba Estado_General, que solo mira 9 metales de desgaste + TBN: el encabezado
           contaba 0 mientras la tabla pintaba un Zn en rojo (BLOQUE 118). Va aqui, en la unica
           lectura de la fundacion, para no agregar referencias al CTE (BLOQUE 117). */
        CASE WHEN CONCAT(Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si,Ca,Zn,K,Na,Mg,B,P,V100,TBN,Mo,TAN,Oxidacion,Sulfatacion,Nitracion,Hollin,Diesel,Agua,ISO4,ISO6,ISO14,V40) LIKE '%:C%'
               OR CONCAT(Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si,Ca,Zn,K,Na,Mg,B,P,V100,TBN,Mo,TAN,Oxidacion,Sulfatacion,Nitracion,Hollin,Diesel,Agua,ISO4,ISO6,ISO14,V40) LIKE '%:P%' THEN 1 ELSE 0 END AS CompMarcado,
        CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN 1 WHEN Compartimiento LIKE '%TRACCION%RH' THEN 2 WHEN Compartimiento LIKE '%RUEDA%LH' THEN 3 WHEN Compartimiento LIKE '%RUEDA%RH' THEN 4 WHEN Compartimiento LIKE '%HIDRAUL%' THEN 6 WHEN Compartimiento='MOTOR' THEN 5 ELSE 9 END AS compOrd, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr
    FROM [dbo].[vw_DiagnosticoEquipo] d
    WHERE d.Equipo = me.[Code]
) b
    CROSS APPLY (VALUES
            (N'Fe', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Fe AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Fe),
            (N'PQ', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(PQ AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), PQ),
            (N'Cr', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Cr AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Cr),
            (N'Ni', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Ni AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Ni),
            (N'Cu', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Cu AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Cu),
            (N'Pb', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Pb AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Pb),
            (N'Sn', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Sn AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Sn),
            (N'Al', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Al AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Al),
            (N'Si', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Si AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Si),
            (N'Ca', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Ca AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Ca),
            (N'Zn', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Zn AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Zn),
            (N'K', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(K AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), K),
            (N'Na', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Na AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Na),
            (N'B', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(B AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), B),
            (N'P', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(P AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), P),
            (N'Mg', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Mg AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Mg),
            (N'V100', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(V100 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), V100),
            (N'TBN', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(TBN AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), TBN),
            (N'Mo', ISNULL(REPLACE(REPLACE(CAST(Mo AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Mo),
            (N'TAN', ISNULL(REPLACE(REPLACE(CAST(TAN AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), TAN),
            (N'Oxidacion', ISNULL(REPLACE(REPLACE(CAST(Oxidacion AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Oxidacion),
            (N'Sulfatacion', ISNULL(REPLACE(REPLACE(CAST(Sulfatacion AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Sulfatacion),
            (N'Nitracion', ISNULL(REPLACE(REPLACE(CAST(Nitracion AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Nitracion),
            (N'Hollin', ISNULL(REPLACE(REPLACE(CAST(Hollin AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Hollin),
            (N'Diesel', ISNULL(REPLACE(REPLACE(CAST(Diesel AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Diesel),
            (N'Agua', ISNULL(REPLACE(REPLACE(CAST(Agua AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Agua),
            (N'Refrigerante', ISNULL(REPLACE(REPLACE(CAST(Refrigerante AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Refrigerante),
            (N'ISO>4', ISNULL(REPLACE(REPLACE(CAST(ISO4 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), ISO4),
            (N'ISO>6', ISNULL(REPLACE(REPLACE(CAST(ISO6 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), ISO6),
            (N'ISO>14', ISNULL(REPLACE(REPLACE(CAST(ISO14 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), ISO14),
            (N'V40', ISNULL(REPLACE(REPLACE(CAST(V40 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), V40)
    ) v(Parametro, cell, raw)
    INNER JOIN [dbo].[vw_FormatoParametro] f
        ON f.CompTipo = '(CRUZADO)' AND f.Parametro = v.Parametro
) unpv
    GROUP BY Equipo, Compartimiento
) comp GROUP BY Equipo
) h ON h.Equipo=r.Equipo GROUP BY r.Equipo
) ba ON ba.Equipo=g.Equipo
LEFT JOIN (
    SELECT Equipo, COUNT(DISTINCT Compartimiento) AS N,
        STRING_AGG(compAbbr, N' | ') WITHIN GROUP (ORDER BY compOrd) AS cols
    FROM (   /* 1 fila por equipo+componente, DERIVADA de unpv.
               Antes hdr_all, hdr_obs y g leian 'base' por su cuenta (3 lecturas de una cadena de
               4 vistas). unpv ya trae cada componente 31 veces: agrupar aqui sale gratis. */
    SELECT Equipo, Compartimiento,
           MAX(Proyecto)    AS Proyecto,
           MAX(Modelo)      AS Modelo,
           MAX(compOrd)     AS compOrd,
           MAX(compAbbr)    AS compAbbr,
           MAX(CompMarcado) AS CompMarcado
    FROM (   /* Las filas salen del formato CRUZADO (union de las 4 hojas, 31 parametros): esta tabla es
               parametros x COMPONENTES, asi que no puede seguir el formato de un solo componente. */
    SELECT b.Equipo, b.Proyecto, b.Modelo, b.Compartimiento, b.compOrd, b.compAbbr, b.CompMarcado,
           f.Orden AS ord, f.Grupo AS grp, f.Parametro AS nombre,
           v.cell,
           /* El valor CRUDO, antes de sustituir ':C'/':P' por los cuadros de color.
              ⛔ NO filtrar por el emoji: son caracteres SUPLEMENTARIOS (U+1F7E5/U+1F7E8) y el
              LIKE de SQL Server con una collation no-_SC no los trata como un solo caracter,
              asi que el patron matchea de mas. Se intento el 29/09 y 'Observados' devolvio los
              31 parametros en vez de los marcados. La marca se busca en ASCII: ':C' / ':P'.
              Mismo patron que el bloque E4 sobre vw_CondicionMT_MD. */
           v.raw
    /* ⚡ PERF (28/09) — antes esto era:
           FROM (   /* UNICA lectura de la fundacion. Antes se leia 4 veces (base, unpv, obsmetals,
                    obsmet) y los CTE de SQL Server NO se materializan: cada referencia la re-ejecutaba.
                    Medido: 1 scan de LaboratoryData en la fuente -> 5-7 en esta vista (BLOQUE 116). */
    SELECT d.*,
        /* Componente OBSERVADO = tiene al menos una celda marcada en la tabla que se imprime.
           Antes se usaba Estado_General, que solo mira 9 metales de desgaste + TBN: el encabezado
           contaba 0 mientras la tabla pintaba un Zn en rojo (BLOQUE 118). Va aqui, en la unica
           lectura de la fundacion, para no agregar referencias al CTE (BLOQUE 117). */
        CASE WHEN CONCAT(Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si,Ca,Zn,K,Na,Mg,B,P,V100,TBN,Mo,TAN,Oxidacion,Sulfatacion,Nitracion,Hollin,Diesel,Agua,ISO4,ISO6,ISO14,V40) LIKE '%:C%'
               OR CONCAT(Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si,Ca,Zn,K,Na,Mg,B,P,V100,TBN,Mo,TAN,Oxidacion,Sulfatacion,Nitracion,Hollin,Diesel,Agua,ISO4,ISO6,ISO14,V40) LIKE '%:P%' THEN 1 ELSE 0 END AS CompMarcado,
        CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN 1 WHEN Compartimiento LIKE '%TRACCION%RH' THEN 2 WHEN Compartimiento LIKE '%RUEDA%LH' THEN 3 WHEN Compartimiento LIKE '%RUEDA%RH' THEN 4 WHEN Compartimiento LIKE '%HIDRAUL%' THEN 6 WHEN Compartimiento='MOTOR' THEN 5 ELSE 9 END AS compOrd, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr
    FROM [dbo].[vw_DiagnosticoEquipo] d
    WHERE d.Equipo = me.[Code]
) b
           INNER JOIN vw_FormatoParametro f ON f.CompTipo='(CRUZADO)'   <- cartesiano base x 31
           OUTER APPLY (SELECT v.cell FROM (VALUES ...31...) v WHERE v.Parametro=f.Parametro)
       o sea: por cada (fila de base x fila del catalogo) se armaba la tabla de 31 tuplas
       ENTERA y se filtraba DENTRO del apply. 6 componentes x 31 parametros = 186 applies,
       cada uno re-derivando 'base', que cuelga de una cadena de 4 vistas.
       MEDIDO (bloque 145.5): 431 scans de [Oil].[LaboratoryData] y 11 910 696 lecturas
       logicas -> 348 s. El triage, que lee la fundacion UNA vez, hacia 1 scan y 1 365.
       AHORA: se expande base UNA vez a sus 31 filas y DESPUES se une el catalogo. Es el
       unpivot de siempre, y es la misma cura que curo el triage (ley 2). */
    FROM (   /* UNICA lectura de la fundacion. Antes se leia 4 veces (base, unpv, obsmetals,
                    obsmet) y los CTE de SQL Server NO se materializan: cada referencia la re-ejecutaba.
                    Medido: 1 scan de LaboratoryData en la fuente -> 5-7 en esta vista (BLOQUE 116). */
    SELECT d.*,
        /* Componente OBSERVADO = tiene al menos una celda marcada en la tabla que se imprime.
           Antes se usaba Estado_General, que solo mira 9 metales de desgaste + TBN: el encabezado
           contaba 0 mientras la tabla pintaba un Zn en rojo (BLOQUE 118). Va aqui, en la unica
           lectura de la fundacion, para no agregar referencias al CTE (BLOQUE 117). */
        CASE WHEN CONCAT(Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si,Ca,Zn,K,Na,Mg,B,P,V100,TBN,Mo,TAN,Oxidacion,Sulfatacion,Nitracion,Hollin,Diesel,Agua,ISO4,ISO6,ISO14,V40) LIKE '%:C%'
               OR CONCAT(Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si,Ca,Zn,K,Na,Mg,B,P,V100,TBN,Mo,TAN,Oxidacion,Sulfatacion,Nitracion,Hollin,Diesel,Agua,ISO4,ISO6,ISO14,V40) LIKE '%:P%' THEN 1 ELSE 0 END AS CompMarcado,
        CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN 1 WHEN Compartimiento LIKE '%TRACCION%RH' THEN 2 WHEN Compartimiento LIKE '%RUEDA%LH' THEN 3 WHEN Compartimiento LIKE '%RUEDA%RH' THEN 4 WHEN Compartimiento LIKE '%HIDRAUL%' THEN 6 WHEN Compartimiento='MOTOR' THEN 5 ELSE 9 END AS compOrd, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr
    FROM [dbo].[vw_DiagnosticoEquipo] d
    WHERE d.Equipo = me.[Code]
) b
    CROSS APPLY (VALUES
            (N'Fe', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Fe AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Fe),
            (N'PQ', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(PQ AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), PQ),
            (N'Cr', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Cr AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Cr),
            (N'Ni', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Ni AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Ni),
            (N'Cu', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Cu AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Cu),
            (N'Pb', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Pb AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Pb),
            (N'Sn', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Sn AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Sn),
            (N'Al', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Al AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Al),
            (N'Si', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Si AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Si),
            (N'Ca', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Ca AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Ca),
            (N'Zn', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Zn AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Zn),
            (N'K', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(K AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), K),
            (N'Na', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Na AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Na),
            (N'B', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(B AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), B),
            (N'P', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(P AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), P),
            (N'Mg', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Mg AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Mg),
            (N'V100', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(V100 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), V100),
            (N'TBN', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(TBN AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), TBN),
            (N'Mo', ISNULL(REPLACE(REPLACE(CAST(Mo AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Mo),
            (N'TAN', ISNULL(REPLACE(REPLACE(CAST(TAN AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), TAN),
            (N'Oxidacion', ISNULL(REPLACE(REPLACE(CAST(Oxidacion AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Oxidacion),
            (N'Sulfatacion', ISNULL(REPLACE(REPLACE(CAST(Sulfatacion AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Sulfatacion),
            (N'Nitracion', ISNULL(REPLACE(REPLACE(CAST(Nitracion AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Nitracion),
            (N'Hollin', ISNULL(REPLACE(REPLACE(CAST(Hollin AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Hollin),
            (N'Diesel', ISNULL(REPLACE(REPLACE(CAST(Diesel AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Diesel),
            (N'Agua', ISNULL(REPLACE(REPLACE(CAST(Agua AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Agua),
            (N'Refrigerante', ISNULL(REPLACE(REPLACE(CAST(Refrigerante AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Refrigerante),
            (N'ISO>4', ISNULL(REPLACE(REPLACE(CAST(ISO4 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), ISO4),
            (N'ISO>6', ISNULL(REPLACE(REPLACE(CAST(ISO6 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), ISO6),
            (N'ISO>14', ISNULL(REPLACE(REPLACE(CAST(ISO14 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), ISO14),
            (N'V40', ISNULL(REPLACE(REPLACE(CAST(V40 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), V40)
    ) v(Parametro, cell, raw)
    INNER JOIN [dbo].[vw_FormatoParametro] f
        ON f.CompTipo = '(CRUZADO)' AND f.Parametro = v.Parametro
) unpv
    GROUP BY Equipo, Compartimiento
) comp WHERE CompMarcado = 1 GROUP BY Equipo
) ho ON ho.Equipo=g.Equipo
LEFT JOIN (
    SELECT r.Equipo,
        STRING_AGG(CAST(CASE WHEN r.EsInicioGrupo = 1 THEN N'| **' + r.grp + N'** |' + REPLICATE(N' |', h.N) + NCHAR(10) ELSE N'' END + r.rowMD AS nvarchar(max)), NCHAR(10))
            WITHIN GROUP (ORDER BY r.ord) AS bodyMD
    FROM (
    SELECT Equipo, grp, ord, nombre,
        CASE WHEN ROW_NUMBER() OVER (PARTITION BY Equipo, grp ORDER BY ord) = 1 THEN 1 ELSE 0 END AS EsInicioGrupo,
        CAST(N'| ' + nombre + N' | ' + STRING_AGG(cell, N' | ') WITHIN GROUP (ORDER BY compOrd) + N' |' AS nvarchar(max)) AS rowMD
    FROM (   /* Las filas salen del formato CRUZADO (union de las 4 hojas, 31 parametros): esta tabla es
               parametros x COMPONENTES, asi que no puede seguir el formato de un solo componente. */
    SELECT b.Equipo, b.Proyecto, b.Modelo, b.Compartimiento, b.compOrd, b.compAbbr, b.CompMarcado,
           f.Orden AS ord, f.Grupo AS grp, f.Parametro AS nombre,
           v.cell,
           /* El valor CRUDO, antes de sustituir ':C'/':P' por los cuadros de color.
              ⛔ NO filtrar por el emoji: son caracteres SUPLEMENTARIOS (U+1F7E5/U+1F7E8) y el
              LIKE de SQL Server con una collation no-_SC no los trata como un solo caracter,
              asi que el patron matchea de mas. Se intento el 29/09 y 'Observados' devolvio los
              31 parametros en vez de los marcados. La marca se busca en ASCII: ':C' / ':P'.
              Mismo patron que el bloque E4 sobre vw_CondicionMT_MD. */
           v.raw
    /* ⚡ PERF (28/09) — antes esto era:
           FROM (   /* UNICA lectura de la fundacion. Antes se leia 4 veces (base, unpv, obsmetals,
                    obsmet) y los CTE de SQL Server NO se materializan: cada referencia la re-ejecutaba.
                    Medido: 1 scan de LaboratoryData en la fuente -> 5-7 en esta vista (BLOQUE 116). */
    SELECT d.*,
        /* Componente OBSERVADO = tiene al menos una celda marcada en la tabla que se imprime.
           Antes se usaba Estado_General, que solo mira 9 metales de desgaste + TBN: el encabezado
           contaba 0 mientras la tabla pintaba un Zn en rojo (BLOQUE 118). Va aqui, en la unica
           lectura de la fundacion, para no agregar referencias al CTE (BLOQUE 117). */
        CASE WHEN CONCAT(Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si,Ca,Zn,K,Na,Mg,B,P,V100,TBN,Mo,TAN,Oxidacion,Sulfatacion,Nitracion,Hollin,Diesel,Agua,ISO4,ISO6,ISO14,V40) LIKE '%:C%'
               OR CONCAT(Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si,Ca,Zn,K,Na,Mg,B,P,V100,TBN,Mo,TAN,Oxidacion,Sulfatacion,Nitracion,Hollin,Diesel,Agua,ISO4,ISO6,ISO14,V40) LIKE '%:P%' THEN 1 ELSE 0 END AS CompMarcado,
        CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN 1 WHEN Compartimiento LIKE '%TRACCION%RH' THEN 2 WHEN Compartimiento LIKE '%RUEDA%LH' THEN 3 WHEN Compartimiento LIKE '%RUEDA%RH' THEN 4 WHEN Compartimiento LIKE '%HIDRAUL%' THEN 6 WHEN Compartimiento='MOTOR' THEN 5 ELSE 9 END AS compOrd, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr
    FROM [dbo].[vw_DiagnosticoEquipo] d
    WHERE d.Equipo = me.[Code]
) b
           INNER JOIN vw_FormatoParametro f ON f.CompTipo='(CRUZADO)'   <- cartesiano base x 31
           OUTER APPLY (SELECT v.cell FROM (VALUES ...31...) v WHERE v.Parametro=f.Parametro)
       o sea: por cada (fila de base x fila del catalogo) se armaba la tabla de 31 tuplas
       ENTERA y se filtraba DENTRO del apply. 6 componentes x 31 parametros = 186 applies,
       cada uno re-derivando 'base', que cuelga de una cadena de 4 vistas.
       MEDIDO (bloque 145.5): 431 scans de [Oil].[LaboratoryData] y 11 910 696 lecturas
       logicas -> 348 s. El triage, que lee la fundacion UNA vez, hacia 1 scan y 1 365.
       AHORA: se expande base UNA vez a sus 31 filas y DESPUES se une el catalogo. Es el
       unpivot de siempre, y es la misma cura que curo el triage (ley 2). */
    FROM (   /* UNICA lectura de la fundacion. Antes se leia 4 veces (base, unpv, obsmetals,
                    obsmet) y los CTE de SQL Server NO se materializan: cada referencia la re-ejecutaba.
                    Medido: 1 scan de LaboratoryData en la fuente -> 5-7 en esta vista (BLOQUE 116). */
    SELECT d.*,
        /* Componente OBSERVADO = tiene al menos una celda marcada en la tabla que se imprime.
           Antes se usaba Estado_General, que solo mira 9 metales de desgaste + TBN: el encabezado
           contaba 0 mientras la tabla pintaba un Zn en rojo (BLOQUE 118). Va aqui, en la unica
           lectura de la fundacion, para no agregar referencias al CTE (BLOQUE 117). */
        CASE WHEN CONCAT(Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si,Ca,Zn,K,Na,Mg,B,P,V100,TBN,Mo,TAN,Oxidacion,Sulfatacion,Nitracion,Hollin,Diesel,Agua,ISO4,ISO6,ISO14,V40) LIKE '%:C%'
               OR CONCAT(Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si,Ca,Zn,K,Na,Mg,B,P,V100,TBN,Mo,TAN,Oxidacion,Sulfatacion,Nitracion,Hollin,Diesel,Agua,ISO4,ISO6,ISO14,V40) LIKE '%:P%' THEN 1 ELSE 0 END AS CompMarcado,
        CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN 1 WHEN Compartimiento LIKE '%TRACCION%RH' THEN 2 WHEN Compartimiento LIKE '%RUEDA%LH' THEN 3 WHEN Compartimiento LIKE '%RUEDA%RH' THEN 4 WHEN Compartimiento LIKE '%HIDRAUL%' THEN 6 WHEN Compartimiento='MOTOR' THEN 5 ELSE 9 END AS compOrd, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr
    FROM [dbo].[vw_DiagnosticoEquipo] d
    WHERE d.Equipo = me.[Code]
) b
    CROSS APPLY (VALUES
            (N'Fe', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Fe AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Fe),
            (N'PQ', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(PQ AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), PQ),
            (N'Cr', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Cr AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Cr),
            (N'Ni', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Ni AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Ni),
            (N'Cu', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Cu AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Cu),
            (N'Pb', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Pb AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Pb),
            (N'Sn', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Sn AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Sn),
            (N'Al', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Al AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Al),
            (N'Si', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Si AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Si),
            (N'Ca', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Ca AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Ca),
            (N'Zn', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Zn AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Zn),
            (N'K', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(K AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), K),
            (N'Na', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Na AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Na),
            (N'B', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(B AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), B),
            (N'P', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(P AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), P),
            (N'Mg', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Mg AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Mg),
            (N'V100', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(V100 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), V100),
            (N'TBN', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(TBN AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), TBN),
            (N'Mo', ISNULL(REPLACE(REPLACE(CAST(Mo AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Mo),
            (N'TAN', ISNULL(REPLACE(REPLACE(CAST(TAN AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), TAN),
            (N'Oxidacion', ISNULL(REPLACE(REPLACE(CAST(Oxidacion AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Oxidacion),
            (N'Sulfatacion', ISNULL(REPLACE(REPLACE(CAST(Sulfatacion AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Sulfatacion),
            (N'Nitracion', ISNULL(REPLACE(REPLACE(CAST(Nitracion AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Nitracion),
            (N'Hollin', ISNULL(REPLACE(REPLACE(CAST(Hollin AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Hollin),
            (N'Diesel', ISNULL(REPLACE(REPLACE(CAST(Diesel AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Diesel),
            (N'Agua', ISNULL(REPLACE(REPLACE(CAST(Agua AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Agua),
            (N'Refrigerante', ISNULL(REPLACE(REPLACE(CAST(Refrigerante AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Refrigerante),
            (N'ISO>4', ISNULL(REPLACE(REPLACE(CAST(ISO4 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), ISO4),
            (N'ISO>6', ISNULL(REPLACE(REPLACE(CAST(ISO6 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), ISO6),
            (N'ISO>14', ISNULL(REPLACE(REPLACE(CAST(ISO14 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), ISO14),
            (N'V40', ISNULL(REPLACE(REPLACE(CAST(V40 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), V40)
    ) v(Parametro, cell, raw)
    INNER JOIN [dbo].[vw_FormatoParametro] f
        ON f.CompTipo = '(CRUZADO)' AND f.Parametro = v.Parametro
) unpv WHERE CompMarcado = 1 GROUP BY Equipo, grp, ord, nombre
) r JOIN (
    SELECT Equipo, COUNT(DISTINCT Compartimiento) AS N,
        STRING_AGG(compAbbr, N' | ') WITHIN GROUP (ORDER BY compOrd) AS cols
    FROM (   /* 1 fila por equipo+componente, DERIVADA de unpv.
               Antes hdr_all, hdr_obs y g leian 'base' por su cuenta (3 lecturas de una cadena de
               4 vistas). unpv ya trae cada componente 31 veces: agrupar aqui sale gratis. */
    SELECT Equipo, Compartimiento,
           MAX(Proyecto)    AS Proyecto,
           MAX(Modelo)      AS Modelo,
           MAX(compOrd)     AS compOrd,
           MAX(compAbbr)    AS compAbbr,
           MAX(CompMarcado) AS CompMarcado
    FROM (   /* Las filas salen del formato CRUZADO (union de las 4 hojas, 31 parametros): esta tabla es
               parametros x COMPONENTES, asi que no puede seguir el formato de un solo componente. */
    SELECT b.Equipo, b.Proyecto, b.Modelo, b.Compartimiento, b.compOrd, b.compAbbr, b.CompMarcado,
           f.Orden AS ord, f.Grupo AS grp, f.Parametro AS nombre,
           v.cell,
           /* El valor CRUDO, antes de sustituir ':C'/':P' por los cuadros de color.
              ⛔ NO filtrar por el emoji: son caracteres SUPLEMENTARIOS (U+1F7E5/U+1F7E8) y el
              LIKE de SQL Server con una collation no-_SC no los trata como un solo caracter,
              asi que el patron matchea de mas. Se intento el 29/09 y 'Observados' devolvio los
              31 parametros en vez de los marcados. La marca se busca en ASCII: ':C' / ':P'.
              Mismo patron que el bloque E4 sobre vw_CondicionMT_MD. */
           v.raw
    /* ⚡ PERF (28/09) — antes esto era:
           FROM (   /* UNICA lectura de la fundacion. Antes se leia 4 veces (base, unpv, obsmetals,
                    obsmet) y los CTE de SQL Server NO se materializan: cada referencia la re-ejecutaba.
                    Medido: 1 scan de LaboratoryData en la fuente -> 5-7 en esta vista (BLOQUE 116). */
    SELECT d.*,
        /* Componente OBSERVADO = tiene al menos una celda marcada en la tabla que se imprime.
           Antes se usaba Estado_General, que solo mira 9 metales de desgaste + TBN: el encabezado
           contaba 0 mientras la tabla pintaba un Zn en rojo (BLOQUE 118). Va aqui, en la unica
           lectura de la fundacion, para no agregar referencias al CTE (BLOQUE 117). */
        CASE WHEN CONCAT(Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si,Ca,Zn,K,Na,Mg,B,P,V100,TBN,Mo,TAN,Oxidacion,Sulfatacion,Nitracion,Hollin,Diesel,Agua,ISO4,ISO6,ISO14,V40) LIKE '%:C%'
               OR CONCAT(Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si,Ca,Zn,K,Na,Mg,B,P,V100,TBN,Mo,TAN,Oxidacion,Sulfatacion,Nitracion,Hollin,Diesel,Agua,ISO4,ISO6,ISO14,V40) LIKE '%:P%' THEN 1 ELSE 0 END AS CompMarcado,
        CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN 1 WHEN Compartimiento LIKE '%TRACCION%RH' THEN 2 WHEN Compartimiento LIKE '%RUEDA%LH' THEN 3 WHEN Compartimiento LIKE '%RUEDA%RH' THEN 4 WHEN Compartimiento LIKE '%HIDRAUL%' THEN 6 WHEN Compartimiento='MOTOR' THEN 5 ELSE 9 END AS compOrd, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr
    FROM [dbo].[vw_DiagnosticoEquipo] d
    WHERE d.Equipo = me.[Code]
) b
           INNER JOIN vw_FormatoParametro f ON f.CompTipo='(CRUZADO)'   <- cartesiano base x 31
           OUTER APPLY (SELECT v.cell FROM (VALUES ...31...) v WHERE v.Parametro=f.Parametro)
       o sea: por cada (fila de base x fila del catalogo) se armaba la tabla de 31 tuplas
       ENTERA y se filtraba DENTRO del apply. 6 componentes x 31 parametros = 186 applies,
       cada uno re-derivando 'base', que cuelga de una cadena de 4 vistas.
       MEDIDO (bloque 145.5): 431 scans de [Oil].[LaboratoryData] y 11 910 696 lecturas
       logicas -> 348 s. El triage, que lee la fundacion UNA vez, hacia 1 scan y 1 365.
       AHORA: se expande base UNA vez a sus 31 filas y DESPUES se une el catalogo. Es el
       unpivot de siempre, y es la misma cura que curo el triage (ley 2). */
    FROM (   /* UNICA lectura de la fundacion. Antes se leia 4 veces (base, unpv, obsmetals,
                    obsmet) y los CTE de SQL Server NO se materializan: cada referencia la re-ejecutaba.
                    Medido: 1 scan de LaboratoryData en la fuente -> 5-7 en esta vista (BLOQUE 116). */
    SELECT d.*,
        /* Componente OBSERVADO = tiene al menos una celda marcada en la tabla que se imprime.
           Antes se usaba Estado_General, que solo mira 9 metales de desgaste + TBN: el encabezado
           contaba 0 mientras la tabla pintaba un Zn en rojo (BLOQUE 118). Va aqui, en la unica
           lectura de la fundacion, para no agregar referencias al CTE (BLOQUE 117). */
        CASE WHEN CONCAT(Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si,Ca,Zn,K,Na,Mg,B,P,V100,TBN,Mo,TAN,Oxidacion,Sulfatacion,Nitracion,Hollin,Diesel,Agua,ISO4,ISO6,ISO14,V40) LIKE '%:C%'
               OR CONCAT(Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si,Ca,Zn,K,Na,Mg,B,P,V100,TBN,Mo,TAN,Oxidacion,Sulfatacion,Nitracion,Hollin,Diesel,Agua,ISO4,ISO6,ISO14,V40) LIKE '%:P%' THEN 1 ELSE 0 END AS CompMarcado,
        CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN 1 WHEN Compartimiento LIKE '%TRACCION%RH' THEN 2 WHEN Compartimiento LIKE '%RUEDA%LH' THEN 3 WHEN Compartimiento LIKE '%RUEDA%RH' THEN 4 WHEN Compartimiento LIKE '%HIDRAUL%' THEN 6 WHEN Compartimiento='MOTOR' THEN 5 ELSE 9 END AS compOrd, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr
    FROM [dbo].[vw_DiagnosticoEquipo] d
    WHERE d.Equipo = me.[Code]
) b
    CROSS APPLY (VALUES
            (N'Fe', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Fe AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Fe),
            (N'PQ', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(PQ AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), PQ),
            (N'Cr', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Cr AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Cr),
            (N'Ni', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Ni AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Ni),
            (N'Cu', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Cu AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Cu),
            (N'Pb', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Pb AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Pb),
            (N'Sn', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Sn AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Sn),
            (N'Al', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Al AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Al),
            (N'Si', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Si AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Si),
            (N'Ca', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Ca AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Ca),
            (N'Zn', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Zn AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Zn),
            (N'K', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(K AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), K),
            (N'Na', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Na AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Na),
            (N'B', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(B AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), B),
            (N'P', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(P AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), P),
            (N'Mg', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Mg AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Mg),
            (N'V100', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(V100 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), V100),
            (N'TBN', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(TBN AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), TBN),
            (N'Mo', ISNULL(REPLACE(REPLACE(CAST(Mo AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Mo),
            (N'TAN', ISNULL(REPLACE(REPLACE(CAST(TAN AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), TAN),
            (N'Oxidacion', ISNULL(REPLACE(REPLACE(CAST(Oxidacion AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Oxidacion),
            (N'Sulfatacion', ISNULL(REPLACE(REPLACE(CAST(Sulfatacion AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Sulfatacion),
            (N'Nitracion', ISNULL(REPLACE(REPLACE(CAST(Nitracion AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Nitracion),
            (N'Hollin', ISNULL(REPLACE(REPLACE(CAST(Hollin AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Hollin),
            (N'Diesel', ISNULL(REPLACE(REPLACE(CAST(Diesel AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Diesel),
            (N'Agua', ISNULL(REPLACE(REPLACE(CAST(Agua AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Agua),
            (N'Refrigerante', ISNULL(REPLACE(REPLACE(CAST(Refrigerante AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Refrigerante),
            (N'ISO>4', ISNULL(REPLACE(REPLACE(CAST(ISO4 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), ISO4),
            (N'ISO>6', ISNULL(REPLACE(REPLACE(CAST(ISO6 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), ISO6),
            (N'ISO>14', ISNULL(REPLACE(REPLACE(CAST(ISO14 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), ISO14),
            (N'V40', ISNULL(REPLACE(REPLACE(CAST(V40 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), V40)
    ) v(Parametro, cell, raw)
    INNER JOIN [dbo].[vw_FormatoParametro] f
        ON f.CompTipo = '(CRUZADO)' AND f.Parametro = v.Parametro
) unpv
    GROUP BY Equipo, Compartimiento
) comp WHERE CompMarcado = 1 GROUP BY Equipo
) h ON h.Equipo=r.Equipo GROUP BY r.Equipo
) bo ON bo.Equipo=g.Equipo
LEFT JOIN (
    SELECT Equipo,
           STRING_AGG(compAbbr + N': ' + metals, N' · ') WITHIN GROUP (ORDER BY compOrd) AS Observados
    FROM (
        SELECT Equipo, Compartimiento, MAX(compOrd) AS compOrd, MAX(compAbbr) AS compAbbr,
               STRING_AGG(CONVERT(nvarchar(max), nombre), N', ') WITHIN GROUP (ORDER BY ord) AS metals
        FROM (   /* UNA sola pasada para las dos cosas que se hacian por separado:
              la lista de metales marcados por componente (obsmetals) y los metales de MT que
              enganchan recomendaciones (obsmet). Baja una referencia mas a unpv. */
    SELECT Equipo, Compartimiento, compOrd, compAbbr, nombre, ord
    FROM (   /* Las filas salen del formato CRUZADO (union de las 4 hojas, 31 parametros): esta tabla es
               parametros x COMPONENTES, asi que no puede seguir el formato de un solo componente. */
    SELECT b.Equipo, b.Proyecto, b.Modelo, b.Compartimiento, b.compOrd, b.compAbbr, b.CompMarcado,
           f.Orden AS ord, f.Grupo AS grp, f.Parametro AS nombre,
           v.cell,
           /* El valor CRUDO, antes de sustituir ':C'/':P' por los cuadros de color.
              ⛔ NO filtrar por el emoji: son caracteres SUPLEMENTARIOS (U+1F7E5/U+1F7E8) y el
              LIKE de SQL Server con una collation no-_SC no los trata como un solo caracter,
              asi que el patron matchea de mas. Se intento el 29/09 y 'Observados' devolvio los
              31 parametros en vez de los marcados. La marca se busca en ASCII: ':C' / ':P'.
              Mismo patron que el bloque E4 sobre vw_CondicionMT_MD. */
           v.raw
    /* ⚡ PERF (28/09) — antes esto era:
           FROM (   /* UNICA lectura de la fundacion. Antes se leia 4 veces (base, unpv, obsmetals,
                    obsmet) y los CTE de SQL Server NO se materializan: cada referencia la re-ejecutaba.
                    Medido: 1 scan de LaboratoryData en la fuente -> 5-7 en esta vista (BLOQUE 116). */
    SELECT d.*,
        /* Componente OBSERVADO = tiene al menos una celda marcada en la tabla que se imprime.
           Antes se usaba Estado_General, que solo mira 9 metales de desgaste + TBN: el encabezado
           contaba 0 mientras la tabla pintaba un Zn en rojo (BLOQUE 118). Va aqui, en la unica
           lectura de la fundacion, para no agregar referencias al CTE (BLOQUE 117). */
        CASE WHEN CONCAT(Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si,Ca,Zn,K,Na,Mg,B,P,V100,TBN,Mo,TAN,Oxidacion,Sulfatacion,Nitracion,Hollin,Diesel,Agua,ISO4,ISO6,ISO14,V40) LIKE '%:C%'
               OR CONCAT(Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si,Ca,Zn,K,Na,Mg,B,P,V100,TBN,Mo,TAN,Oxidacion,Sulfatacion,Nitracion,Hollin,Diesel,Agua,ISO4,ISO6,ISO14,V40) LIKE '%:P%' THEN 1 ELSE 0 END AS CompMarcado,
        CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN 1 WHEN Compartimiento LIKE '%TRACCION%RH' THEN 2 WHEN Compartimiento LIKE '%RUEDA%LH' THEN 3 WHEN Compartimiento LIKE '%RUEDA%RH' THEN 4 WHEN Compartimiento LIKE '%HIDRAUL%' THEN 6 WHEN Compartimiento='MOTOR' THEN 5 ELSE 9 END AS compOrd, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr
    FROM [dbo].[vw_DiagnosticoEquipo] d
    WHERE d.Equipo = me.[Code]
) b
           INNER JOIN vw_FormatoParametro f ON f.CompTipo='(CRUZADO)'   <- cartesiano base x 31
           OUTER APPLY (SELECT v.cell FROM (VALUES ...31...) v WHERE v.Parametro=f.Parametro)
       o sea: por cada (fila de base x fila del catalogo) se armaba la tabla de 31 tuplas
       ENTERA y se filtraba DENTRO del apply. 6 componentes x 31 parametros = 186 applies,
       cada uno re-derivando 'base', que cuelga de una cadena de 4 vistas.
       MEDIDO (bloque 145.5): 431 scans de [Oil].[LaboratoryData] y 11 910 696 lecturas
       logicas -> 348 s. El triage, que lee la fundacion UNA vez, hacia 1 scan y 1 365.
       AHORA: se expande base UNA vez a sus 31 filas y DESPUES se une el catalogo. Es el
       unpivot de siempre, y es la misma cura que curo el triage (ley 2). */
    FROM (   /* UNICA lectura de la fundacion. Antes se leia 4 veces (base, unpv, obsmetals,
                    obsmet) y los CTE de SQL Server NO se materializan: cada referencia la re-ejecutaba.
                    Medido: 1 scan de LaboratoryData en la fuente -> 5-7 en esta vista (BLOQUE 116). */
    SELECT d.*,
        /* Componente OBSERVADO = tiene al menos una celda marcada en la tabla que se imprime.
           Antes se usaba Estado_General, que solo mira 9 metales de desgaste + TBN: el encabezado
           contaba 0 mientras la tabla pintaba un Zn en rojo (BLOQUE 118). Va aqui, en la unica
           lectura de la fundacion, para no agregar referencias al CTE (BLOQUE 117). */
        CASE WHEN CONCAT(Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si,Ca,Zn,K,Na,Mg,B,P,V100,TBN,Mo,TAN,Oxidacion,Sulfatacion,Nitracion,Hollin,Diesel,Agua,ISO4,ISO6,ISO14,V40) LIKE '%:C%'
               OR CONCAT(Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si,Ca,Zn,K,Na,Mg,B,P,V100,TBN,Mo,TAN,Oxidacion,Sulfatacion,Nitracion,Hollin,Diesel,Agua,ISO4,ISO6,ISO14,V40) LIKE '%:P%' THEN 1 ELSE 0 END AS CompMarcado,
        CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN 1 WHEN Compartimiento LIKE '%TRACCION%RH' THEN 2 WHEN Compartimiento LIKE '%RUEDA%LH' THEN 3 WHEN Compartimiento LIKE '%RUEDA%RH' THEN 4 WHEN Compartimiento LIKE '%HIDRAUL%' THEN 6 WHEN Compartimiento='MOTOR' THEN 5 ELSE 9 END AS compOrd, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr
    FROM [dbo].[vw_DiagnosticoEquipo] d
    WHERE d.Equipo = me.[Code]
) b
    CROSS APPLY (VALUES
            (N'Fe', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Fe AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Fe),
            (N'PQ', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(PQ AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), PQ),
            (N'Cr', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Cr AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Cr),
            (N'Ni', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Ni AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Ni),
            (N'Cu', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Cu AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Cu),
            (N'Pb', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Pb AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Pb),
            (N'Sn', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Sn AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Sn),
            (N'Al', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Al AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Al),
            (N'Si', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Si AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Si),
            (N'Ca', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Ca AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Ca),
            (N'Zn', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Zn AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Zn),
            (N'K', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(K AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), K),
            (N'Na', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Na AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Na),
            (N'B', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(B AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), B),
            (N'P', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(P AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), P),
            (N'Mg', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Mg AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Mg),
            (N'V100', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(V100 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), V100),
            (N'TBN', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(TBN AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), TBN),
            (N'Mo', ISNULL(REPLACE(REPLACE(CAST(Mo AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Mo),
            (N'TAN', ISNULL(REPLACE(REPLACE(CAST(TAN AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), TAN),
            (N'Oxidacion', ISNULL(REPLACE(REPLACE(CAST(Oxidacion AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Oxidacion),
            (N'Sulfatacion', ISNULL(REPLACE(REPLACE(CAST(Sulfatacion AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Sulfatacion),
            (N'Nitracion', ISNULL(REPLACE(REPLACE(CAST(Nitracion AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Nitracion),
            (N'Hollin', ISNULL(REPLACE(REPLACE(CAST(Hollin AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Hollin),
            (N'Diesel', ISNULL(REPLACE(REPLACE(CAST(Diesel AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Diesel),
            (N'Agua', ISNULL(REPLACE(REPLACE(CAST(Agua AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Agua),
            (N'Refrigerante', ISNULL(REPLACE(REPLACE(CAST(Refrigerante AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Refrigerante),
            (N'ISO>4', ISNULL(REPLACE(REPLACE(CAST(ISO4 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), ISO4),
            (N'ISO>6', ISNULL(REPLACE(REPLACE(CAST(ISO6 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), ISO6),
            (N'ISO>14', ISNULL(REPLACE(REPLACE(CAST(ISO14 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), ISO14),
            (N'V40', ISNULL(REPLACE(REPLACE(CAST(V40 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), V40)
    ) v(Parametro, cell, raw)
    INNER JOIN [dbo].[vw_FormatoParametro] f
        ON f.CompTipo = '(CRUZADO)' AND f.Parametro = v.Parametro
) unpv
    WHERE raw LIKE '%:C%' OR raw LIKE '%:P%'
) obs GROUP BY Equipo, Compartimiento
    ) z
    GROUP BY Equipo
) oa ON oa.Equipo=g.Equipo
LEFT JOIN (
    SELECT Equipo,
        CAST(N'**🔧 Recomendaciones Técnicas**' + NCHAR(10)
           + STRING_AGG(CONVERT(nvarchar(max), N'- **' + label + N':** ' + indicio), NCHAR(10)) WITHIN GROUP (ORDER BY ord)
           + NCHAR(10) + NCHAR(10) + N'Acortar la frecuencia de monitoreo y programar dializado/cambio de aceite en el próximo PM. Retirar los 8 tapones magnéticos para inspección y limpieza en busca de particulado anormal. Para mayor información y detalle, contactar a confiabilidad.operaciones@kmmp.com.pe' AS nvarchar(max)) AS Recomendaciones
    FROM (
    SELECT DISTINCT om.Equipo, r.ord, r.label, r.indicio
    FROM (   /* Metales marcados de MT: enganchan las recomendaciones. Sale de 'obs'. */
    SELECT DISTINCT Equipo, nombre AS metal
    FROM (   /* UNA sola pasada para las dos cosas que se hacian por separado:
              la lista de metales marcados por componente (obsmetals) y los metales de MT que
              enganchan recomendaciones (obsmet). Baja una referencia mas a unpv. */
    SELECT Equipo, Compartimiento, compOrd, compAbbr, nombre, ord
    FROM (   /* Las filas salen del formato CRUZADO (union de las 4 hojas, 31 parametros): esta tabla es
               parametros x COMPONENTES, asi que no puede seguir el formato de un solo componente. */
    SELECT b.Equipo, b.Proyecto, b.Modelo, b.Compartimiento, b.compOrd, b.compAbbr, b.CompMarcado,
           f.Orden AS ord, f.Grupo AS grp, f.Parametro AS nombre,
           v.cell,
           /* El valor CRUDO, antes de sustituir ':C'/':P' por los cuadros de color.
              ⛔ NO filtrar por el emoji: son caracteres SUPLEMENTARIOS (U+1F7E5/U+1F7E8) y el
              LIKE de SQL Server con una collation no-_SC no los trata como un solo caracter,
              asi que el patron matchea de mas. Se intento el 29/09 y 'Observados' devolvio los
              31 parametros en vez de los marcados. La marca se busca en ASCII: ':C' / ':P'.
              Mismo patron que el bloque E4 sobre vw_CondicionMT_MD. */
           v.raw
    /* ⚡ PERF (28/09) — antes esto era:
           FROM (   /* UNICA lectura de la fundacion. Antes se leia 4 veces (base, unpv, obsmetals,
                    obsmet) y los CTE de SQL Server NO se materializan: cada referencia la re-ejecutaba.
                    Medido: 1 scan de LaboratoryData en la fuente -> 5-7 en esta vista (BLOQUE 116). */
    SELECT d.*,
        /* Componente OBSERVADO = tiene al menos una celda marcada en la tabla que se imprime.
           Antes se usaba Estado_General, que solo mira 9 metales de desgaste + TBN: el encabezado
           contaba 0 mientras la tabla pintaba un Zn en rojo (BLOQUE 118). Va aqui, en la unica
           lectura de la fundacion, para no agregar referencias al CTE (BLOQUE 117). */
        CASE WHEN CONCAT(Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si,Ca,Zn,K,Na,Mg,B,P,V100,TBN,Mo,TAN,Oxidacion,Sulfatacion,Nitracion,Hollin,Diesel,Agua,ISO4,ISO6,ISO14,V40) LIKE '%:C%'
               OR CONCAT(Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si,Ca,Zn,K,Na,Mg,B,P,V100,TBN,Mo,TAN,Oxidacion,Sulfatacion,Nitracion,Hollin,Diesel,Agua,ISO4,ISO6,ISO14,V40) LIKE '%:P%' THEN 1 ELSE 0 END AS CompMarcado,
        CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN 1 WHEN Compartimiento LIKE '%TRACCION%RH' THEN 2 WHEN Compartimiento LIKE '%RUEDA%LH' THEN 3 WHEN Compartimiento LIKE '%RUEDA%RH' THEN 4 WHEN Compartimiento LIKE '%HIDRAUL%' THEN 6 WHEN Compartimiento='MOTOR' THEN 5 ELSE 9 END AS compOrd, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr
    FROM [dbo].[vw_DiagnosticoEquipo] d
    WHERE d.Equipo = me.[Code]
) b
           INNER JOIN vw_FormatoParametro f ON f.CompTipo='(CRUZADO)'   <- cartesiano base x 31
           OUTER APPLY (SELECT v.cell FROM (VALUES ...31...) v WHERE v.Parametro=f.Parametro)
       o sea: por cada (fila de base x fila del catalogo) se armaba la tabla de 31 tuplas
       ENTERA y se filtraba DENTRO del apply. 6 componentes x 31 parametros = 186 applies,
       cada uno re-derivando 'base', que cuelga de una cadena de 4 vistas.
       MEDIDO (bloque 145.5): 431 scans de [Oil].[LaboratoryData] y 11 910 696 lecturas
       logicas -> 348 s. El triage, que lee la fundacion UNA vez, hacia 1 scan y 1 365.
       AHORA: se expande base UNA vez a sus 31 filas y DESPUES se une el catalogo. Es el
       unpivot de siempre, y es la misma cura que curo el triage (ley 2). */
    FROM (   /* UNICA lectura de la fundacion. Antes se leia 4 veces (base, unpv, obsmetals,
                    obsmet) y los CTE de SQL Server NO se materializan: cada referencia la re-ejecutaba.
                    Medido: 1 scan de LaboratoryData en la fuente -> 5-7 en esta vista (BLOQUE 116). */
    SELECT d.*,
        /* Componente OBSERVADO = tiene al menos una celda marcada en la tabla que se imprime.
           Antes se usaba Estado_General, que solo mira 9 metales de desgaste + TBN: el encabezado
           contaba 0 mientras la tabla pintaba un Zn en rojo (BLOQUE 118). Va aqui, en la unica
           lectura de la fundacion, para no agregar referencias al CTE (BLOQUE 117). */
        CASE WHEN CONCAT(Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si,Ca,Zn,K,Na,Mg,B,P,V100,TBN,Mo,TAN,Oxidacion,Sulfatacion,Nitracion,Hollin,Diesel,Agua,ISO4,ISO6,ISO14,V40) LIKE '%:C%'
               OR CONCAT(Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si,Ca,Zn,K,Na,Mg,B,P,V100,TBN,Mo,TAN,Oxidacion,Sulfatacion,Nitracion,Hollin,Diesel,Agua,ISO4,ISO6,ISO14,V40) LIKE '%:P%' THEN 1 ELSE 0 END AS CompMarcado,
        CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN 1 WHEN Compartimiento LIKE '%TRACCION%RH' THEN 2 WHEN Compartimiento LIKE '%RUEDA%LH' THEN 3 WHEN Compartimiento LIKE '%RUEDA%RH' THEN 4 WHEN Compartimiento LIKE '%HIDRAUL%' THEN 6 WHEN Compartimiento='MOTOR' THEN 5 ELSE 9 END AS compOrd, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr
    FROM [dbo].[vw_DiagnosticoEquipo] d
    WHERE d.Equipo = me.[Code]
) b
    CROSS APPLY (VALUES
            (N'Fe', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Fe AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Fe),
            (N'PQ', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(PQ AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), PQ),
            (N'Cr', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Cr AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Cr),
            (N'Ni', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Ni AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Ni),
            (N'Cu', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Cu AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Cu),
            (N'Pb', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Pb AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Pb),
            (N'Sn', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Sn AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Sn),
            (N'Al', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Al AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Al),
            (N'Si', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Si AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Si),
            (N'Ca', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Ca AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Ca),
            (N'Zn', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Zn AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Zn),
            (N'K', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(K AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), K),
            (N'Na', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Na AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Na),
            (N'B', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(B AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), B),
            (N'P', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(P AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), P),
            (N'Mg', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Mg AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), Mg),
            (N'V100', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(V100 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), V100),
            (N'TBN', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(TBN AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), TBN),
            (N'Mo', ISNULL(REPLACE(REPLACE(CAST(Mo AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Mo),
            (N'TAN', ISNULL(REPLACE(REPLACE(CAST(TAN AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), TAN),
            (N'Oxidacion', ISNULL(REPLACE(REPLACE(CAST(Oxidacion AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Oxidacion),
            (N'Sulfatacion', ISNULL(REPLACE(REPLACE(CAST(Sulfatacion AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Sulfatacion),
            (N'Nitracion', ISNULL(REPLACE(REPLACE(CAST(Nitracion AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Nitracion),
            (N'Hollin', ISNULL(REPLACE(REPLACE(CAST(Hollin AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Hollin),
            (N'Diesel', ISNULL(REPLACE(REPLACE(CAST(Diesel AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Diesel),
            (N'Agua', ISNULL(REPLACE(REPLACE(CAST(Agua AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Agua),
            (N'Refrigerante', ISNULL(REPLACE(REPLACE(CAST(Refrigerante AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), Refrigerante),
            (N'ISO>4', ISNULL(REPLACE(REPLACE(CAST(ISO4 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), ISO4),
            (N'ISO>6', ISNULL(REPLACE(REPLACE(CAST(ISO6 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), ISO6),
            (N'ISO>14', ISNULL(REPLACE(REPLACE(CAST(ISO14 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), ISO14),
            (N'V40', ISNULL(REPLACE(REPLACE(CAST(V40 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'—'), V40)
    ) v(Parametro, cell, raw)
    INNER JOIN [dbo].[vw_FormatoParametro] f
        ON f.CompTipo = '(CRUZADO)' AND f.Parametro = v.Parametro
) unpv
    WHERE raw LIKE '%:C%' OR raw LIKE '%:P%'
) obs WHERE Compartimiento LIKE '%TRACCION%'
) om JOIN [dbo].[vw_Recomendaciones] r ON r.metal = om.metal
) recos GROUP BY Equipo
) rb ON rb.Equipo=g.Equipo
) x;
GO


/* ==== vw_Recomendaciones (diccionario de indicios, para el bloque determinístico) ==== */
CREATE OR ALTER VIEW [dbo].[vw_Recomendaciones] AS
/* Diccionario de indicios (verbatim de legado/02-copilot-multiagente/knowledge/Recomendaciones_MT.docx). metal -> unidad+indicio.
   Fe/PQ comparten unidad; Pb/Sn comparten. Extensible: agregar filas por (CompTipo,)metal. */
SELECT metal, ord, label, indicio
FROM (VALUES
    (N'Fe', 1, N'Hierro (Fe) y PQ', N'Alto Hierro y/o PQ entre muestras de aceite puede indicar un problema en los engranajes o cojinetes. De continuar elevada la tendencia, solicitar inspección del piñón solar.'),
    (N'PQ', 1, N'Hierro (Fe) y PQ', N'Alto Hierro y/o PQ entre muestras de aceite puede indicar un problema en los engranajes o cojinetes. De continuar elevada la tendencia, solicitar inspección del piñón solar.'),
    (N'Cr', 2, N'Cromo (Cr)', N'Alto Cromo entre muestras de aceite puede indicar un problema en los rodillos y pistas de rodamientos.'),
    (N'Ni', 3, N'Níquel (Ni)', N'Alto Níquel entre muestras de aceite puede indicar un problema en los engranajes. De continuar elevada la tendencia, solicitar inspección del piñón solar.'),
    (N'Cu', 4, N'Cobre (Cu)', N'Alto Cobre entre muestras de aceite puede indicar un desgaste en las arandelas de empuje (interna y/o externa) o en el cojinete. Revise la arandela de empuje si encuentra valores altos de Cu/Pb/Sn en conjunto; si encuentra daños o desgaste excesivo, reemplácela de ser necesario.'),
    (N'Pb', 5, N'Plomo (Pb) y Estaño (Sn)', N'Alto Plomo acompañado de alto Cu y Sn puede indicar un desgaste en las arandelas de empuje (interna y/o externa). Revise la arandela de empuje; si encuentra daños o desgaste excesivo, reemplácela de ser necesario.'),
    (N'Sn', 5, N'Plomo (Pb) y Estaño (Sn)', N'Alto Plomo acompañado de alto Cu y Sn puede indicar un desgaste en las arandelas de empuje (interna y/o externa). Revise la arandela de empuje; si encuentra daños o desgaste excesivo, reemplácela de ser necesario.'),
    (N'Si', 6, N'Silicio (Si)', N'Alto Silicio entre muestras de aceite probablemente esté asociado a ingreso de contaminación a la caja de engranajes. Revise la tendencia de Al: si ambas suben en paralelo indicaría presencia de tierra/polvo abrasivo, con correlación en el incremento de Fe/PQ.'),
    (N'Ca', 7, N'Calcio (Ca)', N'El calcio no es un elemento común en los componentes de la caja de engranajes ni en el aceite. Si el calcio aumenta rápidamente, se ha producido contaminación, generalmente por otro aceite o grasa. En ese caso, detenga el equipo y solicite el cambio de aceite; filtrar el aceite no ayudará a mejorar la condición.'),
    (N'Zn', 8, N'Zinc (Zn)', N'Alto Zinc puede indicar una de dos situaciones: contaminación del aceite de la caja de engranajes por una sustancia extraña, o un desgaste excesivo de los componentes mecánicos. Si otros elementos como el Fósforo o el Calcio crecen junto con el Zinc, se ha producido contaminación por grasa u otro aceite: detenga el equipo y cambie el aceite de la caja de engranajes; filtrar el aceite no ayudará a mejorar la condición. Si solo el Zn está elevado, puede indicar desgaste excesivo de componentes mecánicos: revise la tendencia de Fe/PQ/Cr y, de ser necesario, programe la inspección del piñón solar.'),
    (N'P', 9, N'Fósforo (P)', N'El fósforo no es un elemento común en los componentes de la caja de engranajes; está asociado al aditivo EP usado en los aceites ISO 680. Si la concentración de fósforo decae por debajo de 240 ppm, se debe realizar el cambio de aceite; filtrar el aceite no ayudará a mejorar la condición.'),
    (N'V100', 10, N'Viscosidad V100', N'Baja viscosidad con tendencia decreciente, acompañada de un sobrenivel de aceite, indicaría un posible pase interno de aceite hidráulico a la caja de engranajes: detenga el equipo y solicite el cambio de aceite. Baja viscosidad constante entre muestras indicaría una posible carga con aceite incorrecto: detenga el equipo y solicite el cambio de aceite. En ambos casos, filtrar el aceite no ayudará a mejorar la condición.')
) v(metal, ord, label, indicio);
GO


/* ==== vw_UltimoAnalisisMD (último análisis de 1 componente) ==== */
CREATE OR ALTER VIEW [dbo].[vw_UltimoAnalisisMD] AS
/* 30/09 -- FILTRO ABAJO (mismo patron que curo /condicionmt: 146 s -> 1,4 s, y /diagcompleto).
   La logica va en CROSS APPLY sobre [Mine].[MiningEquipment] y CADA lectura pesada lleva el filtro
   (Equipo = me.[Code]), asi que ninguna rama calcula mas que ese camion. Los CTE van desplegados:
   un APPLY no admite WITH y SQL Server ya los trata como macros. Misma logica y salida. Respaldo: respaldo/DDL_vistas_2026-09-30_antes_filtro_abajo.sql */
SELECT me.[Code] AS Equipo, x.[Proyecto], x.[Modelo], x.[Compartimiento], x.[compAbbr], x.[Observados], x.[Recomendaciones], x.[MD]
FROM [Mine].[MiningEquipment] me
CROSS APPLY (
SELECT u.Equipo, u.Proyecto, u.Modelo, u.Compartimiento, u.compAbbr,
    ISNULL(u.compAbbr + N': ' + oaz.metals, u.compAbbr + N': (sin observados)') AS Observados,
    /* Tres casos, no dos: negar hallazgos debajo de una tabla con marcas rojas parece un bug. */
    ISNULL(rc.Recomendaciones, N'**🔧 Recomendaciones Técnicas**' + NCHAR(10)
        + CASE WHEN u.Compartimiento LIKE '%TRACCION%'
               THEN N'Sin parámetros de Motor de Tracción fuera de límite — sin recomendaciones aplicables por ahora.'
               ELSE N'Las recomendaciones técnicas hoy solo están definidas para Motor de Tracción. Lo que esté fuera de límite en este componente aparece marcado en la tabla.'
          END) AS Recomendaciones,
    CAST(
      /* Sin componente registrado no hay nada que evaluar, pero hay que DECIRLO: si se deja que compAbbr
         NULL anule la concatenacion, el flujo responde 'no encontre datos' y suena a que el equipo no
         tiene muestras. La muestra existe; lo que falta es el componente. (66 filas, BLOQUE 110.) */
      CASE WHEN u.Compartimiento IS NULL THEN
           N'**Último análisis — ' + u.Equipo + N'**' + NCHAR(10) + NCHAR(10)
         + N'_Esta muestra no tiene **componente** registrado en la base, así que no se puede evaluar._'
      ELSE
        N'**Último análisis — ' + u.Equipo + N' · ' + u.compAbbr + N'**' + NCHAR(10)
      + N'*Mod. ' + ISNULL(u.Modelo,N'—') + N' · Lubric. ' + ISNULL(u.Grado,N'—') + N' · SMR ' + ISNULL(CONVERT(varchar(20),CAST(u.Horometro AS decimal(18,0))),N'—')
      + N' · Hor.Comp. ' + ISNULL(CONVERT(varchar(20),CAST(u.HorasComponente AS decimal(18,0))),N'—')
      + N' · T. muestra ' + ISNULL(u.CM,N'—') + N' · ' + ISNULL(FORMAT(u.FechaMuestreo,'dd-MMM-yy'),N'—') + N'*' + NCHAR(10) + NCHAR(10)
      + N'| Par. | LP | LC | Valor |' + NCHAR(10) + N'|---|---|---|---|' + NCHAR(10)
      + ISNULL(tb.b, N'')
      END
    AS nvarchar(max)) AS MD
FROM (
    SELECT *,
        CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH'
             WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH'
             WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr
    FROM (SELECT * FROM [dbo].[vw_UltimoAnalisisAceite] WHERE Equipo = me.[Code]) vw_UltimoAnalisisAceite
) u
LEFT JOIN (
    SELECT o.Equipo, o.Compartimiento,
        CAST(N'**🔧 Recomendaciones Técnicas**' + NCHAR(10)
           + STRING_AGG(CONVERT(nvarchar(max), N'- **' + r.label + N':** ' + r.indicio), NCHAR(10)) WITHIN GROUP (ORDER BY r.ord)
           + NCHAR(10) + NCHAR(10) + N'Acortar la frecuencia de monitoreo y programar dializado/cambio de aceite en el próximo PM. Retirar los 8 tapones magnéticos para inspección y limpieza en busca de particulado anormal. Para mayor información y detalle, contactar a confiabilidad.operaciones@kmmp.com.pe'
        AS nvarchar(max)) AS Recomendaciones
    FROM (SELECT DISTINCT Equipo, Compartimiento, metal FROM (
    SELECT Equipo, Compartimiento, mm.metal
    FROM (SELECT * FROM [dbo].[vw_UltimoAnalisisAceite] WHERE Equipo = me.[Code]) vw_UltimoAnalisisAceite
    CROSS APPLY (VALUES (N'Fe',Fe_ppm,Fe_LP,Fe_LC),(N'PQ',Indice_PQ,PQ_LP,PQ_LC),(N'Cr',Cr_ppm,Cr_LP,Cr_LC),(N'Ni',Ni_ppm,Ni_LP,Ni_LC),(N'Cu',Cu_ppm,Cu_LP,Cu_LC),(N'Pb',Pb_ppm,Pb_LP,Pb_LC),(N'Sn',Sn_ppm,Sn_LP,Sn_LC),(N'Al',Al_ppm,Al_LP,Al_LC),(N'Si',Si_ppm,Si_LP,Si_LC),(N'Ca',Ca_ppm,Ca_LP,Ca_LC),(N'Zn',Zn_ppm,Zn_LP,Zn_LC),(N'K',K_ppm,K_LP,K_LC),(N'Na',Na_ppm,Na_LP,Na_LC),(N'Mg',Mg_ppm,Mg_LP,Mg_LC)) mm(metal, ppm, lp, lc)
    WHERE (ppm > ISNULL(lc,9999) OR ppm > ISNULL(lp,9999)) AND Compartimiento LIKE '%TRACCION%'
) om) o
    JOIN [dbo].[vw_Recomendaciones] r ON r.metal = o.metal
    GROUP BY o.Equipo, o.Compartimiento
) rc  ON rc.Equipo=u.Equipo AND rc.Compartimiento=u.Compartimiento
LEFT JOIN (
    SELECT Equipo, Compartimiento, STRING_AGG(metal, N', ') AS metals
    FROM (SELECT Equipo, Compartimiento, mm.metal
          FROM (SELECT * FROM [dbo].[vw_UltimoAnalisisAceite] WHERE Equipo = me.[Code]) vw_UltimoAnalisisAceite
          CROSS APPLY (VALUES (N'Fe',Fe_ppm,Fe_LP,Fe_LC),(N'PQ',Indice_PQ,PQ_LP,PQ_LC),(N'Cr',Cr_ppm,Cr_LP,Cr_LC),(N'Ni',Ni_ppm,Ni_LP,Ni_LC),(N'Cu',Cu_ppm,Cu_LP,Cu_LC),(N'Pb',Pb_ppm,Pb_LP,Pb_LC),(N'Sn',Sn_ppm,Sn_LP,Sn_LC),(N'Al',Al_ppm,Al_LP,Al_LC),(N'Si',Si_ppm,Si_LP,Si_LC),(N'Ca',Ca_ppm,Ca_LP,Ca_LC),(N'Zn',Zn_ppm,Zn_LP,Zn_LC),(N'K',K_ppm,K_LP,K_LC),(N'Na',Na_ppm,Na_LP,Na_LC),(N'Mg',Mg_ppm,Mg_LP,Mg_LC)) mm(metal, ppm, lp, lc)
          WHERE ppm > ISNULL(lc,9999) OR ppm > ISNULL(lp,9999)) z
    GROUP BY Equipo, Compartimiento
) oaz ON oaz.Equipo=u.Equipo AND oaz.Compartimiento=u.Compartimiento
LEFT JOIN (
    SELECT Equipo, Compartimiento,
           STRING_AGG(rowMD, NCHAR(10)) WITHIN GROUP (ORDER BY Orden) AS b
    FROM (   /* La tabla la genera el FORMATO (vw_FormatoParametro), no una lista hardcodeada: el
                orden, los grupos y que parametros aparecen dependen del componente. */
    SELECT a.Equipo, a.Compartimiento, f.Orden,
        CASE WHEN ROW_NUMBER() OVER (PARTITION BY a.Equipo, a.Compartimiento, f.Grupo ORDER BY f.Orden) = 1
             THEN N'| **' + f.Grupo + N'** | | | |' + NCHAR(10) ELSE N'' END
      + N'| ' + f.Parametro + N' | '
      + ISNULL(CONVERT(varchar(20),CAST(p.LP AS decimal(18,1))), N'—') + N' | '
      + ISNULL(CONVERT(varchar(20),CAST(p.LC AS decimal(18,1))), N'—') + N' | '
      + CASE WHEN p.Valor IS NULL THEN N'—'
             /* Inv=1 (aditivos y TBN): la alerta es por DEBAJO, el aditivo se agota */
             WHEN f.Inv = 1 THEN CONVERT(varchar(20),CAST(p.Valor AS decimal(18,1)))
                  + CASE WHEN p.LC IS NOT NULL AND p.Valor > 0 AND p.Valor < p.LC THEN N' 🟥'
                         WHEN p.LP IS NOT NULL AND p.Valor > 0 AND p.Valor < p.LP THEN N' 🟨'
                         ELSE N'' END
             ELSE CONVERT(varchar(20),CAST(p.Valor AS decimal(18,1)))
                  + CASE WHEN p.Valor > ISNULL(p.LC, 9999) THEN N' 🟥'
                         WHEN p.Valor > ISNULL(p.LP, 9999) THEN N' 🟨'
                         ELSE N'' END
        END
      + N' |' AS rowMD
    FROM (SELECT * FROM [dbo].[vw_UltimoAnalisisAceite] WHERE Equipo = me.[Code]) a
    INNER JOIN [dbo].[vw_FormatoParametro] f ON f.CompTipo = a.CompTipo
    OUTER APPLY (
        SELECT v.Valor, v.LP, v.LC
        FROM (VALUES
            (N'Fe',  a.Fe_ppm,    a.Fe_LP,  a.Fe_LC),
            (N'PQ',  a.Indice_PQ, a.PQ_LP,  a.PQ_LC),
            (N'Cr',  a.Cr_ppm,    a.Cr_LP,  a.Cr_LC),
            (N'Ni',  a.Ni_ppm,    a.Ni_LP,  a.Ni_LC),
            (N'Cu',  a.Cu_ppm,    a.Cu_LP,  a.Cu_LC),
            (N'Pb',  a.Pb_ppm,    a.Pb_LP,  a.Pb_LC),
            (N'Sn',  a.Sn_ppm,    a.Sn_LP,  a.Sn_LC),
            (N'Al',  a.Al_ppm,    a.Al_LP,  a.Al_LC),
            (N'Si',  a.Si_ppm,    a.Si_LP,  a.Si_LC),
            (N'Ca',  a.Ca_ppm,    a.Ca_LP,  a.Ca_LC),
            (N'Zn',  a.Zn_ppm,    a.Zn_LP,  a.Zn_LC),
            (N'K',   a.K_ppm,     a.K_LP,   a.K_LC),
            (N'Na',  a.Na_ppm,    a.Na_LP,  a.Na_LC),
            (N'Mg',  a.Mg_ppm,    a.Mg_LP,  a.Mg_LC),
            (N'B',   a.B_ppm,     NULL,     NULL),
            (N'P',   a.P_ppm,     NULL,     NULL),
            (N'V100',a.V100,      NULL,     NULL),
            (N'TBN', a.TBN,       a.TBN_LP, NULL)
        ) v(Parametro, Valor, LP, LC)
        WHERE v.Parametro = f.Parametro
    ) p
) filas GROUP BY Equipo, Compartimiento
) tb  ON tb.Equipo=u.Equipo AND tb.Compartimiento=u.Compartimiento
) x;
GO


/* ==== vw_CondicionMT_MD (condición de Motores de Tracción de 1 equipo) ==== */
CREATE OR ALTER VIEW [dbo].[vw_CondicionMT_MD] AS
/* 30/09 -- EL FILTRO POR EQUIPO VIVE ABAJO, no arriba.
   Con la tuberia como CTEs y el filtro sobre el resultado final, el optimizador NO lo bajaba a traves
   de las agregaciones: al armar el MD calculaba la traccion de TODA la flota (lc leido 655 veces = los
   654 componentes de traccion de la base) y filtraba al final -- ~2,5 min por camion (BLOQUES 179-183).
   Aqui la vista recorre Mine.MiningEquipment (10 paginas) y hace CROSS APPLY de la tuberia con el equipo
   ya fijado en su base (d.Equipo = me.Code). El filtro del flujo -- LIKE o '=' -- cae sobre la tabla
   chica y la tuberia corre una vez, para ese camion. Misma logica y misma salida que antes. */
/* Equipo sale de me.[Code] y no de x: asi el WHERE del flujo cae sobre la tabla chica ANTES del APPLY.
   Si saliera de x, el optimizador podria no reconocer que es el mismo valor y correr el APPLY por equipo. */
SELECT me.[Code] AS Equipo, x.Proyecto, x.Modelo, x.Observados, x.Recomendaciones, x.MD
FROM [Mine].[MiningEquipment] me
CROSS APPLY (
    SELECT * FROM (
        SELECT fi.Equipo, fi.Proyecto, fi.Modelo,
    ISNULL(NULLIF(CONCAT_WS(N' · ',
        CASE WHEN fi.obsLH IS NOT NULL THEN N'MT LH: ' + fi.obsLH END,
        CASE WHEN fi.obsRH IS NOT NULL THEN N'MT RH: ' + fi.obsRH END), N''), N'(ninguno fuera de límite)') AS Observados,
    ISNULL(rc.Recomendaciones, N'**🔧 Recomendaciones Técnicas**' + NCHAR(10) + N'Sin parámetros de Motor de Tracción fuera de límite — sin recomendaciones aplicables por ahora.') AS Recomendaciones,
    CAST(
        N'**Condición Motores de Tracción — ' + fi.Equipo + N'** · ' + CAST(fi.NumObs AS nvarchar(10)) + N' de ' + CAST(fi.NumMT AS nvarchar(10)) + N' observados' + NCHAR(10) + NCHAR(10)
      + N'| Par. | ' + fi.cols + N' |' + NCHAR(10)
      + N'|---|' + REPLICATE(N'---|', fi.N) + NCHAR(10)
      + fi.bodyMD
    AS nvarchar(max)) AS MD
FROM (
            SELECT Equipo, MAX(Proyecto) AS Proyecto, MAX(Modelo) AS Modelo,
                    MAX(N) AS N, MAX(cols) AS cols, MAX(NumObs) AS NumObs, MAX(NumMT) AS NumMT,
                    STRING_AGG(CAST(CASE WHEN EsInicioGrupo = 1 THEN N'| **' + grp + N'** |' + REPLICATE(N' |', N) + NCHAR(10) ELSE N'' END + rowMD AS nvarchar(max)), NCHAR(10))
                        WITHIN GROUP (ORDER BY ord) AS bodyMD,
                    STRING_AGG(CAST(obsLH AS nvarchar(max)), N', ') WITHIN GROUP (ORDER BY ord) AS obsLH,
                    STRING_AGG(CAST(obsRH AS nvarchar(max)), N', ') WITHIN GROUP (ORDER BY ord) AS obsRH,
                    STRING_AGG(CAST(CASE WHEN algunaMarcada = 1 THEN nombre END AS nvarchar(max)), N',') AS marcados
                FROM (
                    SELECT Equipo, grp, ord, nombre,
                            MAX(Proyecto) AS Proyecto, MAX(Modelo) AS Modelo,
                            COUNT(DISTINCT compAbbr) AS N,
                            STRING_AGG(compAbbr, N' | ') WITHIN GROUP (ORDER BY compOrd) AS cols,
                            COUNT(DISTINCT CASE WHEN compMarcado = 1 THEN compOrd END) AS NumObs,
                            COUNT(DISTINCT compOrd) AS NumMT,
                            MAX(marcada) AS algunaMarcada,
                            MAX(CASE WHEN compOrd = 1 AND marcada = 1 THEN nombre END) AS obsLH,
                            MAX(CASE WHEN compOrd = 2 AND marcada = 1 THEN nombre END) AS obsRH,
                            CASE WHEN ROW_NUMBER() OVER (PARTITION BY Equipo, grp ORDER BY ord) = 1 THEN 1 ELSE 0 END AS EsInicioGrupo,
                            CAST(N'| ' + nombre + N' | ' + STRING_AGG(cell, N' | ') WITHIN GROUP (ORDER BY compOrd) + N' |' AS nvarchar(max)) AS rowMD
                        FROM (
                            SELECT u.*, MAX(u.marcada) OVER (PARTITION BY u.Equipo, u.compOrd) AS compMarcado
                                FROM (
                                    SELECT b.Equipo, b.Proyecto, b.Modelo, b.compOrd, b.compAbbr,
                                               f.Orden AS ord, f.Grupo AS grp, f.Parametro AS nombre,
                                               ISNULL(p.cell, N'—') AS cell,
                                               CASE WHEN p.raw LIKE '%:C%' OR p.raw LIKE '%:P%' THEN 1 ELSE 0 END AS marcada
                                        FROM (
                                                SELECT d.*,
                                                    CASE WHEN d.Compartimiento LIKE '%TRACCION%LH' THEN 1 ELSE 2 END AS compOrd,
                                                    CASE WHEN d.Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' ELSE N'MT RH' END AS compAbbr
                                                FROM [dbo].[vw_DiagnosticoEquipo] d
                                                WHERE d.Compartimiento LIKE '%TRACCION%' AND d.Equipo = me.[Code]
                                        ) b
                                        INNER JOIN [dbo].[vw_FormatoParametro] f ON f.CompTipo = 'TRACCION'
                                        OUTER APPLY (
                                            SELECT v.cell, v.raw FROM (VALUES
                                                (N'Fe', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Fe AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), CAST(Fe AS nvarchar(40))),
                                                (N'PQ', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(PQ AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), CAST(PQ AS nvarchar(40))),
                                                (N'Cr', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Cr AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), CAST(Cr AS nvarchar(40))),
                                                (N'Ni', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Ni AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), CAST(Ni AS nvarchar(40))),
                                                (N'Cu', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Cu AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), CAST(Cu AS nvarchar(40))),
                                                (N'Pb', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Pb AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), CAST(Pb AS nvarchar(40))),
                                                (N'Sn', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Sn AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), CAST(Sn AS nvarchar(40))),
                                                (N'Al', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Al AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), CAST(Al AS nvarchar(40))),
                                                (N'Si', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Si AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), CAST(Si AS nvarchar(40))),
                                                (N'Ca', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Ca AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), CAST(Ca AS nvarchar(40))),
                                                (N'Zn', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Zn AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), CAST(Zn AS nvarchar(40))),
                                                (N'K', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(K AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), CAST(K AS nvarchar(40))),
                                                (N'Na', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Na AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), CAST(Na AS nvarchar(40))),
                                                (N'B', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(B AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), CAST(B AS nvarchar(40))),
                                                (N'P', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(P AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), CAST(P AS nvarchar(40))),
                                                (N'Mg', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Mg AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), CAST(Mg AS nvarchar(40))),
                                                (N'V100', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(V100 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), CAST(V100 AS nvarchar(40))),
                                                (N'TBN', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(TBN AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'),':C',N' 🟥'),':P',N' 🟨'), N'—'), CAST(TBN AS nvarchar(40)))
                                            ) v(Parametro, cell, raw) WHERE v.Parametro = f.Parametro
                                        ) p
                                ) u
                        ) u2 GROUP BY Equipo, grp, ord, nombre
                ) r GROUP BY Equipo
        ) fi
OUTER APPLY (
    SELECT CAST(N'**🔧 Recomendaciones Técnicas**' + NCHAR(10)
           + STRING_AGG(CONVERT(nvarchar(max), N'- **' + r.label + N':** ' + r.indicio), NCHAR(10)) WITHIN GROUP (ORDER BY r.ord)
           + NCHAR(10) + NCHAR(10) + N'Acortar la frecuencia de monitoreo y programar dializado/cambio de aceite en el próximo PM. Retirar los 8 tapones magnéticos para inspección y limpieza en busca de particulado anormal. Para mayor información y detalle, contactar a confiabilidad.operaciones@kmmp.com.pe' AS nvarchar(max)) AS Recomendaciones
    FROM (SELECT DISTINCT rr.ord, rr.label, rr.indicio
          FROM [dbo].[vw_Recomendaciones] rr
          WHERE CHARINDEX(N',' + rr.metal + N',', N',' + fi.marcados + N',') > 0) r
    HAVING COUNT(*) > 0
) rc
    ) z
) x;
GO


/* ==== vw_TendenciaP1MD (PASO 1 de tendencia: general x fechas) ==== */
CREATE OR ALTER VIEW [dbo].[vw_TendenciaP1MD] AS
/* 30/09 -- FILTRO ABAJO (mismo patron que curo /condicionmt: 146 s -> 1,4 s, y /diagcompleto).
   La logica va en CROSS APPLY sobre [Mine].[MiningEquipment] y CADA lectura pesada lleva el filtro
   (Equipo = me.[Code]), asi que ninguna rama calcula mas que ese camion. Los CTE van desplegados:
   un APPLY no admite WITH y SQL Server ya los trata como macros. Misma logica y salida. Respaldo: respaldo/DDL_vistas_2026-09-30_antes_filtro_abajo.sql */
SELECT me.[Code] AS Equipo, x.[compAbbr], x.[Observados], x.[Recomendaciones], x.[MD], x.[MD_Contexto]
FROM [Mine].[MiningEquipment] me
CROSS APPLY (
SELECT
    h.Equipo, h.compAbbr,
    CAST(NULL AS nvarchar(max)) AS Observados,      -- contrato fijo (no aplica en PASO 1)
    CAST(NULL AS nvarchar(max)) AS Recomendaciones, -- contrato fijo (no aplica en PASO 1)
    CAST(
        N'**Tendencia — ' + h.Equipo + N' · ' + h.compAbbr + N'** · últimas ' + CAST(h.Ncols AS nvarchar(10)) + N' muestras' + NCHAR(10) + NCHAR(10)
      + N'| Campo | ' + h.cols + N' |' + NCHAR(10)
      + N'|---|' + REPLICATE(N'---|', h.Ncols) + NCHAR(10)
      + bd.bodyMD + NCHAR(10) + NCHAR(10)
      + N'_¿Deseas el **detalle por elemento** (metales × fechas) o la **gráfica** de un metal?_'
    AS nvarchar(max)) AS MD,
    /* Mismo encabezado y misma tabla, SIN la pregunta de cierre: es lo que embebe vw_TendenciaMD
       al fusionar los dos modulos (F1). Se expone aqui para no duplicar la logica alla. */
    CAST(
        N'**Tendencia — ' + h.Equipo + N' · ' + h.compAbbr + N'** · últimas ' + CAST(h.Ncols AS nvarchar(10)) + N' muestras' + NCHAR(10) + NCHAR(10)
      + N'| Campo | ' + h.cols + N' |' + NCHAR(10)
      + N'|---|' + REPLICATE(N'---|', h.Ncols) + NCHAR(10)
      + bd.bodyMD
    AS nvarchar(max)) AS MD_Contexto
FROM (
    SELECT Equipo, compAbbr, COUNT(*) AS Ncols,
        STRING_AGG(colLabel, N' | ') WITHIN GROUP (ORDER BY rn_recencia DESC) AS cols
    FROM (SELECT DISTINCT Equipo, compAbbr, rn_recencia, colLabel FROM (
    /* 'base' se lleva TODO lo que necesita la tabla de contexto para que 'unpv' no vuelva a leer la
       fundacion: antes eran DOS lecturas de vw_MuestrasRankeadas para la misma ventana de 6 muestras.
       Mismo anti-patron del BLOQUE 117 (un CTE no se materializa: cada referencia lo re-ejecuta). */
    SELECT Equipo, Proyecto, Modelo, Compartimiento, rn_recencia,
        Horometro, HorasDeAceite, HorasComponente, CM, Grado, Estado_General,
        CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr,
        ISNULL(FORMAT(FechaMuestreo,'dd-MMM'), N'—') AS colLabel
    FROM (SELECT * FROM [dbo].[vw_MuestrasRankeadas] WHERE Equipo = me.[Code]) vw_MuestrasRankeadas
    WHERE rn_recencia <= 6
) base) z
    GROUP BY Equipo, compAbbr
) h
JOIN (
    SELECT Equipo, compAbbr,
        STRING_AGG(rowMD, NCHAR(10)) WITHIN GROUP (ORDER BY ord) AS bodyMD
    FROM (
    SELECT Equipo, compAbbr, ord, etq,
        CAST(N'| ' + etq + N' | ' + STRING_AGG(val, N' | ') WITHIN GROUP (ORDER BY rn_recencia DESC) + N' |' AS nvarchar(max)) AS rowMD
    FROM (
    SELECT b.Equipo, b.compAbbr, b.rn_recencia, v.ord, v.etq, v.val
    FROM (
    /* 'base' se lleva TODO lo que necesita la tabla de contexto para que 'unpv' no vuelva a leer la
       fundacion: antes eran DOS lecturas de vw_MuestrasRankeadas para la misma ventana de 6 muestras.
       Mismo anti-patron del BLOQUE 117 (un CTE no se materializa: cada referencia lo re-ejecuta). */
    SELECT Equipo, Proyecto, Modelo, Compartimiento, rn_recencia,
        Horometro, HorasDeAceite, HorasComponente, CM, Grado, Estado_General,
        CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr,
        ISNULL(FORMAT(FechaMuestreo,'dd-MMM'), N'—') AS colLabel
    FROM (SELECT * FROM [dbo].[vw_MuestrasRankeadas] WHERE Equipo = me.[Code]) vw_MuestrasRankeadas
    WHERE rn_recencia <= 6
) b
    CROSS APPLY (VALUES
            (1, N'SMR', ISNULL(CONVERT(nvarchar(20),CAST(Horometro AS decimal(18,0))), N'—')),
            (2, N'Hrs Aceite', ISNULL(CONVERT(nvarchar(20),CAST(HorasDeAceite AS decimal(18,0))), N'—')),
            (3, N'Hrs Comp', ISNULL(CONVERT(nvarchar(20),CAST(HorasComponente AS decimal(18,0))), N'—')),
            (6, N'Grado', ISNULL(Grado, N'—')),
            (4, N'CM', ISNULL(CM, N'—')),
            (5, N'Estado', CASE WHEN Estado_General LIKE '%CRITIC%' THEN N'🟥' WHEN Estado_General LIKE '%PRECAUC%' THEN N'🟨' WHEN Estado_General LIKE '%OK%' OR Estado_General LIKE '%NORMAL%' THEN N'🟢' ELSE ISNULL(Estado_General,N'—') END)
    ) v(ord, etq, val)
) unpv GROUP BY Equipo, compAbbr, ord, etq
) rows_ GROUP BY Equipo, compAbbr
) bd ON bd.Equipo=h.Equipo AND bd.compAbbr=h.compAbbr
) x;
GO


/* ==== vw_TendenciaMD (tendencia DETALLE: params x fechas + Acum + Spark) ==== */
CREATE OR ALTER VIEW [dbo].[vw_TendenciaMD] AS
/* 30/09 -- FILTRO ABAJO (mismo patron que curo /condicionmt: 146 s -> 1,4 s, y /diagcompleto).
   La logica va en CROSS APPLY sobre [Mine].[MiningEquipment] y CADA lectura pesada lleva el filtro
   (Equipo = me.[Code]), asi que ninguna rama calcula mas que ese camion. Los CTE van desplegados:
   un APPLY no admite WITH y SQL Server ya los trata como macros. Misma logica y salida. Respaldo: respaldo/DDL_vistas_2026-09-30_antes_filtro_abajo.sql */
SELECT me.[Code] AS Equipo, x.[compAbbr], x.[Observados], x.[Recomendaciones], x.[MD], x.[MD_Estadistica], x.[MD_Relevantes]
FROM [Mine].[MiningEquipment] me
CROSS APPLY (
SELECT
    d.Equipo, d.compAbbr,
    ISNULL(oa.compAbbr + N': ' + oa.metals, d.compAbbr + N': (última muestra sin observados)') AS Observados,
    ISNULL(rb.Recomendaciones,
        CASE WHEN d.compAbbr LIKE 'MT %'
             THEN N'**🔧 Recomendaciones Técnicas**' + NCHAR(10) + N'Sin parámetros de Motor de Tracción fuera de límite en la última muestra — sin recomendaciones aplicables por ahora.'
             ELSE N'**🔧 Recomendaciones Técnicas**' + NCHAR(10) + N'Nada que comentar sobre el Motor de Tracción para este componente.' END) AS Recomendaciones,
    /* MODULO FUSIONADO (F1): contexto de /tendencia + matriz + limites. El resumen estadistico
       salio de aqui a MD_Estadistica -- medido en el BLOQUE 123: 91 lineas en MT (el componente
       MAS chico) y ~103 en MOTOR. No cabe leerlo en un movil de una sentada.
       El contexto se EMBEBE de vw_TendenciaP1MD en vez de recalcularlo: una sola definicion.
       LEFT JOIN + ISNULL a proposito: si P1 no tuviera fila, el MD no puede quedar NULL. */
    CAST(   -- DEFAULT (columna=MD)
        ISNULL(p1.MD_Contexto, N'**Tendencia — ' + d.Equipo + N' · ' + d.compAbbr + N'**') + NCHAR(10) + NCHAR(10)
      + N'**Detalle por parámetro**' + NCHAR(10) + NCHAR(10)
      + N'| Par. | ' + d.h1+N' | '+d.h2+N' | '+d.h3+N' | '+d.h4+N' | '+d.h5+N' | '+d.h6 + N' | Acum | Spark |' + NCHAR(10)
      + N'|---|' + REPLICATE(N'---|', 8) + NCHAR(10)
      + ba.bodyMD + NCHAR(10) + NCHAR(10)
      /* B (29/09): FUERA la tabla de limites, pedido de Carlos. Y es redundante de verdad: cada
         celda de la tabla de arriba ya trae su semaforo (':C' -> 🟥, ':P' -> 🟨), asi que repetir
         LP/LC abajo no anade nada que no se vea ya.
         ⚠ LO QUE NO SE PODIA PERDER es el aviso de «sin limites cargados». Vivia PEGADO a esa
         tabla, y son 45 combinaciones proyecto+modelo las que lo necesitan (BLOQUE 102). Sin el,
         un componente sin limites se lee igual que uno en regla: fallo silencioso. Sobrevive como
         LINEA DE TEXTO, que era la unica condicion. */
      + CASE WHEN ISNULL(lf.nLimDesgaste, 0) = 0
             THEN N'_⚠ **Sin límites (LP/LC) cargados** para los metales de desgaste de este componente: los valores se '
                + N'muestran, pero no hay contra qué compararlos, y el estado **no se puede evaluar**. Esto **no** significa que estén dentro de límite._' + NCHAR(10) + NCHAR(10)
             ELSE N'' END
      /* Dos 'acumulados' distintos con el mismo nombre coloquial confunden: se dice cual es cual. */
      + N'_**Acum** = suma del metal, solo en metales de desgaste y con el criterio del área: en **Motor de Tracción** las muestras previas al dializado y los cambios, en **Motor** todas, y en **Rueda** e **Hidráulico** solo los cambios. En MT y Motor está acotado al componente instalado hoy; en rueda e hidráulico no, porque la base no registra cuál lo está. Un `—` significa **no se puede calcular**, no cero._' + NCHAR(10) + NCHAR(10)
      + N'_¿Quieres el **resumen estadístico** (promedio, σ, nº fuera de límite) o la **gráfica** de un metal?_'
    AS nvarchar(max)) AS MD,
    /* CONTINUACION (columna=MD_Estadistica): lo que salio del bloque principal por tamano.
       Mismo patron que MD_Relevantes -- una columna mas, no un modulo mas. */
    CAST(
        N'**Resumen estadístico — ' + d.Equipo + N' · ' + d.compAbbr + N'**' + NCHAR(10) + NCHAR(10)
      + N'| Par. | Prom. | σ | Acum | Nº fuera de límite |' + NCHAR(10)
      + N'|---|---|---|---|---|' + NCHAR(10)
      + ISNULL(st.bodyMD, N'_Sin muestras suficientes para el resumen._') + NCHAR(10) + NCHAR(10)
      + N'_**Acum** = suma del metal, solo en metales de desgaste y con el criterio del área: en **Motor de Tracción** las muestras previas al dializado y los cambios, en **Motor** todas, y en **Rueda** e **Hidráulico** solo los cambios. En MT y Motor está acotado al componente instalado hoy; en rueda e hidráulico no, porque la base no registra cuál lo está. Un `—` significa **no se puede calcular**, no cero._'
    AS nvarchar(max)) AS MD_Estadistica,
    CAST(   -- opt-in (columna=MD_Relevantes): TABLA solo si hay relevantes; si no, solo el mensaje
        N'**Tendencia — parámetros relevantes · ' + d.Equipo + N' · ' + d.compAbbr + N'**' + NCHAR(10) + NCHAR(10)
      + CASE WHEN br.bodyMD IS NOT NULL THEN
            N'| Par. | ' + d.h1+N' | '+d.h2+N' | '+d.h3+N' | '+d.h4+N' | '+d.h5+N' | '+d.h6 + N' | Acum | Spark |' + NCHAR(10)
          + N'|---|' + REPLICATE(N'---|', 8) + NCHAR(10) + br.bodyMD
        /* B (29/09): aqui la tabla de limites tambien sobra. Y de paso se arregla un fallo
           silencioso que ya estaba: sin limites cargados NADA puede ser 'relevante', asi que la
           vista afirmaba «opera en condicion normal» -- de un componente que nadie pudo evaluar.
           Ahora distingue los dos casos. */
        ELSE CASE WHEN ISNULL(lf.nLimDesgaste, 0) = 0
                  THEN N'_⚠ **Sin límites (LP/LC) cargados** para los metales de desgaste de este componente: **no se puede decir** si hay parámetros fuera de umbral._'
                  ELSE N'_Sin parámetros fuera de umbral — el componente opera en condición normal._' END END
    AS nvarchar(max)) AS MD_Relevantes
FROM (
    SELECT Equipo, Compartimiento, MAX(compAbbr) AS compAbbr,
        ISNULL(FORMAT(MAX(f1),'dd-MMM'),N'—') AS h1, ISNULL(FORMAT(MAX(f2),'dd-MMM'),N'—') AS h2,
        ISNULL(FORMAT(MAX(f3),'dd-MMM'),N'—') AS h3, ISNULL(FORMAT(MAX(f4),'dd-MMM'),N'—') AS h4,
        ISNULL(FORMAT(MAX(f5),'dd-MMM'),N'—') AS h5, ISNULL(FORMAT(MAX(f6),'dd-MMM'),N'—') AS h6
    FROM (
    SELECT *, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr FROM (SELECT * FROM [dbo].[vw_TendenciaElemento] WHERE Equipo = me.[Code]) vw_TendenciaElemento
) te GROUP BY Equipo, Compartimiento
) d
LEFT JOIN (SELECT * FROM [dbo].[vw_TendenciaP1MD] WHERE Equipo = me.[Code]) p1 ON p1.Equipo=d.Equipo AND p1.compAbbr=d.compAbbr
JOIN (
    SELECT Equipo, Compartimiento,
        STRING_AGG(CAST(CASE WHEN EsInicioGrupo = 1 THEN N'| **' + Grupo + N'** |' + REPLICATE(N' |', 8) + NCHAR(10) ELSE N'' END + rowMD AS nvarchar(max)), NCHAR(10))
            WITHIN GROUP (ORDER BY Orden) AS bodyMD
    FROM (
    /* El encabezado de grupo se emite en la PRIMERA fila de cada grupo, no en posiciones fijas: con el
       formato por componente (vw_FormatoParametro) los limites de grupo cambian segun el componente. */
    SELECT Equipo, Compartimiento, compAbbr, Grupo, Orden, EsRelevante,
        CASE WHEN ROW_NUMBER() OVER (PARTITION BY Equipo, Compartimiento, Grupo ORDER BY Orden) = 1
             THEN 1 ELSE 0 END AS EsInicioGrupo,
        CAST(N'| ' + Parametro + N' | '
           + ISNULL(REPLACE(REPLACE(CAST(d1 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'·') + N' | ' + ISNULL(REPLACE(REPLACE(CAST(d2 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'·') + N' | ' + ISNULL(REPLACE(REPLACE(CAST(d3 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'·') + N' | ' + ISNULL(REPLACE(REPLACE(CAST(d4 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'·') + N' | ' + ISNULL(REPLACE(REPLACE(CAST(d5 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'·') + N' | ' + ISNULL(REPLACE(REPLACE(CAST(d6 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'·') + N' | ' + CASE WHEN Parametro NOT IN ('Fe','PQ','Cr','Ni','Cu','Pb','Sn','Al') THEN N'—' ELSE ISNULL(CONVERT(nvarchar(20),CAST(Acumulado AS decimal(18,1))), N'—') END + N' | ' + ISNULL(Spark, N'—') + N' |' AS nvarchar(max)) AS rowMD
    FROM (
    SELECT *, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr FROM (SELECT * FROM [dbo].[vw_TendenciaElemento] WHERE Equipo = me.[Code]) vw_TendenciaElemento
) te
) rowcte GROUP BY Equipo, Compartimiento
) ba ON ba.Equipo=d.Equipo AND ba.Compartimiento=d.Compartimiento
LEFT JOIN (   -- tabla SOLO de los parámetros relevantes (sin cabeceras de grupo, filas limpias)
    SELECT Equipo, Compartimiento,
        STRING_AGG(rowMD, NCHAR(10)) WITHIN GROUP (ORDER BY Orden) AS bodyMD
    FROM (
    /* El encabezado de grupo se emite en la PRIMERA fila de cada grupo, no en posiciones fijas: con el
       formato por componente (vw_FormatoParametro) los limites de grupo cambian segun el componente. */
    SELECT Equipo, Compartimiento, compAbbr, Grupo, Orden, EsRelevante,
        CASE WHEN ROW_NUMBER() OVER (PARTITION BY Equipo, Compartimiento, Grupo ORDER BY Orden) = 1
             THEN 1 ELSE 0 END AS EsInicioGrupo,
        CAST(N'| ' + Parametro + N' | '
           + ISNULL(REPLACE(REPLACE(CAST(d1 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'·') + N' | ' + ISNULL(REPLACE(REPLACE(CAST(d2 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'·') + N' | ' + ISNULL(REPLACE(REPLACE(CAST(d3 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'·') + N' | ' + ISNULL(REPLACE(REPLACE(CAST(d4 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'·') + N' | ' + ISNULL(REPLACE(REPLACE(CAST(d5 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'·') + N' | ' + ISNULL(REPLACE(REPLACE(CAST(d6 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'·') + N' | ' + CASE WHEN Parametro NOT IN ('Fe','PQ','Cr','Ni','Cu','Pb','Sn','Al') THEN N'—' ELSE ISNULL(CONVERT(nvarchar(20),CAST(Acumulado AS decimal(18,1))), N'—') END + N' | ' + ISNULL(Spark, N'—') + N' |' AS nvarchar(max)) AS rowMD
    FROM (
    SELECT *, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr FROM (SELECT * FROM [dbo].[vw_TendenciaElemento] WHERE Equipo = me.[Code]) vw_TendenciaElemento
) te
) rowcte WHERE EsRelevante=1 GROUP BY Equipo, Compartimiento
) br ON br.Equipo=d.Equipo AND br.Compartimiento=d.Compartimiento
LEFT JOIN (   -- B (29/09): ya no se arma la tabla de limites, solo se cuenta.
    /* ⛔ B2 (29/09) -- LA PREGUNTA ERA LA EQUIVOCADA, Y VENIA DE ANTES.
       El aviso original se disparaba con "este componente no tiene NINGUN limite". Medido con
       HT079/HT080 (930E de Antamina, BLOQUE 164.4): no salta, porque tienen algun limite suelto
       -- un V100, un TBN -- aunque NO TENGAN NI UNO SOLO de los metales de desgaste. Y con eso
       MD_Relevantes llegaba a afirmar "opera en condicion normal" de un componente que nadie
       puede evaluar. Son 885 componentes (BLOQUE 164.3).
       La pregunta correcta no es "¿hay algun limite?" sino "¿hay limite de lo que decide el
       estado?". Los 9 de desgaste son exactamente los que mira Estado_General: sin ellos el
       semaforo verde no significa nada. */
    SELECT Equipo, Compartimiento,
           COUNT(*) AS nLim,
           SUM(CASE WHEN Parametro IN (N'Fe',N'PQ',N'Cr',N'Ni',N'Cu',N'Pb',N'Sn',N'Al',N'Si')
                    THEN 1 ELSE 0 END) AS nLimDesgaste
    FROM (
    SELECT *, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr FROM (SELECT * FROM [dbo].[vw_TendenciaElemento] WHERE Equipo = me.[Code]) vw_TendenciaElemento
) te WHERE LP IS NOT NULL OR LC IS NOT NULL
    GROUP BY Equipo, Compartimiento
) lf ON lf.Equipo=d.Equipo AND lf.Compartimiento=d.Compartimiento
LEFT JOIN (   -- Resumen estadístico por parámetro (Prom, σ, Acum, Nº fuera)
    SELECT Equipo, Compartimiento,
        STRING_AGG(CAST(N'| ' + CONVERT(nvarchar(20),Parametro) + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(Prom AS decimal(18,1))),N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(Sigma AS decimal(18,1))),N'—') + N' | ' + CASE WHEN Parametro NOT IN ('Fe','PQ','Cr','Ni','Cu','Pb','Sn','Al') THEN N'—' ELSE ISNULL(CONVERT(nvarchar(20),CAST(Acumulado AS decimal(18,1))), N'—') END + N' | ' + CONVERT(nvarchar(10), NVecesObs) + CASE WHEN NVecesObs>0 THEN N' 🟥' ELSE N'' END + N' |' AS nvarchar(max)), NCHAR(10)) WITHIN GROUP (ORDER BY Orden) AS bodyMD
    FROM (
    SELECT *, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr FROM (SELECT * FROM [dbo].[vw_TendenciaElemento] WHERE Equipo = me.[Code]) vw_TendenciaElemento
) te GROUP BY Equipo, Compartimiento
) st ON st.Equipo=d.Equipo AND st.Compartimiento=d.Compartimiento
LEFT JOIN (
    SELECT Equipo, Compartimiento, MAX(compAbbr) AS compAbbr, STRING_AGG(CONVERT(nvarchar(20), Parametro), N', ') AS metals
    FROM (
    SELECT te.Equipo, te.Compartimiento, te.compAbbr, te.Parametro
    FROM (
    SELECT *, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr FROM (SELECT * FROM [dbo].[vw_TendenciaElemento] WHERE Equipo = me.[Code]) vw_TendenciaElemento
) te WHERE (te.d6 LIKE '%:C%' OR te.d6 LIKE '%:P%')
) obslast GROUP BY Equipo, Compartimiento
) oa ON oa.Equipo=d.Equipo AND oa.Compartimiento=d.Compartimiento
LEFT JOIN (
    SELECT Equipo, Compartimiento,
        CAST(N'**🔧 Recomendaciones Técnicas**' + NCHAR(10)
           + STRING_AGG(CONVERT(nvarchar(max), N'- **' + label + N':** ' + indicio), NCHAR(10)) WITHIN GROUP (ORDER BY ord)
           + NCHAR(10) + NCHAR(10) + N'Acortar la frecuencia de monitoreo y programar dializado/cambio de aceite en el próximo PM. Retirar los 8 tapones magnéticos para inspección y limpieza en busca de particulado anormal. Para mayor información y detalle, contactar a confiabilidad.operaciones@kmmp.com.pe' AS nvarchar(max)) AS Recomendaciones
    FROM (
    SELECT DISTINCT ol.Equipo, ol.Compartimiento, r.ord, r.label, r.indicio
    FROM (
    SELECT te.Equipo, te.Compartimiento, te.compAbbr, te.Parametro
    FROM (
    SELECT *, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr FROM (SELECT * FROM [dbo].[vw_TendenciaElemento] WHERE Equipo = me.[Code]) vw_TendenciaElemento
) te WHERE (te.d6 LIKE '%:C%' OR te.d6 LIKE '%:P%')
) ol JOIN [dbo].[vw_Recomendaciones] r ON r.metal = ol.Parametro
    WHERE ol.Compartimiento LIKE '%TRACCION%'
) recos GROUP BY Equipo, Compartimiento
) rb ON rb.Equipo=d.Equipo AND rb.Compartimiento=d.Compartimiento
) x;
GO


/* ==== vw_TendenciaGraficoMD (wrapper del gráfico ASCII en fence, contrato MD) ==== */
CREATE OR ALTER VIEW [dbo].[vw_TendenciaGraficoMD] AS
/* 30/09 -- FILTRO ABAJO (mismo patron que curo /condicionmt: 146 s -> 1,4 s, y /diagcompleto).
   La logica va en CROSS APPLY sobre [Mine].[MiningEquipment] y CADA lectura pesada lleva el filtro
   (Equipo = me.[Code]), asi que ninguna rama calcula mas que ese camion. Los CTE van desplegados:
   un APPLY no admite WITH y SQL Server ya los trata como macros. Misma logica y salida. Respaldo: respaldo/DDL_vistas_2026-09-30_antes_filtro_abajo.sql */
SELECT me.[Code] AS Equipo, x.[compAbbr], x.[Parametro], x.[Observados], x.[Recomendaciones], x.[MD]
FROM [Mine].[MiningEquipment] me
CROSS APPLY (
SELECT
    g.Equipo, CASE WHEN g.Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN g.Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN g.Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN g.Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN g.Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN g.Compartimiento='MOTOR' THEN N'Motor' ELSE g.Compartimiento END AS compAbbr, g.Parametro,
    CAST(NULL AS nvarchar(max)) AS Observados,
    CAST(NULL AS nvarchar(max)) AS Recomendaciones,
    CAST(
        /* El CUADRO de /tendencia, entero y arriba de la grafica (pedido de gerencia). Se embebe
           de vw_TendenciaP1MD -- una sola definicion, igual que en el modulo fusionado.
           LEFT JOIN + ISNULL: si P1 no tuviera fila, el MD no puede quedar NULL. */
        ISNULL(p1.MD_Contexto,
               N'**Tendencia — ' + g.Equipo + N' · ' + CASE WHEN g.Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN g.Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN g.Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN g.Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN g.Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN g.Compartimiento='MOTOR' THEN N'Motor' ELSE g.Compartimiento END + N'**')
      + NCHAR(10) + NCHAR(10)
      + N'**Gráfica de ' + CONVERT(nvarchar(20), g.Parametro) + N'**' + NCHAR(10) + NCHAR(10)
      + N'| Par. | ' + ISNULL(FORMAT(te.f1,'dd-MMM'),N'—') + N' | ' + ISNULL(FORMAT(te.f2,'dd-MMM'),N'—') + N' | ' + ISNULL(FORMAT(te.f3,'dd-MMM'),N'—') + N' | ' + ISNULL(FORMAT(te.f4,'dd-MMM'),N'—') + N' | ' + ISNULL(FORMAT(te.f5,'dd-MMM'),N'—') + N' | ' + ISNULL(FORMAT(te.f6,'dd-MMM'),N'—') + N' | Acum |' + NCHAR(10)
      + N'|---|---|---|---|---|---|---|---|' + NCHAR(10)
      + N'| ' + CONVERT(nvarchar(20),g.Parametro) + N' | ' + ISNULL(REPLACE(REPLACE(CAST(te.d1 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'·') + N' | ' + ISNULL(REPLACE(REPLACE(CAST(te.d2 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'·') + N' | ' + ISNULL(REPLACE(REPLACE(CAST(te.d3 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'·') + N' | ' + ISNULL(REPLACE(REPLACE(CAST(te.d4 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'·') + N' | ' + ISNULL(REPLACE(REPLACE(CAST(te.d5 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'·') + N' | ' + ISNULL(REPLACE(REPLACE(CAST(te.d6 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'·')
        + N' | ' + CASE WHEN te.Parametro NOT IN ('Fe','PQ','Cr','Ni','Cu','Pb','Sn','Al') THEN N'—' ELSE ISNULL(CONVERT(nvarchar(20),CAST(te.Acumulado AS decimal(18,1))), N'—') END + N' |' + NCHAR(10) + NCHAR(10)
      /* A (29/09): el resumen sale como LISTA DE TEXTO y diciendo de que esta hecho cada cifra.
         Andres lo pidio asi: "como texto, pero bien detallado y mencionando la logica". En una
         tabla, 'Prom.' y 'σ' son dos numeros sin contexto; aqui cada uno lleva su regla, que es
         lo que evita que alguien compare un promedio de 6 muestras con uno de 2.
         El Spark se va: la grafica ASCII esta debajo y decia lo mismo en peor. */
      + N'**Resumen del período**' + NCHAR(10) + NCHAR(10)
      + N'- **Prom.:** ' + ISNULL(CONVERT(nvarchar(20),CAST(te.Prom AS decimal(18,1))), N'—')
        + N' — media de las **' + CONVERT(nvarchar(10), te.NMuestras) + N'** muestras del período (las 6 últimas como máximo).' + NCHAR(10)
      + N'- **Desv. est. (σ):** ' + ISNULL(CONVERT(nvarchar(20),CAST(te.Sigma AS decimal(18,1))), N'—')
        + N' — cuánto se mueve el parámetro entre muestra y muestra. Un σ alto con promedio bajo apunta a una lectura suelta, no a una tendencia.' + NCHAR(10)
      + N'- **Nº fuera de límite:** ' + CONVERT(nvarchar(10), te.NVecesObs)
        + N' de ' + CONVERT(nvarchar(10), te.NMuestras) + N' — veces que superó **LP** en el período.' + NCHAR(10)
      + N'- **Acum:** ' + CASE WHEN te.Parametro NOT IN ('Fe','PQ','Cr','Ni','Cu','Pb','Sn','Al') THEN N'— (solo aplica a metales de desgaste)' ELSE ISNULL(CONVERT(nvarchar(20),CAST(te.Acumulado AS decimal(18,1))), N'—') + N' — suma del metal con el criterio del área; un `—` significa **no se puede calcular**, no cero.' END + NCHAR(10) + NCHAR(10)
      + N'**Límites de referencia (ppm)**: LP ' + ISNULL(CONVERT(nvarchar(20),CAST(te.LP AS decimal(18,1))), N'—') + N' · LC ' + ISNULL(CONVERT(nvarchar(20),CAST(te.LC AS decimal(18,1))), N'—') + NCHAR(10) + NCHAR(10)
      + N'```' + NCHAR(10) + g.Grafico + NCHAR(10) + N'```'
    AS nvarchar(max)) AS MD
FROM (SELECT * FROM [dbo].[vw_TendenciaGrafico] WHERE Equipo = me.[Code]) g
LEFT JOIN (SELECT * FROM [dbo].[vw_TendenciaP1MD] WHERE Equipo = me.[Code]) p1 ON p1.Equipo = g.Equipo
  AND p1.compAbbr = CASE WHEN g.Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN g.Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN g.Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN g.Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN g.Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN g.Compartimiento='MOTOR' THEN N'Motor' ELSE g.Compartimiento END
JOIN (SELECT * FROM [dbo].[vw_TendenciaElemento] WHERE Equipo = me.[Code]) te
  ON te.Equipo=g.Equipo AND te.Compartimiento=g.Compartimiento AND te.Parametro=g.Parametro
) x;
GO


/* ==== vw_TendenciaGraficoObsMD (gráficas de los metales observados; default del gráfico) ==== */
CREATE OR ALTER VIEW [dbo].[vw_TendenciaGraficoObsMD] AS
/* 30/09 -- FILTRO ABAJO (mismo patron que curo /condicionmt: 146 s -> 1,4 s, y /diagcompleto).
   La logica va en CROSS APPLY sobre [Mine].[MiningEquipment] y CADA lectura pesada lleva el filtro
   (Equipo = me.[Code]), asi que ninguna rama calcula mas que ese camion. Los CTE van desplegados:
   un APPLY no admite WITH y SQL Server ya los trata como macros. Misma logica y salida. Respaldo: respaldo/DDL_vistas_2026-09-30_antes_filtro_abajo.sql */
SELECT me.[Code] AS Equipo, x.[compAbbr], x.[Observados], x.[Recomendaciones], x.[MD]
FROM [Mine].[MiningEquipment] me
CROSS APPLY (
SELECT b.Equipo, b.compAbbr,
    CAST(NULL AS nvarchar(max)) AS Observados,       -- contrato fijo
    CAST(NULL AS nvarchar(max)) AS Recomendaciones,  -- contrato fijo
    CAST(
        /* Mismo cuadro de /tendencia arriba, embebido de P1 (F3, redefinido el 25/09). */
        ISNULL(p1.MD_Contexto, N'**Tendencia — ' + b.Equipo + N' · ' + b.compAbbr + N'**')
      + NCHAR(10) + NCHAR(10)
      + N'**Gráficas de metales observados**' + NCHAR(10) + NCHAR(10)
      + ISNULL(go.graphs, N'_No hay metales fuera de límite en este componente. Dime qué metal quieres graficar (ej. Cr, Fe, Cu)._')
    AS nvarchar(max)) AS MD
FROM (
    /* El contexto ya no se arma aqui: viene entero de p1.MD_Contexto. Este CTE solo da la lista
       de componentes del equipo. */
    SELECT DISTINCT Equipo, Compartimiento,
           CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr
    FROM (SELECT * FROM [dbo].[vw_TendenciaElemento] WHERE Equipo = me.[Code]) vw_TendenciaElemento
) b
LEFT JOIN (SELECT * FROM [dbo].[vw_TendenciaP1MD] WHERE Equipo = me.[Code]) p1 ON p1.Equipo = b.Equipo AND p1.compAbbr = b.compAbbr
LEFT JOIN (   -- concatena las gráficas de los parámetros relevantes (fuera de umbral), cada una en su ```
    SELECT te.Equipo, te.Compartimiento,
        STRING_AGG(CONVERT(nvarchar(max), N'```' + NCHAR(10) + gr.Grafico + NCHAR(10) + N'```'), NCHAR(10)+NCHAR(10))
            WITHIN GROUP (ORDER BY te.Orden) AS graphs
    FROM (SELECT * FROM [dbo].[vw_TendenciaElemento] WHERE Equipo = me.[Code]) te
    JOIN (SELECT * FROM [dbo].[vw_TendenciaGrafico] WHERE Equipo = me.[Code]) gr
      ON gr.Equipo=te.Equipo AND gr.Compartimiento=te.Compartimiento AND gr.Parametro=te.Parametro
    WHERE te.EsRelevante=1
    GROUP BY te.Equipo, te.Compartimiento
) go ON go.Equipo=b.Equipo AND go.Compartimiento=b.Compartimiento
) x;
GO


/* ==== vw_TendenciaMetalMD (tendencia de un metal en todos los componentes) ==== */
CREATE OR ALTER VIEW [dbo].[vw_TendenciaMetalMD] AS
/* 30/09 -- FILTRO ABAJO (mismo patron que curo /condicionmt: 146 s -> 1,4 s, y /diagcompleto).
   La logica va en CROSS APPLY sobre [Mine].[MiningEquipment] y CADA lectura pesada lleva el filtro
   (Equipo = me.[Code]), asi que ninguna rama calcula mas que ese camion. Los CTE van desplegados:
   un APPLY no admite WITH y SQL Server ya los trata como macros. Misma logica y salida. Respaldo: respaldo/DDL_vistas_2026-09-30_antes_filtro_abajo.sql */
SELECT me.[Code] AS Equipo, x.[compAbbr], x.[Parametro], x.[Observados], x.[Recomendaciones], x.[MD]
FROM [Mine].[MiningEquipment] me
CROSS APPLY (
SELECT
    q.Equipo, N'(todos)' AS compAbbr, q.Parametro,
    CAST(NULL AS nvarchar(max)) AS Observados,
    CAST(NULL AS nvarchar(max)) AS Recomendaciones,
    CAST(
        N'**Tendencia de ' + CONVERT(nvarchar(20), q.Parametro) + N' — ' + q.Equipo + N' (todos los componentes)**' + NCHAR(10) + NCHAR(10)
      + N'| Componente | Grado | Hrs C. | Última | Tend. | Spark |' + NCHAR(10)
      + N'|---|---|---|---|---|---|' + NCHAR(10) + q.b + NCHAR(10) + NCHAR(10)
      + N'**Límites de referencia (ppm)**' + NCHAR(10) + NCHAR(10)
      + N'| Componente | LP | LC |' + NCHAR(10)
      + N'|---|---|---|' + NCHAR(10) + l.b + NCHAR(10) + NCHAR(10)
      + N'**Resumen estadístico**' + NCHAR(10) + NCHAR(10)
      + N'| Componente | Prom. | σ | Acum | Nº fuera de límite |' + NCHAR(10)
      + N'|---|---|---|---|---|' + NCHAR(10) + s.b
    AS nvarchar(max)) AS MD
FROM (SELECT Equipo, Parametro, STRING_AGG(rowMD, NCHAR(10)) WITHIN GROUP (ORDER BY compOrd) AS b FROM (
    SELECT Equipo, Parametro, compOrd,
        CAST(N'| ' + compAbbr + N' | ' + ISNULL(Grado, N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(HorasComponente AS decimal(18,0))), N'—') + N' | ' + ISNULL(REPLACE(REPLACE(CAST(d6 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'·')
           + N' | ' + ISNULL(Tendencia, N'—') + N' | ' + ISNULL(Spark, N'·') + N' |' AS nvarchar(max)) AS rowMD
    FROM (
    SELECT Equipo, Parametro, LP, LC, d6, Tendencia, Acumulado, Spark, Orden, Prom, Sigma, NVecesObs, Grado, HorasComponente,
        CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN 1 WHEN Compartimiento LIKE '%TRACCION%RH' THEN 2 WHEN Compartimiento LIKE '%RUEDA%LH' THEN 3 WHEN Compartimiento LIKE '%RUEDA%RH' THEN 4 WHEN Compartimiento='MOTOR' THEN 5 WHEN Compartimiento LIKE '%HIDRAUL%' THEN 6 ELSE 9 END AS compOrd, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr
    FROM (SELECT * FROM [dbo].[vw_TendenciaElemento] WHERE Equipo = me.[Code]) vw_TendenciaElemento
) te
) qrows GROUP BY Equipo, Parametro) q JOIN (SELECT Equipo, Parametro, STRING_AGG(rowMD, NCHAR(10)) WITHIN GROUP (ORDER BY compOrd) AS b FROM (
    SELECT Equipo, Parametro, compOrd,
        CAST(N'| ' + compAbbr + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(Prom AS decimal(18,1))),N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(Sigma AS decimal(18,1))),N'—')
           + N' | ' + CASE WHEN Parametro NOT IN ('Fe','PQ','Cr','Ni','Cu','Pb','Sn','Al') THEN N'—' ELSE ISNULL(CONVERT(nvarchar(20),CAST(Acumulado AS decimal(18,1))), N'—') END + N' | ' + CONVERT(nvarchar(10), NVecesObs) + CASE WHEN NVecesObs>0 THEN N' 🟥' ELSE N'' END + N' |' AS nvarchar(max)) AS rowMD
    FROM (
    SELECT Equipo, Parametro, LP, LC, d6, Tendencia, Acumulado, Spark, Orden, Prom, Sigma, NVecesObs, Grado, HorasComponente,
        CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN 1 WHEN Compartimiento LIKE '%TRACCION%RH' THEN 2 WHEN Compartimiento LIKE '%RUEDA%LH' THEN 3 WHEN Compartimiento LIKE '%RUEDA%RH' THEN 4 WHEN Compartimiento='MOTOR' THEN 5 WHEN Compartimiento LIKE '%HIDRAUL%' THEN 6 ELSE 9 END AS compOrd, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr
    FROM (SELECT * FROM [dbo].[vw_TendenciaElemento] WHERE Equipo = me.[Code]) vw_TendenciaElemento
) te
) srows GROUP BY Equipo, Parametro) s ON s.Equipo=q.Equipo AND s.Parametro=q.Parametro
JOIN (SELECT Equipo, Parametro, STRING_AGG(rowMD, NCHAR(10)) WITHIN GROUP (ORDER BY compOrd) AS b FROM (   -- limites de referencia en tabla APARTE (pedido gerencia: no como columnas de la matriz)
    SELECT Equipo, Parametro, compOrd,
        CAST(N'| ' + compAbbr + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(LP AS decimal(18,1))), N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(LC AS decimal(18,1))), N'—') + N' |' AS nvarchar(max)) AS rowMD
    FROM (
    SELECT Equipo, Parametro, LP, LC, d6, Tendencia, Acumulado, Spark, Orden, Prom, Sigma, NVecesObs, Grado, HorasComponente,
        CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN 1 WHEN Compartimiento LIKE '%TRACCION%RH' THEN 2 WHEN Compartimiento LIKE '%RUEDA%LH' THEN 3 WHEN Compartimiento LIKE '%RUEDA%RH' THEN 4 WHEN Compartimiento='MOTOR' THEN 5 WHEN Compartimiento LIKE '%HIDRAUL%' THEN 6 ELSE 9 END AS compOrd, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr
    FROM (SELECT * FROM [dbo].[vw_TendenciaElemento] WHERE Equipo = me.[Code]) vw_TendenciaElemento
) te
) lrows GROUP BY Equipo, Parametro) l ON l.Equipo=q.Equipo AND l.Parametro=q.Parametro
) x;
GO


/* ⛔ G2 (29/09) -- compAbbr NUNCA puede salir NULL.
   El smoke test del BLOQUE 160.5 devolvio 'HistorialMD NULL': el MD entero venia nulo. La causa es
   el modo A de la ley 5 -- en SQL Server un solo operando NULL anula TODA la concatenacion, y
   compAbbr se calculaba con un CASE cuyo ELSE devolvia Compartimiento tal cual, que puede ser NULL
   (el bug 'nan' conocido). Una fila con Compartimiento nulo forma su propio grupo en el GROUP BY,
   MAX(compAbbr) da NULL, y la vista entera devuelve MD = NULL -> el tema imprime "no encontre
   datos" sin que nadie sepa por que.
   Cura: ISNULL en los 19 sitios donde se calcula compAbbr. Asi la fila SE VE, etiquetada, en vez
   de tumbar el mensaje. Verificado: BLOQUE 161. */

/* ==== vw_HistorialMD (log cronológico de un componente) ==== */
CREATE OR ALTER VIEW [dbo].[vw_HistorialMD] AS
/* 30/09 -- FILTRO ABAJO (mismo patron que curo /condicionmt: 146 s -> 1,4 s, y /diagcompleto).
   La logica va en CROSS APPLY sobre [Mine].[MiningEquipment] y CADA lectura pesada lleva el filtro
   (Equipo = me.[Code]), asi que ninguna rama calcula mas que ese camion. Los CTE van desplegados:
   un APPLY no admite WITH y SQL Server ya los trata como macros. Misma logica y salida. Respaldo: respaldo/DDL_vistas_2026-09-30_antes_filtro_abajo.sql */
SELECT me.[Code] AS Equipo, x.[compAbbr], x.[Observados], x.[Recomendaciones], x.[MD]
FROM [Mine].[MiningEquipment] me
CROSS APPLY (
SELECT
    b.Equipo, b.compAbbr,
    CAST(NULL AS nvarchar(max)) AS Observados,
    CAST(NULL AS nvarchar(max)) AS Recomendaciones,
    CAST(
        N'**Historial — ' + b.Equipo + N' · ' + b.compAbbr + N'** · ' + CAST(b.N AS nvarchar(10)) + N' muestras (recientes arriba)' + NCHAR(10) + NCHAR(10)
      + N'| Fecha | SMR | Hor. Aci. | Met. Obs. | Hrs Comp | T. muestra | Estado |' + NCHAR(10)
      + N'|---|---|---|---|---|---|---|' + NCHAR(10) + b.bodyMD
    AS nvarchar(max)) AS MD
FROM (
    SELECT Equipo, Compartimiento, MAX(compAbbr) AS compAbbr, COUNT(*) AS N,
        STRING_AGG(rowMD, NCHAR(10)) WITHIN GROUP (ORDER BY rn_hist) AS bodyMD
    FROM (
    SELECT s.Equipo, s.Compartimiento, s.compAbbr, s.rn_hist,
        CAST(N'| ' + ISNULL(FORMAT(s.FechaMuestreo,'dd-MMM-yy'),N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(s.Horometro AS decimal(18,0))), N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(s.HorasDeAceite AS decimal(18,0))), N'—')
           + N' | ' + ISNULL(o.obsList, N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(s.HorasComponente AS decimal(18,0))), N'—') + N' | ' + ISNULL(s.CM,N'—') + N' | ' + s.estadoChip + N' |' AS nvarchar(max)) AS rowMD
    FROM (
    SELECT Equipo, Compartimiento, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr, rn_hist, FechaMuestreo, Horometro, HorasDeAceite, HorasComponente, CM,
        CASE WHEN Estado_General LIKE '%CRITIC%' THEN N'🟥' WHEN Estado_General LIKE '%PRECAUC%' THEN N'🟨' WHEN Estado_General LIKE '%OK%' OR Estado_General LIKE '%NORMAL%' THEN N'🟢' ELSE ISNULL(Estado_General,N'—') END AS estadoChip,
        Fe_ppm, Fe_LP, Indice_PQ, PQ_LP, Cr_ppm, Cr_LP, Ni_ppm, Ni_LP, Cu_ppm, Cu_LP,
        Pb_ppm, Pb_LP, Sn_ppm, Sn_LP, Al_ppm, Al_LP, Si_ppm, Si_LP
    FROM (SELECT * FROM [dbo].[vw_MuestrasHistorial] WHERE Equipo = me.[Code]) vw_MuestrasHistorial
    WHERE rn_hist <= 12
) s LEFT JOIN (
    SELECT s.Equipo, s.Compartimiento, s.rn_hist,
        STRING_AGG(CASE WHEN mm.ppm > ISNULL(mm.lp, 9999) THEN CONVERT(nvarchar(20), mm.metal) END, N', ') AS obsList
    FROM (
    SELECT Equipo, Compartimiento, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr, rn_hist, FechaMuestreo, Horometro, HorasDeAceite, HorasComponente, CM,
        CASE WHEN Estado_General LIKE '%CRITIC%' THEN N'🟥' WHEN Estado_General LIKE '%PRECAUC%' THEN N'🟨' WHEN Estado_General LIKE '%OK%' OR Estado_General LIKE '%NORMAL%' THEN N'🟢' ELSE ISNULL(Estado_General,N'—') END AS estadoChip,
        Fe_ppm, Fe_LP, Indice_PQ, PQ_LP, Cr_ppm, Cr_LP, Ni_ppm, Ni_LP, Cu_ppm, Cu_LP,
        Pb_ppm, Pb_LP, Sn_ppm, Sn_LP, Al_ppm, Al_LP, Si_ppm, Si_LP
    FROM (SELECT * FROM [dbo].[vw_MuestrasHistorial] WHERE Equipo = me.[Code]) vw_MuestrasHistorial
    WHERE rn_hist <= 12
) s CROSS APPLY (VALUES
            (N'Fe',Fe_ppm,Fe_LP),
            (N'PQ',Indice_PQ,PQ_LP),
            (N'Cr',Cr_ppm,Cr_LP),
            (N'Ni',Ni_ppm,Ni_LP),
            (N'Cu',Cu_ppm,Cu_LP),
            (N'Pb',Pb_ppm,Pb_LP),
            (N'Sn',Sn_ppm,Sn_LP),
            (N'Al',Al_ppm,Al_LP),
            (N'Si',Si_ppm,Si_LP)
    ) mm(metal, ppm, lp)
    GROUP BY s.Equipo, s.Compartimiento, s.rn_hist
) o ON o.Equipo=s.Equipo AND o.Compartimiento=s.Compartimiento AND o.rn_hist=s.rn_hist
) rows_ GROUP BY Equipo, Compartimiento
) b
) x;
GO


/* ============================================================================
   vw_HistorialFilasMD — P4 (rango): historial en FILAS, 1 fila por MUESTRA. Tema 11.
   POR QUE EXISTE: vw_HistorialMD concatena el markdown DENTRO (STRING_AGG), asi que cuando el flujo ve
   la fila las muestras ya son un string y NO puede filtrar por fecha. Y no podemos parametrizar una vista:
   CREATE FUNCTION esta DENEGADO en esta BD (Msg 262) — solo CREATE OR ALTER VIEW + lectura.

   CONTRATO UNICO de las vistas *FilasMD (8.1) — las 5 variantes de historial exponen lo MISMO para que
   UN solo flujo (MD_historial) las sirva a todas; donde una columna no aplica va constante vacia:
     Equipo · compAbbr · Parametro · Proyecto · FechaMuestreo · rn · TituloMD · SufijoMD · ColsMD · Fila
   El flujo arma:  MAX(TituloMD) + COUNT(*) + MAX(SufijoMD) + salto + MAX(ColsMD) + salto + STRING_AGG(Fila)
   (el conteo lo pone el flujo porque depende del rango; por eso el titulo va partido en Titulo+Sufijo).
   Mismo patron que vw_RankingMD, que ya expone HeaderMD y deja que el flujo concatene.

   ⚠ Fila es IDENTICA al rowMD de vw_HistorialMD (verificado por hash, BLOQUE 72) -> sin rango la salida
   es byte a byte la de hoy.
   PERF: la lista de metales se arma FILA A FILA con STUFF(CONCAT(...)), sin GROUP BY ni JOIN (medido:
   la version con CTE obs + JOIN tardaba 5m22s; esta, 9s). Orden fijo Fe,PQ,Cr,Ni,Cu,Pb,Sn,Al,Si.
   TOPE 200 = seguridad de canal (59 chars/fila max -> ~11 800 chars, muy bajo los ~28 000 de Teams).
   Validacion: VALIDACION_SSMS.sql BLOQUE 72.
   ---------------------------------------------------------------------------- */
CREATE OR ALTER VIEW [dbo].[vw_HistorialFilasMD] AS
WITH s AS (
    SELECT Equipo, Proyecto, Compartimiento, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr, rn_hist, FechaMuestreo, Horometro, HorasDeAceite, HorasComponente, CM,
        CASE WHEN Estado_General LIKE '%CRITIC%' THEN N'🟥' WHEN Estado_General LIKE '%PRECAUC%' THEN N'🟨' WHEN Estado_General LIKE '%OK%' OR Estado_General LIKE '%NORMAL%' THEN N'🟢' ELSE ISNULL(Estado_General,N'—') END AS estadoChip,
        /* metales fuera de LP, fila a fila (sin GROUP BY ni JOIN). Mismo orden y separador ', ' que el STRING_AGG original */
        STUFF(CONCAT(
            CASE WHEN Fe_ppm    > ISNULL(Fe_LP,9999) THEN N', Fe' ELSE N'' END,
            CASE WHEN Indice_PQ > ISNULL(PQ_LP,9999) THEN N', PQ' ELSE N'' END,
            CASE WHEN Cr_ppm    > ISNULL(Cr_LP,9999) THEN N', Cr' ELSE N'' END,
            CASE WHEN Ni_ppm    > ISNULL(Ni_LP,9999) THEN N', Ni' ELSE N'' END,
            CASE WHEN Cu_ppm    > ISNULL(Cu_LP,9999) THEN N', Cu' ELSE N'' END,
            CASE WHEN Pb_ppm    > ISNULL(Pb_LP,9999) THEN N', Pb' ELSE N'' END,
            CASE WHEN Sn_ppm    > ISNULL(Sn_LP,9999) THEN N', Sn' ELSE N'' END,
            CASE WHEN Al_ppm    > ISNULL(Al_LP,9999) THEN N', Al' ELSE N'' END,
            CASE WHEN Si_ppm    > ISNULL(Si_LP,9999) THEN N', Si' ELSE N'' END
        ), 1, 2, N'') AS obsList
    FROM [dbo].[vw_MuestrasHistorial]
    WHERE rn_hist <= 200
)
SELECT
    Equipo, compAbbr, CAST(N'' AS nvarchar(20)) AS Parametro, Proyecto, FechaMuestreo,
    rn_hist AS rn,
    CAST(N'**Historial — ' + Equipo + N' · ' + compAbbr + N'** · ' AS nvarchar(max))            AS TituloMD,
    CAST(N' muestras (recientes arriba)' AS nvarchar(max))                                      AS SufijoMD,
    CAST(N'| Fecha | SMR | Hor. Aci. | Met. Obs. | Hrs Comp | T. muestra | Estado |' + NCHAR(10)
       + N'|---|---|---|---|---|---|---|' AS nvarchar(max))                                     AS ColsMD,
    CAST(N'| ' + ISNULL(FORMAT(FechaMuestreo,'dd-MMM-yy'),N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(Horometro AS decimal(18,0))), N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(HorasDeAceite AS decimal(18,0))), N'—')
       + N' | ' + ISNULL(obsList, N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(HorasComponente AS decimal(18,0))), N'—') + N' | ' + ISNULL(CM,N'—') + N' | ' + estadoChip + N' |' AS nvarchar(max)) AS Fila
FROM s;
GO


/* ============================================================================
   vw_HistorialEquipoFilasMD — P4 (8.2) · Tema 12 «Historial general del equipo».
   Filas de vw_HistorialEquipoMD, con el CONTRATO UNICO *FilasMD. Tope 24 -> 200.
   PERF: obsList fila a fila con STUFF(CONCAT(...)) — sin el CTE obs (GROUP BY + LEFT JOIN) del original.
   ---------------------------------------------------------------------------- */
CREATE OR ALTER VIEW [dbo].[vw_HistorialEquipoFilasMD] AS
WITH s0 AS (
    SELECT Equipo, Proyecto, Compartimiento, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr, FechaMuestreo, Horometro, HorasDeAceite, CM,
        CASE WHEN Estado_General LIKE '%CRITIC%' THEN N'🟥' WHEN Estado_General LIKE '%PRECAUC%' THEN N'🟨' WHEN Estado_General LIKE '%OK%' OR Estado_General LIKE '%NORMAL%' THEN N'🟢' ELSE ISNULL(Estado_General,N'—') END AS estadoChip,
        STUFF(CONCAT(
            CASE WHEN Fe_ppm    > ISNULL(Fe_LP,9999) THEN N', Fe' ELSE N'' END,
            CASE WHEN Indice_PQ > ISNULL(PQ_LP,9999) THEN N', PQ' ELSE N'' END,
            CASE WHEN Cr_ppm    > ISNULL(Cr_LP,9999) THEN N', Cr' ELSE N'' END,
            CASE WHEN Ni_ppm    > ISNULL(Ni_LP,9999) THEN N', Ni' ELSE N'' END,
            CASE WHEN Cu_ppm    > ISNULL(Cu_LP,9999) THEN N', Cu' ELSE N'' END,
            CASE WHEN Pb_ppm    > ISNULL(Pb_LP,9999) THEN N', Pb' ELSE N'' END,
            CASE WHEN Sn_ppm    > ISNULL(Sn_LP,9999) THEN N', Sn' ELSE N'' END,
            CASE WHEN Al_ppm    > ISNULL(Al_LP,9999) THEN N', Al' ELSE N'' END,
            CASE WHEN Si_ppm    > ISNULL(Si_LP,9999) THEN N', Si' ELSE N'' END
        ), 1, 2, N'') AS obsList,
        ROW_NUMBER() OVER (PARTITION BY Equipo ORDER BY FechaMuestreo DESC, Compartimiento, LaboratoryDataId) AS grn
    FROM [dbo].[vw_MuestrasHistorial]
)
SELECT
    Equipo, compAbbr, CAST(N'' AS nvarchar(20)) AS Parametro, Proyecto, FechaMuestreo, grn AS rn,
    CAST(N'**Historial del equipo — ' + Equipo + N'** · ' AS nvarchar(max))                     AS TituloMD,
    CAST(N' muestras (todos los componentes, recientes arriba)' AS nvarchar(max))               AS SufijoMD,
    CAST(N'| Fecha | SMR | Hor. Aci. | Met. Obs. | Componente | T. muestra | Estado |' + NCHAR(10)
       + N'|---|---|---|---|---|---|---|' AS nvarchar(max))                                     AS ColsMD,
    CAST(N'| ' + ISNULL(FORMAT(FechaMuestreo,'dd-MMM-yy'),N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(Horometro AS decimal(18,0))), N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(HorasDeAceite AS decimal(18,0))), N'—')
       + N' | ' + ISNULL(obsList, N'—') + N' | ' + compAbbr + N' | ' + ISNULL(CM,N'—') + N' | ' + estadoChip + N' |' AS nvarchar(max)) AS Fila
FROM s0
WHERE grn <= 200;
GO


/* ============================================================================
   vw_HistorialFlotaFilasMD — P4 (8.2) · Tema 15 «Historial de observados de flota».
   Filas de vw_HistorialFlotaMD. SOLO observados (mismo filtro que el original). Tope 24 -> 200.
   ⚠ Su tabla tiene 5 columnas (no 7): por eso ColsMD sale de la vista y no del flujo.
   ---------------------------------------------------------------------------- */
CREATE OR ALTER VIEW [dbo].[vw_HistorialFlotaFilasMD] AS
WITH s0 AS (
    SELECT Proyecto, Equipo, Compartimiento, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr, FechaMuestreo,
        CASE WHEN Estado_General LIKE '%CRITIC%' THEN N'🟥' WHEN Estado_General LIKE '%PRECAUC%' THEN N'🟨' WHEN Estado_General LIKE '%OK%' OR Estado_General LIKE '%NORMAL%' THEN N'🟢' ELSE ISNULL(Estado_General,N'—') END AS estadoChip,
        STUFF(CONCAT(
            CASE WHEN Fe_ppm    > ISNULL(Fe_LP,9999) THEN N', Fe' ELSE N'' END,
            CASE WHEN Indice_PQ > ISNULL(PQ_LP,9999) THEN N', PQ' ELSE N'' END,
            CASE WHEN Cr_ppm    > ISNULL(Cr_LP,9999) THEN N', Cr' ELSE N'' END,
            CASE WHEN Ni_ppm    > ISNULL(Ni_LP,9999) THEN N', Ni' ELSE N'' END,
            CASE WHEN Cu_ppm    > ISNULL(Cu_LP,9999) THEN N', Cu' ELSE N'' END,
            CASE WHEN Pb_ppm    > ISNULL(Pb_LP,9999) THEN N', Pb' ELSE N'' END,
            CASE WHEN Sn_ppm    > ISNULL(Sn_LP,9999) THEN N', Sn' ELSE N'' END,
            CASE WHEN Al_ppm    > ISNULL(Al_LP,9999) THEN N', Al' ELSE N'' END,
            CASE WHEN Si_ppm    > ISNULL(Si_LP,9999) THEN N', Si' ELSE N'' END
        ), 1, 2, N'') AS obsList,
        ROW_NUMBER() OVER (PARTITION BY Proyecto ORDER BY FechaMuestreo DESC, Equipo, Compartimiento, LaboratoryDataId) AS grn
    FROM [dbo].[vw_MuestrasHistorial]
    WHERE Estado_General NOT LIKE '%OK%' AND Estado_General NOT LIKE '%NORMAL%'
)
SELECT
    Equipo, compAbbr, CAST(N'' AS nvarchar(20)) AS Parametro, Proyecto, FechaMuestreo, grn AS rn,
    CAST(N'**Historial de observados — flota ' + Proyecto + N'** · últimos ' AS nvarchar(max))  AS TituloMD,
    CAST(N' registros observados (recientes arriba)' AS nvarchar(max))                          AS SufijoMD,
    CAST(N'| Fecha | Equipo | Componente | Estado | Observados |' + NCHAR(10)
       + N'|---|---|---|---|---|' AS nvarchar(max))                                             AS ColsMD,
    CAST(N'| ' + ISNULL(FORMAT(FechaMuestreo,'dd-MMM-yy'),N'—') + N' | ' + Equipo + N' | ' + compAbbr
       + N' | ' + estadoChip + N' | ' + ISNULL(obsList, N'—') + N' |' AS nvarchar(max))          AS Fila
FROM s0
WHERE grn <= 200;
GO


/* ============================================================================
   vw_HistorialMetalFilasMD — P4 (8.2) · Tema 14 «Historial de un metal en un componente».
   Filas de vw_HistorialMetalMD. 1 fila por muestra x metal. Tope rn_hist 12 -> 200.
   ⚠ ColsMD y TituloMD son DINAMICOS (llevan el nombre del metal y sus LP/LC).
   LP/LC se fijan por ventana para que TituloMD sea IGUAL en todas las filas del grupo
   (el original usaba MAX(LP)/MAX(LC) al agregar; MAX(TituloMD) en el flujo exige que no varie).
   ---------------------------------------------------------------------------- */
CREATE OR ALTER VIEW [dbo].[vw_HistorialMetalFilasMD] AS
WITH s AS (
    SELECT Equipo, Proyecto, Compartimiento, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr, rn_hist, FechaMuestreo, Horometro, HorasDeAceite, HorasComponente, CM,
        CASE WHEN Estado_General LIKE '%CRITIC%' THEN N'🟥' WHEN Estado_General LIKE '%PRECAUC%' THEN N'🟨' WHEN Estado_General LIKE '%OK%' OR Estado_General LIKE '%NORMAL%' THEN N'🟢' ELSE ISNULL(Estado_General,N'—') END AS estadoChip,
        Fe_ppm, Fe_LP, Fe_LC, Indice_PQ, PQ_LP, PQ_LC, Cr_ppm, Cr_LP, Cr_LC, Ni_ppm, Ni_LP, Ni_LC,
        Cu_ppm, Cu_LP, Cu_LC, Pb_ppm, Pb_LP, Pb_LC, Sn_ppm, Sn_LP, Sn_LC, Al_ppm, Al_LP, Al_LC, Si_ppm, Si_LP, Si_LC,
        Ca_ppm, Ca_LP, Ca_LC, Zn_ppm, Zn_LP, Zn_LC, K_ppm, K_LP, K_LC, Na_ppm, Na_LP, Na_LC,
        Mg_ppm, Mg_LP, Mg_LC, B_ppm, P_ppm, V100, TBN, TBN_LP
    FROM [dbo].[vw_MuestrasHistorial]
    WHERE rn_hist <= 200
),
u AS (
    SELECT s.Equipo, s.Proyecto, s.Compartimiento, s.compAbbr, s.rn_hist, s.FechaMuestreo, s.Horometro, s.HorasDeAceite, s.HorasComponente, s.CM, s.estadoChip,
        CONVERT(nvarchar(20), m.metal) AS Parametro, CAST(m.Valor AS decimal(18,2)) AS Valor,
        MAX(CAST(m.LP AS decimal(18,2))) OVER (PARTITION BY s.Equipo, s.Compartimiento, m.metal) AS LPg,
        MAX(CAST(m.LC AS decimal(18,2))) OVER (PARTITION BY s.Equipo, s.Compartimiento, m.metal) AS LCg,
        CAST(m.LP AS decimal(18,2)) AS LP, CAST(m.LC AS decimal(18,2)) AS LC
    FROM s CROSS APPLY (VALUES
            (N'Fe',Fe_ppm,Fe_LP,Fe_LC), (N'PQ',Indice_PQ,PQ_LP,PQ_LC), (N'Cr',Cr_ppm,Cr_LP,Cr_LC),
            (N'Ni',Ni_ppm,Ni_LP,Ni_LC), (N'Cu',Cu_ppm,Cu_LP,Cu_LC), (N'Pb',Pb_ppm,Pb_LP,Pb_LC),
            (N'Sn',Sn_ppm,Sn_LP,Sn_LC), (N'Al',Al_ppm,Al_LP,Al_LC), (N'Si',Si_ppm,Si_LP,Si_LC),
            (N'Ca',Ca_ppm,Ca_LP,Ca_LC), (N'Zn',Zn_ppm,Zn_LP,Zn_LC), (N'K',K_ppm,K_LP,K_LC),
            (N'Na',Na_ppm,Na_LP,Na_LC), (N'Mg',Mg_ppm,Mg_LP,Mg_LC), (N'B',B_ppm,NULL,NULL),
            (N'P',P_ppm,NULL,NULL), (N'V100',V100,NULL,NULL), (N'TBN',TBN,TBN_LP,NULL)
    ) m(metal, Valor, LP, LC)
)
SELECT
    Equipo, compAbbr, Parametro, Proyecto, FechaMuestreo, rn_hist AS rn,
    CAST(N'**Historial de ' + Parametro + N' — ' + Equipo + N' · ' + compAbbr + N'**'
       + N' · LP ' + ISNULL(CONVERT(nvarchar(20),CAST(LPg AS decimal(18,1))),N'—')
       + N' · LC ' + ISNULL(CONVERT(nvarchar(20),CAST(LCg AS decimal(18,1))),N'—')
       + N' · ' AS nvarchar(max))                                                               AS TituloMD,
    CAST(N' muestras (recientes arriba)' AS nvarchar(max))                                      AS SufijoMD,
    CAST(N'| Fecha | SMR | Hor. Aci. | ' + Parametro + N' | Hrs Comp | T. muestra | Estado |' + NCHAR(10)
       + N'|---|---|---|---|---|---|---|' AS nvarchar(max))                                     AS ColsMD,
    CAST(N'| ' + ISNULL(FORMAT(FechaMuestreo,'dd-MMM-yy'),N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(Horometro AS decimal(18,0))), N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(HorasDeAceite AS decimal(18,0))), N'—')
       + N' | ' + ISNULL(CASE WHEN Valor > ISNULL(LC,999999) THEN CONVERT(nvarchar(20),CAST(Valor AS decimal(18,1)))+N' 🟥' WHEN Valor > ISNULL(LP,999999) THEN CONVERT(nvarchar(20),CAST(Valor AS decimal(18,1)))+N' 🟨' ELSE CONVERT(nvarchar(20),CAST(Valor AS decimal(18,1))) END, N'—')
       + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(HorasComponente AS decimal(18,0))), N'—') + N' | ' + ISNULL(CM,N'—') + N' | ' + estadoChip + N' |' AS nvarchar(max)) AS Fila
FROM u;
GO


/* ============================================================================
   vw_HistorialMetalEquipoFilasMD — P4 (8.2) · Tema 13 «Historial de un metal en el equipo».
   Filas de vw_HistorialMetalEquipoMD (metal en TODOS los componentes). Tope grn 24 -> 200.
   ⚠ ColsMD dinamico (lleva el metal). El original NO muestra LP/LC en el titulo (a diferencia del Tema 14).
   ---------------------------------------------------------------------------- */
CREATE OR ALTER VIEW [dbo].[vw_HistorialMetalEquipoFilasMD] AS
WITH s0 AS (
    SELECT Equipo, Proyecto, Compartimiento, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr, FechaMuestreo, Horometro, HorasDeAceite, CM,
        CASE WHEN Estado_General LIKE '%CRITIC%' THEN N'🟥' WHEN Estado_General LIKE '%PRECAUC%' THEN N'🟨' WHEN Estado_General LIKE '%OK%' OR Estado_General LIKE '%NORMAL%' THEN N'🟢' ELSE ISNULL(Estado_General,N'—') END AS estadoChip,
        Fe_ppm,Fe_LP,Fe_LC,Indice_PQ,PQ_LP,PQ_LC,Cr_ppm,Cr_LP,Cr_LC,Ni_ppm,Ni_LP,Ni_LC,Cu_ppm,Cu_LP,Cu_LC,
        Pb_ppm,Pb_LP,Pb_LC,Sn_ppm,Sn_LP,Sn_LC,Al_ppm,Al_LP,Al_LC,Si_ppm,Si_LP,Si_LC,Ca_ppm,Ca_LP,Ca_LC,Zn_ppm,Zn_LP,Zn_LC,
        K_ppm,K_LP,K_LC,Na_ppm,Na_LP,Na_LC,Mg_ppm,Mg_LP,Mg_LC,B_ppm,P_ppm,V100,TBN,TBN_LP,
        ROW_NUMBER() OVER (PARTITION BY Equipo ORDER BY FechaMuestreo DESC, Compartimiento, LaboratoryDataId) AS grn
    FROM [dbo].[vw_MuestrasHistorial]
),
s AS (SELECT * FROM s0 WHERE grn <= 200),
u AS (
    SELECT s.Equipo, s.Proyecto, s.compAbbr, s.grn, s.FechaMuestreo, s.Horometro, s.HorasDeAceite, s.CM, s.estadoChip,
        CONVERT(nvarchar(20), m.metal) AS Parametro, CAST(m.Valor AS decimal(18,2)) AS Valor,
        CAST(m.LP AS decimal(18,2)) AS LP, CAST(m.LC AS decimal(18,2)) AS LC
    FROM s CROSS APPLY (VALUES
            (N'Fe',Fe_ppm,Fe_LP,Fe_LC), (N'PQ',Indice_PQ,PQ_LP,PQ_LC), (N'Cr',Cr_ppm,Cr_LP,Cr_LC),
            (N'Ni',Ni_ppm,Ni_LP,Ni_LC), (N'Cu',Cu_ppm,Cu_LP,Cu_LC), (N'Pb',Pb_ppm,Pb_LP,Pb_LC),
            (N'Sn',Sn_ppm,Sn_LP,Sn_LC), (N'Al',Al_ppm,Al_LP,Al_LC), (N'Si',Si_ppm,Si_LP,Si_LC),
            (N'Ca',Ca_ppm,Ca_LP,Ca_LC), (N'Zn',Zn_ppm,Zn_LP,Zn_LC), (N'K',K_ppm,K_LP,K_LC),
            (N'Na',Na_ppm,Na_LP,Na_LC), (N'Mg',Mg_ppm,Mg_LP,Mg_LC), (N'B',B_ppm,NULL,NULL),
            (N'P',P_ppm,NULL,NULL), (N'V100',V100,NULL,NULL), (N'TBN',TBN,TBN_LP,NULL)
    ) m(metal, Valor, LP, LC)
)
SELECT
    Equipo, compAbbr, Parametro, Proyecto, FechaMuestreo, grn AS rn,
    CAST(N'**Historial de ' + Parametro + N' — ' + Equipo + N' (todos los componentes)** · ' AS nvarchar(max)) AS TituloMD,
    CAST(N' muestras (recientes arriba)' AS nvarchar(max))                                      AS SufijoMD,
    CAST(N'| Fecha | SMR | Hor. Aci. | ' + Parametro + N' | Componente | T. muestra | Estado |' + NCHAR(10)
       + N'|---|---|---|---|---|---|---|' AS nvarchar(max))                                     AS ColsMD,
    CAST(N'| ' + ISNULL(FORMAT(FechaMuestreo,'dd-MMM-yy'),N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(Horometro AS decimal(18,0))), N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(HorasDeAceite AS decimal(18,0))), N'—')
       + N' | ' + ISNULL(CASE WHEN Valor > ISNULL(LC,999999) THEN CONVERT(nvarchar(20),CAST(Valor AS decimal(18,1)))+N' 🟥' WHEN Valor > ISNULL(LP,999999) THEN CONVERT(nvarchar(20),CAST(Valor AS decimal(18,1)))+N' 🟨' ELSE CONVERT(nvarchar(20),CAST(Valor AS decimal(18,1))) END, N'—')
       + N' | ' + compAbbr + N' | ' + ISNULL(CM,N'—') + N' | ' + estadoChip + N' |' AS nvarchar(max)) AS Fila
FROM u;
GO


/* ==== vw_HistorialMetalMD (historial de un metal en un componente) ==== */
CREATE OR ALTER VIEW [dbo].[vw_HistorialMetalMD] AS
WITH s AS (
    SELECT Equipo, Compartimiento, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr, rn_hist, FechaMuestreo, Horometro, HorasDeAceite, HorasComponente, CM, CASE WHEN Estado_General LIKE '%CRITIC%' THEN N'🟥' WHEN Estado_General LIKE '%PRECAUC%' THEN N'🟨' WHEN Estado_General LIKE '%OK%' OR Estado_General LIKE '%NORMAL%' THEN N'🟢' ELSE ISNULL(Estado_General,N'—') END AS estadoChip,
        Fe_ppm, Fe_LP, Fe_LC, Indice_PQ, PQ_LP, PQ_LC, Cr_ppm, Cr_LP, Cr_LC, Ni_ppm, Ni_LP, Ni_LC,
        Cu_ppm, Cu_LP, Cu_LC, Pb_ppm, Pb_LP, Pb_LC, Sn_ppm, Sn_LP, Sn_LC, Al_ppm, Al_LP, Al_LC, Si_ppm, Si_LP, Si_LC,
        Ca_ppm, Ca_LP, Ca_LC, Zn_ppm, Zn_LP, Zn_LC, K_ppm, K_LP, K_LC, Na_ppm, Na_LP, Na_LC,
        Mg_ppm, Mg_LP, Mg_LC, B_ppm, P_ppm, V100, TBN, TBN_LP
    FROM [dbo].[vw_MuestrasHistorial]
    WHERE rn_hist <= 12
),
u AS (
    SELECT s.Equipo, s.Compartimiento, s.compAbbr, s.rn_hist, s.FechaMuestreo, s.Horometro, s.HorasDeAceite, s.HorasComponente, s.CM, s.estadoChip,
        CONVERT(nvarchar(20), m.metal) AS Parametro, CAST(m.Valor AS decimal(18,2)) AS Valor,
        CAST(m.LP AS decimal(18,2)) AS LP, CAST(m.LC AS decimal(18,2)) AS LC
    FROM s CROSS APPLY (VALUES
            (N'Fe',Fe_ppm,Fe_LP,Fe_LC),
            (N'PQ',Indice_PQ,PQ_LP,PQ_LC),
            (N'Cr',Cr_ppm,Cr_LP,Cr_LC),
            (N'Ni',Ni_ppm,Ni_LP,Ni_LC),
            (N'Cu',Cu_ppm,Cu_LP,Cu_LC),
            (N'Pb',Pb_ppm,Pb_LP,Pb_LC),
            (N'Sn',Sn_ppm,Sn_LP,Sn_LC),
            (N'Al',Al_ppm,Al_LP,Al_LC),
            (N'Si',Si_ppm,Si_LP,Si_LC),
            (N'Ca',Ca_ppm,Ca_LP,Ca_LC),
            (N'Zn',Zn_ppm,Zn_LP,Zn_LC),
            (N'K',K_ppm,K_LP,K_LC),
            (N'Na',Na_ppm,Na_LP,Na_LC),
            (N'Mg',Mg_ppm,Mg_LP,Mg_LC),
            (N'B',B_ppm,NULL,NULL),
            (N'P',P_ppm,NULL,NULL),
            (N'V100',V100,NULL,NULL),
            (N'TBN',TBN,TBN_LP,NULL)
    ) m(metal, Valor, LP, LC)
),
rows_ AS (
    SELECT Equipo, Compartimiento, compAbbr, Parametro, rn_hist, LP, LC,
        CAST(N'| ' + ISNULL(FORMAT(FechaMuestreo,'dd-MMM-yy'),N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(Horometro AS decimal(18,0))), N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(HorasDeAceite AS decimal(18,0))), N'—') + N' | ' + ISNULL(CASE WHEN u.Valor > ISNULL(u.LC,999999) THEN CONVERT(nvarchar(20),CAST(u.Valor AS decimal(18,1)))+N' 🟥' WHEN u.Valor > ISNULL(u.LP,999999) THEN CONVERT(nvarchar(20),CAST(u.Valor AS decimal(18,1)))+N' 🟨' ELSE CONVERT(nvarchar(20),CAST(u.Valor AS decimal(18,1))) END, N'—')
           + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(HorasComponente AS decimal(18,0))), N'—') + N' | ' + ISNULL(CM,N'—') + N' | ' + estadoChip + N' |' AS nvarchar(max)) AS rowMD
    FROM u
),
body AS (
    SELECT Equipo, Compartimiento, MAX(compAbbr) AS compAbbr, Parametro,
        MAX(LP) AS LP, MAX(LC) AS LC, COUNT(*) AS N,
        STRING_AGG(rowMD, NCHAR(10)) WITHIN GROUP (ORDER BY rn_hist) AS bodyMD
    FROM rows_
    GROUP BY Equipo, Compartimiento, Parametro
)
SELECT
    b.Equipo, b.compAbbr, b.Parametro,
    CAST(NULL AS nvarchar(max)) AS Observados,
    CAST(NULL AS nvarchar(max)) AS Recomendaciones,
    CAST(
        N'**Historial de ' + b.Parametro + N' — ' + b.Equipo + N' · ' + b.compAbbr + N'**'
      + N' · LP ' + ISNULL(CONVERT(nvarchar(20),CAST(b.LP AS decimal(18,1))),N'—')
      + N' · LC ' + ISNULL(CONVERT(nvarchar(20),CAST(b.LC AS decimal(18,1))),N'—')
      + N' · ' + CAST(b.N AS nvarchar(10)) + N' muestras (recientes arriba)' + NCHAR(10) + NCHAR(10)
      + N'| Fecha | SMR | Hor. Aci. | ' + b.Parametro + N' | Hrs Comp | T. muestra | Estado |' + NCHAR(10)
      + N'|---|---|---|---|---|---|---|' + NCHAR(10) + b.bodyMD
    AS nvarchar(max)) AS MD
FROM body b;
GO


/* ==== vw_HistorialEquipoMD ==== */
CREATE OR ALTER VIEW [dbo].[vw_HistorialEquipoMD] AS
/* 30/09 -- FILTRO ABAJO (mismo patron que curo /condicionmt: 146 s -> 1,4 s, y /diagcompleto).
   La logica va en CROSS APPLY sobre [Mine].[MiningEquipment] y CADA lectura pesada lleva el filtro
   (Equipo = me.[Code]), asi que ninguna rama calcula mas que ese camion. Los CTE van desplegados:
   un APPLY no admite WITH y SQL Server ya los trata como macros. Misma logica y salida. Respaldo: respaldo/DDL_vistas_2026-09-30_antes_filtro_abajo.sql */
SELECT me.[Code] AS Equipo, x.[Observados], x.[Recomendaciones], x.[MD]
FROM [Mine].[MiningEquipment] me
CROSS APPLY (
SELECT b.Equipo,
    CAST(NULL AS nvarchar(max)) AS Observados, CAST(NULL AS nvarchar(max)) AS Recomendaciones,
    CAST(N'**Historial del equipo — ' + b.Equipo + N'** · ' + CAST(b.N AS nvarchar(10)) + N' muestras (todos los componentes, recientes arriba)' + NCHAR(10) + NCHAR(10)
       + N'| Fecha | SMR | Hor. Aci. | Met. Obs. | Componente | T. muestra | Estado |' + NCHAR(10) + N'|---|---|---|---|---|---|---|' + NCHAR(10) + b.bodyMD
    AS nvarchar(max)) AS MD
FROM (SELECT Equipo, COUNT(*) AS N, STRING_AGG(rowMD, NCHAR(10)) WITHIN GROUP (ORDER BY grn) AS bodyMD FROM (
    SELECT s.Equipo, s.grn,
        CAST(N'| ' + ISNULL(FORMAT(s.FechaMuestreo,'dd-MMM-yy'),N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(s.Horometro AS decimal(18,0))), N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(s.HorasDeAceite AS decimal(18,0))), N'—')
           + N' | ' + ISNULL(o.obsList, N'—') + N' | ' + s.compAbbr + N' | ' + ISNULL(s.CM,N'—') + N' | ' + s.estadoChip + N' |' AS nvarchar(max)) AS rowMD
    FROM (SELECT * FROM (
    SELECT Equipo, Compartimiento, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr, rn_hist, FechaMuestreo, Horometro, HorasDeAceite, CM, CASE WHEN Estado_General LIKE '%CRITIC%' THEN N'🟥' WHEN Estado_General LIKE '%PRECAUC%' THEN N'🟨' WHEN Estado_General LIKE '%OK%' OR Estado_General LIKE '%NORMAL%' THEN N'🟢' ELSE ISNULL(Estado_General,N'—') END AS estadoChip,
        Fe_ppm,Fe_LP,Indice_PQ,PQ_LP,Cr_ppm,Cr_LP,Ni_ppm,Ni_LP,Cu_ppm,Cu_LP,Pb_ppm,Pb_LP,Sn_ppm,Sn_LP,Al_ppm,Al_LP,Si_ppm,Si_LP,
        ROW_NUMBER() OVER (PARTITION BY Equipo ORDER BY FechaMuestreo DESC, Compartimiento, LaboratoryDataId) AS grn
    FROM (SELECT * FROM [dbo].[vw_MuestrasHistorial] WHERE Equipo = me.[Code]) vw_MuestrasHistorial
) s0 WHERE grn <= 24) s LEFT JOIN (
    SELECT s.Equipo, s.Compartimiento, s.rn_hist,
        STRING_AGG(CASE WHEN mm.ppm > ISNULL(mm.lp,9999) THEN CONVERT(nvarchar(20), mm.metal) END, N', ') AS obsList
    FROM (SELECT * FROM (
    SELECT Equipo, Compartimiento, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr, rn_hist, FechaMuestreo, Horometro, HorasDeAceite, CM, CASE WHEN Estado_General LIKE '%CRITIC%' THEN N'🟥' WHEN Estado_General LIKE '%PRECAUC%' THEN N'🟨' WHEN Estado_General LIKE '%OK%' OR Estado_General LIKE '%NORMAL%' THEN N'🟢' ELSE ISNULL(Estado_General,N'—') END AS estadoChip,
        Fe_ppm,Fe_LP,Indice_PQ,PQ_LP,Cr_ppm,Cr_LP,Ni_ppm,Ni_LP,Cu_ppm,Cu_LP,Pb_ppm,Pb_LP,Sn_ppm,Sn_LP,Al_ppm,Al_LP,Si_ppm,Si_LP,
        ROW_NUMBER() OVER (PARTITION BY Equipo ORDER BY FechaMuestreo DESC, Compartimiento, LaboratoryDataId) AS grn
    FROM (SELECT * FROM [dbo].[vw_MuestrasHistorial] WHERE Equipo = me.[Code]) vw_MuestrasHistorial
) s0 WHERE grn <= 24) s CROSS APPLY (VALUES
            (N'Fe',Fe_ppm,Fe_LP),
            (N'PQ',Indice_PQ,PQ_LP),
            (N'Cr',Cr_ppm,Cr_LP),
            (N'Ni',Ni_ppm,Ni_LP),
            (N'Cu',Cu_ppm,Cu_LP),
            (N'Pb',Pb_ppm,Pb_LP),
            (N'Sn',Sn_ppm,Sn_LP),
            (N'Al',Al_ppm,Al_LP),
            (N'Si',Si_ppm,Si_LP)
    ) mm(metal, ppm, lp)
    GROUP BY s.Equipo, s.Compartimiento, s.rn_hist
) o ON o.Equipo=s.Equipo AND o.Compartimiento=s.Compartimiento AND o.rn_hist=s.rn_hist
) rows_ GROUP BY Equipo) b
) x;
GO


/* ==== vw_HistorialFlotaMD ==== */
CREATE OR ALTER VIEW [dbo].[vw_HistorialFlotaMD] AS
WITH s0 AS (
    SELECT Proyecto, Equipo, Compartimiento, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr, rn_hist, FechaMuestreo, Estado_General, CASE WHEN Estado_General LIKE '%CRITIC%' THEN N'🟥' WHEN Estado_General LIKE '%PRECAUC%' THEN N'🟨' WHEN Estado_General LIKE '%OK%' OR Estado_General LIKE '%NORMAL%' THEN N'🟢' ELSE ISNULL(Estado_General,N'—') END AS estadoChip,
        Fe_ppm,Fe_LP,Indice_PQ,PQ_LP,Cr_ppm,Cr_LP,Ni_ppm,Ni_LP,Cu_ppm,Cu_LP,Pb_ppm,Pb_LP,Sn_ppm,Sn_LP,Al_ppm,Al_LP,Si_ppm,Si_LP,
        ROW_NUMBER() OVER (PARTITION BY Proyecto ORDER BY FechaMuestreo DESC, Equipo, Compartimiento, LaboratoryDataId) AS grn
    FROM [dbo].[vw_MuestrasHistorial]
    WHERE Estado_General NOT LIKE '%OK%' AND Estado_General NOT LIKE '%NORMAL%'
),
s AS (SELECT * FROM s0 WHERE grn <= 24),
obs AS (
    SELECT s.Equipo, s.Compartimiento, s.rn_hist,
        STRING_AGG(CASE WHEN mm.ppm > ISNULL(mm.lp,9999) THEN CONVERT(nvarchar(20), mm.metal) END, N', ') AS obsList
    FROM s CROSS APPLY (VALUES
            (N'Fe',Fe_ppm,Fe_LP),
            (N'PQ',Indice_PQ,PQ_LP),
            (N'Cr',Cr_ppm,Cr_LP),
            (N'Ni',Ni_ppm,Ni_LP),
            (N'Cu',Cu_ppm,Cu_LP),
            (N'Pb',Pb_ppm,Pb_LP),
            (N'Sn',Sn_ppm,Sn_LP),
            (N'Al',Al_ppm,Al_LP),
            (N'Si',Si_ppm,Si_LP)
    ) mm(metal, ppm, lp)
    GROUP BY s.Equipo, s.Compartimiento, s.rn_hist
),
rows_ AS (
    SELECT s.Proyecto, s.grn,
        CAST(N'| ' + ISNULL(FORMAT(s.FechaMuestreo,'dd-MMM-yy'),N'—') + N' | ' + s.Equipo + N' | ' + s.compAbbr
           + N' | ' + s.estadoChip + N' | ' + ISNULL(o.obsList, N'—') + N' |' AS nvarchar(max)) AS rowMD
    FROM s LEFT JOIN obs o ON o.Equipo=s.Equipo AND o.Compartimiento=s.Compartimiento AND o.rn_hist=s.rn_hist
),
body AS (SELECT Proyecto, COUNT(*) AS N, STRING_AGG(rowMD, NCHAR(10)) WITHIN GROUP (ORDER BY grn) AS bodyMD FROM rows_ GROUP BY Proyecto)
SELECT b.Proyecto, N'(todos)' AS Modelo,
    CAST(NULL AS nvarchar(max)) AS Observados, CAST(NULL AS nvarchar(max)) AS Recomendaciones,
    CAST(N'**Historial de observados — flota ' + b.Proyecto + N'** · últimos ' + CAST(b.N AS nvarchar(10)) + N' registros observados (recientes arriba)' + NCHAR(10) + NCHAR(10)
       + N'| Fecha | Equipo | Componente | Estado | Observados |' + NCHAR(10) + N'|---|---|---|---|---|' + NCHAR(10) + b.bodyMD
    AS nvarchar(max)) AS MD
FROM body b;
GO


/* ==== vw_HistorialMetalEquipoMD (variante 2: metal en todos los componentes) ==== */
CREATE OR ALTER VIEW [dbo].[vw_HistorialMetalEquipoMD] AS
WITH s0 AS (
    SELECT Equipo, Compartimiento, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr, FechaMuestreo, Horometro, HorasDeAceite, CM, CASE WHEN Estado_General LIKE '%CRITIC%' THEN N'🟥' WHEN Estado_General LIKE '%PRECAUC%' THEN N'🟨' WHEN Estado_General LIKE '%OK%' OR Estado_General LIKE '%NORMAL%' THEN N'🟢' ELSE ISNULL(Estado_General,N'—') END AS estadoChip,
        Fe_ppm,Fe_LP,Fe_LC,Indice_PQ,PQ_LP,PQ_LC,Cr_ppm,Cr_LP,Cr_LC,Ni_ppm,Ni_LP,Ni_LC,Cu_ppm,Cu_LP,Cu_LC,
        Pb_ppm,Pb_LP,Pb_LC,Sn_ppm,Sn_LP,Sn_LC,Al_ppm,Al_LP,Al_LC,Si_ppm,Si_LP,Si_LC,Ca_ppm,Ca_LP,Ca_LC,Zn_ppm,Zn_LP,Zn_LC,
        K_ppm,K_LP,K_LC,Na_ppm,Na_LP,Na_LC,Mg_ppm,Mg_LP,Mg_LC,B_ppm,P_ppm,V100,TBN,TBN_LP,
        ROW_NUMBER() OVER (PARTITION BY Equipo ORDER BY FechaMuestreo DESC, Compartimiento, LaboratoryDataId) AS grn
    FROM [dbo].[vw_MuestrasHistorial]
),
s AS (SELECT * FROM s0 WHERE grn <= 24),
u AS (
    SELECT s.Equipo, s.compAbbr, s.grn, s.FechaMuestreo, s.Horometro, s.HorasDeAceite, s.CM, s.estadoChip,
        CONVERT(nvarchar(20), m.metal) AS Parametro, CAST(m.Valor AS decimal(18,2)) AS Valor,
        CAST(m.LP AS decimal(18,2)) AS LP, CAST(m.LC AS decimal(18,2)) AS LC
    FROM s CROSS APPLY (VALUES
            (N'Fe',Fe_ppm,Fe_LP,Fe_LC),
            (N'PQ',Indice_PQ,PQ_LP,PQ_LC),
            (N'Cr',Cr_ppm,Cr_LP,Cr_LC),
            (N'Ni',Ni_ppm,Ni_LP,Ni_LC),
            (N'Cu',Cu_ppm,Cu_LP,Cu_LC),
            (N'Pb',Pb_ppm,Pb_LP,Pb_LC),
            (N'Sn',Sn_ppm,Sn_LP,Sn_LC),
            (N'Al',Al_ppm,Al_LP,Al_LC),
            (N'Si',Si_ppm,Si_LP,Si_LC),
            (N'Ca',Ca_ppm,Ca_LP,Ca_LC),
            (N'Zn',Zn_ppm,Zn_LP,Zn_LC),
            (N'K',K_ppm,K_LP,K_LC),
            (N'Na',Na_ppm,Na_LP,Na_LC),
            (N'Mg',Mg_ppm,Mg_LP,Mg_LC),
            (N'B',B_ppm,NULL,NULL),
            (N'P',P_ppm,NULL,NULL),
            (N'V100',V100,NULL,NULL),
            (N'TBN',TBN,TBN_LP,NULL)
    ) m(metal, Valor, LP, LC)
),
rows_ AS (
    SELECT Equipo, Parametro, grn,
        CAST(N'| ' + ISNULL(FORMAT(FechaMuestreo,'dd-MMM-yy'),N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(Horometro AS decimal(18,0))), N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(HorasDeAceite AS decimal(18,0))), N'—') + N' | ' + ISNULL(CASE WHEN u.Valor > ISNULL(u.LC,999999) THEN CONVERT(nvarchar(20),CAST(u.Valor AS decimal(18,1)))+N' 🟥' WHEN u.Valor > ISNULL(u.LP,999999) THEN CONVERT(nvarchar(20),CAST(u.Valor AS decimal(18,1)))+N' 🟨' ELSE CONVERT(nvarchar(20),CAST(u.Valor AS decimal(18,1))) END, N'—')
           + N' | ' + compAbbr + N' | ' + ISNULL(CM,N'—') + N' | ' + estadoChip + N' |' AS nvarchar(max)) AS rowMD
    FROM u
),
body AS (
    SELECT Equipo, Parametro, COUNT(*) AS N,
        STRING_AGG(rowMD, NCHAR(10)) WITHIN GROUP (ORDER BY grn) AS bodyMD
    FROM rows_ GROUP BY Equipo, Parametro
)
SELECT b.Equipo, N'(todos)' AS compAbbr, b.Parametro,
    CAST(NULL AS nvarchar(max)) AS Observados, CAST(NULL AS nvarchar(max)) AS Recomendaciones,
    CAST(N'**Historial de ' + b.Parametro + N' — ' + b.Equipo + N' (todos los componentes)** · ' + CAST(b.N AS nvarchar(10)) + N' muestras (recientes arriba)' + NCHAR(10) + NCHAR(10)
       + N'| Fecha | SMR | Hor. Aci. | ' + b.Parametro + N' | Componente | T. muestra | Estado |' + NCHAR(10)
       + N'|---|---|---|---|---|---|---|' + NCHAR(10) + b.bodyMD
    AS nvarchar(max)) AS MD
FROM body b;
GO


/* ==== vw_TriageMD (triage MT de flota — caso de uso principal) ==== */
CREATE OR ALTER VIEW [dbo].[vw_TriageMD] AS
/* ==== OPTIMIZADA 25/09 ====================================================================
   Sintoma: la MISMA consulta daba 4 s una vez y 62-114 s la siguiente (BLOQUES 131 y 132).
   Esa inestabilidad es la firma del anti-patron nº1, el mismo que mato al barrido:
     'rows_' leia 'mg' y le hacia LEFT JOIN a 'met', que TAMBIEN sale de 'mg'.
   Un CTE no se materializa: cada rama re-ejecuta 'mg' (y con el 'base' y la fundacion), y el JOIN
   entre las dos ramas sale por nested loops con estimaciones pesimas -> el plan es bueno o malo casi
   por azar.
   Cambios:
     1. 'met' DESAPARECE. Los metales observados se arman con un OUTER APPLY dentro de 'rows_',
        sobre la MISMA fila -> ni rama paralela ni JOIN.
     2. 'obs' queda SOLO para las recomendaciones, y filtra CompTipo='TRACCION' EN EL ORIGEN
        (antes desdoblaba los 9 metales de los 6 comptipos para tirar el 83%).
     3. 'lbl' DESAPARECE: la etiqueta es un CASE en el SELECT final, no un CTE que re-lee 'body'.
   ⛔ La salida no cambia ni un caracter: es rendimiento, no formato.
   ========================================================================================= */
WITH base AS (   -- BASE LIGERA: rankeadas rn=1 (1 pasada de la fundacion); TODOS los comptipos (no solo TRACCION)
    SELECT Equipo, Proyecto, Modelo, CompTipo, Compartimiento, Estado_General, HorasComponente, FechaMuestreo, Grado,
        Fe_ppm, Estado_Fe, Indice_PQ, Estado_PQ, Cr_ppm, Estado_Cr, Ni_ppm, Estado_Ni, Cu_ppm, Estado_Cu,
        Pb_ppm, Estado_Pb, Sn_ppm, Estado_Sn, Al_ppm, Estado_Al, Si_ppm, Estado_Si,
        /* J (29/09): el triage pasa a 5 columnas por familia, asi que necesita TODOS los
           parametros que el formato agrupa -- no solo los 9 de desgaste/contaminacion.
           Todos tienen limite y Estado_* desde el bloque D. */
        Ca_ppm, Estado_Ca, Zn_ppm, Estado_Zn, Mg_ppm, Estado_Mg, K_ppm, Estado_K, Na_ppm, Estado_Na,
        B_ppm, Estado_B, P_ppm, Estado_P, Mo_ppm, Estado_Mo,
        V100, Estado_V100, V40, Estado_V40, TAN, Estado_TAN, TBN, Estado_TBN,
        Oxidacion, Estado_Oxi, Sulfatacion, Estado_Sulf, Nitracion, Estado_Nit,
        Agua, Estado_Agua, Hollin, Estado_Hollin, Diesel, Estado_Diesel,
        ISO4, Estado_ISO4, ISO6, Estado_ISO6, ISO14, Estado_ISO14,
        CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr
    /* 5c/N (29/09): el chip y el contador YA NO salen de Estado_General. Ese mira 9 metales de
       desgaste + TBN, mientras la tabla muestra 30 parametros: por eso podia haber una fila 🟢
       con algo marcado dos columnas mas alla, que es el bug E0. Ahora los dos se calculan en
       'rows_' a partir de las MISMAS celdas que se imprimen, asi que no pueden contradecirse.
       Mismo arreglo que ya llevaba vw_CondicionMT_MD desde el BLOQUE 118. */
    FROM [dbo].[vw_MuestrasRankeadas]
    WHERE rn_recencia = 1 AND CompTipo <> 'OTRO'
),
mg AS (   -- expandir a (modelo real) + (todos)
    SELECT b.*, g.ModeloG FROM base b CROSS APPLY (SELECT b.Modelo AS ModeloG
             UNION ALL
             SELECT N'(todos)' WHERE EXISTS (
                 SELECT 1 FROM [dbo].[vw_ModeloConLimites] ml
                 WHERE ml.ProyKey   = UPPER(LTRIM(RTRIM(b.Proyecto)))
                   AND ml.ModeloKey = UPPER(LTRIM(RTRIM(b.Modelo))))) g
),
rows_ AS (   -- 1 fila de tabla por equipo+componente. Los metales se agregan SOBRE LA MISMA FILA
             -- (OUTER APPLY), no en un CTE aparte al que luego haya que volver con un JOIN.
    SELECT m.Proyecto, m.ModeloG, m.CompTipo, m.Modelo AS RealModelo, m.Equipo,
        ISNULL(mm.peor, 3) AS estadoOrd,
        CAST(N'| ' + m.Equipo + N' | ' + m.compAbbr + N' | ' + ISNULL(m.Grado,N'—')
           + N' | ' + CASE mm.peor WHEN 1 THEN N'🟥' WHEN 2 THEN N'🟨' ELSE N'🟢' END
           + N' | ' + ISNULL(mm.Desgaste,      N'—')
           + N' | ' + ISNULL(mm.Aditivos,      N'—')
           + N' | ' + ISNULL(mm.Contaminacion, N'—')
           + N' | ' + ISNULL(mm.Salud,         N'—')
           + N' | ' + ISNULL(mm.Limpieza,      N'—')
           + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(m.HorasComponente AS decimal(18,0))),N'—')
           + N' | ' + ISNULL(FORMAT(m.FechaMuestreo,'dd-MMM-yy'),N'—') + N' |' AS nvarchar(max)) AS rowMD
    FROM mg m
    /* J (29/09): el triage pasa de dos columnas ('Metales Obs.' y 'Salud') a CINCO, una por
       familia del formato: Desgaste · Aditivos · Contaminacion · Salud · Codigo Limpieza.
       La familia de cada parametro NO se escribe a mano: sale de vw_FormatoParametro, y eso
       importa porque DEPENDE DEL COMPONENTE -- el Ca es contaminante en Motor de Traccion y
       aditivo en el resto. Una lista fija se equivocaria en la mitad de los casos.
       El TOP 1 busca la fila del CompTipo propio y cae a '(CRUZADO)' si ese componente no esta
       en el formato: MANDO y TRANSMISION no estan, y sin el fallback sus parametros
       desapareceran de la tabla sin ruido.
       GrupoOrden del formato: 1 Salud · 2 Aditivos · 3 Contaminacion · 4 Desgaste · 5 Cod.Limpieza.
       ⛔ Cuando se enchufe 'Inf' aqui (paso 5c): filtra el CONTADOR, no la celda. El parametro
          Inf=1 se sigue imprimiendo con su valor y sin ninguna marca que lo distinga. Ver la
          REGLA PERMANENTE DE 'Inf' en la cabecera de vw_FormatoParametro.
       Cada parametro sale con su VALOR (antes la columna Salud mostraba 'V100' a secas, sin
       numero) y con 🟥 si es critico. */
    OUTER APPLY (
        SELECT MIN(g.peorFam) AS peor,
               MAX(CASE WHEN g.GrupoOrden = 4 THEN g.txt END) AS Desgaste,
               MAX(CASE WHEN g.GrupoOrden = 2 THEN g.txt END) AS Aditivos,
               MAX(CASE WHEN g.GrupoOrden = 3 THEN g.txt END) AS Contaminacion,
               MAX(CASE WHEN g.GrupoOrden = 1 THEN g.txt END) AS Salud,
               MAX(CASE WHEN g.GrupoOrden = 5 THEN g.txt END) AS Limpieza
        FROM (
            SELECT ff.GrupoOrden,
                   /* peor estado de esta familia MIRANDO SOLO los parametros que cuentan (Inf=0).
                      1 critico · 2 precaucion · 3 nada. Los Inf=1 (K, Na, B, y Ca/Zn/Mg/Mo cuando
                      son contaminantes, o sea en MT) SIGUEN IMPRIMIENDOSE con su valor en la celda
                      de siempre -- solo no entran al conteo. */
                   MIN(CASE WHEN ff.Inf = 0 AND v.est = 'CRITICO'    THEN 1
                            WHEN ff.Inf = 0 AND v.est = 'PRECAUCION' THEN 2
                            ELSE 3 END) AS peorFam,
                   STRING_AGG(CONVERT(nvarchar(max),
                       v.metal + N'(' + CONVERT(nvarchar(20), CAST(v.val AS decimal(18,1))) + N')'
                     + CASE WHEN v.est = 'CRITICO' THEN N' 🟥' ELSE N'' END), N', ')
                       WITHIN GROUP (ORDER BY ff.Orden) AS txt
            FROM (VALUES
                (N'Fe',   m.Fe_ppm,      m.Estado_Fe),
                (N'PQ',   m.Indice_PQ,   m.Estado_PQ),
                (N'Cr',   m.Cr_ppm,      m.Estado_Cr),
                (N'Ni',   m.Ni_ppm,      m.Estado_Ni),
                (N'Cu',   m.Cu_ppm,      m.Estado_Cu),
                (N'Pb',   m.Pb_ppm,      m.Estado_Pb),
                (N'Sn',   m.Sn_ppm,      m.Estado_Sn),
                (N'Al',   m.Al_ppm,      m.Estado_Al),
                (N'Si',   m.Si_ppm,      m.Estado_Si),
                (N'Ca',   m.Ca_ppm,      m.Estado_Ca),
                (N'Zn',   m.Zn_ppm,      m.Estado_Zn),
                (N'Mg',   m.Mg_ppm,      m.Estado_Mg),
                (N'K',    m.K_ppm,       m.Estado_K),
                (N'Na',   m.Na_ppm,      m.Estado_Na),
                (N'B',    m.B_ppm,       m.Estado_B),
                (N'P',    m.P_ppm,       m.Estado_P),
                (N'Mo',   m.Mo_ppm,      m.Estado_Mo),
                (N'V100', m.V100,        m.Estado_V100),
                (N'V40',  m.V40,         m.Estado_V40),
                (N'TAN',  m.TAN,         m.Estado_TAN),
                (N'TBN',  m.TBN,         m.Estado_TBN),
                (N'Oxidacion',   m.Oxidacion,   m.Estado_Oxi),
                (N'Sulfatacion', m.Sulfatacion, m.Estado_Sulf),
                (N'Nitracion',   m.Nitracion,   m.Estado_Nit),
                (N'Agua',   m.Agua,   m.Estado_Agua),
                (N'Hollin', m.Hollin, m.Estado_Hollin),
                (N'Diesel', m.Diesel, m.Estado_Diesel),
                (N'ISO>4',  m.ISO4,   m.Estado_ISO4),
                (N'ISO>6',  m.ISO6,   m.Estado_ISO6),
                (N'ISO>14', m.ISO14,  m.Estado_ISO14)
            ) v(metal, val, est)
            CROSS APPLY (
                SELECT TOP 1 f.GrupoOrden, f.Orden, f.Inf
                FROM [dbo].[vw_FormatoParametro] f
                WHERE f.Parametro = v.metal AND f.CompTipo IN (m.CompTipo, N'(CRUZADO)')
                ORDER BY CASE WHEN f.CompTipo = m.CompTipo THEN 0 ELSE 1 END
            ) ff
            WHERE v.est IN ('CRITICO','PRECAUCION')
            GROUP BY ff.GrupoOrden
        ) g
    ) mm
),
sec AS (   -- una seccion por (Proyecto, ModeloG, CompTipo, modelo real): sub-titulo (solo en '(todos)') + tabla
    SELECT Proyecto, ModeloG, CompTipo, RealModelo,
        MIN(estadoOrd) AS secOrd, COUNT(*) AS nTot,
        SUM(CASE WHEN estadoOrd<3 THEN 1 ELSE 0 END) AS nObs, SUM(CASE WHEN estadoOrd=1 THEN 1 ELSE 0 END) AS nCrit,
        CAST(
            CASE WHEN MAX(ModeloG)=N'(todos)' THEN N'### ' + RealModelo + N' · ' + CAST(COUNT(*) AS nvarchar(10)) + N' equipos (' + CAST(SUM(CASE WHEN estadoOrd<3 THEN 1 ELSE 0 END) AS nvarchar(10)) + N' obs)' + NCHAR(10) + NCHAR(10) ELSE N'' END
          + N'| Equipo | Comp | Grado | Estado | Desgaste | Aditivos | Contaminación | Salud | Cód. Limpieza | Hrs Comp | Últ. |' + NCHAR(10)
          + N'|---|---|---|---|---|---|---|---|---|---|---|' + NCHAR(10)
          + STRING_AGG(rowMD, NCHAR(10)) WITHIN GROUP (ORDER BY estadoOrd, Equipo)
        AS nvarchar(max)) AS secMD
    FROM rows_ GROUP BY Proyecto, ModeloG, CompTipo, RealModelo
),
body AS (
    SELECT Proyecto, ModeloG, CompTipo,
        SUM(nTot) AS nTot, SUM(nObs) AS nObs, SUM(nCrit) AS nCrit,
        STRING_AGG(secMD, NCHAR(10)+NCHAR(10)) WITHIN GROUP (ORDER BY secOrd, RealModelo) AS bodyMD
    FROM sec GROUP BY Proyecto, ModeloG, CompTipo
),
obs AS (   -- SOLO para las recomendaciones: TRACCION filtrado EN EL ORIGEN, no despues
    SELECT DISTINCT m.Proyecto, m.ModeloG, m.CompTipo, m.Equipo, v.metal
    FROM mg m
    CROSS APPLY (VALUES
        (N'Fe',m.Estado_Fe),(N'PQ',m.Estado_PQ),(N'Cr',m.Estado_Cr),(N'Ni',m.Estado_Ni),(N'Cu',m.Estado_Cu),
        (N'Pb',m.Estado_Pb),(N'Sn',m.Estado_Sn),(N'Al',m.Estado_Al),(N'Si',m.Estado_Si)
    ) v(metal, est)
    WHERE m.CompTipo = 'TRACCION' AND v.est IN ('CRITICO','PRECAUCION')
),
recos AS (   -- recos verbatim SOLO para TRACCION (indicios de caja de engranajes)
    SELECT o.Proyecto, o.ModeloG, o.CompTipo, r.ord, r.label, r.indicio,
        STRING_AGG(CONVERT(nvarchar(20), o.Equipo), N', ') AS equipos
    FROM obs o
    JOIN [dbo].[vw_Recomendaciones] r ON r.metal = o.metal
    GROUP BY o.Proyecto, o.ModeloG, o.CompTipo, r.ord, r.label, r.indicio
),
recoblock AS (
    SELECT Proyecto, ModeloG, CompTipo,
        CAST(N'**🔧 Recomendaciones Técnicas**' + NCHAR(10)
           + STRING_AGG(CONVERT(nvarchar(max), N'- **' + label + N':** ' + indicio + N' _(equipos: ' + equipos + N')_'), NCHAR(10)) WITHIN GROUP (ORDER BY ord)
           + NCHAR(10) + NCHAR(10) + N'Acortar la frecuencia de monitoreo y programar dializado/cambio de aceite en el próximo PM. Retirar los 8 tapones magnéticos para inspección y limpieza en busca de particulado anormal. Para mayor información y detalle, contactar a confiabilidad.operaciones@kmmp.com.pe' AS nvarchar(max)) AS Recomendaciones
    FROM recos GROUP BY Proyecto, ModeloG, CompTipo
)
SELECT
    b.Proyecto, b.ModeloG AS Modelo, b.CompTipo,
    CAST(NULL AS nvarchar(max)) AS Observados,
    rb.Recomendaciones,
    CAST(
        N'**Triage '
      + CASE b.CompTipo WHEN 'TRACCION' THEN N'Motores de Tracción' WHEN 'HIDRAULICO' THEN N'Sistemas Hidráulicos' WHEN 'RUEDA' THEN N'Ruedas Delanteras' WHEN 'MANDO' THEN N'Mandos Finales' WHEN 'TRANSMISION' THEN N'Transmisiones' WHEN 'MOTOR' THEN N'Motores' ELSE b.CompTipo END
      + N' — ' + b.Proyecto + CASE WHEN b.ModeloG<>N'(todos)' THEN N' · ' + b.ModeloG ELSE N'' END + N'** · '
      + CAST(b.nObs AS nvarchar(10)) + N' de ' + CAST(b.nTot AS nvarchar(10)) + N' observados (' + CAST(b.nCrit AS nvarchar(10)) + N' críticos)' + NCHAR(10) + NCHAR(10)
      /* L5 (29/09): si el modelo que se pidio NO tiene limites cargados, decirlo.
         Sin esto, "930E · 0 de 18 observados" se lee como "los 18 estan sanos", cuando lo
         que pasa es que no hay con que evaluarlos -- el mismo fallo silencioso que venimos
         cerrando toda la ronda. ⛔ NO se restringe nada: el modelo sigue saliendo entero.
         El NOT EXISTS se evalua una vez por fila del resultado (una por proyecto+modelo+
         comptipo), no por equipo: es barato. */
      + CASE WHEN b.ModeloG <> N'(todos)'
                  AND NOT EXISTS (SELECT 1 FROM [dbo].[vw_ModeloConLimites] ml
                                  WHERE ml.ProyKey   = UPPER(LTRIM(RTRIM(b.Proyecto)))
                                    AND ml.ModeloKey = UPPER(LTRIM(RTRIM(b.ModeloG))))
             THEN N'⚠ **' + b.ModeloG + N' no tiene límites cargados** para este proyecto: los equipos salen **sin evaluar**, no sanos.' + NCHAR(10) + NCHAR(10)
             ELSE N'' END
      + b.bodyMD
      /* 5c/N (29/09): con J las 5 columnas ya se ven, pero el contador seguia siendo
         Estado_General (9 metales) -- una fila 🟢 con un aditivo marcado se leia como
         contradiccion, el bug E0. Se dejo un pie explicandolo, que era un PARCHE. Ahora el
         contador sale de las mismas celdas, asi que E0 esta cerrado de raiz. El pie sigue, pero
         ya no justifica una contradiccion: nombra los parametros que el area declaro
         INFORMATIVOS (Inf=1) y que se ven sin contar.
         ⛔ Y se nombran EN PROSA, en el pie, una sola vez. Nunca una etiqueta pegada al dato:
            ver la REGLA PERMANENTE DE 'Inf' en la cabecera de vw_FormatoParametro. */
      + NCHAR(10) + NCHAR(10)
      + N'_El **Estado** y el conteo salen de las **mismas celdas** que ves en la tabla. Se muestran también algunos parámetros que el área tiene definidos como **informativos** — `K`, `Na`, `B`, y `Ca`/`Zn`/`Mg`/`Mo` en Motor de Tracción, donde son contaminantes: se ven con su valor, pero **no cuentan** como observación._'
    AS nvarchar(max)) AS MD
FROM body b
LEFT JOIN recoblock rb ON rb.Proyecto=b.Proyecto AND rb.ModeloG=b.ModeloG AND rb.CompTipo=b.CompTipo;
GO

/* ==== vw_TendenciaIncipienteMD (#14: equipos que varian de su promedio sin superar el LP) ==== */
/* P3 (22/09): generalizada a CUALQUIER componente (filtro por CompTipo, lo aplica el flujo), con
   denominador honesto (separa universo evaluable de equipos sin limites) y piso de 1 ppm para no
   reportar ruido de laboratorio. El BLOQUE 84 midio que el 46% de las alertas eran saltos <1 ppm,
   casi todos de metales de traza (Cr 53/54, Ni 14/15, Al 50/69). */
CREATE OR ALTER VIEW [dbo].[vw_TendenciaIncipienteMD] AS
/* 30/09 -- FILTRO ABAJO (mismo patron que curo /condicionmt: 146 s -> 1,4 s, y /diagcompleto).
   La logica va en CROSS APPLY sobre [Mine].[MiningProject] y CADA lectura pesada lleva el filtro
   (Proyecto = mp.[Name]), asi que ninguna rama calcula mas que ese proyecto. Los CTE van desplegados:
   un APPLY no admite WITH y SQL Server ya los trata como macros. Misma logica y salida. Respaldo: respaldo/DDL_vistas_2026-09-30_antes_filtro_abajo.sql */
SELECT mp.[Name] AS Proyecto, x.[Modelo], x.[CompTipo], x.[Observados], x.[Recomendaciones], x.[MD]
FROM [Mine].[MiningProject] mp
CROSS APPLY (
SELECT
    u.Proyecto, N'(todos)' AS Modelo, u.CompTipo,
    CAST(NULL AS nvarchar(max)) AS Observados,
    CAST(NULL AS nvarchar(max)) AS Recomendaciones,
    CAST(
        N'**Tendencia incipiente 🔵 🟧 · ' + CASE u.CompTipo WHEN 'TRACCION' THEN N'Motores de Tracción' WHEN 'HIDRAULICO' THEN N'Sistemas Hidráulicos' WHEN 'RUEDA' THEN N'Ruedas Delanteras' WHEN 'MANDO' THEN N'Mandos Finales' WHEN 'TRANSMISION' THEN N'Transmisiones' WHEN 'MOTOR' THEN N'Motores' ELSE u.CompTipo END
      + N' · ' + u.Proyecto + N'** · '
      + CASE WHEN u.Neval = 0 THEN N'sin límites cargados'
             ELSE CAST(ISNULL(b.Ninc, 0) AS nvarchar(10)) + N' de ' + CAST(u.Neval AS nvarchar(10)) + N' evaluados' END + NCHAR(10)
      + CASE WHEN u.Neval = 0 THEN
            N'_No hay límites (LP) cargados para este componente en este proyecto: no hay contra qué comparar, por eso no se evalúa. ⚠ Esto **no** significa que estén sanos._'
        ELSE
            N'_Última muestra vs. el promedio de las 6 anteriores. Se listan los que subieron ≥40% sobre ese promedio y ya están en la mitad superior del límite (≥50% del LP), sin superarlo todavía. Se descartan las variaciones menores a 1 ppm (ruido de laboratorio)._'
          + CASE WHEN u.Nsin > 0 THEN NCHAR(10) + N'_⚠ ' + CAST(u.Nsin AS nvarchar(10)) + N' sin límites cargados: no evaluados._' ELSE N'' END
        END
      + CASE WHEN b.bodyMD IS NOT NULL THEN
            NCHAR(10) + NCHAR(10)
          + N'| Equipo | Componente | Tendencia | Parámetros (prom' + N'→' + N'últ) |' + NCHAR(10)
          + N'|---|---|---|---|' + NCHAR(10) + b.bodyMD
          + CASE WHEN b.Ninc > b.Nmostrados THEN NCHAR(10) + NCHAR(10) + N'_Mostrando ' + CAST(b.Nmostrados AS nvarchar(10)) + N' de ' + CAST(b.Ninc AS nvarchar(10)) + N', los de mayor variación._' ELSE N'' END
          + NCHAR(10) + NCHAR(10)
          + N'**Límites de referencia (ppm)**' + NCHAR(10) + NCHAR(10)
          + N'| Metal | LP | LC |' + NCHAR(10) + N'|---|---|---|' + NCHAR(10) + ISNULL(lb.b, N'_—_')
        WHEN u.Neval > 0 THEN
            NCHAR(10) + NCHAR(10) + N'_Ninguno: ningún equipo de este componente muestra desviación incipiente sobre su comportamiento histórico._'
        ELSE N'' END
    AS nvarchar(max)) AS MD
FROM (   -- universo: evaluables (con limite) vs sin limites cargados. Sale de agg, NO de s:
            -- cada referencia extra a la fundacion la vuelve a expandir (los CTE no se materializan).
    SELECT Proyecto, CompTipo,
        COUNT(CASE WHEN tieneLP = 1 THEN 1 END) AS Neval,
        COUNT(CASE WHEN tieneLP = 0 THEN 1 END) AS Nsin
    FROM (
        SELECT Proyecto, CompTipo, Equipo, Compartimiento,
               MAX(CASE WHEN LP IS NOT NULL THEN 1 ELSE 0 END) AS tieneLP
        FROM (   -- ultimo (rn=1) vs promedio de las 6 previas (rn 2..7, SIN el ultimo)
    SELECT Proyecto, Equipo, Compartimiento, CompTipo, compAbbr, metal, Orden,
        MAX(CASE WHEN rn_recencia = 1 THEN Valor END) AS ult,
        MAX(CASE WHEN rn_recencia = 1 THEN LP END)    AS LP,
        MAX(CASE WHEN rn_recencia = 1 THEN LC END)    AS LC,
        AVG(CASE WHEN rn_recencia BETWEEN 2 AND 7 THEN Valor END) AS prom_prev,
        SUM(CASE WHEN rn_recencia BETWEEN 2 AND 7 AND Valor IS NOT NULL THEN 1 ELSE 0 END) AS n_prev
    FROM (   -- ultimas 7 muestras por equipo+compartimiento, un renglon por metal de desgaste
    SELECT Proyecto, Equipo, Compartimiento, CompTipo, rn_recencia,
        CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr,
        p.metal, p.Orden, CAST(p.Valor AS decimal(18,2)) AS Valor, CAST(p.LP AS decimal(18,2)) AS LP, CAST(p.LC AS decimal(18,2)) AS LC
    FROM (SELECT * FROM [dbo].[vw_MuestrasRankeadas] WHERE Proyecto = mp.[Name]) vw_MuestrasRankeadas
    CROSS APPLY (VALUES
        (N'Fe',1,Fe_ppm,Fe_LP,Fe_LC),
        (N'PQ',2,Indice_PQ,PQ_LP,PQ_LC),
        (N'Cr',3,Cr_ppm,Cr_LP,Cr_LC),
        (N'Ni',4,Ni_ppm,Ni_LP,Ni_LC),
        (N'Cu',5,Cu_ppm,Cu_LP,Cu_LC),
        (N'Pb',6,Pb_ppm,Pb_LP,Pb_LC),
        (N'Sn',7,Sn_ppm,Sn_LP,Sn_LC),
        (N'Al',8,Al_ppm,Al_LP,Al_LC),
        (N'Si',9,Si_ppm,Si_LP,Si_LC)
    ) p(metal, Orden, Valor, LP, LC)
    WHERE EsDDI = 0 AND rn_recencia <= 7
) s GROUP BY Proyecto, Equipo, Compartimiento, CompTipo, compAbbr, metal, Orden
) agg GROUP BY Proyecto, CompTipo, Equipo, Compartimiento
    ) z GROUP BY Proyecto, CompTipo
) u
LEFT JOIN (
    SELECT Proyecto, CompTipo, MAX(Ninc) AS Ninc, COUNT(*) AS Nmostrados,
        STRING_AGG(CAST(N'| ' + Equipo + N' | ' + compAbbr + N' | '
           + CASE WHEN sev = 1 THEN N'🟧 acelerada' ELSE N'🔵 incipiente' END
           + N' | ' + mets + N' |' AS nvarchar(max)), NCHAR(10)) WITHIN GROUP (ORDER BY rn) AS bodyMD
    FROM (   -- lo mas severo primero, para que el tope nunca corte lo importante
    SELECT *, ROW_NUMBER() OVER (PARTITION BY Proyecto, CompTipo ORDER BY sev, maxpct DESC, Equipo, compAbbr) AS rn,
              COUNT(*) OVER (PARTITION BY Proyecto, CompTipo) AS Ninc
    FROM (   -- por equipo+componente: metales disparados + severidad
    SELECT Proyecto, CompTipo, Equipo, compAbbr,
        STRING_AGG(CONVERT(nvarchar(max),
            metal + N' ' + CONVERT(nvarchar(20), CAST(prom_prev AS decimal(18,1))) + N'→'
            + CONVERT(nvarchar(20), CAST(ult AS decimal(18,1)))
            + N' (+' + CASE WHEN pct > 500 THEN N'>500' ELSE CONVERT(nvarchar(12), pct) END + N'%)'), N', ') WITHIN GROUP (ORDER BY Orden) AS mets,
        MIN(CASE WHEN pct >= 80 THEN 1 ELSE 2 END) AS sev,
        MAX(pct) AS maxpct
    FROM (   -- se acerca al LP y sube sobre su propia media, sin superarlo todavia
    SELECT *, CONVERT(int, ROUND((ult - prom_prev) / NULLIF(prom_prev, 0) * 100, 0)) AS pct
    FROM (   -- ultimo (rn=1) vs promedio de las 6 previas (rn 2..7, SIN el ultimo)
    SELECT Proyecto, Equipo, Compartimiento, CompTipo, compAbbr, metal, Orden,
        MAX(CASE WHEN rn_recencia = 1 THEN Valor END) AS ult,
        MAX(CASE WHEN rn_recencia = 1 THEN LP END)    AS LP,
        MAX(CASE WHEN rn_recencia = 1 THEN LC END)    AS LC,
        AVG(CASE WHEN rn_recencia BETWEEN 2 AND 7 THEN Valor END) AS prom_prev,
        SUM(CASE WHEN rn_recencia BETWEEN 2 AND 7 AND Valor IS NOT NULL THEN 1 ELSE 0 END) AS n_prev
    FROM (   -- ultimas 7 muestras por equipo+compartimiento, un renglon por metal de desgaste
    SELECT Proyecto, Equipo, Compartimiento, CompTipo, rn_recencia,
        CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr,
        p.metal, p.Orden, CAST(p.Valor AS decimal(18,2)) AS Valor, CAST(p.LP AS decimal(18,2)) AS LP, CAST(p.LC AS decimal(18,2)) AS LC
    FROM (SELECT * FROM [dbo].[vw_MuestrasRankeadas] WHERE Proyecto = mp.[Name]) vw_MuestrasRankeadas
    CROSS APPLY (VALUES
        (N'Fe',1,Fe_ppm,Fe_LP,Fe_LC),
        (N'PQ',2,Indice_PQ,PQ_LP,PQ_LC),
        (N'Cr',3,Cr_ppm,Cr_LP,Cr_LC),
        (N'Ni',4,Ni_ppm,Ni_LP,Ni_LC),
        (N'Cu',5,Cu_ppm,Cu_LP,Cu_LC),
        (N'Pb',6,Pb_ppm,Pb_LP,Pb_LC),
        (N'Sn',7,Sn_ppm,Sn_LP,Sn_LC),
        (N'Al',8,Al_ppm,Al_LP,Al_LC),
        (N'Si',9,Si_ppm,Si_LP,Si_LC)
    ) p(metal, Orden, Valor, LP, LC)
    WHERE EsDDI = 0 AND rn_recencia <= 7
) s GROUP BY Proyecto, Equipo, Compartimiento, CompTipo, compAbbr, metal, Orden
) agg
    WHERE n_prev >= 2 AND ult > 0 AND prom_prev > 0
      AND LP IS NOT NULL            -- solo metales con limite definido
      AND ult <= LP                 -- aun NO observado
      AND ult >= 0.5 * LP           -- mitad superior: acercandose al limite
      AND ult >= prom_prev * 1.4    -- acelerando respecto a su propia media
      AND (ult - prom_prev) >= 1.0  -- piso de ruido: un salto <1 ppm no es desgaste, es el suelo del laboratorio
) inc GROUP BY Proyecto, CompTipo, Equipo, compAbbr
) eq
) rank_ WHERE rn <= 25 GROUP BY Proyecto, CompTipo
) b    ON b.Proyecto  = u.Proyecto AND b.CompTipo  = u.CompTipo
LEFT JOIN (
    SELECT Proyecto, CompTipo, STRING_AGG(CAST(N'| ' + metal + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(LP AS decimal(18,1))),N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(LC AS decimal(18,1))),N'—') + N' |' AS nvarchar(max)), NCHAR(10)) WITHIN GROUP (ORDER BY Orden) AS b
    FROM (   -- limites solo de los metales que efectivamente salieron. Sale de inc directamente:
            -- el EXISTS correlacionado contra s re-ejecutaba la fundacion por cada fila (anti-patron nº1).
    SELECT Proyecto, CompTipo, metal, Orden, MAX(LP) AS LP, MAX(LC) AS LC
    FROM (   -- se acerca al LP y sube sobre su propia media, sin superarlo todavia
    SELECT *, CONVERT(int, ROUND((ult - prom_prev) / NULLIF(prom_prev, 0) * 100, 0)) AS pct
    FROM (   -- ultimo (rn=1) vs promedio de las 6 previas (rn 2..7, SIN el ultimo)
    SELECT Proyecto, Equipo, Compartimiento, CompTipo, compAbbr, metal, Orden,
        MAX(CASE WHEN rn_recencia = 1 THEN Valor END) AS ult,
        MAX(CASE WHEN rn_recencia = 1 THEN LP END)    AS LP,
        MAX(CASE WHEN rn_recencia = 1 THEN LC END)    AS LC,
        AVG(CASE WHEN rn_recencia BETWEEN 2 AND 7 THEN Valor END) AS prom_prev,
        SUM(CASE WHEN rn_recencia BETWEEN 2 AND 7 AND Valor IS NOT NULL THEN 1 ELSE 0 END) AS n_prev
    FROM (   -- ultimas 7 muestras por equipo+compartimiento, un renglon por metal de desgaste
    SELECT Proyecto, Equipo, Compartimiento, CompTipo, rn_recencia,
        CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr,
        p.metal, p.Orden, CAST(p.Valor AS decimal(18,2)) AS Valor, CAST(p.LP AS decimal(18,2)) AS LP, CAST(p.LC AS decimal(18,2)) AS LC
    FROM (SELECT * FROM [dbo].[vw_MuestrasRankeadas] WHERE Proyecto = mp.[Name]) vw_MuestrasRankeadas
    CROSS APPLY (VALUES
        (N'Fe',1,Fe_ppm,Fe_LP,Fe_LC),
        (N'PQ',2,Indice_PQ,PQ_LP,PQ_LC),
        (N'Cr',3,Cr_ppm,Cr_LP,Cr_LC),
        (N'Ni',4,Ni_ppm,Ni_LP,Ni_LC),
        (N'Cu',5,Cu_ppm,Cu_LP,Cu_LC),
        (N'Pb',6,Pb_ppm,Pb_LP,Pb_LC),
        (N'Sn',7,Sn_ppm,Sn_LP,Sn_LC),
        (N'Al',8,Al_ppm,Al_LP,Al_LC),
        (N'Si',9,Si_ppm,Si_LP,Si_LC)
    ) p(metal, Orden, Valor, LP, LC)
    WHERE EsDDI = 0 AND rn_recencia <= 7
) s GROUP BY Proyecto, Equipo, Compartimiento, CompTipo, compAbbr, metal, Orden
) agg
    WHERE n_prev >= 2 AND ult > 0 AND prom_prev > 0
      AND LP IS NOT NULL            -- solo metales con limite definido
      AND ult <= LP                 -- aun NO observado
      AND ult >= 0.5 * LP           -- mitad superior: acercandose al limite
      AND ult >= prom_prev * 1.4    -- acelerando respecto a su propia media
      AND (ult - prom_prev) >= 1.0  -- piso de ruido: un salto <1 ppm no es desgaste, es el suelo del laboratorio
) inc GROUP BY Proyecto, CompTipo, metal, Orden
) lims GROUP BY Proyecto, CompTipo
) lb ON lb.Proyecto = u.Proyecto AND lb.CompTipo = u.CompTipo
) x;
GO

/* ==== vw_ConteoFlotaMD (Conteo deterministico — reemplaza KomfIA SQL) ==== */
CREATE OR ALTER VIEW [dbo].[vw_ConteoFlotaMD] AS
WITH base AS (   -- ultima muestra por equipo+comp (sin DDI), duplicada por modelo real + '(todos)'
    SELECT b.Proyecto, mg.ModeloG AS Modelo, b.Equipo, b.Compartimiento, b.Estado_General,
        CASE WHEN b.Estado_General LIKE '%CRITIC%' THEN 1 ELSE 0 END AS esCrit,
        CASE WHEN b.Estado_General LIKE '%PRECAUC%' THEN 1 ELSE 0 END AS esPrec,
        CASE WHEN b.Estado_General NOT LIKE '%OK%' AND b.Estado_General NOT LIKE '%NORMAL%' THEN 1 ELSE 0 END AS esObs
    FROM [dbo].[vw_MuestrasRankeadas] b
    CROSS APPLY (SELECT b.Modelo AS ModeloG
             UNION ALL
             SELECT N'(todos)' WHERE EXISTS (
                 SELECT 1 FROM [dbo].[vw_ModeloConLimites] ml
                 WHERE ml.ProyKey   = UPPER(LTRIM(RTRIM(b.Proyecto)))
                   AND ml.ModeloKey = UPPER(LTRIM(RTRIM(b.Modelo))))) mg
    WHERE b.rn_recencia = 1
),
comprow AS (   -- por componente (data-driven)
    SELECT Proyecto, Modelo, REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(Compartimiento,'MOTOR DE TRACCION LH','MT LH'),'MOTOR DE TRACCION RH','MT RH'),'RUEDA DELANTERA LH','RD LH'),'RUEDA DELANTERA RH','RD RH'),'SISTEMA HIDRAULICO','Hidr'),'MOTOR','Motor') AS Comp,
        COUNT(DISTINCT Equipo) AS nEq, SUM(esObs) AS nObs, SUM(esCrit) AS nCrit, SUM(esPrec) AS nPrec,
        MIN(CASE WHEN esCrit=1 THEN 1 WHEN esObs=1 THEN 2 ELSE 3 END) AS sev
    FROM base GROUP BY Proyecto, Modelo, REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(Compartimiento,'MOTOR DE TRACCION LH','MT LH'),'MOTOR DE TRACCION RH','MT RH'),'RUEDA DELANTERA LH','RD LH'),'RUEDA DELANTERA RH','RD RH'),'SISTEMA HIDRAULICO','Hidr'),'MOTOR','Motor')
),
fleet AS (   -- por proyecto+modelo (equipos DISTINTOS)
    SELECT Proyecto, Modelo,
        COUNT(DISTINCT Equipo) AS nEq,
        COUNT(DISTINCT CASE WHEN esObs=1 THEN Equipo END) AS nObs,
        COUNT(DISTINCT CASE WHEN esCrit=1 THEN Equipo END) AS nCrit,
        COUNT(DISTINCT CASE WHEN esPrec=1 AND esCrit=0 THEN Equipo END) AS nPrecOnly
    FROM base GROUP BY Proyecto, Modelo
),
rows_ AS (
    SELECT Proyecto, Modelo, sev,
        CAST(N'| ' + Comp + N' | ' + CAST(nEq AS nvarchar(10)) + N' | ' + CAST(nObs AS nvarchar(10))
           + N' | ' + CAST(nCrit AS nvarchar(10)) + N' | ' + CAST(nPrec AS nvarchar(10)) + N' |' AS nvarchar(max)) AS rowMD
    FROM comprow
),
body AS (
    SELECT Proyecto, Modelo, STRING_AGG(rowMD, NCHAR(10)) WITHIN GROUP (ORDER BY sev, rowMD) AS bodyMD
    FROM rows_ GROUP BY Proyecto, Modelo
)
SELECT
    f.Proyecto, f.Modelo,
    CAST(NULL AS nvarchar(max)) AS Observados,
    CAST(NULL AS nvarchar(max)) AS Recomendaciones,
    CAST(
        N'**Conteo de flota — ' + f.Proyecto + CASE WHEN f.Modelo <> N'(todos)' THEN N' · ' + f.Modelo ELSE N'' END + N'**' + NCHAR(10)
      + CAST(f.nEq AS nvarchar(10)) + N' equipos · ' + CAST(f.nObs AS nvarchar(10)) + N' observados ('
      + CAST(f.nCrit AS nvarchar(10)) + N' criticos · ' + CAST(f.nObs - f.nCrit AS nvarchar(10)) + N' precaucion) · '
      + CAST(f.nEq - f.nObs AS nvarchar(10)) + N' sin novedad' + NCHAR(10) + NCHAR(10)
      /* L5 (29/09): avisar si el modelo pedido no tiene limites cargados. No restringe nada
         -- el modelo sigue saliendo entero -- pero evita que "0 observados" se lea como
         "todos sanos" cuando lo que pasa es que no hay con que evaluarlos. */
      + CASE WHEN f.Modelo <> N'(todos)'
                  AND NOT EXISTS (SELECT 1 FROM [dbo].[vw_ModeloConLimites] ml
                                  WHERE ml.ProyKey   = UPPER(LTRIM(RTRIM(f.Proyecto)))
                                    AND ml.ModeloKey = UPPER(LTRIM(RTRIM(f.Modelo))))
             THEN N'⚠ **' + f.Modelo + N' no tiene límites cargados** para este proyecto: los equipos salen **sin evaluar**, no sanos.' + NCHAR(10) + NCHAR(10)
             ELSE N'' END
      + N'| Componente | Equipos | Observ. | Criticos | Precau. |' + NCHAR(10)
      + N'|---|---|---|---|---|' + NCHAR(10) + ISNULL(b.bodyMD, N'—')
    AS nvarchar(max)) AS MD
FROM fleet f
LEFT JOIN body b ON b.Proyecto = f.Proyecto AND b.Modelo = f.Modelo;
GO

/* ==== vw_RankingMD (Ranking deterministico — reemplaza KomfIA SQL) ==== */
CREATE OR ALTER VIEW [dbo].[vw_RankingMD] AS
WITH s AS (   -- ultima muestra por equipo+comp (sin DDI), metales normalizados, modelo real + '(todos)'
    SELECT b.Proyecto, mg.ModeloG AS Modelo, b.Equipo, b.CompTipo,
        p.metal, p.Orden, CAST(p.val AS decimal(18,2)) AS val, CAST(p.lp AS decimal(18,2)) AS lp, CAST(p.lc AS decimal(18,2)) AS lc
    FROM [dbo].[vw_MuestrasRankeadas] b
    CROSS APPLY (SELECT b.Modelo AS ModeloG
             UNION ALL
             SELECT N'(todos)' WHERE EXISTS (
                 SELECT 1 FROM [dbo].[vw_ModeloConLimites] ml
                 WHERE ml.ProyKey   = UPPER(LTRIM(RTRIM(b.Proyecto)))
                   AND ml.ModeloKey = UPPER(LTRIM(RTRIM(b.Modelo))))) mg
    CROSS APPLY (VALUES
            (N'Fe',1,Fe_ppm,Fe_LP,Fe_LC),
            (N'PQ',2,Indice_PQ,PQ_LP,PQ_LC),
            (N'Cr',3,Cr_ppm,Cr_LP,Cr_LC),
            (N'Ni',4,Ni_ppm,Ni_LP,Ni_LC),
            (N'Cu',5,Cu_ppm,Cu_LP,Cu_LC),
            (N'Pb',6,Pb_ppm,Pb_LP,Pb_LC),
            (N'Sn',7,Sn_ppm,Sn_LP,Sn_LC),
            (N'Al',8,Al_ppm,Al_LP,Al_LC),
            (N'Si',9,Si_ppm,Si_LP,Si_LC)
    ) p(metal, Orden, val, lp, lc)
    WHERE b.rn_recencia = 1 AND p.val IS NOT NULL
),
eqmax AS (   -- por equipo+comptipo+metal: el PEOR (MAX) valor del equipo (combina lados LH/RH)
    SELECT Proyecto, Modelo, CompTipo, metal, Orden, Equipo,
        MAX(val) AS val, MAX(lp) AS lp, MAX(lc) AS lc
    FROM s GROUP BY Proyecto, Modelo, CompTipo, metal, Orden, Equipo
),
rk AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY Proyecto, Modelo, CompTipo, metal ORDER BY val DESC, Equipo) AS pos
    FROM eqmax
)
SELECT
    Proyecto, Modelo, CompTipo, metal AS Metal, pos,
    CAST(N'| ' + CAST(pos AS nvarchar(10)) + N' | ' + Equipo + N' | ' + CONVERT(nvarchar(20), CAST(val AS decimal(18,1)))
       + N' | ' + ISNULL(CONVERT(nvarchar(20), CAST(lp AS decimal(18,1))), N'—') + N'/' + ISNULL(CONVERT(nvarchar(20), CAST(lc AS decimal(18,1))), N'—')
       + N' | ' + CASE WHEN lc IS NOT NULL AND val > lc THEN N'🟥' WHEN lp IS NOT NULL AND val > lp THEN N'🟨' ELSE N'—' END + N' |' AS nvarchar(max)) AS Fila,
    CAST(N'**Ranking ' + metal + N' — ' + CASE CompTipo WHEN 'TRACCION' THEN N'Motor de Traccion' WHEN 'HIDRAULICO' THEN N'Sistema Hidraulico' WHEN 'RUEDA' THEN N'Rueda Delantera' WHEN 'MANDO' THEN N'Mando Final' WHEN 'TRANSMISION' THEN N'Transmision' WHEN 'MOTOR' THEN N'Motor' ELSE CompTipo END + N' · ' + Proyecto
       + CASE WHEN Modelo <> N'(todos)' THEN N' · ' + Modelo ELSE N'' END + N'**' + NCHAR(10) + NCHAR(10)
       + N'| # | Equipo | ' + metal + N' | LP/LC | Est. |' + NCHAR(10) + N'|---|---|---|---|---|' AS nvarchar(max)) AS HeaderMD
FROM rk
/* L4 (29/09): el corte sube de 20 a 50. El flujo ya aplica el top que pide el usuario
   (`AND pos <= if(empty(‹top›),'10',‹top›)`), asi que este numero es solo un techo de
   seguridad -- pero con 20 era un TOPE SILENCIOSO: pedir "top 30" devolvia 20 y nadie
   lo decia. 50 filas por (proyecto, modelo, comptipo, metal) es trivial. */
WHERE pos <= 50;
GO

/* ==== vw_TendenciaMetalFlotaMD (Gap 1: tendencia de un metal en un CompTipo, a nivel flota) ==== */
CREATE OR ALTER VIEW [dbo].[vw_TendenciaMetalFlotaMD] AS
WITH te AS (
    SELECT Proyecto, CompTipo, Parametro, Equipo, LP, LC, d6, Tendencia, Prom, Sigma, Acumulado, Orden, Spark,
        CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Hidr' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE ISNULL(Compartimiento, N'(sin componente)') END AS compAbbr,
        CASE Tendencia WHEN N'↑' THEN 1 WHEN N'→' THEN 2 ELSE 3 END AS tendOrd,
        CASE CompTipo WHEN 'TRACCION' THEN N'Motor de Traccion' WHEN 'HIDRAULICO' THEN N'Sistema Hidraulico' WHEN 'RUEDA' THEN N'Rueda Delantera' WHEN 'MANDO' THEN N'Mando Final' WHEN 'TRANSMISION' THEN N'Transmision' WHEN 'MOTOR' THEN N'Motor' ELSE CompTipo END AS compLabel
    FROM [dbo].[vw_TendenciaElemento]
),
rows_ AS (
    SELECT Proyecto, CompTipo, Parametro, tendOrd, Prom,
        CAST(N'| ' + Equipo + N' | ' + compAbbr
           + N' | ' + ISNULL(REPLACE(REPLACE(CAST(d6 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'·')
           + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(Prom AS decimal(18,1))), N'—')
           + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(Sigma AS decimal(18,1))), N'—')
           + N' | ' + ISNULL(Tendencia, N'—')
           + N' | ' + ISNULL(Spark, N'·') + N' |' AS nvarchar(max)) AS rowMD
    FROM te
),
body AS (
    SELECT Proyecto, CompTipo, Parametro,
        STRING_AGG(rowMD, NCHAR(10)) WITHIN GROUP (ORDER BY tendOrd, Prom DESC) AS bodyMD
    FROM rows_ GROUP BY Proyecto, CompTipo, Parametro
)
SELECT
    b.Proyecto, N'(todos)' AS Modelo, b.CompTipo, b.Parametro AS Metal,
    CAST(NULL AS nvarchar(max)) AS Observados,
    CAST(NULL AS nvarchar(max)) AS Recomendaciones,
    CAST(
        N'**Tendencia de ' + b.Parametro + N' — ' + CASE b.CompTipo WHEN 'TRACCION' THEN N'Motor de Traccion' WHEN 'HIDRAULICO' THEN N'Sistema Hidraulico' WHEN 'RUEDA' THEN N'Rueda Delantera' WHEN 'MANDO' THEN N'Mando Final' WHEN 'TRANSMISION' THEN N'Transmision' WHEN 'MOTOR' THEN N'Motor' ELSE b.CompTipo END + N' · ' + b.Proyecto + N' (flota)**' + NCHAR(10)
      + N'_Dirección por equipo: ↑ sube · ↓ baja · → estable (últimas 6 muestras)._' + NCHAR(10) + NCHAR(10)
      + N'| Equipo | Comp | Última | Prom | σ | Tend | Spark |' + NCHAR(10)
      + N'|---|---|---|---|---|---|---|' + NCHAR(10) + b.bodyMD
    AS nvarchar(max)) AS MD
FROM body b;
GO

/* ==== vw_CondicionCompMD (Gap 2: condición de un CompTipo en la flota) ==== */
CREATE OR ALTER VIEW [dbo].[vw_CondicionCompMD] AS
WITH base AS (
    SELECT b.Proyecto, mg.ModeloG AS Modelo, b.CompTipo, b.Equipo, b.Compartimiento, b.Grado,
        b.FechaMuestreo, b.HorasComponente, b.CM, b.Estado_General, b.Mets_Obs, b.Infs_Obs,
        CASE WHEN b.Estado_General='CRITICO' THEN 1 ELSE 2 END AS sev
    FROM [dbo].[vw_ObservadosFlota] b
    CROSS APPLY (SELECT b.Modelo AS ModeloG
             UNION ALL
             SELECT N'(todos)' WHERE EXISTS (
                 SELECT 1 FROM [dbo].[vw_ModeloConLimites] ml
                 WHERE ml.ProyKey   = UPPER(LTRIM(RTRIM(b.Proyecto)))
                   AND ml.ModeloKey = UPPER(LTRIM(RTRIM(b.Modelo))))) mg
    WHERE b.Estado_General <> 'OK'
),
rows_ AS (
    SELECT Proyecto, Modelo, CompTipo, sev, Equipo,
        CAST(N'| ' + Equipo + N' | ' + ISNULL(Grado, N'—')
           + N' | ' + ISNULL(FORMAT(FechaMuestreo,'dd-MMM'), N'—')
           + N' | ' + ISNULL(CONVERT(nvarchar(12), CAST(HorasComponente AS decimal(18,0))), N'—')
           + N' | ' + ISNULL(CM, N'—')
           + N' | ' + CASE Estado_General WHEN 'CRITICO' THEN N'🟥' WHEN 'PRECAUCION' THEN N'🟨' ELSE N'' END
           + N' | ' + ISNULL(REPLACE(REPLACE(REPLACE(Mets_Obs,':C',N' 🟥'),':P',N' 🟨'),',',N' · '), N'—')
             + CASE WHEN Infs_Obs IS NOT NULL THEN N' · ' + REPLACE(REPLACE(REPLACE(Infs_Obs,':C',N' 🟥'),':P',N' 🟨'),',',N' · ') ELSE N'' END
           + N' |' AS nvarchar(max)) AS rowMD
    FROM base
),
cnt AS (
    SELECT Proyecto, Modelo, CompTipo,
        COUNT(DISTINCT Equipo) AS nObs,
        COUNT(DISTINCT CASE WHEN Estado_General='CRITICO' THEN Equipo END) AS nCrit
    FROM base GROUP BY Proyecto, Modelo, CompTipo
),
body AS (
    SELECT Proyecto, Modelo, CompTipo, STRING_AGG(rowMD, NCHAR(10)) WITHIN GROUP (ORDER BY sev, Equipo) AS bodyMD
    FROM rows_ GROUP BY Proyecto, Modelo, CompTipo
)
SELECT
    c.Proyecto, c.Modelo, c.CompTipo, N'(todos)' AS Metal,
    CAST(NULL AS nvarchar(max)) AS Observados,
    CAST(NULL AS nvarchar(max)) AS Recomendaciones,
    CAST(
        N'**Condición ' + CASE c.CompTipo WHEN 'TRACCION' THEN N'Motores de Traccion' WHEN 'HIDRAULICO' THEN N'Sistemas Hidraulicos' WHEN 'RUEDA' THEN N'Ruedas Delanteras' WHEN 'MANDO' THEN N'Mandos Finales' WHEN 'TRANSMISION' THEN N'Transmisiones' WHEN 'MOTOR' THEN N'Motores' ELSE c.CompTipo END + N' — ' + c.Proyecto + N'** · ' + CAST(c.nObs AS nvarchar(10))
      + N' observados (' + CAST(c.nCrit AS nvarchar(10)) + N' críticos)' + NCHAR(10) + NCHAR(10)
      + CASE WHEN b.bodyMD IS NOT NULL THEN
            N'| Equipo | Grado | Fec. | Hor.Comp. | T. muestra | Est. | Observado |' + NCHAR(10)
          + N'|---|---|---|---|---|---|---|' + NCHAR(10) + b.bodyMD
        ELSE N'_Ninguno observado — todos dentro de límite._' END
    AS nvarchar(max)) AS MD
FROM cnt c
LEFT JOIN body b ON b.Proyecto=c.Proyecto AND b.Modelo=c.Modelo AND b.CompTipo=c.CompTipo;
GO

/* ==== vw_UltimoMetalFlotaMD (Ultimo analisis en barrido por metal: 1..N metales, flota de un CompTipo) ==== */
CREATE OR ALTER VIEW [dbo].[vw_UltimoMetalFlotaMD] AS
WITH base AS (
    SELECT u.Proyecto, u.Modelo, u.CompTipo, u.Equipo, u.Compartimiento, u.FechaMuestreo, u.Horometro, u.HorasComponente, u.CM,
        CASE WHEN u.Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN u.Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN u.Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN u.Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN u.Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN u.Compartimiento='MOTOR' THEN N'Motor' ELSE u.Compartimiento END AS compAbbr,
        p.Metal, p.Orden AS MetalOrden, p.Inf, p.Inv,
        CAST(p.Valor AS decimal(18,2)) AS Valor, CAST(p.LP AS decimal(18,2)) AS LP, CAST(p.LC AS decimal(18,2)) AS LC
    FROM [dbo].[vw_UltimoAnalisisAceite] u
    CROSS APPLY (VALUES
        (N'Fe',1,0,0,u.Fe_ppm,u.Fe_LP,u.Fe_LC),
        (N'PQ',2,0,0,u.Indice_PQ,u.PQ_LP,u.PQ_LC),
        (N'Cr',3,0,0,u.Cr_ppm,u.Cr_LP,u.Cr_LC),
        (N'Ni',4,0,0,u.Ni_ppm,u.Ni_LP,u.Ni_LC),
        (N'Cu',5,0,0,u.Cu_ppm,u.Cu_LP,u.Cu_LC),
        (N'Pb',6,0,0,u.Pb_ppm,u.Pb_LP,u.Pb_LC),
        (N'Sn',7,0,0,u.Sn_ppm,u.Sn_LP,u.Sn_LC),
        (N'Al',8,0,0,u.Al_ppm,u.Al_LP,u.Al_LC),
        (N'Si',9,0,0,u.Si_ppm,u.Si_LP,u.Si_LC),
        (N'Ca',10,1,0,u.Ca_ppm,u.Ca_LP,u.Ca_LC),
        (N'Zn',11,1,0,u.Zn_ppm,u.Zn_LP,u.Zn_LC),
        (N'K',12,1,0,u.K_ppm,u.K_LP,u.K_LC),
        (N'Na',13,1,0,u.Na_ppm,u.Na_LP,u.Na_LC),
        (N'Mg',14,1,0,u.Mg_ppm,u.Mg_LP,u.Mg_LC),
        (N'B',15,1,0,u.B_ppm,NULL,NULL),
        (N'P',16,1,0,u.P_ppm,NULL,NULL),
        (N'V100',17,1,0,u.V100,NULL,NULL),
        (N'TBN',18,0,1,u.TBN,u.TBN_LP,NULL)
    ) p(Metal, Orden, Inf, Inv, Valor, LP, LC)
    WHERE u.Compartimiento IS NOT NULL AND LTRIM(RTRIM(u.Compartimiento)) <> '' AND p.Valor IS NOT NULL
),
mg AS (
    SELECT b.*, g.ModeloG FROM base b CROSS APPLY (SELECT b.Modelo AS ModeloG
             UNION ALL
             SELECT N'(todos)' WHERE EXISTS (
                 SELECT 1 FROM [dbo].[vw_ModeloConLimites] ml
                 WHERE ml.ProyKey   = UPPER(LTRIM(RTRIM(b.Proyecto)))
                   AND ml.ModeloKey = UPPER(LTRIM(RTRIM(b.Modelo))))) g
),
mr AS (   -- limite de REFERENCIA del grupo (para juzgar filas cuyo LP/LC propio viene NULL).
          -- SOLO dentro de UN modelo (mismo limite); en '(todos)' NO se cruza (modelos distintos = limites distintos,
          -- ej. hidraulico varia por modelo) -> fila sin limite propio queda sin chip en vez de juzgarse mal.
    SELECT *,
        CASE WHEN ModeloG = N'(todos)' THEN LP ELSE ISNULL(LP, MAX(LP) OVER (PARTITION BY Proyecto, ModeloG, CompTipo, Metal)) END AS LPx,
        CASE WHEN ModeloG = N'(todos)' THEN LC ELSE ISNULL(LC, MAX(LC) OVER (PARTITION BY Proyecto, ModeloG, CompTipo, Metal)) END AS LCx
    FROM mg
),
r AS (
    SELECT Proyecto, ModeloG, CompTipo, Metal, MetalOrden, Valor,
        MAX(LP) OVER (PARTITION BY Proyecto, ModeloG, CompTipo, Metal) AS LPref,
        MAX(LC) OVER (PARTITION BY Proyecto, ModeloG, CompTipo, Metal) AS LCref,
        CASE WHEN Inf=1 THEN 0 WHEN Inv=1 THEN CASE WHEN LPx IS NOT NULL AND Valor>0 AND Valor<LPx THEN 1 ELSE 0 END
             ELSE CASE WHEN Valor>ISNULL(LPx,999999) THEN 1 ELSE 0 END END AS Obs,
        CASE WHEN Inf=0 AND Inv=0 AND Valor>ISNULL(LCx,999999) THEN 1 ELSE 0 END AS Crit,
        CAST(N'| ' + Equipo + N' | ' + compAbbr + N' | ' + ISNULL(FORMAT(FechaMuestreo,'dd-MMM-yy'), N'—')
           + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(Horometro AS decimal(18,0))), N'—')
           + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(HorasComponente AS decimal(18,0))), N'—')
           + N' | ' + ISNULL(CM, N'—') + N' | '
           + CASE WHEN Inf=1 THEN CONVERT(nvarchar(20),CAST(Valor AS decimal(18,1)))
                  WHEN Inv=1 THEN CONVERT(nvarchar(20),CAST(Valor AS decimal(18,1))) + CASE WHEN LPx IS NOT NULL AND Valor>0 AND Valor<LPx THEN N' 🟨' ELSE N'' END
                  WHEN Valor>ISNULL(LCx,999999) THEN CONVERT(nvarchar(20),CAST(Valor AS decimal(18,1))) + N' 🟥'
                  WHEN Valor>ISNULL(LPx,999999) THEN CONVERT(nvarchar(20),CAST(Valor AS decimal(18,1))) + N' 🟨'
                  ELSE CONVERT(nvarchar(20),CAST(Valor AS decimal(18,1))) END
           + CASE WHEN ROUND(Valor,1)=0 THEN N' ⚠️' ELSE N'' END   -- 0 en el metal (no-DDI) = posible falso positivo
           + N' |' AS nvarchar(max)) AS rowMD
    FROM mr
),
body AS (
    SELECT Proyecto, ModeloG, CompTipo, Metal, MetalOrden,
        COUNT(*) AS nTot, SUM(Obs) AS nObs, SUM(Crit) AS nCrit, MAX(LPref) AS LPh, MAX(LCref) AS LCh,
        STRING_AGG(rowMD, NCHAR(10)) WITHIN GROUP (ORDER BY Valor DESC, Metal) AS bodyMD
    FROM r GROUP BY Proyecto, ModeloG, CompTipo, Metal, MetalOrden
)
SELECT
    b.Proyecto, b.ModeloG AS Modelo, b.CompTipo, b.Metal, b.MetalOrden,
    CAST(NULL AS nvarchar(max)) AS Observados,
    -- Recomendaciones (verbatim vw_Recomendaciones) SOLO si el componente es MT y el metal salio observado en la flota
    CASE WHEN b.CompTipo = N'TRACCION' AND b.nObs > 0 AND rc.indicio IS NOT NULL
         THEN CAST(N'- **' + rc.label + N':** ' + rc.indicio AS nvarchar(max)) ELSE NULL END AS Recomendaciones,
    CAST(
        N'**Último análisis de ' + b.Metal + N' — ' + CASE b.CompTipo WHEN 'TRACCION' THEN N'Motores de Traccion' WHEN 'HIDRAULICO' THEN N'Sistemas Hidraulicos' WHEN 'RUEDA' THEN N'Ruedas Delanteras' WHEN 'MANDO' THEN N'Mandos Finales' WHEN 'TRANSMISION' THEN N'Transmisiones' WHEN 'MOTOR' THEN N'Motores' ELSE b.CompTipo END + N' · ' + b.Proyecto
      + CASE WHEN b.ModeloG <> N'(todos)' THEN N' · ' + b.ModeloG ELSE N'' END + N'** · '
      + CAST(b.nTot AS nvarchar(10)) + N' equipos (' + CAST(b.nObs AS nvarchar(10)) + N' observados, ' + CAST(b.nCrit AS nvarchar(10)) + N' críticos)' + NCHAR(10)
      + N'_Límites de referencia: LP ' + ISNULL(CONVERT(nvarchar(20),CAST(b.LPh AS decimal(18,1))), N'—') + N' · LC ' + ISNULL(CONVERT(nvarchar(20),CAST(b.LCh AS decimal(18,1))), N'—') + N' ppm._' + NCHAR(10) + NCHAR(10)
      + N'| Equipo | Comp | Fecha | SMR | Hrs C. | T. muestra | ' + b.Metal + N' (ppm) |' + NCHAR(10)
      + N'|---|---|---|---|---|---|---|' + NCHAR(10) + b.bodyMD
    AS nvarchar(max)) AS MD
FROM body b
LEFT JOIN [dbo].[vw_Recomendaciones] rc ON rc.metal = b.Metal;
GO

/* ==== vw_AcumuladosFlotaMD (wrapper KomfIA del Ranking de Atencion / acumulados motor diesel) ==== */
CREATE OR ALTER VIEW [dbo].[vw_AcumuladosFlotaMD] AS
WITH base AS (   -- ultima foto por equipo de vw_RankingHistorico (reemplazo VIGENTE; incluye lixiviacion de Cu)
    SELECT z.* FROM (
        SELECT rh.*, ROW_NUMBER() OVER (PARTITION BY rh.[N° Int.] ORDER BY rh.Fecha DESC, rh.[Horas Motor Actual] DESC) AS _rn
        FROM [dbo].[vw_RankingHistorico] rh
    ) z WHERE z._rn = 1
),
ranked AS (
    SELECT r.*, CASE WHEN r.[Ranking] >= 70 THEN N'🟥 Crítico' WHEN r.[Ranking] >= 65 THEN N'🟧 Alerta' WHEN r.[Ranking] >= 60 THEN N'🟨 Atención' ELSE N'🟢 Monitoreo' END AS Estado, ROW_NUMBER() OVER (ORDER BY r.[Ranking] DESC, r.[N° Int.]) AS Pos
    FROM base r
),
rows_ AS (
    SELECT Pos,
        CAST(N'| ' + CONVERT(nvarchar(10), Pos) + N' | ' + ISNULL(CONVERT(nvarchar(40), r.[N° Int.]), N'—') + N' | ' + ISNULL(CONVERT(nvarchar(40), r.[Serie]), N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20), r.[Horas Motor Actual]), N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20), r.[Horas Motor Metal]), N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20), r.[Fe Acum]), N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20), r.[Cr Acum]), N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20), r.[Pb Acum]), N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20), r.[Cu Acum]), N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20), r.[Na Acum]), N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20), r.[K Acum]), N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20), r.[Si Acum]), N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20), r.[Ranking]), N'—') + N' | ' + Estado + N' |' AS nvarchar(max)) AS rowMD
    FROM ranked r
),
body AS (
    SELECT STRING_AGG(rowMD, NCHAR(10)) WITHIN GROUP (ORDER BY Pos) AS bodyMD, COUNT(*) AS N FROM rows_
)
SELECT
    N'Antapaccay' AS Proyecto, N'(todos)' AS Modelo, N'MOTOR' AS CompTipo,
    CAST(NULL AS nvarchar(max)) AS Observados, CAST(NULL AS nvarchar(max)) AS Recomendaciones,
    CAST(
        N'**Ranking de Atención — Motor Diésel · Antapaccay** · ' + CONVERT(nvarchar(10), b.N) + N' equipos' + NCHAR(10) + NCHAR(10)
      + N'| Pos. | Equipo | Serie | H.Motor | H.Metal | Fe | Cr | Pb | Cu | Na | K | Si | Ranking | Estado |' + NCHAR(10) + N'|---|---|---|---|---|---|---|---|---|---|---|---|---|---|' + NCHAR(10) + b.bodyMD
    AS nvarchar(max)) AS MD
FROM body b;
GO

/* ==== vw_AcumuladosEquipoMD (wrapper KomfIA acumulados motor diesel) ==== */
CREATE OR ALTER VIEW [dbo].[vw_AcumuladosEquipoMD] AS
WITH base AS (   -- ultima foto por equipo de vw_RankingHistorico (reemplazo VIGENTE; incluye lixiviacion de Cu)
    SELECT z.* FROM (
        SELECT rh.*, ROW_NUMBER() OVER (PARTITION BY rh.[N° Int.] ORDER BY rh.Fecha DESC, rh.[Horas Motor Actual] DESC) AS _rn
        FROM [dbo].[vw_RankingHistorico] rh
    ) z WHERE z._rn = 1
),
m AS (
    SELECT r.[N° Int.] AS Equipo, r.[Serie] AS Serie, r.[Horas Motor Actual] AS HMotor, r.[Horas Motor Metal] AS HMetal, r.[Ranking] AS Ranking,
        CASE WHEN r.[Ranking] >= 70 THEN N'🟥 Crítico' WHEN r.[Ranking] >= 65 THEN N'🟧 Alerta' WHEN r.[Ranking] >= 60 THEN N'🟨 Atención' ELSE N'🟢 Monitoreo' END AS Estado,
        STRING_AGG(CONVERT(nvarchar(max), N'| ' + mm.metal + N' | ' + ISNULL(CONVERT(nvarchar(20), mm.acum), N'—') + N' |'), NCHAR(10)) WITHIN GROUP (ORDER BY mm.ord) AS bodyMD
    FROM base r
    CROSS APPLY (VALUES
        (1,N'Fe',r.[Fe Acum]),(2,N'Cr',r.[Cr Acum]),(3,N'Pb',r.[Pb Acum]),(4,N'Cu',r.[Cu Acum]),
        (5,N'Na',r.[Na Acum]),(6,N'K',r.[K Acum]),(7,N'Si',r.[Si Acum])
    ) mm(ord, metal, acum)
    GROUP BY r.[N° Int.], r.[Serie], r.[Horas Motor Actual], r.[Horas Motor Metal], r.[Ranking]
)
SELECT
    Equipo, N'Antapaccay' AS Proyecto, N'MOTOR' AS CompTipo,
    CAST(NULL AS nvarchar(max)) AS Observados, CAST(NULL AS nvarchar(max)) AS Recomendaciones,
    CAST(
        N'**Acumulados — Motor Diésel · ' + Equipo + N' (Antapaccay)**' + NCHAR(10)
      + N'_Serie ' + ISNULL(Serie, N'—') + N' · Horas motor ' + ISNULL(CONVERT(nvarchar(20), HMotor), N'—')
        + N' · Horas metal ' + ISNULL(CONVERT(nvarchar(20), HMetal), N'—')
        + N' · Ranking ' + ISNULL(CONVERT(nvarchar(20), Ranking), N'—') + N' · ' + Estado + N'_' + NCHAR(10) + NCHAR(10)
      + N'| Metal | Acumulado |' + NCHAR(10) + N'|---|---|' + NCHAR(10) + bodyMD
    AS nvarchar(max)) AS MD
FROM m;
GO


/* ==== vw_RankingGrafMD (P5: version GRAFICA del Ranking de Atencion, barras horizontales ASCII) ==== */
/* Misma data que vw_AcumuladosFlotaMD (ultima foto de vw_RankingHistorico), mismo orden y mismo desempate.
   Escala FIJA 0-75 sobre 45 caracteres -> las bandas 60/65/70 caen siempre en las columnas 36/39/42 de la
   barra y se dibujan como lineas verticales que atraviesan el grafico, como en el dashboard. Fija, no al
   maximo del dato: si no, las bandas se moverian entre proyectos y dejarian de ser comparables.
   El rombo sale de la lista manual 'interv', espejo del DAX del PBI -> ver DEPENDENCIA_RankingAtencion.md. */
CREATE OR ALTER VIEW [dbo].[vw_RankingGrafMD] AS
WITH interv AS (   -- EQUIPOS INTERVENIDOS: lista MANUAL (al 2026-09-21). Para agregar o quitar, editar SOLO estas filas.
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
),
ranked AS (
    SELECT r.[N° Int.] AS Equipo, r.[Ranking], r.[Horas Motor Actual] AS HMotor, r.[Horas Motor Metal] AS HMetal,
        CASE WHEN r.[Ranking] >= 70 THEN N'🟥' WHEN r.[Ranking] >= 65 THEN N'🟧' WHEN r.[Ranking] >= 60 THEN N'🟨' ELSE N'🟢' END AS Chip,
        CASE WHEN r.[Ranking] >= 70 THEN N'Crí.' WHEN r.[Ranking] >= 65 THEN N'Ale.' WHEN r.[Ranking] >= 60 THEN N'Ate.' ELSE N'Mon.' END AS Abrev,
        CASE WHEN i.Equipo IS NULL THEN N' ' ELSE N'◆' END AS Rombo,
        ROW_NUMBER() OVER (ORDER BY r.[Ranking] DESC, r.[N° Int.]) AS Pos,
        CASE WHEN r.[Ranking] IS NULL OR r.[Ranking] < 0 THEN 0
             WHEN r.[Ranking] > 75 THEN 45
             ELSE CAST(ROUND(r.[Ranking] / 75.0 * 45, 0) AS int) END AS Largo
    FROM base r
    LEFT JOIN interv i ON i.Equipo = r.[N° Int.]
),
barras AS (   -- barra de ancho fijo (45); las 3 marcas solo se pintan donde la barra todavia no llega
    SELECT q.*,
        STUFF(STUFF(STUFF(
            REPLICATE(N'█', q.Largo) + REPLICATE(N' ', 45 - q.Largo),
            42, CASE WHEN q.Largo < 42 THEN 1 ELSE 0 END, CASE WHEN q.Largo < 42 THEN N'|' ELSE N'' END),
            39, CASE WHEN q.Largo < 39 THEN 1 ELSE 0 END, CASE WHEN q.Largo < 39 THEN N'|' ELSE N'' END),
            36, CASE WHEN q.Largo < 36 THEN 1 ELSE 0 END, CASE WHEN q.Largo < 36 THEN N'|' ELSE N'' END) AS Barra
    FROM ranked q
),
filas AS (
    SELECT b.Pos, b.Rombo,
        CAST(
            RIGHT(N'      ' + ISNULL(CONVERT(nvarchar(20), b.Equipo), N'—'), 6) + N' '
          + b.Barra + N' '
          + RIGHT(N'      ' + ISNULL(CONVERT(nvarchar(20), CAST(b.Ranking AS decimal(6,2))), N'—'), 6) + N' '
          + b.Rombo + N' '
          + RIGHT(N'      ' + ISNULL(CONVERT(nvarchar(20), b.HMotor), N'—'), 6) + N'  '
          + RIGHT(N'      ' + ISNULL(CONVERT(nvarchar(20), b.HMetal), N'—'), 6) + N' '
          + b.Abrev + N' ' + b.Chip
        AS nvarchar(max)) AS Fila
    FROM barras b
),
cuerpo AS (
    SELECT STRING_AGG(Fila, NCHAR(10)) WITHIN GROUP (ORDER BY Pos) AS bodyMD,
           COUNT(*) AS N,
           SUM(CASE WHEN Rombo = N'◆' THEN 1 ELSE 0 END) AS NInterv
    FROM filas
)
SELECT
    N'Antapaccay' AS Proyecto, N'(todos)' AS Modelo, N'MOTOR' AS CompTipo,
    CAST(NULL AS nvarchar(max)) AS Observados, CAST(NULL AS nvarchar(max)) AS Recomendaciones,
    CAST(
        N'**Ranking de Atención — Motor Diésel · Antapaccay** · ' + CONVERT(nvarchar(10), c.N) + N' equipos (gráfica)' + NCHAR(10)
      + N'_Ranking = Pb·0.68 + Cu·0.17 + Cr·0.07 + (Fe·Na·K·Si)·0.02. Escala 0–75, con las 3 líneas de 60, 65 y 70. Estado: **Mon.** Monitoreo (<60) · **Ate.** Atención · **Ale.** Alerta · **Crí.** Crítico. ◆ = equipo intervenido (' + CONVERT(nvarchar(10), c.NInterv) + N'). H.Motor = horas del motor actual · H.Metal = horas desde el último cambio de metal. El detalle por metal está en el ranking de acumulados._' + NCHAR(10) + NCHAR(10)
      + N'```' + NCHAR(10)
      + N'                                         60 65 70' + NCHAR(10)
      + N'Equipo                                    v  v  v      Rank  H.Motor H.Metal Estado' + NCHAR(10)
      + c.bodyMD + NCHAR(10)
      + N'```'
    AS nvarchar(max)) AS MD
FROM cuerpo c;
GO
