#!/usr/bin/env bash
# Corre todos los scripts de db/ en orden numerico contra el contenedor de SQL Server.
# Uso:  ./db/aplicar_todo.sh            (contenedor por defecto: mssql-tp3)
#       CONTAINER=otro-nombre ./db/aplicar_todo.sh
set -euo pipefail
cd "$(dirname "$0")"
CONT="${CONTAINER:-mssql-tp3}"
for f in $(ls [0-9][0-9]_*.sql | sort); do
  echo ">> $f"
  docker exec -i "$CONT" sh -c \
    '/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -I -b' < "$f"
done
echo "Listo."
