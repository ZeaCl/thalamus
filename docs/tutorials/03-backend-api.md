# Tutorial 03: Backend API - Integración con Node.js y Python

Este tutorial muestra cómo integrar APIs backend (Node.js, Python/FastAPI) con Thalamus usando **Client Credentials Flow** (M2M - Machine-to-Machine) para autenticación entre servicios.

**Basado en código real de Thalamus** (análisis directo del código, no especulación).

---

## 📋 Tabla de Contenidos

1. [Flujo Client Credentials (M2M)](#1-flujo-client-credentials-m2m)
2. [Análisis del Endpoint de Token](#2-análisis-del-endpoint-de-token)
3. [Análisis del Endpoint de Introspección](#3-análisis-del-endpoint-de-introspección)
4. [Caché de Tokens con Redis](#4-caché-de-tokens-con-redis)
5. [Implementación en Node.js/Express](#5-implementación-en-nodejsexpress)
6. [Implementación en Python/FastAPI](#6-implementación-en-pythonfastapi)
7. [Middleware para Proteger Endpoints](#7-middleware-para-proteger-endpoints)
8. [Manejo de Errores](#8-manejo-de-errores)

---

## 1. Flujo Client Credentials (M2M)

### ¿Cuándo Usar Client Credentials?

Este flujo es para **autenticación máquina-a-máquina** sin intervención de usuario:

- ✅ **Backend API** que consume otros servicios
- ✅ **Microservicios** que se comunican entre sí
- ✅ **Jobs/Workers** que necesitan acceder a recursos
- ✅ **Scripts automatizados** que ejecutan tareas
- ❌ NO usar para frontend (usa Authorization Code + PKCE)

### Diagrama del Flujo

```
┌─────────────────┐                                  ┌──────────────────┐
│   Tu Backend    │                                  │     Thalamus     │
│   (API Server)  │                                  │  (Auth Server)   │
└────────┬────────┘                                  └────────┬─────────┘
         │                                                    │
         │  1. POST /oauth/token                             │
         │     grant_type=client_credentials                 │
         │     client_id=your_client_id                      │
         │     client_secret=your_secret                     │
         │     scope=api:read api:write                      │
         ├──────────────────────────────────────────────────>│
         │                                                    │
         │                                   2. Valida client│
         │                                      Genera token │
         │                                                    │
         │  3. Response:                                     │
         │     {                                             │
         │       "access_token": "at_xxx...",                │
         │       "token_type": "Bearer",                     │
         │       "expires_in": 3600,                         │
         │       "scope": "api:read api:write"               │
         │     }                                             │
         │<──────────────────────────────────────────────────┤
         │                                                    │
         │  4. Usa token para llamadas API                   │
         │     Authorization: Bearer at_xxx...               │
         └────────────────────────────────────────────────────
```

**Nota importante**: En Client Credentials NO se genera `refresh_token` porque no hay usuario. El backend debe obtener un nuevo token cuando expire.

---

## 2. Análisis del Endpoint de Token

### Código Real: `lib/thalamus_web/controllers/oauth2/token_controller.ex`

```elixir
def create(conn, params) do
  token_params = extract_token_params(params)

  case TokenRequest.new(token_params) do
    {:ok, token_request} ->
      case GenerateTokens.execute(token_request, @deps) do
        {:ok, %TokenResponse{} = token_response} ->
          conn
          |> put_status(:ok)
          |> put_resp_header("cache-control", "no-store")
          |> put_resp_header("pragma", "no-cache")
          |> json(TokenResponse.to_map(token_response))

        {:error, :invalid_client_secret} ->
          oauth2_error(conn, "invalid_client", "Invalid client credentials", :unauthorized)

        # ... otros errores
      end
  end
end
```

### Parámetros Requeridos (Form-Encoded o JSON)

```http
POST /oauth/token
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials
&client_id=your_client_id
&client_secret=your_client_secret
&scope=api:read api:write
```

O en JSON:

```json
{
  "grant_type": "client_credentials",
  "client_id": "your_client_id",
  "client_secret": "your_client_secret",
  "scope": "api:read api:write"
}
```

### Respuesta Exitosa (200 OK)

```json
{
  "access_token": "at_s3cur3T0k3nStr1ng...",
  "token_type": "Bearer",
  "expires_in": 3600,
  "scope": "api:read api:write"
}
```

**Nota**: `expires_in` está en **segundos** (3600 = 1 hora).

### Errores Comunes

| Código | Error OAuth2 | Descripción |
|--------|--------------|-------------|
| 401 | `invalid_client` | client_id o client_secret incorrecto |
| 400 | `unsupported_grant_type` | grant_type no soportado por el cliente |
| 400 | `invalid_scope` | Scope solicitado no permitido |

---

## 3. Análisis del Endpoint de Introspección

### Código Real: `lib/thalamus_web/controllers/oauth2/introspection_controller.ex`

```elixir
def create(conn, params) do
  token = get_param(params, "token")

  case CachedValidateToken.execute(token, @deps) do
    {:ok, validation_result} ->
      response = build_introspection_response(validation_result)

      conn
      |> put_status(:ok)
      |> put_resp_header("cache-control", "no-store")
      |> json(response)

    {:error, _reason} ->
      # Token inválido o expirado - retorna inactive
      conn
      |> put_status(:ok)
      |> json(%{active: false})
  end
end
```

### Llamada de Introspección

```bash
curl -X POST http://localhost:4000/oauth/introspect \
  -H "Content-Type: application/json" \
  -d '{
    "token": "at_s3cur3T0k3nStr1ng..."
  }'
```

### Respuesta - Token Activo

```json
{
  "active": true,
  "scope": "api:read api:write",
  "client_id": "your_client_id",
  "token_type": "Bearer",
  "exp": 1640995200,
  "iat": 1640991600,
  "sub": null
}
```

**Campos importantes**:
- `active`: `true` si el token es válido y no ha expirado
- `scope`: Lista de scopes separados por espacio
- `client_id`: Identificador del cliente
- `exp`: Timestamp de expiración (Unix epoch en segundos)
- `iat`: Timestamp de emisión (Unix epoch en segundos)
- `sub`: Subject (user_id) - `null` para Client Credentials

### Respuesta - Token Inactivo

```json
{
  "active": false
}
```

**SIEMPRE retorna 200 OK**, incluso si el token es inválido. Debes verificar `active: false`.

---

## 4. Caché de Tokens con Redis

### Análisis: `lib/thalamus/application/use_cases/cached_validate_token.ex`

Thalamus implementa caché automático de validaciones de token:

```elixir
@cache_ttl 300  # 5 minutos

def execute(token, deps) do
  cache_key = "token:introspect:#{token}"

  case deps.cache_service.get(cache_key) do
    {:ok, cached_result} ->
      Logger.debug("Token introspection cache HIT")
      {:ok, cached_result}

    {:error, :not_found} ->
      Logger.debug("Token introspection cache MISS")
      validate_and_cache(token, cache_key, deps)
  end
end
```

### Rendimiento

| Tipo | Latencia | Descripción |
|------|----------|-------------|
| **Cache HIT** | ~1-3ms | Token encontrado en Redis |
| **Cache MISS** | ~15-25ms | Consulta DB + actualiza caché |
| **TTL** | 5 minutos | Tiempo de vida en caché |

### Invalidación de Caché

El caché se invalida automáticamente cuando:
- Token es revocado (`POST /oauth/revoke`)
- Token expira (TTL automático)

**Recomendación**: En tu backend, implementa caché local con la misma estrategia para reducir llamadas a Thalamus.

---

## 5. Implementación en Node.js/Express

### 5.1. Instalación

```bash
npm install @zea.cl/thalamus-js express dotenv
```

### 5.2. Configuración (.env)

```env
THALAMUS_BASE_URL=http://localhost:4000
THALAMUS_CLIENT_ID=your_backend_client_id
THALAMUS_CLIENT_SECRET=your_client_secret
PORT=3000
```

### 5.3. Inicialización del Cliente

```javascript
import express from 'express'
import ThalamusClient from '@zea.cl/thalamus-js'

const app = express()
app.use(express.json())

// Inicializar SDK de Thalamus
const thalamus = new ThalamusClient({
  clientId: process.env.THALAMUS_CLIENT_ID,
  clientSecret: process.env.THALAMUS_CLIENT_SECRET,
  baseUrl: process.env.THALAMUS_BASE_URL
})
```

### 5.4. Middleware de Autenticación

**Código Real**: `examples/nodejs-backend/server.js`

```javascript
// Caché en memoria (usar Redis en producción)
let cachedToken = null
let tokenExpiry = null

// Middleware para asegurar token válido
async function ensureToken(req, res, next) {
  try {
    // Verificar si el token en caché sigue válido
    if (cachedToken && tokenExpiry && Date.now() < tokenExpiry) {
      req.accessToken = cachedToken
      return next()
    }

    // Obtener nuevo token usando client credentials
    const tokens = await thalamus.auth.clientCredentials({
      scope: ['api:read', 'api:write']
    })

    // Cachear token (restar 60s como margen de seguridad)
    cachedToken = tokens.access_token
    tokenExpiry = Date.now() + (tokens.expires_in - 60) * 1000

    req.accessToken = cachedToken
    next()
  } catch (error) {
    console.error('Token acquisition failed:', error)
    res.status(500).json({ error: 'Failed to authenticate with Thalamus' })
  }
}
```

**Estrategia de caché**:
1. Verificar si hay token en caché y no ha expirado
2. Si expiró o no existe, obtener nuevo token
3. Cachear token con margen de seguridad de 60 segundos

### 5.5. Endpoints Protegidos

```javascript
// Endpoint público (sin autenticación)
app.get('/api/public/health', (req, res) => {
  res.json({ status: 'ok', message: 'Server is running' })
})

// Endpoint protegido (requiere token válido)
app.get('/api/protected/data', ensureToken, async (req, res) => {
  try {
    // Validar token
    const validation = await thalamus.tokens.introspect(req.accessToken)

    if (!validation.active) {
      return res.status(401).json({ error: 'Token is not active' })
    }

    // Retornar datos protegidos
    res.json({
      message: 'This is protected data',
      authenticated: true,
      scopes: validation.scope,
      client_id: validation.client_id
    })
  } catch (error) {
    console.error('Token validation failed:', error)
    res.status(401).json({ error: 'Token validation failed' })
  }
})
```

### 5.6. Introspección de Tokens

```javascript
// Introspeccionar un token (para debugging)
app.post('/api/introspect', ensureToken, async (req, res) => {
  try {
    const { token } = req.body

    if (!token) {
      return res.status(400).json({ error: 'Token is required' })
    }

    const result = await thalamus.tokens.introspect(token)
    res.json(result)
  } catch (error) {
    console.error('Introspection failed:', error)
    res.status(500).json({ error: 'Introspection failed' })
  }
})
```

### 5.7. Información del Token de Servicio

```javascript
// Obtener info del token del servicio
app.get('/api/token-info', ensureToken, async (req, res) => {
  try {
    const info = await thalamus.tokens.introspect(req.accessToken)
    res.json({
      active: info.active,
      scopes: info.scope,
      client_id: info.client_id,
      expires_at: info.exp ? new Date(info.exp * 1000).toISOString() : null
    })
  } catch (error) {
    console.error('Token info failed:', error)
    res.status(500).json({ error: 'Failed to get token info' })
  }
})
```

### 5.8. Iniciar Servidor

```javascript
const PORT = process.env.PORT || 3000

app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`)
  console.log(`Thalamus server: ${process.env.THALAMUS_BASE_URL}`)
})
```

---

## 6. Implementación en Python/FastAPI

### 6.1. Instalación

```bash
pip install fastapi uvicorn python-dotenv httpx
```

### 6.2. Cliente Thalamus (thalamus_client.py)

```python
import httpx
from typing import Optional, List, Dict, Any

class ThalamusClient:
    """Cliente para Thalamus OAuth2 API."""

    def __init__(self, base_url: str, client_id: str, client_secret: str):
        self.base_url = base_url.rstrip('/')
        self.client_id = client_id
        self.client_secret = client_secret
        self._token_cache: Optional[Dict[str, Any]] = None

    async def get_cached_token(self, scopes: List[str]) -> str:
        """
        Obtiene token con caché local.
        Retorna token válido o solicita uno nuevo.
        """
        # Verificar si hay token en caché y no ha expirado
        if self._token_cache:
            # Verificar expiración (con margen de 60s)
            import time
            if time.time() < self._token_cache.get('expires_at', 0) - 60:
                return self._token_cache['access_token']

        # Obtener nuevo token
        tokens = await self.client_credentials(scopes)

        # Cachear token
        import time
        self._token_cache = {
            'access_token': tokens['access_token'],
            'expires_at': time.time() + tokens['expires_in']
        }

        return tokens['access_token']

    async def client_credentials(self, scopes: List[str]) -> Dict[str, Any]:
        """
        Flujo Client Credentials para obtener token M2M.
        """
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.base_url}/oauth/token",
                data={
                    "grant_type": "client_credentials",
                    "client_id": self.client_id,
                    "client_secret": self.client_secret,
                    "scope": " ".join(scopes)
                },
                headers={"Content-Type": "application/x-www-form-urlencoded"}
            )

            if response.status_code != 200:
                raise Exception(f"Token request failed: {response.text}")

            return response.json()

    async def introspect_token(self, token: str) -> Dict[str, Any]:
        """
        Introspecciona un token para validarlo.
        """
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.base_url}/oauth/introspect",
                json={"token": token},
                headers={"Content-Type": "application/json"}
            )

            if response.status_code != 200:
                raise Exception(f"Introspection failed: {response.text}")

            return response.json()
```

### 6.3. Implementación FastAPI

**Código Real**: `examples/python-fastapi/main.py`

```python
import os
from typing import Annotated
from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
from dotenv import load_dotenv
from thalamus_client import ThalamusClient

# Cargar variables de entorno
load_dotenv()

# Inicializar FastAPI
app = FastAPI(
    title="Thalamus FastAPI Example",
    description="Backend API using Thalamus OAuth2 Client Credentials",
    version="1.0.0"
)

# Inicializar cliente Thalamus
thalamus = ThalamusClient(
    base_url=os.getenv("THALAMUS_BASE_URL", "http://localhost:4000"),
    client_id=os.getenv("THALAMUS_CLIENT_ID"),
    client_secret=os.getenv("THALAMUS_CLIENT_SECRET")
)

# Esquema de seguridad
security = HTTPBearer()
```

### 6.4. Modelos de Datos

```python
class HealthResponse(BaseModel):
    status: str
    message: str

class ProtectedDataResponse(BaseModel):
    message: str
    authenticated: bool
    scopes: list[str] | None
    client_id: str | None
```

### 6.5. Dependency para Validación de Token

```python
async def validate_token(
    credentials: Annotated[HTTPAuthorizationCredentials, Depends(security)]
) -> dict:
    """
    Valida Bearer token usando introspección de Thalamus.
    """
    try:
        token = credentials.credentials
        introspection = await thalamus.introspect_token(token)

        if not introspection.get("active"):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token is not active"
            )

        return introspection
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Token validation failed: {str(e)}"
        )
