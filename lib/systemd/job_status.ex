defmodule Systemd.JobStatus do
  @moduledoc """
  Runtime job information returned by systemd's `ListJobs` D-Bus method.
  """

  @enforce_keys [:id, :unit, :type, :state, :job_path, :unit_path]
  @type t :: %__MODULE__{
          id: non_neg_integer(),
          unit: String.t(),
          type: String.t(),
          state: String.t(),
          job_path: String.t(),
          unit_path: String.t()
        }

  defstruct [:id, :unit, :type, :state, :job_path, :unit_path]

  @doc false
  @spec from_dbus(tuple() | list()) :: t()
  def from_dbus({id, unit, type, state, job_path, unit_path}) do
    from_dbus([id, unit, type, state, job_path, unit_path])
  end

  def from_dbus([id, unit, type, state, job_path, unit_path]) do
    %__MODULE__{
      id: id,
      unit: unit,
      type: type,
      state: state,
      job_path: job_path,
      unit_path: unit_path
    }
  end
end
