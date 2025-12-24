defmodule ThalamusWeb.OAuth2.AuthorizationHTML do
  @moduledoc """
  Renders OAuth2 authorization pages (consent screen).
  """
  use ThalamusWeb, :html

  embed_templates "authorization_html/*"

  @doc """
  Returns a human-readable description for an OAuth2 scope.
  """
  def scope_description("openid"), do: "Access your basic profile information"
  def scope_description("profile"), do: "View your profile details (name, picture)"
  def scope_description("email"), do: "Access your email address"
  def scope_description("org:read"), do: "Read your organization information"
  def scope_description("org:write"), do: "Manage your organization"
  def scope_description(scope), do: "Access #{scope}"
end
