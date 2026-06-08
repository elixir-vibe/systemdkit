defmodule Systemd.Manager.Options do
  @moduledoc """
  Normalized options for systemd manager operations.
  """

  @type t :: %__MODULE__{
          bus: Systemd.DBus.bus(),
          mode: String.t(),
          wait: boolean(),
          timeout: non_neg_integer(),
          interval: pos_integer(),
          runtime: boolean(),
          force: boolean()
        }

  defstruct bus: :system,
            mode: "replace",
            wait: true,
            timeout: 30_000,
            interval: 100,
            runtime: false,
            force: false

  @doc false
  @spec new(keyword() | t()) :: t()
  def new(%__MODULE__{} = opts), do: opts

  def new(opts) when is_list(opts) do
    struct!(__MODULE__,
      bus: Keyword.get(opts, :bus, :system),
      mode: Keyword.get(opts, :mode, "replace"),
      wait: Keyword.get(opts, :wait, true),
      timeout: Keyword.get(opts, :timeout, 30_000),
      interval: Keyword.get(opts, :interval, 100),
      runtime: Keyword.get(opts, :runtime, false),
      force: Keyword.get(opts, :force, false)
    )
  end

  @doc false
  @spec await_opts(t()) :: keyword()
  def await_opts(%__MODULE__{timeout: timeout, interval: interval}) do
    [timeout: timeout, interval: interval]
  end
end
