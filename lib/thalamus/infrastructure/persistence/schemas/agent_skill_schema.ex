defmodule Thalamus.Infrastructure.Persistence.Schemas.AgentSkillSchema do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "agent_skills" do
    field :name, :string
    field :description, :string
    field :instructions, :string
    field :execution_type, :string
    field :execution_endpoint, :string

    timestamps()
  end

  @doc false
  def changeset(agent_skill, attrs) do
    agent_skill
    |> cast(attrs, [:name, :description, :instructions, :execution_type, :execution_endpoint])
    |> validate_required([:name, :description, :instructions, :execution_type])
    |> validate_inclusion(:execution_type, ["bash", "http"])
    |> unique_constraint(:name)
  end
end
