defmodule ThalamusWeb.API.AuthorizationControllerTest do
  use ThalamusWeb.ConnCase, async: false

  @moduledoc """
  Basic smoke tests for AuthorizationController HTTP endpoint.

  NOTE: This endpoint is in the authenticated_api pipeline, which runs
  AuthenticateToken plug before reaching the controller. Most validation
  happens in the plug, not the controller.

  Comprehensive business logic testing is in ValidateStepAuthorization use case tests.
  """

  describe "POST /api/authorization/validate-step" do
    test "returns 401 when authorization header is missing", %{conn: conn} do
      conn =
        conn
        |> post("/api/authorization/validate-step", %{
          "step_name" => "send_email",
          "required_scopes" => ["email:send"]
        })

      response = json_response(conn, 401)
      # AuthenticateToken plug returns this error
      assert response["error"] == "unauthorized"
    end

    test "returns 401 when token format is invalid", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "InvalidFormat token123")
        |> post("/api/authorization/validate-step", %{
          "step_name" => "send_email",
          "required_scopes" => ["email:send"]
        })

      response = json_response(conn, 401)
      # AuthenticateToken plug validates format
      assert response["error"] == "unauthorized"
    end

    test "route exists and accepts POST requests", %{conn: conn} do
      # Verify the route is configured
      conn =
        conn
        |> post("/api/authorization/validate-step", %{})

      # Should get 401 (not 404), confirming route exists
      assert conn.status == 401
    end
  end
end
