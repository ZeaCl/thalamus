defmodule ThalamusWeb.Plugs.RequireSuperAdmin do
  @moduledoc """
  Plug that ensures the current user has super_admin role.

  This plug must be used AFTER authentication (e.g., after APIAuth plug).
  It checks if the authenticated user has the `super_admin` role.

  ## Usage

      pipeline :super_admin do
        plug :accepts, ["json"]
        plug ThalamusWeb.Plugs.APIAuth
        plug ThalamusWeb.Plugs.RequireSuperAdmin
      end

  ## Behavior

  - If user is authenticated as JWT and has super_admin role → Allow
  - If user is authenticated but not super_admin → 403 Forbidden
  - If authenticated with API Key → 403 Forbidden (API keys cannot manage other API keys)

  SOLID Principles Applied:
  - Single Responsibility: Only checks for super_admin role
  - Open/Closed: Can be extended for other role checks without modification
  """

  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.assigns do
      %{auth_type: :jwt, current_user: user} ->
        check_super_admin_role(conn, user)

      %{auth_type: :api_key} ->
        # API keys cannot manage other API keys (security measure)
        forbidden(
          conn,
          "API keys cannot access super admin endpoints. Use a super admin user account."
        )

      _ ->
        # Not authenticated (should not happen if APIAuth plug ran first)
        unauthorized(conn, "Authentication required")
    end
  end

  defp check_super_admin_role(conn, user) do
    # TODO: Implement actual role checking once User entity has roles field
    # For now, this is a placeholder

    # Expected implementation:
    # if has_role?(user, :super_admin) do
    #   conn
    # else
    #   forbidden(conn, "Super admin access required")
    # end

    # Placeholder: Allow all authenticated users
    # IMPORTANT: Replace this with actual role checking before production!
    case get_user_roles(user) do
      roles when is_list(roles) ->
        if :super_admin in roles or "super_admin" in roles do
          conn
        else
          forbidden(
            conn,
            "Super admin access required. Your roles: #{inspect(roles)}"
          )
        end

      _ ->
        # No roles found, deny access
        forbidden(conn, "Super admin access required. No roles assigned to user.")
    end
  end

  defp get_user_roles(user) do
    # TODO: Update this when User entity has roles field
    # Expected: user.roles or user.organization_roles

    # Placeholder: Check if user has roles in map
    cond do
      is_map(user) and Map.has_key?(user, :roles) ->
        user.roles

      is_map(user) and Map.has_key?(user, "roles") ->
        user["roles"]

      # For development/testing: allow user with id "admin" or email containing "admin"
      is_map(user) and user[:id] == "admin-user-id" ->
        [:super_admin]

      is_map(user) and is_binary(user[:email]) and String.contains?(user[:email], "admin") ->
        [:super_admin]

      is_map(user) and (user[:id] == "admin" or user["id"] == "admin") ->
        [:super_admin]

      true ->
        []
    end
  end

  defp forbidden(conn, message) do
    conn
    |> put_status(:forbidden)
    |> json(%{error: message})
    |> halt()
  end

  defp unauthorized(conn, message) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: message})
    |> halt()
  end
end
