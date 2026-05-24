# Tutoriales de Integración con Thalamus

Esta sección contiene tutoriales prácticos paso a paso para integrarse con Thalamus, basados en el **código real implementado**.

## 📚 Tutoriales Disponibles

### Para Desarrolladores
1. **[Integración Completa](./01-integracion-completa.md)** ⭐ COMENZAR AQUÍ
   - Tutorial paso a paso desde cero
   - Basado en código real de Thalamus
   - Incluye todos los flujos OAuth2

### Por Tipo de Aplicación
2. **[Frontend Web (React/Next.js)](./02-frontend-web.md)**
   - Authorization Code Flow + PKCE
   - Manejo de tokens en el navegador
   - Rutas protegidas

3. **[Backend API (Node.js/Python)](./03-backend-api.md)**
   - Client Credentials (M2M)
   - Validación de tokens
   - Rate limiting

4. **[Aplicación Móvil](./04-mobile-app.md)**
   - Authorization Code + PKCE
   - Deep linking
   - Refresh tokens

### Por Flujo OAuth2
5. **[Authorization Code Flow](./05-authorization-code-flow.md)**
   - Flujo completo con código de autorización
   - PKCE (Proof Key for Code Exchange)
   - Estado y seguridad CSRF

6. **[Client Credentials (M2M)](./06-client-credentials-m2m.md)**
   - Autenticación máquina a máquina
   - Sin interacción de usuario
   - Service accounts

7. **[Token Refresh](./07-token-refresh.md)**
   - Renovación de tokens
   - Manejo de expiración
   - Rotación de refresh tokens

### Temas Avanzados
8. **[Admin API Keys](./08-admin-api-keys.md)**
   - Auto-registro de clientes OAuth2
   - Service-to-service authentication
   - Gestión de permisos

9. **[Multi-Factor Authentication](./09-mfa-integration.md)**
   - Integración con TOTP/MFA
   - Flujo de login con 2FA
   - Backup codes

10. **[Token Introspection](./10-token-introspection.md)**
    - Validación de tokens en backend
    - Metadatos del token
    - Caché de validaciones

11. **[Agent Tokens](./11-agent-tokens.md)** ⭐ NUEVO - Para Agentes de IA
    - Tokens especializados para agentes de IA
    - Task-scoping y delegation tracking
    - Operation limits y auto-revocación
    - Compliance (EU AI Act)

## 🎯 ¿Por Dónde Empezar?

### Si eres nuevo en Thalamus:
👉 **Empieza con: [01-integracion-completa.md](./01-integracion-completa.md)**

Este tutorial te guiará desde cero con:
- Análisis del código real
- Endpoints disponibles
- Ejemplos prácticos
- Troubleshooting

### Si ya conoces OAuth2:
- **Frontend?** → Tutorial 02 (Frontend Web)
- **Backend?** → Tutorial 03 (Backend API) o 06 (Client Credentials)
- **Mobile?** → Tutorial 04 (Mobile App)

### Si tienes un caso específico:
- **Auto-registro de servicios** → Tutorial 08 (Admin API Keys)
- **Validar tokens** → Tutorial 10 (Token Introspection)
- **MFA** → Tutorial 09 (MFA Integration)

## 📖 Cómo Usar Estos Tutoriales

Cada tutorial incluye:

✅ **Análisis del código real** de Thalamus (no especulación)
✅ **Endpoints exactos** con ejemplos curl
✅ **Código funcional** listo para usar
✅ **Errores comunes** y cómo resolverlos
✅ **Diagramas de flujo** cuando son necesarios

## 🔄 Actualización

Estos tutoriales se actualizan cuando hay cambios en el código de Thalamus. La última actualización fue basada en el análisis del código el **2026-01-23**.

## 💡 Diferencia con Otra Documentación

| Documento | Propósito |
|-----------|-----------|
| **Tutoriales** (aquí) | Paso a paso práctico basado en código real |
| `GETTING_STARTED.md` | Vista rápida conceptual |
| `INTEGRATION_GUIDE.md` | Referencia técnica completa |
| `OPENAPI_SPEC.yaml` | Especificación formal de API |

## 🆘 Soporte

Si encuentras algo que no coincide con el código real:
1. Verifica que estés usando la última versión de Thalamus
2. Revisa el código en `lib/thalamus_web/` directamente
3. Abre un issue en GitHub con el problema específico

---

**¡Comienza ahora con el [Tutorial de Integración Completa](./01-integracion-completa.md)!**
