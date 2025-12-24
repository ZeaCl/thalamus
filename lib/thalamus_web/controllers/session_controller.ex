defmodule ThalamusWeb.SessionController do
  @moduledoc """
  Handles user authentication sessions for OAuth2 authorization flow.
  This is the login page where users authenticate before granting OAuth2 consent.
  """
  use ThalamusWeb, :controller

  alias Thalamus.Infrastructure.Repositories.PostgreSQLUserRepository
  alias Thalamus.Domain.ValueObjects.{Email, UserId, PasswordHash}

  @doc """
  GET /login

  Shows the login form.
  Can redirect back to OAuth2 authorization flow after successful login.
  """
  def new(conn, params) do
    # Check if user is already authenticated
    case get_session(conn, :user_id) do
      nil ->
        # Not authenticated, show login form
        render(conn, :new, return_to: params["return_to"])

      _user_id ->
        # Already authenticated, redirect to return_to or home
        redirect_url = params["return_to"] || "/"
        redirect(conn, to: redirect_url)
    end
  end

  @doc """
  POST /login

  Processes login form submission and authenticates the user.
  """
  def create(conn, %{"user" => %{"email" => email_string, "password" => password}} = params) do
    return_to = params["return_to"]

    # Authenticate user
    with {:ok, email} <- Email.from_string(email_string),
         {:ok, user} <- PostgreSQLUserRepository.find_by_email(email),
         :ok <- PasswordHash.verify(user.password_hash, password) do
      # Check user status
      case user.status do
        :active ->
          # Authentication successful
          # Check if there's a stored authorization request to redirect back to
          redirect_url = build_redirect_url(conn, return_to)

          conn
          |> put_session(:user_id, UserId.to_string(user.id))
          |> delete_session(:authorization_request)
          |> put_flash(:info, "Welcome back!")
          |> redirect(to: redirect_url)

        :pending_verification ->
          conn
          |> put_flash(:error, "Please verify your email address before logging in")
          |> render(:new, return_to: return_to)

        :locked ->
          conn
          |> put_flash(:error, "Your account has been locked")
          |> render(:new, return_to: return_to)

        _ ->
          conn
          |> put_flash(:error, "Your account is not active")
          |> render(:new, return_to: return_to)
      end
    else
      _ ->
        # Invalid credentials
        conn
        |> put_flash(:error, "Invalid email or password")
        |> render(:new, return_to: return_to)
    end
  end

  @doc """
  DELETE /logout

  Logs out the current user.
  """
  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> put_flash(:info, "You have been logged out")
    |> redirect(to: "/")
  end

  # Private helper functions

  defp build_redirect_url(conn, return_to) do
    case get_session(conn, :authorization_request) do
      nil ->
        # No stored authorization request, use return_to or default
        return_to || "/"

      auth_params when is_map(auth_params) ->
        # Rebuild the authorization URL with original parameters
        query_string = URI.encode_query(auth_params)
        return_to <> "?" <> query_string

      _ ->
        return_to || "/"
    end
  end
end
