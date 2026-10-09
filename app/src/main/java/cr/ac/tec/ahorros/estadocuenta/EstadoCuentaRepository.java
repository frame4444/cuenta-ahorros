package cr.ac.tec.ahorros.estadocuenta;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.List;
import java.util.Map;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.simple.SimpleJdbcCall;
import org.springframework.stereotype.Repository;

import cr.ac.tec.ahorros.common.Sp;

@Repository
public class EstadoCuentaRepository {

    private final SimpleJdbcCall consultarCall;

    public EstadoCuentaRepository(JdbcTemplate jdbc) {
        this.consultarCall = new SimpleJdbcCall(jdbc)
                .withSchemaName("dbo")
                .withProcedureName("sp_ConsultarEstadosCuenta")
                .returningResultSet("estados", EstadoCuentaRepository::mapear);
    }

    @SuppressWarnings("unchecked")
    public List<EstadoCuentaDto> consultar(int idUsuario, String numeroCuenta) {
        Map<String, Object> out = consultarCall.execute(new MapSqlParameterSource()
                .addValue("inIdUsuario", idUsuario)
                .addValue("inNumeroCuenta", numeroCuenta));
        Sp.verificar(out);
        List<EstadoCuentaDto> filas = (List<EstadoCuentaDto>) out.get("estados");
        return filas == null ? List.of() : filas;
    }

    private static EstadoCuentaDto mapear(ResultSet rs, int fila) throws SQLException {
        return new EstadoCuentaDto(
                rs.getInt("Id"),
                rs.getDate("FechaInicio").toLocalDate(),
                rs.getDate("FechaFin").toLocalDate(),
                rs.getBigDecimal("SaldoInicial"),
                rs.getBigDecimal("SaldoFinal"),
                rs.getBigDecimal("SaldoMinimo"),
                rs.getBigDecimal("InteresesAcumulados"),
                rs.getInt("CantRetiros"),
                rs.getInt("CantDepositos"),
                rs.getInt("CantSinpeEntrantes"),
                rs.getInt("CantSinpeSalientes"));
    }
}
