# gerencia/ — fuentes oficiales del área y registro con gerencia

⚠ **Esta carpeta está fuera del control de versiones** (`.gitignore`), salvo este README. No hay red de
seguridad: **nada de acá se borra**. Si algo sobra, se mueve, no se elimina.

## Vivo — se actualiza

| Archivo | Qué es |
|---|---|
| `ACTA DE REUNION_PROYECTOS DE DESARROLLO CONFIABILIDAD.xlsx` | **Registro vivo.** Se presenta a gerencia cada viernes; cada sesión de trabajo se plasma en una fila nueva (módulo, título, fecha, objetivo, checkboxes, seguimiento). |

⛔ **Se edita vía XML directo** (descomprimir el `.xlsx`, tocar `sheet1.xml` y `table1.xml`, recomprimir).
**openpyxl destruye el logo y los checkboxes.** Al agregar filas hay que extender también el `dimension` de
la hoja y el `ref` de `table1.xml`.

## Fuente oficial — entregado por el área, no se modifica

| Archivo | Qué aporta al sistema |
|---|---|
| `LIMITES CONDENATORIOS 1.xlsm` | **Los límites LP/LC definitivos**: 524 límites por proyecto / componente / modelo. De acá salió el hallazgo de los **límites invertidos** (aditivos y TBN: la alerta es por debajo). |
| `Requerimientos Analisis Aceite 1.xlsx` | Requerimientos de análisis de aceite del área. |
| `formatos 1.xlsx` | Los 4 formatos por componente (Motor de Tracción, Rueda, Sistema Hidráulico, Motor Diésel). Volcado a [`../arquitectura/FORMATO_POR_COMPONENTE.md`](../arquitectura/FORMATO_POR_COMPONENTE.md). |

> Los dos primeros son **definitivos**: ante una discrepancia, manda el archivo. Detalle de lo que se
> corroboró contra ellos: [`../BITACORA.md`](../BITACORA.md) (Hito 3, 07-08/08).

## Referencia — se conserva, ya cumplió

| Archivo | Por qué se conserva |
|---|---|
| `ACTA DE REUNION_PRUEBA DE ACEITES EN MTs_ANTAMINA.xlsx` | Acta de la prueba de Antamina. Referencia, no se edita. |
| `Limites.xlsx` | El feedback de límites del 07/08/26 — la versión previa a `LIMITES CONDENATORIOS 1.xlsm`. Es el documento donde salió que **Pb y Sn sí tienen LC crítico**. |
| `SEGUIMIENTO_Pedidos_partes_interesadas.docx` | Seguimiento de pedidos anterior al acta. Superado: hoy el seguimiento va en el acta. |
| `CONFIA_Presentacion_Gerencia.pptx` | Presentación ejecutiva de una etapa anterior del proyecto. |
