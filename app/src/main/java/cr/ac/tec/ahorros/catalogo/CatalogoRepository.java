package cr.ac.tec.ahorros.catalogo;

import java.util.List;
import java.util.Map;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.simple.SimpleJdbcCall;
import org.springframework.stereotype.Repository;

@Repository
public class CatalogoRepository {

    private final SimpleJdbcCall parentezcosCall;
    private final SimpleJdbcCall tiposDocumentoCall;

    public CatalogoRepository(JdbcTemplate jdbc) {
        this.parentezcosCall = crearLlamada(jdbc, "sp_ListarParentezcos");
        this.tiposDocumentoCall = crearLlamada(jdbc, "sp_ListarTiposDocumento");
    }

    public List<CatalogoItem> listarParentezcos() {
        return ejecutar(parentezcosCall);
    }

    public List<CatalogoItem> listarTiposDocumento() {
        return ejecutar(tiposDocumentoCall);
    }

    private static SimpleJdbcCall crearLlamada(JdbcTemplate jdbc, String sp) {
        return new SimpleJdbcCall(jdbc)
                .withSchemaName("dbo")
                .withProcedureName(sp)
                .returningResultSet("items",
                        (rs, i) -> new CatalogoItem(rs.getInt("Id"), rs.getString("Nombre")));
    }

    @SuppressWarnings("unchecked")
    private static List<CatalogoItem> ejecutar(SimpleJdbcCall call) {
        Map<String, Object> out = call.execute();
        List<CatalogoItem> items = (List<CatalogoItem>) out.get("items");
        return items == null ? List.of() : items;
    }
}
