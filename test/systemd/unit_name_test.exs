defmodule Systemd.UnitNameTest do
  use ExUnit.Case, async: true

  doctest Systemd.UnitName

  alias Systemd.UnitName

  test "formats typed unit names" do
    assert UnitName.new("dbus", :service) == "dbus.service"
    assert UnitName.new("dbus.service", :service) == "dbus.service"
    assert UnitName.new("timers", :target) == "timers.target"
  end

  test "formats template unit names" do
    assert UnitName.template("my_app", :service) == "my_app@.service"
    assert UnitName.template("my_app.service", :service) == "my_app@.service"
    assert UnitName.template("my_app@.service", :service) == "my_app@.service"
    assert UnitName.template("socket_app", :socket) == "socket_app@.socket"
  end

  test "formats instance unit names" do
    assert UnitName.instance("my_app", 4000, :service) == "my_app@4000.service"
    assert UnitName.instance("my_app.service", "blue", :service) == "my_app@blue.service"
    assert UnitName.instance("my_app@.service", "blue", :service) == "my_app@blue.service"
    assert UnitName.instance("timer_app", "daily", :timer) == "timer_app@daily.timer"
  end

  test "ensures unit type suffix" do
    assert UnitName.ensure_type("my_app@4000", :service) == "my_app@4000.service"
    assert UnitName.ensure_type("my_app@4000.service", :service) == "my_app@4000.service"
    assert UnitName.ensure_type("custom", "service") == "custom.service"
    assert UnitName.ensure_type("custom", ".service") == "custom.service"
  end

  test "drops known unit type suffixes" do
    assert UnitName.drop_type("my_app@4000.service") == "my_app@4000"
    assert UnitName.drop_type("timers.target") == "timers"
    assert UnitName.drop_type("plain") == "plain"
  end
end
