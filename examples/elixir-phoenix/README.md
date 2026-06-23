# Elixir Phoenix Example with Thalamus

Phoenix LiveView application demonstrating OAuth2 integration with Thalamus using the `oauth2` Elixir library.

## Features

- ✅ Phoenix 1.7+ with LiveView
- ✅ OAuth2 Authorization Code Flow
- ✅ Session-based authentication
- ✅ Protected LiveView pages
- ✅ Token management and refresh
- ✅ Real-time user interface

## Prerequisites

1. **Running Thalamus server** at `http://localhost:4000`
2. **Elixir 1.14+** and **Erlang/OTP 25+** installed
3. **PostgreSQL** running (for session storage)
4. **OAuth2 Client created** in Thalamus dashboard

## Setup

### 1. Create New Phoenix App

```bash
mix phx.new thalamus_phoenix_example --no-ecto
cd thalamus_phoenix_example
```

Or integrate into existing Phoenix app by following steps 2-5.

### 2. Add Dependencies

Add to `mix.exs`:

```elixir
defp deps do
  [
    # ... existing deps
    {:oauth2, "~> 2.1"},
    {:req, "~> 0.4"}
  ]
end
```

Install:
```bash
mix deps.get
```

### 3. Configure OAuth2 Client

Create `lib/thalamus_phoenix_example/thalamus_oauth.ex`:

```elixir
defmodule ThalamusPhoenixExample.ThalamusOAuth do
  @moduledoc """
  OAuth2 client for Thalamus authentication.
  """

  use OAuth2.Strategy.AuthCode

  alias OAuth2.Client
  alias OAuth2.Strategy.AuthCode

  # OAuth2 configuration
  def client do
    base_url = Application.get_env(:thalamus_phoenix_example, :thalamus_base_url)

    Client.new([
      strategy: __MODULE__,
      client_id: Application.get_env(:thalamus_phoenix_example, :thalamus_client_id),
      client_secret: Application.get_env(:thalamus_phoenix_example, :thalamus_client_secret),
      redirect_uri: Application.get_env(:thalamus_phoenix_example, :thalamus_redirect_uri),
      site: base_url,
      authorize_url: "#{base_url}/oauth/authorize",
      token_url: "#{base_url}/oauth/token"
    ])
  end

  # Generate authorization URL
  def authorize_url!(params \\ []) do
    Client.authorize_url!(
      client(),
      Keyword.merge([scope: "openid profile email"], params)
    )
  end

  # Exchange authorization code for access token
  def get_token!(params \\ [], _headers \\ [], _opts \\ []) do
    Client.get_token!(client(), params)
  end

  # Get user info from access token
  def get_user_info!(access_token) do
    base_url = Application.get_env(:thalamus_phoenix_example, :thalamus_base_url)

    response = Req.get!(
      "#{base_url}/oauth/userinfo",
      headers: [{"authorization", "Bearer #{access_token}"}]
    )

    response.body
  end

  # Refresh access token
  def refresh_token!(refresh_token) do
    client()
    |> Client.put_param(:grant_type, "refresh_token")
    |> Client.put_param(:refresh_token, refresh_token)
    |> Client.get_token!()
  end

  # Revoke token
  def revoke_token!(access_token) do
    base_url = Application.get_env(:thalamus_phoenix_example, :thalamus_base_url)

    Req.post!(
      "#{base_url}/oauth/revoke",
      form: [
        token: access_token,
        client_id: Application.get_env(:thalamus_phoenix_example, :thalamus_client_id),
        client_secret: Application.get_env(:thalamus_phoenix_example, :thalamus_client_secret)
      ]
    )
  end
end
```

### 4. Add Configuration

Add to `config/dev.exs`:

```elixir
config :thalamus_phoenix_example,
  thalamus_base_url: "http://localhost:4000",
  thalamus_client_id: System.get_env("THALAMUS_CLIENT_ID") || "your_client_id",
  thalamus_client_secret: System.get_env("THALAMUS_CLIENT_SECRET") || "your_client_secret",
  thalamus_redirect_uri: "http://localhost:4001/auth/callback"
```

Add to `config/runtime.exs`:

