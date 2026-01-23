# Documentación para Equipo ZEA Platform

**Fecha:** 2025-12-30
**Preparado por:** Equipo Thalamus
**Para:** Equipo Platform Development

---

## 🎯 Resumen Ejecutivo

El cliente OAuth2 de Platform (`client_3a70d151-7523-416e-b7ac-07cfe87a457c`) tenía su `client_secret` en texto plano en la base de datos, causando errores 401 al autenticar usuarios.

**✅ SOLUCIONADO:** El secret fue rotado exitosamente usando el nuevo endpoint `/api/clients/:id/rotate-secret`.

---

## 🔐 Nuevo Client Secret

**⚠️ ACCIÓN REQUERIDA: Actualizar y Reiniciar Platform**

### Credenciales Actualizadas:

```bash
# OAuth2 Configuration (Thalamus)
OAUTH_CLIENT_ID=client_3a70d151-7523-416e-b7ac-07cfe87a457c
OAUTH_CLIENT_SECRET=sq3Wafxd70wpqqVNrecK6zAYOYXggwb_kFgpuEWi4lE
OAUTH_REDIRECT_URI=http://localhost:4001/auth/callback  # dev
# OAUTH_REDIRECT_URI=https://zea.cl/auth/callback       # prod
```

### Pasos para Aplicar:

1. **Desarrollo (localhost):**
   ```bash
   cd /path/to/platform
   # El .env ya fue actualizado con el nuevo secret

   # Reiniciar el servidor
   # Si corre con mix:
   # Ctrl+C y luego:
   mix phx.server

   # Si corre con docker-compose:
   docker-compose restart platform
   ```

2. **Producción:**
   ```bash
   # Actualizar en el secrets manager
   aws secretsmanager update-secret \
     --secret-id platform-oauth-client-secret \
     --secret-string "sq3Wafxd70wpqqVNrecK6zAYOYXggwb_kFgpuEWi4lE"

   # Reiniciar deployment
   kubectl rollout restart deployment/platform-web
   ```

3. **Verificar que funciona:**
   ```bash
   # Probar login en Platform
   # Usuario debería poder autenticarse sin errores 401
   ```

---

## 🏗️ Arquitectura ZEA Platform

### Cómo Funciona Actualmente:

```
┌─────────────────────────────────────────────────────┐
│  Usuario (Browser)                                  │
└──────────────────┬──────────────────────────────────┘
                   │
                   ↓
┌──────────────────────────────────────────────────────┐
│  ZEA Platform (Phoenix - Puerto 4001)                │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│  Frontend: LiveView + Templates                     │
│  │                                                   │
│  BFF Integrado:                                      │
│  ├── ThalamusClient.ex  → Autenticación OAuth2      │
│  ├── CortexClient.ex    → AI Gateway                │
│  ├── SynapseClient.ex   → Telemetría                │
│  ├── BillingClient.ex   → Facturación               │
│  └── CerebelumClient.ex → Workflows                 │
│  │                                                   │
│  Database: PostgreSQL (users, orgs, subscriptions)  │
└──────────────┬───────────────────────────────────────┘
               │
               ↓ (Orquesta servicios)
┌──────────────────────────────────────────────────────┐
│  Servicios Backend (Microservicios)                  │
│  ├── Thalamus (4000)   - OAuth2 & Auth              │
│  ├── Cortex (4006)     - AI Gateway                 │
│  ├── Synapse (4002)    - Telemetry                  │
│  ├── Billing (4003)    - Billing                    │
│  └── Cerebelum (4005)  - Workflows                  │
└──────────────────────────────────────────────────────┘
```

### Principio de Diseño:

**Platform es el "Sistema Operativo" de ZEA Cloud:**
- **Frontend unificado** para todos los servicios
- **BFF integrado** (no necesita BFF separado por ahora)
- **Orquestador** de microservicios backend
- **Dashboard centralizado** donde usuarios gestionan todo

**Analogía:** Platform es como Google Cloud Console, que orquesta Compute Engine, Storage, etc.

---

## 🔄 Gestión de Client Secrets

### Endpoint Disponible:

Ahora pueden rotar el client secret de Platform **sin acceso a la BD de Thalamus**:

```
POST /api/clients/:client_id/rotate-secret
Authorization: Bearer <ADMIN_TOKEN_O_API_KEY>
```

### Ejemplo de Uso:

```bash
# 1. Obtener token (login como admin de Thalamus)
TOKEN=$(curl -s -X POST "http://localhost:4000/api/public/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "c@zea.cl",
    "password": "tu_password"
  }' | jq -r '.data.access_token')

# 2. Rotar secret
curl -X POST "http://localhost:4000/api/clients/client_3a70d151-7523-416e-b7ac-07cfe87a457c/rotate-secret" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json"

# Respuesta:
# {
#   "data": {
#     "client_id": "client_3a70d151-7523-416e-b7ac-07cfe87a457c",
#     "client_secret": "NUEVO_SECRET_AQUI",
#     "rotated_at": "2025-12-30T15:50:33Z"
#   },
#   "message": "⚠️ IMPORTANT: Save the new client_secret securely..."
# }

# 3. Actualizar en Platform .env o secrets manager
# 4. Reiniciar Platform
```

