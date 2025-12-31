# Thalamus Documentation

**Centro de documentación para integración con Thalamus**

---

## 🚀 Empezar Aquí

**¿Primera vez integrando con Thalamus?** Lee esto primero:

👉 **[GETTING_STARTED.md](GETTING_STARTED.md)** - Guía rápida de integración en 4 pasos

---

## 📚 Documentación Principal

### Para Integradores y Desarrolladores

| Documento | Descripción | Cuándo usar |
|-----------|-------------|-------------|
| **[GETTING_STARTED.md](GETTING_STARTED.md)** | Guía rápida de integración | 🟢 **Empieza aquí** |
| **[INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md)** | Guía completa con todos los detalles | Referencia técnica detallada |
| **[OPENAPI_SPEC.yaml](OPENAPI_SPEC.yaml)** | Especificación OpenAPI 3.0 | Referencia de API completa |
| **[ARCHITECTURE.md](ARCHITECTURE.md)** | Arquitectura del sistema | Entender cómo funciona internamente |
| **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** | Guía de deployment | Desplegar a producción |

---

## 🎯 Guías Específicas

### Autenticación y OAuth2

| Guía | Descripción |
|------|-------------|
| **[Admin API Keys](guides/admin-api-keys.md)** | Autenticación servicio-a-servicio |
| **[OAuth2 Authorization Code](guides/oauth2-authorization-code.md)** | Flujo para aplicaciones web/mobile |
| **[OAuth2 Client Credentials](guides/oauth2-client-credentials.md)** | Flujo Machine-to-Machine (M2M) |
| **[OAuth2 Client Management](guides/oauth2-client-management.md)** | Gestionar clientes OAuth2 y rotar secrets |
| **[Token Introspection](guides/token-introspection.md)** | Validar tokens en tu backend |
| **[Multi-Factor Authentication](guides/mfa-setup.md)** | Configurar MFA para usuarios |

### Integración y Desarrollo

| Guía | Descripción |
|------|-------------|
| **[Integration Examples](guides/integration-examples.md)** | Ejemplos de código por tecnología |
| **[Security Best Practices](guides/security-best-practices.md)** | Recomendaciones de seguridad |
| **[Troubleshooting](guides/troubleshooting.md)** | Solución de problemas comunes |
| **[Testing Guide](guides/testing-guide.md)** | Cómo probar tu integración |

---

## 💻 Ejemplos de Código

### Por Tecnología

| Tecnología | Guía | Descripción |
|------------|------|-------------|
| 🐍 **Python** | [Python Integration](examples/python-integration.md) | FastAPI, Django, Flask |
| 🟢 **Node.js** | [Node.js Integration](examples/nodejs-integration.md) | Express, NestJS |
| ⚛️ **React** | [React Integration](examples/react-integration.md) | React, Next.js |
| 🔷 **Elixir** | [Elixir Integration](examples/elixir-integration.md) | Phoenix Framework |

---

## 🔍 Buscar Documentación

### Por Caso de Uso

**Necesito autenticar usuarios en mi web app**
→ [OAuth2 Authorization Code Flow](guides/oauth2-authorization-code.md)

**Necesito comunicación backend-to-backend**
→ [OAuth2 Client Credentials (M2M)](guides/oauth2-client-credentials.md)

**Necesito que mi servicio se auto-registre**
→ [Admin API Keys](guides/admin-api-keys.md)

**Necesito validar tokens en mi API**
→ [Token Introspection](guides/token-introspection.md)

**Necesito rotar el secret de mi cliente OAuth2**
→ [OAuth2 Client Management](guides/oauth2-client-management.md)

**Necesito implementar MFA**
→ [Multi-Factor Authentication](guides/mfa-setup.md)

**Necesito ejemplos de código**
→ [Integration Examples](guides/integration-examples.md)

**Tengo errores/problemas**
→ [Troubleshooting](guides/troubleshooting.md)

**Voy a producción**
→ [Deployment Guide](DEPLOYMENT_GUIDE.md)

### Por Rol

**Soy Developer (Frontend/Backend)**
1. [GETTING_STARTED.md](GETTING_STARTED.md)
2. [Integration Examples](guides/integration-examples.md)
3. [OAuth2 Flows](guides/oauth2-authorization-code.md)

