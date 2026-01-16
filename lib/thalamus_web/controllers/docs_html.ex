defmodule ThalamusWeb.DocsHTML do
  @moduledoc """
  This module contains pages rendered by DocsController.
  """
  use ThalamusWeb, :html

  embed_templates "docs_html/*"
end
