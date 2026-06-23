# Tutorial: Integración Completa con Thalamus

**Basado en el código real de Thalamus** | Última actualización: 2026-01-23

Este tutorial te guiará paso a paso para integrar tu aplicación con Thalamus, analizando el código fuente real para entender exactamente cómo funciona.

---

## 📋 Tabla de Contenidos

1. [Entendiendo Thalamus desde el Código](#1-entendiendo-thalamus-desde-el-código)
2. [Endpoints Disponibles](#2-endpoints-disponibles)
3. [Flujo 1: Authorization Code (Para Usuarios)](#3-flujo-1-authorization-code)
4. [Flujo 2: Client Credentials (Máquina a Máquina)](#4-flujo-2-client-credentials-m2m)
5. [Validación de Tokens](#5-validación-de-tokens)
6. [Auto-registro con Admin API Keys](#6-auto-registro-con-admin-api-keys)
7. [Implementación Práctica](#7-implementación-práctica)
8. [Troubleshooting](#8-troubleshooting)

---

## 1. Entendiendo Thalamus desde el Código

### 1.1 Estructura de Rutas (Código Real)

Analicemos `lib/thalamus_web/router.ex` para ver qué endpoints están disponibles:

```elixir
# OAUTH2 ENDPOINTS (Sin autenticación previa)
scope "/oauth", ThalamusWeb.OAuth2 do
  # Authorization Code Flow
  get "/authorize", AuthorizationController, :new        # Pantalla de login
  post "/authorize", AuthorizationController, :create    # Procesar consentimiento

  # Token Management
  post "/token", TokenController, :create                # Obtener tokens
  post "/introspect", IntrospectionController, :create   # Validar tokens
  post "/revoke", RevocationController, :create          # Revocar tokens
  get "/userinfo", UserinfoController, :show             # Info del usuario (OpenID Connect)

  # Agent Tokens (Avanzado)
  post "/agent-token", AgentTokenController, :create     # Tokens para agentes
end

# API PÚBLICA (Sin autenticación)
scope "/api/public", ThalamusWeb.API do
  get "/health", HealthController, :index                # Health check
  post "/register", RegistrationController, :create      # Registro de usuarios
  post "/login", LoginController, :create                # Login directo (para obtener JWT)
end

# API DE GESTIÓN (Requiere autenticación JWT o API Key)
scope "/api", ThalamusWeb.API do
  # OAuth2 Clients (acepta JWT o API Key)
  resources "/clients", OAuth2ClientController
  post "/clients/:client_id/rotate-secret", OAuth2ClientController, :rotate_secret

  # Usuarios (solo JWT)
  resources "/users", UserController

  # Organizaciones (solo JWT)
  resources "/organizations", OrganizationController
end

# ADMIN API (Requiere super_admin)
scope "/api/admin", ThalamusWeb.Admin do
  resources "/api-keys", AdminApiKeyController, only: [:index, :create, :show, :delete]
  post "/api-keys/:id/rotate", AdminApiKeyController, :rotate
end
```

### 1.2 Grant Types Soportados

Del código de `TokenController` (`lib/thalamus_web/controllers/oauth2/token_controller.ex`):

```elixir
# Grant types soportados:
# - authorization_code (con PKCE opcional)
# - client_credentials (M2M)
# - refresh_token
# - password (DEPRECATED - no usar)
```

### 1.3 Pipelines de Seguridad

```elixir
# :oauth2_browser - Para /oauth/authorize (necesita CSRF protection)
# - Rate limit: 20 req/min por IP
# - Tiene protección CSRF

# :oauth2_api - Para /oauth/token, /oauth/introspect (SIN CSRF)
# - Rate limit: 1000 req/min por IP
# - No tiene CSRF (porque es API)

# :api_auth - Para /api/clients (acepta JWT o API Key)
# - Rate limit: 5000 req/min por usuario
# - Autenticación flexible

# :authenticated_api - Solo JWT
# - Rate limit: 5000 req/min por usuario

# :super_admin - Solo super admin
# - Rate limit: 1000 req/min por usuario
```

---

## 2. Endpoints Disponibles

### 2.1 Endpoint de Health Check

**Código:** `lib/thalamus_web/controllers/api/health_controller.ex`

```bash
curl http://localhost:4000/api/public/health
```

**Respuesta:**
```json
{
  "status": "ok",
  "version": "1.0.0",
  "timestamp": "2026-01-23T10:00:00Z"
}
```

### 2.2 Endpoint de Discovery (OpenID Connect)

**Código:** `lib/thalamus_web/controllers/oauth2/discovery_controller.ex`

```bash
curl http://localhost:4000/.well-known/openid-configuration
```

**Respuesta:** Configuración completa de endpoints OAuth2/OIDC

---

## 3. Flujo 1: Authorization Code

Este es el flujo para aplicaciones con usuarios (web apps, mobile apps).

### 3.1 Análisis del Código de Authorization

**Archivo:** `lib/thalamus_web/controllers/oauth2/authorization_controller.ex`

El flujo real implementado:

```elixir
# GET /oauth/authorize
def new(conn, params) do
  # 1. Valida response_type (debe ser "code")
  # 2. Valida client_id
  # 3. Busca el cliente en la BD
  # 4. Valida redirect_uri contra los registrados
  # 5. Parsea y valida scopes
  # 6. Extrae y valida parámetros PKCE (code_challenge, code_challenge_method)
  # 7. Verifica si el usuario está autenticado
  #    - Si SÍ: muestra pantalla de consentimiento
  #    - Si NO: redirige a /login
end

# POST /oauth/authorize
def create(conn, params) do
  # 1. Obtiene la decisión del usuario (approve/deny)
  # 2. Si approve:
  #    - Genera authorization code
  #    - Guarda code en BD con: client_id, user_id, scopes, PKCE challenge
  #    - Redirige a redirect_uri con el code
  # 3. Si deny:
  #    - Redirige a redirect_uri con error=access_denied
end
```

### 3.2 Paso a Paso Práctico

#### Paso 1: Crear un OAuth2 Client

**Opción A: Usando el Dashboard**
1. Ir a `http://localhost:4000/login`
2. Login con admin user
3. Ir a `http://localhost:4000/dashboard/clients`
4. Crear nuevo cliente

**Opción B: Usando la API** (requiere JWT o API Key)

```bash
# Primero, obtén un JWT (si eres admin)
curl -X POST http://localhost:4000/api/public/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@example.com",
    "password": "your_password"
  }'

# Usar el JWT para crear el cliente
curl -X POST http://localhost:4000/api/clients \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Mi Aplicación Web",
    "organization_id": "YOUR_ORG_ID",
    "client_type": "confidential",
    "redirect_uris": ["http://localhost:3000/auth/callback"],
    "grant_types": ["authorization_code", "refresh_token"],
    "scopes": ["openid", "profile", "email"]
  }'
```

**Respuesta:**
```json
{
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "client_id": "client_abc123def456",
    "client_secret": "secret_xyz789uvw012",
    "name": "Mi Aplicación Web",
    "client_type": "confidential",
    "redirect_uris": ["http://localhost:3000/auth/callback"],
    "grant_types": ["authorization_code", "refresh_token"],
    "scopes": ["openid", "profile", "email"]
  },
  "message": "OAuth2 client created successfully"
}
```

⚠️ **IMPORTANTE:** Guarda el `client_secret`, solo se muestra una vez.

#### Paso 2: Redirigir al Usuario a /oauth/authorize

**En tu aplicación:**

```javascript
// Generar PKCE challenge (recomendado para seguridad)
function generateCodeVerifier() {
  const array = new Uint8Array(32);
  crypto.getRandomValues(array);
  return base64URLEncode(array);
}

async function generateCodeChallenge(verifier) {
  const encoder = new TextEncoder();
  const data = encoder.encode(verifier);
  const hash = await crypto.subtle.digest('SHA-256', data);
  return base64URLEncode(new Uint8Array(hash));
}

// Generar state (CSRF protection)
function generateState() {
  const array = new Uint8Array(16);
  crypto.getRandomValues(array);
  return base64URLEncode(array);
}

// Iniciar login
async function login() {
  const codeVerifier = generateCodeVerifier();
  const codeChallenge = await generateCodeChallenge(codeVerifier);
  const state = generateState();

  // Guardar para usar después
  sessionStorage.setItem('code_verifier', codeVerifier);
  sessionStorage.setItem('oauth_state', state);

  // Construir URL de autorización
  const params = new URLSearchParams({
    response_type: 'code',
    client_id: 'client_abc123def456',
    redirect_uri: 'http://localhost:3000/auth/callback',
    scope: 'openid profile email',
    state: state,
    code_challenge: codeChallenge,
    code_challenge_method: 'S256'
  });

  window.location.href = `http://localhost:4000/oauth/authorize?${params}`;
}
```

#### Paso 3: Usuario Autentica en Thalamus

El usuario verá:
1. Pantalla de login de Thalamus (si no está autenticado)
2. Pantalla de consentimiento (permisos solicitados)
3. Redirigirá a tu `redirect_uri` con el código

#### Paso 4: Recibir el Código de Autorización

**En tu callback endpoint:**

```
http://localhost:3000/auth/callback?code=ac_ABC123XYZ789&state=xyz123
```

**Validar el state:**

```javascript
const urlParams = new URLSearchParams(window.location.search);
const code = urlParams.get('code');
const state = urlParams.get('state');
const error = urlParams.get('error');

// Verificar errores
if (error) {
  console.error('Error de OAuth2:', error);
  console.error('Descripción:', urlParams.get('error_description'));
  return;
}

// Verificar state (CSRF protection)
const savedState = sessionStorage.getItem('oauth_state');
if (state !== savedState) {
  console.error('Estado inválido - posible ataque CSRF');
  return;
}

// Continuar con el intercambio de código...
```

#### Paso 5: Intercambiar Código por Tokens

**Análisis del código de TokenController:**

```elixir
# POST /oauth/token con grant_type=authorization_code
# Valida:
# 1. client_id y client_secret (si es confidential)
# 2. code es válido y no ha expirado
# 3. redirect_uri coincide
# 4. PKCE code_verifier (si el código tiene code_challenge)
# 5. code no ha sido usado antes
#
# Si todo es válido:
# - Genera access_token (JWT)
# - Genera refresh_token (si el grant_type lo incluye)
# - Guarda tokens en BD
# - Marca el code como usado
# - Retorna tokens
```

**Request:**

```bash
curl -X POST http://localhost:4000/oauth/token \
  -H "Content-Type: application/json" \
  -d '{
    "grant_type": "authorization_code",
    "code": "ac_ABC123XYZ789",
    "client_id": "client_abc123def456",
    "client_secret": "secret_xyz789uvw012",
    "redirect_uri": "http://localhost:3000/auth/callback",
    "code_verifier": "CODE_VERIFIER_FROM_PKCE"
  }'
```

**Respuesta:**

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 3600,
  "refresh_token": "rt_abc123def456xyz789",
  "scope": "openid profile email"
}
```

#### Paso 6: Usar el Access Token

```bash
curl -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  http://localhost:4000/oauth/userinfo
```

**Respuesta:**

```json
{
  "sub": "user_123",
  "email": "user@example.com",
  "name": "John Doe",
  "email_verified": true,
  "organization_id": "org_456"
}
```

---

## 4. Flujo 2: Client Credentials (M2M)

Para servicios backend que no tienen usuarios.

### 4.1 Análisis del Código

Del código de `GenerateTokens` use case:

```elixir
# Client Credentials Flow:
# 1. Valida client_id y client_secret
# 2. Verifica que el cliente tenga grant_type "client_credentials"
# 3. Valida los scopes solicitados contra los permitidos del cliente
# 4. Genera access_token (NO genera refresh_token en M2M)
# 5. Guarda el token en BD
# 6. Retorna access_token
```

### 4.2 Paso a Paso

#### Paso 1: Crear Cliente M2M

```bash
curl -X POST http://localhost:4000/api/clients \
  -H "Authorization: Bearer YOUR_JWT_OR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Mi Servicio Backend",
    "organization_id": "YOUR_ORG_ID",
    "client_type": "confidential",
    "redirect_uris": [],
    "grant_types": ["client_credentials"],
    "scopes": ["api:read", "api:write"]
  }'
```

#### Paso 2: Obtener Token

```bash
curl -X POST http://localhost:4000/oauth/token \
  -H "Content-Type: application/json" \
  -d '{
    "grant_type": "client_credentials",
    "client_id": "client_m2m_123",
    "client_secret": "secret_m2m_456",
    "scope": "api:read api:write"
  }'
```

**Respuesta:**

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 3600,
  "scope": "api:read api:write"
}
```

⚠️ **NOTA:** NO hay `refresh_token` en Client Credentials. Cuando expira, solicitas uno nuevo.

#### Paso 3: Usar el Token

```bash
curl -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  http://localhost:4000/api/users
```

---

## 5. Validación de Tokens

### 5.1 Token Introspection (RFC 7662)

**Código:** `lib/thalamus_web/controllers/oauth2/introspection_controller.ex`

```elixir
# POST /oauth/introspect
# - Usa CachedValidateToken use case (con Redis cache)
# - Valida formato del token
# - Verifica que no esté expirado
# - Verifica que no esté revocado
# - Retorna metadata completa del token
```

**Request:**

```bash
curl -X POST http://localhost:4000/oauth/introspect \
  -H "Content-Type: application/json" \
  -d '{
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }'
```

**Respuesta (token válido):**

```json
{
  "active": true,
  "scope": "openid profile email",
  "client_id": "client_abc123",
  "username": "user@example.com",
  "email": "user@example.com",
  "user_id": "user_123",
  "sub": "user_123",
  "organization_id": "org_456",
  "tenant_id": "org_456",
  "token_type": "Bearer",
  "exp": 1640995200,
  "iat": 1640991600
}
```

**Respuesta (token inválido):**

```json
{
  "active": false
}
```

### 5.2 Caché de Validaciones

**Código:** `lib/thalamus/application/use_cases/cached_validate_token.ex`

```elixir
# CachedValidateToken usa Redis para cachear validaciones:
# - Cache key: "token_validation:#{token_hash}"
# - TTL: hasta la expiración del token
# - Reduce carga en BD para tokens frecuentemente validados
```

---

## 6. Auto-registro con Admin API Keys

Para que servicios externos se auto-registren sin intervención manual.

### 6.1 Análisis del Pipeline

**Código:** `lib/thalamus_web/plugs/api_auth.ex`

```elixir
# APIAuth plug acepta DOS tipos de autenticación:
#
# 1. JWT Token (Bearer)
#    Authorization: Bearer eyJhbGc...
#
# 2. Admin API Key
#    Authorization: ApiKey ak_dev_abc123...
#
# El plug:
# - Detecta el tipo de autenticación
# - Para API Keys: valida el key, verifica scopes
# - Para JWT: valida el token normalmente
# - Pone user/api_key info en conn.assigns
```

### 6.2 Paso a Paso

#### Paso 1: Super Admin Crea API Key

**Código:** `lib/thalamus_web/controllers/admin/admin_api_key_controller.ex`

```bash
# Requiere super_admin role
curl -X POST http://localhost:4000/api/admin/api-keys \
  -H "Authorization: Bearer SUPER_ADMIN_JWT" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Service Auto-Registration",
    "description": "Allows services to self-register as OAuth2 clients",
    "scopes": ["clients:write", "clients:read"],
    "expires_at": "2027-12-31T23:59:59Z"
  }'
```

**Respuesta:**

```json
{
  "data": {
    "id": "apikey_uuid",
    "api_key": "ak_dev_vK8mN2pQ7xR9tY3wZ5aB1cD4eF6gH8jL",
    "key_prefix": "ak_dev_vK8m",
    "name": "Service Auto-Registration",
    "scopes": ["clients:write", "clients:read"],
    "is_active": true,
    "expires_at": "2027-12-31T23:59:59Z",
    "created_at": "2026-01-23T10:00:00Z"
  },
  "message": "⚠️ IMPORTANT: Save the api_key in a secure location. It cannot be retrieved later."
}
```

#### Paso 2: Servicio Usa API Key para Auto-registrarse

```bash
# El servicio externo usa el API Key
curl -X POST http://localhost:4000/api/clients \
  -H "Authorization: ApiKey ak_dev_vK8mN2pQ7xR9tY3wZ5aB1cD4eF6gH8jL" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "External Service",
    "organization_id": "org_uuid",
    "client_type": "confidential",
    "redirect_uris": ["https://external-service.com/callback"],
    "grant_types": ["authorization_code", "refresh_token"],
    "scopes": ["openid", "profile", "email"]
  }'
```

**Código real que maneja esto:**

```elixir
# lib/thalamus_web/controllers/api/oauth2_client_controller.ex

def create(conn, params) do
  # Este controller está en pipeline :api_auth
  # que acepta JWT O API Key

  # Verifica scopes del API Key
  with :ok <- verify_api_key_scopes(conn),
       # ... continúa creando el cliente

defp verify_api_key_scopes(conn) do
  case conn.assigns[:api_key] do
    nil ->
      # Autenticado con JWT, permitir
      :ok

    api_key ->
      # Autenticado con API Key, verificar scopes
      if "clients:write" in api_key.scopes do
        :ok
      else
        {:error, :insufficient_scopes}
      end
  end
end
```

---

## 7. Implementación Práctica

### 7.1 Ejemplo Completo: Express.js Backend

```javascript
const express = require('express');
const axios = require('axios');

const app = express();
const THALAMUS_URL = 'http://localhost:4000';
const CLIENT_ID = 'client_abc123';
const CLIENT_SECRET = 'secret_xyz789';

// Caché de tokens M2M
let cachedToken = null;
let tokenExpiry = null;

// Obtener token M2M
async function getM2MToken() {
  // Usar caché si es válido
  if (cachedToken && Date.now() < tokenExpiry) {
    return cachedToken;
  }

  const response = await axios.post(`${THALAMUS_URL}/oauth/token`, {
    grant_type: 'client_credentials',
    client_id: CLIENT_ID,
    client_secret: CLIENT_SECRET,
    scope: 'api:read api:write'
  });

  cachedToken = response.data.access_token;
  // Renovar 60s antes de expirar
  tokenExpiry = Date.now() + (response.data.expires_in - 60) * 1000;

  return cachedToken;
}

// Middleware: validar token de usuario
async function validateUserToken(req, res, next) {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'No token provided' });
  }

  const token = authHeader.substring(7);

  try {
    const response = await axios.post(`${THALAMUS_URL}/oauth/introspect`, {
      token
    });

    if (!response.data.active) {
      return res.status(401).json({ error: 'Invalid token' });
    }

    // Agregar info del usuario al request
    req.user = response.data;
    next();
  } catch (error) {
    return res.status(401).json({ error: 'Token validation failed' });
  }
}

