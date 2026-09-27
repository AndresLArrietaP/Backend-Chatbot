# test/test_conexionazure.py
# -*- coding: utf-8 -*-
"""
Script de diagnóstico: verifica la conexión directa a Azure SQL.

Usa pymssql (el mismo driver que producción — sin ODBC Driver requerido),
leyendo las credenciales desde .env para no exponer secretos en código.

Uso:
    python test/test_conexionazure.py

Variables de entorno requeridas (definidas en .env):
    DATABASE_URL  → mssql+pymssql://usuario:contraseña@servidor/base_datos
    o bien:
    DB_SERVER, DB_NAME, DB_USER, DB_PASSWORD  (alternativa explícita)

Nota: el script usa solo stdlib + pymssql para no depender del stack completo.
"""

import os
import sys


def _leer_env(clave: str, default: str = "") -> str:
    """Lee una variable de entorno, con fallback a .env manual si no está cargada."""
    val = os.environ.get(clave, "").strip()
    if val:
        return val
    # Intentar cargar .env si python-decouple está disponible
    try:
        from decouple import config
        return config(clave, default=default)
    except Exception:
        return default


def main() -> None:
    # Intentar obtener parámetros de conexión desde DATABASE_URL o variables individuales
    database_url = _leer_env("DATABASE_URL")

    if database_url and database_url.startswith("mssql+pymssql://"):
        # Parsear DSN del formato SQLAlchemy: mssql+pymssql://user:pass@server/db
        try:
            from urllib.parse import urlparse
            parsed = urlparse(database_url.replace("mssql+pymssql://", "http://"))
            server = parsed.hostname or ""
            database = (parsed.path or "").lstrip("/")
            user = parsed.username or ""
            password = parsed.password or ""
        except Exception as e:
            print(f"[ERROR] No se pudo parsear DATABASE_URL: {e}")
            sys.exit(1)
    else:
        # Variables individuales como alternativa
        server = _leer_env("DB_SERVER")
        database = _leer_env("DB_NAME")
        user = _leer_env("DB_USER")
        password = _leer_env("DB_PASSWORD")

    if not all([server, database, user, password]):
        print(
            "[ERROR] Faltan parámetros de conexión.\n"
            "Define DATABASE_URL en .env (mssql+pymssql://user:pass@server/db)\n"
            "o bien DB_SERVER, DB_NAME, DB_USER, DB_PASSWORD."
        )
        sys.exit(1)

    print(f"[INFO] Conectando a: {server} / {database} (usuario: {user})")

    try:
        import pymssql  # type: ignore
    except ImportError:
        print("[ERROR] pymssql no está instalado. Ejecuta: pip install pymssql")
        sys.exit(1)

    try:
        conn = pymssql.connect(
            server=server,
            user=user,
            password=password,
            database=database,
            timeout=15,
        )
        cursor = conn.cursor()
        cursor.execute("SELECT TOP 1 1 AS ping FROM [Oil].[LaboratoryData] WITH (NOLOCK)")
        row = cursor.fetchone()
        conn.close()
        print(f"[OK] Conexión exitosa. Ping a [Oil].[LaboratoryData]: {row}")
    except Exception as e:
        print(f"[ERROR] Falló la conexión: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
