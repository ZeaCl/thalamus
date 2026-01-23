# Test Failures Categorization - 142 Tests

## Summary

**Total Tests**: 1,684
**Passing**: 1,542 (91.6%)
**Failing**: 142 (8.4%)
**Excluded**: 16 (implementation gaps)

**Session Progress**:
- Fixed: 9 tests (1 PasswordHashTest + 8 OAuth2ClientTest)
- Fixed: 1 entity bug (OAuth2Client scope/URI handling)
- Improvement: 151 → 142 failures (9 tests fixed)

---

## Categorization by Error Type and Priority

### 🔴 HIGH PRIORITY (Quick Fixes - 26 tests, ~40 min effort)

#### Category 1: Phoenix.Param Protocol Missing (~10-15 tests)
**Error**: `structs expect an :id key when converting to_param`

**Affected Value Objects**:
- `UserId`
- `ClientId`
- `OrganizationId`

**Root Cause**: Phoenix uses ~p sigils for URL generation (`~p"/users/#{user_id}"`). When user_id is a value object, Phoenix can't convert it to a string parameter.

**Solution**: Implement `Phoenix.Param` protocol for each value object:
```elixir
defimpl Phoenix.Param, for: Thalamus.Domain.ValueObjects.UserId do
  def to_param(%{value: value}), do: value
end
```

**Effort**: 15 minutes (3 implementations × 5 min each)

**Affected Tests**:
- LiveView tests using route helpers with value objects
- Controller tests with resource routes

---

#### Category 2: Missing generate!/0 Functions (~5 tests)
**Error**: `function Thalamus.Domain.ValueObjects.UserId.generate!/0 is undefined`

**Affected**:
- `UserId.generate!/0`
- `OrganizationId.generate!/0`

**Root Cause**: Tests use `generate!()` bang version, but value objects only have `generate()` that returns `{:ok, value}`.

**Solution**: Either:
1. Add bang versions to value objects:
   ```elixir
   def generate! do
     {:ok, id} = generate()
     id
   end
   ```
2. OR update tests to use `{:ok, id} = ValueObject.generate()` pattern

**Effort**: 10 minutes

**Affected Tests**:
- Domain tests
- Repository tests

---

#### Category 3: Email.to_string/1 FunctionClauseError (~3 tests)
**Error**: `no function clause matching in Thalamus.Domain.ValueObjects.Email.to_string/1`

**Root Cause**: Email value object's `to_string/1` function missing a pattern match.

**Solution**: Check Email implementation and add missing pattern.

**Effort**: 5 minutes

**Affected Tests**:
- Tests using Email value objects in string interpolation

---

#### Category 4: User Entity Missing :mfa_enabled Field (~3 tests)
**Error**: `key :mfa_enabled not found in: %Thalamus.Domain.Entities.User{}`

**Root Cause**: Tests expect `:mfa_enabled` field but User entity doesn't have it.

**Solution**: Either:
1. Add `:mfa_enabled` field to User entity
2. OR update tests to use correct field name (`:mfa_status`?)

**Effort**: 10 minutes

**Affected Tests**:
- MFAControllerTest (likely)
- User domain tests

---

### 🟡 MEDIUM PRIORITY (22 tests, ~1 hour effort)

#### Category 5: Session Handling (~14 tests)
**Error**: `session not fetched, call fetch_session/2`

**Module**: `ThalamusWeb.OAuth2.AuthorizationControllerTest` (14 failures)

**Root Cause**: Tests use `put_session/2` without first calling `fetch_session/2` or `init_test_session/1`.

**Solution**: Add session initialization in test setup or before put_session:
```elixir
conn
|> Plug.Test.init_test_session(%{})
|> put_session(:user_id, user_id)
```

**Effort**: 20 minutes

**Affected Tests**:
- OAuth2 AuthorizationControllerTest (all tests with user authentication)

---

#### Category 6: OAuth2Client.new/5 Old API (~3 tests)
**Error**: `function Thalamus.Domain.Entities.OAuth2Client.new/5 is undefined`

**Root Cause**: Tests using old constructor API `OAuth2Client.new(name, org_id, ...)`.

**Solution**: Migrate to new API: `OAuth2Client.new(%{id:, organization_id:, name:, ...})`

**Effort**: 5 minutes

**Affected Tests**:
- OAuth2ClientControllerTest
- Integration tests

---

#### Category 7: Organization.add_member/4 Undefined (~1 test)
**Error**: `function Thalamus.Domain.Entities.Organization.add_member/4 is undefined`

**Root Cause**: Function doesn't exist in Organization entity.

**Solution**: Either:
1. Implement `add_member/4` function
2. OR update test to use correct API

**Effort**: Varies (10 min if just fixing test, 30+ min if implementing feature)

---

#### Category 8: DateTime Microseconds Precision (~2 tests)
**Error**: `:utc_datetime expects microseconds to be empty, got: ~U[2026-01-19 12:49:07.070295Z]`

