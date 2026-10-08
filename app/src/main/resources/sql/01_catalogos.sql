-- TP2 - Creacion de tablas de catalogos

CREATE TABLE dbo.TipoDocuIdentidad (
    Id INT NOT NULL PRIMARY KEY,
    Nombre NVARCHAR(64) NOT NULL
);

CREATE TABLE dbo.TipoMoneda (
    Id INT NOT NULL PRIMARY KEY,
    Nombre NVARCHAR(32) NOT NULL,
    Simbolo NVARCHAR(5) NOT NULL
);

CREATE TABLE dbo.Parentezco (
    Id INT NOT NULL PRIMARY KEY,
    Nombre NVARCHAR(32) NOT NULL
);


CREATE TABLE dbo.TipoCuentaAhorro (
    Id INT NOT NULL PRIMARY KEY,
    Nombre NVARCHAR(64) NOT NULL,
    IdTipoMoneda INT NOT NULL,

    SaldoMinimo DECIMAL(18,2) NOT NULL,
    MultaSaldoMin DECIMAL(18,2) NOT NULL,
    CargoMensual DECIMAL(18,2) NOT NULL,

    NumRetirosHumano INT NOT NULL,
    NumRetirosAutomatico INT NOT NULL,

    ComisionHumano DECIMAL(18,2) NOT NULL,
    ComisionAutomatico DECIMAL(18,2) NOT NULL,

    MontoMaximoDiarioSinpeSinComision
        DECIMAL(18,2) NOT NULL,

    ComisionSinpeExcedente
        DECIMAL(18,2) NOT NULL,

    InteresMensual DECIMAL(9,4) NOT NULL,

    CONSTRAINT FK_TipoCuentaAhorro_TipoMoneda
        FOREIGN KEY (IdTipoMoneda)
        REFERENCES dbo.TipoMoneda(Id)
);

