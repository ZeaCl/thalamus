defmodule ThalamusWeb.OAuth2.DeviceHTML do
  @moduledoc """
  Renders OAuth2 device authorization pages (activation, success).
  """
  use ThalamusWeb, :html

  embed_templates "device_html/*"
end