**Soy DevOps/SRE**
1. [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)
2. [Security Best Practices](guides/security-best-practices.md)
3. [ARCHITECTURE.md](ARCHITECTURE.md)

**Soy QA/Tester**
1. [Testing Guide](guides/testing-guide.md)
2. [Troubleshooting](guides/troubleshooting.md)
3. [OPENAPI_SPEC.yaml](OPENAPI_SPEC.yaml)

**Soy Architect/Tech Lead**
1. [ARCHITECTURE.md](ARCHITECTURE.md)
2. [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md)
3. [Security Best Practices](guides/security-best-practices.md)

---

## 📖 Referencia Rápida

### Endpoints Principales

```bash
# OAuth2
POST /oauth/authorize          # Authorization screen
POST /oauth/token              # Exchange code/credentials for tokens
POST /oauth/introspect         # Validate tokens
POST /oauth/revoke             # Revoke tokens
GET  /oauth/userinfo           # Get user info (OpenID Connect)

# Public API
POST /api/public/register      # User registration
POST /api/public/login         # User login
POST /api/public/verify-email  # Email verification

# Authenticated API (require Bearer token)
GET    /api/users                        # List users
POST   /api/users                        # Create user
GET    /api/clients                      # List OAuth2 clients
POST   /api/clients                      # Create OAuth2 client
POST   /api/clients/:id/rotate-secret    # Rotate OAuth2 client secret

# Admin API (require ApiKey header)
GET    /api/admin/api-keys     # List API keys (super admin only)
POST   /api/admin/api-keys     # Create API key (super admin only)
DELETE /api/admin/api-keys/:id # Revoke API key (super admin only)
```

### Authentication Headers

```bash
# JWT Bearer Token (for user authentication)
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# Admin API Key (for service authentication)
Authorization: ApiKey ak_dev_vK8mN2pQ7xR9tY3wZ5aB1cD4eF6gH8jL
```

### Environment Variables

```bash
# Thalamus Configuration
THALAMUS_URL=http://localhost:4000

# OAuth2 Credentials (después del auto-registro)
OAUTH2_CLIENT_ID=client_abc123...
OAUTH2_CLIENT_SECRET=secret_xyz789...

# Admin API Key (para auto-registro)
THALAMUS_API_KEY=ak_dev_vK8mN2pQ7xR9tY3wZ5aB1cD4eF6gH8jL

# Organization
ORGANIZATION_ID=660e8400-e29b-41d4-a716-446655440000
```

---

## 🛠️ Herramientas

### Swagger UI (visualizar OpenAPI)

```bash
docker run -p 8082:8080 \
  -e SWAGGER_JSON=/spec/openapi.yaml \
  -v $(pwd)/OPENAPI_SPEC.yaml:/spec/openapi.yaml \
  swaggerapi/swagger-ui
```

Abre: http://localhost:8082

### Thalamus Local (testing)

```bash
git clone <thalamus-repo>
cd thalamus
docker-compose up -d
```

Thalamus: http://localhost:4000

---

## 🔗 Links Útiles

- **GitHub Repository:** https://github.com/zea/thalamus
- **Issues/Bugs:** https://github.com/zea/thalamus/issues
- **Discussions:** https://github.com/zea/thalamus/discussions

---

## 📝 Notas

### Estado de la Documentación

| Documento | Estado |
|-----------|--------|
| GETTING_STARTED.md | ✅ Completo |
| INTEGRATION_GUIDE.md | ✅ Completo |
| OPENAPI_SPEC.yaml | ✅ Completo |
| Admin API Keys Guide | ✅ Completo |
| OAuth2 Client Management | ✅ Completo |
| OAuth2 Authorization Code | 🚧 En progreso |
| OAuth2 Client Credentials | 🚧 En progreso |
| Token Introspection | 🚧 En progreso |
| Integration Examples | 🚧 En progreso |

### Convenciones

- ✅ = Completado y validado
- 🚧 = En progreso
- 📝 = Planeado
- ❌ = Deprecado

---

## 🔄 Historial de Cambios

Ver [CHANGELOG.md](../CHANGELOG.md)

---

**¿No encuentras lo que buscas?** Abre un [issue](https://github.com/zea/thalamus/issues) o pregunta en [discussions](https://github.com/zea/thalamus/discussions).
