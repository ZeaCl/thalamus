"""
Thalamus OAuth2 client for Python.
This is a lightweight wrapper around the Thalamus OAuth2 API.
"""

import httpx
from typing import Optional, Dict, Any
from datetime import datetime, timedelta


class ThalamusClient:
    def __init__(
        self,
        base_url: str,
        client_id: str,
        client_secret: Optional[str] = None,
        timeout: int = 30
    ):
        self.base_url = base_url.rstrip('/')
        self.client_id = client_id
        self.client_secret = client_secret
        self.timeout = timeout
        self._cached_token: Optional[str] = None
        self._token_expiry: Optional[datetime] = None

    async def client_credentials(self, scopes: list[str]) -> Dict[str, Any]:
        """
        Get an access token using OAuth2 Client Credentials flow.

        Args:
            scopes: List of scopes to request

        Returns:
            Token response dict with access_token, token_type, expires_in, scope
        """
        if not self.client_secret:
            raise ValueError("Client secret is required for client credentials flow")

        async with httpx.AsyncClient(timeout=self.timeout) as client:
            response = await client.post(
                f"{self.base_url}/oauth/token",
                data={
                    "grant_type": "client_credentials",
                    "client_id": self.client_id,
                    "client_secret": self.client_secret,
                    "scope": " ".join(scopes)
                },
                headers={"Content-Type": "application/x-www-form-urlencoded"}
            )
            response.raise_for_status()
            return response.json()

    async def introspect_token(self, token: str) -> Dict[str, Any]:
        """
        Introspect a token to validate and get metadata.

        Args:
            token: Access token to introspect

        Returns:
            Introspection response with active status and token metadata
        """
        if not self.client_secret:
            raise ValueError("Client secret is required for token introspection")

        async with httpx.AsyncClient(timeout=self.timeout) as client:
            response = await client.post(
                f"{self.base_url}/oauth/introspect",
                data={
                    "token": token,
                    "client_id": self.client_id,
                    "client_secret": self.client_secret
                },
                headers={"Content-Type": "application/x-www-form-urlencoded"}
            )
            response.raise_for_status()
            return response.json()

    async def revoke_token(self, token: str) -> None:
        """
        Revoke an access token.

        Args:
            token: Access token to revoke
        """
        if not self.client_secret:
            raise ValueError("Client secret is required for token revocation")

        async with httpx.AsyncClient(timeout=self.timeout) as client:
            response = await client.post(
                f"{self.base_url}/oauth/revoke",
                data={
                    "token": token,
                    "client_id": self.client_id,
                    "client_secret": self.client_secret
                },
                headers={"Content-Type": "application/x-www-form-urlencoded"}
            )
            response.raise_for_status()

    async def get_cached_token(self, scopes: list[str]) -> str:
        """
        Get a cached token or fetch a new one if expired.

        Args:
            scopes: List of scopes to request

        Returns:
            Valid access token
        """
        # Check if cached token is still valid
        if (self._cached_token and self._token_expiry and
            datetime.now() < self._token_expiry):
            return self._cached_token

        # Fetch new token
        token_response = await self.client_credentials(scopes)
        self._cached_token = token_response["access_token"]

        # Cache token (subtract 60s for safety margin)
        expires_in = token_response.get("expires_in", 3600)
        self._token_expiry = datetime.now() + timedelta(seconds=expires_in - 60)

        return self._cached_token
