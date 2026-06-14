defmodule ThalamusWeb.Plugs.SecurityHeaders do
  @moduledoc """
  Security Headers Plug.

  Adds security-related HTTP headers to all responses to protect
  against common web vulnerabilities.

  SOLID Principles Applied:
  - Single Responsibility: Only handles security headers
  - Open/Closed: Configurable without code changes

  ## Headers Added

  - **Content-Security-Policy**: Prevents XSS and injection attacks
  - **X-Frame-Options**: Prevents clickjacking
  - **X-Content-Type-Options**: Prevents MIME-type sniffing
  - **X-XSS-Protection**: Legacy XSS protection
  - **Strict-Transport-Security**: Enforces HTTPS
  - **Referrer-Policy**: Controls referrer information
  - **Permissions-Policy**: Controls browser features

  ## Configuration

  In config/config.exs:

      config :thalamus, ThalamusWeb.Plugs.SecurityHeaders,
        csp_policy: "default-src 'self'; script-src 'self' 'unsafe-inline'",
        hsts_max_age: 31_536_000,
        frame_options: "DENY"

  ## Usage

  Add to your endpoint.ex before other plugs:

      plug ThalamusWeb.Plugs.SecurityHeaders

  ## Security Headers Explained

  ### Content-Security-Policy (CSP)
  Controls which resources can be loaded. Prevents XSS attacks.

  ### X-Frame-Options
  Prevents the page from being embedded in iframes (clickjacking protection).
  Options: DENY, SAMEORIGIN

  ### X-Content-Type-Options
  Prevents browsers from MIME-sniffing responses.
  Always set to "nosniff".

  ### Strict-Transport-Security (HSTS)
  Forces browsers to use HTTPS for future requests.
  Only added if connection is HTTPS.

  ### Referrer-Policy
  Controls how much referrer information is sent with requests.
  """

  import Plug.Conn

  # Default security policies
  @default_csp_policy """
                      default-src 'self'; \
                      script-src 'self' 'unsafe-inline' 'unsafe-eval'; \
                      style-src 'self' 'unsafe-inline'; \
                      img-src 'self' data: https:; \
                      font-src 'self' data:; \
                      connect-src 'self' ws://localhost:* wss://localhost:*; \
                      frame-src 'self'; \
                      frame-ancestors 'none'; \
                      base-uri 'self'; \
                      form-action 'self' http://localhost:* http://auth.zea.localhost:* http://soma.zea.localhost:* http://cranium.zea.localhost:* http://sudlich.zea.localhost:* http://*.zea.localhost:*
                      """
                      |> String.replace(~r/\s+/, " ")
                      |> String.trim()

  # 1 year
  @default_hsts_max_age 31_536_000
  @default_frame_options "DENY"
  @default_referrer_policy "strict-origin-when-cross-origin"

  def init(opts), do: opts

  def call(conn, _opts) do
    config = get_config()

    conn
    |> put_csp_header(config.csp_policy)
    |> put_resp_header("x-frame-options", config.frame_options)
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-xss-protection", "1; mode=block")
    |> put_resp_header("referrer-policy", config.referrer_policy)
    |> put_resp_header("permissions-policy", build_permissions_policy())
    |> maybe_put_hsts_header(config.hsts_max_age)
  end

  # Private functions

  defp put_csp_header(conn, policy) do
    # Apply the configured CSP policy to all responses
    # The default policy is permissive enough for HTML and secure enough for APIs
    put_resp_header(conn, "content-security-policy", policy)
  end

  defp maybe_put_hsts_header(conn, max_age) do
    # Only add HSTS header if connection is HTTPS
    if conn.scheme == :https do
      hsts_value = "max-age=#{max_age}; includeSubDomains; preload"
      put_resp_header(conn, "strict-transport-security", hsts_value)
    else
      conn
    end
  end

  defp build_permissions_policy do
    # Restrict potentially dangerous browser features
    # Format: feature=(origin1 origin2) or feature=()
    [
      "accelerometer=()",
      "camera=()",
      "geolocation=()",
      "gyroscope=()",
      "magnetometer=()",
      "microphone=()",
      "payment=()",
      "usb=()"
    ]
    |> Enum.join(", ")
  end

  defp get_config do
    config = Application.get_env(:thalamus, __MODULE__, [])

    %{
      csp_policy: Keyword.get(config, :csp_policy, @default_csp_policy),
      hsts_max_age: Keyword.get(config, :hsts_max_age, @default_hsts_max_age),
      frame_options: Keyword.get(config, :frame_options, @default_frame_options),
      referrer_policy: Keyword.get(config, :referrer_policy, @default_referrer_policy)
    }
  end
end
