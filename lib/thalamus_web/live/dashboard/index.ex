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
    socket
    |> assign(:total_users, count_users())
    |> assign(:total_clients, count_clients())
    |> assign(:active_tokens, count_active_tokens())
    |> assign(:active_agent_tokens, count_active_agent_tokens())
    |> assign(:total_organizations, count_organizations())
    |> assign(:recent_activity, load_recent_activity())
  end

  defp count_users do
    case PostgreSQLUserRepository.count() do
      {:ok, count} -> count
      _ -> 0
    end
  end

  defp count_clients do
    Repo.aggregate(OAuth2ClientSchema, :count, :id)
  end

  defp count_organizations do
    case PostgreSQLOrganizationRepository.count() do
      {:ok, count} -> count
      _ -> 0
    end
  end

  defp count_active_tokens do
    now = DateTime.utc_now()

    TokenSchema
    |> where([t], t.revoked == false)
    |> where([t], t.expires_at > ^now)
    |> Repo.aggregate(:count, :id)
  end

  defp count_active_agent_tokens do
    now = DateTime.utc_now()

    TokenSchema
    |> where([t], t.revoked == false)
    |> where([t], t.expires_at > ^now)
    |> where([t], not is_nil(t.agent_type))
    |> Repo.aggregate(:count, :id)
  end

  defp load_recent_activity do
    # Get last 10 tokens created with user and client information
    TokenSchema
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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8 py-8 space-y-8">
      <%!-- Header --%>
      <div class="sm:flex sm:items-center justify-between border-b border-white/5 pb-6">
        <div class="sm:flex-auto">
          <h1
            class="text-2xl font-bold tracking-tight text-white"
            style="font-family: 'Google Sans', sans-serif;"
          >
            Dashboard
          </h1>
          <p class="mt-2 text-xs text-base-content/50">
            Overview of your active AI agents, multi-agent clients, security audits, and developer metrics.
          </p>
        </div>
      </div>
      
    <!-- Stats Grid -->
      <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-5">
        <!-- Total Users -->
        <div class="bg-base-100/35 backdrop-blur border border-white/5 rounded-2xl p-6 relative overflow-hidden group hover:border-white/10 transition-all duration-200">
          <div class="absolute inset-x-0 top-0 h-[1px] bg-gradient-to-r from-transparent via-primary/20 to-transparent">
          </div>
          <div class="flex items-center justify-between">
            <div>
              <p class="text-[11px] font-mono font-medium text-base-content/50 uppercase tracking-wider">
                Total Users
              </p>
              <h3 class="text-2xl font-bold text-white mt-1.5">{number_format(@total_users)}</h3>
            </div>
            <div class="p-3 bg-primary/10 text-primary border border-primary/10 rounded-xl">
              <svg
                class="h-5 w-5"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M15 19.128a9.38 9.38 0 0 0 2.625.372 9.337 9.337 0 0 0 4.121-.952 4.125 4.125 0 0 0-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.109A11.386 11.386 0 0 1 10.089 20c-2.302 0-4.462-.684-6.273-1.858v-.01a4.125 4.125 0 0 1 7.533-2.493M15 9.048a3.5 3.5 0 1 1-3.5 3.5m3.5-3.5a3.5 3.5 0 0 1-3.5-3.5m0 7a3.5 3.5 0 0 1-3.5-3.5m3.5 3.5v3.5m0-3.5H10"
                />
              </svg>
            </div>
          </div>
        </div>
        
    <!-- Multi-Agent Clients -->
        <div class="bg-base-100/35 backdrop-blur border border-white/5 rounded-2xl p-6 relative overflow-hidden group hover:border-white/10 transition-all duration-200">
          <div class="absolute inset-x-0 top-0 h-[1px] bg-gradient-to-r from-transparent via-primary/20 to-transparent">
          </div>
          <div class="flex items-center justify-between">
            <div>
              <p class="text-[11px] font-mono font-medium text-base-content/50 uppercase tracking-wider">
                Multi-Agent Clients
              </p>
              <h3 class="text-2xl font-bold text-white mt-1.5">{number_format(@total_clients)}</h3>
            </div>
            <div class="p-3 bg-primary/10 text-primary border border-primary/10 rounded-xl">
              <svg
                class="h-5 w-5"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                />
              </svg>
            </div>
          </div>
        </div>
        
    <!-- Active Tokens -->
        <div class="bg-base-100/35 backdrop-blur border border-white/5 rounded-2xl p-6 relative overflow-hidden group hover:border-white/10 transition-all duration-200">
          <div class="absolute inset-x-0 top-0 h-[1px] bg-gradient-to-r from-transparent via-primary/20 to-transparent">
          </div>
          <div class="flex items-center justify-between">
            <div>
              <p class="text-[11px] font-mono font-medium text-base-content/50 uppercase tracking-wider">
                Active Tokens
              </p>
              <h3 class="text-2xl font-bold text-white mt-1.5">{number_format(@active_tokens)}</h3>
            </div>
            <div class="p-3 bg-primary/10 text-primary border border-primary/10 rounded-xl">
              <svg
                class="h-5 w-5"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M15.75 5.25a3 3 0 0 1 3 3m3 0a6 6 0 0 1-7.029 5.912c-.563-.097-1.159.026-1.563.43L10.5 17.25H8.25v2.25H6v2.25H2.25v-2.818c0-.597.237-1.17.659-1.591l6.499-6.499c.404-.404.527-1 .43-1.563A6 6 0 1 1 21.75 8.25Z"
                />
              </svg>
            </div>
          </div>
        </div>
        
    <!-- Organizations -->
        <div class="bg-base-100/35 backdrop-blur border border-white/5 rounded-2xl p-6 relative overflow-hidden group hover:border-white/10 transition-all duration-200">
          <div class="absolute inset-x-0 top-0 h-[1px] bg-gradient-to-r from-transparent via-primary/20 to-transparent">
          </div>
          <div class="flex items-center justify-between">
            <div>
              <p class="text-[11px] font-mono font-medium text-base-content/50 uppercase tracking-wider">
                Organizations
              </p>
              <h3 class="text-2xl font-bold text-white mt-1.5">
                {number_format(@total_organizations)}
              </h3>
            </div>
            <div class="p-3 bg-primary/10 text-primary border border-primary/10 rounded-xl">
              <svg
                class="h-5 w-5"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"
                />
              </svg>
            </div>
          </div>
        </div>
        
    <!-- Active AI Agents -->
        <div class="bg-base-100/35 backdrop-blur border border-primary/20 rounded-2xl p-6 relative overflow-hidden group hover:border-primary/30 transition-all duration-200 shadow-lg shadow-primary/5">
          <div class="absolute inset-x-0 top-0 h-[1px] bg-gradient-to-r from-transparent via-primary/45 to-transparent">
          </div>
          <div class="flex items-center justify-between">
            <div>
              <p class="text-[11px] font-mono font-medium text-primary uppercase tracking-wider">
                Active AI Agents
              </p>
              <h3 class="text-2xl font-bold text-white mt-1.5">
                {number_format(@active_agent_tokens)}
              </h3>
            </div>
            <div class="p-3 bg-primary/20 text-primary border border-primary/20 rounded-xl">
              🤖
            </div>
          </div>
        </div>
      </div>
      
    <!-- Quick Actions -->
      <div>
        <h2
          class="text-sm font-semibold text-white/80 uppercase tracking-wider mb-4"
          style="font-family: 'Google Sans', sans-serif;"
        >
          Quick Actions
        </h2>
        <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3">
          <.link
            navigate="/dashboard/users"
            class="bg-base-100/35 backdrop-blur border border-white/5 rounded-2xl p-5 relative overflow-hidden group hover:border-white/10 hover:bg-white/[0.02] transition-all duration-200 cursor-pointer flex items-center justify-between"
          >
            <div class="flex items-center gap-4">
              <div class="p-2.5 bg-primary/10 text-primary border border-primary/10 rounded-xl">
                <svg
                  class="h-5 w-5"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M19 7.5v3m0 0v3m0-3h3m-3 0h-3m-2.25-4.125a3.375 3.375 0 1 1-6.75 0 3.375 3.375 0 0 1 6.75 0zM4 19.235v-.11a6.375 6.375 0 0 1 12.75 0v.109A12.318 12.318 0 0 1 10.374 21c-2.331 0-4.512-.647-6.374-1.765z"
                  />
                </svg>
              </div>
              <div>
                <h3 class="text-sm font-semibold text-white">Invite User</h3>
                <p class="text-[10px] text-base-content/40 mt-0.5">
                  Add developers or collaborators to your organization.
                </p>
              </div>
            </div>
            <svg
              class="h-4 w-4 text-base-content/30 group-hover:text-white group-hover:translate-x-1 transition-all duration-200"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5" />
            </svg>
          </.link>

          <.link
            navigate="/dashboard/clients"
            class="bg-base-100/35 backdrop-blur border border-white/5 rounded-2xl p-5 relative overflow-hidden group hover:border-white/10 hover:bg-white/[0.02] transition-all duration-200 cursor-pointer flex items-center justify-between"
          >
            <div class="flex items-center gap-4">
              <div class="p-2.5 bg-primary/10 text-primary border border-primary/10 rounded-xl">
                <svg
                  class="h-5 w-5"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  viewBox="0 0 24 24"
                >
                  <path stroke-linecap="round" stroke-linejoin="round" d="M12 4v16m8-8H4" />
                </svg>
              </div>
              <div>
                <h3 class="text-sm font-semibold text-white">Register Glia Agent</h3>
                <p class="text-[10px] text-base-content/40 mt-0.5">
                  Provision credentials and register an autonomous agent.
                </p>
              </div>
            </div>
            <svg
              class="h-4 w-4 text-base-content/30 group-hover:text-white group-hover:translate-x-1 transition-all duration-200"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5" />
            </svg>
          </.link>

          <.link
            navigate="/dashboard/audit-logs"
            class="bg-base-100/35 backdrop-blur border border-white/5 rounded-2xl p-5 relative overflow-hidden group hover:border-white/10 hover:bg-white/[0.02] transition-all duration-200 cursor-pointer flex items-center justify-between"
          >
            <div class="flex items-center gap-4">
              <div class="p-2.5 bg-primary/10 text-primary border border-primary/10 rounded-xl">
                <svg
                  class="h-5 w-5"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                  />
                </svg>
              </div>
              <div>
                <h3 class="text-sm font-semibold text-white">View Security Audit</h3>
                <p class="text-[10px] text-base-content/40 mt-0.5">
                  Check access logs, token states, and security events.
                </p>
              </div>
            </div>
            <svg
              class="h-4 w-4 text-base-content/30 group-hover:text-white group-hover:translate-x-1 transition-all duration-200"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5" />
            </svg>
          </.link>
        </div>
      </div>
      
    <!-- Recent Activity -->
      <div>
        <h2
          class="text-sm font-semibold text-white/80 uppercase tracking-wider mb-4"
          style="font-family: 'Google Sans', sans-serif;"
        >
          Recent Agent & API Activity
        </h2>
        <div class="bg-base-100/35 backdrop-blur border border-white/5 rounded-2xl overflow-hidden">
          <%= if @recent_activity == [] do %>
            <div class="p-12 text-center">
              <p class="text-xs text-base-content/40 font-mono">
                No recent activity detected on the network
              </p>
            </div>
          <% else %>
            <div class="overflow-x-auto">
              <table class="w-full text-left border-collapse">
                <thead>
                  <tr class="border-b border-white/5 bg-white/[0.01]">
                    <th class="px-6 py-4 text-[10px] font-semibold text-base-content/50 uppercase tracking-wider">
                      Type
                    </th>
                    <th class="px-6 py-4 text-[10px] font-semibold text-base-content/50 uppercase tracking-wider">
                      Agent
                    </th>
                    <th class="px-6 py-4 text-[10px] font-semibold text-base-content/50 uppercase tracking-wider">
                      Client ID
                    </th>
                    <th class="px-6 py-4 text-[10px] font-semibold text-base-content/50 uppercase tracking-wider">
                      Scopes
                    </th>
                    <th class="px-6 py-4 text-[10px] font-semibold text-base-content/50 uppercase tracking-wider">
                      Created
                    </th>
                    <th class="px-6 py-4 text-[10px] font-semibold text-base-content/50 uppercase tracking-wider">
                      Status
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-white/5">
                  <%= for activity <- @recent_activity do %>
                    <tr class="hover:bg-white/[0.01] transition-colors">
                      <td class="px-6 py-4">
                        <span class={[
                          "px-2 py-1 rounded-lg text-[10px] font-mono font-medium border",
                          if(activity.type == "access_token",
                            do: "bg-primary/10 text-primary border-primary/20",
                            else: "bg-purple-500/10 text-purple-400 border-purple-500/20"
                          )
                        ]}>
                          {activity.type}
                        </span>
                      </td>
                      <td class="px-6 py-4">
                        <%= if activity.agent_type do %>
                          <%= case activity.agent_type do %>
                            <% "autonomous" -> %>
                              <span class="px-2 py-0.5 rounded bg-accent/10 text-accent border border-accent/20 text-[10px] font-semibold uppercase tracking-wider">
                                🤖 Autonomous
                              </span>
                            <% "supervised" -> %>
                              <span class="px-2 py-0.5 rounded bg-info/10 text-info border border-info/20 text-[10px] font-semibold uppercase tracking-wider">
                                👁️ Supervised
                              </span>
                            <% "ephemeral" -> %>
                              <span class="px-2 py-0.5 rounded bg-warning/10 text-warning border border-warning/20 text-[10px] font-semibold uppercase tracking-wider">
                                ⚡ Ephemeral
                              </span>
                            <% _ -> %>
                              <span class="text-base-content/30 text-xs font-mono">—</span>
                          <% end %>
                        <% else %>
                          <span class="text-base-content/30 text-xs font-mono">—</span>
                        <% end %>
                      </td>
                      <td class="px-6 py-4 font-mono text-xs text-white/80">
                        {String.slice(activity.client_id || "N/A", 0..15)}...
                      </td>
                      <td class="px-6 py-4 text-xs text-base-content/70">
                        <%= if activity.scopes == [] do %>
                          <span class="text-base-content/30 italic">none</span>
                        <% else %>
                          <div class="flex flex-wrap gap-1">
                            <%= for scope <- Enum.take(activity.scopes, 3) do %>
                              <span class="px-1.5 py-0.5 bg-base-300/60 rounded border border-white/5 font-mono text-[9px]">
                                {scope}
                              </span>
                            <% end %>
                            <%= if length(activity.scopes) > 3 do %>
                              <span class="text-[9px] text-base-content/40 font-mono">
                                +{length(activity.scopes) - 3} more
                              </span>
                            <% end %>
                          </div>
                        <% end %>
                      </td>
                      <td class="px-6 py-4 text-xs text-base-content/60">
                        {format_relative_time(activity.created_at)}
                      </td>
                      <td class="px-6 py-4">
                        <%= if activity.revoked do %>
                          <span class="px-2 py-0.5 rounded bg-red-500/10 text-red-400 border border-red-500/20 text-[9px] font-semibold uppercase tracking-wider">
                            Revoked
                          </span>
                        <% else %>
                          <%= if DateTime.compare(activity.expires_at, DateTime.utc_now()) == :gt do %>
                            <span class="px-2 py-0.5 rounded bg-green-500/10 text-green-400 border border-green-500/20 text-[9px] font-semibold uppercase tracking-wider">
                              Active
                            </span>
                          <% else %>
                            <span class="px-2 py-0.5 rounded bg-yellow-500/10 text-yellow-400 border border-yellow-500/20 text-[9px] font-semibold uppercase tracking-wider">
                              Expired
                            </span>
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
