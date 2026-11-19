USE AhorrosDB;
GO
SET QUOTED_IDENTIFIER ON;
GO

/*
 TP3 - Aplica un movimiento del XML a UNA cuenta.
 - El monto de Movimiento siempre es positivo; TipoMovimiento.Accion da el signo.
 - Los cargos internos del banco pueden causar saldo negativo (politica adoptada).
 - Un Retiro Sinpe que excede el limite diario genera Comision Sinpe en la misma transaccion.
 - No autentica al usuario: es un SP de la simulacion, no una transferencia de portal.
*/
CREATE OR ALTER PROCEDURE dbo.sp_AplicarMovimiento
    @inFecha DATE,
    @inNumeroCuenta VARCHAR(16),
    @inNombreTipoMovimiento VARCHAR(64),
    @inMonto DECIMAL(18,2),
    @inDescripcion NVARCHAR(200),
    @outResultCode INT OUTPUT,
    @outMensaje NVARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @outResultCode = 0;
    SET @outMensaje = N'OK';

    IF @inFecha IS NULL OR NULLIF(LTRIM(RTRIM(@inNumeroCuenta)), '') IS NULL
       OR NULLIF(LTRIM(RTRIM(@inNombreTipoMovimiento)), '') IS NULL
       OR @inMonto IS NULL OR @inMonto <= 0
       OR NULLIF(LTRIM(RTRIM(@inDescripcion)), N'') IS NULL
    BEGIN
        SET @outResultCode = 50001;
        SET @outMensaje = N'Parametros incompletos o monto no positivo.';
        RETURN;
    END;

    DECLARE @idCuenta INT, @saldoActual DECIMAL(18,2),
            @idEstadoCuenta INT,
            @idTipoMovimiento INT, @accion VARCHAR(8), @generaComprobante BIT,
            @nuevoSaldo DECIMAL(18,2), @idMovimiento BIGINT,
            @emailDestino VARCHAR(128),
            @esRetiroSinpe BIT = 0,
            @montoEnviadoHoy DECIMAL(38,2) = 0,
            @limiteSinpe DECIMAL(18,2), @comisionSinpe DECIMAL(18,2),
            @idTipoComision INT, @comisionAccion VARCHAR(8),
            @saldoTrasComision DECIMAL(18,2);

    -- Cuando el llamador abre la transacción, también decide su rollback.
    DECLARE @transaccionPropia BIT = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;

    BEGIN TRY
        IF @transaccionPropia = 1 BEGIN TRANSACTION;

        -- Bloquear primero la cuenta; serializa movimientos simultaneos sobre ella.
        SELECT @idCuenta = C.Id,
               @saldoActual = C.Saldo
        FROM dbo.Cuenta AS C WITH (UPDLOCK, HOLDLOCK)
        WHERE C.NumeroCuenta = @inNumeroCuenta;

        IF @idCuenta IS NULL
            THROW 50007, N'La cuenta no existe.', 1;

        SELECT @idTipoMovimiento = TM.Id,
               @accion = TM.Accion,
               @generaComprobante = TM.FlagGeneraComprobante
        FROM dbo.TipoMovimiento AS TM
        WHERE TM.Nombre = @inNombreTipoMovimiento;

        IF @idTipoMovimiento IS NULL
            THROW 50009, N'El tipo de movimiento no existe en el catalogo.', 1;

        SELECT @idEstadoCuenta = EC.Id
        FROM dbo.EstadoCuenta AS EC WITH (UPDLOCK, HOLDLOCK)
        WHERE EC.IdCuenta = @idCuenta
          AND EC.FlagCerrado = 0
          AND @inFecha BETWEEN EC.FechaInicio AND EC.FechaFin;

        IF @idEstadoCuenta IS NULL
            THROW 50008, N'No hay estado de cuenta abierto para esa fecha.', 1;

        IF @accion = 'Credito'
            SET @nuevoSaldo = @saldoActual + @inMonto;
        ELSE IF @accion = 'Debito'
            SET @nuevoSaldo = @saldoActual - @inMonto;
        ELSE
            THROW 50010, N'Accion de movimiento no valida.', 1;

        -- Los cargos internos se cobran incluso sin fondos; debitos ordinarios no.
        IF @accion = 'Debito'
           AND @nuevoSaldo < 0
           AND @inNombreTipoMovimiento NOT IN
              ('Comision Exceso Ventana', 'Comision Exceso ATM',
               'Comision Sinpe', 'Cargo Servicio Mensual',
               'Multa Saldo Minimo', 'Debito por Ajuste')
            THROW 50011, N'Saldo insuficiente para realizar el movimiento.', 1;

        -- Recibir un comprobante requiere email valido en el modelo de datos.
        IF @generaComprobante = 1
        BEGIN
            SELECT @emailDestino = P.Email
            FROM dbo.Cuenta AS C
            INNER JOIN dbo.Persona AS P ON P.Id = C.IdPersona
            WHERE C.Id = @idCuenta;

            IF NULLIF(LTRIM(RTRIM(@emailDestino)), '') IS NULL
                THROW 50012, N'La cuenta no tiene un email de destino valido.', 1;
        END;

        IF @inNombreTipoMovimiento = 'Retiro Sinpe'
        BEGIN
            SET @esRetiroSinpe = 1;

            SELECT @limiteSinpe = T.MontoMaxSinpeDiario,
                   @comisionSinpe = T.ComisionSinpe
            FROM dbo.Cuenta AS C
            INNER JOIN dbo.TipoCuentaAhorro AS T ON T.Id = C.IdTipoCuentaAhorro
            WHERE C.Id = @idCuenta;

            IF @limiteSinpe IS NULL OR @comisionSinpe IS NULL
                THROW 50013, N'Configuracion SINPE incompleta para el tipo de cuenta.', 1;

            SELECT @montoEnviadoHoy = COALESCE(SUM(CONVERT(DECIMAL(38,2), M.Monto)), 0)
            FROM dbo.Movimiento AS M
            WHERE M.IdCuenta = @idCuenta
              AND M.Fecha = @inFecha
              AND M.IdTipoMovimiento = @idTipoMovimiento;

            IF @montoEnviadoHoy + @inMonto > @limiteSinpe AND @comisionSinpe > 0
            BEGIN
                SELECT @idTipoComision = Id, @comisionAccion = Accion
                FROM dbo.TipoMovimiento
                WHERE Nombre = 'Comision Sinpe';

                IF @idTipoComision IS NULL OR @comisionAccion <> 'Debito'
                    THROW 50014, N'Falta configurar el movimiento Comision Sinpe como debito.', 1;
            END;
        END;

        UPDATE dbo.Cuenta
        SET Saldo = @nuevoSaldo
        WHERE Id = @idCuenta;

        UPDATE dbo.EstadoCuenta
        SET SaldoFinal = @nuevoSaldo,
            SaldoMinimo = CASE
                WHEN COALESCE(SaldoMinimo, SaldoInicial) < @nuevoSaldo
                    THEN COALESCE(SaldoMinimo, SaldoInicial)
                ELSE @nuevoSaldo
            END,
            CantOpATM = CantOpATM + CASE WHEN @inNombreTipoMovimiento IN ('Deposito ATM', 'Retiro ATM') THEN 1 ELSE 0 END,
            CantOpHumano = CantOpHumano + CASE WHEN @inNombreTipoMovimiento IN ('Deposito Ventana', 'Retiro Ventana') THEN 1 ELSE 0 END,
            CantOpSinpe = CantOpSinpe + CASE WHEN @inNombreTipoMovimiento IN ('Deposito Sinpe', 'Retiro Sinpe') THEN 1 ELSE 0 END
        WHERE Id = @idEstadoCuenta;

        INSERT INTO dbo.Movimiento
            (IdCuenta, IdEstadoCuenta, IdTipoMovimiento, Fecha, Monto, Descripcion, NuevoSaldo)
        VALUES
            (@idCuenta, @idEstadoCuenta, @idTipoMovimiento, @inFecha, @inMonto, @inDescripcion, @nuevoSaldo);

        SET @idMovimiento = CONVERT(BIGINT, SCOPE_IDENTITY());

        IF @generaComprobante = 1
            INSERT INTO dbo.Comprobante (IdMovimiento, EmailDestino, Asunto, Fecha)
            VALUES (@idMovimiento, @emailDestino,
                    LEFT(CONCAT(N'Comprobante: ', @inNombreTipoMovimiento), 200), @inFecha);

        -- Un retiro SINPE que excede el acumulado diario produce dos movimientos.
        IF @esRetiroSinpe = 1 AND @idTipoComision IS NOT NULL
        BEGIN
            SET @saldoTrasComision = @nuevoSaldo - @comisionSinpe;

            UPDATE dbo.Cuenta
            SET Saldo = @saldoTrasComision
            WHERE Id = @idCuenta;

            UPDATE dbo.EstadoCuenta
            SET SaldoFinal = @saldoTrasComision,
                SaldoMinimo = CASE WHEN SaldoMinimo < @saldoTrasComision THEN SaldoMinimo
                                  ELSE @saldoTrasComision END
            WHERE Id = @idEstadoCuenta;

            INSERT INTO dbo.Movimiento
                (IdCuenta, IdEstadoCuenta, IdTipoMovimiento, Fecha, Monto, Descripcion, NuevoSaldo)
            VALUES
                (@idCuenta, @idEstadoCuenta, @idTipoComision, @inFecha, @comisionSinpe,
                 N'Comision por exceder limite diario de envio SINPE', @saldoTrasComision);
        END;

        IF @transaccionPropia = 1 COMMIT TRANSACTION;
        SET @outResultCode = 0;
        SET @outMensaje = CASE WHEN @idTipoComision IS NOT NULL
            THEN N'Movimiento aplicado y comision SINPE registrada.'
            ELSE N'Movimiento aplicado correctamente.' END;
    END TRY
    BEGIN CATCH
        IF @transaccionPropia = 1 AND XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        SET @outResultCode = ERROR_NUMBER();
        SET @outMensaje = LEFT(ERROR_MESSAGE(), 400);
    END CATCH;
END;
GO
