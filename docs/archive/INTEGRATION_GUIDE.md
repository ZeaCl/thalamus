# ZEA Thalamus - Integration Guide

**Official Integration Guide for External Teams**

Version: 1.0.0
Last Updated: December 26, 2025
Service: ZEA Thalamus OAuth2 Authentication Service

**✅ Implementation Status: All features documented in this guide are fully implemented and tested.**
All flows (Authorization Code, Client Credentials M2M, Admin API Keys) are production-ready.

---

## Table of Contents

1. [Introduction](#introduction)
2. [Quick Start](#quick-start)
3. [Authentication Flows](#authentication-flows)
   - [Flow 1: Direct API Authentication](#flow-1-direct-api-authentication-simplest)
   - [Flow 2: OAuth2 Authorization Code](#flow-2-oauth2-authorization-code-flow-standard)
   - [Flow 3: Client Credentials (M2M)](#flow-3-client-credentials-m2m---machine-to-machine)
   - [Flow 4: Token Introspection](#flow-4-token-introspection-backend-validation)
4. [API Reference](#api-reference)
   - [Admin API Keys (Service Authentication)](#admin-api-keys-service-authentication)
5. [Integration Examples](#integration-examples)
6. [Security Best Practices](#security-best-practices)
7. [Troubleshooting](#troubleshooting)
8. [Testing](#testing)
9. [Production Deployment](#production-deployment)

---

## Introduction

### What is ZEA Thalamus?

ZEA Thalamus is an enterprise-grade OAuth2 authentication and authorization service that provides:

- **OAuth2 2.0** compliant authentication (RFC 6749)
- **OpenID Connect** user information endpoint
- **Multi-factor Authentication** (TOTP)
- **Token Introspection** (RFC 7662)
- **Token Revocation** (RFC 7009)
- **Multi-tenancy** with organization management
- **Role-Based Access Control** (RBAC)

### Who Should Use This Guide?

This guide is for development teams integrating their applications with ZEA Thalamus:

- Frontend developers building web/mobile apps
- Backend developers implementing API authentication
- DevOps engineers deploying integrated services
- QA engineers testing authentication flows

### Prerequisites

- Basic understanding of OAuth2 and JWT tokens
- HTTP/REST API knowledge
- Development environment (Docker recommended)
- Access to Thalamus instance (local or production)

---

## Integration Flow Overview

### 🎯 Complete Integration Process

Cuando una **nueva vertical/aplicación** (ej: Sport, Campaigns, Corpus) quiere integrarse con Thalamus, sigue este flujo:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     INTEGRATION FLOW (4 PASOS)                          │
└─────────────────────────────────────────────────────────────────────────┘

PASO 0: [Super Admin] Crea Admin API Key para la vertical
        ↓
        Ejemplo: Admin API Key para "Sport"
        Scopes: ["clients:write", "clients:read"]

PASO 1: [Vertical Backend] Usa Admin API Key para auto-registrarse
        ↓
        Sport usa el API Key para crear su OAuth2 Client
        Resultado: client_id + client_secret

PASO 2: [Vertical Backend] Configura OAuth2 en su aplicación
        ↓
        Sport configura client_id/client_secret en su .env
        Implementa flujo OAuth2 (Authorization Code o M2M)

PASO 3: [Usuarios] Autenticación a través de Thalamus
        ↓
        Usuarios de Sport → Login en Thalamus → Token → Acceso a Sport
```

---

### Ejemplo Concreto: Integrar "Sport"

**Contexto**: La vertical "Sport" necesita autenticación para su aplicación web.

#### **Paso 0: Super Admin crea Admin API Key** (One-time setup)

El super admin de Thalamus crea un API Key para que Sport se auto-registre:

```bash
# Super admin se autentica
curl -X POST http://localhost:4000/api/public/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@zea.com",
    "password": "AdminPass123!@#"
  }'

# Crea Admin API Key para Sport
curl -X POST http://localhost:4000/api/admin/api-keys \
  -H "Authorization: Bearer <super_admin_jwt>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Sport Service",
    "description": "API Key for Sport to self-register as OAuth2 client",
    "scopes": ["clients:write", "clients:read"],
    "expires_at": "2026-12-31T23:59:59Z"
  }'
```

**Resultado**:
```json
{
  "data": {
    "api_key": "ak_dev_vK8mN2pQ7xR9tY3wZ5aB1cD4eF6gH8jL...",
    "key_prefix": "ak_dev_vK8m",
    "name": "Sport Service"
  },
  "message": "⚠️ IMPORTANT: Save the api_key in a secure location."
}
```

**Importante**: El super admin entrega este `api_key` al equipo de Sport (por canal seguro).

---

#### **Paso 1: Sport se auto-registra como OAuth2 Client**

El backend de Sport usa el Admin API Key para registrarse automáticamente:

**En el código de Sport (Python/FastAPI ejemplo)**:

```python
# sport/config.py
import os

THALAMUS_URL = os.getenv("THALAMUS_URL", "http://localhost:4000")
THALAMUS_API_KEY = os.getenv("THALAMUS_API_KEY")  # ak_dev_vK8mN2pQ7x...
SPORT_URL = os.getenv("SPORT_URL", "http://localhost:3001")
ORGANIZATION_ID = os.getenv("ORGANIZATION_ID")  # UUID de la organización Sport

# sport/startup.py
import httpx
from config import THALAMUS_URL, THALAMUS_API_KEY, SPORT_URL, ORGANIZATION_ID

def register_oauth2_client():
    """Auto-registro de Sport como OAuth2 client al iniciar."""

    headers = {
        "Authorization": f"ApiKey {THALAMUS_API_KEY}",
        "Content-Type": "application/json"
    }

    payload = {
        "name": "Sport Application",
        "organization_id": ORGANIZATION_ID,
        "client_type": "confidential",
        "redirect_uris": [
            f"{SPORT_URL}/auth/callback"
        ],
        "grant_types": ["authorization_code", "refresh_token"],
        "scopes": ["openid", "profile", "email", "sport:read", "sport:write"]
    }

    response = httpx.post(
        f"{THALAMUS_URL}/api/clients",
        headers=headers,
        json=payload,
        timeout=10.0
    )

    if response.status_code == 201:
        data = response.json()["data"]

        # Guarda credenciales (en producción: usar secrets manager)
        print(f"✅ OAuth2 Client registrado!")
        print(f"   CLIENT_ID: {data['client_id']}")
        print(f"   CLIENT_SECRET: {data['client_secret']}")
        print(f"⚠️  Guarda estas credenciales en variables de entorno!")

        return data
    else:
        print(f"❌ Error: {response.status_code}")
        print(response.json())
        raise Exception("Failed to register OAuth2 client")

# Ejecutar al iniciar Sport
if __name__ == "__main__":
    register_oauth2_client()
```

**Ejecutar**:
```bash
# En Sport backend
export THALAMUS_API_KEY="ak_dev_vK8mN2pQ7xR9tY3wZ5aB1cD4eF6gH8jL..."
export ORGANIZATION_ID="660e8400-e29b-41d4-a716-446655440000"
export SPORT_URL="http://localhost:3001"

python sport/startup.py
```

**Resultado**:
```
✅ OAuth2 Client registrado!
   CLIENT_ID: client_abc123def456
   CLIENT_SECRET: secret_xyz789uvw012
⚠️  Guarda estas credenciales en variables de entorno!
```

---

#### **Paso 2: Sport configura OAuth2**

Sport guarda las credenciales y configura el flujo OAuth2:

```bash
# sport/.env
THALAMUS_URL=http://localhost:4000
OAUTH2_CLIENT_ID=client_abc123def456
OAUTH2_CLIENT_SECRET=secret_xyz789uvw012
SPORT_URL=http://localhost:3001
```

**Implementar flujo OAuth2 en Sport** (usando Authorization Code):

```python
# sport/auth.py
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import RedirectResponse
import httpx
import secrets
from config import THALAMUS_URL, OAUTH2_CLIENT_ID, OAUTH2_CLIENT_SECRET, SPORT_URL

app = FastAPI()

# Almacenamiento temporal de estados (en producción: usar Redis)
oauth_states = {}

@app.get("/login")
def login():
    """Redirige al usuario a Thalamus para autenticarse."""

    # Genera estado para CSRF protection
    state = secrets.token_urlsafe(32)
    oauth_states[state] = True  # Guarda el estado

    # Construye URL de autorización
    auth_url = (
        f"{THALAMUS_URL}/oauth/authorize"
        f"?response_type=code"
        f"&client_id={OAUTH2_CLIENT_ID}"
        f"&redirect_uri={SPORT_URL}/auth/callback"
        f"&scope=openid profile email sport:read sport:write"
        f"&state={state}"
    )

    return RedirectResponse(auth_url)


@app.get("/auth/callback")
async def oauth_callback(code: str, state: str):
    """Maneja el callback de Thalamus después de la autenticación."""

    # Verifica estado (CSRF protection)
    if state not in oauth_states:
        raise HTTPException(status_code=400, detail="Invalid state")

    del oauth_states[state]  # Limpia estado usado

    # Intercambia código por tokens
    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{THALAMUS_URL}/oauth/token",
            json={
                "grant_type": "authorization_code",
                "code": code,
                "client_id": OAUTH2_CLIENT_ID,
                "client_secret": OAUTH2_CLIENT_SECRET,
                "redirect_uri": f"{SPORT_URL}/auth/callback"
            },
            timeout=10.0
        )

    if response.status_code != 200:
        raise HTTPException(status_code=400, detail="Failed to exchange code")

    tokens = response.json()

    # Guarda tokens en sesión/cookies (implementación depende de tu app)
    # En producción: usar httpOnly cookies

    return {
        "message": "Login exitoso",
        "access_token": tokens["access_token"],
        "user": tokens.get("user")
    }


@app.get("/api/profile")
async def get_profile(request: Request):
    """Endpoint protegido que requiere autenticación."""

    # Obtiene token del header
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Not authenticated")

    token = auth_header.split(" ")[1]

    # Valida token con Thalamus
    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{THALAMUS_URL}/oauth/introspect",
            json={"token": token},
            timeout=5.0
        )

    if response.status_code != 200:
        raise HTTPException(status_code=401, detail="Invalid token")

    user_info = response.json()

    if not user_info.get("active"):
        raise HTTPException(status_code=401, detail="Token not active")

    return {
        "user_id": user_info["user_id"],
        "email": user_info["email"],
        "name": user_info.get("name"),
        "organization_id": user_info["organization_id"]
    }
```

---

#### **Paso 3: Usuarios autenticándose**

Ahora los usuarios pueden usar Sport:

```
1. Usuario visita: http://localhost:3001
2. Usuario hace clic en "Login"
3. Sport redirige a: http://localhost:4000/oauth/authorize?...
4. Usuario ingresa credenciales en Thalamus
5. Thalamus redirige a: http://localhost:3001/auth/callback?code=xxx
6. Sport intercambia código por tokens
7. Usuario autenticado → Puede usar Sport
```

**Flujo visual**:
```
┌──────────┐                  ┌──────────┐                  ┌──────────┐
│ Usuario  │                  │  Sport   │                  │ Thalamus │
└────┬─────┘                  └────┬─────┘                  └────┬─────┘
     │                             │                             │
     │  1. Click "Login"           │                             │
     ├───────────────────────────→ │                             │
     │                             │                             │
     │  2. Redirect /oauth/authorize                            │
     │  ←─────────────────────────┤                             │
     │                             │                             │
     │  3. GET /oauth/authorize                                 │
     ├─────────────────────────────────────────────────────────→│
     │                             │                             │
     │  4. Login form              │                             │
     │  ←─────────────────────────────────────────────────────┤
     │                             │                             │
     │  5. POST credentials        │                             │
     ├─────────────────────────────────────────────────────────→│
     │                             │                             │
     │  6. Redirect /auth/callback?code=abc                     │
     │  ←─────────────────────────────────────────────────────┤
     │                             │                             │
     │  7. GET /auth/callback?code=abc                          │
     ├───────────────────────────→ │                             │
     │                             │                             │
     │                             │  8. POST /oauth/token       │
     │                             │     (exchange code)         │
     │                             ├────────────────────────────→│
     │                             │                             │
     │                             │  9. { access_token, ... }   │
     │                             │  ←──────────────────────────┤
     │                             │                             │
     │  10. Logged in (with token) │                             │
     │  ←─────────────────────────┤                             │
     │                             │                             │
```

---

### 📋 Checklist de Integración

Use esta lista para verificar que la integración está completa:

#### Paso 0: Preparación
- [ ] Super admin tiene acceso a Thalamus
- [ ] Organización existe en Thalamus (o se creará con primer usuario)
- [ ] Se conoce el `organization_id` (o se obtendrá del registro)

#### Paso 1: Admin API Key
- [ ] Super admin creó Admin API Key para la vertical
- [ ] API Key tiene scopes correctos: `["clients:write", "clients:read"]`
- [ ] API Key guardado de forma segura (secrets manager o .env)
- [ ] API Key entregado al equipo de la vertical

#### Paso 2: Auto-registro OAuth2
- [ ] Vertical implementó script de auto-registro
- [ ] Script usa Admin API Key correctamente (`Authorization: ApiKey ...`)
- [ ] Script ejecutado exitosamente
- [ ] `client_id` y `client_secret` obtenidos
- [ ] Credenciales guardadas en variables de entorno

#### Paso 3: Configuración OAuth2
- [ ] Variables de entorno configuradas:
  - `THALAMUS_URL`
  - `OAUTH2_CLIENT_ID`
  - `OAUTH2_CLIENT_SECRET`
  - `REDIRECT_URI`
- [ ] Flujo OAuth2 implementado (Authorization Code o M2M)
- [ ] Endpoint `/login` redirige a Thalamus
- [ ] Endpoint `/auth/callback` maneja respuesta de Thalamus
- [ ] Tokens almacenados de forma segura (httpOnly cookies recomendado)

#### Paso 4: Protección de Endpoints
- [ ] Middleware de autenticación implementado
- [ ] Endpoints protegidos validan tokens con `/oauth/introspect`
- [ ] Manejo de tokens expirados (refresh token)
- [ ] Manejo de errores de autenticación (401, 403)

#### Paso 5: Testing
- [ ] Test de login funciona
- [ ] Test de callback funciona
- [ ] Test de endpoint protegido funciona
- [ ] Test de token expirado funciona
- [ ] Test de refresh token funciona

#### Paso 6: Producción
- [ ] Variables de entorno configuradas en producción
- [ ] HTTPS habilitado
- [ ] Cookies con `secure=true` y `httpOnly=true`
- [ ] CORS configurado correctamente
- [ ] Rate limiting configurado
- [ ] Logs de auditoría habilitados

---

## Quick Start

### Step 1: Start Thalamus Locally

**Option A: Using Docker (Recommended)**

```bash
# Clone the repository
git clone <thalamus-repo-url>
cd thalamus

# Start all services (PostgreSQL, Redis, Thalamus)
docker-compose up -d

# Verify services are running
docker-compose ps

# View logs
docker-compose logs -f thalamus
```

**Option B: Local Development**

```bash
# Install dependencies
mix deps.get

# Setup database
mix ecto.setup

# Start Phoenix server
mix phx.server
```

**Verify Installation:**

```bash
# Health check
curl http://localhost:4000/api/public/health

# Expected response:
# {
#   "status": "ok",
#   "version": "1.0.0",
#   "timestamp": "2025-12-24T10:00:00Z",
#   "checks": {
#     "database": "ok",
#     "cache": "ok"
#   }
# }
```

### Step 2: Register Your First User

```bash
curl -X POST http://localhost:4000/api/public/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "developer@example.com",
    "password": "SecurePass123!@#",
    "password_confirmation": "SecurePass123!@#",
    "name": "Developer User"
  }'
```

**Success Response (201 Created):**

```json
{
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "developer@example.com",
    "name": "Developer User",
    "email_verified": false,
    "created_at": "2025-12-24T10:00:00Z"
  },
  "organization": {
    "id": "660e8400-e29b-41d4-a716-446655440000",
    "name": "Developer User's Organization",
    "created_at": "2025-12-24T10:00:00Z"
  },
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 3600,
  "refresh_token": "def50200..."
}
```

### Step 3: Test Authentication

```bash
# Save the token from previous response
TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

# Test authenticated endpoint
curl -X GET http://localhost:4000/api/users \
  -H "Authorization: Bearer $TOKEN"
```

---

## Authentication Flows

### Flow 1: Direct API Authentication (Simplest)

**Use Case:** Mobile apps, SPAs, or trusted clients

```
┌─────────┐                                  ┌──────────┐
│  Client │                                  │ Thalamus │
└────┬────┘                                  └────┬─────┘
     │                                            │
     │  1. POST /api/public/login                │
     │    { email, password }                    │
     ├──────────────────────────────────────────>│
     │                                            │
     │  2. { access_token, refresh_token }       │
     │<──────────────────────────────────────────┤
     │                                            │
     │  3. GET /api/users                        │
     │    Authorization: Bearer <token>          │
     ├──────────────────────────────────────────>│
     │                                            │
     │  4. { users: [...] }                      │
     │<──────────────────────────────────────────┤
     │                                            │
```

**Implementation:**

```bash
# 1. Login
curl -X POST http://localhost:4000/api/public/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "developer@example.com",
    "password": "SecurePass123!@#"
  }'

# 2. Use token in subsequent requests
curl -X GET http://localhost:4000/api/users \
  -H "Authorization: Bearer <access_token>"
```

---

### Flow 2: OAuth2 Authorization Code Flow (Standard)

**Use Case:** Web applications with backend server

```
┌────────┐         ┌─────────┐         ┌──────────┐
│ Browser│         │Your App │         │ Thalamus │
└───┬────┘         └────┬────┘         └────┬─────┘
    │                   │                   │
    │ 1. Click Login    │                   │
    ├──────────────────>│                   │
    │                   │                   │
    │ 2. Redirect to /oauth/authorize       │
    │<──────────────────┤                   │
    │                   │                   │
    │ 3. GET /oauth/authorize?client_id=... │
    ├──────────────────────────────────────>│
    │                   │                   │
    │ 4. Login Screen   │                   │
    │<──────────────────────────────────────┤
    │                   │                   │
    │ 5. Enter credentials                  │
    ├──────────────────────────────────────>│
    │                   │                   │
    │ 6. Redirect with code                 │
    │<──────────────────────────────────────┤
    │                   │                   │
    │ 7. Send code      │                   │
    ├──────────────────>│                   │
    │                   │                   │
    │                   │ 8. POST /oauth/token
    │                   ├──────────────────>│
    │                   │                   │
    │                   │ 9. Access Token   │
    │                   │<──────────────────┤
    │                   │                   │
    │ 10. Authenticated │                   │
    │<──────────────────┤                   │
    │                   │                   │
```

**Step-by-Step:**

**1. Register OAuth2 Client:**

```bash
# In Thalamus IEx console
iex -S mix phx.server

# Create client
alias Thalamus.Domain.Entities.OAuth2Client
alias Thalamus.Infrastructure.Repositories.PostgresqlOAuth2ClientRepository

{:ok, client} = OAuth2Client.create(%{
  name: "My Web App",
  redirect_uris: ["http://localhost:3000/auth/callback"],
  scopes: ["openid", "profile", "email"]
})

{:ok, saved_client} = PostgresqlOAuth2ClientRepository.save(client)

# Note the client_id and client_secret
IO.puts("Client ID: #{saved_client.client_id}")
IO.puts("Client Secret: #{saved_client.client_secret}")
```

**2. Initiate Authorization:**

```javascript
// In your web app
const authUrl = new URL('http://localhost:4000/oauth/authorize');
authUrl.searchParams.append('response_type', 'code');
authUrl.searchParams.append('client_id', 'YOUR_CLIENT_ID');
authUrl.searchParams.append('redirect_uri', 'http://localhost:3000/auth/callback');
authUrl.searchParams.append('scope', 'openid profile email');
authUrl.searchParams.append('state', generateRandomState()); // CSRF protection

// Redirect user
window.location.href = authUrl.toString();
```

**3. Handle Callback:**

```javascript
// In your callback route (e.g., /auth/callback)
const code = urlParams.get('code');
const state = urlParams.get('state');

// Verify state matches (CSRF protection)
if (state !== sessionStorage.getItem('oauth_state')) {
  throw new Error('Invalid state');
}

// Exchange code for token (backend)
const response = await fetch('http://localhost:4000/oauth/token', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    grant_type: 'authorization_code',
    code: code,
    client_id: 'YOUR_CLIENT_ID',
    client_secret: 'YOUR_CLIENT_SECRET',
    redirect_uri: 'http://localhost:3000/auth/callback'
  })
});

const { access_token, refresh_token } = await response.json();
```

---

### Flow 3: Client Credentials (M2M - Machine-to-Machine)

**Use Case:** Backend service authentication without user context

This flow is perfect for:
- Microservices communicating with each other
- Backend jobs/workers
- System integrations (e.g., Campaigns backend connecting to Thalamus)
- API-to-API authentication

```
┌─────────────┐                              ┌──────────┐
│Your Backend │                              │ Thalamus │
└──────┬──────┘                              └────┬─────┘
       │                                          │
       │ 1. POST /oauth/token                    │
       │    grant_type=client_credentials        │
       │    client_id=<id>                       │
       │    client_secret=<secret>               │
       ├────────────────────────────────────────>│
       │                                          │
       │ 2. Validate credentials                 │
       │                            [Thalamus]   │
       │                                          │
       │ 3. { access_token, expires_in }         │
       │<────────────────────────────────────────┤
       │                                          │
       │ 4. GET /api/users                       │
       │    Authorization: Bearer <token>        │
       ├────────────────────────────────────────>│
       │                                          │
       │ 5. { users: [...] }                     │
       │<────────────────────────────────────────┤
       │                                          │
```

#### Step 1: Create OAuth2 Client for M2M (Automated with Admin API Keys)

**RECOMMENDED: Use Admin API Keys for Automated Setup**

El super admin crea un Admin API Key para tu servicio backend, y tu servicio se auto-registra como cliente M2M:

**1a. Super Admin crea Admin API Key:**

```bash
# Super admin crea API Key para Campaigns Backend
curl -X POST http://localhost:4000/api/admin/api-keys \
  -H "Authorization: Bearer <super_admin_jwt>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Campaigns Backend",
    "description": "API Key for Campaigns to register M2M client",
    "scopes": ["clients:write", "clients:read"],
    "expires_at": "2026-12-31T23:59:59Z"
  }'

# Guardar el api_key retornado
# Ejemplo: ak_dev_vK8mN2pQ7xR9tY3wZ5aB1cD4eF6gH8jL...
```

**1b. Tu Backend se Auto-Registra como Cliente M2M:**

**Python Example:**

```python
# campaigns/config.py
import os

THALAMUS_URL = os.getenv("THALAMUS_URL", "http://localhost:4000")
THALAMUS_API_KEY = os.getenv("THALAMUS_API_KEY")  # Admin API Key
ORGANIZATION_ID = os.getenv("ORGANIZATION_ID")

# campaigns/register_m2m.py
import httpx
import os
from config import THALAMUS_URL, THALAMUS_API_KEY, ORGANIZATION_ID

def register_m2m_client():
    """Auto-registro como cliente M2M usando Admin API Key."""

    headers = {
        "Authorization": f"ApiKey {THALAMUS_API_KEY}",
        "Content-Type": "application/json"
    }

    # Configuración para cliente M2M (sin redirect_uris)
    payload = {
        "name": "Campaigns Backend Service",
        "organization_id": ORGANIZATION_ID,
        "client_type": "confidential",
        "redirect_uris": [],  # No necesario para M2M
        "grant_types": ["client_credentials"],  # Solo M2M
        "scopes": [
            "campaigns:read",
            "campaigns:write",
            "leads:read",
            "leads:write",
            "organizations:read"
        ]
    }

    response = httpx.post(
        f"{THALAMUS_URL}/api/clients",
        headers=headers,
        json=payload,
        timeout=10.0
    )

    if response.status_code == 201:
        data = response.json()["data"]

        print("=" * 60)
        print("✅ M2M OAuth2 Client Registered Successfully!")
        print("=" * 60)
        print(f"CLIENT_ID:     {data['client_id']}")
        print(f"CLIENT_SECRET: {data['client_secret']}")
        print(f"SCOPES:        {', '.join(data['scopes'])}")
        print("=" * 60)
        print("⚠️  SAVE THESE CREDENTIALS IN YOUR .env FILE")
        print("=" * 60)

        # Opcional: Guardar en .env automáticamente (desarrollo)
        with open(".env", "a") as f:
            f.write(f"\nOAUTH2_CLIENT_ID={data['client_id']}\n")
            f.write(f"OAUTH2_CLIENT_SECRET={data['client_secret']}\n")

        return data
    else:
        print(f"❌ Error: {response.status_code}")
        print(response.json())
        raise Exception("Failed to register M2M client")

if __name__ == "__main__":
    register_m2m_client()
```

**Node.js Example:**

```javascript
// campaigns/registerM2M.js
const axios = require('axios');
const fs = require('fs');

const THALAMUS_URL = process.env.THALAMUS_URL || 'http://localhost:4000';
const THALAMUS_API_KEY = process.env.THALAMUS_API_KEY;
const ORGANIZATION_ID = process.env.ORGANIZATION_ID;

async function registerM2MClient() {
  try {
    const response = await axios.post(
      `${THALAMUS_URL}/api/clients`,
      {
        name: 'Campaigns Backend Service',
        organization_id: ORGANIZATION_ID,
        client_type: 'confidential',
        redirect_uris: [],  // No necesario para M2M
        grant_types: ['client_credentials'],
        scopes: [
          'campaigns:read',
          'campaigns:write',
          'leads:read',
          'leads:write',
          'organizations:read'
        ]
      },
      {
        headers: {
          'Authorization': `ApiKey ${THALAMUS_API_KEY}`,
          'Content-Type': 'application/json'
        }
      }
    );

    const { data } = response.data;

    console.log('='.repeat(60));
    console.log('✅ M2M OAuth2 Client Registered Successfully!');
    console.log('='.repeat(60));
    console.log(`CLIENT_ID:     ${data.client_id}`);
    console.log(`CLIENT_SECRET: ${data.client_secret}`);
    console.log(`SCOPES:        ${data.scopes.join(', ')}`);
    console.log('='.repeat(60));
    console.log('⚠️  SAVE THESE CREDENTIALS IN YOUR .env FILE');
    console.log('='.repeat(60));

    // Opcional: Guardar en .env automáticamente
    fs.appendFileSync('.env',
      `\nOAUTH2_CLIENT_ID=${data.client_id}\n` +
      `OAUTH2_CLIENT_SECRET=${data.client_secret}\n`
    );

    return data;
  } catch (error) {
    console.error('❌ Error:', error.response?.status);
    console.error(error.response?.data);
    throw error;
  }
}

registerM2MClient();
```

**Ejecutar el auto-registro:**

```bash
# Configurar Admin API Key
export THALAMUS_API_KEY="ak_dev_vK8mN2pQ7xR9tY3wZ5aB1cD4eF6gH8jL..."
export ORGANIZATION_ID="660e8400-e29b-41d4-a716-446655440000"

# Python
python campaigns/register_m2m.py

# Node.js
node campaigns/registerM2M.js
```

**Output:**
```
============================================================
✅ M2M OAuth2 Client Registered Successfully!
============================================================
CLIENT_ID:     550e8400-e29b-41d4-a716-446655440000
CLIENT_SECRET: abc123XYZ789_random_secret_here
SCOPES:        campaigns:read, campaigns:write, leads:read
============================================================
⚠️  SAVE THESE CREDENTIALS IN YOUR .env FILE
============================================================
```

---

**ALTERNATIVE: Manual Setup (No recomendado, usar solo para desarrollo)**

Si no puedes usar Admin API Keys, puedes crear el cliente manualmente:

**Option A: Using Seeds File**

Create `priv/repo/seeds_m2m_client.exs`:

```elixir
# Seeds file for creating M2M OAuth2 client
alias Thalamus.Repo
alias Thalamus.Infrastructure.Persistence.Schemas.{
  OAuth2ClientSchema,
  OrganizationSchema
}

# Get or create organization
organization = case Repo.get_by(OrganizationSchema, name: "System Services") do
  nil ->
    %OrganizationSchema{
      id: Ecto.UUID.generate(),
      name: "System Services",
      slug: "system-services",
      plan: "enterprise"
    }
    |> Repo.insert!()

  org -> org
end

# Generate client credentials
client_id = Ecto.UUID.generate()
client_secret = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

# Hash the secret (use Bcrypt)
client_secret_hash = Bcrypt.hash_pwd_salt(client_secret)

# Create M2M client
client = %OAuth2ClientSchema{
  id: Ecto.UUID.generate(),
  client_id_string: client_id,
  client_secret_hash: client_secret_hash,
  name: "My Backend Service",
  description: "Backend service for Campaigns module",
  organization_id: organization.id,
  client_type: "confidential",
  allowed_grant_types: ["client_credentials"],
  allowed_scopes: [
    "campaigns:read",
    "campaigns:write",
    "leads:read",
    "leads:write",
    "organizations:read"
  ],
  redirect_uris: [],  # Not needed for M2M
  is_active: true,
  token_endpoint_auth_method: "client_secret_post"
}
|> Repo.insert!()

IO.puts("\n========================================")
IO.puts("M2M OAuth2 Client Created!")
IO.puts("========================================")
IO.puts("Client ID:     #{client_id}")
IO.puts("Client Secret: #{client_secret}")
IO.puts("Name:          #{client.name}")
IO.puts("Scopes:        #{Enum.join(client.allowed_scopes, ", ")}")
IO.puts("\n⚠️  SAVE THESE CREDENTIALS - Secret cannot be retrieved later!")
IO.puts("========================================\n")
```

Run the seed file:

```bash
cd thalamus
mix run priv/repo/seeds_m2m_client.exs
```

**Save the output:**
```
Client ID:     550e8400-e29b-41d4-a716-446655440000
Client Secret: abc123XYZ789_random_secret_here
```

**Option B: Using IEx Console**

```bash
iex -S mix phx.server
```

```elixir
alias Thalamus.Repo
alias Thalamus.Infrastructure.Persistence.Schemas.OAuth2ClientSchema

# Generate credentials
client_id = Ecto.UUID.generate()
client_secret = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
client_secret_hash = Bcrypt.hash_pwd_salt(client_secret)

# Create client
client = %OAuth2ClientSchema{
  id: Ecto.UUID.generate(),
  client_id_string: client_id,
  client_secret_hash: client_secret_hash,
  name: "My Backend Service",
  organization_id: "your-org-uuid",  # Replace with your org ID
  client_type: "confidential",
  allowed_grant_types: ["client_credentials"],
  allowed_scopes: ["campaigns:read", "campaigns:write"],
  redirect_uris: [],
  is_active: true,
  token_endpoint_auth_method: "client_secret_post"
}

{:ok, saved_client} = Repo.insert(client)

IO.puts("Client ID: #{client_id}")
IO.puts("Client Secret: #{client_secret}")
```

**Option C: Using API (if available)**

```bash
# First, authenticate as admin user
curl -X POST http://localhost:4000/api/public/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@example.com",
    "password": "AdminPass123!@#"
  }'

# Then create OAuth2 client
curl -X POST http://localhost:4000/api/clients \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <admin_token>" \
  -d '{
    "name": "My Backend Service",
    "client_type": "confidential",
    "grant_types": ["client_credentials"],
    "scopes": ["campaigns:read", "campaigns:write"]
  }'
```

#### Step 2: Request Access Token

**Using cURL:**

```bash
# Set your credentials
CLIENT_ID="550e8400-e29b-41d4-a716-446655440000"
CLIENT_SECRET="abc123XYZ789_random_secret_here"

# Request token
curl -X POST http://localhost:4000/oauth/token \
  -H "Content-Type: application/json" \
  -d "{
    \"grant_type\": \"client_credentials\",
    \"client_id\": \"$CLIENT_ID\",
    \"client_secret\": \"$CLIENT_SECRET\",
    \"scope\": \"campaigns:read campaigns:write\"
  }"
