"use strict";
const login = document.getElementById("login");
const panel = document.getElementById("panel");
const navegacion = document.getElementById("navegacion");
const mensaje = document.getElementById("mensaje");
const numeroCuenta = document.getElementById("numeroCuenta");

const listaCuentas = document.getElementById("listaCuentas");
const listaBeneficiarios = document.getElementById("listaBeneficiarios");
const listaEstados = document.getElementById("listaEstados");
const formularioBeneficiario = document.getElementById("formularioBeneficiario");

let usuarioActual = null;
let parentescos = [];
let tiposDocumento = [];

async function api(ruta, opciones = {}) {
    const respuesta = await fetch(ruta, {
        ...opciones,
        credentials: "same-origin",
        headers: {
            "Content-Type": "application/json",
            ...opciones.headers
        }
    });

    if (respuesta.status === 401) {
        if (ruta === "/api/auth/login") {
            throw new Error("Usuario o contraseña incorrectos.");
        }

        mostrarLogin();
        throw new Error("La sesión expiró. Inicia sesión nuevamente.");
    }

    if (!respuesta.ok) {
        let detalle = "";

        try {
            const datos = await respuesta.json();
            detalle = datos.message || datos.mensaje || datos.error || "";
        } catch {
            detalle = "";
        }

        throw new Error(
            detalle || `Error del servidor (${respuesta.status})`
        );
    }

    if (respuesta.status === 204) {
        return null;
    }

    return respuesta.json();
}


function mostrarMensaje(texto, tipo = "") {
    mensaje.textContent = texto;
    mensaje.className = tipo;
}

function limpiar(elemento) {
    elemento.replaceChildren();
}

function crearElemento(etiqueta, texto, clase = "") {
    const elemento = document.createElement(etiqueta);
    elemento.textContent = texto;
    if (clase) elemento.className = clase;
    return elemento;
}

function formatoDinero(valor) {
    return new Intl.NumberFormat("es-CR", {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2
    }).format(Number(valor));
}

function cuentaSeleccionada() {
    const cuenta = numeroCuenta.value.trim();

    if (!cuenta) {
        throw new Error("Primero selecciona una cuenta en Mis cuentas.");
    }

    return encodeURIComponent(cuenta);
}

function mostrarLogin() {
    usuarioActual = null;
    login.hidden = false;
    panel.hidden = true;
    navegacion.hidden = true;
    limpiar(listaBeneficiarios);
    limpiar(listaEstados);
    limpiar(formularioBeneficiario);
    numeroCuenta.value = "";
    limpiar(listaCuentas);
}

function mostrarPanel(usuario) {
    usuarioActual = usuario;
    login.hidden = true;
    panel.hidden = false;
    navegacion.hidden = false;

    document.getElementById("usuarioActual").textContent =
        `Sesión iniciada como ${usuario.username}`;

    cambiarSeccion("cuentas");
}



async function cargarCuentas() {
    limpiar(listaCuentas);
    listaCuentas.append(crearElemento("p", "Cargando cuentas..."));

    try {
        const cuentas = await api("/api/cuentas");

        limpiar(listaCuentas);

        if (!cuentas.length) {
            listaCuentas.append(
                crearElemento("p", "No tienes cuentas autorizadas.")
            );
            return;
        }

        for (const cuenta of cuentas) {
            const div = tarjeta(`Cuenta ${cuenta.numeroCuenta}`);

            detalle(div, "Saldo", `₡${formatoDinero(cuenta.saldo)}`);
            detalle(div, "Fecha de creación", cuenta.fechaCreacion);

            div.append(
                botonAccion("Seleccionar cuenta", () => {
                    numeroCuenta.value = cuenta.numeroCuenta;
                    cambiarSeccion("beneficiarios");
                })
            );

            listaCuentas.append(div);
        }
    } catch (error) {
        limpiar(listaCuentas);
        mostrarMensaje(error.message, "error");
    }
}

