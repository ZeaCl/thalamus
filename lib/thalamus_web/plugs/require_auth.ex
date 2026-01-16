defmodule ThalamusWeb.Plugs.RequireAuth do
  @moduledoc """
  Plug to require user authentication for dashboard access.

  This plug checks if a user is authenticated (has a session with user_id).
  If not authenticated, redirects to the login page with a return_to parameter.

  ## Usage

  In your router:

      pipeline :dashboard do
        plug :browser
        plug ThalamusWeb.Plugs.RequireAuth
      end

  Or in a controller:

      defmodule ThalamusWeb.SomeController do
        use ThalamusWeb, :controller

        plug ThalamusWeb.Plugs.RequireAuth when action in [:edit, :update]
      end

  ## How it works

  1. Checks if :user_id exists in the session
  2. If yes: allows the request to continue
  3. If no: redirects to /login with return_to parameter

  ## Session structure

  The session should have:
  - :user_id - String UUID of the authenticated user
  """

  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2, put_flash: 3]

  @behaviour Plug

  @doc """
  Initializes the plug with options.

  ## Options

  - `:login_path` - Path to redirect for login (default: "/login")
  """
  @impl true
  def init(opts), do: opts

  @doc """
  Verifies that a user is authenticated.

  If the user is not authenticated, redirects to the login page.
  """
  @impl true
  def call(conn, opts) do
    case get_session(conn, :user_id) do
      nil ->
        # User not authenticated - redirect to login
        login_path = Keyword.get(opts, :login_path, "/login")
        return_to = current_path(conn)

        conn
        |> put_flash(:error, "You must be logged in to access this page")
        |> redirect(to: "#{login_path}?return_to=#{URI.encode(return_to)}")
        |> halt()

      _user_id ->
        # User authenticated - allow request to continue
        conn
    end
  end

  # Private helpers

  defp current_path(conn) do
    case conn.query_string do
      "" -> conn.request_path
      query -> "#{conn.request_path}?#{query}"
    end
  end
end
