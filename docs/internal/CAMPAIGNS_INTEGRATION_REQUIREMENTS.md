# Requerimientos de Integración: Campaigns Backend → Thalamus

**Fecha**: 2025-12-08
**Módulo Solicitante**: Campaigns Backend
**Módulo Proveedor**: Thalamus (OAuth2 Server)

## Resumen

El módulo de Campaigns Backend necesita integrarse con Thalamus para autenticación OAuth2 y gestión de usuarios/organizaciones. Este documento especifica los endpoints y funcionalidad requerida para que la integración funcione correctamente.

---

## 1. Endpoint de Registro de Usuarios (Crítico)

### Necesidad
Campaigns necesita que usuarios puedan registrarse y obtener acceso al sistema. Actualmente no existe un endpoint público de registro.

### Endpoint Solicitado

```http
POST /api/public/register
Content-Type: application/json
```

### Request Body
```json
{
  "email": "user@example.com",
  "password": "SecurePass123!@#",
  "password_confirmation": "SecurePass123!@#",
  "name": "User Full Name",
  "organization_name": "Company Name" // Optional - crear nueva org o asociar a existente
}
```

### Validaciones Esperadas
- Email: formato válido, único en el sistema
- Password:
  - Mínimo 8 caracteres
  - Al menos 1 mayúscula
  - Al menos 1 minúscula
  - Al menos 1 número
  - Al menos 1 caracter especial
- Password confirmation: debe coincidir con password
- Name: no vacío

### Response Exitoso (201 Created)
```json
{
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "name": "User Full Name",
    "created_at": "2025-12-08T10:00:00Z"
  },
  "organization": {
    "id": "uuid",
    "name": "Company Name",
    "created_at": "2025-12-08T10:00:00Z"
  },
  "access_token": "oauth2_token_here",
  "token_type": "Bearer",
  "expires_in": 3600
}
```

### Response de Error (400/422)
```json
{
  "error": "validation_failed",
  "details": {
    "email": ["Email already taken"],
    "password": ["Password must contain uppercase letter"]
  }
}
```

---

## 2. Endpoint de Login (Confirmar Funcionamiento)

### Endpoint
```http
POST /api/public/login
Content-Type: application/json
```

### Request Body
```json
{
  "email": "user@example.com",
  "password": "SecurePass123!@#"
}
```

### Response Esperado
```json
{
  "access_token": "oauth2_token_here",
  "token_type": "Bearer",
  "expires_in": 3600,
  "refresh_token": "refresh_token_here",
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "name": "User Full Name"
  },
  "organization": {
    "id": "uuid",
    "name": "Company Name"
  }
}
```

**Estado**: Por confirmar si ya existe y funciona correctamente.

---

## 3. Token Introspection (Verificar Funcionamiento Actual)

### Endpoint
```http
POST /api/oauth/introspect
Content-Type: application/json
```

### Request Body
```json
{
  "token": "bearer_token_aqui"
}
```

### Response Esperado (Token Válido)
```json
{
  "active": true,
  "user_id": "uuid",
  "tenant_id": "uuid",  // Mismo que organization_id
  "organization_id": "uuid",
  "email": "user@example.com",
  "scopes": ["campaigns:read", "campaigns:write", "leads:read", "leads:write"],
  "exp": 1702044000,
  "iat": 1702040400
}
```

### Response Esperado (Token Inválido)
```json
{
  "active": false
}
```

**Estado**: Campaigns ya tiene implementado el cliente para este endpoint en:
- `/Users/dev/Documents/zea/modules/campaigns/backend/presentation/api/dependencies/auth.py`

**Acción Requerida**: Verificar que el endpoint existe y devuelve los campos correctos, especialmente:
- `user_id`
- `organization_id` o `tenant_id` (preferiblemente ambos)
- `email`
- `active`

---

## 4. Gestión de Organizaciones

### Necesidad
Los usuarios deben poder:
1. Crear organizaciones durante el registro (si no existe)
2. Asociarse a una organización existente (invitación futura)
3. Ver información de su organización

### Endpoints Deseados (Prioridad Media)

#### Crear Organización
```http
POST /api/organizations
Authorization: Bearer {token}
Content-Type: application/json

{
  "name": "Company Name",
  "description": "Optional description"
}
```

#### Obtener Organización Actual
```http
GET /api/me/organization
Authorization: Bearer {token}
```

**Estado**: No crítico para MVP, pero útil para futuras funcionalidades.

---

## 5. Scopes y Permisos

### Scopes Necesarios para Campaigns
- `campaigns:read` - Listar y ver campañas
- `campaigns:write` - Crear, actualizar, eliminar campañas
- `campaigns:sync` - Sincronizar con APIs externas (Meta, Google)
- `leads:read` - Listar y ver leads
- `leads:write` - Crear, actualizar leads
- `meta:read` - Ver credenciales de Meta
- `meta:write` - Gestionar credenciales de Meta

### Implementación
Los tokens generados durante login/registro deben incluir estos scopes automáticamente para usuarios normales. En el futuro, se pueden implementar roles más granulares.

---

## 6. Configuración de Cliente OAuth2 para Campaigns

### Necesidad
Campaigns necesita credenciales de cliente OAuth2 para comunicarse con Thalamus.

### Opción A: Usar Token Introspection (Actual)
Campaigns valida tokens enviados por el frontend usando el endpoint `/api/oauth/introspect`.

