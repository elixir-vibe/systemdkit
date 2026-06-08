defmodule Systemd.ErrorTest do
  use ExUnit.Case, async: true

  alias Systemd.Error

  test "builds D-Bus errors with normalized reasons" do
    assert %Error{
             source: :dbus,
             reason: :access_denied,
             dbus_name: "org.freedesktop.DBus.Error.AccessDenied",
             message: "permission denied",
             body: ["permission denied"]
           } = Error.dbus_error("org.freedesktop.DBus.Error.AccessDenied", ["permission denied"])
  end

  test "classifies polkit and permission errors" do
    error =
      Error.dbus_error("org.freedesktop.DBus.Error.InteractiveAuthorizationRequired", [
        "Interactive authentication required."
      ])

    assert %Error{reason: :interactive_authorization_required, category: :permission} = error
    assert Error.permission?(error)
  end

  test "builds connection errors" do
    assert %Error{
             source: :connection,
             reason: :enoent,
             message: "D-Bus connection failed: :enoent",
             details: :enoent
           } = Error.connection_error(:enoent)
  end
end
