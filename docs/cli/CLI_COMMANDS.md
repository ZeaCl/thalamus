# ZEA CLI — Thalamus Command Reference

> **Status**: Draft v0.3 — estructura `zea <servicio> <recurso> <verbo>` + análisis comparativo
> **Última actualización**: 2025-07-21

---

## Benchmark: ZEA CLI vs AWS / Azure / Google Cloud

Antes de definir los comandos, analizamos cómo las CLIs más usadas del mundo resuelven
los mismos problemas. Esto no es copiar — es no reinventar ruedas que ya son redondas.

### Comparativa estructural

| Aspecto | AWS CLI | Azure CLI | gcloud (GCP) | **ZEA CLI** |
|---|---|---|---|---|
| **Patrón** | `aws <svc> <verbo>` | `az <svc> <verbo>` | `gcloud <grupo> <sub> <verbo>` | `zea <svc> <recurso> <verbo>` ✅ |
| **Auth** | `aws configure` + IAM | `az login` (browser) | `gcloud auth login` | `zea thalamus auth login` ✅ |
| **Perfiles** | `--profile` | `--subscription` | `--project` + `gcloud config` | `--org` + `zea thalamus org switch` ✅ |
| **Output formats** | `--output json\|table\|text\|yaml` | `--output json\|table\|tsv\|yaml` | `--format json\|yaml\|csv\|table` | ❌ solo texto plano |
| **Filtrado** | `--query` (JMESPath) | `--query` (JMESPath) | `--filter` (server-side) | ❌ no existe |
| **Dry run** | `--dry-run` | `--dry-run` | `--dry-run` | ❌ no existe |
| **Modo silencioso** | `--no-cli-pager` | `--only-show-errors` | `--quiet` | ❌ no existe |
| **Paginación** | `--max-items` + auto | `--max-items` | `--limit` + auto | ❌ manual |
| **Wizard inicial** | `aws configure` | `az configure` | `gcloud init` | `zea setup` (planeado) |
| **Help** | `aws <svc> help` | `az <svc> --help` | `gcloud help` | `zea --help` ✅ |
| **Resource detail** | `describe-*` | `show` | `describe` | `show` ✅ |
| **CRUD verbs** | create/list/describe/update/delete | create/list/show/update/delete | create/list/describe/update/delete | create/list/show/update/delete ✅ |

### Lecciones aprendidas de las Big 3

1. **Formato de salida es tabla por defecto, JSON con `--output json`**
   - Las 3 usan tabla como default humano, JSON para scripting
   - gcloud usa `--format` en vez de `--output`, pero el concepto es idéntico
   - ZEA CLI debe implementar `--output json|table|text` como flag global

2. **`--dry-run` salva vidas**
   - AWS lo tiene en create/delete/update
   - Muestra qué pasaría sin ejecutar
   - En ZEA: `zea thalamus client create --dry-run` → muestra el request body que se enviaría

3. **`--query` / `--filter` evita `grep | awk`**
   - AWS y Azure usan JMESPath: `aws ec2 describe-instances --query 'Reservations[*].Instances[*].InstanceId'`
   - gcloud usa `--filter` server-side: `gcloud compute instances list --filter="zone:us-central1-a"`
   - ZEA CLI puede implementar `--query` (client-side JMESPath) en v1, `--filter` (server-side) en v2

4. **Paginación automática** es esperada
   - `aws s3 ls` pagina automáticamente si hay 10,000+ objetos
   - `gcloud compute instances list` usa `--limit` con auto-pagination
   - ZEA debe paginar automáticamente con `--limit` para control

5. **Profiles > variables de entorno sueltas**
   - AWS: `~/.aws/config` + `~/.aws/credentials` con secciones `[profile name]`
   - Azure: `~/.azure/config` con secciones por subscription
   - gcloud: `gcloud config configurations`
   - ZEA hoy: `~/.config/zea/config.json` plano (sin multi-profile)
   - ZEA debería: `~/.config/zea/profiles/<name>.json` con `zea profile switch`

