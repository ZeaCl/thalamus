# Respuesta al Equipo de ZEA Platform

**Fecha:** 2025-12-30 (Actualizado)
**Asunto:** Client Secret en Texto Plano - Cliente `platform_web`

---

## ✅ Confirmación del Problema

**Diagnóstico correcto**: El `client_secret` del cliente `platform_web` está almacenado en texto plano en la BD, pero Thalamus espera que esté **hasheado con Bcrypt**.

**Causa del error 401:** Thalamus compara el hash almacenado con el secret enviado usando `Bcrypt.verify_pass/2`. Si el secret en BD está en texto plano, la comparación falla.

---

## ✨ ACTUALIZACIÓN: Endpoint de Rotación Implementado

**NUEVO:** Hemos implementado el endpoint `POST /api/clients/:client_id/rotate-secret` para que puedan rotar el secret **exclusivamente a través de la API REST**, sin necesidad de acceder al código o base de datos de Thalamus.

---

## 🎯 Solución Recomendada: **Rotar Secret vía API**

Esta es la solución **profesional y automatizable** que permite resolver el problema sin acceso directo a la base de datos.

### Pasos a Seguir

**1. Rotar el Client Secret (vía API):**

```bash
curl -X POST "https://thalamus.zea.com/api/clients/client_<PLATFORM_WEB_UUID>/rotate-secret" \
  -H "Authorization: Bearer YOUR_ADMIN_API_KEY" \
  -H "Content-Type: application/json"
```

**Respuesta esperada:**
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

⚠️ **CRÍTICO:** El secret solo se retorna UNA VEZ. Guárdenlo inmediatamente.

**2. Actualizar la variable de entorno:**

```bash
# Actualizar en su sistema de secrets management
export OAUTH2_CLIENT_SECRET="sOodSYnE7YvBf7hg08GUy3jEzgeEQ5LOHZzg9MObKFA"

# O con AWS Secrets Manager
aws secretsmanager update-secret \
  --secret-id platform-oauth-client-secret \
  --secret-string "sOodSYnE7YvBf7hg08GUy3jEzgeEQ5LOHZzg9MObKFA"
```

**3. Reiniciar el servicio:**

```bash
# Kubernetes
kubectl rollout restart deployment/platform-web

# Docker Compose
docker-compose restart platform-web
```

**4. Probar el flujo OAuth2:**

```bash
# Paso 1: Obtener authorization code
# (Usuario hace login en Thalamus y autoriza)

# Paso 2: Intercambiar code por tokens
curl -X POST http://localhost:4000/oauth/token \
  -H "Content-Type: application/json" \
  -d '{
    "grant_type": "authorization_code",
    "code": "<authorization_code_from_step_1>",
    "client_id": "platform_web",
    "client_secret": "dev_secret_change_in_production",
    "redirect_uri": "http://localhost:4001/auth/callback"
  }'
```

**Respuesta esperada (éxito):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 3600,
  "refresh_token": "...",
  "scope": "openid profile email"
}
```

---

## 🔄 Comportamiento del Endpoint

El endpoint implementado realiza las siguientes operaciones de forma automática:

1. ✅ **Genera un nuevo secret criptográficamente seguro**
   - 32 bytes aleatorios (`:crypto.strong_rand_bytes/1`)
   - Codificado en base64url (44 caracteres)

2. ✅ **Hashea automáticamente con Bcrypt**
   - 12 rounds (configuración segura)
   - Hash almacenado en base de datos

3. ✅ **Invalida el secret anterior inmediatamente**
   - El secret anterior deja de funcionar al instante
   - No hay período de gracia

4. ⚠️ **Retorna el secret en texto plano UNA SOLA VEZ**
   - Único momento para obtener el secret
   - No se puede recuperar después

5. ✅ **Actualiza el timestamp `updated_at`**
   - Permite auditar cuándo se rotó

---

## 📚 Documentación Completa

Hemos actualizado la documentación con información detallada sobre el endpoint:

**👉 [OAuth2 Client Management Guide](docs/guides/oauth2-client-management.md)**

La guía incluye:
- ✅ Uso completo del endpoint de rotación
- ✅ Ejemplos en Python, Node.js y Bash
- ✅ Scripts de automatización para rotación periódica
- ✅ Mejores prácticas de seguridad
- ✅ Troubleshooting detallado
- ✅ Plan de disaster recovery

**Documentación actualizada:**
- `docs/README.md` - Índice con referencia al endpoint
- `docs/GETTING_STARTED.md` - Guía rápida actualizada
- `docs/guides/oauth2-client-management.md` - Guía completa

---

## 🔐 Cómo Evitar Este Problema en el Futuro

### ✅ Método Correcto: Usar la API de Thalamus

**Crear cliente via API** (automáticamente hashea el secret):

```bash
curl -X POST http://localhost:4000/api/clients \
  -H "Authorization: ApiKey <admin_api_key>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Platform Web",
    "organization_id": "<org-uuid>",
    "client_type": "confidential",
    "redirect_uris": ["http://localhost:4001/auth/callback"],
    "grant_types": ["authorization_code", "refresh_token"],
    "scopes": ["openid", "profile", "email"]
  }'
