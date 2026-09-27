# Límites de referencia — fallback desde el archivo de gerencia

> Fuente: `docs/gerencia/LIMITES CONDENATORIOS 1.xlsm`, hoja **BD_LC** (64 filas × ~40 parámetros).
> Entregado el 23/09 como **la** fuente confiable y completa de límites. Volcado a
> [DDL_vw_LimitesFallback.sql](DDL_vw_LimitesFallback.sql) (**524 filas**, solo proyectos en alcance).

## ✅ Corroboración contra lo que KomfIA muestra hoy
Motor de Tracción · Antapaccay · 980E coincide **exacto** con lo que ya sale en `/ultimo` y `/tendenciadet`:
`Fe 200/230` · `PQ 130/150` · `Cr 2/3` · `Ni 2/3` · `Cu 10/15` · `Pb 3/5` · `Sn 3/5` · `Al 2/3` ·
`Si 75/80` · `Ca 18/25` · `Zn 18/25` · `K 2/3` · `Na 3/4`.
→ El Excel y `[Eqpcare].[lc]` **son la misma fuente**; el Excel es el superconjunto.

## 🔴 Hallazgo: los aditivos tienen el límite INVERTIDO
47 pares traen `LP > LC`, lo que a primera vista parece error. No lo es: **46 de 47 son aditivos**
(`P` 16 · `Zn` 8 · `Ca` 8 · `Mg` 8 · `B` 2) **y `TBN`** (4). En un aditivo el límite es **inferior** —
el aditivo se **agota**, así que la alerta es por DEBAJO. Es la misma mecánica que ya tratamos en `TBN`.

**Consecuencia para nosotros:** hoy las vistas evalúan `Ca`, `Zn`, `P`, `Mg`, `B` como si fueran
contaminantes (alerta al SUBIR). Con estos límites, esa evaluación está **al revés**. Esto conecta con el
pedido «Ca y Zn como aditivo»: no es solo moverlos de grupo en la tabla, es **cambiarles el sentido de la
comparación**. El DDL ya tiene el mecanismo (`Inv`), hoy usado solo para TBN.

**La única inversión que NO es aditivo** — y que sí parece un typo del archivo:
`CERRO VERDE · MOTOR DE TRACCION LH · 980E · Pb LP=2 LC=1` (el RH del mismo proyecto trae 1/2).
⛔ No lo corregí por mi cuenta: es dato de gerencia. Preguntar.

## Cobertura

| Proyecto | Componentes | Modelos |
|---|---|---|
| **ANTAMINA** | 6 — MOTOR, MOTOR DE TRACCION LH, MOTOR DE TRACCION RH, RUEDA DELANTERA LH, RUEDA DELANTERA RH, SISTEMA HIDRAULICO | 980E |
| **ANTAPACCAY** | 13 — CAJA GIRO FRONT, CAJA GIRO REAR, DAMPER, MANDO FINAL LH, MANDO FINAL RH, MOTOR, MOTOR DE TRACCION LH, MOTOR DE TRACCION RH, PTO, RUEDA DELANTERA LH, RUEDA DELANTERA RH, SISTEMA HIDRAULICO, TRANSMISION | 980E, D475A, PC1250 |
| **CERRO VERDE** | 6 — MOTOR, MOTOR DE TRACCION LH, MOTOR DE TRACCION RH, RUEDA DELANTERA LH, RUEDA DELANTERA RH, SISTEMA HIDRAULICO | 730E-, 980E |
| **TOROMOCHO** | 6 — MOTOR, MOTOR DE TRACCION LH, MOTOR DE TRACCION RH, RUEDA DELANTERA LH, RUEDA DELANTERA RH, SISTEMA HIDRAULICO | 980E |

### ⚠ Cuajone y Toquepala NO están en el archivo
Tampoco en `[Eqpcare].[lc]`. Es decir: **el fallback no los resuelve**. Su «sin límites cargados» es real,
no un hueco de la BD. Es una pregunta para gerencia, no un bug nuestro.
(Quellaveco **sí** está en el Excel, con 222 pares, pero está fuera del alcance de KomfIA: se omitió.)

## Lo que el fallback AGREGA sobre lo que usamos hoy
1. **Límite por MODELO.** La clave real es `Proyecto + Componente + **Modelo**`: Cerro Verde tiene valores
   distintos para 980E y 730E-10. Hoy el JOIN a `lc` es solo por componente → puede estar aplicando el
   límite de un modelo a otro. **Verificar antes de asumir** (bloque de validación pendiente).
2. **Componentes que hoy no cubrimos:** Antapaccay suma `PTO`, `CAJA GIRO FRONT/REAR`, `DAMPER`,
   `TRANSMISION`, `MANDO FINAL LH/RH` (modelos PC1250 y D475A).
3. **Parámetros nuevos:** `TAN`, `Oxidacion`, `Sulfatacion`, `Nitracion`, `Hollin`, `Diesel`, `Glycol`,
   `Agua`, `Mo`, `ISO 4/6/14um`, `Ag`, `Sb`, `Li`, `Cd`, `V`, `Ba`.

## Lo que quedó FUERA del volcado
Las columnas de **viscosidad** (`VISC - LPI/LCI/LPS/LCS`, `VISC40 - …`, `AW%`) usan una forma de **4
cotas** (inferior y superior) que no entra en el par `LP/LC`. Se dejaron fuera a propósito.
→ Es justo lo que falta para que `V100` pueda tener estado (hoy no dispara `Estado_General`). Ítem aparte.

## Cómo enchufarlo
`vw_LimitesFallback` **no reemplaza** a `[Eqpcare].[lc]`: se usa con `COALESCE` cuando `lc` no trae fila.
⛔ Nunca al revés — la BD manda; el Excel rellena. Y el `Inv` debe respetarse en la evaluación de estado.
