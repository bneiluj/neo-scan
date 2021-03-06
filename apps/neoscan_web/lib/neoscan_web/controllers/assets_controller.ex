defmodule NeoscanWeb.AssetsController do
  use NeoscanWeb, :controller

  alias NeoscanMonitor.Api

  def index(conn, _params) do
    assets = Api.get_assets
    render(conn, "assets.html", assets: assets)
  end

  def round_or_not(value) do
    if round_or_not?(value) do
      Kernel.round(value)
    else
      value
    end
    |> check()
  end

  def check(value) do
    if value < 0 do
      "Unlimited"
    else
      value
    end
  end

  defp round_or_not?(value), do: Kernel.round(value) == value
end
