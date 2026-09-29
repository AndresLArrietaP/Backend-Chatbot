# tools/

Dos scripts vivos. Los generadores de `.docx` de las etapas anteriores están archivados en
[`../legado/generadores/`](../legado/generadores/) y **no deben ejecutarse**: los `.docx` que quedan
(`docs/copilot/*_MD.docx`) se editan directo y son la fuente de verdad.

## `gen_comandos_card.py`

Genera la Adaptive Card del comando `/comandos` a partir del catálogo que tiene dentro:

```bash
python tools/gen_comandos_card.py     # → docs/copilot/tarjetas/comandos_card.json
```

⚠ **Al agregar, editar o quitar un comando hay que tocar los tres, en el mismo cambio:**

1. `docs/copilot/CONFIG_COMANDOS.md` — la config canónica (y el tema 00 en Copilot Studio)
2. este script — el catálogo que arma la tarjeta
3. `docs/copilot/tarjetas/comandos_card.json` — regenerándolo con el script

Trampas de la tarjeta, ya pagadas:

- Los placeholders van con `‹ ›`, **nunca con `< >`**: el markdown de la tarjeta los borra como si fueran
  etiquetas HTML y el parámetro desaparece.
- La tarjeta se envía desde un nodo **«Enviar un mensaje»**, no desde el nodo de tarjeta adaptable: ese
  exige un `Action.Submit` y el botón bloquea la conversación.
- Las Adaptive Cards **no tienen scroll**. Si no cabe, se pagina; no se comprime.

Dependencias: ninguna fuera de la librería estándar.

---

## `check_ddl.py`

Verifica `docs/arquitectura/DDL_vistas.sql` **antes** de mandarlo a SSMS:

```bash
python tools/check_ddl.py        # → "47 vistas revisadas, 0 con problemas"
```

Ataca los errores que revientan **al desplegar** y cuestan una ronda de ida y vuelta:

| Error | Causa |
|---|---|
| `Msg 102 · Incorrect syntax near '('` | a una tupla de `VALUES` le falta la coma |
| `Msg 102 · Incorrect syntax near ','` | a la última tupla le sobra la coma |
| paréntesis desbalanceados | en una tupla o en el cuerpo de la vista |

Los tres salieron el 28/09 al ampliar listas de `VALUES` a mano: se pega una entrada detrás de la última
—que no llevaba coma— y el error aparece diez líneas más abajo, en otra tupla.

⛔ **No reemplaza al smoke test** (`BLOQUE 89` de `VALIDACION_SSMS.sql`): SQL Server **guarda** una vista
aunque su cuerpo sea inválido, y esos errores solo salen al consultarla. Son las dos mitades del mismo
problema — este corre antes de desplegar, el otro después.