### Lo que ZEA hace diferente (y está bien)

1. **Multi-tenancy es first-class, no un afterthought**
   - AWS tiene `--profile` para cambiar de cuenta, pero es un switch de contexto pesado
   - ZEA tiene `zea thalamus org switch` ligero y `--org` en cada comando — correcto para el modelo multi-tenant

2. **OAuth2 Client management como comando nativo**
   - AWS/Azure/GCloud no exponen OAuth2 client registration en su CLI (lo manejan en consola web)
   - ZEA lo necesita porque los microservicios se registran como OAuth2 clients — es correcto tener `zea thalamus client`

3. **Domain Roles para microservicios**
   - No existe equivalente directo en las Big 3 — es un patrón ZEA
   - `zea thalamus domain register/grant` es la DX correcta para el modelo de autorización por dominio

### Decisiones de diseño

| Decisión | Inspirado por | Motivo |
|---|---|---|
| `zea <servicio> <recurso> <verbo>` | Las 3 | Consistencia con el ecosistema, fácil de adivinar |
| `--output json\|table` global | Las 3 | Table para humanos, JSON para `jq` y scripts |
| `--dry-run` en create/delete | AWS | Seguridad: validar antes de ejecutar |
| `--query` JMESPath | AWS/Azure | Filtrar output sin depender de `jq` externo |
| `zea thalamus doctor` | Propio | No existe en las Big 3 — valor diferencial: diagnóstico completo de integración |
| `zea setup` wizard | Las 3 | `aws configure`, `az configure`, `gcloud init` — primera experiencia |
| `zea profile` (v2) | AWS | Multi-entorno: dev/staging/prod, multi-cliente |

---

## Arquitectura de comandos

La CLI sigue el patrón `zea <servicio> <recurso> <verbo> [--flags]`, alineado con
AWS (`aws iam role create`), Azure (`az ad app create`) y GCloud (`gcloud compute instances list`).

El namespace `thalamus` es **built-in** en la CLI core (no un binario externo).
Otros servicios como `cerebelum`, `cortex`, `glia` se descubren dinámicamente desde `$PATH`
(binarios `zea-cerebelum`, `zea-cortex`, etc.).

```
zea
├── thalamus                ← Servicio built-in (Identity & Auth)
│   ├── auth                ← Autenticación y sesión
│   │   ├── login           ← OAuth2 PKCE + direct login
│   │   ├── logout          ← Revocar token
│   │   ├── whoami          ← UserInfo del token actual
│   │   ├── refresh         ← Refresh token
│   │   └── debug           ← Introspect token
│   │
│   ├── org                 ← Organizaciones (multi-tenancy)
│   │   ├── list            ← Listar mis orgs
│   │   ├── show            ← Ver detalle de una org
│   │   ├── create          ← Crear org
│   │   ├── update          ← Actualizar org
│   │   ├── switch          ← Cambiar org activa (local)
│   │   ├── member          ← Gestión de miembros
│   │   │   ├── add         ← Agregar miembro
│   │   │   ├── remove      ← Remover miembro
│   │   │   └── list        ← Listar miembros
│   │   └── saml            ← SAML SSO config
│   │
│   ├── client              ← OAuth2 Clients
│   │   ├── list
│   │   ├── show
│   │   ├── create
│   │   ├── update
│   │   ├── delete
│   │   ├── rotate-secret
│   │   ├── add-redirect-uri
│   │   └── validate
│   │
│   ├── token               ← Personal Access Tokens
│   │   ├── create
│   │   ├── list
│   │   └── revoke
│   │
│   ├── user                ← Usuarios
│   │   ├── list
│   │   ├── show
│   │   ├── create
│   │   ├── update
│   │   ├── delete
│   │   ├── role            ← Asignación de roles
│   │   └── scopes          ← Effective scopes
│   │
│   ├── domain              ← Domain Roles (microservicios)
│   │   ├── list
│   │   ├── register
│   │   ├── grant
│   │   ├── revoke
│   │   └── roles
│   │
│   ├── role                ← RBAC Roles
│   │   ├── list
│   │   ├── show
│   │   ├── create
│   │   ├── update
│   │   └── delete
│   │
│   ├── mfa                 ← Multi-Factor Authentication
│   │   ├── setup
│   │   ├── verify
│   │   ├── disable
│   │   └── backup-codes
│   │
│   ├── secret              ← Secrets Management
│   │   ├── list
│   │   ├── create
│   │   ├── delete
│   │   └── resolve
│   │
│   ├── audit               ← Auditoría y compliance
│   │   └── export
│   │
│   ├── health              ← Health check
│   │
│   ├── oidc                ← OpenID Connect Discovery
│   │   ├── discovery
│   │   └── jwks
│   │
│   ├── doctor              ← Diagnóstico completo
│   │
│   └── admin               ← Admin API Keys (super_admin)
│       └── api-key
│           ├── list
│           ├── show
│           ├── create
│           ├── revoke
│           └── rotate
│
├── cerebelum               ← Servicio externo (binario zea-cerebelum)
│   └── workflow ...
│
├── cortex                  ← Servicio externo (binario zea-cortex)
│   └── chat ...
│
├── config                  ← Configuración local (global, cross-service)
│   ├── set-env
│   ├── set
│   ├── get
│   ├── list
│   ├── unset
│   └── path
│
└── setup                   ← Wizard de primer uso (global)
```

