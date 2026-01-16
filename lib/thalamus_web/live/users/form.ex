defmodule ThalamusWeb.Users.Form do
  @moduledoc """
  LiveView for creating and editing users.
  """
  use ThalamusWeb, :live_view

  # Load authenticated user on mount
  on_mount ThalamusWeb.Live.Hooks.LiveAuth

  alias Thalamus.Infrastructure.Persistence.Schemas.{UserSchema, OrganizationSchema}
  alias Thalamus.Repo

  @impl true
  def mount(_params, _session, socket) do
    organizations = Repo.all(OrganizationSchema)

    {:ok,
     socket
     |> assign(:current_path, "/dashboard/users")
     |> assign(:organizations, organizations)
     |> assign(:generated_password, nil)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New User")
    |> assign(:user, %UserSchema{})
    |> assign(:changeset, UserSchema.update_changeset(%UserSchema{}, %{}))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    case Repo.get(UserSchema, id) do
      nil ->
        socket
        |> put_flash(:error, "User not found")
        |> push_navigate(to: ~p"/dashboard/users")

      user ->
        socket
        |> assign(:page_title, "Edit User")
        |> assign(:user, user)
        |> assign(:changeset, UserSchema.update_changeset(user, %{}))
    end
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      socket.assigns.user
      |> UserSchema.update_changeset(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, changeset: changeset)}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    save_user(socket, socket.assigns.live_action, user_params)
  end

  defp save_user(socket, :new, user_params) do
    # Generate a random password
    generated_password = generate_password()
    password_hash = Bcrypt.hash_pwd_salt(generated_password)

    attrs =
      user_params
      |> Map.put("password_hash", password_hash)
      |> Map.put("status", "pending_verification")

    changeset = UserSchema.create_changeset(attrs)

    case Repo.insert(changeset) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> assign(:generated_password, generated_password)
         |> put_flash(:info, "User created successfully. Please save the generated password!")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  defp save_user(socket, :edit, user_params) do
    changeset = UserSchema.update_changeset(socket.assigns.user, user_params)

    case Repo.update(changeset) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "User updated successfully")
         |> push_navigate(to: ~p"/dashboard/users")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  defp generate_password do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8 py-8">
      <%= if @live_action == :new do %>
        <.breadcrumbs items={[
          %{label: "Dashboard", path: "/dashboard"},
          %{label: "Users", path: "/dashboard/users"},
          %{label: "New User", path: nil}
        ]} />
      <% else %>
        <.breadcrumbs items={[
          %{label: "Dashboard", path: "/dashboard"},
          %{label: "Users", path: "/dashboard/users"},
          %{label: @user.name, path: "/dashboard/users/#{@user.id}"},
          %{label: "Edit", path: nil}
        ]} />
      <% end %>
      
    <!-- Header -->
      <div class="mb-8">
        <h1 class="text-2xl font-semibold text-base-content">{@page_title}</h1>
      </div>

      <%= if @generated_password do %>
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
            <h3 class="font-bold">User Created - Password Generated!</h3>
            <div class="text-sm mt-2">
              Please save this password securely and share it with the user. They should change it on first login.
            </div>
            <div class="mt-3 p-3 bg-base-300 rounded font-mono text-sm break-all">
              {@generated_password}
            </div>
            <div class="mt-3">
              <.link navigate={~p"/dashboard/users"} class="btn btn-sm btn-primary">
                Continue to Users List
              </.link>
            </div>
          </div>
        </div>
      <% end %>

      <.form :let={f} for={@changeset} phx-change="validate" phx-submit="save" class="space-y-6">
        <!-- Basic Information -->
        <div class="card bg-base-100 shadow">
          <div class="card-body">
            <h3 class="card-title text-lg mb-4">Basic Information</h3>

            <div class="space-y-4">
              <div class="form-control">
                <label class="label">
                  <span class="label-text">Email *</span>
                </label>
                <input
                  type="email"
                  name="user[email]"
                  value={Phoenix.HTML.Form.input_value(f, :email)}
                  class="input input-bordered w-full"
                  placeholder="user@example.com"
                  required
                />
              </div>

              <div class="form-control">
                <label class="label">
                  <span class="label-text">Full Name</span>
                </label>
                <input
                  type="text"
                  name="user[name]"
                  value={Phoenix.HTML.Form.input_value(f, :name)}
                  class="input input-bordered w-full"
                  placeholder="John Doe"
                />
              </div>

              <div class="form-control">
                <label class="label">
                  <span class="label-text">Organization</span>
                </label>
                <select name="user[organization_id]" class="select select-bordered w-full">
                  <option value="">No organization</option>
                  <%= for org <- @organizations do %>
                    <option
                      value={org.id}
                      selected={Phoenix.HTML.Form.input_value(f, :organization_id) == org.id}
                    >
                      {org.name}
                    </option>
                  <% end %>
                </select>
              </div>

              <%= if @live_action == :edit do %>
                <div class="form-control">
                  <label class="label">
                    <span class="label-text">Status</span>
                  </label>
                  <select name="user[status]" class="select select-bordered w-full">
                    <option
                      value="pending_verification"
                      selected={Phoenix.HTML.Form.input_value(f, :status) == :pending_verification}
                    >
                      Pending Verification
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
                      value="deactivated"
                      selected={Phoenix.HTML.Form.input_value(f, :status) == :deactivated}
                    >
                      Deactivated
                    </option>
                  </select>
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
              A random secure password will be generated for this user. The user should change it on first login.
            </span>
          </div>
        <% end %>
        
    <!-- Actions -->
        <div class="flex justify-end gap-3">
          <.link navigate={~p"/dashboard/users"} class="btn btn-ghost">
            Cancel
          </.link>
          <button type="submit" phx-disable-with="Saving..." class="btn btn-primary">
            {if @live_action == :new, do: "Create User", else: "Update User"}
          </button>
        </div>
      </.form>
    </div>
    """
  end
end
