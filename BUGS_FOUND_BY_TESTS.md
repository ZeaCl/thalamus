# Bugs Found by Test Suite

## Summary

The comprehensive test suite discovered **4 critical bugs** in production repository code where value object prefixes are not properly stripped before database queries.

All bugs follow the same pattern: passing value objects' string representation (e.g., "user_UUID") to Ecto queries expecting raw UUIDs.

---

## Bug #1: update_last_login doesn't extract UUID

**File**: `lib/thalamus/infrastructure/repositories/postgresql_user_repository.ex:149`

**Status**: ❌ Failing (3 tests skipped)

**Issue**: The function passes "user_UUID" to `Repo.get` which expects just "UUID"

**Current Code**:
```elixir
def update_last_login(%UserId{} = user_id, timestamp) do
  user_id_string = UserId.to_string(user_id)

  case Repo.get(UserSchema, user_id_string) do  # ❌ Passes "user_<uuid>"
    nil -> {:error, :not_found}
    schema ->
      schema
      |> Ecto.Changeset.change(%{last_login_at: timestamp})
      |> Repo.update()
      # ...
  end
end
```

**Fix**:
```elixir
def update_last_login(%UserId{} = user_id, timestamp) do
  user_id_string = UserId.to_string(user_id)
  uuid = String.replace_prefix(user_id_string, "user_", "")  # ✅ Extract UUID

  case Repo.get(UserSchema, uuid) do
    # ... rest remains the same
  end
end
```

**Failing Tests**:
- `test update_last_login/2 updates timestamp for existing user` (skipped)
- `test update_last_login/2 returns error for non-existent user` (skipped)
- `test update_last_login/2 handles UserId value object` (skipped)

**Reference**: See `delete/1` in the same file (line 102-104) for correct pattern

---

## Bug #2: revoke_all_for_user doesn't extract UUID

**File**: `lib/thalamus/infrastructure/repositories/postgresql_token_repository.ex:72-77`

**Status**: ❌ Failing (5 tests failing)

**Issue**: Uses `UserId.to_string()` which includes "user_" prefix in WHERE clause

**Current Code**:
```elixir
def revoke_all_for_user(%UserId{} = user_id) do
  user_id_string = UserId.to_string(user_id)  # Returns "user_<uuid>"

  from(t in TokenSchema,
    where: t.user_id == ^user_id_string,  # ❌ Tries to match "user_<uuid>" against binary_id
    where: t.revoked == false
  )
  |> Repo.update_all(set: [revoked: true, revoked_at: DateTime.utc_now()])
  # ...
end
```

**Error**:
```
** (Ecto.Query.CastError) value `"user_eee83ab4-5878-4a98-95fe-034faca13d59"`
cannot be dumped to type :binary_id
```

**Fix**:
```elixir
def revoke_all_for_user(%UserId{} = user_id) do
  user_id_string = UserId.to_string(user_id)
  uuid = String.replace_prefix(user_id_string, "user_", "")  # ✅ Extract UUID

  from(t in TokenSchema,
    where: t.user_id == ^uuid,  # ✅ Now matches correctly
    where: t.revoked == false
  )
  |> Repo.update_all(set: [revoked: true, revoked_at: DateTime.utc_now()])
  # ...
end
```

**Failing Tests**:
- `test revoke_all_for_user/1 revokes all tokens for user`
- `test revoke_all_for_user/1 doesn't revoke already revoked tokens`
- `test revoke_all_for_user/1 doesn't affect other users' tokens`
- `test revoke_all_for_user/1 handles user with no tokens`
- `test revoke_all_for_user/1 returns count of revoked tokens`

---

## Bug #3: revoke_all_for_client doesn't extract UUID

**File**: `lib/thalamus/infrastructure/repositories/postgresql_token_repository.ex:84-93`

**Status**: ❌ Failing (4 tests failing)

**Issue**: Uses `ClientId.to_string()` which includes "client_" prefix in WHERE clause

**Current Code**:
```elixir
def revoke_all_for_client(%ClientId{} = client_id) do
  client_id_string = ClientId.to_string(client_id)  # Returns "client_<uuid>"

  from(t in TokenSchema,
    where: t.client_id == ^client_id_string,  # ❌ Tries to match "client_<uuid>" against binary_id
    where: t.revoked == false
  )
  |> Repo.update_all(set: [revoked: true, revoked_at: DateTime.utc_now()])
  # ...
end
```

**Error**:
```
** (Ecto.Query.CastError) value `"client_eee83ab4-5878-4a98-95fe-034faca13d59"`
cannot be dumped to type :binary_id
```

**Fix**:
```elixir
def revoke_all_for_client(%ClientId{} = client_id) do
  client_id_string = ClientId.to_string(client_id)
  uuid = String.replace_prefix(client_id_string, "client_", "")  # ✅ Extract UUID

  from(t in TokenSchema,
    where: t.client_id == ^uuid,  # ✅ Now matches correctly
    where: t.revoked == false
  )
  |> Repo.update_all(set: [revoked: true, revoked_at: DateTime.utc_now()])
  # ...
end
```

