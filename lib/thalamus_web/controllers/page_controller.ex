defmodule ThalamusWeb.PageController do
  use ThalamusWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
