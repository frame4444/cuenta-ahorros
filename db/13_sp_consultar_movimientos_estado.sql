USE AhorrosDB;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- Detalle cronologico de movimientos de un estado de cuenta.
-- API: GET /api/cuentas/{numeroCuenta}/estados-cuenta/{idEstadoCuenta}/movimientos
-- Codigos: 0 = OK; 50003 = sin acceso; 50007 = inexistente; 50008 = error SQL.
CREATE OR ALTER PROCEDURE dbo.sp_ConsultarMovimientosEstado
    @inIdUsuario INT,
    @inNumeroCuenta VARCHAR(16),
    @inIdEstadoCuenta INT,
    @outResultCode INT OUTPUT,
    @outMensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;
    SET @outMensaje = NULL;

    BEGIN TRY
        DECLARE @idCuenta INT;

        IF @inIdUsuario IS NULL OR @inIdEstadoCuenta IS NULL
           OR NULLIF(LTRIM(RTRIM(@inNumeroCuenta)), '') IS NULL
        BEGIN
            SET @outResultCode = 50007;
            SET @outMensaje = N'Parametros invalidos.';
            RETURN;
        END;

        SELECT @idCuenta = Id
        FROM dbo.Cuenta
        WHERE NumeroCuenta = @inNumeroCuenta;

        IF @idCuenta IS NULL
        BEGIN
            SET @outResultCode = 50007;
            SET @outMensaje = N'La cuenta no existe.';
            RETURN;
        END;

        EXEC dbo.sp_VerificarAccesoCuenta
            @inIdUsuario = @inIdUsuario,
            @inNumeroCuenta = @inNumeroCuenta,
            @outResultCode = @outResultCode OUTPUT;

        IF @outResultCode <> 0
        BEGIN
            SET @outMensaje = CASE @outResultCode
                WHEN 50003 THEN N'No tiene acceso a la cuenta.'
                ELSE N'Error al verificar el acceso.' END;
            RETURN;
        END;

        IF NOT EXISTS (
            SELECT 1
            FROM dbo.EstadoCuenta
            WHERE Id = @inIdEstadoCuenta AND IdCuenta = @idCuenta
        )
        BEGIN
            SET @outResultCode = 50007;
            SET @outMensaje = N'El estado de cuenta no existe para esta cuenta.';
            RETURN;
        END;

        SELECT M.Id, M.Fecha, M.Monto, M.Descripcion, M.NuevoSaldo, TM.Simbolo
        FROM dbo.Movimiento AS M
        INNER JOIN dbo.Cuenta AS C ON C.Id = M.IdCuenta
        INNER JOIN dbo.TipoCuentaAhorro AS TC ON TC.Id = C.IdTipoCuentaAhorro
        INNER JOIN dbo.TipoMoneda AS TM ON TM.Id = TC.IdTipoMoneda
        WHERE M.IdCuenta = @idCuenta
          AND M.IdEstadoCuenta = @inIdEstadoCuenta
        ORDER BY M.Fecha ASC, M.Id ASC;
    END TRY
    BEGIN CATCH
        SET @outResultCode = 50008;
        SET @outMensaje = LEFT(ERROR_MESSAGE(), 200);
    END CATCH;
END;
GO
