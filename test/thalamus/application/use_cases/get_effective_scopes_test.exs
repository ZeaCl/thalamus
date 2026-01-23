defmodule Thalamus.Application.UseCases.GetEffectiveScopesTest do
  use ExUnit.Case, async: true
  import Mox

  alias Thalamus.Application.UseCases.GetEffectiveScopes
  alias Thalamus.Domain.Entities.Role

  setup :verify_on_exit!

  @deps %{
    role_repository: Thalamus.MockRoleRepository,
    cache_service: Thalamus.MockCacheService
  }

  describe "execute/2" do
    test "returns effective scopes from cache when available" do
      user_id = Ecto.UUID.generate()
      cached_scopes = ["read:code", "write:code", "read:docs"]

      Thalamus.MockCacheService
      |> expect(:get, fn "user_effective_scopes:" <> ^user_id ->
        {:ok, cached_scopes}
      end)

      assert {:ok, scopes} = GetEffectiveScopes.execute(user_id, @deps)
      assert scopes == cached_scopes
    end

    test "computes and caches effective scopes when not in cache" do
      user_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()

      role1 = %Role{
        id: Ecto.UUID.generate(),
        organization_id: org_id,
        name: "Developer",
        scopes: ["read:code", "write:code"],
        description: "Dev role"
      }

      role2 = %Role{
        id: Ecto.UUID.generate(),
        organization_id: org_id,
        name: "Reviewer",
        scopes: ["read:code", "review:pr"],
        description: "Reviewer role"
      }

      Thalamus.MockCacheService
      |> expect(:get, fn "user_effective_scopes:" <> ^user_id -> {:error, :not_found} end)
      |> expect(:set, fn cache_key, scopes, ttl ->
        assert cache_key == "user_effective_scopes:#{user_id}"
        assert Enum.sort(scopes) == ["read:code", "review:pr", "write:code"]
        assert ttl == 300_000
        :ok
      end)

      Thalamus.MockRoleRepository
      |> expect(:get_user_roles, fn ^user_id -> {:ok, [role1, role2]} end)

      assert {:ok, scopes} = GetEffectiveScopes.execute(user_id, @deps)
      assert Enum.sort(scopes) == ["read:code", "review:pr", "write:code"]
    end

    test "returns empty list when user has no roles" do
      user_id = Ecto.UUID.generate()

      Thalamus.MockCacheService
      |> expect(:get, fn _ -> {:error, :not_found} end)
      |> expect(:set, fn _, scopes, _ ->
        assert scopes == []
        :ok
      end)

      Thalamus.MockRoleRepository
      |> expect(:get_user_roles, fn ^user_id -> {:ok, []} end)

      assert {:ok, []} = GetEffectiveScopes.execute(user_id, @deps)
    end

    test "deduplicates scopes from multiple roles" do
      user_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()

      role1 = %Role{
        id: Ecto.UUID.generate(),
        organization_id: org_id,
        name: "Admin",
        scopes: ["read:all", "write:all"],
        description: "Admin"
      }

      role2 = %Role{
        id: Ecto.UUID.generate(),
        organization_id: org_id,
        name: "SuperAdmin",
        scopes: ["read:all", "write:all", "delete:all"],
        description: "SuperAdmin"
      }

      Thalamus.MockCacheService
      |> expect(:get, fn _ -> {:error, :not_found} end)
      |> expect(:set, fn _, scopes, _ ->
        # Should have unique scopes only
        assert Enum.sort(scopes) == ["delete:all", "read:all", "write:all"]
        :ok
      end)

      Thalamus.MockRoleRepository
      |> expect(:get_user_roles, fn ^user_id -> {:ok, [role1, role2]} end)

      assert {:ok, scopes} = GetEffectiveScopes.execute(user_id, @deps)
      assert length(scopes) == 3
      assert Enum.uniq(scopes) == scopes
    end

    test "handles cache errors gracefully" do
      user_id = Ecto.UUID.generate()

      Thalamus.MockCacheService
      |> expect(:get, fn _ -> {:error, :connection_failed} end)
      |> expect(:set, fn _, _, _ -> {:error, :connection_failed} end)

      Thalamus.MockRoleRepository
      |> expect(:get_user_roles, fn ^user_id -> {:ok, []} end)

      # Should still return scopes even if cache fails
      assert {:ok, []} = GetEffectiveScopes.execute(user_id, @deps)
    end
  end
end
