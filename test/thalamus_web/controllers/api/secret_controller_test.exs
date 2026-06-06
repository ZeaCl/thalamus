defmodule ThalamusWeb.API.SecretControllerTest do
  use ThalamusWeb.ConnCase

  alias Thalamus.Application.UseCases.ManageSecrets

  setup %{conn: conn} do
    # Use JwtSigner to create a valid access token
    user_id = Ecto.UUID.generate()

    token =
      Thalamus.Infrastructure.JwtSigner.sign_access_token(%{
        "sub" => user_id,
        "scope" => "api:admin"
      })

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "Bearer #{token}")

    %{conn: conn, user_id: user_id}
  end

  describe "resolve" do
    test "returns the decrypted secret value", %{conn: conn, user_id: user_id} do
      ManageSecrets.create_secret(%{
        owner_type: "user",
        owner_id: user_id,
        provider: "stitch",
        name: "Test Key",
        value: "123456"
      })

      org_id = Ecto.UUID.generate()

      conn =
        get(
          conn,
          ~p"/api/internal/secrets/resolve?provider=stitch&user_id=#{user_id}&org_id=#{org_id}&prefer_user=true"
        )

      assert response = json_response(conn, 200)
      assert response["provider"] == "stitch"
      # Should be decrypted
      assert response["value"] == "123456"
    end
  end
end
