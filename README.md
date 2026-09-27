# KomfIA — asistente de análisis de aceite (KMMP)

Responde en lenguaje natural preguntas sobre el **análisis de aceite de las flotas mineras** de KMMP
—«¿qué motores de tracción de Antapaccay están observados?», «¿cómo viene el hierro del CA3171?»— leyendo
la base de confiabilidad `bd_kmmp_osconfiabilidad` (Azure SQL) y devolviendo tablas con semáforo, los
límites reales del área y una lectura analítica.

**Este repositorio no contiene código en ejecución.** KomfIA vive en **Microsoft Copilot Studio** +
**Power Automate** + **Azure SQL**; lo que se versiona acá es todo lo que lo define: el SQL de las vistas,
la configuración de los temas y flujos, los prompts, las tarjetas y el registro de las pruebas.

```
Usuario (Teams)
  ├── «/triage antapaccay»          → Tema 00 Comandos (despacho determinista)
  └── lenguaje natural              → KomfIA Central (rutea por descripción)
       ↓
   Tema NN → flujo de Power Automate → vista vw_*MD  →  columna MD (markdown ya armado)
       ↓
   el tema imprime el MD VERBATIM  +  un prompt que solo LEE esa tabla  +  recomendaciones de la vista
```

La idea que sostiene todo se llama **Tier 2**: la vista devuelve el markdown terminado y el tópico lo
imprime tal cual. Ningún modelo toca la tabla, así que la misma pregunta da siempre la misma respuesta.

## Por dónde empezar

| Si eres… | Lee |
|---|---|
| Nuevo en el proyecto | **[docs/BITACORA.md](docs/BITACORA.md)** — los 3 hitos, con fechas y las lecciones que costaron caro |
| Quien va a tocar algo | [docs/README.md](docs/README.md) — qué archivo es el canónico para cada cosa |
| Quien busca qué falta | [docs/copilot/PENDIENTES.md](docs/copilot/PENDIENTES.md) — backlog único |

## Estructura

```
├── docs/        Todo lo que define el sistema vivo (ver docs/README.md)
├── tools/       gen_comandos_card.py — genera la Adaptive Card de /comandos
└── legado/      Los dos hitos anteriores, archivados (ver legado/README.md)
     ├── 01-python-api/            El backend FastAPI (feb–jun 2026). NO está en uso.
     ├── 02-copilot-multiagente/   Instrucciones y Conocimientos previos al Tier 2
     └── generadores/              Los scripts que producían esos .docx
```

## Reglas que no se negocian

- **La base es de solo lectura.** `CREATE OR ALTER VIEW` y `SELECT`, sí. `CREATE INDEX` y `CREATE FUNCTION`
  requieren al DBA. Nunca sugerir `ALTER TABLE`.
- **Todo SQL de prueba** va a `docs/arquitectura/VALIDACION_SSMS.sql` en un bloque numerado. El SQL que se
  despliega, a `docs/arquitectura/DDL_*.sql`. Nada de SQL suelto en otros documentos.
- **Verificar cada columna** contra el esquema canónico `docs/schemaaceites 1 (1).xlsx` antes de escribir
  SQL. Es el único que incluye las vistas `vw_*`.
- **Editar un comando = editar su módulo completo:** descripción + tema + nodos + flujo + vista.
- Antes de un cambio, auditar el sistema completo, no solo el archivo que se toca.
