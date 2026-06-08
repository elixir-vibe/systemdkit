defmodule Systemd.TransientUnitTest do
  use ExUnit.Case, async: true

  alias Systemd.TransientUnit
  alias Systemd.TransientUnit.{AuxUnit, Property}

  test "builds typed properties with explicit D-Bus contracts" do
    assert %Property{name: "Description", signature: "s", value: "example"} =
             TransientUnit.string("Description", "example")

    assert Property.to_dbus(TransientUnit.exec_start("/bin/true", ["/bin/true"])) == [
             "ExecStart",
             {"a(sasb)", [["/bin/true", ["/bin/true"], false]]}
           ]
  end

  test "builds typed auxiliary units" do
    aux = AuxUnit.new("helper.service", [TransientUnit.string("Description", "helper")])

    assert AuxUnit.to_dbus(aux) == ["helper.service", [["Description", {"s", "helper"}]]]
  end
end
