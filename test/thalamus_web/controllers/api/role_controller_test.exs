defmodule ThalamusWeb.API.RoleControllerTest do
  use ThalamusWeb.ConnCase, async: true

  alias Thalamus.Infrastructure.Persistence.Schemas.{RoleSchema, OrganizationSchema, UserSchema}
  alias Thalamus.Repo

  setup %{conn: conn} do
    {conn, user, org, _token} = authenticate_api(conn)
    conn = put_req_header(conn, "accept", "application/json")

    {:ok, conn: conn, organization: org, user: user}
  end

  describe "GET /api/roles" do
    test "lists all roles for organization", %{conn: conn, organization: org} do
      role1 = insert_role(org, "Admin", ["admin:all"])
      role2 = insert_role(org, "Developer", ["read:code", "write:code"])

      # Create role in different org (should not be returned)
      other_org = insert_organization()
      _other_role = insert_role(other_org, "Other", ["other:scope"])

      conn = get(conn, ~p"/api/roles")

      assert %{"data" => roles} = json_response(conn, 200)
      assert length(roles) == 2

      role_ids = Enum.map(roles, & &1["id"])
      assert role1.id in role_ids
      assert role2.id in role_ids
    end

    test "returns empty list when no roles exist", %{conn: conn} do
      conn = get(conn, ~p"/api/roles")

      assert %{"data" => []} = json_response(conn, 200)
    end
  end

  describe "POST /api/roles" do
    test "creates role with valid data", %{conn: conn, organization: org} do
      params = %{
        "name" => "Manager",
        "description" => "Team manager",
        "scopes" => ["manage:team", "read:reports"]
      }

      conn = post(conn, ~p"/api/roles", params)

      assert %{"data" => role} = json_response(conn, 201)
      assert role["name"] == "Manager"
      assert role["description"] == "Team manager"
      assert role["scopes"] == ["manage:team", "read:reports"]
      org_id_string = Thalamus.Domain.ValueObjects.OrganizationId.to_string(org.id)
      assert role["organization_id"] == org_id_string

      # Verify in database
      db_role = Repo.get(RoleSchema, role["id"])
      assert db_role.name == "Manager"
    end

    test "creates role without description", %{conn: conn} do
      params = %{
        "name" => "Minimal",
        "scopes" => ["read:data"]
      }

      conn = post(conn, ~p"/api/roles", params)

      assert %{"data" => role} = json_response(conn, 201)
      assert role["name"] == "Minimal"
      assert role["description"] == nil
    end

    test "creates role with empty scopes", %{conn: conn} do
      params = %{
        "name" => "NoScopes",
        "description" => "No scopes yet",
        "scopes" => []
      }

      conn = post(conn, ~p"/api/roles", params)

      assert %{"data" => role} = json_response(conn, 201)
      assert role["scopes"] == []
    end

    test "returns error for duplicate role name", %{conn: conn, organization: org} do
      insert_role(org, "Duplicate", ["scope:one"])

      params = %{
        "name" => "Duplicate",
        "description" => "Another duplicate",
        "scopes" => ["scope:two"]
      }

      conn = post(conn, ~p"/api/roles", params)

      assert %{"error" => "duplicate_role_name"} = json_response(conn, 422)
    end

    test "returns error for invalid role name", %{conn: conn} do
      params = %{
        "name" => "",
        "scopes" => ["valid:scope"]
      }

      conn = post(conn, ~p"/api/roles", params)

      assert %{"error" => "invalid_role_name"} = json_response(conn, 422)
    end

    test "returns error for invalid scope format", %{conn: conn} do
      params = %{
        "name" => "ValidName",
        "scopes" => ["Invalid-With-Uppercase", "has spaces", "special@chars!"]
      }

      conn = post(conn, ~p"/api/roles", params)

      assert %{"error" => "invalid_scope_format"} = json_response(conn, 422)
    end
  end

  describe "GET /api/roles/:id" do
    test "shows role when it exists", %{conn: conn, organization: org} do
      role = insert_role(org, "Viewer", ["read:all"])

      conn = get(conn, ~p"/api/roles/#{role.id}")

      assert %{"data" => returned_role} = json_response(conn, 200)
      assert returned_role["id"] == role.id
      assert returned_role["name"] == "Viewer"
      assert returned_role["scopes"] == ["read:all"]
    end

    test "returns forbidden for role in different organization", %{conn: conn} do
      other_org = insert_organization()
      role = insert_role(other_org, "Private", ["private:scope"])

      conn = get(conn, ~p"/api/roles/#{role.id}")

      assert %{"error" => "forbidden"} = json_response(conn, 403)
    end

    test "returns not found when role doesn't exist", %{conn: conn} do
      fake_id = Ecto.UUID.generate()

      conn = get(conn, ~p"/api/roles/#{fake_id}")

      assert %{"error" => "role not found"} = json_response(conn, 404)
    end
  end

  describe "PATCH /api/roles/:id" do
    test "updates role scopes", %{conn: conn, organization: org} do
      role = insert_role(org, "Updatable", ["read:old"])

      params = %{"scopes" => ["read:new", "write:new"]}
      conn = patch(conn, ~p"/api/roles/#{role.id}", params)

      assert %{"data" => updated_role} = json_response(conn, 200)
      assert updated_role["scopes"] == ["read:new", "write:new"]
      assert updated_role["id"] == role.id

      # Verify in database
      db_role = Repo.get(RoleSchema, role.id)
      assert db_role.scopes == ["read:new", "write:new"]
    end

    test "returns invalidated cache count", %{conn: conn, organization: org} do
      role = insert_role(org, "WithUsers", ["scope:one"])
      user1 = insert_user(org)
      user2 = insert_user(org)
      insert_user_role(user1, role)
      insert_user_role(user2, role)

      params = %{"scopes" => ["scope:two"]}
      conn = patch(conn, ~p"/api/roles/#{role.id}", params)

      assert %{"invalidated_cache_for" => count} = json_response(conn, 200)
      assert count == 2
    end

    test "returns forbidden for role in different organization", %{conn: conn} do
      other_org = insert_organization()
      role = insert_role(other_org, "Private", ["private:scope"])

      params = %{"scopes" => ["new:scope"]}
      conn = patch(conn, ~p"/api/roles/#{role.id}", params)

      assert %{"error" => "forbidden"} = json_response(conn, 403)
    end

    test "returns not found when role doesn't exist", %{conn: conn} do
      fake_id = Ecto.UUID.generate()

      params = %{"scopes" => ["new:scope"]}
      conn = patch(conn, ~p"/api/roles/#{fake_id}", params)

      assert %{"error" => "role not found"} = json_response(conn, 404)
    end
  end

  describe "DELETE /api/roles/:id" do
    test "deletes role", %{conn: conn, organization: org} do
      role = insert_role(org, "ToDelete", ["delete:me"])

      conn = delete(conn, ~p"/api/roles/#{role.id}")

      assert %{"deleted" => true, "deleted_role_id" => deleted_id} = json_response(conn, 200)
      assert deleted_id == role.id

      # Verify deletion
      refute Repo.get(RoleSchema, role.id)
    end

    test "cascades to user_roles", %{conn: conn, organization: org} do
      role = insert_role(org, "WithAssignments", ["scope"])
      user = insert_user(org)
      user_role = insert_user_role(user, role)

      conn = delete(conn, ~p"/api/roles/#{role.id}")

      assert json_response(conn, 200)

      # Verify cascade deletion
      refute Repo.get(RoleSchema, role.id)

      refute Repo.get_by(Thalamus.Infrastructure.Persistence.Schemas.UserRoleSchema,
               user_id: user_role.user_id,
               role_id: role.id
             )
    end

    test "returns invalidated cache count", %{conn: conn, organization: org} do
      role = insert_role(org, "WithManyUsers", ["scope"])
      user1 = insert_user(org)
      user2 = insert_user(org)
      user3 = insert_user(org)
      insert_user_role(user1, role)
      insert_user_role(user2, role)
      insert_user_role(user3, role)

      conn = delete(conn, ~p"/api/roles/#{role.id}")

      assert %{"invalidated_cache_for" => count} = json_response(conn, 200)
      assert count == 3
    end

    test "returns forbidden for role in different organization", %{conn: conn} do
      other_org = insert_organization()
      role = insert_role(other_org, "Private", ["private:scope"])

      conn = delete(conn, ~p"/api/roles/#{role.id}")

      assert %{"error" => "forbidden"} = json_response(conn, 403)
    end

    test "returns not found when role doesn't exist", %{conn: conn} do
      fake_id = Ecto.UUID.generate()

      conn = delete(conn, ~p"/api/roles/#{fake_id}")

      assert %{"error" => "role not found"} = json_response(conn, 404)
    end
  end

  # Test helpers

  defp insert_organization do
    Repo.insert!(%OrganizationSchema{
      id: Ecto.UUID.generate(),
      name: "Test Org #{:rand.uniform(10000)}",
      status: :active,
      plan_type: :free,
      max_users: 10,
      max_api_calls_per_month: 10000,
      support_level: :community,
      api_calls_reset_at: DateTime.utc_now() |> DateTime.truncate(:second),
      inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
      updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end

  defp insert_user(org) do
    # Handle both Organization entity (from authenticate_api) and OrganizationSchema
    org_id =
      case org do
        %{id: %Thalamus.Domain.ValueObjects.OrganizationId{} = org_id_vo} ->
          Thalamus.Domain.ValueObjects.OrganizationId.to_string(org_id_vo)

        %{id: id} when is_binary(id) ->
          id

        _ ->
          org.id
      end

    Repo.insert!(%UserSchema{
      id: Ecto.UUID.generate(),
      organization_id: org_id,
      email: "user#{:rand.uniform(10000)}@example.com",
      password_hash: Bcrypt.hash_pwd_salt("password123"),
      status: :active,
      inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
      updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end

  defp insert_role(org, name, scopes) do
    # Handle both Organization entity (from authenticate_api) and OrganizationSchema
    org_id =
      case org do
        %{id: %Thalamus.Domain.ValueObjects.OrganizationId{} = org_id_vo} ->
          # Extract UUID from OrganizationId value object
          Thalamus.Domain.ValueObjects.OrganizationId.to_string(org_id_vo)

        %{id: id} when is_binary(id) ->
          id

        _ ->
          org.id
      end

    Repo.insert!(%RoleSchema{
      id: Ecto.UUID.generate(),
      organization_id: org_id,
      name: name,
      description: "Test role: #{name}",
      scopes: scopes,
      inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
      updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end

  defp insert_user_role(user, role) do
    Repo.insert!(%Thalamus.Infrastructure.Persistence.Schemas.UserRoleSchema{
      user_id: user.id,
      role_id: role.id,
      assigned_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end
end
