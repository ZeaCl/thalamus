# Getting Started with Thalamus

**Quick integration guide for new teams** | Version 1.0.0

---

## 🎯 What is Thalamus?

Thalamus es el servicio centralizado de autenticación OAuth2 para el ecosistema ZEA. Permite que cualquier aplicación (Sport, Campaigns, Corpus, etc.) autentique usuarios sin implementar su propio sistema de login.

**¿Por qué usar Thalamus?**
- ✅ Single Sign-On (SSO) - Un solo login para todas las apps ZEA
- ✅ OAuth2 2.0 compliant - Estándar de la industria
- ✅ Multi-factor Authentication (MFA) - Mayor seguridad
- ✅ Role-Based Access Control (RBAC) - Permisos granulares
- ✅ Production-ready - Probado y seguro

---

## 🚀 Integración en 4 Pasos

```
┌─────────────────────────────────────────────────────────────┐
│  PASO 0: Super Admin crea Admin API Key                    │
│  └─→ Una sola vez por vertical/servicio                    │
└─────────────────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────────────────┐
│  PASO 1: Tu servicio se auto-registra como OAuth2 Client   │
│  └─→ Obtienes client_id + client_secret                    │
└─────────────────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────────────────┐
│  PASO 2: Configuras OAuth2 en tu aplicación                │
│  └─→ Implementas flujo de autenticación                    │
└─────────────────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────────────────┐
│  PASO 3: Usuarios autentican vía Thalamus                  │
│  └─→ Login → Token → Acceso a tu app                       │
└─────────────────────────────────────────────────────────────┘
```

---

## 📋 Paso 0: Obtener Admin API Key

**¿Quién?** Super admin de Thalamus
**¿Cuándo?** Una sola vez al crear tu vertical/servicio
**Resultado:** Un API Key para que tu servicio se auto-registre

```bash
# El super admin ejecuta:
curl -X POST http://thalamus.zea.com/api/admin/api-keys \
  -H "Authorization: Bearer <super_admin_jwt>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Sport Service",
    "description": "API Key for Sport to self-register",
    "scopes": ["clients:write", "clients:read"],
    "expires_at": "2026-12-31T23:59:59Z"
  }'
```

**Importante:** Guarda el `api_key` que recibes de forma segura (se muestra solo una vez).

📖 **Detalles completos:** [Admin API Keys Guide](guides/admin-api-keys.md)

---

## 📋 Paso 1: Auto-registro como OAuth2 Client

**¿Quién?** Tu equipo de desarrollo
**¿Cuándo?** Una sola vez durante el setup inicial
**Resultado:** Obtienes `client_id` + `client_secret`

```bash
# Tu servicio ejecuta:
curl -X POST http://thalamus.zea.com/api/clients \
  -H "Authorization: ApiKey <admin_api_key_del_paso_0>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Sport Application",
    "organization_id": "<tu-org-uuid>",
    "client_type": "confidential",
    "redirect_uris": ["https://sport.zea.com/auth/callback"],
    "grant_types": ["authorization_code", "refresh_token"],
    "scopes": ["openid", "profile", "email", "sport:read", "sport:write"]
  }'
```

**Guarda las credenciales** en tus variables de entorno:
```bash
OAUTH2_CLIENT_ID=client_abc123...
OAUTH2_CLIENT_SECRET=secret_xyz789...
```

📖 **Scripts de ejemplo:** [Integration Examples](guides/integration-examples.md)

---

## 📋 Paso 2: Configurar OAuth2 en tu App

**¿Quién?** Tu equipo de desarrollo
**¿Qué?** Implementar el flujo OAuth2 en tu aplicación

### Opción A: Aplicación Web/Mobile (Authorization Code)

**Flujo típico:**
1. Usuario hace click en "Login"
2. Redirigir a Thalamus: `/oauth/authorize?client_id=...`
3. Usuario ingresa credenciales en Thalamus
4. Thalamus redirige de vuelta: `/auth/callback?code=...`
5. Tu app intercambia `code` por `access_token`
6. Usas `access_token` para llamar APIs

📖 **Guía detallada:** [OAuth2 Authorization Code Flow](guides/oauth2-authorization-code.md)

### Opción B: Backend-to-Backend (Client Credentials)

**Flujo típico:**
1. Tu servicio solicita token directamente
2. Thalamus retorna `access_token`
3. Usas `access_token` para llamar APIs

📖 **Guía detallada:** [Machine-to-Machine (M2M) Flow](guides/oauth2-client-credentials.md)

---

## 📋 Paso 3: Usar Tokens en tus APIs

Una vez que tienes el `access_token`, úsalo en todas las llamadas a APIs:

```bash
curl -H "Authorization: Bearer <access_token>" \
  https://api.zea.com/sport/events
```

**Validar tokens en tu backend:**
```bash
curl -X POST http://thalamus.zea.com/oauth/introspect \
  -H "Content-Type: application/json" \
  -d '{
    "token": "<access_token>",
    "client_id": "<tu_client_id>",
    "client_secret": "<tu_client_secret>"
  }'
```

