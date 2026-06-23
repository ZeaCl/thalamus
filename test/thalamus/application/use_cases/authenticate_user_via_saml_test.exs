defmodule Thalamus.Application.UseCases.AuthenticateUserViaSamlTest do
  use ExUnit.Case, async: true
  import Mox

  alias Thalamus.Application.UseCases.AuthenticateUserViaSaml
  alias Thalamus.Domain.Entities.{User, SamlIdentityProvider}
  alias Thalamus.Domain.ValueObjects.{UserId, Email, PasswordHash, OrganizationId}

  setup :verify_on_exit!

  @valid_assertion %{
    email: "pepito@contoso.com",
    name: "Pepito Pérez"
  }

  defp build_test_user do
    {:ok, user_id} = UserId.generate()
    {:ok, email} = Email.new("pepito@contoso.com")
    {:ok, pass_hash} = PasswordHash.from_password("SecureP@ss1")

    %User{
      id: user_id,
      email: email,
      name: "Pepito Pérez",
      password_hash: pass_hash,
      status: :active,
      verified_at: DateTime.truncate(DateTime.utc_now(), :second),
      failed_login_attempts: 0,
      locked_until: nil,
      mfa_methods: [],
      created_at: DateTime.truncate(DateTime.utc_now(), :second),
      updated_at: DateTime.truncate(DateTime.utc_now(), :second),
      is_agent: false,
      agent_config: nil
    }
  end

  defp build_idp_config(org_id) do
    %SamlIdentityProvider{
      id: Ecto.UUID.generate(),
      organization_id: org_id,
      name: "Azure AD - Contoso",
      idp_entity_id: "https://sts.windows.net/contoso/",
      idp_sso_url: "https://login.microsoftonline.com/contoso/saml2",
      idp_certificate: "MOCKCERT",
      enabled: true,
      force_saml: false,
      jit_provisioning: true,
      allowed_domains: ["contoso.com"],
      attribute_mapping: %{},
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end

  defp deps do
    %{
      user_repository: MockUserRepository,
      saml_idp_repository: MockSamlIdentityProviderRepository,
      saml_service: MockSamlService,
      audit_logger: MockAuditLogger
    }
  end

  setup do
    {:ok, org_id} = OrganizationId.generate()
    # Stub audit logger globally for all tests
    MockAuditLogger
    |> stub(:log_authentication_success, fn _user_id, _data -> :ok end)
    |> stub(:log_authentication_failure, fn _id, _reason, _data -> :ok end)

    {:ok, org_id: org_id}
  end

  describe "execute/3 - JIT provisioning" do
    test "creates a new user when JIT is enabled", %{org_id: org_id} do
      idp_config = build_idp_config(org_id)

      MockSamlIdentityProviderRepository
      |> expect(:find_by_organization_id, fn ^org_id -> {:ok, idp_config} end)

      MockSamlService
      |> expect(:validate_assertion, fn _xml, _idp -> {:ok, @valid_assertion} end)

      MockUserRepository
      |> expect(:find_by_email, fn _email -> {:error, :not_found} end)
      |> expect(:save, fn user -> {:ok, user} end)
      |> expect(:save, fn user -> {:ok, user} end)

      assert {:ok, response} = AuthenticateUserViaSaml.execute("<saml/>", org_id, deps())
      assert response.authenticated == true
      assert response.user_id != nil
    end
  end

  describe "execute/3 - existing user" do
    test "finds existing user by email", %{org_id: org_id} do
      idp_config = build_idp_config(org_id)
      user = build_test_user()

      MockSamlIdentityProviderRepository
      |> expect(:find_by_organization_id, fn ^org_id -> {:ok, idp_config} end)

      MockSamlService
      |> expect(:validate_assertion, fn _xml, _idp -> {:ok, @valid_assertion} end)

      MockUserRepository
      |> expect(:find_by_email, fn _email -> {:ok, user} end)
      |> expect(:save, fn _user -> {:ok, user} end)

      assert {:ok, response} = AuthenticateUserViaSaml.execute("<saml/>", org_id, deps())
      assert response.authenticated == true
    end
  end

  describe "execute/3 - error cases" do
    test "returns error when SAML is disabled", %{org_id: org_id} do
      idp_config = %{build_idp_config(org_id) | enabled: false}

      MockSamlIdentityProviderRepository
      |> expect(:find_by_organization_id, fn ^org_id -> {:ok, idp_config} end)

      assert {:error, :saml_disabled} =
               AuthenticateUserViaSaml.execute("<saml/>", org_id, deps())
    end

    test "returns error when JIT disabled and user not found", %{org_id: org_id} do
      idp_config = %{build_idp_config(org_id) | jit_provisioning: false}

      MockSamlIdentityProviderRepository
      |> expect(:find_by_organization_id, fn ^org_id -> {:ok, idp_config} end)

      MockSamlService
      |> expect(:validate_assertion, fn _xml, _idp -> {:ok, @valid_assertion} end)

      MockUserRepository
      |> expect(:find_by_email, fn _email -> {:error, :not_found} end)

      assert {:error, :saml_user_not_found} =
               AuthenticateUserViaSaml.execute("<saml/>", org_id, deps())
    end

    test "returns error when assertion validation fails", %{org_id: org_id} do
      idp_config = build_idp_config(org_id)

      MockSamlIdentityProviderRepository
      |> expect(:find_by_organization_id, fn ^org_id -> {:ok, idp_config} end)

      MockSamlService
      |> expect(:validate_assertion, fn _xml, _idp ->
        {:error, :invalid_saml_assertion}
      end)

      assert {:error, :invalid_saml_assertion} =
               AuthenticateUserViaSaml.execute("<saml/>", org_id, deps())
    end

    test "returns error when IdP config not found", %{org_id: org_id} do
      MockSamlIdentityProviderRepository
      |> expect(:find_by_organization_id, fn ^org_id -> {:error, :not_found} end)

      assert {:error, :not_found} =
               AuthenticateUserViaSaml.execute("<saml/>", org_id, deps())
    end
  end
end
