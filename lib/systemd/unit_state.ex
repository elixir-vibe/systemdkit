defmodule Systemd.UnitState do
  @moduledoc """
  Common state properties for a systemd unit object.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          load_state: String.t() | nil,
          active_state: String.t() | nil,
          sub_state: String.t() | nil,
          main_pid: non_neg_integer() | nil,
          fragment_path: String.t() | nil
        }

  defstruct [:id, :load_state, :active_state, :sub_state, :main_pid, :fragment_path]

  @doc false
  @spec from_properties(map()) :: t()
  def from_properties(properties) when is_map(properties) do
    %__MODULE__{
      id: Map.get(properties, "Id"),
      load_state: Map.get(properties, "LoadState"),
      active_state: Map.get(properties, "ActiveState"),
      sub_state: Map.get(properties, "SubState"),
      main_pid: Map.get(properties, "MainPID"),
      fragment_path: Map.get(properties, "FragmentPath")
    }
  end
end
