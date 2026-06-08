defmodule Systemd.UnitFile.Section do
  @moduledoc """
  Section header in a systemd unit file, for example `[Service]`.
  """

  @type t :: %__MODULE__{name: String.t()}

  defstruct [:name]
end
