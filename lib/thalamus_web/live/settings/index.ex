defmodule ThalamusWeb.Settings.Index do
  @moduledoc """
  LiveView for user settings and preferences.
  """
  use ThalamusWeb, :live_view

  # Load authenticated user on mount
  on_mount ThalamusWeb.Live.Hooks.LiveAuth

  alias Thalamus.Repo
  alias Thalamus.Infrastructure.Persistence.Schemas.UserSchema

  @impl true
  def mount(_params, session, socket) do
    # Get user from session
    user_id = session["user_id"]

    case load_user(user_id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "User not found")
         |> push_navigate(to: ~p"/login")}

      user ->
        {:ok,
         socket
         |> assign(:page_title, "Settings")
         |> assign(:current_path, "/dashboard/settings")
         |> assign(:user, user)
         |> assign(:active_tab, "profile")
         |> assign(
           :profile_form,
           to_form(%{"full_name" => user.full_name, "email" => user.email})
         )
         |> assign(:password_form, to_form(%{}))
         |> assign(:password_changed, false)}
    end
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("update_profile", %{"profile" => params}, socket) do
    user = Repo.get!(UserSchema, socket.assigns.user.id)

    case update_profile(user, params) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(:user, format_user(updated_user))
         |> put_flash(:info, "Profile updated successfully")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update profile: #{format_errors(changeset)}")}
    end
  end

  @impl true
  def handle_event("change_password", %{"password" => params}, socket) do
    user = Repo.get!(UserSchema, socket.assigns.user.id)

    current_password = params["current_password"]
    new_password = params["new_password"]
    confirm_password = params["confirm_password"]

    cond do
      !Bcrypt.verify_pass(current_password, user.password_hash) ->
        {:noreply,
         socket
         |> put_flash(:error, "Current password is incorrect")}

      new_password != confirm_password ->
        {:noreply,
         socket
         |> put_flash(:error, "New passwords do not match")}

      String.length(new_password) < 8 ->
        {:noreply,
         socket
         |> put_flash(:error, "New password must be at least 8 characters long")}

      true ->
        changeset = UserSchema.password_changeset(user, %{"password" => new_password})

        case Repo.update(changeset) do
          {:ok, _updated} ->
            {:noreply,
             socket
             |> assign(:password_changed, true)
             |> assign(:password_form, to_form(%{}))
             |> put_flash(:info, "Password changed successfully")}

          {:error, changeset} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to change password: #{format_errors(changeset)}")}
        end
    end
  end

  @impl true
  def handle_event("enable_mfa", _params, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "MFA setup - Coming soon")}
  end

  @impl true
  def handle_event("disable_mfa", _params, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "MFA disabled - Coming soon")}
  end

  defp load_user(user_id) do
    case Repo.get(UserSchema, user_id) do
      nil -> nil
      user -> format_user(user)
    end
  end

  defp format_user(schema) do
    %{
      id: schema.id,
      email: schema.email,
      full_name: schema.full_name,
      mfa_enabled: schema.mfa_enabled || false,
      status: schema.status,
      created_at: schema.inserted_at
    }
  end

  defp update_profile(user, params) do
    changeset =
      user
      |> Ecto.Changeset.cast(params, [:full_name, :email])
      |> Ecto.Changeset.validate_required([:email])
      |> Ecto.Changeset.validate_format(:email, ~r/^[^\s]+@[^\s]+$/,
        message: "must be a valid email"
      )

    Repo.update(changeset)
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
    |> Enum.map(fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
    |> Enum.join("; ")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8 py-8">
      <.breadcrumbs items={[
        %{label: "Dashboard", path: "/dashboard"},
        %{label: "Settings", path: nil}
      ]} />
      
    <!-- Header -->
      <div class="sm:flex sm:items-center sm:justify-between mb-6">
        <div class="sm:flex-auto">
          <h1 class="text-2xl font-semibold text-base-content">Settings</h1>
          <p class="mt-2 text-sm text-base-content/70">
            Manage your account settings and preferences
          </p>
        </div>
      </div>
      
    <!-- Tabs -->
      <div class="tabs tabs-boxed bg-base-100 mb-6">
        <a
          phx-click="switch_tab"
          phx-value-tab="profile"
          class={"tab " <> if(@active_tab == "profile", do: "tab-active", else: "")}
        >
          <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
            />
          </svg>
          Profile
        </a>
        <a
          phx-click="switch_tab"
          phx-value-tab="security"
          class={"tab " <> if(@active_tab == "security", do: "tab-active", else: "")}
        >
          <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"
            />
          </svg>
          Security
        </a>
        <a
          phx-click="switch_tab"
          phx-value-tab="preferences"
          class={"tab " <> if(@active_tab == "preferences", do: "tab-active", else: "")}
        >
          <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"
            />
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
            />
          </svg>
          Preferences
        </a>
      </div>
      
    <!-- Profile Tab -->
      <%= if @active_tab == "profile" do %>
        <div class="card bg-base-100 shadow">
          <div class="card-body">
            <h2 class="card-title text-lg mb-4">Profile Information</h2>

            <form phx-submit="update_profile">
              <div class="form-control">
                <label class="label">
                  <span class="label-text font-semibold">Full Name</span>
                </label>
                <input
                  type="text"
                  name="profile[full_name]"
                  value={@profile_form.params["full_name"]}
                  class="input input-bordered"
                  placeholder="Enter your full name"
                />
              </div>

              <div class="form-control mt-4">
                <label class="label">
                  <span class="label-text font-semibold">Email<span class="text-error">*</span></span>
                </label>
                <input
                  type="email"
                  name="profile[email]"
                  value={@profile_form.params["email"]}
                  class="input input-bordered"
                  required
                />
              </div>

              <div class="alert alert-info mt-6">
                <svg
                  class="h-5 w-5"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
                <span class="text-sm">
                  Your account was created on {Calendar.strftime(
                    @user.created_at,
                    "%B %d, %Y"
                  )}
                </span>
              </div>

              <div class="card-actions justify-end mt-6">
                <button type="submit" class="btn btn-primary">
                  Save Changes
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>
      <!-- Security Tab -->
      <%= if @active_tab == "security" do %>
        <div class="space-y-6">
          <!-- Change Password -->
          <div class="card bg-base-100 shadow">
            <div class="card-body">
              <h2 class="card-title text-lg mb-4">Change Password</h2>

              <%= if @password_changed do %>
                <div class="alert alert-success mb-4">
                  <svg
                    class="h-5 w-5"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                    />
                  </svg>
                  <span>Password changed successfully!</span>
                </div>
              <% end %>

              <form phx-submit="change_password">
                <div class="form-control">
                  <label class="label">
                    <span class="label-text font-semibold">Current Password</span>
                  </label>
                  <input
                    type="password"
                    name="password[current_password]"
                    class="input input-bordered"
                    required
                    autocomplete="current-password"
                  />
                </div>

                <div class="form-control mt-4">
                  <label class="label">
                    <span class="label-text font-semibold">New Password</span>
                  </label>
                  <input
                    type="password"
                    name="password[new_password]"
                    class="input input-bordered"
                    required
                    autocomplete="new-password"
                  />
                  <label class="label">
                    <span class="label-text-alt">At least 8 characters</span>
                  </label>
                </div>

                <div class="form-control mt-4">
                  <label class="label">
                    <span class="label-text font-semibold">Confirm New Password</span>
                  </label>
                  <input
                    type="password"
                    name="password[confirm_password]"
                    class="input input-bordered"
                    required
                    autocomplete="new-password"
                  />
                </div>

                <div class="card-actions justify-end mt-6">
                  <button type="submit" class="btn btn-primary">
                    Change Password
                  </button>
                </div>
              </form>
            </div>
          </div>
          <!-- MFA Settings -->
          <div class="card bg-base-100 shadow">
            <div class="card-body">
              <h2 class="card-title text-lg mb-4">Multi-Factor Authentication (MFA)</h2>

              <p class="text-sm text-base-content/70 mb-4">
                Add an extra layer of security to your account by enabling multi-factor authentication.
              </p>

              <div class="flex items-center justify-between">
                <div>
                  <div class="font-medium">Status</div>
                  <%= if @user.mfa_enabled do %>
                    <span class="badge badge-success mt-1">Enabled</span>
                  <% else %>
                    <span class="badge badge-ghost mt-1">Disabled</span>
                  <% end %>
                </div>
                <div>
                  <%= if @user.mfa_enabled do %>
                    <button phx-click="disable_mfa" class="btn btn-warning">
                      Disable MFA
                    </button>
                  <% else %>
                    <button phx-click="enable_mfa" class="btn btn-primary">
                      Enable MFA
                    </button>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
        </div>
      <% end %>
      <!-- Preferences Tab -->
      <%= if @active_tab == "preferences" do %>
        <div class="card bg-base-100 shadow">
          <div class="card-body">
            <h2 class="card-title text-lg mb-4">Appearance</h2>

            <div class="form-control">
              <label class="label">
                <span class="label-text font-semibold">Theme</span>
              </label>
              <div class="flex gap-4">
                <button
                  phx-click={JS.dispatch("phx:set-theme", to: "html")}
                  data-phx-theme="light"
                  class="btn btn-outline flex-1"
                >
                  <svg class="h-5 w-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z"
                    />
                  </svg>
                  Light
                </button>
                <button
                  phx-click={JS.dispatch("phx:set-theme", to: "html")}
                  data-phx-theme="dark"
                  class="btn btn-outline flex-1"
                >
                  <svg class="h-5 w-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z"
                    />
                  </svg>
                  Dark
                </button>
                <button
                  phx-click={JS.dispatch("phx:set-theme", to: "html")}
                  data-phx-theme="system"
                  class="btn btn-outline flex-1"
                >
                  <svg class="h-5 w-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
                    />
                  </svg>
                  System
                </button>
              </div>
            </div>

            <div class="alert alert-info mt-6">
              <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                />
              </svg>
              <span class="text-sm">
                Theme changes are saved automatically and apply across all your devices.
              </span>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
