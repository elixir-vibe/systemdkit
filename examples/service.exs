unit_file =
  Systemd.UnitFile.service(
    unit: [description: "Example application", after: "network.target"],
    service: [
      type: "exec",
      exec_start: "/opt/example/bin/example start",
      restart: "on-failure",
      restart_sec: 5
    ],
    install: [wanted_by: "multi-user.target"]
  )

IO.write(Systemd.UnitFile.to_string(unit_file))
