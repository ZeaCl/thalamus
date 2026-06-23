# Requirements Document — OAuth2 Client Validation Endpoint

## Introduction

This document specifies a diagnostic endpoint that allows developers to validate the configuration of their OAuth2 clients registered in Thalamus. The endpoint runs automated checks on client coherence, CORS, CSP, redirect URIs, and endpoint health, returning a structured report of what passes, what fails, and what needs attention.

### Purpose
Provide a self-service validation API that eliminates the need for Thalamus administrators to manually verify OAuth2 client configurations during integration.

### Scope
- New REST endpoint `GET /api/clients/:id/validate`
- Ownership verification: only organization members can validate their own clients
- Automated checks covering: client config coherence, redirect URIs, CORS origins, CSP form-action, JWKS/token/authorize endpoint health
- Structured JSON response with PASS/FAIL/WARN status per check
- Support for authentication via JWT, Personal Access Token (PAT), and API Key

### Value Proposition
A developer integrating a service with Thalamus OAuth2 can, in a single API call (or via their AI coding agent), get a complete diagnostic report showing exactly what needs to be fixed — no back-and-forth with the Thalamus team.

---

## Requirements

### Requirement 1: Client Validation Endpoint

**User Story:** As a developer integrating with Thalamus, I want to validate my OAuth2 client configuration via API so that I know exactly what needs to be fixed without asking the Thalamus team.

#### Acceptance Criteria

1. WHEN a developer sends `GET /api/clients/:id/validate` with a valid Bearer token THEN the system SHALL return a JSON response containing a list of validation checks, each with a check name, status (pass/fail/warn), and an optional detail message.

2. IF the `:id` parameter does not correspond to an existing OAuth2 client THEN the system SHALL return HTTP 404 with `{"error": "Client not found"}`.

3. IF the `:id` parameter is not a valid UUID format THEN the system SHALL return HTTP 400 with `{"error": "Invalid client ID format"}`.

4. WHEN the validation completes successfully THEN the response SHALL include a top-level `status` field with value `"valid"`, `"invalid"`, or `"warning"` based on whether all checks passed, any failed, or only warnings exist.

5. WHEN the validation completes THEN the response SHALL include a `summary` object with integer counts of `pass`, `fail`, and `warn` checks.

### Requirement 2: Authorization — Ownership Verification

**User Story:** As a Thalamus administrator, I want only authorized users to validate their own organization's clients so that client configuration details are not exposed to outsiders.

#### Acceptance Criteria

1. WHEN the request includes a valid PAT (`th_pat_` prefix) THEN the system SHALL extract the user's organization memberships from the token and only allow validation of clients belonging to those organizations.

2. IF the authenticated user is not a member of the client's organization THEN the system SHALL return HTTP 403 with `{"error": "Forbidden", "detail": "You do not have access to this client's organization"}`.

3. WHEN the request includes a valid JWT THEN the system SHALL extract current_user_id and verify organization membership against the client's organization.

4. WHEN the request includes a valid API Key THEN the system SHALL allow validation of any client regardless of organization (admin/super_admin override).

5. IF no valid Authorization header is present THEN the system SHALL return HTTP 401 with `{"error": "Unauthorized"}`.

### Requirement 3: Client Configuration Coherence Checks

**User Story:** As a developer, I want the validator to detect misconfigurations in my client (like wrong client_type/auth_method combination) so that I fix them before they cause runtime errors.

#### Acceptance Criteria

1. WHEN the client exists and is active THEN the system SHALL report `"client_active"` as PASS; IF the client is inactive THEN the system SHALL report it as FAIL with detail "Client is deactivated".

2. WHEN the client type is `public` THEN the system SHALL verify `token_endpoint_auth_method` is `"none"` and report FAIL with detail if it is not.

3. WHEN the client type is `public` THEN the system SHALL verify `pkce_required` is `true` and report WARN with detail "PKCE is recommended for SPAs" if it is not.

4. WHEN the client type is `public` THEN the system SHALL verify `authorization_code` is in `allowed_grant_types` and report FAIL if it is not present.

5. WHEN the client type is `public` THEN the system SHALL verify at least one `redirect_uri` is registered and report FAIL if none exist.

6. WHEN the client type is `confidential` THEN the system SHALL verify `token_endpoint_auth_method` is `"client_secret_post"` and report WARN if it differs.

7. WHEN the client type is `confidential` THEN the system SHALL verify `client_credentials` is in `allowed_grant_types` and report WARN if it is not present.

8. WHEN the client has no scopes or `"openid"` is missing from `allowed_scopes` THEN the system SHALL report FAIL for `"has_openid_scope"` with detail "openid scope is required for OIDC".

9. WHEN the client has no `organization_id` THEN the system SHALL report FAIL with detail "Client must belong to an organization".

### Requirement 4: Redirect URI Validation

**User Story:** As a developer, I want to know if my registered redirect URIs match what my application is requesting so that the OAuth2 redirect flow does not fail with `invalid_redirect_uri`.

#### Acceptance Criteria

1. WHEN the client has redirect URIs THEN the system SHALL validate each URI has a valid `http://` or `https://` scheme and report FAIL for each malformed URI.

2. WHEN the client type is `public` and has zero redirect URIs THEN the system SHALL report FAIL with detail "SPA clients require at least one redirect URI".

3. WHEN the client type is `confidential` and has zero redirect URIs THEN the system SHALL report PASS (backends using client_credentials do not need redirect URIs).

