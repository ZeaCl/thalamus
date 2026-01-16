defmodule ThalamusWeb.Live.Hooks.LiveAuth do
  @moduledoc """
  LiveView hook for loading authenticated user.

  This hook:
  1. Reads user_id from the session (set by SessionController on login)
  2. Loads the full user record with organization preloaded
  3. Makes it available in socket assigns as :current_user

  ## Usage

  In your LiveView:

      defmodule MyLiveView do
        use ThalamusWeb, :live_view

        on_mount ThalamusWeb.Live.Hooks.LiveAuth

        def mount(_params, _session, socket) do
          # socket.assigns.current_user is now available
          # socket.assigns.current_organization is now available
          {:ok, socket}
        end
      end

  ## Assigns set by this hook

  - `:current_user` - The authenticated user struct (or nil if not logged in)
  - `:current_organization` - The user's organization (or nil if user has no org)

  ## Note

  This hook does NOT redirect unauthenticated users. It only loads the user if present.
  Use ThalamusWeb.Plugs.RequireAuth in your router pipeline to enforce authentication.
  """

  import Phoenix.Component

  alias Thalamus.Repo
  alias Thalamus.Infrastructure.Persistence.Schemas.UserSchema

  @doc """
  on_mount callback that loads the current user from session.
  """
  def on_mount(:default, _params, session, socket) do
    socket =
      case session["user_id"] do
        nil ->
          socket
          |> assign(:current_user, nil)
          |> assign(:current_organization, nil)

        user_id ->
          case load_user(user_id) do
            {:ok, user} ->
              socket
              |> assign(:current_user, user)
              |> assign(:current_organization, user.organization)

            {:error, _reason} ->
              # User not found (maybe deleted?) - clear invalid session
              socket
              |> assign(:current_user, nil)
              |> assign(:current_organization, nil)
          end
      end

    {:cont, socket}
  end

  # Private helpers

  defp load_user(user_id) do
    case Repo.get(UserSchema, user_id) do
      nil ->
        {:error, :not_found}

      user ->
        # Preload organization if associated
        user = Repo.preload(user, :organization)
        {:ok, user}
    end
  end
end
