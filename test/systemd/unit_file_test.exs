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
        service: [exec_start: "/opt/app/bin/app start", restart: :always, LimitNOFILE: 1_048_576],
        install: [wanted_by: "multi-user.target"]
      )

    assert UnitFile.to_string(unit_file) ==
             "[Unit]\nDescription=My app\nAfter=network.target\nAfter=postgresql.service\n[Service]\nExecStart=/opt/app/bin/app start\nRestart=always\nLimitNOFILE=1048576\n[Install]\nWantedBy=multi-user.target\n"
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
