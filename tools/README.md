# tools/

Un solo script vivo. Los generadores de `.docx` de las etapas anteriores están archivados en
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
