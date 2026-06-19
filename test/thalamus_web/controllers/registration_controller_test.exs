defmodule ThalamusWeb.RegistrationControllerTest do
  use ThalamusWeb.ConnCase

  alias Thalamus.Repo
  alias Thalamus.Infrastructure.Persistence.Schemas.UserSchema

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
    test "creates a new user and redirects", %{conn: conn} do
      valid_attrs = %{
        "email" => "test@example.com",
        "name" => "Test User",
        "password" => "password123!@1aA"
      }

      conn = post(conn, "/register", %{"registration" => valid_attrs})
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "Welcome to Thalamus! Your account has been created."

      # Verify user in database
      user = Repo.get_by(UserSchema, email: "test@example.com")
      assert user != nil
      assert user.name == "Test User"
    end

    test "renders errors when fields are missing", %{conn: conn} do
      invalid_attrs = %{
        "email" => "",
        "name" => "",
        "password" => ""
      }

      conn = post(conn, "/register", %{"registration" => invalid_attrs})
      assert html_response(conn, 200) =~ "Please provide"
    end

    test "renders errors when email is already in use", %{conn: conn} do
      # Create an existing user
      UserSchema.create_changeset(%{
        email: "existing@example.com",
        name: "Existing User",
        password_hash: "hashed",
        status: :active
      })
      |> Repo.insert!()

      attrs = %{
        "email" => "existing@example.com",
        "name" => "Test User",
        "password" => "password123!@1aA"
      }

      conn = post(conn, "/register", %{"registration" => attrs})
      assert html_response(conn, 200) =~ "Email address already registered"
    end
  end
end
