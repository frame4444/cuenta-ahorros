package cr.ac.tec.ahorros.auth;

import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.simple.SimpleJdbcCall;
import org.springframework.stereotype.Repository;

/** Solo llama SPs: nada de SQL incrustado. */
@Repository
public class UsuarioRepository {

    private final SimpleJdbcCall loginCall;
    private final SimpleJdbcCall logoutCall;
    private final SimpleJdbcCall accesoCall;

    public UsuarioRepository(JdbcTemplate jdbc) {
        this.loginCall = new SimpleJdbcCall(jdbc)
                .withSchemaName("dbo")
                .withProcedureName("sp_Login")
                .returningResultSet("usuario", (rs, i) -> new Usuario(
                        rs.getInt("Id"),
                        rs.getString("Username"),
                        rs.getBoolean("EsAdministrador"),
                        rs.getInt("IdPersona")));
        this.logoutCall = new SimpleJdbcCall(jdbc)
                .withSchemaName("dbo")
                .withProcedureName("sp_Logout");
        this.accesoCall = new SimpleJdbcCall(jdbc)
                .withSchemaName("dbo")
                .withProcedureName("sp_VerificarAccesoCuenta");
    }

    @SuppressWarnings("unchecked")
    public Optional<Usuario> login(String user, String pass, String ip) {
        Map<String, Object> out = loginCall.execute(new MapSqlParameterSource()
                .addValue("inUser", user)
                .addValue("inPass", pass)
                .addValue("inIP", ip));
        List<Usuario> filas = (List<Usuario>) out.get("usuario");
        return (filas == null || filas.isEmpty()) ? Optional.empty() : Optional.of(filas.get(0));
    }

    public void logout(int idUsuario) {
        logoutCall.execute(new MapSqlParameterSource().addValue("inIdUsuario", idUsuario));
    }

    public boolean puedeVerCuenta(int idUsuario, String numeroCuenta) {
        Map<String, Object> out = accesoCall.execute(new MapSqlParameterSource()
                .addValue("inIdUsuario", idUsuario)
                .addValue("inNumeroCuenta", numeroCuenta));
        return Integer.valueOf(0).equals(out.get("outResultCode"));
    }
}