> **Nota**: `zea config` y `zea setup` son globales (sin namespace de servicio) porque
> operan sobre la configuración local de la CLI, no contra un servicio remoto.
> Esto es consistente con `aws configure` y `gcloud init`.

---

## 1. Autenticación y Sesión

### `zea thalamus auth login`

Autentica contra Thalamus. Dos modos:

```bash
# Modo interactivo (OAuth2 PKCE + browser)
zea thalamus auth login

# Modo directo (no interactivo, CI/CD)
zea auth login --email c@zea.cl --password "..."
```

| # | Caso de prueba | Input | Expected Output | Exit |
|---|---|---|---|---|
| 1.1 | PKCE — flujo completo | `zea thalamus auth login` | Browser se abre, login en Thalamus, token guardado. `✅ Successfully authenticated! User: c@zea.cl (Carlos Hinostroza)` | 0 |
| 1.2 | PKCE — puerto ocupado | Puerto 4005 en uso | `⚠️ Port 4005 in use, trying 4006...` flujo continúa | 0 |
| 1.3 | PKCE — timeout | Usuario cierra browser | `❌ Authentication timed out after 5 minutes` | 1 |
| 1.4 | Directo — credenciales válidas | `--email c@zea.cl --password correcta` | `✅ Successfully authenticated! User: c@zea.cl (Carlos Hinostroza)` | 0 |
| 1.5 | Directo — credenciales inválidas | Email correcto, password mal | `❌ Invalid email or password` | 1 |
| 1.6 | Directo — cuenta no verificada | Email no verificado | `❌ Account email has not been verified. Check your inbox.` | 1 |
| 1.7 | Directo — cuenta locked | 5+ intentos fallidos | `❌ Account temporarily locked. Wait 15 minutes or reset password.` | 1 |
| 1.8 | Directo — cuenta suspendida | Usuario suspended | `❌ Account has been suspended. Contact your admin.` | 1 |
| 1.9 | Directo — Thalamus caído | Servicio no responde | `❌ Cannot reach auth.zea.localhost. Is Thalamus running? Run: zea thalamus doctor` | 1 |
| 1.10 | Directo — timeout | Request >30s | `❌ Connection timed out after 30s. Check your network or Thalamus URL.` | 1 |

### `zea thalamus auth whoami`

```bash
zea thalamus auth whoami
```

