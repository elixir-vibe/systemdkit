defmodule Systemd.UnitFile.Span do
  @moduledoc """
  Source location for a parsed unit file entry.
  """

  @type t :: %__MODULE__{
          line: pos_integer() | nil,
          column: pos_integer() | nil
        }

  defstruct [:line, :column]
end
