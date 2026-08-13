# /oauth/userinfo returns 401 for stateless login JWTs

- **Issue**: #154
- **Branch**: fix/issue-154-userinfo-jwt-fallback
- **Status**: ✅ completed (tests passing locally)

## What was done

Aligned `UserinfoController` with `AuthenticateToken`: `/oauth/userinfo` now accepts
the stateless JWTs issued by `POST /api/public/login` (`thalamus_api` client),
validating the signature via JWKS when the token is not in the `tokens` table.

## Root cause

`POST /api/public/login` issues a **stateless** JWT (RS256, `client_id: thalamus_api`)
that is NOT persisted in `tokens`. The `AuthenticateToken` plug (`/api/*` pipeline)
already handled this case with a JWKS fallback, but `UserinfoController` validated only
via `ValidateToken.execute` → `PostgreSQLTokenRepository.find/1` → `token not found in DB` → 401.

Result: the same token worked on `/api/organizations` but failed on `/oauth/userinfo`.

## Key decisions

- **Reuse JWKS verification**: extracted the logic into `JwtSigner.verify_access_token/1`,
  `validate_claims/1`, `jwt_format?/1` and `thalamus_api_jwt?/1` to avoid duplication.
- **`AuthenticateToken` delegates to `JwtSigner`** (single source of truth), keeping its
  public functions (`jwt_format?`, `thalamus_api_jwt?`, `validate_jwt_claims`) for
  compatibility with existing tests.
- **Fallback in `UserinfoController`**: when `ValidateToken` returns `valid: false` and the
  token is a `thalamus_api` JWT with a valid signature and unexpired `exp`, use `sub`
  (normalized without the `user_` prefix) as `user_id` and continue the normal flow.

## Modified files

- `lib/thalamus/infrastructure/jwt_signer.ex` — `verify_access_token/1`, `validate_claims/1`, `jwt_format?/1`, `thalamus_api_jwt?/1` + private helpers
- `lib/thalamus_web/plugs/authenticate_token.ex` — delegates to `JwtSigner`, removes duplication
- `lib/thalamus_web/controllers/oauth2/userinfo_controller.ex` — JWKS fallback in `resolve_user_id/1`
- `test/thalamus_web/controllers/oauth2/userinfo_controller_test.exs` — new tests

## Errors found

- Credo: single-condition `cond` in `validate_claims` → replaced with `if`.
- Credo: nesting in `resolve_stateless_jwt_user_id` → refactored with `with`.
- Credo: misordered aliases + nested module `Thalamus.Application.UseCases.ValidateToken` → ordered aliases + `ValidateToken` alias.

## Verification

- `mix test` → 1916 tests, 0 failures (17 pre-existing skips).
- `test/thalamus_web/controllers/oauth2/userinfo_controller_test.exs` → 5 new tests.

## References

- [#154](https://github.com/ZeaCl/thalamus/issues/154)
- #69 documented the same root cause but only applied a CI workaround (use a PAT instead of the login JWT).
- #6 added `domain_roles` to the JWT (already resolved).
