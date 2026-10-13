
package cr.ac.tec.ahorros.cuenta;

import java.util.List;
import java.util.Map;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import cr.ac.tec.ahorros.auth.Usuario;
import cr.ac.tec.ahorros.common.Sesion;
import jakarta.servlet.http.HttpSession;

@RestController
@RequestMapping("/api/cuentas")
public class CuentaController {

    private final CuentaRepository repo;

    public CuentaController(CuentaRepository repo) {
        this.repo = repo;
    }

    @GetMapping
    public List<Map<String, Object>> listar(HttpSession session) {
        Usuario usuario = Sesion.requerirUsuario(session);
        return repo.listar(usuario.id());
    }
}
