defmodule ThalamusWeb.API.MFAControllerTest do
  use ThalamusWeb.ConnCase, async: true

  alias Thalamus.Domain.Entities.User
  alias Thalamus.Domain.ValueObjects.AccessToken
  alias Thalamus.Infrastructure.Repositories.{
    PostgreSQLUserRepository,
    PostgreSQLTokenRepository
  }
  alias Thalamus.Infrastructure.Adapters.RedisCacheAdapter

  setup do
    # Create and verify user
    {:ok, user} = User.register("user@test.com", "Password123!")
    {:ok, user} = User.verify_email(user)
    {:ok, user} = PostgreSQLUserRepository.save(user)

    # Generate access token for authenticated requests
    {:ok, access_token} = AccessToken.generate(
      user.id,
      Thalamus.Domain.ValueObjects.ClientId.generate!(),
      [:read, :write],
      3600
    )

    token_data = %{
      token: access_token.token,
      type: :access_token,
      user_id: user.id,
      scope: [:read, :write],
      expires_at: access_token.expires_at
    }
    :ok = PostgreSQLTokenRepository.store(token_data)

    {:ok, %{user: user, access_token: access_token.token}}
  end

  describe "POST /api/mfa/totp/setup" do
    test "returns TOTP secret and QR code for new setup", %{conn: conn, access_token: token} do
      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> post(~p"/api/mfa/totp/setup")

      assert %{
        "data" => %{
          "secret" => secret,
          "qr_code_uri" => qr_uri,
          "backup_codes" => backup_codes,
          "instructions" => _
        }
      } = json_response(conn, 200)

      # Validate secret format (Base32)
      assert String.length(secret) == 32
      assert String.match?(secret, ~r/^[A-Z2-7]+$/)

      # Validate QR code URI format
      assert String.starts_with?(qr_uri, "otpauth://totp/")
      assert String.contains?(qr_uri, "secret=#{secret}")
      assert String.contains?(qr_uri, "user@test.com")

      # Validate backup codes
      assert length(backup_codes) == 10
      Enum.each(backup_codes, fn code ->
        assert String.length(code) == 8
        assert String.match?(code, ~r/^[a-f0-9]+$/)
      end)
    end

    test "returns error if MFA already enabled", %{conn: conn, user: user, access_token: token} do
      # Enable MFA first
      {:ok, mfa_method} = Thalamus.Domain.ValueObjects.MFAMethod.new(:totp, "TESTSECRET123456")
      updated_user = %{user | mfa_enabled: true, mfa_methods: [mfa_method]}
      {:ok, _} = PostgreSQLUserRepository.save(updated_user)

      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> post(~p"/api/mfa/totp/setup")

      assert %{
        "error" => "MFA is already enabled for this account"
      } = json_response(conn, 400)
    end

    test "requires authentication", %{conn: conn} do
      conn = post(conn, ~p"/api/mfa/totp/setup")

      assert json_response(conn, 401)
    end
  end

  describe "POST /api/mfa/totp/verify" do
    test "enables MFA with valid TOTP code", %{conn: conn, user: user, access_token: token} do
      # Setup TOTP first
      setup_conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> post(~p"/api/mfa/totp/setup")

      %{"data" => %{"secret" => secret}} = json_response(setup_conn, 200)

      # Generate valid TOTP code
      code = generate_totp_code(secret)

      # Verify code
      verify_conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> post(~p"/api/mfa/totp/verify", %{code: code})

      assert %{
        "data" => %{
          "mfa_enabled" => true,
          "method" => "totp",
          "backup_codes" => backup_codes,
          "message" => _
        }
      } = json_response(verify_conn, 200)

      assert length(backup_codes) == 10

      # Verify user has MFA enabled
      {:ok, updated_user} = PostgreSQLUserRepository.find_by_id(user.id)
      assert updated_user.mfa_enabled == true
    end

    test "returns error with invalid code", %{conn: conn, access_token: token} do
      # Setup TOTP first
      setup_conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> post(~p"/api/mfa/totp/setup")

      json_response(setup_conn, 200)

      # Try with invalid code
      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> post(~p"/api/mfa/totp/verify", %{code: "000000"})

      assert %{
        "error" => "Invalid verification code"
      } = json_response(conn, 400)
    end

    test "returns error without pending setup", %{conn: conn, access_token: token} do
      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> post(~p"/api/mfa/totp/verify", %{code: "123456"})

      assert %{
        "error" => "No pending MFA setup found. Please initiate setup first."
      } = json_response(conn, 400)
    end

    test "returns error with missing code", %{conn: conn, access_token: token} do
      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> post(~p"/api/mfa/totp/verify", %{})

      assert %{
        "error" => "Missing required field: code"
      } = json_response(conn, 400)
    end
  end

  describe "DELETE /api/mfa/disable" do
    test "disables MFA with valid password and code", %{conn: conn, user: user, access_token: token} do
      # Setup and enable MFA first
      setup_conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> post(~p"/api/mfa/totp/setup")

      %{"data" => %{"secret" => secret}} = json_response(setup_conn, 200)
      code = generate_totp_code(secret)

      verify_conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> post(~p"/api/mfa/totp/verify", %{code: code})

      json_response(verify_conn, 200)

      # Now disable MFA
      new_code = generate_totp_code(secret)

      disable_conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> delete(~p"/api/mfa/disable", %{
        password: "Password123!",
        code: new_code
      })

      assert %{
        "data" => %{
          "mfa_enabled" => false,
          "message" => _
        }
      } = json_response(disable_conn, 200)

      # Verify MFA is disabled
      {:ok, updated_user} = PostgreSQLUserRepository.find_by_id(user.id)
      assert updated_user.mfa_enabled == false
    end

    test "returns error with invalid password", %{conn: conn, user: user, access_token: token} do
      # Enable MFA
      {:ok, mfa_method} = Thalamus.Domain.ValueObjects.MFAMethod.new(:totp, "TESTSECRET123456")
      updated_user = %{user | mfa_enabled: true, mfa_methods: [mfa_method]}
      {:ok, _} = PostgreSQLUserRepository.save(updated_user)

      code = generate_totp_code("TESTSECRET123456")

      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> delete(~p"/api/mfa/disable", %{
        password: "WrongPassword!",
        code: code
      })

      assert %{
        "error" => "Invalid password"
      } = json_response(conn, 400)
    end

    test "returns error with invalid code", %{conn: conn, user: user, access_token: token} do
      # Enable MFA
      {:ok, mfa_method} = Thalamus.Domain.ValueObjects.MFAMethod.new(:totp, "TESTSECRET123456")
      updated_user = %{user | mfa_enabled: true, mfa_methods: [mfa_method]}
      {:ok, _} = PostgreSQLUserRepository.save(updated_user)

      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> delete(~p"/api/mfa/disable", %{
        password: "Password123!",
        code: "000000"
      })

      assert %{
        "error" => "Invalid verification code"
      } = json_response(conn, 400)
    end

    test "returns error if MFA not enabled", %{conn: conn, access_token: token} do
      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> delete(~p"/api/mfa/disable", %{
        password: "Password123!",
        code: "123456"
      })

      assert %{
        "error" => "MFA is not enabled for this account"
      } = json_response(conn, 400)
    end
  end

  describe "POST /api/mfa/backup-codes/regenerate" do
    test "regenerates backup codes with valid credentials", %{conn: conn, user: user, access_token: token} do
      # Enable MFA
      {:ok, mfa_method} = Thalamus.Domain.ValueObjects.MFAMethod.new(:totp, "TESTSECRET123456")
      updated_user = %{user | mfa_enabled: true, mfa_methods: [mfa_method]}
      {:ok, _} = PostgreSQLUserRepository.save(updated_user)

      code = generate_totp_code("TESTSECRET123456")

      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> post(~p"/api/mfa/backup-codes/regenerate", %{
        password: "Password123!",
        code: code
      })

      assert %{
        "data" => %{
          "backup_codes" => backup_codes,
          "message" => _
        }
      } = json_response(conn, 200)

      assert length(backup_codes) == 10
      Enum.each(backup_codes, fn code ->
        assert String.length(code) == 8
      end)
    end

    test "returns error with invalid password", %{conn: conn, user: user, access_token: token} do
      {:ok, mfa_method} = Thalamus.Domain.ValueObjects.MFAMethod.new(:totp, "TESTSECRET123456")
      updated_user = %{user | mfa_enabled: true, mfa_methods: [mfa_method]}
      {:ok, _} = PostgreSQLUserRepository.save(updated_user)

      code = generate_totp_code("TESTSECRET123456")

      conn = conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> post(~p"/api/mfa/backup-codes/regenerate", %{
        password: "WrongPassword!",
        code: code
      })

      assert %{"error" => _} = json_response(conn, 400)
    end
  end

  # Helper functions

  defp generate_totp_code(secret) do
    # Decode base32 secret
    decoded_secret = Base.decode32!(secret, padding: false)

    # Get current time window (30 second intervals)
    current_time = System.os_time(:second)
    time_window = div(current_time, 30)

    # Convert time window to 8-byte big-endian integer
    time_bytes = <<time_window::unsigned-big-integer-64>>

    # Generate HMAC-SHA1
    hmac = :crypto.mac(:hmac, :sha, decoded_secret, time_bytes)

    # Dynamic truncation (RFC 4226)
    <<_::binary-size(19), offset::4, _::4>> = hmac
    <<_::binary-size(offset), _::1, code::31, _::binary>> = hmac

    # Generate 6-digit code
    code
    |> rem(1_000_000)
    |> Integer.to_string()
    |> String.pad_leading(6, "0")
  end
end
