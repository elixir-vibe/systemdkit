defmodule Systemd.TransientUnit do
  @moduledoc """
  Constructors for systemd transient units.
  """

  alias Systemd.TransientUnit.Property

  @type property :: Property.t()

  @doc """
  Creates a typed transient-unit property.
  """
  @spec property(String.t(), String.t(), term()) :: Property.t()
  defdelegate property(name, signature, value), to: Property, as: :new

  @doc """
  Creates a string property.
  """
  @spec string(String.t(), String.t()) :: Property.t()
  def string(name, value), do: property(name, "s", value)

  @doc """
  Creates a boolean property.
  """
  @spec boolean(String.t(), boolean()) :: Property.t()
  def boolean(name, value), do: property(name, "b", value)

  @doc """
  Creates an unsigned 64-bit property.
  """
  @spec uint64(String.t(), non_neg_integer()) :: Property.t()
  def uint64(name, value), do: property(name, "t", value)

  @doc """
  Creates a memory limit property such as `MemoryMax`.
  """
  @spec memory_max(non_neg_integer()) :: Property.t()
  def memory_max(bytes), do: uint64("MemoryMax", bytes)

  @doc """
  Creates a task-count limit property such as `TasksMax`.
  """
  @spec tasks_max(non_neg_integer()) :: Property.t()
  def tasks_max(tasks), do: uint64("TasksMax", tasks)

  @doc """
  Creates a CPU quota property in microseconds per second.
  """
  @spec cpu_quota_per_sec_usec(non_neg_integer()) :: Property.t()
  def cpu_quota_per_sec_usec(usec), do: uint64("CPUQuotaPerSecUSec", usec)

  @doc """
  Creates an `ExecStart` property.
  """
  @spec exec_start(String.t(), [String.t()], boolean()) :: Property.t()
  def exec_start(path, argv, ignore_failure \\ false) do
    property("ExecStart", "a(sasb)", [{path, argv, ignore_failure}])
  end
end
