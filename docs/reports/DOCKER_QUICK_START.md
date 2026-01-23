# 🐳 Docker Quick Start - Thalamus v1.0.0

**Guía rápida para levantar Thalamus con Docker (puertos personalizados)**

---

## 📋 Puertos Configurados

Para evitar conflictos con otras instancias, usamos estos puertos:

| Servicio | Puerto Externo | Puerto Interno | URL de Acceso |
|----------|---------------|----------------|---------------|
| **Thalamus App** | 4100 | 4000 | http://localhost:4100 |
| **PostgreSQL** | 5532 | 5432 | localhost:5532 |
| **Redis** | 6479 | 6379 | localhost:6479 |
| **Adminer (DB UI)** | 8180 | 8080 | http://localhost:8180 |
| **Redis Commander** | 8181 | 8081 | http://localhost:8181 |

---

## 🚀 Inicio Rápido

### 1. Levantar todos los servicios

```bash
# En el directorio raíz de thalamus
docker-compose up -d
```

Esto levantará:
- ✅ PostgreSQL (puerto 5532)
- ✅ Redis (puerto 6479)
- ✅ Thalamus App (puerto 4100)
- ✅ Adminer - UI de PostgreSQL (puerto 8180)
- ✅ Redis Commander - UI de Redis (puerto 8181)

### 2. Ver los logs

```bash
# Ver logs de todos los servicios
docker-compose logs -f

# Ver solo logs de Thalamus
docker-compose logs -f thalamus

# Ver solo logs de PostgreSQL
docker-compose logs -f postgres
```

### 3. Verificar que todo está corriendo

```bash
# Ver contenedores activos
docker-compose ps
```

Deberías ver algo como:
```
NAME                       STATUS         PORTS
thalamus_app              Up             0.0.0.0:4100->4000/tcp
thalamus_postgres         Up (healthy)   0.0.0.0:5532->5432/tcp
thalamus_redis            Up (healthy)   0.0.0.0:6479->6379/tcp
thalamus_adminer          Up             0.0.0.0:8180->8080/tcp
thalamus_redis_commander  Up             0.0.0.0:8181->8081/tcp
```

---

## 🔍 Acceder a los Servicios

### Thalamus Application
```bash
# Dashboard principal
open http://localhost:4100/dashboard

# Login page
open http://localhost:4100/login

# Health check
curl http://localhost:4100/api/public/health
```

**Credenciales por defecto:**
- Email: `admin@zea.com`
- Password: (la que se configuró en seeds)

### Email Preview (Mailbox)
```bash
# Ver emails capturados en desarrollo
open http://localhost:4100/dev/mailbox
```

### Adminer (PostgreSQL UI)
```bash
open http://localhost:8180
```

**Credenciales de conexión:**
- System: `PostgreSQL`
- Server: `postgres`
- Username: `postgres`
- Password: `postgres`
- Database: `thalamus_dev`

### Redis Commander
```bash
open http://localhost:8181
```

Automáticamente conectado a Redis.

---

## 🛠️ Comandos Útiles

### Ejecutar comandos en el contenedor

```bash
# IEx console
docker-compose exec thalamus iex -S mix

# Mix commands
docker-compose exec thalamus mix ecto.migrate
docker-compose exec thalamus mix run priv/repo/seeds.exs

# Shell en el contenedor
docker-compose exec thalamus sh
```

### Resetear la base de datos

```bash
# Bajar servicios
docker-compose down

# Eliminar volúmenes (¡CUIDADO! Borra todos los datos)
docker volume rm thalamus_postgres_data thalamus_redis_data

# Levantar de nuevo (creará BD desde cero)
docker-compose up -d
```

### Reconstruir la imagen

```bash
# Si cambias código y quieres reconstruir
docker-compose build thalamus

# O forzar reconstrucción completa
docker-compose build --no-cache thalamus
```

### Ver uso de recursos

```bash
# Ver uso de CPU/memoria
docker stats
```

---

## 🧪 Probar las Nuevas Funcionalidades v1.0.0

### 1. Probar Email Service

```bash
# Abrir mailbox
open http://localhost:4100/dev/mailbox

# En IEx, enviar un email de prueba:
docker-compose exec thalamus iex -S mix

# Dentro de IEx:
alias Thalamus.Emails.UserEmail
alias Thalamus.Mailer

user = %{email: "test@example.com", full_name: "Usuario Prueba"}
UserEmail.welcome(user) |> Mailer.deliver()
```

Luego visita http://localhost:4100/dev/mailbox para ver el email.

### 2. Probar API Keys UI

1. Navega a: http://localhost:4100/dashboard/api-keys
2. Click "New API Key"
3. Llena el formulario:
   - Name: "Test API Key"
   - Description: "Testing API key creation"
   - Selecciona scopes: `clients:read`, `clients:write`
