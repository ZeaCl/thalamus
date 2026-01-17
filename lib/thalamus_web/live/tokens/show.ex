defmodule ThalamusWeb.Tokens.Show do
  @moduledoc """
  LiveView for displaying token details.
  """
  use ThalamusWeb, :live_view

  # Load authenticated user on mount
  on_mount ThalamusWeb.Live.Hooks.LiveAuth

  alias Thalamus.Infrastructure.Persistence.Schemas.TokenSchema
  alias Thalamus.Repo

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Repo.get(TokenSchema, id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Token not found")
         |> push_navigate(to: ~p"/dashboard/tokens")}

      token ->
        token = Repo.preload(token, [:user, :client, :organization])

        {:ok,
         socket
         |> assign(:current_path, "/dashboard/tokens")
         |> assign(:token, token)}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply,
     socket
     |> assign(:page_title, "Token Details")}
  end

  @impl true
  def handle_event("revoke", _params, socket) do
    token = socket.assigns.token

    if token.revoked do
      {:noreply, put_flash(socket, :error, "Token is already revoked")}
    else
      changeset = TokenSchema.revoke_changeset(token)

      case Repo.update(changeset) do
        {:ok, updated_token} ->
          {:noreply,
           socket
           |> assign(
             :token,
             Repo.preload(updated_token, [:user, :client, :organization], force: true)
           )
           |> put_flash(:info, "Token revoked successfully")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to revoke token")}
      end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8 py-8">
      <.breadcrumbs items={[
        %{label: "Dashboard", path: "/dashboard"},
        %{label: "Access Tokens", path: "/dashboard/tokens"},
        %{label: "Token Details", path: nil}
      ]} />
      
    <!-- Header -->
      <div class="mb-8">
        <.link
          navigate={~p"/dashboard/tokens"}
          class="text-sm text-base-content/70 hover:text-base-content flex items-center gap-2 mb-4"
        >
          <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
          </svg>
          Back to Tokens
        </.link>
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-semibold text-base-content">Token Details</h1>
            <p class="mt-1 text-sm text-base-content/70">
              {type_label(@token.type)} · {status_label(@token)}
            </p>
          </div>
          <div class="flex gap-3">
            <%= if !@token.revoked && !is_expired?(@token) do %>
              <button
                phx-click="revoke"
                data-confirm="Are you sure you want to revoke this token? This action cannot be undone."
                class="btn btn-error btn-sm"
              >
                Revoke Token
              </button>
            <% end %>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <!-- Token Information -->
        <div class="card bg-base-100 shadow">
          <div class="card-body">
            <h3 class="card-title text-lg">Token Information</h3>

            <div class="space-y-4 mt-4">
              <div>
                <dt class="text-sm font-medium text-base-content/70">Token Value</dt>
                <dd class="mt-1 text-sm text-base-content font-mono break-all">
                  {@token.token}
                </dd>
              </div>

              <div>
                <dt class="text-sm font-medium text-base-content/70">Type</dt>
                <dd class="mt-1 text-sm text-base-content">
                  {type_badge(@token.type)}
                </dd>
              </div>

              <div>
                <dt class="text-sm font-medium text-base-content/70">Status</dt>
                <dd class="mt-1 text-sm text-base-content">
                  {status_badge(@token)}
                </dd>
              </div>

              <div>
                <dt class="text-sm font-medium text-base-content/70">Scopes</dt>
                <dd class="mt-1 text-sm text-base-content">
                  <%= if Enum.empty?(@token.scopes) do %>
                    <span class="text-base-content/50">No scopes</span>
                  <% else %>
                    <div class="flex flex-wrap gap-2">
                      <%= for scope <- @token.scopes do %>
                        <span class="badge badge-outline badge-sm">{scope}</span>
                      <% end %>
                    </div>
                  <% end %>
                </dd>
              </div>

              <div>
                <dt class="text-sm font-medium text-base-content/70">Created At</dt>
                <dd class="mt-1 text-sm text-base-content">
                  {format_datetime(@token.inserted_at)}
                </dd>
              </div>

              <div>
                <dt class="text-sm font-medium text-base-content/70">Expires At</dt>
                <dd class="mt-1 text-sm text-base-content">
                  {format_datetime(@token.expires_at)}
                  <%= if is_expired?(@token) do %>
                    <span class="text-error text-xs ml-2">(Expired)</span>
                  <% else %>
                    <span class="text-success text-xs ml-2">
                      (Valid for {time_until_expiry(@token)})
                    </span>
                  <% end %>
                </dd>
              </div>

              <%= if @token.revoked do %>
                <div>
                  <dt class="text-sm font-medium text-base-content/70">Revoked At</dt>
                  <dd class="mt-1 text-sm text-base-content">
                    {format_datetime(@token.revoked_at)}
                  </dd>
                </div>
              <% end %>
            </div>
          </div>
        </div>
        
    <!-- Associated Entities -->
        <div class="space-y-6">
          <!-- User Information -->
          <div class="card bg-base-100 shadow">
            <div class="card-body">
              <h3 class="card-title text-lg">User</h3>

              <%= if @token.user do %>
                <div class="space-y-3 mt-4">
                  <div>
                    <dt class="text-sm font-medium text-base-content/70">Email</dt>
                    <dd class="mt-1 text-sm text-base-content">
                      <.link
                        navigate={~p"/dashboard/users/#{@token.user.id}"}
                        class="text-primary hover:underline"
                      >
                        {@token.user.email}
                      </.link>
                    </dd>
                  </div>

                  <%= if @token.user.name do %>
                    <div>
                      <dt class="text-sm font-medium text-base-content/70">Name</dt>
                      <dd class="mt-1 text-sm text-base-content">
                        {@token.user.name}
                      </dd>
                    </div>
                  <% end %>

                  <div>
                    <dt class="text-sm font-medium text-base-content/70">Status</dt>
                    <dd class="mt-1 text-sm text-base-content">
                      {user_status_badge(@token.user.status)}
                    </dd>
                  </div>
                </div>
              <% else %>
                <p class="text-sm text-base-content/50 mt-4">No associated user</p>
              <% end %>
            </div>
          </div>
          
    <!-- Client Information -->
          <div class="card bg-base-100 shadow">
            <div class="card-body">
              <h3 class="card-title text-lg">OAuth2 Client</h3>

              <%= if @token.client do %>
                <div class="space-y-3 mt-4">
                  <div>
                    <dt class="text-sm font-medium text-base-content/70">Client Name</dt>
                    <dd class="mt-1 text-sm text-base-content">
                      <.link
                        navigate={~p"/dashboard/clients/#{@token.client.id}"}
                        class="text-primary hover:underline"
                      >
                        {@token.client.name}
                      </.link>
                    </dd>
                  </div>

                  <div>
                    <dt class="text-sm font-medium text-base-content/70">Client ID</dt>
                    <dd class="mt-1 text-sm text-base-content font-mono text-xs">
                      {@token.client.client_id_string}
                    </dd>
                  </div>

                  <div>
                    <dt class="text-sm font-medium text-base-content/70">Client Type</dt>
                    <dd class="mt-1 text-sm text-base-content">
                      {client_type_badge(@token.client.client_type)}
                    </dd>
                  </div>
                </div>
              <% else %>
                <p class="text-sm text-base-content/50 mt-4">No associated client</p>
              <% end %>
            </div>
          </div>
          
    <!-- PKCE Information (for authorization codes) -->
          <%= if @token.type == :authorization_code && (@token.code_challenge || @token.code_challenge_method) do %>
            <div class="card bg-base-100 shadow">
              <div class="card-body">
                <h3 class="card-title text-lg">PKCE Details</h3>

                <div class="space-y-3 mt-4">
                  <%= if @token.code_challenge do %>
                    <div>
                      <dt class="text-sm font-medium text-base-content/70">Code Challenge</dt>
                      <dd class="mt-1 text-sm text-base-content font-mono break-all">
                        {@token.code_challenge}
                      </dd>
                    </div>
                  <% end %>

                  <%= if @token.code_challenge_method do %>
                    <div>
                      <dt class="text-sm font-medium text-base-content/70">Challenge Method</dt>
                      <dd class="mt-1 text-sm text-base-content">
                        <span class="badge badge-sm">{@token.code_challenge_method}</span>
                      </dd>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>
          
    <!-- Agent Token Information -->
          <%= if @token.agent_type do %>
            <div class="card bg-base-100 shadow border-2 border-accent">
              <div class="card-body">
                <h3 class="card-title text-lg flex items-center gap-2">
                  <span class="text-2xl">🤖</span> Agent Token Details
                </h3>

                <div class="space-y-4 mt-4">
                  <!-- Agent Type -->
                  <div>
                    <dt class="text-sm font-medium text-base-content/70">Agent Type</dt>
                    <dd class="mt-1">
                      {agent_type_badge(@token.agent_type)}
                    </dd>
                  </div>
                  
    <!-- Delegated By -->
                  <%= if @token.delegated_by_user_id do %>
                    <div>
                      <dt class="text-sm font-medium text-base-content/70">Delegated By</dt>
                      <dd class="mt-1 text-sm text-base-content">
                        <.link
                          navigate={~p"/dashboard/users/#{@token.delegated_by_user_id}"}
                          class="text-primary hover:underline font-medium"
                        >
                          {get_delegator_email(@token.delegated_by_user_id)}
                        </.link>
                        <p class="text-xs text-base-content/60 mt-1">
                          Human authorizer who granted this agent permission
                        </p>
                      </dd>
                    </div>
                  <% end %>
                  
    <!-- Task Information -->
                  <%= if @token.task_id do %>
                    <div class="divider text-xs text-base-content/50">Task Details</div>

                    <div>
                      <dt class="text-sm font-medium text-base-content/70">Task ID</dt>
                      <dd class="mt-1 text-sm text-base-content font-mono">
                        {@token.task_id}
                      </dd>
                    </div>
                  <% end %>

                  <%= if @token.task_type do %>
                    <div>
                      <dt class="text-sm font-medium text-base-content/70">Task Type</dt>
                      <dd class="mt-1 text-sm text-base-content">
                        <span class="badge badge-outline badge-sm">{@token.task_type}</span>
                      </dd>
                    </div>
                  <% end %>

                  <%= if @token.task_scopes && !Enum.empty?(@token.task_scopes) do %>
                    <div>
                      <dt class="text-sm font-medium text-base-content/70">Task Scopes</dt>
                      <dd class="mt-1">
                        <div class="flex flex-wrap gap-2">
                          <%= for scope <- @token.task_scopes do %>
                            <span class="badge badge-accent badge-sm">{scope}</span>
                          <% end %>
                        </div>
                        <p class="text-xs text-base-content/60 mt-1">
                          Restricted subset of client's allowed scopes
                        </p>
                      </dd>
                    </div>
                  <% end %>
                  
    <!-- Operations Limit -->
                  <%= if @token.max_operations do %>
                    <div class="divider text-xs text-base-content/50">Operations</div>

                    <div>
                      <dt class="text-sm font-medium text-base-content/70">Usage</dt>
                      <dd class="mt-2">
                        <div class="flex justify-between text-sm mb-1">
                          <span class="text-base-content">
                            {@token.operations_count || 0} / {@token.max_operations} operations
                          </span>
                          <span class="text-base-content/70">
                            {calculate_operations_percentage(@token)}%
                          </span>
                        </div>
                        <progress
                          class="progress progress-accent w-full"
                          value={@token.operations_count || 0}
                          max={@token.max_operations}
                        >
                        </progress>
                        <p class="text-xs text-base-content/60 mt-1">
                          {@token.max_operations - (@token.operations_count || 0)} operations remaining
                        </p>
                      </dd>
                    </div>

                    <%= if @token.expires_on_completion do %>
                      <div class="alert alert-warning">
                        <svg
                          xmlns="http://www.w3.org/2000/svg"
                          class="stroke-current shrink-0 h-5 w-5"
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
                        <span class="text-sm">Auto-revokes when max operations reached</span>
                      </div>
                    <% end %>
                  <% end %>
                  
    <!-- Compliance -->
                  <%= if @token.intent_description do %>
                    <div class="divider text-xs text-base-content/50">Compliance</div>

                    <div>
                      <dt class="text-sm font-medium text-base-content/70">Intent Description</dt>
                      <dd class="mt-1 text-sm text-base-content italic bg-base-200 p-3 rounded">
                        "{@token.intent_description}"
                      </dd>
                      <p class="text-xs text-base-content/60 mt-1">
                        Human-readable purpose for audit trail
                      </p>
                    </div>
                  <% end %>

                  <%= if @token.orchestrator_id do %>
                    <div>
                      <dt class="text-sm font-medium text-base-content/70">Orchestrator ID</dt>
                      <dd class="mt-1 text-sm text-base-content font-mono text-xs">
                        {@token.orchestrator_id}
                      </dd>
                    </div>
                  <% end %>

                  <%= if @token.environment do %>
                    <div>
                      <dt class="text-sm font-medium text-base-content/70">Environment</dt>
                      <dd class="mt-1">
                        <span class="badge badge-ghost badge-sm">{@token.environment}</span>
                      </dd>
                    </div>
                  <% end %>
                  
    <!-- Delegation Chain -->
                  <%= if @token.delegation_chain && !Enum.empty?(@token.delegation_chain) do %>
                    <div class="divider text-xs text-base-content/50">Authorization Chain</div>

                    <div>
                      <dt class="text-sm font-medium text-base-content/70">Delegation Chain</dt>
                      <dd class="mt-2">
                        <div class="space-y-2">
                          <%= for {user_id, index} <- Enum.with_index(@token.delegation_chain) do %>
                            <div class="flex items-center gap-2 text-sm">
                              <span class="badge badge-sm">{index + 1}</span>
                              <span class="text-base-content/70">→</span>
                              <span class="font-mono text-xs text-base-content">
                                {String.slice(user_id, 0..7)}...
                              </span>
                            </div>
                          <% end %>
                        </div>
                        <p class="text-xs text-base-content/60 mt-2">
                          Chain of {length(@token.delegation_chain)} authorization(s)
                        </p>
                      </dd>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions

  defp type_label(:access_token), do: "Access Token"
  defp type_label(:refresh_token), do: "Refresh Token"
  defp type_label(:authorization_code), do: "Authorization Code"

  defp status_label(token) do
    cond do
      token.revoked -> "Revoked"
      is_expired?(token) -> "Expired"
      true -> "Active"
    end
  end

  defp type_badge(:access_token) do
    assigns = %{}

    ~H"""
    <span class="badge badge-primary">Access Token</span>
    """
  end

  defp type_badge(:refresh_token) do
    assigns = %{}

    ~H"""
    <span class="badge badge-secondary">Refresh Token</span>
    """
  end

  defp type_badge(:authorization_code) do
    assigns = %{}

    ~H"""
    <span class="badge badge-accent">Authorization Code</span>
    """
  end

  defp status_badge(token) do
    cond do
      token.revoked ->
        assigns = %{}

        ~H"""
        <span class="badge badge-error">Revoked</span>
        """

      is_expired?(token) ->
        assigns = %{}

        ~H"""
        <span class="badge badge-warning">Expired</span>
        """

      true ->
        assigns = %{}

        ~H"""
        <span class="badge badge-success">Active</span>
        """
    end
  end

  defp user_status_badge(:active) do
    assigns = %{}

    ~H"""
    <span class="badge badge-success badge-sm">Active</span>
    """
  end

  defp user_status_badge(:pending_verification) do
    assigns = %{}

    ~H"""
    <span class="badge badge-warning badge-sm">Pending</span>
    """
  end

  defp user_status_badge(:suspended) do
    assigns = %{}

    ~H"""
    <span class="badge badge-error badge-sm">Suspended</span>
    """
  end

  defp user_status_badge(:deactivated) do
    assigns = %{}

    ~H"""
    <span class="badge badge-ghost badge-sm">Deactivated</span>
    """
  end

  defp client_type_badge(:confidential) do
    assigns = %{}

    ~H"""
    <span class="badge badge-primary badge-sm">Confidential</span>
    """
  end

  defp client_type_badge(:public) do
    assigns = %{}

    ~H"""
    <span class="badge badge-secondary badge-sm">Public</span>
    """
  end

  defp is_expired?(token) do
    DateTime.compare(token.expires_at, DateTime.utc_now()) == :lt
  end

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S UTC")
  end

  defp time_until_expiry(token) do
    diff = DateTime.diff(token.expires_at, DateTime.utc_now(), :second)

    cond do
      diff < 60 ->
        "#{diff}s"

      diff < 3600 ->
        "#{div(diff, 60)}m"

      diff < 86400 ->
        "#{div(diff, 3600)}h"

      true ->
        "#{div(diff, 86400)}d"
    end
  end

  # Agent Token Helper Functions

  defp agent_type_badge("autonomous") do
    assigns = %{}

    ~H"""
    <span class="badge badge-accent">🤖 Autonomous Agent</span>
    """
  end

  defp agent_type_badge("supervisor") do
    assigns = %{}

    ~H"""
    <span class="badge badge-info">👁️ Supervised Agent</span>
    """
  end

  defp agent_type_badge("tool") do
    assigns = %{}

    ~H"""
    <span class="badge badge-warning">⚡ Ephemeral Agent</span>
    """
  end

  defp agent_type_badge(_), do: nil

  defp get_delegator_email(user_id) when is_binary(user_id) do
    alias Thalamus.Infrastructure.Persistence.Schemas.UserSchema

    case Thalamus.Repo.get(UserSchema, user_id) do
      nil -> "Unknown User (#{String.slice(user_id, 0..7)}...)"
      user -> user.email
    end
  end

  defp get_delegator_email(_), do: "N/A"

  defp calculate_operations_percentage(token) do
    if token.max_operations && token.max_operations > 0 do
      operations = token.operations_count || 0
      percentage = (operations / token.max_operations * 100) |> Float.round(1)
      min(percentage, 100)
    else
      0
    end
  end
end
