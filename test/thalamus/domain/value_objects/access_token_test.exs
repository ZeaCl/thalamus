defmodule Thalamus.Domain.ValueObjects.AccessTokenTest do
  use ExUnit.Case, async: true

  alias Thalamus.Domain.ValueObjects.{AccessToken, UserId, ClientId, Scope}

  # Test fixtures
  defp valid_token do
    "at_" <> Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
  end

  defp create_valid_scopes do
    {:ok, scope1} = Scope.new("openid")
    {:ok, scope2} = Scope.new("profile")
    [scope1, scope2]
  end

  defp create_user_id do
    {:ok, user_id} = UserId.from_string("user_test123")
    user_id
  end

  defp create_client_id do
    {:ok, client_id} = ClientId.new("client_test123")
    client_id
  end

  describe "new/5 with UserId subject" do
    test "creates a new access token with required params" do
      token = valid_token()
      scopes = create_valid_scopes()
      user_id = create_user_id()

      assert {:ok, access_token} = AccessToken.new(token, scopes, user_id)

      assert access_token.token == token
      assert access_token.scopes == scopes
      assert access_token.subject == user_id
      assert access_token.token_type == :bearer
      assert is_struct(access_token.issued_at, DateTime)
      assert is_struct(access_token.expires_at, DateTime)
    end

    test "creates access token with default expiration of 3600 seconds" do
      token = valid_token()
      scopes = create_valid_scopes()
      user_id = create_user_id()

      assert {:ok, access_token} = AccessToken.new(token, scopes, user_id)

      diff = DateTime.diff(access_token.expires_at, access_token.issued_at)
      assert diff == 3600
    end

    test "creates access token with custom expiration" do
      token = valid_token()
      scopes = create_valid_scopes()
      user_id = create_user_id()
      custom_expiry = 7200

      assert {:ok, access_token} = AccessToken.new(token, scopes, user_id, custom_expiry)

      diff = DateTime.diff(access_token.expires_at, access_token.issued_at)
      assert diff == custom_expiry
    end

    test "creates access token with custom token type" do
      token = valid_token()
      scopes = create_valid_scopes()
      user_id = create_user_id()

      assert {:ok, access_token} = AccessToken.new(token, scopes, user_id, 3600, :mac)

      assert access_token.token_type == :mac
    end

    test "returns error for token that is too short" do
      short_token = "at_short"
      scopes = create_valid_scopes()
      user_id = create_user_id()

      assert {:error, :token_too_short} = AccessToken.new(short_token, scopes, user_id)
    end

    test "returns error for token that is too long" do
      long_token = "at_" <> String.duplicate("a", 600)
      scopes = create_valid_scopes()
      user_id = create_user_id()

      assert {:error, :token_too_long} = AccessToken.new(long_token, scopes, user_id)
    end

    test "returns error for invalid token format" do
      invalid_token = "at_" <> String.duplicate("a", 30) <> "@@@@"
      scopes = create_valid_scopes()
      user_id = create_user_id()

      assert {:error, :invalid_token_format} = AccessToken.new(invalid_token, scopes, user_id)
    end

    test "returns error for empty scopes" do
      token = valid_token()
      user_id = create_user_id()

      assert {:error, :no_scopes_provided} = AccessToken.new(token, [], user_id)
    end

    test "returns error for invalid scopes" do
      token = valid_token()
      user_id = create_user_id()
      invalid_scopes = ["invalid_scope", "another_invalid"]

      assert {:error, :invalid_scopes} = AccessToken.new(token, invalid_scopes, user_id)
    end

    test "returns error for invalid subject" do
      token = valid_token()
      scopes = create_valid_scopes()

      assert {:error, :invalid_subject} = AccessToken.new(token, scopes, "invalid_subject")
    end

    test "returns error for invalid token type" do
      token = valid_token()
      scopes = create_valid_scopes()
      user_id = create_user_id()

      assert {:error, :invalid_token_type} =
               AccessToken.new(token, scopes, user_id, 3600, :invalid)
    end

    test "returns error with invalid parameters" do
      assert {:error, :invalid_parameters} = AccessToken.new(nil, nil, nil)
      assert {:error, :invalid_parameters} = AccessToken.new(123, [], create_user_id())
      assert {:error, :invalid_parameters} = AccessToken.new(valid_token(), "not_a_list", create_user_id())
      assert {:error, :invalid_parameters} = AccessToken.new(valid_token(), [], create_user_id(), -100)
      assert {:error, :invalid_parameters} = AccessToken.new(valid_token(), [], create_user_id(), 0)
    end
  end

  describe "new/5 with ClientId subject" do
    test "creates access token with ClientId as subject" do
      token = valid_token()
      scopes = create_valid_scopes()
      client_id = create_client_id()

      assert {:ok, access_token} = AccessToken.new(token, scopes, client_id)

      assert access_token.subject == client_id
      assert access_token.token == token
    end
  end

  describe "generate/4 with UserId subject" do
    test "generates a new access token with secure random token" do
      scopes = create_valid_scopes()
      user_id = create_user_id()

      assert {:ok, access_token} = AccessToken.generate(scopes, user_id)

      # Check token format
      assert String.starts_with?(access_token.token, "at_")
      assert String.length(access_token.token) >= 32
      assert access_token.scopes == scopes
      assert access_token.subject == user_id
      assert access_token.token_type == :bearer
    end

    test "generates different tokens on each call" do
      scopes = create_valid_scopes()
      user_id = create_user_id()

      {:ok, token1} = AccessToken.generate(scopes, user_id)
      {:ok, token2} = AccessToken.generate(scopes, user_id)

      assert token1.token != token2.token
    end

    test "generates token with custom expiration" do
      scopes = create_valid_scopes()
      user_id = create_user_id()

      assert {:ok, access_token} = AccessToken.generate(scopes, user_id, 7200)

      diff = DateTime.diff(access_token.expires_at, access_token.issued_at)
      assert diff == 7200
    end

    test "generates token with custom token type" do
      scopes = create_valid_scopes()
      user_id = create_user_id()

      assert {:ok, access_token} = AccessToken.generate(scopes, user_id, 3600, :mac)

      assert access_token.token_type == :mac
    end
  end

  describe "generate/4 with ClientId subject" do
    test "generates access token with ClientId as subject" do
      scopes = create_valid_scopes()
      client_id = create_client_id()

      assert {:ok, access_token} = AccessToken.generate(scopes, client_id)

      assert access_token.subject == client_id
      assert String.starts_with?(access_token.token, "at_")
    end
  end

  describe "expired?/1" do
    test "returns true for expired token" do
      token = valid_token()
      scopes = create_valid_scopes()
      user_id = create_user_id()

      {:ok, access_token} = AccessToken.new(token, scopes, user_id, 3600)

      # Manually set expires_at to the past
      expired_token = %{access_token | expires_at: DateTime.add(DateTime.utc_now(), -10, :second)}
      assert AccessToken.expired?(expired_token) == true
    end

    test "returns false for non-expired token" do
      token = valid_token()
      scopes = create_valid_scopes()
      user_id = create_user_id()

      {:ok, access_token} = AccessToken.new(token, scopes, user_id, 3600)

      assert AccessToken.expired?(access_token) == false
    end

    test "returns false for token expiring in the future" do
      token = valid_token()
      scopes = create_valid_scopes()
      user_id = create_user_id()

      {:ok, access_token} = AccessToken.new(token, scopes, user_id, 3600)

      # Set expires_at to 1 hour in the future
      future_token = %{access_token | expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)}
      assert AccessToken.expired?(future_token) == false
    end
  end

  describe "valid?/1" do
    test "returns true for valid token (not expired)" do
      token = valid_token()
      scopes = create_valid_scopes()
      user_id = create_user_id()

      {:ok, access_token} = AccessToken.new(token, scopes, user_id, 3600)

      assert AccessToken.valid?(access_token) == true
    end

    test "returns false for expired token" do
      token = valid_token()
      scopes = create_valid_scopes()
      user_id = create_user_id()

      {:ok, access_token} = AccessToken.new(token, scopes, user_id, 3600)

      # Manually set expires_at to the past
      expired_token = %{access_token | expires_at: DateTime.add(DateTime.utc_now(), -10, :second)}
      assert AccessToken.valid?(expired_token) == false
    end
  end

  describe "time_to_expiry/1" do
    test "returns positive seconds until expiration" do
      token = valid_token()
      scopes = create_valid_scopes()
      user_id = create_user_id()

      {:ok, access_token} = AccessToken.new(token, scopes, user_id, 3600)

      time_left = AccessToken.time_to_expiry(access_token)
      assert time_left > 0
      assert time_left <= 3600
    end

    test "returns 0 for expired token" do
      token = valid_token()
      scopes = create_valid_scopes()
      user_id = create_user_id()

      {:ok, access_token} = AccessToken.new(token, scopes, user_id, 3600)

      # Manually set expires_at to the past
      expired_token = %{access_token | expires_at: DateTime.add(DateTime.utc_now(), -10, :second)}
      assert AccessToken.time_to_expiry(expired_token) == 0
    end

    test "returns approximately 0 when at or near expiration" do
      token = valid_token()
      scopes = create_valid_scopes()
      user_id = create_user_id()

      {:ok, access_token} = AccessToken.new(token, scopes, user_id, 3600)

      # Set expires_at to very close to now (1 second in the future)
      near_expiry_token = %{access_token | expires_at: DateTime.add(DateTime.utc_now(), 1, :second)}
      time_left = AccessToken.time_to_expiry(near_expiry_token)
      assert time_left <= 1
    end
  end

  describe "has_scope?/2 with string scope" do
    test "returns true when token has the scope" do
      token = valid_token()
      scopes = create_valid_scopes()
      user_id = create_user_id()

      {:ok, access_token} = AccessToken.new(token, scopes, user_id)

      assert AccessToken.has_scope?(access_token, "openid") == true
      assert AccessToken.has_scope?(access_token, "profile") == true
    end

    test "returns false when token does not have the scope" do
      token = valid_token()
      scopes = create_valid_scopes()
      user_id = create_user_id()

      {:ok, access_token} = AccessToken.new(token, scopes, user_id)

      assert AccessToken.has_scope?(access_token, "email") == false
      assert AccessToken.has_scope?(access_token, "invalid") == false
    end
  end

  describe "has_scope?/2 with Scope struct" do
    test "returns true when token has the scope" do
      token = valid_token()
      scopes = create_valid_scopes()
      user_id = create_user_id()

      {:ok, access_token} = AccessToken.new(token, scopes, user_id)
      {:ok, required_scope} = Scope.new("openid")

      assert AccessToken.has_scope?(access_token, required_scope) == true
    end

    test "returns false when token does not have the scope" do
      token = valid_token()
      scopes = create_valid_scopes()
      user_id = create_user_id()

      {:ok, access_token} = AccessToken.new(token, scopes, user_id)
      {:ok, required_scope} = Scope.new("email")

      assert AccessToken.has_scope?(access_token, required_scope) == false
    end
  end

  describe "has_scopes?/2" do
    test "returns true when token has all required scopes" do
      token = valid_token()
      scopes = create_valid_scopes()
      user_id = create_user_id()

      {:ok, access_token} = AccessToken.new(token, scopes, user_id)

      assert AccessToken.has_scopes?(access_token, ["openid", "profile"]) == true
      assert AccessToken.has_scopes?(access_token, ["openid"]) == true
    end

    test "returns false when token is missing any required scope" do
      token = valid_token()
      scopes = create_valid_scopes()
      user_id = create_user_id()

      {:ok, access_token} = AccessToken.new(token, scopes, user_id)

      assert AccessToken.has_scopes?(access_token, ["openid", "email"]) == false
      assert AccessToken.has_scopes?(access_token, ["email", "address"]) == false
    end

    test "returns true for empty list of required scopes" do
      token = valid_token()
      scopes = create_valid_scopes()
      user_id = create_user_id()

      {:ok, access_token} = AccessToken.new(token, scopes, user_id)

      assert AccessToken.has_scopes?(access_token, []) == true
    end
  end

  describe "to_string/1" do
    test "returns the token value" do
      token = valid_token()
      scopes = create_valid_scopes()
      user_id = create_user_id()

      {:ok, access_token} = AccessToken.new(token, scopes, user_id)

      assert AccessToken.to_string(access_token) == token
    end
  end

  describe "to_response/1" do
    test "converts token to OAuth2 response format" do
      token = valid_token()
      scopes = create_valid_scopes()
      user_id = create_user_id()

      {:ok, access_token} = AccessToken.new(token, scopes, user_id, 3600)

      response = AccessToken.to_response(access_token)

      assert response.access_token == token
      assert response.token_type == "bearer"
      assert response.expires_in > 0
      assert response.expires_in <= 3600
      assert response.scope == "openid profile"
    end

    test "includes correct token type for MAC tokens" do
      token = valid_token()
      scopes = create_valid_scopes()
      user_id = create_user_id()

      {:ok, access_token} = AccessToken.new(token, scopes, user_id, 3600, :mac)

      response = AccessToken.to_response(access_token)

      assert response.token_type == "mac"
    end

    test "formats scopes correctly" do
      token = valid_token()
      {:ok, scope1} = Scope.new("openid")
      {:ok, scope2} = Scope.new("profile")
      {:ok, scope3} = Scope.new("email")
      scopes = [scope1, scope2, scope3]
      user_id = create_user_id()

      {:ok, access_token} = AccessToken.new(token, scopes, user_id)

      response = AccessToken.to_response(access_token)

      assert response.scope == "openid profile email"
    end
  end

  describe "String.Chars protocol" do
    test "converts access token to string" do
      token = valid_token()
      scopes = create_valid_scopes()
      user_id = create_user_id()

      {:ok, access_token} = AccessToken.new(token, scopes, user_id)

      assert to_string(access_token) == token
    end

    test "works with string interpolation" do
      token = valid_token()
      scopes = create_valid_scopes()
      user_id = create_user_id()

      {:ok, access_token} = AccessToken.new(token, scopes, user_id)

      assert "Token: #{access_token}" == "Token: #{token}"
    end
  end

  describe "Jason.Encoder protocol" do
    test "encodes access token to JSON response format" do
      token = valid_token()
      scopes = create_valid_scopes()
      user_id = create_user_id()

      {:ok, access_token} = AccessToken.new(token, scopes, user_id)

      assert {:ok, json} = Jason.encode(access_token)
      decoded = Jason.decode!(json)

      assert decoded["access_token"] == token
      assert decoded["token_type"] == "bearer"
      assert is_integer(decoded["expires_in"])
      assert decoded["scope"] == "openid profile"
    end
  end

  describe "edge cases" do
    test "handles minimum valid token length" do
      # Minimum is 32 characters
      min_token = "at_" <> String.duplicate("a", 29)
      scopes = create_valid_scopes()
      user_id = create_user_id()

      assert {:ok, access_token} = AccessToken.new(min_token, scopes, user_id)
      assert access_token.token == min_token
    end

    test "handles maximum valid token length" do
      # Maximum is 512 characters
      max_token = "at_" <> String.duplicate("a", 509)
      scopes = create_valid_scopes()
      user_id = create_user_id()

      assert {:ok, access_token} = AccessToken.new(max_token, scopes, user_id)
      assert access_token.token == max_token
    end

    test "handles single scope" do
      token = valid_token()
      {:ok, scope} = Scope.new("openid")
      user_id = create_user_id()

      assert {:ok, access_token} = AccessToken.new(token, [scope], user_id)
      assert access_token.scopes == [scope]
    end

    test "allows valid token format characters" do
      valid_token_chars = "at_abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"
      scopes = create_valid_scopes()
      user_id = create_user_id()

      assert {:ok, access_token} = AccessToken.new(valid_token_chars, scopes, user_id)
      assert access_token.token == valid_token_chars
    end

    test "rejects invalid characters in token" do
      # Make sure tokens are long enough to pass length check (32+ chars)
      invalid_tokens = [
        "at_" <> String.duplicate("a", 29) <> "@invalid",
        "at_" <> String.duplicate("a", 29) <> "#invalid",
        "at_" <> String.duplicate("a", 29) <> "$invalid",
        "at_" <> String.duplicate("a", 20) <> " with spaces",
        "at_" <> String.duplicate("a", 29) <> ".invalid"
      ]

      scopes = create_valid_scopes()
      user_id = create_user_id()

      for invalid_token <- invalid_tokens do
        assert {:error, :invalid_token_format} = AccessToken.new(invalid_token, scopes, user_id)
      end
    end

    test "handles very long expiration time" do
      token = valid_token()
      scopes = create_valid_scopes()
      user_id = create_user_id()
      # 30 days in seconds
      long_expiry = 30 * 24 * 60 * 60

      assert {:ok, access_token} = AccessToken.new(token, scopes, user_id, long_expiry)

      diff = DateTime.diff(access_token.expires_at, access_token.issued_at)
      assert diff == long_expiry
    end

    test "handles very short expiration time" do
      token = valid_token()
      scopes = create_valid_scopes()
      user_id = create_user_id()
      # 1 second
      short_expiry = 1

      assert {:ok, access_token} = AccessToken.new(token, scopes, user_id, short_expiry)

      diff = DateTime.diff(access_token.expires_at, access_token.issued_at)
      assert diff == short_expiry
    end
  end
end
