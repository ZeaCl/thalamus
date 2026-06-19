# Instrucciones de Autenticación para Platform Team

**Para usar el endpoint de rotación de secrets necesitan autenticación. Aquí están las opciones:**

---

## Opción 1: Admin API Key (Recomendado para servicios)

### ¿Qué es?
Un Admin API Key es una credencial de servicio-a-servicio que no expira y se puede usar para automatización.

### ¿Cómo obtenerlo?

**Si ya existe un Admin API Key:**
1. Pregunta al administrador de Thalamus por el API Key existente
2. Debería tener el formato: `ak_dev_xxxxx...` o `ak_prod_xxxxx...`

**Si necesitas crear uno nuevo:**

```bash
# 1. Conectarse a la base de datos de Thalamus
psql -h localhost -U postgres -d thalamus_dev

# 2. Buscar el usuario super admin
SELECT id, email, is_super_admin FROM users WHERE is_super_admin = true;

# 3. Con el ID del super admin, crear el API Key
# Reemplaza <SUPER_ADMIN_USER_ID> con el UUID obtenido arriba
# Reemplaza <YOUR_ORG_ID> con el UUID de tu organización

INSERT INTO admin_api_keys (
  id,
  key_prefix,
  key_hash,
  user_id,
  organization_id,
  name,
  scopes,
  is_active,
  expires_at,
  inserted_at,
  updated_at
) VALUES (
  gen_random_uuid(),
  'ak_dev',
  crypt('platform_temp_key_123', gen_salt('bf', 12)),
  '<SUPER_ADMIN_USER_ID>',
  '<YOUR_ORG_ID>',
  'Platform Team - Client Management',
  ARRAY['clients:read', 'clients:write'],
  true,
  NULL,  -- No expira
  now(),
  now()
);

# 4. El API Key completo será:
# ak_dev_platform_temp_key_123
```

**Usar el API Key:**
```bash
export THALAMUS_API_KEY="ak_dev_platform_temp_key_123"

# Listar clientes
curl -X GET "http://localhost:4000/api/clients" \
  -H "Authorization: Bearer $THALAMUS_API_KEY"

# Rotar secret
curl -X POST "http://localhost:4000/api/clients/client_<UUID>/rotate-secret" \
  -H "Authorization: Bearer $THALAMUS_API_KEY"
```

---

## Opción 2: JWT Bearer Token (Más rápido para testing)

### ¿Qué es?
Un token JWT que se obtiene haciendo login con un usuario administrador. Expira después de 1 hora.

### ¿Cómo obtenerlo?

**Paso 1: Login**
```bash
curl -X POST "http://localhost:4000/api/public/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@zea.com",
    "password": "tu_password_admin"
  }'
```

**Respuesta:**
```json
{
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refresh_token": "...",
    "expires_in": 3600,
    "user": {
      "id": "...",
      "email": "admin@zea.com",
      "is_super_admin": true
    }
  }
}
```

**Paso 2: Usar el token**
```bash
export BEARER_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

# Listar clientes
curl -X GET "http://localhost:4000/api/clients" \
  -H "Authorization: Bearer $BEARER_TOKEN"

# Rotar secret
curl -X POST "http://localhost:4000/api/clients/client_<UUID>/rotate-secret" \
  -H "Authorization: Bearer $BEARER_TOKEN"
```

**Nota:** El token JWT expira en 1 hora. Si expira, repetir el paso 1 para obtener uno nuevo.

---

## Opción 3: Crear Admin API Key via Mix Task (Si tienes acceso al servidor)

Si tienes acceso SSH al servidor donde corre Thalamus:

```bash
# 1. SSH al servidor
ssh user@thalamus-server

# 2. Ir al directorio de Thalamus
cd /path/to/thalamus

# 3. Ejecutar mix task para crear API Key
MIX_ENV=production mix run -e '
# Encontrar super admin
admin = Thalamus.Repo.one!(from u in Thalamus.Infrastructure.Persistence.Schemas.UserSchema,
  where: u.is_super_admin == true,
  limit: 1
)

# Crear API Key
alias Thalamus.Infrastructure.Persistence.Schemas.AdminApiKeySchema
alias Thalamus.Repo

plain_key = "platform_client_management_#{:crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)}"

{:ok, api_key} = %AdminApiKeySchema{}
|> AdminApiKeySchema.create_changeset(%{
  key_prefix: "ak_prod",
  key_hash: Bcrypt.hash_pwd_salt(plain_key),
  user_id: admin.id,
  organization_id: admin.organization_id,
  name: "Platform Team - Client Management",
  scopes: ["clients:read", "clients:write"],
  is_active: true
})
|> Repo.insert()

IO.puts("✅ API Key creado exitosamente")
IO.puts("Key: ak_prod_#{plain_key}")
IO.puts("⚠️  Guárdalo de forma segura, no se puede recuperar")
'
```

---

## Script Completo de Rotación

Una vez que tengas el token, aquí está el script completo:

