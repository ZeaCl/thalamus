defmodule ThalamusWeb.Plugs.AuthenticateTokenTest do
  use ThalamusWeb.ConnCase, async: false

  alias ThalamusWeb.Plugs.AuthenticateToken
  alias Thalamus.Infrastructure.JwtSigner

  @jwt_signer_module JwtSigner

  # ── Token extraction ──────────────────────────────────────────

  describe "token extraction" do
    test "returns unauthorized when Authorization header is missing" do
      conn =
        build_conn()
        |> AuthenticateToken.call(%{})

      assert conn.status == 401
      assert conn.halted
      assert %{"error" => "unauthorized"} = json_response(conn, 401)
      assert json_response(conn, 401)["error_description"] =~ "Missing"
    end

    test "returns unauthorized when Authorization header is empty" do
      conn =
        build_conn()
        |> put_req_header("authorization", "")
        |> AuthenticateToken.call(%{})

      assert conn.status == 401
      assert conn.halted
    end

    test "returns unauthorized for non-Bearer authorization" do
      conn =
        build_conn()
        |> put_req_header("authorization", "Basic dXNlcjpwYXNz")
        |> AuthenticateToken.call(%{})

      assert conn.status == 401
      assert conn.halted
    end

    test "returns unauthorized for malformed Bearer header" do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer")
        |> AuthenticateToken.call(%{})

      assert conn.status == 401
      assert conn.halted
    end
  end

  # ── JWT format detection (pure functions) ─────────────────────

  describe "jwt_format?/1" do
    test "returns true for standard 3-segment JWT" do
      # Manually crafted segments that match the JWT regex
      token = "eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiIxMjMifQ.sig"
      assert AuthenticateToken.jwt_format?(token)
    end

    test "returns false for opaque hex tokens" do
      refute AuthenticateToken.jwt_format?("abc123def456")
    end

    test "returns false for tokens with fewer than 3 segments" do
      refute AuthenticateToken.jwt_format?("eyJhbGci.eyJzdWIi")
    end

    test "returns false for tokens with more than 3 segments" do
      refute AuthenticateToken.jwt_format?("a.b.c.d")
    end

    test "returns false for empty string" do
      refute AuthenticateToken.jwt_format?("")
    end
  end

  describe "thalamus_api_jwt?/1" do
    test "returns true when payload contains client_id: thalamus_api" do
      header = Base.url_encode64("{\"alg\":\"RS256\"}", padding: false)
      payload = Base.url_encode64("{\"client_id\":\"thalamus_api\"}", padding: false)
      sig = "fake_signature"
      token = "#{header}.#{payload}.#{sig}"

      assert AuthenticateToken.thalamus_api_jwt?(token)
    end

    test "returns false when payload has different client_id" do
      header = Base.url_encode64("{\"alg\":\"RS256\"}", padding: false)
      payload = Base.url_encode64("{\"client_id\":\"other_client\"}", padding: false)
      sig = "fake_signature"
      token = "#{header}.#{payload}.#{sig}"

      refute AuthenticateToken.thalamus_api_jwt?(token)
    end

    test "returns false for malformed base64 in payload" do
      token = "header.not-base64$$.sig"
      refute AuthenticateToken.thalamus_api_jwt?(token)
    end

    test "returns false when token has fewer than 2 segments" do
      refute AuthenticateToken.thalamus_api_jwt?("just_one_segment")
    end
  end

  # ── JWT claim validation ─────────────────────────────────────

  @issuer "https://auth.zea.cl"

  describe "validate_jwt_claims/1" do
    test "returns :ok for a valid token" do
      future = DateTime.utc_now() |> DateTime.to_unix() |> Kernel.+(3600)

      claims = %{
        "exp" => future,
        "iss" => @issuer,
        "aud" => "zea"
      }

      assert :ok = AuthenticateToken.validate_jwt_claims(claims)
    end

    test "returns {:error, message} for expired token" do
      past = DateTime.utc_now() |> DateTime.to_unix() |> Kernel.-(3600)

      claims = %{
        "exp" => past,
        "iss" => @issuer,
        "aud" => "zea"
      }

      assert {:error, _} = AuthenticateToken.validate_jwt_claims(claims)
    end

    test "returns {:error, _} when exp claim is missing" do
      claims = %{"iss" => @issuer, "aud" => "zea"}
      assert {:error, _} = AuthenticateToken.validate_jwt_claims(claims)
    end

    test "returns {:error, _} when exp is not an integer" do
      claims = %{"exp" => "not_an_int", "iss" => @issuer, "aud" => "zea"}
      assert {:error, _} = AuthenticateToken.validate_jwt_claims(claims)
    end

    test "returns {:error, _} when issuer does not match" do
      future = DateTime.utc_now() |> DateTime.to_unix() |> Kernel.+(3600)
      claims = %{"exp" => future, "iss" => "https://evil.example.com", "aud" => "zea"}
      assert {:error, _} = AuthenticateToken.validate_jwt_claims(claims)
    end

    test "returns {:error, _} when audience is missing" do
      future = DateTime.utc_now() |> DateTime.to_unix() |> Kernel.+(3600)
      claims = %{"exp" => future, "iss" => @issuer}
      assert {:error, _} = AuthenticateToken.validate_jwt_claims(claims)
    end
  end

  # ── Full plug flow: opaque tokens via DB ──────────────────────

  describe "authenticated request with valid DB token" do
    setup do
      {conn, _user, _org, token} = authenticate_api(build_conn())
      %{conn: conn, token: token}
    end

    test "bypasses plug when conn already has current_user (pre-authenticated)", %{
      conn: conn
    } do
      # The authenticate_api helper pre-loads current_user and organization_id.
      # When the plug runs on this conn, it should still process the token but
      # the assigns should reflect the already-set user.
      new_conn = AuthenticateToken.call(conn, %{})
      refute new_conn.halted
      assert new_conn.assigns[:current_user_id]
      assert new_conn.assigns[:current_client_id]
      assert new_conn.assigns[:token_scope]
    end
  end

  # ── Full plug flow: JWT fallback ─────────────────────────────

  describe "JWT fallback with real signed token" do
    test "authenticates with a valid thalamus_api JWT when token is not in DB" do
      # Generate a real JWT using JwtSigner
      jwt =
        @jwt_signer_module.sign_access_token(%{
          user_id: "user_test123",
          client_id: "thalamus_api",
          scope: "openid profile",
          expires_in: 3600
        })

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{jwt}")
        |> AuthenticateToken.call(%{})

      refute conn.halted
      assert conn.assigns[:current_user_id] == "user_test123"
      assert conn.assigns[:current_client_id] == "thalamus_api"
      assert "openid" in conn.assigns[:token_scope]
      assert "profile" in conn.assigns[:token_scope]
      assert conn.assigns[:auth_context][:jwt] == true
    end

    test "rejects JWT that is not from thalamus_api client" do
      jwt =
        @jwt_signer_module.sign_access_token(%{
          user_id: "user_test456",
          client_id: "other_client",
          scope: "openid",
          expires_in: 3600
        })

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{jwt}")
        |> AuthenticateToken.call(%{})

      assert conn.status == 401
      assert conn.halted
    end

    test "rejects opaque token that is not in DB and not a JWT" do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer some_random_opaque_token_123")
        |> AuthenticateToken.call(%{})

      assert conn.status == 401
      assert conn.halted
    end
  end

  # ── JWT fallback: expired token ──────────────────────────────

  describe "JWT fallback with expired token" do
    test "rejects an expired thalamus_api JWT" do
      # Generate a JWT that expired 1 hour ago
      jwt =
        @jwt_signer_module.sign_access_token(%{
          user_id: "user_test789",
          client_id: "thalamus_api",
          scope: "openid",
          expires_in: -1
        })

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{jwt}")
        |> AuthenticateToken.call(%{})

      assert conn.status == 401
      assert conn.halted
    end
  end
end
