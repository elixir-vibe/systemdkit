defmodule Systemd.UnitFile.Raw do
  @moduledoc """
  Raw line preserved by the parser when it is not a complete section,
  directive, comment, or blank line.

  Raw lines are primarily used for directive continuations.
  """

  alias Systemd.UnitFile.Span

  @type t :: %__MODULE__{content: String.t(), span: Span.t() | nil}

  defstruct content: "", span: nil
end
