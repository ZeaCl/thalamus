defmodule ThalamusWeb.OAuth2.AgentTokenControllerTest do
  use ThalamusWeb.ConnCase, async: true

  import Thalamus.TestHelpers

  alias Thalamus.Domain.Entities.{User, Organization}

  alias Thalamus.Infrastructure.Repositories.{
    PostgreSQLUserRepository,
    PostgreSQLOrganizationRepository,
    PostgreSQLOAuth2ClientRepository,
    PostgreSQLTokenRepository
  }

  # Plain text secret for testing (matches the one in test_helpers.ex)
  @test_client_secret "test_secret_123"

  setup do
    # Create organization
    {:ok, org} = Organization.new("Test Corp", "owner@test.com", :professional)
    {:ok, org} = PostgreSQLOrganizationRepository.save(org)

    # Create and verify delegator user
    {:ok, delegator} = User.register("delegator@test.com", "Password123!")
    {:ok, delegator} = User.verify_email(delegator)
    {:ok, delegator} = PostgreSQLUserRepository.save(delegator)

    # Create OAuth2 client with agent-friendly scopes using helper
    {:ok, client} =
      create_test_client(
        "Test Agent Client",
        org.id,
        ["zea:read", "zea:write", "synapse:events"],
        grant_types: [:client_credentials],
        redirect_uris: ["http://localhost:3000/callback"]
      )

    {:ok, client} = PostgreSQLOAuth2ClientRepository.save(client)

    {:ok, %{delegator: delegator, client: client, org: org}}
  end

  describe "POST /oauth/agent-token - successful generation" do
    test "generates autonomous agent token with minimal params", %{
      conn: conn,
      delegator: delegator,
      client: client
    } do
      conn =
        post(conn, ~p"/oauth/agent-token", %{
          client_id: to_string(client.id),
          client_secret: @test_client_secret,
          delegated_by_user_id: to_string(delegator.id),
          agent_type: "autonomous",
          scope: "zea:read"
        })

      assert %{
               "access_token" => access_token,
               "token_type" => "Bearer",
               "expires_in" => expires_in,
               "scope" => "zea:read",
               "agent_type" => "autonomous"
             } = json_response(conn, 200)

      assert String.starts_with?(access_token, "at_")
      # Default 15 minutes
      assert expires_in == 900
    end

    test "generates supervised agent token with all optional params", %{
      conn: conn,
      delegator: delegator,
      client: client
    } do
      conn =
        post(conn, ~p"/oauth/agent-token", %{
          client_id: to_string(client.id),
          client_secret: @test_client_secret,
          delegated_by_user_id: to_string(delegator.id),
          agent_type: "supervised",
          scope: "zea:read zea:write",
          task_id: "task_abc123",
          task_type: "document_processing",
          max_operations: 100,
          expires_on_completion: true,
          intent_description: "Process user uploaded documents for compliance check",
          orchestrator_id: "orchestrator_xyz789",
          expires_in: 1800
        })

      assert %{
               "access_token" => access_token,
               "token_type" => "Bearer",
               "expires_in" => 1800,
               "scope" => scope,
               "agent_type" => "supervised",
               "task_id" => "task_abc123",
               "max_operations" => 100,
               "expires_on_completion" => true
             } = json_response(conn, 200)

      assert String.starts_with?(access_token, "at_")
      assert scope =~ "zea:read"
      assert scope =~ "zea:write"
    end

    test "generates ephemeral agent token with operations limit", %{
      conn: conn,
      delegator: delegator,
      client: client
    } do
      conn =
        post(conn, ~p"/oauth/agent-token", %{
          client_id: to_string(client.id),
          client_secret: @test_client_secret,
          delegated_by_user_id: to_string(delegator.id),
          agent_type: "ephemeral",
          scope: "zea:read",
          task_id: "ephemeral_task_001",
          max_operations: 10,
          expires_on_completion: true,
          expires_in: 300
        })

      assert %{
               "access_token" => access_token,
               "token_type" => "Bearer",
               "expires_in" => 300,
               "scope" => "zea:read",
               "agent_type" => "ephemeral",
               "task_id" => "ephemeral_task_001",
               "max_operations" => 10,
               "expires_on_completion" => true
             } = json_response(conn, 200)

      assert String.starts_with?(access_token, "at_")
    end

    test "enforces max TTL of 3600 seconds", %{conn: conn, delegator: delegator, client: client} do
      conn =
        post(conn, ~p"/oauth/agent-token", %{
          client_id: to_string(client.id),
          client_secret: @test_client_secret,
          delegated_by_user_id: to_string(delegator.id),
          agent_type: "autonomous",
          scope: "zea:read",
          # Request 2 hours, should be capped at 1 hour
          expires_in: 7200
        })

      assert %{
               "access_token" => _,
               # Capped at max
               "expires_in" => 3600
             } = json_response(conn, 200)
    end
  end

  describe "POST /oauth/agent-token - validation errors" do
    test "returns error with missing client_id", %{
      conn: conn,
      delegator: delegator,
      client: client
    } do
      conn =
        post(conn, ~p"/oauth/agent-token", %{
          client_secret: @test_client_secret,
          delegated_by_user_id: to_string(delegator.id),
          agent_type: "autonomous",
          scope: "zea:read"
        })

      assert %{
               "error" => "invalid_request",
               "error_description" => "client_id is required"
             } = json_response(conn, 400)
    end

    test "returns error with missing client_secret", %{
      conn: conn,
      delegator: delegator,
      client: client
    } do
      conn =
        post(conn, ~p"/oauth/agent-token", %{
          client_id: to_string(client.id),
          delegated_by_user_id: to_string(delegator.id),
          agent_type: "autonomous",
          scope: "zea:read"
        })

      assert %{
               "error" => "invalid_request",
               "error_description" => "client_secret is required"
             } = json_response(conn, 400)
    end

    test "returns error with missing delegated_by_user_id", %{conn: conn, client: client} do
      conn =
        post(conn, ~p"/oauth/agent-token", %{
          client_id: to_string(client.id),
          client_secret: @test_client_secret,
          agent_type: "autonomous",
          scope: "zea:read"
        })

      assert %{
               "error" => "invalid_request",
               "error_description" => "delegated_by_user_id is required"
             } = json_response(conn, 400)
    end

    test "returns error with missing agent_type", %{
      conn: conn,
      delegator: delegator,
      client: client
    } do
      conn =
        post(conn, ~p"/oauth/agent-token", %{
          client_id: to_string(client.id),
          client_secret: @test_client_secret,
          delegated_by_user_id: to_string(delegator.id),
          scope: "zea:read"
        })

      assert %{
               "error" => "invalid_request",
               "error_description" => "agent_type is required"
             } = json_response(conn, 400)
    end

    test "returns error with invalid agent_type", %{
      conn: conn,
      delegator: delegator,
      client: client
    } do
      conn =
        post(conn, ~p"/oauth/agent-token", %{
          client_id: to_string(client.id),
          client_secret: @test_client_secret,
          delegated_by_user_id: to_string(delegator.id),
          agent_type: "invalid_type",
          scope: "zea:read"
        })

      assert %{
               "error" => "invalid_request",
               "error_description" => "agent_type must be autonomous, supervised, or ephemeral"
             } = json_response(conn, 400)
    end

    test "returns error with empty scope", %{conn: conn, delegator: delegator, client: client} do
      conn =
        post(conn, ~p"/oauth/agent-token", %{
          client_id: to_string(client.id),
          client_secret: @test_client_secret,
          delegated_by_user_id: to_string(delegator.id),
          agent_type: "autonomous",
          scope: ""
        })

      assert %{
               "error" => "invalid_scope",
               "error_description" => "scope parameter is required"
             } = json_response(conn, 400)
    end

    test "returns error with missing scope parameter", %{
      conn: conn,
      delegator: delegator,
      client: client
    } do
      conn =
        post(conn, ~p"/oauth/agent-token", %{
          client_id: to_string(client.id),
          client_secret: @test_client_secret,
          delegated_by_user_id: to_string(delegator.id),
          agent_type: "autonomous"
        })

      assert %{
               "error" => "invalid_scope",
               "error_description" => "scope parameter is required"
             } = json_response(conn, 400)
    end
  end

  describe "POST /oauth/agent-token - authentication errors" do
    test "returns error with invalid client_id", %{
      conn: conn,
      delegator: delegator,
      client: client
    } do
      conn =
        post(conn, ~p"/oauth/agent-token", %{
          client_id: "00000000-0000-0000-0000-000000000000",
          client_secret: @test_client_secret,
          delegated_by_user_id: to_string(delegator.id),
          agent_type: "autonomous",
          scope: "zea:read"
        })

      assert %{
               "error" => "invalid_client",
               "error_description" => "client authentication failed"
             } = json_response(conn, 401)
    end

    test "returns error with invalid client_secret", %{
      conn: conn,
      delegator: delegator,
      client: client
    } do
      conn =
        post(conn, ~p"/oauth/agent-token", %{
          client_id: to_string(client.id),
          client_secret: "wrong_secret",
          delegated_by_user_id: to_string(delegator.id),
          agent_type: "autonomous",
          scope: "zea:read"
        })

      assert %{
               "error" => "invalid_client",
               "error_description" => "client authentication failed"
             } = json_response(conn, 401)
    end

    test "returns error with non-existent delegator", %{conn: conn, client: client} do
      conn =
        post(conn, ~p"/oauth/agent-token", %{
          client_id: to_string(client.id),
          client_secret: @test_client_secret,
          delegated_by_user_id: "00000000-0000-0000-0000-000000000000",
          agent_type: "autonomous",
          scope: "zea:read"
        })

      assert %{
               "error" => "invalid_request",
               "error_description" => "delegated_by_user_id not found"
             } = json_response(conn, 400)
    end

    test "returns error with inactive delegator", %{conn: conn, client: client, org: org} do
      # Create inactive user
      {:ok, inactive_user} = User.register("inactive@test.com", "Password123!")
      {:ok, inactive_user} = User.verify_email(inactive_user)
      {:ok, inactive_user} = User.deactivate(inactive_user)
      {:ok, inactive_user} = PostgreSQLUserRepository.save(inactive_user)

      conn =
        post(conn, ~p"/oauth/agent-token", %{
          client_id: to_string(client.id),
          client_secret: @test_client_secret,
          delegated_by_user_id: to_string(inactive_user.id),
          agent_type: "autonomous",
          scope: "zea:read"
        })

      assert %{
               "error" => "invalid_request",
               "error_description" => "delegating user is inactive"
             } = json_response(conn, 400)
    end
  end

  describe "POST /oauth/agent-token - scope validation" do
    test "returns error with scope not in client allowed_scopes", %{
      conn: conn,
      delegator: delegator,
      client: client
    } do
      conn =
        post(conn, ~p"/oauth/agent-token", %{
          client_id: to_string(client.id),
          client_secret: @test_client_secret,
          delegated_by_user_id: to_string(delegator.id),
          agent_type: "autonomous",
          # Not in client's allowed scopes
          scope: "admin:delete"
        })

      assert %{
               "error" => "invalid_scope",
               "error_description" => description
             } = json_response(conn, 400)

      assert description =~ "invalid scopes"
      assert description =~ "admin:delete"
    end

    test "returns error with partially invalid scopes", %{
      conn: conn,
      delegator: delegator,
      client: client
    } do
      conn =
        post(conn, ~p"/oauth/agent-token", %{
          client_id: to_string(client.id),
          client_secret: @test_client_secret,
          delegated_by_user_id: to_string(delegator.id),
          agent_type: "autonomous",
          # Only zea:read is allowed
          scope: "zea:read admin:write billing:admin"
        })

      assert %{
               "error" => "invalid_scope",
               "error_description" => description
             } = json_response(conn, 400)

      assert description =~ "invalid scopes"
      assert description =~ "admin:write"
      assert description =~ "billing:admin"
    end

    test "accepts valid subset of client allowed_scopes", %{
      conn: conn,
      delegator: delegator,
      client: client
    } do
      conn =
        post(conn, ~p"/oauth/agent-token", %{
          client_id: to_string(client.id),
          client_secret: @test_client_secret,
          delegated_by_user_id: to_string(delegator.id),
          agent_type: "autonomous",
          # Both are in allowed scopes
          scope: "zea:read zea:write"
        })

      assert %{
               "access_token" => _,
               "scope" => scope
             } = json_response(conn, 200)

      assert scope =~ "zea:read"
      assert scope =~ "zea:write"
    end
  end

  describe "POST /oauth/agent-token - TTL validation" do
    test "accepts valid TTL within range", %{conn: conn, delegator: delegator, client: client} do
      conn =
        post(conn, ~p"/oauth/agent-token", %{
          client_id: to_string(client.id),
          client_secret: @test_client_secret,
          delegated_by_user_id: to_string(delegator.id),
          agent_type: "autonomous",
          scope: "zea:read",
          # 30 minutes
          expires_in: 1800
        })

      assert %{
               "access_token" => _,
               "expires_in" => 1800
             } = json_response(conn, 200)
    end

    test "applies default TTL when not specified", %{
      conn: conn,
      delegator: delegator,
      client: client
    } do
      conn =
        post(conn, ~p"/oauth/agent-token", %{
          client_id: to_string(client.id),
          client_secret: @test_client_secret,
          delegated_by_user_id: to_string(delegator.id),
          agent_type: "autonomous",
          scope: "zea:read"
        })

      assert %{
               # 15 minutes default
               "expires_in" => 900
             } = json_response(conn, 200)
    end
  end

  describe "POST /oauth/agent-token - token storage and introspection" do
    test "stores agent token with full metadata in database", %{
      conn: conn,
      delegator: delegator,
      client: client
    } do
      conn =
        post(conn, ~p"/oauth/agent-token", %{
          client_id: to_string(client.id),
          client_secret: @test_client_secret,
          delegated_by_user_id: to_string(delegator.id),
          agent_type: "autonomous",
          scope: "zea:read",
          task_id: "test_task_123",
          task_type: "data_extraction",
          max_operations: 50,
          expires_on_completion: true,
          intent_description: "Extract data from uploaded CSV files",
          orchestrator_id: "orch_test_001"
        })

      %{"access_token" => access_token} = json_response(conn, 200)

      # Verify token was stored correctly
      {:ok, token_data} = PostgreSQLTokenRepository.find(access_token)

      assert token_data.agent_type == "autonomous"
      assert token_data.delegated_by_user_id == delegator.id
      assert token_data.delegation_chain == [delegator.id]
      assert token_data.task_id == "test_task_123"
      assert token_data.task_type == "data_extraction"
      assert token_data.task_scopes == ["zea:read"]
      assert token_data.max_operations == 50
      assert token_data.operations_count == 0
      assert token_data.expires_on_completion == true
      assert token_data.intent_description == "Extract data from uploaded CSV files"
      assert token_data.orchestrator_id == "orch_test_001"
    end

    test "generated token can be introspected via /oauth/introspect", %{
      conn: conn,
      delegator: delegator,
      client: client
    } do
      # Generate agent token
      conn1 =
        post(conn, ~p"/oauth/agent-token", %{
          client_id: to_string(client.id),
          client_secret: @test_client_secret,
          delegated_by_user_id: to_string(delegator.id),
          agent_type: "supervised",
          scope: "zea:write",
          task_id: "introspection_test",
          max_operations: 25
        })

      %{"access_token" => access_token} = json_response(conn1, 200)

      # Introspect the token
      conn2 =
        post(conn, ~p"/oauth/introspect", %{
          token: access_token,
          client_id: to_string(client.id),
          client_secret: @test_client_secret
        })

      assert %{
               "active" => true,
               "scope" => "zea:write",
               "client_id" => _,
               "agent_type" => "supervised",
               "delegated_by" => _,
               "delegation_chain" => [_],
               "delegation_depth" => 1,
               "task_id" => "introspection_test",
               "max_operations" => 25,
               "operations_remaining" => 25
             } = json_response(conn2, 200)
    end
  end
end
