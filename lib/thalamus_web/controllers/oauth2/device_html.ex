defmodule ThalamusWeb.OAuth2.DeviceHTML do
  @moduledoc """
  Renders OAuth2 device authorization pages (activation form and success).

  Used by DeviceController to render:
  - `activate.html.heex` — User enters the 8-character device code
  - `success.html.heex` — Confirmation after successful authorization
  """
  use ThalamusWeb, :html

  embed_templates "device_html/*"
end
