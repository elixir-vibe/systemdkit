defmodule Systemd.UnitFile.ValidationError do
  @moduledoc """
  Validation error for a parsed systemd unit file.
  """

  alias Systemd.UnitFile.Span

  @type t :: %__MODULE__{
          reason: atom(),
          message: String.t(),
          section: String.t() | nil,
          directive: String.t() | nil,
          span: Span.t() | nil
        }

  defstruct [:reason, :message, :section, :directive, :span]
end
