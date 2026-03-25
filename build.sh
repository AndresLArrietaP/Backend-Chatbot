#!/bin/bash
set -e

# Install Microsoft ODBC Driver 17 for SQL Server (required for mssql+pyodbc)
# Render uses Ubuntu 22.04 (Jammy)

curl -sSL https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
curl -sSL https://packages.microsoft.com/config/ubuntu/22.04/prod.list \
    -o /etc/apt/sources.list.d/mssql-release.list

apt-get update -qq
ACCEPT_EULA=Y apt-get install -y -qq msodbcsql17 unixodbc-dev

pip install -r requirements.txt
