defmodule ThalamusWeb.ApiKeys.Show do
  @moduledoc """
  LiveView for showing Admin API Key details.
  """
  use ThalamusWeb, :live_view

  # Load authenticated user on mount
  on_mount ThalamusWeb.Live.Hooks.LiveAuth

  alias Thalamus.Repo
  alias Thalamus.Infrastructure.Persistence.Schemas.AdminApiKeySchema

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Repo.get(AdminApiKeySchema, id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "API key not found")
         |> push_navigate(to: ~p"/dashboard/api-keys")}

      api_key ->
        {:ok,
         socket
         |> assign(:page_title, api_key.name)
         |> assign(:current_path, "/dashboard/api-keys/#{id}")
         |> assign(:api_key, format_api_key(api_key))}
    end
  end

  @impl true
  def handle_event("revoke", _params, socket) do
    api_key_id = socket.assigns.api_key.id

    case Repo.get(AdminApiKeySchema, api_key_id) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "API key not found")
         |> push_navigate(to: ~p"/dashboard/api-keys")}

      api_key ->
        changeset = AdminApiKeySchema.update_changeset(api_key, %{is_active: false})

        case Repo.update(changeset) do
          {:ok, updated} ->
            {:noreply,
             socket
             |> put_flash(:info, "API key revoked successfully")
             |> assign(:api_key, format_api_key(updated))}

          {:error, _changeset} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to revoke API key")}
        end
    end
  end

  @impl true
  def handle_event("activate", _params, socket) do
    api_key_id = socket.assigns.api_key.id

    case Repo.get(AdminApiKeySchema, api_key_id) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "API key not found")
         |> push_navigate(to: ~p"/dashboard/api-keys")}

      api_key ->
        changeset = AdminApiKeySchema.update_changeset(api_key, %{is_active: true})

        case Repo.update(changeset) do
          {:ok, updated} ->
            {:noreply,
             socket
             |> put_flash(:info, "API key activated successfully")
             |> assign(:api_key, format_api_key(updated))}

          {:error, _changeset} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to activate API key")}
        end
    end
  end

  @impl true
  def handle_event("delete", _params, socket) do
    api_key_id = socket.assigns.api_key.id

    case Repo.get(AdminApiKeySchema, api_key_id) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "API key not found")
         |> push_navigate(to: ~p"/dashboard/api-keys")}

      api_key ->
        case Repo.delete(api_key) do
          {:ok, _deleted} ->
            {:noreply,
             socket
             |> put_flash(:info, "API key deleted successfully")
             |> push_navigate(to: ~p"/dashboard/api-keys")}

          {:error, _changeset} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to delete API key")}
        end
    end
  end

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
      created_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8 py-8">
      <.breadcrumbs items={[
        %{label: "Dashboard", path: "/dashboard"},
        %{label: "API Keys", path: "/dashboard/api-keys"},
        %{label: @api_key.name, path: nil}
      ]} />
      
    <!-- Header -->
      <div class="sm:flex sm:items-center sm:justify-between mb-6">
        <div class="sm:flex-auto">
          <h1 class="text-2xl font-semibold text-base-content">{@api_key.name}</h1>
          <%= if @api_key.description do %>
            <p class="mt-2 text-sm text-base-content/70">
              {@api_key.description}
            </p>
          <% end %>
        </div>
        <div class="mt-4 sm:ml-16 sm:mt-0 flex gap-2">
          <%= if @api_key.is_active do %>
            <button
              phx-click="revoke"
              data-confirm="Are you sure you want to revoke this API key? This action cannot be undone."
              class="btn btn-warning"
            >
              Revoke Key
            </button>
          <% else %>
            <button phx-click="activate" class="btn btn-success">
              Activate Key
            </button>
          <% end %>
          <button
            phx-click="delete"
            data-confirm="Are you sure you want to delete this API key? This action cannot be undone."
            class="btn btn-error"
          >
            Delete
          </button>
        </div>
      </div>
      
    <!-- Status Alert -->
      <%= if not @api_key.is_active do %>
        <div class="alert alert-error mb-6">
          <svg
            class="h-5 w-5"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
            />
          </svg>
          <span>This API key has been revoked and can no longer be used.</span>
        </div>
      <% end %>

      <%= if @api_key.expires_at && DateTime.compare(DateTime.utc_now(), @api_key.expires_at) == :gt do %>
        <div class="alert alert-warning mb-6">
          <svg
            class="h-5 w-5"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
            />
          </svg>
          <span>
            This API key expired on {Calendar.strftime(@api_key.expires_at, "%Y-%m-%d %H:%M:%S")} UTC
          </span>
        </div>
      <% end %>
      
    <!-- Details Cards -->
      <div class="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <!-- Key Information -->
        <div class="card bg-base-100 shadow">
          <div class="card-body">
            <h2 class="card-title text-lg mb-4">Key Information</h2>

            <div class="space-y-4">
              <div>
                <div class="text-sm text-base-content/70 mb-1">Key Prefix</div>
                <code class="text-base font-mono bg-base-200 px-3 py-2 rounded block">
                  {@api_key.key_prefix}
                </code>
              </div>

              <div>
                <div class="text-sm text-base-content/70 mb-1">Status</div>
                <%= if @api_key.is_active do %>
                  <span class="badge badge-success">Active</span>
                <% else %>
                  <span class="badge badge-error">Revoked</span>
                <% end %>
                <%= if @api_key.expires_at && DateTime.compare(DateTime.utc_now(), @api_key.expires_at) == :gt do %>
                  <span class="badge badge-warning ml-2">Expired</span>
                <% end %>
              </div>

              <div>
                <div class="text-sm text-base-content/70 mb-1">Last Used</div>
                <%= if @api_key.last_used_at do %>
                  <div class="text-base-content">
                    {Calendar.strftime(@api_key.last_used_at, "%Y-%m-%d %H:%M:%S")} UTC
                  </div>
                <% else %>
                  <div class="text-base-content/50">Never used</div>
                <% end %>
              </div>

              <div>
                <div class="text-sm text-base-content/70 mb-1">Expires</div>
                <%= if @api_key.expires_at do %>
                  <div class="text-base-content">
                    {Calendar.strftime(@api_key.expires_at, "%Y-%m-%d %H:%M:%S")} UTC
                  </div>
                <% else %>
                  <div class="text-base-content/50">Never expires</div>
                <% end %>
              </div>

              <div>
                <div class="text-sm text-base-content/70 mb-1">Created</div>
                <div class="text-base-content">
                  {Calendar.strftime(@api_key.created_at, "%Y-%m-%d %H:%M:%S")} UTC
                </div>
              </div>
            </div>
          </div>
        </div>
        
    <!-- Scopes -->
        <div class="card bg-base-100 shadow">
          <div class="card-body">
            <h2 class="card-title text-lg mb-4">Permissions (Scopes)</h2>

            <%= if @api_key.scopes == [] do %>
              <div class="text-center py-8 text-base-content/50">
                <svg
                  class="mx-auto h-12 w-12 mb-2"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"
                  />
                </svg>
                No scopes assigned
              </div>
            <% else %>
              <div class="space-y-2">
                <%= for scope <- @api_key.scopes do %>
                  <div class="flex items-center gap-3 p-3 bg-base-200 rounded-lg">
                    <svg
                      class="h-5 w-5 text-success flex-shrink-0"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                      />
                    </svg>
                    <code class="font-mono text-sm">{scope}</code>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      </div>
      
    <!-- Usage Information -->
      <div class="card bg-base-100 shadow mt-6">
        <div class="card-body">
          <h2 class="card-title text-lg mb-4">How to Use This API Key</h2>

          <p class="text-sm text-base-content/70 mb-4">
            To authenticate API requests, include this header in your HTTP requests:
          </p>

          <div class="mockup-code">
            <pre><code>Authorization: Bearer <%= @api_key.key_prefix %>****************************</code></pre>
          </div>

          <p class="text-sm text-base-content/70 mt-4">
            Replace the asterisks with the full API key that was shown when you created it.
          </p>

          <div class="alert alert-info mt-4">
            <svg
              class="h-5 w-5"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
              />
            </svg>
            <span class="text-sm">
              For security, the full API key is only shown once when created. If you've lost it, revoke this key and create a new one.
            </span>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
