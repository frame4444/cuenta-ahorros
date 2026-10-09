-- =====================================================================
-- TP2 - Catalogos para los formularios (parentescos y tipos de documento)
-- =====================================================================
USE AhorrosDB;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ListarParentezcos
AS
BEGIN
    SET NOCOUNT ON;
    SELECT P.Id, P.Nombre
    FROM dbo.Parentezco P
    ORDER BY P.Id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ListarTiposDocumento
AS
BEGIN
    SET NOCOUNT ON;
    SELECT T.Id, T.Nombre
    FROM dbo.TipoDocuIdentidad T
    ORDER BY T.Id;
END;
GO
