# import os
# from typing import Any
# import openai
# import database 
# openai.api_key = os.getenv("OPEN_AI_API_KEY")
# async def human_query_to_sql(human_query: str) -> str | None:
# # Obtenemos el esquema de la base de datos
# database_schema = database.get_schema()
# system_message = f"""
# Given the following schema, write a SQL query that retrieves the requested information. 
# Return the SQL query inside a JSON structure with the key "sql_query".
# <example>{{
    # "sql_query": "SELECT * FROM users WHERE age > 18;"
    # "original_query": "Show me all users older than 18 years old."
    # }}
    # </example>
    # <schema>
    # {database_schema}
    # </schema>
    # """
    # user_message = human_query

    # Enviamos el esquema completo con la consulta al LLM
    # response = openai.chat.completions.create(
        # model="gpt-4o",
        # response_format={"type": "json_object"},
        # messages=[
            # {"role": "system", "content": system_message},
            # {"role": "user", "content": user_message},
            # ],
            # max_tokens=4000,
            # )
            # return response.choices[0].message.content
# async def build_answer(result: list[dict[str, Any]], human_query: str) -> str | None:
# system_message = f"""
# Given a users question and the SQL rows response from the database from which the user wants to get the answer,
# write a response to the user's question.
# <user_question> 
# {human_query}
# </user_question>
# <sql_response>
# ${result} 
# </sql_response>
# """
# response = openai.chat.completions.create(
    # model="gpt-4o",
    # messages=[
        # {"role": "system", "content": system_message},
        # ],
        # max_tokens=4000,
        # )
        # return response.choices[0].message.content
    
    
# src/llm.py
# from typing import Any, List, Dict, Optional
# from decouple import config as env
# from openai import OpenAI
# from . import database
# OPENAI_API_KEY = env("OPENAI_API_KEY", default=None)
# if not OPENAI_API_KEY:
# raise RuntimeError("Falta OPENAI_API_KEY en .env o entorno.")
# client = OpenAI(api_key=OPENAI_API_KEY)
# async def human_query_to_sql(human_query: str) -> Optional[str]:
    # Obtén el esquema actual
    # database_schema = database.get_schema()
# system_message = f"""
# Given the following schema, write a SQL query that retrieves the requested information.
# Return the SQL query inside a JSON structure with the key "sql_query", and include the original query in "original_query".
# <example>{{
    # "sql_query": "SELECT * FROM users WHERE age > 18;",
    # "original_query": "Show me all users older than 18 years old."
    # }}
    # </example>
    # <schema>
    # {database_schema}
    # </schema>
    # """
    # resp = client.chat.completions.create(
        # model="gpt-4o",
        # response_format={"type": "json_object"},
        # messages=[
            # {"role": "system", "content": system_message},
            # {"role": "user", "content": human_query},
            # ],
            # max_tokens=4000,
            # temperature=0.2,
            # )
        # return resp.choices[0].message.content
# async def build_answer(result: List[Dict[str, Any]], human_query: str) -> Optional[str]:
    # system_message = f"""
    # Given a user's question and the SQL rows response from the database, write a helpful and concise answer.
    # <user_question>
    # {human_query}
    # </user_question>
    # <sql_response>
    # {result}
    # </sql_response>
    # """
    # resp = client.chat.completions.create(
        # model="gpt-4o",
        # messages=[{"role": "system", "content": system_message}],
        # max_tokens=4000,
        # temperature=0.2,
        # )
        # return resp.choices[0].message.content
        
# src/llm.py
from typing import Any, List, Dict, Optional
from decouple import config as env
from openai import OpenAI
import json

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

async def human_query_to_sql(
    human_query: str,
    schema_json: Dict[str, Any],
    dialect: str = "postgresql",
    default_limit: int = 100,
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

async def build_answer(result: List[Dict[str, Any]], human_query: str) -> Optional[str]:
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

    resp = client.chat.completions.create(
        model="gpt-4o",
        messages=[{"role": "system", "content": system_message}],
        max_tokens=600,
        temperature=0.2,
    )
    return resp.choices[0].message.content

