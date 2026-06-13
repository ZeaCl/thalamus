---
name: thalamus-auth
description: "Configurar OAuth2 PKCE con Thalamus para un nuevo servicio o SPA. Usar cuando se crea un servicio ZEA nuevo, se necesita login con ZEA Platform, o el OAuth2 flow falla. Triggers: 'conectar con Thalamus', 'login con ZEA', 'OAuth2 client', 'PKCE setup', 'auth redirect no funciona', 'CORS token endpoint', 'register OAuth2 client'."
---

# Thalamus Auth — OAuth2 Client Setup

## 🎯 Qué hace

Guía completa para conectar un servicio nuevo (backend o SPA) con Thalamus vía OAuth2 PKCE.

## ⚡ Quick Check (antes de debuggear)

Si el OAuth2 flow falla, verificá en este orden:

```
1. ¿El OAuth2 client existe en Thalamus?
   → RPC: Thalamus.Repo.get_by(OAuth2ClientSchema, client_id_string: "mi_servicio")

2. ¿Tiene los scopes correctos?
   → allowed_scopes DEBE incluir "openid" como mínimo

3. ¿Tiene el grant type correcto?
   → SPA necesita "authorization_code", backend "client_credentials"

4. ¿El redirect_uri está registrado?
   → Debe matchear EXACTO (incluyendo http:// y el path)

5. ¿CORS está configurado?
   → El dominio del servicio DEBE estar en CORS_ORIGINS de Thalamus

6. ¿El tipo de cliente es correcto?
   → SPA = public + auth_method "none", Backend = confidential + "client_secret_post"
```

---

## 📋 Checklist: Nuevo Servicio → Thalamus

### 1. Registrar OAuth2 Client

```bash
# Conectarse al container de Thalamus
docker exec zea_thalamus_local bin/thalamus rpc '
```

#### 🖥️ SPA / Frontend (ej: Soma, Cranium shell, Südlich)

```elixir
# Cliente PÚBLICO — sin client_secret, PKCE requerido
client = %Thalamus.Infrastructure.Persistence.Schemas.OAuth2ClientSchema{
  id: Ecto.UUID.generate(),
  client_id_string: "soma_service",         # ← slug único
  name: "Soma — Agent Hub",                 # ← nombre descriptivo
  client_type: :public,                      # ⚠️ PUBLIC (no confidential)
  is_active: true,
  allowed_grant_types: ["authorization_code", "refresh_token"],
  allowed_scopes: ["openid", "profile", "email"],
  redirect_uris: ["http://soma.zea.localhost/callback"],
  pkce_required: true,                       # ⚠️ OBLIGATORIO para SPAs
  token_endpoint_auth_method: "none",        # ⚠️ "none" para public clients
  organization_id: "5fd11ea0-852c-44e5-aee1-a761ec76eaea"
}
Thalamus.Repo.insert!(client)
```

#### ⚙️ Backend / Service-to-Service

```elixir
# Cliente CONFIDENCIAL — con client_secret, client_credentials grant
client = %Thalamus.Infrastructure.Persistence.Schemas.OAuth2ClientSchema{
  id: Ecto.UUID.generate(),
  client_id_string: "mi_servicio_internal",
  name: "Mi Servicio",
  client_type: :confidential,
  client_secret: "cambio_esto_en_produccion",  # bcrypt hasheado en prod
  is_active: true,
  allowed_grant_types: ["client_credentials"],
  allowed_scopes: ["openid", "mi_servicio:read", "mi_servicio:write"],
  redirect_uris: [],
  pkce_required: false,
  token_endpoint_auth_method: "client_secret_post",
  organization_id: "5fd11ea0-852c-44e5-aee1-a761ec76eaea"
}
Thalamus.Repo.insert!(client)
```

### 2. Actualizar Cliente Existente

```elixir
client = Thalamus.Repo.get_by(
  Thalamus.Infrastructure.Persistence.Schemas.OAuth2ClientSchema,
  client_id_string: "soma_service"
)
changeset = Ecto.Changeset.change(client,
  client_type: :public,
  token_endpoint_auth_method: "none",
  pkce_required: true,
  allowed_grant_types: ["authorization_code", "refresh_token", "client_credentials"],
  allowed_scopes: ["openid", "profile", "email"],
  redirect_uris: ["http://soma.zea.localhost/callback", "http://localhost:5173/callback"]
)
Thalamus.Repo.update!(changeset)
'
```

### 3. Configurar CORS en Thalamus

```yaml
# En docker-compose.local.yml → thalamus → environment:
CORS_ORIGINS: "...,http://soma.zea.localhost,http://cranium.zea.localhost,..."
```

```bash
# Rebuild después de cambiar CORS_ORIGINS
docker compose up -d thalamus
```

**Verificar:**
```bash
curl -s -X OPTIONS 'http://auth.zea.localhost/oauth/token' \
  -H 'Origin: http://soma.zea.localhost' \
  -H 'Access-Control-Request-Method: POST' \
  -H 'Access-Control-Request-Headers: Content-Type' \
  -I | grep 'Access-Control-Allow-Origin'
# Debe devolver: Access-Control-Allow-Origin: http://soma.zea.localhost
```

