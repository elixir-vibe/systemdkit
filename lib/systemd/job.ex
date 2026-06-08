defmodule Systemd.Job do
  @moduledoc """
  A systemd job returned by manager operations such as `StartUnit`.
  """

  alias Systemd.{Error, Properties}

  @interface "org.freedesktop.systemd1.Job"

  @type state :: :waiting | :running | :done | :unknown
  @type t :: %__MODULE__{object_path: String.t()}

  defstruct [:object_path]

  @doc """
  Reads a job property.
  """
  @spec property(pid(), t(), String.t()) :: {:ok, term()} | {:error, Error.t()}
  def property(conn, %__MODULE__{object_path: path}, property) do
    Properties.get(conn, path, @interface, property)
  end

  @doc """
  Polls until a job leaves `waiting`/`running` or disappears from the bus.
  """
  @spec await(pid(), t(), keyword()) :: :ok | {:error, Error.t()}
  def await(conn, %__MODULE__{} = job, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    interval = Keyword.get(opts, :interval, 100)
    deadline = System.monotonic_time(:millisecond) + timeout

    do_await(conn, job, interval, deadline)
  end

  defp do_await(conn, job, interval, deadline) do
    case state(conn, job) do
      {:ok, state} when state in [:waiting, :running] ->
        if System.monotonic_time(:millisecond) >= deadline do
          {:error, Error.connection_error(:timeout)}
        else
          Process.sleep(interval)
          do_await(conn, job, interval, deadline)
        end

      {:ok, _state} ->
        :ok

      {:error, %Error{reason: reason}} when reason in [:unknown_object, :no_such_job] ->
        :ok

      {:error, error} ->
        {:error, error}
    end
  end

  defp state(conn, job) do
    with {:ok, value} <- property(conn, job, "State") do
      {:ok, normalize_state(value)}
    end
  end

  defp normalize_state("waiting"), do: :waiting
  defp normalize_state("running"), do: :running
  defp normalize_state("done"), do: :done
  defp normalize_state(_state), do: :unknown
end
