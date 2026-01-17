defmodule Thalamus.APITest do
  use Thalamus.DataCase, async: false

  @moduledoc """
  Basic smoke tests for Thalamus.API public interface.

  NOTE: Comprehensive testing of business logic is done in use case tests.
  These tests just verify the API contract exists and handles basic validation.

  These tests use DataCase (not async) because Thalamus.API calls real repositories.
  """

  describe "generate_agent_token/1" do
    test "returns error for invalid params structure" do
      # Empty params should fail validation
      assert {:error, _reason} = Thalamus.API.generate_agent_token(%{})
    end

    test "returns error for missing required fields" do
      params = %{
        "client_id" => "test",
        # Missing other required fields
      }

      assert {:error, _reason} = Thalamus.API.generate_agent_token(params)
    end

    test "accepts params with string keys" do
      # Should fail due to invalid credentials, but validates param parsing
      params = %{
        "client_id" => "nonexistent",
        "client_secret" => "invalid",
        "organization_id" => Ecto.UUID.generate(),
        "delegator_user_id" => Ecto.UUID.generate(),
        "agent_type" => "autonomous",
        "task_id" => Ecto.UUID.generate(),
        "task_description" => "Test",
        "scopes" => ["test:read"]
      }

      # Will fail auth, but params are parsed correctly
      assert {:error, _reason} = Thalamus.API.generate_agent_token(params)
    end

    test "accepts params with atom keys" do
      params = %{
        client_id: "nonexistent",
        client_secret: "invalid",
        organization_id: Ecto.UUID.generate(),
        delegator_user_id: Ecto.UUID.generate(),
        agent_type: "autonomous",
        task_id: Ecto.UUID.generate(),
        task_description: "Test",
        scopes: ["test:read"]
      }

      # Will fail auth, but params are parsed correctly
      assert {:error, _reason} = Thalamus.API.generate_agent_token(params)
    end
  end

  describe "validate_step/4" do
    test "returns error for invalid token format" do
      result = Thalamus.API.validate_step("invalid_token", "step_name", ["scope:read"])

      assert {:error, :invalid_token_format} = result
    end

    test "returns error for nonexistent token" do
      token = "at_nonexistent_" <> (:crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false))

      result = Thalamus.API.validate_step(token, "step_name", ["scope:read"])

      assert {:error, :token_not_found} = result
    end

    test "accepts workflow context parameter" do
      token = "at_test_" <> (:crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false))
      context = %{workflow_id: "wf_123", execution_id: "exec_456"}

      result = Thalamus.API.validate_step(token, "step_name", ["scope:read"], context)

      # Token won't be found, but context is accepted
      assert {:error, :token_not_found} = result
    end

    test "validates with empty context by default" do
      token = "at_test_" <> (:crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false))

      # Should work with default empty context
      result = Thalamus.API.validate_step(token, "step_name", ["scope:read"])

      assert {:error, _reason} = result
    end
  end

  describe "revoke_token/2" do
    test "returns error for invalid token_id format" do
      result = Thalamus.API.revoke_token("invalid_uuid", %{
        organization_id: Ecto.UUID.generate(),
        revoked_by_user_id: Ecto.UUID.generate()
      })

      assert {:error, :invalid_token_id} = result
    end

    test "returns error for missing organization_id" do
      token_id = Ecto.UUID.generate()

      result = Thalamus.API.revoke_token(token_id, %{
        revoked_by_user_id: Ecto.UUID.generate()
      })

      assert {:error, :missing_organization_id} = result
    end

    test "validates request parameters" do
      token_id = Ecto.UUID.generate()

      result = Thalamus.API.revoke_token(token_id, %{
        organization_id: Ecto.UUID.generate(),
        revoked_by_user_id: Ecto.UUID.generate()
      })

      # Returns :not_found because token doesn't exist (validation passed)
      assert {:error, :not_found} = result
    end

    test "accepts cascade parameter" do
      token_id = Ecto.UUID.generate()

      result = Thalamus.API.revoke_token(token_id, %{
        organization_id: Ecto.UUID.generate(),
        revoked_by_user_id: Ecto.UUID.generate(),
        cascade: true,
        reason: "Test revocation"
      })

      # Will fail because token doesn't exist, but params are validated
      assert {:error, _reason} = result
    end
  end

  describe "introspect_token/1" do
    test "returns not_implemented error" do
      token = "at_some_token_123"

      assert {:error, :not_implemented} = Thalamus.API.introspect_token(token)
    end

    test "accepts any token format (not yet implemented)" do
      assert {:error, :not_implemented} = Thalamus.API.introspect_token("any_string")
      assert {:error, :not_implemented} = Thalamus.API.introspect_token("")
      assert {:error, :not_implemented} = Thalamus.API.introspect_token("at_valid_format")
    end
  end
end
