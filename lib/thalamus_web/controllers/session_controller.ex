defmodule ThalamusWeb.SessionController do
  use ThalamusWeb, :controller

  alias Thalamus.Repo
  alias Thalamus.Infrastructure.Persistence.Schemas.UserSchema

  def new(conn, params) do
    # Preserve return_to parameter in session for OAuth2 authorization flow
    conn =
      case params["return_to"] do
        nil -> conn
        return_to -> put_session(conn, :return_to, return_to)
      end

    render(conn, :new, layout: false)
  end

  def create(conn, %{"session" => %{"email" => email, "password" => password}}) do
    case authenticate_user(email, password) do
      {:ok, user} ->
        # Check if there's an OAuth2 authorization request in session
        authorization_request = get_session(conn, :authorization_request)

        conn
        |> put_flash(:info, "Welcome back!")
        |> put_session(:user_id, user.id)
        # Clear return_to after reading it
        |> delete_session(:return_to)
        # Clear authorization request
        |> delete_session(:authorization_request)
        |> redirect_after_login(authorization_request)

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Invalid email or password")
        |> render(:new, layout: false)
    end
  end

  def delete(conn, params) do
    return_to =
      params["return_to"] || conn.params["return_to"] ||
        System.get_env("DEFAULT_LOGOUT_URL") || "http://zea.localhost"

    conn
    |> clear_session()
    |> put_flash(:info, "Logged out successfully")
    |> redirect(external: return_to)
  end

  def mock_oauth(conn, %{"provider" => provider}) do
    email_string =
      case provider do
        "google" -> "google-dev@zea.cl"
        "github" -> "github-dev@zea.cl"
        _ -> "dev@zea.cl"
      end

    name =
      case provider do
        "google" -> "Google Developer"
        "github" -> "GitHub Developer"
        _ -> "ZEA Developer"
      end

    user =
      case Repo.get_by(UserSchema, email: email_string) do
        nil ->
          password_hash = Bcrypt.hash_pwd_salt(:crypto.strong_rand_bytes(16) |> Base.encode64())

          user_params = %{
            email: email_string,
            name: name,
            password_hash: password_hash,
            status: :active,
            verified_at: DateTime.truncate(DateTime.utc_now(), :second)
          }

          {:ok, new_user} = Repo.insert(UserSchema.create_changeset(user_params))
          new_user

        existing_user ->
          existing_user
      end

    authorization_request = get_session(conn, :authorization_request)

    conn
    |> put_flash(:info, "Successfully authenticated with #{String.capitalize(provider)}!")
    |> put_session(:user_id, user.id)
    |> delete_session(:return_to)
    |> delete_session(:authorization_request)
    |> redirect_after_login(authorization_request)
  end

  defp authenticate_user(email, password) do
    user = Repo.get_by(UserSchema, email: email)

    if user && Bcrypt.verify_pass(password, user.password_hash) && user.status == :active do
      {:ok, user}
    else
      Bcrypt.no_user_verify()
      {:error, :invalid_credentials}
    end
  end

  defp get_return_to(conn) do
    get_session(conn, :return_to) || conn.params["return_to"] ||
      System.get_env("DEFAULT_REDIRECT_URL") || "http://zea.localhost/dashboard"
  end

  defp redirect_after_login(conn, nil) do
    # No authorization request - use normal return_to logic
    redirect(conn, to: get_return_to(conn))
  end

  defp redirect_after_login(conn, authorization_request) when is_map(authorization_request) do
    # Rebuild authorization URL with original OAuth2 parameters
    query_string = URI.encode_query(authorization_request)
    redirect(conn, to: "/oauth/authorize?" <> query_string)
  end
end
