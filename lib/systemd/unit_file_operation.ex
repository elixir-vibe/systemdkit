defmodule Systemd.UnitFileOperation do
  @moduledoc """
  Result returned by systemd unit-file operations.
  """

  alias Systemd.UnitFileChange

  @type t :: %__MODULE__{
          changes: [UnitFileChange.t()],
          carries_install_info: boolean() | nil
        }

  defstruct changes: [], carries_install_info: nil

  @doc false
  @spec new([term()], keyword()) :: t()
  def new(changes, opts \\ []) when is_list(changes) do
    %__MODULE__{
      changes: Enum.map(changes, &UnitFileChange.from_dbus/1),
      carries_install_info: Keyword.get(opts, :carries_install_info)
    }
  end
end
