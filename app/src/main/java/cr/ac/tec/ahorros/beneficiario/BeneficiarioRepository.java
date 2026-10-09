package cr.ac.tec.ahorros.beneficiario;

import java.sql.Date;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.List;
import java.util.Map;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.simple.SimpleJdbcCall;
import org.springframework.stereotype.Repository;

import cr.ac.tec.ahorros.common.Sp;

/** Solo llama SPs; las reglas de negocio y la bitácora viven en la BD. */
@Repository
public class BeneficiarioRepository {

    private final SimpleJdbcCall listarCall;
    private final SimpleJdbcCall insertarCall;
    private final SimpleJdbcCall actualizarCall;
    private final SimpleJdbcCall eliminarCall;

    public BeneficiarioRepository(JdbcTemplate jdbc) {
        this.listarCall = new SimpleJdbcCall(jdbc)
                .withSchemaName("dbo")
                .withProcedureName("sp_ListarBeneficiarios")
                .returningResultSet("beneficiarios", BeneficiarioRepository::mapear);
        this.insertarCall = new SimpleJdbcCall(jdbc)
                .withSchemaName("dbo").withProcedureName("sp_InsertarBeneficiario");
        this.actualizarCall = new SimpleJdbcCall(jdbc)
                .withSchemaName("dbo").withProcedureName("sp_ActualizarBeneficiario");
        this.eliminarCall = new SimpleJdbcCall(jdbc)
                .withSchemaName("dbo").withProcedureName("sp_EliminarBeneficiario");
    }

    @SuppressWarnings("unchecked")
    public ListaBeneficiariosResponse listar(int idUsuario, String numeroCuenta) {
        Map<String, Object> out = listarCall.execute(new MapSqlParameterSource()
                .addValue("inIdUsuario", idUsuario)
                .addValue("inNumeroCuenta", numeroCuenta));
        Sp.verificar(out);
        List<BeneficiarioDto> filas = (List<BeneficiarioDto>) out.get("beneficiarios");
        int suma = ((Number) out.get("outSumaPorcentajes")).intValue();
        return ListaBeneficiariosResponse.de(filas == null ? List.of() : filas, suma);
    }

    public int insertar(int idUsuario, String numeroCuenta, BeneficiarioRequest r) {
        Map<String, Object> out = insertarCall.execute(new MapSqlParameterSource()
                .addValue("inIdUsuario", idUsuario)
                .addValue("inNumeroCuenta", numeroCuenta)
                .addValue("inIdTipoDocuIdentidad", r.idTipoDocuIdentidad())
                .addValue("inValorDocumentoIdentidad", r.valorDocumentoIdentidad())
                .addValue("inNombre", r.nombre())
                .addValue("inFechaNacimiento", Date.valueOf(r.fechaNacimiento()))
                .addValue("inEmail", r.email())
                .addValue("inTelefono1", r.telefono1())
                .addValue("inTelefono2", r.telefono2())
                .addValue("inIdParentezco", r.idParentezco())
                .addValue("inPorcentaje", r.porcentaje()));
        Sp.verificar(out);
        return ((Number) out.get("outIdBeneficiario")).intValue();
    }

    public void actualizar(int idUsuario, String numeroCuenta, int idBeneficiario,
                           BeneficiarioUpdateRequest r) {
        Map<String, Object> out = actualizarCall.execute(new MapSqlParameterSource()
                .addValue("inIdUsuario", idUsuario)
                .addValue("inNumeroCuenta", numeroCuenta)
                .addValue("inIdBeneficiario", idBeneficiario)
                .addValue("inNombre", r.nombre())
                .addValue("inIdParentezco", r.idParentezco())
                .addValue("inPorcentaje", r.porcentaje()));
        Sp.verificar(out);
    }

    public void eliminar(int idUsuario, String numeroCuenta, int idBeneficiario) {
        Map<String, Object> out = eliminarCall.execute(new MapSqlParameterSource()
                .addValue("inIdUsuario", idUsuario)
                .addValue("inNumeroCuenta", numeroCuenta)
                .addValue("inIdBeneficiario", idBeneficiario));
        Sp.verificar(out);
    }

    private static BeneficiarioDto mapear(ResultSet rs, int fila) throws SQLException {
        return new BeneficiarioDto(
                rs.getInt("Id"),
                rs.getString("Nombre"),
                rs.getInt("IdTipoDocuIdentidad"),
                rs.getString("ValorDocumentoIdentidad"),
                rs.getDate("FechaNacimiento").toLocalDate(),
                rs.getString("Email"),
                rs.getString("Telefono1"),
                rs.getString("Telefono2"),
                rs.getInt("IdParentezco"),
                rs.getString("Parentezco"),
                rs.getInt("Porcentaje"));
    }
}
