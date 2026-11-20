-- =====================================================================
-- Carga solo los USUARIOS (y las personas a las que pertenecen) desde
-- no_catalogos.xml. No toca cuentas, beneficiarios, estados de cuenta ni
-- UsuarioPuedeVer: eso lo crea la simulacion (OperacionesTarea3.xml).
-- Re-ejecutable: solo inserta lo que no existe.
-- Codigos (@outResultCode): 0 OK | 50008 error (detalle en @outMensaje).
-- =====================================================================
USE AhorrosDB;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_CargarUsuariosBase
    @inXml          NVARCHAR(MAX),
    @outResultCode  INT OUTPUT,
    @outMensaje     NVARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @outResultCode = 0;
    SET @outMensaje = NULL;

    BEGIN TRY
        DECLARE @x XML = CAST(@inXml AS XML);
        DECLARE @nPer INT, @nUsu INT;

        -- El salt se asigna una sola vez (DEFAULT NEWID() al insertar)
        DECLARE @U TABLE (
            Username VARCHAR(64), Pass VARCHAR(128), EsAdmin INT,
            Doc VARCHAR(32),
            Salt UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID());

        INSERT @U (Username, Pass, EsAdmin, Doc)
        SELECT T.n.value('@User', 'VARCHAR(64)'),
               T.n.value('@Pass', 'VARCHAR(128)'),
               T.n.value('@EsAdministrador', 'INT'),
               T.n.value('@ValorDocId', 'VARCHAR(32)')
        FROM @x.nodes('/*/Usuarios/Usuario') AS T(n);

        BEGIN TRANSACTION;

        -- Solo las personas que son duenas de un usuario
        INSERT dbo.Persona
            (IdTipoDocuIdentidad, ValorDocumentoIdentidad, Nombre,
             FechaNacimiento, Email, Telefono1, Telefono2)
        SELECT T.n.value('@TipoDocuIdentidad', 'INT'),
               T.n.value('@ValorDocumentoIdentidad', 'VARCHAR(32)'),
               T.n.value('@Nombre', 'VARCHAR(64)'),
               T.n.value('@FechaNacimiento', 'DATE'),
               T.n.value('@Email', 'VARCHAR(128)'),
               T.n.value('@telefono1', 'VARCHAR(16)'),
               T.n.value('@telefono2', 'VARCHAR(16)')
        FROM @x.nodes('/*/Personas/Persona') AS T(n)
        WHERE EXISTS (SELECT 1 FROM @U S
                      WHERE S.Doc =
                        T.n.value('@ValorDocumentoIdentidad', 'VARCHAR(32)'))
          AND NOT EXISTS (SELECT 1 FROM dbo.Persona P
                          WHERE P.ValorDocumentoIdentidad =
                            T.n.value('@ValorDocumentoIdentidad', 'VARCHAR(32)'));
        SET @nPer = @@ROWCOUNT;

        -- Hash con salt: mismo calculo que sp_Login
        INSERT dbo.Usuario
            (Username, Salt, PasswordHash, EsAdministrador, IdPersona)
        SELECT S.Username, S.Salt,
               HASHBYTES('SHA2_256',
                         CONCAT(CONVERT(CHAR(36), S.Salt), S.Pass)),
               CASE WHEN S.EsAdmin = 0 THEN 0 ELSE 1 END,
               P.Id
        FROM @U S
        LEFT JOIN dbo.Persona P ON P.ValorDocumentoIdentidad = S.Doc
        WHERE NOT EXISTS (SELECT 1 FROM dbo.Usuario X
                          WHERE X.Username = S.Username);
        SET @nUsu = @@ROWCOUNT;

        COMMIT TRANSACTION;

        SET @outMensaje = CONCAT('Usuarios base: Personas=', @nPer,
                                 ' Usuarios=', @nUsu);
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        SET @outResultCode = 50008;
        SET @outMensaje = LEFT(ERROR_MESSAGE(), 400);
    END CATCH
END;
GO
