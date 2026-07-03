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

### Para Agentes de IA
5. **[Agent Tokens](./11-agent-tokens.md)** ⭐
   - Tokens especializados para agentes de IA
   - Task-scoping y delegation tracking
   - Operation limits y auto-revocación
   - Compliance (EU AI Act)

### Referencia (documentación canónica)
- [OAuth2 Overview](../oauth2/overview.md) — Grants, PKCE, scopes
- [Authorization Code + PKCE](../oauth2/authorization-code.md) — Flujo completo
- [Client Credentials (M2M)](../oauth2/client-credentials.md) — Machine-to-machine
- [Token Introspection](../oauth2/token-introspection.md) — RFC 7662
- [Agents Section](../agents/overview.md) — CLI + Skills
- [API Reference](../api/rest.md) — Todos los endpoints

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
| [`getting-started.md`](../getting-started.md) | Quickstart por persona |
| [`oauth2/`](../oauth2/overview.md) | Referencia canónica OAuth2 |
| [`api/`](../api/rest.md) | Referencia REST API |
| [`OPENAPI_SPEC.yaml`](../OPENAPI_SPEC.yaml) | Especificación formal |

## 🆘 Soporte

Si encuentras algo que no coincide con el código real:
1. Verifica que estés usando la última versión de Thalamus
2. Revisa el código en `lib/thalamus_web/` directamente
3. Abre un issue en GitHub con el problema específico

---

**¡Comienza ahora con el [Tutorial de Integración Completa](./01-integracion-completa.md)!**
