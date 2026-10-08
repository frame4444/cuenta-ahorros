# Bitácora de desarrollo - TP2

## 07/10/2026 - JJ - Creación de tablas de catálogos 8:15 pm

**Tarea:** Implementación inicial de las tablas de catálogos en SQL Server.

**Descripción:** Se preparó el script SQL para crear las tablas TipoDocuIdentidad, TipoMoneda, Parentezco y TipoCuentaAhorro.

Se definieron las primary keys de los catálogos sin utilizar IDENTITY. Además, se estableció la relación entre TipoCuentaAhorro y TipoMoneda mediante una foreign key.

**Archivos agregados:**
- `app/src/main/resources/sql/01_catalogos.sql`

**Estado:** Pendiente de ejecución y validación en SQL Server.

## 07/10/2026 - JJ - Creación de tablas principales 11:15 pm

**Tarea:** Implementación inicial de las tablas Persona, Cuenta y EstadoCuenta.

**Descripción:**

Se preparó el segundo script SQL para definir las entidades principales del sistema de cuentas de ahorro.

Se implementaron las siguientes estructuras:

- **Persona:** almacena la información personal, identificación, fecha de nacimiento, correo electrónico y teléfonos.
- **Cuenta:** almacena el número de cuenta, propietario, tipo de cuenta, fecha de creación y saldo.
- **EstadoCuenta:** almacena la información general de los estados de cuenta, incluyendo fechas y saldos.

Se utilizaron primary keys mediante IDENTITY y se establecieron relaciones utilizando foreign keys

**Archivos agregados:**
- `app/src/main/resources/sql/02_tablas_principales.sql`

**Dependencias:**
- Requiere la creación previa de las tablas de catálogos.

**Estado:** Código preparado. Pendiente de ejecución y pruebas en SQL Server.

**Ajuste del diseño:** Se revisó la tabla TipoCuentaAhorro y se incorporaron los atributos relacionados con las transferencias SINPE Móvil. También se ajustaron los nombres de los campos correspondientes al cargo mensual y a la tasa de interés mensual para reflejar los requerimientos funcionales del proyecto.

**Validación:** Pendiente de ejecución en SQL Server.