```

### 6.6. Endpoints Públicos

```python
@app.get("/", response_model=HealthResponse)
async def root():
    """Public health check endpoint."""
    return HealthResponse(
        status="ok",
        message="Thalamus FastAPI Example is running"
    )

@app.get("/api/public/health", response_model=HealthResponse)
async def health():
    """Public health check endpoint."""
    return HealthResponse(
        status="ok",
        message="Server is healthy"
    )
```

### 6.7. Endpoints Protegidos

```python
@app.get("/api/protected/data", response_model=ProtectedDataResponse)
async def protected_data(
    token_data: Annotated[dict, Depends(validate_token)]
):
    """
    Endpoint protegido que requiere Bearer token válido.
    """
    return ProtectedDataResponse(
        message="This is protected data from FastAPI",
        authenticated=True,
        scopes=token_data.get("scope", "").split() if token_data.get("scope") else None,
        client_id=token_data.get("client_id")
    )
```

### 6.8. Endpoints M2M (usando token del servicio)

```python
@app.get("/api/service/test-m2m")
async def test_m2m():
    """
    Test endpoint que usa client credentials para autenticarse.
    """
    try:
        # Obtener token del servicio usando client credentials
        token = await thalamus.get_cached_token(["api:read", "api:write"])

        # Validarlo
        validation = await thalamus.introspect_token(token)

        return {
            "message": "M2M authentication successful",
            "token_active": validation.get("active"),
            "client_id": validation.get("client_id"),
            "scopes": validation.get("scope", "").split() if validation.get("scope") else None
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"M2M authentication failed: {str(e)}"
        )