```

**Respuesta:**
```json
{
  "data": {
    "client_id": "client_abc123...",
    "client_secret": "plain_secret_xyz...",
    "name": "Platform Web"
  },
  "message": "⚠️ Save the client_secret securely. It cannot be retrieved later."
}
```

**⚠️ Importante:** El `client_secret` solo se muestra **una vez** en esta respuesta. Después se guarda hasheado en la BD.

### ❌ Método Incorrecto: INSERT directo en BD

```sql
-- ❌ NO HACER ESTO
INSERT INTO oauth2_clients (client_secret, ...)
VALUES ('plain_text_secret', ...);  -- Se guarda en texto plano
```

**Por qué falla:**
- El INSERT directo no pasa por el repositorio de Thalamus
- El repositorio es el que hashea automáticamente el secret (líneas 207-210)
- Resultado: secret en texto plano → error 401

---

## 🔄 Próximos Pasos

### Acción Inmediata (Platform)

1. ✅ Llamar al endpoint `/api/clients/:id/rotate-secret`
2. ✅ Guardar el nuevo secret en su secrets manager
3. ✅ Actualizar variable de entorno en platform-web
4. ✅ Reiniciar el servicio
5. ✅ Probar el flujo OAuth2

### Automatización Recomendada

**Script de rotación mensual:**

```python
#!/usr/bin/env python3
# scripts/rotate-platform-secret.py

import requests
import os

THALAMUS_URL = os.getenv("THALAMUS_URL", "https://thalamus.zea.com")
CLIENT_ID = os.getenv("OAUTH2_CLIENT_ID")
API_KEY = os.getenv("THALAMUS_API_KEY")

response = requests.post(
    f"{THALAMUS_URL}/api/clients/{CLIENT_ID}/rotate-secret",
    headers={"Authorization": f"Bearer {API_KEY}"}
)
response.raise_for_status()

new_secret = response.json()["data"]["client_secret"]
print(f"✅ New secret: {new_secret}")

# Actualizar en AWS Secrets Manager
# aws_client.update_secret(SecretId="platform-oauth", SecretString=new_secret)
```

**Cronjob para rotación cada 90 días:**
```bash
0 0 1 */3 * /path/to/rotate-platform-secret.py && kubectl rollout restart deployment/platform-web
```

---

## 📞 Contacto y Soporte

Si tienen preguntas o problemas:

1. **Documentación:** `docs/guides/oauth2-client-management.md` - Guía completa con ejemplos
2. **Troubleshooting:** Ver sección de troubleshooting en la guía
3. **Issues:** [GitHub Issues](https://github.com/zea/thalamus/issues)
4. **Soporte:** Contactar equipo de Thalamus vía Slack #thalamus-support

---

## ✅ Resumen Ejecutivo

| Aspecto | Estado |
|---------|--------|
| **Problema confirmado** | ✅ Sí, secret debe estar hasheado |
| **Solución recomendada** | ✅ Rotar secret vía API REST |
| **Endpoint implementado** | ✅ `POST /api/clients/:id/rotate-secret` |
| **Documentación completa** | ✅ Ver `docs/guides/oauth2-client-management.md` |
| **Probado y funcionando** | ✅ Tests unitarios + manual testing |
| **Acceso a BD requerido** | ❌ No, solo API REST |
| **Tiempo estimado** | ⏱️ 5 minutos (API call + reiniciar servicio) |

**El endpoint está listo para ser usado en producción. No requiere acceso a código o BD de Thalamus.**
