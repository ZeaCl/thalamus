defmodule ThalamusWeb.DocsController do
  @moduledoc """
  Controller for serving documentation pages.

  Provides comprehensive documentation for developers and organizations
  integrating with Thalamus OAuth2 server.
  """
  use ThalamusWeb, :controller

  @doc """
  GET /docs

  Main documentation landing page with index of all available docs.
  """
  def index(conn, _params) do
    render(conn, :index, page_title: "Documentation")
  end

  @doc """
  GET /docs/getting-started

  Quick start guide for developers.
  """
  def getting_started(conn, _params) do
    render(conn, :getting_started, page_title: "Getting Started")
  end

  @doc """
  GET /docs/integration

  OAuth2 integration guide with code examples.
  """
  def integration(conn, _params) do
    render(conn, :integration, page_title: "Integration Guide")
  end

  @doc """
  GET /docs/api-reference

  Complete API reference with all endpoints.
  """
  def api_reference(conn, _params) do
    render(conn, :api_reference, page_title: "API Reference")
  end

  @doc """
  GET /docs/deployment

  Production deployment guide.
  """
  def deployment(conn, _params) do
    render(conn, :deployment, page_title: "Deployment Guide")
  end

  @doc """
  GET /docs/agent-tokens

  Agent tokens for agentic economy.
  """
  def agent_tokens(conn, _params) do
    render(conn, :agent_tokens, page_title: "Agent Tokens")
  end
end
