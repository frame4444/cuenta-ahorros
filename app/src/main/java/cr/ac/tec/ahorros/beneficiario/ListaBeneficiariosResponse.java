package cr.ac.tec.ahorros.beneficiario;

import java.util.List;

public record ListaBeneficiariosResponse(
        List<BeneficiarioDto> beneficiarios,
        int sumaPorcentajes,
        boolean alertaPorcentajes,
        String mensajeAlerta) {

    private static final String MENSAJE_ALERTA =
            "la suma de los porcentajes de sus beneficiarios no suma 100, "
            + "favor corregir y cancelar la edición";

    public static ListaBeneficiariosResponse de(List<BeneficiarioDto> lista, int suma) {
        boolean alerta = suma != 100;
        return new ListaBeneficiariosResponse(lista, suma, alerta, alerta ? MENSAJE_ALERTA : null);
    }
}
