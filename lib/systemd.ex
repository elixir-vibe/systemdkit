defmodule Systemd do
  @moduledoc """
  Pure Elixir tools for working with systemd.

  The package provides a D-Bus backed manager client, unit object/property APIs,
  job awaiting, installation helpers, and a loss-aware unit file parser/generator.

  ## Examples

      {:ok, units} = Systemd.list_units()
      :ok = Systemd.start_unit("example.service")
      {:ok, state} = Systemd.unit_state("dbus.service")

      unit_file =
        Systemd.UnitFile.service(
          unit: [description: "Example"],
          service: [exec_start: "/bin/true", type: :oneshot],
          install: [wanted_by: "multi-user.target"]
        )

      :ok = Systemd.UnitFile.validate(unit_file, :service)

  Mutating calls can return `{:error, %Systemd.Error{category: :permission}}`
  when systemd or polkit denies the D-Bus operation.
  """

  alias Systemd.{Error, Manager}
  alias Systemd.Manager.Options

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
  Lists queued jobs using a short-lived connection.
  """
  @spec list_jobs(keyword()) :: {:ok, [Systemd.JobStatus.t()]} | {:error, Error.t()}
  def list_jobs(opts \\ []) do
    with_connection(opts, &Manager.list_jobs/1)
  end

  @doc """
  Reads common state for a unit using a short-lived connection.
  """
  @spec unit_state(String.t(), keyword()) :: {:ok, Systemd.UnitState.t()} | {:error, Error.t()}
  def unit_state(name, opts \\ []) do
    with_connection(opts, fn conn ->
      with {:ok, unit} <- Manager.get_unit(conn, name) do
        Systemd.UnitObject.state(conn, unit)
      end
    end)
  end

  @doc """
  Returns unit files known to systemd using a short-lived connection.
  """
  @spec list_unit_files(keyword()) :: {:ok, [Systemd.UnitFileStatus.t()]} | {:error, Error.t()}
  def list_unit_files(opts \\ []) do
    with_connection(opts, &Manager.list_unit_files/1)
  end

  @doc """
  Returns the enablement state of a unit file using a short-lived connection.
  """
  @spec unit_file_state(String.t(), keyword()) :: {:ok, String.t()} | {:error, Error.t()}
  def unit_file_state(name, opts \\ []) do
    with_connection(opts, &Manager.unit_file_state(&1, name))
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
  Tries to restart a unit only if it is already active.
  """
  @spec try_restart_unit(String.t(), keyword()) ::
          :ok | {:ok, Systemd.Job.t()} | {:error, Error.t()}
  def try_restart_unit(name, opts \\ []) do
    run_unit_operation(:try_restart_unit, name, opts)
  end

  @doc """
  Reloads a unit if supported, otherwise restarts it.
  """
  @spec reload_or_restart_unit(String.t(), keyword()) ::
          :ok | {:ok, Systemd.Job.t()} | {:error, Error.t()}
  def reload_or_restart_unit(name, opts \\ []) do
    run_unit_operation(:reload_or_restart_unit, name, opts)
  end

  @doc """
  Reloads a unit if supported, otherwise tries to restart it only if active.
  """
  @spec reload_or_try_restart_unit(String.t(), keyword()) ::
          :ok | {:ok, Systemd.Job.t()} | {:error, Error.t()}
  def reload_or_try_restart_unit(name, opts \\ []) do
    run_unit_operation(:reload_or_try_restart_unit, name, opts)
  end

  @doc """
  Resets failed state for a unit using a short-lived connection.
  """
  @spec reset_failed_unit(String.t(), keyword()) :: :ok | {:error, Error.t()}
  def reset_failed_unit(name, opts \\ []) do
    with_connection(opts, &Manager.reset_failed_unit(&1, name))
  end

  @doc """
  Sends a Unix signal to processes belonging to a unit using a short-lived connection.
  """
  @spec kill_unit(String.t(), String.t(), integer(), keyword()) :: :ok | {:error, Error.t()}
  def kill_unit(name, who \\ "all", signal \\ 15, opts \\ []) do
    with_connection(opts, &Manager.kill_unit(&1, name, who, signal))
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
    opts = Options.new(opts)
    wait? = opts.wait
    await_opts = Options.await_opts(opts)

    with_connection([bus: opts.bus], fn conn ->
      Manager
      |> apply(operation, [conn, name, opts])
      |> maybe_await_job(conn, wait?, await_opts)
    end)
  end

  defp maybe_await_job({:ok, job}, conn, true, await_opts),
    do: Systemd.Job.await(conn, job, await_opts)

  defp maybe_await_job({:ok, job}, _conn, false, _await_opts), do: {:ok, job}
  defp maybe_await_job({:error, error}, _conn, _wait?, _await_opts), do: {:error, error}
end
