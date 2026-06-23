defmodule ThalamusWeb.API.LoginController do
  use ThalamusWeb, :controller

  alias Thalamus.Repo
  alias Thalamus.Infrastructure.Persistence.Schemas.UserSchema

  @doc """
  POST /api/public/login

  Simple API login — same logic as the browser login (SessionController).

  ## Request Body (JSON)
  {
    "email": "user@example.com",
    "password": "SecurePassword123!"
  }

  ## Response (200 OK)
  {
    "access_token": "eyJ...",
    "token_type": "Bearer",
    "expires_in": 3600,
    "user": { "id": "...", "email": "...", "name": "...", "verified": true }
  }
  """
  def create(conn, params) do
    email = params["email"] || ""
    password = params["password"] || ""

    if email == "" or password == "" do
      conn
      |> put_status(:bad_request)
      |> json(%{error: "missing_parameter", error_description: "Email and password are required"})
    else
      case authenticate(email, password) do
        {:ok, user} ->
          token = generate_token(user)

          conn
          |> put_status(:ok)
          |> json(%{
            access_token: token,
            token_type: "Bearer",
            expires_in: 3600,
            user: %{
              id: user.id,
              email: user.email,
              name: user.name,
              verified: not is_nil(user.verified_at)
            }
          })

        {:error, reason} ->
          conn
          |> put_status(:unauthorized)
          |> json(%{error: reason, error_description: error_description(reason)})
      end
    end
  end

  # ── Auth (same as SessionController) ──────────────────────────

  defp authenticate(email, password) do
    user = Repo.get_by(UserSchema, email: String.downcase(email))

    cond do
      is_nil(user) ->
        Bcrypt.no_user_verify()
        {:error, "invalid_credentials"}

      not Bcrypt.verify_pass(password, user.password_hash) ->
        {:error, "invalid_credentials"}

      user.status != :active ->
        {:error, "account_inactive"}

      true ->
        {:ok, user}
    end
  end

  # ── Token (simple JWT) ────────────────────────────────────────

  defp generate_token(user) do
    signer = Joken.Signer.create("HS256", signing_secret())

    claims = %{
      "sub" => user.id,
      "email" => user.email,
      "name" => user.name,
      "iat" => DateTime.utc_now() |> DateTime.to_unix(),
      "exp" => DateTime.utc_now() |> DateTime.to_unix() |> Kernel.+(3600)
    }

    {:ok, token, _claims} = Joken.encode_and_sign(claims, signer)
    token
  end

  defp signing_secret do
    Application.get_env(:thalamus, ThalamusWeb.Endpoint)[:secret_key_base] ||
      "dev-secret-key-base-at-least-64-chars-long-change-in-production"
  end

  # ── Helpers ───────────────────────────────────────────────────

  defp error_description("invalid_credentials"), do: "Invalid email or password"
  defp error_description("account_inactive"), do: "Account is not active"
end