```elixir
if config_env() == :prod do
  config :thalamus_phoenix_example,
    thalamus_base_url: System.fetch_env!("THALAMUS_BASE_URL"),
    thalamus_client_id: System.fetch_env!("THALAMUS_CLIENT_ID"),
    thalamus_client_secret: System.fetch_env!("THALAMUS_CLIENT_SECRET"),
    thalamus_redirect_uri: System.fetch_env!("THALAMUS_REDIRECT_URI")
end
```

### 5. Create Authentication Controllers

Create `lib/thalamus_phoenix_example_web/controllers/auth_controller.ex`:

```elixir
defmodule ThalamusPhoenixExampleWeb.AuthController do
  use ThalamusPhoenixExampleWeb, :controller

  alias ThalamusPhoenixExample.ThalamusOAuth

  def login(conn, _params) do
    # Redirect to Thalamus authorization page
    redirect(conn, external: ThalamusOAuth.authorize_url!())
  end

  def callback(conn, %{"code" => code}) do
    # Exchange authorization code for access token
    client = ThalamusOAuth.get_token!(code: code)
    access_token = client.token.access_token
    refresh_token = client.token.refresh_token

    # Get user info
    user_info = ThalamusOAuth.get_user_info!(access_token)

    # Store in session
    conn
    |> put_session(:access_token, access_token)
    |> put_session(:refresh_token, refresh_token)
    |> put_session(:current_user, user_info)
    |> put_flash(:info, "Successfully authenticated!")
    |> redirect(to: ~p"/dashboard")
  end

  def callback(conn, %{"error" => error, "error_description" => description}) do
    conn
    |> put_flash(:error, "Authentication failed: #{description}")
    |> redirect(to: ~p"/")
  end

  def logout(conn, _params) do
    # Revoke token
    case get_session(conn, :access_token) do
      nil -> :ok
      token -> ThalamusOAuth.revoke_token!(token)
    end

    # Clear session
    conn
    |> configure_session(drop: true)
    |> put_flash(:info, "Logged out successfully")
    |> redirect(to: ~p"/")
  end
end
```

### 6. Add Routes

Update `lib/thalamus_phoenix_example_web/router.ex`:

```elixir
scope "/", ThalamusPhoenixExampleWeb do
  pipe_through :browser

  get "/", PageController, :home
  get "/auth/login", AuthController, :login
  get "/auth/callback", AuthController, :callback
  delete "/auth/logout", AuthController, :logout
end

# Protected routes
scope "/", ThalamusPhoenixExampleWeb do
  pipe_through [:browser, :require_auth]

  live "/dashboard", DashboardLive
  live "/profile", ProfileLive
end
```

### 7. Create Auth Plug

Create `lib/thalamus_phoenix_example_web/plugs/require_auth.ex`:

```elixir
defmodule ThalamusPhoenixExampleWeb.Plugs.RequireAuth do
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    if get_session(conn, :current_user) do
      conn
    else
      conn
      |> put_flash(:error, "You must be logged in to access this page")
      |> redirect(to: "/")
      |> halt()
    end
  end
end
```

Add to router:

```elixir
pipeline :require_auth do
  plug ThalamusPhoenixExampleWeb.Plugs.RequireAuth
end
```

### 8. Create LiveView Pages

Create `lib/thalamus_phoenix_example_web/live/dashboard_live.ex`:

```elixir
defmodule ThalamusPhoenixExampleWeb.DashboardLive do
  use ThalamusPhoenixExampleWeb, :live_view

  def mount(_params, session, socket) do
    user = session["current_user"]

    {:ok, assign(socket, :user, user)}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto py-10">
      <h1 class="text-3xl font-bold mb-6">Dashboard</h1>

      <div class="bg-white shadow rounded-lg p-6">
        <h2 class="text-xl font-semibold mb-4">
          Welcome, <%= @user["name"] || @user["email"] %>!
        </h2>

        <div class="space-y-2">
          <div>
            <strong>Email:</strong> <%= @user["email"] %>
          </div>
          <%= if @user["name"] do %>
            <div>
              <strong>Name:</strong> <%= @user["name"] %>
            </div>
          <% end %>
          <div>
            <strong>User ID:</strong> <%= @user["sub"] %>
          </div>
        </div>

        <div class="mt-6 flex gap-4">
          <.link navigate={~p"/profile"} class="btn btn-primary">
            View Full Profile
          </.link>

          <.link href={~p"/auth/logout"} method="delete" class="btn btn-danger">
            Sign Out
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
```

