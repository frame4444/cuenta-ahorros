-- TP2 - Tablas principales

CREATE TABLE dbo.Persona (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    IdTipoDocuIdentidad INT NOT NULL,
    ValorDocumentoIdentidad NVARCHAR(32) NOT NULL,
    Nombre NVARCHAR(64) NOT NULL,
    FechaNacimiento DATE NOT NULL,
    Email NVARCHAR(254) NOT NULL,
    Telefono1 NVARCHAR(20) NOT NULL,
    Telefono2 NVARCHAR(20) NOT NULL,

    CONSTRAINT UQ_Persona_Documento
        UNIQUE (IdTipoDocuIdentidad, ValorDocumentoIdentidad),

    CONSTRAINT FK_Persona_TipoDoc
        FOREIGN KEY (IdTipoDocuIdentidad)
        REFERENCES dbo.TipoDocuIdentidad(Id)
);

CREATE TABLE dbo.Cuenta (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    IdPersona INT NOT NULL,
    IdTipoCuentaAhorro INT NOT NULL,
    NumeroCuenta NVARCHAR(32) NOT NULL UNIQUE,
    FechaCreacion DATE NOT NULL,
    Saldo DECIMAL(18,2) NOT NULL,

    CONSTRAINT FK_Cuenta_Persona
        FOREIGN KEY (IdPersona)
        REFERENCES dbo.Persona(Id),

    CONSTRAINT FK_Cuenta_TipoCuenta
        FOREIGN KEY (IdTipoCuentaAhorro)
        REFERENCES dbo.TipoCuentaAhorro(Id)
);

CREATE TABLE dbo.EstadoCuenta (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    IdCuenta INT NOT NULL,
    FechaInicio DATE NOT NULL,
    FechaFin DATE NOT NULL,
    SaldoInicial DECIMAL(18,2) NOT NULL,
    SaldoMinimo DECIMAL(18,2) NOT NULL,
    SaldoFinal DECIMAL(18,2) NOT NULL,

    CONSTRAINT FK_EstadoCuenta_Cuenta
        FOREIGN KEY (IdCuenta)
        REFERENCES dbo.Cuenta(Id),

    CONSTRAINT CK_EstadoCuenta_Fechas
        CHECK (FechaFin >= FechaInicio)
);
