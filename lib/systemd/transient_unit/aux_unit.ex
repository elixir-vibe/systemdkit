defmodule Systemd.TransientUnit.AuxUnit do
  @moduledoc """
  Auxiliary transient unit passed to `StartTransientUnit`.
  """

  alias Systemd.TransientUnit.Property

  @type t :: %__MODULE__{
          name: String.t(),
          properties: [Property.t()]
        }

  @enforce_keys [:name]
  defstruct [:name, properties: []]

  @doc """
  Builds an auxiliary transient unit.
  """
  @spec new(String.t(), [Property.t()]) :: t()
  def new(name, properties \\ []) when is_binary(name) and is_list(properties) do
    %__MODULE__{name: name, properties: properties}
  end

  @doc false
  @spec to_dbus(t()) :: [String.t() | list()]
  def to_dbus(%__MODULE__{name: name, properties: properties}) do
    [name, Enum.map(properties, &Property.to_dbus/1)]
  end
end
