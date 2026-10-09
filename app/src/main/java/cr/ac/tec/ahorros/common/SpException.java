package cr.ac.tec.ahorros.common;

/** Error de negocio devuelto por un SP (código distinto de 0). */
public class SpException extends RuntimeException {

    private final int codigo;

    public SpException(int codigo, String mensaje) {
        super(mensaje);
        this.codigo = codigo;
    }

    public int getCodigo() {
        return codigo;
    }
}
