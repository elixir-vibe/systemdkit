defmodule Systemd.UnitFileTest do
  use ExUnit.Case, async: true

  alias Systemd.UnitFile
  alias Systemd.UnitFile.{Blank, Comment, Directive, ParseError, Section, Span, Value}

  test "parses sections, comments, blanks, directives, and duplicates" do
    text = """
    # example
    [Unit]
    Description=My app
    After=network.target
    After=postgresql.service

    [Service]
    ExecStart=/opt/app/bin/app start
    ExecStart=
    ExecStart=/opt/app/bin/app foreground
    """

    assert {:ok, %UnitFile{entries: entries} = unit_file} = UnitFile.parse(text)

    assert [
             %Comment{marker: "#", text: " example"},
             %Section{name: "Unit"},
             %Directive{name: "Description", value: "My app"},
             %Directive{name: "After", value: "network.target"},
             %Directive{name: "After", value: "postgresql.service"},
             %Blank{},
             %Section{name: "Service"},
             %Directive{name: "ExecStart", value: "/opt/app/bin/app start"},
             %Directive{name: "ExecStart", value: ""},
             %Directive{name: "ExecStart", value: "/opt/app/bin/app foreground"}
           ] = entries

    assert UnitFile.get_all(unit_file, "Unit", "After") == [
             "network.target",
             "postgresql.service"
           ]

    assert UnitFile.get_all(unit_file, "Service", "ExecStart") == [
             "/opt/app/bin/app start",
             "",
             "/opt/app/bin/app foreground"
           ]
  end

  test "renders parsed unit files deterministically" do
    text = "[Unit]\nDescription=My app\n\n[Install]\nWantedBy=multi-user.target\n"

    assert {:ok, unit_file} = UnitFile.parse(text)
    assert UnitFile.to_string(unit_file) == text
  end

  test "supports directive continuations" do
    text = "[Service]\nExecStart=/bin/echo hello \\\n      world\n"

    assert {:ok, unit_file} = UnitFile.parse(text)
    assert UnitFile.get_all(unit_file, "Service", "ExecStart") == ["/bin/echo hello world"]
  end

  test "records source spans" do
    assert {:ok,
            %UnitFile{
              entries: [
                %Comment{span: %Span{line: 1, column: 3}},
                %Section{span: %Span{line: 2, column: 1}}
              ]
            }} =
             UnitFile.parse("  ; hello\n[Unit]\n")
  end

  test "returns structured parse errors" do
    assert {:error, %ParseError{line: 1, reason: reason}} = UnitFile.parse("[Unit] trailing\n")
    assert is_binary(reason)
  end

  test "parses quoted value words" do
    assert Value.words(~s[/bin/echo "hello world" 'again' escaped\\ space]) ==
             {:ok, ["/bin/echo", "hello world", "again", "escaped space"]}
  end

  test "builds common service unit sections" do
    unit_file =
      UnitFile.service(
        unit: [description: "My app", after: ["network.target", "postgresql.service"]],
        service: [exec_start: "/opt/app/bin/app start", restart: :always, limit_nofile: 1_048_576],
        install: [wanted_by: "multi-user.target"]
      )

    assert UnitFile.to_string(unit_file) ==
             "[Unit]\nDescription=My app\nAfter=network.target\nAfter=postgresql.service\n[Service]\nExecStart=/opt/app/bin/app start\nRestart=always\nLimitNOFILE=1048576\n[Install]\nWantedBy=multi-user.target\n"
  end

  test "builds common socket and timer unit sections" do
    socket =
      UnitFile.socket(
        unit: [description: "App socket"],
        socket: [listen_stream: 4_000, accept: false, socket_mode: "0660"],
        install: [wanted_by: "sockets.target"]
      )

    assert UnitFile.to_string(socket) ==
             "[Unit]\nDescription=App socket\n[Socket]\nListenStream=4000\nAccept=false\nSocketMode=0660\n[Install]\nWantedBy=sockets.target\n"

    timer =
      UnitFile.timer(
        unit: [description: "App timer"],
        timer: [on_calendar: "*:0/5", persistent: true, randomized_delay_sec: "30s"],
        install: [wanted_by: "timers.target"]
      )

    assert UnitFile.to_string(timer) ==
             "[Unit]\nDescription=App timer\n[Timer]\nOnCalendar=*:0/5\nPersistent=true\nRandomizedDelaySec=30s\n[Install]\nWantedBy=timers.target\n"
  end

  test "builds mount, path, and target unit sections" do
    mount =
      UnitFile.mount(
        mount: [
          what: "/dev/disk/by-label/data",
          where: "/srv/data",
          type: "ext4",
          directory_mode: "0755",
          timeout_sec: "30s"
        ]
      )

    assert UnitFile.to_string(mount) ==
             "[Mount]\nWhat=/dev/disk/by-label/data\nWhere=/srv/data\nType=ext4\nDirectoryMode=0755\nTimeoutSec=30s\n"

    path =
      UnitFile.path(
        path: [path_changed: "/etc/app/config.toml", make_directory: true, directory_mode: "0750"]
      )

    assert UnitFile.to_string(path) ==
             "[Path]\nPathChanged=/etc/app/config.toml\nMakeDirectory=true\nDirectoryMode=0750\n"

    target = UnitFile.target(unit: [description: "App stack"], target: [allow_isolate: true])

    assert UnitFile.to_string(target) ==
             "[Unit]\nDescription=App stack\n[Target]\nAllowIsolate=true\n"
  end

  test "preserves known systemd acronym directive names" do
    unit_file =
      UnitFile.service(
        service: [
          pid_file: "/run/app.pid",
          syslog_identifier: "app",
          limit_nofile: 1_048_576,
          limit_memlock: :infinity,
          oom_policy: :stop
        ]
      )

    assert UnitFile.to_string(unit_file) ==
             "[Service]\nPIDFile=/run/app.pid\nSyslogIdentifier=app\nLimitNOFILE=1048576\nLimitMEMLOCK=infinity\nOOMPolicy=stop\n"
  end

  test "validates common cgroup and resource-control directives" do
    assert :ok =
             UnitFile.parse!(
               "[Service]\nExecStart=/bin/true\nCPUAccounting=yes\nCPUWeight=100\nCPUQuota=50%\nMemoryAccounting=true\nMemoryMax=256M\nMemorySwapMax=infinity\nTasksMax=64\nIOAccounting=on\nIOWeight=200\nDelegate=no\n"
             )
             |> UnitFile.validate(:service)

    assert {:error, errors} =
             UnitFile.parse!(
               "[Service]\nExecStart=/bin/true\nCPUAccounting=maybe\nCPUWeight=heavy\nCPUQuota=half\nMemoryMax=lots\nTasksMax=many\n"
             )
             |> UnitFile.validate(:service)

    for directive <- ["CPUAccounting", "CPUWeight", "CPUQuota", "MemoryMax", "TasksMax"] do
      assert Enum.any?(
               errors,
               &match?(
                 %Systemd.UnitFile.ValidationError{
                   reason: :invalid_directive_value,
                   directive: ^directive
                 },
                 &1
               )
             )
    end
  end

  test "validates unit file sections and directives" do
    assert :ok =
             UnitFile.parse!("[Service]\nExecStart=/bin/true\nLimitNOFILE=1048576\n")
             |> UnitFile.validate(:service)

    assert {:error, [%Systemd.UnitFile.ValidationError{reason: :missing_section}]} =
             UnitFile.parse!("[Unit]\nDescription=Only metadata\n") |> UnitFile.validate(:service)

    assert {:error, [%Systemd.UnitFile.ValidationError{reason: :unknown_directive}]} =
             UnitFile.parse!("[Service]\nDefinitelyNotAServiceDirective=true\n")
             |> UnitFile.validate(:service)
  end

  test "validates mount, path, and target directive values" do
    assert :ok =
             UnitFile.parse!(
               "[Mount]\nWhat=/dev/sda1\nWhere=/mnt/data\nDirectoryMode=0755\nTimeoutSec=1min\n"
             )
             |> UnitFile.validate(:mount)

    assert :ok =
             UnitFile.parse!(
               "[Path]\nPathChanged=/etc/app/config.toml\nMakeDirectory=yes\nDirectoryMode=0750\nTriggerLimitIntervalSec=10s\n"
             )
             |> UnitFile.validate(:path)

    assert :ok = UnitFile.parse!("[Target]\nAllowIsolate=true\n") |> UnitFile.validate(:target)

    assert {:error, errors} =
             UnitFile.parse!(
               "[Mount]\nWhat=\nWhere=/mnt/data\nDirectoryMode=invalid\n[Path]\nMakeDirectory=maybe\n[Target]\nAllowIsolate=perhaps\n"
             )
             |> UnitFile.validate()

    assert Enum.any?(
             errors,
             &match?(
               %Systemd.UnitFile.ValidationError{
                 reason: :invalid_directive_value,
                 directive: "What"
               },
               &1
             )
           )

    assert Enum.any?(
             errors,
             &match?(
               %Systemd.UnitFile.ValidationError{
                 reason: :invalid_directive_value,
                 directive: "DirectoryMode"
               },
               &1
             )
           )

    assert Enum.any?(
             errors,
             &match?(
               %Systemd.UnitFile.ValidationError{
                 reason: :invalid_directive_value,
                 directive: "MakeDirectory"
               },
               &1
             )
           )

    assert Enum.any?(
             errors,
             &match?(
               %Systemd.UnitFile.ValidationError{
                 reason: :invalid_directive_value,
                 directive: "AllowIsolate"
               },
               &1
             )
           )
  end

  test "validates common directive values" do
    assert :ok =
             UnitFile.parse!("[Service]\nType=oneshot\nExecStart=/bin/true\nRestart=on-failure\n")
             |> UnitFile.validate(:service)

    assert {:error, errors} =
             UnitFile.parse!(
               "[Service]\nType=sometimes\nRestartSec=later\n[Timer]\nPersistent=maybe\n"
             )
             |> UnitFile.validate(:service)

    assert Enum.any?(
             errors,
             &match?(
               %Systemd.UnitFile.ValidationError{
                 reason: :invalid_directive_value,
                 directive: "Type"
               },
               &1
             )
           )

    assert Enum.any?(
             errors,
             &match?(
               %Systemd.UnitFile.ValidationError{
                 reason: :invalid_directive_value,
                 directive: "RestartSec"
               },
               &1
             )
           )

    assert Enum.any?(
             errors,
             &match?(
               %Systemd.UnitFile.ValidationError{
                 reason: :invalid_directive_value,
                 directive: "Persistent"
               },
               &1
             )
           )
  end

  test "appends before trailing section trivia" do
    unit_file =
      UnitFile.parse!(
        "[Service]\nExecStart=/bin/true\n\n# keep with section\n[Install]\nWantedBy=multi-user.target\n"
      )

    unit_file = UnitFile.append(unit_file, "Service", "Restart", "always")

    assert UnitFile.to_string(unit_file) ==
             "[Service]\nExecStart=/bin/true\nRestart=always\n\n# keep with section\n[Install]\nWantedBy=multi-user.target\n"
  end

  test "appends, puts, and deletes directives while preserving duplicates elsewhere" do
    unit_file = UnitFile.parse!("[Service]\nEnvironment=FOO=1\nEnvironment=BAR=2\n")

    unit_file = UnitFile.append(unit_file, "Service", "Restart", "on-failure")
    assert UnitFile.get_all(unit_file, "Service", "Restart") == ["on-failure"]

    unit_file = UnitFile.put(unit_file, "Service", "Environment", "BAZ=3")
    assert UnitFile.get_all(unit_file, "Service", "Environment") == ["BAZ=3"]

    unit_file = UnitFile.delete(unit_file, "Service", "Restart")
    assert UnitFile.get_all(unit_file, "Service", "Restart") == []
  end
end
