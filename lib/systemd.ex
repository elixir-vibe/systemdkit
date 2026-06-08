defmodule Systemd do
  @moduledoc """
  Pure Elixir tools for working with systemd.

  The package provides a D-Bus backed manager client, unit object/property APIs,
  job awaiting, installation helpers, and a loss-aware unit file parser/generator.
  """

  alias Systemd.{Error, Manager}

  @type connection_option :: {:bus, Systemd.DBus.bus()}

  @doc """
  Runs a function with a short-lived systemd manager D-Bus connection.
  """
  @spec with_connection(keyword(), (pid() -> result)) :: result | {:error, Error.t()}
        when result: term()
  def with_connection(opts \\ [], fun) when is_function(fun, 1) do
    with {:ok, conn} <- Manager.connect(opts) do
      try do
        fun.(conn)
      after
        close(conn)
      end
    end
  end

  @doc """
  Closes a D-Bus connection process opened by this package.
  """
  @spec close(pid()) :: :ok
  def close(conn) when is_pid(conn) do
    if Process.alive?(conn), do: Process.exit(conn, :shutdown)
    :ok
  end

  @doc """
  Lists loaded units using a short-lived connection.
  """
  @spec list_units(keyword()) :: {:ok, [Systemd.Unit.t()]} | {:error, Error.t()}
  def list_units(opts \\ []) do
    with_connection(opts, &Manager.list_units/1)
  end

  @doc """
  Reads common state for a unit using a short-lived connection.
  """
  @spec unit_state(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def unit_state(name, opts \\ []) do
    with_connection(opts, fn conn ->
      with {:ok, unit} <- Manager.get_unit(conn, name) do
        Systemd.UnitObject.state(conn, unit)
      end
    end)
  end

  @doc """
  Starts a unit and waits for the returned job by default.
  """
  @spec start_unit(String.t(), keyword()) :: :ok | {:ok, Systemd.Job.t()} | {:error, Error.t()}
  def start_unit(name, opts \\ []) do
    run_unit_operation(:start_unit, name, opts)
  end

  @doc """
  Stops a unit and waits for the returned job by default.
  """
  @spec stop_unit(String.t(), keyword()) :: :ok | {:ok, Systemd.Job.t()} | {:error, Error.t()}
  def stop_unit(name, opts \\ []) do
    run_unit_operation(:stop_unit, name, opts)
  end

  @doc """
  Restarts a unit and waits for the returned job by default.
  """
  @spec restart_unit(String.t(), keyword()) :: :ok | {:ok, Systemd.Job.t()} | {:error, Error.t()}
  def restart_unit(name, opts \\ []) do
    run_unit_operation(:restart_unit, name, opts)
  end

  @doc """
  Reloads a unit and waits for the returned job by default.
  """
  @spec reload_unit(String.t(), keyword()) :: :ok | {:ok, Systemd.Job.t()} | {:error, Error.t()}
  def reload_unit(name, opts \\ []) do
    run_unit_operation(:reload_unit, name, opts)
  end

  @doc """
  Enables unit files using a short-lived connection.
  """
  @spec enable_unit_files([String.t()], keyword()) ::
          {:ok, Systemd.UnitFileOperation.t()} | {:error, Error.t()}
  def enable_unit_files(files, opts \\ []) do
    with_connection(opts, &Manager.enable_unit_files(&1, files, opts))
  end

  @doc """
  Disables unit files using a short-lived connection.
  """
  @spec disable_unit_files([String.t()], keyword()) ::
          {:ok, Systemd.UnitFileOperation.t()} | {:error, Error.t()}
  def disable_unit_files(files, opts \\ []) do
    with_connection(opts, &Manager.disable_unit_files(&1, files, opts))
  end

  @doc """
  Masks unit files using a short-lived connection.
  """
  @spec mask_unit_files([String.t()], keyword()) ::
          {:ok, Systemd.UnitFileOperation.t()} | {:error, Error.t()}
  def mask_unit_files(files, opts \\ []) do
    with_connection(opts, &Manager.mask_unit_files(&1, files, opts))
  end

  @doc """
  Unmasks unit files using a short-lived connection.
  """
  @spec unmask_unit_files([String.t()], keyword()) ::
          {:ok, Systemd.UnitFileOperation.t()} | {:error, Error.t()}
  def unmask_unit_files(files, opts \\ []) do
    with_connection(opts, &Manager.unmask_unit_files(&1, files, opts))
  end

  @doc """
  Links unit files using a short-lived connection.
  """
  @spec link_unit_files([String.t()], keyword()) ::
          {:ok, Systemd.UnitFileOperation.t()} | {:error, Error.t()}
  def link_unit_files(files, opts \\ []) do
    with_connection(opts, &Manager.link_unit_files(&1, files, opts))
  end

  @doc """
  Reloads systemd manager configuration using a short-lived connection.
  """
  @spec reload(keyword()) :: :ok | {:error, Error.t()}
  def reload(opts \\ []) do
    with_connection(opts, &Manager.reload/1)
  end

  defp run_unit_operation(operation, name, opts) do
    wait? = Keyword.get(opts, :wait, true)
    await_opts = Keyword.take(opts, [:timeout, :interval])
    manager_opts = Keyword.take(opts, [:mode])

    with_connection(opts, fn conn ->
      Manager
      |> apply(operation, [conn, name, manager_opts])
      |> maybe_await_job(conn, wait?, await_opts)
    end)
  end

  defp maybe_await_job({:ok, job}, conn, true, await_opts),
    do: Systemd.Job.await(conn, job, await_opts)

  defp maybe_await_job({:ok, job}, _conn, false, _await_opts), do: {:ok, job}
  defp maybe_await_job({:error, error}, _conn, _wait?, _await_opts), do: {:error, error}
end
