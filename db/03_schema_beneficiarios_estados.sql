-- =====================================================================
-- Parentezco y Beneficiario (EstadoCuenta vive en 09_schema_tp3.sql)
-- Correr DESPUES de 01_schema_auth.sql. Re-ejecutable: cada objeto se
-- crea solo si todavía no existe.
-- =====================================================================
USE AhorrosDB;
GO
-- Necesario para índices filtrados y métodos XML; sqlcmd lo trae en OFF por defecto
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('dbo.Parentezco', 'U') IS NULL
CREATE TABLE dbo.Parentezco (            -- catálogo: sin IDENTITY
    Id     INT         NOT NULL PRIMARY KEY,
    Nombre VARCHAR(32) NOT NULL
);
GO

IF OBJECT_ID('dbo.Beneficiario', 'U') IS NULL
CREATE TABLE dbo.Beneficiario (
    Id                 INT IDENTITY(1,1) PRIMARY KEY,
    IdCuenta           INT  NOT NULL REFERENCES dbo.Cuenta(Id),
    IdPersona          INT  NOT NULL REFERENCES dbo.Persona(Id),
    IdParentezco       INT  NOT NULL REFERENCES dbo.Parentezco(Id),
    Porcentaje         INT  NOT NULL
        CONSTRAINT CK_Beneficiario_Porcentaje CHECK (Porcentaje BETWEEN 0 AND 100),
    FlagActivo         BIT  NOT NULL DEFAULT 1,   -- borrado lógico
    FechaDesactivacion DATE NULL
);
GO

-- Una persona no puede estar dos veces ACTIVA como beneficiaria de la misma cuenta
IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = 'UX_Beneficiario_Activo'
                 AND object_id = OBJECT_ID('dbo.Beneficiario'))
CREATE UNIQUE INDEX UX_Beneficiario_Activo
    ON dbo.Beneficiario (IdCuenta, IdPersona) WHERE FlagActivo = 1;
GO

-- EstadoCuenta (TP3) se crea en 09_schema_tp3.sql
