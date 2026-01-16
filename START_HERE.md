# 🚀 Thalamus v1.0.0 - START HERE

**La forma más rápida de probar Thalamus v1.0.0 con Docker**

---

## ⚡ Quick Start (2 comandos)

```bash
# 1. Ejecutar el script de inicio
./docker-start.sh

# 2. Abrir dashboard
open http://localhost:4100/dashboard
```

**¡Eso es todo!** 🎉

---

## 📋 ¿Qué hace esto?

El script `docker-start.sh` automáticamente:

1. ✅ Verifica que Docker esté instalado
2. ✅ Levanta PostgreSQL en puerto **5532**
3. ✅ Levanta Redis en puerto **6479**
4. ✅ Levanta Thalamus en puerto **4100**
5. ✅ Levanta Adminer (DB UI) en puerto **8180**
6. ✅ Levanta Redis Commander en puerto **8181**
7. ✅ Ejecuta migraciones de base de datos
8. ✅ Verifica que todo esté funcionando
9. ✅ Te muestra las URLs de acceso

**Tiempo estimado:** 1-2 minutos la primera vez (descarga imágenes)

---

## 🌐 URLs de Acceso

Una vez que esté corriendo:

| Servicio | URL | Descripción |
|----------|-----|-------------|
| **Dashboard** | http://localhost:4100/dashboard | Panel principal de Thalamus |
| **Login** | http://localhost:4100/login | Página de inicio de sesión |
| **Email Preview** | http://localhost:4100/dev/mailbox | Ver emails capturados |
| **API Keys** | http://localhost:4100/dashboard/api-keys | Gestión de API keys 🆕 |
| **Settings** | http://localhost:4100/dashboard/settings | Configuración de usuario 🆕 |
| **Adminer** | http://localhost:8180 | UI para PostgreSQL |
| **Redis Commander** | http://localhost:8181 | UI para Redis |

---

## 🧪 Probar las Nuevas Funcionalidades v1.0.0

### 1. Email Service

```bash
# Abrir preview de emails
open http://localhost:4100/dev/mailbox

# Enviar un email de prueba (en IEx):
docker-compose exec thalamus iex -S mix

# Dentro de IEx, ejecuta:
alias Thalamus.Emails.UserEmail
alias Thalamus.Mailer
user = %{email: "test@example.com", full_name: "Usuario Prueba"}
UserEmail.welcome(user) |> Mailer.deliver()
```

Luego visita http://localhost:4100/dev/mailbox para ver el email.

### 2. API Keys Management UI

1. Ve a: http://localhost:4100/dashboard/api-keys
2. Click "New API Key"
3. Llena el formulario y selecciona scopes
4. **¡Copia la clave! Solo se muestra una vez**
5. Prueba usarla:

```bash
export API_KEY="ak_dev_..."  # Tu API key generada

curl -H "Authorization: ApiKey $API_KEY" \
  http://localhost:4100/api/clients
```

### 3. Settings Page

1. Ve a: http://localhost:4100/dashboard/settings
2. Prueba las 3 pestañas:
   - **Profile:** Actualiza nombre y email
   - **Security:** Cambia contraseña
   - **Preferences:** Cambia tema (Light/Dark/System)

---

## 🛠️ Comandos Útiles

```bash
# Ver logs en tiempo real
docker-compose logs -f thalamus

# Ver todos los logs
docker-compose logs -f

# Ver estado de servicios
docker-compose ps

# Acceder a IEx console
docker-compose exec thalamus iex -S mix

# Ejecutar migraciones
docker-compose exec thalamus mix ecto.migrate

# Detener servicios
docker-compose down

# Detener y eliminar datos
docker-compose down -v
```

---

## 🔧 Troubleshooting

### Puerto ocupado

Si ves error de "port already allocated":

**Opción 1:** Detén el otro servicio que usa ese puerto

**Opción 2:** Cambia el puerto en `docker-compose.yml`:
```yaml
ports:
  - "NUEVO_PUERTO:4000"  # Ej: 4200:4000
```

### Servicios no inician

```bash
# Ver logs detallados
docker-compose logs -f

# Reiniciar todo
docker-compose down
docker-compose up -d
```

### Base de datos vacía

```bash
# Ejecutar migraciones manualmente
docker-compose exec thalamus mix ecto.migrate

# Ejecutar seeds
docker-compose exec thalamus mix run priv/repo/seeds.exs
```

---

## 📚 Documentación Completa

- **Guía rápida Docker:** [DOCKER_QUICK_START.md](DOCKER_QUICK_START.md)
- **Guía del Dashboard:** [docs/guides/dashboard-user-guide.md](docs/guides/dashboard-user-guide.md)
- **Configuración Email:** [docs/EMAIL_CONFIGURATION.md](docs/EMAIL_CONFIGURATION.md)
- **Release Notes:** [CHANGELOG_v1.0.0.md](CHANGELOG_v1.0.0.md)
- **Resumen v1.0.0:** [V1_0_0_SUMMARY.md](V1_0_0_SUMMARY.md)
- **Deployment:** [docs/DEPLOYMENT_GUIDE.md](docs/DEPLOYMENT_GUIDE.md)

---

## ❓ FAQ

### ¿Por qué puerto 4100 y no 4000?

Para evitar conflictos con otras instancias de Thalamus u otros servicios que corren en 4000.

### ¿Puedo cambiar los puertos?

Sí, edita `docker-compose.yml` y cambia la sección `ports`:
```yaml
ports:
  - "TU_PUERTO:4000"
```

### ¿Cómo accedo a PostgreSQL?

**Desde tu máquina:**
```bash
psql -h localhost -p 5532 -U postgres -d thalamus_dev
# Password: postgres
```

**Desde Adminer:** http://localhost:8180

### ¿Los datos se pierden al reiniciar?

No. Docker Compose usa volúmenes persistentes:
- `thalamus_postgres_data` - Datos de PostgreSQL
- `thalamus_redis_data` - Datos de Redis

Para eliminar datos: `docker-compose down -v`

---

## 🎯 Siguiente Paso

### Desarrollo Local

Si quieres desarrollar (sin Docker):
```bash
# Instalar dependencias
mix deps.get

# Crear base de datos
mix ecto.create
mix ecto.migrate

# Iniciar servidor
mix phx.server

# Abrir en navegador
open http://localhost:4000
```

### Producción

Para desplegar a producción, sigue: [docs/DEPLOYMENT_GUIDE.md](docs/DEPLOYMENT_GUIDE.md)

---

## 🆘 ¿Necesitas Ayuda?

1. **Revisa los logs:** `docker-compose logs -f`
2. **Consulta:** [DOCKER_QUICK_START.md](DOCKER_QUICK_START.md)
3. **Lee la guía:** [docs/guides/dashboard-user-guide.md](docs/guides/dashboard-user-guide.md)
4. **Issues:** https://github.com/zea/thalamus/issues

---

**¡Feliz prueba de Thalamus v1.0.0! 🚀**
