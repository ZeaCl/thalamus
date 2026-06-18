defmodule Thalamus.Infrastructure.Persistence.Schemas.ProjectSchemaTest do
  use Thalamus.DataCase, async: false
  alias Thalamus.Infrastructure.Persistence.Schemas.ProjectSchema

  describe "ProjectSchema" do
    test "changeset/2 with valid attributes" do
      attrs = %{name: "Zea Platform", description: "Core Zea cloud platform"}
      changeset = ProjectSchema.changeset(%ProjectSchema{}, attrs)
      assert changeset.valid?
    end

    test "changeset/2 requires a name" do
      attrs = %{description: "Core Zea cloud platform"}
      changeset = ProjectSchema.changeset(%ProjectSchema{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
    end

    test "changeset/2 enforces unique name" do
      attrs = %{name: "Zea Platform"}

      %ProjectSchema{}
      |> ProjectSchema.changeset(attrs)
      |> Repo.insert!()

      changeset = ProjectSchema.changeset(%ProjectSchema{}, attrs)
      {:error, changeset} = Repo.insert(changeset)

      refute changeset.valid?
      assert "has already been taken" in errors_on(changeset).name
    end
  end
end
