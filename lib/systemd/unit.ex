defmodule Systemd.Unit do
  @moduledoc """
  Runtime information for a systemd unit returned by `ListUnits`.
  """

  @type t :: %__MODULE__{
          name: String.t(),
          description: String.t(),
          load_state: String.t(),
          active_state: String.t(),
          sub_state: String.t(),
          followed: String.t(),
          object_path: String.t(),
          job_id: non_neg_integer(),
          job_type: String.t(),
          job_path: String.t()
        }

  @enforce_keys [:name]
  defstruct [
    :name,
    :description,
    :load_state,
    :active_state,
    :sub_state,
    :followed,
    :object_path,
    :job_id,
    :job_type,
    :job_path
  ]

  @doc false
  @spec new(keyword()) :: t()
  def new(attrs) when is_list(attrs), do: struct!(__MODULE__, attrs)

  @doc false
  @spec from_list_units_row(tuple() | list()) :: t()
  def from_list_units_row(
        {name, description, load_state, active_state, sub_state, followed, object_path, job_id,
         job_type, job_path}
      ) do
    %__MODULE__{
      name: name,
      description: description,
      load_state: load_state,
      active_state: active_state,
      sub_state: sub_state,
      followed: followed,
      object_path: object_path,
      job_id: job_id,
      job_type: job_type,
      job_path: job_path
    }
  end

  def from_list_units_row([
        name,
        description,
        load_state,
        active_state,
        sub_state,
        followed,
        object_path,
        job_id,
        job_type,
        job_path
      ]) do
    from_list_units_row(
      {name, description, load_state, active_state, sub_state, followed, object_path, job_id,
       job_type, job_path}
    )
  end
end
