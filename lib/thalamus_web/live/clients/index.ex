defmodule ThalamusWeb.Clients.Index do
  @moduledoc """
  LiveView for listing and managing OAuth2 clients.
  """
  use ThalamusWeb, :live_view

  import Ecto.Query

  alias Thalamus.Repo
  alias Thalamus.Infrastructure.Persistence.Schemas.OAuth2ClientSchema

  # Load authenticated user on mount
  on_mount ThalamusWeb.Live.Hooks.LiveAuth

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "OAuth2 Clients")
     |> assign(:current_path, "/dashboard/clients")
     |> assign(:search_query, "")
     |> assign(:filter_active, :all)
     |> load_clients()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    case Repo.get_by(OAuth2ClientSchema, client_id_string: id) do
      nil ->
        socket
        |> put_flash(:error, "Client not found")
        |> push_navigate(to: ~p"/dashboard/clients")

      client ->
        socket
        |> assign(:page_title, "Edit Client")
        |> assign(:client, client)
    end
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Client")
    |> assign(:client, %OAuth2ClientSchema{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "OAuth2 Clients")
    |> assign(:client, nil)
  end

  @impl true
  def handle_event("search", %{"search" => query}, socket) do
    {:noreply,
     socket
     |> assign(:search_query, query)
     |> load_clients()}
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
     |> load_clients()}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    # Find the client schema by client_id_string
    case Repo.get_by(OAuth2ClientSchema, client_id_string: id) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "Client not found")
         |> load_clients()}

      client ->
        case Repo.delete(client) do
          {:ok, _deleted} ->
            {:noreply,
             socket
             |> put_flash(:info, "Client deleted successfully")
             |> load_clients()}

          {:error, _changeset} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to delete client")
             |> load_clients()}
        end
    end
  end

  defp load_clients(socket) do
    search = socket.assigns.search_query
    filter = socket.assigns.filter_active
    organization = socket.assigns.current_organization

    clients =
      OAuth2ClientSchema
      |> apply_organization_filter(organization)
      |> apply_search_filter(search)
      |> apply_active_filter(filter)
      |> order_by([c], desc: c.inserted_at)
      |> Repo.all()
      |> Enum.map(&format_client/1)

    assign(socket, :clients, clients)
  end

  defp apply_organization_filter(query, nil), do: where(query, [c], false)

  defp apply_organization_filter(query, organization) do
    where(query, [c], c.organization_id == ^organization.id)
  end

  defp apply_search_filter(query, "") do
    query
  end

  defp apply_search_filter(query, search) do
    search_pattern = "%#{search}%"

    where(
      query,
      [c],
      ilike(c.name, ^search_pattern) or
        ilike(c.client_id_string, ^search_pattern)
    )
  end

  defp apply_active_filter(query, :all), do: query
  defp apply_active_filter(query, :active), do: where(query, [c], c.is_active == true)
  defp apply_active_filter(query, :inactive), do: where(query, [c], c.is_active == false)

  defp format_client(schema) do
    %{
      id: schema.id,
      client_id: schema.client_id_string,
      name: schema.name,
      client_type: schema.client_type,
      is_active: schema.is_active,
      grant_types: schema.allowed_grant_types || [],
      scopes: schema.allowed_scopes || [],
      redirect_uris: schema.redirect_uris || [],
      created_at: schema.inserted_at
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8 py-8">
      <.breadcrumbs items={[
        %{label: "Dashboard", path: "/dashboard"},
        %{label: "OAuth2 Clients", path: nil}
      ]} />
      
    <!-- Header -->
      <div class="sm:flex sm:items-center sm:justify-between">
        <div class="sm:flex-auto">
          <h1 class="text-2xl font-semibold text-base-content">OAuth2 Clients</h1>
          <p class="mt-2 text-sm text-base-content/70">
            Manage OAuth2 client applications and their permissions
          </p>
        </div>
        <div class="mt-4 sm:ml-16 sm:mt-0 sm:flex-none">
          <.link
            navigate="/dashboard/clients/new"
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
            New Client
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
              placeholder="Search by name or client ID..."
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
              <option value="all" selected={@filter_active == :all}>All Clients</option>
              <option value="active" selected={@filter_active == :active}>Active Only</option>
              <option value="inactive" selected={@filter_active == :inactive}>
                Inactive Only
              </option>
            </select>
          </form>
        </div>
      </div>
      
    <!-- Clients Table -->
      <div class="mt-8 flow-root">
        <div class="card bg-base-100 shadow">
          <div class="card-body p-0">
            <%= if @clients == [] do %>
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
                <h3 class="mt-2 text-sm font-medium text-base-content">No clients found</h3>
                <p class="mt-1 text-sm text-base-content/70">
                  Get started by creating a new OAuth2 client.
                </p>
                <div class="mt-6">
                  <.link navigate="/dashboard/clients/new" class="btn btn-primary">
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
                    New Client
                  </.link>
                </div>
              </div>
            <% else %>
              <div class="overflow-x-auto">
                <table class="table table-sm">
                  <thead>
                    <tr>
                      <th>Name</th>
                      <th>Client ID</th>
                      <th>Type</th>
                      <th>Grant Types</th>
                      <th>Status</th>
                      <th>Created</th>
                      <th class="text-right">Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for client <- @clients do %>
                      <tr>
                        <td>
                          <div class="font-medium text-base-content">
                            {client.name}
                          </div>
                        </td>
                        <td>
                          <code class="text-xs font-mono text-base-content/70">
                            {String.slice(client.client_id, 0..15)}...
                          </code>
                        </td>
                        <td>
                          <span class="badge badge-sm badge-ghost">
                            {client.client_type}
                          </span>
                        </td>
                        <td class="text-xs">
                          <%= if client.grant_types == [] do %>
                            <span class="text-base-content/50">none</span>
                          <% else %>
                            {Enum.join(Enum.take(client.grant_types, 2), ", ")}{if length(
                                                                                     client.grant_types
                                                                                   ) > 2,
                                                                                   do: "..."}
                          <% end %>
                        </td>
                        <td>
                          <%= if client.is_active do %>
                            <span class="badge badge-sm badge-success">Active</span>
                          <% else %>
                            <span class="badge badge-sm badge-error">Inactive</span>
                          <% end %>
                        </td>
                        <td class="text-xs text-base-content/70">
                          {Calendar.strftime(client.created_at, "%Y-%m-%d")}
                        </td>
                        <td class="text-right">
                          <div class="flex justify-end gap-2">
                            <.link
                              navigate={"/dashboard/clients/#{client.client_id}"}
                              class="btn btn-ghost btn-xs"
                            >
                              View
                            </.link>
                            <.link
                              navigate={"/dashboard/clients/#{client.client_id}/edit"}
                              class="btn btn-ghost btn-xs"
                            >
                              Edit
                            </.link>
                            <button
                              phx-click="delete"
                              phx-value-id={client.client_id}
                              data-confirm="Are you sure you want to delete this client?"
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