**Root Cause**: Database column type `:utc_datetime` doesn't store microseconds, but Elixir DateTime includes them.

**Solution**: Either:
1. Change migration to use `:utc_datetime_usec` column type
2. OR truncate microseconds before saving: `DateTime.truncate(datetime, :second)`

**Effort**: 15 minutes

**Affected Tests**:
- Repository tests with datetime fields

---

### 🟢 LOW PRIORITY (94 tests, ~2-3 hours effort)

#### Category 9: Assertion Mismatches (~40 tests)
**Types**:
- HTTP status mismatches (expected 200, got 400/404/500)
- Response body mismatches
- LiveView elements not found
- Invalid scope errors

**Examples**:
- Expected: 200, Got: 400 with `{"error":"invalid_scope"}`
- Expected: 400, Got: 404
- Expected button not found in LiveView

**Root Cause**: Various - implementation changes, API changes, validation issues.

**Solution**: Case-by-case analysis and fixes.

**Effort**: 1-2 hours

**Affected Tests**:
- OrganizationControllerTest (12 failures)
- OAuth2ClientControllerTest (10 failures)
- MFAControllerTest (9 failures)
- RegistrationControllerTest (8 failures)
- Clients.IndexTest (7 failures)
- UserControllerTest (5 failures)
- PasswordControllerTest (4 failures)

---

#### Category 10: Integration Test Issues (~5 tests)
**Module**: `Thalamus.Integration.OAuth2FlowTest`

**Issues**:
- Session handling (covered in Category 5)
- Scope validation mismatches
- Grant type validation

**Effort**: 30 minutes

---

#### Category 11: Repository Tests (~16 tests)
**Modules**:
- PostgreSQLAgentTokenRepositoryTest (12 failures)
- PostgreSQLTokenRepositoryTest (4 failures)

**Issues**: Various - likely datetime precision, value object handling, query issues.

**Effort**: 45 minutes

---

## Fix Strategy (Recommended Order)

### Phase 1: Quick Wins (26 tests, ~40 min) ⚡
1. ✅ Implement Phoenix.Param protocol (15 min) → ~10-15 tests fixed
2. ✅ Add generate!/0 functions (10 min) → ~5 tests fixed
3. ✅ Fix Email.to_string/1 (5 min) → ~3 tests fixed
4. ✅ Fix User :mfa_enabled field (10 min) → ~3 tests fixed

**Result**: 116 failures remaining

---

### Phase 2: Session Handling (14 tests, ~20 min) 🔧
1. Fix AuthorizationControllerTest session initialization

**Result**: 102 failures remaining

---

### Phase 3: Quick API Fixes (8 tests, ~20 min) 🔧
1. Migrate OAuth2Client.new/5 calls (5 min) → ~3 tests
2. Fix datetime precision (15 min) → ~2 tests
3. Fix/implement Organization.add_member (varies) → ~1 test

**Result**: ~94 failures remaining

---

### Phase 4: Assertion Analysis (optional, ~2-3 hours) 📊
1. Categorize remaining failures by type
2. Fix in batches by similarity
3. Target: 93-95% test success rate

**Target Result**: ~50-70 failures remaining

---

## Estimated Impact

| Phase | Effort | Tests Fixed | Success Rate |
|-------|--------|-------------|--------------|
| Current | - | - | 91.6% |
| Phase 1 | 40 min | 26 tests | 93.1% |
| Phase 2 | 20 min | 14 tests | 93.9% |
| Phase 3 | 20 min | 8 tests | 94.4% |
| Phase 4 | 2-3 hrs | 40+ tests | 96-97% |

---

## Test Modules Summary (Failures by Module)

| Module | Failures | Category |
|--------|----------|----------|
| OAuth2.AuthorizationControllerTest | 14 | Session handling |
| API.OrganizationControllerTest | 12 | Assertions |
| PostgreSQLAgentTokenRepositoryTest | 12 | Repository |
| API.OAuth2ClientControllerTest | 10 | Assertions |
| API.MFAControllerTest | 9 | Assertions, User field |
| API.RegistrationControllerTest | 8 | Assertions |
| Clients.IndexTest | 7 | Phoenix.Param, LiveView |
| API.UserControllerTest | 5 | Assertions |
| API.PasswordControllerTest | 4 | Assertions |
| PostgreSQLTokenRepositoryTest | 4 | Repository |
| Domain.Entities.UserTest | 4 | User field |
| Plugs.RequireAuthTest | 3 | Phoenix.Param |
| Application.UseCases.GenerateAgentTokenTest | 2 | generate!/0 |
| Others | ~48 | Various |

---

## Notes

- High priority fixes are **quick wins** with high impact
- Phase 1 alone would take success rate from 91.6% to 93.1% in 40 minutes
- Phases 1-3 combined: **94.4% success rate in ~80 minutes**
- Phase 4 is optional - depends on desired success rate target