| # | Caso de prueba | Expected Output | Exit |
|---|---|---|---|
| 2.1 | Token válido | `c@zea.cl | ZEA (owner) | orgs: ZEA, Südlich | scopes: openid profile email zea:read zea:write` | 0 |
| 2.2 | Token expirado | `❌ Token expired. Run: zea thalamus auth login` | 1 |
| 2.3 | Sin token guardado | `❌ Not authenticated. Run: zea thalamus auth login` | 1 |

### `zea thalamus auth logout`

```bash
zea thalamus auth logout
```

| # | Expected Output | Exit |
|---|---|---|
| 3.1 | Token revocado, config local limpiado. `✅ Logged out successfully` | 0 |
| 3.2 | Sin token (ya estaba logged out). `⚠️ Not currently authenticated` | 0 |

### `zea thalamus auth debug <token>`

```bash
zea thalamus auth debug eyJhbGciOi...
```

Decodifica un JWT localmente + llama a `/oauth/introspect` para verificar estado.

| # | Caso | Expected Output | Exit |
|---|---|---|---|
| 4.1 | Token activo | Header, Payload (sub, email, scope, domain_roles[], exp), Signature. `active: true` del servidor | 0 |
| 4.2 | Token expirado | Payload decodificado. `active: false — token expired at 2025-07-20T10:00:00Z` | 0 |
| 4.3 | Token malformado | `❌ Not a valid JWT` | 1 |

---

## 2. Organizaciones

### `zea thalamus org list`

```bash
zea thalamus org list
```

| # | Expected Output | Exit |
|---|---|---|
| 5.1 | 2+ orgs: `* ZEA (zea) — owner — enterprise` + `  Südlich (sudlich) — admin — enterprise` | 0 |
| 5.2 | 0 orgs: `No organizations found. Create one: zea thalamus org create` | 0 |

### `zea thalamus org switch <slug>`

```bash
zea thalamus org switch sudlich
zea thalamus org switch          # interactivo: elige con flechas
```

| # | Caso | Expected Output | Exit |
|---|---|---|---|
| 6.1 | Slug válido | `✅ Active organization: Südlich (5fd11ea0-...)` | 0 |
| 6.2 | Slug no encontrado | `❌ Organization 'xyz' not found in your memberships. Run: zea thalamus org list` | 1 |

### `zea thalamus org create`

```bash
zea thalamus org create --name "Acme Corp" --email admin@acme.com --plan standard
zea thalamus org create          # interactivo
```

| # | Caso | Expected Output | Exit |
|---|---|---|---|
| 7.1 | Datos válidos | `✅ Organization 'Acme Corp' created! ID: abc-123 | Owner: admin@acme.com | Plan: standard` | 0 |
| 7.2 | Faltan parámetros | `❌ Missing required parameter: --email` | 1 |

### `zea thalamus org show <slug>`

```bash
zea thalamus org show sudlich
```

| # | Expected Output | Exit |
|---|---|---|
| 8.1 | Org existe: name, plan, status, verified, members count, domains, created_at | 0 |
| 8.2 | Org no encontrada: `❌ Organization not found` | 1 |

### `zea thalamus org member`

```bash
zea thalamus org member list <slug>
zea thalamus org member add <slug> --email user@example.com --role admin
zea thalamus org member remove <slug> --user-id abc-123
```

| # | Caso | Expected Output | Exit |
|---|---|---|---|
| 9.1 | `list` con 3+ miembros | Tabla: email, role, joined_at | 0 |
| 9.2 | `add` — usuario existe | `✅ user@example.com added as admin` | 0 |
| 9.3 | `add` — usuario no existe | `❌ User not found. They need to register first: zea user create` | 1 |
| 9.4 | `add` — ya es miembro | `❌ Already a member of this organization` | 1 |
| 9.5 | `remove` — miembro existe | `✅ Member removed` | 0 |

---

## 3. OAuth2 Clients

### `zea thalamus client`

```bash
zea thalamus client list [--org <slug>]
zea thalamus client show <id>
zea thalamus client create --name "My App" --type confidential --redirect-uris "https://example.com/callback" --grants "authorization_code,refresh_token" --scopes "openid,profile,email"
zea thalamus client update <id> --name "New Name"
zea thalamus client delete <id>
zea thalamus client rotate-secret <id>
zea thalamus client add-redirect-uri <id> --uri "https://new.example.com/callback"
zea thalamus client validate <id>
```

