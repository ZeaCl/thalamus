# Admin API Keys - Service-to-Service Authentication

**Autenticación para servicios backend y automatización**

---

## 🎯 ¿Qué son los Admin API Keys?

Los Admin API Keys son credenciales de larga duración que permiten a servicios backend autenticarse con Thalamus **sin intervención de usuarios**. Son ideales para:

- ✅ **Auto-registro de OAuth2 Clients** - Servicios que se registran automáticamente
- ✅ **Machine-to-Machine (M2M)** - Backend services comunicándose entre sí
- ✅ **CI/CD Pipelines** - Automatización de testing y deployment
- ✅ **Scheduled Jobs** - Cron jobs que necesitan acceso a APIs
- ✅ **Service Integration** - Integraciones entre sistemas

---

## 🔒 Seguridad

### Características de Seguridad

- **Bcrypt Hashing:** Las claves se hashean antes de guardarse (nunca en texto plano)
- **Prefix Lookup:** Solo el prefijo se usa para búsquedas eficientes
- **Scoped Permissions:** Control granular vía scopes
- **Expiration Support:** Fechas de expiración opcionales
- **Instant Revocation:** Revocación inmediata
- **Audit Logging:** Todas las operaciones se registran
- **Last Used Tracking:** Monitoreo de uso

### ⚠️ Advertencias Importantes

- El API Key completo **solo se muestra una vez** durante la creación
- Guárdalo en un **secrets manager** (AWS Secrets, Vault, etc.)
- **NUNCA** lo commits en git
- Rota las claves cada **90 días**
- Solo **super admins** pueden crear API Keys

---

## 📋 Crear un Admin API Key

### Prerequisitos

- Ser **super admin** en Thalamus
- Tener un **JWT token válido** de super admin

### Paso 1: Obtener JWT de Super Admin

```bash
curl -X POST http://localhost:4000/api/public/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@zea.com",
    "password": "AdminPass123!@#"
  }'
```

**Respuesta:**
```json
{
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refresh_token": "...",
    "expires_in": 3600
  }
}
```

### Paso 2: Crear el API Key

```bash
curl -X POST http://localhost:4000/api/admin/api-keys \
  -H "Authorization: Bearer <super_admin_jwt>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Sport Backend Integration",
    "description": "API Key for Sport app to register OAuth2 clients",
    "scopes": ["clients:write", "clients:read"],
    "expires_at": "2026-12-31T23:59:59Z"
  }'
```

**Parámetros:**

| Campo | Tipo | Requerido | Descripción |
|-------|------|-----------|-------------|
| `name` | string | ✅ | Nombre descriptivo del API Key |
| `description` | string | ❌ | Descripción del propósito |
| `scopes` | array | ✅ | Lista de permisos (ver tabla abajo) |
| `expires_at` | datetime | ❌ | Fecha de expiración (ISO 8601) |

**Respuesta:**
```json
{
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "api_key": "ak_dev_vK8mN2pQ7xR9tY3wZ5aB1cD4eF6gH8jL",
    "key_prefix": "ak_dev_vK8m",
    "name": "Sport Backend Integration",
    "description": "API Key for Sport app to register OAuth2 clients",
    "scopes": ["clients:write", "clients:read"],
    "is_active": true,
    "expires_at": "2026-12-31T23:59:59Z",
    "last_used_at": null,
    "created_at": "2025-10-26T10:00:00Z"
  },
  "message": "⚠️ IMPORTANT: Save the api_key in a secure location. It cannot be retrieved later."
}
```

### ⚠️ Guarda el API Key

El campo `api_key` **solo se muestra una vez**. Guárdalo de inmediato:

```bash
# En tu .env o secrets manager
THALAMUS_API_KEY=ak_dev_vK8mN2pQ7xR9tY3wZ5aB1cD4eF6gH8jL
```

---

## 🔑 Scopes Disponibles

| Scope | Descripción |
|-------|-------------|
| `clients:read` | Ver OAuth2 clients |
| `clients:write` | Crear y actualizar OAuth2 clients |
| `clients:delete` | Eliminar OAuth2 clients |
| `users:read` | Ver usuarios |
| `users:write` | Crear y actualizar usuarios |
| `users:delete` | Eliminar usuarios |
| `organizations:read` | Ver organizaciones |
| `organizations:write` | Crear y actualizar organizaciones |
| `corpus:read` | Leer datos de corpus |
| `corpus:write` | Escribir datos de corpus |