```bash
#!/bin/bash
# rotate_platform_secret.sh

set -e

# Configuración
THALAMUS_URL="${THALAMUS_URL:-http://localhost:4000}"
AUTH_TOKEN="${THALAMUS_API_KEY}"  # O usa tu Bearer token

if [ -z "$AUTH_TOKEN" ]; then
  echo "❌ Error: Falta el token de autenticación"
  echo "   Exporta THALAMUS_API_KEY=ak_dev_..."
  exit 1
fi

echo "🔍 Paso 1: Buscando cliente platform_web..."

# Listar todos los clientes
CLIENTS=$(curl -s -X GET "$THALAMUS_URL/api/clients" \
  -H "Authorization: Bearer $AUTH_TOKEN")

# Extraer el UUID del cliente platform_web
# Asumiendo que el nombre contiene "platform" o "Platform Web"
CLIENT_UUID=$(echo "$CLIENTS" | jq -r '.data[] | select(.name | test("Platform"; "i")) | .id' | head -1)

if [ -z "$CLIENT_UUID" ]; then
  echo "❌ Error: No se encontró el cliente platform_web"
  echo "Clientes disponibles:"
  echo "$CLIENTS" | jq -r '.data[] | "  - \(.name) (ID: \(.id))"'
  exit 1
fi

echo "✅ Cliente encontrado: $CLIENT_UUID"
echo ""

echo "🔄 Paso 2: Rotando secret del cliente..."

RESPONSE=$(curl -s -X POST "$THALAMUS_URL/api/clients/$CLIENT_UUID/rotate-secret" \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -H "Content-Type: application/json")

# Verificar si hay error
if echo "$RESPONSE" | grep -q '"error"'; then
  echo "❌ Error al rotar secret:"
  echo "$RESPONSE" | jq -r '.error'
  exit 1
fi

# Extraer el nuevo secret
NEW_SECRET=$(echo "$RESPONSE" | jq -r '.data.client_secret')
ROTATED_AT=$(echo "$RESPONSE" | jq -r '.data.rotated_at')

echo "✅ Secret rotado exitosamente"
echo ""
echo "📋 Información del nuevo secret:"
echo "   Client ID: $CLIENT_UUID"
echo "   New Secret: $NEW_SECRET"
echo "   Rotated at: $ROTATED_AT"
echo ""
echo "⚠️  IMPORTANTE: Guarda este secret de forma segura"
echo ""
echo "🔄 Paso 3: Actualizar en tu sistema"
echo ""
echo "# Opción A: Actualizar variable de entorno"
echo "export OAUTH2_CLIENT_SECRET=$NEW_SECRET"
echo ""
echo "# Opción B: Actualizar en AWS Secrets Manager"
echo "aws secretsmanager update-secret \\"
echo "  --secret-id platform-oauth-client-secret \\"
echo "  --secret-string '$NEW_SECRET'"
echo ""
echo "# Opción C: Actualizar en Kubernetes Secret"
echo "kubectl create secret generic platform-oauth \\"
echo "  --from-literal=client-secret='$NEW_SECRET' \\"
echo "  --dry-run=client -o yaml | kubectl apply -f -"
echo ""
echo "⚠️  Paso 4: Reiniciar el servicio platform-web"
echo "kubectl rollout restart deployment/platform-web"
```

**Uso del script:**
```bash
# Dar permisos de ejecución
chmod +x rotate_platform_secret.sh

# Ejecutar con API Key
export THALAMUS_API_KEY="ak_dev_platform_temp_key_123"
./rotate_platform_secret.sh

# O con Bearer Token
export THALAMUS_API_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
./rotate_platform_secret.sh
```

---

## Troubleshooting

### Error: "Unauthorized"
```bash
# Verificar que el token es válido
curl -X POST "http://localhost:4000/oauth/introspect" \
  -H "Content-Type: application/json" \
  -d '{
    "token": "'"$THALAMUS_API_KEY"'"
  }'
```

Si retorna `"active": false`, el token expiró o es inválido. Obtén uno nuevo.

### Error: "Client not found"
```bash
# Listar todos los clientes disponibles
curl -X GET "http://localhost:4000/api/clients" \
  -H "Authorization: Bearer $THALAMUS_API_KEY" | jq
```

Verifica el `id` correcto del cliente y úsalo en la URL.

### Error: "Cannot rotate secret for public clients"
Los clientes `public` (como SPAs) no tienen secret. Solo clientes `confidential` y `m2m` pueden rotar secrets.

---

## Resumen de Opciones

| Opción | Ventajas | Desventajas | Cuándo usar |
|--------|----------|-------------|-------------|
| **Admin API Key** | ✅ No expira<br>✅ Para automatización<br>✅ Scopes específicos | ⚠️ Requiere crear manualmente<br>⚠️ Requiere acceso BD o super admin | Producción, automatización |
| **JWT Bearer Token** | ✅ Fácil de obtener<br>✅ Solo requiere login | ⚠️ Expira en 1 hora<br>⚠️ Requiere re-login | Testing, uso puntual |
| **Mix Task** | ✅ Scripteable<br>✅ Genera key segura | ⚠️ Requiere acceso SSH<br>⚠️ Requiere conocimiento Elixir | Creación inicial de keys |

**Recomendación para Platform:**
1. **Ahora (urgente):** Usar Opción 2 (JWT Bearer Token) para rotar el secret inmediatamente
2. **Después (producción):** Crear un Admin API Key (Opción 1 o 3) para automatización

---

## Contacto

Si tienen problemas:
- 📖 Documentación: `docs/guides/oauth2-client-management.md`
- 🆘 Soporte: Equipo Thalamus via Slack #thalamus-support
