defmodule ThalamusWeb.Organizations.Show do
  @moduledoc """
  LiveView for showing organization details.
  """
  use ThalamusWeb, :live_view

  # Load authenticated user on mount
  on_mount ThalamusWeb.Live.Hooks.LiveAuth

  import Ecto.Query

  alias Thalamus.Repo

  alias Thalamus.Infrastructure.Persistence.Schemas.{
    OrganizationSchema,
    UserSchema,
    OAuth2ClientSchema
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_path, "/dashboard/organizations")}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    case Repo.get(OrganizationSchema, id) |> Repo.preload(:users) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "Organization not found")
         |> push_navigate(to: ~p"/dashboard/organizations")}

      organization ->
        {:noreply,
         socket
         |> assign(:page_title, "Organization Details")
         |> assign(:organization, organization)
         |> load_stats(organization)}
    end
  end

  @impl true
  def handle_event("verify", _params, socket) do
    changeset = OrganizationSchema.verify_changeset(socket.assigns.organization)

    case Repo.update(changeset) do
      {:ok, updated_org} ->
        {:noreply,
         socket
         |> assign(:organization, Repo.preload(updated_org, :users, force: true))
         |> put_flash(:info, "Organization verified successfully!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to verify organization")}
    end
  end

  @impl true
  def handle_event("suspend", _params, socket) do
    changeset = OrganizationSchema.suspend_changeset(socket.assigns.organization)

    case Repo.update(changeset) do
      {:ok, updated_org} ->
        {:noreply,
         socket
         |> assign(:organization, Repo.preload(updated_org, :users, force: true))
         |> put_flash(:info, "Organization suspended")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to suspend organization")}
    end
  end

  @impl true
  def handle_event("reactivate", _params, socket) do
    changeset = OrganizationSchema.reactivate_changeset(socket.assigns.organization)

    case Repo.update(changeset) do
      {:ok, updated_org} ->
        {:noreply,
         socket
         |> assign(:organization, Repo.preload(updated_org, :users, force: true))
         |> put_flash(:info, "Organization reactivated")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to reactivate organization")}
    end
  end

  @impl true
  def handle_event("change_plan", %{"plan" => plan_type_string}, socket) do
    plan_type = String.to_existing_atom(plan_type_string)
    changeset = OrganizationSchema.change_plan_changeset(socket.assigns.organization, plan_type)

    case Repo.update(changeset) do
      {:ok, updated_org} ->
        {:noreply,
         socket
         |> assign(:organization, Repo.preload(updated_org, :users, force: true))
         |> put_flash(:info, "Plan changed successfully to #{plan_type_string}")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to change plan")}
    end
  end

  defp load_stats(socket, organization) do
    # Get OAuth2 clients count
    clients_count =
      OAuth2ClientSchema
      |> where([c], c.organization_id == ^organization.id)
      |> select([c], count(c.id))
      |> Repo.one()

    # Get recent users (last 5)
    recent_users =
      UserSchema
      |> where([u], u.organization_id == ^organization.id)
      |> order_by([u], desc: u.inserted_at)
      |> limit(5)
      |> Repo.all()

    socket
    |> assign(:clients_count, clients_count || 0)
    |> assign(:recent_users, recent_users)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8 py-8">
      <.breadcrumbs items={[
        %{label: "Dashboard", path: "/dashboard"},
        %{label: "Organizations", path: "/dashboard/organizations"},
        %{label: @organization.name, path: nil}
      ]} />
      
    <!-- Header -->
      <div class="mb-8">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-semibold text-base-content">{@organization.name}</h1>
            <p class="text-sm text-base-content/70 mt-1">
              Created {Calendar.strftime(@organization.inserted_at, "%Y-%m-%d")}
            </p>
          </div>
          <div class="flex gap-2 items-center">
            <.link
              navigate={~p"/dashboard/organizations/#{@organization.id}/edit"}
              class="btn btn-sm btn-ghost"
            >
              Edit
            </.link>
            <span class={[
              "badge",
              status_badge_class(@organization.status)
            ]}>
              {format_status(@organization.status)}
            </span>
          </div>
        </div>
      </div>
      
    <!-- Stats Cards -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-8">
        <div class="stat bg-base-100 shadow rounded-lg">
          <div class="stat-title">Users</div>
          <div class="stat-value text-primary">{@organization.current_user_count}</div>
          <div class="stat-desc">of {@organization.max_users} maximum</div>
        </div>
        <div class="stat bg-base-100 shadow rounded-lg">
          <div class="stat-title">OAuth2 Clients</div>
          <div class="stat-value text-success">{@clients_count}</div>
        </div>
        <div class="stat bg-base-100 shadow rounded-lg">
          <div class="stat-title">API Calls (This Month)</div>
          <div class="stat-value text-info">
            {format_number(@organization.api_calls_current_month)}
          </div>
          <div class="stat-desc">of {format_number(@organization.max_api_calls_per_month)} limit</div>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <!-- Organization Information -->
        <div class="card bg-base-100 shadow">
          <div class="card-body">
            <h2 class="card-title">Organization Information</h2>

            <div class="space-y-4">
              <div>
                <label class="text-xs text-base-content/70 uppercase">Name</label>
                <p class="font-medium">{@organization.name}</p>
              </div>

              <div>
                <label class="text-xs text-base-content/70 uppercase">Status</label>
                <p class="font-medium">{format_status(@organization.status)}</p>
              </div>

              <div>
                <label class="text-xs text-base-content/70 uppercase">Verified</label>
                <p class="font-medium">
                  <%= if @organization.verified do %>
                    <span class="text-success">Yes</span>
                  <% else %>
                    <span class="text-warning">No</span>
                  <% end %>
                </p>
              </div>

              <div>
                <label class="text-xs text-base-content/70 uppercase">Created</label>
                <p class="font-medium">
                  {Calendar.strftime(@organization.inserted_at, "%Y-%m-%d %H:%M")}
                </p>
              </div>

              <div class="divider"></div>
              
    <!-- Actions -->
              <div class="space-y-2">
                <%= if @organization.verified == false do %>
                  <button phx-click="verify" class="btn btn-success btn-sm w-full">
                    Verify Organization
                  </button>
                <% end %>

                <%= if @organization.status == :active or @organization.status == :trial do %>
                  <button
                    phx-click="suspend"
                    data-confirm="Are you sure you want to suspend this organization?"
                    class="btn btn-error btn-sm w-full"
                  >
                    Suspend Organization
                  </button>
                <% end %>

                <%= if @organization.status == :suspended do %>
                  <button
                    phx-click="reactivate"
                    class="btn btn-success btn-sm w-full"
                  >
                    Reactivate Organization
                  </button>
                <% end %>
              </div>
            </div>
          </div>
        </div>
        
    <!-- Plan Information -->
        <div class="card bg-base-100 shadow">
          <div class="card-body">
            <h2 class="card-title">Plan & Limits</h2>

            <div class="space-y-4">
              <div>
                <label class="text-xs text-base-content/70 uppercase">Current Plan</label>
                <p class="font-medium">
                  <span class={[
                    "badge",
                    plan_badge_class(@organization.plan_type)
                  ]}>
                    {format_plan(@organization.plan_type)}
                  </span>
                </p>
              </div>

              <div>
                <label class="text-xs text-base-content/70 uppercase">Max Users</label>
                <p class="font-medium">{format_number(@organization.max_users)}</p>
              </div>

              <div>
                <label class="text-xs text-base-content/70 uppercase">Max API Calls/Month</label>
                <p class="font-medium">{format_number(@organization.max_api_calls_per_month)}</p>
              </div>

              <div>
                <label class="text-xs text-base-content/70 uppercase">MFA Required</label>
                <p class="font-medium">{if @organization.mfa_required, do: "Yes", else: "No"}</p>
              </div>

              <div>
                <label class="text-xs text-base-content/70 uppercase">SSO Enabled</label>
                <p class="font-medium">{if @organization.sso_enabled, do: "Yes", else: "No"}</p>
              </div>

              <div>
                <label class="text-xs text-base-content/70 uppercase">Audit Logs Retention</label>
                <p class="font-medium">{@organization.audit_logs_retention_days} days</p>
              </div>

              <div>
                <label class="text-xs text-base-content/70 uppercase">Support Level</label>
                <p class="font-medium">{format_support(@organization.support_level)}</p>
              </div>

              <div class="divider"></div>
              
    <!-- Change Plan -->
              <div>
                <label class="text-xs text-base-content/70 uppercase mb-2 block">Change Plan</label>
                <select
                  phx-change="change_plan"
                  name="plan"
                  class="select select-bordered select-sm w-full"
                >
                  <option value="free" selected={@organization.plan_type == :free}>Free</option>
                  <option value="starter" selected={@organization.plan_type == :starter}>
                    Starter
                  </option>
                  <option value="professional" selected={@organization.plan_type == :professional}>
                    Professional
                  </option>
                  <option value="enterprise" selected={@organization.plan_type == :enterprise}>
                    Enterprise
                  </option>
                </select>
              </div>
            </div>
          </div>
        </div>
      </div>
      
    <!-- Recent Users -->
      <div class="card bg-base-100 shadow mt-6">
        <div class="card-body">
          <h2 class="card-title">Recent Users</h2>

          <%= if @recent_users == [] do %>
            <p class="text-center text-base-content/70 py-8">No users in this organization yet</p>
          <% else %>
            <div class="overflow-x-auto">
              <table class="table table-sm">
                <thead>
                  <tr>
                    <th>Email</th>
                    <th>Name</th>
                    <th>Status</th>
                    <th>Joined</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for user <- @recent_users do %>
                    <tr>
                      <td>{user.email}</td>
                      <td>{user.name || "-"}</td>
                      <td>
                        <span class={[
                          "badge badge-sm",
                          user_status_badge_class(user.status)
                        ]}>
                          {format_user_status(user.status)}
                        </span>
                      </td>
                      <td class="text-xs text-base-content/70">
                        {Calendar.strftime(user.inserted_at, "%Y-%m-%d")}
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

  # Helper functions

  defp status_badge_class(:trial), do: "badge-info"
  defp status_badge_class(:active), do: "badge-success"
  defp status_badge_class(:suspended), do: "badge-error"
  defp status_badge_class(:cancelled), do: "badge-ghost"

  defp format_status(:trial), do: "Trial"
  defp format_status(:active), do: "Active"
  defp format_status(:suspended), do: "Suspended"
  defp format_status(:cancelled), do: "Cancelled"

  defp plan_badge_class(:free), do: "badge-ghost"
  defp plan_badge_class(:basic), do: "badge-info"
  defp plan_badge_class(:standard), do: "badge-primary"
  defp plan_badge_class(:premium), do: "badge-success"
  defp plan_badge_class(:enterprise), do: "badge-accent"

  defp format_plan(:free), do: "Free"
  defp format_plan(:basic), do: "Basic"
  defp format_plan(:standard), do: "Standard"
  defp format_plan(:premium), do: "Premium"
  defp format_plan(:enterprise), do: "Enterprise"

  defp format_support(:community), do: "Community"
  defp format_support(:email), do: "Email"
  defp format_support(:priority), do: "Priority"
  defp format_support(:dedicated), do: "Dedicated"
  defp format_support(:enterprise), do: "Enterprise"
  defp format_support(_), do: "Unknown"

  defp user_status_badge_class(:active), do: "badge-success"
  defp user_status_badge_class(:pending_verification), do: "badge-warning"
  defp user_status_badge_class(:suspended), do: "badge-error"
  defp user_status_badge_class(:deactivated), do: "badge-ghost"

  defp format_user_status(:active), do: "Active"
  defp format_user_status(:pending_verification), do: "Pending"
  defp format_user_status(:suspended), do: "Suspended"
  defp format_user_status(:deactivated), do: "Deactivated"

  defp format_number(num) when num >= 1_000_000 do
    "#{Float.round(num / 1_000_000, 1)}M"
  end

  defp format_number(num) when num >= 1_000 do
    "#{Float.round(num / 1_000, 1)}K"
  end

  defp format_number(num), do: to_string(num)
end
