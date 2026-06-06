# SAML SSO — Enterprise Single Sign-On

**Status**: ✅ Implementado (core) | ⏳ Pendiente: prueba con IdP real  
**Fecha**: 2026-06-05  
**Branch/Tag**: `feature/saml-sso`

---

## 📌 ¿Qué se implementó?

SAML 2.0 Service Provider (SP) para permitir que organizaciones enterprise se autentiquen en ZEA usando su Identity Provider corporativo (Azure AD, Okta, Google Workspace, etc.).

### Endpoints

| Método | Ruta | Descripción |
|--------|------|-------------|
| `GET` | `/auth/saml/init?email=` | Inicia flujo SAML: detecta org por dominio, redirige al IdP |
| `POST` | `/auth/saml/acs` | Assertion Consumer Service: recibe y valida la assertion del IdP |
| `GET` | `/auth/saml/metadata/:org_id` | SP metadata XML para configurar en el IdP del cliente |
| `GET` | `/api/organizations/:id/saml-config` | Ver configuración SAML de la org |
| `PUT` | `/api/organizations/:id/saml-config` | Crear/actualizar configuración SAML |
| `DELETE` | `/api/organizations/:id/saml-config` | Eliminar configuración SAML |

### Flujo

```
Usuario → /login (email sin password) → /auth/saml/init → Azure AD/Okta
                                                                    ↓
Usuario ← establece sesión JWT ← /auth/saml/acs ← SAML Assertion
```

### Funcionalidades

- ✅ SP-initiated SAML flow
- ✅ Just-in-Time user provisioning (crea usuario automáticamente en primer login)
- ✅ Force SAML por organización (deshabilita password login)
- ✅ Domain matching (allowed_domains por org)
- ✅ Attribute mapping configurable (email, name, avatar_url)
- ✅ JWT token emission después de SAML (mismo sistema de tokens existente)
- ✅ SP metadata generation
- ✅ IdP certificate validation
- ⏳ IdP-initiated flow (el usuario arranca desde el portal del cliente)
- ⏳ Single Logout (SLO)
- ⏳ Mapeo de grupos SAML → roles ZEA
- ⏳ Múltiples IdPs por organización

### Arquitectura

Sigue Clean Architecture con capas separadas:
- **Domain**: `SamlIdentityProvider` entity, `SamlEntityId`, `SamlNameId`, `SamlAttributeMapping` VOs
- **Application**: `AuthenticateUserViaSaml` use case, `SamlIdentityProviderRepository` port, `SamlService` port
- **Infrastructure**: PostgreSQL schema/repo, `SamlyAssertionValidator` adapter (usa `samly`+`esaml`)
- **Web**: `SamlController`, rutas en router, detección SAML en `SessionController`

### Tests

**51 tests, 0 failures** cubriendo todas las capas:
- 21 value object tests
- 14 entity tests
- 6 use case tests (JIT, existing user, error cases)
- 7 repository integration tests
- 3 controller tests

---

## ⏳ Para retomar: Prueba con IdP real

### Paso 1: Crear organización y usuario

```bash
# Registrar org + usuario
curl -X POST http://localhost:4000/api/public/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@contoso.com",
    "password": "SecureP@ss1",
    "password_confirmation": "SecureP@ss1",
    "name": "Contoso Admin",
    "organization_name": "Contoso Corp"
  }'
```

### Paso 2: Verificar email

```bash
curl -X POST http://localhost:4000/api/public/verify-email \
  -H "Content-Type: application/json" \
  -d '{"email": "admin@contoso.com", "token": "<token_del_paso_1>"}'
```

### Paso 3: Obtener JWT

```bash
curl -X POST http://localhost:4000/api/public/login \
  -H "Content-Type: application/json" \
  -d '{"email": "admin@contoso.com", "password": "SecureP@ss1"}'
# Guardar el token de la respuesta
```

### Paso 4: Obtener organization_id