| # | Caso | Expected Output | Exit |
|---|---|---|---|
| 10.1 | `list` con 2+ clients | Tabla: name, client_id, type, redirect_uris, active | 0 |
| 10.2 | `create` confidential | `✅ Client created. ⚠️ CLIENT SECRET: cs_abc123... — SAVE THIS, it won't be shown again.` | 0 |
| 10.3 | `create` public | `✅ Client created. Public client — no client secret.` | 0 |
| 10.4 | `create` sin args | Wizard interactivo: name → type → redirect URIs → grants → scopes | 0 |
| 10.5 | `create` redirect URI inválida | `❌ Invalid redirect URI: 'invalid' — must be a valid https:// URL` | 1 |
| 10.6 | `rotate-secret` confidential | `✅ New secret: cs_xyz... (SAVE THIS — old secret is now invalid)` | 0 |
| 10.7 | `rotate-secret` public | `❌ Cannot rotate secret for public clients` | 1 |
| 10.8 | `validate` OK | `Overall: PASS ✅ | redirect_uris: ✅ | grant_types: ✅ | scopes: ✅` | 0 |
| 10.9 | `validate` FAIL | `Overall: FAIL (1 failure) | redirect_uris: ❌ No redirect URIs configured` | 0 |

---

## 4. Personal Access Tokens

```bash
zea thalamus token create --name "CLI local" [--scopes "openid,profile"]
zea thalamus token list
zea thalamus token revoke <id>
```

| # | Caso | Expected Output | Exit |
|---|---|---|---|
| 11.1 | `create` | `✅ Token: th_pat_abc123... — ⚠️ SAVE THIS, shown only once.` | 0 |
| 11.2 | `list` con 3+ tokens | Tabla: name, prefix (th_pat_...), scopes, active, last_used | 0 |
| 11.3 | `list` sin tokens | `No active tokens. Create one: zea thalamus token create` | 0 |
| 11.4 | `revoke` | `✅ Token revoked` | 0 |

---

## 5. Usuarios

```bash
zea thalamus user list [--status active|suspended] [--org <slug>] [--verified true|false]
zea thalamus user show <id>
zea thalamus user create --email "user@example.com" --password "..." [--name "User Name"]
zea thalamus user update <id> --status suspended|active|deactivated [--name "..."]
zea thalamus user delete <id>
zea thalamus user role list <user_id>
zea thalamus user role assign <user_id> --role-id <id>
zea thalamus user role revoke <user_id> --role-id <id>
zea thalamus user scopes <user_id>
```

| # | Caso | Expected Output | Exit |
|---|---|---|---|
| 12.1 | `list` con filtros | Tabla: email, name, status, verified, org | 0 |
| 12.2 | `create` válido | `✅ User created: user@example.com (abc-123)` | 0 |
| 12.3 | `create` email duplicado | `❌ Email already registered` | 1 |
| 12.4 | `update` suspend | `✅ User suspended` | 0 |
| 12.5 | `delete` con confirmación | `⚠️ This will deactivate the user. Continue? [y/N]` | 0 |
| 12.6 | `scopes` con roles | Lista plana de scopes efectivos (unión de todos los roles) | 0 |

---

## 6. Domain Roles (Microservicios)

```bash
zea thalamus domain list
zea thalamus domain register --domain "venture" --scopes '[{"scope":"venture:fund.read","description":"Ver fondos"},...]'
zea thalamus domain grant --user <id> --org <id> --domain "venture" --role "fund_manager" --scopes "venture:fund.*"
zea thalamus domain revoke --user <id> --org <id> --domain "venture" --role "fund_manager"
zea thalamus domain roles [--user <id>] [--org <id>] [--domain <domain>]
```