**Principio de Least Privilege:** Solo otorga los scopes mínimos necesarios.

---

## 💻 Usar el API Key

### Formato del Header

```bash
Authorization: ApiKey <tu_api_key>
```

### Ejemplo: Crear un OAuth2 Client

```bash
curl -X POST http://localhost:4000/api/clients \
  -H "Authorization: ApiKey ak_dev_vK8mN2pQ7xR9tY3wZ5aB1cD4eF6gH8jL" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Sport Application",
    "organization_id": "660e8400-e29b-41d4-a716-446655440000",
    "client_type": "confidential",
    "redirect_uris": ["https://sport.zea.com/auth/callback"],
    "grant_types": ["authorization_code", "refresh_token"],
    "scopes": ["openid", "profile", "email", "sport:read", "sport:write"]
  }'
```

### Ejemplo: Listar OAuth2 Clients

```bash
curl -H "Authorization: ApiKey ak_dev_vK8mN2pQ7xR9tY3wZ5aB1cD4eF6gH8jL" \
  http://localhost:4000/api/clients
```

---

## 🔄 Gestión de API Keys

### Listar todos los API Keys

```bash
curl -H "Authorization: Bearer <super_admin_jwt>" \
  http://localhost:4000/api/admin/api-keys
```

### Ver un API Key específico

```bash
curl -H "Authorization: Bearer <super_admin_jwt>" \
  http://localhost:4000/api/admin/api-keys/<api_key_id>
```

**Nota:** El `api_key` completo nunca se retorna después de la creación, solo el `key_prefix`.

### Rotar un API Key

Genera una nueva clave (invalida la anterior):

```bash
curl -X POST http://localhost:4000/api/admin/api-keys/<api_key_id>/rotate \
  -H "Authorization: Bearer <super_admin_jwt>"
```

**Respuesta:**
```json
{
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "api_key": "ak_dev_nEwK3yAfT3rR0t4t10n",
    "key_prefix": "ak_dev_nEwK",
    "name": "Sport Backend Integration"
  },
  "message": "⚠️ API key rotated successfully. Save the new key securely."
}
```

### Revocar un API Key

```bash
curl -X DELETE http://localhost:4000/api/admin/api-keys/<api_key_id> \
  -H "Authorization: Bearer <super_admin_jwt>"
```

---

## 🐍 Ejemplo: Script de Auto-Registro (Python)

```python
# auto_register.py
import os
import httpx
import json

THALAMUS_URL = os.getenv("THALAMUS_URL", "http://localhost:4000")
THALAMUS_API_KEY = os.getenv("THALAMUS_API_KEY")
ORGANIZATION_ID = os.getenv("ORGANIZATION_ID")
SERVICE_NAME = os.getenv("SERVICE_NAME", "My Service")
SERVICE_URL = os.getenv("SERVICE_URL", "http://localhost:3000")

def register_oauth2_client():
    """Auto-registro de servicio como OAuth2 client."""

    if not THALAMUS_API_KEY:
        raise ValueError("THALAMUS_API_KEY not set")

    if not ORGANIZATION_ID:
        raise ValueError("ORGANIZATION_ID not set")

    headers = {
        "Authorization": f"ApiKey {THALAMUS_API_KEY}",
        "Content-Type": "application/json"
    }

    payload = {
        "name": SERVICE_NAME,
        "organization_id": ORGANIZATION_ID,
        "client_type": "confidential",
        "redirect_uris": [f"{SERVICE_URL}/auth/callback"],
        "grant_types": ["authorization_code", "refresh_token"],
        "scopes": ["openid", "profile", "email"]
    }

    response = httpx.post(
        f"{THALAMUS_URL}/api/clients",
        headers=headers,
        json=payload,
        timeout=10.0
    )

    if response.status_code == 201:
        data = response.json()["data"]

        print("✅ OAuth2 Client registered successfully!")
        print(f"\nClient ID: {data['client_id']}")
        print(f"Client Secret: {data['client_secret']}")
        print("\n⚠️  IMPORTANT: Save these credentials in your secrets manager!")
        print("\nAdd to your .env file:")
        print(f"OAUTH2_CLIENT_ID={data['client_id']}")
        print(f"OAUTH2_CLIENT_SECRET={data['client_secret']}")

        return data
    else:
        print(f"❌ Error: {response.status_code}")
        print(response.text)
        raise Exception("Failed to register OAuth2 client")

if __name__ == "__main__":
    register_oauth2_client()
```

