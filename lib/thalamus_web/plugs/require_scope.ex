defmodule ThalamusWeb.Plugs.RequireScope do
  @moduledoc """
  Scope Authorization Plug.

  Ensures the authenticated token has the required OAuth2 scopes
  to access the endpoint.

  This plug should be used after AuthenticateToken plug.

  ## Usage

      pipeline :users_api do
        plug :accepts, ["json"]
        plug ThalamusWeb.Plugs.AuthenticateToken
        plug ThalamusWeb.Plugs.RequireScope, scopes: ["users:read"]
      end

      # Or in a controller:
      plug ThalamusWeb.Plugs.RequireScope, scopes: ["users:write"] when action in [:create, :update, :delete]
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  @doc """
  Initialize the plug with required scopes.

  ## Options
  - :scopes - List of required scopes (at least one must match)
  - :require_all - If true, all scopes must be present (default: false)
  """
  def init(opts) do
    scopes = Keyword.get(opts, :scopes, [])
    require_all = Keyword.get(opts, :require_all, false)

    %{
      scopes: scopes,
      require_all: require_all
    }
  end

  @doc """
  Call the plug to check if the token has required scopes.
  """
  def call(conn, %{scopes: required_scopes, require_all: require_all}) do
    # Get the token scopes from conn.assigns (set by AuthenticateToken)
    token_scopes = conn.assigns[:token_scope] || []

    cond do
      # No scopes required
      required_scopes == [] ->
        conn

      # Require all scopes
      require_all ->
        if all_scopes_present?(token_scopes, required_scopes) do
          conn
        else
          forbidden(conn, "Missing required scopes: #{Enum.join(required_scopes, ", ")}")
        end

      # Require at least one scope
      true ->
        if any_scope_present?(token_scopes, required_scopes) do
          conn
        else
          forbidden(conn, "Missing required scopes: #{Enum.join(required_scopes, ", ")}")
        end
    end
  end

  # Private functions

  defp all_scopes_present?(token_scopes, required_scopes) do
    Enum.all?(required_scopes, fn scope ->
      scope in token_scopes
    end)
  end

  defp any_scope_present?(token_scopes, required_scopes) do
    Enum.any?(required_scopes, fn scope ->
      scope in token_scopes
    end)
  end

  defp forbidden(conn, message) do
    conn
    |> put_status(:forbidden)
    |> json(%{
      error: "insufficient_scope",
      error_description: message
    })
    |> halt()
  end
end
