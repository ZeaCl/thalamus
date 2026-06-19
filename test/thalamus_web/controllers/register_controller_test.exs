defmodule ThalamusWeb.RegisterControllerTest do
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

    test "extracts sdk params from return_to", %{conn: conn} do
      conn =
        get(conn, "/register", %{
          "return_to" =>
            "http://localhost:4000?org_name=MyOrg&app_origin=http://app.com&client_id=123"
        })

      assert html_response(conn, 200) =~ "Create your account"

      assert get_session(conn, :return_to) ==
               "http://localhost:4000?org_name=MyOrg&app_origin=http://app.com&client_id=123"

      assert get_session(conn, :sdk_client_id) == "123"
    end
  end

  describe "POST /register" do
    test "creates a new user and redirects to success", %{conn: conn} do
      valid_attrs = %{
        "email" => "test@example.com",
        "name" => "Test User",
        "password" => "password123",
        "password_confirmation" => "password123"
      }

      conn = post(conn, "/register", %{"user" => valid_attrs})
      assert redirected_to(conn) == "https://zea.cl/studio"
      assert get_flash(conn, :info) =~ "Check your email to verify your account"

      # Verify user in database
      user = Repo.get_by(UserSchema, email: "test@example.com")
      assert user != nil
      assert user.name == "Test User"
    end

    test "renders errors when fields are missing", %{conn: conn} do
      invalid_attrs = %{
        "email" => "",
        "name" => "",
        "password" => "",
        "password_confirmation" => ""
      }

      conn = post(conn, "/register", %{"user" => invalid_attrs})
      assert html_response(conn, 200) =~ "All fields are required"
    end

    test "renders errors when passwords do not match", %{conn: conn} do
      invalid_attrs = %{
        "email" => "test@example.com",
        "name" => "Test User",
        "password" => "password123",
        "password_confirmation" => "wrongpassword"
      }

      conn = post(conn, "/register", %{"user" => invalid_attrs})
      assert html_response(conn, 200) =~ "Passwords do not match"
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
        "password" => "password123",
        "password_confirmation" => "password123"
      }

      conn = post(conn, "/register", %{"user" => attrs})
      assert html_response(conn, 200) =~ "Email address already in use"
    end

    test "creates user and organization and oauth client if sdk params present", %{conn: conn} do
      valid_attrs = %{
        "email" => "sdk@example.com",
        "name" => "SDK User",
        "password" => "password123",
        "password_confirmation" => "password123",
        "org_name" => "New Org",
        "app_origin" => "http://localhost:5173"
      }

      conn =
        conn
        |> init_test_session(%{return_to: "http://localhost:5173?client_id=temp"})
        |> post("/register", %{"user" => valid_attrs})

      assert redirected_to(conn) =~ "http://localhost:5173?client_id=app_"
      assert get_flash(conn, :info) =~ "Check your email to verify your account"

      user = Repo.get_by(UserSchema, email: "sdk@example.com")
      assert user != nil
    end
  end
end