// Endpoint público
app.get('/api/public/health', (req, res) => {
  res.json({ status: 'ok' });
});

// Endpoint protegido
app.get('/api/profile', validateUserToken, (req, res) => {
  res.json({
    message: 'This is your profile',
    user: req.user
  });
});

// Endpoint M2M
app.get('/api/internal/data', async (req, res) => {
  try {
    const token = await getM2MToken();

    // Usar el token para llamar a otro servicio
    const response = await axios.get(`${THALAMUS_URL}/api/users`, {
      headers: { Authorization: `Bearer ${token}` }
    });

    res.json(response.data);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch data' });
  }
});

app.listen(3000, () => {
  console.log('Server running on port 3000');
});
```

---

## 8. Troubleshooting

### Error: "invalid_client"

**Causa:** `client_id` o `client_secret` incorrectos

**Del código:**
```elixir
# lib/thalamus/application/use_cases/generate_tokens.ex
# Valida client credentials usando Bcrypt.verify_pass
```

**Solución:**
1. Verificar que el `client_id` sea correcto
2. Si el cliente fue creado antes de la implementación de hashing, rotar el secret:
   ```bash
   POST /api/clients/{id}/rotate-secret
   ```

### Error: "invalid_grant" - PKCE

**Causa:** `code_verifier` no coincide con `code_challenge`

**Del código:**
```elixir
# Valida PKCE:
# 1. Hashea code_verifier con SHA256
# 2. Compara con code_challenge guardado
# 3. Si no coinciden, retorna :invalid_pkce_verifier
```

**Solución:**
- Asegúrate de usar el mismo `code_verifier` que generaste antes
- El `code_challenge` debe ser SHA256 del `code_verifier`, base64url encoded

### Error: "unsupported_grant_type"

**Del código:**
```elixir
# lib/thalamus_web/controllers/oauth2/token_controller.ex
# Valida que el cliente tenga el grant_type permitido
```

**Solución:**
- Verificar que el cliente tenga el `grant_type` en su configuración
- Ejemplo: un cliente creado solo con `authorization_code` no puede usar `client_credentials`

### Error: Rate Limit Exceeded

**Del código router:**
```elixir
# :oauth2_api pipeline: 1000 req/min por IP
# :oauth2_browser pipeline: 20 req/min por IP (para /authorize)
```

**Solución:**
- Implementar caché de tokens (no solicitar en cada request)
- Para introspection, usar caché local con TTL del token

### Error: "Token is not active"

**Posibles causas:**
1. Token expirado
2. Token revocado
3. Token usado antes de que PKCE esté implementado completamente

**Del código de introspection:**
```elixir
# Retorna active: false si:
# - Token no existe en BD
# - Token está revocado (revoked_at no es nil)
# - Token expiró (expires_at < now)
```

---

## 📚 Próximos Pasos

Ahora que entiendes cómo funciona Thalamus desde el código:

1. **Para Frontend:** Lee [Tutorial 02 - Frontend Web](./02-frontend-web.md)
2. **Para Backend:** Lee [Tutorial 03 - Backend API](./03-backend-api.md)
3. **Para Admin API Keys:** Lee [Tutorial 08 - Admin API Keys](./08-admin-api-keys.md)

---

## 🔗 Referencias del Código

Todos los ejemplos están basados en:
- `lib/thalamus_web/router.ex` - Rutas y pipelines
- `lib/thalamus_web/controllers/oauth2/*_controller.ex` - Controllers OAuth2
- `lib/thalamus/application/use_cases/generate_tokens.ex` - Lógica de generación de tokens
- `lib/thalamus/application/use_cases/cached_validate_token.ex` - Validación con caché

**Última revisión del código:** 2026-01-23
