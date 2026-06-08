defmodule Systemd.UnitStateTest do
  use ExUnit.Case, async: true

  alias Systemd.UnitState

  test "builds typed unit state from properties" do
    assert %UnitState{id: "dbus.service", active_state: "active", main_pid: 123} =
             UnitState.from_properties(%{
               "Id" => "dbus.service",
               "ActiveState" => "active",
               "MainPID" => 123
             })
  end
end
