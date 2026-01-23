defmodule ThalamusWeb.Clients.FormComponent do
  @moduledoc """
  Form component for creating and editing OAuth2 clients.
  """
  use ThalamusWeb, :live_component

  alias Thalamus.Infrastructure.Persistence.Schemas.OAuth2ClientSchema
  alias Thalamus.Repo

  @impl true
  def update(%{client: client} = assigns, socket) do
    changeset = change_client(client)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)
     |> assign(:client_secret, nil)}
  end

  @impl true
  def handle_event("validate", %{"client" => client_params}, socket) do
    changeset =
      socket.assigns.client
      |> change_client(client_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"client" => client_params}, socket) do
    save_client(socket, socket.assigns.action, client_params)
  end

  defp save_client(socket, :new, client_params) do
    # Generate client_id and client_secret
    client_id = "client_#{Ecto.UUID.generate()}"
    client_secret = generate_client_secret()

    # Get first organization (temporary - should come from current user)
    org = Repo.one(Thalamus.Infrastructure.Persistence.Schemas.OrganizationSchema)

    attrs =
      client_params
      |> Map.put("client_id_string", client_id)
      |> Map.put("client_secret", client_secret)
      |> Map.put("organization_id", org && org.id)
      |> Map.put("is_active", true)

    changeset = OAuth2ClientSchema.create_changeset(attrs)

    case Repo.insert(changeset) do
      {:ok, _client} ->
        {:noreply,
         socket
         |> assign(:client_secret, client_secret)
         |> put_flash(:info, "Client created successfully")
         |> push_navigate(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  defp save_client(socket, :edit, client_params) do
    client = socket.assigns.client

    changeset = OAuth2ClientSchema.update_changeset(client, client_params)

    case Repo.update(changeset) do
      {:ok, _client} ->
        {:noreply,
         socket
         |> put_flash(:info, "Client updated successfully")
         |> push_navigate(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  defp change_client(client, attrs \\ %{}) do
    OAuth2ClientSchema.update_changeset(client, attrs)
  end

  defp generate_client_secret do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form
        :let={f}
        for={@changeset}
        id="client-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="space-y-6">
          <!-- Basic Information -->
          <div class="card bg-base-100 shadow">
            <div class="card-body">
              <h3 class="card-title text-lg">Basic Information</h3>

              <div class="form-control">
                <label class="label">
                  <span class="label-text">Client Name *</span>
                </label>
                <input
                  type="text"
                  name="client[name]"
                  value={Phoenix.HTML.Form.input_value(f, :name)}
                  class="input input-bordered"
                  placeholder="My Application"
                  required
                />
                <%= if error = f[:name].errors do %>
                  <label class="label">
                    <span class="label-text-alt text-error">{translate_error(error)}</span>
                  </label>
                <% end %>
              </div>

              <div class="form-control">
                <label class="label">
                  <span class="label-text">Description</span>
                </label>
                <textarea
                  name="client[description]"
                  class="textarea textarea-bordered"
                  rows="3"
                  placeholder="Brief description of your application"
                ><%= Phoenix.HTML.Form.input_value(f, :description) %></textarea>
              </div>

              <div class="form-control">
                <label class="label">
                  <span class="label-text">Client Type *</span>
                </label>
                <select name="client[client_type]" class="select select-bordered" required>
                  <option value="">Select type...</option>
                  <option
                    value="confidential"
                    selected={Phoenix.HTML.Form.input_value(f, :client_type) == :confidential}
                  >
                    Confidential (Web apps with backend)
                  </option>
                  <option
                    value="public"
                    selected={Phoenix.HTML.Form.input_value(f, :client_type) == :public}
                  >
                    Public (SPAs, mobile apps)
                  </option>
                  <option
                    value="m2m"
                    selected={Phoenix.HTML.Form.input_value(f, :client_type) == :m2m}
                  >
                    Machine-to-Machine
                  </option>
                </select>
              </div>
            </div>
          </div>
          <!-- OAuth2 Configuration -->
          <div class="card bg-base-100 shadow">
            <div class="card-body">
              <h3 class="card-title text-lg">OAuth2 Configuration</h3>

              <div class="form-control">
                <label class="label">
                  <span class="label-text">Grant Types *</span>
                </label>
                <div class="space-y-2">
                  <label class="label cursor-pointer justify-start gap-3">
                    <input
                      type="checkbox"
                      name="client[allowed_grant_types][]"
                      value="authorization_code"
                      checked={
                        "authorization_code" in (Phoenix.HTML.Form.input_value(
                                                   f,
                                                   :allowed_grant_types
                                                 ) ||
                                                   [])
                      }
                      class="checkbox checkbox-primary"
                    />
                    <span class="label-text">Authorization Code</span>
                  </label>
                  <label class="label cursor-pointer justify-start gap-3">
                    <input
                      type="checkbox"
                      name="client[allowed_grant_types][]"
                      value="client_credentials"
                      checked={
                        "client_credentials" in (Phoenix.HTML.Form.input_value(
                                                   f,
                                                   :allowed_grant_types
                                                 ) ||
                                                   [])
                      }
                      class="checkbox checkbox-primary"
                    />
                    <span class="label-text">Client Credentials</span>
                  </label>
                  <label class="label cursor-pointer justify-start gap-3">
                    <input
                      type="checkbox"
                      name="client[allowed_grant_types][]"
                      value="refresh_token"
                      checked={
                        "refresh_token" in (Phoenix.HTML.Form.input_value(f, :allowed_grant_types) ||
                                              [])
                      }
                      class="checkbox checkbox-primary"
                    />
                    <span class="label-text">Refresh Token</span>
                  </label>
                </div>
              </div>

              <div class="form-control">
                <label class="label">
                  <span class="label-text">Redirect URIs</span>
                  <span class="label-text-alt">One per line</span>
                </label>
                <textarea
                  name="client[redirect_uris_text]"
                  class="textarea textarea-bordered font-mono text-xs"
                  rows="4"
                  placeholder="https://example.com/callback\nhttps://example.com/oauth/callback"
                ><%= Enum.join(Phoenix.HTML.Form.input_value(f, :redirect_uris) || [], "\n") %></textarea>
              </div>

              <div class="form-control">
                <label class="label">
                  <span class="label-text">Allowed Scopes</span>
                </label>
                <div class="grid grid-cols-2 gap-2">
                  <%= for scope <- ["openid", "profile", "email", "offline_access", "api:read", "api:write", "data:read", "data:write"] do %>
                    <label class="label cursor-pointer justify-start gap-3">
                      <input
                        type="checkbox"
                        name="client[allowed_scopes][]"
                        value={scope}
                        checked={scope in (Phoenix.HTML.Form.input_value(f, :allowed_scopes) || [])}
                        class="checkbox checkbox-sm"
                      />
                      <span class="label-text text-sm">{scope}</span>
                    </label>
                  <% end %>
                </div>
              </div>

              <div class="form-control">
                <label class="label cursor-pointer justify-start gap-3">
                  <input
                    type="checkbox"
                    name="client[pkce_required]"
                    value="true"
                    checked={Phoenix.HTML.Form.input_value(f, :pkce_required)}
                    class="checkbox checkbox-primary"
                  />
                  <span class="label-text">Require PKCE (Proof Key for Code Exchange)</span>
                </label>
              </div>
            </div>
          </div>
          <!-- Actions -->
          <div class="flex justify-end gap-3">
            <button
              type="button"
              phx-click={JS.navigate(@navigate)}
              class="btn btn-ghost"
            >
              Cancel
            </button>
            <button type="submit" phx-disable-with="Saving..." class="btn btn-primary">
              {if @action == :new, do: "Create Client", else: "Update Client"}
            </button>
          </div>

          <%= if @client_secret do %>
            <div class="alert alert-warning">
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
              <div>
                <h3 class="font-bold">Client Secret Generated!</h3>
                <div class="text-xs mt-2">
                  Please save this secret securely. You won't be able to see it again.
                </div>
                <div class="mt-3">
                  <code class="bg-base-300 px-3 py-2 rounded font-mono text-sm break-all">
                    {@client_secret}
                  </code>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </.form>
    </div>
    """
  end
end
