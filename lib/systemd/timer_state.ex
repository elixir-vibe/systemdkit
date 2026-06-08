defmodule Systemd.TimerState do
  @moduledoc """
  Common state properties for a systemd timer object.
  """

  @type t :: %__MODULE__{
          result: String.t() | nil,
          unit: String.t() | nil,
          next_elapse_usec_realtime: non_neg_integer() | nil,
          last_trigger_usec: non_neg_integer() | nil,
          timers_calendar: [term()] | nil
        }

  defstruct [:result, :unit, :next_elapse_usec_realtime, :last_trigger_usec, :timers_calendar]

  @doc false
  @spec from_properties(map()) :: t()
  def from_properties(properties) when is_map(properties) do
    %__MODULE__{
      result: Map.get(properties, "Result"),
      unit: Map.get(properties, "Unit"),
      next_elapse_usec_realtime: Map.get(properties, "NextElapseUSecRealtime"),
      last_trigger_usec: Map.get(properties, "LastTriggerUSec"),
      timers_calendar: Map.get(properties, "TimersCalendar")
    }
  end
end