| # | Caso | Expected Output | Exit |
|---|---|---|---|
| 13.1 | `list` | Tabla: domain, scopes count, scopes[] | 0 |
| 13.2 | `register` | `✅ Domain 'venture' registered with 5 scopes` | 0 |
| 13.3 | `grant` | `✅ Role 'fund_manager' granted on domain 'venture'` | 0 |
| 13.4 | `grant` (ya existe) | `✅ Role updated (already existed — scopes updated)` | 0 |
| 13.5 | `revoke` | `✅ Role 'fund_manager' revoked from domain 'venture'` | 0 |

---

## 7. RBAC Roles

```bash
zea thalamus role list
zea thalamus role show <id>
zea thalamus role create --name "..." --scopes "..."
zea thalamus role update <id> --scopes "..."
zea thalamus role delete <id>
```

---

## 8. MFA

```bash
zea thalamus mfa setup
zea thalamus mfa verify --code 123456
zea thalamus mfa disable
zea thalamus mfa backup-codes
```

| # | Expected Output | Exit |
|---|---|---|
| 14.1 | `setup`: QR code ASCII + `Secret: JBSWY3DPEHPK3PXP` | 0 |
| 14.2 | `verify` OK: `✅ MFA enabled. Save these backup codes: ...` | 0 |
| 14.3 | `verify` fail: `❌ Invalid TOTP code. Try again.` | 1 |
| 14.4 | `disable`: `⚠️ This weakens account security. Continue? [y/N]` → `✅ MFA disabled` | 0 |
| 14.5 | `backup-codes`: 10 nuevos códigos, `SAVE THESE — previous codes invalidated` | 0 |

---

## 9. Secrets

```bash
zea thalamus secret list --owner-type user --owner-id <id>
zea thalamus secret create --name "deepseek" --provider "deepseek" --value "sk-abc123..."
zea thalamus secret delete <id>
zea thalamus secret resolve --provider "deepseek"
```

| # | Expected Output | Exit |
|---|---|---|
| 15.1 | `list`: tabla con name, provider (valores enmascarados `••••sk-`) | 0 |
| 15.2 | `resolve`: `✅ Resolved 'deepseek': sk-abc123...xyz` | 0 |
| 15.3 | `resolve` not found: `❌ No secret found for provider 'deepseek'` | 1 |

---

## 10. Auditoría

```bash
zea thalamus audit export [--from 2024-01-01] [--to 2024-12-31] [--event-type user_created] [--format csv|json] [--limit 1000]
```

| # | Caso | Expected Output | Exit |
|---|---|---|---|
| 16.1 | CSV a archivo | `✅ Exported 1432 events to audit_logs_2024.csv` | 0 |
| 16.2 | JSON en terminal | Pretty-print JSON con `total_records` y array `audit_logs` | 0 |
| 16.3 | Sin eventos | `No audit events found for the given filters` | 0 |
| 16.4 | Rango >1 año | `❌ Date range cannot exceed 1 year` | 1 |

---

## 11. Health & Discovery

```bash
zea thalamus health
zea thalamus oidc discovery
zea thalamus oidc jwks
zea thalamus doctor
```

| # | Caso | Expected Output | Exit |
|---|---|---|---|
| 17.1 | `health` OK | `✅ Thalamus v1.0.0 | DB: ok | Cache: ok` | 0 |
| 17.2 | `health` degraded | `⚠️ DEGRADED | DB: error — connection refused | Cache: ok` | 1 |
| 17.3 | `doctor` OK | Checklist: `✅ Auth reachable ✅ Token valid ✅ DB ✅ Cache ✅ Org accessible` | 0 |
| 17.4 | `doctor` token expired | `⚠️ Token expired — run zea auth login | ✅ Auth reachable ✅ DB ✅ Cache` | 1 |
| 17.5 | `oidc discovery` | JSON con `issuer, authorization_endpoint, token_endpoint, jwks_uri, scopes_supported` | 0 |

---

## 12. Admin API Keys (super_admin)

