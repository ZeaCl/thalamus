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
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Helper to log in a user for testing protected routes.
  Creates a test user if user_id is not provided.
  """
  def log_in_user(conn, user_id \\ nil) do
    user_id = user_id || create_test_user()

    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:user_id, user_id)
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
