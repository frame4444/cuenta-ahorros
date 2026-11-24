# TP3 – Cuenta de Ahorros

## Reparto

- **Persona A:** `sp_AplicarMovimiento`, `sp_ProcesarOperacionesDia`, portal de detalle de movimientos y README.
- **Persona B:** `sp_AbrirEstadoCuenta`, `sp_CerrarEstadoCuenta`, `sp_Simulacion`, portal de estados de cuenta y verificación.
- Ambos deben probar los SP del compañero antes de la corrida final.

> En la entrega, reemplazar Persona A / Persona B por los nombres acordados.

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

La prueba de un día aplica las operaciones de esa fecha y deja pendiente el cierre. Para la corrida completa de cuatro meses usá `sp_Simulacion` (ver abajo).

La simulación se procesa fecha por fecha y se puede reanudar porque cada nodo tiene `FlagProcesado` y cada fecha `FlagTerminada`.

## Simulación

Ejecutar:

```sql
DECLARE @rc INT, @msg NVARCHAR(200);
EXEC dbo.sp_Simulacion @outResultCode=@rc OUTPUT, @outMensaje=@msg OUTPUT;
SELECT @rc AS ResultCode, @msg AS Mensaje;
```

El proceso:

1. toma la fecha pendiente más antigua;
2. exige que la fecha anterior esté terminada;
3. ejecuta `sp_ProcesarOperacionesDia`;
4. ejecuta los cierres cuya `FechaFin` corresponde a esa fecha;
5. marca la fecha como terminada y confirma la transacción del día.

Si falla una operación, un cierre o una apertura, la fecha en curso se revierte completa. Al repetir la corrida, se retoma desde la fecha pendiente más antigua.

## Cierre de estado de cuenta

El orden implementado es:

1. intereses sobre el saldo mínimo del periodo;
2. comisión por exceso de retiros ATM;
3. comisión por exceso de retiros en cajero humano;
4. cargo mensual;
5. multa por saldo mínimo.

Los contadores `CantOpATM` y `CantOpHumano` incluyen depósitos y retiros para efectos informativos. Los límites de comisión se calculan exclusivamente con retiros.

El saldo mínimo se actualiza con los saldos **posteriores a los movimientos**; el saldo inicial no se considera como una observación del mínimo cuando todavía no existe un movimiento.

## Portal

El portal permite:

- listar estados de cuenta de la cuenta seleccionada;
- ver saldo inicial, saldo final, saldo mínimo y contadores;
- abrir el detalle de movimientos de un estado;
- consultar fecha, monto, descripción y nuevo saldo en orden cronológico.

La consulta de movimientos pasa por `sp_ConsultarMovimientosEstado`, que valida el acceso del usuario antes de devolver información.

## Verificación

Ejecutar `17_verificacion_tp3.sql`. Cada consulta debe devolver cero filas. El script verifica:

- saldo de cuenta contra estado abierto;
- saldo final = saldo inicial + créditos - débitos;
- contadores ATM, cajero humano y SINPE;
- máximo un estado abierto por cuenta;
- todas las fechas de simulación terminadas.

## Corrida final

Antes de la entrega:

1. ejecutar los scripts sobre una base limpia;
2. cargar los dos XML;
3. ejecutar `sp_Simulacion`;
4. ejecutar `17_verificacion_tp3.sql`;
5. entrar al portal y capturar la lista de estados y el detalle de movimientos;
6. guardar capturas de la corrida final.
