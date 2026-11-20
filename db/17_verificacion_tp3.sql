USE AhorrosDB;
GO
SET NOCOUNT ON;

/*
 Verificacion TP3. Devuelve filas de error; si cada consulta retorna 0 filas,
 las reglas verificadas pasan.
*/

-- 1) El saldo actual de Cuenta debe coincidir con SaldoFinal del estado abierto.
SELECT C.Id, C.NumeroCuenta, C.Saldo, E.SaldoFinal
FROM dbo.Cuenta C
JOIN dbo.EstadoCuenta E ON E.IdCuenta = C.Id AND E.FlagCerrado = 0
WHERE C.Saldo <> E.SaldoFinal;

-- 2) El saldo final de cada estado cerrado debe ser el saldo inicial mas
--    creditos menos debitos, respetando el signo del catalogo.
SELECT E.Id, E.IdCuenta, E.SaldoInicial, E.SaldoFinal,
       E.SaldoInicial + COALESCE(SUM(CASE WHEN TM.Accion = 'Credito' THEN M.Monto ELSE -M.Monto END), 0) AS SaldoCalculado
FROM dbo.EstadoCuenta E
LEFT JOIN dbo.Movimiento M ON M.IdEstadoCuenta = E.Id
LEFT JOIN dbo.TipoMovimiento TM ON TM.Id = M.IdTipoMovimiento
WHERE E.FlagCerrado = 1
GROUP BY E.Id, E.IdCuenta, E.SaldoInicial, E.SaldoFinal
HAVING E.SaldoFinal <> E.SaldoInicial + COALESCE(SUM(CASE WHEN TM.Accion = 'Credito' THEN M.Monto ELSE -M.Monto END), 0);

-- 3) Contador ATM = depositos ATM + retiros ATM.
SELECT E.Id,
       E.CantOpATM,
       COALESCE(SUM(CASE WHEN TM.Nombre IN ('Deposito ATM','Retiro ATM') THEN 1 ELSE 0 END), 0) AS ContadorCalculado
FROM dbo.EstadoCuenta E
LEFT JOIN dbo.Movimiento M ON M.IdEstadoCuenta = E.Id
LEFT JOIN dbo.TipoMovimiento TM ON TM.Id = M.IdTipoMovimiento
GROUP BY E.Id, E.CantOpATM
HAVING E.CantOpATM <> COALESCE(SUM(CASE WHEN TM.Nombre IN ('Deposito ATM','Retiro ATM') THEN 1 ELSE 0 END), 0);

-- 4) Contador cajero humano = depositos + retiros en ventana.
SELECT E.Id,
       E.CantOpHumano,
       COALESCE(SUM(CASE WHEN TM.Nombre IN ('Deposito Ventana','Retiro Ventana') THEN 1 ELSE 0 END), 0) AS ContadorCalculado
FROM dbo.EstadoCuenta E
LEFT JOIN dbo.Movimiento M ON M.IdEstadoCuenta = E.Id
LEFT JOIN dbo.TipoMovimiento TM ON TM.Id = M.IdTipoMovimiento
GROUP BY E.Id, E.CantOpHumano
HAVING E.CantOpHumano <> COALESCE(SUM(CASE WHEN TM.Nombre IN ('Deposito Ventana','Retiro Ventana') THEN 1 ELSE 0 END), 0);

-- 5) Contador SINPE = depositos + retiros SINPE.
SELECT E.Id,
       E.CantOpSinpe,
       COALESCE(SUM(CASE WHEN TM.Nombre IN ('Deposito Sinpe','Retiro Sinpe') THEN 1 ELSE 0 END), 0) AS ContadorCalculado
FROM dbo.EstadoCuenta E
LEFT JOIN dbo.Movimiento M ON M.IdEstadoCuenta = E.Id
LEFT JOIN dbo.TipoMovimiento TM ON TM.Id = M.IdTipoMovimiento
GROUP BY E.Id, E.CantOpSinpe
HAVING E.CantOpSinpe <> COALESCE(SUM(CASE WHEN TM.Nombre IN ('Deposito Sinpe','Retiro Sinpe') THEN 1 ELSE 0 END), 0);

-- 6) Unicidad: maximo un estado abierto por cuenta.
SELECT IdCuenta, COUNT(*) AS Abiertos
FROM dbo.EstadoCuenta
WHERE FlagCerrado = 0
GROUP BY IdCuenta
HAVING COUNT(*) > 1;

-- 7) Todas las fechas de simulacion deben estar terminadas al finalizar.
SELECT Fecha
FROM dbo.SimFecha
WHERE FlagTerminada = 0;
GO
