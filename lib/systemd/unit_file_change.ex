defmodule Systemd.UnitFileChange do
  @moduledoc """
  Change reported by systemd unit-file operations.
  """

  @type action :: :symlink | :unlink | :masked | :unmasked | :unknown

  @type t :: %__MODULE__{
          action: action(),
          path: String.t(),
          target: String.t()
        }

  @enforce_keys [:action, :path, :target]
  defstruct [:action, :path, :target]

  @doc false
  @spec new(action(), String.t(), String.t()) :: t()
  def new(action, path, target) when is_atom(action) and is_binary(path) and is_binary(target) do
    %__MODULE__{action: action, path: path, target: target}
  end

  @doc false
  @spec from_dbus(tuple() | list()) :: t()
  def from_dbus({action, path, target}), do: from_dbus([action, path, target])

  def from_dbus([action, path, target]) do
    new(normalize_action(action), path, target)
  end

  defp normalize_action("symlink"), do: :symlink
  defp normalize_action("unlink"), do: :unlink
  defp normalize_action("masked"), do: :masked
  defp normalize_action("unmasked"), do: :unmasked
  defp normalize_action(_action), do: :unknown
end
