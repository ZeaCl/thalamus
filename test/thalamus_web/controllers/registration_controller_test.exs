defmodule ThalamusWeb.RegistrationControllerTest do
  use ThalamusWeb.ConnCase

  alias Thalamus.Repo
  alias Thalamus.Infrastructure.Persistence.Schemas.{UserSchema, OrganizationSchema}
  require Ecto.Query

  setup %{conn: conn} do
    {:ok, conn: conn}
  end

  describe "GET /register" do
    test "renders registration form", %{conn: conn} do
      conn = get(conn, "/register")
      assert html_response(conn, 200) =~ "Create your account"
    end
  end

  describe "POST /register" do
    test "creates a new user and organization and redirects to home without OAuth context", %{conn: conn} do
      valid_attrs = %{
        "email" => "test@example.com",
        "name" => "Test User",
        "password" => "password123!@1aA",
        "password_confirmation" => "password123!@1aA"
      }

      conn = post(conn, "/register", %{"registration" => valid_attrs})
      assert redirected_to(conn) == "http://zea.localhost/dashboard"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "Welcome to Thalamus! Your account has been created."

      # Verify user in database
      user = Repo.get_by(UserSchema, email: "test@example.com")
      assert user != nil
      assert user.name == "Test User"
      
      # Verify organization in database
      org = Repo.one!(Ecto.Query.where(OrganizationSchema, name: "Test User's Organization"))
      assert org.owner_email == "test@example.com"
      
      # Verify user is associated with org
      assert user.organization_id == org.id
    end

    test "creates a new user and redirects back to OAuth authorization if context exists", %{conn: conn} do
      valid_attrs = %{
        "email" => "test2@example.com",
        "name" => "Test User 2",
        "password" => "password123!@1aA",
        "password_confirmation" => "password123!@1aA"
      }

      authorization_request = %{
        "client_id" => "test_client",
        "redirect_uri" => "https://app.com/callback",
        "response_type" => "code",
        "state" => "xyz"
      }

      conn = 
        conn
        |> init_test_session(authorization_request: authorization_request)
        |> post("/register", %{"registration" => valid_attrs})

      assert redirected_to(conn) == "/oauth/authorize?client_id=test_client&redirect_uri=https%3A%2F%2Fapp.com%2Fcallback&response_type=code&state=xyz"
      
      # Verify user in database
      user = Repo.get_by(UserSchema, email: "test2@example.com")
      assert user != nil
    end

    test "rolls back transaction completely if password confirmation does not match", %{conn: conn} do
      invalid_attrs = %{
        "email" => "rollback_test@example.com",
        "name" => "Rollback User",
        "password" => "password123!@1aA",
        "password_confirmation" => "wrong_password"
      }

      conn = post(conn, "/register", %{"registration" => invalid_attrs})
      assert html_response(conn, 200) =~ "Passwords do not match"

      # Verify NOTHING was inserted
      user = Repo.get_by(UserSchema, email: "rollback_test@example.com")
      assert user == nil
      
      org = Repo.one(Ecto.Query.where(OrganizationSchema, name: "Rollback User's Organization"))
      assert org == nil
    end

    test "rolls back transaction completely if password validation fails", %{conn: conn} do
      invalid_attrs = %{
        "email" => "rollback_test2@example.com",
        "name" => "Rollback User 2",
        "password" => "weak",
        "password_confirmation" => "weak"
      }

      conn = post(conn, "/register", %{"registration" => invalid_attrs})
      assert html_response(conn, 200) =~ "Invalid input"

      # Verify NOTHING was inserted
      user = Repo.get_by(UserSchema, email: "rollback_test2@example.com")
      assert user == nil
      
      org = Repo.one(Ecto.Query.where(OrganizationSchema, name: "Rollback User 2's Organization"))
      assert org == nil
    end

    test "renders errors when fields are missing", %{conn: conn} do
      invalid_attrs = %{
        "email" => "",
        "name" => "",
        "password" => "",
        "password_confirmation" => ""
      }

      conn = post(conn, "/register", %{"registration" => invalid_attrs})
      assert html_response(conn, 200) =~ "Please provide"
    end

    test "renders errors when email is already in use", %{conn: conn} do
      # Create an existing user with a valid password hash
      password_hash = Bcrypt.hash_pwd_salt("password123!@1aA")

      UserSchema.create_changeset(%{
        email: "existing@example.com",
        name: "Existing User",
        password_hash: password_hash,
        status: :active
      })
      |> Repo.insert!()

      attrs = %{
        "email" => "existing@example.com",
        "name" => "Test User",
        "password" => "password123!@1aA",
        "password_confirmation" => "password123!@1aA"
      }

      conn = post(conn, "/register", %{"registration" => attrs})
      assert html_response(conn, 200) =~ "Create your account"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Email address already registered"
    end
  end
end