```

**Success Response:**

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 3600,
  "scope": "campaigns:read campaigns:write"
}
```

**Note:** No `refresh_token` is returned for client_credentials grant. When the token expires, request a new one.

#### Step 3: Use Token to Access API

```bash
TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

# Access protected endpoints
curl -X GET http://localhost:4000/api/organizations \
  -H "Authorization: Bearer $TOKEN"

curl -X GET http://localhost:4000/api/users \
  -H "Authorization: Bearer $TOKEN"
```

#### Implementation Examples

**Python (for Campaigns Backend):**

```python
import httpx
import time
from typing import Optional

class ThalamusM2MClient:
    """Machine-to-Machine OAuth2 client for Thalamus."""

    def __init__(self, base_url: str, client_id: str, client_secret: str):
        self.base_url = base_url
        self.client_id = client_id
        self.client_secret = client_secret
        self._access_token: Optional[str] = None
        self._token_expires_at: Optional[float] = None

    async def get_access_token(self) -> str:
        """Get valid access token (cached or new)."""
        # Return cached token if still valid
        if self._access_token and self._token_expires_at:
            if time.time() < self._token_expires_at - 60:  # 60s buffer
                return self._access_token

        # Request new token
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.base_url}/oauth/token",
                json={
                    "grant_type": "client_credentials",
                    "client_id": self.client_id,
                    "client_secret": self.client_secret,
                    "scope": "campaigns:read campaigns:write leads:read leads:write"
                },
                timeout=10.0
            )

            response.raise_for_status()
            data = response.json()

            # Cache token
            self._access_token = data["access_token"]
            self._token_expires_at = time.time() + data["expires_in"]

            return self._access_token

    async def make_authenticated_request(
        self,
        method: str,
        endpoint: str,
        **kwargs
    ) -> httpx.Response:
        """Make authenticated request to Thalamus API."""
        token = await self.get_access_token()

        headers = kwargs.pop("headers", {})
        headers["Authorization"] = f"Bearer {token}"

        async with httpx.AsyncClient() as client:
            response = await client.request(
                method=method,
                url=f"{self.base_url}{endpoint}",
                headers=headers,
                **kwargs
            )

            # Handle token expiration
            if response.status_code == 401:
                # Token might be expired, clear cache and retry once
                self._access_token = None
                self._token_expires_at = None
                token = await self.get_access_token()
                headers["Authorization"] = f"Bearer {token}"

                response = await client.request(
                    method=method,
                    url=f"{self.base_url}{endpoint}",
                    headers=headers,
                    **kwargs
                )

            return response

    async def get_users(self):
        """Example: Get users from Thalamus."""
        response = await self.make_authenticated_request("GET", "/api/users")
        response.raise_for_status()
        return response.json()

    async def get_organizations(self):
        """Example: Get organizations from Thalamus."""
        response = await self.make_authenticated_request("GET", "/api/organizations")
        response.raise_for_status()
        return response.json()


# Usage in your application
thalamus_client = ThalamusM2MClient(
    base_url="http://localhost:4000",
    client_id="your-client-id",
    client_secret="your-client-secret"
)

# Use in FastAPI dependencies
async def get_thalamus_client() -> ThalamusM2MClient:
    return thalamus_client

# In your endpoints
from fastapi import Depends

@app.get("/campaigns")
async def list_campaigns(
    thalamus: ThalamusM2MClient = Depends(get_thalamus_client)
):
    # Get organization info from Thalamus
    orgs = await thalamus.get_organizations()
    return {"organizations": orgs}
```

