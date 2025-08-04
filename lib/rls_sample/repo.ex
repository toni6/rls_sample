defmodule RlsSample.Repo do
  use Ecto.Repo,
    otp_app: :rls_sample,
    adapter: Ecto.Adapters.Postgres
end
