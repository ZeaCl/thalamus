defmodule Thalamus.Infrastructure.Persistence.Schemas.OAuth2ClientSchema do
  @moduledoc """
  Ecto schema for OAuth2Client persistence.

  Maps the OAuth2Client domain entity to the database.
  This is part of the Infrastructure layer and should only be used by repositories.

  SOLID Principles Applied:
  - Single Responsibility: Only handles database mapping
  - Dependency Inversion: Domain entities don't depend on this schema
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Thalamus.Infrastructure.Persistence.Schemas.OrganizationSchema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "oauth2_clients" do
    field :client_id_string, :string
    field :name, :string
    field :client_type, Ecto.Enum, values: [:confidential, :public, :m2m]
    field :client_secret, :string
    field :is_active, :boolean, default: true

    # Grant types stored as array of strings
    field :allowed_grant_types, {:array, :string}, default: []

    # Scopes stored as array of strings
    field :allowed_scopes, {:array, :string}, default: []

    # Redirect URIs stored as array of strings
    field :redirect_uris, {:array, :string}, default: []

    # Metadata
    field :description, :string
    field :logo_url, :string
    field :terms_of_service_url, :string
    field :privacy_policy_url, :string

    # Security settings
    field :pkce_required, :boolean, default: false
    field :token_endpoint_auth_method, :string, default: "client_secret_post"

    # Token lifetimes (in seconds)
    field :access_token_lifetime, :integer, default: 3600
    field :refresh_token_lifetime, :integer, default: 2_592_000
    field :authorization_code_lifetime, :integer, default: 600

    # Relationships
    belongs_to :organization, OrganizationSchema

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a new OAuth2 client.

  ## Required fields
  - client_id_string
  - name
  - client_type
  - organization_id
  """
  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [
      :id,
      :client_id_string,
      :name,
      :client_type,
      :client_secret,
      :organization_id,
      :description,
      :logo_url,
      :pkce_required,
      :allowed_grant_types,
      :allowed_scopes,
      :redirect_uris
    ])
    |> validate_required([:client_id_string, :name, :client_type, :organization_id])
    |> validate_client_type()
    |> validate_name()
    |> put_default_values()
    |> unique_constraint(:client_id_string)
  end

  @doc """
  Changeset for updating OAuth2 client attributes.
  """
  def update_changeset(client, attrs) do
    client
    |> cast(attrs, [
      :name,
      :description,
      :logo_url,
      :terms_of_service_url,
      :privacy_policy_url,
      :is_active,
      :pkce_required,
      :allowed_grant_types,
      :allowed_scopes,
      :redirect_uris,
      :access_token_lifetime,
      :refresh_token_lifetime
    ])
    |> validate_name()
    |> validate_urls()
  end

  @doc """
  Changeset for rotating client secret.
  """
  def rotate_secret_changeset(client, new_secret) do
    client
    |> change(%{client_secret: new_secret})
    |> validate_required([:client_secret])
  end

  @doc """
  Changeset for activating a client.
  """
  def activate_changeset(client) do
    client
    |> change(%{is_active: true})
  end

  @doc """
  Changeset for deactivating a client.
  """
  def deactivate_changeset(client) do
    client
    |> change(%{is_active: false})
  end

  @doc """
  Changeset for adding a grant type.
  """
  def add_grant_type_changeset(client, grant_type) do
    existing_grants = client.allowed_grant_types || []

    if grant_type in existing_grants do
      add_error(client |> change(), :allowed_grant_types, "grant type already exists")
    else
      client
      |> change(%{allowed_grant_types: existing_grants ++ [grant_type]})
    end
  end

  @doc """
  Changeset for removing a grant type.
  """
  def remove_grant_type_changeset(client, grant_type) do
    existing_grants = client.allowed_grant_types || []
    new_grants = Enum.reject(existing_grants, &(&1 == grant_type))

    client
    |> change(%{allowed_grant_types: new_grants})
  end

  @doc """
  Changeset for adding a redirect URI.
  """
  def add_redirect_uri_changeset(client, uri) do
    existing_uris = client.redirect_uris || []

    if uri in existing_uris do
      add_error(client |> change(), :redirect_uris, "redirect URI already exists")
    else
      client
      |> change(%{redirect_uris: existing_uris ++ [uri]})
      |> validate_redirect_uri(uri)
    end
  end

  @doc """
  Changeset for removing a redirect URI.
  """
  def remove_redirect_uri_changeset(client, uri) do
    existing_uris = client.redirect_uris || []
    new_uris = Enum.reject(existing_uris, &(&1 == uri))

    client
    |> change(%{redirect_uris: new_uris})
  end

  @doc """
  Changeset for adding a scope.
  """
  def add_scope_changeset(client, scope) do
    existing_scopes = client.allowed_scopes || []

    if scope in existing_scopes do
      add_error(client |> change(), :allowed_scopes, "scope already exists")
    else
      client
      |> change(%{allowed_scopes: existing_scopes ++ [scope]})
    end
  end

  @doc """
  Changeset for removing a scope.
  """
  def remove_scope_changeset(client, scope) do
    existing_scopes = client.allowed_scopes || []
    new_scopes = Enum.reject(existing_scopes, &(&1 == scope))

    client
    |> change(%{allowed_scopes: new_scopes})
  end

  # Private functions

  defp validate_client_type(changeset) do
    changeset
    |> validate_required([:client_type])
    |> validate_inclusion(:client_type, [:confidential, :public, :m2m])
  end

  defp validate_name(changeset) do
    changeset
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 100)
  end

  defp validate_urls(changeset) do
    changeset
    |> validate_url(:logo_url)
    |> validate_url(:terms_of_service_url)
    |> validate_url(:privacy_policy_url)
  end

  defp validate_url(changeset, field) do
    case get_change(changeset, field) do
      nil ->
        changeset

      url ->
        if valid_url?(url) do
          changeset
        else
          add_error(changeset, field, "must be a valid URL")
        end
    end
  end

  defp valid_url?(url) when is_binary(url) do
    uri = URI.parse(url)
    uri.scheme in ["http", "https"] && uri.host != nil
  end

  defp valid_url?(_), do: false

  defp validate_redirect_uri(changeset, uri) do
    if valid_url?(uri) do
      changeset
    else
      add_error(changeset, :redirect_uris, "must be a valid HTTPS URL")
    end
  end

  defp put_default_values(changeset) do
    changeset
    |> put_change(:is_active, true)
    # Only set defaults if values are not provided
    |> put_default_if_missing(:allowed_grant_types, ["client_credentials"])
    |> put_default_if_missing(:allowed_scopes, [])
    |> put_default_if_missing(:redirect_uris, [])
    |> put_change(:access_token_lifetime, 3600)
    |> put_change(:refresh_token_lifetime, 2_592_000)
    |> put_change(:authorization_code_lifetime, 600)
  end

  defp put_default_if_missing(changeset, field, default_value) do
    case get_change(changeset, field) do
      nil -> put_change(changeset, field, default_value)
      _value -> changeset
    end
  end
end
