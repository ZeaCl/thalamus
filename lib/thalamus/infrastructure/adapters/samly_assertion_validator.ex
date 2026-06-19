defmodule Thalamus.Infrastructure.Adapters.SamlyAssertionValidator do
  @moduledoc """
  Adapter for SAML cryptographic operations using samly/esaml.

  Wraps the samly and esaml libraries for:
  - Building SP metadata XML (for IdP configuration)
  - Building AuthnRequests (HTTP-Redirect binding to IdP)
  - Validating SAML assertions from the IdP

  SOLID:
  - Single Responsibility: Only handles SAML crypto and protocol operations
  - Dependency Inversion: Implements SamlService behaviour from Application layer
  """

  @behaviour Thalamus.Application.Services.SamlService

  alias Thalamus.Domain.Entities.SamlIdentityProvider

  require Logger

  @impl true
  def build_sp_metadata(%SamlIdentityProvider{} = idp) do
    sp_entity_id = resolve_sp_entity_id(idp)
    {_private_key, cert_pem} = load_sp_keys()
    base_url = base_url()
    acs_url = "#{base_url}/auth/saml/acs"
    slo_url = "#{base_url}/auth/saml/slo"

    try do
      metadata_xml =
        :esaml_sp.generate_metadata(%{
          entity_id: sp_entity_id,
          cert: cert_pem,
          org_name: "ZEA Platform",
          org_displayname: "ZEA",
          org_url: base_url,
          tech_contact_name: "ZEA Engineering",
          tech_contact_email: "engineering@zea.cl",
          assertion_consumer_service_url: acs_url,
          single_logout_service_url: slo_url,
          name_id_formats: [
            "urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress",
            "urn:oasis:names:tc:SAML:2.0:nameid-format:persistent"
          ]
        })

      {:ok, to_string(metadata_xml)}
    rescue
      e ->
        Logger.error("SP metadata generation failed: #{inspect(e)}")
        {:error, :metadata_generation_failed}
    end
  end

  @impl true
  def build_authn_request(%SamlIdentityProvider{} = idp, relay_state) do
    sp_entity_id = resolve_sp_entity_id(idp)
    base_url = base_url()
    acs_url = "#{base_url}/auth/saml/acs"

    sp_config = %{
      entity_id: sp_entity_id,
      consume_url: to_charlist(acs_url),
      org_name: "ZEA",
      tech_contact_name: "ZEA Engineering",
      tech_contact_email: "engineering@zea.cl"
    }

    idp_config = %{
      entity_id: to_string(idp.idp_entity_id),
      signon_url: idp.idp_sso_url
    }

    try do
      # Use esaml_sp to generate the AuthnRequest
      # Returns: {:ok, {url, saml_params}} for HTTP-Redirect binding
      result =
        :esaml_sp.generate_authn_request(
          idp_config,
          sp_config,
          to_charlist(relay_state)
        )

      case result do
        {:ok, {url, _saml_params}} ->
          {:ok, to_string(url)}

        {:error, reason} ->
          Logger.error("AuthnRequest generation failed: #{inspect(reason)}")
          {:error, :authn_request_failed}
      end
    rescue
      e ->
        Logger.error("AuthnRequest generation error: #{inspect(e)}")
        {:error, :authn_request_failed}
    end
  end

  @impl true
  def validate_assertion(saml_response_xml, %SamlIdentityProvider{} = idp) do
    cert = clean_pem(idp.idp_certificate)
    idp_entity_id = to_string(idp.idp_entity_id)

    _sp_entity_id = resolve_sp_entity_id(idp)
    _private_key = load_sp_keys() |> elem(0)

    # Build expected audience/recipient URLs
    base_url = base_url()
    acs_url = to_charlist("#{base_url}/auth/saml/acs")

    sp_config = %{
      entity_id: to_charlist(sp_entity_id),
      key: to_charlist(private_key),
      org_name: "ZEA"
    }

    idp_config = %{
      entity_id: to_charlist(idp_entity_id),
      cert: to_charlist(cert)
    }

    try do
      # Use esaml_sp to validate the SAML response (HTTP-POST binding)
      # validate_assertion/2: (SAMLResponseXml, AcsUrl) -> {ok, Attributes} | {error, Reason}
      case :esaml_sp.validate_assertion(
        to_charlist(saml_response_xml),
        acs_url
      ) do
        {:ok, assertion_data} ->
          # Extract attributes from the validated assertion
          name_id = Keyword.get(assertion_data, :name_id, "")
          session_index = Keyword.get(assertion_data, :session_index, "")

          # Attributes are a proplist of {name, [values]}
          attrs = Keyword.get(assertion_data, :attributes, [])

          email =
            extract_attr(attrs, "emailaddress") ||
              extract_attr(attrs, "email") ||
              to_string(name_id)

          name =
            extract_attr(attrs, "displayname") ||
              extract_attr(attrs, "name") ||
              extract_attr(attrs, "givenname")

          Logger.info("SAML assertion validated successfully", email: email)

          {:ok,
           %{
             email: String.downcase(email),
             name: clean_nil(name),
             name_id: to_string(name_id),
             session_index: to_string(session_index)
           }}

        {:error, reason} ->
          Logger.error("SAML assertion validation failed: #{inspect(reason)}")
          {:error, :invalid_saml_assertion}
      end
    rescue
      e ->
        Logger.error("SAML assertion validation error: #{inspect(e)}")
        {:error, :invalid_saml_assertion}
    end
  end

  # ─── Private ────────────────────────────────────────────────

  defp resolve_sp_entity_id(idp) do
    idp.sp_entity_id ||
      Application.get_env(:thalamus, :saml)[:sp_entity_id] ||
      "#{base_url()}/auth/saml/metadata"
  end

  defp base_url do
    endpoint_config = Application.get_env(:thalamus, ThalamusWeb.Endpoint)

    scheme =
      if endpoint_config[:force_ssl] || endpoint_config[:https], do: "https", else: "http"

    host =
      case endpoint_config[:url] do
        nil -> "localhost"
        url when is_list(url) -> Keyword.get(url, :host, "localhost")
        url -> Map.get(url, :host, "localhost")
      end

    "#{scheme}://#{host}"
  end

  defp load_sp_keys do
    private_key_path = Application.get_env(:thalamus, :saml)[:sp_private_key_path]
    cert_path = Application.get_env(:thalamus, :saml)[:sp_certificate_path]

    private_key = File.read!(private_key_path)
    cert = File.read!(cert_path)
    {private_key, cert}
  end

  defp clean_pem(cert) when is_binary(cert) do
    # If cert is a base64 blob (no headers), add headers
    cond do
      String.contains?(cert, "BEGIN CERTIFICATE") ->
        cert

      true ->
        "-----BEGIN CERTIFICATE-----\n#{cert}\n-----END CERTIFICATE-----"
    end
  end

  defp extract_attr(attrs, name) do
    case List.keyfind(attrs, to_charlist(name), 0) do
      {_key, [value | _]} -> to_string(value)
      nil -> nil
    end
  end

  defp clean_nil(nil), do: nil
  defp clean_nil(""), do: nil
  defp clean_nil(value), do: to_string(value)
end
