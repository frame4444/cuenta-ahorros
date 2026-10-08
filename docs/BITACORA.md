![[login.png]]Segunda tarea BDD por Marco Angulo y Jose Julián Gomez.

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

# 7/10/26 - Login y Scripts DB
## Marco - 2:30 pm 11:00 pm
Se implementó el login, como no existe frontend, se probó mediante curls. 
![[media/login.png]]

Se crearon los scripts para las tablas y para poblar la base de datos con los xmls proporcionados por los otros estudiantes. También las SP de autenticación.

## Problemas
Tuvimos un [problema de comunicación] que resultó en [trabajo desperdiciado]. Marco avisó que iba a trabajar en autenticación, usuarios y login, pero dijo nada al respecto de trabajar con scripts de  DB. Jose Julián trabajó precisamente en los scripts de la DB. De ahora en adelante ambos debemos o bien, repartir claramente el trabajo, o avisar con tiempo, en que módulos trabajaremos.


# 8/10/26 - Actualización de archivos XML
## José Julián - 4:20 pm - 4:40

Se recibieron los archivos XML corregidos proporcionados por los otros estudiantes y se compararon con los que se estaban utilizando anteriormente en el proyecto.

Se encontraron algunos cambios en los datos de las cuentas, beneficiarios, estados de cuenta y permisos de acceso. También se corrigieron algunos nombres de atributos en los catálogos.

Se reemplazaron los archivos `catalogos.xml` y `no_catalogos.xml` en la carpeta `db/datos/` por las nuevas versiones.

## Problemas

Los archivos XML proporcionados inicialmente contenían errores y diferencias con los datos esperados, por lo que fue necesario esperar a que se enviaran las versiones corregidas.

Al comparar los archivos, se encontraron modificaciones en las relaciones de beneficiarios, propietarios de cuentas, estados de cuenta y permisos de acceso de usuarios.

También se identificaron diferencias en los nombres de algunos atributos, lo que podría causar problemas al ejecutar los procedimientos almacenados encargados de cargar los datos.

## Pendiente

Revisar y adaptar los procedimientos almacenados de carga para asegurar que sean compatibles con los XML corregidos. Posteriormente, realizar las pruebas de inserción en SQL Server para verificar que los datos se carguen correctamente.