defmodule GameEightWeb.Router do
  use GameEightWeb, :router

  import GameEightWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {GameEightWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", GameEightWeb do
    pipe_through :browser

    get "/test", PageController, :test
    # get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", GameEightWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:game_eight, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: GameEightWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", GameEightWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{GameEightWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
      live "/rooms", GameLive.RoomIndex, :index
      live "/rooms/new", GameLive.RoomIndex, :new
      live "/rooms/:id", GameLive.RoomShow, :show
      live "/game/:room_id", GameLive, :play
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", GameEightWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{GameEightWeb.UserAuth, :mount_current_scope}] do
      live "/", GameLive.Hall, :index
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
