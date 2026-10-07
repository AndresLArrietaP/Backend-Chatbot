/* RESPALDO 07/10/2026 -- vw_DiagnosticoMD antes de la lectura unica (BLOQUE 203).
   Para revertir: ejecutar este archivo completo en SSMS. Etiqueta git: respaldo-antes-1lectura-diagnostico-2026-10-07. */

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
      + N'_SMR (horómetro) ' + ISNULL(CONVERT(nvarchar(20), CAST(g.SMR AS decimal(18,0))), N'—') + N' · última muestra ' + ISNULL(FORMAT(g.FecUlt,'dd-MMM-yy'), N'—') + N'_' + NCHAR(10) + NCHAR(10)
      + CASE WHEN bo.bodyMD IS NULL THEN
             /* Equipo SANO: 0 componentes observados. Antes la tabla quedaba vacia y todo el MD se volvia
                NULL -> el flujo respondia 'no encontre datos', que suena a que el equipo no existe. La
                respuesta correcta es decir que NO tiene observados: es justo lo que se pregunto. */
             N'_Ninguno de sus ' + CAST(g.NumCompTotal AS nvarchar(10)) + N' componentes tiene parámetros fuera de límite._'
        ELSE
             N'| Par. | ' + ho.cols + N' |' + NCHAR(10)
           + N'|---|' + REPLICATE(N'---|', ho.N) + NCHAR(10)
           + N'| **Muestra** |' + REPLICATE(N' |', ho.N) + NCHAR(10) + N'| Fec. últ. | ' + ho.fecs + N' |' + NCHAR(10) + N'| H. Comp. | ' + ho.hcs + N' |' + NCHAR(10) + N'| T. muestra | ' + ho.cms + N' |' + NCHAR(10)
           + bo.bodyMD + NCHAR(10) + NCHAR(10) + N'_`Ca`, `Mg`, `Mo` y `Zn` cambian de sentido según la columna: en **Motor de Tracción** (MT LH / MT RH) son **contaminantes** y la alerta es por **ENCIMA** del límite; en **los demás componentes** son **aditivos** y la alerta es por **DEBAJO** (el aditivo se agota)._'
        END
    AS nvarchar(max)) AS MD,
    CAST(
        N'**Diagnóstico ' + g.Equipo + N' (completo) — ' + CAST(g.NumCompTotal AS nvarchar(10)) + N' componentes**' + NCHAR(10) + NCHAR(10)
      + N'_SMR (horómetro) ' + ISNULL(CONVERT(nvarchar(20), CAST(g.SMR AS decimal(18,0))), N'—') + N' · última muestra ' + ISNULL(FORMAT(g.FecUlt,'dd-MMM-yy'), N'—') + N'_' + NCHAR(10) + NCHAR(10)
      + N'| Par. | ' + ha.cols + N' |' + NCHAR(10)
      + N'|---|' + REPLICATE(N'---|', ha.N) + NCHAR(10)
      + N'| **Muestra** |' + REPLICATE(N' |', ha.N) + NCHAR(10) + N'| Fec. últ. | ' + ha.fecs + N' |' + NCHAR(10) + N'| H. Comp. | ' + ha.hcs + N' |' + NCHAR(10) + N'| T. muestra | ' + ha.cms + N' |' + NCHAR(10)
      + ba.bodyMD + NCHAR(10) + NCHAR(10) + N'_`Ca`, `Mg`, `Mo` y `Zn` cambian de sentido según la columna: en **Motor de Tracción** (MT LH / MT RH) son **contaminantes** y la alerta es por **ENCIMA** del límite; en **los demás componentes** son **aditivos** y la alerta es por **DEBAJO** (el aditivo se agota)._'
    AS nvarchar(max)) AS MD_Completo
