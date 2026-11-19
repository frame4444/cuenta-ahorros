-- =====================================================================
-- TP3 - Carga de catalogos (version TP3) y carga del XML de operaciones
-- a las tablas de control SimFecha / SimOperacion.
-- Correr DESPUES de 09_schema_tp3.sql. Reemplaza sp_CargarCatalogos de la TP2.
-- sp_CargarDatos (TP2) ya no se usa: en la TP3 las personas, cuentas,
-- beneficiarios y usuarios entran dia por dia desde la simulacion.
-- Codigos (@outResultCode): 0 OK | 50008 error (detalle en @outMensaje).
-- =====================================================================
USE AhorrosDB;
GO
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
        DECLARE @nDoc INT, @nMon INT, @nPar INT, @nCta INT, @nMov INT, @nOp INT;

        BEGIN TRANSACTION;

        INSERT dbo.TipoDocuIdentidad (Id, Nombre)
        SELECT T.n.value('@Id', 'INT'), T.n.value('@Nombre', 'VARCHAR(64)')
        FROM @x.nodes('//TipoDocuIdentidad') AS T(n)
        WHERE NOT EXISTS (SELECT 1 FROM dbo.TipoDocuIdentidad D
                          WHERE D.Id = T.n.value('@Id', 'INT'));
        SET @nDoc = @@ROWCOUNT;

        INSERT dbo.TipoMoneda (Id, Nombre, Simbolo)
        SELECT T.n.value('@Id', 'INT'), T.n.value('@Nombre', 'VARCHAR(32)'),
               T.n.value('@Simbolo', 'NVARCHAR(4)')
        FROM @x.nodes('//TipoMoneda') AS T(n)
        WHERE NOT EXISTS (SELECT 1 FROM dbo.TipoMoneda M
                          WHERE M.Id = T.n.value('@Id', 'INT'));
        SET @nMon = @@ROWCOUNT;

        INSERT dbo.Parentezco (Id, Nombre)
        SELECT T.n.value('@Id', 'INT'), T.n.value('@Nombre', 'VARCHAR(32)')
        FROM @x.nodes('//Parentezco') AS T(n)
        WHERE NOT EXISTS (SELECT 1 FROM dbo.Parentezco P
                          WHERE P.Id = T.n.value('@Id', 'INT'));
        SET @nPar = @@ROWCOUNT;

        -- TP3: tasa ANUAL (en %), cargo mensual, limite y comision Sinpe
        INSERT dbo.TipoCuentaAhorro
            (Id, Nombre, IdTipoMoneda, SaldoMinimo, MultaSaldoMin, CargoServicio,
             NumRetirosHumano, NumRetirosAutomatico, ComisionHumano, ComisionAutomatico,
             MontoMaxSinpeDiario, ComisionSinpe, TasaInteresAnual)
        SELECT T.n.value('@Id', 'INT'),
               T.n.value('@Nombre', 'VARCHAR(64)'),
               T.n.value('@IdTipoMoneda', 'INT'),
               T.n.value('@SaldoMinimo', 'DECIMAL(18,2)'),
               T.n.value('@MultaSaldoMin', 'DECIMAL(18,2)'),
               T.n.value('@CargoMensual', 'DECIMAL(18,2)'),
               T.n.value('@NumRetirosHumano', 'INT'),
               T.n.value('@NumRetirosAutomatico', 'INT'),
               T.n.value('@ComisionHumano', 'DECIMAL(18,2)'),
               T.n.value('@ComisionAutomatico', 'DECIMAL(18,2)'),
               T.n.value('@MontoMaxSinpeDiario', 'DECIMAL(18,2)'),
               T.n.value('@ComisionSinpe', 'DECIMAL(18,2)'),
               T.n.value('@TasaInteresAnual', 'DECIMAL(9,4)')
        FROM @x.nodes('//TipoCuentaAhorro') AS T(n)
        WHERE NOT EXISTS (SELECT 1 FROM dbo.TipoCuentaAhorro C
                          WHERE C.Id = T.n.value('@Id', 'INT'));
        SET @nCta = @@ROWCOUNT;

        INSERT dbo.TipoMovimiento (Id, Nombre, Accion, FlagGeneraComprobante)
        SELECT T.n.value('@Id', 'INT'),
               T.n.value('@Nombre', 'VARCHAR(64)'),
               T.n.value('@Accion', 'VARCHAR(8)'),
               T.n.value('@flagGeneraComprobante', 'BIT')
        FROM @x.nodes('//TipoMovimiento') AS T(n)
        WHERE NOT EXISTS (SELECT 1 FROM dbo.TipoMovimiento M
                          WHERE M.Id = T.n.value('@Id', 'INT'));
        SET @nMov = @@ROWCOUNT;

        INSERT dbo.TipoOperacionBitacora (Id, Nombre)
        SELECT T.n.value('@Id', 'INT'), T.n.value('@Nombre', 'VARCHAR(64)')
        FROM @x.nodes('//TipoOperacion') AS T(n)
        WHERE NOT EXISTS (SELECT 1 FROM dbo.TipoOperacionBitacora O
                          WHERE O.Id = T.n.value('@Id', 'INT'));
        SET @nOp = @@ROWCOUNT;

        COMMIT TRANSACTION;

        SET @outMensaje = CONCAT('Catalogos nuevos: TipoDocu=', @nDoc, ' Moneda=', @nMon,
                                 ' Parentezco=', @nPar, ' TipoCuenta=', @nCta,
                                 ' TipoMovimiento=', @nMov, ' TipoOperacion=', @nOp);
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        SET @outResultCode = 50008;
        SET @outMensaje = LEFT(ERROR_MESSAGE(), 400);
    END CATCH
