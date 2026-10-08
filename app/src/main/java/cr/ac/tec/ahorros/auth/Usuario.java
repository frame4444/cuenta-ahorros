package cr.ac.tec.ahorros.auth;

import java.io.Serializable;

public record Usuario(int id, String username, boolean esAdministrador, int idPersona)
        implements Serializable {}
