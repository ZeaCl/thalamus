defmodule Thalamus.Infrastructure.Persistence.Schemas.AgentSkillSchemaTest do
  use Thalamus.DataCase, async: false
  alias Thalamus.Infrastructure.Persistence.Schemas.AgentSkillSchema

  describe "AgentSkillSchema" do
    test "changeset/2 with valid attributes" do
      attrs = %{
        name: "zea_cli",
        description: "Uses the Zea CLI tool",
        instructions: "# ZEA CLI\nRun zea deploy to deploy",
        execution_type: "bash"
      }

      changeset = AgentSkillSchema.changeset(%AgentSkillSchema{}, attrs)
      assert changeset.valid?
    end

    test "changeset/2 requires name, description, instructions and execution_type" do
      attrs = %{}
      changeset = AgentSkillSchema.changeset(%AgentSkillSchema{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
      assert "can't be blank" in errors_on(changeset).description
      assert "can't be blank" in errors_on(changeset).instructions
      assert "can't be blank" in errors_on(changeset).execution_type
    end

    test "changeset/2 validates execution_type is one of the allowed values" do
      attrs = %{
        name: "test",
        description: "test",
        instructions: "test",
        execution_type: "invalid_type"
      }

      changeset = AgentSkillSchema.changeset(%AgentSkillSchema{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).execution_type

      # Valid ones
      valid_attrs = %{attrs | execution_type: "bash"}
      assert AgentSkillSchema.changeset(%AgentSkillSchema{}, valid_attrs).valid?

      valid_attrs_http = %{attrs | execution_type: "http"}
      assert AgentSkillSchema.changeset(%AgentSkillSchema{}, valid_attrs_http).valid?
    end

    test "changeset/2 enforces unique name" do
      attrs = %{
        name: "zea_cli",
        description: "Uses the Zea CLI tool",
        instructions: "...",
        execution_type: "bash"
      }

      %AgentSkillSchema{}
      |> AgentSkillSchema.changeset(attrs)
      |> Repo.insert!()

      changeset = AgentSkillSchema.changeset(%AgentSkillSchema{}, attrs)
      {:error, changeset} = Repo.insert(changeset)

      refute changeset.valid?
      assert "has already been taken" in errors_on(changeset).name
    end
  end
end
