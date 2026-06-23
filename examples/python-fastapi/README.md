# Python FastAPI Example with Thalamus

FastAPI backend demonstrating OAuth2 Client Credentials flow and Bearer token validation using Thalamus OAuth2 server.

## Features

- ✅ FastAPI modern Python web framework
- ✅ OAuth2 Client Credentials flow (M2M)
- ✅ Bearer token authentication
- ✅ Token introspection and validation
- ✅ Token caching for performance
- ✅ OpenAPI documentation (Swagger UI)
- ✅ Type hints and Pydantic models

## Prerequisites

1. **Running Thalamus server** at `http://localhost:4000`
2. **Python 3.11+** installed
3. **OAuth2 Client created** in Thalamus dashboard

## Setup

### 1. Create Virtual Environment

```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

### 2. Install Dependencies

```bash
pip install -r requirements.txt
```

### 3. Configure Environment

Copy `.env.example` to `.env`:

```bash
cp .env.example .env
```

Edit `.env`:

```env
THALAMUS_BASE_URL=http://localhost:4000
THALAMUS_CLIENT_ID=your_client_id_here
THALAMUS_CLIENT_SECRET=your_client_secret_here
PORT=8000
```

### 4. Create OAuth2 Client in Thalamus

1. Go to http://localhost:4000/dashboard/clients
2. Click "New Client"
3. Fill in:
   - **Name**: "Python FastAPI Service"
   - **Client Type**: Confidential (with client secret)
   - **Grant Types**: Enable "Client Credentials"
   - **Scopes**: `api:read`, `api:write`
4. Save and copy the `client_id` and `client_secret`
5. Paste them in your `.env` file

## Running

```bash
# Development mode (with auto-reload)
python main.py

# Or using uvicorn directly
uvicorn main:app --reload --port 8000
```

Server runs at http://localhost:8000

## API Documentation

FastAPI provides automatic interactive API documentation:

- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

## API Endpoints

### Public Endpoints

**GET /**
```bash
curl http://localhost:8000/
```

**GET /api/public/health**
```bash
curl http://localhost:8000/api/public/health
```

### Protected Endpoints (Require Bearer Token)

**GET /api/protected/data**

Requires a valid Bearer token in the Authorization header:

```bash
# First, get a token from Thalamus
TOKEN=$(curl -X POST http://localhost:4000/oauth/token \
  -d "grant_type=client_credentials" \
  -d "client_id=your_client_id" \
  -d "client_secret=your_client_secret" \
  -d "scope=api:read api:write" \
  | jq -r '.access_token')

# Use the token
curl http://localhost:8000/api/protected/data \
  -H "Authorization: Bearer $TOKEN"
```

Response:
```json
{
  "message": "This is protected data from FastAPI",
  "authenticated": true,
  "scopes": ["api:read", "api:write"],
  "client_id": "your_client_id"
}
```

**POST /api/introspect**
```bash
curl -X POST http://localhost:8000/api/introspect \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"token": "token_to_introspect"}'
```

### M2M Endpoints (Service Authentication)

**GET /api/service/token-info**

Gets the service's own token using client credentials:

```bash
curl http://localhost:8000/api/service/token-info
```

**GET /api/service/test-m2m**

Tests M2M authentication flow:

```bash
curl http://localhost:8000/api/service/test-m2m
```

## How It Works

### 1. Client Credentials Flow

The service authenticates using client credentials to get an access token:

```python
token_response = await thalamus.client_credentials(["api:read", "api:write"])
access_token = token_response["access_token"]
```

### 2. Token Caching

Tokens are cached to avoid requesting new ones on every request:

```python
async def get_cached_token(self, scopes: list[str]) -> str:
    # Check if cached token is still valid
    if (self._cached_token and self._token_expiry and
        datetime.now() < self._token_expiry):
        return self._cached_token

    # Fetch new token
    token_response = await self.client_credentials(scopes)
    self._cached_token = token_response["access_token"]

    # Cache with 60s safety margin
    expires_in = token_response.get("expires_in", 3600)
    self._token_expiry = datetime.now() + timedelta(seconds=expires_in - 60)

    return self._cached_token
```

### 3. Bearer Token Validation

Protected endpoints validate Bearer tokens using dependency injection:

```python
async def validate_token(
    credentials: Annotated[HTTPAuthorizationCredentials, Depends(security)]
) -> dict:
    token = credentials.credentials
    introspection = await thalamus.introspect_token(token)

    if not introspection.get("active"):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token is not active"
        )

    return introspection

@app.get("/api/protected/data")
async def protected_data(
    token_data: Annotated[dict, Depends(validate_token)]
):
    # token_data contains validated token information
    return {"message": "Protected data", "scopes": token_data["scope"]}
```

### 4. Type Safety with Pydantic

All request/response models use Pydantic for validation and serialization:

```python
class ProtectedDataResponse(BaseModel):
    message: str
    authenticated: bool
    scopes: list[str] | None
    client_id: str | None
```

## Project Structure

```
python-fastapi/
├── main.py                 # FastAPI application
├── thalamus_client.py      # Thalamus OAuth2 client wrapper
├── requirements.txt        # Python dependencies
├── .env.example            # Environment template
└── README.md               # This file
```

## Security Notes

- ✅ Client secret stored in environment variables
- ✅ Bearer token authentication on protected endpoints
- ✅ Token introspection validates tokens
- ✅ Token caching prevents excessive requests
- ✅ Type validation with Pydantic
- ⚠️ Use Redis for token caching in production
- ⚠️ Always use HTTPS in production
- ⚠️ Implement rate limiting

## Production Considerations

1. **Token Storage**: Use Redis instead of in-memory cache
   ```python
   from redis.asyncio import Redis
   redis = Redis(host='localhost', port=6379)
   ```

2. **HTTPS Only**: Configure HTTPS with proper certificates

3. **Environment Variables**: Use secret management (AWS Secrets Manager, etc.)

4. **Logging**: Add structured logging
   ```python
   import logging
   logging.basicConfig(level=logging.INFO)
   ```

5. **CORS**: Configure CORS for frontend integration
   ```python
   from fastapi.middleware.cors import CORSMiddleware
   app.add_middleware(CORSMiddleware, allow_origins=["*"])
   ```

6. **Rate Limiting**: Use SlowAPI or similar
   ```python
   from slowapi import Limiter, _rate_limit_exceeded_handler
   ```

## Testing

```bash
# Install testing dependencies
pip install pytest httpx pytest-asyncio

# Run tests
pytest
```

Example test:

```python
import pytest
from httpx import AsyncClient
from main import app

@pytest.mark.asyncio
async def test_health():
    async with AsyncClient(app=app, base_url="http://test") as client:
        response = await client.get("/api/public/health")
        assert response.status_code == 200
        assert response.json()["status"] == "ok"
```

## Troubleshooting

**"Client secret is required"**
- Check that `THALAMUS_CLIENT_SECRET` is set in `.env`
- Verify the secret is correct

**"Token is not active"**
- Token may have expired
- Check token scopes match endpoint requirements
- Verify token hasn't been revoked

**"Connection refused"**
- Ensure Thalamus server is running
- Check `THALAMUS_BASE_URL` in `.env`

## Learn More

- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Thalamus Documentation](../../docs/README.md)
- [OAuth2 Client Credentials](https://oauth.net/2/grant-types/client-credentials/)
- [Pydantic Documentation](https://docs.pydantic.dev/)
