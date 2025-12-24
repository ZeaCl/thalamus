# ZEA Thalamus - Integration Guide

**Official Integration Guide for External Teams**

Version: 1.0.0
Last Updated: December 24, 2024
Service: ZEA Thalamus OAuth2 Authentication Service

---

## Table of Contents

1. [Introduction](#introduction)
2. [Quick Start](#quick-start)
3. [Authentication Flows](#authentication-flows)
4. [API Reference](#api-reference)
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
#   "timestamp": "2024-12-24T10:00:00Z",
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
    "created_at": "2024-12-24T10:00:00Z"
  },
  "organization": {
    "id": "660e8400-e29b-41d4-a716-446655440000",
    "name": "Developer User's Organization",
    "created_at": "2024-12-24T10:00:00Z"
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

### Flow 3: Token Introspection (Backend Validation)

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
    "created_at": "2024-12-24T10:00:00Z"
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

### Version 1.0.0 (2024-12-24)

- Initial release of integration guide
- Added examples for Python, Node.js, JavaScript
- Added troubleshooting section
- Added Postman collection
- Added production deployment guide

---

**Happy integrating! 🚀**

For questions or feedback, please contact the ZEA Thalamus team.
