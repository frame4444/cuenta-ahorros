USE AhorrosDB;
GO
SET QUOTED_IDENTIFIER ON;
GO

/*
 TP3 - Apertura y cierre de estados de cuenta.

 Reglas implementadas:
 - El primer estado lo crea el trigger de 09_schema_tp3.sql.
 - El cierre ocurre cuando FechaFin = @inFecha.
 - Orden del cierre: intereses, comision ATM, comision cajero humano,
   cargo mensual y multa por saldo minimo.
 - La comision se calcula sobre RETIROS, no sobre depositos.
 - SaldoMinimo del periodo se obtiene solo de saldos posteriores a movimientos.
 - El siguiente estado empieza el dia siguiente y termina el dia anterior
   al mismo dia del mes siguiente (1-may -> 31-may; 31-mar -> 30-abr).
*/

CREATE OR ALTER PROCEDURE dbo.sp_AbrirEstadoCuenta
    @inFechaInicio DATE,
    @inIdCuenta INT,
    @inSaldoInicial DECIMAL(18,2),
    @outResultCode INT OUT,
    @outMensaje NVARCHAR(200) OUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @outResultCode = 0;
    SET @outMensaje = N'OK';

    BEGIN TRY
        IF @inFechaInicio IS NULL OR @inIdCuenta IS NULL OR @inSaldoInicial IS NULL
            THROW 50001, N'Parametros incompletos para abrir el estado de cuenta.', 1;

        IF EXISTS (SELECT 1 FROM dbo.EstadoCuenta WHERE IdCuenta = @inIdCuenta AND FlagCerrado = 0)
            THROW 50002, N'La cuenta ya tiene un estado de cuenta abierto.', 1;

        DECLARE @fechaFin DATE = DATEADD(DAY, -1, DATEADD(MONTH, 1, @inFechaInicio));

        INSERT dbo.EstadoCuenta
            (IdCuenta, FechaInicio, FechaFin, SaldoInicial, SaldoMinimo, SaldoFinal, FlagCerrado)
        VALUES
            (@inIdCuenta, @inFechaInicio, @fechaFin, @inSaldoInicial, NULL, @inSaldoInicial, 0);

        SET @outMensaje = N'Estado de cuenta abierto correctamente.';
    END TRY
    BEGIN CATCH
        SET @outResultCode = ERROR_NUMBER();
        SET @outMensaje = LEFT(ERROR_MESSAGE(), 200);
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_CerrarEstadoCuenta
    @inFecha DATE,
    @inIdCuenta INT,
    @outResultCode INT OUT,
    @outMensaje NVARCHAR(200) OUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @outResultCode = 0;
    SET @outMensaje = N'OK';

    DECLARE @idEstado INT, @numeroCuenta VARCHAR(16), @saldoActual DECIMAL(18,2),
            @saldoMinimoPeriodo DECIMAL(18,2), @idTipoCuenta INT,
            @tasaAnual DECIMAL(9,4), @saldoMinimoPermitido DECIMAL(18,2),
            @multaSaldoMin DECIMAL(18,2), @cargoServicio DECIMAL(18,2),
            @maxHumano INT, @maxATM INT, @comisionHumano DECIMAL(18,2),
            @comisionATM DECIMAL(18,2), @retirosHumano INT, @retirosATM INT,
            @interes DECIMAL(18,2), @montoComision DECIMAL(18,2),
            @codigo INT, @mensaje NVARCHAR(200);

    BEGIN TRY
        IF @inFecha IS NULL OR @inIdCuenta IS NULL
            THROW 50001, N'La fecha y la cuenta son obligatorias.', 1;

        BEGIN TRANSACTION;

        SELECT @numeroCuenta = C.NumeroCuenta,
               @saldoActual = C.Saldo,
               @idTipoCuenta = C.IdTipoCuentaAhorro
        FROM dbo.Cuenta C WITH (UPDLOCK, HOLDLOCK)
        WHERE C.Id = @inIdCuenta;

        IF @numeroCuenta IS NULL
            THROW 50002, N'La cuenta no existe.', 1;

        SELECT @idEstado = E.Id,
               @saldoMinimoPeriodo = E.SaldoMinimo
        FROM dbo.EstadoCuenta E WITH (UPDLOCK, HOLDLOCK)
        WHERE E.IdCuenta = @inIdCuenta
          AND E.FechaFin = @inFecha
          AND E.FlagCerrado = 0;

        IF @idEstado IS NULL
            THROW 50003, N'No existe un estado abierto que cierre en la fecha indicada.', 1;

        SELECT @tasaAnual = T.TasaInteresAnual,
               @saldoMinimoPermitido = T.SaldoMinimo,
               @multaSaldoMin = T.MultaSaldoMin,
               @cargoServicio = T.CargoServicio,
               @maxHumano = T.NumRetirosHumano,
               @maxATM = T.NumRetirosAutomatico,
               @comisionHumano = T.ComisionHumano,
               @comisionATM = T.ComisionAutomatico
        FROM dbo.TipoCuentaAhorro T
        WHERE T.Id = @idTipoCuenta;

        IF @tasaAnual IS NULL
            THROW 50004, N'No existe configuracion para el tipo de cuenta.', 1;

        -- Si no hubo movimientos, el saldo minimo no se define por el saldo inicial.
        -- Para el periodo con movimientos, sp_AplicarMovimiento ya lo mantiene.
        IF @saldoMinimoPeriodo IS NULL
            SET @saldoMinimoPeriodo = @saldoActual;

        -- 1. Intereses sobre saldo minimo.
        SET @interes = ROUND(@saldoMinimoPeriodo * (@tasaAnual / 100.0) / 12.0, 2);
        IF @interes > 0
        BEGIN
            EXEC dbo.sp_AplicarMovimiento
                @inFecha = @inFecha,
                @inNumeroCuenta = @numeroCuenta,
                @inNombreTipoMovimiento = 'Intereses Mensuales',
                @inMonto = @interes,
                @inDescripcion = N'Intereses mensuales sobre saldo minimo',
                @outResultCode = @codigo OUTPUT,
                @outMensaje = @mensaje OUTPUT;
            IF @codigo <> 0 THROW 50005, @mensaje, 1;
        END;

        -- Los contadores del estado pueden mostrar depositos y retiros, pero
        -- los limites de comision se calculan exclusivamente con retiros.
        SELECT @retirosATM = COUNT(*)
        FROM dbo.Movimiento M
        INNER JOIN dbo.TipoMovimiento TM ON TM.Id = M.IdTipoMovimiento
        WHERE M.IdEstadoCuenta = @idEstado
          AND M.Fecha >= (SELECT FechaInicio FROM dbo.EstadoCuenta WHERE Id = @idEstado)
          AND M.Fecha <= @inFecha
          AND TM.Nombre = 'Retiro ATM';

        SELECT @retirosHumano = COUNT(*)
        FROM dbo.Movimiento M
        INNER JOIN dbo.TipoMovimiento TM ON TM.Id = M.IdTipoMovimiento
        WHERE M.IdEstadoCuenta = @idEstado
          AND M.Fecha >= (SELECT FechaInicio FROM dbo.EstadoCuenta WHERE Id = @idEstado)
          AND M.Fecha <= @inFecha
          AND TM.Nombre = 'Retiro Ventana';

        -- 2. Comision por exceso ATM.
        IF @retirosATM > @maxATM AND @comisionATM > 0
        BEGIN
            SET @montoComision = (@retirosATM - @maxATM) * @comisionATM;
            EXEC dbo.sp_AplicarMovimiento
                @inFecha = @inFecha,
                @inNumeroCuenta = @numeroCuenta,
                @inNombreTipoMovimiento = 'Comision Exceso ATM',
                @inMonto = @montoComision,
                @inDescripcion = N'Comision por exceso de retiros ATM',
                @outResultCode = @codigo OUTPUT,
                @outMensaje = @mensaje OUTPUT;
            IF @codigo <> 0 THROW 50006, @mensaje, 1;
        END;

        -- 3. Comision por exceso de cajero humano.
        IF @retirosHumano > @maxHumano AND @comisionHumano > 0
        BEGIN
            SET @montoComision = (@retirosHumano - @maxHumano) * @comisionHumano;
            EXEC dbo.sp_AplicarMovimiento
                @inFecha = @inFecha,
                @inNumeroCuenta = @numeroCuenta,
                @inNombreTipoMovimiento = 'Comision Exceso Ventana',
                @inMonto = @montoComision,
                @inDescripcion = N'Comision por exceso de retiros en cajero humano',
                @outResultCode = @codigo OUTPUT,
                @outMensaje = @mensaje OUTPUT;
            IF @codigo <> 0 THROW 50007, @mensaje, 1;
        END;

        -- 4. Cargo mensual.
        IF @cargoServicio > 0
        BEGIN
            EXEC dbo.sp_AplicarMovimiento
                @inFecha = @inFecha,
                @inNumeroCuenta = @numeroCuenta,
                @inNombreTipoMovimiento = 'Cargo Servicio Mensual',
                @inMonto = @cargoServicio,
                @inDescripcion = N'Cargo por servicio mensual',
                @outResultCode = @codigo OUTPUT,
                @outMensaje = @mensaje OUTPUT;
            IF @codigo <> 0 THROW 50008, @mensaje, 1;
        END;

        -- 5. Multa por saldo minimo.
        IF @saldoMinimoPeriodo < @saldoMinimoPermitido AND @multaSaldoMin > 0
        BEGIN
            EXEC dbo.sp_AplicarMovimiento
                @inFecha = @inFecha,
                @inNumeroCuenta = @numeroCuenta,
                @inNombreTipoMovimiento = 'Multa Saldo Minimo',
                @inMonto = @multaSaldoMin,
                @inDescripcion = N'Multa por saldo minimo inferior al permitido',
                @outResultCode = @codigo OUTPUT,
                @outMensaje = @mensaje OUTPUT;
            IF @codigo <> 0 THROW 50009, @mensaje, 1;
        END;

        -- El minimo del periodo no debe contaminarse con cargos de cierre.
        UPDATE dbo.EstadoCuenta
        SET SaldoMinimo = @saldoMinimoPeriodo,
            SaldoFinal = (SELECT Saldo FROM dbo.Cuenta WHERE Id = @inIdCuenta),
            FlagCerrado = 1
        WHERE Id = @idEstado;

        SET @saldoActual = (SELECT Saldo FROM dbo.Cuenta WHERE Id = @inIdCuenta);

        COMMIT TRANSACTION;
        SET @outMensaje = N'Estado de cuenta cerrado correctamente.';
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        SET @outResultCode = ERROR_NUMBER();
        SET @outMensaje = LEFT(ERROR_MESSAGE(), 200);
    END CATCH;
