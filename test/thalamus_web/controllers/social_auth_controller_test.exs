defmodule ThalamusWeb.SocialAuthControllerTest do
  use ThalamusWeb.ConnCase, async: false

  defmodule MockSocialAdapter do
    def get_authorization_url(state, _opts \\ []) do
      {:ok, "https://idp.example.com/oauth?state=#{state}"}
    end

    def exchange_code(code, opts \\ [])

    def exchange_code("valid_code", _opts) do
      {:ok,
       %{
         provider: "google",
         provider_uid: "sub_mock_123",
         email: "mock.user@zea.cl",
         email_verified: true,
         name: "Mock User",
         avatar_url: "https://example.com/avatar.png",
         raw: %{}
       }}
    end

    def exchange_code("unverified_code", _opts) do
      {:ok,
       %{
         provider: "google",
         provider_uid: "sub_unverified",
         email: "unverified@zea.cl",
         email_verified: false,
         name: "Unverified",
         avatar_url: nil,
         raw: %{}
       }}
    end

    def exchange_code("invalid_code", _opts) do
      {:error, :bad_code}
    end
  end

  setup do
    Application.put_env(:thalamus, :google_adapter, MockSocialAdapter)
    Application.put_env(:thalamus, :github_adapter, MockSocialAdapter)
    Application.put_env(:thalamus, :apple_adapter, MockSocialAdapter)

    on_exit(fn ->
      Application.delete_env(:thalamus, :google_adapter)
      Application.delete_env(:thalamus, :github_adapter)
      Application.delete_env(:thalamus, :apple_adapter)
    end)

    :ok
  end

  describe "GET /auth/social/:provider/init" do
    test "redirects to external provider and sets state in session", %{conn: conn} do
      conn = get(conn, ~p"/auth/social/google/init?return_to=/dashboard")

      assert redirected_to(conn) =~ "https://idp.example.com/oauth?state="
      assert get_session(conn, :social_auth_state) != nil
      assert get_session(conn, :return_to) == "/dashboard"
    end

    test "rejects invalid provider", %{conn: conn} do
      conn = get(conn, ~p"/auth/social/unknown/init")
      assert redirected_to(conn) == ~p"/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Unsupported provider"
    end
  end

  describe "GET /auth/social/:provider/callback" do
    test "authenticates successfully when state matches and code is valid", %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{
          social_auth_state: "expected_state_123",
          return_to: "/custom_dashboard"
        })
        |> get(~p"/auth/social/google/callback", %{
          "code" => "valid_code",
          "state" => "expected_state_123"
        })

      assert redirected_to(conn) == "/custom_dashboard"
      assert get_session(conn, :user_id) != nil
      assert get_session(conn, :social_auth_state) == nil
    end

    test "redirects to /oauth/authorize if authorization_request is stored in session", %{
      conn: conn
    } do
      auth_req = %{
        "client_id" => "client_abc",
        "redirect_uri" => "http://localhost:3000/cb",
        "response_type" => "code"
      }

      conn =
        conn
        |> Plug.Test.init_test_session(%{
          social_auth_state: "state_oauth_req",
          authorization_request: auth_req
        })
        |> get(~p"/auth/social/google/callback", %{
          "code" => "valid_code",
          "state" => "state_oauth_req"
        })

      assert redirected_to(conn) =~ "/oauth/authorize?client_id=client_abc"
      assert get_session(conn, :user_id) != nil
    end

    test "rejects callback if CSRF state does not match", %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{social_auth_state: "correct_state"})
        |> get(~p"/auth/social/google/callback", %{
          "code" => "valid_code",
          "state" => "wrong_state"
        })

      assert redirected_to(conn) == ~p"/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Invalid authentication request"
    end

    test "rejects callback if provider returns error", %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{social_auth_state: "any_state"})
        |> get(~p"/auth/social/google/callback", %{
          "error" => "access_denied",
          "state" => "any_state"
        })

      assert redirected_to(conn) == ~p"/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "cancelled or failed"
    end

    test "handles unverified email from social provider", %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{social_auth_state: "state_uv"})
        |> get(~p"/auth/social/google/callback", %{
          "code" => "unverified_code",
          "state" => "state_uv"
        })

      assert redirected_to(conn) == ~p"/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "not verified"
    end

    test "prevents Open Redirect attacks with external URL", %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{
          social_auth_state: "state_or",
          return_to: "https://evil.com/steal-credentials"
        })
        |> get(~p"/auth/social/google/callback", %{
          "code" => "valid_code",
          "state" => "state_or"
        })

      # Must not redirect to evil.com
      assert redirected_to(conn) == "/"
    end

    test "prevents Open Redirect attacks with protocol-relative URL", %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{
          social_auth_state: "state_pr",
          return_to: "//evil.com"
        })
        |> get(~p"/auth/social/google/callback", %{
          "code" => "valid_code",
          "state" => "state_pr"
        })

      assert redirected_to(conn) == "/"
    end
  end

  describe "POST /auth/social/apple/callback" do
    test "authenticates successfully via form-post with session state", %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{social_auth_state: "apple_state_abc"})
        |> post(~p"/auth/social/apple/callback", %{
          "code" => "valid_code",
          "state" => "apple_state_abc"
        })

      assert redirected_to(conn) == "/"
      assert get_session(conn, :user_id) != nil
    end

    test "authenticates successfully stateless when SameSite=Lax omits session cookie", %{
      conn: conn
    } do
      # Generate HMAC signed state using Phoenix.Token
      token_payload = %{
        csrf: UUID.uuid4(),
        provider: "apple",
        return_to: "/settings/security",
        auth_req: nil
      }

      signed_state =
        Phoenix.Token.sign(ThalamusWeb.Endpoint, "social_auth_state", token_payload)

      # Request with completely empty session (no cookies sent by browser)
      conn =
        post(conn, ~p"/auth/social/apple/callback", %{
          "code" => "valid_code",
          "state" => signed_state
        })

      assert redirected_to(conn) == "/settings/security"
      assert get_session(conn, :user_id) != nil
    end

    test "rejects signed state if provider does not match", %{conn: conn} do
      token_payload = %{
        csrf: UUID.uuid4(),
        provider: "google",
        return_to: "/dashboard",
        auth_req: nil
      }

      google_token =
        Phoenix.Token.sign(ThalamusWeb.Endpoint, "social_auth_state", token_payload)

      conn =
        post(conn, ~p"/auth/social/apple/callback", %{
          "code" => "valid_code",
          "state" => google_token
        })

      assert redirected_to(conn) == ~p"/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Invalid authentication request"
    end
  end

  describe "safe_return_target/1" do
    test "accepts valid relative paths" do
      assert ThalamusWeb.SocialAuthController.safe_return_target("/dashboard") == "/dashboard"

      assert ThalamusWeb.SocialAuthController.safe_return_target(
               "/oauth/authorize?client_id=123&response_type=code"
             ) == "/oauth/authorize?client_id=123&response_type=code"
    end

    test "rejects external URLs and malicious schemes" do
      assert is_nil(
               ThalamusWeb.SocialAuthController.safe_return_target("https://attacker.com/steal")
             )

      assert is_nil(
               ThalamusWeb.SocialAuthController.safe_return_target("http://attacker.com/steal")
             )

      assert is_nil(ThalamusWeb.SocialAuthController.safe_return_target("//attacker.com"))
      assert is_nil(ThalamusWeb.SocialAuthController.safe_return_target("/\\attacker.com"))
      assert is_nil(ThalamusWeb.SocialAuthController.safe_return_target("javascript:alert(1)"))
      assert is_nil(ThalamusWeb.SocialAuthController.safe_return_target(""))
      assert is_nil(ThalamusWeb.SocialAuthController.safe_return_target(nil))
    end
  end
end
