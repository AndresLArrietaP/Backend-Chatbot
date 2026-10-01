# docs/ — índice

Todo lo que define el KomfIA que está vivo hoy. Si buscas historia, lee
**[BITACORA.md](BITACORA.md)**; si buscas qué falta, **[copilot/PENDIENTES.md](copilot/PENDIENTES.md)**.

```
docs/
├── BITACORA.md                 Consolidado histórico: los 3 hitos, con fechas y lecciones
│
├── arquitectura/               ← lo que se despliega en la base de datos
│   ├── DDL_vistas.sql              TODAS las vistas (47). Se corre de corrido.
│   ├── DDL_indices.sql             Índices: los desplegados + los propuestos (gated DBA)
│   ├── DDL_vw_LimitesFallback.sql  Vista de límites de respaldo
│   ├── VALIDACION_SSMS.sql         136 bloques numerados de prueba. TODO SQL de prueba va acá
│   ├── DIAGNOSTICO_LATENCIA.sql    Bloques L0-L8 para aislar latencia (BD vs render)
│   ├── FORMATO_POR_COMPONENTE.md   Orden y agrupación oficiales de parámetros, por componente
│   ├── LIMITES_FALLBACK.md         Cómo funciona el respaldo de límites
│   ├── DEPENDENCIA_RankingAtencion.md  De qué vistas del dashboard depende Acumulados
│   ├── ESQUEMA_BD.xlsx             ESQUEMA CANÓNICO de la BD: 1964 columnas, incluye las 49 vistas
│   ├── ESQUEMA_BD.md               Su ficha: qué trae, qué le falta y las 9 vistas ajenas
│   └── KOMFIA.drawio               Diagrama del sistema
│
├── copilot/                    ← configuración del agente (lo que está aplicado en Copilot Studio)
│   ├── PENDIENTES.md               BACKLOG ÚNICO Y VIVO. Nadie más lista pendientes.
│   ├── CONFIG_TEMAS.md             28 temas: descripciones de ruteo, nodos, entradas
│   ├── CONFIG_FLUJOS.md            Power Automate: 4 flujos reutilizables + dedicados
│   ├── CONFIG_COMANDOS.md          Los 18 comandos «/» y el tema 00 que los despacha
│   ├── CONFIG_PROMPTS.md           Los nodos de IA (Solicitud / AI Builder)
│   ├── CONFIG_TIMEOUT.md           Las 3 capas contra el corte del conector
│   ├── KomfIA_central_MD.docx      Instrucción DESPLEGADA del orquestador (tope 8000 UTF-16)
│   ├── KomfIA_SQL_MD.docx          Instrucción DESPLEGADA del sub-agente de respaldo
│   ├── pendientes-legado/          Versiones retiradas del backlog (NO son el backlog)
│   ├── prompts/                    analisis_prompts.md · ayuda_glosario.md · formateo_fallback.md
│   ├── tarjetas/                   Adaptive Cards + el plan de tarjetas con datos
│   └── knowledge/                  .docx de referencia — NO cargados en el agente (ver su README)
│
├── pruebas/                    ← sets de prueba y registros de marcha (ver su README)
│   ├── PRUEBAS_ALFA_COMANDOS.md    SET VIGENTE: 32 pruebas, cada consulta con su comando
│   ├── MARCHA_ALFA_0918.md         Registro congelado: 1ª alfa viva con gerencia
│   ├── MARCHA_ALFA_0923.md         Registro congelado: ronda de feedback de Carlos
│   └── *.xlsx (julio)             Evidencia «antes de los límites» — no son sets reutilizables
│
├── gerencia/                   ← actas y fuentes oficiales del área (ver su README)
│                                  versionadas por EXCEPCIÓN, una por una, en el .gitignore
└── avance-semanal/             ← un .md por semana y por proyecto (ver su README + _PLANTILLA)
```

## Qué archivo abrir

| Necesito… | Archivo |
|---|---|
| Entender por qué el sistema es así | [BITACORA.md](BITACORA.md) |
| Saber qué falta / qué está abierto | [copilot/PENDIENTES.md](copilot/PENDIENTES.md) |
| Crear o modificar una vista | [arquitectura/DDL_vistas.sql](arquitectura/DDL_vistas.sql) |
| Probar algo en SSMS | [arquitectura/VALIDACION_SSMS.sql](arquitectura/VALIDACION_SSMS.sql) — **bloque nuevo numerado ahí, nunca SQL suelto** |
| Verificar una columna antes de escribir SQL | [arquitectura/ESQUEMA_BD.xlsx](arquitectura/) — su ficha en [ESQUEMA_BD.md](arquitectura/ESQUEMA_BD.md) |
| Cambiar la descripción o los nodos de un tema | [copilot/CONFIG_TEMAS.md](copilot/CONFIG_TEMAS.md) |
| Agregar o editar un comando `/` | [copilot/CONFIG_COMANDOS.md](copilot/CONFIG_COMANDOS.md) — y **siempre** los 3 a la vez: el doc, `tarjetas/comandos_card.json` y `../tools/gen_comandos_card.py` |
| Cambiar el texto del análisis | [copilot/prompts/analisis_prompts.md](copilot/prompts/analisis_prompts.md) |
| Diagnosticar lentitud | [arquitectura/DIAGNOSTICO_LATENCIA.sql](arquitectura/DIAGNOSTICO_LATENCIA.sql) + las leyes 2, 3 y 4 de la [BITACORA](BITACORA.md#las-leyes-que-el-proyecto-pagó-caro) |
| Ver el orden oficial de parámetros de un componente | [arquitectura/FORMATO_POR_COMPONENTE.md](arquitectura/FORMATO_POR_COMPONENTE.md) |

## Reglas de este directorio

- **Un solo backlog:** `copilot/PENDIENTES.md`. Los registros de marcha (`pruebas/MARCHA_*.md`) cuentan qué
  pasó en una sesión de prueba; los pendientes que salgan de ahí se copian al backlog.
- **Un solo archivo de SQL de prueba:** `arquitectura/VALIDACION_SSMS.sql`, en bloques numerados. El SQL que
  se despliega va a `DDL_*.sql`. Nada de SQL suelto en otros documentos.
- **Un solo esquema canónico:** el `.xlsx`. Es el único que incluye las vistas `vw_*`.
- **Editar un comando = editar su módulo completo:** descripción + tema + nodos + flujo + vista.
- **El acta de gerencia se edita vía XML directo**, nunca con openpyxl (borra el logo y los checkboxes).
- Lo que ya no está en uso vive en [`../legado/`](../legado/), no acá.
