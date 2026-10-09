package cr.ac.tec.ahorros.catalogo;

import java.util.List;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import cr.ac.tec.ahorros.common.Sesion;
import jakarta.servlet.http.HttpSession;

@RestController
@RequestMapping("/api/catalogos")
public class CatalogoController {

    private final CatalogoRepository repo;

    public CatalogoController(CatalogoRepository repo) {
        this.repo = repo;
    }

    @GetMapping("/parentezcos")
    public List<CatalogoItem> parentezcos(HttpSession session) {
        Sesion.requerirUsuario(session);
        return repo.listarParentezcos();
    }

    @GetMapping("/tipos-documento")
    public List<CatalogoItem> tiposDocumento(HttpSession session) {
        Sesion.requerirUsuario(session);
        return repo.listarTiposDocumento();
    }
}
