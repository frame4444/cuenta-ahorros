package cr.ac.tec.ahorros.carga;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * Carga catálogos y el XML de operaciones (hacia SimOperacion) al arrancar, SOLO si
 * app.carga.habilitada=true. La lógica de inserción vive en los SPs.
 */
@Component
@ConditionalOnProperty(name = "app.carga.habilitada", havingValue = "true")
public class CargaRunner implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(CargaRunner.class);

    private final CargaRepository repo;
    private final String rutaCatalogos;
    private final String rutaOperaciones;

    public CargaRunner(CargaRepository repo,
                       @Value("${app.carga.catalogos}") String rutaCatalogos,
                       @Value("${app.carga.operaciones}") String rutaOperaciones) {
        this.repo = repo;
        this.rutaCatalogos = rutaCatalogos;
        this.rutaOperaciones = rutaOperaciones;
    }

    @Override
    public void run(ApplicationArguments args) throws Exception {
        log.info("Catálogos: {}", repo.cargarCatalogos(leerXml(rutaCatalogos)));
        log.info("Simulación: {}", repo.cargarSimulacion(leerXml(rutaOperaciones)));
    }

    /** Quita BOM y la declaración <?xml ... ?> (SQL Server no la acepta en NVARCHAR con encoding="UTF-8"). */
    private static String leerXml(String ruta) throws Exception {
        String xml = Files.readString(Path.of(ruta), StandardCharsets.UTF_8);
        return xml.replace("\uFEFF", "").replaceFirst("^\\s*<\\?xml[^>]*\\?>", "");
    }
}
