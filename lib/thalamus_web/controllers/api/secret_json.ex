defmodule ThalamusWeb.API.SecretJSON do
  alias Thalamus.Domain.Entities.Secret

  def index(%{secrets: secrets}) do
    %{data: for(secret <- secrets, do: data(secret))}
  end

  def show(%{secret: secret}) do
    %{data: data(secret)}
  end

  defp data(%Secret{} = secret) do
    %{
      id: secret.id,
      owner_type: secret.owner_type,
      owner_id: secret.owner_id,
      provider: secret.provider,
      name: secret.name,
      # Never return the value!
      inserted_at: secret.inserted_at
    }
  end
end
