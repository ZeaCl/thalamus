defmodule Thalamus.CORSRegistryTest do
  use Thalamus.DataCase

  alias Thalamus.Infrastructure.Persistence.Schemas.{OAuth2ClientSchema, OrganizationSchema}
  alias Thalamus.Repo

  setup do
    # Iniciamos el GenServer (o lo limpiamos si ya estaba corriendo)
    case Thalamus.CORSRegistry.start_link([]) do
      {:ok, _pid} ->
        :ok

      {:error, {:already_started, _pid}} ->
        :ets.delete_all_objects(:cors_registry)
        :ok
    end
  end

  describe "Funciones en memoria" do
    test "inicia vacío, agrega orígenes y evita duplicados" do
      refute Thalamus.CORSRegistry.member?("https://ejemplo.com")

      Thalamus.CORSRegistry.add("https://ejemplo.com")
      Thalamus.CORSRegistry.add("http://localhost:4000")
      Thalamus.CORSRegistry.add("https://ejemplo.com")

      assert Thalamus.CORSRegistry.member?("https://ejemplo.com")
      assert Thalamus.CORSRegistry.member?("http://localhost:4000")
      refute Thalamus.CORSRegistry.member?("https://otro.com")
    end
  end

  describe "rebuild_from_clients/0" do
    test "carga orígenes únicamente desde clientes activos y extrae bien el host" do
      # 1. Creamos una organización usando el changeset para que cargue los defaults
      org_changeset =
        OrganizationSchema.create_changeset(%{
          "name" => "Org Test CORS",
          "plan_type" => :standard,
          "owner_email" => "admin@test.com",
          "status" => :active
        })

      org = Repo.insert!(org_changeset)

      # 2. Insertamos un cliente activo usando su changeset
      client_changeset =
        OAuth2ClientSchema.create_changeset(%{
          "client_id_string" => "client_123",
          "name" => "Test Client",
          "client_type" => :public,
          "organization_id" => org.id,
          "redirect_uris" => [
            "https://app.produccion.com/callback",
            "http://localhost:8080/callback",
            # Esto prueba el bloque `rescue` de `extract_origin/1`
            "invalid-uri"
          ]
        })

      Repo.insert!(client_changeset)

      # 3. Insertamos un cliente inactivo (usamos el changeset y luego lo forzamos a false)
      inactive_changeset =
        OAuth2ClientSchema.create_changeset(%{
          "client_id_string" => "client_inactivo",
          "name" => "Test Inactive Client",
          "client_type" => :public,
          "organization_id" => org.id,
          "redirect_uris" => ["https://app.inactiva.com/callback"]
        })
        |> Ecto.Changeset.put_change(:is_active, false)

      Repo.insert!(inactive_changeset)

      # 4. Ejecutamos la función
      Thalamus.CORSRegistry.rebuild_from_clients()

      # Esperamos un poco porque es un cast asíncrono
      :timer.sleep(50)

      # 5. Validamos
      assert Thalamus.CORSRegistry.member?("https://app.produccion.com")
      assert Thalamus.CORSRegistry.member?("http://localhost:8080")
      refute Thalamus.CORSRegistry.member?("https://app.inactiva.com")
    end
  end
end
