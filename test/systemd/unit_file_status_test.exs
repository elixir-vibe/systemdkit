defmodule Systemd.UnitFileStatusTest do
  use ExUnit.Case, async: true

  alias Systemd.UnitFileStatus

  test "builds unit-file status from D-Bus rows" do
    assert %UnitFileStatus{path: "dbus.service", state: "enabled"} =
             UnitFileStatus.from_dbus(["dbus.service", "enabled"])

    assert %UnitFileStatus{path: "ssh.service", state: "disabled"} =
             UnitFileStatus.from_dbus({"ssh.service", "disabled"})
  end
end
