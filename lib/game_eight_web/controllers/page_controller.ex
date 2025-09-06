defmodule GameEightWeb.PageController do
  use GameEightWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
