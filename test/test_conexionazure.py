import pyodbc

conn = pyodbc.connect(
    "DRIVER={ODBC Driver 18 for SQL Server};"
    "SERVER=serverbd-osconfiabilidad.database.windows.net;"
    "DATABASE=bd_kmmp_osconfiabilidad;"
    "UID=usuario_lectura_sql;"
    "PWD=C0nfi@bilid@d2026;"
    "Encrypt=yes;"
    "TrustServerCertificate=no;"
)

print("Conectado!")