---

## 🔄 Flujo OAuth2 PKCE (SPA)

```
1. SPA genera code_verifier (random) + code_challenge (SHA256 del verifier)
2. Guarda verifier en sessionStorage
3. Redirect a:
   auth.zea.localhost/oauth/authorize?
     client_id={CLIENT_ID}&
     redirect_uri={CALLBACK}&
     response_type=code&
     code_challenge={CHALLENGE}&
     code_challenge_method=S256&
     scope=openid+profile+email&
     state={RANDOM}

4. Usuario hace login en Thalamus → ve pantalla de consentimiento
5. Click "Authorize" → Thalamus redirige a {CALLBACK}?code={CODE}&state={STATE}
6. SPA intercambia code por token:
   POST auth.zea.localhost/oauth/token
   { grant_type: "authorization_code", client_id, code, code_verifier, redirect_uri }

7. Respuesta: { access_token, refresh_token, expires_in }
8. SPA guarda token en localStorage
```

### Implementación TypeScript (SPA)

```typescript
const CLIENT_ID = 'soma_service'
const AUTH_URL = 'http://auth.zea.localhost'
const REDIRECT_URI = 'http://soma.zea.localhost/callback'

// PKCE helpers
function base64URLEncode(buffer: ArrayBuffer): string {
  return btoa(String.fromCharCode(...new Uint8Array(buffer)))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

export function generatePKCE() {
  const verifier = base64URLEncode(crypto.getRandomValues(new Uint8Array(32)))
  const challenge = crypto.subtle.digest('SHA-256', new TextEncoder().encode(verifier))
    .then(base64URLEncode)
  return { verifier, challenge }
}

export function getAuthorizationUrl(codeChallenge: string): string {
  return `${AUTH_URL}/oauth/authorize?${new URLSearchParams({
    client_id: CLIENT_ID,
    redirect_uri: REDIRECT_URI,
    response_type: 'code',
    code_challenge: codeChallenge,
    code_challenge_method: 'S256',
    scope: 'openid profile email',
    state: crypto.randomUUID(),
  })}`
}

export async function exchangeCode(code: string, codeVerifier: string): Promise<string> {
  const res = await fetch(`${AUTH_URL}/oauth/token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      grant_type: 'authorization_code',
      client_id: CLIENT_ID,
      code,
      code_verifier: codeVerifier,
      redirect_uri: REDIRECT_URI,
    }),
  })
  if (!res.ok) throw new Error(`Token exchange failed: ${res.status}`)
  return (await res.json()).access_token
}
```

---

## 🧪 Testing

```bash
# 1. Verificar discovery
curl http://auth.zea.localhost/.well-known/jwks.json | jq

# 2. Verificar OAuth2 client
docker exec zea_thalamus_local bin/thalamus rpc '
  Thalamus.Repo.get_by(
    Thalamus.Infrastructure.Persistence.Schemas.OAuth2ClientSchema,
    client_id_string: "soma_service"
  ) |> IO.inspect
'

# 3. Verificar CORS
curl -s -X OPTIONS 'http://auth.zea.localhost/oauth/token' \
  -H 'Origin: http://soma.zea.localhost' \
  -H 'Access-Control-Request-Method: POST' \
  -I | grep 'Access-Control'

# 4. Verificar callback
curl -sI http://soma.zea.localhost/callback
# Debe devolver 200 (SPA serve index.html)

# 5. Probar token exchange (con código real)
curl -X POST http://auth.zea.localhost/oauth/token \
  -H 'Content-Type: application/json' \
  -H 'Origin: http://soma.zea.localhost' \
  -d '{"grant_type":"authorization_code","client_id":"soma_service","code":"...","code_verifier":"...","redirect_uri":"http://soma.zea.localhost/callback"}'
```

---

## ❌ Errores Comunes

| Error | Causa | Solución |
|-------|-------|----------|
| `invalid_scope` | Scopes no incluidos en `allowed_scopes` del cliente | Agregar scopes al cliente o pedir solo `openid` |
| `invalid_client` | Client ID no existe o está inactivo | Verificar `client_id_string` en DB |
| `invalid_redirect_uri` | URI no registrada en `redirect_uris` | Agregar la URI exacta (incluye `http://`) |
| `invalid_grant` al exchange | Code expirado (10 min) o code_verifier no matchea | Verificar PKCE en sessionStorage |
| OPTIONS 403 en /oauth/token | Dominio no en CORS | Agregar a `CORS_ORIGINS` en docker-compose |
| 302 redirect pero no navega | Token exchange falla por CORS | Verificar `Access-Control-Allow-Origin` |
| `client_secret_post` con SPA | Cliente confidential sin secret | Cambiar a `public` + `auth_method: "none"` |
| Formulario authorize no redirige | `authorization_code` no en `allowed_grant_types` | Agregar grant type al cliente |
