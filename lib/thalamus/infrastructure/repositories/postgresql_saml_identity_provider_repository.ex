defmodule Thalamus.Infrastructure.Repositories.PostgreSQLSamlIdentityProviderRepository do
  @moduledoc """
  PostgreSQL implementation of SamlIdentityProviderRepository port.

  Handles persistence and retrieval of SAML Identity Provider entities.

  SOLID: Single Responsibility — only handles SAML IdP data persistence.
  Dependency Inversion — implements the port defined by the Application layer.
  """

  @behaviour Thalamus.Application.Ports.SamlIdentityProviderRepository

  alias Thalamus.Repo
  alias Thalamus.Domain.Entities.SamlIdentityProvider
  alias Thalamus.Domain.ValueObjects.{OrganizationId, SamlEntityId}
  alias Thalamus.Infrastructure.Persistence.Schemas.SamlIdentityProviderSchema

  import Ecto.Query

  @impl true
  def find_by_organization_id(%OrganizationId{} = org_id) do
    org_uuid = extract_uuid(OrganizationId.to_string(org_id))

    query =
      from s in SamlIdentityProviderSchema,
        where: s.organization_id == ^org_uuid

    case Repo.one(query) do
      nil -> {:error, :not_found}
      schema -> {:ok, schema_to_entity(schema)}
    end
  end

  @impl true
  def find_by_email_domain(email_domain) when is_binary(email_domain) do
    domain = String.downcase(email_domain)

    query =
      from s in SamlIdentityProviderSchema,
        where: s.enabled == true,
        where: ^domain in s.allowed_domains

    case Repo.one(query) do
      nil -> {:error, :not_found}
      schema -> {:ok, schema_to_entity(schema)}
    end
  end

  @impl true
  def save(%SamlIdentityProvider{} = idp) do
    changeset =
      case Repo.get(SamlIdentityProviderSchema, idp.id) do
        nil ->
          SamlIdentityProviderSchema.create_changeset(entity_to_map(idp))

        existing ->
          SamlIdentityProviderSchema.update_changeset(existing, entity_to_map(idp))
      end

    case Repo.insert_or_update(changeset) do
      {:ok, schema} -> {:ok, schema_to_entity(schema)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @impl true
  def delete(%OrganizationId{} = org_id) do
    org_uuid = extract_uuid(OrganizationId.to_string(org_id))

    query =
      from s in SamlIdentityProviderSchema,
        where: s.organization_id == ^org_uuid

    case Repo.one(query) do
      nil ->
        {:error, :not_found}

      schema ->
        Repo.delete(schema)
        :ok
    end
  end

  # ─── Private Converters ─────────────────────────────────────

  defp schema_to_entity(%SamlIdentityProviderSchema{} = schema) do
    {:ok, org_id} = OrganizationId.from_string(schema.organization_id)
    {:ok, idp_entity_id} = SamlEntityId.new(schema.idp_entity_id)

    %SamlIdentityProvider{
      id: schema.id,
      organization_id: org_id,
      name: schema.name,
      idp_entity_id: idp_entity_id,
      idp_sso_url: schema.idp_sso_url,
      idp_slo_url: schema.idp_slo_url,
      idp_certificate: schema.idp_certificate,
      sp_entity_id: schema.sp_entity_id,
      idp_metadata_xml: schema.idp_metadata_xml,
      enabled: schema.enabled,
      force_saml: schema.force_saml,
      jit_provisioning: schema.jit_provisioning,
      allowed_domains: schema.allowed_domains,
      attribute_mapping: schema.attribute_mapping,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end

  defp entity_to_map(%SamlIdentityProvider{} = entity) do
    %{
      id: entity.id,
      organization_id: extract_uuid(OrganizationId.to_string(entity.organization_id)),
      name: entity.name,
      idp_entity_id: to_string(entity.idp_entity_id),
      idp_sso_url: entity.idp_sso_url,
      idp_slo_url: entity.idp_slo_url,
      idp_certificate: entity.idp_certificate,
      sp_entity_id: entity.sp_entity_id,
      idp_metadata_xml: entity.idp_metadata_xml,
      enabled: entity.enabled,
      force_saml: entity.force_saml,
      jit_provisioning: entity.jit_provisioning,
      allowed_domains: entity.allowed_domains,
      attribute_mapping:
        if is_struct(entity.attribute_mapping) do
          entity.attribute_mapping.mappings
        else
          entity.attribute_mapping
        end
    }
  end

  defp extract_uuid(prefixed_id) when is_binary(prefixed_id) do
    String.replace_prefix(prefixed_id, "org_", "")
  end
end
