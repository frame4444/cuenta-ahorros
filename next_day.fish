#!/usr/bin/env fish

printf '%s\n' "
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @fecha DATE, @rc INT, @bloqueo INT, @msg NVARCHAR(400),
        @dias INT = 0, @movimientos INT;

BEGIN TRY
    WHILE 1 = 1
    BEGIN
        BEGIN TRANSACTION;

        EXEC @bloqueo = sys.sp_getapplock
            @Resource = N'AhorrosDB:sp_Simulacion',
            @LockMode = 'Exclusive',
            @LockOwner = 'Transaction',
            @LockTimeout = 10000;

        IF @bloqueo < 0
            THROW 51000, N'No se pudo obtener el bloqueo de la simulación.', 1;

        SELECT @fecha = MIN(Fecha)
        FROM dbo.SimFecha
        WHERE FlagTerminada = 0;

        IF @fecha IS NULL
        BEGIN
            COMMIT TRANSACTION;
            SELECT @dias AS DiasProcesados, N'No quedan fechas pendientes.' AS Mensaje;
            BREAK;
        END;

        EXEC dbo.sp_ProcesarOperacionesDia @fecha, @rc OUTPUT, @msg OUTPUT;
        IF @rc <> 0 THROW 51001, @msg, 1;

        EXEC dbo.sp_CerrarAbrirEstadosCuenta @fecha, @rc OUTPUT, @msg OUTPUT;
        IF @rc <> 0 THROW 51002, @msg, 1;

        SELECT @movimientos = COUNT(*)
        FROM dbo.Movimiento
        WHERE Fecha = @fecha;

        UPDATE dbo.SimFecha
        SET FlagTerminada = 1, FechaHoraFin = SYSDATETIME()
        WHERE Fecha = @fecha;

        COMMIT TRANSACTION;
        SET @dias += 1;

        IF @movimientos > 0
        BEGIN
            SELECT @fecha AS FechaConMovimientos,
                   @movimientos AS Movimientos,
                   @dias AS DiasProcesados;
            BREAK;
        END;
    END;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT @fecha AS FechaDelError;
    THROW;
END CATCH;
" | sudo docker exec -i mssql-tp3 sh -c \
    '/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -I -b -d AhorrosDB'
