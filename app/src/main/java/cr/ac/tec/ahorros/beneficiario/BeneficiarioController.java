package cr.ac.tec.ahorros.beneficiario;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import cr.ac.tec.ahorros.auth.Usuario;
import cr.ac.tec.ahorros.common.Sesion;
import jakarta.servlet.http.HttpSession;
import jakarta.validation.Valid;

/**
 * Las operaciones que modifican devuelven la lista ya actualizada, con la
 * suma de porcentajes y la alerta, para que el frontend refresque de una vez.
 */
@RestController
@RequestMapping("/api/cuentas/{numeroCuenta}/beneficiarios")
public class BeneficiarioController {

    private final BeneficiarioRepository repo;

    public BeneficiarioController(BeneficiarioRepository repo) {
        this.repo = repo;
    }

    @GetMapping
    public ListaBeneficiariosResponse listar(@PathVariable String numeroCuenta,
                                             HttpSession session) {
        Usuario u = Sesion.requerirUsuario(session);
        return repo.listar(u.id(), numeroCuenta);
    }

    @PostMapping
    public ResponseEntity<ListaBeneficiariosResponse> agregar(
            @PathVariable String numeroCuenta,
            @Valid @RequestBody BeneficiarioRequest req,
            HttpSession session) {
        Usuario u = Sesion.requerirUsuario(session);
        repo.insertar(u.id(), numeroCuenta, req);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(repo.listar(u.id(), numeroCuenta));
    }

    @PutMapping("/{id}")
    public ListaBeneficiariosResponse actualizar(
            @PathVariable String numeroCuenta,
            @PathVariable int id,
            @Valid @RequestBody BeneficiarioUpdateRequest req,
            HttpSession session) {
        Usuario u = Sesion.requerirUsuario(session);
        repo.actualizar(u.id(), numeroCuenta, id, req);
        return repo.listar(u.id(), numeroCuenta);
    }

    @DeleteMapping("/{id}")
    public ListaBeneficiariosResponse eliminar(@PathVariable String numeroCuenta,
                                               @PathVariable int id,
                                               HttpSession session) {
        Usuario u = Sesion.requerirUsuario(session);
        repo.eliminar(u.id(), numeroCuenta, id);
        return repo.listar(u.id(), numeroCuenta);
    }
}
