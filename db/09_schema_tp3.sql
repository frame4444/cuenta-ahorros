-- =====================================================================
-- TP3 - Cambios de esquema sobre la base de la TP2 + trigger del primer
-- estado de cuenta.
-- Correr DESPUES de 01..08. Pensado para una AhorrosDB limpia: BORRA y
-- recrea dbo.EstadoCuenta (los datos de la TP2 no sirven; la TP3 genera
-- sus propios estados con la simulacion).
-- =====================================================================
USE AhorrosDB;
GO
SET QUOTED_IDENTIFIER ON;
GO

---------------------------------------------------------------- 1. TipoCuentaAhorro
-- El catalogo nuevo trae la tasa ANUAL (se divide entre 12 al cierre) y el
-- limite/comision Sinpe ya vienen informados.
IF COL_LENGTH('dbo.TipoCuentaAhorro', 'TasaInteresMensual') IS NOT NULL
    EXEC sp_rename 'dbo.TipoCuentaAhorro.TasaInteresMensual', 'TasaInteresAnual', 'COLUMN';
IF COL_LENGTH('dbo.TipoCuentaAhorro', 'MontoMaxSinpeSinComision') IS NOT NULL
    EXEC sp_rename 'dbo.TipoCuentaAhorro.MontoMaxSinpeSinComision', 'MontoMaxSinpeDiario', 'COLUMN';
GO

---------------------------------------------------------------- 2. TipoMovimiento (catalogo nuevo)
IF OBJECT_ID('dbo.TipoMovimiento', 'U') IS NULL
CREATE TABLE dbo.TipoMovimiento (          -- llaves tal cual vienen en el XML
    Id                  INT         NOT NULL PRIMARY KEY,
    Nombre              VARCHAR(64) NOT NULL,
    Accion              VARCHAR(8)  NOT NULL
        CONSTRAINT CK_TipoMovimiento_Accion CHECK (Accion IN ('Credito', 'Debito')),
    FlagGeneraComprobante BIT       NOT NULL,
    CONSTRAINT UQ_TipoMovimiento_Nombre UNIQUE (Nombre)   -- el XML de operaciones lo referencia por nombre
);
GO

---------------------------------------------------------------- 3. EstadoCuenta (recreado)
IF OBJECT_ID('dbo.EstadoCuenta', 'U') IS NOT NULL
    DROP TABLE dbo.EstadoCuenta;
GO
CREATE TABLE dbo.EstadoCuenta (
    Id             INT IDENTITY(1,1) PRIMARY KEY,
    IdCuenta       INT           NOT NULL REFERENCES dbo.Cuenta(Id),
    FechaInicio    DATE          NOT NULL,
    FechaFin       DATE          NOT NULL,      -- dia de cierre (inclusive)
    SaldoInicial   DECIMAL(18,2) NOT NULL,
    SaldoMinimo    DECIMAL(18,2) NULL,          -- NULL hasta el primer movimiento del primer estado
    SaldoFinal     DECIMAL(18,2) NOT NULL,      -- saldo corriente mientras esta abierto
    CantOpATM      INT           NOT NULL DEFAULT 0,
    CantOpHumano   INT           NOT NULL DEFAULT 0,
    CantOpSinpe    INT           NOT NULL DEFAULT 0,
    FlagCerrado    BIT           NOT NULL DEFAULT 0,
    CONSTRAINT CK_EstadoCuenta_Fechas CHECK (FechaFin > FechaInicio)
);
GO
-- Portal: estados de una cuenta, del mas reciente al mas antiguo
CREATE INDEX IX_EstadoCuenta_Cuenta_Fin ON dbo.EstadoCuenta (IdCuenta, FechaFin DESC);
-- Maximo UN estado abierto por cuenta
CREATE UNIQUE INDEX UX_EstadoCuenta_Abierto ON dbo.EstadoCuenta (IdCuenta) WHERE FlagCerrado = 0;
-- Cierre diario: "estados abiertos que vencen hoy"
CREATE INDEX IX_EstadoCuenta_Cierre ON dbo.EstadoCuenta (FechaFin) WHERE FlagCerrado = 0;
GO

