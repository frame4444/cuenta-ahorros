package cr.ac.tec.ahorros.beneficiario;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/** Se pueden actualizar nombre, parentesco y porcentaje. */
public record BeneficiarioUpdateRequest(
        @NotBlank @Size(max = 64) String nombre,
        @NotNull Integer idParentezco,
        @NotNull @Min(0) @Max(100) Integer porcentaje) {}
