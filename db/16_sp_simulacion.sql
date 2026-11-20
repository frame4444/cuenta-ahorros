USE AhorrosDB;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* TP3 - Simulacion reanudable y estrictamente ordenada por fecha. */
CREATE OR ALTER PROCEDURE dbo.sp_Simulacion
    @outResultCode INT OUTPUT,
    @outMensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @outResultCode = 0;
    SET @outMensaje = NULL;

    IF @@TRANCOUNT <> 0 OR (@@OPTIONS & 2) = 2
    BEGIN
        SET @outResultCode = 50001;
        SET @outMensaje = N'La simulación requiere una sesión sin transacción externa.';
        RETURN;
    END;

    DECLARE @fecha DATE, @bloqueo INT,
            @codigo INT, @mensaje NVARCHAR(400), @n INT = 0;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.SimFecha)
            THROW 50008, N'Cargue primero el XML de operaciones.', 1;

        WHILE 1 = 1
        BEGIN
            SET @fecha = NULL;
            BEGIN TRANSACTION;

            -- Serializa la elección de la próxima fecha entre corridas concurrentes.
            EXEC @bloqueo = sys.sp_getapplock
                @Resource = N'AhorrosDB:sp_Simulacion',
                @LockMode = 'Exclusive',
                @LockOwner = 'Transaction',
                @LockTimeout = 10000;
            IF @bloqueo < 0
                THROW 50008, N'No se pudo obtener el bloqueo de la simulación.', 1;

            SELECT @fecha = MIN(Fecha)
            FROM dbo.SimFecha
            WHERE FlagTerminada = 0;

            IF @fecha IS NULL
            BEGIN
                COMMIT TRANSACTION;
                BREAK;
            END;

            SET @codigo = 0;
            EXEC dbo.sp_ProcesarOperacionesDia
                @inFecha = @fecha,
                @outResultCode = @codigo OUTPUT,
                @outMensaje = @mensaje OUTPUT;
            IF @codigo <> 0 THROW 50021, @mensaje, 1;

            -- Los cierres solo se ejecutan despues de haber procesado todos los
            -- nodos de entidades y movimientos de esa fecha.
            SET @codigo = 0;
            EXEC dbo.sp_CerrarAbrirEstadosCuenta
                @inFecha = @fecha,
                @outResultCode = @codigo OUTPUT,
                @outMensaje = @mensaje OUTPUT;
            IF @codigo <> 0 THROW 50022, @mensaje, 1;

            UPDATE dbo.SimFecha
            SET FlagTerminada = 1, FechaHoraFin = SYSDATETIME()
            WHERE Fecha = @fecha AND FlagTerminada = 0;

            IF @@ROWCOUNT <> 1
                THROW 50023, N'No se pudo marcar la fecha como terminada.', 1;

            COMMIT TRANSACTION;
            SET @n += 1;
        END;

        SET @outMensaje = CONCAT(N'Simulacion completada. Fechas procesadas: ', @n, N'.');
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        SET @outResultCode = ERROR_NUMBER();
        SET @outMensaje = LEFT(CONCAT(
            CASE WHEN @fecha IS NOT NULL THEN CONCAT(CONVERT(CHAR(10), @fecha, 23), N': ') ELSE N'' END,
            ERROR_MESSAGE()), 200);
    END CATCH;
END;
GO

-- Alias de compatibilidad con el nombre del avance anterior.
CREATE OR ALTER PROCEDURE dbo.sp_EjecutarSimulacion
    @outResultCode INT OUTPUT,
    @outMensaje NVARCHAR(400) OUTPUT
AS
BEGIN
    EXEC dbo.sp_Simulacion
        @outResultCode = @outResultCode OUTPUT,
        @outMensaje = @outMensaje OUTPUT;
END;
GO
