unit_file =
  Systemd.UnitFile.parse!(""")
  [Unit]
  Description=Run example cleanup daily

  [Timer]
  OnCalendar=daily
  Persistent=true
  Unit=example-cleanup.service

  [Install]
  WantedBy=timers.target
  """)

:ok = Systemd.UnitFile.validate(unit_file, :timer)
IO.write(Systemd.UnitFile.to_string(unit_file))
