defmodule ThalamusWeb.API.AvatarControllerTest do
  use ThalamusWeb.ConnCase, async: true

  alias Thalamus.Domain.Entities.{User, Organization}
  alias Thalamus.Domain.ValueObjects.{AccessToken, Scope}
  alias Thalamus.TestHelpers

  alias Thalamus.Infrastructure.Repositories.{
    PostgreSQLUserRepository,
    PostgreSQLOrganizationRepository,
    PostgreSQLOAuth2ClientRepository,
    PostgreSQLTokenRepository
  }

  @upload_dir "priv/static/uploads/avatars"

  setup do
    # Ensure upload directory exists
    File.mkdir_p!(@upload_dir)

    # Create organization for OAuth2 client
    {:ok, org} = Organization.new("Test Corp", "owner@test.com", :standard)
    {:ok, org} = PostgreSQLOrganizationRepository.save(org)

    # Create and verify user
    {:ok, user} = User.register("avatartest@test.com", "TestPassword123!")
    {:ok, user} = User.verify_email(user)
    {:ok, user} = PostgreSQLUserRepository.save(user)

    # Create OAuth2 client
    {:ok, client} =
      TestHelpers.create_test_client("Test Client", org.id, ["openid", "profile"])

    {:ok, client} = PostgreSQLOAuth2ClientRepository.save(client)

    # Generate access token for authenticated requests
    {:ok, openid_scope} = Scope.new("openid")
    {:ok, profile_scope} = Scope.new("profile")
    scopes = [openid_scope, profile_scope]

    {:ok, access_token} =
      AccessToken.generate(
        scopes,
        user.id,
        3600
      )

    # Extract client ID without "client_" prefix for DB storage
    client_id_string = Thalamus.Domain.ValueObjects.ClientId.to_string(client.id)
    client_uuid = String.replace_prefix(client_id_string, "client_", "")

    token_data = %{
      token: access_token.token,
      type: :access_token,
      user_id: user.id,
      client_id: client_uuid,
      scopes: ["openid", "profile"],
      expires_at: access_token.expires_at
    }

    :ok = PostgreSQLTokenRepository.store(token_data)

    {:ok, %{user: user, access_token: access_token.token}}
  end

  describe "POST /api/avatar - upload avatar" do
    test "uploads avatar successfully with valid image", %{
      conn: conn,
      user: user,
      access_token: token
    } do
      # Create a small test image (1x1 PNG)
      image_data = create_test_png()

      upload = %Plug.Upload{
        path: write_temp_file(image_data),
        filename: "avatar.png",
        content_type: "image/png"
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/avatar", %{"avatar" => upload})

      assert %{
               "data" => %{
                 "avatar_url" => avatar_url,
                 "user_id" => user_id
               },
               "message" => message
             } = json_response(conn, 200)

      assert String.starts_with?(avatar_url, "/uploads/avatars/")
      assert user_id == Thalamus.Domain.ValueObjects.UserId.to_string(user.id)
      assert String.contains?(message, "successfully")

      # Verify user has avatar_url set in database
      {:ok, updated_user} = PostgreSQLUserRepository.find_by_id(user.id)
      assert updated_user.avatar_url == avatar_url

      # Cleanup
      File.rm(upload.path)
    end

    test "replaces existing avatar when uploading new one", %{
      conn: conn,
      user: user,
      access_token: token
    } do
      # Upload first avatar
      image_data = create_test_png()

      upload1 = %Plug.Upload{
        path: write_temp_file(image_data),
        filename: "avatar1.png",
        content_type: "image/png"
      }

      conn1 =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/avatar", %{"avatar" => upload1})

      %{"data" => %{"avatar_url" => first_url}} = json_response(conn1, 200)

      # Upload second avatar (should replace first)
      upload2 = %Plug.Upload{
        path: write_temp_file(image_data),
        filename: "avatar2.png",
        content_type: "image/png"
      }

      conn2 =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/avatar", %{"avatar" => upload2})

      %{"data" => %{"avatar_url" => second_url}} = json_response(conn2, 200)

      assert second_url != first_url

      # Verify user has new avatar
      {:ok, updated_user} = PostgreSQLUserRepository.find_by_id(user.id)
      assert updated_user.avatar_url == second_url

      # Cleanup
      File.rm(upload1.path)
      File.rm(upload2.path)
    end

    test "returns error when no file is uploaded", %{conn: conn, access_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/avatar", %{})

      assert %{
               "error" => error
             } = json_response(conn, 400)

      assert String.contains?(error, "No file uploaded")
    end

    test "returns error when file is too large", %{conn: conn, access_token: token} do
      # Create a file larger than 5MB (we'll simulate this with metadata)
      image_data = create_test_png()
      temp_file = write_temp_file(image_data)

      # Mock a large file by creating it with many bytes
      # 6MB
      large_data = :binary.copy(<<0>>, 6 * 1024 * 1024)
      File.write!(temp_file, large_data)

      upload = %Plug.Upload{
        path: temp_file,
        filename: "large_avatar.png",
        content_type: "image/png"
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/avatar", %{"avatar" => upload})

      assert %{
               "error" => error
             } = json_response(conn, 413)

      assert String.contains?(error, "too large") or String.contains?(error, "5MB")

      # Cleanup
      File.rm(temp_file)
    end

    test "returns error with invalid content type", %{conn: conn, access_token: token} do
      # Create a text file instead of an image
      text_data = "This is not an image"

      upload = %Plug.Upload{
        path: write_temp_file(text_data),
        filename: "not_an_image.txt",
        content_type: "text/plain"
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/avatar", %{"avatar" => upload})

      assert %{
               "error" => error
             } = json_response(conn, 400)

      assert String.contains?(error, "Invalid file type") or String.contains?(error, "allowed")

      # Cleanup
      File.rm(upload.path)
    end

    test "requires authentication", %{conn: conn} do
      image_data = create_test_png()

      upload = %Plug.Upload{
        path: write_temp_file(image_data),
        filename: "avatar.png",
        content_type: "image/png"
      }

      conn = post(conn, ~p"/api/avatar", %{"avatar" => upload})

      assert json_response(conn, 401)

      # Cleanup
      File.rm(upload.path)
    end

    test "accepts JPEG images", %{conn: conn, access_token: token} do
      # Using PNG data but marking as JPEG for test
      image_data = create_test_png()

      upload = %Plug.Upload{
        path: write_temp_file(image_data),
        filename: "avatar.jpg",
        content_type: "image/jpeg"
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/avatar", %{"avatar" => upload})

      assert %{"data" => %{"avatar_url" => _}} = json_response(conn, 200)

      # Cleanup
      File.rm(upload.path)
    end

    test "accepts WebP images", %{conn: conn, access_token: token} do
      image_data = create_test_png()

      upload = %Plug.Upload{
        path: write_temp_file(image_data),
        filename: "avatar.webp",
        content_type: "image/webp"
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/avatar", %{"avatar" => upload})

      assert %{"data" => %{"avatar_url" => _}} = json_response(conn, 200)

      # Cleanup
      File.rm(upload.path)
    end
  end

  describe "DELETE /api/avatar - delete avatar" do
    test "deletes avatar successfully", %{conn: conn, user: user, access_token: token} do
      # First upload an avatar
      image_data = create_test_png()

      upload = %Plug.Upload{
        path: write_temp_file(image_data),
        filename: "avatar.png",
        content_type: "image/png"
      }

      upload_conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/avatar", %{"avatar" => upload})

      %{"data" => %{"avatar_url" => avatar_url}} = json_response(upload_conn, 200)

      # Now delete it
      delete_conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> delete(~p"/api/avatar")

      assert %{
               "message" => message
             } = json_response(delete_conn, 200)

      assert String.contains?(message, "deleted") or String.contains?(message, "success")

      # Verify avatar is removed from database
      {:ok, updated_user} = PostgreSQLUserRepository.find_by_id(user.id)
      assert is_nil(updated_user.avatar_url)

      # Verify file is deleted from filesystem
      filename = String.replace(avatar_url, "/uploads/avatars/", "")
      file_path = Path.join(@upload_dir, filename)
      refute File.exists?(file_path)

      # Cleanup
      File.rm(upload.path)
    end

    test "returns error when no avatar is set", %{conn: conn, access_token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> delete(~p"/api/avatar")

      assert %{
               "error" => error
             } = json_response(conn, 404)

      assert String.contains?(error, "No avatar")
    end

    test "requires authentication", %{conn: conn} do
      conn = delete(conn, ~p"/api/avatar")

      assert json_response(conn, 401)
    end
  end

  # Helper functions

  defp create_test_png do
    # Minimal valid 1x1 PNG file (base64 decoded)
    Base.decode64!(
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
    )
  end

  defp write_temp_file(data) do
    temp_file = Path.join(System.tmp_dir!(), "test_upload_#{:rand.uniform(999_999)}.png")
    File.write!(temp_file, data)
    temp_file
  end
end
