-- =====================================================================
-- TP2 - SPs de autenticación
-- Códigos de resultado (OUTPUT @outResultCode):
--   0     OK
--   50001 credenciales inválidas
--   50002 usuario inactivo (reservado)
--   50003 sin acceso a la cuenta
--   50008 error de base de datos
-- =====================================================================
USE AhorrosDB;
GO
-- Necesario para índices filtrados y métodos XML; sqlcmd lo trae en OFF por defecto
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Login
    @inUser         VARCHAR(64),
    @inPass         VARCHAR(128),
    @inIP           VARCHAR(45),
    @outResultCode  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;
    BEGIN TRY
        DECLARE @IdUsuario INT;

        SELECT @IdUsuario = U.Id
        FROM dbo.Usuario U
        WHERE U.Username = @inUser
          AND U.FlagActivo = 1
          AND U.PasswordHash = HASHBYTES('SHA2_256',
                CONCAT(CONVERT(CHAR(36), U.Salt), @inPass));

        IF @IdUsuario IS NULL
        BEGIN
            SET @outResultCode = 50001;
            RETURN;
        END;

        -- Bitácora: login exitoso (Id 1 = Login)
        INSERT INTO dbo.Bitacora (IdUsuario, IdTipoOperacion, IP)
        VALUES (@IdUsuario, 1, @inIP);

        SELECT U.Id, U.Username, U.EsAdministrador, U.IdPersona
        FROM dbo.Usuario U
        WHERE U.Id = @IdUsuario;
    END TRY
    BEGIN CATCH
        SET @outResultCode = 50008;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Logout
    @inIdUsuario    INT,
    @outResultCode  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;
    BEGIN TRY
        -- Id 2 = Logout
        INSERT INTO dbo.Bitacora (IdUsuario, IdTipoOperacion)
        VALUES (@inIdUsuario, 2);
    END TRY
    BEGIN CATCH
        SET @outResultCode = 50008;
    END CATCH
END;
GO

-- El administrador ve todo; el cliente solo lo que esté en UsuarioPuedeVerCuenta
CREATE OR ALTER PROCEDURE dbo.sp_VerificarAccesoCuenta
    @inIdUsuario    INT,
    @inNumeroCuenta VARCHAR(16),
    @outResultCode  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 50003;
    BEGIN TRY
        IF EXISTS (SELECT 1
                   FROM dbo.Usuario U
                   WHERE U.Id = @inIdUsuario AND U.EsAdministrador = 1)
           OR EXISTS (SELECT 1
                      FROM dbo.UsuarioPuedeVerCuenta V
                      INNER JOIN dbo.Cuenta C ON C.Id = V.IdCuenta
                      WHERE V.IdUsuario = @inIdUsuario
                        AND C.NumeroCuenta = @inNumeroCuenta)
            SET @outResultCode = 0;
    END TRY
    BEGIN CATCH
        SET @outResultCode = 50008;
    END CATCH
END;
GO
