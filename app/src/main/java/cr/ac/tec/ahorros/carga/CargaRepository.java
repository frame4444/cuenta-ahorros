package cr.ac.tec.ahorros.carga;

import java.util.Map;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.simple.SimpleJdbcCall;
import org.springframework.stereotype.Repository;

@Repository
public class CargaRepository {

    private final SimpleJdbcCall catalogosCall;
    private final SimpleJdbcCall datosCall;

    public CargaRepository(JdbcTemplate jdbc) {
        this.catalogosCall = new SimpleJdbcCall(jdbc)
                .withSchemaName("dbo").withProcedureName("sp_CargarCatalogos");
        this.datosCall = new SimpleJdbcCall(jdbc)
                .withSchemaName("dbo").withProcedureName("sp_CargarDatos");
    }

    public String cargarCatalogos(String xml) {
        return ejecutar(catalogosCall, xml);
    }

    public String cargarDatos(String xml) {
        return ejecutar(datosCall, xml);
    }

    private String ejecutar(SimpleJdbcCall call, String xml) {
        Map<String, Object> out = call.execute(new MapSqlParameterSource().addValue("inXml", xml));
        int codigo = ((Number) out.get("outResultCode")).intValue();
        String mensaje = (String) out.get("outMensaje");
        if (codigo != 0) {
            throw new IllegalStateException("La carga falló (código " + codigo + "): " + mensaje);
        }
        return mensaje;
    }
}
