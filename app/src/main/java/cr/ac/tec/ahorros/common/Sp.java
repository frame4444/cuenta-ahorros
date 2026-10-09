package cr.ac.tec.ahorros.common;

import java.util.Map;

public final class Sp {

    private Sp() {}

    /** Lanza SpException si el SP devolvió un código de error en outResultCode. */
    public static void verificar(Map<String, Object> out) {
        int codigo = ((Number) out.get("outResultCode")).intValue();
        if (codigo != 0) {
            throw new SpException(codigo, (String) out.get("outMensaje"));
        }
    }
}
