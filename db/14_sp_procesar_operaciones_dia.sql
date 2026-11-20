USE AhorrosDB;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- Aplica nodos por Id, con una transacción por nodo para permitir reanudar.
-- El llamador ejecuta los cierres y marca SimFecha como terminada después.
CREATE OR ALTER PROCEDURE dbo.sp_ProcesarOperacionesDia
    @inFecha DATE,
    @outResultCode INT OUTPUT,
    @outMensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;
    SET @outMensaje = NULL;

    IF @@TRANCOUNT <> 0 OR (@@OPTIONS & 2) = 2
    BEGIN
        SET @outResultCode = 50001;
        SET @outMensaje = N'El proceso requiere transacciones explícitas por nodo y ninguna transacción externa.';
        RETURN;
    END;

    SET XACT_ABORT ON;

    DECLARE @id INT, @tipo VARCHAR(20), @nodo XML,
            @terminada BIT, @procesados INT = 0,
            @saldo DECIMAL(18,2), @salt UNIQUEIDENTIFIER,
            @numeroCuenta VARCHAR(16), @tipoMovimiento VARCHAR(64),
            @monto DECIMAL(18,2), @descripcion NVARCHAR(200),
            @codigoMovimiento INT, @mensajeMovimiento NVARCHAR(400);

    BEGIN TRY
        WHILE 1 = 1
        BEGIN
            SET @id = NULL;
            SET @terminada = NULL;
            BEGIN TRANSACTION;

            -- Serializa la selección y aplicación de nodos de la misma fecha.
            SELECT @terminada = FlagTerminada
            FROM dbo.SimFecha WITH (UPDLOCK, HOLDLOCK)
            WHERE Fecha = @inFecha;

            IF @terminada IS NULL
                THROW 50001, N'La fecha no está registrada en SimFecha.', 1;

            IF @terminada = 0
                SELECT TOP (1) @id = Id, @tipo = TipoNodo, @nodo = Nodo
                FROM dbo.SimOperacion
                WHERE Fecha = @inFecha AND FlagProcesado = 0
                ORDER BY Id;

            IF @id IS NULL
            BEGIN
                COMMIT TRANSACTION;
                BREAK;
            END;

            IF @tipo = 'Persona'
            BEGIN
                INSERT dbo.Persona (IdTipoDocuIdentidad, ValorDocumentoIdentidad, Nombre,
                                    FechaNacimiento, Email, Telefono1, Telefono2)
                VALUES (@nodo.value('(/Persona/@TipoDocuIdentidad)[1]', 'INT'),
                        @nodo.value('(/Persona/@ValorDocumentoIdentidad)[1]', 'VARCHAR(32)'),
                        @nodo.value('(/Persona/@Nombre)[1]', 'VARCHAR(64)'),
                        @nodo.value('(/Persona/@FechaNacimiento)[1]', 'DATE'),
                        @nodo.value('(/Persona/@Email)[1]', 'VARCHAR(128)'),
                        @nodo.value('(/Persona/@telefono1)[1]', 'VARCHAR(16)'),
                        @nodo.value('(/Persona/@telefono2)[1]', 'VARCHAR(16)'));
            END
            ELSE IF @tipo = 'Cuenta'
            BEGIN
                SET @saldo = @nodo.value('(/Cuenta/@Saldo)[1]', 'DECIMAL(18,2)');
                IF @saldo IS NULL OR @saldo <> 0
                    THROW 50001, N'El saldo de apertura de la cuenta debe ser cero.', 1;

                INSERT dbo.Cuenta (NumeroCuenta, IdPersona, IdTipoCuentaAhorro, FechaCreacion, Saldo)
                VALUES (@nodo.value('(/Cuenta/@NumeroCuenta)[1]', 'VARCHAR(16)'),
                        (SELECT Id FROM dbo.Persona WHERE ValorDocumentoIdentidad =
                            @nodo.value('(/Cuenta/@ValorDocumentoIdentidadDelCliente)[1]', 'VARCHAR(32)')),
                        @nodo.value('(/Cuenta/@TipoCuentaId)[1]', 'INT'),
                        @nodo.value('(/Cuenta/@FechaCreacion)[1]', 'DATE'),
                        @saldo);
            END
            ELSE IF @tipo = 'Beneficiario'
            BEGIN
                INSERT dbo.Beneficiario (IdCuenta, IdPersona, IdParentezco, Porcentaje)
                VALUES ((SELECT Id FROM dbo.Cuenta WHERE NumeroCuenta =
                            @nodo.value('(/Beneficiario/@NumeroCuenta)[1]', 'VARCHAR(16)')),
                        (SELECT Id FROM dbo.Persona WHERE ValorDocumentoIdentidad =
                            @nodo.value('(/Beneficiario/@ValorDocumentoIdentidadBeneficiario)[1]', 'VARCHAR(32)')),
                        @nodo.value('(/Beneficiario/@IdParentezco)[1]', 'INT'),
                        @nodo.value('(/Beneficiario/@Porcentaje)[1]', 'INT'));
            END
            ELSE IF @tipo = 'Usuario'
            BEGIN
                SET @salt = NEWID();

                INSERT dbo.Usuario (Username, Salt, PasswordHash, EsAdministrador, IdPersona)
                VALUES (@nodo.value('(/Usuario/@User)[1]', 'VARCHAR(64)'),
                        @salt,
                        HASHBYTES('SHA2_256', CONVERT(CHAR(36), @salt) +
                            @nodo.value('(/Usuario/@Pass)[1]', 'VARCHAR(128)')),
                        @nodo.value('(/Usuario/@EsAdministrador)[1]', 'BIT'),
                        (SELECT Id FROM dbo.Persona WHERE ValorDocumentoIdentidad =
                            @nodo.value('(/Usuario/@ValorDocId)[1]', 'VARCHAR(32)')));
            END
            ELSE IF @tipo = 'UsuarioPuedeVer'
            BEGIN
                INSERT dbo.UsuarioPuedeVerCuenta (IdUsuario, IdCuenta)
                VALUES ((SELECT Id FROM dbo.Usuario WHERE Username =
                            @nodo.value('(/UsuarioPuedeVer/@User)[1]', 'VARCHAR(64)')),
                        (SELECT Id FROM dbo.Cuenta WHERE NumeroCuenta =
                            @nodo.value('(/UsuarioPuedeVer/@NumeroCuenta)[1]', 'VARCHAR(16)')));
            END
            ELSE IF @tipo = 'Movimientos'
            BEGIN
                SELECT @numeroCuenta = TRIM(@nodo.value('(/Movimientos/@CodigoCuenta)[1]', 'VARCHAR(16)')),
                       @tipoMovimiento = TRIM(@nodo.value('(/Movimientos/@Tipo)[1]', 'VARCHAR(64)')),
                       @monto = @nodo.value('(/Movimientos/@Monto)[1]', 'DECIMAL(18,2)'),
                       @descripcion = @nodo.value('(/Movimientos/@Descripcion)[1]', 'NVARCHAR(200)');

                SET @codigoMovimiento = NULL;
                BEGIN TRY
                    EXEC dbo.sp_AplicarMovimiento
                        @inFecha = @inFecha,
                        @inNumeroCuenta = @numeroCuenta,
                        @inNombreTipoMovimiento = @tipoMovimiento,
                        @inMonto = @monto,
                        @inDescripcion = @descripcion,
                        @outResultCode = @codigoMovimiento OUTPUT,
                        @outMensaje = @mensajeMovimiento OUTPUT;
                END TRY
                BEGIN CATCH
                    -- El rollback interno de la SP 12 puede generar el error 266.
                    IF ERROR_NUMBER() <> 266 OR @codigoMovimiento IS NULL OR @codigoMovimiento = 0
                        THROW;
                END CATCH;

                IF @codigoMovimiento <> 0
                BEGIN
                    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
                    SET @outResultCode = @codigoMovimiento;
                    SET @outMensaje = LEFT(CONCAT(N'Nodo ', @id, N' (', @tipo, N'): ', @mensajeMovimiento), 200);
                    RETURN;
                END;
            END
            ELSE
                THROW 50001, N'Tipo de nodo no reconocido.', 1;

            UPDATE dbo.SimOperacion SET FlagProcesado = 1 WHERE Id = @id;
            COMMIT TRANSACTION;
            SET @procesados += 1;
        END;

        SET @outMensaje = CONCAT(N'Nodos procesados en esta llamada: ', @procesados, N'.');
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        SET @outResultCode = ERROR_NUMBER();
        SET @outMensaje = LEFT(CONCAT(
            CASE WHEN @id IS NOT NULL THEN CONCAT(N'Nodo ', @id, N' (', @tipo, N'): ') ELSE N'' END,
            ERROR_MESSAGE()), 200);
    END CATCH;
END;
GO