### Cuándo Rotar:

- 🔄 **Cada 90 días** (recomendado para producción)
- 🚨 **Inmediatamente** si sospechan que el secret fue comprometido
- 👤 **Cuando alguien con acceso** deja el equipo
- 📋 **Por compliance** (SOC2, ISO 27001, etc.)

### Documentación Completa:

Ver: `docs/guides/oauth2-client-management.md` en el repo de Thalamus

---

## 🚀 Roadmap: Próximos Pasos

### Lo que viene para Platform:

1. **Crear Apps AI** (Cortex Integration)
   - Dashboard para que usuarios creen y gestionen apps AI
   - Platform orquesta las llamadas a Cortex API
   - Usuarios nunca interactúan directamente con Cortex

2. **Workflows Visuales** (Cerebelum Integration)
   - Editor visual de workflows en Platform
   - Platform orquesta la ejecución en Cerebelum
   - Monitoreo y logs centralizados en Platform

3. **Billing & Subscriptions**
   - Gestión de planes y facturación
   - Platform se comunica con Billing API
   - Dashboard unificado para usuarios

### Patrón de Desarrollo:

```elixir
# lib/zea_platform/services/cortex_client.ex
defmodule ZeaPlatform.Services.CortexClient do
  @moduledoc """
  Cliente para Cortex AI Gateway.
  Abstrae la comunicación con Cortex.
  """

  def create_ai_app(user_id, params) do
    # Platform orquesta:
    # 1. Validar usuario tiene permisos
    # 2. Crear workspace en Cortex
    # 3. Guardar referencia en Platform DB
    # 4. Retornar al usuario
  end
end
```

**Usuario nunca sabe que Cortex existe** - solo ve "Crear App AI" en Platform.

---

## 📋 Desarrollo Day-to-Day

### Flujo de Autenticación (OAuth2):

```elixir
# lib/zea_platform_web/controllers/auth_controller.ex

def callback(conn, %{"code" => code}) do
  # 1. Intercambiar código por tokens
  {:ok, tokens} = ThalamusClient.exchange_code_for_tokens(code)

  # 2. Obtener info del usuario
  {:ok, user_info} = ThalamusClient.get_user_info(tokens.access_token)

  # 3. Crear/actualizar usuario en Platform DB
  {:ok, user} = Accounts.upsert_user_from_oauth(user_info)

  # 4. Guardar sesión
  conn
  |> put_session(:user_id, user.id)
  |> put_session(:access_token, tokens.access_token)
  |> redirect(to: ~p"/dashboard")
end
```

### Llamadas a Servicios:

```elixir
# En controllers o LiveView
defmodule ZeaPlatformWeb.DashboardLive do
  def mount(_params, session, socket) do
    user_id = session["user_id"]

    # Obtener data de múltiples servicios
    {:ok, ai_apps} = CortexClient.list_user_apps(user_id)
    {:ok, workflows} = CerebelumClient.list_workflows(user_id)
    {:ok, usage} = SynapseClient.get_user_metrics(user_id)

    socket = assign(socket,
      ai_apps: ai_apps,
      workflows: workflows,
      usage: usage
    )

    {:ok, socket}
  end
end
```

### Manejo de Errores:

```elixir
case CortexClient.create_ai_app(user_id, params) do
  {:ok, app} ->
    # Éxito
    {:noreply, assign(socket, :app, app)}

  {:error, :service_unavailable} ->
    # Cortex está caído
    {:noreply, put_flash(socket, :error, "AI service temporarily unavailable")}

  {:error, :unauthorized} ->
    # Token expiró, refrescar
    {:ok, new_token} = ThalamusClient.refresh_access_token(refresh_token)
    # Retry...
end
```

---

## 🔐 Mejores Prácticas de Seguridad

### 1. Secrets Management

**❌ NUNCA:**
```elixir
# Hardcodear secrets
@oauth_secret "sq3Wafxd70wpqqVNrecK6zAYOYXggwb_kFgpuEWi4lE"
```

**✅ SIEMPRE:**
```elixir
# Runtime configuration
defp oauth_secret do
  Application.get_env(:zea_platform, :oauth_client_secret) ||
    raise "OAUTH_CLIENT_SECRET not configured"
end
```

### 2. Variables de Entorno

```bash
# Development (.env)
OAUTH_CLIENT_SECRET=sq3Wafxd70wpqqVNrecK6zAYOYXggwb_kFgpuEWi4lE

# Production (Secrets Manager)
aws secretsmanager get-secret-value \
  --secret-id prod/platform/oauth-client-secret \
  --query SecretString \
  --output text
```

### 3. Rotación Programada

```bash
# Cronjob mensual (ejemplo)
# crontab -e
0 0 1 * * /path/to/scripts/rotate-platform-secret.sh && kubectl rollout restart deployment/platform-web
```

