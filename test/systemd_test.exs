defmodule SystemdTest do
  use ExUnit.Case, async: true
  doctest Systemd

  test "close tolerates live processes" do
    pid = spawn(fn -> Process.sleep(:infinity) end)
    assert :ok = Systemd.close(pid)
    Process.sleep(10)
    refute Process.alive?(pid)
  end
end