FROM (
    SELECT Equipo, MAX(Proyecto) AS Proyecto, MAX(Modelo) AS Modelo,
        SUM(CASE WHEN CompMarcado = 1 THEN 1 ELSE 0 END) AS NumCompObs,
        COUNT(*) AS NumCompTotal,
        MAX(Hor) AS SMR, MAX(Fec) AS FecUlt
    FROM (   /* 1 fila por equipo+componente, DERIVADA de unpv.
               Antes hdr_all, hdr_obs y g leian 'base' por su cuenta (3 lecturas de una cadena de
               4 vistas). unpv ya trae cada componente 31 veces: agrupar aqui sale gratis. */
    SELECT Equipo, Compartimiento,
           MAX(Proyecto)    AS Proyecto,
           MAX(Modelo)      AS Modelo,
           MAX(compOrd)     AS compOrd,
           MAX(compAbbr)    AS compAbbr,
           MAX(CompMarcado) AS CompMarcado,
           MAX(FechaMuestreo) AS Fec, MAX(Horometro) AS Hor, MAX(HorasComponente) AS HC, MAX(CM) AS CMc
    FROM (   /* Las filas salen del formato CRUZADO (union de las 4 hojas, 31 parametros): esta tabla es
               parametros x COMPONENTES, asi que no puede seguir el formato de un solo componente. */
    SELECT b.Equipo, b.Proyecto, b.Modelo, b.Compartimiento, b.compOrd, b.compAbbr, b.CompMarcado, b.FechaMuestreo, b.Horometro, b.HorasComponente, b.CM,
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
        STRING_AGG(compAbbr, N' | ') WITHIN GROUP (ORDER BY compOrd) AS cols,
        STRING_AGG(ISNULL(FORMAT(Fec,'dd-MMM'), N'—'), N' | ') WITHIN GROUP (ORDER BY compOrd) AS fecs,
        STRING_AGG(ISNULL(CONVERT(nvarchar(20), CAST(HC AS decimal(18,0))), N'—'), N' | ') WITHIN GROUP (ORDER BY compOrd) AS hcs,
        STRING_AGG(ISNULL(CONVERT(nvarchar(20), CMc), N'—'), N' | ') WITHIN GROUP (ORDER BY compOrd) AS cms
    FROM (   /* 1 fila por equipo+componente, DERIVADA de unpv.
               Antes hdr_all, hdr_obs y g leian 'base' por su cuenta (3 lecturas de una cadena de
               4 vistas). unpv ya trae cada componente 31 veces: agrupar aqui sale gratis. */
    SELECT Equipo, Compartimiento,
           MAX(Proyecto)    AS Proyecto,
           MAX(Modelo)      AS Modelo,
           MAX(compOrd)     AS compOrd,
           MAX(compAbbr)    AS compAbbr,
           MAX(CompMarcado) AS CompMarcado,
           MAX(FechaMuestreo) AS Fec, MAX(Horometro) AS Hor, MAX(HorasComponente) AS HC, MAX(CM) AS CMc
    FROM (   /* Las filas salen del formato CRUZADO (union de las 4 hojas, 31 parametros): esta tabla es
               parametros x COMPONENTES, asi que no puede seguir el formato de un solo componente. */
    SELECT b.Equipo, b.Proyecto, b.Modelo, b.Compartimiento, b.compOrd, b.compAbbr, b.CompMarcado, b.FechaMuestreo, b.Horometro, b.HorasComponente, b.CM,
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
        STRING_AGG(compAbbr, N' | ') WITHIN GROUP (ORDER BY compOrd) AS cols,
        STRING_AGG(ISNULL(FORMAT(Fec,'dd-MMM'), N'—'), N' | ') WITHIN GROUP (ORDER BY compOrd) AS fecs,
        STRING_AGG(ISNULL(CONVERT(nvarchar(20), CAST(HC AS decimal(18,0))), N'—'), N' | ') WITHIN GROUP (ORDER BY compOrd) AS hcs,
        STRING_AGG(ISNULL(CONVERT(nvarchar(20), CMc), N'—'), N' | ') WITHIN GROUP (ORDER BY compOrd) AS cms
    FROM (   /* 1 fila por equipo+componente, DERIVADA de unpv.
               Antes hdr_all, hdr_obs y g leian 'base' por su cuenta (3 lecturas de una cadena de
               4 vistas). unpv ya trae cada componente 31 veces: agrupar aqui sale gratis. */
    SELECT Equipo, Compartimiento,
           MAX(Proyecto)    AS Proyecto,
           MAX(Modelo)      AS Modelo,
           MAX(compOrd)     AS compOrd,
           MAX(compAbbr)    AS compAbbr,
           MAX(CompMarcado) AS CompMarcado,
           MAX(FechaMuestreo) AS Fec, MAX(Horometro) AS Hor, MAX(HorasComponente) AS HC, MAX(CM) AS CMc
    FROM (   /* Las filas salen del formato CRUZADO (union de las 4 hojas, 31 parametros): esta tabla es
               parametros x COMPONENTES, asi que no puede seguir el formato de un solo componente. */
    SELECT b.Equipo, b.Proyecto, b.Modelo, b.Compartimiento, b.compOrd, b.compAbbr, b.CompMarcado, b.FechaMuestreo, b.Horometro, b.HorasComponente, b.CM,
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
