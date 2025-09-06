defmodule GameEight.Repo do
  use Ecto.Repo,
    otp_app: :game_eight,
    adapter: Ecto.Adapters.Postgres
end
