defmodule ThalamusWeb.Users.Show do
  @moduledoc """
  LiveView for showing user details.
  """
  use ThalamusWeb, :live_view

  # Load authenticated user on mount
  on_mount ThalamusWeb.Live.Hooks.LiveAuth

  import Ecto.Query

  alias Thalamus.Repo
  alias Thalamus.Infrastructure.Persistence.Schemas.{UserSchema, TokenSchema}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_path, "/dashboard/users")
     |> assign(:new_password, nil)}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    case Repo.get(UserSchema, id) |> Repo.preload(:organization) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "User not found")
         |> push_navigate(to: ~p"/dashboard/users")}

      user ->
        {:noreply,
         socket
         |> assign(:page_title, "User Details")
         |> assign(:user, user)
         |> load_stats(user)}
    end
  end

  @impl true
  def handle_event("reset_password", _params, socket) do
    # Generate new password
    new_password = generate_password()
    password_hash = Bcrypt.hash_pwd_salt(new_password)

    changeset = UserSchema.password_changeset(socket.assigns.user, password_hash)

    case Repo.update(changeset) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(:user, updated_user)
         |> assign(:new_password, new_password)
         |> put_flash(:info, "Password reset successfully!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to reset password")}
    end
  end

  @impl true
  def handle_event("verify_email", _params, socket) do
    changeset = UserSchema.verify_email_changeset(socket.assigns.user)

    case Repo.update(changeset) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(:user, updated_user)
         |> put_flash(:info, "Email verified successfully!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to verify email")}
    end
  end

  @impl true
  def handle_event("suspend", _params, socket) do
    changeset = UserSchema.suspend_changeset(socket.assigns.user)

    case Repo.update(changeset) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(:user, updated_user)
         |> put_flash(:info, "User suspended")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to suspend user")}
    end
  end

  @impl true
  def handle_event("reactivate", _params, socket) do
    changeset = UserSchema.reactivate_changeset(socket.assigns.user)

    case Repo.update(changeset) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(:user, updated_user)
         |> put_flash(:info, "User reactivated")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to reactivate user")}
    end
  end

  defp load_stats(socket, user) do
    # Get token stats
    token_stats =
      TokenSchema
      |> where([t], t.user_id == ^user.id)
      |> select([t], %{
        total: count(t.id),
        active:
          fragment("COUNT(CASE WHEN ? = false AND ? > NOW() THEN 1 END)", t.revoked, t.expires_at),
        revoked: fragment("COUNT(CASE WHEN ? = true THEN 1 END)", t.revoked)
      })
      |> Repo.one()

    # Get recent tokens
    recent_tokens =
      TokenSchema
      |> where([t], t.user_id == ^user.id)
      |> order_by([t], desc: t.inserted_at)
      |> limit(5)
      |> Repo.all()

    socket
    |> assign(:token_stats, token_stats || %{total: 0, active: 0, revoked: 0})
    |> assign(:recent_tokens, recent_tokens)
  end

  defp generate_password do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8 py-8">
      <.breadcrumbs items={[
        %{label: "Dashboard", path: "/dashboard"},
        %{label: "Users", path: "/dashboard/users"},
        %{label: @user.name, path: nil}
      ]} />
      
    <!-- Header -->
      <div class="mb-8">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-semibold text-base-content">{@user.name || @user.email}</h1>
            <p class="text-sm text-base-content/70 mt-1">
              <code class="font-mono">{@user.email}</code>
            </p>
          </div>
          <div class="flex gap-2 items-center">
            <.link navigate={~p"/dashboard/users"} class="btn btn-sm btn-ghost">
              Back to Users
            </.link>
            <.link navigate={~p"/dashboard/users/#{@user.id}/edit"} class="btn btn-sm btn-ghost">
              Edit
            </.link>
            <span class={[
              "badge",
              status_badge_class(@user.status)
            ]}>
              {format_status(@user.status)}
            </span>
          </div>
        </div>
      </div>

      <%= if @new_password do %>
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
            <h3 class="font-bold">New Password Generated!</h3>
            <div class="text-sm mt-2">
              Please save this password securely and share it with the user.
            </div>
            <div class="mt-3 p-3 bg-base-300 rounded font-mono text-sm break-all">
              {@new_password}
            </div>
          </div>
        </div>
      <% end %>
      
    <!-- Stats Cards -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-8">
        <div class="stat bg-base-100 shadow rounded-lg">
          <div class="stat-title">Total Tokens</div>
          <div class="stat-value text-primary">{@token_stats.total}</div>
        </div>
        <div class="stat bg-base-100 shadow rounded-lg">
          <div class="stat-title">Active Tokens</div>
          <div class="stat-value text-success">{@token_stats.active}</div>
        </div>
        <div class="stat bg-base-100 shadow rounded-lg">
          <div class="stat-title">Revoked</div>
          <div class="stat-value text-error">{@token_stats.revoked}</div>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <!-- User Information -->
        <div class="card bg-base-100 shadow">
          <div class="card-body">
            <h2 class="card-title">User Information</h2>

            <div class="space-y-4">
              <div>
                <label class="text-xs text-base-content/70 uppercase">Email</label>
                <p class="font-medium">{@user.email}</p>
              </div>

              <%= if @user.name do %>
                <div>
                  <label class="text-xs text-base-content/70 uppercase">Full Name</label>
                  <p class="font-medium">{@user.name}</p>
                </div>
              <% end %>

              <div>
                <label class="text-xs text-base-content/70 uppercase">Organization</label>
                <p class="font-medium">
                  <%= if @user.organization do %>
                    {@user.organization.name}
                  <% else %>
                    <span class="text-base-content/50">No organization</span>
                  <% end %>
                </p>
              </div>

              <div>
                <label class="text-xs text-base-content/70 uppercase">Status</label>
                <p class="font-medium">{format_status(@user.status)}</p>
              </div>

              <div>
                <label class="text-xs text-base-content/70 uppercase">Email Verified</label>
                <p class="font-medium">
                  <%= if @user.verified_at do %>
                    Yes - {Calendar.strftime(@user.verified_at, "%Y-%m-%d %H:%M")}
                  <% else %>
                    <span class="text-warning">No</span>
                  <% end %>
                </p>
              </div>

              <div>
                <label class="text-xs text-base-content/70 uppercase">Last Login</label>
                <p class="font-medium">
                  <%= if @user.last_login_at do %>
                    {Calendar.strftime(@user.last_login_at, "%Y-%m-%d %H:%M")}
                  <% else %>
                    <span class="text-base-content/50">Never</span>
                  <% end %>
                </p>
              </div>

              <div>
                <label class="text-xs text-base-content/70 uppercase">Created</label>
                <p class="font-medium">{Calendar.strftime(@user.inserted_at, "%Y-%m-%d %H:%M")}</p>
              </div>

              <div class="divider"></div>
              
    <!-- Actions -->
              <div class="space-y-2">
                <%= if @user.status == :pending_verification do %>
                  <button phx-click="verify_email" class="btn btn-success btn-sm w-full">
                    Verify Email
                  </button>
                <% end %>

                <button
                  phx-click="reset_password"
                  data-confirm="Are you sure you want to reset this user's password?"
                  class="btn btn-warning btn-sm w-full"
                >
                  Reset Password
                </button>

                <%= if @user.status == :active do %>
                  <button
                    phx-click="suspend"
                    data-confirm="Are you sure you want to suspend this user?"
                    class="btn btn-error btn-sm w-full"
                  >
                    Suspend User
                  </button>
                <% end %>

                <%= if @user.status == :suspended do %>
                  <button
                    phx-click="reactivate"
                    class="btn btn-success btn-sm w-full"
                  >
                    Reactivate User
                  </button>
                <% end %>
              </div>
            </div>
          </div>
        </div>
        
    <!-- Security & MFA -->
        <div class="card bg-base-100 shadow">
          <div class="card-body">
            <h2 class="card-title">Security & MFA</h2>

            <div class="space-y-4">
              <div>
                <label class="text-xs text-base-content/70 uppercase">Failed Login Attempts</label>
                <p class="font-medium">{@user.failed_login_attempts}</p>
              </div>

              <%= if @user.locked_until do %>
                <div>
                  <label class="text-xs text-base-content/70 uppercase">Account Locked Until</label>
                  <p class="font-medium text-error">
                    {Calendar.strftime(@user.locked_until, "%Y-%m-%d %H:%M")}
                  </p>
                </div>
              <% end %>

              <div>
                <label class="text-xs text-base-content/70 uppercase">MFA Methods</label>
                <%= if @user.mfa_methods && length(@user.mfa_methods) > 0 do %>
                  <div class="space-y-2 mt-2">
                    <%= for method <- @user.mfa_methods do %>
                      <div class="badge badge-info gap-2">
                        {method["type"]} - {method["identifier"]}
                      </div>
                    <% end %>
                  </div>
                <% else %>
                  <p class="text-base-content/50">No MFA methods configured</p>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </div>
      
    <!-- Recent Tokens -->
      <div class="card bg-base-100 shadow mt-6">
        <div class="card-body">
          <h2 class="card-title">Recent Tokens</h2>

          <%= if @recent_tokens == [] do %>
            <p class="text-center text-base-content/70 py-8">No tokens issued yet</p>
          <% else %>
            <div class="overflow-x-auto">
              <table class="table table-sm">
                <thead>
                  <tr>
                    <th>Type</th>
                    <th>Client</th>
                    <th>Scopes</th>
                    <th>Created</th>
                    <th>Expires</th>
                    <th>Status</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for token <- @recent_tokens do %>
                    <tr>
                      <td>
                        <span class="badge badge-sm">{token.type}</span>
                      </td>
                      <td class="font-mono text-xs">
                        <%= if token.client_id do %>
                          {String.slice(to_string(token.client_id), 0..10)}...
                        <% else %>
                          <span class="text-base-content/50">-</span>
                        <% end %>
                      </td>
                      <td class="text-xs">
                        {Enum.join(Enum.take(token.scopes || [], 2), ", ")}{if length(
                                                                                 token.scopes || []
                                                                               ) > 2,
                                                                               do: "..."}
                      </td>
                      <td class="text-xs text-base-content/70">
                        {Calendar.strftime(token.inserted_at, "%Y-%m-%d %H:%M")}
                      </td>
                      <td class="text-xs text-base-content/70">
                        {Calendar.strftime(token.expires_at, "%Y-%m-%d %H:%M")}
                      </td>
                      <td>
                        <%= if token.revoked do %>
                          <span class="badge badge-sm badge-error">Revoked</span>
                        <% else %>
                          <%= if DateTime.compare(token.expires_at, DateTime.utc_now()) == :gt do %>
                            <span class="badge badge-sm badge-success">Active</span>
                          <% else %>
                            <span class="badge badge-sm badge-warning">Expired</span>
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

  # Helper functions

  defp status_badge_class(:active), do: "badge-success"
  defp status_badge_class(:pending_verification), do: "badge-warning"
  defp status_badge_class(:suspended), do: "badge-error"
  defp status_badge_class(:deactivated), do: "badge-ghost"

  defp format_status(:active), do: "Active"
  defp format_status(:pending_verification), do: "Pending Verification"
  defp format_status(:suspended), do: "Suspended"
  defp format_status(:deactivated), do: "Deactivated"
end
