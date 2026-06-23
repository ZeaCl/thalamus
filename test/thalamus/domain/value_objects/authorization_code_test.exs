defmodule Thalamus.Domain.ValueObjects.AuthorizationCodeTest do
  use ExUnit.Case, async: false

  alias Thalamus.Domain.ValueObjects.{
    AuthorizationCode,
    UserId,
    ClientId,
    RedirectUri,
    Scope
  }

  # Test fixtures
  defp valid_code do
    "ac_" <> Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
  end

  defp create_valid_params do
    {:ok, user_id} = UserId.from_string("user_test123")
    {:ok, client_id} = ClientId.new("client_test123")
    {:ok, redirect_uri} = RedirectUri.new("https://app.example.com/callback")
    {:ok, scope1} = Scope.new("openid")
    {:ok, scope2} = Scope.new("profile")

    %{
      code: valid_code(),
      client_id: client_id,
      user_id: user_id,
      redirect_uri: redirect_uri,
      scopes: [scope1, scope2]
    }
  end

  describe "new/7" do
    test "creates a new authorization code with required params" do
      params = create_valid_params()

      assert {:ok, auth_code} =
               AuthorizationCode.new(
                 params.code,
                 params.client_id,
                 params.user_id,
                 params.redirect_uri,
                 params.scopes
               )

      assert auth_code.code == params.code
      assert auth_code.client_id == params.client_id
      assert auth_code.user_id == params.user_id
      assert auth_code.redirect_uri == params.redirect_uri
      assert auth_code.scopes == params.scopes
      assert auth_code.pkce_challenge == nil
      assert auth_code.used_at == nil
      assert is_struct(auth_code.issued_at, DateTime)
      assert is_struct(auth_code.expires_at, DateTime)
    end

    test "creates authorization code with nil PKCE challenge" do
      params = create_valid_params()

      assert {:ok, auth_code} =
               AuthorizationCode.new(
                 params.code,
                 params.client_id,
                 params.user_id,
                 params.redirect_uri,
                 params.scopes,
                 nil
               )

      assert auth_code.pkce_challenge == nil
    end

    test "creates authorization code with custom expiration" do
      params = create_valid_params()
      custom_expiry = 300

      assert {:ok, auth_code} =
               AuthorizationCode.new(
                 params.code,
                 params.client_id,
                 params.user_id,
                 params.redirect_uri,
                 params.scopes,
                 nil,
                 custom_expiry
               )

      diff = DateTime.diff(auth_code.expires_at, auth_code.issued_at)
      assert diff == custom_expiry
    end

    test "returns error for code that is too short" do
      params = create_valid_params()
      short_code = "ac_short"

      assert {:error, :code_too_short} =
               AuthorizationCode.new(
                 short_code,
                 params.client_id,
                 params.user_id,
                 params.redirect_uri,
                 params.scopes
               )
    end

    test "returns error for code that is too long" do
      params = create_valid_params()
      long_code = "ac_" <> String.duplicate("a", 130)

      assert {:error, :code_too_long} =
               AuthorizationCode.new(
                 long_code,
                 params.client_id,
                 params.user_id,
                 params.redirect_uri,
                 params.scopes
               )
    end

    test "returns error for invalid code format" do
      params = create_valid_params()
      invalid_code = "ac_" <> String.duplicate("a", 30) <> "@@@@"

      assert {:error, :invalid_code_format} =
               AuthorizationCode.new(
                 invalid_code,
                 params.client_id,
                 params.user_id,
                 params.redirect_uri,
                 params.scopes
               )
    end

    test "returns error for invalid client_id" do
      params = create_valid_params()

      assert {:error, :invalid_client_id} =
               AuthorizationCode.new(
                 params.code,
                 "invalid_client_id",
                 params.user_id,
                 params.redirect_uri,
                 params.scopes
               )
    end

    test "returns error for invalid user_id" do
      params = create_valid_params()

      assert {:error, :invalid_user_id} =
               AuthorizationCode.new(
                 params.code,
                 params.client_id,
                 "invalid_user_id",
                 params.redirect_uri,
                 params.scopes
               )
    end

    test "returns error for invalid redirect_uri" do
      params = create_valid_params()

      assert {:error, :invalid_redirect_uri} =
               AuthorizationCode.new(
                 params.code,
                 params.client_id,
                 params.user_id,
                 "invalid_redirect_uri",
                 params.scopes
               )
    end

    test "returns error for empty scopes" do
      params = create_valid_params()

      assert {:error, :no_scopes_provided} =
               AuthorizationCode.new(
                 params.code,
                 params.client_id,
                 params.user_id,
                 params.redirect_uri,
                 []
               )
    end

    test "returns error for invalid scopes" do
      params = create_valid_params()

      assert {:error, :invalid_scopes} =
               AuthorizationCode.new(
                 params.code,
                 params.client_id,
                 params.user_id,
                 params.redirect_uri,
                 ["invalid_scope", "another_invalid"]
               )
    end

    test "returns error for invalid PKCE challenge" do
      params = create_valid_params()

      assert {:error, :invalid_pkce_challenge} =
               AuthorizationCode.new(
                 params.code,
                 params.client_id,
                 params.user_id,
                 params.redirect_uri,
                 params.scopes,
                 "invalid_pkce"
               )
    end

    test "returns error with invalid parameters" do
      assert {:error, :invalid_parameters} = AuthorizationCode.new(nil, nil, nil, nil, nil)
      assert {:error, :invalid_parameters} = AuthorizationCode.new(123, nil, nil, nil, nil)
    end
  end

  describe "generate/6" do
    test "generates a new authorization code with secure random code" do
      params = create_valid_params()

      assert {:ok, auth_code} =
               AuthorizationCode.generate(
                 params.client_id,
                 params.user_id,
                 params.redirect_uri,
                 params.scopes
               )

      # Check code format
      assert String.starts_with?(auth_code.code, "ac_")
      assert String.length(auth_code.code) >= 32
      assert auth_code.client_id == params.client_id
      assert auth_code.user_id == params.user_id
    end

    test "generates different codes on each call" do
      params = create_valid_params()

      {:ok, code1} =
        AuthorizationCode.generate(
          params.client_id,
          params.user_id,
          params.redirect_uri,
          params.scopes
        )

      {:ok, code2} =
        AuthorizationCode.generate(
          params.client_id,
          params.user_id,
          params.redirect_uri,
          params.scopes
        )

      assert code1.code != code2.code
    end

    test "generates code with nil PKCE challenge" do
      params = create_valid_params()

      assert {:ok, auth_code} =
               AuthorizationCode.generate(
                 params.client_id,
                 params.user_id,
                 params.redirect_uri,
                 params.scopes,
                 nil
               )

      assert auth_code.pkce_challenge == nil
    end

    test "generates code with custom expiration" do
      params = create_valid_params()

      assert {:ok, auth_code} =
               AuthorizationCode.generate(
                 params.client_id,
                 params.user_id,
                 params.redirect_uri,
                 params.scopes,
                 nil,
                 300
               )

      diff = DateTime.diff(auth_code.expires_at, auth_code.issued_at)
      assert diff == 300
    end
  end

  describe "expired?/1" do
    test "returns true for expired code" do
      params = create_valid_params()

      {:ok, auth_code} =
        AuthorizationCode.new(
          params.code,
          params.client_id,
          params.user_id,
          params.redirect_uri,
          params.scopes,
          nil,
          600
        )

      # Manually set expires_at to the past
      expired_code = %{auth_code | expires_at: DateTime.add(DateTime.utc_now(), -10, :second)}
      assert AuthorizationCode.expired?(expired_code) == true
    end

    test "returns false for non-expired code" do
      params = create_valid_params()

      {:ok, auth_code} =
        AuthorizationCode.new(
          params.code,
          params.client_id,
          params.user_id,
          params.redirect_uri,
          params.scopes,
          nil,
          600
        )

      assert AuthorizationCode.expired?(auth_code) == false
    end
  end

  describe "used?/1" do
    test "returns false when used_at is nil" do
      params = create_valid_params()

      {:ok, auth_code} =
        AuthorizationCode.new(
          params.code,
          params.client_id,
          params.user_id,
          params.redirect_uri,
          params.scopes
        )

      assert AuthorizationCode.used?(auth_code) == false
    end

    test "returns true when used_at is set" do
      params = create_valid_params()

      {:ok, auth_code} =
        AuthorizationCode.new(
          params.code,
          params.client_id,
          params.user_id,
          params.redirect_uri,
          params.scopes
        )

      used_code = AuthorizationCode.mark_as_used(auth_code)
      assert AuthorizationCode.used?(used_code) == true
    end
  end

  describe "valid?/1" do
    test "returns true for valid code (not expired, not used)" do
      params = create_valid_params()

      {:ok, auth_code} =
        AuthorizationCode.new(
          params.code,
          params.client_id,
          params.user_id,
          params.redirect_uri,
          params.scopes,
          nil,
          600
        )

      assert AuthorizationCode.valid?(auth_code) == true
    end

    test "returns false for expired code" do
      params = create_valid_params()

      {:ok, auth_code} =
        AuthorizationCode.new(
          params.code,
          params.client_id,
          params.user_id,
          params.redirect_uri,
          params.scopes,
          nil,
          600
        )

      # Manually set expires_at to the past
      expired_code = %{auth_code | expires_at: DateTime.add(DateTime.utc_now(), -10, :second)}
      assert AuthorizationCode.valid?(expired_code) == false
    end

    test "returns false for used code" do
      params = create_valid_params()

      {:ok, auth_code} =
        AuthorizationCode.new(
          params.code,
          params.client_id,
          params.user_id,
          params.redirect_uri,
          params.scopes,
          nil,
          600
        )

      used_code = AuthorizationCode.mark_as_used(auth_code)
      assert AuthorizationCode.valid?(used_code) == false
    end
  end

  describe "mark_as_used/1" do
    test "sets used_at timestamp" do
      params = create_valid_params()

      {:ok, auth_code} =
        AuthorizationCode.new(
          params.code,
          params.client_id,
          params.user_id,
          params.redirect_uri,
          params.scopes
        )

      assert auth_code.used_at == nil

      used_code = AuthorizationCode.mark_as_used(auth_code)

      assert is_struct(used_code.used_at, DateTime)
      refute is_nil(used_code.used_at)
    end
  end

  describe "validate_redirect_uri/2" do
    test "returns :ok for matching redirect URI" do
      params = create_valid_params()

      {:ok, auth_code} =
        AuthorizationCode.new(
          params.code,
          params.client_id,
          params.user_id,
          params.redirect_uri,
          params.scopes
        )

      assert :ok =
               AuthorizationCode.validate_redirect_uri(
                 auth_code,
                 "https://app.example.com/callback"
               )
    end

    test "returns error for mismatched redirect URI" do
      params = create_valid_params()

      {:ok, auth_code} =
        AuthorizationCode.new(
          params.code,
          params.client_id,
          params.user_id,
          params.redirect_uri,
          params.scopes
        )

      assert {:error, :redirect_uri_mismatch} =
               AuthorizationCode.validate_redirect_uri(auth_code, "https://evil.com/callback")
    end
  end

  describe "validate_client_id/2" do
    test "returns :ok for matching client ID" do
      params = create_valid_params()

      {:ok, auth_code} =
        AuthorizationCode.new(
          params.code,
          params.client_id,
          params.user_id,
          params.redirect_uri,
          params.scopes
        )

      assert :ok = AuthorizationCode.validate_client_id(auth_code, "client_test123")
    end

    test "returns error for mismatched client ID" do
      params = create_valid_params()

      {:ok, auth_code} =
        AuthorizationCode.new(
          params.code,
          params.client_id,
          params.user_id,
          params.redirect_uri,
          params.scopes
        )

      assert {:error, :client_id_mismatch} =
               AuthorizationCode.validate_client_id(auth_code, "different_client")
    end
  end

  describe "validate_pkce/2" do
    test "returns :ok when no PKCE challenge is set" do
      params = create_valid_params()

      {:ok, auth_code} =
        AuthorizationCode.new(
          params.code,
          params.client_id,
          params.user_id,
          params.redirect_uri,
          params.scopes
        )

      assert :ok = AuthorizationCode.validate_pkce(auth_code, "any_verifier")
    end
  end

  describe "time_to_expiry/1" do
    test "returns positive seconds until expiration" do
      params = create_valid_params()

      {:ok, auth_code} =
        AuthorizationCode.new(
          params.code,
          params.client_id,
          params.user_id,
          params.redirect_uri,
          params.scopes,
          nil,
          600
        )

      time_left = AuthorizationCode.time_to_expiry(auth_code)
      assert time_left > 0
      assert time_left <= 600
    end

    test "returns 0 for expired code" do
      params = create_valid_params()

      {:ok, auth_code} =
        AuthorizationCode.new(
          params.code,
          params.client_id,
          params.user_id,
          params.redirect_uri,
          params.scopes,
          nil,
          600
        )

      # Manually set expires_at to the past
      expired_code = %{auth_code | expires_at: DateTime.add(DateTime.utc_now(), -10, :second)}
      assert AuthorizationCode.time_to_expiry(expired_code) == 0
    end
  end

  describe "to_string/1" do
    test "returns the code value" do
      params = create_valid_params()

      {:ok, auth_code} =
        AuthorizationCode.new(
          params.code,
          params.client_id,
          params.user_id,
          params.redirect_uri,
          params.scopes
        )

      assert AuthorizationCode.to_string(auth_code) == params.code
    end
  end

  describe "String.Chars protocol" do
    test "converts authorization code to string" do
      params = create_valid_params()

      {:ok, auth_code} =
        AuthorizationCode.new(
          params.code,
          params.client_id,
          params.user_id,
          params.redirect_uri,
          params.scopes
        )

      assert to_string(auth_code) == params.code
    end
  end

  describe "Jason.Encoder protocol" do
    test "encodes authorization code to JSON" do
      params = create_valid_params()

      {:ok, auth_code} =
        AuthorizationCode.new(
          params.code,
          params.client_id,
          params.user_id,
          params.redirect_uri,
          params.scopes
        )

      assert {:ok, json} = Jason.encode(auth_code)
      assert json == Jason.encode!(params.code)
    end
  end
end