**Uso:**

```bash
export THALAMUS_API_KEY="ak_dev_vK8mN2pQ7xR9tY3wZ5aB1cD4eF6gH8jL"
export ORGANIZATION_ID="660e8400-e29b-41d4-a716-446655440000"
export SERVICE_NAME="Sport Application"
export SERVICE_URL="https://sport.zea.com"

python auto_register.py
```

---

## 🟢 Ejemplo: Script de Auto-Registro (Node.js)

```javascript
// auto-register.js
const axios = require('axios');

const THALAMUS_URL = process.env.THALAMUS_URL || 'http://localhost:4000';
const THALAMUS_API_KEY = process.env.THALAMUS_API_KEY;
const ORGANIZATION_ID = process.env.ORGANIZATION_ID;
const SERVICE_NAME = process.env.SERVICE_NAME || 'My Service';
const SERVICE_URL = process.env.SERVICE_URL || 'http://localhost:3000';

async function registerOAuth2Client() {
  if (!THALAMUS_API_KEY) {
    throw new Error('THALAMUS_API_KEY not set');
  }

  if (!ORGANIZATION_ID) {
    throw new Error('ORGANIZATION_ID not set');
  }

  try {
    const response = await axios.post(
      `${THALAMUS_URL}/api/clients`,
      {
        name: SERVICE_NAME,
        organization_id: ORGANIZATION_ID,
        client_type: 'confidential',
        redirect_uris: [`${SERVICE_URL}/auth/callback`],
        grant_types: ['authorization_code', 'refresh_token'],
        scopes: ['openid', 'profile', 'email']
      },
      {
        headers: {
          'Authorization': `ApiKey ${THALAMUS_API_KEY}`,
          'Content-Type': 'application/json'
        }
      }
    );

    const data = response.data.data;

    console.log('✅ OAuth2 Client registered successfully!');
    console.log(`\nClient ID: ${data.client_id}`);
    console.log(`Client Secret: ${data.client_secret}`);
    console.log('\n⚠️  IMPORTANT: Save these credentials in your secrets manager!');
    console.log('\nAdd to your .env file:');
    console.log(`OAUTH2_CLIENT_ID=${data.client_id}`);
    console.log(`OAUTH2_CLIENT_SECRET=${data.client_secret}`);

    return data;
  } catch (error) {
    console.error('❌ Error:', error.response?.status, error.response?.data);
    throw error;
  }
}

registerOAuth2Client();
```

**Uso:**

```bash
export THALAMUS_API_KEY="ak_dev_vK8mN2pQ7xR9tY3wZ5aB1cD4eF6gH8jL"
export ORGANIZATION_ID="660e8400-e29b-41d4-a716-446655440000"
export SERVICE_NAME="Sport Application"
export SERVICE_URL="https://sport.zea.com"

node auto-register.js
```

---

## ❓ Troubleshooting

### Error: "Unauthorized"

```json
{
  "error": "unauthorized",
  "message": "Invalid API key"
}
```

**Causas:**
- API Key inválido o revocado
- Formato incorrecto del header (debe ser `ApiKey` no `Bearer`)
- API Key expirado

**Solución:**
- Verifica que el API Key sea correcto
- Usa `Authorization: ApiKey <key>` (no `Bearer`)
- Verifica la fecha de expiración

### Error: "Forbidden - insufficient scopes"

```json
{
  "error": "forbidden",
  "message": "Insufficient scopes"
}
```

**Causa:** El API Key no tiene el scope necesario

**Solución:** Solicita al super admin que agregue los scopes faltantes o cree un nuevo API Key

### Error: "API key not found"

**Causa:** El prefijo del API Key no coincide con ningún registro

**Solución:** Verifica que el API Key sea correcto y no haya sido eliminado

---

## 📚 Ver También

- [OAuth2 Authorization Code Flow](oauth2-authorization-code.md)
- [OAuth2 Client Credentials (M2M)](oauth2-client-credentials.md)
- [Integration Examples](integration-examples.md)
- [Security Best Practices](security-best-practices.md)

---

## 🔗 Referencia API

**Endpoint:** `/api/admin/api-keys`

Para la especificación OpenAPI completa, consulta: [OPENAPI_SPEC.yaml](../OPENAPI_SPEC.yaml)
