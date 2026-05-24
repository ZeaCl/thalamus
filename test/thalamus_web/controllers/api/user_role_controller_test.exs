defmodule ThalamusWeb.API.UserRoleControllerTest do
  use ThalamusWeb.ConnCase, async: true

  alias Thalamus.Infrastructure.Persistence.Schemas.{
    RoleSchema,
    UserRoleSchema,
    OrganizationSchema,
    UserSchema
  }

  alias Thalamus.Repo

  setup %{conn: conn} do
    {conn, user, org, _token} = authenticate_api(conn)
    conn = put_req_header(conn, "accept", "application/json")

    {:ok, conn: conn, organization: org, current_user: user}
  end

  describe "POST /api/users/:user_id/roles" do
    test "assigns role to user", %{conn: conn, organization: org} do
      target_user = insert_user(org)
      role = insert_role(org, "Developer", ["read:code", "write:code"])

      params = %{"role_id" => role.id}
      conn = post(conn, ~p"/api/users/#{target_user.id}/roles", params)

      assert %{"data" => user_role} = json_response(conn, 201)
      assert user_role["user_id"] == target_user.id
      assert user_role["role_id"] == role.id

      # Verify in database
      db_assignment = Repo.get_by(UserRoleSchema, user_id: target_user.id, role_id: role.id)
      assert db_assignment != nil
    end

    test "returns error when user not found", %{conn: conn, organization: org} do
      role = insert_role(org, "Admin", ["admin:all"])
      fake_user_id = Ecto.UUID.generate()

      params = %{"role_id" => role.id}
      conn = post(conn, ~p"/api/users/#{fake_user_id}/roles", params)

      assert %{"error" => "not_found"} = json_response(conn, 404)
    end

    test "returns error when role not found", %{conn: conn, organization: org} do
      target_user = insert_user(org)
      fake_role_id = Ecto.UUID.generate()

      params = %{"role_id" => fake_role_id}
      conn = post(conn, ~p"/api/users/#{target_user.id}/roles", params)

      assert %{"error" => "not_found"} = json_response(conn, 404)
    end

    test "returns error when user is not active", %{conn: conn, organization: org} do
      suspended_user = insert_user(org, :suspended)
      role = insert_role(org, "Manager", ["manage:team"])

      params = %{"role_id" => role.id}
      conn = post(conn, ~p"/api/users/#{suspended_user.id}/roles", params)

      assert %{"error" => "user_not_active"} = json_response(conn, 422)
    end

    test "returns error when user and role in different organizations", %{conn: conn} do
      org1 = insert_organization()
      org2 = insert_organization()

      user_in_org1 = insert_user(org1)
      role_in_org2 = insert_role(org2, "CrossOrg", ["scope"])

      params = %{"role_id" => role_in_org2.id}
      conn = post(conn, ~p"/api/users/#{user_in_org1.id}/roles", params)

      assert %{"error" => "organization_mismatch"} = json_response(conn, 403)
    end
  end

  describe "DELETE /api/users/:user_id/roles/:role_id" do
    test "revokes role from user", %{conn: conn, organization: org} do
      target_user = insert_user(org)
      role = insert_role(org, "Reviewer", ["review:pr"])
      insert_user_role(target_user, role)

      conn = delete(conn, ~p"/api/users/#{target_user.id}/roles/#{role.id}")

      assert %{"data" => result} = json_response(conn, 200)
      assert result["user_id"] == target_user.id
      assert result["role_id"] == role.id

      # Verify removal from database
      refute Repo.get_by(UserRoleSchema, user_id: target_user.id, role_id: role.id)
    end

    test "returns error when assignment doesn't exist", %{conn: conn, organization: org} do
      target_user = insert_user(org)
      role = insert_role(org, "NeverAssigned", ["scope"])

      conn = delete(conn, ~p"/api/users/#{target_user.id}/roles/#{role.id}")

      assert %{"error" => "assignment_not_found"} = json_response(conn, 404)
    end
  end

  describe "GET /api/users/:user_id/roles" do
    test "lists all roles assigned to user", %{conn: conn, organization: org} do
      target_user = insert_user(org)
      role1 = insert_role(org, "Developer", ["read:code", "write:code"])
      role2 = insert_role(org, "Reviewer", ["review:pr"])
      role3 = insert_role(org, "Unassigned", ["other:scope"])

      insert_user_role(target_user, role1)
      insert_user_role(target_user, role2)

      conn = get(conn, ~p"/api/users/#{target_user.id}/roles")

      assert %{"data" => roles} = json_response(conn, 200)
      assert length(roles) == 2

      role_ids = Enum.map(roles, & &1["id"])
      assert role1.id in role_ids
      assert role2.id in role_ids
      refute role3.id in role_ids
    end

    test "returns empty list when user has no roles", %{conn: conn, organization: org} do
      target_user = insert_user(org)

      conn = get(conn, ~p"/api/users/#{target_user.id}/roles")

      assert %{"data" => []} = json_response(conn, 200)
    end
  end

  describe "GET /api/users/:user_id/effective-scopes" do
    test "returns effective scopes for user with multiple roles", %{conn: conn, organization: org} do
      target_user = insert_user(org)
      role1 = insert_role(org, "Developer", ["read:code", "write:code"])
      role2 = insert_role(org, "Reviewer", ["read:code", "review:pr"])

      insert_user_role(target_user, role1)
      insert_user_role(target_user, role2)

      conn = get(conn, ~p"/api/users/#{target_user.id}/effective-scopes")

      assert %{"data" => %{"user_id" => user_id, "effective_scopes" => scopes}} =
               json_response(conn, 200)

      assert user_id == target_user.id

      # Should have union of all scopes (deduplicated)
      assert Enum.sort(scopes) == ["read:code", "review:pr", "write:code"]
    end

    test "returns empty scopes for user with no roles", %{conn: conn, organization: org} do
      target_user = insert_user(org)

      conn = get(conn, ~p"/api/users/#{target_user.id}/effective-scopes")

      assert %{"data" => %{"effective_scopes" => []}} = json_response(conn, 200)
    end

    test "deduplicates scopes from overlapping roles", %{conn: conn, organization: org} do
      target_user = insert_user(org)
      role1 = insert_role(org, "Admin", ["read:all", "write:all"])
      role2 = insert_role(org, "SuperAdmin", ["read:all", "write:all", "delete:all"])

      insert_user_role(target_user, role1)
      insert_user_role(target_user, role2)

      conn = get(conn, ~p"/api/users/#{target_user.id}/effective-scopes")

      assert %{"data" => %{"effective_scopes" => scopes}} = json_response(conn, 200)
      # Should have unique scopes only
      assert Enum.sort(scopes) == ["delete:all", "read:all", "write:all"]
      assert length(scopes) == length(Enum.uniq(scopes))
    end

    test "uses cache on second request", %{conn: conn, organization: org} do
      target_user = insert_user(org)
      role = insert_role(org, "Cached", ["cached:scope"])
      insert_user_role(target_user, role)

      # First request - should compute and cache
      conn1 = get(conn, ~p"/api/users/#{target_user.id}/effective-scopes")
      assert %{"data" => %{"effective_scopes" => scopes1}} = json_response(conn1, 200)

      # Second request - should use cache
      conn2 =
        get(build_conn() |> recycle_conn(conn), ~p"/api/users/#{target_user.id}/effective-scopes")

      assert %{"data" => %{"effective_scopes" => scopes2}} = json_response(conn2, 200)

      assert scopes1 == scopes2
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

  defp insert_user(org, status \\ :active) do
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
      status: status,
      inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
      updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end

  defp insert_role(org, name, scopes) do
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
    Repo.insert!(%UserRoleSchema{
      user_id: user.id,
      role_id: role.id,
      assigned_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end

  defp recycle_conn(new_conn, old_conn) do
    # Copy the authorization header from old_conn
    auth_header = get_req_header(old_conn, "authorization") |> List.first()

    new_conn
    |> put_req_header("accept", "application/json")
    |> put_req_header("authorization", auth_header || "")
    |> assign(:current_user, old_conn.assigns.current_user)
    |> assign(:organization_id, old_conn.assigns.organization_id)
  end
end