function cambiarSeccion(seccion) {
    document.getElementById("seccionCuentas").hidden =
        seccion !== "cuentas";

    document.getElementById("seccionBeneficiarios").hidden =
        seccion !== "beneficiarios";

    document.getElementById("seccionEstados").hidden =
        seccion !== "estados";

    document.querySelectorAll("[data-seccion]").forEach(boton => {
        boton.classList.toggle(
            "activo",
            boton.dataset.seccion === seccion
        );
    });

    mostrarMensaje("");

    if (seccion === "cuentas") cargarCuentas();
    if (seccion === "beneficiarios") cargarBeneficiarios();
    if (seccion === "estados") cargarEstados();
}
document.getElementById("formLogin").addEventListener(
    "submit",
    async evento => {
        evento.preventDefault();

        const user = document.getElementById("usuario").value.trim();
        const pass = document.getElementById("contrasena").value;

        try {
            const usuario = await api("/api/auth/login", {
                method: "POST",
                body: JSON.stringify({ user, pass })
            });

            document.getElementById("contrasena").value = "";
            mostrarPanel(usuario);
            mostrarMensaje("Sesión iniciada correctamente.", "exito");
        } catch (error) {
            mostrarMensaje(error.message, "error");
        }
    }
);
document.getElementById("cerrarSesion").addEventListener(
    "click",
    async () => {
        try {
            await api("/api/auth/logout", {
                method: "POST"
            });
            mostrarLogin();
            mostrarMensaje("Sesión cerrada correctamente.", "exito");
        } catch (error) {
            mostrarMensaje(error.message, "error");
        }
    }
);
document.querySelectorAll("[data-seccion]").forEach(boton => {
    boton.addEventListener("click", () => {
        cambiarSeccion(boton.dataset.seccion);
    });
});
async function cargarCatalogos() {
    const [p, t] = await Promise.all([
        api("/api/catalogos/parentezcos"),
        api("/api/catalogos/tipos-documento")
    ]);

    parentescos = p;
    tiposDocumento = t;
}

function crearSelect(nombre, elementos, seleccionado) {
    const select = document.createElement("select");
    select.name = nombre;
    select.required = true;

    for (const elemento of elementos) {
        const opcion = document.createElement("option");
        opcion.value = elemento.id;
        opcion.textContent = elemento.nombre;
        opcion.selected = elemento.id === seleccionado;
        select.append(opcion);
    }

    return select;
}

function campo(formulario, etiqueta, nombre, tipo = "text", valor = "") {
    const label = crearElemento("label", etiqueta);
    const input = document.createElement("input");

    input.name = nombre;
    input.type = tipo;
    input.value = valor ?? "";
    input.required = true;

    label.append(input);
    formulario.append(label);
    return input;
}

function selector(formulario, etiqueta, nombre, opciones, valor) {
    const label = crearElemento("label", etiqueta);
    label.append(crearSelect(nombre, opciones, valor));
    formulario.append(label);
}

function tarjeta(titulo) {
    const div = document.createElement("div");
    div.className = "tarjeta";
    div.append(crearElemento("h4", titulo));
    return div;
}

function detalle(div, etiqueta, valor) {
    div.append(crearElemento("p", `${etiqueta}: ${valor ?? "-"}`));
}

function botonAccion(texto, accion) {
    const boton = document.createElement("button");
    boton.type = "button";
    boton.textContent = texto;
    boton.addEventListener("click", accion);
    return boton;
}
async function cargarBeneficiarios() {
    try {
        const cuenta = cuentaSeleccionada();
        await cargarCatalogos();

        const datos = await api(
            `/api/cuentas/${cuenta}/beneficiarios`
        );

        limpiar(listaBeneficiarios);
        limpiar(formularioBeneficiario);

        const resumen = crearElemento(
            "p",
            `Porcentaje asignado: ${datos.sumaPorcentajes}%`
        );
        listaBeneficiarios.append(resumen);
        
        if (datos.alertaPorcentajes) {
            mostrarMensaje(datos.mensajeAlerta || "La suma de los porcentajes de sus beneficiarios no suma 100, favor corregir y cancelar la edición.", "error");
        } else {
            mostrarMensaje("");
        }


        if (!datos.beneficiarios.length) {
            listaBeneficiarios.append(
                crearElemento("p", "Esta cuenta no tiene beneficiarios.")
            );
        }

        for (const beneficiario of datos.beneficiarios) {
            const div = tarjeta(beneficiario.nombre);

            detalle(
                div,
                "Documento",
                beneficiario.valorDocumentoIdentidad
            );
            detalle(div, "Parentesco", beneficiario.parentezco);
            detalle(div, "Porcentaje", `${beneficiario.porcentaje}%`);
            detalle(div, "Correo", beneficiario.email);

            div.append(
                botonAccion("Editar", () => {
                    mostrarFormularioBeneficiario(beneficiario);
                })
            );

            div.append(
                botonAccion("Eliminar", async () => {
                    if (!confirm(
                        `¿Eliminar a ${beneficiario.nombre} como beneficiario?`
                    )) return;

                    try {
                        await api(
                            `/api/cuentas/${cuenta}/beneficiarios/${beneficiario.id}`,
                            { method: "DELETE" }
                        );
                        await cargarBeneficiarios();
                        mostrarMensaje("Beneficiario eliminado.", "exito");
                    } catch (error) {
                        mostrarMensaje(error.message, "error");
                    }
                })
            );

            listaBeneficiarios.append(div);
        }

        formularioBeneficiario.append(
            botonAccion("Agregar beneficiario", () => {
                mostrarFormularioBeneficiario();
            })
        );

    } catch (error) {
        limpiar(listaBeneficiarios);
        limpiar(formularioBeneficiario);
        mostrarMensaje(error.message, "error");
    }
}

