defmodule Systemd.UnitFile.Section do
  @moduledoc """
  Section header in a systemd unit file, for example `[Service]`.
  """

  alias Systemd.UnitFile.Span

  @type t :: %__MODULE__{name: String.t(), span: Span.t() | nil}

  defstruct [:name, :span]
end
