package cr.ac.tec.ahorros.auth;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record LoginRequest(
        @NotBlank @Size(max = 64) String user,
        @NotBlank @Size(max = 128) String pass) {}
