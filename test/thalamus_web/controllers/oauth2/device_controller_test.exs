defmodule ThalamusWeb.OAuth2.DeviceControllerTest do
  use ThalamusWeb.ConnCase, async: false

  alias Thalamus.Domain.Entities.Organization
  alias Thalamus.Domain.ValueObjects.ClientId
  alias Thalamus.TestHelpers

  alias Thalamus.Infrastructure.Repositories.{
    PostgreSQLOAuth2ClientRepository,
    PostgreSQLOrganizationRepository
  }

  setup do
    {:ok, org} = Organization.new("Test Corp", "owner@test.com", :standard)
    {:ok, org} = PostgreSQLOrganizationRepository.save(org)

    {:ok, client} =
      TestHelpers.create_test_client(
        "Device Test Client",
        org.id,
        ["openid", "profile", "email"]
      )

    {:ok, client} = PostgreSQLOAuth2ClientRepository.save(client)

    client_id = ClientId.to_string(client.id)

    {:ok, %{client_id: client_id}}
  end

  describe "POST /oauth/device" do
    test "omits :80 from verification_uri when public_port is 80 behind https proxy (issue #160)",
         %{conn: conn, client_id: client_id} do
      Application.put_env(:thalamus, :host, "auth.zea.cl")
      Application.put_env(:thalamus, :public_port, 80)

      on_exit(fn ->
        Application.delete_env(:thalamus, :host)
        Application.delete_env(:thalamus, :public_port)
      end)

      conn =
        conn
        |> Plug.Conn.put_req_header("x-forwarded-proto", "https")
        |> post(~p"/oauth/device", %{client_id: client_id, scope: "openid profile"})

      response = json_response(conn, 200)

      assert response["verification_uri"] == "https://auth.zea.cl/oauth/activate"
      assert response["verification_uri_complete"] =~ "?code="
      refute response["verification_uri"] =~ ":80"
      refute response["verification_uri_complete"] =~ ":80"
    end

    test "omits :443 from verification_uri when public_port is 443", %{
      conn: conn,
      client_id: client_id
    } do
      Application.put_env(:thalamus, :host, "auth.zea.cl")
      Application.put_env(:thalamus, :public_port, 443)

      on_exit(fn ->
        Application.delete_env(:thalamus, :host)
        Application.delete_env(:thalamus, :public_port)
      end)

      conn =
        conn
        |> Plug.Conn.put_req_header("x-forwarded-proto", "https")
        |> post(~p"/oauth/device", %{client_id: client_id, scope: "openid profile"})

      response = json_response(conn, 200)

      assert response["verification_uri"] == "https://auth.zea.cl/oauth/activate"
      refute response["verification_uri"] =~ ":443"
    end

    test "keeps a non-default public_port in verification_uri", %{
      conn: conn,
      client_id: client_id
    } do
      Application.put_env(:thalamus, :host, "auth.zea.cl")
      Application.put_env(:thalamus, :public_port, 8443)

      on_exit(fn ->
        Application.delete_env(:thalamus, :host)
        Application.delete_env(:thalamus, :public_port)
      end)

      conn =
        conn
        |> Plug.Conn.put_req_header("x-forwarded-proto", "https")
        |> post(~p"/oauth/device", %{client_id: client_id, scope: "openid profile"})

      response = json_response(conn, 200)

      assert response["verification_uri"] == "https://auth.zea.cl:8443/oauth/activate"
    end

    test "returns device_code and user_code on success", %{conn: conn, client_id: client_id} do
      conn =
        post(conn, ~p"/oauth/device", %{client_id: client_id, scope: "openid profile"})

      response = json_response(conn, 200)

      assert is_binary(response["device_code"])
      assert is_binary(response["user_code"])
      assert response["expires_in"] == 600
      assert is_integer(response["interval"])
    end

    test "returns invalid_client for unknown client_id", %{conn: conn} do
      conn =
        post(conn, ~p"/oauth/device", %{
          client_id: "client_does_not_exist",
          scope: "openid"
        })

      assert %{"error" => "invalid_client"} = json_response(conn, 401)
    end
  end
end
