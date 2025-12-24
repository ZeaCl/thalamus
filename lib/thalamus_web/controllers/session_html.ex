defmodule ThalamusWeb.SessionHTML do
  @moduledoc """
  Renders session-related pages (login, logout).
  """
  use ThalamusWeb, :html

  embed_templates "session_html/*"
end
