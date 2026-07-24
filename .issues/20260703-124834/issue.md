# Issue: Documentación e integración de apps con Thalamus — Lecciones de cerebelum-cli login

**Autor:** AI Agent (cerebelum-core E4)
**Fecha:** 2026-07-03
**Contexto:** Implementación de `cerebelum login` vía OAuth2 Thalamus

---

## Resumen

Estuve implementando el flujo de login OAuth2 + PKCE para el CLI de cerebelum (`npx @zea.cl/cerebelum-cli login`). La implementación técnica fue directa (~1h), pero perdí mucho tiempo entendiendo **cómo se relacionan los clientes OAuth2 del ecosistema ZEA** porque no está documentado el patrón de "bootstrap client".

---

## Lo que hice

1. Leí el código de Thalamus: controllers OAuth2, router, seeds, session controller
2. Implementé PKCE + localhost:4005 callback en `cerebelum-cli/src/commands/login.ts`
3. Probé conectividad contra `https://auth.zea.cl` (OIDC discovery, authorize, token)
4. Descubrí que `zea-auth-init` (en `@zea.cl/auth`) hace exactamente lo mismo

## Lo que funciona

| Componente | Estado |
|---|---|
| `GET /.well-known/openid-configuration` | ✅ `https://auth.zea.cl` |
| `GET /oauth/authorize?client_id=thalamus_cli&...` | ✅ 302 → login page |
| `POST /oauth/token` (code exchange) | ✅ Formato RFC 6749 correcto |
| `cerebelum login` (código) | ✅ Compila, build OK |

---

## Dudas / Confusiones que tuve

### 1. ¿`thalamus_cli` es "el CLI de Thalamus" o un bootstrap client compartido?

La respuesta es: **es un bootstrap client compartido**. Lo usan:
- `npx zea-auth-init` → para loguear al developer y registrar una nueva app
- `cerebelum login` → para loguear al developer y guardar JWT

Esto **no está documentado en ningún lado**. Deduje el patrón leyendo el código de `zea-auth-init.mjs` y comparándolo con el authorization controller.

**Sugerencia:** Agregar una sección en la doc de Thalamus explicando el patrón de bootstrap client, qué es `thalamus_cli`, y cuándo usarlo.

### 2. ¿Cerebelum debería tener su propio client_id o usar `thalamus_cli`?

La respuesta es: **usa `thalamus_cli`**. Es el punto de entrada unificado del ecosistema. No hay necesidad de crear `cerebelum_cli` porque:

- `thalamus_cli` ya tiene auto-approve (first-party client en el controller)
- No se necesita registrar un nuevo OAuth2 client (cerebelum no es una app web, es un CLI que consume la API de cerebelum directamente con el JWT)

**Sugerencia:** Documentar explícitamente en Thalamus: "Si tu app necesita autenticar developers vía CLI, usá `thalamus_cli` como client_id. Si es una app web/spa, usá `npx zea-auth-init` para registrar tu propio client."

### 3. La lista de auto-approve está hardcodeada en el controller

```elixir
# lib/thalamus_web/controllers/oauth2/authorization_controller.ex
if client_id_string in [
     "platform_web",
     "thalamus_cli",
     "59991e63-852c-44e5-aee1-a761ec76eaea"
   ] or String.starts_with?(client_id_string, "app_") do
  # auto-approve
```

**Sugerencia:** ¿Debería ser una columna en `oauth2_clients` (ej: `auto_approve: boolean`) en vez de hardcodeado?

### 4. OIDC discovery retorna `http://` en vez de `https://`

```
"issuer": "http://auth.zea.cl",          ← debería ser https://
"authorization_endpoint": "http://..."    ← debería ser https://
```

Asumo que es porque Caddy maneja TLS termination y el header `X-Forwarded-Proto` no se está configurando correctamente en Thalamus. No es bloqueante (los endpoints funcionan con HTTPS), pero es incorrecto según la spec OIDC.

### 5. En los seeds, `thalamus_cli` usa `client_secret` dummy

```ruby
client_secret: "cli_secret_does_not_matter_pkce_public_client"
```

Esto funciona porque es un cliente público con PKCE, pero el valor podría confundir a alguien que no entienda que `client_type: :public` implica que el secret no se usa en el token exchange. **Sugerencia:** Cambiar a `nil` o documentar por qué es un valor dummy.

---

## Sugerencias de issues para el board de Thalamus

Propongo crear estos issues en el board de Thalamus:

### 🟡 Mejoras de documentación

1. **Doc: Bootstrap client pattern (`thalamus_cli`)**
   - Explicar qué es `thalamus_cli`, cuándo usarlo vs registrar un client propio
   - Diagrama de cómo las apps del ecosistema se autentican a través de Thalamus
   - Ejemplo: cerebelum login, zea-auth-init

2. **Doc: "How to integrate a new CLI/API with Thalamus"**
   - Guía paso a paso: PKCE, scopes, token exchange, storage
   - Template de código para CLI tools (Node.js)
   - Decisión: ¿usar `thalamus_cli` o registrar client propio?

### 🟢 Mejoras técnicas

3. **Fix: OIDC discovery issuer usa `https://` cuando está detrás de reverse proxy**
   - Configurar `X-Forwarded-Proto` en el endpoint o en Caddy
   - O hardcodear el scheme en prod config

4. **Refactor: Mover auto-approve a columna en `oauth2_clients`**
   - Agregar `auto_approve: boolean` al schema
   - Migración para marcar los clientes existentes
   - Quitar el hardcode del controller

5. **Cleanup: Usar `nil` en vez de string dummy para `client_secret` de clientes públicos**
   - Cambiar `"cli_secret_does_not_matter_pkce_public_client"` → `nil`

---

## Información que me habría ahorrado tiempo

Si hubiera tenido desde el principio:

1. **Un diagrama de arquitectura de auth del ecosistema ZEA** mostrando:
   ```
   Usuario → [Browser] → Thalamus (OAuth2)
                        ↓
              thalamus_cli (bootstrap client)
              ├── zea-auth-init → registra app_XXX
              └── cerebelum login → guarda JWT
   ```

2. **Una tabla de clientes OAuth2 pre-registrados y su propósito:**
   | Client ID | Tipo | Propósito |
   |---|---|---|
   | `thalamus_cli` | public | Bootstrap - autentica developers para registrar apps |
   | `platform_web` | public | ZEA Platform web app |
   | `cerebelum_service` | confidential | M2M - Cerebelum Engine ↔ Thalamus |
   | `internal_login` | confidential | Login interno (deprecado) |

3. **Que `README.md` o `docs/` de Thalamus mencione explícitamente a `thalamus_cli`** como el bootstrap client y explique el patrón.

---

## Conclusión

La implementación técnica de `cerebelum login` está lista y es correcta. La fricción estuvo en entender el **modelo de integración del ecosistema**, no en la tecnología. Con mejor documentación sobre el rol de `thalamus_cli` y el patrón de bootstrap client, otro desarrollador (o AI agent) lo resolvería en 15 minutos en vez de 1 hora.