**Configuración Requerida**:
- URL del endpoint de introspection en settings
- Timeout configurado (actualmente 5 segundos)

### Opción B: Client Credentials Flow (Futuro)
Para comunicación backend-to-backend, Campaigns podría necesitar sus propias credenciales.

```
Client ID: campaigns-backend
Client Secret: {generar_secreto_seguro}
Grant Type: client_credentials
Scopes: introspect, user_info
```

**Estado**: Opción A es suficiente para MVP. Opción B para futuras integraciones.

---

## 7. Variables de Entorno en Campaigns

### Configuración Actual en Campaigns
```python
# config.py
THALAMUS_INTROSPECT_URL = os.getenv(
    "THALAMUS_INTROSPECT_URL",
    "http://localhost:4000/api/oauth/introspect"
)
```

### Necesario de Thalamus
- Confirmar URL exacta del endpoint de introspection
- Confirmar si requiere autenticación (client_id/secret) o acepta tokens directamente
- URL del endpoint de registro cuando esté disponible
- URL del endpoint de login

---

## 8. Base de Datos: Estructura Esperada

### Tablas en Thalamus (Existentes - Verificado)
```sql
-- users
id (uuid)
email (string, unique)
name (string)
password_hash (string)
created_at (timestamp)
updated_at (timestamp)

-- organizations
id (uuid)
name (string)
created_at (timestamp)
updated_at (timestamp)

-- oauth2_clients
id (uuid)
client_id (string)
client_secret_hash (string)
...

-- oauth2_tokens
id (uuid)
user_id (uuid, FK -> users)
token (string)
expires_at (timestamp)
...
```

### Asociación Usuario-Organización
Necesitamos confirmar cómo se relacionan users y organizations:
- ¿Tabla intermedia `user_organizations`?
- ¿Campo `organization_id` en tabla `users`?
- ¿Un usuario puede pertenecer a múltiples organizaciones?

**Acción Requerida**: Revisar schema actual y documentar la relación.

---

## 9. Testing y Desarrollo

### Endpoints de Desarrollo
Mientras Thalamus implementa los endpoints necesarios, Campaigns tiene endpoints DEV (solo en DEBUG mode) en:
- `/api/v1/dev/*` - Bypass de autenticación para testing

**⚠️ IMPORTANTE**: Estos endpoints se eliminarán antes de producción.

### Cómo Probar la Integración

1. **Registro de Usuario**:
   ```bash
   curl -X POST http://localhost:4000/api/public/register \
     -H "Content-Type: application/json" \
     -d '{
       "email": "test@zea.com",
       "password": "Test123!@#",
       "password_confirmation": "Test123!@#",
       "name": "Test User"
     }'
   ```

2. **Login**:
   ```bash
   curl -X POST http://localhost:4000/api/public/login \
     -H "Content-Type: application/json" \
     -d '{
       "email": "test@zea.com",
       "password": "Test123!@#"
     }'
   ```

3. **Usar Token en Campaigns**:
   ```bash
   TOKEN="<token_from_login>"

   curl -X GET http://localhost:8001/api/v1/campaigns \
     -H "Authorization: Bearer $TOKEN"
   ```

---

## 10. Cronograma y Prioridades

### Crítico (Bloquea desarrollo)
- ✅ Token introspection endpoint (verificar que funcione)
- 🔴 **Endpoint de registro de usuarios** (`POST /api/public/register`)
- 🔴 **Endpoint de login** (`POST /api/public/login`) - verificar

### Alta Prioridad
- Documentación de la relación User-Organization
- Confirmación de scopes/permisos en tokens
- URLs definitivas de endpoints

### Media Prioridad
- Gestión de organizaciones (CRUD)
- Refresh token functionality
- Client credentials para backend-to-backend

### Baja Prioridad
- Roles y permisos granulares
- Invitaciones a organizaciones
- OAuth2 con providers externos (Google, GitHub)

---

## 11. Contacto y Seguimiento

**Equipo Campaigns**: Esperando notificación cuando los endpoints estén listos.

**Testing**: Una vez implementado, favor notificar para realizar pruebas de integración conjuntas.

**Dudas o Cambios**: Cualquier duda sobre estos requerimientos, favor contactar al equipo de Campaigns.

---

## Anexo: Código de Referencia en Campaigns

### Auth Dependency (Implementado)
Ver: `/Users/dev/Documents/zea/modules/campaigns/backend/presentation/api/dependencies/auth.py`

```python
async def introspect_token(token: str) -> dict:
    """Introspect token with Thalamus OAuth2 server."""
    async with httpx.AsyncClient() as client:
        response = await client.post(
            settings.THALAMUS_INTROSPECT_URL,
            json={"token": token},
            headers={"Content-Type": "application/json"},
            timeout=5.0,
        )

        if response.status_code != 200:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid authentication token",
            )

        data = response.json()

        if not data.get("active", False):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token is not active",
            )

        return data
```

### Uso en Endpoints
```python
from presentation.api.dependencies import get_organization_id, get_current_user

@router.get("/campaigns")
async def list_campaigns(
    organization_id: UUID = Depends(get_organization_id),
    db: Session = Depends(get_db),
):
    # organization_id viene del token introspectado
    campaigns = db.query(CampaignModel).filter(
        CampaignModel.organization_id == organization_id
    ).all()
    return campaigns
```

---

**FIN DEL DOCUMENTO**

Por favor notificar cuando los endpoints estén implementados para proceder con las pruebas de integración.
