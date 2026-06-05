defmodule Thalamus.Infrastructure.Persistence.Schemas.ProjectContextSchema do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "project_contexts" do
    field :file_name, :string
    field :content, :string
    field :priority, :integer, default: 0
    
    belongs_to :project, Thalamus.Infrastructure.Persistence.Schemas.ProjectSchema

    timestamps()
  end

  @doc false
  def changeset(project_context, attrs) do
    project_context
    |> cast(attrs, [:project_id, :file_name, :content, :priority])
    |> validate_required([:project_id, :file_name, :content])
  end
end
