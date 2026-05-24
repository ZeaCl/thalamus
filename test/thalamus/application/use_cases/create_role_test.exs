defmodule Thalamus.Application.UseCases.CreateRoleTest do
  use ExUnit.Case, async: true
  import Mox

  alias Thalamus.Application.UseCases.CreateRole
  alias Thalamus.Domain.Entities.Role

  setup :verify_on_exit!

  @deps %{
    role_repository: Thalamus.MockRoleRepository
  }

  describe "execute/2" do
    test "successfully creates a new role" do
      org_id = Ecto.UUID.generate()

      request = %{
        organization_id: org_id,
        name: "Developer",
        description: "Development team",
        scopes: ["read:code", "write:code"]
      }

      Thalamus.MockRoleRepository
      |> expect(:find_by_name, fn ^org_id, "Developer" -> {:error, :not_found} end)
      |> expect(:save, fn role ->
        assert %Role{} = role
        assert role.name == "Developer"
        assert role.scopes == ["read:code", "write:code"]
        {:ok, %{role | id: Ecto.UUID.generate()}}
      end)

      assert {:ok, role} = CreateRole.execute(request, @deps)
      assert role.name == "Developer"
      assert role.id != nil
    end

    test "returns error for duplicate role name" do
      org_id = Ecto.UUID.generate()

      existing_role = %Role{
        id: Ecto.UUID.generate(),
        organization_id: org_id,
        name: "Admin",
        scopes: ["admin:all"],
        description: "Admin"
      }

      request = %{
        organization_id: org_id,
        name: "Admin",
        description: "New admin",
        scopes: ["admin:new"]
      }

      Thalamus.MockRoleRepository
      |> expect(:find_by_name, fn ^org_id, "Admin" -> {:ok, existing_role} end)

      assert {:error, :duplicate_role_name} = CreateRole.execute(request, @deps)
    end

    test "checks for duplicate case-insensitively" do
      org_id = Ecto.UUID.generate()

      existing_role = %Role{
        id: Ecto.UUID.generate(),
        organization_id: org_id,
        name: "Manager",
        scopes: ["manage:team"],
        description: "Manager"
      }

      request = %{
        organization_id: org_id,
        name: "MANAGER",
        description: "New manager",
        scopes: ["manage:new"]
      }

      Thalamus.MockRoleRepository
      |> expect(:find_by_name, fn ^org_id, "MANAGER" -> {:ok, existing_role} end)

      assert {:error, :duplicate_role_name} = CreateRole.execute(request, @deps)
    end

    test "validates role name format" do
      org_id = Ecto.UUID.generate()

      request = %{
        organization_id: org_id,
        name: "",
        description: "Invalid",
        scopes: ["some:scope"]
      }

      # Role.new should fail validation
      assert {:error, :invalid_name} = CreateRole.execute(request, @deps)
    end

    test "validates scope format" do
      org_id = Ecto.UUID.generate()

      request = %{
        organization_id: org_id,
        name: "ValidName",
        description: "Test",
        # Invalid: starts with capital, contains special char
        scopes: ["Invalid!Scope"]
      }

      # Note: find_by_name is NOT called because validation fails first

      # Should fail because scope doesn't match the required format
      assert {:error, :invalid_scope_format} = CreateRole.execute(request, @deps)
    end

    test "allows creation with empty description" do
      org_id = Ecto.UUID.generate()

      request = %{
        organization_id: org_id,
        name: "MinimalRole",
        description: nil,
        scopes: ["read:minimal"]
      }

      Thalamus.MockRoleRepository
      |> expect(:find_by_name, fn _, _ -> {:error, :not_found} end)
      |> expect(:save, fn role ->
        assert role.description == nil
        {:ok, %{role | id: Ecto.UUID.generate()}}
      end)

      assert {:ok, _role} = CreateRole.execute(request, @deps)
    end

    test "allows creation with empty scopes list" do
      org_id = Ecto.UUID.generate()

      request = %{
        organization_id: org_id,
        name: "NoScopesRole",
        description: "No scopes yet",
        scopes: []
      }

      Thalamus.MockRoleRepository
      |> expect(:find_by_name, fn _, _ -> {:error, :not_found} end)
      |> expect(:save, fn role ->
        assert role.scopes == []
        {:ok, %{role | id: Ecto.UUID.generate()}}
      end)

      assert {:ok, _role} = CreateRole.execute(request, @deps)
    end
  end
end
