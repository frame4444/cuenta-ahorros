package cr.ac.tec.ahorros.common;

import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

import cr.ac.tec.ahorros.auth.AuthController;
import cr.ac.tec.ahorros.auth.Usuario;
import jakarta.servlet.http.HttpSession;

public final class Sesion {

    private Sesion() {}

    /** Devuelve el usuario de la sesión o responde 401 si no hay login. */
    public static Usuario requerirUsuario(HttpSession session) {
        Usuario usuario = (Usuario) session.getAttribute(AuthController.SESSION_USER);
        if (usuario == null) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED);
        }
        return usuario;
    }
}
