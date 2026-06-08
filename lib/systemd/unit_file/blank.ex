defmodule Systemd.UnitFile.Blank do
  @moduledoc """
  Blank line in a systemd unit file.
  """

  alias Systemd.UnitFile.Span

  @type t :: %__MODULE__{span: Span.t() | nil}

  defstruct [:span]
end