```

### 6.9. Iniciar Servidor

```python
if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=port,
        reload=True
    )
```

---

## 7. Middleware para Proteger Endpoints

### 7.1. Express Middleware Avanzado

```javascript
// Middleware que valida scope específico
function requireScope(...requiredScopes) {
  return async (req, res, next) => {
    try {
      const authHeader = req.headers.authorization

      if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ error: 'Missing or invalid Authorization header' })
      }

      const token = authHeader.substring(7) // Remove 'Bearer '
      const introspection = await thalamus.tokens.introspect(token)

      if (!introspection.active) {
        return res.status(401).json({ error: 'Token is not active' })
      }

      // Verificar scopes
      const tokenScopes = introspection.scope ? introspection.scope.split(' ') : []
      const hasRequiredScope = requiredScopes.some(scope => tokenScopes.includes(scope))

      if (!hasRequiredScope) {
        return res.status(403).json({
          error: 'Insufficient scope',
          required: requiredScopes,
          provided: tokenScopes
        })
      }

      // Adjuntar info del token al request
      req.tokenInfo = introspection
      next()
    } catch (error) {
      console.error('Token validation failed:', error)
      res.status(401).json({ error: 'Token validation failed' })
    }
  }
}

// Uso:
app.get('/api/admin/users', requireScope('admin:read', 'users:read'), (req, res) => {
  res.json({ message: 'Admin data', user: req.tokenInfo })
})
```

### 7.2. FastAPI Dependency con Scopes

```python
from typing import List

