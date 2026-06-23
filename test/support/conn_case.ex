defmodule ThalamusWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use ThalamusWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint ThalamusWeb.Endpoint

      use ThalamusWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import ThalamusWeb.ConnCase
    end
  end

  setup tags do
    Thalamus.DataCase.setup_sandbox(tags)

    Mox.stub(MockCacheService, :get, fn _ -> {:error, :not_found} end)
    Mox.stub(MockCacheService, :set, fn _, _, _ -> :ok end)
    Mox.stub(MockCacheService, :delete, fn _ -> :ok end)

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Helper to log in a user for testing protected routes.
  Creates a test user if user_id is not provided.
  Loads the user and assigns it to conn for LiveView tests.
  """
  def log_in_user(conn, user_id \\ nil) do
    alias Thalamus.Repo
    alias Thalamus.Infrastructure.Persistence.Schemas.UserSchema

    user_id = user_id || create_test_user()

    # Load user from database for assigns
    user = Repo.get(UserSchema, user_id)

    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:user_id, user_id)
    |> Plug.Conn.assign(:current_user, user)
  end

  @doc """
  Helper to authenticate API requests with Bearer token.
  Creates a test user and organization, generates a valid access token,
  and adds it to the Authorization header.

  Returns {conn, user, organization, token}
  """
  def authenticate_api(conn) do
    alias Thalamus.Domain.Entities.{User, Organization}
    alias Thalamus.Domain.ValueObjects.{AccessToken, Scope, UserId}
    alias Thalamus.TestHelpers

    alias Thalamus.Infrastructure.Repositories.{
      PostgreSQLUserRepository,
      PostgreSQLOrganizationRepository,
      PostgreSQLOAuth2ClientRepository,
      PostgreSQLTokenRepository
    }

    # Create organization
    {:ok, org} =
      Organization.new("Test Corp #{:rand.uniform(100_000)}", "owner@test.com", :standard)

    {:ok, org} = PostgreSQLOrganizationRepository.save(org)

    # Create and verify user
    {:ok, user} = User.register("testuser#{:rand.uniform(100_000)}@test.com", "TestPassword123!")
    {:ok, user} = User.verify_email(user)
    user = %{user | organization_id: org.id}
    {:ok, user} = PostgreSQLUserRepository.save(user)

    # Create OAuth2 client
    {:ok, client} = TestHelpers.create_test_client("Test Client", org.id, ["openid", "profile"])
    {:ok, client} = PostgreSQLOAuth2ClientRepository.save(client)

    # Generate access token
    {:ok, openid_scope} = Scope.new("openid")
    {:ok, profile_scope} = Scope.new("profile")
    scopes = [openid_scope, profile_scope]

    {:ok, access_token} = AccessToken.generate(scopes, user.id, 3600)

    # Store token in database
    client_id_string = Thalamus.Domain.ValueObjects.ClientId.to_string(client.id)
    client_uuid = String.replace_prefix(client_id_string, "client_", "")
    user_uuid = UserId.to_string(user.id) |> String.replace_prefix("user_", "")
    org_id_string = Thalamus.Domain.ValueObjects.OrganizationId.to_string(org.id)

    token_data = %{
      token: access_token.token,
      type: :access_token,
      user_id: user_uuid,
      client_id: client_uuid,
      organization_id: org_id_string,
      scopes: ["openid", "profile"],
      expires_at: access_token.expires_at
    }

    :ok = PostgreSQLTokenRepository.store(token_data)

    # Update user with string organization_id for controller use
    user_with_org_string = %{user | organization_id: org_id_string}

    # Add token to connection
    authenticated_conn =
      conn
      |> Plug.Conn.put_req_header("authorization", "Bearer #{access_token.token}")
      |> Plug.Conn.assign(:current_user, user_with_org_string)
      |> Plug.Conn.assign(:organization_id, org_id_string)

    {authenticated_conn, user_with_org_string, org, access_token.token}
  end

  @doc """
  Extracts a bare UUID from an organization id, stripping the "org_" prefix if present.
  Works with %OrganizationId{} structs, "org_uuid" strings, and plain UUID strings.
  """
  def org_uuid(org) do
    id_string =
      case org do
        %{id: %Thalamus.Domain.ValueObjects.OrganizationId{} = vo} ->
          Thalamus.Domain.ValueObjects.OrganizationId.to_string(vo)

        %{id: id} when is_binary(id) ->
          id

        id when is_binary(id) ->
          id

        _ ->
          to_string(org)
      end

    String.replace_prefix(id_string, "org_", "")
  end

  defp create_test_user do
    alias Thalamus.Repo
    alias Thalamus.Infrastructure.Persistence.Schemas.{UserSchema, OrganizationSchema}

    # Create unique test organization for each test
    # This prevents deadlocks when running tests in parallel (async: true)
    org =
      OrganizationSchema.create_changeset(%{
        "name" => "Test Org #{System.unique_integer()}",
        "plan_type" => "free"
      })
      |> Repo.insert!()

    # Hash password before creating user
    password_hash = Bcrypt.hash_pwd_salt("TestPassword123!")

    # Create test user
    user =
      UserSchema.create_changeset(%{
        "email" => "test#{System.unique_integer()}@example.com",
        "password_hash" => password_hash,
        "organization_id" => org.id,
        "status" => "active"
      })
      |> Repo.insert!()

    user.id
  end
end
