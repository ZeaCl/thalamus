defmodule ThalamusWeb.ApiKeys.Index do
  @moduledoc """
  LiveView for listing and managing Admin API Keys.
  """
  use ThalamusWeb, :live_view

  # Load authenticated user on mount
  on_mount ThalamusWeb.Live.Hooks.LiveAuth

  import Ecto.Query

  alias Thalamus.Repo
  alias Thalamus.Infrastructure.Persistence.Schemas.AdminApiKeySchema

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "API Keys")
     |> assign(:current_path, "/dashboard/api-keys")
     |> assign(:search_query, "")
     |> assign(:filter_active, :all)
     |> load_api_keys()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New API Key")
    |> assign(:api_key, nil)
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "API Keys")
    |> assign(:api_key, nil)
  end

  @impl true
  def handle_event("search", %{"search" => query}, socket) do
    {:noreply,
     socket
     |> assign(:search_query, query)
     |> load_api_keys()}
  end

  @impl true
  def handle_event("filter", %{"filter" => filter}, socket) do
    filter_atom =
      case filter do
        "active" -> :active
        "inactive" -> :inactive
        _ -> :all
      end

    {:noreply,
     socket
     |> assign(:filter_active, filter_atom)
     |> load_api_keys()}
  end

  @impl true
  def handle_event("revoke", %{"id" => id}, socket) do
    case Repo.get(AdminApiKeySchema, id) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "API key not found")
         |> load_api_keys()}

      api_key ->
        changeset = AdminApiKeySchema.update_changeset(api_key, %{is_active: false})

        case Repo.update(changeset) do
          {:ok, _updated} ->
            {:noreply,
             socket
             |> put_flash(:info, "API key revoked successfully")
             |> load_api_keys()}

          {:error, _changeset} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to revoke API key")
             |> load_api_keys()}
        end
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    case Repo.get(AdminApiKeySchema, id) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "API key not found")
         |> load_api_keys()}

      api_key ->
        case Repo.delete(api_key) do
          {:ok, _deleted} ->
            {:noreply,
             socket
             |> put_flash(:info, "API key deleted successfully")
             |> load_api_keys()}

          {:error, _changeset} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to delete API key")
             |> load_api_keys()}
        end
    end
  end

  defp load_api_keys(socket) do
    search = socket.assigns.search_query
    filter = socket.assigns.filter_active

    api_keys =
      AdminApiKeySchema
      |> apply_search_filter(search)
      |> apply_active_filter(filter)
      |> order_by([k], desc: k.inserted_at)
      |> Repo.all()
      |> Enum.map(&format_api_key/1)

    assign(socket, :api_keys, api_keys)
  end

  defp apply_search_filter(query, "") do
    query
  end

  defp apply_search_filter(query, search) do
    search_pattern = "%#{search}%"

    where(
      query,
      [k],
      ilike(k.name, ^search_pattern) or
        ilike(k.key_prefix, ^search_pattern)
    )
  end

  defp apply_active_filter(query, :all), do: query
  defp apply_active_filter(query, :active), do: where(query, [k], k.is_active == true)
  defp apply_active_filter(query, :inactive), do: where(query, [k], k.is_active == false)

  defp format_api_key(schema) do
    %{
      id: schema.id,
      name: schema.name,
      description: schema.description,
      key_prefix: schema.key_prefix,
      scopes: schema.scopes || [],
      is_active: schema.is_active,
      expires_at: schema.expires_at,
      last_used_at: schema.last_used_at,
      created_at: schema.inserted_at
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8 py-8">
      <.breadcrumbs items={[
        %{label: "Dashboard", path: "/dashboard"},
        %{label: "API Keys", path: nil}
      ]} />
      
    <!-- Header -->
      <div class="sm:flex sm:items-center sm:justify-between">
        <div class="sm:flex-auto">
          <h1 class="text-2xl font-semibold text-base-content">API Keys</h1>
          <p class="mt-2 text-sm text-base-content/70">
            Manage API keys for programmatic access to ZEA
          </p>
        </div>
        <div class="mt-4 sm:ml-16 sm:mt-0 sm:flex-none">
          <.link
            navigate="/dashboard/api-keys/new"
            class="btn btn-primary"
          >
            <svg
              class="h-5 w-5 mr-2"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12 4v16m8-8H4"
              />
            </svg>
            New API Key
          </.link>
        </div>
      </div>
      
    <!-- Search and Filters -->
      <div class="mt-6 flex flex-col sm:flex-row gap-4">
        <div class="flex-1">
          <form phx-change="search" class="relative">
            <input
              type="text"
              name="search"
              value={@search_query}
              placeholder="Search by name or key prefix..."
              class="input input-bordered w-full"
            />
            <svg
              class="absolute right-3 top-3 h-5 w-5 text-base-content/50"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
              />
            </svg>
          </form>
        </div>
        <div class="flex gap-2">
          <form phx-change="filter">
            <select name="filter" class="select select-bordered">
              <option value="all" selected={@filter_active == :all}>All Keys</option>
              <option value="active" selected={@filter_active == :active}>Active Only</option>
              <option value="inactive" selected={@filter_active == :inactive}>
                Revoked Only
              </option>
            </select>
          </form>
        </div>
      </div>
      
    <!-- API Keys Table -->
      <div class="mt-8 flow-root">
        <div class="card bg-base-100 shadow">
          <div class="card-body p-0">
            <%= if @api_keys == [] do %>
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
                    d="M15 7a2 2 0 012 2m4 0a6 6 0 01-7.743 5.743L11 17H9v2H7v2H4a1 1 0 01-1-1v-2.586a1 1 0 01.293-.707l5.964-5.964A6 6 0 1121 9z"
                  />
                </svg>
                <h3 class="mt-2 text-sm font-medium text-base-content">No API keys found</h3>
                <p class="mt-1 text-sm text-base-content/70">
                  Get started by creating a new API key for programmatic access.
                </p>
                <div class="mt-6">
                  <.link navigate="/dashboard/api-keys/new" class="btn btn-primary">
                    <svg
                      class="h-5 w-5 mr-2"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M12 4v16m8-8H4"
                      />
                    </svg>
                    New API Key
                  </.link>
                </div>
              </div>
            <% else %>
              <div class="overflow-x-auto">
                <table class="table table-sm">
                  <thead>
                    <tr>
                      <th>Name</th>
                      <th>Key Prefix</th>
                      <th>Scopes</th>
                      <th>Status</th>
                      <th>Last Used</th>
                      <th>Created</th>
                      <th class="text-right">Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for key <- @api_keys do %>
                      <tr>
                        <td>
                          <div>
                            <div class="font-medium text-base-content">
                              {key.name}
                            </div>
                            <%= if key.description do %>
                              <div class="text-xs text-base-content/50 mt-1">
                                {key.description}
                              </div>
                            <% end %>
                          </div>
                        </td>
                        <td>
                          <code class="text-xs font-mono text-base-content/70 bg-base-200 px-2 py-1 rounded">
                            {key.key_prefix}
                          </code>
                        </td>
                        <td class="text-xs">
                          <%= if key.scopes == [] do %>
                            <span class="text-base-content/50">none</span>
                          <% else %>
                            {Enum.join(Enum.take(key.scopes, 2), ", ")}{if length(key.scopes) > 2,
                              do: "..."}
                          <% end %>
                        </td>
                        <td>
                          <%= if key.is_active do %>
                            <span class="badge badge-sm badge-success">Active</span>
                          <% else %>
                            <span class="badge badge-sm badge-error">Revoked</span>
                          <% end %>
                          <%= if key.expires_at && DateTime.compare(DateTime.utc_now(), key.expires_at) == :gt do %>
                            <span class="badge badge-sm badge-warning ml-1">Expired</span>
                          <% end %>
                        </td>
                        <td class="text-xs text-base-content/70">
                          <%= if key.last_used_at do %>
                            {Calendar.strftime(key.last_used_at, "%Y-%m-%d %H:%M")}
                          <% else %>
                            <span class="text-base-content/30">Never</span>
                          <% end %>
                        </td>
                        <td class="text-xs text-base-content/70">
                          {Calendar.strftime(key.created_at, "%Y-%m-%d")}
                        </td>
                        <td class="text-right">
                          <div class="flex justify-end gap-2">
                            <.link
                              navigate={"/dashboard/api-keys/#{key.id}"}
                              class="btn btn-ghost btn-xs"
                            >
                              View
                            </.link>
                            <%= if key.is_active do %>
                              <button
                                phx-click="revoke"
                                phx-value-id={key.id}
                                data-confirm="Are you sure you want to revoke this API key? This action cannot be undone."
                                class="btn btn-ghost btn-xs text-warning"
                              >
                                Revoke
                              </button>
                            <% end %>
                            <button
                              phx-click="delete"
                              phx-value-id={key.id}
                              data-confirm="Are you sure you want to delete this API key? This action cannot be undone."
                              class="btn btn-ghost btn-xs text-error"
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
        </div>
      </div>
    </div>
    """
  end
end
