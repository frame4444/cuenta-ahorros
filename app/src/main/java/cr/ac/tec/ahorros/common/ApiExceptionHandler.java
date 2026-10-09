package cr.ac.tec.ahorros.common;

import java.util.stream.Collectors;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class ApiExceptionHandler {

    public record ErrorBody(int codigo, String mensaje) {}

    @ExceptionHandler(SpException.class)
    public ResponseEntity<ErrorBody> sp(SpException e) {
        HttpStatus estado = switch (e.getCodigo()) {
            case 50003 -> HttpStatus.FORBIDDEN;
            case 50004, 50006 -> HttpStatus.CONFLICT;
            case 50005 -> HttpStatus.BAD_REQUEST;
            case 50007 -> HttpStatus.NOT_FOUND;
            default -> HttpStatus.INTERNAL_SERVER_ERROR;
        };
        return ResponseEntity.status(estado).body(new ErrorBody(e.getCodigo(), e.getMessage()));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorBody> validacion(MethodArgumentNotValidException e) {
        String detalle = e.getBindingResult().getFieldErrors().stream()
                .map(f -> f.getField() + ": " + f.getDefaultMessage())
                .collect(Collectors.joining("; "));
        return ResponseEntity.badRequest().body(new ErrorBody(50005, detalle));
    }
}
