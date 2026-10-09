package cr.ac.tec.ahorros.estadocuenta;

import java.util.List;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import cr.ac.tec.ahorros.auth.Usuario;
import cr.ac.tec.ahorros.common.Sesion;
import jakarta.servlet.http.HttpSession;

@RestController
@RequestMapping("/api/cuentas/{numeroCuenta}/estados-cuenta")
public class EstadoCuentaController {

    private final EstadoCuentaRepository repo;

    public EstadoCuentaController(EstadoCuentaRepository repo) {
        this.repo = repo;
    }

    /** Últimos 8 estados de cuenta, el más reciente primero. */
    @GetMapping
    public List<EstadoCuentaDto> listar(@PathVariable String numeroCuenta,
                                        HttpSession session) {
        Usuario u = Sesion.requerirUsuario(session);
        return repo.consultar(u.id(), numeroCuenta);
    }
}
