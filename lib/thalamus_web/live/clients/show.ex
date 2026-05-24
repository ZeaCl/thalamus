defmodule ThalamusWeb.Clients.Show do
  @moduledoc """
  LiveView for showing OAuth2 client details.
  """
  use ThalamusWeb, :live_view

  # Load authenticated user on mount
  on_mount ThalamusWeb.Live.Hooks.LiveAuth

  import Ecto.Query

  alias Thalamus.Repo
  alias Thalamus.Infrastructure.Persistence.Schemas.{OAuth2ClientSchema, TokenSchema}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_path, "/dashboard/clients")
     |> assign(:show_secret, false)}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    case Repo.get_by(OAuth2ClientSchema, client_id_string: id) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "Client not found")
         |> push_navigate(to: ~p"/dashboard/clients")}

      client ->
        {:noreply,
         socket
         |> assign(:page_title, "Client Details")
         |> assign(:client, client)
         |> load_stats(client)}
    end
  end

  @impl true
  def handle_event("toggle_secret", _params, socket) do
    {:noreply, assign(socket, :show_secret, !socket.assigns.show_secret)}
  end

  @impl true
  def handle_event("rotate_secret", _params, socket) do
    # Generate new secret
    new_secret = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    hashed_secret = Bcrypt.hash_pwd_salt(new_secret)

    changeset =
      socket.assigns.client
      |> OAuth2ClientSchema.rotate_secret_changeset(hashed_secret)

    case Repo.update(changeset) do
      {:ok, updated_client} ->
        {:noreply,
         socket
         |> assign(:client, updated_client)
         |> assign(:new_secret, new_secret)
         |> put_flash(:info, "Client secret rotated successfully!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to rotate secret")}
    end
  end

  defp load_stats(socket, client) do
    # Get token stats
    token_stats =
      TokenSchema
      |> where([t], t.client_id == ^client.id)
      |> select([t], %{
        total: count(t.id),
        active:
          fragment("COUNT(CASE WHEN ? = false AND ? > NOW() THEN 1 END)", t.revoked, t.expires_at),
        revoked: fragment("COUNT(CASE WHEN ? = true THEN 1 END)", t.revoked)
      })
      |> Repo.one()

    # Get recent tokens
    recent_tokens =
      TokenSchema
      |> where([t], t.client_id == ^client.id)
      |> order_by([t], desc: t.inserted_at)
      |> limit(5)
      |> Repo.all()

    socket
    |> assign(:token_stats, token_stats || %{total: 0, active: 0, revoked: 0})
    |> assign(:recent_tokens, recent_tokens)
    |> assign(:new_secret, nil)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8 py-8">
      <.breadcrumbs items={[
        %{label: "Dashboard", path: "/dashboard"},
        %{label: "Multi-Agent Clients", path: "/dashboard/clients"},
        %{label: @client.name, path: nil}
      ]} />
      
    <!-- Header -->
      <div class="mb-8">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-semibold text-base-content">{@client.name}</h1>
            <p class="text-sm text-base-content/70 mt-1">
              <code class="font-mono">{@client.client_id_string}</code>
            </p>
          </div>
          <div class="flex gap-2">
            <.link
              navigate={~p"/dashboard/clients"}
              class="btn btn-sm btn-ghost"
            >
              Back to Clients
            </.link>
            <.link
              navigate={~p"/dashboard/clients/#{@client.client_id_string}/edit"}
              class="btn btn-sm btn-ghost"
            >
              Edit
            </.link>
            <%= if @client.is_active do %>
              <span class="badge badge-success">Active</span>
            <% else %>
              <span class="badge badge-error">Inactive</span>
            <% end %>
          </div>
        </div>
      </div>

      <%= if @new_secret do %>
        <div class="alert alert-warning mb-6">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="stroke-current shrink-0 h-6 w-6"
            fill="none"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
            />
          </svg>
          <div class="w-full">
            <h3 class="font-bold">New Client Secret Generated!</h3>
            <div class="text-sm mt-2">
              Please save this secret securely. You won't be able to see it again.
            </div>
            <div class="mt-3 p-3 bg-base-300 rounded font-mono text-sm break-all">
              {@new_secret}
            </div>
          </div>
        </div>
      <% end %>
      
    <!-- Stats Cards -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-8">
        <div class="stat bg-base-100 shadow rounded-lg">
          <div class="stat-title">Total Tokens</div>
          <div class="stat-value text-primary">{@token_stats.total}</div>
        </div>
        <div class="stat bg-base-100 shadow rounded-lg">
          <div class="stat-title">Active Tokens</div>
          <div class="stat-value text-success">{@token_stats.active}</div>
        </div>
        <div class="stat bg-base-100 shadow rounded-lg">
          <div class="stat-title">Revoked</div>
          <div class="stat-value text-error">{@token_stats.revoked}</div>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <!-- Client Information -->
        <div class="card bg-base-100 shadow">
          <div class="card-body">
            <h2 class="card-title">Agent Information</h2>

            <div class="space-y-4">
              <div>
                <label class="text-xs text-base-content/70 uppercase">Client Type</label>
                <p class="font-medium">{@client.client_type}</p>
              </div>

              <%= if @client.description do %>
                <div>
                  <label class="text-xs text-base-content/70 uppercase">Description</label>
                  <p class="font-medium">{@client.description}</p>
                </div>
              <% end %>

              <div>
                <label class="text-xs text-base-content/70 uppercase">Created</label>
                <p class="font-medium">{Calendar.strftime(@client.inserted_at, "%Y-%m-%d %H:%M")}</p>
              </div>

              <div>
                <label class="text-xs text-base-content/70 uppercase">Client Secret</label>
                <div class="flex gap-2 items-center">
                  <%= if @show_secret do %>
                    <code class="font-mono text-sm bg-base-200 p-2 rounded flex-1 break-all">
                      {String.slice(@client.client_secret || "", 0..20)}...
                    </code>
                  <% else %>
                    <code class="font-mono text-sm bg-base-200 p-2 rounded flex-1">
                      ••••••••••••••••••••
                    </code>
                  <% end %>
                  <button phx-click="toggle_secret" class="btn btn-sm btn-ghost">
                    {if @show_secret, do: "Hide", else: "Show"}
                  </button>
                </div>
              </div>

              <div class="divider"></div>

              <button
                phx-click="rotate_secret"
                class="btn btn-warning btn-sm w-full"
                data-confirm="Are you sure you want to rotate the client secret? The old secret will stop working immediately."
              >
                <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
                  />
                </svg>
                Rotate Client Secret
              </button>
            </div>
          </div>
        </div>
        
    <!-- OAuth2 Configuration -->
        <div class="card bg-base-100 shadow">
          <div class="card-body">
            <h2 class="card-title">Identity & OAuth2 Scopes</h2>

            <div class="space-y-4">
              <div>
                <label class="text-xs text-base-content/70 uppercase">Grant Types</label>
                <div class="flex flex-wrap gap-2 mt-1">
                  <%= for grant <- @client.allowed_grant_types || [] do %>
                    <span class="badge badge-primary">{grant}</span>
                  <% end %>
                  <%= if @client.allowed_grant_types == [] do %>
                    <span class="text-base-content/50">None configured</span>
                  <% end %>
                </div>
              </div>

              <div>
                <label class="text-xs text-base-content/70 uppercase">Allowed Scopes</label>
                <div class="flex flex-wrap gap-2 mt-1">
                  <%= for scope <- @client.allowed_scopes || [] do %>
                    <span class="badge badge-sm">{scope}</span>
                  <% end %>
                  <%= if @client.allowed_scopes == [] do %>
                    <span class="text-base-content/50">None configured</span>
                  <% end %>
                </div>
              </div>

              <div>
                <label class="text-xs text-base-content/70 uppercase">Redirect URIs</label>
                <%= if @client.redirect_uris && @client.redirect_uris != [] do %>
                  <div class="mt-1 space-y-1">
                    <%= for uri <- @client.redirect_uris do %>
                      <code class="block text-xs bg-base-200 p-2 rounded break-all">{uri}</code>
                    <% end %>
                  </div>
                <% else %>
                  <p class="text-base-content/50">None configured</p>
                <% end %>
              </div>

              <div>
                <label class="text-xs text-base-content/70 uppercase">PKCE Required</label>
                <p class="font-medium">
                  {if @client.pkce_required, do: "Yes", else: "No"}
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
      
    <!-- Recent Tokens -->
      <div class="card bg-base-100 shadow mt-6">
        <div class="card-body">
          <h2 class="card-title">Recent Tokens</h2>

          <%= if @recent_tokens == [] do %>
            <p class="text-center text-base-content/70 py-8">No tokens issued yet</p>
          <% else %>
            <div class="overflow-x-auto">
              <table class="table table-sm">
                <thead>
                  <tr>
                    <th>Type</th>
                    <th>User</th>
                    <th>Scopes</th>
                    <th>Created</th>
                    <th>Expires</th>
                    <th>Status</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for token <- @recent_tokens do %>
                    <tr>
                      <td>
                        <span class="badge badge-sm">{token.type}</span>
                      </td>
                      <td class="font-mono text-xs">
                        <%= if token.user_id do %>
                          {String.slice(token.user_id, 0..10)}...
                        <% else %>
                          <span class="text-base-content/50">M2M</span>
                        <% end %>
                      </td>
                      <td class="text-xs">
                        {Enum.join(Enum.take(token.scopes || [], 2), ", ")}{if length(
                                                                                 token.scopes || []
                                                                               ) > 2,
                                                                               do: "..."}
                      </td>
                      <td class="text-xs text-base-content/70">
                        {Calendar.strftime(token.inserted_at, "%Y-%m-%d %H:%M")}
                      </td>
                      <td class="text-xs text-base-content/70">
                        {Calendar.strftime(token.expires_at, "%Y-%m-%d %H:%M")}
                      </td>
                      <td>
                        <%= if token.revoked do %>
                          <span class="badge badge-sm badge-error">Revoked</span>
                        <% else %>
                          <%= if DateTime.compare(token.expires_at, DateTime.utc_now()) == :gt do %>
                            <span class="badge badge-sm badge-success">Active</span>
                          <% else %>
                            <span class="badge badge-sm badge-warning">Expired</span>
                          <% end %>
                        <% end %>
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
    """
  end
end