**Failing Tests**:
- `test revoke_all_for_client/1 revokes all tokens for client`
- `test revoke_all_for_client/1 doesn't revoke already revoked tokens`
- `test revoke_all_for_client/1 doesn't affect other clients' tokens`
- `test revoke_all_for_client/1 returns count of revoked tokens`

---

## Bug #4: find_by_user doesn't extract UUID

**File**: `lib/thalamus/infrastructure/repositories/postgresql_token_repository.ex:109-119`

**Status**: ❌ Failing (6 tests failing)

**Issue**: Uses `UserId.to_string()` which includes "user_" prefix in WHERE clause

**Current Code**:
```elixir
def find_by_user(%UserId{} = user_id, opts \\ []) do
  user_id_string = UserId.to_string(user_id)  # Returns "user_<uuid>"

  query =
    from(t in TokenSchema,
      where: t.user_id == ^user_id_string  # ❌ Tries to match "user_<uuid>" against binary_id
    )
    |> apply_token_type_filter(opts)
    |> apply_active_filter(opts)
    # ...

  Repo.all(query)
  # ...
end
```

**Error**:
```
** (Ecto.Query.CastError) value `"user_eee83ab4-5878-4a98-95fe-034faca13d59"`
cannot be dumped to type :binary_id
```

**Fix**:
```elixir
def find_by_user(%UserId{} = user_id, opts \\ []) do
  user_id_string = UserId.to_string(user_id)
  uuid = String.replace_prefix(user_id_string, "user_", "")  # ✅ Extract UUID

  query =
    from(t in TokenSchema,
      where: t.user_id == ^uuid  # ✅ Now matches correctly
    )
    |> apply_token_type_filter(opts)
    |> apply_active_filter(opts)
    # ...

  Repo.all(query)
  # ...
end
```

**Failing Tests**:
- `test find_by_user/1 returns all tokens for user`
- `test find_by_user/1 with token_type filter`
- `test find_by_user/1 with active_only filter`
- `test find_by_user/1 with active_only excludes revoked tokens`
- `test find_by_user/1 with active_only excludes expired tokens`
- `test find_by_user/1 returns empty list for user with no tokens`

---

## Impact Analysis

### Severity: **HIGH** 🔴

All 4 bugs prevent critical repository operations from working:
- User login tracking (update_last_login)
- Bulk token revocation for security (revoke_all_for_user, revoke_all_for_client)
- User token listing (find_by_user)

### Affected Functionality

1. **Authentication Flow**: Can't track last login timestamps
2. **Security**: Can't revoke all tokens when user/client is compromised
3. **Token Management**: Can't list user's active sessions/tokens
4. **Admin Operations**: Bulk token operations fail

### Why These Bugs Exist

The bugs stem from inconsistent handling of value objects across the repository:

**Correct Pattern** (used in some functions):
```elixir
def delete(%UserId{} = user_id) do
  user_id_string = UserId.to_string(user_id)
  uuid = String.replace_prefix(user_id_string, "user_", "")  # ✅ Extract UUID
  # Use uuid with Repo
end
```

**Incorrect Pattern** (used in buggy functions):
```elixir
def find_by_user(%UserId{} = user_id) do
  user_id_string = UserId.to_string(user_id)
  # Directly use user_id_string without extracting UUID  ❌
end
```

---

## Test Coverage Impact

### Before Fixes
- 169 tests total
- 150 passing (88.8%)
- 16 failing (9.5%)
- 3 skipped (1.8%)

### After Fixes (Estimated)
- 169 tests total
- 169 passing (100%) ✅
- 0 failing
- 0 skipped

### Coverage Impact
- Current: 61.5%
- After fixes: Estimated 63-65% (failed tests will contribute to coverage)

---

## Resolution Steps

1. ✅ **Document bugs** (this file)
2. **Apply fixes** to 4 repository functions
3. **Run tests** to verify all pass
4. **Commit fixes** with reference to test suite
5. **Update COVERAGE_ROADMAP.md** with new baseline

---

## Prevention

To prevent similar bugs in the future:

1. **Add helper functions** to repositories:
```elixir
defp prepare_user_id(%UserId{} = user_id) do
  user_id |> UserId.to_string() |> String.replace_prefix("user_", "")
end

defp prepare_client_id(%ClientId{} = client_id) do
  client_id |> ClientId.to_string() |> String.replace_prefix("client_", "")
end
```

2. **Use helpers consistently** in all repository functions

3. **Add integration tests** for all repository methods (✅ already done)

4. **Code review checklist**: Verify value object → UUID conversion in queries

---

## References

- Test suite: `test/thalamus/infrastructure/repositories/postgresql_user_repository_test.exs`
- Test suite: `test/thalamus/infrastructure/repositories/postgresql_token_repository_test.exs`
- Value object definitions: `lib/thalamus/domain/value_objects/user_id.ex`, `client_id.ex`
- Schema definitions: `lib/thalamus/infrastructure/persistence/schemas/`
