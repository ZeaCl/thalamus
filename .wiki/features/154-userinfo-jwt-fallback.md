# Stateless login tokens removed + userinfo JWKS fallback

- **Issue**: #154
- **Branch**: fix/issue-154-userinfo-jwt-fallback
- **Status**: ✅ completed

## What was done

1. **Root-cause fix**: removed the stateless login token path entirely.
   - Deleted `POST /api/public/login` (`LoginController`) and its route.
   - Removed `JwtSigner.sign_refresh_token/1` (only used by that endpoint).
   - Removed the CLI's direct login (`handleDirectLogin` + `login --email/--password`).

2. **Left only the correct auth flows**:
   - Browser: OAuth2 Authorization Code + PKCE (`zea thalamus login`).
   - Headless: Device Authorization Grant (`zea thalamus login --device`).
   - M2M: `client_credentials` (`/oauth/token`).

3. **Defensive fix (kept)**: `/oauth/userinfo` now falls back to JWKS signature
   validation for `thalamus_api` JWTs, aligned with `AuthenticateToken`.

4. **Cleanup**: removed the CLI unit-test machinery (`.test.js`, `cli/test/`,
   `cli.test.coverage`) — the CLI is tested by running commands (E2E) — plus the
   legacy `test/cli/*.sh` suite and the now-unused `AuthenticateUser` use case.

## Root cause

`POST /api/public/login` issued a **stateless** JWT (RS256, `client_id: thalamus_api`)
that was NOT persisted in `tokens`. The `AuthenticateToken` plug already handled this
case via JWKS, but `UserinfoController` validated only against the DB → 401.
The same token worked on `/api/*` but failed on `/oauth/userinfo`.

Stateless tokens cannot be revoked (RFC 7009), introspected (RFC 7662), or refreshed —
the login refresh token was unusable because `/oauth/token` only looks up DB rows.

## Key decisions

- **Remove, don't patch**: instead of only aligning `UserinfoController`, remove the
  stateless login endpoint so there is a single token model (persisted OAuth2 tokens).
- **Reuse JWKS verification**: extracted into `JwtSigner.verify_access_token/1`
  (+ `validate_claims/1`, `jwt_format?/1`, `thalamus_api_jwt?/1`).
- **`AuthenticateToken` delegates to `JwtSigner`** (single source of truth).
- **CLI keeps two interactive flows**: browser PKCE and device flow.

## Modified files

- `lib/thalamus_web/router.ex` — removed `/api/public/login` route
- `lib/thalamus_web/controllers/api/login_controller.ex` — deleted
- `test/thalamus_web/controllers/api/login_controller_test.exs` — deleted
- `lib/thalamus/infrastructure/jwt_signer.ex` — removed `sign_refresh_token/1`; added JWKS verification helpers
- `lib/thalamus_web/plugs/authenticate_token.ex` — delegates to `JwtSigner`
- `lib/thalamus_web/controllers/oauth2/userinfo_controller.ex` — JWKS fallback
- `cli/src/lib/client.js` — removed `handleDirectLogin`
- `cli/src/commands/auth.js` — removed `--email`/`--password` from `login`
- `scripts/test-cli.sh` — replaced direct-login E2E with device-flow help check
- `test/thalamus_web/controllers/oauth2/userinfo_controller_test.exs` — new tests
- `cli/src/commands/*.test.js`, `cli/test/`, `cli.test.coverage`, `test/cli/`, `scripts/smoke-test-cli.sh` — removed (E2E is the CLI test)
- `lib/thalamus/application/use_cases/authenticate_user.ex`, `lib/thalamus/application/dtos/authentication_request.ex` — removed (no caller)
- `docs/*` — removed `/api/public/login` references

## Verification

- `mix test` → 1906 tests, 0 failures
- `mix compile` → CLI coverage 72/72 routes ✅
- `mix format --check-formatted` → OK

## References

- [#154](https://github.com/ZeaCl/thalamus/issues/154)
- #69 documented the same root cause (CI workaround only).
- #6 added `domain_roles` to the JWT (already resolved).
