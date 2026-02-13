import os
from typing import Any
from sqlalchemy import QueuePool, create_engine, inspect
from sqlalchemy.orm import sessionmaker
from sqlalchemy.sql import text

DB_URL = os.getenv("DATABASE_URL","default")
engine = create_engine(DB_URL, poolclass=QueuePool, pool_size=5, max_orverflow=10)
Session = sessionmaker(bind=engine)

def get_schema() -> LiteralString:
    engine = create_engine(
        "postgresql+psycopg2://postgres.uagqfqdimjsohhcovyjo:Dinobots_5@aws-0-us-west-2.pooler.supabase.com:6543/postgres"
    )
    inspector = inspect(engine)
    table_names = inspector.get_table_names()
    
    def get_column_details(table_name) ->list[str]:
        columns = inspector.get_columns(table_name)
        return [f"{col['name']} ({col['type']})" for col in columns] 

    schema_info = []
    for table_name in table_names:
        table_info = [f"Table: {table_name}"]
        table_info.append("Columns:")
        table_info.extend(f"  - {column}" for column in get_column_details(table_name))
        schema_info.append("\n.join"(table_info))
        
    engine.dispose()
    return "\n\n".join(schema_info)
    # tu función para obtener el esquema de la base de datos

async def query(sql_query: str) -> list[dict[str,Any]]:
    print("sql_query",sql_query)
    with Session() as session:
        statement = text(sql_query)
        result = session.execute(statement)
        return [dict(row._mapping) for row in result]
    # tu función para hacer la consulta a la base de datos

def cleanup() ->None:
    engine.dispose()