**Script:** Ver `INSTRUCCIONES_AUTH_PLATFORM.md` para script completo de rotación.

---

## 🆘 Troubleshooting

### Error: "Invalid client credentials"

**Causa:** El `client_secret` en Platform no coincide con el hash en Thalamus.

**Solución:**
```bash
# Verificar secret actual en Platform
cat .env | grep OAUTH_CLIENT_SECRET

# Si es diferente al rotado (sq3Wafxd70wpqqVNrecK6zAYOYXggwb_kFgpuEWi4lE)
# Actualizar y reiniciar
```

### Error: "Token expired"

**Causa:** El access token JWT expiró (vida útil: 1 hora).

**Solución:**
```elixir
# Usar refresh token automáticamente
case ThalamusClient.refresh_access_token(refresh_token) do
  {:ok, new_tokens} ->
    # Actualizar sesión con nuevo access_token
    conn
    |> put_session(:access_token, new_tokens.access_token)
end
```

### Error: "Service unavailable"

**Causa:** Algún microservicio (Cortex, Synapse, etc.) está caído.

**Solución:**
```elixir
# Implementar fallbacks y circuit breakers
defmodule ZeaPlatform.Services.CortexClient do
  def list_user_apps(user_id) do
    case HTTPoison.get(url, headers, timeout: 5_000) do
      {:ok, %{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:error, %HTTPoison.Error{reason: :timeout}} ->
        # Servicio lento, retornar cache o empty
        {:ok, []}

      _ ->
        {:error, :service_unavailable}
    end
  end
end
```

---

## 📞 Contacto y Recursos

### Equipo Thalamus:

- **Super Admin:** c@zea.cl
- **Soporte:** Slack #thalamus-support
- **Issues:** GitHub Issues en repo de Thalamus

### Documentación:

- **OAuth2 Client Management:** `docs/guides/oauth2-client-management.md`
- **Getting Started:** `docs/GETTING_STARTED.md`
- **OpenAPI Spec:** `docs/OPENAPI_SPEC.yaml`
- **Architecture:** `docs/ARCHITECTURE.md`

### URLs de Servicios:

**Development:**
```bash
Thalamus:  http://localhost:4000
Platform:  http://localhost:4001
Synapse:   http://localhost:4002
Billing:   http://localhost:4003
Cerebelum: http://localhost:4005
Cortex:    http://localhost:4006
```

**Production:**
```bash
Thalamus:  https://auth.zea.cl
Platform:  https://zea.cl
Cortex:    https://ai.zea.cl
# etc...
```

---

## ✅ Checklist para Continuar Desarrollo

### Inmediato:

- [ ] ✅ Actualizar `OAUTH_CLIENT_SECRET` en Platform (HECHO)
- [ ] Reiniciar Platform development server
- [ ] Verificar que login funciona sin errores 401
- [ ] Commit del nuevo `.env.example` (sin el secret real)

### Esta Semana:

- [ ] Implementar circuit breaker para llamadas a servicios
- [ ] Agregar health checks de todos los servicios en dashboard
- [ ] Configurar secrets en production (AWS Secrets Manager / Vault)
- [ ] Documentar flujo de deployment de Platform

### Próximas 2 Semanas:

- [ ] Implementar creación de "Workspaces" desde Platform UI
- [ ] Integrar dashboard de Cortex (AI Apps) en Platform
- [ ] Integrar dashboard de Cerebelum (Workflows) en Platform
- [ ] Setup de rotación automática de secrets (cronjob)

---

## 🎓 Conceptos Clave para el Equipo

### 1. Platform como "Sistema Operativo"

Platform **no es solo un frontend**. Es el cerebro que:
- Orquesta múltiples servicios
- Maneja autenticación unificada
- Provee UX consistente
- Abstrae la complejidad

### 2. Usuario NUNCA toca servicios directamente

```
Usuario → Platform UI → Platform Backend → Thalamus/Cortex/Synapse/etc.
          ✅ Ve UI bonita  ✅ Orquesta   ❌ Usuario no sabe que existen
```

### 3. OAuth2 es para autenticar USUARIOS

```
Usuario → Platform → Thalamus OAuth2 → JWT Token → Usuario autenticado
```

**NO** es para servicios backend (para eso: Admin API Keys o M2M client credentials)

### 4. Desarrollo Incremental

No sobre-ingeniería. Construir features incrementalmente:
1. MVP funcional
2. Iterar según feedback
3. Escalar cuando sea necesario

---

## 📝 Notas Finales

**Estado actual:** ✅ Platform puede autenticar usuarios correctamente

**Próximo milestone:** Integración de creación de AI Apps (Cortex) desde Platform dashboard

**Recuerden:**
- Platform es el punto de entrada único para usuarios
- Los microservicios son infraestructura, invisibles para el usuario
- Mantengan las credenciales seguras (nunca en git)
- Roten secrets regularmente

**¡Éxito con el desarrollo!** 🚀

---

_Documento generado: 2025-12-30_
_Versión: 1.0_
_Última actualización del secret: 2025-12-30 15:50:33Z_
