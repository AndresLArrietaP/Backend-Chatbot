# Formato de salida por componente — fuente: `docs/gerencia/Requerimientos Analisis Aceite 1.xlsx`

> Entregado por el tribólogo (23/09). **Define el ORDEN y la AGRUPACIÓN de parámetros de las tablas**
> de `/ultimo`, `/condicionmt`, `/diagcompleto` y `/tendenciadet`. Es la fuente canónica del formato;
> los límites vienen de [LIMITES_FALLBACK.md](LIMITES_FALLBACK.md).

## ⚠ Lo que cambia respecto de hoy

| Hoy | Debe ser | Detalle |
|---|---|---|
| Grupos fijos iguales para todo componente | **Grupos POR componente** | `Ca`/`Zn` son **Aditivos** en RD/SH/MODI pero **Contaminación** en MT |
| `Si` bajo «Met. Desg.» | **Contaminación** | en los 4 componentes |
| `Al` bajo «Met. Desg.» | **Desgaste** (sin cambio) | ⚠ el Excel lo deja en Desgaste; la nota de gerencia decía «Al y Si como contaminante». **Si** sí se mueve; **Al** no. Confirmar |
| Orden único | **Orden por componente** | ver tablas abajo |
| 4 grupos (Desg./Contam./Adit./Salud) | **5 grupos** | se suma **Código Limpieza** (ISO 4/6/14), hoy inexistente |

**Orden de grupos:** 1 Salud · 2 Aditivos · 3 Contaminación · 4 Desgaste · 5 Código Limpieza.

## Motor de Tracción (`MT`) — 23 parámetros

| # | Grupo | Parámetro | Símbolo |
|---|---|---|---|
| 1 | Salud | Viscosidad a 100°C | `V100` |
| 2 | Salud | Viscosidad a 40°C | `V40` |
| 3 | Aditivos | Fósforo (P) | `P` |
| 4 | Aditivos | Boro (B) | `B` |
| 5 | Contaminacion | Silicio (Si) | `Si` |
| 6 | Contaminacion | Sodio (Na) | `Na` |
| 7 | Contaminacion | Potasio (K) | `K` |
| 8 | Contaminacion | Calcio (Ca) | `Ca` |
| 9 | Contaminacion | Zinc (Zn) | `Zn` |
| 10 | Contaminacion | Magnesio (Mg) | `Mg` |
| 11 | Contaminacion | Molibdeno (Mo) | `Mo` |
| 12 | Contaminacion | Agua | `Agua` |
| 13 | Desgaste | Hierro (Fe) | `Fe` |
| 14 | Desgaste | PQ | `PQ` |
| 15 | Desgaste | Cromo (Cr) | `Cr` |
| 16 | Desgaste | Níquel (Ni) | `Ni` |
| 17 | Desgaste | Cobre (Cu) | `Cu` |
| 18 | Desgaste | Plomo (Pb) | `Pb` |
| 19 | Desgaste | Estaño (Sn) | `Sn` |
| 20 | Desgaste | Aluminio (Al) | `Al` |
| 21 | Codigo Limpieza | ISO Code >4 | `ISO4` |
| 22 | Codigo Limpieza | ISO Code >6 | `ISO6` |
| 23 | Codigo Limpieza | ISO Code >14 | `ISO14` |

## Rueda Delantera (`RD`) — 25 parámetros

| # | Grupo | Parámetro | Símbolo |
|---|---|---|---|
| 1 | Salud | Viscosidad a 100°C | `V100` |
| 2 | Salud | Viscosidad a 40°C | `V40` |
| 3 | Salud | TAN | `TAN` |
| 4 | Salud | Oxidación | `Oxidacion` |
| 5 | Aditivos | Calcio (Ca) | `Ca` |
| 6 | Aditivos | Zinc (Zn) | `Zn` |
| 7 | Aditivos | Fósforo (P) | `P` |
| 8 | Aditivos | Magnesio (Mg) | `Mg` |
| 9 | Aditivos | Molibdeno (Mo) | `Mo` |
| 10 | Aditivos | Boro (B) | `B` |
| 11 | Contaminacion | Sillico (Si) | `Si` |
| 12 | Contaminacion | Sodio (Na) | `Na` |
| 13 | Contaminacion | Potasio (K) | `K` |
| 14 | Contaminacion | Agua | `Agua` |
| 15 | Desgaste | Hierro (Fe) | `Fe` |
| 16 | Desgaste | PQ | `PQ` |
| 17 | Desgaste | Aluminio (Al) | `Al` |
| 18 | Desgaste | Cromo (Cr) | `Cr` |
| 19 | Desgaste | Níquel (Ni) | `Ni` |
| 20 | Desgaste | Cobre (Cu) | `Cu` |
| 21 | Desgaste | Plomo (Pb) | `Pb` |
| 22 | Desgaste | Estaño (Sn) | `Sn` |
| 23 | Codigo Limpieza | >4 | `ISO4` |
| 24 | Codigo Limpieza | >6 | `ISO6` |
| 25 | Codigo Limpieza | >14 | `ISO14` |

