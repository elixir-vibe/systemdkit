# Xamal-style deployment units

`systemdkit` can build and validate template service units like the ones used by
Xamal-style blue/green deployments. The port is the instance identifier, so
`my_app@4000.service` and `my_app@4001.service` can be started independently.

```elixir
unit_file =
  Systemd.UnitFile.service(
    unit: [
      description: "my_app (%i)",
      after: "network.target"
    ],
    service: [
      type: :exec,
      user: "deploy",
      working_directory: "/opt/xamal/my-app/current",
      environment_file: "-/opt/xamal/my-app/env/app.env",
      environment: ["PORT=%i", "RELEASE_NODE=my_app_%i"],
      exec_start: "/opt/xamal/my-app/current/bin/my_app start",
      restart: "on-failure",
      restart_sec: 5,
      timeout_stop_sec: 30,
      limit_nofile: 1_048_576,
      cpu_accounting: true,
      cpu_quota: "50%",
      memory_accounting: true,
      memory_max: "512M",
      tasks_max: 512,
      no_new_privileges: true,
      protect_system: :strict,
      protect_home: "read-only"
    ],
    install: [wanted_by: "multi-user.target"]
  )

:ok = Systemd.UnitFile.validate(unit_file, :service)
Systemd.UnitFile.to_string(unit_file)
```

For local systemd managers, D-Bus operations can be used directly:

```elixir
:ok = Systemd.reload()
:ok = Systemd.start_unit("my_app@4000.service")
{:ok, state} = Systemd.unit_state("my_app@4000.service")
```

For remote deployment tools, generate and validate unit files locally, then use
the tool's remote execution layer to install the rendered unit on the host.