```bash
zea thalamus admin api-key list
zea thalamus admin api-key show <id>
zea thalamus admin api-key create --name "..." --scopes "..."
zea thalamus admin api-key revoke <id>
zea thalamus admin api-key rotate <id>
```

| # | Expected Output | Exit |
|---|---|---|
| 18.1 | `create`: `✅ API Key: zak_abc123... — SAVE THIS, shown only once` | 0 |
| 18.2 | `rotate`: `✅ New key: zak_xyz... (old key invalidated)` | 0 |
| 18.3 | Sin permisos: `❌ Forbidden — super_admin role required` | 1 |

---

## 13. Configuración

```bash
zea config set-env local|prod
zea config set <key> <value>
zea config get <key>
zea config list
zea config unset <key>
zea config path
```

| # | Caso | Expected Output | Exit |
|---|---|---|---|
| 19.1 | `set-env local` | Configura 8 servicios a `.localhost` | 0 |
| 19.2 | `set-env prod` | Configura a `.zea.cl` | 0 |
| 19.3 | `list` | Muestra todas las keys (token enmascarado `••••xyz1`) | 0 |

---

## 14. Setup Wizard

```bash
zea setup
zea setup --url http://auth.zea.localhost
```

| # | Flujo | Exit |
|---|---|---|
| 20.1 | ① URL de Thalamus → ② Login → ③ Elegir org default → `✅ ZEA CLI ready!` | 0 |
| 20.2 | Con `--url`: saltea prompt de URL | 0 |

---

## Flags globales

Cada comando hereda del root `zea`:

| Flag | Tipo | Default | Inspirado por | Descripción |
|---|---|---|---|---|
| `--output` | `json\|table\|text` | `table` | AWS/Azure/GCloud | Formato de salida |
| `--org` | `string` | Org activa | Propio (multi-tenant) | ID o slug de organización para este comando |
| `--profile` | `string` | `default` | AWS (`--profile`) | Perfil de configuración (v2) |
| `--dry-run` | `boolean` | `false` | AWS/Azure | Validar sin ejecutar |
| `--quiet` | `boolean` | `false` | gcloud (`--quiet`) | Suprimir output no esencial |
| `--no-color` | `boolean` | `false` | Estándar | Desactivar colores ANSI |
| `--debug` | `boolean` | `false` | Estándar | Mostrar request/response HTTP |

### Jerarquía de contexto

El `--org` flag sigue esta prioridad (mayor a menor):

1. `--org <id>` explícito en el comando
2. `ZEA_ORG_ID` environment variable
3. `zea thalamus org switch <slug>` (guardado en `~/.config/zea/config.json`)
4. Primera org del `/oauth/userinfo` (seteada en `zea thalamus auth login`)

### Ejemplos con flags globales

```bash
# JSON para scripting
zea thalamus org list --output json | jq '.[].name'

# Dry-run: validar sin crear
zea thalamus client create --name "test" --dry-run
# → [DRY RUN] Would POST to /api/clients with body: { "name": "test", ... }

# Debug mode: ver request/response HTTP
zea thalamus user list --debug
# → [DEBUG] GET http://auth.zea.localhost/api/users
# → [DEBUG] ← 200 OK (45ms)

# Operar en org específica sin switchear contexto
zea thalamus user list --org sudlich

# Modo script: solo JSON, sin colores, sin prompts
zea thalamus token create --name "CI" --output json --quiet --no-color
```

---

## Roadmap de implementación

### P0 — Crítico (CLI actual rota o inusable sin esto)

| # | Comando | Por qué | Depende de |
|---|---|---|---|
| 1 | `zea thalamus auth login --email/--password` | Fix: `handleDirectLogin` no matchea el formato real de respuesta de Thalamus | Thalamus `/api/public/login` |
| 2 | `zea thalamus auth whoami` | Nuevo: saber quién soy sin leer config.json a mano | Thalamus `/oauth/userinfo` |
| 3 | `zea thalamus health` | Nuevo: primer comando que ejecuta un developer nuevo | Thalamus `/api/public/health` |
| 4 | `zea thalamus doctor` | Nuevo: diagnóstico completo (auth + token + DB + org) | Varios endpoints |
| 5 | `--output json\|table` | Global: sin esto, scripting es frágil (regex contra output coloreado) | Solo local |
| 6 | `--debug` | Global: sin esto, debuggear integración requiere Wireshark | Solo local |

