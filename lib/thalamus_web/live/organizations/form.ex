defmodule ThalamusWeb.Organizations.Form do
  @moduledoc """
  LiveView for creating and editing organizations.
  """
  use ThalamusWeb, :live_view

  # Load authenticated user on mount
  on_mount ThalamusWeb.Live.Hooks.LiveAuth

  alias Thalamus.Infrastructure.Persistence.Schemas.OrganizationSchema
  alias Thalamus.Repo

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_path, "/dashboard/organizations")}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Organization")
    |> assign(:organization, %OrganizationSchema{})
    |> assign(:changeset, OrganizationSchema.create_changeset(%{}))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    case Repo.get(OrganizationSchema, id) do
      nil ->
        socket
        |> put_flash(:error, "Organization not found")
        |> push_navigate(to: ~p"/dashboard/organizations")

      organization ->
        socket
        |> assign(:page_title, "Edit Organization")
        |> assign(:organization, organization)
        |> assign(:changeset, OrganizationSchema.update_changeset(organization, %{}))
    end
  end

  @impl true
  def handle_event("validate", %{"organization" => org_params}, socket) do
    changeset =
      case socket.assigns.live_action do
        :new ->
          OrganizationSchema.create_changeset(org_params)
          |> Map.put(:action, :validate)

        :edit ->
          OrganizationSchema.update_changeset(socket.assigns.organization, org_params)
          |> Map.put(:action, :validate)
      end

    {:noreply, assign(socket, changeset: changeset)}
  end

  @impl true
  def handle_event("save", %{"organization" => org_params}, socket) do
    save_organization(socket, socket.assigns.live_action, org_params)
  end

  defp save_organization(socket, :new, org_params) do
    changeset = OrganizationSchema.create_changeset(org_params)

    case Repo.insert(changeset) do
      {:ok, _organization} ->
        {:noreply,
         socket
         |> put_flash(:info, "Organization created successfully")
         |> push_navigate(to: ~p"/dashboard/organizations")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  defp save_organization(socket, :edit, org_params) do
    changeset = OrganizationSchema.update_changeset(socket.assigns.organization, org_params)

    case Repo.update(changeset) do
      {:ok, _organization} ->
        {:noreply,
         socket
         |> put_flash(:info, "Organization updated successfully")
         |> push_navigate(to: ~p"/dashboard/organizations")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8 py-8">
      <%= if @live_action == :new do %>
        <.breadcrumbs items={[
          %{label: "Dashboard", path: "/dashboard"},
          %{label: "Organizations", path: "/dashboard/organizations"},
          %{label: "New Organization", path: nil}
        ]} />
      <% else %>
        <.breadcrumbs items={[
          %{label: "Dashboard", path: "/dashboard"},
          %{label: "Organizations", path: "/dashboard/organizations"},
          %{label: @organization.name, path: "/dashboard/organizations/#{@organization.id}"},
          %{label: "Edit", path: nil}
        ]} />
      <% end %>
      
    <!-- Header -->
      <div class="mb-8">
        <h1 class="text-2xl font-semibold text-base-content">{@page_title}</h1>
      </div>

      <.form :let={f} for={@changeset} phx-change="validate" phx-submit="save" class="space-y-6">
        <!-- Basic Information -->
        <div class="card bg-base-100 shadow">
          <div class="card-body">
            <h3 class="card-title text-lg mb-4">Basic Information</h3>

            <div class="space-y-4">
              <div class="form-control">
                <label class="label">
                  <span class="label-text">Organization Name *</span>
                </label>
                <input
                  type="text"
                  name="organization[name]"
                  value={Phoenix.HTML.Form.input_value(f, :name)}
                  class="input input-bordered w-full"
                  placeholder="Acme Corporation"
                  required
                />
              </div>

              <div class="form-control">
                <label class="label">
                  <span class="label-text">Plan Type</span>
                </label>
                <select name="organization[plan_type]" class="select select-bordered w-full">
                  <option
                    value="free"
                    selected={Phoenix.HTML.Form.input_value(f, :plan_type) == :free}
                  >
                    Free - 5 users, 10K API calls/month
                  </option>
                  <option
                    value="basic"
                    selected={Phoenix.HTML.Form.input_value(f, :plan_type) == :basic}
                  >
                    Basic - 10 users, 50K API calls/month
                  </option>
                  <option
                    value="standard"
                    selected={Phoenix.HTML.Form.input_value(f, :plan_type) == :standard}
                  >
                    Standard - 100 users, 500K API calls/month
                  </option>
                  <option
                    value="premium"
                    selected={Phoenix.HTML.Form.input_value(f, :plan_type) == :premium}
                  >
                    Premium - 500 users, 5M API calls/month
                  </option>
                  <option
                    value="enterprise"
                    selected={Phoenix.HTML.Form.input_value(f, :plan_type) == :enterprise}
                  >
                    Enterprise - Unlimited users and API calls
                  </option>
                </select>
              </div>

              <%= if @live_action == :edit do %>
                <div class="form-control">
                  <label class="label">
                    <span class="label-text">Status</span>
                  </label>
                  <select name="organization[status]" class="select select-bordered w-full">
                    <option
                      value="trial"
                      selected={Phoenix.HTML.Form.input_value(f, :status) == :trial}
                    >
                      Trial
                    </option>
                    <option
                      value="active"
                      selected={Phoenix.HTML.Form.input_value(f, :status) == :active}
                    >
                      Active
                    </option>
                    <option
                      value="suspended"
                      selected={Phoenix.HTML.Form.input_value(f, :status) == :suspended}
                    >
                      Suspended
                    </option>
                    <option
                      value="cancelled"
                      selected={Phoenix.HTML.Form.input_value(f, :status) == :cancelled}
                    >
                      Cancelled
                    </option>
                  </select>
                </div>

                <div class="form-control">
                  <label class="label cursor-pointer">
                    <span class="label-text">Verified</span>
                    <input
                      type="checkbox"
                      name="organization[verified]"
                      class="checkbox"
                      checked={Phoenix.HTML.Form.input_value(f, :verified)}
                    />
                  </label>
                </div>
              <% end %>
            </div>
          </div>
        </div>

        <%= if @live_action == :new do %>
          <div class="alert alert-info">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              class="stroke-current shrink-0 w-6 h-6"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
              />
            </svg>
            <span>
              The organization will start in Trial mode. Plan limits will be applied automatically based on the selected plan.
            </span>
          </div>
        <% end %>
        
    <!-- Actions -->
        <div class="flex justify-end gap-3">
          <.link navigate={~p"/dashboard/organizations"} class="btn btn-ghost">
            Cancel
          </.link>
          <button type="submit" phx-disable-with="Saving..." class="btn btn-primary">
            {if @live_action == :new, do: "Create Organization", else: "Update Organization"}
          </button>
        </div>
      </.form>
    </div>
    """
  end
end
