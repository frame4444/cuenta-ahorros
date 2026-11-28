#!/usr/bin/env bash
# Corre todos los scripts de db/ en orden numerico contra el contenedor de SQL Server.
# Uso:  ./db/aplicar_todo.sh            (contenedor por defecto: mssql-tp3)
#       CONTAINER=otro-nombre ./db/aplicar_todo.sh
set -euo pipefail
CONT=${CONTAINER:-mssql-tp3}
cd "$(dirname "$0")"
for f in $(find [0-9][0-9]_*.sql | sort); do
  case "$f" in
    04_sp_carga.sql|07_sp_estados_cuenta.sql)
      echo ">> Omitiendo $f (versión TP2)"
      continue
      ;;
  esac

  echo ">> $f"

  docker exec -i "$CONT" sh -c \
    '/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -I -b' < "$f"
done
