-- =====================================================================
-- TP2 - Consulta de estados de cuenta: los ultimos 8, el mas reciente
-- primero (fecha de emision = fecha en que cierra el estado, FechaFin).
-- Cada consulta queda en Bitacora (tipo 7).
-- Codigos (@outResultCode): 0 OK | 50003 sin acceso | 50007 cuenta no
-- existe | 50008 error de base de datos.
-- =====================================================================
USE AhorrosDB;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ConsultarEstadosCuenta
    @inIdUsuario     INT,
    @inNumeroCuenta  VARCHAR(16),
    @outResultCode   INT OUTPUT,
    @outMensaje      NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;
    SET @outMensaje = NULL;

    DECLARE @idCuenta INT;

    BEGIN TRY
        EXEC dbo.sp_VerificarAccesoCuenta
             @inIdUsuario, @inNumeroCuenta, @outResultCode OUTPUT;
        IF @outResultCode <> 0
        BEGIN
            SET @outMensaje = CASE @outResultCode
                WHEN 50003 THEN N'No tiene acceso a la cuenta.'
                ELSE N'Error al verificar el acceso.' END;
            RETURN;
        END;

        SELECT @idCuenta = C.Id
        FROM dbo.Cuenta C
        WHERE C.NumeroCuenta = @inNumeroCuenta;

        IF @idCuenta IS NULL
        BEGIN
            SET @outResultCode = 50007;
            SET @outMensaje = N'La cuenta no existe.';
            RETURN;
        END;

        -- Bitacora: consulta de estado de cuenta (Id 7)
        INSERT dbo.Bitacora (IdUsuario, IdTipoOperacion)
        VALUES (@inIdUsuario, 7);

        SELECT TOP (8)
               E.Id, E.FechaInicio, E.FechaFin, E.SaldoInicial,
               E.SaldoFinal, E.SaldoMinimo, E.InteresesAcumulados,
               E.CantRetiros, E.CantDepositos,
               E.CantSinpeEntrantes, E.CantSinpeSalientes
        FROM dbo.EstadoCuenta E
        WHERE E.IdCuenta = @idCuenta
        ORDER BY E.FechaFin DESC, E.Id DESC;
    END TRY
    BEGIN CATCH
        SET @outResultCode = 50008;
        SET @outMensaje = LEFT(ERROR_MESSAGE(), 200);
    END CATCH
END;
GO
