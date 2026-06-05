defmodule Thalamus.Encrypted.Binary do
  @moduledoc """
  Encrypted binary field using Cloak.Ecto.
  """
  use Cloak.Ecto.Binary, vault: Thalamus.Vault
end
