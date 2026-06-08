defmodule SystemdTest do
  use ExUnit.Case
  doctest Systemd

  test "greets the world" do
    assert Systemd.hello() == :world
  end
end