def require_scopes(required_scopes: List[str]):
    """
    Dependency que verifica scopes específicos en el token.
    """
    async def verify_scopes(
        credentials: Annotated[HTTPAuthorizationCredentials, Depends(security)]
    ) -> dict:
        token = credentials.credentials
        introspection = await thalamus.introspect_token(token)

        if not introspection.get("active"):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token is not active"
            )

        # Verificar scopes
        token_scopes = introspection.get("scope", "").split()
        has_required_scope = any(scope in token_scopes for scope in required_scopes)

        if not has_required_scope:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Insufficient scope. Required: {required_scopes}, Provided: {token_scopes}"
            )

        return introspection

    return verify_scopes

# Uso:
@app.get("/api/admin/users")
async def admin_users(
    token_data: Annotated[dict, Depends(require_scopes(["admin:read", "users:read"]))]
):
    return {"message": "Admin data", "token_info": token_data}
```

---

## 8. Manejo de Errores

### 8.1. Errores Comunes y Soluciones

| Error | Causa | Solución |
|-------|-------|----------|
| `invalid_client` | client_id o client_secret incorrecto | Verificar credenciales en .env |
| `unsupported_grant_type` | Cliente no tiene permiso para client_credentials | Habilitar grant type en cliente OAuth2 |
| `invalid_scope` | Scope solicitado no permitido | Verificar scopes permitidos del cliente |
| `Token is not active` | Token expirado o revocado | Obtener nuevo token |
| Connection refused | Thalamus no está corriendo | Iniciar servidor: `mix phx.server` |

### 8.2. Express - Error Handler Global

```javascript
// Error handler global
app.use((err, req, res, next) => {
  console.error('Server error:', err)

  // Errores de Thalamus
  if (err.response) {
    return res.status(err.response.status).json({
      error: 'Thalamus error',
      details: err.response.data
    })
  }

  // Errores genéricos
  res.status(500).json({
    error: 'Internal server error',
    message: process.env.NODE_ENV === 'development' ? err.message : undefined
  })
})
```

### 8.3. FastAPI - Exception Handlers

```python
from fastapi import Request
from fastapi.responses import JSONResponse

