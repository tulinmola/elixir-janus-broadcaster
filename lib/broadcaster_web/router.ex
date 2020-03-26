defmodule BroadcasterWeb.Router do
  use BroadcasterWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", BroadcasterWeb do
    pipe_through :browser

    get "/", PageController, :index
    resources "/rooms", RoomController, only: [:index, :new, :show, :create, :delete]
  end

  # Other scopes may use custom stacks.
  # scope "/api", BroadcasterWeb do
  #   pipe_through :api
  # end
end
