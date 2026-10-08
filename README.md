# TP2 – Cuenta de Ahorros (Base de Datos 1, ITCR)

API REST en Java + Spring Boot sobre SQL Server (Docker). Toda la lógica de base de datos vive en procedimientos almacenados.

## Requisitos

- Docker y Docker Compose
- JDK 21 (`java -version`)
- Git

No hace falta instalar Maven: el proyecto trae el wrapper `./mvnw`.

## Estructura

```
.
├── docker-compose.yml      # SQL Server 2022
├── .env                    # SA_PASSWORD (no se sube a git)
├── db/                     # scripts SQL, ejecutar en orden numérico
│   ├── 01_schema_auth.sql
│   └── 02_sp_auth.sql
└── app/                    # proyecto Spring Boot (pom.xml, mvnw, src/)
    └── src/main/java/cr/ac/tec/ahorros/
        └── auth/           # módulos por funcionalidad
```

## Puesta en marcha

### 1. Variables de entorno

Crear un archivo `.env` en la raíz con una clave que cumpla la política de SQL Server (mayúscula, minúscula, número y símbolo):

```
SA_PASSWORD=TuClave_Fuerte123
```

### 2. Levantar SQL Server

```bash
docker compose up -d
```

Esperar unos segundos a que arranque y crear la base de datos (solo la primera vez):

```bash
docker exec -it mssql-tp2 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -Q "CREATE DATABASE AhorrosDB"
```

> `$SA_PASSWORD` debe estar exportada en la terminal. Ver el paso 4 para cargarla desde `.env`.

### 3. Cargar los scripts SQL

Desde la raíz del proyecto, en orden:

```bash
for f in db/*.sql; do
  docker exec -i mssql-tp2 /opt/mssql-tools18/bin/sqlcmd \
    -S localhost -U sa -P "$SA_PASSWORD" -C < "$f"
done
```

> Los scripts de esquema no son re-ejecutables (hacen `CREATE TABLE`). Para empezar de cero:
> `docker compose down -v` y repetir desde el paso 2.

### 4. Correr la aplicación

```bash
set -a; source .env; set +a     # carga SA_PASSWORD en la terminal
cd app
./mvnw spring-boot:run
```

La API queda en `http://localhost:8080`.

### 5. Probar el login

```bash
curl -i -c cookies.txt -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"user":"jaguero","pass":"LaFacil"}'

curl -b cookies.txt http://localhost:8080/api/auth/me
curl -b cookies.txt -X POST http://localhost:8080/api/auth/logout
```

Respuestas esperadas: `200` con el usuario en JSON, `401` si las credenciales son inválidas.

> Los usuarios de prueba existen solo después de cargar los datos desde el XML (script de carga pendiente).

## Endpoints actuales

| Método | Ruta               | Descripción                         |
|--------|--------------------|-------------------------------------|
| POST   | `/api/auth/login`  | Inicia sesión (queda en bitácora)   |
| POST   | `/api/auth/logout` | Cierra sesión (queda en bitácora)   |
| GET    | `/api/auth/me`     | Usuario de la sesión actual         |

## Convenciones del proyecto

- **Paquetes por módulo**, no por capa: cada carpeta (`auth`, `beneficiario`, `estadocuenta`...) tiene su controller, repository y DTOs.
- **Cero SQL en Java**: los repositories solo llaman SPs con `SimpleJdbcCall`.
- Los SPs devuelven un código de resultado por `OUTPUT` (`@outResultCode`; `0` = OK).
- Commits pequeños y frecuentes: el historial de GitHub es evidencia de avance para la revisión.

## Problemas comunes

| Síntoma | Causa probable |
|---------|----------------|
| `./mvnw: command not found` o falla el comando | Se está ejecutando fuera de `app/`; hacer `cd app` |
| `Login failed for user 'sa'` | `SA_PASSWORD` no está exportada o no coincide con la del contenedor |
| `Cannot open database "AhorrosDB"` | Falta el `CREATE DATABASE` del paso 2 |
| Error de conexión al arrancar | El contenedor no está listo: `docker ps` y `docker logs mssql-tp2` |
