defmodule Thalamus.Domain.ValueObjects.GrantTypeTest do
  use ExUnit.Case, async: true

  alias Thalamus.Domain.ValueObjects.GrantType

  describe "new/1" do
    test "creates valid authorization_code grant type" do
      assert {:ok, %GrantType{type: :authorization_code}} = GrantType.new(:authorization_code)
    end

    test "creates valid client_credentials grant type" do
      assert {:ok, %GrantType{type: :client_credentials}} = GrantType.new(:client_credentials)
    end

    test "creates valid refresh_token grant type" do
      assert {:ok, %GrantType{type: :refresh_token}} = GrantType.new(:refresh_token)
    end

    test "creates valid implicit grant type" do
      assert {:ok, %GrantType{type: :implicit}} = GrantType.new(:implicit)
    end

    test "creates valid password grant type" do
      assert {:ok, %GrantType{type: :password}} = GrantType.new(:password)
    end

    test "sets correct properties for authorization_code" do
      assert {:ok, grant} = GrantType.new(:authorization_code)
      assert grant.type == :authorization_code
      assert grant.requires_user == true
      assert grant.requires_client_secret == true
      assert grant.issues_refresh_token == true
      assert grant.pkce_required == true
    end

    test "sets correct properties for client_credentials" do
      assert {:ok, grant} = GrantType.new(:client_credentials)
      assert grant.type == :client_credentials
      assert grant.requires_user == false
      assert grant.requires_client_secret == true
      assert grant.issues_refresh_token == false
      assert grant.pkce_required == false
    end

    test "sets correct properties for refresh_token" do
      assert {:ok, grant} = GrantType.new(:refresh_token)
      assert grant.type == :refresh_token
      assert grant.requires_user == true
      assert grant.requires_client_secret == true
      assert grant.issues_refresh_token == true
      assert grant.pkce_required == false
    end

    test "sets correct properties for implicit" do
      assert {:ok, grant} = GrantType.new(:implicit)
      assert grant.type == :implicit
      assert grant.requires_user == true
      assert grant.requires_client_secret == false
      assert grant.issues_refresh_token == false
      assert grant.pkce_required == false
    end

    test "sets correct properties for password" do
      assert {:ok, grant} = GrantType.new(:password)
      assert grant.type == :password
      assert grant.requires_user == true
      assert grant.requires_client_secret == true
      assert grant.issues_refresh_token == true
      assert grant.pkce_required == false
    end

    test "returns error for invalid grant type atom" do
      assert {:error, :invalid_grant_type} = GrantType.new(:invalid_type)
      assert {:error, :invalid_grant_type} = GrantType.new(:unknown)
    end

    test "returns error for non-atom input" do
      assert {:error, :invalid_grant_type} = GrantType.new("authorization_code")
      assert {:error, :invalid_grant_type} = GrantType.new(123)
    end

    test "returns error for nil" do
      assert {:error, :invalid_grant_type} = GrantType.new(nil)
    end
  end

  describe "authorization_code/0" do
    test "creates authorization code grant type" do
      assert {:ok, %GrantType{type: :authorization_code}} = GrantType.authorization_code()
    end

    test "sets pkce_required to true" do
      assert {:ok, grant} = GrantType.authorization_code()
      assert grant.pkce_required == true
    end
  end

  describe "client_credentials/0" do
    test "creates client credentials grant type" do
      assert {:ok, %GrantType{type: :client_credentials}} = GrantType.client_credentials()
    end

    test "sets requires_user to false" do
      assert {:ok, grant} = GrantType.client_credentials()
      assert grant.requires_user == false
    end
  end

  describe "refresh_token/0" do
    test "creates refresh token grant type" do
      assert {:ok, %GrantType{type: :refresh_token}} = GrantType.refresh_token()
    end
  end

  describe "implicit/0" do
    test "creates implicit grant type" do
      assert {:ok, %GrantType{type: :implicit}} = GrantType.implicit()
    end
  end

  describe "password/0" do
    test "creates password grant type" do
      assert {:ok, %GrantType{type: :password}} = GrantType.password()
    end
  end

  describe "recommended?/1" do
    test "returns true for authorization_code" do
      {:ok, grant} = GrantType.authorization_code()
      assert GrantType.recommended?(grant) == true
    end

    test "returns true for client_credentials" do
      {:ok, grant} = GrantType.client_credentials()
      assert GrantType.recommended?(grant) == true
    end

    test "returns true for refresh_token" do
      {:ok, grant} = GrantType.refresh_token()
      assert GrantType.recommended?(grant) == true
    end

    test "returns false for implicit (deprecated)" do
      {:ok, grant} = GrantType.implicit()
      assert GrantType.recommended?(grant) == false
    end

    test "returns false for password (deprecated)" do
      {:ok, grant} = GrantType.password()
      assert GrantType.recommended?(grant) == false
    end
  end

  describe "requires_user?/1" do
    test "returns true for grant types requiring user" do
      {:ok, auth_code} = GrantType.authorization_code()
      assert GrantType.requires_user?(auth_code) == true

      {:ok, refresh} = GrantType.refresh_token()
      assert GrantType.requires_user?(refresh) == true

      {:ok, implicit} = GrantType.implicit()
      assert GrantType.requires_user?(implicit) == true

      {:ok, password} = GrantType.password()
      assert GrantType.requires_user?(password) == true
    end

    test "returns false for client_credentials" do
      {:ok, grant} = GrantType.client_credentials()
      assert GrantType.requires_user?(grant) == false
    end
  end

  describe "requires_client_secret?/1" do
    test "returns true for grant types requiring client secret" do
      {:ok, auth_code} = GrantType.authorization_code()
      assert GrantType.requires_client_secret?(auth_code) == true

      {:ok, client_creds} = GrantType.client_credentials()
      assert GrantType.requires_client_secret?(client_creds) == true

      {:ok, refresh} = GrantType.refresh_token()
      assert GrantType.requires_client_secret?(refresh) == true

      {:ok, password} = GrantType.password()
      assert GrantType.requires_client_secret?(password) == true
    end

    test "returns false for implicit grant" do
      {:ok, grant} = GrantType.implicit()
      assert GrantType.requires_client_secret?(grant) == false
    end
  end

  describe "issues_refresh_token?/1" do
    test "returns true for grant types that issue refresh tokens" do
      {:ok, auth_code} = GrantType.authorization_code()
      assert GrantType.issues_refresh_token?(auth_code) == true

      {:ok, refresh} = GrantType.refresh_token()
      assert GrantType.issues_refresh_token?(refresh) == true

      {:ok, password} = GrantType.password()
      assert GrantType.issues_refresh_token?(password) == true
    end

    test "returns false for grant types that don't issue refresh tokens" do
      {:ok, client_creds} = GrantType.client_credentials()
      assert GrantType.issues_refresh_token?(client_creds) == false

      {:ok, implicit} = GrantType.implicit()
      assert GrantType.issues_refresh_token?(implicit) == false
    end
  end

  describe "pkce_required?/1" do
    test "returns true for authorization_code" do
      {:ok, grant} = GrantType.authorization_code()
      assert GrantType.pkce_required?(grant) == true
    end

    test "returns false for other grant types" do
      {:ok, client_creds} = GrantType.client_credentials()
      assert GrantType.pkce_required?(client_creds) == false

      {:ok, refresh} = GrantType.refresh_token()
      assert GrantType.pkce_required?(refresh) == false

      {:ok, implicit} = GrantType.implicit()
      assert GrantType.pkce_required?(implicit) == false

      {:ok, password} = GrantType.password()
      assert GrantType.pkce_required?(password) == false
    end
  end

  describe "compatible?/2" do
    test "authorization_code is compatible with refresh_token" do
      {:ok, auth_code} = GrantType.authorization_code()
      {:ok, refresh} = GrantType.refresh_token()
      assert GrantType.compatible?(auth_code, refresh) == true
    end

    test "password is compatible with refresh_token" do
      {:ok, password} = GrantType.password()
      {:ok, refresh} = GrantType.refresh_token()
      assert GrantType.compatible?(password, refresh) == true
    end

    test "client_credentials is compatible with itself" do
      {:ok, client_creds1} = GrantType.client_credentials()
      {:ok, client_creds2} = GrantType.client_credentials()
      assert GrantType.compatible?(client_creds1, client_creds2) == true
    end

    test "implicit is not compatible with refresh_token" do
      {:ok, implicit} = GrantType.implicit()
      {:ok, refresh} = GrantType.refresh_token()
      assert GrantType.compatible?(implicit, refresh) == false
    end

    test "authorization_code is not compatible with client_credentials" do
      {:ok, auth_code} = GrantType.authorization_code()
      {:ok, client_creds} = GrantType.client_credentials()
      assert GrantType.compatible?(auth_code, client_creds) == false
    end

    test "authorization_code is not compatible with itself" do
      {:ok, auth_code1} = GrantType.authorization_code()
      {:ok, auth_code2} = GrantType.authorization_code()
      assert GrantType.compatible?(auth_code1, auth_code2) == false
    end

    test "refresh_token is not compatible with authorization_code (order matters)" do
      {:ok, refresh} = GrantType.refresh_token()
      {:ok, auth_code} = GrantType.authorization_code()
      assert GrantType.compatible?(refresh, auth_code) == false
    end
  end

  describe "String.Chars protocol" do
    test "converts authorization_code to string" do
      {:ok, grant} = GrantType.authorization_code()
      assert to_string(grant) == "GrantType:authorization_code"
    end

    test "converts client_credentials to string" do
      {:ok, grant} = GrantType.client_credentials()
      assert to_string(grant) == "GrantType:client_credentials"
    end

    test "converts refresh_token to string" do
      {:ok, grant} = GrantType.refresh_token()
      assert to_string(grant) == "GrantType:refresh_token"
    end

    test "converts implicit to string" do
      {:ok, grant} = GrantType.implicit()
      assert to_string(grant) == "GrantType:implicit"
    end

    test "converts password to string" do
      {:ok, grant} = GrantType.password()
      assert to_string(grant) == "GrantType:password"
    end
  end

  describe "Jason.Encoder protocol" do
    test "encodes authorization_code grant type to JSON" do
      {:ok, grant} = GrantType.authorization_code()
      assert {:ok, json} = Jason.encode(grant)
      decoded = Jason.decode!(json)

      assert decoded["type"] == "authorization_code"
      assert decoded["requires_user"] == true
      assert decoded["requires_client_secret"] == true
      assert decoded["issues_refresh_token"] == true
      assert decoded["pkce_required"] == true
    end

    test "encodes client_credentials grant type to JSON" do
      {:ok, grant} = GrantType.client_credentials()
      assert {:ok, json} = Jason.encode(grant)
      decoded = Jason.decode!(json)

      assert decoded["type"] == "client_credentials"
      assert decoded["requires_user"] == false
      assert decoded["requires_client_secret"] == true
      assert decoded["issues_refresh_token"] == false
      assert decoded["pkce_required"] == false
    end

    test "encodes refresh_token grant type to JSON" do
      {:ok, grant} = GrantType.refresh_token()
      assert {:ok, json} = Jason.encode(grant)
      decoded = Jason.decode!(json)

      assert decoded["type"] == "refresh_token"
      assert decoded["requires_user"] == true
      assert decoded["requires_client_secret"] == true
      assert decoded["issues_refresh_token"] == true
      assert decoded["pkce_required"] == false
    end

    test "encodes implicit grant type to JSON" do
      {:ok, grant} = GrantType.implicit()
      assert {:ok, json} = Jason.encode(grant)
      decoded = Jason.decode!(json)

      assert decoded["type"] == "implicit"
      assert decoded["requires_user"] == true
      assert decoded["requires_client_secret"] == false
      assert decoded["issues_refresh_token"] == false
      assert decoded["pkce_required"] == false
    end

    test "encodes password grant type to JSON" do
      {:ok, grant} = GrantType.password()
      assert {:ok, json} = Jason.encode(grant)
      decoded = Jason.decode!(json)

      assert decoded["type"] == "password"
      assert decoded["requires_user"] == true
      assert decoded["requires_client_secret"] == true
      assert decoded["issues_refresh_token"] == true
      assert decoded["pkce_required"] == false
    end

    test "encodes all grant type properties" do
      {:ok, grant} = GrantType.authorization_code()
      assert {:ok, json} = Jason.encode(grant)
      decoded = Jason.decode!(json)

      # Ensure all properties are present
      assert Map.has_key?(decoded, "type")
      assert Map.has_key?(decoded, "requires_user")
      assert Map.has_key?(decoded, "requires_client_secret")
      assert Map.has_key?(decoded, "issues_refresh_token")
      assert Map.has_key?(decoded, "pkce_required")
    end
  end
end
