package cr.ac.tec.ahorros.beneficiario;

import java.time.LocalDate;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Past;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/** Datos para agregar un beneficiario. El SP vuelve a validar todo. */
public record BeneficiarioRequest(
        @NotNull Integer idTipoDocuIdentidad,
        @NotBlank @Pattern(regexp = "\\d{1,32}", message = "debe ser numérico (máx. 32)")
        String valorDocumentoIdentidad,
        @NotBlank @Size(max = 64) String nombre,
        @NotNull @Past LocalDate fechaNacimiento,
        @NotBlank @Email @Size(max = 128) String email,
        @NotBlank @Pattern(regexp = "\\d{1,16}", message = "debe ser numérico") String telefono1,
        @NotBlank @Pattern(regexp = "\\d{1,16}", message = "debe ser numérico") String telefono2,
        @NotNull Integer idParentezco,
        @NotNull @Min(0) @Max(100) Integer porcentaje) {}
