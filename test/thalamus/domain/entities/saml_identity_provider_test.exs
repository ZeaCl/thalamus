defmodule Thalamus.Domain.Entities.SamlIdentityProviderTest do
  use ExUnit.Case, async: false

  alias Thalamus.Domain.Entities.SamlIdentityProvider
  alias Thalamus.Domain.ValueObjects.OrganizationId

  @valid_attrs %{
    name: "Azure AD - Contoso",
    idp_entity_id: "https://sts.windows.net/contoso/",
    idp_sso_url: "https://login.microsoftonline.com/contoso/saml2",
    idp_certificate: String.duplicate("A", 200)
  }

  setup do
    {:ok, org_id} = OrganizationId.generate()
    %{org_id: org_id}
  end

  describe "new/1 with valid attributes" do
    test "creates with minimum required fields", %{org_id: org_id} do
      attrs = Map.put(@valid_attrs, :organization_id, org_id)

      assert {:ok, idp} = SamlIdentityProvider.new(attrs)
      assert idp.name == "Azure AD - Contoso"
      assert idp.organization_id == org_id
      assert idp.enabled == true
      assert idp.force_saml == false
      assert idp.jit_provisioning == true
      assert idp.allowed_domains == []
      assert idp.attribute_mapping.mappings == %{}
    end

    test "creates with all optional fields", %{org_id: org_id} do
      attrs =
        @valid_attrs
        |> Map.put(:organization_id, org_id)
        |> Map.merge(%{
          idp_slo_url: "https://example.com/slo",
          sp_entity_id: "https://custom.sp.zea.cl",
          allowed_domains: ["contoso.com"],
          enabled: false,
          force_saml: true,
          jit_provisioning: false,
          attribute_mapping: %{"email" => "emailaddress"}
        })

      assert {:ok, idp} = SamlIdentityProvider.new(attrs)
      assert idp.idp_slo_url == "https://example.com/slo"
      assert idp.sp_entity_id == "https://custom.sp.zea.cl"
      assert idp.allowed_domains == ["contoso.com"]
      assert idp.enabled == false
      assert idp.force_saml == true
      assert idp.jit_provisioning == false
    end

    test "cleans certificate by removing PEM headers", %{org_id: org_id} do
      cert_with_headers = """
      -----BEGIN CERTIFICATE-----
      MIIDXTCCAkWgAwIBAgIJAKl...
      -----END CERTIFICATE-----
      """

      attrs =
        %{@valid_attrs | idp_certificate: cert_with_headers} |> Map.put(:organization_id, org_id)

      assert {:ok, idp} = SamlIdentityProvider.new(attrs)
      refute String.contains?(idp.idp_certificate, "BEGIN CERTIFICATE")
    end
  end

  describe "new/1 with invalid attributes" do
    test "rejects missing required fields" do
      assert {:error, :missing_required_fields} = SamlIdentityProvider.new(%{})
    end

    test "rejects missing organization_id", %{org_id: _org_id} do
      assert {:error, :missing_required_fields} = SamlIdentityProvider.new(@valid_attrs)
    end

    test "rejects invalid entity ID", %{org_id: org_id} do
      attrs = %{@valid_attrs | idp_entity_id: "invalid"} |> Map.put(:organization_id, org_id)
      assert {:error, :invalid_entity_id} = SamlIdentityProvider.new(attrs)
    end

    test "rejects invalid SSO URL", %{org_id: org_id} do
      attrs = %{@valid_attrs | idp_sso_url: "not_a_url"} |> Map.put(:organization_id, org_id)
      assert {:error, :invalid_url} = SamlIdentityProvider.new(attrs)
    end

    test "rejects name longer than 255 chars", %{org_id: org_id} do
      long_name = String.duplicate("a", 256)
      attrs = %{@valid_attrs | name: long_name} |> Map.put(:organization_id, org_id)
      assert {:error, :name_too_long} = SamlIdentityProvider.new(attrs)
    end
  end

  describe "predicates" do
    test "enabled?/1", %{org_id: org_id} do
      {:ok, idp} = SamlIdentityProvider.new(Map.put(@valid_attrs, :organization_id, org_id))
      assert SamlIdentityProvider.enabled?(idp)

      {:ok, idp2} =
        SamlIdentityProvider.new(
          Map.merge(Map.put(@valid_attrs, :organization_id, org_id), %{enabled: false})
        )

      refute SamlIdentityProvider.enabled?(idp2)
    end

    test "force_saml?/1", %{org_id: org_id} do
      {:ok, idp} = SamlIdentityProvider.new(Map.put(@valid_attrs, :organization_id, org_id))
      refute SamlIdentityProvider.force_saml?(idp)

      {:ok, idp2} =
        SamlIdentityProvider.new(
          Map.merge(Map.put(@valid_attrs, :organization_id, org_id), %{force_saml: true})
        )

      assert SamlIdentityProvider.force_saml?(idp2)
    end

    test "jit_enabled?/1", %{org_id: org_id} do
      {:ok, idp} = SamlIdentityProvider.new(Map.put(@valid_attrs, :organization_id, org_id))
      assert SamlIdentityProvider.jit_enabled?(idp)

      {:ok, idp2} =
        SamlIdentityProvider.new(
          Map.merge(Map.put(@valid_attrs, :organization_id, org_id), %{jit_provisioning: false})
        )

      refute SamlIdentityProvider.jit_enabled?(idp2)
    end
  end

  describe "domain_allowed?/2" do
    test "returns true when domain matches", %{org_id: org_id} do
      {:ok, idp} =
        SamlIdentityProvider.new(
          Map.merge(Map.put(@valid_attrs, :organization_id, org_id), %{
            allowed_domains: ["contoso.com"]
          })
        )

      assert SamlIdentityProvider.domain_allowed?(idp, "contoso.com")
    end

    test "returns false when domain does not match", %{org_id: org_id} do
      {:ok, idp} =
        SamlIdentityProvider.new(
          Map.merge(Map.put(@valid_attrs, :organization_id, org_id), %{
            allowed_domains: ["contoso.com"]
          })
        )

      refute SamlIdentityProvider.domain_allowed?(idp, "other.com")
    end

    test "returns true for any domain when allowed_domains is empty", %{org_id: org_id} do
      {:ok, idp} = SamlIdentityProvider.new(Map.put(@valid_attrs, :organization_id, org_id))
      assert SamlIdentityProvider.domain_allowed?(idp, "any.com")
      assert SamlIdentityProvider.domain_allowed?(idp, "whatever.org")
    end
  end
end
