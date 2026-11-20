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

    DECLARE @fecha DATE, @fechaAnterior DATE,
            @codigo INT, @mensaje NVARCHAR(400), @n INT = 0;

    BEGIN TRY
        WHILE EXISTS (SELECT 1 FROM dbo.SimFecha WHERE FlagTerminada = 0)
        BEGIN
            SELECT TOP (1) @fecha = Fecha
            FROM dbo.SimFecha
            WHERE FlagTerminada = 0
            ORDER BY Fecha;

            SELECT @fechaAnterior = MAX(Fecha)
            FROM dbo.SimFecha
            WHERE Fecha < @fecha;

            IF @fechaAnterior IS NOT NULL
               AND EXISTS (SELECT 1 FROM dbo.SimFecha WHERE Fecha = @fechaAnterior AND FlagTerminada = 0)
                THROW 50020, N'La fecha anterior aun no esta terminada.', 1;

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

            SET @n += 1;
        END;

        SET @outMensaje = CONCAT(N'Simulacion completada. Fechas procesadas: ', @n, N'.');
    END TRY
    BEGIN CATCH
        SET @outResultCode = ERROR_NUMBER();
        SET @outMensaje = LEFT(ERROR_MESSAGE(), 200);
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
