defmodule ThalamusWeb.Dashboard.PlaceholderLive do
  use ThalamusWeb, :live_view

  # Load authenticated user on mount
  on_mount ThalamusWeb.Live.Hooks.LiveAuth

  alias Thalamus.Repo
  alias Thalamus.Infrastructure.Persistence.Schemas.UserSchema
  alias Thalamus.Infrastructure.Persistence.Schemas.OrganizationSchema

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, uri, socket) do
    action = socket.assigns.live_action
    current_path = URI.parse(uri).path

    socket =
      socket
      |> assign(:page_title, String.capitalize(to_string(action)))
      |> assign(:section, action)
      |> assign(:current_path, current_path)
      |> assign_section_data(action)

    {:noreply, socket}
  end

  # Assign DB data for Identity
  defp assign_section_data(socket, :identity) do
    users = Repo.all(UserSchema)
    orgs = Repo.all(OrganizationSchema)

    socket
    |> assign(:users, users)
    |> assign(:organizations, orgs)
  end

  defp assign_section_data(socket, _other) do
    socket
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#0B0D13] text-white p-8 relative overflow-hidden">
      <%!-- Glows --%>
      <div class="absolute top-[-20%] left-[-10%] w-[50%] h-[50%] bg-primary/5 rounded-full blur-[120px] pointer-events-none">
      </div>
      <div class="absolute bottom-[-20%] right-[-10%] w-[50%] h-[50%] bg-purple-500/5 rounded-full blur-[120px] pointer-events-none">
      </div>

      <div class="max-w-6xl mx-auto relative z-10">
        <%!-- Header --%>
        <div class="flex flex-col md:flex-row md:items-center justify-between border-b border-white/5 pb-6 mb-8 gap-4">
          <div>
            <div class="flex items-center gap-2.5 mb-1.5">
              <span class="text-xs font-mono font-medium text-gray-400 tracking-widest uppercase">
                ZEA
              </span>
              <span class="w-1.5 h-1.5 rounded-full bg-green-500 animate-pulse"></span>
            </div>
            <h1 class="text-3xl font-bold tracking-tight text-white capitalize">
              <%= case @section do %>
                <% :identity -> %>
                  Identity & Access
                <% :docs -> %>
                  Documentation
                <% :api_keys -> %>
                  API Keys
                <% other -> %>
                  {to_string(other)}
              <% end %>
            </h1>
          </div>
          <div class="flex items-center gap-3">
            <span class="text-xs text-base-content/40 font-mono bg-base-300/40 border border-white/5 rounded-lg px-3 py-1.5">
              Ref: {to_string(@section) |> String.upcase()}
            </span>
          </div>
        </div>

        <%!-- Content Router based on Section --%>
        <%= case @section do %>
          <% :workflows -> %>
            <%!-- Workflows Section --%>
            <div class="space-y-6">
              <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
                <div class="bg-base-100/35 backdrop-blur border border-white/5 rounded-2xl p-6 relative overflow-hidden">
                  <div class="absolute inset-x-0 top-0 h-[1px] bg-gradient-to-r from-transparent via-primary/20 to-transparent">
                  </div>
                  <h3 class="text-xs font-mono text-base-content/50 uppercase mb-2">
                    Active Pipelines
                  </h3>
                  <p class="text-3xl font-bold text-white">4</p>
                </div>
                <div class="bg-base-100/35 backdrop-blur border border-white/5 rounded-2xl p-6 relative overflow-hidden">
                  <div class="absolute inset-x-0 top-0 h-[1px] bg-gradient-to-r from-transparent via-purple-500/20 to-transparent">
                  </div>
                  <h3 class="text-xs font-mono text-base-content/50 uppercase mb-2">
                    Total Executions (24h)
                  </h3>
                  <p class="text-3xl font-bold text-white">1,482</p>
                </div>
                <div class="bg-base-100/35 backdrop-blur border border-white/5 rounded-2xl p-6 relative overflow-hidden">
                  <div class="absolute inset-x-0 top-0 h-[1px] bg-gradient-to-r from-transparent via-green-500/20 to-transparent">
                  </div>
                  <h3 class="text-xs font-mono text-base-content/50 uppercase mb-2">Success Rate</h3>
                  <p class="text-3xl font-bold text-white">99.8%</p>
                </div>
              </div>

              <%!-- Workflow list --%>
              <div class="bg-base-100/35 backdrop-blur border border-white/5 rounded-2xl overflow-hidden">
                <div class="p-6 border-b border-white/5 flex items-center justify-between">
                  <h3 class="font-bold text-base text-white">Stateful Workflows (Cerebelum)</h3>
                  <span class="text-xs text-primary font-mono font-medium">Auto-Healing Enabled</span>
                </div>
                <div class="divide-y divide-white/5">
                  <div class="p-5 flex items-center justify-between hover:bg-white/[0.01] transition-all duration-200">
                    <div>
                      <div class="flex items-center gap-2">
                        <span class="font-semibold text-sm text-white">DB-Auto-Migration</span>
                        <span class="text-[9px] px-1.5 py-0.5 rounded bg-green-500/10 text-green-400 border border-green-500/20 font-mono font-medium uppercase">
                          Idle
                        </span>
                      </div>
                      <p class="text-xs text-base-content/40 mt-1">
                        Ecto schema sync and Docker build automation
                      </p>
                    </div>
                    <div class="text-right">
                      <span class="text-xs font-mono text-base-content/60">Last ran: 12m ago</span>
                    </div>
                  </div>
                  <div class="p-5 flex items-center justify-between hover:bg-white/[0.01] transition-all duration-200">
                    <div>
                      <div class="flex items-center gap-2">
                        <span class="font-semibold text-sm text-white">
                          Venture-Portal-Deployment
                        </span>
                        <span class="text-[9px] px-1.5 py-0.5 rounded bg-blue-500/10 text-blue-400 border border-blue-500/20 font-mono font-medium uppercase animate-pulse">
                          Running
                        </span>
                      </div>
                      <p class="text-xs text-base-content/40 mt-1">
                        Production build compilation and Caddy SSL reload
                      </p>
                    </div>
                    <div class="text-right">
                      <span class="text-xs font-mono text-base-content/60">Last ran: Active</span>
                    </div>
                  </div>
                  <div class="p-5 flex items-center justify-between hover:bg-white/[0.01] transition-all duration-200">
                    <div>
                      <div class="flex items-center gap-2">
                        <span class="font-semibold text-sm text-white">Daily-Backup-Sync</span>
                        <span class="text-[9px] px-1.5 py-0.5 rounded bg-green-500/10 text-green-400 border border-green-500/20 font-mono font-medium uppercase">
                          Idle
                        </span>
                      </div>
                      <p class="text-xs text-base-content/40 mt-1">
                        Postgres database snapshot and S3 sync
                      </p>
                    </div>
                    <div class="text-right">
                      <span class="text-xs font-mono text-base-content/60">Last ran: 8h ago</span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          <% :identity -> %>
            <%!-- Identity Section --%>
            <div class="space-y-6">
              <%!-- Real Organizations List --%>
              <div class="bg-base-100/35 backdrop-blur border border-white/5 rounded-2xl overflow-hidden mb-6">
                <div class="p-6 border-b border-white/5 flex items-center justify-between">
                  <h3 class="font-bold text-base text-white">Organizations</h3>
                  <span class="text-xs text-base-content/40 font-mono">
                    {length(@organizations)} registered
                  </span>
                </div>
                <%= if Enum.empty?(@organizations) do %>
                  <div class="p-8 text-center text-xs text-base-content/35">
                    No organizations created yet.
                  </div>
                <% else %>
                  <div class="divide-y divide-white/5">
                    <%= for org <- @organizations do %>
                      <div class="p-5 flex items-center justify-between">
                        <div>
                          <span class="font-semibold text-sm text-white">{org.name}</span>
                          <div class="text-[10px] text-base-content/40 font-mono mt-0.5">
                            ID: {org.id}
                          </div>
                        </div>
                        <div class="text-right text-xs text-base-content/50">
                          Created: {Calendar.strftime(org.inserted_at, "%Y-%m-%d")}
                        </div>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>

              <%!-- Real Users List --%>
              <div class="bg-base-100/35 backdrop-blur border border-white/5 rounded-2xl overflow-hidden">
                <div class="p-6 border-b border-white/5 flex items-center justify-between">
                  <h3 class="font-bold text-base text-white">User Accounts</h3>
                  <span class="text-xs text-base-content/40 font-mono">
                    {length(@users)} registered
                  </span>
                </div>
                <%= if Enum.empty?(@users) do %>
                  <div class="p-8 text-center text-xs text-base-content/35">
                    No users created yet.
                  </div>
                <% else %>
                  <div class="divide-y divide-white/5">
                    <%= for user <- @users do %>
                      <div class="p-5 flex items-center justify-between hover:bg-white/[0.01] transition-all duration-200">
                        <div>
                          <div class="flex items-center gap-2">
                            <span class="font-semibold text-sm text-white">
                              {user.name || "Unnamed User"}
                            </span>
                            <%= if user.status == :active do %>
                              <span class="text-[9px] px-1.5 py-0.5 rounded bg-green-500/10 text-green-400 border border-green-500/20 font-mono font-medium uppercase">
                                Active
                              </span>
                            <% else %>
                              <span class="text-[9px] px-1.5 py-0.5 rounded bg-yellow-500/10 text-yellow-400 border border-yellow-500/20 font-mono font-medium uppercase">
                                {to_string(user.status)}
                              </span>
                            <% end %>
                          </div>
                          <p class="text-xs text-base-content/40 mt-1">{user.email}</p>
                        </div>
                        <div class="text-right text-xs text-base-content/50">
                          Last Login: {if user.last_login_at,
                            do: Calendar.strftime(user.last_login_at, "%Y-%m-%d %H:%M"),
                            else: "Never"}
                        </div>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>
          <% :billing -> %>
            <%!-- Billing Section --%>
            <div class="space-y-6">
              <div class="bg-base-100/35 backdrop-blur border border-white/5 rounded-2xl p-6 relative overflow-hidden">
                <div class="absolute inset-x-0 top-0 h-[1px] bg-gradient-to-r from-transparent via-primary/30 to-transparent">
                </div>
                <div class="flex flex-col md:flex-row md:items-center justify-between gap-4">
                  <div>
                    <h3 class="text-xs font-mono text-base-content/50 uppercase mb-1">
                      Current Plan
                    </h3>
                    <h2 class="text-xl font-bold text-white">Developer Enterprise Pro</h2>
                    <p class="text-xs text-base-content/40 mt-1">
                      Renews automatically on Oct 26, 2026
                    </p>
                  </div>
                  <div class="bg-primary/10 border border-primary/20 rounded-xl px-4 py-2 text-xs text-primary font-medium text-center font-mono uppercase tracking-wider">
                    Active Account
                  </div>
                </div>
              </div>

              <%!-- Usage quotas --%>
              <div class="bg-base-100/35 backdrop-blur border border-white/5 rounded-2xl p-6">
                <h3 class="font-bold text-base text-white mb-6">Quota Usage</h3>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
                  <div>
                    <div class="flex justify-between text-xs mb-2">
                      <span class="text-base-content/60">Agent Compute Hours</span>
                      <span class="font-mono text-white">124 / 500 hrs</span>
                    </div>
                    <div class="w-full bg-base-300 rounded-full h-1.5 overflow-hidden">
                      <div class="bg-primary h-1.5 rounded-full" style="width: 25%"></div>
                    </div>
                  </div>
                  <div>
                    <div class="flex justify-between text-xs mb-2">
                      <span class="text-base-content/60">API Gateways & OAuth Tokens</span>
                      <span class="font-mono text-white">45,210 / 100,000 calls</span>
                    </div>
                    <div class="w-full bg-base-300 rounded-full h-1.5 overflow-hidden">
                      <div class="bg-purple-500 h-1.5 rounded-full" style="width: 45%"></div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          <% :pricing -> %>
            <%!-- Pricing Section --%>
            <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
              <div class="bg-base-100/35 backdrop-blur border border-white/5 rounded-2xl p-8 relative flex flex-col justify-between">
                <div>
                  <h3 class="text-sm font-bold text-white mb-2">Developer Free</h3>
                  <p class="text-xs text-base-content/40">
                    For developers starting with local agents.
                  </p>
                  <div class="my-6">
                    <span class="text-3xl font-bold text-white">$0</span>
                    <span class="text-xs text-base-content/50">/ month</span>
                  </div>
                  <ul class="text-xs text-base-content/60 space-y-3 border-t border-white/5 pt-6">
                    <li class="flex items-center gap-2">✓ 1 Active Local Agent</li>
                    <li class="flex items-center gap-2">✓ 3 active local skills</li>
                    <li class="flex items-center gap-2">✓ Stateful workflows sandbox</li>
                  </ul>
                </div>
                <button class="btn bg-white/5 border border-white/10 hover:bg-white/10 text-white rounded-xl mt-8 w-full text-xs font-semibold normal-case">
                  Current Plan
                </button>
              </div>

              <div class="bg-base-100/35 backdrop-blur border border-primary/20 rounded-2xl p-8 relative flex flex-col justify-between scale-105 shadow-xl shadow-primary/5">
                <div class="absolute top-4 right-4 bg-primary/10 border border-primary/20 text-primary text-[8px] font-mono tracking-widest uppercase px-2 py-0.5 rounded-full">
                  Popular
                </div>
                <div>
                  <h3 class="text-sm font-bold text-white mb-2">Team Pro</h3>
                  <p class="text-xs text-base-content/40">For teams running multi-agent tasks.</p>
                  <div class="my-6">
                    <span class="text-3xl font-bold text-white">$49</span>
                    <span class="text-xs text-base-content/50">/ month</span>
                  </div>
                  <ul class="text-xs text-base-content/60 space-y-3 border-t border-white/5 pt-6">
                    <li class="flex items-center gap-2">✓ Unlimited Local Agents</li>
                    <li class="flex items-center gap-2">✓ Custom skill registry</li>
                    <li class="flex items-center gap-2">✓ Full OAuth Identity management</li>
                    <li class="flex items-center gap-2">✓ Priority runtime executions</li>
                  </ul>
                </div>
                <button class="btn btn-primary rounded-xl mt-8 w-full text-xs font-semibold normal-case">
                  Upgrade Plan
                </button>
              </div>

              <div class="bg-base-100/35 backdrop-blur border border-white/5 rounded-2xl p-8 relative flex flex-col justify-between">
                <div>
                  <h3 class="text-sm font-bold text-white mb-2">Enterprise</h3>
                  <p class="text-xs text-base-content/40">For scaling secure agent infrastructure.</p>
                  <div class="my-6">
                    <span class="text-3xl font-bold text-white">Custom</span>
                  </div>
                  <ul class="text-xs text-base-content/60 space-y-3 border-t border-white/5 pt-6">
                    <li class="flex items-center gap-2">✓ Dedicated runtime resources</li>
                    <li class="flex items-center gap-2">✓ Auditing & immutable logs integration</li>
                    <li class="flex items-center gap-2">✓ SSO & advanced enterprise security</li>
                  </ul>
                </div>
                <button class="btn bg-white/5 border border-white/10 hover:bg-white/10 text-white rounded-xl mt-8 w-full text-xs font-semibold normal-case">
                  Contact Sales
                </button>
              </div>
            </div>
          <% :integration -> %>
            <%!-- Integration Section --%>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div class="bg-base-100/35 backdrop-blur border border-white/5 rounded-2xl p-6 flex items-center justify-between">
                <div class="flex items-center gap-4">
                  <div class="w-12 h-12 rounded-xl bg-purple-500/10 text-purple-400 flex items-center justify-center text-xl">
                    💬
                  </div>
                  <div>
                    <h3 class="font-bold text-sm text-white">Telegram Channel</h3>
                    <p class="text-xs text-base-content/40 mt-0.5">
                      Control your agents via chat messages.
                    </p>
                  </div>
                </div>
                <input type="checkbox" class="toggle toggle-primary toggle-sm" checked />
              </div>

              <div class="bg-base-100/35 backdrop-blur border border-white/5 rounded-2xl p-6 flex items-center justify-between">
                <div class="flex items-center gap-4">
                  <div class="w-12 h-12 rounded-xl bg-blue-500/10 text-blue-400 flex items-center justify-center text-xl">
                    🐙
                  </div>
                  <div>
                    <h3 class="font-bold text-sm text-white">GitHub Actions</h3>
                    <p class="text-xs text-base-content/40 mt-0.5">
                      Automate CI/CD executions based on agent updates.
                    </p>
                  </div>
                </div>
                <input type="checkbox" class="toggle toggle-primary toggle-sm" checked />
              </div>

              <div class="bg-base-100/35 backdrop-blur border border-white/5 rounded-2xl p-6 flex items-center justify-between">
                <div class="flex items-center gap-4">
                  <div class="w-12 h-12 rounded-xl bg-green-500/10 text-green-400 flex items-center justify-center text-xl">
                    ⚡
                  </div>
                  <div>
                    <h3 class="font-bold text-sm text-white">Vercel Deployments</h3>
                    <p class="text-xs text-base-content/40 mt-0.5">
                      Triggers serverless redeploys from workflows.
                    </p>
                  </div>
                </div>
                <input type="checkbox" class="toggle toggle-primary toggle-sm" />
              </div>

              <div class="bg-base-100/35 backdrop-blur border border-white/5 rounded-2xl p-6 flex items-center justify-between">
                <div class="flex items-center gap-4">
                  <div class="w-12 h-12 rounded-xl bg-yellow-500/10 text-yellow-400 flex items-center justify-center text-xl">
                    Slack
                  </div>
                  <div>
                    <h3 class="font-bold text-sm text-white">Slack Workspace</h3>
                    <p class="text-xs text-base-content/40 mt-0.5">
                      Receive build status reports & notifications.
                    </p>
                  </div>
                </div>
                <input type="checkbox" class="toggle toggle-primary toggle-sm" />
              </div>
            </div>
          <% :docs -> %>
            <%!-- Docs Section --%>
            <div class="bg-base-100/35 backdrop-blur border border-white/5 rounded-2xl p-8 space-y-6">
              <h2 class="text-lg font-bold text-white mb-2">Getting Started with ZEA CLI</h2>
              <p class="text-xs text-base-content/60 leading-relaxed">
                Initialize ZEA inside your development repository to start managing autonomous coding workflows.
              </p>

              <div class="bg-[#0B0D13] border border-white/5 rounded-xl p-5 font-mono text-xs text-gray-300 relative group overflow-hidden">
                <div class="text-base-content/30 mb-2"># Install ZEA CLI and Scaffold workspace</div>
                <div class="text-cyan-400">$ <span class="text-white">npx @zea-ai/init</span></div>
              </div>

              <h3 class="text-sm font-bold text-white mt-8 mb-2">Connecting Agents (Glia)</h3>
              <p class="text-xs text-base-content/60 leading-relaxed">
                Authorize Glia to create file structures and run commands using machine-to-machine OAuth2 identity profiles generated under the
                <strong>Multi-Agent</strong>
                section.
              </p>

              <div class="bg-[#0B0D13] border border-white/5 rounded-xl p-5 font-mono text-xs text-gray-300 relative overflow-hidden">
                <div class="text-base-content/30 mb-2"># Export active agent credential key</div>
                <div class="text-cyan-400">
                  ZEA_API_KEY=<span class="text-white">zea_key_m2m_token_prod_99x8...</span>
                </div>
              </div>
            </div>
        <% end %>
      </div>
    </div>
    """
  end
end
