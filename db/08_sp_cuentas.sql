
USE AhorrosDB;
GO

SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ListarCuentasUsuario
    @inIdUsuario INT,
    @outResultCode INT OUTPUT,
    @outMensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 0;
    SET @outMensaje = N'';

    BEGIN TRY
        IF NOT EXISTS (
            SELECT 1
            FROM dbo.Usuario
            WHERE Id = @inIdUsuario
              AND FlagActivo = 1
        )
        BEGIN
            SET @outResultCode = 50003;
            SET @outMensaje = N'Usuario no encontrado o inactivo';
            RETURN;
        END;

        SELECT
            C.Id,
            C.NumeroCuenta,
            C.Saldo,
            C.FechaCreacion
        FROM dbo.Cuenta C
        WHERE EXISTS (
            SELECT 1
            FROM dbo.Usuario U
            WHERE U.Id = @inIdUsuario
              AND U.EsAdministrador = 1
              AND U.FlagActivo = 1
        )
        OR EXISTS (
            SELECT 1
            FROM dbo.UsuarioPuedeVerCuenta V
            WHERE V.IdUsuario = @inIdUsuario
              AND V.IdCuenta = C.Id
        )
        ORDER BY C.NumeroCuenta;
    END TRY
    BEGIN CATCH
        SET @outResultCode = 50008;
        SET @outMensaje = ERROR_MESSAGE();
    END CATCH;
END;
GO
