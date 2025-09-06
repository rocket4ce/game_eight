defmodule GameEightWeb.PageController do
  use GameEightWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
  
  def test(conn, _params) do
    html(conn, "<h1>Test página funcionando</h1><p>Controller simple</p>")
  end
end