function mostrarFormularioBeneficiario(beneficiario = null) {
    limpiar(formularioBeneficiario);

    const form = document.createElement("form");
    form.append(
        crearElemento(
            "h3",
            beneficiario ? "Editar beneficiario" : "Nuevo beneficiario"
        )
    );

    if (!beneficiario) {
        campo(form, "Nombre", "nombre");
        selector(
            form, "Tipo de documento", "idTipoDocuIdentidad",
            tiposDocumento
        );
        campo(form, "Número de documento", "valorDocumentoIdentidad");
        campo(form, "Fecha de nacimiento", "fechaNacimiento", "date");
        campo(form, "Correo electrónico", "email", "email");
        campo(form, "Teléfono 1", "telefono1", "tel");
        campo(form, "Teléfono 2", "telefono2", "tel");
    } else {
        campo(form, "Nombre", "nombre", "text", beneficiario.nombre);
    }

    selector(
        form,
        "Parentesco",
        "idParentezco",
        parentescos,
        beneficiario?.idParentezco
    );

    const porcentaje = campo(
        form,
        "Porcentaje",
        "porcentaje",
        "number",
        beneficiario?.porcentaje ?? ""
    );
    porcentaje.min = "0";
    porcentaje.max = "100";

    const guardar = document.createElement("button");
    guardar.type = "submit";
    guardar.textContent = "Guardar beneficiario";
    form.append(guardar);

    form.addEventListener("submit", async evento => {
        evento.preventDefault();

        const datos = Object.fromEntries(new FormData(form));

        datos.idParentezco = Number(datos.idParentezco);
        datos.porcentaje = Number(datos.porcentaje);

        if (!beneficiario) {
            datos.idTipoDocuIdentidad =
                Number(datos.idTipoDocuIdentidad);
        }

        try {
            const cuenta = cuentaSeleccionada();
            const ruta = `/api/cuentas/${cuenta}/beneficiarios`;

            await api(
                beneficiario ? `${ruta}/${beneficiario.id}` : ruta,
                {
                    method: beneficiario ? "PUT" : "POST",
                    body: JSON.stringify(datos)
                }
            );

            await cargarBeneficiarios();
            mostrarMensaje("Beneficiario guardado.", "exito");
        } catch (error) {
            mostrarMensaje(error.message, "error");
        }
    });

    formularioBeneficiario.append(form);
}
async function cargarEstados() {
    try {
        const cuenta = cuentaSeleccionada();
        const estados = await api(
            `/api/cuentas/${cuenta}/estados-cuenta`
        );

        limpiar(listaEstados);

        if (!estados.length) {
            listaEstados.append(
                crearElemento("p", "No hay estados de cuenta disponibles.")
            );
            return;
        }

        for (const estado of estados) {
            const div = tarjeta(
                `${estado.fechaInicio} al ${estado.fechaFin}`
            );

            detalle(div, "Saldo inicial", formatoDinero(estado.saldoInicial));
            detalle(div, "Saldo final", formatoDinero(estado.saldoFinal));
            detalle(div, "Saldo mínimo", formatoDinero(estado.saldoMinimo));
            detalle(
                div,
                "Intereses acumulados",
                formatoDinero(estado.interesesAcumulados)
            );
            detalle(div, "Retiros", estado.cantRetiros);
            detalle(div, "Depósitos", estado.cantDepositos);
            detalle(div, "SINPE entrantes", estado.cantSinpeEntrantes);
            detalle(div, "SINPE salientes", estado.cantSinpeSalientes);

            listaEstados.append(div);
        }
    } catch (error) {
        limpiar(listaEstados);
        mostrarMensaje(error.message, "error");
    }
}
numeroCuenta.addEventListener("change", () => {
    if (document.getElementById("seccionBeneficiarios").hidden === false) {
        cargarBeneficiarios();
    } else if (
        document.getElementById("seccionEstados").hidden === false
    ) {
        cargarEstados();
    }
});
async function iniciar() {
    try {
        const respuesta = await fetch("/api/auth/me", {
            credentials: "same-origin"
        });

        if (respuesta.ok) {
            mostrarPanel(await respuesta.json());
        } else {
            mostrarLogin();
        }
    } catch {
        mostrarLogin();
        mostrarMensaje("No se pudo conectar con el servidor.", "error");
    }
}

iniciar();