---------------------------------------------------------------- 4. Movimiento y Comprobante
IF OBJECT_ID('dbo.Movimiento', 'U') IS NULL
CREATE TABLE dbo.Movimiento (
    Id               BIGINT IDENTITY(1,1) PRIMARY KEY,
    IdCuenta         INT           NOT NULL REFERENCES dbo.Cuenta(Id),
    IdEstadoCuenta   INT           NOT NULL REFERENCES dbo.EstadoCuenta(Id),
    IdTipoMovimiento INT           NOT NULL REFERENCES dbo.TipoMovimiento(Id),
    Fecha            DATE          NOT NULL,
    Monto            DECIMAL(18,2) NOT NULL CHECK (Monto > 0),   -- siempre positivo; el signo lo da TipoMovimiento.Accion
    Descripcion      NVARCHAR(200) NOT NULL,
    NuevoSaldo       DECIMAL(18,2) NOT NULL
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Movimiento_Estado'
               AND object_id = OBJECT_ID('dbo.Movimiento'))
    CREATE INDEX IX_Movimiento_Estado ON dbo.Movimiento (IdEstadoCuenta, Id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Movimiento_Cuenta_Fecha'
               AND object_id = OBJECT_ID('dbo.Movimiento'))
    CREATE INDEX IX_Movimiento_Cuenta_Fecha ON dbo.Movimiento (IdCuenta, Fecha, IdTipoMovimiento);
GO

-- "Cola de correos": un registro por movimiento cuyo tipo tiene FlagGeneraComprobante = 1
IF OBJECT_ID('dbo.Comprobante', 'U') IS NULL
CREATE TABLE dbo.Comprobante (
    Id           BIGINT IDENTITY(1,1) PRIMARY KEY,
    IdMovimiento BIGINT        NOT NULL REFERENCES dbo.Movimiento(Id),
    EmailDestino VARCHAR(128)  NOT NULL,     -- email del dueno de la cuenta
    Asunto       NVARCHAR(200) NOT NULL,
    Fecha        DATE          NOT NULL
);
GO

---------------------------------------------------------------- 5. Control de la simulacion
-- El XML se carga COMPLETO a SimOperacion (un renglon por nodo, en orden de documento)
-- y luego se procesa fecha por fecha. Asi el proceso puede reiniciarse desde la ultima
-- PK procesada y nunca corre dos veces el mismo nodo.
IF OBJECT_ID('dbo.SimFecha', 'U') IS NULL
CREATE TABLE dbo.SimFecha (
    Fecha         DATE         NOT NULL PRIMARY KEY,   -- TODAS las fechas consecutivas, haya o no nodos
    FlagTerminada BIT          NOT NULL DEFAULT 0,
    FechaHoraFin  DATETIME2(0) NULL
);
GO
IF OBJECT_ID('dbo.SimOperacion', 'U') IS NULL
CREATE TABLE dbo.SimOperacion (
    Id           INT IDENTITY(1,1) PRIMARY KEY,         -- orden de procesamiento
    Fecha        DATE         NOT NULL REFERENCES dbo.SimFecha(Fecha),
    TipoNodo     VARCHAR(20)  NOT NULL,                 -- Persona, Cuenta, Beneficiario, Usuario, UsuarioPuedeVer, Movimientos
    Nodo         XML          NOT NULL,
    FlagProcesado BIT         NOT NULL DEFAULT 0
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_SimOperacion_Pendientes'
               AND object_id = OBJECT_ID('dbo.SimOperacion'))
    CREATE INDEX IX_SimOperacion_Pendientes ON dbo.SimOperacion (Fecha, Id) WHERE FlagProcesado = 0;
GO

---------------------------------------------------------------- 6. Trigger: primer estado de cuenta
-- Se dispara al insertar la cuenta (tambien con inserts de varias filas).
-- El primer estado va de la fecha de creacion a "un mes despues"; DATEADD ya
-- recorta a fin de mes (31-mar -> 30-abr). Los estados siguientes los abre el SP
-- de cierre.
CREATE OR ALTER TRIGGER dbo.trg_Cuenta_AbrirPrimerEstado
ON dbo.Cuenta
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT dbo.EstadoCuenta (IdCuenta, FechaInicio, FechaFin, SaldoInicial, SaldoMinimo, SaldoFinal)
    SELECT I.Id, I.FechaCreacion, DATEADD(MONTH, 1, I.FechaCreacion), I.Saldo, NULL, I.Saldo
    FROM inserted I;
END;
GO