4. Click "Generate API Key"
5. **Copia la clave completa** (se muestra solo una vez!)
6. Prueba usar el API key:

```bash
# Guarda el API key
export API_KEY="ak_dev_..."

# Lista OAuth2 clients usando el API key
curl -H "Authorization: ApiKey $API_KEY" \
  http://localhost:4100/api/clients
```

### 3. Probar Settings Page

1. Navega a: http://localhost:4100/dashboard/settings
2. Prueba cada pestaña:
   - **Profile:** Actualiza nombre y email
   - **Security:** Cambia contraseña
   - **Preferences:** Cambia tema (Light/Dark/System)

### 4. Probar OAuth2 Flow

```bash
# 1. Crear un cliente OAuth2 via UI
# http://localhost:4100/dashboard/clients → New Client

# 2. Obtener authorization code (abre en navegador):
http://localhost:4100/oauth/authorize?client_id=<CLIENT_ID>&redirect_uri=http://localhost:4100/&response_type=code&scope=openid%20profile%20email

# 3. Intercambiar code por token
curl -X POST http://localhost:4100/oauth/token \
  -H "Content-Type: application/json" \
  -d '{
    "grant_type": "authorization_code",
    "code": "<CODE_FROM_STEP_2>",
    "client_id": "<CLIENT_ID>",
    "client_secret": "<CLIENT_SECRET>",
    "redirect_uri": "http://localhost:4100/"
  }'
```

---

## 🔧 Troubleshooting

### Error: "port is already allocated"

Si ves este error, significa que el puerto está siendo usado por otro proceso.

**Solución 1:** Detén el otro servicio que usa ese puerto

**Solución 2:** Cambia el puerto en `docker-compose.yml`:
```yaml
ports:
  - "NUEVO_PUERTO:4000"  # Cambia NUEVO_PUERTO por ej: 4200
```

### Error: "Cannot connect to database"

```bash
# Verifica que PostgreSQL esté corriendo
docker-compose ps postgres

# Ver logs de PostgreSQL
docker-compose logs postgres

# Reiniciar PostgreSQL
docker-compose restart postgres
```

### Error: "Mix dependencies not found"

```bash
# Reinstalar dependencias
docker-compose exec thalamus mix deps.get
docker-compose exec thalamus mix deps.compile
```

### Contenedor no inicia (crash loop)

```bash
# Ver logs detallados
docker-compose logs -f thalamus

# Verificar health checks
docker-compose ps

# Reiniciar desde cero
docker-compose down
docker-compose up -d
```

### Base de datos vacía (no hay tablas)

```bash
# Ejecutar migraciones
docker-compose exec thalamus mix ecto.migrate

# Ejecutar seeds
docker-compose exec thalamus mix run priv/repo/seeds.exs
```

---

## 🧹 Limpieza

### Detener servicios

```bash
# Detener pero mantener volúmenes
docker-compose down

# Detener y eliminar volúmenes (borra datos)
docker-compose down -v
```

### Limpiar todo (completo)

```bash
# Eliminar contenedores, redes y volúmenes
docker-compose down -v

# Eliminar imágenes también
docker-compose down -v --rmi all

# Limpiar sistema completo Docker
docker system prune -a --volumes
```

---

## 📊 Verificación de Health

### Check rápido de todos los servicios

```bash
# Script de verificación
echo "=== Thalamus Health Check ==="
echo ""
echo "🔹 Thalamus App:"
curl -s http://localhost:4100/api/public/health | jq .
echo ""
echo "🔹 PostgreSQL:"
docker-compose exec postgres pg_isready
echo ""
echo "🔹 Redis:"
docker-compose exec redis redis-cli -a redis_password ping
echo ""
echo "=== Dashboard URLs ==="
echo "📱 Thalamus:        http://localhost:4100"
echo "📱 Mailbox:         http://localhost:4100/dev/mailbox"
echo "📱 Adminer:         http://localhost:8180"
echo "📱 Redis Commander: http://localhost:8181"
```

---

## 🎯 URLs de Acceso Rápido

**Copiar y pegar en el navegador:**

```
# Dashboard Principal
http://localhost:4100/dashboard

# Login
http://localhost:4100/login

# OAuth2 Clients
http://localhost:4100/dashboard/clients

# API Keys
http://localhost:4100/dashboard/api-keys

# Settings
http://localhost:4100/dashboard/settings

# Email Preview
http://localhost:4100/dev/mailbox

# Adminer (DB)
http://localhost:8180

# Redis Commander
http://localhost:8181
```

---

## 🚀 ¡Listo para Probar!

Ya tienes Thalamus v1.0.0 corriendo en Docker con todos los servicios funcionando.

**Siguiente paso:** Prueba todas las nuevas funcionalidades (Email, API Keys, Settings)

**¿Problemas?** Revisa la sección de Troubleshooting o los logs con `docker-compose logs -f`
