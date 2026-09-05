defmodule Thalamus.Infrastructure.Adapters.SocialAuth.AppleAdapterTest do
  use ExUnit.Case, async: true

  alias Thalamus.Infrastructure.Adapters.SocialAuth.AppleAdapter

  setup_all do
    # Generate test EC P-256 private key for testing ES256 JWT signature
    {_, pem_binary} = JOSE.JWK.generate_key({:ec, "P-256"}) |> JOSE.JWK.to_pem()
    %{test_pem: pem_binary}
  end

  defmodule MockHttpClient do
    def post("https://appleid.apple.com/auth/token", form: %{"code" => "valid_apple_code"}) do
      # Mock id_token JWT
      id_token = generate_test_id_token()
      {:ok, %{status: 200, body: %{"id_token" => id_token, "access_token" => "apple_at"}}}
    end

    def post("https://appleid.apple.com/auth/token", form: %{"code" => "invalid_code"}) do
      {:ok, %{status: 400, body: %{"error" => "invalid_grant"}}}
    end

    defp generate_test_id_token do
      jwk = JOSE.JWK.generate_key({:ec, "P-256"})
      jws = %{"alg" => "ES256"}

      jwt = %{
        "sub" => "apple_sub_789",
        "email" => "apple.user@privaterelay.appleid.com",
        "email_verified" => "true",
        "iss" => "https://appleid.apple.com"
      }

      {_, token} = JOSE.JWT.sign(jwk, jws, jwt) |> JOSE.JWS.compact()
      token
    end
  end

  describe "get_authorization_url/2" do
    test "generates authorization URL with Apple specific parameters" do
      opts = [
        client_id: "cl.zea.auth.service",
        redirect_uri: "https://auth.zea.cl/auth/social/apple/callback"
      ]

      assert {:ok, url} = AppleAdapter.get_authorization_url("state_apple_123", opts)
      uri = URI.parse(url)

      assert uri.host == "appleid.apple.com"
      assert uri.path == "/auth/authorize"

      params = URI.decode_query(uri.query)
      assert params["client_id"] == "cl.zea.auth.service"
      assert params["redirect_uri"] == "https://auth.zea.cl/auth/social/apple/callback"
      assert params["response_type"] == "code"
      assert params["response_mode"] == "form_post"
      assert params["scope"] == "name email"
      assert params["state"] == "state_apple_123"
    end
  end

  describe "generate_client_secret/4" do
    test "generates valid ES256 signed JWT", %{test_pem: test_pem} do
      client_id = "cl.zea.auth.service"
      team_id = "TEAM12345"
      key_id = "KEY12345"

      assert {:ok, jwt_string} =
               AppleAdapter.generate_client_secret(client_id, team_id, key_id, test_pem)

      assert is_binary(jwt_string)
      %JOSE.JWT{fields: claims} = JOSE.JWT.peek_payload(jwt_string)
      assert claims["iss"] == team_id
      assert claims["sub"] == client_id
      assert claims["aud"] == "https://appleid.apple.com"

      header = JOSE.JWS.peek_protected(jwt_string) |> Jason.decode!()
      assert header["alg"] == "ES256"
      assert header["kid"] == key_id
    end
  end

  describe "exchange_code/2" do
    test "exchanges code and extracts claims + user param name", %{test_pem: test_pem} do
      user_json = Jason.encode!(%{"name" => %{"firstName" => "Steve", "lastName" => "Jobs"}})

      opts = [
        client_id: "cl.zea.auth.service",
        team_id: "TEAM12345",
        key_id: "KEY12345",
        private_key: test_pem,
        redirect_uri: "https://auth.zea.cl/auth/social/apple/callback",
        http_client: MockHttpClient,
        user_param: user_json
      ]

      assert {:ok, profile} = AppleAdapter.exchange_code("valid_apple_code", opts)
      assert profile.provider == "apple"
      assert profile.provider_uid == "apple_sub_789"
      assert profile.email == "apple.user@privaterelay.appleid.com"
      assert profile.email_verified == true
      assert profile.name == "Steve Jobs"
    end
  end
end
