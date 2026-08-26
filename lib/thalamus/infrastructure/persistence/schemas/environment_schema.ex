defmodule Thalamus.Infrastructure.Persistence.Schemas.EnvironmentSchema do
  @moduledoc """
  Ecto schema for environment persistence.

  Maps database records to Elixir structs for persistence operations in the Infrastructure layer.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Thalamus.Infrastructure.Persistence.Schemas.OrganizationSchema

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "environments" do
    belongs_to :organization, OrganizationSchema, foreign_key: :organization_id

    field :slug, :string
    field :name, :string

    field :type, Ecto.Enum,
      values: [:production, :staging, :development, :sandbox, :demo],
      default: :development

    field :is_default, :boolean, default: false

    field :status, Ecto.Enum,
      values: [:active, :suspended, :archived],
      default: :active

    field :description, :string

    timestamps(type: :utc_datetime)
  end

  @slug_regex ~r/^[a-z0-9]+(?:-[a-z0-9]+)*$/

  @doc """
  Changeset for creating a new environment.
  """
  def create_changeset(schema \\ %__MODULE__{}, attrs) do
    schema
    |> cast(attrs, [
      :id,
      :organization_id,
      :slug,
      :name,
      :type,
      :is_default,
      :status,
      :description,
      :inserted_at,
      :updated_at
    ])
    |> validate_required([:organization_id, :slug, :name])
    |> normalize_slug()
    |> validate_slug()
    |> validate_length(:name, min: 2, max: 100)
    |> foreign_key_constraint(:organization_id)
    |> unique_constraint(:slug, name: :idx_environments_org_slug)
    |> unique_constraint(:organization_id,
      name: :idx_single_default_env_per_org,
      message: "an organization can only have one default environment"
    )
  end

  @doc """
  Changeset for updating an environment.
  """
  def update_changeset(schema, attrs) do
    schema
    |> cast(attrs, [:name, :type, :is_default, :status, :description])
    |> validate_length(:name, min: 2, max: 100)
    |> unique_constraint([:organization_id],
      name: :idx_single_default_env_per_org,
      message: "an organization can only have one default environment"
    )
  end

  defp normalize_slug(changeset) do
    case get_change(changeset, :slug) do
      nil ->
        changeset

      slug when is_binary(slug) ->
        put_change(changeset, :slug, String.downcase(String.trim(slug)))

      _ ->
        changeset
    end
  end

  defp validate_slug(changeset) do
    changeset
    |> validate_length(:slug, min: 2, max: 50)
    |> validate_format(:slug, @slug_regex,
      message: "must contain only lowercase alphanumeric characters and single hyphens"
    )
  end
end
