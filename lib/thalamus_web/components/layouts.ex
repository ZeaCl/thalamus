defmodule ThalamusWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use Phoenix.Component
  use Gettext, backend: ThalamusWeb.Gettext

  import Phoenix.Controller, only: [get_csrf_token: 0]
  import ThalamusWeb.CoreComponents

  alias Phoenix.LiveView.JS

  # Routes generation
  use Phoenix.VerifiedRoutes,
    endpoint: ThalamusWeb.Endpoint,
    router: ThalamusWeb.Router,
    statics: ThalamusWeb.static_paths()

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  # app.html.heex will be automatically available as app/1
  embed_templates "layouts/*"

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Navigation link component for app layout.
  """
  attr :href, :string, required: true
  attr :current, :string, required: true
  slot :inner_block, required: true

  def nav_link(assigns) do
    active = String.starts_with?(assigns.current, assigns.href)

    assigns = assign(assigns, :active, active)

    ~H"""
    <a
      href={@href}
      class={[
        "inline-flex items-center border-b-2 px-1 pt-1 text-sm font-medium transition-colors",
        if(@active,
          do: "border-primary-500 text-gray-900",
          else: "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700"
        )
      ]}
    >
      {render_slot(@inner_block)}
    </a>
    """
  end

  @doc """
  Breadcrumbs component for navigation.
  """
  attr :items, :list, required: true, doc: "list of %{label: string, path: string | nil} maps"

  def breadcrumbs(assigns) do
    ~H"""
    <nav class="flex mb-6" aria-label="Breadcrumb">
      <ol class="inline-flex items-center space-x-1 md:space-x-2">
        <%= for {item, index} <- Enum.with_index(@items) do %>
          <li class="inline-flex items-center">
            <%= if index > 0 do %>
              <svg
                class="w-3 h-3 mx-1 text-base-content/40"
                fill="currentColor"
                viewBox="0 0 20 20"
              >
                <path
                  fill-rule="evenodd"
                  d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z"
                  clip-rule="evenodd"
                />
              </svg>
            <% end %>
            <%= if item[:path] do %>
              <.link
                navigate={item[:path]}
                class="inline-flex items-center text-sm font-medium text-base-content/70 hover:text-primary"
              >
                <%= if index == 0 do %>
                  <svg class="w-4 h-4 mr-1" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M10.707 2.293a1 1 0 00-1.414 0l-7 7a1 1 0 001.414 1.414L4 10.414V17a1 1 0 001 1h2a1 1 0 001-1v-2a1 1 0 011-1h2a1 1 0 011 1v2a1 1 0 001 1h2a1 1 0 001-1v-6.586l.293.293a1 1 0 001.414-1.414l-7-7z" />
                  </svg>
                <% end %>
                {item[:label]}
              </.link>
            <% else %>
              <span class="text-sm font-medium text-base-content">
                {item[:label]}
              </span>
            <% end %>
          </li>
        <% end %>
      </ol>
    </nav>
    """
  end

  @doc """
  Sidebar navigation link component with ZEA styling.
  """
  attr :href, :string, default: nil
  attr :navigate, :string, default: nil
  attr :current, :string, required: true
  slot :inner_block, required: true

  def sidebar_link(assigns) do
    target_path = assigns.navigate || assigns.href
    active = String.starts_with?(assigns.current, target_path)

    assigns =
      assigns
      |> assign(:active, active)
      |> assign(:target_path, target_path)

    ~H"""
    <.link
      navigate={@navigate}
      href={@href}
      x-bind:class="sidebarCollapsed ? 'justify-center px-2' : 'px-3'"
      class={[
        "sidebar-link-item group flex items-center py-3 text-[13px] font-medium rounded-md transition-all",
        if(@active,
          do: "bg-white/10 text-white border-l-2 border-white",
          else: "text-gray-400 hover:bg-white/5 hover:text-white border-l-2 border-transparent"
        )
      ]}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  @doc """
  Mobile navigation link component.
  """
  attr :href, :string, required: true
  attr :current, :string, required: true
  slot :inner_block, required: true

  def mobile_nav_link(assigns) do
    active = String.starts_with?(assigns.current, assigns.href)

    assigns = assign(assigns, :active, active)

    ~H"""
    <a
      href={@href}
      class={[
        "block border-l-4 py-2 pl-3 pr-4 text-base font-medium transition-colors",
        if(@active,
          do: "border-white bg-white/10 text-white",
          else:
            "border-transparent text-gray-400 hover:border-gray-300 hover:bg-white/5 hover:text-white"
        )
      ]}
    >
      {render_slot(@inner_block)}
    </a>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
