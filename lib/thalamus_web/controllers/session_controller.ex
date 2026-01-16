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

  def delete(conn, _params) do
    conn
    |> clear_session()
    |> put_flash(:info, "Logged out successfully")
    |> redirect(to: ~p"/")
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
    get_session(conn, :return_to) || conn.params["return_to"] || ~p"/dashboard"
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
