defmodule ThalamusWeb.ApiKeys.Form do
  @moduledoc """
  LiveView for creating Admin API Keys.
  """
  use ThalamusWeb, :live_view

  alias Thalamus.Repo
  alias Thalamus.Domain.Services.AdminApiKeyGenerator
  alias Thalamus.Infrastructure.Persistence.Schemas.AdminApiKeySchema

  # Load authenticated user on mount
  on_mount ThalamusWeb.Live.Hooks.LiveAuth

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "New API Key")
     |> assign(:current_path, "/dashboard/api-keys/new")
     |> assign(:generated_key, nil)
     |> assign(
       :form,
       to_form(%{
         "name" => "",
         "description" => "",
         "scopes" => []
       })
     )}
  end

  @impl true
  def handle_event("validate", %{"api_key" => params}, socket) do
    {:noreply, assign(socket, :form, to_form(params))}
  end

  @impl true
  def handle_event("save", %{"api_key" => params}, socket) do
    # Get current user ID from socket assigns
    user_id = socket.assigns.current_user && socket.assigns.current_user.id

    case create_api_key(params, user_id) do
      {:ok, {api_key_schema, full_api_key}} ->
        {:noreply,
         socket
         |> assign(:generated_key, %{
           id: api_key_schema.id,
           name: api_key_schema.name,
           key: full_api_key,
           key_prefix: api_key_schema.key_prefix,
           scopes: api_key_schema.scopes
         })
         |> put_flash(
           :info,
           "API key created successfully! Make sure to copy it now, you won't see it again."
         )}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to create API key: #{format_errors(changeset)}")
         |> assign(:form, to_form(Map.put(params, "errors", changeset)))}
    end
  end

  @impl true
  def handle_event("toggle_scope", %{"scope" => scope}, socket) do
    current_scopes = socket.assigns.form.params["scopes"] || []

    new_scopes =
      if scope in current_scopes do
        List.delete(current_scopes, scope)
      else
        [scope | current_scopes]
      end

    updated_params = Map.put(socket.assigns.form.params, "scopes", new_scopes)
    {:noreply, assign(socket, :form, to_form(updated_params))}
  end

  @impl true
  def handle_event("done", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/dashboard/api-keys")}
  end

  defp create_api_key(params, user_id) do
    # Generate the API key using the domain service
    %{api_key: full_key, key_hash: key_hash, key_prefix: key_prefix} =
      AdminApiKeyGenerator.generate()

    # Create attributes for the schema
    attrs = %{
      "id" => Ecto.UUID.generate(),
      "key_hash" => key_hash,
      "key_prefix" => key_prefix,
      "name" => params["name"],
      "description" => params["description"],
      "scopes" => params["scopes"] || [],
      "is_active" => true,
      "expires_at" => nil,
      "created_by_user_id" => user_id
    }

    changeset = AdminApiKeySchema.create_changeset(attrs)

    case Repo.insert(changeset) do
      {:ok, schema} -> {:ok, {schema, full_key}}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
    |> Enum.map(fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
    |> Enum.join("; ")
  end

  defp available_scopes do
    [
      %{
        value: "clients:read",
        label: "Read OAuth2 Clients",
        description: "View client configurations"
      },
      %{
        value: "clients:write",
        label: "Write OAuth2 Clients",
        description: "Create and update clients"
      },
      %{
        value: "clients:delete",
        label: "Delete OAuth2 Clients",
        description: "Delete client applications"
      },
      %{value: "users:read", label: "Read Users", description: "View user information"},
      %{value: "users:write", label: "Write Users", description: "Create and update users"},
      %{
        value: "organizations:read",
        label: "Read Organizations",
        description: "View organization data"
      },
      %{
        value: "organizations:write",
        label: "Write Organizations",
        description: "Create and update organizations"
      },
      %{value: "corpus:read", label: "Read Corpus", description: "Access corpus data"},
      %{value: "corpus:write", label: "Write Corpus", description: "Modify corpus data"}
    ]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8 py-8">
      <.breadcrumbs items={[
        %{label: "Dashboard", path: "/dashboard"},
        %{label: "API Keys", path: "/dashboard/api-keys"},
        %{label: "New API Key", path: nil}
      ]} />

      <%= if @generated_key do %>
        <!-- Success: Show generated key -->
        <div class="max-w-2xl mx-auto">
          <div class="alert alert-success mb-6">
            <svg
              class="h-6 w-6"
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
            <span>API Key Created Successfully!</span>
          </div>

          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <h2 class="card-title text-2xl mb-4">{@generated_key.name}</h2>

              <div class="alert alert-warning mb-6">
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
                    d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
                  />
                </svg>
                <span class="text-sm">
                  <strong>Important:</strong>
                  Copy your API key now. For security reasons, you won't be able to see it again.
                </span>
              </div>

              <div class="form-control">
                <label class="label">
                  <span class="label-text font-semibold">Your API Key</span>
                </label>
                <div class="flex gap-2">
                  <input
                    type="text"
                    value={@generated_key.key}
                    readonly
                    class="input input-bordered flex-1 font-mono text-sm"
                    id="api-key-input"
                  />
                  <button
                    type="button"
                    class="btn btn-primary"
                    onclick="navigator.clipboard.writeText(document.getElementById('api-key-input').value); this.textContent = 'Copied!'; setTimeout(() => this.textContent = 'Copy', 2000)"
                  >
                    Copy
                  </button>
                </div>
              </div>

              <div class="divider"></div>

              <div class="grid grid-cols-2 gap-4 text-sm">
                <div>
                  <div class="text-base-content/70">Key Prefix</div>
                  <code class="text-base-content font-mono">{@generated_key.key_prefix}</code>
                </div>
                <div>
                  <div class="text-base-content/70">Scopes</div>
                  <div class="flex flex-wrap gap-1 mt-1">
                    <%= for scope <- @generated_key.scopes do %>
                      <span class="badge badge-sm">{scope}</span>
                    <% end %>
                  </div>
                </div>
              </div>

              <div class="card-actions justify-end mt-6">
                <button phx-click="done" class="btn btn-primary">
                  Done
                </button>
              </div>
            </div>
          </div>
        </div>
      <% else %>
        <!-- Form: Create new key -->
        <div class="max-w-2xl mx-auto">
          <div class="sm:flex sm:items-center sm:justify-between mb-6">
            <div class="sm:flex-auto">
              <h1 class="text-2xl font-semibold text-base-content">Create API Key</h1>
              <p class="mt-2 text-sm text-base-content/70">
                Generate a new API key for programmatic access to ZEA
              </p>
            </div>
          </div>

          <div class="card bg-base-100 shadow">
            <div class="card-body">
              <form phx-submit="save" phx-change="validate">
                <div class="form-control">
                  <label class="label">
                    <span class="label-text font-semibold">
                      Name<span class="text-error">*</span>
                    </span>
                  </label>
                  <input
                    type="text"
                    name="api_key[name]"
                    value={@form.params["name"]}
                    placeholder="e.g., Sport Backend Service"
                    class="input input-bordered"
                    required
                  />
                  <label class="label">
                    <span class="label-text-alt">
                      A descriptive name to identify this API key
                    </span>
                  </label>
                </div>

                <div class="form-control mt-4">
                  <label class="label">
                    <span class="label-text font-semibold">Description</span>
                  </label>
                  <textarea
                    name="api_key[description]"
                    value={@form.params["description"]}
                    placeholder="What will this API key be used for?"
                    class="textarea textarea-bordered h-24"
                  ></textarea>
                </div>

                <div class="form-control mt-6">
                  <label class="label">
                    <span class="label-text font-semibold">Scopes</span>
                  </label>
                  <div class="space-y-2">
                    <%= for scope <- available_scopes() do %>
                      <label class="flex items-start gap-3 p-3 rounded-lg hover:bg-base-200 cursor-pointer">
                        <input
                          type="checkbox"
                          class="checkbox checkbox-primary mt-1"
                          checked={scope.value in (@form.params["scopes"] || [])}
                          phx-click="toggle_scope"
                          phx-value-scope={scope.value}
                        />
                        <div class="flex-1">
                          <div class="font-medium text-base-content">
                            {scope.label}
                          </div>
                          <div class="text-sm text-base-content/70">
                            {scope.description}
                          </div>
                        </div>
                      </label>
                    <% end %>
                  </div>
                </div>

                <div class="card-actions justify-end mt-8">
                  <.link navigate="/dashboard/api-keys" class="btn btn-ghost">
                    Cancel
                  </.link>
                  <button type="submit" class="btn btn-primary">
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
                        d="M15 7a2 2 0 012 2m4 0a6 6 0 01-7.743 5.743L11 17H9v2H7v2H4a1 1 0 01-1-1v-2.586a1 1 0 01.293-.707l5.964-5.964A6 6 0 1121 9z"
                      />
                    </svg>
                    Generate API Key
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
