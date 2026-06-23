defmodule Thalamus.Domain.Entities.AdminApiKeyTest do
  use ExUnit.Case, async: false

  alias Thalamus.Domain.Entities.AdminApiKey

  describe "new/1" do
    test "creates a valid AdminApiKey with required fields" do
      attrs = %{
        id: Ecto.UUID.generate(),
        key_hash: "$2b$10$abcdefghijklmnopqrstuvwxyz",
        key_prefix: "ak_dev_vK8mN2",
        name: "Test API Key"
      }

      assert {:ok, api_key} = AdminApiKey.new(attrs)
      assert api_key.id == attrs.id
      assert api_key.key_hash == attrs.key_hash
      assert api_key.key_prefix == attrs.key_prefix
      assert api_key.name == attrs.name
      assert api_key.is_active == true
      assert api_key.scopes == []
      assert is_nil(api_key.description)
      assert is_nil(api_key.expires_at)
    end

    test "creates AdminApiKey with optional fields" do
      expires_at = DateTime.add(DateTime.utc_now(), 3600, :second)

      attrs = %{
        id: Ecto.UUID.generate(),
        key_hash: "$2b$10$abcdefghijklmnopqrstuvwxyz",
        key_prefix: "ak_dev_vK8mN2",
        name: "Test API Key",
        description: "Test description",
        scopes: ["clients:read", "clients:write"],
        expires_at: expires_at,
        created_by_user_id: Ecto.UUID.generate()
      }

      assert {:ok, api_key} = AdminApiKey.new(attrs)
      assert api_key.description == "Test description"
      assert api_key.scopes == ["clients:read", "clients:write"]
      assert api_key.expires_at == expires_at
      assert api_key.created_by_user_id == attrs.created_by_user_id
    end

    test "fails with missing required fields" do
      assert {:error, :missing_required_fields} = AdminApiKey.new(%{})

      assert {:error, :missing_required_fields} =
               AdminApiKey.new(%{
                 id: Ecto.UUID.generate(),
                 key_hash: "$2b$10$abc"
               })
    end

    test "fails with name too short" do
      attrs = %{
        id: Ecto.UUID.generate(),
        key_hash: "$2b$10$abcdefghijklmnopqrstuvwxyz",
        key_prefix: "ak_dev_vK8mN2",
        name: "AB"
      }

      assert {:error, :name_too_short} = AdminApiKey.new(attrs)
    end

    test "fails with name too long" do
      long_name = String.duplicate("a", 256)

      attrs = %{
        id: Ecto.UUID.generate(),
        key_hash: "$2b$10$abcdefghijklmnopqrstuvwxyz",
        key_prefix: "ak_dev_vK8mN2",
        name: long_name
      }

      assert {:error, :name_too_long} = AdminApiKey.new(attrs)
    end

    test "fails with invalid key_prefix length" do
      attrs = %{
        id: Ecto.UUID.generate(),
        key_hash: "$2b$10$abcdefghijklmnopqrstuvwxyz",
        key_prefix: "ak_dev_short",
        name: "Test API Key"
      }

      assert {:error, :invalid_key_prefix_length} = AdminApiKey.new(attrs)
    end

    test "fails with invalid key_prefix format" do
      attrs = %{
        id: Ecto.UUID.generate(),
        key_hash: "$2b$10$abcdefghijklmnopqrstuvwxyz",
        key_prefix: "invalid_12345",
        name: "Test API Key"
      }

      assert {:error, :invalid_key_prefix_format} = AdminApiKey.new(attrs)
    end

    test "accepts valid dev key prefix" do
      attrs = %{
        id: Ecto.UUID.generate(),
        key_hash: "$2b$10$abcdefghijklmnopqrstuvwxyz",
        key_prefix: "ak_dev_vK8mN2",
        name: "Test API Key"
      }

      assert {:ok, _api_key} = AdminApiKey.new(attrs)
    end

    test "accepts valid live key prefix" do
      attrs = %{
        id: Ecto.UUID.generate(),
        key_hash: "$2b$10$abcdefghijklmnopqrstuvwxyz",
        key_prefix: "ak_live_vK8mN",
        name: "Test API Key"
      }

      assert {:ok, _api_key} = AdminApiKey.new(attrs)
    end

    test "fails with invalid scopes" do
      attrs = %{
        id: Ecto.UUID.generate(),
        key_hash: "$2b$10$abcdefghijklmnopqrstuvwxyz",
        key_prefix: "ak_dev_vK8mN2",
        name: "Test API Key",
        scopes: ["clients:read", "invalid:scope"]
      }

      assert {:error, {:invalid_scopes, ["invalid:scope"]}} = AdminApiKey.new(attrs)
    end

    test "fails when scopes is not a list" do
      attrs = %{
        id: Ecto.UUID.generate(),
        key_hash: "$2b$10$abcdefghijklmnopqrstuvwxyz",
        key_prefix: "ak_dev_vK8mN2",
        name: "Test API Key",
        scopes: "not_a_list"
      }

      assert {:error, :scopes_must_be_list} = AdminApiKey.new(attrs)
    end
  end

  describe "activate/1" do
    test "activates an inactive API key" do
      {:ok, api_key} =
        AdminApiKey.new(%{
          id: Ecto.UUID.generate(),
          key_hash: "$2b$10$abc",
          key_prefix: "ak_dev_vK8mN2",
          name: "Test",
          is_active: false
        })

      assert {:ok, activated} = AdminApiKey.activate(api_key)
      assert activated.is_active == true
      # updated_at should be set (may be same as created if executed in same second)
      assert activated.updated_at != nil
    end
  end

  describe "deactivate/1" do
    test "deactivates an active API key" do
      {:ok, api_key} =
        AdminApiKey.new(%{
          id: Ecto.UUID.generate(),
          key_hash: "$2b$10$abc",
          key_prefix: "ak_dev_vK8mN2",
          name: "Test"
        })

      assert {:ok, deactivated} = AdminApiKey.deactivate(api_key)
      assert deactivated.is_active == false
      # updated_at should be set (may be same as created if executed in same second)
      assert deactivated.updated_at != nil
    end
  end

  describe "expired?/1" do
    test "returns false when expires_at is nil" do
      {:ok, api_key} =
        AdminApiKey.new(%{
          id: Ecto.UUID.generate(),
          key_hash: "$2b$10$abc",
          key_prefix: "ak_dev_vK8mN2",
          name: "Test",
          expires_at: nil
        })

      assert AdminApiKey.expired?(api_key) == false
    end

    test "returns false when expires_at is in the future" do
      future = DateTime.add(DateTime.utc_now(), 3600, :second)

      {:ok, api_key} =
        AdminApiKey.new(%{
          id: Ecto.UUID.generate(),
          key_hash: "$2b$10$abc",
          key_prefix: "ak_dev_vK8mN2",
          name: "Test",
          expires_at: future
        })

      assert AdminApiKey.expired?(api_key) == false
    end

    test "returns true when expires_at is in the past" do
      past = DateTime.add(DateTime.utc_now(), -3600, :second)

      {:ok, api_key} =
        AdminApiKey.new(%{
          id: Ecto.UUID.generate(),
          key_hash: "$2b$10$abc",
          key_prefix: "ak_dev_vK8mN2",
          name: "Test",
          expires_at: past
        })

      assert AdminApiKey.expired?(api_key) == true
    end
  end

  describe "valid?/1" do
    test "returns true when active and not expired" do
      {:ok, api_key} =
        AdminApiKey.new(%{
          id: Ecto.UUID.generate(),
          key_hash: "$2b$10$abc",
          key_prefix: "ak_dev_vK8mN2",
          name: "Test",
          is_active: true,
          expires_at: nil
        })

      assert AdminApiKey.valid?(api_key) == true
    end

    test "returns false when inactive" do
      {:ok, api_key} =
        AdminApiKey.new(%{
          id: Ecto.UUID.generate(),
          key_hash: "$2b$10$abc",
          key_prefix: "ak_dev_vK8mN2",
          name: "Test",
          is_active: false
        })

      assert AdminApiKey.valid?(api_key) == false
    end

    test "returns false when expired" do
      past = DateTime.add(DateTime.utc_now(), -3600, :second)

      {:ok, api_key} =
        AdminApiKey.new(%{
          id: Ecto.UUID.generate(),
          key_hash: "$2b$10$abc",
          key_prefix: "ak_dev_vK8mN2",
          name: "Test",
          is_active: true,
          expires_at: past
        })

      assert AdminApiKey.valid?(api_key) == false
    end
  end

  describe "has_scope?/2" do
    test "returns true when API key has the scope" do
      {:ok, api_key} =
        AdminApiKey.new(%{
          id: Ecto.UUID.generate(),
          key_hash: "$2b$10$abc",
          key_prefix: "ak_dev_vK8mN2",
          name: "Test",
          scopes: ["clients:read", "clients:write"]
        })

      assert AdminApiKey.has_scope?(api_key, "clients:read") == true
      assert AdminApiKey.has_scope?(api_key, "clients:write") == true
    end

    test "returns false when API key doesn't have the scope" do
      {:ok, api_key} =
        AdminApiKey.new(%{
          id: Ecto.UUID.generate(),
          key_hash: "$2b$10$abc",
          key_prefix: "ak_dev_vK8mN2",
          name: "Test",
          scopes: ["clients:read"]
        })

      assert AdminApiKey.has_scope?(api_key, "clients:write") == false
    end
  end

  describe "has_scopes?/2" do
    test "returns true when API key has all required scopes" do
      {:ok, api_key} =
        AdminApiKey.new(%{
          id: Ecto.UUID.generate(),
          key_hash: "$2b$10$abc",
          key_prefix: "ak_dev_vK8mN2",
          name: "Test",
          scopes: ["clients:read", "clients:write", "clients:delete"]
        })

      assert AdminApiKey.has_scopes?(api_key, ["clients:read", "clients:write"]) == true
    end

    test "returns false when API key is missing some required scopes" do
      {:ok, api_key} =
        AdminApiKey.new(%{
          id: Ecto.UUID.generate(),
          key_hash: "$2b$10$abc",
          key_prefix: "ak_dev_vK8mN2",
          name: "Test",
          scopes: ["clients:read"]
        })

      assert AdminApiKey.has_scopes?(api_key, ["clients:read", "clients:write"]) == false
    end

    test "returns true for empty required scopes list" do
      {:ok, api_key} =
        AdminApiKey.new(%{
          id: Ecto.UUID.generate(),
          key_hash: "$2b$10$abc",
          key_prefix: "ak_dev_vK8mN2",
          name: "Test",
          scopes: ["clients:read"]
        })

      assert AdminApiKey.has_scopes?(api_key, []) == true
    end
  end

  describe "mark_as_used/1" do
    test "updates last_used_at timestamp" do
      {:ok, api_key} =
        AdminApiKey.new(%{
          id: Ecto.UUID.generate(),
          key_hash: "$2b$10$abc",
          key_prefix: "ak_dev_vK8mN2",
          name: "Test",
          last_used_at: nil
        })

      assert {:ok, updated} = AdminApiKey.mark_as_used(api_key)
      assert updated.last_used_at != nil
      # updated_at should be set (may be same as created if executed in same second)
      assert updated.updated_at != nil
    end
  end

  describe "valid_scopes/0" do
    test "returns all valid scopes" do
      scopes = AdminApiKey.valid_scopes()

      assert is_list(scopes)
      assert "clients:read" in scopes
      assert "clients:write" in scopes
      assert "clients:delete" in scopes
      assert "users:read" in scopes
      assert "users:write" in scopes
      assert "organizations:read" in scopes
      assert "organizations:write" in scopes
      assert "corpus:read" in scopes
      assert "corpus:write" in scopes
    end
  end
end