### Requirement 5: CORS Origin Validation

**User Story:** As a developer, I want to know if my application's origin is in Thalamus's CORS configuration so that browser-based token requests do not get blocked by CORS.

#### Acceptance Criteria

1. WHEN the client has redirect URIs THEN the system SHALL extract the origin (scheme + host) from each unique redirect URI.

2. WHEN the system reads `CORS_ORIGINS` from the Thalamus runtime environment THEN it SHALL check each redirect URI origin against the configured CORS origins.

3. IF a redirect URI origin is not found in `CORS_ORIGINS` THEN the system SHALL report FAIL for `"cors_origins"` with detail specifying which origin is missing and the instruction "Add to CORS_ORIGINS in docker-compose.yml".

4. IF all redirect URI origins are covered by `CORS_ORIGINS` THEN the system SHALL report PASS for `"cors_origins"`.

5. WHEN `CORS_ORIGINS` is not configured THEN the system SHALL report WARN with detail "CORS_ORIGINS is not set — CORS check skipped".

### Requirement 6: CSP Form-Action Validation

**User Story:** As a developer, I want to know if my redirect URI domains are covered by Thalamus's Content-Security-Policy form-action directive so that the authorize form does not get silently blocked by the browser.

#### Acceptance Criteria

1. WHEN the CSP header is present on `/oauth/authorize` THEN the system SHALL extract the `form-action` directive value.

2. WHEN a redirect URI's host is covered by an exact entry or a wildcard entry (e.g., `*.zea.localhost:*` covering `app.zea.localhost`) in `form-action` THEN the system SHALL report PASS.

3. IF a redirect URI's host is not covered by `form-action` THEN the system SHALL report WARN with detail specifying which domain is missing and the instruction "Add to form-action in config/config.exs and security_headers.ex".

4. WHEN `form-action` includes `'self'` THEN the system SHALL report PASS for the Thalamus host itself.

5. WHEN the CSP header is absent THEN the system SHALL report FAIL for `"csp_header"` with detail "CSP header not found — security headers may not be configured".

### Requirement 7: Endpoint Health Checks

**User Story:** As a developer, I want to verify that Thalamus OAuth2 endpoints are reachable so that I know infrastructure issues are not causing my integration failures.

#### Acceptance Criteria

1. WHEN the validator runs THEN the system SHALL perform an internal HTTP request to `/.well-known/jwks.json` and report `"jwks_endpoint"` as PASS if the response is HTTP 200, FAIL otherwise.

2. WHEN the validator runs THEN the system SHALL perform an internal HTTP request to `/oauth/authorize` and report `"authorize_endpoint"` as PASS if the response is HTTP 302 or 400 (endpoint is live), FAIL otherwise.

3. WHEN the validator runs THEN the system SHALL perform an internal HTTP request to `POST /oauth/token` and report `"token_endpoint"` as PASS if the response is HTTP 400 (endpoint is live without params), FAIL otherwise.

### Requirement 8: Response Format

**User Story:** As a developer using the response programmatically, I want the JSON to be predictable and stable so that I can parse it reliably in scripts and CI pipelines.

#### Acceptance Criteria

1. WHEN validation completes THEN the response SHALL have the following top-level structure: `client_id`, `client_name`, `organization_id`, `validated_at` (ISO 8601), `status`, `summary` (with `pass`, `fail`, `warn` counts), and `checks` (array of check objects).

2. WHEN a check passes THEN the check object SHALL contain `check` (string), `status` ("pass"), and no `detail` field.

3. WHEN a check fails or warns THEN the check object SHALL contain `check`, `status` ("fail" or "warn"), and `detail` (human-readable explanation with fix instruction).

4. WHEN all checks pass THEN `status` SHALL be `"valid"`; IF any check fails THEN `status` SHALL be `"invalid"`; IF only warnings exist THEN `status` SHALL be `"warning"`.

---

## Non-Functional Requirements

- **Performance:** Validation SHALL complete in under 2 seconds under normal conditions
- **Idempotency:** Repeated calls with the same client ID SHALL return consistent results (no side effects on the client)
- **Immutability:** The validation endpoint SHALL NOT modify any client configuration
- **Availability:** The endpoint SHALL be available when Thalamus is running normally (no external dependencies beyond Thalamus itself)
- **Security:** Client secret SHALL NEVER appear in the validation response under any circumstance
- **Compatibility:** The endpoint SHALL work with the existing `:api_auth` pipeline (JWT, PAT, API Key)

---

## Edge Cases

| Edge Case | Expected Behavior |
|-----------|-------------------|
| Client has 50+ redirect URIs | All URIs are validated; CORS/CSP checks process unique origins only |
| Client has mixed http/https redirect URIs | Both schemes are validated independently |
| CORS_ORIGINS env var is empty or not set | CORS check reports WARN, not FAIL |
| CSP header missing from authorize response | CSP check reports FAIL, not crash |
| Thalamus internal endpoints unreachable | Endpoint health checks report FAIL individually; other checks still run |
| Client is deleted between existence check and validation | Appropriate 404 response |
| User is authenticated but belongs to 0 organizations | Organization check returns 403 |
| Client has no allowed_scopes | `has_openid_scope` reports FAIL |
| Client has duplicate redirect URIs | Deduplicated before CORS/CSP checks |
| Client is of type `m2m` (machine-to-machine) | Treated as confidential backend client |
| Request from agent using PAT with expired token | Returns 401 Unauthorized |
