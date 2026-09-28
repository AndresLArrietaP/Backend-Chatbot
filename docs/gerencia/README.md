# gerencia/ — actas y fuentes oficiales del área

Los archivos de esta carpeta **sí se versionan, por excepción** (el `.gitignore` ignora `docs/gerencia/*` y
lista uno por uno los que entran). Son irreemplazables y pesan poco: el más grande, `LIMITES CONDENATORIOS
1.xlsm`, ocupa 950 KB — muy lejos del límite de GitHub (aviso a 50 MB, tope duro 100 MB).

⚠ **Si dejas aquí un archivo nuevo, no se versiona hasta que lo agregues como excepción** en el
`.gitignore`. Es a propósito: evita que un `.pptx` o un `.xlsm` pesado entre al repositorio sin querer.

## Vivo — se actualiza cada semana

| Archivo | Qué es | Última |
|---|---|---|
| `ACTA DE REUNION_PROYECTOS DE DESARROLLO CONFIABILIDAD.xlsx` | **Registro vivo**, presentado a gerencia cada viernes. Cubre KomfIA **e** INVERTEX. Una fila por sesión de trabajo: módulo · título · fecha · objetivo · checkboxes · seguimiento. | 25/09/26 |

⛔ **Se edita vía XML directo** (descomprimir el `.xlsx`, tocar `sheet1.xml` y `table1.xml`, recomprimir).
**openpyxl destruye el logo y los checkboxes.** Al agregar filas hay que extender también el `dimension` de
la hoja y el `ref` de `table1.xml`. Se sincroniza con `INVERTEX v3/refs/gerencia/`.

## Fuente oficial — entregada por el área. No se modifica: ante una discrepancia, manda el archivo

| Archivo | Qué aporta al sistema | Volcado a |
|---|---|---|
| `LIMITES CONDENATORIOS 1.xlsm` (24/09/26) | Los **límites LP/LC definitivos**: hoja `BD_LC`, 64 filas × ~40 parámetros → 524 límites por proyecto/componente/modelo. De aquí salió el hallazgo de los **límites invertidos** (aditivos y TBN: la alerta es por debajo). | [`../arquitectura/LIMITES_FALLBACK.md`](../arquitectura/LIMITES_FALLBACK.md) + `DDL_vw_LimitesFallback.sql` |
| `Requerimientos Analisis Aceite 1.xlsx` (24/09/26) | El **formato** oficial por componente: hojas MT / RD / SH / MODI — orden y agrupación de los parámetros. | [`../arquitectura/FORMATO_POR_COMPONENTE.md`](../arquitectura/FORMATO_POR_COMPONENTE.md) |

## Referencia — cumplieron, se conservan por trazabilidad

| Archivo | Por qué se conserva |
|---|---|
| `ACTA DE REUNION_PRUEBA DE ACEITES EN MTs_ANTAMINA.xlsx` (18/07/26) | Acta de la prueba de Antamina. No se edita. |
| `Limites.xlsx` (07/08/26) | **Predecesor** de `LIMITES CONDENATORIOS 1.xlsm`. Es el documento donde salió que **Pb y Sn sí tienen LC crítico**, y sigue siendo la referencia del **BLOQUE 50** de `VALIDACION_SSMS.sql`. |
| `formatos 1.xlsx` (21/06/26) | **Predecesor** de `Requerimientos Analisis Aceite 1.xlsx`: los 4 formatos por componente en su primera versión. |

> Los dos «predecesor» quedan solo por trazabilidad; **para escribir SQL se usa el de 24/09**. Si los quieres
> fuera, se borran en una línea (ya están versionados, así que el borrado es recuperable).

## Borrados el 27/09/26

| Archivo | Por qué |
|---|---|
| `CONFIA_Presentacion_Gerencia.pptx` (28/05/26) | Presentación ejecutiva de la etapa del backend Python. Superada por el acta viva y por las demostraciones en Teams. |
| `SEGUIMIENTO_Pedidos_partes_interesadas.docx` (23/07/26) | El seguimiento de pedidos vive hoy en la columna «seguimiento» del acta. |
