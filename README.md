# TP2 – Cuenta de Ahorros 

## Inicialización de Base de Datos local (linux) 
### Crear contenedor Docker con la DB 
En el root del proyecto:
`sudo docker compose up -d`

`sudo docker exec -it mssql-tp2 bash -c \
        '/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -Q "CREATE DATABASE AhorrosDB"'`
### Ejecutar los scrpits de DB
` for f in 01_schema_auth 02_sp_auth 03_schema_beneficiarios_estados 04_sp_carga 05_sp_beneficiarios 06_sp_catalogos 07_sp_estados_cuenta
      sudo docker exec -i mssql-tp2 sh -c '/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -I' < db/$f.sql
  end`

### Poblar la DB con los XML
`cd app`
`./mvnw spring-boot:run -Dspring-boot.run.arguments="--app.carga.habilitada=true --spring.main.web-application-type=none"`
esto inicia el programa con los argumentos de carga y para matar la instancia inmediatamente después