### P1 — Integración de microservicios

| # | Comando | Quién lo necesita |
|---|---|---|
| 7 | `zea thalamus client create/list/validate` | Todo microservicio nuevo (fm_funds, fm_investors, etc.) |
| 8 | `zea thalamus domain register/grant/roles` | Microservicios que validan JWT con domain_roles |
| 9 | `zea thalamus token create/list` | CI/CD, desarrollo local |
| 10 | `zea thalamus auth debug <token>` | Debuggear por qué un servicio recibe 401 |
| 11 | `--dry-run` | Seguridad en create/delete |

### P2 — Gestión completa

| # | Comando |
|---|---|
| 12 | `zea thalamus user create/list/update/delete` |
| 13 | `zea thalamus org member add/remove/list` |
| 14 | `zea thalamus role create/list/update/delete` |
| 15 | `zea thalamus mfa setup/verify/disable` |
| 16 | `zea thalamus secret create/list/resolve` |
| 17 | `zea thalamus user role assign/revoke/scopes` |
| 18 | `--query` (JMESPath) |

### P3 — Admin y Compliance

| # | Comando |
|---|---|
| 19 | `zea thalamus admin api-key create/list/revoke/rotate` |
| 20 | `zea thalamus audit export` |
| 21 | `zea thalamus org saml show/update` |
| 22 | `zea setup` wizard |
| 23 | `zea profile` (multi-profile) |

---

## Flujos de integración típicos

### Integrar un nuevo microservicio (fm_funds, fm_investors, etc.)

```bash
# 1. Verificar que Thalamus está vivo
zea thalamus health

# 2. Autenticarse
zea thalamus auth login

# 3. Registrar el domain y sus scopes
zea thalamus domain register --domain "fund_management" --scopes '[
  {"scope":"fund_management:fund.read","description":"Ver fondos"},
  {"scope":"fund_management:fund.write","description":"Crear/editar fondos"},
  {"scope":"fund_management:capital_call.read","description":"Ver llamados de capital"},
  {"scope":"fund_management:capital_call.write","description":"Crear/ejecutar llamados"}
]'

# 4. Crear un OAuth2 client para el servicio (M2M)
zea thalamus client create \
  --name "fm_funds Service" \
  --type confidential \
  --grants "client_credentials" \
  --scopes "fund_management:fund.read,fund_management:fund.write"

# 5. Validar la configuración del client
zea thalamus client validate <client_id>

# 6. Grant domain roles a los usuarios
zea thalamus domain grant \
  --user c0000000-852c-44e5-aee1-a761ec76eaea \
  --org ea7b11ea-852c-44e5-aee1-a761ec76eaea \
  --domain "fund_management" \
  --role "gp_admin" \
  --scopes "fund_management:fund.*,fund_management:capital_call.*"

# 7. Verificar que el usuario tiene los scopes
zea thalamus user scopes c0000000-852c-44e5-aee1-a761ec76eaea
```

### Setup de CI/CD

```bash
# Non-interactive: usar PAT
zea auth login --email ci-bot@zea.cl --password "$ZEA_CI_PASSWORD"
zea thalamus token create --name "GitHub Actions" --scopes "openid,profile,clients:write"
# Guardar th_pat_... como ZEA_PAT en secrets del CI
```

### Diagnóstico de integración

```bash
# Diagnóstico completo
zea thalamus doctor

# Debug de token (ver qué domain_roles tiene)
zea thalamus auth debug $(zea config get token)

# Validar un OAuth2 client antes de usarlo
zea thalamus client validate <client_id>

# Ver health de Thalamus
zea thalamus health
```
