# OAuth2 Client Management Guide

**Guía completa para gestionar clientes OAuth2 en Thalamus**

---

## Tabla de Contenidos

- [Introducción](#introducción)
- [Operaciones Disponibles](#operaciones-disponibles)
- [Rotar Client Secret](#rotar-client-secret)
- [Crear Cliente OAuth2](#crear-cliente-oauth2)
- [Listar Clientes](#listar-clientes)
- [Actualizar Cliente](#actualizar-cliente)
- [Eliminar Cliente](#eliminar-cliente)
- [Mejores Prácticas](#mejores-prácticas)
- [Troubleshooting](#troubleshooting)

---

## Introducción

Los clientes OAuth2 son aplicaciones registradas que pueden autenticarse contra Thalamus. Esta guía te muestra cómo gestionar estos clientes a través de la API REST.

**Prerequisitos:**
- Token de autenticación válido (Admin API Key o JWT Bearer Token)
- Permisos para gestionar clientes OAuth2

---

## Operaciones Disponibles

| Operación | Endpoint | Método |
|-----------|----------|--------|
| Listar clientes | `/api/clients` | GET |
| Crear cliente | `/api/clients` | POST |
| Obtener cliente | `/api/clients/:id` | GET |
| Actualizar cliente | `/api/clients/:id` | PUT |
| Eliminar cliente | `/api/clients/:id` | DELETE |
| **Rotar secret** | `/api/clients/:id/rotate-secret` | POST |

---

## Rotar Client Secret

### ¿Cuándo rotar el secret?

Rota el client secret cuando:
- 🔒 Sospechas que el secret fue comprometido
- 🔄 Como parte de una rotación de credenciales programada (recomendado cada 90 días)
- 🐛 El secret actual está en texto plano en la base de datos (migración)
- 👤 Un desarrollador con acceso al secret deja el equipo
- 📝 Requisitos de compliance (SOC2, ISO 27001, etc.)

### Endpoint

```
POST /api/clients/:client_id/rotate-secret
```

**Autenticación:** Bearer Token (Admin API Key o User JWT)

**Parámetros de ruta:**
- `client_id` (string, required): ID del cliente con formato `client_<uuid>`

### Request

```bash
curl -X POST "https://thalamus.zea.com/api/clients/client_abc123.../rotate-secret" \
  -H "Authorization: Bearer YOUR_ADMIN_API_KEY" \
  -H "Content-Type: application/json"
```

### Response (200 OK)

```json
{
  "data": {
    "client_id": "client_91f5f021-55a4-4bd5-9548-3bbb2e6e5ef4",
    "client_secret": "sOodSYnE7YvBf7hg08GUy3jEzgeEQ5LOHZzg9MObKFA",
    "rotated_at": "2025-12-30T04:33:46.617227Z"
  },
  "message": "⚠️ IMPORTANT: Save the new client_secret securely. It cannot be retrieved later."
}
```

### Comportamiento

1. ✅ **Genera un nuevo secret criptográficamente seguro**
   - 32 bytes aleatorios (`:crypto.strong_rand_bytes/1`)
   - Codificado en base64url (44 caracteres)
   - Sin padding (`=`)

2. ✅ **Hashea automáticamente con Bcrypt**
   - 12 rounds (configuración segura por defecto)
   - Hash almacenado en base de datos (no el texto plano)

3. ✅ **Invalida el secret anterior inmediatamente**
   - El secret anterior deja de funcionar instantáneamente
   - No hay período de gracia
   - Actualiza el timestamp `updated_at`

4. ⚠️ **Retorna el secret en texto plano UNA SOLA VEZ**
   - Este es el único momento para obtener el secret
   - Debe guardarse inmediatamente
   - No se puede recuperar después

### Errores Comunes

#### 404 Not Found
```json
{
  "error": "Client not found"
}
```
**Solución:** Verifica que el `client_id` sea correcto y exista.

#### 400 Bad Request
```json
{
  "error": "Cannot rotate secret for public clients"
}
```
**Solución:** Solo los clientes `confidential` y `m2m` pueden rotar secrets. Los clientes `public` no tienen secret.

#### 401 Unauthorized
```json
{
  "error": "Unauthorized"
}
```
**Solución:** Verifica que el token de autenticación sea válido y tenga permisos.

---

## Ejemplos de Código

### Python

```python
import requests
import os

def rotate_client_secret(client_id: str, api_key: str) -> str:
    """
    Rota el client secret de un cliente OAuth2.

    Args:
        client_id: ID del cliente (formato: client_<uuid>)
        api_key: Admin API Key o JWT token

    Returns:
        Nuevo client secret (texto plano)

    Raises:
        requests.HTTPError: Si la rotación falla
    """
    url = f"https://thalamus.zea.com/api/clients/{client_id}/rotate-secret"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }

    response = requests.post(url, headers=headers)
    response.raise_for_status()

    data = response.json()["data"]
    new_secret = data["client_secret"]
    rotated_at = data["rotated_at"]

    print(f"✅ Secret rotado exitosamente")
    print(f"   Rotated at: {rotated_at}")
    print(f"   New secret: {new_secret}")
    print(f"   ⚠️  IMPORTANTE: Guardar este secret de forma segura")

    return new_secret

# Uso
if __name__ == "__main__":
    CLIENT_ID = os.getenv("OAUTH2_CLIENT_ID")
    API_KEY = os.getenv("THALAMUS_API_KEY")

    new_secret = rotate_client_secret(CLIENT_ID, API_KEY)

    # Guardar el nuevo secret en tu sistema
    # Ejemplo: actualizar variable de entorno, secrets manager, etc.
    os.environ["OAUTH2_CLIENT_SECRET"] = new_secret

    print("\n🔄 Actualiza la variable de entorno:")
    print(f"   export OAUTH2_CLIENT_SECRET={new_secret}")
    print("\n⚠️  Reinicia tu servicio para que tome el nuevo secret")
```

### Node.js

```javascript
const axios = require('axios');

async function rotateClientSecret(clientId, apiKey) {
  try {
    const response = await axios.post(
      `https://thalamus.zea.com/api/clients/${clientId}/rotate-secret`,
      {},
      {
        headers: {
          'Authorization': `Bearer ${apiKey}`,
          'Content-Type': 'application/json'
        }
      }
    );

    const { client_id, client_secret, rotated_at } = response.data.data;

    console.log('✅ Secret rotado exitosamente');
    console.log(`   Client ID: ${client_id}`);
    console.log(`   Rotated at: ${rotated_at}`);
    console.log(`   New secret: ${client_secret}`);
    console.log('   ⚠️  IMPORTANTE: Guardar este secret de forma segura');

    return client_secret;
  } catch (error) {
    if (error.response) {
      console.error('❌ Error:', error.response.data.error);
      throw new Error(`Failed to rotate secret: ${error.response.data.error}`);
    }
    throw error;
  }
}

// Uso
(async () => {
  const clientId = process.env.OAUTH2_CLIENT_ID;
  const apiKey = process.env.THALAMUS_API_KEY;

  const newSecret = await rotateClientSecret(clientId, apiKey);

  // Guardar el nuevo secret
  process.env.OAUTH2_CLIENT_SECRET = newSecret;

  console.log('\n🔄 Actualiza la variable de entorno:');
  console.log(`   export OAUTH2_CLIENT_SECRET=${newSecret}`);
  console.log('\n⚠️  Reinicia tu servicio para que tome el nuevo secret');
})();
```

### Bash/cURL

```bash
#!/bin/bash

# Script para rotar el client secret de un cliente OAuth2

set -e

CLIENT_ID="${OAUTH2_CLIENT_ID}"
API_KEY="${THALAMUS_API_KEY}"
THALAMUS_URL="${THALAMUS_URL:-https://thalamus.zea.com}"

if [ -z "$CLIENT_ID" ] || [ -z "$API_KEY" ]; then
  echo "❌ Error: Faltan variables de entorno"
  echo "   OAUTH2_CLIENT_ID=$CLIENT_ID"
  echo "   THALAMUS_API_KEY=$API_KEY"
  exit 1
fi

echo "🔄 Rotando secret para cliente: $CLIENT_ID"

RESPONSE=$(curl -s -X POST \
  "$THALAMUS_URL/api/clients/$CLIENT_ID/rotate-secret" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json")

# Verificar si la respuesta contiene error
if echo "$RESPONSE" | grep -q '"error"'; then
  echo "❌ Error al rotar secret:"
  echo "$RESPONSE" | jq -r '.error'
  exit 1
fi

# Extraer el nuevo secret
NEW_SECRET=$(echo "$RESPONSE" | jq -r '.data.client_secret')
ROTATED_AT=$(echo "$RESPONSE" | jq -r '.data.rotated_at')

echo "✅ Secret rotado exitosamente"
echo "   Rotated at: $ROTATED_AT"
echo "   New secret: $NEW_SECRET"
echo ""
echo "⚠️  IMPORTANTE: Guardar este secret de forma segura"
echo ""
echo "🔄 Actualiza la variable de entorno:"
echo "   export OAUTH2_CLIENT_SECRET=$NEW_SECRET"
echo ""
echo "💾 O guárdalo en tu secrets manager:"
echo "   aws secretsmanager update-secret \\"
echo "     --secret-id oauth2-client-secret \\"
echo "     --secret-string $NEW_SECRET"
echo ""
echo "⚠️  Reinicia tu servicio para que tome el nuevo secret"
```

---

## Crear Cliente OAuth2

### Endpoint

```
POST /api/clients
```

**Autenticación:** Bearer Token (Admin API Key recomendado)

### Request Body

```json
{
  "name": "My Application",
  "client_type": "confidential",
  "organization_id": "org_abc123...",
  "allowed_grant_types": ["authorization_code", "refresh_token"],
  "allowed_scopes": ["openid", "profile", "email"],
  "redirect_uris": ["https://myapp.com/callback"],
  "pkce_required": true,
  "description": "Production OAuth2 client for My Application"
}
```

**Campos requeridos:**
- `name`: Nombre del cliente (2-100 caracteres)
- `client_type`: Tipo de cliente (`confidential`, `public`, `m2m`)
- `organization_id`: ID de la organización
- `allowed_grant_types`: Tipos de grant permitidos
- `allowed_scopes`: Scopes permitidos
- `redirect_uris`: URIs de redirección (solo para confidential/public)

**Campos opcionales:**
- `pkce_required`: Si se requiere PKCE (recomendado: `true`)
- `description`: Descripción del cliente
- `logo_url`: URL del logo
- `terms_of_service_url`: URL de términos de servicio
- `privacy_policy_url`: URL de política de privacidad

### Response (201 Created)

```json
{
  "data": {
    "id": "client_91f5f021-55a4-4bd5-9548-3bbb2e6e5ef4",
    "name": "My Application",
    "client_id": "client_91f5f021-55a4-4bd5-9548-3bbb2e6e5ef4",
    "client_secret": "sOodSYnE7YvBf7hg08GUy3jEzgeEQ5LOHZzg9MObKFA",
    "client_type": "confidential",
    "allowed_grant_types": ["authorization_code", "refresh_token"],
    "allowed_scopes": ["openid", "profile", "email"],
    "redirect_uris": ["https://myapp.com/callback"],
    "pkce_required": true,
    "is_active": true,
    "created_at": "2025-12-30T04:33:46.617227Z"
  },
  "message": "⚠️ IMPORTANT: Save the client_secret securely. It cannot be retrieved later."
}
```

⚠️ **IMPORTANTE:** El `client_secret` solo se retorna al crear el cliente. Guárdalo de forma segura, no se puede recuperar después.

---

## Listar Clientes

### Endpoint

```
GET /api/clients
```

**Query parameters:**
- `organization_id` (optional): Filtrar por organización
- `client_type` (optional): Filtrar por tipo (`confidential`, `public`, `m2m`)
- `is_active` (optional): Filtrar por estado activo (`true`/`false`)

### Request

```bash
curl -X GET "https://thalamus.zea.com/api/clients?organization_id=org_abc123" \
  -H "Authorization: Bearer YOUR_API_KEY"
```

### Response (200 OK)

```json
{
  "data": [
    {
      "id": "client_91f5f021-55a4-4bd5-9548-3bbb2e6e5ef4",
      "name": "My Application",
      "client_id": "client_91f5f021-55a4-4bd5-9548-3bbb2e6e5ef4",
      "client_type": "confidential",
      "is_active": true,
      "created_at": "2025-12-30T04:33:46Z",
      "updated_at": "2025-12-30T04:33:46Z"
    }
  ]
}
```

**Nota:** El `client_secret` nunca se retorna en listados por seguridad.

---

## Actualizar Cliente

### Endpoint

```
PUT /api/clients/:client_id
```

### Campos Actualizables

```json
{
  "name": "Updated Application Name",
  "description": "Updated description",
  "logo_url": "https://example.com/new-logo.png",
  "terms_of_service_url": "https://example.com/tos",
  "privacy_policy_url": "https://example.com/privacy",
  "is_active": true,
  "pkce_required": true,
  "allowed_grant_types": ["authorization_code", "refresh_token"],
  "allowed_scopes": ["openid", "profile", "email", "address"],
  "redirect_uris": ["https://myapp.com/callback", "https://myapp.com/callback2"],
  "access_token_lifetime": 3600,
  "refresh_token_lifetime": 2592000
}
```

**Campos NO actualizables:**
- `client_id`
- `client_secret` (usar endpoint `/rotate-secret` en su lugar)
- `client_type`
- `organization_id`

### Response (200 OK)

```json
{
  "data": {
    "id": "client_91f5f021-55a4-4bd5-9548-3bbb2e6e5ef4",
    "name": "Updated Application Name",
    "client_id": "client_91f5f021-55a4-4bd5-9548-3bbb2e6e5ef4",
    "updated_at": "2025-12-30T05:00:00Z"
  }
}
```

---

## Eliminar Cliente

### Endpoint

```
DELETE /api/clients/:client_id
```

⚠️ **PRECAUCIÓN:** Esta operación es irreversible. Todos los tokens emitidos para este cliente serán revocados.

### Request

```bash
curl -X DELETE "https://thalamus.zea.com/api/clients/client_abc123..." \
  -H "Authorization: Bearer YOUR_API_KEY"
```

### Response (204 No Content)

Sin contenido en el cuerpo de la respuesta.

---

## Mejores Prácticas

### Seguridad

1. **Rotar secrets regularmente**
   - 🔄 Cada 90 días como mínimo
   - 🔄 Inmediatamente si se sospecha compromiso
   - 🔄 Cuando empleados con acceso dejan la empresa

2. **Almacenar secrets de forma segura**
   - ✅ Usar secrets managers (AWS Secrets Manager, HashiCorp Vault, Azure Key Vault)
   - ✅ Nunca commitear secrets en git
   - ✅ Usar variables de entorno en producción
   - ❌ No hardcodear secrets en el código
   - ❌ No almacenar en texto plano

3. **Limitar permisos**
   - Solo otorgar los scopes necesarios
   - Usar PKCE para clientes públicos
   - Validar redirect URIs estrictamente

### Operaciones

1. **Automatizar rotación**
   ```bash
   # Ejemplo: cronjob mensual
   0 0 1 * * /path/to/rotate-secrets.sh
   ```

2. **Monitorear uso**
   - Revisar logs de autenticación
   - Alertar en fallos de autenticación
   - Monitorear expiración de tokens

3. **Documentar cambios**
   - Registrar cuándo y por qué se rotaron secrets
   - Mantener inventario de clientes OAuth2
   - Documentar configuración de cada cliente

### Disaster Recovery

1. **Backup de configuración**
   ```bash
   # Exportar lista de clientes (sin secrets)
   curl -X GET "https://thalamus.zea.com/api/clients" \
     -H "Authorization: Bearer $API_KEY" > clients-backup.json
   ```

2. **Plan de rotación de emergencia**
   - Tener scripts preparados para rotación masiva
   - Documentar procedimiento de actualización en servicios
   - Mantener contactos de emergencia

3. **Rollback plan**
   - Tener procedimiento documentado si falla rotación
   - Mantener comunicación con equipos dependientes
   - Testing en staging antes de producción

---

## Troubleshooting

### El secret rotado no funciona

**Síntoma:** Después de rotar el secret, obtengo error `invalid_client`

**Diagnóstico:**
```bash
# 1. Verificar que el secret se guardó correctamente
echo $OAUTH2_CLIENT_SECRET

# 2. Probar autenticación
curl -X POST "https://thalamus.zea.com/oauth/token" \
  -H "Content-Type: application/json" \
  -d '{
    "grant_type": "client_credentials",
    "client_id": "'"$OAUTH2_CLIENT_ID"'",
    "client_secret": "'"$OAUTH2_CLIENT_SECRET"'"
  }'
```

**Soluciones:**
1. Verificar que copiaste el secret completo (44 caracteres)
2. Verificar que no hay espacios o saltos de línea
3. Verificar que reiniciaste el servicio después de actualizar
4. Verificar que el cliente tiene el grant type habilitado

### No puedo rotar el secret

**Síntoma:** Recibo error `Cannot rotate secret for public clients`

**Solución:** Los clientes públicos (como SPAs) no tienen secret. Solo clientes `confidential` y `m2m` pueden rotar secrets.

### Error 401 al llamar el endpoint

**Síntoma:** `Unauthorized` al llamar `/rotate-secret`

**Diagnóstico:**
```bash
# Verificar que el token es válido
curl -X POST "https://thalamus.zea.com/oauth/introspect" \
  -H "Content-Type: application/json" \
  -d '{
    "token": "'"$THALAMUS_API_KEY"'"
  }'
```

**Soluciones:**
1. Verificar que el token no expiró
2. Verificar que tienes permisos para gestionar clientes
3. Usar Admin API Key en lugar de JWT si es posible

---

## Próximos Pasos

- 📖 [Admin API Keys](admin-api-keys.md) - Autenticación servicio-a-servicio
- 📖 [OAuth2 Client Credentials](../oauth2/client-credentials.md) - Flujo M2M
- 📖 [API Reference](../api/rest.md) - Endpoints completos
- 📖 [Clients API](../api/clients.md) - Gestión de clientes OAuth2

---

## Soporte

¿Necesitas ayuda? Contacta a:
- 📧 Email: support@zea.com
- 💬 Slack: #thalamus-support
- 🐛 Issues: https://github.com/zea/thalamus/issues
