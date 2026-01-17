defmodule Thalamus.Infrastructure.Persistence.Schemas.AgentTokenSchemaTest do
  use Thalamus.DataCase, async: true

  alias Thalamus.Infrastructure.Persistence.Schemas.AgentTokenSchema

  describe "changeset/2 with valid data" do
    test "creates valid changeset with all required fields" do
      attrs = valid_attrs()
      changeset = AgentTokenSchema.changeset(%AgentTokenSchema{}, attrs)

      assert changeset.valid?
      assert changeset.changes.client_id == attrs.client_id
      assert changeset.changes.organization_id == attrs.organization_id
      assert changeset.changes.access_token == attrs.access_token
      assert changeset.changes.agent_type == attrs.agent_type
      assert changeset.changes.task_id == attrs.task_id
      assert changeset.changes.task_description == attrs.task_description
      assert changeset.changes.scopes == attrs.scopes
      assert changeset.changes.delegation_chain == attrs.delegation_chain
      # delegation_depth defaults to 0, so it may not be in changes if value is 0
      assert Ecto.Changeset.get_field(changeset, :delegation_depth) == attrs.delegation_depth
      assert changeset.changes.delegator_user_id == attrs.delegator_user_id
      assert changeset.changes.expires_in == attrs.expires_in
      # Truncate microseconds for comparison
      assert DateTime.truncate(changeset.changes.expires_at, :second) ==
               DateTime.truncate(attrs.expires_at, :second)
    end

    test "creates valid changeset with optional reason field" do
      attrs = Map.put(valid_attrs(), :reason, "Automated workflow")
      changeset = AgentTokenSchema.changeset(%AgentTokenSchema{}, attrs)

      assert changeset.valid?
      assert changeset.changes.reason == "Automated workflow"
    end

    test "creates valid changeset with parent_agent_id" do
      parent_id = Ecto.UUID.generate()
      attrs = Map.put(valid_attrs(), :parent_agent_id, parent_id)
      changeset = AgentTokenSchema.changeset(%AgentTokenSchema{}, attrs)

      assert changeset.valid?
      assert changeset.changes.parent_agent_id == parent_id
    end

    test "accepts autonomous agent_type" do
      attrs = Map.put(valid_attrs(), :agent_type, "autonomous")
      changeset = AgentTokenSchema.changeset(%AgentTokenSchema{}, attrs)

      assert changeset.valid?
    end

    test "accepts supervisor agent_type" do
      attrs = Map.put(valid_attrs(), :agent_type, "supervisor")
      changeset = AgentTokenSchema.changeset(%AgentTokenSchema{}, attrs)

      assert changeset.valid?
    end

    test "accepts tool agent_type" do
      attrs = Map.put(valid_attrs(), :agent_type, "tool")
      changeset = AgentTokenSchema.changeset(%AgentTokenSchema{}, attrs)

      assert changeset.valid?
    end

    test "accepts delegation_depth 0" do
      attrs = Map.put(valid_attrs(), :delegation_depth, 0)
      changeset = AgentTokenSchema.changeset(%AgentTokenSchema{}, attrs)

      assert changeset.valid?
    end

    test "accepts delegation_depth 4 (maximum)" do
      attrs = Map.put(valid_attrs(), :delegation_depth, 4)
      changeset = AgentTokenSchema.changeset(%AgentTokenSchema{}, attrs)

      assert changeset.valid?
    end

    test "accepts empty scopes array" do
      attrs = Map.put(valid_attrs(), :scopes, [])
      changeset = AgentTokenSchema.changeset(%AgentTokenSchema{}, attrs)

      assert changeset.valid?
    end

    test "accepts scopes with multiple values" do
      attrs = Map.put(valid_attrs(), :scopes, ["read:data", "write:results", "admin"])
      changeset = AgentTokenSchema.changeset(%AgentTokenSchema{}, attrs)

      assert changeset.valid?
      assert length(changeset.changes.scopes) == 3
    end
  end

  describe "changeset/2 with invalid data" do
    test "fails when missing required fields" do
      changeset = AgentTokenSchema.changeset(%AgentTokenSchema{}, %{})

      refute changeset.valid?

      # Note: scopes, delegation_chain, and delegation_depth have default values
      # so they won't appear in validation errors
      assert %{
               client_id: ["can't be blank"],
               organization_id: ["can't be blank"],
               access_token: ["can't be blank"],
               agent_type: ["can't be blank"],
               task_id: ["can't be blank"],
               task_description: ["can't be blank"],
               delegator_user_id: ["can't be blank"],
               expires_in: ["can't be blank"],
               expires_at: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "fails with invalid agent_type" do
      attrs = Map.put(valid_attrs(), :agent_type, "invalid_type")
      changeset = AgentTokenSchema.changeset(%AgentTokenSchema{}, attrs)

      refute changeset.valid?
      assert %{agent_type: ["is invalid"]} = errors_on(changeset)
    end

    test "fails with delegation_depth < 0" do
      attrs = Map.put(valid_attrs(), :delegation_depth, -1)
      changeset = AgentTokenSchema.changeset(%AgentTokenSchema{}, attrs)

      refute changeset.valid?
      assert %{delegation_depth: ["must be greater than or equal to 0"]} = errors_on(changeset)
    end

    test "fails with delegation_depth >= 5" do
      attrs = Map.put(valid_attrs(), :delegation_depth, 5)
      changeset = AgentTokenSchema.changeset(%AgentTokenSchema{}, attrs)

      refute changeset.valid?
      assert %{delegation_depth: ["must be less than 5"]} = errors_on(changeset)
    end

    test "fails with access_token too short" do
      attrs = Map.put(valid_attrs(), :access_token, "short")
      changeset = AgentTokenSchema.changeset(%AgentTokenSchema{}, attrs)

      refute changeset.valid?
      assert %{access_token: ["should be at least 10 character(s)"]} = errors_on(changeset)
    end

    test "fails with access_token too long" do
      attrs = Map.put(valid_attrs(), :access_token, String.duplicate("a", 256))
      changeset = AgentTokenSchema.changeset(%AgentTokenSchema{}, attrs)

      refute changeset.valid?
      assert %{access_token: ["should be at most 255 character(s)"]} = errors_on(changeset)
    end

    test "fails with empty task_description" do
      attrs = Map.put(valid_attrs(), :task_description, "")
      changeset = AgentTokenSchema.changeset(%AgentTokenSchema{}, attrs)

      refute changeset.valid?
      # Empty strings fail the length validation with "can't be blank" message
      assert %{task_description: ["can't be blank"]} = errors_on(changeset)
    end

    test "fails with expires_in <= 0" do
      attrs = Map.put(valid_attrs(), :expires_in, 0)
      changeset = AgentTokenSchema.changeset(%AgentTokenSchema{}, attrs)

      refute changeset.valid?
      assert %{expires_in: ["must be greater than 0"]} = errors_on(changeset)
    end

    test "fails with negative expires_in" do
      attrs = Map.put(valid_attrs(), :expires_in, -100)
      changeset = AgentTokenSchema.changeset(%AgentTokenSchema{}, attrs)

      refute changeset.valid?
      assert %{expires_in: ["must be greater than 0"]} = errors_on(changeset)
    end
  end

  describe "update_changeset/2" do
    test "creates valid update changeset for revocation" do
      schema = %AgentTokenSchema{}
      revoked_at = DateTime.utc_now() |> DateTime.truncate(:second)

      attrs = %{
        revoked_at: revoked_at,
        revoke_reason: "Task completed"
      }

      changeset = AgentTokenSchema.update_changeset(schema, attrs)

      assert changeset.valid?
      assert DateTime.truncate(changeset.changes.revoked_at, :second) == revoked_at
      assert changeset.changes.revoke_reason == "Task completed"
    end

    test "creates valid update changeset without revoke_reason" do
      schema = %AgentTokenSchema{}
      revoked_at = DateTime.utc_now() |> DateTime.truncate(:second)

      attrs = %{revoked_at: revoked_at}
      changeset = AgentTokenSchema.update_changeset(schema, attrs)

      assert changeset.valid?
      assert DateTime.truncate(changeset.changes.revoked_at, :second) == revoked_at
      refute Map.has_key?(changeset.changes, :revoke_reason)
    end

    test "fails when revoked_at is missing" do
      schema = %AgentTokenSchema{}
      attrs = %{revoke_reason: "Manual revocation"}
      changeset = AgentTokenSchema.update_changeset(schema, attrs)

      refute changeset.valid?
      assert %{revoked_at: ["can't be blank"]} = errors_on(changeset)
    end

    test "does not allow updating other fields" do
      schema = %AgentTokenSchema{access_token: "original_token"}

      attrs = %{
        revoked_at: DateTime.utc_now(),
        access_token: "new_token",
        agent_type: "tool"
      }

      changeset = AgentTokenSchema.update_changeset(schema, attrs)

      # Only revocation fields should be in changes
      assert Map.has_key?(changeset.changes, :revoked_at)
      refute Map.has_key?(changeset.changes, :access_token)
      refute Map.has_key?(changeset.changes, :agent_type)
    end
  end

  describe "associations" do
    test "belongs_to :client" do
      assert AgentTokenSchema.__schema__(:association, :client)
    end

    test "belongs_to :organization" do
      assert AgentTokenSchema.__schema__(:association, :organization)
    end

    test "belongs_to :parent_agent" do
      assert AgentTokenSchema.__schema__(:association, :parent_agent)
    end

    test "has_many :child_agents" do
      assert AgentTokenSchema.__schema__(:association, :child_agents)
    end
  end

  # Helper function to generate valid attributes
  defp valid_attrs do
    %{
      client_id: Ecto.UUID.generate(),
      organization_id: Ecto.UUID.generate(),
      access_token:
        "test_token_" <> (:crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)),
      agent_type: "autonomous",
      task_id: Ecto.UUID.generate(),
      task_description: "Test task description",
      scopes: ["read:data", "write:results"],
      delegation_chain: %{"parent_token_id" => nil, "depth" => 0, "path" => []},
      delegation_depth: 0,
      delegator_user_id: Ecto.UUID.generate(),
      expires_in: 3600,
      expires_at: DateTime.utc_now() |> DateTime.add(3600, :second)
    }
  end
end
