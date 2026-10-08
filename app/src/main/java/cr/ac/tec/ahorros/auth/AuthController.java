package cr.ac.tec.ahorros.auth;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpSession;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    public static final String SESSION_USER = "usuario";

    private final UsuarioRepository repo;

    public AuthController(UsuarioRepository repo) {
        this.repo = repo;
    }

    @PostMapping("/login")
    public ResponseEntity<Usuario> login(@Valid @RequestBody LoginRequest req, HttpServletRequest http) {
        var usuario = repo.login(req.user(), req.pass(), http.getRemoteAddr());
        if (usuario.isEmpty()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }
        // Sesión nueva en cada login (evita session fixation)
        HttpSession anterior = http.getSession(false);
        if (anterior != null) anterior.invalidate();
        http.getSession(true).setAttribute(SESSION_USER, usuario.get());
        return ResponseEntity.ok(usuario.get());
    }

    @PostMapping("/logout")
    public ResponseEntity<Void> logout(HttpSession session) {
        Usuario u = (Usuario) session.getAttribute(SESSION_USER);
        if (u != null) repo.logout(u.id());
        session.invalidate();
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/me")
    public ResponseEntity<Usuario> me(HttpSession session) {
        Usuario u = (Usuario) session.getAttribute(SESSION_USER);
        return u == null ? ResponseEntity.status(HttpStatus.UNAUTHORIZED).build() : ResponseEntity.ok(u);
    }
}
