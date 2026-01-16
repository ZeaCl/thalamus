defmodule Thalamus.Domain.Entities.OAuth2ClientTest do
  use ExUnit.Case, async: true

  alias Thalamus.Domain.Entities.OAuth2Client
  alias Thalamus.Domain.ValueObjects.{ClientId, OrganizationId, GrantType, RedirectUri, Scope}

  describe "create_confidential/2" do
    test "creates confidential client with secret" do
      {:ok, org_id} = OrganizationId.generate()
      assert {:ok, %OAuth2Client{} = client} = OAuth2Client.create_confidential("My App", org_id)

      assert client.name == "My App"
      assert client.client_type == :confidential
      assert is_binary(client.client_secret)
      assert String.length(client.client_secret) > 20
      assert client.is_active == true
    end
  end

  describe "create_public/2" do
    test "creates public client without secret" do
      {:ok, org_id} = OrganizationId.generate()
      assert {:ok, %OAuth2Client{} = client} = OAuth2Client.create_public("Mobile App", org_id)

      assert client.name == "Mobile App"
      assert client.client_type == :public
      assert is_nil(client.client_secret)
    end
  end

  describe "create_m2m/2" do
    test "creates machine-to-machine client" do
      {:ok, org_id} = OrganizationId.generate()
      assert {:ok, %OAuth2Client{} = client} = OAuth2Client.create_m2m("Service", org_id)

      assert client.client_type == :confidential
      assert OAuth2Client.supports_grant_type?(client, :client_credentials)
      assert is_binary(client.client_secret)
    end
  end

  describe "verify_secret/2" do
    test "successfully verifies correct secret" do
      {:ok, org_id} = OrganizationId.generate()
      {:ok, client} = OAuth2Client.create_confidential("App", org_id)

      assert :ok = OAuth2Client.verify_secret(client, client.client_secret)
    end

    test "fails with incorrect secret" do
      {:ok, org_id} = OrganizationId.generate()
      {:ok, client} = OAuth2Client.create_confidential("App", org_id)

      assert {:error, :invalid_client_secret} = OAuth2Client.verify_secret(client, "wrong")
    end

    test "fails for public client" do
      {:ok, org_id} = OrganizationId.generate()
      {:ok, client} = OAuth2Client.create_public("App", org_id)

      assert {:error, :public_client_no_secret} = OAuth2Client.verify_secret(client, "any")
    end
  end

  describe "rotate_secret/1" do
    test "successfully rotates confidential client secret" do
      {:ok, org_id} = OrganizationId.generate()
      {:ok, client} = OAuth2Client.create_confidential("App", org_id)
      old_secret = client.client_secret

      assert {:ok, rotated_client} = OAuth2Client.rotate_secret(client)
      assert rotated_client.client_secret != old_secret
      assert :ok = OAuth2Client.verify_secret(rotated_client, rotated_client.client_secret)

      assert {:error, :invalid_client_secret} =
               OAuth2Client.verify_secret(rotated_client, old_secret)
    end

    test "fails for public client" do
      {:ok, org_id} = OrganizationId.generate()
      {:ok, client} = OAuth2Client.create_public("App", org_id)

      assert {:error, :cannot_rotate_public_client_secret} = OAuth2Client.rotate_secret(client)
    end
  end

  describe "grant type management" do
    test "adds grant type successfully" do
      {:ok, org_id} = OrganizationId.generate()
      {:ok, client} = OAuth2Client.create_confidential("App", org_id)
      {:ok, refresh_grant} = GrantType.refresh_token()

      assert {:ok, updated} = OAuth2Client.add_grant_type(client, refresh_grant)
      assert OAuth2Client.supports_grant_type?(updated, :refresh_token)
    end

    test "fails when adding duplicate grant type" do
      {:ok, org_id} = OrganizationId.generate()
      {:ok, client} = OAuth2Client.create_confidential("App", org_id)
      {:ok, auth_code} = GrantType.authorization_code()

      # authorization_code is already added by default
      assert {:error, :grant_type_already_exists} = OAuth2Client.add_grant_type(client, auth_code)
    end

    test "removes grant type successfully" do
      {:ok, org_id} = OrganizationId.generate()
      {:ok, client} = OAuth2Client.create_confidential("App", org_id)
      {:ok, refresh_grant} = GrantType.refresh_token()
      {:ok, client} = OAuth2Client.add_grant_type(client, refresh_grant)

      assert {:ok, updated} = OAuth2Client.remove_grant_type(client, :refresh_token)
      refute OAuth2Client.supports_grant_type?(updated, :refresh_token)
    end

    test "fails when removing last grant type" do
      {:ok, org_id} = OrganizationId.generate()
      {:ok, client} = OAuth2Client.create_confidential("App", org_id)

      assert {:error, :cannot_remove_last_grant_type} =
               OAuth2Client.remove_grant_type(client, :authorization_code)
    end
  end

  describe "redirect URI management" do
    test "adds redirect URI successfully" do
      {:ok, org_id} = OrganizationId.generate()
      {:ok, client} = OAuth2Client.create_confidential("App", org_id)
      {:ok, uri} = RedirectUri.new("https://app.example.com/callback")

      assert {:ok, updated} = OAuth2Client.add_redirect_uri(client, uri)
      assert OAuth2Client.valid_redirect_uri?(updated, "https://app.example.com/callback")
    end

    test "fails when adding duplicate redirect URI" do
      {:ok, org_id} = OrganizationId.generate()
      {:ok, client} = OAuth2Client.create_confidential("App", org_id)
      {:ok, uri} = RedirectUri.new("https://app.example.com/callback")

      {:ok, client} = OAuth2Client.add_redirect_uri(client, uri)

      assert {:error, :redirect_uri_already_exists} = OAuth2Client.add_redirect_uri(client, uri)
    end

    test "removes redirect URI successfully" do
      {:ok, org_id} = OrganizationId.generate()
      {:ok, client} = OAuth2Client.create_confidential("App", org_id)
      {:ok, uri} = RedirectUri.new("https://app.example.com/callback")

      {:ok, client} = OAuth2Client.add_redirect_uri(client, uri)

      assert {:ok, updated} =
               OAuth2Client.remove_redirect_uri(client, "https://app.example.com/callback")

      refute OAuth2Client.valid_redirect_uri?(updated, "https://app.example.com/callback")
    end

    test "validates redirect URIs correctly" do
      {:ok, org_id} = OrganizationId.generate()
      {:ok, client} = OAuth2Client.create_confidential("App", org_id)
      {:ok, uri1} = RedirectUri.new("https://app.example.com/callback")
      {:ok, uri2} = RedirectUri.new("https://app.example.com/callback2")

      {:ok, client} = OAuth2Client.add_redirect_uri(client, uri1)

      assert OAuth2Client.valid_redirect_uri?(client, "https://app.example.com/callback")
      refute OAuth2Client.valid_redirect_uri?(client, "https://app.example.com/callback2")
    end
  end

  describe "scope management" do
    test "adds scope successfully" do
      {:ok, org_id} = OrganizationId.generate()
      {:ok, client} = OAuth2Client.create_confidential("App", org_id)
      {:ok, profile_scope} = Scope.new("profile")

      assert {:ok, updated} = OAuth2Client.add_scope(client, profile_scope)
      assert OAuth2Client.valid_scopes?(updated, ["openid", "profile"])
    end

    test "fails when adding duplicate scope" do
      {:ok, org_id} = OrganizationId.generate()
      {:ok, client} = OAuth2Client.create_confidential("App", org_id)
      {:ok, openid_scope} = Scope.new("openid")

      # openid is added by default
      assert {:error, :scope_already_exists} = OAuth2Client.add_scope(client, openid_scope)
    end

    test "removes scope successfully" do
      {:ok, org_id} = OrganizationId.generate()
      {:ok, client} = OAuth2Client.create_confidential("App", org_id)
      {:ok, profile_scope} = Scope.new("profile")

      {:ok, client} = OAuth2Client.add_scope(client, profile_scope)
      assert {:ok, updated} = OAuth2Client.remove_scope(client, "profile")
      refute OAuth2Client.valid_scopes?(updated, ["openid", "profile"])
    end

    test "fails when removing last scope" do
      {:ok, org_id} = OrganizationId.generate()
      {:ok, client} = OAuth2Client.create_confidential("App", org_id)

      assert {:error, :cannot_remove_last_scope} = OAuth2Client.remove_scope(client, "openid")
    end

    test "validates scopes correctly" do
      {:ok, org_id} = OrganizationId.generate()
      {:ok, client} = OAuth2Client.create_confidential("App", org_id)
      {:ok, profile} = Scope.new("profile")
      {:ok, email} = Scope.new("email")

      {:ok, client} = OAuth2Client.add_scope(client, profile)

      assert OAuth2Client.valid_scopes?(client, ["openid"])
      assert OAuth2Client.valid_scopes?(client, ["openid", "profile"])
      refute OAuth2Client.valid_scopes?(client, ["openid", "profile", "email"])
      refute OAuth2Client.valid_scopes?(client, ["invalid"])
    end
  end

  describe "activation/deactivation" do
    test "activates client" do
      {:ok, org_id} = OrganizationId.generate()
      {:ok, client} = OAuth2Client.create_confidential("App", org_id)
      {:ok, deactivated} = OAuth2Client.deactivate(client)

      assert {:ok, activated} = OAuth2Client.activate(deactivated)
      assert activated.is_active == true
    end

    test "deactivates client" do
      {:ok, org_id} = OrganizationId.generate()
      {:ok, client} = OAuth2Client.create_confidential("App", org_id)

      assert {:ok, deactivated} = OAuth2Client.deactivate(client)
      assert deactivated.is_active == false
    end
  end

  describe "trusted status" do
    test "marks client as trusted" do
      {:ok, org_id} = OrganizationId.generate()
      {:ok, client} = OAuth2Client.create_confidential("App", org_id)

      assert {:ok, trusted} = OAuth2Client.mark_trusted(client)
      assert trusted.trusted == true
    end

    test "removes trusted status" do
      {:ok, org_id} = OrganizationId.generate()
      {:ok, client} = OAuth2Client.create_confidential("App", org_id)
      {:ok, trusted} = OAuth2Client.mark_trusted(client)

      assert {:ok, untrusted} = OAuth2Client.mark_untrusted(trusted)
      assert untrusted.trusted == false
    end
  end

  describe "protocols" do
    test "implements String.Chars protocol" do
      {:ok, org_id} = OrganizationId.generate()
      {:ok, client} = OAuth2Client.create_confidential("My App", org_id)

      assert to_string(client) == "OAuth2Client<My App>"
    end

    test "implements Jason.Encoder protocol without exposing secret" do
      {:ok, org_id} = OrganizationId.generate()
      {:ok, client} = OAuth2Client.create_confidential("My App", org_id)

      json = Jason.encode!(client)

      assert String.contains?(json, "My App")
      assert String.contains?(json, "confidential")
      # Should NOT expose client secret
      refute String.contains?(json, client.client_secret)
    end
  end

  describe "security properties" do
    test "generates different secrets for each client" do
      {:ok, org_id} = OrganizationId.generate()
      {:ok, client1} = OAuth2Client.create_confidential("App1", org_id)
      {:ok, client2} = OAuth2Client.create_confidential("App2", org_id)

      assert client1.client_secret != client2.client_secret
    end

    test "client secret has sufficient entropy" do
      {:ok, org_id} = OrganizationId.generate()
      {:ok, client} = OAuth2Client.create_confidential("App", org_id)

      # Should be at least 32 characters (256 bits base64 encoded)
      assert String.length(client.client_secret) >= 32
    end
  end
end