📖 **Detalles:** [Token Introspection Guide](guides/token-introspection.md)

---

## 🔧 Ejemplos por Tecnología

Tenemos guías completas con código funcional para:

- 🐍 **Python (FastAPI/Django)** → [Python Integration](examples/python-integration.md)
- 🟢 **Node.js (Express/NestJS)** → [Node.js Integration](examples/nodejs-integration.md)
- ⚛️ **React/Next.js** → [React Integration](examples/react-integration.md)
- 🔷 **Elixir/Phoenix** → [Elixir Integration](examples/elixir-integration.md)

📖 **Todos los ejemplos:** [Integration Examples](guides/integration-examples.md)

---

## 🛠️ Testing Local

### 1. Levantar Thalamus localmente

```bash
git clone <thalamus-repo>
cd thalamus
docker-compose up -d
```

Thalamus estará en `http://localhost:4000`

### 2. Crear usuario de prueba

```bash
curl -X POST http://localhost:4000/api/public/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@zea.com",
    "password": "TestPass123!@#",
    "full_name": "Test User"
  }'
```

### 3. Verificar email (modo desarrollo)

En desarrollo, los tokens de verificación se imprimen en los logs:
```bash
docker-compose logs thalamus | grep "Verification token"
```

### 4. Probar flujo OAuth2

Sigue los ejemplos en las guías de integración específicas.

📖 **Guía completa de testing:** [Testing Guide](guides/testing-guide.md)

---

## 🚀 Deployment a Producción

**Checklist antes de producción:**

- [ ] Configurar `SECRET_KEY_BASE` (64+ caracteres aleatorios)
- [ ] Configurar PostgreSQL production
- [ ] Configurar Redis (opcional pero recomendado)
- [ ] Configurar dominio y SSL/TLS
- [ ] Configurar email service (SMTP)
- [ ] Configurar CORS origins
- [ ] Rotar Admin API Keys cada 90 días
- [ ] Rotar Client Secrets cada 90 días (usar `/api/clients/:id/rotate-secret`)
- [ ] Configurar monitoring y logs

📖 **Guía completa:** [Deployment Guide](DEPLOYMENT_GUIDE.md)

---

## 📚 Documentación Completa

| Documento | Descripción |
|-----------|-------------|
| [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md) | Guía completa de integración (referencia técnica) |
| [OPENAPI_SPEC.yaml](OPENAPI_SPEC.yaml) | Especificación OpenAPI 3.0 (todos los endpoints) |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Arquitectura del sistema |
| [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) | Guía de deployment a producción |

### Guías Específicas

- [OAuth2 Authorization Code Flow](guides/oauth2-authorization-code.md)
- [OAuth2 Client Credentials (M2M)](guides/oauth2-client-credentials.md)
- [OAuth2 Client Management](guides/oauth2-client-management.md) - **Nuevo: Rotar secrets**
- [Admin API Keys](guides/admin-api-keys.md)
- [Token Introspection](guides/token-introspection.md)
- [Multi-Factor Authentication (MFA)](guides/mfa-setup.md)
- [Security Best Practices](guides/security-best-practices.md)

### Ejemplos de Código

- [Python (FastAPI)](examples/python-integration.md)
- [Node.js (Express)](examples/nodejs-integration.md)
- [React/Next.js](examples/react-integration.md)
- [Elixir/Phoenix](examples/elixir-integration.md)

---

## ❓ Troubleshooting

### Error: "Invalid client_id"
- Verifica que el `client_id` sea correcto
- Verifica que el cliente no esté deshabilitado

### Error: "Redirect URI mismatch"
- La `redirect_uri` debe coincidir exactamente con la registrada
- Incluye protocolo (`http://` o `https://`)

### Error: "Invalid grant"
- El `authorization_code` solo se puede usar una vez
- Verifica que no haya expirado (5 minutos)

### Error: "Unauthorized client"
- Verifica `client_secret`
- Verifica que el `grant_type` esté permitido para tu cliente
- Si el secret está en texto plano en BD, usa `/api/clients/:id/rotate-secret`

### ¿Necesitas rotar el client secret?
📖 Ver: [OAuth2 Client Management - Rotar Secret](guides/oauth2-client-management.md#rotar-client-secret)

📖 **Más soluciones:** [Troubleshooting Guide](guides/troubleshooting.md)

---

## 🆘 Soporte

- **Issues/Bugs:** [GitHub Issues](https://github.com/zea/thalamus/issues)
- **Preguntas:** [GitHub Discussions](https://github.com/zea/thalamus/discussions)
- **Email:** dev@zea.com

---

## 🔄 Próximos Pasos

1. ✅ Lee esta guía completa
2. ✅ Solicita Admin API Key al super admin
3. ✅ Sigue la guía específica para tu tecnología
4. ✅ Prueba localmente con Docker
5. ✅ Despliega a staging/producción

**¡Listo para integrar! 🚀**
