defmodule ThalamusWeb.Plugs.SecurityHeadersTest do
  use ThalamusWeb.ConnCase, async: true

  alias ThalamusWeb.Plugs.SecurityHeaders

  test "call/2 sets default security headers" do
    conn = build_conn() |> SecurityHeaders.call(%{})

    assert Plug.Conn.get_resp_header(conn, "content-security-policy") != []
    assert Plug.Conn.get_resp_header(conn, "x-frame-options") == ["SAMEORIGIN"]
    assert Plug.Conn.get_resp_header(conn, "x-content-type-options") == ["nosniff"]
  end

  describe "add_form_action/2" do
    test "appends host to form-action directive dynamically" do
      # 1. Initialize conn with default headers
      conn = build_conn() |> SecurityHeaders.call(%{})

      # 2. Get the original CSP
      [original_csp] = Plug.Conn.get_resp_header(conn, "content-security-policy")
      refute original_csp =~ "http://test-dynamic-host.com:*"

      # 3. Call the new function
      conn = SecurityHeaders.add_form_action(conn, "test-dynamic-host.com")

      # 4. Verify it was added
      [new_csp] = Plug.Conn.get_resp_header(conn, "content-security-policy")
      assert new_csp =~ "form-action "
      assert new_csp =~ "http://test-dynamic-host.com:*"
      assert new_csp =~ "https://test-dynamic-host.com:*"
    end

    test "does nothing if CSP header is missing" do
      # A clean conn without SecurityHeaders.call
      conn = build_conn()

      conn = SecurityHeaders.add_form_action(conn, "test.com")

      assert Plug.Conn.get_resp_header(conn, "content-security-policy") == []
    end
  end
end
