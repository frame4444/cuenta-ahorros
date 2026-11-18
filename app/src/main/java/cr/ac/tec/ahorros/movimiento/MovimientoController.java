package cr.ac.tec.ahorros.movimiento;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import cr.ac.tec.ahorros.auth.Usuario;
import cr.ac.tec.ahorros.common.Sesion;
import jakarta.servlet.http.HttpSession;

/** Endpoint de solo lectura: la aplicación de movimientos ocurre en SQL. */
@RestController
@RequestMapping("/api/cuentas/{numeroCuenta}/estados-cuenta/{idEstadoCuenta}/movimientos")
public class MovimientoController {

    private final MovimientoRepository repo;

    public MovimientoController(MovimientoRepository repo) {
        this.repo = repo;
    }

    @GetMapping
    public List<MovimientoDto> listar(@PathVariable String numeroCuenta,
                                      @PathVariable int idEstadoCuenta,
                                      HttpSession session) {
        Usuario usuario = Sesion.requerirUsuario(session);
        if (idEstadoCuenta <= 0 || numeroCuenta.isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Cuenta o estado inválido");
        }
        return repo.consultar(usuario.id(), numeroCuenta, idEstadoCuenta);
    }
}