END;
GO

-- ---------------------------------------------------------------------
-- Carga del XML de operaciones a SimFecha (todas las fechas consecutivas)
-- y SimOperacion (un renglon por nodo hijo de cada FechaOperacion).
-- Es re-ejecutable: si ya hay nodos cargados no vuelve a cargar nada.
-- El Id (IDENTITY) de SimOperacion respeta el orden de documento dentro de
-- cada fecha: eso garantiza que los movimientos se apliquen en el orden del XML.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_CargarSimulacion
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
        IF EXISTS (SELECT 1 FROM dbo.SimOperacion)
        BEGIN
            SET @outMensaje = N'La simulacion ya estaba cargada; no se cargo nada.';
            RETURN;
        END;

        DECLARE @x XML = CAST(@inXml AS XML);
        DECLARE @min DATE, @max DATE, @nFechas INT, @nNodos INT;

        SELECT @min = MIN(F.Fecha), @max = MAX(F.Fecha)
        FROM (SELECT T.n.value('@Fecha', 'DATE') AS Fecha
              FROM @x.nodes('/Operaciones/FechaOperacion') AS T(n)) F;

        IF @min IS NULL
        BEGIN
            SET @outResultCode = 50008;
            SET @outMensaje = N'El XML no trae nodos FechaOperacion.';
            RETURN;
        END;

        BEGIN TRANSACTION;

        -- Todas las fechas del rango, aunque el XML no traiga datos para alguna
        ;WITH D AS (
            SELECT @min AS Fecha
            UNION ALL
            SELECT DATEADD(DAY, 1, Fecha) FROM D WHERE Fecha < @max
        )
        INSERT dbo.SimFecha (Fecha)
        SELECT Fecha FROM D
        OPTION (MAXRECURSION 0);
        SET @nFechas = @@ROWCOUNT;

        -- Un renglon por nodo; el ORDER BY fija el orden en que se asigna el IDENTITY.
        -- count(preceding-sibling::*) = posicion del nodo dentro de su FechaOperacion.
        INSERT dbo.SimOperacion (Fecha, TipoNodo, Nodo)
        SELECT F.n.value('@Fecha', 'DATE'),
               C.n.value('local-name(.)', 'VARCHAR(20)'),
               C.n.query('.')
        FROM @x.nodes('/Operaciones/FechaOperacion') AS F(n)
        CROSS APPLY F.n.nodes('*') AS C(n)
        ORDER BY F.n.value('@Fecha', 'DATE'),
                 C.n.value('count(preceding-sibling::*)', 'INT');
        SET @nNodos = @@ROWCOUNT;

        COMMIT TRANSACTION;

        SET @outMensaje = CONCAT('Simulacion cargada: fechas=', @nFechas, ' nodos=', @nNodos);
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        SET @outResultCode = 50008;
        SET @outMensaje = LEFT(ERROR_MESSAGE(), 400);
    END CATCH
END;
GO