**Node.js:**

```javascript
const axios = require('axios');

class ThalamusM2MClient {
  constructor(baseUrl, clientId, clientSecret) {
    this.baseUrl = baseUrl;
    this.clientId = clientId;
    this.clientSecret = clientSecret;
    this.accessToken = null;
    this.tokenExpiresAt = null;
  }

  async getAccessToken() {
    // Return cached token if valid
    if (this.accessToken && this.tokenExpiresAt) {
      if (Date.now() < this.tokenExpiresAt - 60000) { // 60s buffer
        return this.accessToken;
      }
    }

    // Request new token
    try {
      const response = await axios.post(
        `${this.baseUrl}/oauth/token`,
        {
          grant_type: 'client_credentials',
          client_id: this.clientId,
          client_secret: this.clientSecret,
          scope: 'campaigns:read campaigns:write'
        }
      );

      // Cache token
      this.accessToken = response.data.access_token;
      this.tokenExpiresAt = Date.now() + (response.data.expires_in * 1000);

      return this.accessToken;
    } catch (error) {
      throw new Error(`Failed to get access token: ${error.message}`);
    }
  }

  async request(method, endpoint, options = {}) {
    const token = await this.getAccessToken();

    try {
      const response = await axios({
        method,
        url: `${this.baseUrl}${endpoint}`,
        headers: {
          'Authorization': `Bearer ${token}`,
          ...options.headers
        },
        ...options
      });

      return response.data;
    } catch (error) {
      // Handle token expiration
      if (error.response?.status === 401) {
        // Clear cache and retry once
        this.accessToken = null;
        this.tokenExpiresAt = null;
        const newToken = await this.getAccessToken();

        const response = await axios({
          method,
          url: `${this.baseUrl}${endpoint}`,
          headers: {
            'Authorization': `Bearer ${newToken}`,
            ...options.headers
          },
          ...options
        });

        return response.data;
      }

      throw error;
    }
  }

  async getUsers() {
    return this.request('GET', '/api/users');
  }

  async getOrganizations() {
    return this.request('GET', '/api/organizations');
  }
}

// Usage
const thalamus = new ThalamusM2MClient(
  'http://localhost:4000',
  process.env.THALAMUS_CLIENT_ID,
  process.env.THALAMUS_CLIENT_SECRET
);

// In Express routes
app.get('/campaigns', async (req, res) => {
  try {
    const orgs = await thalamus.getOrganizations();
    res.json({ organizations: orgs });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});
```

