defmodule Thalamus.Vault do
  @moduledoc """
  Cloak Vault for encrypting sensitive data in the database (e.g., API keys, secrets).
  """
  use Cloak.Vault, otp_app: :thalamus
end
