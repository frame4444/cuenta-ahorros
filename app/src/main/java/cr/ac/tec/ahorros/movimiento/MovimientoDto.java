package cr.ac.tec.ahorros.movimiento;

import java.math.BigDecimal;
import java.time.LocalDate;

/** Datos que el portal muestra para cada movimiento de un estado de cuenta. */
public record MovimientoDto(
        long id,
        LocalDate fecha,
        BigDecimal monto,
        String descripcion,
        BigDecimal nuevoSaldo,
        String simbolo) {}
