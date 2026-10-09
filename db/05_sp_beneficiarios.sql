-- =====================================================================
-- TP2 - Beneficiarios: listar, insertar, actualizar, eliminar (logico)
-- Codigos de resultado (@outResultCode):
--   0 OK | 50003 sin acceso a la cuenta | 50004 maximo 3 beneficiarios
--   50005 dato invalido (detalle en @outMensaje) | 50006 ya es beneficiario
--   50007 cuenta o beneficiario no existe | 50008 error de base de datos
-- Cada cambio queda en Bitacora con JSON antes/despues (3 agregar,
-- 4 actualizar, 5 eliminar, 6 actualizar solo el porcentaje).
-- =====================================================================
USE AhorrosDB;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- JSON de un beneficiario, para la bitacora
CREATE OR ALTER FUNCTION dbo.fn_JsonBeneficiario (@inIdBeneficiario INT)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    RETURN (
        SELECT B.Id                      AS id,
               C.NumeroCuenta            AS numeroCuenta,
               P.Nombre                  AS nombre,
               P.IdTipoDocuIdentidad     AS idTipoDocuIdentidad,
               P.ValorDocumentoIdentidad AS valorDocumentoIdentidad,
               P.FechaNacimiento         AS fechaNacimiento,
               P.Email                   AS email,
               P.Telefono1               AS telefono1,
               P.Telefono2               AS telefono2,
               B.IdParentezco            AS idParentezco,
               B.Porcentaje              AS porcentaje,
               B.FlagActivo              AS flagActivo,
               B.FechaDesactivacion      AS fechaDesactivacion
        FROM dbo.Beneficiario B
        INNER JOIN dbo.Persona P ON P.Id = B.IdPersona
        INNER JOIN dbo.Cuenta  C ON C.Id = B.IdCuenta
        WHERE B.Id = @inIdBeneficiario
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ListarBeneficiarios
    @inIdUsuario         INT,
    @inNumeroCuenta      VARCHAR(16),
    @outSumaPorcentajes  INT OUTPUT,
    @outResultCode       INT OUTPUT,
    @outMensaje          NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @outSumaPorcentajes = 0;
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

        SELECT @outSumaPorcentajes = COALESCE(SUM(B.Porcentaje), 0)
        FROM dbo.Beneficiario B
        WHERE B.IdCuenta = @idCuenta AND B.FlagActivo = 1;

        SELECT B.Id, P.Nombre, P.IdTipoDocuIdentidad,
               P.ValorDocumentoIdentidad, P.FechaNacimiento, P.Email,
               P.Telefono1, P.Telefono2, B.IdParentezco,
               PA.Nombre AS Parentezco, B.Porcentaje
        FROM dbo.Beneficiario B
        INNER JOIN dbo.Persona    P  ON P.Id  = B.IdPersona
        INNER JOIN dbo.Parentezco PA ON PA.Id = B.IdParentezco
        WHERE B.IdCuenta = @idCuenta AND B.FlagActivo = 1
        ORDER BY B.Id;
    END TRY
    BEGIN CATCH
        SET @outResultCode = 50008;
        SET @outMensaje = LEFT(ERROR_MESSAGE(), 200);
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_InsertarBeneficiario
    @inIdUsuario                INT,
    @inNumeroCuenta             VARCHAR(16),
    @inIdTipoDocuIdentidad      INT,
    @inValorDocumentoIdentidad  VARCHAR(32),
    @inNombre                   VARCHAR(64),
    @inFechaNacimiento          DATE,
    @inEmail                    VARCHAR(128),
    @inTelefono1                VARCHAR(16),
    @inTelefono2                VARCHAR(16),
    @inIdParentezco             INT,
    @inPorcentaje               INT,
    @outIdBeneficiario          INT OUTPUT,
    @outResultCode              INT OUTPUT,
    @outMensaje                 NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @outIdBeneficiario = NULL;
    SET @outResultCode = 0;
    SET @outMensaje = NULL;

    DECLARE @idCuenta INT, @idPersona INT, @idBeneficiario INT;
    DECLARE @cantActivos INT, @jsonDespues NVARCHAR(MAX);

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

        SET @inNombre = LTRIM(RTRIM(COALESCE(@inNombre, '')));

        -- Validaciones: gana el primer mensaje que aplique
        SET @outMensaje = CASE
            WHEN @inNombre = ''
                THEN N'El nombre es obligatorio.'
            WHEN COALESCE(@inValorDocumentoIdentidad, '') = ''
              OR @inValorDocumentoIdentidad LIKE '%[^0-9]%'
                THEN N'El documento debe ser un valor numerico.'
            WHEN NOT EXISTS (SELECT 1 FROM dbo.TipoDocuIdentidad T
                             WHERE T.Id = @inIdTipoDocuIdentidad)
                THEN N'El tipo de documento no existe.'
            WHEN @inFechaNacimiento IS NULL
              OR @inFechaNacimiento > CAST(SYSDATETIME() AS DATE)
              OR @inFechaNacimiento < '1900-01-01'
                THEN N'La fecha de nacimiento no es valida.'
            WHEN @inEmail IS NULL OR @inEmail NOT LIKE '%_@_%._%'
                THEN N'El email no es valido.'
            WHEN COALESCE(@inTelefono1, '') = ''
              OR @inTelefono1 LIKE '%[^0-9]%'
              OR COALESCE(@inTelefono2, '') = ''
              OR @inTelefono2 LIKE '%[^0-9]%'
                THEN N'Los dos telefonos deben ser numericos.'
            WHEN NOT EXISTS (SELECT 1 FROM dbo.Parentezco PA
                             WHERE PA.Id = @inIdParentezco)
                THEN N'El parentesco no existe.'
            WHEN @inPorcentaje IS NULL
              OR @inPorcentaje NOT BETWEEN 0 AND 100
                THEN N'El porcentaje debe estar entre 0 y 100.'
            END;
        IF @outMensaje IS NOT NULL
        BEGIN
            SET @outResultCode = 50005;
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

        BEGIN TRANSACTION;

        -- UPDLOCK/HOLDLOCK: dos altas simultaneas no pasan del maximo
        SELECT @cantActivos = COUNT(*)
        FROM dbo.Beneficiario B WITH (UPDLOCK, HOLDLOCK)
        WHERE B.IdCuenta = @idCuenta AND B.FlagActivo = 1;

        IF @cantActivos >= 3
        BEGIN
            ROLLBACK TRANSACTION;
            SET @outResultCode = 50004;
            SET @outMensaje = N'La cuenta ya tiene 3 beneficiarios.';
            RETURN;
        END;

        -- La persona se comparte con los duenos: existe una sola vez
        SELECT @idPersona = P.Id
        FROM dbo.Persona P
        WHERE P.ValorDocumentoIdentidad = @inValorDocumentoIdentidad;

        IF @idPersona IS NULL
        BEGIN
            INSERT dbo.Persona
                (IdTipoDocuIdentidad, ValorDocumentoIdentidad, Nombre,
                 FechaNacimiento, Email, Telefono1, Telefono2)
            VALUES
                (@inIdTipoDocuIdentidad, @inValorDocumentoIdentidad, @inNombre,
                 @inFechaNacimiento, @inEmail, @inTelefono1, @inTelefono2);
            SET @idPersona = SCOPE_IDENTITY();
        END;

        IF EXISTS (SELECT 1 FROM dbo.Beneficiario B
                   WHERE B.IdCuenta = @idCuenta
                     AND B.IdPersona = @idPersona
                     AND B.FlagActivo = 1)
        BEGIN
            ROLLBACK TRANSACTION;
            SET @outResultCode = 50006;
            SET @outMensaje = N'Esa persona ya es beneficiaria de la cuenta.';
            RETURN;
        END;

        INSERT dbo.Beneficiario (IdCuenta, IdPersona, IdParentezco, Porcentaje)
        VALUES (@idCuenta, @idPersona, @inIdParentezco, @inPorcentaje);
        SET @idBeneficiario = SCOPE_IDENTITY();

        SET @jsonDespues = dbo.fn_JsonBeneficiario(@idBeneficiario);
        INSERT dbo.Bitacora (IdUsuario, IdTipoOperacion, JsonAntes, JsonDespues)
        VALUES (@inIdUsuario, 3, NULL, @jsonDespues);

        COMMIT TRANSACTION;
        SET @outIdBeneficiario = @idBeneficiario;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        SET @outResultCode = 50008;
        SET @outMensaje = LEFT(ERROR_MESSAGE(), 200);
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ActualizarBeneficiario
    @inIdUsuario        INT,
    @inNumeroCuenta     VARCHAR(16),
    @inIdBeneficiario   INT,
    @inNombre           VARCHAR(64),
    @inIdParentezco     INT,
    @inPorcentaje       INT,
    @outResultCode      INT OUTPUT,
    @outMensaje         NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @outResultCode = 0;
    SET @outMensaje = NULL;

    DECLARE @idPersona INT, @nombreActual VARCHAR(64);
    DECLARE @idParentezcoActual INT, @porcentajeActual INT;
    DECLARE @flagCambioNombre BIT, @flagCambioParentezco BIT;
    DECLARE @flagCambioPorcentaje BIT;
    DECLARE @idTipoOperacion INT;
    DECLARE @jsonAntes NVARCHAR(MAX), @jsonDespues NVARCHAR(MAX);

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

        SET @inNombre = LTRIM(RTRIM(COALESCE(@inNombre, '')));

        SET @outMensaje = CASE
            WHEN @inNombre = ''
                THEN N'El nombre es obligatorio.'
            WHEN NOT EXISTS (SELECT 1 FROM dbo.Parentezco PA
                             WHERE PA.Id = @inIdParentezco)
                THEN N'El parentesco no existe.'
            WHEN @inPorcentaje IS NULL
              OR @inPorcentaje NOT BETWEEN 0 AND 100
                THEN N'El porcentaje debe estar entre 0 y 100.'
            END;
        IF @outMensaje IS NOT NULL
        BEGIN
            SET @outResultCode = 50005;
            RETURN;
        END;

        SELECT @idPersona         = B.IdPersona,
               @nombreActual      = P.Nombre,
               @idParentezcoActual = B.IdParentezco,
               @porcentajeActual  = B.Porcentaje
        FROM dbo.Beneficiario B
        INNER JOIN dbo.Persona P ON P.Id = B.IdPersona
        INNER JOIN dbo.Cuenta  C ON C.Id = B.IdCuenta
        WHERE B.Id = @inIdBeneficiario
          AND C.NumeroCuenta = @inNumeroCuenta
          AND B.FlagActivo = 1;

        IF @idPersona IS NULL
        BEGIN
            SET @outResultCode = 50007;
            SET @outMensaje = N'El beneficiario no existe en esa cuenta.';
            RETURN;
        END;

        SET @flagCambioNombre =
            CASE WHEN @inNombre COLLATE Latin1_General_BIN
                    = @nombreActual COLLATE Latin1_General_BIN
                 THEN 0 ELSE 1 END;
        SET @flagCambioParentezco =
            CASE WHEN @inIdParentezco = @idParentezcoActual
                 THEN 0 ELSE 1 END;
        SET @flagCambioPorcentaje =
            CASE WHEN @inPorcentaje = @porcentajeActual
                 THEN 0 ELSE 1 END;

        IF @flagCambioNombre = 0 AND @flagCambioParentezco = 0
           AND @flagCambioPorcentaje = 0
            RETURN;  -- no hay nada que cambiar: no se escribe bitacora

        -- 6 = solo cambio el porcentaje; 4 = cualquier otro cambio
        SET @idTipoOperacion =
            CASE WHEN @flagCambioNombre = 0 AND @flagCambioParentezco = 0
                 THEN 6 ELSE 4 END;

        SET @jsonAntes = dbo.fn_JsonBeneficiario(@inIdBeneficiario);

        BEGIN TRANSACTION;

        IF @flagCambioNombre = 1
            UPDATE dbo.Persona
            SET Nombre = @inNombre
            WHERE Id = @idPersona;

        UPDATE dbo.Beneficiario
        SET IdParentezco = @inIdParentezco,
            Porcentaje   = @inPorcentaje
        WHERE Id = @inIdBeneficiario;

        SET @jsonDespues = dbo.fn_JsonBeneficiario(@inIdBeneficiario);
        INSERT dbo.Bitacora (IdUsuario, IdTipoOperacion, JsonAntes, JsonDespues)
        VALUES (@inIdUsuario, @idTipoOperacion, @jsonAntes, @jsonDespues);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        SET @outResultCode = 50008;
        SET @outMensaje = LEFT(ERROR_MESSAGE(), 200);
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_EliminarBeneficiario
    @inIdUsuario        INT,
    @inNumeroCuenta     VARCHAR(16),
    @inIdBeneficiario   INT,
    @outResultCode      INT OUTPUT,
    @outMensaje         NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @outResultCode = 0;
    SET @outMensaje = NULL;

    DECLARE @idEncontrado INT;
    DECLARE @jsonAntes NVARCHAR(MAX), @jsonDespues NVARCHAR(MAX);

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

        SELECT @idEncontrado = B.Id
        FROM dbo.Beneficiario B
        INNER JOIN dbo.Cuenta C ON C.Id = B.IdCuenta
        WHERE B.Id = @inIdBeneficiario
          AND C.NumeroCuenta = @inNumeroCuenta
          AND B.FlagActivo = 1;

        IF @idEncontrado IS NULL
        BEGIN
            SET @outResultCode = 50007;
            SET @outMensaje = N'El beneficiario no existe en esa cuenta.';
            RETURN;
        END;

        SET @jsonAntes = dbo.fn_JsonBeneficiario(@idEncontrado);

        BEGIN TRANSACTION;

        UPDATE dbo.Beneficiario
        SET FlagActivo = 0,
            FechaDesactivacion = CAST(SYSDATETIME() AS DATE)
        WHERE Id = @idEncontrado;

        SET @jsonDespues = dbo.fn_JsonBeneficiario(@idEncontrado);
        INSERT dbo.Bitacora (IdUsuario, IdTipoOperacion, JsonAntes, JsonDespues)
        VALUES (@inIdUsuario, 5, @jsonAntes, @jsonDespues);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        SET @outResultCode = 50008;
        SET @outMensaje = LEFT(ERROR_MESSAGE(), 200);
    END CATCH
END;
GO
