defmodule Systemd.ManagerIntegrationTest do
  use ExUnit.Case, async: false

  alias Systemd.Manager
  alias Systemd.Unit

  @moduletag :integration

  test "lists units from a real systemd manager over the system bus" do
    assert File.exists?("/run/dbus/system_bus_socket")

    assert {:ok, units} = Manager.list_units()
    assert Enum.any?(units, &match?(%Unit{name: "dbus.service"}, &1))
    assert Enum.any?(units, &(&1.name == "init.scope" or &1.name == "-.slice"))
  end
end
