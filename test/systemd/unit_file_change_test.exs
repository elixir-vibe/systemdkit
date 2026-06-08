defmodule Systemd.UnitFileChangeTest do
  use ExUnit.Case, async: true

  alias Systemd.UnitFileChange

  test "builds changes from D-Bus rows" do
    assert %UnitFileChange{
             action: :symlink,
             path: "/etc/systemd/system/app.service",
             target: "/dev/null"
           } =
             UnitFileChange.from_dbus(["symlink", "/etc/systemd/system/app.service", "/dev/null"])
  end
end
