defmodule Systemd.ServiceState do
  @moduledoc """
  Common state properties for a systemd service object.
  """

  @type t :: %__MODULE__{
          type: String.t() | nil,
          result: String.t() | nil,
          exec_main_pid: non_neg_integer() | nil,
          exec_main_status: non_neg_integer() | nil,
          restart: String.t() | nil
        }

  defstruct [:type, :result, :exec_main_pid, :exec_main_status, :restart]

  @doc false
  @spec from_properties(map()) :: t()
  def from_properties(properties) when is_map(properties) do
    %__MODULE__{
      type: Map.get(properties, "Type"),
      result: Map.get(properties, "Result"),
      exec_main_pid: Map.get(properties, "ExecMainPID"),
      exec_main_status: Map.get(properties, "ExecMainStatus"),
      restart: Map.get(properties, "Restart")
    }
  end
end
