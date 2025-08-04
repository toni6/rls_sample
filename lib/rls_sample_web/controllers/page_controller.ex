defmodule RlsSampleWeb.PageController do
  use RlsSampleWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
