defmodule ThalamusWeb.Admin.AdminApiKeyControllerTest do
  use ThalamusWeb.ConnCase, async: false

  alias Thalamus.Domain.Services.AdminApiKeyGenerator
  alias Thalamus.Domain.Entities.AdminApiKey
  alias Thalamus.Infrastructure.Repositories.PostgreSQLAdminApiKeyRepository

  setup %{conn: conn} do
    # Setup authenticated connection with super_admin JWT
    # Assign a mock user with super_admin role for testing
    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "Bearer fake_super_admin_jwt")
      |> Plug.Conn.assign(:auth_type, :jwt)
      |> Plug.Conn.assign(:current_user, %{
        id: "admin-user-id",
        email: "admin@test.com",
        roles: [:super_admin]
      })
      |> Plug.Conn.assign(:user_id, "admin-user-id")

    {:ok, conn: conn}
  end

  describe "POST /api/admin/api-keys (create)" do
    test "creates API key with valid parameters", %{conn: conn} do
      params = %{
        "name" => "Test API Key",
        "description" => "Test description",
        "scopes" => ["clients:read", "clients:write"],
        "expires_at" => "2026-12-31T23:59:59Z"
      }

      conn = post(conn, ~p"/api/admin/api-keys", params)

      assert %{
               "data" => %{
                 "id" => id,
                 "api_key" => api_key,
                 "key_prefix" => key_prefix,
                 "name" => "Test API Key",
                 "description" => "Test description",
                 "scopes" => ["clients:read", "clients:write"],
                 "is_active" => true
               },
               "message" => message
             } = json_response(conn, 201)

      assert is_binary(id)
      assert is_binary(api_key)
      assert String.starts_with?(api_key, "ak_")
      assert is_binary(key_prefix)
      assert String.length(key_prefix) == 13
      assert String.contains?(message, "IMPORTANT")
    end

    test "creates API key without optional fields", %{conn: conn} do
      params = %{
        "name" => "Minimal API Key",
        "scopes" => []
      }

      conn = post(conn, ~p"/api/admin/api-keys", params)

      assert %{
               "data" => %{
                 "name" => "Minimal API Key",
                 "scopes" => [],
                 "is_active" => true
               }
             } = json_response(conn, 201)
    end

    test "returns error for missing name", %{conn: conn} do
      params = %{
        "scopes" => ["clients:read"]
      }

      conn = post(conn, ~p"/api/admin/api-keys", params)

      assert %{"error" => "Missing required parameter: name"} = json_response(conn, 400)
    end

    test "returns error for invalid scopes", %{conn: conn} do
      params = %{
        "name" => "Test API Key",
        "scopes" => ["clients:read", "invalid:scope", "another:invalid"]
      }

      conn = post(conn, ~p"/api/admin/api-keys", params)

      assert %{
               "error" => "Invalid scopes",
               "details" => details,
               "valid_scopes" => valid_scopes
             } = json_response(conn, 400)

      assert String.contains?(details, "invalid:scope")
      assert is_list(valid_scopes)
    end

    test "returns error for non-list scopes", %{conn: conn} do
      params = %{
        "name" => "Test API Key",
        "scopes" => "not_a_list"
      }

      conn = post(conn, ~p"/api/admin/api-keys", params)

      assert %{"error" => "Failed to create API key"} = json_response(conn, 400)
    end
  end

  describe "GET /api/admin/api-keys (index)" do
    setup do
      # Create some test API keys
      {:ok, key1} = create_test_api_key("Key 1", ["clients:read"])
      {:ok, key2} = create_test_api_key("Key 2", ["clients:write"], false)
      {:ok, _saved1} = PostgreSQLAdminApiKeyRepository.save(key1)
      {:ok, _saved2} = PostgreSQLAdminApiKeyRepository.save(key2)

      :ok
    end

    test "lists all API keys", %{conn: conn} do
      conn = get(conn, ~p"/api/admin/api-keys")

      assert %{
               "data" => keys,
               "meta" => %{"count" => count}
             } = json_response(conn, 200)

      assert is_list(keys)
      assert count >= 2

      # Verify structure (should NOT include full api_key)
      first_key = List.first(keys)
      assert Map.has_key?(first_key, "id")
      assert Map.has_key?(first_key, "key_prefix")
      assert Map.has_key?(first_key, "name")
      assert Map.has_key?(first_key, "scopes")
      refute Map.has_key?(first_key, "api_key")
    end

    test "filters by is_active", %{conn: conn} do
      conn = get(conn, ~p"/api/admin/api-keys?is_active=true")

      assert %{"data" => keys} = json_response(conn, 200)

      assert Enum.all?(keys, fn key -> key["is_active"] == true end)
    end
  end

  describe "GET /api/admin/api-keys/:id (show)" do
    setup do
      {:ok, api_key} = create_test_api_key("Show Test Key", ["clients:read"])
      {:ok, saved} = PostgreSQLAdminApiKeyRepository.save(api_key)

      {:ok, api_key: saved}
    end

    test "shows specific API key", %{conn: conn, api_key: api_key} do
      conn = get(conn, ~p"/api/admin/api-keys/#{api_key.id}")

      assert %{
               "data" => %{
                 "id" => id,
                 "name" => "Show Test Key",
                 "scopes" => ["clients:read"]
               }
             } = json_response(conn, 200)

      assert id == api_key.id
    end

    test "returns 404 for non-existent API key", %{conn: conn} do
      fake_id = Ecto.UUID.generate()
      conn = get(conn, ~p"/api/admin/api-keys/#{fake_id}")

      assert %{"error" => "API key not found"} = json_response(conn, 404)
    end
  end

  describe "DELETE /api/admin/api-keys/:id (delete)" do
    setup do
      {:ok, api_key} = create_test_api_key("Delete Test Key", ["clients:read"])
      {:ok, saved} = PostgreSQLAdminApiKeyRepository.save(api_key)

      {:ok, api_key: saved}
    end

    test "revokes API key", %{conn: conn, api_key: api_key} do
      conn = delete(conn, ~p"/api/admin/api-keys/#{api_key.id}")

      assert %{
               "message" => "API key revoked successfully",
               "data" => %{
                 "id" => id,
                 "is_active" => false
               }
             } = json_response(conn, 200)

      assert id == api_key.id

      # Verify in database
      {:ok, updated} = PostgreSQLAdminApiKeyRepository.find_by_id(api_key.id)
      assert updated.is_active == false
    end

    test "returns 404 for non-existent API key", %{conn: conn} do
      fake_id = Ecto.UUID.generate()
      conn = delete(conn, ~p"/api/admin/api-keys/#{fake_id}")

      assert %{"error" => "API key not found"} = json_response(conn, 404)
    end
  end

  describe "POST /api/admin/api-keys/:id/rotate (rotate)" do
    setup do
      {:ok, api_key} = create_test_api_key("Rotate Test Key", ["clients:read"])
      {:ok, saved} = PostgreSQLAdminApiKeyRepository.save(api_key)

      {:ok, api_key: saved}
    end

    test "rotates API key", %{conn: conn, api_key: api_key} do
      _old_prefix = api_key.key_prefix
      old_hash = api_key.key_hash

      conn = post(conn, ~p"/api/admin/api-keys/#{api_key.id}/rotate")

      assert %{
               "data" => %{
                 "id" => id,
                 "api_key" => new_api_key,
                 "key_prefix" => new_prefix,
                 "name" => "Rotate Test Key"
               },
               "message" => message
             } = json_response(conn, 200)

      assert id == api_key.id
      assert is_binary(new_api_key)
      assert String.starts_with?(new_api_key, "ak_")
      # Verify that a new key was generated (prefix may coincidentally be the same, but unlikely)
      assert is_binary(new_prefix)
      assert String.length(new_prefix) == 13
      assert String.contains?(message, "old API key is no longer valid")

      # Verify in database
      {:ok, updated} = PostgreSQLAdminApiKeyRepository.find_by_id(api_key.id)
      assert updated.key_prefix == new_prefix
      assert updated.key_hash != old_hash
    end

    test "returns 404 for non-existent API key", %{conn: conn} do
      fake_id = Ecto.UUID.generate()
      conn = post(conn, ~p"/api/admin/api-keys/#{fake_id}/rotate")

      assert %{"error" => "API key not found"} = json_response(conn, 404)
    end
  end

  # Helper functions

  defp create_test_api_key(name, scopes, is_active \\ true) do
    %{key_prefix: key_prefix, key_hash: key_hash} = AdminApiKeyGenerator.generate()

    AdminApiKey.new(%{
      id: Ecto.UUID.generate(),
      key_hash: key_hash,
      key_prefix: key_prefix,
      name: name,
      scopes: scopes,
      is_active: is_active
    })
  end
end
