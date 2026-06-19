defmodule Thalamus.Infrastructure.Persistence.Schemas.ProjectContextSchemaTest do
  use Thalamus.DataCase, async: true
  alias Thalamus.Infrastructure.Persistence.Schemas.{ProjectContextSchema, ProjectSchema}

  describe "ProjectContextSchema" do
    test "changeset/2 with valid attributes" do
      # Mock a project
      project = Repo.insert!(%ProjectSchema{name: "Test Project"})

      attrs = %{
        project_id: project.id,
        file_name: "AGENTS.md",
        content: "You are an expert in Elixir.",
        priority: 1
      }

      changeset = ProjectContextSchema.changeset(%ProjectContextSchema{}, attrs)
      assert changeset.valid?
    end

    test "changeset/2 requires project_id, file_name and content" do
      attrs = %{}
      changeset = ProjectContextSchema.changeset(%ProjectContextSchema{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).project_id
      assert "can't be blank" in errors_on(changeset).file_name
      assert "can't be blank" in errors_on(changeset).content
    end

    test "changeset/2 defaults priority to 0 if not provided" do
      project = Repo.insert!(%ProjectSchema{name: "Test Project 2"})
      attrs = %{project_id: project.id, file_name: "RULES.md", content: "No CSS"}

      changeset = ProjectContextSchema.changeset(%ProjectContextSchema{}, attrs)
      assert changeset.valid?

      # We test this after insertion or through the schema default
      record = Repo.insert!(changeset)
      assert record.priority == 0
    end
  end
end
