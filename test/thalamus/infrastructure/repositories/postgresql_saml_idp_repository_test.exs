defmodule Thalamus.Infrastructure.Repositories.PostgreSQLSamlIdpRepositoryTest do
  use Thalamus.DataCase, async: false

  alias Thalamus.Domain.Entities.SamlIdentityProvider
  alias Thalamus.Domain.ValueObjects.OrganizationId
  alias Thalamus.Infrastructure.Repositories.PostgreSQLSamlIdentityProviderRepository
  alias Thalamus.Infrastructure.Repositories.PostgreSQLOrganizationRepository
  alias Thalamus.Domain.Entities.Organization
  alias Thalamus.Domain.ValueObjects.Email

  @repo PostgreSQLSamlIdentityProviderRepository

  @valid_attrs %{
    name: "Azure AD - Contoso",
    idp_entity_id: "https://sts.windows.net/contoso/",
    idp_sso_url: "https://login.microsoftonline.com/contoso/saml2",
    idp_certificate: String.duplicate("A", 200),
    allowed_domains: ["contoso.com"]
  }

  setup do
    {:ok, email} = Email.new("admin@contoso.com")
    {:ok, org} = Organization.new("Test Org", to_string(email))
    {:ok, saved_org} = PostgreSQLOrganizationRepository.save(org)
    org_id = saved_org.id

    %{org_id: org_id}
  end

  describe "save/1 and find_by_organization_id/1" do
    test "saves and retrieves a SAML IdP config", %{org_id: org_id} do
      {:ok, idp} = SamlIdentityProvider.new(Map.put(@valid_attrs, :organization_id, org_id))

      assert {:ok, saved} = @repo.save(idp)
      assert saved.name == "Azure AD - Contoso"
      assert saved.enabled == true

      assert {:ok, retrieved} = @repo.find_by_organization_id(org_id)
      assert retrieved.name == saved.name
      assert retrieved.idp_sso_url == saved.idp_sso_url
    end

    test "updates existing config", %{org_id: org_id} do
      {:ok, idp} = SamlIdentityProvider.new(Map.put(@valid_attrs, :organization_id, org_id))
      {:ok, saved} = @repo.save(idp)

      updated = %{saved | name: "Updated Name", force_saml: true}
      assert {:ok, updated_saved} = @repo.save(updated)
      assert updated_saved.name == "Updated Name"
      assert updated_saved.force_saml == true
    end
  end

  describe "find_by_email_domain/1" do
    test "finds IdP by allowed email domain", %{org_id: org_id} do
      {:ok, idp} = SamlIdentityProvider.new(Map.put(@valid_attrs, :organization_id, org_id))
      {:ok, _saved} = @repo.save(idp)

      assert {:ok, found} = @repo.find_by_email_domain("contoso.com")
      assert found.organization_id == org_id
    end

    test "returns :not_found for unknown domain", %{org_id: org_id} do
      {:ok, idp} = SamlIdentityProvider.new(Map.put(@valid_attrs, :organization_id, org_id))
      {:ok, _saved} = @repo.save(idp)

      assert {:error, :not_found} = @repo.find_by_email_domain("other.com")
    end

    test "does not find disabled IdP by domain", %{org_id: org_id} do
      attrs = Map.put(@valid_attrs, :organization_id, org_id) |> Map.put(:enabled, false)
      {:ok, idp} = SamlIdentityProvider.new(attrs)
      {:ok, _saved} = @repo.save(idp)

      assert {:error, :not_found} = @repo.find_by_email_domain("contoso.com")
    end
  end

  describe "delete/1" do
    test "deletes SAML config for organization", %{org_id: org_id} do
      {:ok, idp} = SamlIdentityProvider.new(Map.put(@valid_attrs, :organization_id, org_id))
      {:ok, _saved} = @repo.save(idp)

      assert :ok = @repo.delete(org_id)
      assert {:error, :not_found} = @repo.find_by_organization_id(org_id)
    end

    test "returns :not_found when deleting non-existent config" do
      {:ok, org_id} = OrganizationId.generate()
      assert {:error, :not_found} = @repo.delete(org_id)
    end
  end
end
