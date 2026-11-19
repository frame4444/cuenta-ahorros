# TP3 – Cuenta de Ahorros

La aplicación usa SQL Server 2022, Docker Compose y Java 21. El Maven Wrapper está en `app/`.

## Crear la base de datos

En la raíz del repo, creá un archivo local `.env` con `SA_PASSWORD` igual a la contraseña de SQL Server. Configurá también `SPRING_DATASOURCE_PASSWORD` con ese mismo valor para los comandos de Spring Boot. En fish podés exportarla con `set -gx SPRING_DATASOURCE_PASSWORD 'tu-contraseña'`.

```sh
docker compose up -d
```

Cuando SQL Server acepte conexiones, creá `AhorrosDB` si aún no existe y aplicá el esquema sobre la base vacía:

```sh
docker exec mssql-tp3 sh -c \
  '/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -b -Q "CREATE DATABASE AhorrosDB"'
./db/aplicar_todo.sh
```

Usá `sudo` para los comandos de Docker y para el runner si tu usuario lo requiere. El runner aplica los scripts en orden numérico y se detiene en el primer error. En una base inicializada, aplicá solo el archivo de la SP que cambió. El 09 recrea la tabla de estados durante la instalación inicial.

## Cargar los XML de TP3

Desde `app/`:

```sh
./mvnw spring-boot:run \
  -Dspring-boot.run.arguments="--app.carga.habilitada=true --spring.main.web-application-type=none"
```

El proceso inserta los catálogos y deja las operaciones en `SimOperacion`, con **157 nodos** en **122 fechas consecutivas**. Las personas, las cuentas y los movimientos se crean al procesar esas operaciones.

## Probar un día y consultar movimientos

Desde la raíz del repo, procesá el primer día con:

```sh
printf '%s\n' \
  "DECLARE @codigo INT, @mensaje NVARCHAR(200);" \
  "EXEC dbo.sp_ProcesarOperacionesDia '20260301', @codigo OUTPUT, @mensaje OUTPUT;" \
  "SELECT @codigo AS Codigo, @mensaje AS Mensaje;" \
  "IF @codigo <> 0 THROW 51000, @mensaje, 1;" \
  | docker exec -i mssql-tp3 sh -c \
    '/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -I -b -d AhorrosDB'
```

En una base recién cargada, la primera llamada aplica 15 nodos. Una segunda llamada procesa cero. Para abrir el portal, ejecutá `./mvnw spring-boot:run` desde `app/` y entrá en <http://localhost:8080>. Iniciá sesión con el usuario de prueba `amora` y la contraseña indicada en `OperacionesTarea3.xml`, seleccioná la cuenta `11000001`, abrí **Estados de cuenta** y desplegá **Movimientos**. El primer movimiento es el depósito de apertura por ₡250 000.

La corrida de cuatro meses necesita el coordinador de simulación y los procedimientos de cierre mensual. La prueba de un día aplica las operaciones de esa fecha y deja pendiente el cierre.