### 9. Create OAuth2 Client in Thalamus

1. Go to http://localhost:4000/dashboard/clients
2. Click "New Client"
3. Fill in:
   - **Name**: "Phoenix Example App"
   - **Client Type**: Confidential (with client secret)
   - **Grant Types**: Enable "Authorization Code"
   - **Redirect URIs**: `http://localhost:4001/auth/callback`
   - **Scopes**: `openid`, `profile`, `email`
4. Save and copy the `client_id` and `client_secret`
5. Set as environment variables or update `config/dev.exs`

## Running

```bash
# Set environment variables
export THALAMUS_CLIENT_ID="your_client_id"
export THALAMUS_CLIENT_SECRET="your_client_secret"

# Start Phoenix server
mix phx.server

# Or with IEx
iex -S mix phx.server
```

Visit http://localhost:4001

## How It Works

### 1. Authorization Flow

1. User clicks "Login" → redirects to `/auth/login`
2. App redirects to Thalamus `/oauth/authorize`
3. User logs in at Thalamus
4. Thalamus redirects to `/auth/callback?code=...`
5. App exchanges code for access token
6. App gets user info and stores in session
7. User is redirected to dashboard

### 2. Session Management

User data and tokens are stored in encrypted Phoenix sessions:

```elixir
conn
|> put_session(:access_token, access_token)
|> put_session(:refresh_token, refresh_token)
|> put_session(:current_user, user_info)
```

### 3. Protected Routes

LiveView pages are protected with a plug:

```elixir
pipeline :require_auth do
  plug ThalamusPhoenixExampleWeb.Plugs.RequireAuth
end

scope "/" do
  pipe_through [:browser, :require_auth]
  live "/dashboard", DashboardLive
end
```

### 4. Token Refresh

Refresh tokens before expiration:

```elixir
def refresh_if_needed(conn) do
  # Check if token is about to expire
  # Use refresh_token to get new access_token
  client = ThalamusOAuth.refresh_token!(refresh_token)
  new_access_token = client.token.access_token

  put_session(conn, :access_token, new_access_token)
end
```

## Project Structure

```
lib/
├── thalamus_phoenix_example/
│   └── thalamus_oauth.ex           # OAuth2 client
└── thalamus_phoenix_example_web/
    ├── controllers/
    │   └── auth_controller.ex      # Auth endpoints
    ├── live/
    │   ├── dashboard_live.ex       # Protected dashboard
    │   └── profile_live.ex         # User profile
    └── plugs/
        └── require_auth.ex         # Auth middleware
```

## Security Notes

- ✅ Client secret stored in environment variables
- ✅ Encrypted session storage (Phoenix default)
- ✅ CSRF protection (Phoenix default)
- ✅ Token revocation on logout
- ✅ Protected routes with plugs
- ⚠️ Use HTTPS in production
- ⚠️ Enable secure session cookies in production
- ⚠️ Implement token refresh before expiration

## Production Considerations

1. **HTTPS Only**: Configure SSL/TLS certificates
2. **Session Storage**: Consider Redis for distributed sessions
3. **Token Storage**: Store tokens in encrypted database
4. **Error Handling**: Add comprehensive error handling
5. **Logging**: Add security event logging
6. **Rate Limiting**: Implement rate limiting on auth endpoints

## Troubleshooting

**"Invalid redirect_uri"**
- Check redirect URI matches exactly in Thalamus client config
- Verify port number (4001 by default for Phoenix)

**"OAuth2 error"**
- Check client_id and client_secret are correct
- Verify Thalamus server is running
- Check scopes are configured correctly

**"Session error"**
- Verify secret_key_base is set
- Check session configuration in endpoint

## Learn More

- [Phoenix Documentation](https://hexdocs.pm/phoenix/)
- [OAuth2 Library](https://hexdocs.pm/oauth2/)
- [Thalamus Documentation](../../docs/README.md)
- [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view/)
