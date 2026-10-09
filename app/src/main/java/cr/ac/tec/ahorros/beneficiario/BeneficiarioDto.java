package cr.ac.tec.ahorros.beneficiario;

import java.time.LocalDate;

public record BeneficiarioDto(
        int id,
        String nombre,
        int idTipoDocuIdentidad,
        String valorDocumentoIdentidad,
        LocalDate fechaNacimiento,
        String email,
        String telefono1,
        String telefono2,
        int idParentezco,
        String parentezco,
        int porcentaje) {}
