defmodule Systemd.TimerStateTest do
  use ExUnit.Case, async: true

  alias Systemd.TimerState

  test "builds timer state from properties" do
    assert %TimerState{result: "success", unit: "example.service", next_elapse_usec_realtime: 10} =
             TimerState.from_properties(%{
               "Result" => "success",
               "Unit" => "example.service",
               "NextElapseUSecRealtime" => 10
             })
  end
end
