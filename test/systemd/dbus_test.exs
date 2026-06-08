defmodule Systemd.DBusTest do
  use ExUnit.Case, async: true

  alias Systemd.DBus
  alias Systemd.Error

  test "returns a validation error for incomplete calls" do
    assert {:error,
            %Error{
              source: :validation,
              reason: :invalid_call,
              message: message
            }} = DBus.call(self(), [])

    assert message =~ "Invalid D-Bus call"
  end
end
