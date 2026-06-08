defmodule Systemd.ServiceStateTest do
  use ExUnit.Case, async: true

  alias Systemd.ServiceState

  test "builds service state from properties" do
    assert %ServiceState{type: "oneshot", result: "success", exec_main_pid: 42} =
             ServiceState.from_properties(%{
               "Type" => "oneshot",
               "Result" => "success",
               "ExecMainPID" => 42
             })
  end
end
