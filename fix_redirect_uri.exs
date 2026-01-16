#!/usr/bin/env elixir

# Fix OAuth2 client redirect_uri
# Change from /auth/callback to /callback (route group doesn't affect URL)

alias Thalamus.Repo
alias Thalamus.Infrastructure.Persistence.Schemas.OAuth2ClientSchema

import Ecto.Query
import Ecto.Changeset

# Find client by client_id_string (UUID only)
client = Repo.get_by(OAuth2ClientSchema, client_id_string: "59991e63-852c-44e5-aee1-a761ec76eaea")

if client do
  IO.puts("✅ Found client: #{inspect(client.name)}")
  IO.puts("   Current redirect_uris: #{inspect(client.redirect_uris)}")

  # Update redirect_uris
  new_redirect_uris = ["http://localhost:3001/callback"]

  IO.puts("\n🔧 Updating redirect_uris to: #{inspect(new_redirect_uris)}")

  changeset = change(client, %{redirect_uris: new_redirect_uris})

  case Repo.update(changeset) do
    {:ok, updated_client} ->
      IO.puts("✅ Successfully updated client!")
      IO.puts("   New redirect_uris: #{inspect(updated_client.redirect_uris)}")

    {:error, changeset} ->
      IO.puts("❌ Error updating client:")
      IO.inspect(changeset.errors)
  end
else
  IO.puts("❌ Client not found")
end
