# ZEA Thalamus — Pendientes de Seguridad

## Implementado ✅
- [x] OAuth2 PKCE flow (SDK + CLI)
- [x] CSRF protection (state param)
- [x] CORS por origin (`localhost:*` en dev, configuración automática en registro)
- [x] Rate limiting en `/register` (5/min por IP)
- [x] `.gitignore` automático para `.zea-config.json`
- [x] Public client (sin secret, seguro para SPAs)

## Pendiente ⏳

### Email Verification
- [ ] Configurar SMTP en Thalamus
- [ ] Enviar email con link de verificación post-registro
- [ ] Endpoint `/verify` para validar token
- [ ] Bloquear login si email no verificado (opcional por org)

### MFA (Multi-Factor Authentication)
- [ ] TOTP (Google Authenticator)
- [ ] WebAuthn/Passkeys
- [ ] Recovery codes

### Token Security
- [ ] Refresh token rotation (cada refresh invalida el anterior)
- [ ] Token en httpOnly cookie (para clientes con backend)
- [ ] Revocación de tokens

### Registro
- [ ] Validación de fortaleza de contraseña
- [ ] Confirmar que org_name sea único (hoy tiene sufijo random)
- [ ] Captcha en /register

### SDK
- [ ] `client_id` de 16 bytes en vez de 8
- [ ] Auto-detección de CORS origin si falla el primer intento
- [ ] Renovación automática de token (refresh)
