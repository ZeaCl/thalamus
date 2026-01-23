defmodule Thalamus.Domain.Entities.RoleTest do
  use ExUnit.Case, async: true

  alias Thalamus.Domain.Entities.Role

  describe "new/1 - valid role creation" do
    test "creates role with all attributes" do
      attrs = %{
        organization_id: "org_abc123",
        name: "Developer",
        description: "Read and write code",
        scopes: ["read:code", "write:code"]
      }

      assert {:ok, %Role{} = role} = Role.new(attrs)
      assert role.organization_id == "org_abc123"
      assert role.name == "Developer"
      assert role.description == "Read and write code"
      assert role.scopes == ["read:code", "write:code"]
      assert %DateTime{} = role.created_at
      assert %DateTime{} = role.updated_at
    end

    test "creates role with minimal attributes" do
      attrs = %{
        organization_id: "org_xyz",
        name: "Viewer",
        scopes: []
      }

      assert {:ok, %Role{} = role} = Role.new(attrs)
      assert role.organization_id == "org_xyz"
      assert role.name == "Viewer"
      assert role.description == nil
      assert role.scopes == []
    end

    test "creates role with id" do
      attrs = %{
        id: "role_123",
        organization_id: "org_abc",
        name: "Admin",
        scopes: ["admin:all"]
      }

      assert {:ok, %Role{} = role} = Role.new(attrs)
      assert role.id == "role_123"
    end

    test "trims role name" do
      attrs = %{
        organization_id: "org_abc",
        name: "  Developer  ",
        scopes: []
      }

      assert {:ok, %Role{} = role} = Role.new(attrs)
      assert role.name == "Developer"
    end

    test "creates role with MCP scopes" do
      attrs = %{
        organization_id: "org_abc",
        name: "MCP Agent",
        scopes: ["mcp:gmail:read", "mcp:slack:channels:list"]
      }

      assert {:ok, %Role{} = role} = Role.new(attrs)
      assert role.scopes == ["mcp:gmail:read", "mcp:slack:channels:list"]
    end
  end

  describe "new/1 - invalid name" do
    test "rejects empty name" do
      attrs = %{
        organization_id: "org_abc",
        name: "",
        scopes: []
      }

      assert {:error, :invalid_name} = Role.new(attrs)
    end

    test "rejects name with only whitespace" do
      attrs = %{
        organization_id: "org_abc",
        name: "   ",
        scopes: []
      }

      assert {:error, :invalid_name} = Role.new(attrs)
    end

    test "rejects name longer than 100 characters" do
      attrs = %{
        organization_id: "org_abc",
        name: String.duplicate("a", 101),
        scopes: []
      }

      assert {:error, :name_too_long} = Role.new(attrs)
    end

    test "accepts name with exactly 100 characters" do
      attrs = %{
        organization_id: "org_abc",
        name: String.duplicate("a", 100),
        scopes: []
      }

      assert {:ok, %Role{}} = Role.new(attrs)
    end
  end

  describe "new/1 - invalid organization_id" do
    test "rejects nil organization_id" do
      attrs = %{
        organization_id: nil,
        name: "Developer",
        scopes: []
      }

      assert {:error, :missing_organization_id} = Role.new(attrs)
    end

    test "rejects empty organization_id" do
      attrs = %{
        organization_id: "",
        name: "Developer",
        scopes: []
      }

      assert {:error, :invalid_organization_id} = Role.new(attrs)
    end
  end

  describe "new/1 - invalid description" do
    test "rejects description longer than 500 characters" do
      attrs = %{
        organization_id: "org_abc",
        name: "Developer",
        description: String.duplicate("a", 501),
        scopes: []
      }

      assert {:error, :description_too_long} = Role.new(attrs)
    end

    test "accepts description with exactly 500 characters" do
      attrs = %{
        organization_id: "org_abc",
        name: "Developer",
        description: String.duplicate("a", 500),
        scopes: []
      }

      assert {:ok, %Role{}} = Role.new(attrs)
    end
  end

  describe "new/1 - invalid scopes" do
    test "rejects invalid scope format" do
      attrs = %{
        organization_id: "org_abc",
        name: "Developer",
        scopes: ["invalid!"]
      }

      assert {:error, :invalid_scope_format} = Role.new(attrs)
    end

    test "rejects mixed valid and invalid scopes" do
      attrs = %{
        organization_id: "org_abc",
        name: "Developer",
        scopes: ["read:code", "INVALID"]
      }

      assert {:error, :invalid_scope_format} = Role.new(attrs)
    end

    test "rejects scope too long" do
      attrs = %{
        organization_id: "org_abc",
        name: "Developer",
        scopes: [String.duplicate("a", 129)]
      }

      assert {:error, :scope_too_long} = Role.new(attrs)
    end

    test "rejects non-list scopes" do
      attrs = %{
        organization_id: "org_abc",
        name: "Developer",
        scopes: "invalid"
      }

      assert {:error, :invalid_scopes} = Role.new(attrs)
    end
  end

  describe "update_scopes/2" do
    setup do
      {:ok, role} =
        Role.new(%{
          organization_id: "org_abc",
          name: "Developer",
          scopes: ["read:code"]
        })

      {:ok, role: role}
    end

    test "updates scopes successfully", %{role: role} do
      new_scopes = ["read:code", "write:code", "delete:code"]
      assert {:ok, %Role{} = updated_role} = Role.update_scopes(role, new_scopes)
      assert updated_role.scopes == new_scopes
      # Updated timestamp should be >= original (may be equal due to fast execution)
      assert DateTime.compare(updated_role.updated_at, role.updated_at) in [:gt, :eq]
    end

    test "updates to empty scopes", %{role: role} do
      assert {:ok, %Role{} = updated_role} = Role.update_scopes(role, [])
      assert updated_role.scopes == []
    end

    test "rejects invalid scope format", %{role: role} do
      new_scopes = ["read:code", "INVALID"]
      assert {:error, :invalid_scope_format} = Role.update_scopes(role, new_scopes)
    end

    test "rejects non-list input", %{role: role} do
      assert {:error, :invalid_scopes} = Role.update_scopes(role, "invalid")
    end

    test "is immutable - returns new struct", %{role: role} do
      original_scopes = role.scopes
      {:ok, updated_role} = Role.update_scopes(role, ["write:code"])

      assert role.scopes == original_scopes
      assert updated_role.scopes == ["write:code"]
    end
  end

  describe "add_scope/2" do
    setup do
      {:ok, role} =
        Role.new(%{
          organization_id: "org_abc",
          name: "Developer",
          scopes: ["read:code"]
        })

      {:ok, role: role}
    end

    test "adds new scope successfully", %{role: role} do
      assert {:ok, %Role{} = updated_role} = Role.add_scope(role, "write:code")
      assert updated_role.scopes == ["read:code", "write:code"]
    end

    test "does not duplicate existing scope", %{role: role} do
      assert {:ok, %Role{} = updated_role} = Role.add_scope(role, "read:code")
      assert updated_role.scopes == ["read:code"]
    end

    test "rejects invalid scope format", %{role: role} do
      assert {:error, :invalid_scope_format} = Role.add_scope(role, "INVALID")
    end

    test "is immutable - returns new struct", %{role: role} do
      original_scopes = role.scopes
      {:ok, updated_role} = Role.add_scope(role, "write:code")

      assert role.scopes == original_scopes
      assert updated_role.scopes == ["read:code", "write:code"]
    end
  end

  describe "remove_scope/2" do
    setup do
      {:ok, role} =
        Role.new(%{
          organization_id: "org_abc",
          name: "Developer",
          scopes: ["read:code", "write:code", "delete:code"]
        })

      {:ok, role: role}
    end

    test "removes scope successfully", %{role: role} do
      assert {:ok, %Role{} = updated_role} = Role.remove_scope(role, "write:code")
      assert updated_role.scopes == ["read:code", "delete:code"]
      # Updated timestamp should be >= original (may be equal due to fast execution)
      assert DateTime.compare(updated_role.updated_at, role.updated_at) in [:gt, :eq]
    end

    test "handles removing non-existent scope", %{role: role} do
      assert {:ok, %Role{} = updated_role} = Role.remove_scope(role, "nonexistent:scope")
      assert updated_role.scopes == ["read:code", "write:code", "delete:code"]
    end

    test "is immutable - returns new struct", %{role: role} do
      original_scopes = role.scopes
      {:ok, updated_role} = Role.remove_scope(role, "write:code")

      assert role.scopes == original_scopes
      assert updated_role.scopes == ["read:code", "delete:code"]
    end
  end

  describe "String.Chars protocol" do
    test "converts Role to string" do
      {:ok, role} =
        Role.new(%{
          organization_id: "org_abc",
          name: "Developer",
          scopes: []
        })

      assert Kernel.to_string(role) == "Role<Developer>"
    end
  end

  describe "Jason.Encoder protocol" do
    test "encodes Role as JSON" do
      now = DateTime.truncate(DateTime.utc_now(), :second)

      {:ok, role} =
        Role.new(%{
          id: "role_123",
          organization_id: "org_abc",
          name: "Developer",
          description: "Dev role",
          scopes: ["read:code"],
          created_at: now,
          updated_at: now
        })

      json = Jason.encode!(role)
      decoded = Jason.decode!(json)

      assert decoded["id"] == "role_123"
      assert decoded["organization_id"] == "org_abc"
      assert decoded["name"] == "Developer"
      assert decoded["description"] == "Dev role"
      assert decoded["scopes"] == ["read:code"]
      assert decoded["created_at"]
      assert decoded["updated_at"]
    end
  end
end