END;
GO

-- Compatibilidad con el nombre usado por la primera versión del avance.
CREATE OR ALTER PROCEDURE dbo.sp_CerrarAbrirEstadosCuenta
    @inFecha DATE,
    @outResultCode INT OUT,
    @outMensaje NVARCHAR(400) OUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;
    SET @outMensaje = NULL;

    DECLARE @idCuenta INT, @codigo INT, @mensaje NVARCHAR(200), @procesadas INT = 0;

    BEGIN TRY
        WHILE 1 = 1
        BEGIN
            SET @idCuenta = NULL;
            SELECT TOP (1) @idCuenta = E.IdCuenta
            FROM dbo.EstadoCuenta E WITH (UPDLOCK, READPAST)
            WHERE E.FechaFin = @inFecha AND E.FlagCerrado = 0
            ORDER BY E.Id;

            IF @idCuenta IS NULL BREAK;

            SET @codigo = 0;
            EXEC dbo.sp_CerrarEstadoCuenta
                @inFecha = @inFecha,
                @inIdCuenta = @idCuenta,
                @outResultCode = @codigo OUTPUT,
                @outMensaje = @mensaje OUTPUT;
            IF @codigo <> 0 THROW 50020, @mensaje, 1;

            DECLARE @saldo DECIMAL(18,2), @fechaInicio DATE;
            SELECT @saldo = C.Saldo FROM dbo.Cuenta C WHERE C.Id = @idCuenta;
            SELECT @fechaInicio = DATEADD(DAY, 1, E.FechaFin)
            FROM dbo.EstadoCuenta E
            WHERE E.IdCuenta = @idCuenta AND E.FechaFin = @inFecha;

            SET @codigo = 0;
            EXEC dbo.sp_AbrirEstadoCuenta
                @inFechaInicio = @fechaInicio,
                @inIdCuenta = @idCuenta,
                @inSaldoInicial = @saldo,
                @outResultCode = @codigo OUTPUT,
                @outMensaje = @mensaje OUTPUT;
            IF @codigo <> 0 THROW 50021, @mensaje, 1;

            SET @procesadas += 1;
            SET @idCuenta = NULL;
        END;

        SET @outMensaje = CONCAT(N'Estados cerrados y abiertos: ', @procesadas, N'.');
    END TRY
    BEGIN CATCH
        SET @outResultCode = ERROR_NUMBER();
        SET @outMensaje = LEFT(ERROR_MESSAGE(), 400);
    END CATCH;
END;
GO