## Sistema Hidráulico (`SH`) — 25 parámetros

| # | Grupo | Parámetro | Símbolo |
|---|---|---|---|
| 1 | Salud | Viscosidad a 100°C | `V100` |
| 2 | Salud | Viscosidad a 40°C | `V40` |
| 3 | Salud | TAN | `TAN` |
| 4 | Salud | Oxidación | `Oxidacion` |
| 5 | Aditivos | Calcio (Ca) | `Ca` |
| 6 | Aditivos | Zinc (Zn) | `Zn` |
| 7 | Aditivos | Fósforo (P) | `P` |
| 8 | Aditivos | Magnesio (Mg) | `Mg` |
| 9 | Aditivos | Molibdeno (Mo) | `Mo` |
| 10 | Aditivos | Boro (B) | `B` |
| 11 | Contaminacion | Sillico (Si) | `Si` |
| 12 | Contaminacion | Sodio (Na) | `Na` |
| 13 | Contaminacion | Potasio (K) | `K` |
| 14 | Contaminacion | Agua | `Agua` |
| 15 | Desgaste | Hierro (Fe) | `Fe` |
| 16 | Desgaste | PQ | `PQ` |
| 17 | Desgaste | Aluminio (Al) | `Al` |
| 18 | Desgaste | Cromo (Cr) | `Cr` |
| 19 | Desgaste | Níquel (Ni) | `Ni` |
| 20 | Desgaste | Cobre (Cu) | `Cu` |
| 21 | Desgaste | Plomo (Pb) | `Pb` |
| 22 | Desgaste | Estaño (Sn) | `Sn` |
| 23 | Codigo Limpieza | >4 | `ISO4` |
| 24 | Codigo Limpieza | >6 | `ISO6` |
| 25 | Codigo Limpieza | >14 | `ISO14` |

## Motor Diésel (`MODI`) — 27 parámetros

| # | Grupo | Parámetro | Símbolo |
|---|---|---|---|
| 1 | Salud | Viscosidad a 100°C | `V100` |
| 2 | Salud | Viscosidad a 40°C | `V40` |
| 3 | Salud | TBN | `TBN` |
| 4 | Salud | Oxidación | `Oxidacion` |
| 5 | Salud | Sulfatación | `Sulfatacion` |
| 6 | Salud | Nitración | `Nitracion` |
| 7 | Aditivos | Calcio (Ca) | `Ca` |
| 8 | Aditivos | Zinc (Zn) | `Zn` |
| 9 | Aditivos | Fósforo (P) | `P` |
| 10 | Aditivos | Magnesio (Mg) | `Mg` |
| 11 | Aditivos | Molibdeno (Mo) | `Mo` |
| 12 | Aditivos | Boro (B) | `B` |
| 13 | Contaminacion | Sillico (Si) | `Si` |
| 14 | Contaminacion | Sodio (Na) | `Na` |
| 15 | Contaminacion | Potasio (K) | `K` |
| 16 | Contaminacion | Hollín | `Hollin` |
| 17 | Contaminacion | Diésel | `Diesel` |
| 18 | Contaminacion | Agua | `Agua` |
| 19 | Contaminacion | Refrigerante | `Refrigerante` |
| 20 | Desgaste | Hierro (Fe) | `Fe` |
| 21 | Desgaste | PQ | `PQ` |
| 22 | Desgaste | Cromo (Cr) | `Cr` |
| 23 | Desgaste | Níquel (Ni) | `Ni` |
| 24 | Desgaste | Aluminio (Al) | `Al` |
| 25 | Desgaste | Cobre (Cu) | `Cu` |
| 26 | Desgaste | Plomo (Pb) | `Pb` |
| 27 | Desgaste | Estaño (Sn) | `Sn` |

## Parámetros que el formato pide y **no tenemos** en la BD
`V40` (viscosidad 40°C) · `TAN` · `Oxidacion` · `Sulfatacion` · `Nitracion` · `Mo` · `Agua` ·
`Hollin` · `Diesel` · `Refrigerante` · `ISO4`/`ISO6`/`ISO14`.
→ Decisión pendiente: **ocultar la fila** (coherente con «parámetros con nulos, cortar fila») o
mostrarla con `—`. ⛔ No inventar el dato.
