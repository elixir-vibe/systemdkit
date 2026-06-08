defmodule Systemd.SocketStateTest do
  use ExUnit.Case, async: true

  alias Systemd.SocketState

  test "builds socket state from properties" do
    assert %SocketState{result: "success", accept: false, n_connections: 0} =
             SocketState.from_properties(%{
               "Result" => "success",
               "Accept" => false,
               "NConnections" => 0
             })
  end
end
