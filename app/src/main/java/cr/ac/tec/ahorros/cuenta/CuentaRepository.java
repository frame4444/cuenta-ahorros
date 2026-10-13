
package cr.ac.tec.ahorros.cuenta;

import java.util.List;
import java.util.Map;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.simple.SimpleJdbcCall;
import org.springframework.stereotype.Repository;

import cr.ac.tec.ahorros.common.Sp;

@Repository
public class CuentaRepository {

    private final SimpleJdbcCall listarCall;

    public CuentaRepository(JdbcTemplate jdbc) {
        this.listarCall = new SimpleJdbcCall(jdbc)
                .withSchemaName("dbo")
                .withProcedureName("sp_ListarCuentasUsuario")
                .returningResultSet("cuentas", (rs, fila) -> Map.of(
                        "id", rs.getInt("Id"),
                        "numeroCuenta", rs.getString("NumeroCuenta"),
                        "saldo", rs.getBigDecimal("Saldo"),
                        "fechaCreacion", rs.getDate("FechaCreacion").toLocalDate().toString()
                ));
    }

    @SuppressWarnings("unchecked")
    public List<Map<String, Object>> listar(int idUsuario) {
        Map<String, Object> resultado = listarCall.execute(
                new MapSqlParameterSource()
                        .addValue("inIdUsuario", idUsuario)
        );

        Sp.verificar(resultado);

        List<Map<String, Object>> cuentas =
                (List<Map<String, Object>>) resultado.get("cuentas");

        return cuentas == null ? List.of() : cuentas;
    }
}
