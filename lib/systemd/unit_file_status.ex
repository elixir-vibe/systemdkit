defmodule Systemd.UnitFileStatus do
  @moduledoc """
  Unit-file status returned by systemd's `ListUnitFiles` D-Bus method.
  """

  @enforce_keys [:path, :state]
  @type t :: %__MODULE__{
          path: String.t(),
          state: String.t()
        }

  defstruct [:path, :state]

  @doc false
  @spec new(String.t(), String.t()) :: t()
  def new(path, state) when is_binary(path) and is_binary(state) do
    %__MODULE__{path: path, state: state}
  end

  @doc false
  @spec from_dbus(tuple() | list()) :: t()
  def from_dbus({path, state}), do: from_dbus([path, state])
  def from_dbus([path, state]), do: new(path, state)
end
