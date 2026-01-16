defmodule ThalamusWeb.AuditLogs.Index do
  @moduledoc """
  LiveView for viewing audit logs.

  Displays immutable security and compliance audit records.
  """
  use ThalamusWeb, :live_view

  # Load authenticated user on mount
  on_mount ThalamusWeb.Live.Hooks.LiveAuth

  import Ecto.Query
  alias Thalamus.Infrastructure.Persistence.Schemas.AuditLogSchema
  alias Thalamus.Repo

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_path, "/dashboard/audit-logs")
     |> assign(:search, "")
     |> assign(:filter_event_type, "all")
     |> assign(:filter_date_range, "7_days")
     |> load_audit_logs()}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply,
     socket
     |> assign(:page_title, "Audit Logs")}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    {:noreply,
     socket
     |> assign(:search, search)
     |> load_audit_logs()}
  end

  @impl true
  def handle_event("filter_event_type", %{"event_type" => event_type}, socket) do
    {:noreply,
     socket
     |> assign(:filter_event_type, event_type)
     |> load_audit_logs()}
  end

  @impl true
  def handle_event("filter_date_range", %{"date_range" => date_range}, socket) do
    {:noreply,
     socket
     |> assign(:filter_date_range, date_range)
     |> load_audit_logs()}
  end

  defp load_audit_logs(socket) do
    search = socket.assigns.search
    filter_event_type = socket.assigns.filter_event_type
    filter_date_range = socket.assigns.filter_date_range

    query =
      AuditLogSchema
      |> filter_by_search(search)
      |> filter_by_event_type(filter_event_type)
      |> filter_by_date_range(filter_date_range)
      |> order_by([a], desc: a.inserted_at)
      |> limit(100)
      |> preload([:user, :organization, :client])

    audit_logs = Repo.all(query)
    assign(socket, :audit_logs, audit_logs)
  end

  defp filter_by_search(query, ""), do: query

  defp filter_by_search(query, search) do
    search_pattern = "%#{search}%"

    query
    |> join(:left, [a], u in assoc(a, :user))
    |> join(:left, [a], o in assoc(a, :organization))
    |> join(:left, [a], c in assoc(a, :client))
    |> where(
      [a, u, o, c],
      ilike(u.email, ^search_pattern) or
        ilike(o.name, ^search_pattern) or
        ilike(c.name, ^search_pattern) or
        ilike(a.ip_address, ^search_pattern) or
        ilike(a.event_type, ^search_pattern)
    )
  end

  defp filter_by_event_type(query, "all"), do: query

  defp filter_by_event_type(query, event_type) do
    where(query, [a], a.event_type == ^event_type)
  end

  defp filter_by_date_range(query, "all"), do: query

  defp filter_by_date_range(query, "1_hour") do
    cutoff = DateTime.utc_now() |> DateTime.add(-3600, :second)
    where(query, [a], a.inserted_at >= ^cutoff)
  end

  defp filter_by_date_range(query, "24_hours") do
    cutoff = DateTime.utc_now() |> DateTime.add(-86400, :second)
    where(query, [a], a.inserted_at >= ^cutoff)
  end

  defp filter_by_date_range(query, "7_days") do
    cutoff = DateTime.utc_now() |> DateTime.add(-604_800, :second)
    where(query, [a], a.inserted_at >= ^cutoff)
  end

  defp filter_by_date_range(query, "30_days") do
    cutoff = DateTime.utc_now() |> DateTime.add(-2_592_000, :second)
    where(query, [a], a.inserted_at >= ^cutoff)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8 py-8">
      <.breadcrumbs items={[
        %{label: "Dashboard", path: "/dashboard"},
        %{label: "Audit Logs", path: nil}
      ]} />
      
    <!-- Header -->
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="text-2xl font-semibold text-base-content">Audit Logs</h1>
          <p class="mt-2 text-sm text-base-content/70">
            Immutable security and compliance audit trail. Showing last 100 entries.
          </p>
        </div>
      </div>
      
    <!-- Filters -->
      <div class="mt-6 grid grid-cols-1 gap-4 sm:grid-cols-3">
        <!-- Search -->
        <form phx-change="search" class="form-control">
          <label class="label">
            <span class="label-text">Search</span>
          </label>
          <input
            type="text"
            name="search"
            value={@search}
            placeholder="Search by user, org, client, IP, or event..."
            class="input input-bordered w-full"
          />
        </form>
        
    <!-- Event Type Filter -->
        <form phx-change="filter_event_type" class="form-control">
          <label class="label">
            <span class="label-text">Event Type</span>
          </label>
          <select name="event_type" class="select select-bordered w-full">
            <option value="all" selected={@filter_event_type == "all"}>All Events</option>
            <option
              value="authentication_success"
              selected={@filter_event_type == "authentication_success"}
            >
              Authentication Success
            </option>
            <option
              value="authentication_failure"
              selected={@filter_event_type == "authentication_failure"}
            >
              Authentication Failure
            </option>
            <option value="token_generated" selected={@filter_event_type == "token_generated"}>
              Token Generated
            </option>
            <option value="token_revoked" selected={@filter_event_type == "token_revoked"}>
              Token Revoked
            </option>
            <option value="mfa_enabled" selected={@filter_event_type == "mfa_enabled"}>
              MFA Enabled
            </option>
            <option value="mfa_disabled" selected={@filter_event_type == "mfa_disabled"}>
              MFA Disabled
            </option>
            <option value="password_changed" selected={@filter_event_type == "password_changed"}>
              Password Changed
            </option>
            <option value="user_created" selected={@filter_event_type == "user_created"}>
              User Created
            </option>
            <option value="user_updated" selected={@filter_event_type == "user_updated"}>
              User Updated
            </option>
            <option
              value="organization_created"
              selected={@filter_event_type == "organization_created"}
            >
              Organization Created
            </option>
            <option value="client_created" selected={@filter_event_type == "client_created"}>
              Client Created
            </option>
            <option
              value="client_secret_rotated"
              selected={@filter_event_type == "client_secret_rotated"}
            >
              Client Secret Rotated
            </option>
          </select>
        </form>
        
    <!-- Date Range Filter -->
        <form phx-change="filter_date_range" class="form-control">
          <label class="label">
            <span class="label-text">Time Range</span>
          </label>
          <select name="date_range" class="select select-bordered w-full">
            <option value="1_hour" selected={@filter_date_range == "1_hour"}>Last Hour</option>
            <option value="24_hours" selected={@filter_date_range == "24_hours"}>
              Last 24 Hours
            </option>
            <option value="7_days" selected={@filter_date_range == "7_days"}>Last 7 Days</option>
            <option value="30_days" selected={@filter_date_range == "30_days"}>Last 30 Days</option>
            <option value="all" selected={@filter_date_range == "all"}>All Time</option>
          </select>
        </form>
      </div>
      
    <!-- Audit Logs Table -->
      <div class="mt-8 flow-root">
        <div class="-mx-4 -my-2 overflow-x-auto sm:-mx-6 lg:-mx-8">
          <div class="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8">
            <div class="overflow-hidden shadow ring-1 ring-base-300 rounded-lg">
              <table class="min-w-full divide-y divide-base-300">
                <thead class="bg-base-200">
                  <tr>
                    <th scope="col" class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold">
                      Timestamp
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold">Event</th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold">User</th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold">
                      Organization
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold">
                      IP Address
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold">Details</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-base-300 bg-base-100">
                  <%= for log <- @audit_logs do %>
                    <tr>
                      <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm">
                        {format_datetime(log.inserted_at)}
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm">
                        {event_badge(log.event_type)}
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm">
                        <%= if log.user do %>
                          <.link
                            navigate={~p"/dashboard/users/#{log.user.id}"}
                            class="text-primary hover:underline"
                          >
                            {log.user.email}
                          </.link>
                        <% else %>
                          <span class="text-base-content/50">N/A</span>
                        <% end %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm">
                        <%= if log.organization do %>
                          <.link
                            navigate={~p"/dashboard/organizations/#{log.organization.id}"}
                            class="text-primary hover:underline"
                          >
                            {log.organization.name}
                          </.link>
                        <% else %>
                          <span class="text-base-content/50">N/A</span>
                        <% end %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-base-content/70 font-mono">
                        {log.ip_address || "N/A"}
                      </td>
                      <td class="px-3 py-4 text-sm text-base-content/70">
                        {format_metadata(log.metadata)}
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>

              <%= if Enum.empty?(@audit_logs) do %>
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
                      d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                    />
                  </svg>
                  <h3 class="mt-2 text-sm font-medium text-base-content">No audit logs found</h3>
                  <p class="mt-1 text-sm text-base-content/70">
                    Adjust your filters or wait for system activity.
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

  defp event_badge(event_type) do
    {color, label} = event_info(event_type)
    assigns = %{color: color, label: label}

    ~H"""
    <span class={"badge badge-#{@color} badge-sm"}>{@label}</span>
    """
  end

  defp event_info("authentication_success"), do: {"success", "Auth Success"}
  defp event_info("authentication_failure"), do: {"error", "Auth Failure"}
  defp event_info("token_generated"), do: {"info", "Token Generated"}
  defp event_info("token_revoked"), do: {"warning", "Token Revoked"}
  defp event_info("mfa_enabled"), do: {"success", "MFA Enabled"}
  defp event_info("mfa_disabled"), do: {"warning", "MFA Disabled"}
  defp event_info("password_changed"), do: {"info", "Password Changed"}
  defp event_info("user_created"), do: {"success", "User Created"}
  defp event_info("user_updated"), do: {"info", "User Updated"}
  defp event_info("user_deleted"), do: {"error", "User Deleted"}
  defp event_info("organization_created"), do: {"success", "Org Created"}
  defp event_info("organization_updated"), do: {"info", "Org Updated"}
  defp event_info("organization_deleted"), do: {"error", "Org Deleted"}
  defp event_info("client_created"), do: {"success", "Client Created"}
  defp event_info("client_secret_rotated"), do: {"warning", "Secret Rotated"}
  defp event_info("mfa_setup_initiated"), do: {"info", "MFA Setup"}
  defp event_info("mfa_verification_success"), do: {"success", "MFA Verified"}
  defp event_info("mfa_verification_failed"), do: {"error", "MFA Failed"}
  defp event_info("backup_codes_regenerated"), do: {"warning", "Backup Codes"}
  defp event_info("failed_login"), do: {"error", "Failed Login"}
  defp event_info(_), do: {"ghost", "Other"}

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S UTC")
  end

  defp format_metadata(metadata) when is_map(metadata) do
    metadata
    |> Map.drop([:user_id, :organization_id, :client_id, :ip_address, :user_agent, :timestamp])
    |> Enum.map(fn {k, v} -> "#{k}: #{inspect(v)}" end)
    |> Enum.take(3)
    |> Enum.join(", ")
    |> case do
      "" -> "—"
      str -> String.slice(str, 0..100)
    end
  end

  defp format_metadata(_), do: "—"
end
