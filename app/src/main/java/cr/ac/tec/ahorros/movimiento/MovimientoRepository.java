package cr.ac.tec.ahorros.movimiento;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.List;
import java.util.Map;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.simple.SimpleJdbcCall;
import org.springframework.stereotype.Repository;

import cr.ac.tec.ahorros.common.Sp;

/**
 * El SP debe verificar que el usuario tenga acceso a la cuenta y que el estado
 * consultado pertenezca a esa cuenta. No consultar Movimiento directamente
 * desde Java sin ese control de autorización.
 */
@Repository
public class MovimientoRepository {

    private final SimpleJdbcCall consultarCall;

    public MovimientoRepository(JdbcTemplate jdbc) {
        this.consultarCall = new SimpleJdbcCall(jdbc)
                .withSchemaName("dbo")
                .withProcedureName("sp_ConsultarMovimientosEstado")
                .returningResultSet("movimientos", MovimientoRepository::mapear);
    }

    @SuppressWarnings("unchecked")
    public List<MovimientoDto> consultar(int idUsuario, String numeroCuenta, int idEstadoCuenta) {
        Map<String, Object> out = consultarCall.execute(new MapSqlParameterSource()
                .addValue("inIdUsuario", idUsuario)
                .addValue("inNumeroCuenta", numeroCuenta)
                .addValue("inIdEstadoCuenta", idEstadoCuenta));

        Sp.verificar(out);
        List<MovimientoDto> movimientos = (List<MovimientoDto>) out.get("movimientos");
        return movimientos == null ? List.of() : movimientos;
    }

    private static MovimientoDto mapear(ResultSet rs, int fila) throws SQLException {
        return new MovimientoDto(
                rs.getLong("Id"),
                rs.getDate("Fecha").toLocalDate(),
                rs.getBigDecimal("Monto"),
                rs.getString("Descripcion"),
                rs.getBigDecimal("NuevoSaldo"),
                rs.getString("Simbolo"));
    }
}
