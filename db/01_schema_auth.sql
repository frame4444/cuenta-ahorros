-- =====================================================================
-- TP2 - Esquema base: catálogos + tablas necesarias para autenticación
-- Ejecutar contra AhorrosDB.
-- NOTA: TipoCuentaAhorro sigue el texto del enunciado; ajustar cuando
-- se tenga el catalogos.xml real.
-- =====================================================================
USE AhorrosDB;
GO
-- Necesario para índices filtrados y métodos XML; sqlcmd lo trae en OFF por defecto
SET QUOTED_IDENTIFIER ON;
GO

------------------------------------------------------------------ Catálogos
-- Llaves tal cual vienen en el XML: sin IDENTITY.
CREATE TABLE dbo.TipoDocuIdentidad (
    Id     INT         NOT NULL PRIMARY KEY,
    Nombre VARCHAR(64) NOT NULL
);

CREATE TABLE dbo.TipoMoneda (
    Id      INT         NOT NULL PRIMARY KEY,
    Nombre  VARCHAR(32) NOT NULL,
    Simbolo NVARCHAR(4) NOT NULL
);

CREATE TABLE dbo.TipoCuentaAhorro (
    Id                           INT           NOT NULL PRIMARY KEY,
    Nombre                       VARCHAR(64)   NOT NULL,
    IdTipoMoneda                 INT           NOT NULL REFERENCES dbo.TipoMoneda(Id),
    SaldoMinimo                  DECIMAL(18,2) NOT NULL,
    MultaSaldoMin                DECIMAL(18,2) NOT NULL,
    CargoServicio                DECIMAL(18,2) NOT NULL,
    NumRetirosHumano             INT           NOT NULL,
    NumRetirosAutomatico         INT           NOT NULL,
    ComisionHumano               DECIMAL(18,2) NOT NULL,
    ComisionAutomatico           DECIMAL(18,2) NOT NULL,
    MontoMaxSinpeSinComision     DECIMAL(18,2) NULL,  -- no viene en el XML de ejemplo
    ComisionSinpe                DECIMAL(18,2) NULL,  -- no viene en el XML de ejemplo
    TasaInteresMensual           DECIMAL(9,4)  NOT NULL
);

CREATE TABLE dbo.TipoOperacionBitacora (
    Id     INT          NOT NULL PRIMARY KEY,
    Nombre VARCHAR(64)  NOT NULL
);

-------------------------------------------------------------- No-catálogos
CREATE TABLE dbo.Persona (
    Id                      INT IDENTITY(1,1) PRIMARY KEY,
    IdTipoDocuIdentidad     INT          NOT NULL REFERENCES dbo.TipoDocuIdentidad(Id),
    ValorDocumentoIdentidad VARCHAR(32)  NOT NULL,
    Nombre                  VARCHAR(64)  NOT NULL,
    FechaNacimiento         DATE         NOT NULL,
    Email                   VARCHAR(128) NOT NULL,
    Telefono1               VARCHAR(16)  NOT NULL,
    Telefono2               VARCHAR(16)  NOT NULL,
    CONSTRAINT UQ_Persona_Documento UNIQUE (ValorDocumentoIdentidad)   -- llave alterna
);

CREATE TABLE dbo.Cuenta (
    Id                  INT IDENTITY(1,1) PRIMARY KEY,
    NumeroCuenta        VARCHAR(16)   NOT NULL,
    IdPersona           INT           NOT NULL REFERENCES dbo.Persona(Id),   -- dueño
    IdTipoCuentaAhorro  INT           NOT NULL REFERENCES dbo.TipoCuentaAhorro(Id),
    FechaCreacion       DATE          NOT NULL,
    Saldo               DECIMAL(18,2) NOT NULL,
    CONSTRAINT UQ_Cuenta_Numero UNIQUE (NumeroCuenta)                      -- llave alterna
);

CREATE TABLE dbo.Usuario (
    Id              INT IDENTITY(1,1) PRIMARY KEY,
    Username        VARCHAR(64)      NOT NULL,
    Salt            UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
    PasswordHash    VARBINARY(32)    NOT NULL,   -- SHA2_256(Salt + Pass), lo calcula el SP de carga
    EsAdministrador BIT              NOT NULL DEFAULT 0,
    IdPersona       INT              NOT NULL REFERENCES dbo.Persona(Id),
    FlagActivo      BIT              NOT NULL DEFAULT 1,
    CONSTRAINT UQ_Usuario_Username UNIQUE (Username)                       -- llave alterna
);

-- Qué cuentas puede acceder cada usuario cliente (el admin ve todas)
CREATE TABLE dbo.UsuarioPuedeVerCuenta (
    IdUsuario INT NOT NULL REFERENCES dbo.Usuario(Id),
    IdCuenta  INT NOT NULL REFERENCES dbo.Cuenta(Id),
    PRIMARY KEY (IdUsuario, IdCuenta)
);

CREATE TABLE dbo.Bitacora (
    Id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    IdUsuario       INT           NOT NULL REFERENCES dbo.Usuario(Id),
    IdTipoOperacion INT           NOT NULL REFERENCES dbo.TipoOperacionBitacora(Id),
    IP              VARCHAR(45)   NULL,            -- solo en login
    JsonAntes       NVARCHAR(MAX) NULL,            -- solo en cambios de beneficiarios
    JsonDespues     NVARCHAR(MAX) NULL,
    FechaHora       DATETIME2(0)  NOT NULL DEFAULT SYSDATETIME()
);
CREATE INDEX IX_Bitacora_Usuario_Fecha ON dbo.Bitacora (IdUsuario, FechaHora);
GO
