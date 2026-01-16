defmodule ThalamusWeb.Users.Index do
  @moduledoc """
  LiveView for listing and managing users.
  """
  use ThalamusWeb, :live_view

  # Load authenticated user on mount
  on_mount ThalamusWeb.Live.Hooks.LiveAuth

  import Ecto.Query

  alias Thalamus.Repo
  alias Thalamus.Infrastructure.Persistence.Schemas.UserSchema

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_path, "/dashboard/users")
     |> assign(:search, "")
     |> assign(:filter, "all")
     |> load_users()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Users")
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    {:noreply,
     socket
     |> assign(:search, search)
     |> load_users()}
  end

  @impl true
  def handle_event("filter", %{"filter" => filter}, socket) do
    {:noreply,
     socket
     |> assign(:filter, filter)
     |> load_users()}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    case Repo.get(UserSchema, id) do
      nil ->
        {:noreply, put_flash(socket, :error, "User not found")}

      user ->
        case Repo.delete(user) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, "User deleted successfully")
             |> load_users()}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to delete user")}
        end
    end
  end

  defp load_users(socket) do
    search = socket.assigns.search
    filter = socket.assigns.filter

    query =
      UserSchema
      |> filter_by_search(search)
      |> filter_by_status(filter)
      |> order_by([u], desc: u.inserted_at)
      |> preload(:organization)

    users = Repo.all(query)

    assign(socket, :users, users)
  end

  defp filter_by_search(query, ""), do: query

  defp filter_by_search(query, search) do
    search_pattern = "%#{search}%"

    where(
      query,
      [u],
      ilike(u.email, ^search_pattern) or ilike(u.name, ^search_pattern)
    )
  end

  defp filter_by_status(query, "all"), do: query

  defp filter_by_status(query, status_string) do
    status = String.to_existing_atom(status_string)
    where(query, [u], u.status == ^status)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8 py-8">
      <.breadcrumbs items={[
        %{label: "Dashboard", path: "/dashboard"},
        %{label: "Users", path: nil}
      ]} />
      
    <!-- Header -->
      <div class="sm:flex sm:items-center sm:justify-between mb-8">
        <div>
          <h1 class="text-2xl font-semibold text-base-content">Users</h1>
          <p class="mt-2 text-sm text-base-content/70">
            Manage user accounts and permissions
          </p>
        </div>
        <div class="mt-4 sm:mt-0">
          <.link navigate={~p"/dashboard/users/new"} class="btn btn-primary">
            <svg class="h-5 w-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12 4v16m8-8H4"
              />
            </svg>
            New User
          </.link>
        </div>
      </div>
      
    <!-- Search and Filters -->
      <div class="mb-6 flex flex-col sm:flex-row gap-4">
        <!-- Search -->
        <form phx-change="search" class="flex-1">
          <input
            type="text"
            name="search"
            value={@search}
            placeholder="Search by email or name..."
            class="input input-bordered w-full"
          />
        </form>
        
    <!-- Status Filter -->
        <form phx-change="filter" class="w-full sm:w-48">
          <select name="filter" class="select select-bordered w-full">
            <option value="all" selected={@filter == "all"}>All Status</option>
            <option value="active" selected={@filter == "active"}>Active</option>
            <option value="pending_verification" selected={@filter == "pending_verification"}>
              Pending
            </option>
            <option value="suspended" selected={@filter == "suspended"}>Suspended</option>
            <option value="deactivated" selected={@filter == "deactivated"}>Deactivated</option>
          </select>
        </form>
      </div>
      
    <!-- Users Table -->
      <%= if @users == [] do %>
        <div class="text-center py-12">
          <svg
            class="mx-auto h-12 w-12 text-base-content/30"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"
            />
          </svg>
          <h3 class="mt-2 text-sm font-medium text-base-content">No users found</h3>
          <p class="mt-1 text-sm text-base-content/70">
            <%= if @search != "" or @filter != "all" do %>
              Try adjusting your search or filter criteria
            <% else %>
              Get started by creating a new user
            <% end %>
          </p>
        </div>
      <% else %>
        <div class="overflow-x-auto bg-base-100 shadow rounded-lg">
          <table class="table table-zebra">
            <thead>
              <tr>
                <th>Email</th>
                <th>Name</th>
                <th>Organization</th>
                <th>Status</th>
                <th>Last Login</th>
                <th>MFA</th>
                <th class="text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              <%= for user <- @users do %>
                <tr>
                  <td>
                    <div class="font-medium">{user.email}</div>
                    <%= if user.verified_at do %>
                      <span class="badge badge-xs badge-success">Verified</span>
                    <% end %>
                  </td>
                  <td>{user.name || "-"}</td>
                  <td>
                    <%= if user.organization do %>
                      {user.organization.name}
                    <% else %>
                      <span class="text-base-content/50">No organization</span>
                    <% end %>
                  </td>
                  <td>
                    <span class={[
                      "badge badge-sm",
                      status_badge_class(user.status)
                    ]}>
                      {format_status(user.status)}
                    </span>
                  </td>
                  <td>
                    <%= if user.last_login_at do %>
                      {Calendar.strftime(user.last_login_at, "%Y-%m-%d %H:%M")}
                    <% else %>
                      <span class="text-base-content/50">Never</span>
                    <% end %>
                  </td>
                  <td>
                    <%= if user.mfa_methods && length(user.mfa_methods) > 0 do %>
                      <span class="badge badge-sm badge-info">
                        {length(user.mfa_methods)} methods
                      </span>
                    <% else %>
                      <span class="text-base-content/50">None</span>
                    <% end %>
                  </td>
                  <td class="text-right">
                    <div class="flex justify-end gap-2">
                      <.link navigate={~p"/dashboard/users/#{user.id}"} class="btn btn-ghost btn-sm">
                        View
                      </.link>
                      <.link
                        navigate={~p"/dashboard/users/#{user.id}/edit"}
                        class="btn btn-ghost btn-sm"
                      >
                        Edit
                      </.link>
                      <button
                        phx-click="delete"
                        phx-value-id={user.id}
                        data-confirm="Are you sure you want to delete this user?"
                        class="btn btn-ghost btn-sm text-error"
                      >
                        Delete
                      </button>
                    </div>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>
    </div>
    """
  end

  # Helper functions

  defp status_badge_class(:active), do: "badge-success"
  defp status_badge_class(:pending_verification), do: "badge-warning"
  defp status_badge_class(:suspended), do: "badge-error"
  defp status_badge_class(:deactivated), do: "badge-ghost"

  defp format_status(:active), do: "Active"
  defp format_status(:pending_verification), do: "Pending"
  defp format_status(:suspended), do: "Suspended"
  defp format_status(:deactivated), do: "Deactivated"
end
