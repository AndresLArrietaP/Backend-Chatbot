# src/llm.py
from typing import Any, List, Dict, Optional
from decouple import config as env
from openai import OpenAI
import json
import asyncio

import google.generativeai as genai
from google.generativeai.types import GenerationConfig
from google.api_core.exceptions import GoogleAPIError

# --- Configuración del cliente Gemini ---
GOOGLE_API_KEY = (env("GOOGLE_API_KEY", default="") or "").strip()
if not GOOGLE_API_KEY:
    raise RuntimeError("Falta GOOGLE_API_KEY (vacía o no definida en .env).")

genai.configure(api_key=GOOGLE_API_KEY)


OPENAI_API_KEY = env("OPENAI_API_KEY", default=None)
if not OPENAI_API_KEY:
    raise RuntimeError("Falta OPENAI_API_KEY.")

client = OpenAI(api_key=OPENAI_API_KEY)

def _dialect_quoting_instructions(dialect: str) -> str:
    d = (dialect or "postgresql").lower()
    if d in ("postgresql", "sqlite"):
        return 'Use double quotes for identifiers (e.g., "TableName", "Column Name").'
    if d == "mysql":
        return "Use backticks for identifiers (e.g., `table_name`, `column_name`)."
    if d in ("mssql", "sqlserver"):
        return "Use square brackets for identifiers (e.g., [TableName], [Column Name])."
    return 'Use ANSI SQL quoting with double quotes for identifiers.'


async def _gen_json(model_name: str, system_text: str, user_text: str) -> str:
    """Llama a Gemini y exige JSON estricto."""
    model = genai.GenerativeModel(
        model_name=model_name,
        system_instruction=system_text
    )
    gen_cfg = GenerationConfig(
        temperature=0.1,
        response_mime_type="application/json",
        # Puedes reforzar esquema esperado:
        # response_schema={
        #   "type": "object",
        #   "properties": {
        #       "sql_query": {"type": "string"},
        #       "original_query": {"type": "string"}
        #   },
        #   "required": ["sql_query", "original_query"],
        # }
    )
    # La SDK es sincrónica, la envolvemos para no bloquear el loop
    resp = await asyncio.to_thread(model.generate_content, user_text, generation_config=gen_cfg)
    # .text ya viene como JSON (por response_mime_type), pero igual devolvemos string
    return resp.text

async def _gen_text(model_name: str, system_text: str) -> str:
    model = genai.GenerativeModel(model_name=model_name)
    gen_cfg = GenerationConfig(temperature=0.2)
    resp = await asyncio.to_thread(model.generate_content, system_text, generation_config=gen_cfg)
    return resp.text



async def human_query_to_sql(
    human_query: str,
    schema_json: Dict[str, Any],
    dialect: str = "postgresql",
    default_limit: int = 100,
    #para modelos nuevos
    model: Optional[str] = None
) -> Optional[str]:
    """
    Devuelve un JSON string con: {"sql_query": "...", "original_query": "..."}
    """
    tables = schema_json.get("tables", [])
    # Estructura compacta: solo lo necesario para el LLM
    schema_compact = [{"schema": t["schema"], "table": t["table"],
                       "columns": [c["name"] for c in t["columns"]]}
                      for t in tables]

    quoting_rule = _dialect_quoting_instructions(dialect)

    system_message = f"""
You are a careful SQL generator for the {dialect.upper()} dialect.
Rules:
- Base your query ONLY on the provided schema (JSON).
- {quoting_rule}
- If column names contain spaces/accents, quote them per rule above.
- Prefer WHERE clauses and include an ORDER BY when meaningful.
- Add LIMIT {default_limit} by default if the user didn't specify a row cap.
- Return a strict JSON object with keys: "sql_query" and "original_query".
- Do not hallucinate tables/columns that are not in the schema.
- Use only tables present in the schema JSON.
<schema_json>
{json.dumps(schema_compact, ensure_ascii=False)}
</schema_json>
""".strip()

    """
    resp = client.chat.completions.create(
        model="gpt-4o",
        response_format={"type": "json_object"},
        messages=[
            {"role": "system", "content": system_message},
            {"role": "user", "content": human_query},
        ],
        max_tokens=800,
        temperature=0.1,
    )
    return resp.choices[0].message.content
    """
    
    mdl = (model or env("GEMINI_MODEL", default="gemini-1.5-flash")).strip()

    try:
        json_str = await _gen_json(mdl, system_message, human_query)
        # Validar que parsea a JSON y contiene sql_query
        parsed = json.loads(json_str)
        if not isinstance(parsed, dict) or "sql_query" not in parsed:
            raise RuntimeError(f"GEMINI devolvió un JSON inesperado: {json_str[:200]}")
        return json_str
    except GoogleAPIError as e:
        raise RuntimeError(f"GEMINI GoogleAPIError: {e.message}") from e
    except Exception as e:
        raise RuntimeError(f"GEMINI error: {str(e)}") from e


# async def build_answer(result: List[Dict[str, Any]], human_query: str) -> Optional[str]:
async def build_answer(result: List[Dict[str, Any]], human_query: str, model: Optional[str]=None) -> Optional[str]:
    system_message = f"""
Eres un analista. Con la pregunta del usuario y las filas de SQL, responde en español de forma concisa y útil.
Incluye cifras clave y filtros si son relevantes. Si no hay datos, dilo explícitamente.
<user_question>
{human_query}
</user_question>
<sql_rows>
{result}
</sql_rows>
""".strip()
    
    """
    resp = client.chat.completions.create(
        model="gpt-4o",
        messages=[{"role": "system", "content": system_message}],
        max_tokens=600,
        temperature=0.2,
    )
    return resp.choices[0].message.content
    """
    
    mdl = (model or env("GEMINI_MODEL", default="gemini-1.5-flash")).strip()

    try:
        text = await _gen_text(mdl, system_message)
        return text
    except GoogleAPIError as e:
        raise RuntimeError(f"GEMINI GoogleAPIError: {e.message}") from e
    except Exception as e:
        raise RuntimeError(f"GEMINI error: {str(e)}") from e


# --------- Ping rápido (útil para /llm/ping) ---------
async def ping(model: Optional[str] = None) -> str:
    mdl = (model or env("GEMINI_MODEL", default="gemini-1.5-flash")).strip()
    model = genai.GenerativeModel(model_name=mdl)
    resp = await asyncio.to_thread(model.generate_content, "ping")
    return resp.text or ""

