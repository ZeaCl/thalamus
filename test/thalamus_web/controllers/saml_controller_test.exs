defmodule ThalamusWeb.SamlControllerTest do
  use ThalamusWeb.ConnCase, async: false

  alias Thalamus.Domain.Entities.SamlIdentityProvider
  alias Thalamus.Domain.ValueObjects.OrganizationId
  alias Thalamus.Infrastructure.Repositories.PostgreSQLSamlIdentityProviderRepository
  alias Thalamus.Infrastructure.Repositories.PostgreSQLOrganizationRepository
  alias Thalamus.Domain.Entities.Organization
  alias Thalamus.Domain.ValueObjects.Email

  setup do
    {:ok, email} = Email.new("admin@contoso.com")
    {:ok, org} = Organization.new("Test Org", to_string(email))
    {:ok, saved_org} = PostgreSQLOrganizationRepository.save(org)

    {:ok, idp} =
      SamlIdentityProvider.new(%{
        name: "Azure AD - Contoso",
        idp_entity_id: "https://sts.windows.net/contoso/",
        idp_sso_url: "https://login.microsoftonline.com/contoso/saml2",
        idp_certificate: String.duplicate("A", 200),
        organization_id: saved_org.id,
        allowed_domains: ["contoso.com"]
      })

    {:ok, _saved_idp} = PostgreSQLSamlIdentityProviderRepository.save(idp)

    org_id_string = OrganizationId.to_string(saved_org.id)

    %{org_id_string: org_id_string, org_id: saved_org.id}
  end

  describe "GET /auth/saml/init" do
    test "redirects to login when domain unknown" do
      conn = get(build_conn(), "/auth/saml/init?email=pepito@unknown.com")
      assert redirected_to(conn) =~ "/login"
    end

    test "redirects to login when no email param" do
      conn = get(build_conn(), "/auth/saml/init")
      assert redirected_to(conn) =~ "/login"
    end
  end

  describe "GET /auth/saml/metadata/:id" do
    test "returns 404 for invalid org" do
      conn = get(build_conn(), "/auth/saml/metadata/org_nonexistent")
      assert conn.status == 404
    end
  end
end
