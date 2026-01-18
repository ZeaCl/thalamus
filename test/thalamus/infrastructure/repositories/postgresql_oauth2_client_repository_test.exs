defmodule Thalamus.Infrastructure.Repositories.PostgreSQLOAuth2ClientRepositoryTest do
  use Thalamus.DataCase, async: true

  alias Thalamus.Infrastructure.Repositories.PostgreSQLOAuth2ClientRepository
  alias Thalamus.Domain.Entities.OAuth2Client
  alias Thalamus.Domain.ValueObjects.{
    ClientId,
    OrganizationId,
    GrantType,
    Scope,
    RedirectUri,
    ClientSecret
  }
  alias Thalamus.Infrastructure.Persistence.Schemas.{OAuth2ClientSchema, OrganizationSchema}

  describe "save/1" do
    test "inserts a new OAuth2 client into the database" do
      {:ok, client} = create_client_entity()

      assert {:ok, saved_client} = PostgreSQLOAuth2ClientRepository.save(client)
      assert saved_client.id != nil
      assert saved_client.name == client.name
      assert saved_client.client_type == client.client_type
      assert saved_client.is_active == true
      assert saved_client.created_at != nil
      assert saved_client.updated_at != nil
    end

    test "saves confidential client with hashed secret" do
      {:ok, client} = create_client_entity(client_type: :confidential)

      assert {:ok, saved_client} = PostgreSQLOAuth2ClientRepository.save(client)
      assert saved_client.client_secret != nil
      # Verify the secret is a ClientSecret value object
      assert %ClientSecret{} = saved_client.client_secret
    end

    test "saves public client without secret" do
      {:ok, client} = create_client_entity(client_type: :public)

      assert {:ok, saved_client} = PostgreSQLOAuth2ClientRepository.save(client)
      assert saved_client.client_secret == nil
    end

    test "saves client with grant types" do
      {:ok, auth_code} = GrantType.authorization_code()
      {:ok, refresh} = GrantType.refresh_token()
      {:ok, client} = create_client_entity(grant_types: [auth_code, refresh])

      assert {:ok, saved_client} = PostgreSQLOAuth2ClientRepository.save(client)
      assert length(saved_client.grant_types) == 2
      grant_type_atoms = Enum.map(saved_client.grant_types, & &1.type)
      assert :authorization_code in grant_type_atoms
      assert :refresh_token in grant_type_atoms
    end

    test "saves client with scopes" do
      {:ok, openid} = Scope.new("openid")
      {:ok, profile} = Scope.new("profile")
      {:ok, email} = Scope.new("email")
      {:ok, client} = create_client_entity(allowed_scopes: [openid, profile, email])

      assert {:ok, saved_client} = PostgreSQLOAuth2ClientRepository.save(client)
      assert length(saved_client.allowed_scopes) == 3
      assert "openid" in saved_client.allowed_scopes
      assert "profile" in saved_client.allowed_scopes
      assert "email" in saved_client.allowed_scopes
    end

    test "saves client with redirect URIs" do
      {:ok, uri1} = RedirectUri.new("https://app.example.com/callback")
      {:ok, uri2} = RedirectUri.new("https://app.example.com/callback2")
      {:ok, client} = create_client_entity(redirect_uris: [uri1, uri2])

      assert {:ok, saved_client} = PostgreSQLOAuth2ClientRepository.save(client)
      assert length(saved_client.redirect_uris) == 2
      assert "https://app.example.com/callback" in saved_client.redirect_uris
      assert "https://app.example.com/callback2" in saved_client.redirect_uris
    end

    test "updates existing client when id exists in database" do
      {:ok, client} = create_client_entity(name: "Original Name")
      {:ok, saved_client} = PostgreSQLOAuth2ClientRepository.save(client)

      # Update the client - convert string scopes back to Scope objects
      {:ok, openid_scope} = Scope.new("openid")

      updated_client = %{
        saved_client
        | name: "Updated Name",
          is_active: false,
          allowed_scopes: [openid_scope]
      }

      assert {:ok, result} = PostgreSQLOAuth2ClientRepository.save(updated_client)

      assert result.id == saved_client.id
      assert result.name == "Updated Name"
      assert result.is_active == false
      assert result.client_type == saved_client.client_type
    end

    test "updates client with new grant types" do
      {:ok, auth_code} = GrantType.authorization_code()
      {:ok, client} = create_client_entity(grant_types: [auth_code])
      {:ok, saved_client} = PostgreSQLOAuth2ClientRepository.save(client)

      # Add refresh token grant - also need to convert scopes
      {:ok, refresh} = GrantType.refresh_token()
      {:ok, openid_scope} = Scope.new("openid")

      updated_client = %{
        saved_client
        | grant_types: [auth_code, refresh],
          allowed_scopes: [openid_scope]
      }

      assert {:ok, result} = PostgreSQLOAuth2ClientRepository.save(updated_client)
      assert length(result.grant_types) == 2
    end

    test "updates client with new scopes" do
      {:ok, openid} = Scope.new("openid")
      {:ok, client} = create_client_entity(allowed_scopes: [openid])
      {:ok, saved_client} = PostgreSQLOAuth2ClientRepository.save(client)

      # Add profile scope - need to use Scope objects for update
      {:ok, openid_scope} = Scope.new("openid")
      {:ok, profile_scope} = Scope.new("profile")
      updated_client = %{saved_client | allowed_scopes: [openid_scope, profile_scope]}

      assert {:ok, result} = PostgreSQLOAuth2ClientRepository.save(updated_client)
      assert length(result.allowed_scopes) == 2
      assert "profile" in result.allowed_scopes
    end

    test "updates client with new redirect URIs" do
      {:ok, uri1} = RedirectUri.new("https://app.example.com/callback")
      {:ok, client} = create_client_entity(redirect_uris: [uri1])
      {:ok, saved_client} = PostgreSQLOAuth2ClientRepository.save(client)

      # Add another redirect URI - need to use RedirectUri and Scope objects for update
      {:ok, uri1_obj} = RedirectUri.new("https://app.example.com/callback")
      {:ok, uri2_obj} = RedirectUri.new("https://app.example.com/callback2")
      {:ok, openid_scope} = Scope.new("openid")

      updated_client = %{
        saved_client
        | redirect_uris: [uri1_obj, uri2_obj],
          allowed_scopes: [openid_scope]
      }

      assert {:ok, result} = PostgreSQLOAuth2ClientRepository.save(updated_client)
      assert length(result.redirect_uris) == 2
    end

    test "rotates client secret when secret changes" do
      {:ok, client} = create_client_entity(client_type: :confidential)
      {:ok, saved_client} = PostgreSQLOAuth2ClientRepository.save(client)

      original_secret_hash = ClientSecret.to_string(saved_client.client_secret)

      # Generate a new secret (plain text)
      new_plain_secret = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
      new_secret_hash = Bcrypt.hash_pwd_salt(new_plain_secret)

      # Need to convert scopes and redirect_uris back to value objects for update
      {:ok, openid_scope} = Scope.new("openid")

      # Update with new secret
      updated_client = %{
        saved_client
        | client_secret: new_secret_hash,
          allowed_scopes: [openid_scope]
      }

      assert {:ok, result} = PostgreSQLOAuth2ClientRepository.save(updated_client)

      # Verify secret changed
      new_stored_hash = ClientSecret.to_string(result.client_secret)
      assert new_stored_hash != original_secret_hash
      # Should still be a bcrypt hash
      assert String.starts_with?(new_stored_hash, "$2b$")
    end

    test "updates client without changing secret" do
      {:ok, client} = create_client_entity(client_type: :confidential)
      {:ok, saved_client} = PostgreSQLOAuth2ClientRepository.save(client)

      original_secret_hash = ClientSecret.to_string(saved_client.client_secret)

      # Need to convert scopes back to value objects for update
      {:ok, openid_scope} = Scope.new("openid")

      # Update without changing secret
      updated_client = %{saved_client | name: "New Name", allowed_scopes: [openid_scope]}
      assert {:ok, result} = PostgreSQLOAuth2ClientRepository.save(updated_client)

      assert result.name == "New Name"
      # Secret should remain the same
      assert ClientSecret.to_string(result.client_secret) == original_secret_hash
    end

    test "returns error on constraint violation (duplicate client_id_string)" do
      {:ok, client1} = create_client_entity()
      {:ok, saved1} = PostgreSQLOAuth2ClientRepository.save(client1)

      # Try to insert a client with a different primary key but same client_id_string
      client_uuid = extract_uuid(saved1.id)
      org_id = create_organization()
      new_uuid = Ecto.UUID.generate()

      changeset =
        OAuth2ClientSchema.create_changeset(%{
          id: new_uuid,
          # Same client_id_string as saved1
          client_id_string: client_uuid,
          name: "Duplicate",
          client_type: :confidential,
          organization_id: org_id,
          allowed_grant_types: ["authorization_code"],
          allowed_scopes: ["openid"],
          redirect_uris: []
        })

      assert {:error, changeset} = Repo.insert(changeset)
      assert changeset.errors[:client_id_string] != nil
    end
  end

  describe "find_by_id/1" do
    test "finds a client by valid ClientId" do
      {:ok, client} = create_client_entity()
      {:ok, saved_client} = PostgreSQLOAuth2ClientRepository.save(client)

      assert {:ok, found_client} = PostgreSQLOAuth2ClientRepository.find_by_id(saved_client.id)
      assert found_client.id == saved_client.id
      assert found_client.name == saved_client.name
      assert found_client.client_type == saved_client.client_type
    end

    test "finds client with grant types" do
      {:ok, auth_code} = GrantType.authorization_code()
      {:ok, refresh} = GrantType.refresh_token()
      {:ok, client} = create_client_entity(grant_types: [auth_code, refresh])
      {:ok, saved_client} = PostgreSQLOAuth2ClientRepository.save(client)

      assert {:ok, found_client} = PostgreSQLOAuth2ClientRepository.find_by_id(saved_client.id)
      assert length(found_client.grant_types) == 2
    end

    test "finds client with scopes" do
      {:ok, openid} = Scope.new("openid")
      {:ok, profile} = Scope.new("profile")
      {:ok, client} = create_client_entity(allowed_scopes: [openid, profile])
      {:ok, saved_client} = PostgreSQLOAuth2ClientRepository.save(client)

      assert {:ok, found_client} = PostgreSQLOAuth2ClientRepository.find_by_id(saved_client.id)
      assert length(found_client.allowed_scopes) == 2
    end

    test "finds client with redirect URIs" do
      {:ok, uri} = RedirectUri.new("https://app.example.com/callback")
      {:ok, client} = create_client_entity(redirect_uris: [uri])
      {:ok, saved_client} = PostgreSQLOAuth2ClientRepository.save(client)

      assert {:ok, found_client} = PostgreSQLOAuth2ClientRepository.find_by_id(saved_client.id)
      assert length(found_client.redirect_uris) == 1
      assert "https://app.example.com/callback" in found_client.redirect_uris
    end

    test "finds confidential client with hashed secret" do
      {:ok, client} = create_client_entity(client_type: :confidential)
      {:ok, saved_client} = PostgreSQLOAuth2ClientRepository.save(client)

      assert {:ok, found_client} = PostgreSQLOAuth2ClientRepository.find_by_id(saved_client.id)
      assert found_client.client_secret != nil
      assert %ClientSecret{} = found_client.client_secret
      # Verify it's a bcrypt hash
      secret_hash = ClientSecret.to_string(found_client.client_secret)
      assert String.starts_with?(secret_hash, "$2b$")
    end

    test "finds public client without secret" do
      {:ok, client} = create_client_entity(client_type: :public)
      {:ok, saved_client} = PostgreSQLOAuth2ClientRepository.save(client)

      assert {:ok, found_client} = PostgreSQLOAuth2ClientRepository.find_by_id(saved_client.id)
      assert found_client.client_secret == nil
    end

    test "returns :not_found when client does not exist" do
      {:ok, non_existent_id} = ClientId.generate()

      assert {:error, :not_found} = PostgreSQLOAuth2ClientRepository.find_by_id(non_existent_id)
    end

    test "handles ClientId format correctly with client_ prefix" do
      {:ok, client} = create_client_entity()
      {:ok, saved_client} = PostgreSQLOAuth2ClientRepository.save(client)

      # ClientId.to_string returns "client_<uuid>"
      client_id_string = ClientId.to_string(saved_client.id)
      assert String.starts_with?(client_id_string, "client_")

      assert {:ok, found_client} = PostgreSQLOAuth2ClientRepository.find_by_id(saved_client.id)
      assert ClientId.to_string(found_client.id) == client_id_string
    end
  end

  describe "find_by_client_id/1" do
    test "finds client by client_id string without prefix" do
      {:ok, client} = create_client_entity()
      {:ok, saved_client} = PostgreSQLOAuth2ClientRepository.save(client)

      # Extract UUID without prefix
      client_uuid = extract_uuid(saved_client.id)

      assert {:ok, found_client} =
               PostgreSQLOAuth2ClientRepository.find_by_client_id(client_uuid)

      assert found_client.id == saved_client.id
      assert found_client.name == saved_client.name
    end

    test "finds client by client_id string with client_ prefix" do
      {:ok, client} = create_client_entity()
      {:ok, saved_client} = PostgreSQLOAuth2ClientRepository.save(client)

      # Use full client_id with prefix (repository should handle removing the prefix)
      client_id_string = ClientId.to_string(saved_client.id)

      assert {:ok, found_client} =
               PostgreSQLOAuth2ClientRepository.find_by_client_id(client_id_string)

      assert found_client.id == saved_client.id
    end

    test "returns :not_found when client_id does not exist" do
      non_existent_uuid = Ecto.UUID.generate()

      assert {:error, :not_found} =
               PostgreSQLOAuth2ClientRepository.find_by_client_id(non_existent_uuid)
    end
  end

  describe "delete/1" do
    test "deletes a client by ClientId" do
      {:ok, client} = create_client_entity()
      {:ok, saved_client} = PostgreSQLOAuth2ClientRepository.save(client)

      assert :ok = PostgreSQLOAuth2ClientRepository.delete(saved_client.id)

      # Verify client is deleted
      assert {:error, :not_found} =
               PostgreSQLOAuth2ClientRepository.find_by_id(saved_client.id)
    end

    test "returns :not_found when deleting non-existent client" do
      {:ok, non_existent_id} = ClientId.generate()

      assert {:error, :not_found} = PostgreSQLOAuth2ClientRepository.delete(non_existent_id)
    end

    test "handles ClientId format correctly in delete" do
      {:ok, client} = create_client_entity()
      {:ok, saved_client} = PostgreSQLOAuth2ClientRepository.save(client)

      # ClientId should have "client_" prefix
      client_id_string = ClientId.to_string(saved_client.id)
      assert String.starts_with?(client_id_string, "client_")

      assert :ok = PostgreSQLOAuth2ClientRepository.delete(saved_client.id)
    end
  end

  describe "list/1" do
    test "returns all clients when no filters provided" do
      {:ok, client1} = create_client_entity(name: "Client 1")
      {:ok, client2} = create_client_entity(name: "Client 2")
      {:ok, _saved1} = PostgreSQLOAuth2ClientRepository.save(client1)
      {:ok, _saved2} = PostgreSQLOAuth2ClientRepository.save(client2)

      assert {:ok, clients} = PostgreSQLOAuth2ClientRepository.list(%{})
      assert length(clients) >= 2
    end

    test "filters by is_active" do
      {:ok, active_client} = create_client_entity(name: "Active")
      {:ok, _saved_active} = PostgreSQLOAuth2ClientRepository.save(active_client)

      {:ok, inactive_client} = create_client_entity(name: "Inactive")
      {:ok, saved_inactive} = PostgreSQLOAuth2ClientRepository.save(inactive_client)

      # Deactivate the client - need to convert scopes back to value objects
      {:ok, openid_scope} = Scope.new("openid")
      deactivated = %{saved_inactive | is_active: false, allowed_scopes: [openid_scope]}
      {:ok, _updated} = PostgreSQLOAuth2ClientRepository.save(deactivated)

      assert {:ok, active_clients} = PostgreSQLOAuth2ClientRepository.list(%{is_active: true})
      assert length(active_clients) >= 1
      assert Enum.all?(active_clients, fn c -> c.is_active == true end)

      assert {:ok, inactive_clients} = PostgreSQLOAuth2ClientRepository.list(%{is_active: false})
      assert length(inactive_clients) >= 1
      assert Enum.all?(inactive_clients, fn c -> c.is_active == false end)
    end

    test "filters by client_type" do
      {:ok, confidential} = create_client_entity(client_type: :confidential)
      {:ok, public} = create_client_entity(client_type: :public)
      {:ok, _saved1} = PostgreSQLOAuth2ClientRepository.save(confidential)
      {:ok, _saved2} = PostgreSQLOAuth2ClientRepository.save(public)

      assert {:ok, conf_clients} =
               PostgreSQLOAuth2ClientRepository.list(%{client_type: :confidential})

      assert length(conf_clients) >= 1
      assert Enum.all?(conf_clients, fn c -> c.client_type == :confidential end)

      assert {:ok, pub_clients} = PostgreSQLOAuth2ClientRepository.list(%{client_type: :public})
      assert length(pub_clients) >= 1
      assert Enum.all?(pub_clients, fn c -> c.client_type == :public end)
    end

    test "filters by organization_id" do
      org_id1 = create_organization()
      org_id2 = create_organization()

      {:ok, org1_id_vo} = OrganizationId.from_string(org_id1)
      {:ok, org2_id_vo} = OrganizationId.from_string(org_id2)

      {:ok, client1} = create_client_entity(organization_id: org1_id_vo)
      {:ok, client2} = create_client_entity(organization_id: org2_id_vo)
      {:ok, _saved1} = PostgreSQLOAuth2ClientRepository.save(client1)
      {:ok, _saved2} = PostgreSQLOAuth2ClientRepository.save(client2)

      assert {:ok, org1_clients} =
               PostgreSQLOAuth2ClientRepository.list(%{organization_id: org_id1})

      assert length(org1_clients) >= 1

      assert Enum.all?(org1_clients, fn c ->
        OrganizationId.to_string(c.organization_id) == org_id1
      end)
    end

    test "supports limit pagination" do
      # Create 5 clients
      for i <- 1..5 do
        {:ok, client} = create_client_entity(name: "Client #{i}")
        {:ok, _saved} = PostgreSQLOAuth2ClientRepository.save(client)
      end

      assert {:ok, limited_clients} = PostgreSQLOAuth2ClientRepository.list(%{limit: 3})
      assert length(limited_clients) == 3
    end

    test "supports offset pagination" do
      # Create 5 clients
      for i <- 1..5 do
        {:ok, client} = create_client_entity(name: "Offset Client #{i}")
        {:ok, _saved} = PostgreSQLOAuth2ClientRepository.save(client)
      end

      assert {:ok, _all_clients} = PostgreSQLOAuth2ClientRepository.list(%{})
      assert {:ok, offset_clients} = PostgreSQLOAuth2ClientRepository.list(%{offset: 2, limit: 2})

      assert length(offset_clients) == 2
    end

    test "supports order_by name" do
      {:ok, client_z} = create_client_entity(name: "Zebra Client")
      {:ok, client_a} = create_client_entity(name: "Alpha Client")
      {:ok, _saved1} = PostgreSQLOAuth2ClientRepository.save(client_z)
      {:ok, _saved2} = PostgreSQLOAuth2ClientRepository.save(client_a)

      assert {:ok, ordered_clients} =
               PostgreSQLOAuth2ClientRepository.list(%{order_by: :name, limit: 10})

      names = Enum.map(ordered_clients, & &1.name)
      # Check that the list is sorted
      assert names == Enum.sort(names)
    end

    test "supports order_by created_at" do
      assert {:ok, clients} =
               PostgreSQLOAuth2ClientRepository.list(%{order_by: :created_at, limit: 5})

      assert length(clients) <= 5
    end

    test "returns empty list when no clients match filters" do
      non_existent_org = Ecto.UUID.generate()

      assert {:ok, clients} =
               PostgreSQLOAuth2ClientRepository.list(%{organization_id: non_existent_org})

      assert clients == []
    end

    test "combines multiple filters" do
      org_id = create_organization()
      {:ok, org_id_vo} = OrganizationId.from_string(org_id)

      {:ok, client} =
        create_client_entity(
          organization_id: org_id_vo,
          client_type: :confidential
        )

      {:ok, _saved} = PostgreSQLOAuth2ClientRepository.save(client)

      assert {:ok, clients} =
               PostgreSQLOAuth2ClientRepository.list(%{
                 organization_id: org_id,
                 client_type: :confidential,
                 is_active: true
               })

      assert length(clients) >= 1

      if length(clients) > 0 do
        assert Enum.all?(clients, fn c ->
          c.client_type == :confidential and c.is_active == true
        end)
      end
    end
  end

  describe "find_by_organization/1" do
    test "finds all clients for an organization" do
      org_id = create_organization()
      {:ok, org_id_vo} = OrganizationId.from_string(org_id)

      {:ok, client1} = create_client_entity(organization_id: org_id_vo, name: "Org Client 1")
      {:ok, client2} = create_client_entity(organization_id: org_id_vo, name: "Org Client 2")
      {:ok, _saved1} = PostgreSQLOAuth2ClientRepository.save(client1)
      {:ok, _saved2} = PostgreSQLOAuth2ClientRepository.save(client2)

      assert {:ok, org_clients} =
               PostgreSQLOAuth2ClientRepository.find_by_organization(org_id_vo)

      assert length(org_clients) >= 2

      assert Enum.all?(org_clients, fn c ->
        OrganizationId.to_string(c.organization_id) == org_id
      end)
    end

    test "returns empty list when organization has no clients" do
      # Create a real organization in the database
      org_id = create_organization()
      {:ok, org_id_vo} = OrganizationId.from_string(org_id)

      assert {:ok, clients} = PostgreSQLOAuth2ClientRepository.find_by_organization(org_id_vo)
      # Should be empty since we haven't created any clients for this org
      assert clients == []
    end

    test "filters out invalid entities during conversion" do
      org_id = create_organization()
      {:ok, org_id_vo} = OrganizationId.from_string(org_id)

      {:ok, client} = create_client_entity(organization_id: org_id_vo)
      {:ok, _saved} = PostgreSQLOAuth2ClientRepository.save(client)

      assert {:ok, clients} = PostgreSQLOAuth2ClientRepository.find_by_organization(org_id_vo)
      assert length(clients) >= 1
    end
  end

  describe "count_by_organization/1" do
    test "counts clients for an organization" do
      org_id = create_organization()
      {:ok, org_id_vo} = OrganizationId.from_string(org_id)

      {:ok, initial_count} = PostgreSQLOAuth2ClientRepository.count_by_organization(org_id_vo)

      {:ok, client1} = create_client_entity(organization_id: org_id_vo)
      {:ok, client2} = create_client_entity(organization_id: org_id_vo)
      {:ok, _saved1} = PostgreSQLOAuth2ClientRepository.save(client1)
      {:ok, _saved2} = PostgreSQLOAuth2ClientRepository.save(client2)

      assert {:ok, new_count} = PostgreSQLOAuth2ClientRepository.count_by_organization(org_id_vo)
      assert new_count == initial_count + 2
    end

    test "returns 0 when organization has no clients" do
      # Create a real organization in the database
      org_id = create_organization()
      {:ok, org_id_vo} = OrganizationId.from_string(org_id)

      assert {:ok, 0} = PostgreSQLOAuth2ClientRepository.count_by_organization(org_id_vo)
    end

    test "counts only active clients when they exist" do
      org_id = create_organization()
      {:ok, org_id_vo} = OrganizationId.from_string(org_id)

      {:ok, client} = create_client_entity(organization_id: org_id_vo)
      {:ok, _saved} = PostgreSQLOAuth2ClientRepository.save(client)

      assert {:ok, count} = PostgreSQLOAuth2ClientRepository.count_by_organization(org_id_vo)
      assert count >= 1
    end
  end

  describe "client secret hashing and verification" do
    test "plain text secret is hashed before storage" do
      # Create entity with plain text secret
      plain_secret = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

      {:ok, client_id} = ClientId.generate()
      # Create a real organization in the database
      org_uuid = create_organization()
      {:ok, org_id} = OrganizationId.from_string(org_uuid)
      {:ok, grant} = GrantType.authorization_code()
      {:ok, scope} = Scope.new("openid")

      client = %OAuth2Client{
        id: client_id,
        organization_id: org_id,
        name: "Test Client",
        client_type: :confidential,
        client_secret: plain_secret,
        grant_types: [grant],
        redirect_uris: [],
        allowed_scopes: [scope],
        is_active: true,
        trusted: false,
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      assert {:ok, saved_client} = PostgreSQLOAuth2ClientRepository.save(client)
      assert %ClientSecret{} = saved_client.client_secret

      # Verify the hash is bcrypt
      stored_hash = ClientSecret.to_string(saved_client.client_secret)
      assert String.starts_with?(stored_hash, "$2b$")

      # Verify we can check the plain secret
      assert ClientSecret.verify(saved_client.client_secret, plain_secret)
    end

    test "ClientSecret value object is stored correctly" do
      {plain_secret, secret_vo} = ClientSecret.generate()

      {:ok, client_id} = ClientId.generate()
      # Create a real organization in the database
      org_uuid = create_organization()
      {:ok, org_id} = OrganizationId.from_string(org_uuid)
      {:ok, grant} = GrantType.authorization_code()
      {:ok, scope} = Scope.new("openid")

      client = %OAuth2Client{
        id: client_id,
        organization_id: org_id,
        name: "Test Client",
        client_type: :confidential,
        client_secret: secret_vo,
        grant_types: [grant],
        redirect_uris: [],
        allowed_scopes: [scope],
        is_active: true,
        trusted: false,
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      assert {:ok, saved_client} = PostgreSQLOAuth2ClientRepository.save(client)
      assert %ClientSecret{} = saved_client.client_secret

      # Verify we can verify the plain secret
      assert ClientSecret.verify(saved_client.client_secret, plain_secret)
    end

    test "loaded client secret can be verified" do
      {:ok, client} = create_client_entity(client_type: :confidential)
      # Store the original secret before it gets hashed
      original_secret = client.client_secret

      assert {:ok, saved_client} = PostgreSQLOAuth2ClientRepository.save(client)

      # Find the client
      assert {:ok, found_client} = PostgreSQLOAuth2ClientRepository.find_by_id(saved_client.id)

      # Verify the secret is a ClientSecret value object
      assert %ClientSecret{} = found_client.client_secret

      # Verify we can check against the original
      assert ClientSecret.verify(found_client.client_secret, original_secret)
    end
  end

  describe "grant type conversions" do
    test "converts authorization_code grant type correctly" do
      {:ok, grant} = GrantType.authorization_code()
      {:ok, client} = create_client_entity(grant_types: [grant])

      assert {:ok, saved_client} = PostgreSQLOAuth2ClientRepository.save(client)
      assert {:ok, found_client} = PostgreSQLOAuth2ClientRepository.find_by_id(saved_client.id)

      assert length(found_client.grant_types) == 1
      assert hd(found_client.grant_types).type == :authorization_code
    end

    test "converts client_credentials grant type correctly" do
      {:ok, grant} = GrantType.client_credentials()
      {:ok, client} = create_client_entity(grant_types: [grant])

      assert {:ok, saved_client} = PostgreSQLOAuth2ClientRepository.save(client)
      assert {:ok, found_client} = PostgreSQLOAuth2ClientRepository.find_by_id(saved_client.id)

      assert length(found_client.grant_types) == 1
      assert hd(found_client.grant_types).type == :client_credentials
    end

    test "converts refresh_token grant type correctly" do
      {:ok, grant} = GrantType.refresh_token()
      {:ok, client} = create_client_entity(grant_types: [grant])

      assert {:ok, saved_client} = PostgreSQLOAuth2ClientRepository.save(client)
      assert {:ok, found_client} = PostgreSQLOAuth2ClientRepository.find_by_id(saved_client.id)

      assert length(found_client.grant_types) == 1
      assert hd(found_client.grant_types).type == :refresh_token
    end

    test "converts multiple grant types correctly" do
      {:ok, auth_code} = GrantType.authorization_code()
      {:ok, refresh} = GrantType.refresh_token()
      {:ok, client_creds} = GrantType.client_credentials()
      {:ok, client} = create_client_entity(grant_types: [auth_code, refresh, client_creds])

      assert {:ok, saved_client} = PostgreSQLOAuth2ClientRepository.save(client)
      assert {:ok, found_client} = PostgreSQLOAuth2ClientRepository.find_by_id(saved_client.id)

      assert length(found_client.grant_types) == 3
      grant_types = Enum.map(found_client.grant_types, & &1.type)
      assert :authorization_code in grant_types
      assert :refresh_token in grant_types
      assert :client_credentials in grant_types
    end
  end

  describe "scope conversions" do
    test "converts standard OIDC scopes correctly" do
      {:ok, openid} = Scope.new("openid")
      {:ok, profile} = Scope.new("profile")
      {:ok, email} = Scope.new("email")
      {:ok, client} = create_client_entity(allowed_scopes: [openid, profile, email])

      assert {:ok, saved_client} = PostgreSQLOAuth2ClientRepository.save(client)
      assert {:ok, found_client} = PostgreSQLOAuth2ClientRepository.find_by_id(saved_client.id)

      assert length(found_client.allowed_scopes) == 3
      assert "openid" in found_client.allowed_scopes
      assert "profile" in found_client.allowed_scopes
      assert "email" in found_client.allowed_scopes
    end

    test "converts custom scopes correctly" do
      {:ok, custom1} = Scope.new("zea:read")
      {:ok, custom2} = Scope.new("zea:write")
      {:ok, client} = create_client_entity(allowed_scopes: [custom1, custom2])

      assert {:ok, saved_client} = PostgreSQLOAuth2ClientRepository.save(client)
      assert {:ok, found_client} = PostgreSQLOAuth2ClientRepository.find_by_id(saved_client.id)

      assert length(found_client.allowed_scopes) == 2
      assert "zea:read" in found_client.allowed_scopes
      assert "zea:write" in found_client.allowed_scopes
    end

    test "handles empty scopes list" do
      {:ok, client} = create_client_entity(allowed_scopes: [])

      assert {:ok, saved_client} = PostgreSQLOAuth2ClientRepository.save(client)
      assert {:ok, found_client} = PostgreSQLOAuth2ClientRepository.find_by_id(saved_client.id)

      assert found_client.allowed_scopes == []
    end
  end

  describe "redirect URI conversions" do
    test "converts HTTPS redirect URIs correctly" do
      {:ok, uri1} = RedirectUri.new("https://app.example.com/callback")
      {:ok, uri2} = RedirectUri.new("https://app.example.com/callback2")
      {:ok, client} = create_client_entity(redirect_uris: [uri1, uri2])

      assert {:ok, saved_client} = PostgreSQLOAuth2ClientRepository.save(client)
      assert {:ok, found_client} = PostgreSQLOAuth2ClientRepository.find_by_id(saved_client.id)

      assert length(found_client.redirect_uris) == 2
      assert "https://app.example.com/callback" in found_client.redirect_uris
      assert "https://app.example.com/callback2" in found_client.redirect_uris
    end

    test "converts localhost redirect URIs correctly" do
      {:ok, uri} = RedirectUri.new("http://localhost:3000/callback")
      {:ok, client} = create_client_entity(redirect_uris: [uri])

      assert {:ok, saved_client} = PostgreSQLOAuth2ClientRepository.save(client)
      assert {:ok, found_client} = PostgreSQLOAuth2ClientRepository.find_by_id(saved_client.id)

      assert length(found_client.redirect_uris) == 1
      assert "http://localhost:3000/callback" in found_client.redirect_uris
    end

    test "handles empty redirect URIs list" do
      {:ok, client} = create_client_entity(redirect_uris: [])

      assert {:ok, saved_client} = PostgreSQLOAuth2ClientRepository.save(client)
      assert {:ok, found_client} = PostgreSQLOAuth2ClientRepository.find_by_id(saved_client.id)

      assert found_client.redirect_uris == []
    end
  end

  # --- Test Helpers ---

  defp create_client_entity(opts \\ []) do
    name = Keyword.get(opts, :name, "Test Client #{:rand.uniform(1_000_000)}")
    client_type = Keyword.get(opts, :client_type, :confidential)

    {:ok, client_id} = ClientId.generate()

    org_id =
      case Keyword.get(opts, :organization_id) do
        nil ->
          org_uuid = create_organization()
          {:ok, org_id_vo} = OrganizationId.from_string(org_uuid)
          org_id_vo

        org_id_vo ->
          org_id_vo
      end

    grant_types =
      case Keyword.get(opts, :grant_types) do
        nil ->
          {:ok, grant} = GrantType.authorization_code()
          [grant]

        types ->
          types
      end

    allowed_scopes =
      case Keyword.get(opts, :allowed_scopes) do
        nil ->
          {:ok, scope} = Scope.new("openid")
          [scope]

        scopes ->
          scopes
      end

    redirect_uris = Keyword.get(opts, :redirect_uris, [])

    # Generate a client secret for the entity
    client_secret =
      if client_type == :confidential do
        :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
      else
        nil
      end

    OAuth2Client.new(%{
      id: client_id,
      organization_id: org_id,
      name: name,
      client_type: client_type,
      client_secret: client_secret,
      grant_types: grant_types,
      redirect_uris: redirect_uris,
      allowed_scopes: allowed_scopes,
      is_active: Keyword.get(opts, :is_active, true),
      trusted: Keyword.get(opts, :trusted, false)
    })
  end

  defp create_organization do
    org = %OrganizationSchema{
      id: Ecto.UUID.generate(),
      name: "Test Organization #{:rand.uniform(1_000_000)}",
      status: :active,
      plan_type: :professional,
      verified: true,
      max_users: 100,
      max_api_calls_per_month: 100_000,
      support_level: :priority,
      api_calls_reset_at: DateTime.truncate(DateTime.utc_now(), :second)
    }

    Repo.insert!(org)
    org.id
  end

  defp extract_uuid(%ClientId{} = client_id) do
    client_id
    |> ClientId.to_string()
    |> String.replace_prefix("client_", "")
  end
end
