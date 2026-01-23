defmodule ThalamusWeb.Organizations.Index do
  @moduledoc """
  LiveView for listing and managing organizations.
  """
  use ThalamusWeb, :live_view

  # Load authenticated user on mount
  on_mount ThalamusWeb.Live.Hooks.LiveAuth

  import Ecto.Query

  alias Thalamus.Repo
  alias Thalamus.Infrastructure.Persistence.Schemas.OrganizationSchema

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_path, "/dashboard/organizations")
     |> assign(:search, "")
     |> assign(:filter_status, "all")
     |> assign(:filter_plan, "all")
     |> load_organizations()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Organizations")
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    {:noreply,
     socket
     |> assign(:search, search)
     |> load_organizations()}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    {:noreply,
     socket
     |> assign(:filter_status, status)
     |> load_organizations()}
  end

  @impl true
  def handle_event("filter_plan", %{"plan" => plan}, socket) do
    {:noreply,
     socket
     |> assign(:filter_plan, plan)
     |> load_organizations()}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    case Repo.get(OrganizationSchema, id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Organization not found")}

      organization ->
        case Repo.delete(organization) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, "Organization deleted successfully")
             |> load_organizations()}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to delete organization")}
        end
    end
  end

  defp load_organizations(socket) do
    search = socket.assigns.search
    filter_status = socket.assigns.filter_status
    filter_plan = socket.assigns.filter_plan

    query =
      OrganizationSchema
      |> filter_by_search(search)
      |> filter_by_status(filter_status)
      |> filter_by_plan(filter_plan)
      |> order_by([o], desc: o.inserted_at)
      |> preload(:users)

    organizations = Repo.all(query)

    assign(socket, :organizations, organizations)
  end

  defp filter_by_search(query, ""), do: query

  defp filter_by_search(query, search) do
    search_pattern = "%#{search}%"

    where(
      query,
      [o],
      ilike(o.name, ^search_pattern)
    )
  end

  defp filter_by_status(query, "all"), do: query

  defp filter_by_status(query, status_string) do
    status = String.to_existing_atom(status_string)
    where(query, [o], o.status == ^status)
  end

  defp filter_by_plan(query, "all"), do: query

  defp filter_by_plan(query, plan_string) do
    plan = String.to_existing_atom(plan_string)
    where(query, [o], o.plan_type == ^plan)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8 py-8">
      <.breadcrumbs items={[
        %{label: "Dashboard", path: "/dashboard"},
        %{label: "Organizations", path: nil}
      ]} />
      
    <!-- Header -->
      <div class="sm:flex sm:items-center sm:justify-between mb-8">
        <div>
          <h1 class="text-2xl font-semibold text-base-content">Organizations</h1>
          <p class="mt-2 text-sm text-base-content/70">
            Manage organizations and their plans
          </p>
        </div>
        <div class="mt-4 sm:mt-0">
          <.link navigate={~p"/dashboard/organizations/new"} class="btn btn-primary">
            <svg class="h-5 w-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12 4v16m8-8H4"
              />
            </svg>
            New Organization
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
            placeholder="Search by name..."
            class="input input-bordered w-full"
          />
        </form>
        
    <!-- Status Filter -->
        <form phx-change="filter_status" class="w-full sm:w-48">
          <select name="status" class="select select-bordered w-full">
            <option value="all" selected={@filter_status == "all"}>All Status</option>
            <option value="trial" selected={@filter_status == "trial"}>Trial</option>
            <option value="active" selected={@filter_status == "active"}>Active</option>
            <option value="suspended" selected={@filter_status == "suspended"}>Suspended</option>
            <option value="cancelled" selected={@filter_status == "cancelled"}>Cancelled</option>
          </select>
        </form>
        
    <!-- Plan Filter -->
        <form phx-change="filter_plan" class="w-full sm:w-48">
          <select name="plan" class="select select-bordered w-full">
            <option value="all" selected={@filter_plan == "all"}>All Plans</option>
            <option value="free" selected={@filter_plan == "free"}>Free</option>
            <option value="starter" selected={@filter_plan == "starter"}>Starter</option>
            <option value="professional" selected={@filter_plan == "professional"}>
              Professional
            </option>
            <option value="enterprise" selected={@filter_plan == "enterprise"}>Enterprise</option>
          </select>
        </form>
      </div>
      
    <!-- Organizations Table -->
      <%= if @organizations == [] do %>
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
              d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"
            />
          </svg>
          <h3 class="mt-2 text-sm font-medium text-base-content">No organizations found</h3>
          <p class="mt-1 text-sm text-base-content/70">
            <%= if @search != "" or @filter_status != "all" or @filter_plan != "all" do %>
              Try adjusting your search or filter criteria
            <% else %>
              Get started by creating a new organization
            <% end %>
          </p>
        </div>
      <% else %>
        <div class="overflow-x-auto bg-base-100 shadow rounded-lg">
          <table class="table table-zebra">
            <thead>
              <tr>
                <th>Name</th>
                <th>Plan</th>
                <th>Status</th>
                <th>Users</th>
                <th>API Calls</th>
                <th>Verified</th>
                <th class="text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              <%= for org <- @organizations do %>
                <tr>
                  <td>
                    <div class="font-medium">{org.name}</div>
                    <div class="text-xs text-base-content/70">
                      {Calendar.strftime(org.inserted_at, "%Y-%m-%d")}
                    </div>
                  </td>
                  <td>
                    <span class={[
                      "badge badge-sm",
                      plan_badge_class(org.plan_type)
                    ]}>
                      {format_plan(org.plan_type)}
                    </span>
                  </td>
                  <td>
                    <span class={[
                      "badge badge-sm",
                      status_badge_class(org.status)
                    ]}>
                      {format_status(org.status)}
                    </span>
                  </td>
                  <td>
                    {org.current_user_count} / {org.max_users}
                  </td>
                  <td>
                    <div class="text-sm">
                      {format_number(org.api_calls_current_month)}
                    </div>
                    <div class="text-xs text-base-content/70">
                      of {format_number(org.max_api_calls_per_month)}
                    </div>
                  </td>
                  <td>
                    <%= if org.verified do %>
                      <span class="badge badge-xs badge-success">Verified</span>
                    <% else %>
                      <span class="badge badge-xs badge-warning">Unverified</span>
                    <% end %>
                  </td>
                  <td class="text-right">
                    <div class="flex justify-end gap-2">
                      <.link
                        navigate={~p"/dashboard/organizations/#{org.id}"}
                        class="btn btn-ghost btn-sm"
                      >
                        View
                      </.link>
                      <.link
                        navigate={~p"/dashboard/organizations/#{org.id}/edit"}
                        class="btn btn-ghost btn-sm"
                      >
                        Edit
                      </.link>
                      <button
                        phx-click="delete"
                        phx-value-id={org.id}
                        data-confirm="Are you sure you want to delete this organization?"
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

  defp format_number(num) when num >= 1_000_000 do
    "#{Float.round(num / 1_000_000, 1)}M"
  end

  defp format_number(num) when num >= 1_000 do
    "#{Float.round(num / 1_000, 1)}K"
  end

  defp format_number(num), do: to_string(num)
end
