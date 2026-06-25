# Requirements Document — Auto CORS/CSP al Registrar Cliente

## Introducción

Cuando un developer registra un OAuth2 client con `redirect_uris`, Thalamus debe extraer automáticamente los orígenes y dominios de esas URIs y registrarlos en CORS y CSP. El developer nunca debe escuchar las palabras "CORS" ni "CSP".

### Value Proposition
Un developer registra su cliente con un redirect URI y queda todo listo. Cero pasos extra, cero llamadas al equipo de Thalamus.

---

## Requirements

### Requirement 1: Auto-CORS al crear cliente

**User Story:** As a developer, when I create an OAuth2 client with redirect URIs, CORS origins should be automatically registered so that my browser-based token requests work without manual configuration.

#### Acceptance Criteria

1. WHEN a client is created via `POST /api/clients` with `redirect_uris` THEN the system SHALL extract the origin (scheme + host) from each redirect URI.

2. WHEN origins are extracted THEN the system SHALL register each unique origin in the CORS configuration so that `GET /api/clients/:id/validate` reports `cors_origins` as PASS.

3. IF the origin is already registered THEN the system SHALL NOT duplicate it.

4. WHEN CORS registration succeeds THEN the client creation SHALL still return 201 with the client data (CORS update is transparent).

5. IF CORS registration fails THEN the system SHALL log a warning but SHALL NOT fail the client creation (best-effort).

### Requirement 2: Auto-CORS al agregar redirect URI

**User Story:** As a developer, when I add a redirect URI to an existing client, the CORS origin should be automatically registered so that I don't need to ask the Thalamus team.

#### Acceptance Criteria

1. WHEN a redirect URI is added via `POST /api/clients/:id/add-redirect-uri` THEN the system SHALL extract the origin and register it in CORS.

2. WHEN the origin is already registered THEN the system SHALL return 200 with "Redirect URI added successfully" (no-op for CORS).

### Requirement 3: Auto-CSP al crear cliente

**User Story:** As a developer, when I create an OAuth2 client, the CSP form-action should be automatically updated so that the authorize form is not blocked by the browser.

#### Acceptance Criteria

1. WHEN a client is created with redirect URIs THEN the system SHALL extract the host from each redirect URI origin.

2. WHEN hosts are extracted THEN the system SHALL register each unique host in the CSP form-action directive.

3. IF a host is already covered by an existing wildcard (e.g., `*.zea.localhost:*`) THEN the system SHALL NOT add a redundant entry.

4. WHEN CSP update succeeds THEN it SHALL be transparent to the client creation response.

### Requirement 4: In-Memory Runtime Registry

**User Story:** As a system, CORS and CSP changes must apply immediately without requiring a Thalamus restart or Docker rebuild.

#### Acceptance Criteria

1. WHEN CORS origins are updated THEN the CORS plug SHALL reflect changes on the next HTTP request without restart.

2. WHEN CSP form-action is updated THEN the SecurityHeaders plug SHALL reflect changes on the next HTTP request without restart.

3. WHERE the CORS/CSP configuration was set via environment variables (docker-compose) THEN runtime additions SHALL be merged with the static config.

4. IF Thalamus restarts THEN runtime CORS/CSP additions SHALL be re-applied from the database (clients table) on startup.

---

## Edge Cases

| Edge Case | Expected Behavior |
|-----------|-------------------|
| Client has no redirect URIs (backend) | No CORS/CSP additions |
| Client has 20 redirect URIs | Only unique origins added, no duplicates |
| Origin already in CORS from env var | Skip, no duplicate |
| Host already covered by `*.zea.localhost:*` wildcard | Skip, no redundant CSP entry |
| CORS env var is empty | Origins are still added to in-memory registry |
| Thalamus restarts | CORS/CSP reloaded from all active clients on boot |

## Non-Functional Requirements

- **Performance:** Origin extraction and registration SHALL complete in under 10ms
- **Transparency:** CORS/CSP updates SHALL NOT be visible in the client creation response
- **Idempotency:** Adding the same redirect URI twice SHALL NOT duplicate CORS/CSP entries