```bash
curl http://localhost:4000/api/organizations \
  -H "Authorization: Bearer <TOKEN>"
```

### Paso 5: Configurar SAML para la org

```bash
ORG_ID="<organization_id>"
TOKEN="<jwt>"

curl -X PUT "http://localhost:4000/api/organizations/$ORG_ID/saml-config" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "saml": {
      "name": "Azure AD - Contoso",
      "idp_entity_id": "<entity_id_del_idp>",
      "idp_sso_url": "<sso_url_del_idp>",
      "idp_certificate": "<cert_x509_base64>",
      "enabled": true,
      "force_saml": false,
      "jit_provisioning": true,
      "allowed_domains": ["contoso.com"],
      "attribute_mapping": {
        "email": "emailaddress",
        "name": "displayname"
      }
    }
  }'
```

### Paso 6: Probar login SAML

```bash
# En navegador: http://localhost:4000/login
# Poner "pepito@contoso.com" sin password → redirige al IdP
```

---

## 🔧 Opciones de IdP para testing

### A) Local (desarrollo rápido)
```bash
docker run -d --name saml-idp -p 8080:8080 -p 8443:8443 \
  -e SIMPLESAMLPHP_SP_ENTITY_ID=https://auth.zea.cl \
  -e SIMPLESAMLPHP_SP_ASSERTION_CONSUMER_SERVICE=http://localhost:4000/auth/saml/acs \
  kristophjunge/docker-test-saml-idp
```

### B) Azure AD (escenario enterprise real)
1. Azure Portal → Microsoft Entra ID → Enterprise Applications → Create
2. SAML config: Entity ID = `https://auth.zea.cl`, Reply URL = `http://localhost:4000/auth/saml/acs`
3. Bajar Certificate (Base64) y Login URL
4. Configurar en Thalamus con los datos de Azure

### C) samltest.id (testing SaaS gratuito)
https://samltest.id/ — provee un IdP público para pruebas

---

## 📁 Archivos del feature

### Nuevos (14)
```
lib/thalamus/domain/value_objects/saml_entity_id.ex
lib/thalamus/domain/value_objects/saml_name_id.ex
lib/thalamus/domain/value_objects/saml_attribute_mapping.ex
lib/thalamus/domain/entities/saml_identity_provider.ex
lib/thalamus/application/ports/saml_identity_provider_repository.ex
lib/thalamus/application/services/saml_service.ex
lib/thalamus/application/use_cases/authenticate_user_via_saml.ex
lib/thalamus/infrastructure/persistence/schemas/saml_identity_provider_schema.ex
lib/thalamus/infrastructure/repositories/postgresql_saml_identity_provider_repository.ex
lib/thalamus/infrastructure/adapters/samly_assertion_validator.ex
lib/thalamus_web/controllers/saml_controller.ex
priv/repo/migrations/20260605194100_create_saml_identity_providers.exs
priv/saml/sp_private_key.pem
priv/saml/sp_certificate.pem
```

### Modificados (6)
```
mix.exs                                          ← {:samly, "~> 1.4"}
config/config.exs                                ← SAML config + samly config
lib/thalamus_web/router.ex                       ← 6 rutas SAML nuevas
lib/thalamus_web/controllers/session_controller.ex   ← detección SAML en login
lib/thalamus_web/controllers/api/organization_controller.ex ← CRUD SAML config
test/test_helper.exs                             ← 2 mocks nuevos
```

### Tests (8 archivos)
```
test/thalamus/domain/value_objects/saml_entity_id_test.exs
test/thalamus/domain/value_objects/saml_name_id_test.exs
test/thalamus/domain/value_objects/saml_attribute_mapping_test.exs
test/thalamus/domain/entities/saml_identity_provider_test.exs
test/thalamus/application/use_cases/authenticate_user_via_saml_test.exs
test/thalamus/infrastructure/repositories/postgresql_saml_idp_repository_test.exs
test/thalamus_web/controllers/saml_controller_test.exs
```
