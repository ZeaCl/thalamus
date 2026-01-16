defmodule ThalamusWeb.Dashboard.Index do
  @moduledoc """
  Dashboard LiveView - Main overview page for Thalamus OAuth2 Server
  """
  use ThalamusWeb, :live_view

  # Load authenticated user on mount
  on_mount ThalamusWeb.Live.Hooks.LiveAuth

  import Ecto.Query

  alias Thalamus.Repo

  alias Thalamus.Infrastructure.Repositories.{
    PostgreSQLUserRepository,
    PostgreSQLOrganizationRepository
  }

  alias Thalamus.Infrastructure.Persistence.Schemas.{
    OAuth2ClientSchema,
    TokenSchema
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> assign(:current_path, "/dashboard")
     |> load_stats()}
  end

  defp load_stats(socket) do
    # Get current user's organization ID for filtering
    org_id = get_organization_id(socket)

    socket
    |> assign(:total_users, count_users(org_id))
    |> assign(:total_clients, count_clients(org_id))
    |> assign(:active_tokens, count_active_tokens(org_id))
    |> assign(:active_agent_tokens, count_active_agent_tokens(org_id))
    |> assign(:total_organizations, count_organizations())
    |> assign(:recent_activity, load_recent_activity(org_id))
  end

  defp get_organization_id(socket) do
    case socket.assigns[:current_organization] do
      %{id: org_id} -> org_id
      _ -> nil
    end
  end

  defp count_users(nil), do: 0

  defp count_users(org_id) do
    # Filter users by organization_id
    org_uuid = extract_uuid(org_id)

    case PostgreSQLUserRepository.count(%{organization_id: org_uuid}) do
      {:ok, count} -> count
      _ -> 0
    end
  end

  defp count_clients(nil), do: 0

  defp count_clients(org_id) do
    # Filter OAuth2 clients by organization_id
    org_uuid = extract_uuid(org_id)

    OAuth2ClientSchema
    |> where([c], c.organization_id == ^org_uuid)
    |> Repo.aggregate(:count, :id)
  end

  defp count_organizations do
    case PostgreSQLOrganizationRepository.count() do
      {:ok, count} -> count
      _ -> 0
    end
  end

  defp count_active_tokens(nil), do: 0

  defp count_active_tokens(org_id) do
    now = DateTime.utc_now()
    org_uuid = extract_uuid(org_id)

    TokenSchema
    |> where([t], t.revoked == false)
    |> where([t], t.expires_at > ^now)
    |> where([t], t.organization_id == ^org_uuid)
    |> Repo.aggregate(:count, :id)
  end

  defp count_active_agent_tokens(nil), do: 0

  defp count_active_agent_tokens(org_id) do
    now = DateTime.utc_now()
    org_uuid = extract_uuid(org_id)

    TokenSchema
    |> where([t], t.revoked == false)
    |> where([t], t.expires_at > ^now)
    |> where([t], not is_nil(t.agent_type))
    |> where([t], t.organization_id == ^org_uuid)
    |> Repo.aggregate(:count, :id)
  end

  defp load_recent_activity(nil), do: []

  defp load_recent_activity(org_id) do
    # Get last 10 tokens created with user and client information
    # Filtered by organization_id
    org_uuid = extract_uuid(org_id)

    TokenSchema
    |> where([t], t.organization_id == ^org_uuid)
    |> order_by([t], desc: t.inserted_at)
    |> limit(10)
    |> Repo.all()
    |> Enum.map(fn token ->
      %{
        id: token.id,
        type: token.type,
        agent_type: token.agent_type,
        client_id: token.client_id,
        user_id: token.user_id,
        scopes: token.scopes || [],
        created_at: token.inserted_at,
        expires_at: token.expires_at,
        revoked: token.revoked
      }
    end)
  end

  # Helper to extract UUID from OrganizationId value object
  defp extract_uuid(%{value: value}) when is_binary(value) do
    String.replace_prefix(value, "org_", "")
  end

  defp extract_uuid(value) when is_binary(value) do
    String.replace_prefix(value, "org_", "")
  end

  defp extract_uuid(_), do: nil

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8 py-8">
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="text-2xl font-semibold text-base-content">OAuth2 Server Dashboard</h1>
          <p class="mt-2 text-sm text-base-content/70">
            Overview of your OAuth2 authentication server
          </p>
        </div>
      </div>
      
    <!-- Stats Grid -->
      <div class="mt-8 grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-5">
        <!-- Total Users -->
        <div class="card bg-base-100 shadow">
          <div class="card-body">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <svg
                  class="h-8 w-8 text-blue-500"
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
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-base-content/70 truncate">Total Users</dt>
                  <dd class="flex items-baseline">
                    <div class="text-2xl font-semibold text-base-content">
                      {number_format(@total_users)}
                    </div>
                  </dd>
                </dl>
              </div>
            </div>
          </div>
        </div>
        
    <!-- Total Clients -->
        <div class="card bg-base-100 shadow">
          <div class="card-body">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <svg
                  class="h-8 w-8 text-indigo-500"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                  />
                </svg>
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-base-content/70 truncate">OAuth2 Clients</dt>
                  <dd class="flex items-baseline">
                    <div class="text-2xl font-semibold text-base-content">
                      {number_format(@total_clients)}
                    </div>
                  </dd>
                </dl>
              </div>
            </div>
          </div>
        </div>
        
    <!-- Active Tokens -->
        <div class="card bg-base-100 shadow">
          <div class="card-body">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <svg
                  class="h-8 w-8 text-green-500"
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
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-base-content/70 truncate">Active Tokens</dt>
                  <dd class="flex items-baseline">
                    <div class="text-2xl font-semibold text-base-content">
                      {number_format(@active_tokens)}
                    </div>
                  </dd>
                </dl>
              </div>
            </div>
          </div>
        </div>
        
    <!-- Total Organizations -->
        <div class="card bg-base-100 shadow">
          <div class="card-body">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <svg
                  class="h-8 w-8 text-orange-500"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"
                  />
                </svg>
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-base-content/70 truncate">Organizations</dt>
                  <dd class="flex items-baseline">
                    <div class="text-2xl font-semibold text-base-content">
                      {number_format(@total_organizations)}
                    </div>
                  </dd>
                </dl>
              </div>
            </div>
          </div>
        </div>
        
    <!-- Active Agent Tokens -->
        <div class="card bg-base-100 shadow border-2 border-accent">
          <div class="card-body">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <div class="h-8 w-8 text-accent text-2xl flex items-center justify-center">
                  🤖
                </div>
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-base-content/70 truncate">Agent Tokens</dt>
                  <dd class="flex items-baseline">
                    <div class="text-2xl font-semibold text-accent">
                      {number_format(@active_agent_tokens)}
                    </div>
                  </dd>
                  <dd class="text-xs text-base-content/50 mt-1">
                    Active AI agents
                  </dd>
                </dl>
              </div>
            </div>
          </div>
        </div>
      </div>
      
    <!-- Quick Actions -->
      <div class="mt-8">
        <h2 class="text-lg font-medium text-base-content mb-4">Quick Actions</h2>
        <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <.link
            navigate="/dashboard/users"
            class="card bg-base-100 shadow hover:shadow-lg transition-shadow cursor-pointer"
          >
            <div class="card-body">
              <div class="flex items-center">
                <svg
                  class="h-6 w-6 text-blue-500"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M18 9v3m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-8 0 4 4 0 018 0zM3 20a6 6 0 0112 0v1H3v-1z"
                  />
                </svg>
                <h3 class="ml-3 text-sm font-medium text-base-content">Create New User</h3>
              </div>
            </div>
          </.link>

          <.link
            navigate="/dashboard/clients"
            class="card bg-base-100 shadow hover:shadow-lg transition-shadow cursor-pointer"
          >
            <div class="card-body">
              <div class="flex items-center">
                <svg
                  class="h-6 w-6 text-indigo-500"
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
                <h3 class="ml-3 text-sm font-medium text-base-content">Register OAuth2 Client</h3>
              </div>
            </div>
          </.link>

          <.link
            navigate="/dashboard/audit-logs"
            class="card bg-base-100 shadow hover:shadow-lg transition-shadow cursor-pointer"
          >
            <div class="card-body">
              <div class="flex items-center">
                <svg
                  class="h-6 w-6 text-emerald-500"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                  />
                </svg>
                <h3 class="ml-3 text-sm font-medium text-base-content">View Audit Logs</h3>
              </div>
            </div>
          </.link>
        </div>
      </div>
      
    <!-- Recent Activity -->
      <div class="mt-8">
        <h2 class="text-lg font-medium text-base-content mb-4">Recent Token Activity</h2>
        <div class="card bg-base-100 shadow">
          <div class="card-body">
            <%= if @recent_activity == [] do %>
              <p class="text-sm text-base-content/70 text-center py-8">
                No recent activity to display
              </p>
            <% else %>
              <div class="overflow-x-auto">
                <table class="table table-sm">
                  <thead>
                    <tr>
                      <th>Type</th>
                      <th>Agent</th>
                      <th>Client</th>
                      <th>User</th>
                      <th>Scopes</th>
                      <th>Created</th>
                      <th>Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for activity <- @recent_activity do %>
                      <tr>
                        <td>
                          <span class={[
                            "badge badge-sm",
                            if(activity.type == "access_token",
                              do: "badge-primary",
                              else: "badge-secondary"
                            )
                          ]}>
                            {activity.type}
                          </span>
                        </td>
                        <td>
                          <%= if activity.agent_type do %>
                            <%= case activity.agent_type do %>
                              <% "autonomous" -> %>
                                <span class="badge badge-accent badge-sm">🤖</span>
                              <% "supervised" -> %>
                                <span class="badge badge-info badge-sm">👁️</span>
                              <% "ephemeral" -> %>
                                <span class="badge badge-warning badge-sm">⚡</span>
                              <% _ -> %>
                                <span class="text-base-content/50 text-xs">—</span>
                            <% end %>
                          <% else %>
                            <span class="text-base-content/50 text-xs">—</span>
                          <% end %>
                        </td>
                        <td class="font-mono text-xs">
                          {String.slice(activity.client_id || "N/A", 0..15)}...
                        </td>
                        <td class="font-mono text-xs">
                          <%= if activity.user_id do %>
                            {String.slice(activity.user_id, 0..10)}...
                          <% else %>
                            <span class="text-base-content/50">Client Credentials</span>
                          <% end %>
                        </td>
                        <td class="text-xs">
                          <%= if activity.scopes == [] do %>
                            <span class="text-base-content/50">none</span>
                          <% else %>
                            {Enum.join(Enum.take(activity.scopes, 2), ", ")}{if length(
                                                                                  activity.scopes
                                                                                ) > 2,
                                                                                do: "..."}
                          <% end %>
                        </td>
                        <td class="text-xs text-base-content/70">
                          {format_relative_time(activity.created_at)}
                        </td>
                        <td>
                          <%= if activity.revoked do %>
                            <span class="badge badge-sm badge-error">Revoked</span>
                          <% else %>
                            <%= if DateTime.compare(activity.expires_at, DateTime.utc_now()) == :gt do %>
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
    </div>
    """
  end

  defp number_format(number) when is_integer(number) do
    Integer.to_string(number)
  end

  defp number_format(_number), do: "0"

  defp format_relative_time(datetime) do
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, datetime, :second)

    cond do
      diff_seconds < 60 ->
        "#{diff_seconds}s ago"

      diff_seconds < 3600 ->
        minutes = div(diff_seconds, 60)
        "#{minutes}m ago"

      diff_seconds < 86400 ->
        hours = div(diff_seconds, 3600)
        "#{hours}h ago"

      diff_seconds < 2_592_000 ->
        days = div(diff_seconds, 86400)
        "#{days}d ago"

      true ->
        Calendar.strftime(datetime, "%Y-%m-%d")
    end
  end
end
