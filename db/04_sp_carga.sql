-- =====================================================================
-- TP2 - SPs de carga desde XML. Re-ejecutables: solo insertan lo que
-- aún no existe (catálogos por Id; personas por documento; cuentas por
-- número; usuarios por username; etc.).
-- El XML llega como NVARCHAR(MAX) desde Java (sin la declaración <?xml ?>).
-- Códigos: 0 OK, 50008 error (detalle en @outMensaje).
-- =====================================================================
USE AhorrosDB;
GO
-- Necesario para índices filtrados y métodos XML; sqlcmd lo trae en OFF por defecto
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_CargarCatalogos
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
        DECLARE @nDoc INT, @nMon INT, @nPar INT, @nCta INT, @nOp INT;

        BEGIN TRANSACTION;

        INSERT dbo.TipoDocuIdentidad (Id, Nombre)
        SELECT T.n.value('(@Id)[1]', 'INT'), T.n.value('(@Nombre)[1]', 'VARCHAR(64)')
        FROM @x.nodes('//TipoDocuIdentidad') AS T(n)
        WHERE NOT EXISTS (SELECT 1 FROM dbo.TipoDocuIdentidad D
                          WHERE D.Id = T.n.value('(@Id)[1]', 'INT'));
        SET @nDoc = @@ROWCOUNT;

        INSERT dbo.TipoMoneda (Id, Nombre, Simbolo)
        SELECT T.n.value('(@Id)[1]', 'INT'), T.n.value('(@Nombre)[1]', 'VARCHAR(32)'),
               T.n.value('(@Simbolo)[1]', 'NVARCHAR(4)')
        FROM @x.nodes('//TipoMoneda') AS T(n)
        WHERE NOT EXISTS (SELECT 1 FROM dbo.TipoMoneda M
                          WHERE M.Id = T.n.value('(@Id)[1]', 'INT'));
        SET @nMon = @@ROWCOUNT;

        INSERT dbo.Parentezco (Id, Nombre)
        SELECT T.n.value('(@Id)[1]', 'INT'), T.n.value('(@Nombre)[1]', 'VARCHAR(32)')
        FROM @x.nodes('//Parentezco') AS T(n)
        WHERE NOT EXISTS (SELECT 1 FROM dbo.Parentezco P
                          WHERE P.Id = T.n.value('(@Id)[1]', 'INT'));
        SET @nPar = @@ROWCOUNT;

        -- Tolerante a mayúsculas distintas en los atributos (el PDF mezcla estilos)
        INSERT dbo.TipoCuentaAhorro
            (Id, Nombre, IdTipoMoneda, SaldoMinimo, MultaSaldoMin, CargoServicio,
             NumRetirosHumano, NumRetirosAutomatico, ComisionHumano, ComisionAutomatico,
             TasaInteresMensual)
        SELECT T.n.value('(@Id)[1]', 'INT'),
               T.n.value('(@Nombre)[1]', 'VARCHAR(64)'),
               T.n.value('(@IdTipoMoneda)[1]', 'INT'),
               T.n.value('(@SaldoMinimo)[1]', 'DECIMAL(18,2)'),
               T.n.value('(@MultaSaldoMin)[1]', 'DECIMAL(18,2)'),
               CASE WHEN T.n.exist('@CargoAnual') = 1 THEN T.n.value('(@CargoAnual)[1]', 'DECIMAL(18,2)') ELSE T.n.value('(@CargoMensual)[1]', 'DECIMAL(18,2)') END,
               T.n.value('(@NumRetirosHumano)[1]', 'INT'),
               T.n.value('(@NumRetirosAutomatico)[1]', 'INT'),
               CASE WHEN T.n.exist('@comisionHumano') = 1 THEN T.n.value('(@comisionHumano)[1]', 'DECIMAL(18,2)') ELSE T.n.value('(@ComisionHumano)[1]', 'DECIMAL(18,2)') END,
               CASE WHEN T.n.exist('@comisionAutomatico') = 1 THEN T.n.value('(@comisionAutomatico)[1]', 'DECIMAL(18,2)') ELSE T.n.value('(@ComisionAutomatico)[1]', 'DECIMAL(18,2)') END,
               CASE WHEN T.n.exist('@interes') = 1 THEN T.n.value('(@interes)[1]', 'DECIMAL(9,4)') ELSE T.n.value('(@Interes)[1]', 'DECIMAL(9,4)') END
        FROM @x.nodes('//TipoCuentaAhorro') AS T(n)
        WHERE NOT EXISTS (SELECT 1 FROM dbo.TipoCuentaAhorro C
                          WHERE C.Id = T.n.value('(@Id)[1]', 'INT'));
        SET @nCta = @@ROWCOUNT;

        INSERT dbo.TipoOperacionBitacora (Id, Nombre)
        SELECT CASE WHEN T.n.exist('@Id') = 1 THEN T.n.value('(@Id)[1]', 'INT') ELSE T.n.value('(@id)[1]', 'INT') END,
               CASE WHEN T.n.exist('@Nombre') = 1 THEN T.n.value('(@Nombre)[1]', 'VARCHAR(64)') ELSE T.n.value('(@nombre)[1]', 'VARCHAR(64)') END
        FROM @x.nodes('//TipoOperacion') AS T(n)
        WHERE NOT EXISTS (SELECT 1 FROM dbo.TipoOperacionBitacora O
                          WHERE O.Id = CASE WHEN T.n.exist('@Id') = 1 THEN T.n.value('(@Id)[1]', 'INT') ELSE T.n.value('(@id)[1]', 'INT') END);
        SET @nOp = @@ROWCOUNT;

        COMMIT TRANSACTION;

        SET @outMensaje = CONCAT('Catalogos nuevos: TipoDocu=', @nDoc, ' Moneda=', @nMon,
                                 ' Parentezco=', @nPar, ' TipoCuenta=', @nCta,
                                 ' TipoOperacion=', @nOp);
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        SET @outResultCode = 50008;
        SET @outMensaje = LEFT(ERROR_MESSAGE(), 400);
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_CargarDatos
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
        DECLARE @nPer INT, @nCta INT, @nBen INT, @nEst INT, @nUsu INT, @nVer INT;

        -- Usuarios: el salt se asigna UNA vez (DEFAULT NEWID() al insertar en la
        -- variable de tabla) para que coincida el hash con lo guardado.
        DECLARE @U TABLE (
            Username VARCHAR(64), Pass VARCHAR(128), EsAdmin INT, Doc VARCHAR(32),
            Salt UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID());

        BEGIN TRANSACTION;

        -- 1. Personas (dueños y beneficiarios comparten tabla)
        INSERT dbo.Persona (IdTipoDocuIdentidad, ValorDocumentoIdentidad, Nombre,
                            FechaNacimiento, Email, Telefono1, Telefono2)
        SELECT T.n.value('(@TipoDocuIdentidad)[1]', 'INT'),
               T.n.value('(@ValorDocumentoIdentidad)[1]', 'VARCHAR(32)'),
               T.n.value('(@Nombre)[1]', 'VARCHAR(64)'),
               T.n.value('(@FechaNacimiento)[1]', 'DATE'),
               T.n.value('(@Email)[1]', 'VARCHAR(128)'),
               T.n.value('(@telefono1)[1]', 'VARCHAR(16)'),
               T.n.value('(@telefono2)[1]', 'VARCHAR(16)')
        FROM @x.nodes('/*/Personas/Persona') AS T(n)
        WHERE NOT EXISTS (SELECT 1 FROM dbo.Persona P
                          WHERE P.ValorDocumentoIdentidad =
                                T.n.value('(@ValorDocumentoIdentidad)[1]', 'VARCHAR(32)'));
        SET @nPer = @@ROWCOUNT;

        -- 2. Cuentas (LEFT JOIN: si no resuelve la llave alterna, el NOT NULL falla y todo se revierte)
        INSERT dbo.Cuenta (NumeroCuenta, IdPersona, IdTipoCuentaAhorro, FechaCreacion, Saldo)
        SELECT T.n.value('(@NumeroCuenta)[1]', 'VARCHAR(16)'),
               P.Id,
               T.n.value('(@TipoCuentaId)[1]', 'INT'),
               T.n.value('(@FechaCreacion)[1]', 'DATE'),
               T.n.value('(@Saldo)[1]', 'DECIMAL(18,2)')
        FROM @x.nodes('/*/Cuentas/Cuenta') AS T(n)
        LEFT JOIN dbo.Persona P
               ON P.ValorDocumentoIdentidad =
                  T.n.value('(@ValorDocumentoIdentidadDelCliente)[1]', 'VARCHAR(32)')
        WHERE NOT EXISTS (SELECT 1 FROM dbo.Cuenta C
                          WHERE C.NumeroCuenta = T.n.value('(@NumeroCuenta)[1]', 'VARCHAR(16)'));
        SET @nCta = @@ROWCOUNT;

        -- 3. Beneficiarios
        INSERT dbo.Beneficiario (IdCuenta, IdPersona, IdParentezco, Porcentaje)
        SELECT C.Id, P.Id,
               T.n.value('(@IdParentezco)[1]', 'INT'),
               T.n.value('(@Porcentaje)[1]', 'INT')
        FROM @x.nodes('/*/Beneficiarios/Beneficiario') AS T(n)
        LEFT JOIN dbo.Cuenta  C ON C.NumeroCuenta = T.n.value('(@NumeroCuenta)[1]', 'VARCHAR(16)')
        LEFT JOIN dbo.Persona P ON P.ValorDocumentoIdentidad =
                                   T.n.value('(@ValorDocumentoIdentidadBeneficiario)[1]', 'VARCHAR(32)')
        WHERE NOT EXISTS (SELECT 1 FROM dbo.Beneficiario B
                          WHERE B.IdCuenta = C.Id AND B.IdPersona = P.Id AND B.FlagActivo = 1);
        SET @nBen = @@ROWCOUNT;

        -- 4. Estados de cuenta
        INSERT dbo.EstadoCuenta
            (IdCuenta, FechaInicio, FechaFin, SaldoInicial, SaldoMinimo, SaldoFinal,
             InteresesAcumulados, CantRetiros, CantDepositos, CantSinpeEntrantes, CantSinpeSalientes)
        SELECT C.Id,
               T.n.value('(@fechaInicio)[1]', 'DATE'),
               T.n.value('(@fechafin)[1]', 'DATE'),
               T.n.value('(@saldoinicial)[1]', 'DECIMAL(18,2)'),
               T.n.value('(@saldoMinimo)[1]', 'DECIMAL(18,2)'),
               T.n.value('(@saldo_final)[1]', 'DECIMAL(18,2)'),
               CASE WHEN T.n.exist('@interesesAcumulados') = 1 THEN T.n.value('(@interesesAcumulados)[1]', 'DECIMAL(18,2)') ELSE 0 END,
               CASE WHEN T.n.exist('@cantRetiros') = 1 THEN T.n.value('(@cantRetiros)[1]', 'INT') ELSE 0 END,
               CASE WHEN T.n.exist('@cantDepositos') = 1 THEN T.n.value('(@cantDepositos)[1]', 'INT') ELSE 0 END,
               CASE WHEN T.n.exist('@cantSinpeEntrantes') = 1 THEN T.n.value('(@cantSinpeEntrantes)[1]', 'INT') ELSE 0 END,
               CASE WHEN T.n.exist('@cantSinpeSalientes') = 1 THEN T.n.value('(@cantSinpeSalientes)[1]', 'INT') ELSE 0 END
        FROM @x.nodes('/*/Estados_de_Cuenta/Estado_de_Cuenta') AS T(n)
        LEFT JOIN dbo.Cuenta C ON C.NumeroCuenta = T.n.value('(@NumeroCuenta)[1]', 'VARCHAR(16)')
        WHERE NOT EXISTS (SELECT 1 FROM dbo.EstadoCuenta E
                          WHERE E.IdCuenta = C.Id
                            AND E.FechaInicio = T.n.value('(@fechaInicio)[1]', 'DATE'));
        SET @nEst = @@ROWCOUNT;

        -- 5. Usuarios (hash con salt; mismo cálculo que sp_Login)
        INSERT @U (Username, Pass, EsAdmin, Doc)
        SELECT T.n.value('(@User)[1]', 'VARCHAR(64)'),
               T.n.value('(@Pass)[1]', 'VARCHAR(128)'),
               T.n.value('(@EsAdministrador)[1]', 'INT'),
               T.n.value('(@ValorDocId)[1]', 'VARCHAR(32)')
        FROM @x.nodes('/*/Usuarios/Usuario') AS T(n);

        INSERT dbo.Usuario (Username, Salt, PasswordHash, EsAdministrador, IdPersona)
        SELECT S.Username, S.Salt,
               HASHBYTES('SHA2_256', CONCAT(CONVERT(CHAR(36), S.Salt), S.Pass)),
               CASE WHEN S.EsAdmin = 0 THEN 0 ELSE 1 END,
               P.Id
        FROM @U S
        LEFT JOIN dbo.Persona P ON P.ValorDocumentoIdentidad = S.Doc
        WHERE NOT EXISTS (SELECT 1 FROM dbo.Usuario X WHERE X.Username = S.Username);
        SET @nUsu = @@ROWCOUNT;

        -- 6. Qué cuentas ve cada usuario
        INSERT dbo.UsuarioPuedeVerCuenta (IdUsuario, IdCuenta)
        SELECT U.Id, C.Id
        FROM @x.nodes('/*/Usuarios_Ver/UsuarioPuedeVer') AS T(n)
        LEFT JOIN dbo.Usuario U ON U.Username     = T.n.value('(@User)[1]', 'VARCHAR(64)')
        LEFT JOIN dbo.Cuenta  C ON C.NumeroCuenta = T.n.value('(@NumeroCuenta)[1]', 'VARCHAR(16)')
        WHERE NOT EXISTS (SELECT 1 FROM dbo.UsuarioPuedeVerCuenta V
                          WHERE V.IdUsuario = U.Id AND V.IdCuenta = C.Id);
        SET @nVer = @@ROWCOUNT;

        COMMIT TRANSACTION;

        SET @outMensaje = CONCAT('Cargado: Personas=', @nPer, ' Cuentas=', @nCta,
                                 ' Beneficiarios=', @nBen, ' Estados=', @nEst,
                                 ' Usuarios=', @nUsu, ' UsuarioVerCuenta=', @nVer);
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        SET @outResultCode = 50008;
        SET @outMensaje = LEFT(ERROR_MESSAGE(), 400);
    END CATCH
END;
GO
