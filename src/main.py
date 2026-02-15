#librerías
import json
import logging
import os
import database
import llm
from fastapi import FastAPI
from openai import BaseModel
from typing import Any


from dotenv import load_dotenv

load_dotenv()
logger = logging.getLogger(__name__)

app = FastAPI(servers = [{"url":"#######################"}])

class PostHumanQueryPayload(BaseModel):
    human_query: str


class PostHumanQueryResponse(BaseModel):
    result: list

@app.post(
    "/human_query",
    name="Human Query",
    operation_id="post_human_query",
    description="Gets a natural language query, internally transforms it to a SQL query, queries the database, and returns the result.",
)

async def human_query(payload: PostHumanQueryPayload) -> dict[str,str]:

    # Transforma la pregunta a sentencia SQL
    sql_query = await llm.human_query_to_sql(payload.human_query)

    if not sql_query:
        return {"error": "Falló la generación de la consulta SQL"}
    result_dict = json.loads(sql_query)

    # Hace la consulta a la base de datos
    result = await database.query(result_dict["sql_query"])

    # Transforma la respuesta SQL a un formato más humano
    answer = await llm.build_answer(result, payload.human_query)
    if not answer:
        return {"error": "Falló la generación de la respuesta"}

    return {"answer": answer}