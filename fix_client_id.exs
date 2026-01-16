#!/usr/bin/env elixir

# Fix OAuth2 client - remove "client_" prefix from client_id_string
# The DB should store only the UUID, not "client_<uuid>"

alias Thalamus.Repo
alias Thalamus.Infrastructure.Persistence.Schemas.OAuth2ClientSchema

import Ecto.Query
import Ecto.Changeset

# Find client with the full prefixed client_id_string
client =
  Repo.get_by(OAuth2ClientSchema, client_id_string: "client_59991e63-852c-44e5-aee1-a761ec76eaea")

if client do
  IO.puts("✅ Found client: #{inspect(client.name)}")
  IO.puts("   Current client_id_string: #{client.client_id_string}")
  IO.puts("   Current id (primary key): #{client.id}")

  # Extract UUID only (remove "client_" prefix)
  uuid_only = String.replace_prefix(client.client_id_string, "client_", "")

  IO.puts("\n🔧 Updating client_id_string to: #{uuid_only}")

  # Update the client_id_string to store only UUID
  changeset = change(client, %{client_id_string: uuid_only})

  case Repo.update(changeset) do
    {:ok, updated_client} ->
      IO.puts("✅ Successfully updated client!")
      IO.puts("   New client_id_string: #{updated_client.client_id_string}")
      IO.puts("   Primary key (id): #{updated_client.id}")

    {:error, changeset} ->
      IO.puts("❌ Error updating client:")
      IO.inspect(changeset.errors)
  end
else
  IO.puts("❌ Client not found with client_id_string: client_59991e63-852c-44e5-aee1-a761ec76eaea")
  IO.puts("   Searching for any clients with 'client_' prefix...")

  clients_with_prefix =
    Repo.all(
      from c in OAuth2ClientSchema,
        where: like(c.client_id_string, "client_%")
    )

  if length(clients_with_prefix) > 0 do
    IO.puts("\n📋 Found #{length(clients_with_prefix)} clients with 'client_' prefix:")

    Enum.each(clients_with_prefix, fn c ->
      IO.puts("   - ID: #{c.id}, client_id_string: #{c.client_id_string}, name: #{c.name}")
    end)
  else
    IO.puts("   No clients found with 'client_' prefix")
  end
end
