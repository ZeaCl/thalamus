defmodule Thalamus.Infrastructure.Persistence.Schemas.SamlIdentityProviderSchema do
  @moduledoc """
  Ecto schema for SAML Identity Provider persistence.

  Maps the SamlIdentityProvider domain entity to the database.
  Part of the Infrastructure layer — only used by the repository.

  SOLID: Single Responsibility — only handles database mapping.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Thalamus.Infrastructure.Persistence.Schemas.OrganizationSchema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "saml_identity_providers" do
    field :name, :string
    field :idp_entity_id, :string
    field :idp_sso_url, :string
    field :idp_slo_url, :string
    field :idp_certificate, :string
    field :sp_entity_id, :string
    field :idp_metadata_xml, :string
    field :enabled, :boolean, default: true
    field :force_saml, :boolean, default: false
    field :jit_provisioning, :boolean, default: true
    field :allowed_domains, {:array, :string}, default: []
    field :attribute_mapping, :map, default: %{}

    belongs_to :organization, OrganizationSchema

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a new SAML Identity Provider record.
  """
  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [
      :id,
      :organization_id,
      :name,
      :idp_entity_id,
      :idp_sso_url,
      :idp_slo_url,
      :idp_certificate,
      :sp_entity_id,
      :idp_metadata_xml,
      :enabled,
      :force_saml,
      :jit_provisioning,
      :allowed_domains,
      :attribute_mapping
    ])
    |> validate_required([
      :organization_id,
      :name,
      :idp_entity_id,
      :idp_sso_url,
      :idp_certificate
    ])
    |> unique_constraint(:organization_id,
      name: :saml_identity_providers_organization_id_index
    )
  end

  @doc """
  Changeset for updating an existing SAML Identity Provider record.
  """
  def update_changeset(schema, attrs) do
    schema
    |> cast(attrs, [
      :name,
      :idp_entity_id,
      :idp_sso_url,
      :idp_slo_url,
      :idp_certificate,
      :sp_entity_id,
      :idp_metadata_xml,
      :enabled,
      :force_saml,
      :jit_provisioning,
      :allowed_domains,
      :attribute_mapping
    ])
  end
end
