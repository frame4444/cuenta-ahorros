package cr.ac.tec.ahorros.estadocuenta;

import java.math.BigDecimal;
import java.time.LocalDate;

public record EstadoCuentaDto(
        int id,
        LocalDate fechaInicio,
        LocalDate fechaFin,
        BigDecimal saldoInicial,
        BigDecimal saldoFinal,
        BigDecimal saldoMinimo,
        int cantOpAtm,
        int cantOpHumano,
        int cantOpSinpe,
        boolean cerrado) {}
