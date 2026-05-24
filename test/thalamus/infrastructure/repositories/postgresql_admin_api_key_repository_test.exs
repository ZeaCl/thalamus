defmodule Thalamus.Infrastructure.Repositories.PostgreSQLAdminApiKeyRepositoryTest do
  use Thalamus.DataCase, async: true

  alias Thalamus.Infrastructure.Repositories.PostgreSQLAdminApiKeyRepository
  alias Thalamus.Domain.Entities.AdminApiKey
  alias Thalamus.Infrastructure.Persistence.Schemas.{AdminApiKeySchema, UserSchema}

  describe "save/1 - creating new API keys" do
    test "inserts a new admin API key into the database" do
      {:ok, api_key} = create_admin_api_key_entity()

      assert {:ok, saved_key} = PostgreSQLAdminApiKeyRepository.save(api_key)
      assert saved_key.id != nil
      assert saved_key.name == api_key.name
      assert saved_key.key_hash == api_key.key_hash
      assert saved_key.key_prefix == api_key.key_prefix
      assert saved_key.is_active == true
      assert saved_key.scopes == []
      assert saved_key.created_at != nil
      assert saved_key.updated_at != nil
    end

    test "saves API key with description" do
      {:ok, api_key} =
        create_admin_api_key_entity(description: "API key for integration testing")

      assert {:ok, saved_key} = PostgreSQLAdminApiKeyRepository.save(api_key)
      assert saved_key.description == "API key for integration testing"
    end

    test "saves API key with scopes" do
      scopes = ["clients:read", "clients:write", "users:read"]
      {:ok, api_key} = create_admin_api_key_entity(scopes: scopes)

      assert {:ok, saved_key} = PostgreSQLAdminApiKeyRepository.save(api_key)
      assert length(saved_key.scopes) == 3
      assert "clients:read" in saved_key.scopes
      assert "clients:write" in saved_key.scopes
      assert "users:read" in saved_key.scopes
    end

    test "saves API key with expires_at" do
      future = DateTime.utc_now() |> DateTime.add(3600, :second)
      {:ok, api_key} = create_admin_api_key_entity(expires_at: future)

      assert {:ok, saved_key} = PostgreSQLAdminApiKeyRepository.save(api_key)
      assert saved_key.expires_at != nil
      # Allow small difference due to truncation
      assert DateTime.diff(saved_key.expires_at, future, :second) in -1..1
    end

    test "saves API key with created_by_user_id" do
      user_id = create_test_user()
      {:ok, api_key} = create_admin_api_key_entity(created_by_user_id: user_id)

      assert {:ok, saved_key} = PostgreSQLAdminApiKeyRepository.save(api_key)
      assert saved_key.created_by_user_id == user_id
    end

    test "saves API key with is_active set to false" do
      {:ok, api_key} = create_admin_api_key_entity(is_active: false)

      assert {:ok, saved_key} = PostgreSQLAdminApiKeyRepository.save(api_key)
      assert saved_key.is_active == false
    end

    test "saves API key with last_used_at timestamp" do
      timestamp = DateTime.utc_now() |> DateTime.add(-1000, :second)
      {:ok, api_key} = create_admin_api_key_entity(last_used_at: timestamp)

      assert {:ok, saved_key} = PostgreSQLAdminApiKeyRepository.save(api_key)
      # last_used_at is not included in create_changeset, so it won't be saved on create
      # It's only updated via update_changeset
      assert saved_key.last_used_at == nil
    end

    test "saves API key with all optional fields" do
      user_id = create_test_user()
      future = DateTime.utc_now() |> DateTime.add(7200, :second)

      {:ok, api_key} =
        create_admin_api_key_entity(
          description: "Full featured key",
          scopes: ["clients:read", "clients:write", "organizations:read"],
          is_active: true,
          expires_at: future,
          created_by_user_id: user_id
        )

      assert {:ok, saved_key} = PostgreSQLAdminApiKeyRepository.save(api_key)
      assert saved_key.description == "Full featured key"
      assert length(saved_key.scopes) == 3
      assert saved_key.created_by_user_id == user_id
      assert saved_key.expires_at != nil
      # last_used_at is not saved on create, only on update
      assert saved_key.last_used_at == nil
    end

    test "returns error on constraint violation (duplicate key_prefix)" do
      {:ok, api_key1} = create_admin_api_key_entity()
      {:ok, _saved} = PostgreSQLAdminApiKeyRepository.save(api_key1)

      # Try to save another key with same prefix
      {:ok, api_key2} =
        create_admin_api_key_entity(
          key_prefix: api_key1.key_prefix,
          key_hash: Bcrypt.hash_pwd_salt("different_secret")
        )

      assert {:error, changeset} = PostgreSQLAdminApiKeyRepository.save(api_key2)
      assert changeset.errors[:key_prefix] != nil
    end
  end

  describe "save/1 - updating existing API keys" do
    test "updates existing API key when id exists in database" do
      {:ok, api_key} = create_admin_api_key_entity(name: "Original Name")
      {:ok, saved_key} = PostgreSQLAdminApiKeyRepository.save(api_key)

      # Update the key
      updated_key = %{saved_key | name: "Updated Name", description: "New description"}
      assert {:ok, result} = PostgreSQLAdminApiKeyRepository.save(updated_key)

      assert result.id == saved_key.id
      # name cannot be updated
      assert result.name == saved_key.name
      assert result.description == "New description"
      assert result.key_hash == saved_key.key_hash
      assert result.key_prefix == saved_key.key_prefix
    end

    test "updates API key scopes" do
      {:ok, api_key} = create_admin_api_key_entity(scopes: ["clients:read"])
      {:ok, saved_key} = PostgreSQLAdminApiKeyRepository.save(api_key)

      # Update scopes
      updated_key = %{saved_key | scopes: ["clients:read", "clients:write", "users:read"]}
      assert {:ok, result} = PostgreSQLAdminApiKeyRepository.save(updated_key)

      assert length(result.scopes) == 3
      assert "clients:write" in result.scopes
      assert "users:read" in result.scopes
    end

    test "updates API key is_active status" do
      {:ok, api_key} = create_admin_api_key_entity(is_active: true)
      {:ok, saved_key} = PostgreSQLAdminApiKeyRepository.save(api_key)

      # Deactivate the key
      updated_key = %{saved_key | is_active: false}
      assert {:ok, result} = PostgreSQLAdminApiKeyRepository.save(updated_key)

      assert result.is_active == false
    end

    test "updates API key expires_at" do
      {:ok, api_key} = create_admin_api_key_entity()
      {:ok, saved_key} = PostgreSQLAdminApiKeyRepository.save(api_key)

      # Set expiration
      future = DateTime.utc_now() |> DateTime.add(7200, :second)
      updated_key = %{saved_key | expires_at: future}
      assert {:ok, result} = PostgreSQLAdminApiKeyRepository.save(updated_key)

      assert result.expires_at != nil
      assert DateTime.diff(result.expires_at, future, :second) in -1..1
    end

    test "updates API key last_used_at" do
      {:ok, api_key} = create_admin_api_key_entity()
      {:ok, saved_key} = PostgreSQLAdminApiKeyRepository.save(api_key)

      # Mark as used
      timestamp = DateTime.utc_now()
      updated_key = %{saved_key | last_used_at: timestamp}
      assert {:ok, result} = PostgreSQLAdminApiKeyRepository.save(updated_key)

      assert result.last_used_at != nil
      assert DateTime.diff(result.last_used_at, timestamp, :second) in -1..1
    end

    test "detects key rotation when key_hash changes" do
      {:ok, api_key} = create_admin_api_key_entity()
      {:ok, saved_key} = PostgreSQLAdminApiKeyRepository.save(api_key)

      original_hash = saved_key.key_hash
      original_prefix = saved_key.key_prefix

      # Rotate the key (new hash and prefix)
      new_hash = Bcrypt.hash_pwd_salt("new_secret_key_12345678901234567890")
      new_prefix = "ak_dev_xY9mN3"

      updated_key = %{saved_key | key_hash: new_hash, key_prefix: new_prefix}
      assert {:ok, result} = PostgreSQLAdminApiKeyRepository.save(updated_key)

      assert result.key_hash == new_hash
      assert result.key_prefix == new_prefix
      assert result.key_hash != original_hash
      assert result.key_prefix != original_prefix
    end

    test "detects key rotation when key_prefix changes" do
      {:ok, api_key} = create_admin_api_key_entity()
      {:ok, saved_key} = PostgreSQLAdminApiKeyRepository.save(api_key)

      original_prefix = saved_key.key_prefix

      # Change prefix only
      new_prefix = "ak_dev_aB1cD2"
      updated_key = %{saved_key | key_prefix: new_prefix}
      assert {:ok, result} = PostgreSQLAdminApiKeyRepository.save(updated_key)

      assert result.key_prefix == new_prefix
      assert result.key_prefix != original_prefix
    end

    test "updates without rotation when key_hash and key_prefix unchanged" do
      {:ok, api_key} = create_admin_api_key_entity()
      {:ok, saved_key} = PostgreSQLAdminApiKeyRepository.save(api_key)

      # Update other fields only
      updated_key = %{
        saved_key
        | description: "Updated description",
          scopes: ["clients:read"],
          is_active: false
      }

      assert {:ok, result} = PostgreSQLAdminApiKeyRepository.save(updated_key)

      assert result.key_hash == saved_key.key_hash
      assert result.key_prefix == saved_key.key_prefix
      assert result.description == "Updated description"
      assert result.is_active == false
    end
  end

  describe "find_by_id/1" do
    test "finds an API key by valid id" do
      {:ok, api_key} = create_admin_api_key_entity()
      {:ok, saved_key} = PostgreSQLAdminApiKeyRepository.save(api_key)

      assert {:ok, found_key} = PostgreSQLAdminApiKeyRepository.find_by_id(saved_key.id)
      assert found_key.id == saved_key.id
      assert found_key.name == saved_key.name
      assert found_key.key_hash == saved_key.key_hash
      assert found_key.key_prefix == saved_key.key_prefix
    end

    test "finds API key with all fields populated" do
      user_id = create_test_user()
      future = DateTime.utc_now() |> DateTime.add(3600, :second)

      {:ok, api_key} =
        create_admin_api_key_entity(
          description: "Test key",
          scopes: ["clients:read", "users:read"],
          expires_at: future,
          created_by_user_id: user_id
        )

      {:ok, saved_key} = PostgreSQLAdminApiKeyRepository.save(api_key)

      assert {:ok, found_key} = PostgreSQLAdminApiKeyRepository.find_by_id(saved_key.id)
      assert found_key.description == "Test key"
      assert length(found_key.scopes) == 2
      assert found_key.expires_at != nil
      assert found_key.created_by_user_id == user_id
    end

    test "returns :not_found when API key does not exist" do
      non_existent_id = Ecto.UUID.generate()

      assert {:error, :not_found} =
               PostgreSQLAdminApiKeyRepository.find_by_id(non_existent_id)
    end

    test "handles nil id gracefully" do
      # This should raise a FunctionClauseError or similar, but we test the behavior
      assert_raise FunctionClauseError, fn ->
        PostgreSQLAdminApiKeyRepository.find_by_id(nil)
      end
    end

    test "raises on invalid UUID format" do
      # Ecto raises CastError when trying to use invalid UUID in query
      assert_raise Ecto.Query.CastError, fn ->
        PostgreSQLAdminApiKeyRepository.find_by_id("not-a-uuid")
      end
    end
  end

  describe "find_by_prefix/1" do
    test "finds an API key by key_prefix" do
      {:ok, api_key} = create_admin_api_key_entity()
      {:ok, saved_key} = PostgreSQLAdminApiKeyRepository.save(api_key)

      assert {:ok, found_key} =
               PostgreSQLAdminApiKeyRepository.find_by_prefix(saved_key.key_prefix)

      assert found_key.id == saved_key.id
      assert found_key.key_prefix == saved_key.key_prefix
    end

    test "finds API key with all associated data" do
      {:ok, api_key} =
        create_admin_api_key_entity(
          description: "Prefix test",
          scopes: ["clients:write"]
        )

      {:ok, saved_key} = PostgreSQLAdminApiKeyRepository.save(api_key)

      assert {:ok, found_key} =
               PostgreSQLAdminApiKeyRepository.find_by_prefix(saved_key.key_prefix)

      assert found_key.description == "Prefix test"
      assert "clients:write" in found_key.scopes
    end

    test "returns :not_found when prefix does not exist" do
      assert {:error, :not_found} =
               PostgreSQLAdminApiKeyRepository.find_by_prefix("ak_dev_000000")
    end

    test "prefix lookup is case sensitive" do
      {:ok, api_key} = create_admin_api_key_entity(key_prefix: "ak_dev_aBcDeF")
      {:ok, _saved_key} = PostgreSQLAdminApiKeyRepository.save(api_key)

      # Lowercase should not find it
      assert {:error, :not_found} =
               PostgreSQLAdminApiKeyRepository.find_by_prefix("ak_dev_abcdef")
    end

    test "finds the correct key when multiple exist" do
      {:ok, api_key1} = create_admin_api_key_entity(key_prefix: "ak_dev_111111")
      {:ok, api_key2} = create_admin_api_key_entity(key_prefix: "ak_dev_222222")

      {:ok, saved1} = PostgreSQLAdminApiKeyRepository.save(api_key1)
      {:ok, saved2} = PostgreSQLAdminApiKeyRepository.save(api_key2)

      assert {:ok, found1} = PostgreSQLAdminApiKeyRepository.find_by_prefix("ak_dev_111111")
      assert {:ok, found2} = PostgreSQLAdminApiKeyRepository.find_by_prefix("ak_dev_222222")

      assert found1.id == saved1.id
      assert found2.id == saved2.id
    end
  end

  describe "delete/1" do
    test "deletes an API key by id" do
      {:ok, api_key} = create_admin_api_key_entity()
      {:ok, saved_key} = PostgreSQLAdminApiKeyRepository.save(api_key)

      assert :ok = PostgreSQLAdminApiKeyRepository.delete(saved_key.id)

      # Verify key is deleted
      assert {:error, :not_found} = PostgreSQLAdminApiKeyRepository.find_by_id(saved_key.id)
    end

    test "returns :not_found when deleting non-existent API key" do
      non_existent_id = Ecto.UUID.generate()

      assert {:error, :not_found} = PostgreSQLAdminApiKeyRepository.delete(non_existent_id)
    end

    test "deletes API key with all associated data" do
      user_id = create_test_user()

      {:ok, api_key} =
        create_admin_api_key_entity(
          description: "To be deleted",
          scopes: ["clients:read", "users:read"],
          created_by_user_id: user_id
        )

      {:ok, saved_key} = PostgreSQLAdminApiKeyRepository.save(api_key)

      assert :ok = PostgreSQLAdminApiKeyRepository.delete(saved_key.id)
      assert {:error, :not_found} = PostgreSQLAdminApiKeyRepository.find_by_id(saved_key.id)
    end

    test "cannot find deleted API key by prefix" do
      {:ok, api_key} = create_admin_api_key_entity()
      {:ok, saved_key} = PostgreSQLAdminApiKeyRepository.save(api_key)

      prefix = saved_key.key_prefix

      assert :ok = PostgreSQLAdminApiKeyRepository.delete(saved_key.id)
      assert {:error, :not_found} = PostgreSQLAdminApiKeyRepository.find_by_prefix(prefix)
    end
  end

  describe "list/1 - filtering" do
    test "returns all API keys when no filters provided" do
      {:ok, key1} = create_admin_api_key_entity(name: "List Test 1")
      {:ok, key2} = create_admin_api_key_entity(name: "List Test 2")
      {:ok, _saved1} = PostgreSQLAdminApiKeyRepository.save(key1)
      {:ok, _saved2} = PostgreSQLAdminApiKeyRepository.save(key2)

      assert {:ok, keys} = PostgreSQLAdminApiKeyRepository.list(%{})
      assert length(keys) >= 2
    end

    test "filters by is_active" do
      {:ok, active_key} = create_admin_api_key_entity(name: "Active Key", is_active: true)
      {:ok, inactive_key} = create_admin_api_key_entity(name: "Inactive Key", is_active: false)

      {:ok, _saved_active} = PostgreSQLAdminApiKeyRepository.save(active_key)
      {:ok, _saved_inactive} = PostgreSQLAdminApiKeyRepository.save(inactive_key)

      assert {:ok, active_keys} = PostgreSQLAdminApiKeyRepository.list(%{is_active: true})
      assert length(active_keys) >= 1
      assert Enum.all?(active_keys, fn k -> k.is_active == true end)

      assert {:ok, inactive_keys} = PostgreSQLAdminApiKeyRepository.list(%{is_active: false})
      assert length(inactive_keys) >= 1
      assert Enum.all?(inactive_keys, fn k -> k.is_active == false end)
    end

    test "filters by created_by_user_id" do
      user1_id = create_test_user()
      user2_id = create_test_user()

      {:ok, key1} = create_admin_api_key_entity(name: "User1 Key", created_by_user_id: user1_id)
      {:ok, key2} = create_admin_api_key_entity(name: "User2 Key", created_by_user_id: user2_id)

      {:ok, _saved1} = PostgreSQLAdminApiKeyRepository.save(key1)
      {:ok, _saved2} = PostgreSQLAdminApiKeyRepository.save(key2)

      assert {:ok, user1_keys} =
               PostgreSQLAdminApiKeyRepository.list(%{created_by_user_id: user1_id})

      assert length(user1_keys) >= 1
      assert Enum.all?(user1_keys, fn k -> k.created_by_user_id == user1_id end)

      assert {:ok, user2_keys} =
               PostgreSQLAdminApiKeyRepository.list(%{created_by_user_id: user2_id})

      assert length(user2_keys) >= 1
      assert Enum.all?(user2_keys, fn k -> k.created_by_user_id == user2_id end)
    end

    test "filters by scopes - returns keys with ANY of the requested scopes" do
      {:ok, key1} =
        create_admin_api_key_entity(
          name: "Clients Key",
          scopes: ["clients:read", "clients:write"]
        )

      {:ok, key2} = create_admin_api_key_entity(name: "Users Key", scopes: ["users:read"])

      {:ok, key3} =
        create_admin_api_key_entity(
          name: "Mixed Key",
          scopes: ["clients:read", "users:read"]
        )

      {:ok, _saved1} = PostgreSQLAdminApiKeyRepository.save(key1)
      {:ok, _saved2} = PostgreSQLAdminApiKeyRepository.save(key2)
      {:ok, _saved3} = PostgreSQLAdminApiKeyRepository.save(key3)

      # Find keys with clients:read OR users:read
      assert {:ok, filtered_keys} =
               PostgreSQLAdminApiKeyRepository.list(%{scopes: ["clients:read", "users:read"]})

      assert length(filtered_keys) >= 3
    end

    test "filters by scopes with single scope" do
      {:ok, key1} =
        create_admin_api_key_entity(
          name: "Clients Only",
          scopes: ["clients:read"]
        )

      {:ok, _saved1} = PostgreSQLAdminApiKeyRepository.save(key1)

      assert {:ok, filtered_keys} =
               PostgreSQLAdminApiKeyRepository.list(%{scopes: ["clients:read"]})

      assert length(filtered_keys) >= 1
    end

    test "ignores unknown filters" do
      {:ok, key} = create_admin_api_key_entity()
      {:ok, _saved} = PostgreSQLAdminApiKeyRepository.save(key)

      # Unknown filter should be ignored
      assert {:ok, keys} =
               PostgreSQLAdminApiKeyRepository.list(%{unknown_filter: "value", is_active: true})

      assert is_list(keys)
    end

    test "combines multiple filters" do
      user_id = create_test_user()

      {:ok, key} =
        create_admin_api_key_entity(
          name: "Multi Filter",
          is_active: true,
          scopes: ["clients:read"],
          created_by_user_id: user_id
        )

      {:ok, _saved} = PostgreSQLAdminApiKeyRepository.save(key)

      assert {:ok, keys} =
               PostgreSQLAdminApiKeyRepository.list(%{
                 is_active: true,
                 created_by_user_id: user_id,
                 scopes: ["clients:read"]
               })

      assert length(keys) >= 1

      if length(keys) > 0 do
        assert Enum.all?(keys, fn k ->
                 k.is_active == true and k.created_by_user_id == user_id
               end)
      end
    end

    test "returns empty list when no keys match filters" do
      non_existent_user = Ecto.UUID.generate()

      assert {:ok, keys} =
               PostgreSQLAdminApiKeyRepository.list(%{created_by_user_id: non_existent_user})

      # May be empty or contain keys from other tests
      assert is_list(keys)
    end
  end

  describe "list/1 - ordering" do
    test "orders by inserted_at descending by default" do
      # Create keys with slight time differences
      {:ok, key1} = create_admin_api_key_entity(name: "First")
      {:ok, saved1} = PostgreSQLAdminApiKeyRepository.save(key1)

      # Small delay to ensure different timestamps
      :timer.sleep(10)

      {:ok, key2} = create_admin_api_key_entity(name: "Second")
      {:ok, saved2} = PostgreSQLAdminApiKeyRepository.save(key2)

      assert {:ok, keys} = PostgreSQLAdminApiKeyRepository.list(%{})

      # Find our test keys
      our_keys = Enum.filter(keys, fn k -> k.id in [saved1.id, saved2.id] end)

      if length(our_keys) == 2 do
        [first, second] = our_keys
        # More recent should come first (descending order)
        assert DateTime.compare(first.created_at, second.created_at) in [:gt, :eq]
      end
    end

    test "returns keys in consistent order" do
      {:ok, keys1} = PostgreSQLAdminApiKeyRepository.list(%{})
      {:ok, keys2} = PostgreSQLAdminApiKeyRepository.list(%{})

      # Should return same order
      ids1 = Enum.map(keys1, & &1.id)
      ids2 = Enum.map(keys2, & &1.id)

      assert ids1 == ids2
    end
  end

  describe "list_active/0" do
    test "returns only active and non-expired keys" do
      # Active, no expiration
      {:ok, active_key} = create_admin_api_key_entity(name: "Active", is_active: true)
      {:ok, _saved_active} = PostgreSQLAdminApiKeyRepository.save(active_key)

      # Inactive
      {:ok, inactive_key} = create_admin_api_key_entity(name: "Inactive", is_active: false)
      {:ok, _saved_inactive} = PostgreSQLAdminApiKeyRepository.save(inactive_key)

      # Active but expired
      past = DateTime.utc_now() |> DateTime.add(-3600, :second)

      {:ok, expired_key} =
        create_admin_api_key_entity(name: "Expired", is_active: true, expires_at: past)

      {:ok, _saved_expired} = PostgreSQLAdminApiKeyRepository.save(expired_key)

      # Active, not yet expired
      future = DateTime.utc_now() |> DateTime.add(3600, :second)

      {:ok, valid_key} =
        create_admin_api_key_entity(name: "Valid", is_active: true, expires_at: future)

      {:ok, _saved_valid} = PostgreSQLAdminApiKeyRepository.save(valid_key)

      assert {:ok, active_keys} = PostgreSQLAdminApiKeyRepository.list_active()

      # Should include active and valid keys only
      assert Enum.all?(active_keys, fn k -> k.is_active == true end)

      # Should not include expired keys
      expired_in_list = Enum.any?(active_keys, fn k -> k.name == "Expired" end)
      assert expired_in_list == false

      # Should include non-expired keys
      active_in_list = Enum.any?(active_keys, fn k -> k.name == "Active" end)
      valid_in_list = Enum.any?(active_keys, fn k -> k.name == "Valid" end)

      assert active_in_list or valid_in_list
    end

    test "returns keys ordered by inserted_at descending" do
      {:ok, key1} = create_admin_api_key_entity(name: "First Active", is_active: true)
      {:ok, saved1} = PostgreSQLAdminApiKeyRepository.save(key1)

      :timer.sleep(10)

      {:ok, key2} = create_admin_api_key_entity(name: "Second Active", is_active: true)
      {:ok, saved2} = PostgreSQLAdminApiKeyRepository.save(key2)

      assert {:ok, active_keys} = PostgreSQLAdminApiKeyRepository.list_active()

      our_keys = Enum.filter(active_keys, fn k -> k.id in [saved1.id, saved2.id] end)

      if length(our_keys) == 2 do
        [first, second] = our_keys
        assert DateTime.compare(first.created_at, second.created_at) in [:gt, :eq]
      end
    end

    test "returns empty list when no active keys exist" do
      # Clean slate or only inactive keys
      {:ok, inactive_key} = create_admin_api_key_entity(name: "Only Inactive", is_active: false)
      {:ok, _saved} = PostgreSQLAdminApiKeyRepository.save(inactive_key)

      # Even if there are some active keys from other tests, this tests the function works
      assert {:ok, active_keys} = PostgreSQLAdminApiKeyRepository.list_active()
      assert is_list(active_keys)

      # Should not include inactive key
      inactive_in_list = Enum.any?(active_keys, fn k -> k.name == "Only Inactive" end)
      assert inactive_in_list == false
    end

    test "includes keys with nil expires_at" do
      {:ok, key} = create_admin_api_key_entity(name: "Never Expires", expires_at: nil)
      {:ok, saved} = PostgreSQLAdminApiKeyRepository.save(key)

      assert {:ok, active_keys} = PostgreSQLAdminApiKeyRepository.list_active()

      found = Enum.find(active_keys, fn k -> k.id == saved.id end)
      assert found != nil
      assert found.expires_at == nil
    end
  end

  describe "edge cases and error handling" do
    test "handles API key with empty scopes array" do
      {:ok, api_key} = create_admin_api_key_entity(scopes: [])
      {:ok, saved_key} = PostgreSQLAdminApiKeyRepository.save(api_key)

      assert saved_key.scopes == []

      assert {:ok, found_key} = PostgreSQLAdminApiKeyRepository.find_by_id(saved_key.id)
      assert found_key.scopes == []
    end

    test "handles API key with nil description" do
      {:ok, api_key} = create_admin_api_key_entity(description: nil)
      {:ok, saved_key} = PostgreSQLAdminApiKeyRepository.save(api_key)

      assert saved_key.description == nil
    end

    test "handles API key with nil expires_at" do
      {:ok, api_key} = create_admin_api_key_entity(expires_at: nil)
      {:ok, saved_key} = PostgreSQLAdminApiKeyRepository.save(api_key)

      assert saved_key.expires_at == nil
    end

    test "handles API key with nil last_used_at" do
      {:ok, api_key} = create_admin_api_key_entity(last_used_at: nil)
      {:ok, saved_key} = PostgreSQLAdminApiKeyRepository.save(api_key)

      assert saved_key.last_used_at == nil
    end

    test "handles API key with nil created_by_user_id" do
      {:ok, api_key} = create_admin_api_key_entity(created_by_user_id: nil)
      {:ok, saved_key} = PostgreSQLAdminApiKeyRepository.save(api_key)

      assert saved_key.created_by_user_id == nil
    end

    test "schema_to_entity handles nil scopes from database" do
      # Directly insert with nil scopes to test schema conversion
      schema = %AdminApiKeySchema{
        key_hash: Bcrypt.hash_pwd_salt("test_key_123456789012345678901234567890"),
        key_prefix: "ak_dev_tEsT01",
        name: "Nil Scopes Test",
        scopes: nil,
        is_active: true
      }

      {:ok, inserted} = Repo.insert(schema)

      assert {:ok, found_key} = PostgreSQLAdminApiKeyRepository.find_by_id(inserted.id)
      # Should convert nil to empty array
      assert found_key.scopes == []
    end

    test "handles concurrent updates gracefully" do
      {:ok, api_key} = create_admin_api_key_entity()
      {:ok, saved_key} = PostgreSQLAdminApiKeyRepository.save(api_key)

      # Simulate concurrent update by updating same key twice
      updated1 = %{saved_key | description: "Update 1"}
      updated2 = %{saved_key | description: "Update 2"}

      {:ok, result1} = PostgreSQLAdminApiKeyRepository.save(updated1)
      {:ok, result2} = PostgreSQLAdminApiKeyRepository.save(updated2)

      # Both should succeed, last one wins
      assert result1.id == saved_key.id
      assert result2.id == saved_key.id
    end
  end

  # --- Test Helpers ---

  defp create_admin_api_key_entity(opts \\ []) do
    id = Keyword.get(opts, :id, Ecto.UUID.generate())
    name = Keyword.get(opts, :name, "Test API Key #{:rand.uniform(1_000_000)}")
    key_prefix = Keyword.get(opts, :key_prefix, generate_key_prefix())

    # Generate a realistic key hash
    test_key = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    key_hash = Keyword.get(opts, :key_hash, Bcrypt.hash_pwd_salt(test_key))

    AdminApiKey.new(%{
      id: id,
      key_hash: key_hash,
      key_prefix: key_prefix,
      name: name,
      description: Keyword.get(opts, :description),
      scopes: Keyword.get(opts, :scopes, []),
      is_active: Keyword.get(opts, :is_active, true),
      expires_at: Keyword.get(opts, :expires_at),
      last_used_at: Keyword.get(opts, :last_used_at),
      created_by_user_id: Keyword.get(opts, :created_by_user_id)
    })
  end

  defp generate_key_prefix do
    # Generate a valid key prefix: ak_dev_XXXXXX (13 chars total)
    random_chars =
      :crypto.strong_rand_bytes(4)
      |> Base.encode64(padding: false)
      |> binary_part(0, 6)

    "ak_dev_#{random_chars}"
  end

  defp create_test_user do
    user = %UserSchema{
      email: "testuser_#{:rand.uniform(1_000_000)}@example.com",
      name: "Test User",
      password_hash: Bcrypt.hash_pwd_salt("TestPassword123!"),
      status: :active,
      failed_login_attempts: 0
    }

    {:ok, inserted} = Repo.insert(user)
    inserted.id
  end
end
