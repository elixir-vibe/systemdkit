defmodule Systemd.ManagerIntegrationTest do
  use ExUnit.Case, async: false

  alias Systemd.{Job, Manager, Unit, UnitObject}

  @moduletag :integration

  test "lists units from a real systemd manager over the system bus" do
    assert File.exists?("/run/dbus/system_bus_socket")

    assert {:ok, units} = Manager.list_units()
    assert Enum.any?(units, &match?(%Unit{name: "dbus.service"}, &1))
    assert Enum.any?(units, &(&1.name == "init.scope" or &1.name == "-.slice"))
  end

  test "gets a unit object and reads common properties" do
    assert {:ok, conn} = Manager.connect()
    assert {:ok, %UnitObject{} = unit} = Manager.get_unit(conn, "dbus.service")
    assert {:ok, state} = UnitObject.state(conn, unit)

    assert state.id == "dbus.service"
    assert state.load_state == "loaded"
    assert state.active_state in ["active", "activating", "inactive"]
  end

  test "daemon reload is available or reports policy denial" do
    assert {:ok, conn} = Manager.connect()

    case Manager.reload(conn) do
      :ok ->
        :ok

      {:error,
       %Systemd.Error{dbus_name: "org.freedesktop.DBus.Error.InteractiveAuthorizationRequired"}} ->
        :ok
    end
  end

  test "starts and awaits a harmless transient unit" do
    assert {:ok, conn} = Manager.connect()

    name = "systemd-elixir-test-#{System.unique_integer([:positive])}.service"

    properties = [
      ["Description", {"s", "systemd Elixir integration test"}],
      ["Type", {"s", "oneshot"}],
      ["ExecStart", {"a(sasb)", [["/bin/true", ["/bin/true"], false]]}]
    ]

    case Manager.start_transient_unit(conn, name, properties) do
      {:ok, %Job{} = job} ->
        assert :ok = Job.await(conn, job, timeout: 5_000)

      {:error,
       %Systemd.Error{dbus_name: "org.freedesktop.DBus.Error.InteractiveAuthorizationRequired"}} ->
        :ok
    end
  end
end