@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": exc.detail,
            "path": str(request.url)
        }
    )

@app.exception_handler(Exception)
async def generic_exception_handler(request: Request, exc: Exception):
    return JSONResponse(
        status_code=500,
        content={
            "error": "Internal server error",
            "message": str(exc) if os.getenv("ENV") == "development" else None
        }
    )
```

### 8.4. Retry Strategy para Token Acquisition

```javascript
async function getTokenWithRetry(maxRetries = 3) {
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      const tokens = await thalamus.auth.clientCredentials({
        scope: ['api:read', 'api:write']
      })
      return tokens
    } catch (error) {
      console.error(`Token acquisition attempt ${attempt} failed:`, error.message)

      if (attempt === maxRetries) {
        throw new Error('Failed to acquire token after multiple attempts')
      }

      // Exponential backoff: 1s, 2s, 4s
      await new Promise(resolve => setTimeout(resolve, Math.pow(2, attempt - 1) * 1000))
    }
  }
}
```

---

## 📝 Resumen

### ✅ Checklist de Implementación

- [ ] Crear cliente OAuth2 confidencial en Thalamus dashboard
- [ ] Configurar `client_id` y `client_secret` en variables de entorno
- [ ] Implementar caché de tokens (con margen de seguridad de 60s)
- [ ] Crear middleware de autenticación para endpoints protegidos
- [ ] Validar tokens usando introspección (`POST /oauth/introspect`)
- [ ] Implementar manejo de errores y retry logic
- [ ] Verificar scopes en endpoints que requieren permisos específicos
- [ ] (Producción) Usar Redis para caché distribuido de tokens
- [ ] (Producción) Implementar rate limiting en endpoints públicos
- [ ] (Producción) Configurar HTTPS y security headers

### 🔑 Puntos Clave

1. **Client Credentials** es para autenticación M2M (máquina-a-máquina)
2. **NO genera refresh_token** - obtener nuevo token cuando expire
3. **Cachear tokens** localmente con margen de seguridad de 60 segundos
4. **Introspección** siempre retorna 200 OK - verificar `active: false`
5. **Thalamus cachea** validaciones con TTL de 5 minutos en Redis
6. **Scopes** definen permisos - verificar en cada endpoint protegido

### 📚 Próximos Pasos

- **Tutorial 04**: Aplicación Móvil (React Native, Flutter)
- **Tutorial 05**: Authorization Code Flow detallado
- **Tutorial 10**: Token Introspection avanzado con caché

---

**Última actualización**: 2026-01-23 (basado en código real de Thalamus)
