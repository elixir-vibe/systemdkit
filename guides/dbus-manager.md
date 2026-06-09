# D-Bus manager operations

`systemdkit` talks to `org.freedesktop.systemd1` over D-Bus and returns
idiomatic `{:ok, value}` / `{:error, %Systemd.Error{}}` tuples. It does not
retry through `sudo` or shell out to `systemctl`.

## Short-lived connections

Use the top-level `Systemd` module for one-off operations:

```elixir
{:ok, units} = Systemd.list_units()
{:ok, jobs} = Systemd.list_jobs()
{:ok, unit_files} = Systemd.list_unit_files()
{:ok, state} = Systemd.unit_file_state("sshd.service")

:ok = Systemd.reload()
:ok = Systemd.start_unit("my_app@4000.service")
:ok = Systemd.reload_or_restart_unit("my_app@4000.service")
:ok = Systemd.reset_failed_unit("my_app@4000.service")
```

Mutating operations may fail with a policy or polkit error:

```elixir
case Systemd.start_unit("my_app@4000.service") do
  :ok -> :ok
  {:error, error} ->
    if Systemd.Error.permission?(error) do
      # Ask the operator to run with suitable policy/root privileges.
      {:error, :permission_denied}
    else
      {:error, error}
    end
end
```

## Reusing a connection

For multiple calls, keep a D-Bus connection open:

```elixir
Systemd.with_connection([], fn conn ->
  with {:ok, unit} <- Systemd.Manager.get_unit(conn, "dbus.service"),
       {:ok, state} <- Systemd.UnitObject.state(conn, unit),
       {:ok, jobs} <- Systemd.Manager.list_jobs(conn) do
    {:ok, {state, jobs}}
  end
end)
```

## Job tracking

Unit lifecycle methods return jobs through `Systemd.Manager`. Top-level helpers
wait for jobs by default; pass `wait: false` to inspect the job yourself:

```elixir
{:ok, conn} = Systemd.Manager.connect()
{:ok, job} = Systemd.Manager.restart_unit(conn, "my_app@4000.service")
{:ok, :running} = Systemd.Job.state(conn, job)
:ok = Systemd.Job.await(conn, job, timeout: 10_000)
```

Jobs can be cancelled through the job object when systemd still exposes it:

```elixir
Systemd.Job.cancel(conn, job)
```

## User bus

Pass `bus: :session` for user units when a systemd user session bus is available:

```elixir
Systemd.list_units(bus: :session)
```
