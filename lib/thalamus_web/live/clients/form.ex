defmodule ThalamusWeb.Clients.Form do
  @moduledoc """
  LiveView for creating and editing OAuth2 clients.
  """
  use ThalamusWeb, :live_view

  alias Thalamus.Infrastructure.Persistence.Schemas.OAuth2ClientSchema
  alias Thalamus.Repo

  # Load authenticated user on mount
  on_mount ThalamusWeb.Live.Hooks.LiveAuth

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_path, "/dashboard/clients")
     |> assign(:client_secret, nil)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New OAuth2 Client")
    |> assign(:client, %OAuth2ClientSchema{})
    |> assign(:changeset, OAuth2ClientSchema.update_changeset(%OAuth2ClientSchema{}, %{}))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    case Repo.get_by(OAuth2ClientSchema, client_id_string: id) do
      nil ->
        socket
        |> put_flash(:error, "Client not found")
        |> push_navigate(to: ~p"/dashboard/clients")

      client ->
        socket
        |> assign(:page_title, "Edit OAuth2 Client")
        |> assign(:client, client)
        |> assign(:changeset, OAuth2ClientSchema.update_changeset(client, %{}))
    end
  end

  @impl true
  def handle_event("validate", %{"client" => client_params}, socket) do
    changeset =
      socket.assigns.client
      |> OAuth2ClientSchema.update_changeset(process_params(client_params))
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, changeset: changeset)}
  end

  @impl true
  def handle_event("save", %{"client" => client_params}, socket) do
    save_client(socket, socket.assigns.live_action, client_params)
  end

  defp save_client(socket, :new, client_params) do
    # Check if user has an organization
    case socket.assigns.current_organization do
      nil ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "You must belong to an organization to create OAuth2 clients. Please contact support."
         )
         |> push_navigate(to: ~p"/dashboard/clients")}

      organization ->
        # Generate client_id and client_secret
        client_id = "client_#{Ecto.UUID.generate()}"
        client_secret = generate_client_secret()

        params = process_params(client_params)

        attrs =
          params
          |> Map.put("client_id_string", client_id)
          |> Map.put("client_secret", Bcrypt.hash_pwd_salt(client_secret))
          |> Map.put("organization_id", organization.id)
          |> Map.put("is_active", true)

        changeset = OAuth2ClientSchema.create_changeset(attrs)

        case Repo.insert(changeset) do
          {:ok, _client} ->
            {:noreply,
             socket
             |> assign(:client_secret, client_secret)
             |> put_flash(
               :info,
               "Client created successfully. Please save the client secret - you won't see it again!"
             )}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, changeset: changeset)}
        end
    end
  end

  defp save_client(socket, :edit, client_params) do
    params = process_params(client_params)
    changeset = OAuth2ClientSchema.update_changeset(socket.assigns.client, params)

    case Repo.update(changeset) do
      {:ok, _client} ->
        {:noreply,
         socket
         |> put_flash(:info, "Client updated successfully")
         |> push_navigate(to: ~p"/dashboard/clients")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  defp process_params(params) do
    params
    |> process_redirect_uris()
    |> process_checkboxes()
  end

  defp process_redirect_uris(params) do
    if redirect_uris_text = params["redirect_uris_text"] do
      uris =
        redirect_uris_text
        |> String.split("\n")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))

      Map.put(params, "redirect_uris", uris)
    else
      params
    end
  end

  defp process_checkboxes(params) do
    params
    |> Map.put_new("allowed_grant_types", [])
    |> Map.put_new("allowed_scopes", [])
    |> Map.put_new("pkce_required", false)
  end

  defp generate_client_secret do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8 py-8">
      <%= if @live_action == :new do %>
        <.breadcrumbs items={[
          %{label: "Dashboard", path: "/dashboard"},
          %{label: "OAuth2 Clients", path: "/dashboard/clients"},
          %{label: "New Client", path: nil}
        ]} />
      <% else %>
        <.breadcrumbs items={[
          %{label: "Dashboard", path: "/dashboard"},
          %{label: "OAuth2 Clients", path: "/dashboard/clients"},
          %{label: @client.name, path: "/dashboard/clients/#{@client.client_id_string}"},
          %{label: "Edit", path: nil}
        ]} />
      <% end %>
      
    <!-- Header -->
      <div class="mb-8">
        <h1 class="text-2xl font-semibold text-base-content">{@page_title}</h1>
      </div>

      <%= if @client_secret do %>
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
            <h3 class="font-bold">Client Secret Generated!</h3>
            <div class="text-sm mt-2">
              Please save this secret securely. You won't be able to see it again.
            </div>
            <div class="mt-3 p-3 bg-base-300 rounded font-mono text-sm break-all">
              {@client_secret}
            </div>
            <div class="mt-3">
              <.link navigate={~p"/dashboard/clients"} class="btn btn-sm btn-primary">
                Continue to Clients List
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
                  <span class="label-text">Client Name *</span>
                </label>
                <input
                  type="text"
                  name="client[name]"
                  value={Phoenix.HTML.Form.input_value(f, :name)}
                  class="input input-bordered w-full"
                  placeholder="My Application"
                  required
                />
              </div>

              <div class="form-control">
                <label class="label">
                  <span class="label-text">Description</span>
                </label>
                <textarea
                  name="client[description]"
                  class="textarea textarea-bordered w-full"
                  rows="3"
                  placeholder="Brief description of your application"
                ><%= Phoenix.HTML.Form.input_value(f, :description) %></textarea>
              </div>

              <div class="form-control">
                <label class="label">
                  <span class="label-text">Client Type *</span>
                </label>
                <select name="client[client_type]" class="select select-bordered w-full" required>
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
        </div>
        
    <!-- OAuth2 Configuration -->
        <div class="card bg-base-100 shadow">
          <div class="card-body">
            <h3 class="card-title text-lg mb-4">OAuth2 Configuration</h3>

            <div class="space-y-4">
              <div class="form-control">
                <label class="label">
                  <span class="label-text font-semibold">Grant Types *</span>
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
                                                 ) || [])
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
                                                 ) || [])
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
                  class="textarea textarea-bordered font-mono text-xs w-full"
                  rows="4"
                  placeholder="https://example.com/callback\nhttps://example.com/oauth/callback"
                ><%= Enum.join(Phoenix.HTML.Form.input_value(f, :redirect_uris) || [], "\n") %></textarea>
              </div>

              <div class="form-control">
                <label class="label">
                  <span class="label-text font-semibold">Allowed Scopes</span>
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
        </div>
        
    <!-- Actions -->
        <div class="flex justify-end gap-3">
          <.link navigate={~p"/dashboard/clients"} class="btn btn-ghost">
            Cancel
          </.link>
          <button type="submit" phx-disable-with="Saving..." class="btn btn-primary">
            {if @live_action == :new, do: "Create Client", else: "Update Client"}
          </button>
        </div>
      </.form>
    </div>
    """
  end
end
