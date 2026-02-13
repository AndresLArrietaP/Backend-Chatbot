import os
from typing import Any
import openai
import database 

openai.api_key = os.getenv("OPEN_AI_API_KEY")

async def human_query_to_sql(human_query: str) -> str | None:

    # Obtenemos el esquema de la base de datos
    database_schema = database.get_schema()

    system_message = f"""
    Given the following schema, write a SQL query that retrieves the requested information. 
    Return the SQL query inside a JSON structure with the key "sql_query".
    <example>{{
        "sql_query": "SELECT * FROM users WHERE age > 18;"
        "original_query": "Show me all users older than 18 years old."
    }}
    </example>
    <schema>
    {database_schema}
    </schema>
    """
    user_message = human_query

    # Enviamos el esquema completo con la consulta al LLM
    response = openai.chat.completions.create(
        model="gpt-4o",
        response_format={"type": "json_object"},
        messages=[
            {"role": "system", "content": system_message},
            {"role": "user", "content": user_message},
        ],
        max_tokens=4000,
    )

    return response.choices[0].message.content

async def build_answer(result: list[dict[str, Any]], human_query: str) -> str | None:

    system_message = f"""
    Given a users question and the SQL rows response from the database from which the user wants to get the answer,
    write a response to the user's question.
    <user_question> 
    {human_query}
    </user_question>
    <sql_response>
    ${result} 
    </sql_response>
    """

    response = openai.chat.completions.create(
        model="gpt-4o",
        messages=[
            {"role": "system", "content": system_message},
        ],
        max_tokens=4000,
    )

    return response.choices[0].message.content
