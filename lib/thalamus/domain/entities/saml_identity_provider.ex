defmodule Thalamus.Domain.Entities.SamlIdentityProvider do
  @moduledoc """
  Entity representing a SAML Identity Provider configuration for an organization.

  Each organization can have one SAML IdP configuration. This entity stores
  the IdP metadata, certificate, and behavioral settings (enabled, force_saml,
  JIT provisioning, domain matching).

  SOLID: Single Responsibility — only manages SAML IdP configuration data.
  """

  alias Thalamus.Domain.ValueObjects.{
    OrganizationId,
    SamlEntityId,
    SamlAttributeMapping
  }

  @type t :: %__MODULE__{
          id: binary(),
          organization_id: OrganizationId.t(),
          name: String.t(),
          idp_entity_id: SamlEntityId.t(),
          idp_sso_url: String.t(),
          idp_slo_url: String.t() | nil,
          idp_certificate: String.t(),
          sp_entity_id: String.t() | nil,
          idp_metadata_xml: String.t() | nil,
          enabled: boolean(),
          force_saml: boolean(),
          jit_provisioning: boolean(),
          allowed_domains: [String.t()],
          attribute_mapping: SamlAttributeMapping.t() | map(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :organization_id,
    :name,
    :idp_entity_id,
    :idp_sso_url,
    :idp_slo_url,
    :idp_certificate,
    :sp_entity_id,
    :idp_metadata_xml,
    :inserted_at,
    :updated_at,
    enabled: true,
    force_saml: false,
    jit_provisioning: true,
    allowed_domains: [],
    attribute_mapping: %{}
  ]

  @required_fields [:name, :idp_entity_id, :idp_sso_url, :idp_certificate, :organization_id]

  @doc """
  Creates a new SamlIdentityProvider with validation.

  ## Required fields
  - :name — human-readable name (e.g. "Azure AD - Contoso")
  - :idp_entity_id — SAML entity ID of the IdP (string, validated as SamlEntityId)
  - :idp_sso_url — SSO URL of the IdP
  - :idp_certificate — X.509 certificate in PEM format (for signature validation)
  - :organization_id — OrganizationId value object

  ## Optional fields
  - :idp_slo_url — Single Logout URL
  - :sp_entity_id — Custom SP entity ID (defaults to global)
  - :idp_metadata_xml — Original IdP metadata XML (for reference/debugging)
  - :enabled — defaults to true
  - :force_saml — defaults to false (force SAML-only login)
  - :jit_provisioning — defaults to true (auto-create users)
  - :allowed_domains — list of email domains for this IdP
  - :attribute_mapping — SAML → User field mapping

  ## Examples

      iex> {:ok, org_id} = OrganizationId.generate()
      iex> SamlIdentityProvider.new(%{
      ...>   name: "Azure AD",
      ...>   idp_entity_id: "https://sts.windows.net/contoso/",
      ...>   idp_sso_url: "https://login.microsoftonline.com/contoso/saml2",
      ...>   idp_certificate: "MIID...",
      ...>   organization_id: org_id
      ...> })
      {:ok, %SamlIdentityProvider{...}}

      iex> SamlIdentityProvider.new(%{})
      {:error, :missing_required_fields}
  """
  @spec new(map()) :: {:ok, t()} | {:error, atom()}
  def new(attrs) when is_map(attrs) do
    with :ok <- validate_required(attrs, @required_fields),
         {:ok, idp_entity_id} <- SamlEntityId.new(Map.get(attrs, :idp_entity_id)),
         {:ok, name} <- validate_name(Map.get(attrs, :name)),
         :ok <- validate_url(Map.get(attrs, :idp_sso_url), "idp_sso_url"),
         :ok <- validate_certificate(Map.get(attrs, :idp_certificate)),
         {:ok, attr_mapping} <- SamlAttributeMapping.new(Map.get(attrs, :attribute_mapping, %{})) do
      now = DateTime.truncate(DateTime.utc_now(), :second)

      {:ok,
       %__MODULE__{
         id: Map.get(attrs, :id, Ecto.UUID.generate()),
         organization_id: Map.get(attrs, :organization_id),
         name: name,
         idp_entity_id: idp_entity_id,
         idp_sso_url: Map.get(attrs, :idp_sso_url),
         idp_slo_url: clean_nil(Map.get(attrs, :idp_slo_url)),
         idp_certificate: clean_certificate(Map.get(attrs, :idp_certificate)),
         sp_entity_id: clean_nil(Map.get(attrs, :sp_entity_id)),
         idp_metadata_xml: clean_nil(Map.get(attrs, :idp_metadata_xml)),
         enabled: Map.get(attrs, :enabled, true),
         force_saml: Map.get(attrs, :force_saml, false),
         jit_provisioning: Map.get(attrs, :jit_provisioning, true),
         allowed_domains: Map.get(attrs, :allowed_domains, []),
         attribute_mapping: attr_mapping,
         inserted_at: Map.get(attrs, :inserted_at, now),
         updated_at: now
       }}
    end
  end

  def new(_), do: {:error, :invalid_attributes}

  @doc """
  Returns true if the SAML IdP is enabled.
  """
  @spec enabled?(t()) :: boolean()
  def enabled?(%__MODULE__{enabled: true}), do: true
  def enabled?(_), do: false

  @doc """
  Returns true if SAML is forced for this organization (no password login).
  """
  @spec force_saml?(t()) :: boolean()
  def force_saml?(%__MODULE__{force_saml: true}), do: true
  def force_saml?(_), do: false

  @doc """
  Returns true if JIT (Just-in-Time) user provisioning is enabled.
  """
  @spec jit_enabled?(t()) :: boolean()
  def jit_enabled?(%__MODULE__{jit_provisioning: true}), do: true
  def jit_enabled?(_), do: false

  @doc """
  Checks if a given email domain is allowed for this IdP.

  Returns true if allowed_domains is empty (all domains allowed) or
  if the domain is explicitly listed.

  ## Examples

      iex> idp = %SamlIdentityProvider{allowed_domains: ["contoso.com"]}
      iex> SamlIdentityProvider.domain_allowed?(idp, "contoso.com")
      true

      iex> SamlIdentityProvider.domain_allowed?(idp, "other.com")
      false

      iex> idp = %SamlIdentityProvider{allowed_domains: []}
      iex> SamlIdentityProvider.domain_allowed?(idp, "any.com")
      true
  """
  @spec domain_allowed?(t(), String.t()) :: boolean()
  def domain_allowed?(%__MODULE__{allowed_domains: domains}, _email_domain)
      when domains == [] do
    true
  end

  def domain_allowed?(%__MODULE__{allowed_domains: domains}, email_domain)
      when is_binary(email_domain) do
    email_domain in domains
  end

  # ─── Private ────────────────────────────────────────────────

  defp validate_required(attrs, required) do
    missing =
      Enum.reject(required, fn field ->
        value = Map.get(attrs, field)
        value != nil and value != ""
      end)

    case missing do
      [] -> :ok
      _ -> {:error, :missing_required_fields}
    end
  end

  defp validate_name(name) when is_binary(name) and byte_size(name) > 0 do
    if byte_size(name) <= 255 do
      {:ok, name}
    else
      {:error, :name_too_long}
    end
  end

  defp validate_name(_), do: {:error, :invalid_name}

  defp validate_url(url, _field) when is_binary(url) do
    if String.starts_with?(url, "http") and byte_size(url) <= 500 do
      :ok
    else
      {:error, :invalid_url}
    end
  end

  defp validate_url(_, _), do: {:error, :invalid_url}

  defp validate_certificate(cert) when is_binary(cert) do
    # Basic validation: must contain PEM headers or be a base64 blob
    has_headers = String.contains?(cert, "BEGIN CERTIFICATE")
    has_length = byte_size(cert) >= 100

    if has_headers or has_length do
      :ok
    else
      {:error, :invalid_certificate}
    end
  end

  defp validate_certificate(_), do: {:error, :invalid_certificate}

  defp clean_certificate(cert) when is_binary(cert) do
    cert
    |> String.replace("-----BEGIN CERTIFICATE-----", "")
    |> String.replace("-----END CERTIFICATE-----", "")
    |> String.replace("\n", "")
    |> String.replace("\r", "")
    |> String.trim()
  end

  defp clean_nil(nil), do: nil
  defp clean_nil(""), do: nil
  defp clean_nil(value), do: value
end
