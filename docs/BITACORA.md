Segunda tarea BDD por Marco Angulo y Jose Julián Gomez.

# 30/9/26 - Creación del git
Se inicializó el git, nada más.

# 2/10/26 - Primera Reunión 
## 5:00 pm - 6:00 pm
El proposito de esta reuntion es definir las herramientas que se usarán para la tarea. Las herramientas definidas por el momento:
* [Java] - Lenguaje backend
* [Springboot] - Java Framework
* [Docker] - Principalmente para poder levantar la DB desde linux
# 5/10/26 - Inicialización del proyecto
## 2:00 pm - 5:00 pm
Se definió la estructura que iba a llevar el proyecto, trabajamos por módulos, almacenando cada dto, service, controller, repositoy, en el directorio de su módulo respectivo, con la intención de tener más orden si la tarea se usa para otras instancias posteriores.
Se instaló el software necesario.

# 7/10/26 
## Marco - 2:30 pm 11:00 pm
### Login y Scripts DB
Se implementó el login, como no existe frontend, se probó mediante curls. 
![[media/login.png]]

Se crearon los scripts para las tablas y para poblar la base de datos con los xmls proporcionados por los otros estudiantes. También las SP de autenticación.

### Problemas
Tuvimos un [problema de comunicación] que resultó en [trabajo desperdiciado]. Marco avisó que iba a trabajar en autenticación, usuarios y login, pero dijo nada al respecto de trabajar con scripts de  DB. Jose Julián trabajó precisamente en los scripts de la DB. De ahora en adelante ambos debemos o bien, repartir claramente el trabajo, o avisar con tiempo, en que módulos trabajaremos. Además, los compañeros pasaron los xmls mal


# 8/10/26
## José Julián - 4:20 pm - 4:40 pm
###  Actualización de archivos XML

Se recibieron los archivos XML corregidos proporcionados por los otros estudiantes y se compararon con los que se estaban utilizando anteriormente en el proyecto.

Se encontraron algunos cambios en los datos de las cuentas, beneficiarios, estados de cuenta y permisos de acceso. También se corrigieron algunos nombres de atributos en los catálogos.

Se reemplazaron los archivos `catalogos.xml` y `no_catalogos.xml` en la carpeta `db/datos/` por las nuevas versiones.

#### Problemas

Los archivos XML proporcionados inicialmente contenían errores y diferencias con los datos esperados, por lo que fue necesario esperar a que se enviaran las versiones corregidas.

Al comparar los archivos, se encontraron modificaciones en las relaciones de beneficiarios, propietarios de cuentas, estados de cuenta y permisos de acceso de usuarios.

También se identificaron diferencias en los nombres de algunos atributos, lo que podría causar problemas al ejecutar los procedimientos almacenados encargados de cargar los datos.

#### Pendiente

Revisar y adaptar los procedimientos almacenados de carga para asegurar que sean compatibles con los XML corregidos. Posteriormente, realizar las pruebas de inserción en SQL Server para verificar que los datos se carguen correctamente.
## José Julián - 4:45 - 5:19
### Corrección de procedimientos de carga XML

Se inició la adaptación de los procedimientos almacenados de carga para trabajar con los archivos XML corregidos.

Se modificó `sp_CargarCatalogos` para mejorar la lectura de los atributos de los tipos de cuenta y de las operaciones de bitácora, respetando los nombres utilizados en los archivos recibidos.

#### Problemas

El procedimiento anterior utilizaba `COALESCE` para leer atributos XML con diferentes nombres. Se identificó que este método podía producir problemas al intentar convertir atributos inexistentes.

También se comprobó que los atributos de las operaciones de bitácora se encuentran en minúsculas (`id` y `nombre`), por lo que se ajustó su lectura.

#### Pendiente

Revisar la carga de las entidades no catálogo y ejecutar pruebas en SQL Server para verificar el funcionamiento de los procedimientos.

## José Julián - 5:20 - 6:20
### Pruebas de carga XML

Se inició Docker y se configuró SQL Server 2022 para realizar las pruebas de los procedimientos almacenados.

Se creó la base de datos `AhorrosDB` y se ejecutaron los cuatro scripts SQL del proyecto. Se comprobó que se crearon correctamente las 12 tablas y los 5 procedimientos almacenados.

Se ejecutó `sp_CargarCatalogos` con el XML corregido, insertando 27 registros. Después se ejecutó `sp_CargarDatos`, insertando 615 registros entre personas, cuentas, beneficiarios, estados de cuenta, usuarios y permisos.

Se verificaron las cantidades de registros almacenados y se ejecutaron ambos procedimientos por segunda vez para comprobar que no duplicaran datos. Las dos pruebas terminaron correctamente, sin insertar registros adicionales.

#### Problemas encontrados

No se encontraron errores durante la ejecución de los procedimientos de carga.

## Marco 4:20 - 9:50
### Beneficiarios
Para esta sesión tenía planeado iniciar con el módulo de beneficiarios. Como escribir el módulo en sí, es un proceso relativamente fácil, pero bastante tedioso, pues solo toma tiempo ver la estructura del objeto, y crear el resto de clases habituales (`dto, repository, controller, etc.`) con respecto a eso. 
Lo que si resulta un tanto más complicado, son las SP, pues es un área de trabajo nueva. Se creó el `05_sp_beneficiarios`. Ningún problema al respecto.

### API Exception Handler
Se implementó el handler de excepciones de la API.

![[media/beneficiarios.png]]

De nuevo, un curl mostrando el listado de los 3 beneficiarios de la cuenta `jaguero`. Al intentar agregar uno nuevo, avisa que ya tiene 3.
### Problemas
Tuve que hacer el merge de las branches del git manualmente. Fue mi primera vez entonces se me dificultó un poco, luego entendí como aceptar los cambios fácilmente y no hubo más problemas
También, al acutalizar el xml, tuve que rehacer mi base de datos, Al volver a correr todos los scripts, absolutamente todo me dio error, estuve a nada de apagar mi computadora e irme a dormir. Por suerte lo volví a correr y funcionó sin cambiar nada, por suerte.