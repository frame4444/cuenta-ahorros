# TP3 – Cuentas de Ahorro

## Reparto

- **Persona A:** `sp_AplicarMovimiento`, `sp_ProcesarOperacionesDia`, portal de detalle de movimientos y README.
- **Persona B:** `sp_AbrirEstadoCuenta`, `sp_CerrarEstadoCuenta`, `sp_Simulacion`, portal de estados de cuenta y verificación.
- Ambos deben probar los SP del compañero antes de la corrida final.

> En la entrega, reemplazar Persona A / Persona B por los nombres acordados.

## Orden de scripts

1. `01_schema_auth.sql`
2. `02_sp_auth.sql`
3. `03_schema_beneficiarios_estados.sql`
5. `05_sp_beneficiarios.sql`
6. `06_sp_catalogos.sql`
7. `08_sp_cuentas.sql`
8. `08_sp_carga_usuarios_base.sql`
9. `09_schema_tp3.sql`
10. `10_sp_carga_tp3.sql`
11. `11_sp_estados_cuenta.sql`
12. `12_sp_aplicar_movimiento.sql`
13. `13_sp_consultar_movimientos_estado.sql`
14. `14_sp_procesar_operaciones_dia.sql`
15. `15_sp_cerrar_abrir_estados.sql`
16. `16_sp_simulacion.sql`
17. `17_verificacion_tp3.sql`

Los nombres de los scripts de TP2 pueden variar respecto al proyecto base; lo importante es ejecutar primero el esquema y procedimientos de TP2 que crean las tablas referenciadas por TP3.

## Carga de catálogos y XML

El procedimiento `sp_CargarCatalogos` recibe `CatalogosTarea3.xml` y carga los catálogos de TP3. Luego `sp_CargarSimulacion` recibe `OperacionesTarea3.xml` y crea:

- una fila por fecha en `SimFecha`;
- una fila por nodo de operación en `SimOperacion`;
- el `Id` de `SimOperacion` conserva el orden de documento.

La simulación se procesa fecha por fecha y se puede reanudar porque cada nodo tiene `FlagProcesado` y cada fecha `FlagTerminada`.

## Simulación

Ejecutar:

```sql
DECLARE @rc INT, @msg NVARCHAR(200);
EXEC dbo.sp_Simulacion @outResultCode=@rc OUTPUT, @outMensaje=@msg OUTPUT;
SELECT @rc AS ResultCode, @msg AS Mensaje;
```

El proceso:

1. toma la fecha pendiente más antigua;
2. exige que la fecha anterior esté terminada;
3. ejecuta `sp_ProcesarOperacionesDia`;
4. ejecuta los cierres cuya `FechaFin` corresponde a esa fecha;
5. marca la fecha como terminada.

## Cierre de estado de cuenta

El orden implementado es:

1. intereses sobre el saldo mínimo del periodo;
2. comisión por exceso de retiros ATM;
3. comisión por exceso de retiros en cajero humano;
4. cargo mensual;
5. multa por saldo mínimo.

Los contadores `CantOpATM` y `CantOpHumano` incluyen depósitos y retiros para efectos informativos. Los límites de comisión se calculan exclusivamente con retiros.

El saldo mínimo se actualiza con los saldos **posteriores a los movimientos**; el saldo inicial no se considera como una observación del mínimo cuando todavía no existe un movimiento.

## Portal

El portal permite:

- listar estados de cuenta de la cuenta seleccionada;
- ver saldo inicial, saldo final, saldo mínimo y contadores;
- abrir el detalle de movimientos de un estado;
- consultar fecha, monto, descripción y nuevo saldo en orden cronológico.

La consulta de movimientos pasa por `sp_ConsultarMovimientosEstado`, que valida el acceso del usuario antes de devolver información.

## Verificación

Ejecutar `17_verificacion_tp3.sql`. Cada consulta debe devolver cero filas. El script verifica:

- saldo de cuenta contra estado abierto;
- saldo final = saldo inicial + créditos - débitos;
- contadores ATM, cajero humano y SINPE;
- máximo un estado abierto por cuenta;
- todas las fechas de simulación terminadas.

## Corrida final

Antes de la entrega:

1. ejecutar los scripts sobre una base limpia;
2. cargar los dos XML;
3. ejecutar `sp_Simulacion`;
4. ejecutar `17_verificacion_tp3.sql`;
5. entrar al portal y capturar la lista de estados y el detalle de movimientos;
6. guardar capturas de la corrida final.
