defmodule Thalamus.Infrastructure.Adapters.SocialAuth.GoogleAdapterTest do
  use ExUnit.Case, async: true

  alias Thalamus.Infrastructure.Adapters.SocialAuth.GoogleAdapter

  defmodule MockHttpClient do
    def post("https://oauth2.googleapis.com/token", form: %{"code" => "valid_code"}) do
      {:ok, %{status: 200, body: %{"access_token" => "google_access_token_123"}}}
    end

    def post("https://oauth2.googleapis.com/token", form: %{"code" => "invalid_code"}) do
      {:ok, %{status: 400, body: %{"error" => "invalid_grant"}}}
    end

    def get("https://openidconnect.googleapis.com/v1/userinfo",
          headers: [{"authorization", "Bearer google_access_token_123"}]
        ) do
      {:ok,
       %{
         status: 200,
         body: %{
           "sub" => "google_sub_999",
           "email" => "google.user@example.com",
           "email_verified" => true,
           "name" => "Google User",
           "picture" => "https://lh3.googleusercontent.com/photo.jpg"
         }
       }}
    end
  end

  describe "get_authorization_url/2" do
    test "generates authorization URL with query parameters" do
      opts = [
        client_id: "test_google_client_id",
        redirect_uri: "https://auth.zea.cl/auth/social/google/callback"
      ]

      assert {:ok, url} = GoogleAdapter.get_authorization_url("random_state_123", opts)
      uri = URI.parse(url)

      assert uri.host == "accounts.google.com"
      assert uri.path == "/o/oauth2/v2/auth"

      params = URI.decode_query(uri.query)
      assert params["client_id"] == "test_google_client_id"
      assert params["redirect_uri"] == "https://auth.zea.cl/auth/social/google/callback"
      assert params["response_type"] == "code"
      assert params["scope"] == "openid email profile"
      assert params["state"] == "random_state_123"
    end

    test "returns error if client_id is missing" do
      assert {:error, :missing_google_client_id} =
               GoogleAdapter.get_authorization_url("state", client_id: nil)
    end
  end

  describe "exchange_code/2" do
    test "successfully exchanges code and retrieves userinfo" do
      opts = [
        client_id: "test_id",
        client_secret: "test_secret",
        redirect_uri: "https://auth.zea.cl/auth/social/google/callback",
        http_client: MockHttpClient
      ]

      assert {:ok, profile} = GoogleAdapter.exchange_code("valid_code", opts)
      assert profile.provider == "google"
      assert profile.provider_uid == "google_sub_999"
      assert profile.email == "google.user@example.com"
      assert profile.email_verified == true
      assert profile.name == "Google User"
      assert profile.avatar_url == "https://lh3.googleusercontent.com/photo.jpg"
    end

    test "handles failed token exchange" do
      opts = [
        client_id: "test_id",
        client_secret: "test_secret",
        http_client: MockHttpClient
      ]

      assert {:error, :token_exchange_failed} = GoogleAdapter.exchange_code("invalid_code", opts)
    end
  end
end
