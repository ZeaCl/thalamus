"""
FastAPI backend example using Thalamus OAuth2.
Demonstrates client credentials flow and token validation.
"""

import os
from typing import Annotated
from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
from dotenv import load_dotenv
from thalamus_client import ThalamusClient

# Load environment variables
load_dotenv()

# Initialize FastAPI app
app = FastAPI(
    title="Thalamus FastAPI Example",
    description="Backend API using Thalamus OAuth2 Client Credentials",
    version="1.0.0"
)

# Initialize Thalamus client
thalamus = ThalamusClient(
    base_url=os.getenv("THALAMUS_BASE_URL", "http://localhost:4000"),
    client_id=os.getenv("THALAMUS_CLIENT_ID"),
    client_secret=os.getenv("THALAMUS_CLIENT_SECRET")
)

# Security scheme
security = HTTPBearer()


# Models
class HealthResponse(BaseModel):
    status: str
    message: str


class IntrospectRequest(BaseModel):
    token: str


class TokenInfoResponse(BaseModel):
    active: bool
    scopes: list[str] | None
    client_id: str | None
    expires_at: str | None


class ProtectedDataResponse(BaseModel):
    message: str
    authenticated: bool
    scopes: list[str] | None
    client_id: str | None


# Dependency for token validation
async def validate_token(
    credentials: Annotated[HTTPAuthorizationCredentials, Depends(security)]
) -> dict:
    """
    Validate Bearer token using Thalamus introspection.
    """
    try:
        token = credentials.credentials
        introspection = await thalamus.introspect_token(token)

        if not introspection.get("active"):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token is not active"
            )

        return introspection
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Token validation failed: {str(e)}"
        )


# Public endpoints
@app.get("/", response_model=HealthResponse)
async def root():
    """Public health check endpoint."""
    return HealthResponse(
        status="ok",
        message="Thalamus FastAPI Example is running"
    )


@app.get("/api/public/health", response_model=HealthResponse)
async def health():
    """Public health check endpoint."""
    return HealthResponse(
        status="ok",
        message="Server is healthy"
    )


# Protected endpoints (require Bearer token)
@app.get("/api/protected/data", response_model=ProtectedDataResponse)
async def protected_data(
    token_data: Annotated[dict, Depends(validate_token)]
):
    """
    Protected endpoint that requires a valid Bearer token.
    """
    return ProtectedDataResponse(
        message="This is protected data from FastAPI",
        authenticated=True,
        scopes=token_data.get("scope", "").split() if token_data.get("scope") else None,
        client_id=token_data.get("client_id")
    )


@app.post("/api/introspect")
async def introspect(
    request: IntrospectRequest,
    token_data: Annotated[dict, Depends(validate_token)]
):
    """
    Introspect a token (requires authentication).
    """
    try:
        result = await thalamus.introspect_token(request.token)
        return result
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Introspection failed: {str(e)}"
        )


# M2M endpoints (use service's own token)
@app.get("/api/service/token-info", response_model=TokenInfoResponse)
async def service_token_info():
    """
    Get the service's own token info using client credentials.
    """
    try:
        # Get service token
        token = await thalamus.get_cached_token(["api:read", "api:write"])

        # Introspect it
        info = await thalamus.introspect_token(token)

        return TokenInfoResponse(
            active=info.get("active", False),
            scopes=info.get("scope", "").split() if info.get("scope") else None,
            client_id=info.get("client_id"),
            expires_at=None  # Could calculate from exp if needed
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get token info: {str(e)}"
        )


@app.get("/api/service/test-m2m")
async def test_m2m():
    """
    Test endpoint that uses client credentials to authenticate.
    """
    try:
        # Get service token using client credentials
        token = await thalamus.get_cached_token(["api:read", "api:write"])

        # Validate it
        validation = await thalamus.introspect_token(token)

        return {
            "message": "M2M authentication successful",
            "token_active": validation.get("active"),
            "client_id": validation.get("client_id"),
            "scopes": validation.get("scope", "").split() if validation.get("scope") else None
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"M2M authentication failed: {str(e)}"
        )


if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=port,
        reload=True
    )
