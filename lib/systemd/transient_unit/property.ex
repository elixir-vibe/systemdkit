defmodule Systemd.TransientUnit.Property do
  @moduledoc """
  A typed systemd transient-unit property.

  Systemd's `StartTransientUnit` expects properties as D-Bus `(sv)` structs.
  This struct keeps that contract explicit instead of passing anonymous tuples or
  lists through the public API.
  """

  @type t :: %__MODULE__{
          name: String.t(),
          signature: String.t(),
          value: term()
        }

  @enforce_keys [:name, :signature, :value]
  defstruct [:name, :signature, :value]

  @doc """
  Builds a transient-unit property.
  """
  @spec new(String.t(), String.t(), term()) :: t()
  def new(name, signature, value) when is_binary(name) and is_binary(signature) do
    %__MODULE__{name: name, signature: signature, value: value}
  end

  @doc false
  @spec to_dbus(t()) :: [String.t() | {String.t(), term()}]
  def to_dbus(%__MODULE__{name: name, signature: signature, value: value}) do
    [name, {signature, normalize_structs(value)}]
  end

  defp normalize_structs(values) when is_list(values), do: Enum.map(values, &normalize_structs/1)

  defp normalize_structs(values) when is_tuple(values),
    do: values |> Tuple.to_list() |> normalize_structs()

  defp normalize_structs(value), do: value
end