#### Environment Variables

**For your backend service:**

```bash
# .env file
THALAMUS_URL=http://localhost:4000
THALAMUS_CLIENT_ID=550e8400-e29b-41d4-a716-446655440000
THALAMUS_CLIENT_SECRET=abc123XYZ789_random_secret_here
THALAMUS_SCOPES=campaigns:read,campaigns:write,leads:read,leads:write
```

**For production:**

```bash
THALAMUS_URL=https://auth.yourdomain.com
THALAMUS_CLIENT_ID=<production-client-id>
THALAMUS_CLIENT_SECRET=<production-client-secret>
```

#### Best Practices for M2M

1. **Token Caching:** Always cache tokens until they expire (minus safety buffer)
2. **Retry Logic:** Implement retry with backoff for token requests
3. **Scope Principle:** Request only the scopes you need
4. **Secret Storage:** Store client_secret in environment variables or secrets manager
5. **Token Rotation:** Request new token before expiration (don't wait for 401)
6. **Monitoring:** Log token request failures for debugging

#### Troubleshooting M2M

**Error: "Invalid client credentials"**

```bash
# Verify your credentials
echo "Client ID: $THALAMUS_CLIENT_ID"
echo "Client Secret: $THALAMUS_CLIENT_SECRET"

# Test manually
curl -X POST http://localhost:4000/oauth/token \
  -H "Content-Type: application/json" \
  -d "{
    \"grant_type\": \"client_credentials\",
    \"client_id\": \"$THALAMUS_CLIENT_ID\",
    \"client_secret\": \"$THALAMUS_CLIENT_SECRET\"
  }"
```

**Error: "Unsupported grant type"**

Your OAuth2 client might not have `client_credentials` in `allowed_grant_types`:

```sql
-- Check in Thalamus database
SELECT client_id_string, name, allowed_grant_types
FROM oauth2_clients
WHERE client_id_string = 'your-client-id';

-- Update if needed
UPDATE oauth2_clients
SET allowed_grant_types = ARRAY['client_credentials']
WHERE client_id_string = 'your-client-id';
```

**Error: "Invalid scope"**

The scopes you requested are not in the client's `allowed_scopes`:

```sql
-- Check allowed scopes
SELECT client_id_string, allowed_scopes
FROM oauth2_clients
WHERE client_id_string = 'your-client-id';

-- Add scopes
UPDATE oauth2_clients
SET allowed_scopes = ARRAY['campaigns:read', 'campaigns:write', 'leads:read']
WHERE client_id_string = 'your-client-id';
```

---

### Flow 4: Token Introspection (Backend Validation)

**Use Case:** Your backend needs to validate tokens from frontend

```
┌──────────┐         ┌─────────────┐         ┌──────────┐
│ Frontend │         │Your Backend │         │ Thalamus │
└────┬─────┘         └──────┬──────┘         └────┬─────┘
     │                      │                     │
     │ 1. Request + Token   │                     │
     ├─────────────────────>│                     │
     │                      │                     │
     │                      │ 2. POST /oauth/introspect
     │                      ├────────────────────>│
     │                      │    { token }        │
     │                      │                     │
     │                      │ 3. Token Info       │
     │                      │<────────────────────┤
     │                      │  { active, user_id, │
     │                      │    organization_id }│
     │                      │                     │
     │ 4. Response          │                     │
     │<─────────────────────┤                     │
     │                      │                     │
```

**Implementation:**

```bash
curl -X POST http://localhost:4000/oauth/introspect \
  -H "Content-Type: application/json" \
  -d '{
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }'
```

**Success Response:**

```json
{
  "active": true,
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "organization_id": "660e8400-e29b-41d4-a716-446655440000",
  "email": "developer@example.com",
  "name": "Developer User",
  "scopes": ["openid", "profile", "email"],
  "exp": 1702044000,
  "iat": 1702040400,
  "client_id": "client-uuid"
}
```

**Invalid Token Response:**

```json
{
  "active": false
}
```

---

## API Reference

### Core Endpoints

#### 1. User Registration

```http
POST /api/public/register
Content-Type: application/json
```

**Request Body:**

```json
{
  "email": "user@example.com",
  "password": "SecurePass123!@#",
  "password_confirmation": "SecurePass123!@#",
  "name": "John Doe",
  "organization_name": "Acme Corp" // Optional
}
```

**Validation Rules:**

- **Email:** Valid format, unique
- **Password:**
  - Minimum 8 characters
  - At least 1 uppercase letter
  - At least 1 lowercase letter
  - At least 1 number
  - At least 1 special character
- **Name:** Required, non-empty

**Success Response (201):**

```json
{
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "name": "John Doe",
    "email_verified": false,
    "created_at": "2025-12-24T10:00:00Z"
  },
  "organization": {
    "id": "uuid",
    "name": "Acme Corp"
  },
  "access_token": "eyJhbGci...",
  "token_type": "Bearer",
  "expires_in": 3600,
  "refresh_token": "def50200..."
}
```

**Error Response (422):**

```json
{
  "error": "validation_failed",
  "details": {
    "email": ["has already been taken"],
    "password": ["must contain at least one uppercase letter"]
  }
}
```

---

#### 2. User Login

```http
POST /api/public/login
Content-Type: application/json
```

**Request Body:**

```json
{
  "email": "user@example.com",
  "password": "SecurePass123!@#"
}
```

**Success Response (200):**

```json
{
  "access_token": "eyJhbGci...",
  "token_type": "Bearer",
  "expires_in": 3600,
  "refresh_token": "def50200...",
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "name": "John Doe",
    "email_verified": true
  },
  "organization": {
    "id": "uuid",
    "name": "Acme Corp"
  }
}
```

**Error Responses:**

```json
// 401 Unauthorized - Invalid credentials
{
  "error": "invalid_credentials",
  "message": "Invalid email or password"
}

// 423 Locked - Account locked
{
  "error": "account_locked",
  "message": "Account locked due to multiple failed login attempts"
}

// 403 Forbidden - MFA required
{
  "error": "mfa_required",
  "message": "Multi-factor authentication required",
  "mfa_token": "temp_token_for_mfa"
}
```

---

#### 3. Token Introspection

```http
POST /oauth/introspect
Content-Type: application/json
```

**Request Body:**

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Success Response (200):**

```json
{
  "active": true,
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "organization_id": "660e8400-e29b-41d4-a716-446655440000",
  "tenant_id": "660e8400-e29b-41d4-a716-446655440000", // Same as organization_id
  "email": "user@example.com",
  "name": "John Doe",
  "scopes": ["openid", "profile", "email", "campaigns:read"],
  "exp": 1702044000,
  "iat": 1702040400,
  "client_id": "client-uuid"
}
```

---

#### 4. Refresh Token

```http
POST /oauth/token
Content-Type: application/json
```

**Request Body:**

```json
{
  "grant_type": "refresh_token",
  "refresh_token": "def50200..."
}
```

**Success Response (200):**

```json
{
  "access_token": "new_access_token",
  "token_type": "Bearer",
  "expires_in": 3600,
  "refresh_token": "new_refresh_token" // Token rotation
}
```

---

#### 5. Get User Info (OpenID Connect)

```http
GET /oauth/userinfo
Authorization: Bearer <access_token>
```

**Success Response (200):**

```json
{
  "sub": "550e8400-e29b-41d4-a716-446655440000",
  "email": "user@example.com",
  "email_verified": true,
  "name": "John Doe",
  "organization_id": "660e8400-e29b-41d4-a716-446655440000",
  "organization_name": "Acme Corp"
}
```

---

### Available Scopes

**Standard OAuth2/OIDC Scopes:**

- `openid` - OpenID Connect authentication
- `profile` - User profile information
- `email` - User email address
- `offline_access` - Refresh token

**ZEA Platform Scopes:**

- `zea:read` - Read ZEA resources
- `zea:write` - Write ZEA resources
- `zea:admin` - Admin privileges
- `campaigns:read` - Read campaigns
- `campaigns:write` - Write campaigns
- `campaigns:sync` - Sync with external APIs
- `leads:read` - Read leads
- `leads:write` - Write leads
- `organizations:read` - Read organizations
- `organizations:write` - Manage organizations

---

### Admin API Keys (Service Authentication)

**Purpose:** Admin API Keys enable external services to authenticate and perform administrative operations without manual intervention. This is ideal for service-to-service (M2M) communication where services need to register OAuth2 clients or manage resources programmatically.

**Key Features:**

- 🔑 Cryptographically secure key generation
- 🎯 Scope-based permissions (fine-grained access control)
- ⏰ Optional expiration dates
- 🔄 Key rotation support
- 📊 Usage tracking (last_used_at)
- 🚫 Revocation capability

**Use Cases:**

1. **Service Self-Registration:** External services (e.g., Sport, Campaigns) can register themselves as OAuth2 clients
2. **Automated Client Management:** CI/CD pipelines creating OAuth2 clients
3. **Resource Management:** Services managing users, organizations via API

---

#### Creating an Admin API Key

**Endpoint:**

```http
POST /api/admin/api-keys
Authorization: Bearer <super_admin_jwt>
Content-Type: application/json
```

**Requirements:**

- Must authenticate with JWT (not API Key)
- Must have `super_admin` role
- API Keys cannot create other API Keys (security measure)

**Request Body:**

```json
{
  "name": "Sport Backend Registration",
  "description": "API Key for Sport service to register as OAuth2 client",
  "scopes": ["clients:write", "clients:read"],
  "expires_at": "2026-12-31T23:59:59Z"  // Optional
}
```

**Available Scopes:**

- `clients:read` - List and view OAuth2 clients
- `clients:write` - Create OAuth2 clients
- `clients:delete` - Delete OAuth2 clients
- `users:read` - View users
- `users:write` - Create/update users
- `organizations:read` - View organizations
- `organizations:write` - Create/update organizations
- `corpus:read` - Read corpus resources
- `corpus:write` - Create/update corpus resources

**Success Response (201 Created):**

```json
{
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "api_key": "ak_dev_vK8mN2pQ7xR9tY3wZ5aB1cD4eF6gH8jL0mN9pQ2rS4tU6vW8xY0zA1bC3dE5fG7hI9jK",
    "key_prefix": "ak_dev_vK8m",
    "name": "Sport Backend Registration",
    "description": "API Key for Sport service to register as OAuth2 client",
    "scopes": ["clients:write", "clients:read"],
    "is_active": true,
    "expires_at": "2026-12-31T23:59:59Z",
    "created_at": "2025-12-24T10:00:00Z"
  },
  "message": "⚠️ IMPORTANT: Save the api_key in a secure location. It cannot be retrieved later."
}
```

**⚠️ CRITICAL SECURITY WARNING:**

The full `api_key` is **ONLY shown once** during creation (and rotation). Store it securely immediately:

```bash
# Store in environment variable
export THALAMUS_API_KEY="ak_dev_vK8mN2pQ7xR9tY3wZ5aB1cD4eF6gH8jL0mN9pQ2rS4tU6vW8xY0zA1bC3dE5fG7hI9jK"

# Or in your secrets manager (e.g., AWS Secrets Manager, HashiCorp Vault)
aws secretsmanager create-secret \
  --name thalamus-api-key \
  --secret-string "$THALAMUS_API_KEY"
```

**Error Responses:**

```json
// 401 Unauthorized - Not authenticated
{
  "error": "Authentication required"
}

// 403 Forbidden - Not super_admin or using API Key
{
  "error": "Super admin access required"
}

// 403 Forbidden - API Key trying to create API Key
{
  "error": "API keys cannot access super admin endpoints. Use a super admin user account."
}

// 400 Bad Request - Invalid scopes
{
  "error": "Invalid scopes",
  "details": "The following scopes are not allowed: invalid:scope",
  "valid_scopes": ["clients:read", "clients:write", ...]
}
```

---

#### Using Admin API Keys for Authentication

**Authentication Header Format:**

```http
Authorization: ApiKey <your-api-key>
```

**Example: Register OAuth2 Client with API Key**

```bash
curl -X POST http://localhost:4000/api/clients \
  -H "Authorization: ApiKey ak_dev_vK8mN2pQ7xR9tY3wZ5aB1cD4eF6gH8jL0mN9pQ2rS4tU6vW8xY0zA1bC3dE5fG7hI9jK" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Sport Application",
    "organization_id": "660e8400-e29b-41d4-a716-446655440000",
    "client_type": "confidential",
    "redirect_uris": ["https://sport.example.com/oauth/callback"],
    "grant_types": ["authorization_code", "refresh_token"],
    "scopes": ["openid", "profile", "email"]
  }'
```

**Success Response (201 Created):**

```json
{
  "data": {
    "id": "770e8400-e29b-41d4-a716-446655440000",
    "client_id": "sport_abc123def456",
    "client_secret": "secret_xyz789uvw012",
    "name": "Sport Application",
    "organization_id": "660e8400-e29b-41d4-a716-446655440000",
    "client_type": "confidential",
    "redirect_uris": ["https://sport.example.com/oauth/callback"],
    "grant_types": ["authorization_code", "refresh_token"],
    "scopes": ["openid", "profile", "email"],
    "is_active": true,
    "created_at": "2025-12-24T10:30:00Z"
  },
  "message": "OAuth2 client created successfully"
}
```

**Scope Verification:**

If your API Key doesn't have the required scope:

```json
// 403 Forbidden
{
  "error": "Insufficient permissions",
  "details": "API key requires 'clients:write' scope to create OAuth2 clients"
}
```

---

#### Managing Admin API Keys

##### List All API Keys

```http
GET /api/admin/api-keys
Authorization: Bearer <super_admin_jwt>
```

**Query Parameters:**

- `is_active` - Filter by active status (true/false)
- `created_by` - Filter by creator user ID

**Success Response (200 OK):**

```json
{
  "data": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "key_prefix": "ak_dev_vK8m",  // Only prefix shown (security)
      "name": "Sport Backend Registration",
      "description": "API Key for Sport service",
      "scopes": ["clients:write", "clients:read"],
      "is_active": true,
      "last_used_at": "2025-12-24T15:00:00Z",
      "expires_at": "2026-12-31T23:59:59Z",
      "created_at": "2025-12-24T10:00:00Z",
      "updated_at": "2025-12-24T15:00:00Z"
    }
  ],
  "meta": {
    "count": 1
  }
}
```

---

##### Get Specific API Key

```http
GET /api/admin/api-keys/:id
Authorization: Bearer <super_admin_jwt>
```

**Success Response (200 OK):**

Same structure as individual item in list.

**Error Response (404):**

```json
{
  "error": "API key not found"
}
```

---

##### Revoke API Key

Deactivates an API Key (soft delete). The key can no longer be used for authentication.

```http
DELETE /api/admin/api-keys/:id
Authorization: Bearer <super_admin_jwt>
```

**Success Response (200 OK):**

```json
{
  "message": "API key revoked successfully",
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "is_active": false
  }
}
```

---

##### Rotate API Key

Generates a new secret for an existing API Key. The old key is immediately invalidated.

**Use this for:**
- Periodic key rotation (security best practice)
- Key compromise or suspected leak
- Compliance requirements

```http
POST /api/admin/api-keys/:id/rotate
Authorization: Bearer <super_admin_jwt>
```

**Success Response (200 OK):**

```json
{
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "api_key": "ak_dev_NEW_zX1yW2vU3tS4rQ5pO6nM7lK8jI9hG0fE1dC2bA3zA4yX5wV6uT7sR8qP9oN0mL",
    "key_prefix": "ak_dev_NEW_",
    "name": "Sport Backend Registration",
    "scopes": ["clients:write", "clients:read"]
  },
  "message": "⚠️ The old API key is no longer valid. Save the new api_key securely."
}
```

**⚠️ Important:** Update your service with the new key immediately to avoid downtime.

---

#### Admin API Keys Security Best Practices

1. **Principle of Least Privilege**
   - Only grant scopes that are absolutely necessary
   - Create separate API Keys for different services
   - Avoid granting write permissions unless required

2. **Secure Storage**
   ```bash
   # ✅ Good: Environment variable or secrets manager
   export THALAMUS_API_KEY="$(vault kv get -field=api_key secret/thalamus)"

   # ❌ Bad: Hardcoded in code
   API_KEY = "ak_dev_vK8mN2pQ7x..."  # NEVER DO THIS
   ```

3. **Rotation Schedule**
   - Rotate keys every 90 days (compliance best practice)
   - Rotate immediately if key is compromised
   - Automate rotation with CI/CD

4. **Monitoring and Auditing**
   - Monitor `last_used_at` timestamps
   - Revoke unused keys
   - Log all API Key usage for audit trails

5. **Expiration Dates**
   - Set expiration dates for temporary access
   - Review and extend before expiration
   - Clean up expired keys

6. **Network Security**
   - Always use HTTPS in production
   - Restrict API Key usage to specific IP ranges (if supported)
   - Use VPN or private networks when possible

---

#### Integration Example: Service Self-Registration

**Scenario:** Sport service needs to register itself as an OAuth2 client on startup.

**Step 1: Create Admin API Key (One-time, Super Admin)**

```bash
# Super admin creates API Key for Sport
curl -X POST http://thalamus.example.com/api/admin/api-keys \
  -H "Authorization: Bearer $SUPER_ADMIN_JWT" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Sport Service",
    "description": "API Key for Sport service client registration",
    "scopes": ["clients:write", "clients:read"],
    "expires_at": "2026-12-31T23:59:59Z"
  }'

# Save the returned api_key
export THALAMUS_API_KEY="ak_dev_vK8mN2pQ7xR9tY3wZ5aB1cD4eF6gH8jL..."
```

**Step 2: Sport Service Uses API Key (Automated)**

**Python Example:**

```python
import os
import httpx

THALAMUS_URL = os.getenv("THALAMUS_URL", "http://localhost:4000")
THALAMUS_API_KEY = os.getenv("THALAMUS_API_KEY")

def register_oauth2_client():
    """Register Sport as OAuth2 client using Admin API Key."""

    headers = {
        "Authorization": f"ApiKey {THALAMUS_API_KEY}",
        "Content-Type": "application/json"
    }

    payload = {
        "name": "Sport Application",
        "organization_id": os.getenv("ORGANIZATION_ID"),
        "client_type": "confidential",
        "redirect_uris": [
            f"{os.getenv('SPORT_URL')}/oauth/callback"
        ],
        "grant_types": ["authorization_code", "refresh_token"],
        "scopes": ["openid", "profile", "email", "sport:read", "sport:write"]
    }

    response = httpx.post(
        f"{THALAMUS_URL}/api/clients",
        headers=headers,
        json=payload,
        timeout=10.0
    )

    if response.status_code == 201:
        data = response.json()["data"]

        # Store client credentials securely
        os.environ["OAUTH2_CLIENT_ID"] = data["client_id"]
        os.environ["OAUTH2_CLIENT_SECRET"] = data["client_secret"]

        print(f"✅ OAuth2 client registered: {data['client_id']}")
        return data
    elif response.status_code == 403:
        print("❌ Insufficient permissions. Check API Key scopes.")
        raise Exception(response.json()["error"])
    else:
        print(f"❌ Registration failed: {response.status_code}")
        raise Exception(response.json())

# Call on service startup
if __name__ == "__main__":
    register_oauth2_client()
```

**Node.js Example:**

```javascript
const axios = require('axios');

const THALAMUS_URL = process.env.THALAMUS_URL || 'http://localhost:4000';
const THALAMUS_API_KEY = process.env.THALAMUS_API_KEY;

async function registerOAuth2Client() {
  try {
    const response = await axios.post(
      `${THALAMUS_URL}/api/clients`,
      {
        name: 'Sport Application',
        organization_id: process.env.ORGANIZATION_ID,
        client_type: 'confidential',
        redirect_uris: [`${process.env.SPORT_URL}/oauth/callback`],
        grant_types: ['authorization_code', 'refresh_token'],
        scopes: ['openid', 'profile', 'email', 'sport:read', 'sport:write']
      },
      {
        headers: {
          'Authorization': `ApiKey ${THALAMUS_API_KEY}`,
          'Content-Type': 'application/json'
        }
      }
    );

    const { data } = response.data;

    // Store credentials securely
    process.env.OAUTH2_CLIENT_ID = data.client_id;
    process.env.OAUTH2_CLIENT_SECRET = data.client_secret;

    console.log(`✅ OAuth2 client registered: ${data.client_id}`);
    return data;
  } catch (error) {
    if (error.response?.status === 403) {
      console.error('❌ Insufficient permissions. Check API Key scopes.');
    }
    throw error;
  }
}

// Call on service startup
registerOAuth2Client();
```

---

#### API Key Troubleshooting

**Error: "Missing or invalid Authorization header"**

```bash
# Check header format
curl -v http://localhost:4000/api/clients \
  -H "Authorization: ApiKey ak_dev_yourkey"

# NOT "Bearer", must be "ApiKey"
```

**Error: "Invalid API key format"**

API Keys must match the pattern `ak_{env}_{random}`:

```
✅ Valid:   ak_dev_vK8mN2pQ7xR9tY3w...
✅ Valid:   ak_live_zX1yW2vU3tS4rQ5p...
❌ Invalid: dev_vK8mN2pQ7xR9tY3w...
❌ Invalid: api_key_12345
```

**Error: "API key has been revoked"**

The API Key has been deactivated. Create a new key or contact the super admin.

**Error: "API key has expired"**

The `expires_at` date has passed. Rotate the key or create a new one.

**Error: "Insufficient permissions"**

The API Key doesn't have the required scope for the operation:

```bash
# Check your API Key's scopes
curl http://localhost:4000/api/admin/api-keys/:id \
  -H "Authorization: Bearer $SUPER_ADMIN_JWT"

# Response shows current scopes
{
  "data": {
    "scopes": ["clients:read"]  // Missing "clients:write"
  }
}
```

**Solution:** Create a new API Key with the correct scopes, or contact super admin to update scopes.

---

## Integration Examples

### Python (FastAPI)

**Install Dependencies:**

```bash
pip install fastapi httpx python-jose[cryptography]
```

**Implementation:**

```python
from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import httpx
from typing import Optional

app = FastAPI()
security = HTTPBearer()

# Configuration
THALAMUS_URL = "http://localhost:4000"

class ThalamusClient:
    def __init__(self, base_url: str):
        self.base_url = base_url

    async def introspect_token(self, token: str) -> dict:
        """Validate token with Thalamus."""
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.base_url}/oauth/introspect",
                json={"token": token},
                headers={"Content-Type": "application/json"},
                timeout=5.0
            )

            if response.status_code != 200:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Failed to introspect token"
                )

            data = response.json()

            if not data.get("active", False):
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Token is not active"
                )

            return data

    async def register_user(self, email: str, password: str, name: str) -> dict:
        """Register a new user."""
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.base_url}/api/public/register",
                json={
                    "email": email,
                    "password": password,
                    "password_confirmation": password,
                    "name": name
                },
                timeout=10.0
            )

            if response.status_code != 201:
                raise HTTPException(
                    status_code=response.status_code,
                    detail=response.json()
                )

            return response.json()

    async def login(self, email: str, password: str) -> dict:
        """Login user."""
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.base_url}/api/public/login",
                json={
                    "email": email,
                    "password": password
                },
                timeout=10.0
            )

            if response.status_code != 200:
                raise HTTPException(
                    status_code=response.status_code,
                    detail="Invalid credentials"
                )

            return response.json()

# Initialize client
thalamus = ThalamusClient(THALAMUS_URL)

# Dependency for authentication
async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> dict:
    """Get current user from token."""
    token = credentials.credentials
    user_info = await thalamus.introspect_token(token)
    return user_info

async def get_organization_id(
    user_info: dict = Depends(get_current_user)
) -> str:
    """Extract organization_id from token."""
    org_id = user_info.get("organization_id") or user_info.get("tenant_id")
    if not org_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No organization associated with user"
        )
    return org_id

# Example protected endpoint
@app.get("/api/profile")
async def get_profile(user: dict = Depends(get_current_user)):
    """Get user profile."""
    return {
        "user_id": user["user_id"],
        "email": user["email"],
        "name": user.get("name"),
        "organization_id": user.get("organization_id")
    }

# Example endpoint with organization context
@app.get("/api/campaigns")
async def list_campaigns(
    organization_id: str = Depends(get_organization_id),
    user: dict = Depends(get_current_user)
):
    """List campaigns for organization."""
    # Your business logic here
    return {
        "organization_id": organization_id,
        "campaigns": []
    }

# Registration endpoint
@app.post("/api/register")
async def register(email: str, password: str, name: str):
    """Register new user."""
    result = await thalamus.register_user(email, password, name)
    return result

# Login endpoint
@app.post("/api/login")
async def login(email: str, password: str):
    """Login user."""
    result = await thalamus.login(email, password)
    return result
```

---

### Node.js (Express)

**Install Dependencies:**

```bash
npm install express axios express-bearer-token
```

**Implementation:**

```javascript
const express = require('express');
const axios = require('axios');
const bearerToken = require('express-bearer-token');

const app = express();
app.use(express.json());
app.use(bearerToken());

const THALAMUS_URL = 'http://localhost:4000';

// Thalamus client
class ThalamusClient {
  constructor(baseUrl) {
    this.baseUrl = baseUrl;
    this.client = axios.create({
      baseURL: baseUrl,
      timeout: 5000,
    });
  }

  async introspectToken(token) {
    try {
      const response = await this.client.post('/oauth/introspect', {
        token: token
      });

      if (!response.data.active) {
        throw new Error('Token is not active');
      }

      return response.data;
    } catch (error) {
      throw new Error('Failed to introspect token: ' + error.message);
    }
  }

  async register(email, password, name) {
    const response = await this.client.post('/api/public/register', {
      email,
      password,
      password_confirmation: password,
      name
    });
    return response.data;
  }

  async login(email, password) {
    const response = await this.client.post('/api/public/login', {
      email,
      password
    });
    return response.data;
  }
}

const thalamus = new ThalamusClient(THALAMUS_URL);

// Authentication middleware
async function authenticate(req, res, next) {
  const token = req.token;

  if (!token) {
    return res.status(401).json({
      error: 'No token provided'
    });
  }

  try {
    const userInfo = await thalamus.introspectToken(token);
    req.user = userInfo;
    next();
  } catch (error) {
    return res.status(401).json({
      error: 'Invalid token',
      message: error.message
    });
  }
}

// Organization middleware
function requireOrganization(req, res, next) {
  const organizationId = req.user.organization_id || req.user.tenant_id;

  if (!organizationId) {
    return res.status(403).json({
      error: 'No organization associated with user'
    });
  }

  req.organizationId = organizationId;
  next();
}

// Public endpoints
app.post('/api/register', async (req, res) => {
  try {
    const { email, password, name } = req.body;
    const result = await thalamus.register(email, password, name);
    res.status(201).json(result);
  } catch (error) {
    res.status(400).json({
      error: 'Registration failed',
      message: error.message
    });
  }
});

app.post('/api/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    const result = await thalamus.login(email, password);
    res.json(result);
  } catch (error) {
    res.status(401).json({
      error: 'Login failed',
      message: error.message
    });
  }
});

// Protected endpoints
app.get('/api/profile', authenticate, (req, res) => {
  res.json({
    user_id: req.user.user_id,
    email: req.user.email,
    name: req.user.name,
    organization_id: req.user.organization_id
  });
});

app.get('/api/campaigns', authenticate, requireOrganization, (req, res) => {
  // Your business logic here
  res.json({
    organization_id: req.organizationId,
    campaigns: []
  });
});

app.listen(3000, () => {
  console.log('Server running on port 3000');
});
```

---

### JavaScript (Frontend - React)

```javascript
// authService.js
const THALAMUS_URL = 'http://localhost:4000';

class AuthService {
  async register(email, password, name) {
    const response = await fetch(`${THALAMUS_URL}/api/public/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email,
        password,
        password_confirmation: password,
        name
      })
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.message || 'Registration failed');
    }

    const data = await response.json();
    this.setTokens(data.access_token, data.refresh_token);
    return data;
  }

  async login(email, password) {
    const response = await fetch(`${THALAMUS_URL}/api/public/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password })
    });

    if (!response.ok) {
      throw new Error('Invalid credentials');
    }

    const data = await response.json();
    this.setTokens(data.access_token, data.refresh_token);
    return data;
  }

  async refreshToken() {
    const refreshToken = localStorage.getItem('refresh_token');

    if (!refreshToken) {
      throw new Error('No refresh token available');
    }

    const response = await fetch(`${THALAMUS_URL}/oauth/token`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        grant_type: 'refresh_token',
        refresh_token: refreshToken
      })
    });

    if (!response.ok) {
      this.logout();
      throw new Error('Token refresh failed');
    }

    const data = await response.json();
    this.setTokens(data.access_token, data.refresh_token);
    return data;
  }

  setTokens(accessToken, refreshToken) {
    localStorage.setItem('access_token', accessToken);
    localStorage.setItem('refresh_token', refreshToken);
  }

  getAccessToken() {
    return localStorage.getItem('access_token');
  }

  logout() {
    localStorage.removeItem('access_token');
    localStorage.removeItem('refresh_token');
  }

  isAuthenticated() {
    return !!this.getAccessToken();
  }
}

export default new AuthService();

// apiClient.js
import authService from './authService';

class ApiClient {
  constructor(baseUrl) {
    this.baseUrl = baseUrl;
  }

  async request(endpoint, options = {}) {
    const token = authService.getAccessToken();

    const headers = {
      'Content-Type': 'application/json',
      ...options.headers
    };

    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    const response = await fetch(`${this.baseUrl}${endpoint}`, {
      ...options,
      headers
    });

    // Handle token expiration
    if (response.status === 401) {
      try {
        await authService.refreshToken();
        // Retry original request with new token
        return this.request(endpoint, options);
      } catch (error) {
        authService.logout();
        window.location.href = '/login';
        throw error;
      }
    }

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.message || 'Request failed');
    }

    return response.json();
  }

  async get(endpoint) {
    return this.request(endpoint, { method: 'GET' });
  }

  async post(endpoint, data) {
    return this.request(endpoint, {
      method: 'POST',
      body: JSON.stringify(data)
    });
  }
}

export default new ApiClient('http://localhost:3000/api');
```

---

## Security Best Practices

### 1. Token Storage

**DO:**
- Store tokens in httpOnly cookies (backend)
- Use secure session storage (backend)
- Implement token rotation
- Set appropriate expiration times

**DON'T:**
- Store tokens in localStorage (XSS vulnerable)
- Store refresh tokens in frontend
- Use tokens without expiration
- Share tokens between users

**Example (Secure Cookie Storage):**

```javascript
// Backend - Set httpOnly cookie
res.cookie('access_token', token, {
  httpOnly: true,
  secure: process.env.NODE_ENV === 'production',
  sameSite: 'strict',
  maxAge: 3600000 // 1 hour
});
```

---

### 2. HTTPS Only in Production

```javascript
// Production configuration
const THALAMUS_URL = process.env.NODE_ENV === 'production'
  ? 'https://auth.yourdomain.com'
  : 'http://localhost:4000';
```

---

### 3. CSRF Protection

```javascript
// Generate and validate state parameter
function generateState() {
  return crypto.randomBytes(32).toString('hex');
}

// Store state in session
sessionStorage.setItem('oauth_state', state);

// Validate on callback
const receivedState = urlParams.get('state');
if (receivedState !== sessionStorage.getItem('oauth_state')) {
  throw new Error('CSRF attack detected');
}
```

---

### 4. Rate Limiting

Respect Thalamus rate limits:

- Public API: 1,000 req/min per IP
- OAuth2 endpoints: 20 req/min per IP
- Authenticated API: 5,000 req/min per user

**Handle Rate Limit Errors:**

```javascript
if (response.status === 429) {
  const retryAfter = response.headers.get('Retry-After');
  console.log(`Rate limited. Retry after ${retryAfter} seconds`);
}
```

---

### 5. Error Handling

```python
async def safe_introspect(token: str) -> Optional[dict]:
    """Safely introspect token with retry logic."""
    max_retries = 3

    for attempt in range(max_retries):
        try:
            return await thalamus.introspect_token(token)
        except httpx.TimeoutException:
            if attempt == max_retries - 1:
                raise
            await asyncio.sleep(2 ** attempt)  # Exponential backoff
        except httpx.HTTPStatusError as e:
            if e.response.status_code == 429:
                # Rate limited
                retry_after = int(e.response.headers.get('Retry-After', 60))
                await asyncio.sleep(retry_after)
            else:
                raise
```

---

## Troubleshooting

### Common Issues

#### 1. "Invalid credentials" on login

**Cause:** Wrong email/password or account locked

**Solution:**
```bash
# Check user exists
curl http://localhost:4000/api/public/health

# Verify password requirements:
# - Min 8 chars
# - 1 uppercase, 1 lowercase, 1 number, 1 special char
```

---

#### 2. "Token is not active" on introspection

**Cause:** Token expired or revoked

**Solution:**
```python
# Use refresh token to get new access token
async def refresh_access_token(refresh_token: str):
    response = await client.post(
        f"{THALAMUS_URL}/oauth/token",
        json={
            "grant_type": "refresh_token",
            "refresh_token": refresh_token
        }
    )
    return response.json()
```

---

#### 3. CORS errors in browser

**Cause:** Thalamus CORS not configured for your origin

**Solution:**
```bash
# Configure CORS in Thalamus
# Add your origin to config/dev.exs or environment variable
CORS_ORIGINS=http://localhost:3000,http://localhost:8001
```

---

#### 4. 429 Rate Limit Exceeded

**Cause:** Too many requests

**Solution:**
```javascript
// Implement exponential backoff
async function fetchWithRetry(url, options, maxRetries = 3) {
  for (let i = 0; i < maxRetries; i++) {
    const response = await fetch(url, options);

    if (response.status !== 429) {
      return response;
    }

    const retryAfter = response.headers.get('Retry-After') || 60;
    await new Promise(resolve => setTimeout(resolve, retryAfter * 1000));
  }

  throw new Error('Max retries exceeded');
}
```

---

#### 5. Database connection errors

**Cause:** PostgreSQL not running or wrong credentials

**Solution:**
```bash
# Check PostgreSQL status
docker-compose ps postgres

# Restart database
docker-compose restart postgres

# Check logs
docker-compose logs postgres
```

---

### Debug Mode

**Enable debug logging:**

```bash
# In Thalamus .env
export LOG_LEVEL=debug

# Restart server
docker-compose restart thalamus

# View logs
docker-compose logs -f thalamus
```

---

## Testing

### Test Environment Setup

```bash
# Start test instance
MIX_ENV=test mix test

# Or with Docker
docker-compose -f docker-compose.test.yml up
```

---

### Test Users

Create test users for development:

```bash
# Create test user
curl -X POST http://localhost:4000/api/public/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "Test123!@#",
    "password_confirmation": "Test123!@#",
    "name": "Test User"
  }'
```

---

### Integration Tests

**Example Test Suite (Python + pytest):**

```python
import pytest
import httpx

THALAMUS_URL = "http://localhost:4000"

@pytest.fixture
async def registered_user():
    """Create and return a registered user."""
    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{THALAMUS_URL}/api/public/register",
            json={
                "email": f"test_{uuid.uuid4()}@example.com",
                "password": "Test123!@#",
                "password_confirmation": "Test123!@#",
                "name": "Test User"
            }
        )
        assert response.status_code == 201
        return response.json()

@pytest.mark.asyncio
async def test_login(registered_user):
    """Test user login."""
    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{THALAMUS_URL}/api/public/login",
            json={
                "email": registered_user["user"]["email"],
                "password": "Test123!@#"
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert "refresh_token" in data

@pytest.mark.asyncio
async def test_token_introspection(registered_user):
    """Test token introspection."""
    token = registered_user["access_token"]

    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{THALAMUS_URL}/oauth/introspect",
            json={"token": token}
        )
        assert response.status_code == 200
        data = response.json()
        assert data["active"] is True
        assert data["user_id"] == registered_user["user"]["id"]

@pytest.mark.asyncio
async def test_protected_endpoint(registered_user):
    """Test accessing protected endpoint."""
    token = registered_user["access_token"]

    async with httpx.AsyncClient() as client:
        response = await client.get(
            f"{THALAMUS_URL}/api/users",
            headers={"Authorization": f"Bearer {token}"}
        )
        assert response.status_code == 200
```

---

### Postman Collection

**Import this JSON into Postman:**

```json
{
  "info": {
    "name": "ZEA Thalamus API",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "variable": [
    {
      "key": "base_url",
      "value": "http://localhost:4000"
    },
    {
      "key": "access_token",
      "value": ""
    }
  ],
  "item": [
    {
      "name": "Register User",
      "request": {
        "method": "POST",
        "header": [
          {
            "key": "Content-Type",
            "value": "application/json"
          }
        ],
        "body": {
          "mode": "raw",
          "raw": "{\n  \"email\": \"test@example.com\",\n  \"password\": \"Test123!@#\",\n  \"password_confirmation\": \"Test123!@#\",\n  \"name\": \"Test User\"\n}"
        },
        "url": "{{base_url}}/api/public/register"
      },
      "event": [
        {
          "listen": "test",
          "script": {
            "exec": [
              "if (pm.response.code === 201) {",
              "  var data = pm.response.json();",
              "  pm.environment.set('access_token', data.access_token);",
              "}"
            ]
          }
        }
      ]
    },
    {
      "name": "Login",
      "request": {
        "method": "POST",
        "header": [
          {
            "key": "Content-Type",
            "value": "application/json"
          }
        ],
        "body": {
          "mode": "raw",
          "raw": "{\n  \"email\": \"test@example.com\",\n  \"password\": \"Test123!@#\"\n}"
        },
        "url": "{{base_url}}/api/public/login"
      },
      "event": [
        {
          "listen": "test",
          "script": {
            "exec": [
              "if (pm.response.code === 200) {",
              "  var data = pm.response.json();",
              "  pm.environment.set('access_token', data.access_token);",
              "}"
            ]
          }
        }
      ]
    },
    {
      "name": "Introspect Token",
      "request": {
        "method": "POST",
        "header": [
          {
            "key": "Content-Type",
            "value": "application/json"
          }
        ],
        "body": {
          "mode": "raw",
          "raw": "{\n  \"token\": \"{{access_token}}\"\n}"
        },
        "url": "{{base_url}}/oauth/introspect"
      }
    },
    {
      "name": "Get Users (Protected)",
      "request": {
        "method": "GET",
        "header": [
          {
            "key": "Authorization",
            "value": "Bearer {{access_token}}"
          }
        ],
        "url": "{{base_url}}/api/users"
      }
    }
  ]
}
```

---

## Production Deployment

### Environment Variables

**Required for Production:**

```bash
# Database
DATABASE_URL=postgresql://user:pass@host:5432/thalamus_prod
DB_POOL_SIZE=20

# Security (generate with: mix phx.gen.secret)
SECRET_KEY_BASE=your-64-char-secret-key
VERIFICATION_TOKEN_SECRET=your-secret
PASSWORD_RESET_SECRET=your-secret
SESSION_SECRET=your-secret

# Server
PHX_HOST=auth.yourdomain.com
PORT=4000
PHX_SERVER=true

# CORS
CORS_ORIGINS=https://yourdomain.com,https://app.yourdomain.com

# Redis
REDIS_URL=redis://user:pass@host:6379/0

# Email
EMAIL_MODE=production
SMTP_HOST=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USERNAME=apikey
SMTP_PASSWORD=your-sendgrid-api-key
EMAIL_FROM=noreply@yourdomain.com
EMAIL_BASE_URL=https://auth.yourdomain.com

# Monitoring
SENTRY_DSN=https://your-sentry-dsn
```

---

### Health Checks

```bash
# Kubernetes liveness probe
curl http://localhost:4000/api/public/health

# Expected: HTTP 200
# { "status": "ok", "checks": { "database": "ok", "cache": "ok" } }
```

---

### Monitoring

**Metrics endpoints:**

```bash
# Prometheus metrics
curl http://localhost:4000/metrics

# Application metrics
curl http://localhost:4000/api/public/health
```

---

## Support & Resources

### Documentation

- **API Specification:** [OPENAPI_SPEC.yaml](./OPENAPI_SPEC.yaml)
- **Architecture:** [ARCHITECTURE.md](./ARCHITECTURE.md)
- **Deployment Guide:** [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)
- **Project Status:** [PROJECT_STATUS.md](./PROJECT_STATUS.md)

### Example Code

- **Python:** See "Integration Examples" section
- **Node.js:** See "Integration Examples" section
- **React:** See "Integration Examples" section

### Issues & Questions

- GitHub Issues: [Link to your repo issues]
- Email: support@yourdomain.com
- Documentation: https://docs.yourdomain.com

---

## Changelog

### Version 1.0.0 (2025-12-24)

- Initial release of integration guide
- Added examples for Python, Node.js, JavaScript
- Added troubleshooting section
- Added Postman collection
- Added production deployment guide

---

**Happy integrating! 🚀**

For questions or feedback, please contact the ZEA Thalamus team.
