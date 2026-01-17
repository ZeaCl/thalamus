defmodule ThalamusWeb.Tokens.Index do
  @moduledoc """
  LiveView for listing and managing OAuth2 tokens.
  """
  use ThalamusWeb, :live_view

  # Load authenticated user on mount
  on_mount ThalamusWeb.Live.Hooks.LiveAuth

  import Ecto.Query
  alias Thalamus.Infrastructure.Persistence.Schemas.TokenSchema
  alias Thalamus.Repo

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_path, "/dashboard/tokens")
     |> assign(:search, "")
     |> assign(:filter_type, "all")
     |> assign(:filter_status, "all")
     |> assign(:filter_agent_type, "all")
     |> load_tokens()}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply,
     socket
     |> assign(:page_title, "Tokens")}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    {:noreply,
     socket
     |> assign(:search, search)
     |> load_tokens()}
  end

  @impl true
  def handle_event("filter_type", %{"type" => type}, socket) do
    {:noreply,
     socket
     |> assign(:filter_type, type)
     |> load_tokens()}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    {:noreply,
     socket
     |> assign(:filter_status, status)
     |> load_tokens()}
  end

  @impl true
  def handle_event("filter_agent_type", %{"agent_type" => agent_type}, socket) do
    {:noreply,
     socket
     |> assign(:filter_agent_type, agent_type)
     |> load_tokens()}
  end

  @impl true
  def handle_event("revoke", %{"id" => id}, socket) do
    case Repo.get(TokenSchema, id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Token not found")}

      token ->
        token
        |> TokenSchema.revoke_changeset()
        |> Repo.update()

        {:noreply,
         socket
         |> put_flash(:info, "Token revoked successfully")
         |> load_tokens()}
    end
  end

  defp load_tokens(socket) do
    search = socket.assigns.search
    filter_type = socket.assigns.filter_type
    filter_status = socket.assigns.filter_status
    filter_agent_type = socket.assigns.filter_agent_type

    query =
      TokenSchema
      |> filter_by_search(search)
      |> filter_by_type(filter_type)
      |> filter_by_status(filter_status)
      |> filter_by_agent_type(filter_agent_type)
      |> order_by([t], desc: t.inserted_at)
      |> preload([:user, :client, :organization])

    tokens = Repo.all(query)
    assign(socket, :tokens, tokens)
  end

  defp filter_by_search(query, ""), do: query

  defp filter_by_search(query, search) do
    search_pattern = "%#{search}%"

    query
    |> join(:left, [t], u in assoc(t, :user))
    |> join(:left, [t], c in assoc(t, :client))
    |> where(
      [t, u, c],
      ilike(u.email, ^search_pattern) or
        ilike(c.name, ^search_pattern) or
        ilike(t.token, ^search_pattern)
    )
  end

  defp filter_by_type(query, "all"), do: query
  defp filter_by_type(query, "access_token"), do: where(query, [t], t.type == :access_token)
  defp filter_by_type(query, "refresh_token"), do: where(query, [t], t.type == :refresh_token)

  defp filter_by_type(query, "authorization_code"),
    do: where(query, [t], t.type == :authorization_code)

  defp filter_by_status(query, "all"), do: query
  defp filter_by_status(query, "active"), do: filter_active_tokens(query)
  defp filter_by_status(query, "expired"), do: filter_expired_tokens(query)
  defp filter_by_status(query, "revoked"), do: where(query, [t], t.revoked == true)

  defp filter_active_tokens(query) do
    now = DateTime.utc_now()

    query
    |> where([t], t.revoked == false)
    |> where([t], t.expires_at > ^now)
  end

  defp filter_expired_tokens(query) do
    now = DateTime.utc_now()

    query
    |> where([t], t.revoked == false)
    |> where([t], t.expires_at <= ^now)
  end

  defp filter_by_agent_type(query, "all"), do: query
  defp filter_by_agent_type(query, "regular"), do: where(query, [t], is_nil(t.agent_type))
  defp filter_by_agent_type(query, "agent"), do: where(query, [t], not is_nil(t.agent_type))

  defp filter_by_agent_type(query, "autonomous"),
    do: where(query, [t], t.agent_type == "autonomous")

  defp filter_by_agent_type(query, "supervisor"),
    do: where(query, [t], t.agent_type == "supervisor")

  defp filter_by_agent_type(query, "tool"),
    do: where(query, [t], t.agent_type == "tool")

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8 py-8">
      <.breadcrumbs items={[
        %{label: "Dashboard", path: "/dashboard"},
        %{label: "Access Tokens", path: nil}
      ]} />
      
    <!-- Header -->
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="text-2xl font-semibold text-base-content">Tokens</h1>
          <p class="mt-2 text-sm text-base-content/70">
            Manage OAuth2 access tokens, refresh tokens, and authorization codes.
          </p>
        </div>
      </div>
      
    <!-- Filters -->
      <div class="mt-6 grid grid-cols-1 gap-4 sm:grid-cols-4">
        <!-- Search -->
        <form phx-change="search" class="form-control">
          <label class="label">
            <span class="label-text">Search</span>
          </label>
          <input
            type="text"
            name="search"
            value={@search}
            placeholder="Search by user, client, or token..."
            class="input input-bordered w-full"
          />
        </form>
        
    <!-- Type Filter -->
        <form phx-change="filter_type" class="form-control">
          <label class="label">
            <span class="label-text">Token Type</span>
          </label>
          <select name="type" class="select select-bordered w-full">
            <option value="all" selected={@filter_type == "all"}>All Types</option>
            <option value="access_token" selected={@filter_type == "access_token"}>
              Access Token
            </option>
            <option value="refresh_token" selected={@filter_type == "refresh_token"}>
              Refresh Token
            </option>
            <option value="authorization_code" selected={@filter_type == "authorization_code"}>
              Authorization Code
            </option>
          </select>
        </form>
        
    <!-- Status Filter -->
        <form phx-change="filter_status" class="form-control">
          <label class="label">
            <span class="label-text">Status</span>
          </label>
          <select name="status" class="select select-bordered w-full">
            <option value="all" selected={@filter_status == "all"}>All Statuses</option>
            <option value="active" selected={@filter_status == "active"}>Active</option>
            <option value="expired" selected={@filter_status == "expired"}>Expired</option>
            <option value="revoked" selected={@filter_status == "revoked"}>Revoked</option>
          </select>
        </form>
        
    <!-- Agent Type Filter -->
        <form phx-change="filter_agent_type" class="form-control">
          <label class="label">
            <span class="label-text">Agent Type</span>
          </label>
          <select name="agent_type" class="select select-bordered w-full">
            <option value="all" selected={@filter_agent_type == "all"}>All Tokens</option>
            <option value="regular" selected={@filter_agent_type == "regular"}>Regular Tokens</option>
            <option value="agent" selected={@filter_agent_type == "agent"}>🤖 All Agents</option>
            <option value="autonomous" selected={@filter_agent_type == "autonomous"}>
              🤖 Autonomous
            </option>
            <option value="supervisor" selected={@filter_agent_type == "supervisor"}>
              👁️ Supervised
            </option>
            <option value="tool" selected={@filter_agent_type == "tool"}>
              ⚡ Ephemeral
            </option>
          </select>
        </form>
      </div>
      
    <!-- Tokens Table -->
      <div class="mt-8 flow-root">
        <div class="-mx-4 -my-2 overflow-x-auto sm:-mx-6 lg:-mx-8">
          <div class="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8">
            <div class="overflow-hidden shadow ring-1 ring-base-300 rounded-lg">
              <table class="min-w-full divide-y divide-base-300">
                <thead class="bg-base-200">
                  <tr>
                    <th scope="col" class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold">
                      Token
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold">Type</th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold">Agent</th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold">User</th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold">Client</th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold">Status</th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold">
                      Expires At
                    </th>
                    <th scope="col" class="relative py-3.5 pl-3 pr-4 sm:pr-6">
                      <span class="sr-only">Actions</span>
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-base-300 bg-base-100">
                  <%= for token <- @tokens do %>
                    <tr>
                      <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-mono">
                        {truncate_token(token.token)}
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm">
                        {type_badge(token.type)}
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm">
                        {agent_type_badge(token.agent_type)}
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm">
                        <%= if token.user do %>
                          <.link
                            navigate={~p"/dashboard/users/#{token.user.id}"}
                            class="text-primary hover:underline"
                          >
                            {token.user.email}
                          </.link>
                        <% else %>
                          <span class="text-base-content/50">N/A</span>
                        <% end %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm">
                        <%= if token.client do %>
                          <.link
                            navigate={~p"/dashboard/clients/#{token.client.id}"}
                            class="text-primary hover:underline"
                          >
                            {token.client.name}
                          </.link>
                        <% else %>
                          <span class="text-base-content/50">N/A</span>
                        <% end %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm">
                        {status_badge(token)}
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-base-content/70">
                        {format_datetime(token.expires_at)}
                      </td>
                      <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-6">
                        <div class="flex justify-end gap-2">
                          <.link
                            navigate={~p"/dashboard/tokens/#{token.id}"}
                            class="text-primary hover:text-primary-focus"
                          >
                            View
                          </.link>
                          <%= if !token.revoked && !is_expired?(token) do %>
                            <button
                              phx-click="revoke"
                              phx-value-id={token.id}
                              data-confirm="Are you sure you want to revoke this token?"
                              class="text-error hover:text-error-focus"
                            >
                              Revoke
                            </button>
                          <% end %>
                        </div>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>

              <%= if Enum.empty?(@tokens) do %>
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
                  <h3 class="mt-2 text-sm font-medium text-base-content">No tokens found</h3>
                  <p class="mt-1 text-sm text-base-content/70">
                    Tokens are created through OAuth2 flows.
                  </p>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions

  defp truncate_token(token) do
    if String.length(token) > 16 do
      String.slice(token, 0..15) <> "..."
    else
      token
    end
  end

  defp type_badge(:access_token) do
    assigns = %{}

    ~H"""
    <span class="badge badge-primary badge-sm">Access Token</span>
    """
  end

  defp type_badge(:refresh_token) do
    assigns = %{}

    ~H"""
    <span class="badge badge-secondary badge-sm">Refresh Token</span>
    """
  end

  defp type_badge(:authorization_code) do
    assigns = %{}

    ~H"""
    <span class="badge badge-accent badge-sm">Auth Code</span>
    """
  end

  defp status_badge(token) do
    cond do
      token.revoked ->
        assigns = %{}

        ~H"""
        <span class="badge badge-error badge-sm">Revoked</span>
        """

      is_expired?(token) ->
        assigns = %{}

        ~H"""
        <span class="badge badge-warning badge-sm">Expired</span>
        """

      true ->
        assigns = %{}

        ~H"""
        <span class="badge badge-success badge-sm">Active</span>
        """
    end
  end

  defp is_expired?(token) do
    DateTime.compare(token.expires_at, DateTime.utc_now()) == :lt
  end

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S UTC")
  end

  defp agent_type_badge(nil) do
    assigns = %{}

    ~H"""
    <span class="text-base-content/50 text-xs">—</span>
    """
  end

  defp agent_type_badge("autonomous") do
    assigns = %{}

    ~H"""
    <span class="badge badge-accent badge-sm">🤖 Autonomous</span>
    """
  end

  defp agent_type_badge("supervisor") do
    assigns = %{}

    ~H"""
    <span class="badge badge-info badge-sm">👁️ Supervised</span>
    """
  end

  defp agent_type_badge("tool") do
    assigns = %{}

    ~H"""
    <span class="badge badge-warning badge-sm">⚡ Ephemeral</span>
    """
  end
end
