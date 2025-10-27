defmodule Thalamus.Repo do
  use Ecto.Repo,
    otp_app: :thalamus,
    adapter: Ecto.Adapters.Postgres
end
