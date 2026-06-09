defmodule Systemd.UnitFile.Validator do
  @moduledoc false

  alias Systemd.UnitFile
  alias Systemd.UnitFile.{Directive, Section, ValidationError, Value, ValueParser}

  @known_sections %{
    "service" => MapSet.new(["Unit", "Service", "Install"]),
    "socket" => MapSet.new(["Unit", "Socket", "Install"]),
    "timer" => MapSet.new(["Unit", "Timer", "Install"]),
    "target" => MapSet.new(["Unit", "Target", "Install"]),
    "mount" => MapSet.new(["Unit", "Mount", "Install"]),
    "path" => MapSet.new(["Unit", "Path", "Install"])
  }

  @required_sections %{
    "service" => ["Service"],
    "socket" => ["Socket"],
    "timer" => ["Timer"],
    "target" => ["Target"],
    "mount" => ["Mount"],
    "path" => ["Path"]
  }

  @known_directives %{
    "Unit" =>
      MapSet.new(
        ~w(Description Documentation Requires Wants After Before BindsTo PartOf Conflicts RequiresMountsFor ConditionPathExists AssertPathExists StartLimitIntervalSec StartLimitBurst)
      ),
    "Service" =>
      MapSet.new(
        ~w(Type ExecStart ExecStartPre ExecStartPost ExecCondition ExecReload ExecStop ExecStopPost Restart RestartSec User Group WorkingDirectory RootDirectory Environment EnvironmentFile PassEnvironment UnsetEnvironment TimeoutStartSec TimeoutStopSec TimeoutAbortSec KillSignal KillMode RemainAfterExit GuessMainPID PIDFile RuntimeDirectory RuntimeDirectoryPreserve StateDirectory CacheDirectory LogsDirectory ConfigurationDirectory StandardOutput StandardError SyslogIdentifier Slice Delegate CPUAccounting CPUWeight CPUQuota MemoryAccounting MemoryMin MemoryLow MemoryHigh MemoryMax MemorySwapMax TasksAccounting TasksMax IOAccounting IOWeight IPAccounting LimitNOFILE LimitNPROC LimitMEMLOCK LimitCORE LimitCPU LimitAS LimitFSIZE NoNewPrivileges PrivateTmp PrivateDevices PrivateNetwork PrivateUsers ProtectSystem ProtectHome ProtectKernelTunables ProtectKernelModules ProtectKernelLogs ProtectControlGroups ProtectClock ProtectHostname ProtectProc RestrictAddressFamilies RestrictNamespaces RestrictRealtime RestrictSUIDSGID SystemCallFilter SystemCallArchitectures SystemCallErrorNumber AmbientCapabilities CapabilityBoundingSet ReadWritePaths ReadOnlyPaths InaccessiblePaths OOMPolicy)
      ),
    "Install" => MapSet.new(~w(WantedBy RequiredBy Also Alias DefaultInstance)),
    "Socket" =>
      MapSet.new(
        ~w(ListenStream ListenDatagram ListenSequentialPacket ListenFIFO ListenSpecial ListenNetlink ListenMessageQueue ListenUSBFunction SocketUser SocketGroup SocketMode DirectoryMode Accept Writable MaxConnections MaxConnectionsPerSource KeepAlive NoDelay FreeBind BindIPv6Only Backlog Service)
      ),
    "Timer" =>
      MapSet.new(
        ~w(OnActiveSec OnBootSec OnStartupSec OnUnitActiveSec OnUnitInactiveSec OnCalendar Unit Persistent AccuracySec RandomizedDelaySec FixedRandomDelay WakeSystem RemainAfterElapse)
      ),
    "Target" => MapSet.new(~w(AllowIsolate StopWhenUnneeded RefuseManualStart RefuseManualStop)),
    "Mount" =>
      MapSet.new(
        ~w(What Where Type Options SloppyOptions LazyUnmount ForceUnmount DirectoryMode TimeoutSec ReadWriteOnly ExtraOptions)
      ),
    "Path" =>
      MapSet.new(
        ~w(PathExists PathExistsGlob PathChanged PathModified DirectoryNotEmpty Unit MakeDirectory DirectoryMode TriggerLimitIntervalSec TriggerLimitBurst)
      )
  }

  @doc false
  @spec validate(UnitFile.t(), String.t() | atom() | nil) :: :ok | {:error, [ValidationError.t()]}
  def validate(%UnitFile{} = unit_file, type \\ nil) do
    errors =
      []
      |> collect_duplicate_section_errors(unit_file)
      |> collect_unknown_section_errors(unit_file, normalize_type(type))
      |> collect_missing_section_errors(unit_file, normalize_type(type))
      |> collect_directive_scope_errors(unit_file)
      |> collect_unknown_directive_errors(unit_file)
      |> collect_directive_value_errors(unit_file)

    case Enum.reverse(errors) do
      [] -> :ok
      errors -> {:error, errors}
    end
  end

  defp collect_duplicate_section_errors(errors, unit_file) do
    {_seen, errors} =
      Enum.reduce(unit_file.entries, {MapSet.new(), errors}, fn
        %Section{name: name, span: span}, {seen, errors} ->
          if MapSet.member?(seen, name) do
            {seen,
             [
               error(:duplicate_section, "duplicate section #{inspect(name)}", name, nil, span)
               | errors
             ]}
          else
            {MapSet.put(seen, name), errors}
          end

        _entry, acc ->
          acc
      end)

    errors
  end

  defp collect_unknown_section_errors(errors, _unit_file, nil), do: errors

  defp collect_unknown_section_errors(errors, unit_file, type) do
    allowed = Map.get(@known_sections, type, MapSet.new())

    Enum.reduce(unit_file.entries, errors, fn
      %Section{name: name, span: span}, errors ->
        if MapSet.member?(allowed, name) do
          errors
        else
          [
            error(:unknown_section, "unknown #{type} section #{inspect(name)}", name, nil, span)
            | errors
          ]
        end

      _entry, errors ->
        errors
    end)
  end

  defp collect_missing_section_errors(errors, _unit_file, nil), do: errors

  defp collect_missing_section_errors(errors, unit_file, type) do
    present = unit_file |> section_names() |> MapSet.new()

    type
    |> required_sections()
    |> Enum.reduce(errors, fn section, errors ->
      if MapSet.member?(present, section) do
        errors
      else
        [
          error(
            :missing_section,
            "missing required section #{inspect(section)}",
            section,
            nil,
            nil
          )
          | errors
        ]
      end
    end)
  end

  defp collect_unknown_directive_errors(errors, unit_file) do
    {_section, errors} =
      Enum.reduce(unit_file.entries, {nil, errors}, fn
        %Section{name: section}, {_current_section, errors} ->
          {section, errors}

        %Directive{name: directive, span: span}, {section, errors} when is_binary(section) ->
          allowed = Map.get(@known_directives, section)

          if is_nil(allowed) or MapSet.member?(allowed, directive) do
            {section, errors}
          else
            {section,
             [
               error(
                 :unknown_directive,
                 "unknown directive #{inspect(directive)} in section #{inspect(section)}",
                 section,
                 directive,
                 span
               )
               | errors
             ]}
          end

        _entry, acc ->
          acc
      end)

    errors
  end

  defp collect_directive_value_errors(errors, unit_file) do
    {_section, errors} =
      Enum.reduce(unit_file.entries, {nil, errors}, fn
        %Section{name: section}, {_current_section, errors} ->
          {section, errors}

        %Directive{name: directive, value: value, span: span}, {section, errors} ->
          errors =
            section
            |> value_errors(directive, value, span)
            |> Enum.concat(errors)

          {section, errors}

        _entry, acc ->
          acc
      end)

    errors
  end

  defp value_errors("Service", "Type", value, span) do
    one_of(
      "Service",
      "Type",
      value,
      ~w(simple exec forking oneshot dbus notify notify-reload idle),
      span
    )
  end

  defp value_errors("Service", "Restart", value, span) do
    one_of(
      "Service",
      "Restart",
      value,
      ~w(no on-success on-failure on-abnormal on-watchdog on-abort always),
      span
    )
  end

  defp value_errors("Service", directive, value, span)
       when directive in ["ExecStart", "ExecReload", "ExecStop"] do
    non_empty("Service", directive, value, span)
  end

  defp value_errors("Service", directive, value, span)
       when directive in ["TimeoutStartSec", "TimeoutStopSec", "TimeoutAbortSec", "RestartSec"] do
    duration("Service", directive, value, span)
  end

  defp value_errors("Service", directive, value, span)
       when directive in [
              "RemainAfterExit",
              "GuessMainPID",
              "Delegate",
              "CPUAccounting",
              "MemoryAccounting",
              "TasksAccounting",
              "IOAccounting",
              "IPAccounting",
              "NoNewPrivileges",
              "PrivateTmp",
              "PrivateDevices",
              "PrivateNetwork",
              "PrivateUsers",
              "ProtectKernelTunables",
              "ProtectKernelModules",
              "ProtectKernelLogs",
              "ProtectControlGroups",
              "ProtectClock",
              "ProtectHostname",
              "RestrictNamespaces",
              "RestrictRealtime",
              "RestrictSUIDSGID"
            ] do
    boolean("Service", directive, value, span)
  end

  defp value_errors("Service", directive, value, span)
       when directive in [
              "MemoryMin",
              "MemoryLow",
              "MemoryHigh",
              "MemoryMax",
              "MemorySwapMax",
              "TasksMax"
            ] do
    resource_limit("Service", directive, value, span)
  end

  defp value_errors("Service", directive, value, span)
       when directive in ["CPUWeight", "IOWeight"] do
    positive_integer("Service", directive, value, span)
  end

  defp value_errors("Service", "CPUQuota", value, span),
    do: percentage("Service", "CPUQuota", value, span)

  defp value_errors("Service", "ProtectSystem", value, span) do
    one_of(
      "Service",
      "ProtectSystem",
      String.downcase(value),
      ~w(1 yes true on 0 no false off full strict),
      span
    )
  end

  defp value_errors("Service", "ProtectHome", value, span) do
    one_of(
      "Service",
      "ProtectHome",
      String.downcase(value),
      ~w(1 yes true on 0 no false off read-only tmpfs),
      span
    )
  end

  defp value_errors("Service", "ProtectProc", value, span) do
    one_of("Service", "ProtectProc", value, ~w(default invisible ptraceable noaccess), span)
  end

  defp value_errors("Service", directive, value, span)
       when directive in [
              "RestrictAddressFamilies",
              "SystemCallFilter",
              "SystemCallArchitectures",
              "SystemCallErrorNumber",
              "AmbientCapabilities",
              "CapabilityBoundingSet",
              "ReadWritePaths",
              "ReadOnlyPaths",
              "InaccessiblePaths"
            ] do
    non_empty_words("Service", directive, value, span)
  end

  defp value_errors("Service", "KillMode", value, span) do
    one_of("Service", "KillMode", value, ~w(control-group mixed process none), span)
  end

  defp value_errors("Timer", directive, value, span)
       when directive in [
              "OnActiveSec",
              "OnBootSec",
              "OnStartupSec",
              "OnUnitActiveSec",
              "OnUnitInactiveSec",
              "AccuracySec",
              "RandomizedDelaySec"
            ] do
    duration("Timer", directive, value, span)
  end

  defp value_errors("Timer", directive, value, span)
       when directive in ["Persistent", "FixedRandomDelay", "WakeSystem", "RemainAfterElapse"] do
    boolean("Timer", directive, value, span)
  end

  defp value_errors("Timer", "OnCalendar", value, span),
    do: non_empty("Timer", "OnCalendar", value, span)

  defp value_errors("Socket", directive, value, span)
       when directive in [
              "ListenStream",
              "ListenDatagram",
              "ListenSequentialPacket",
              "ListenFIFO",
              "ListenSpecial",
              "ListenNetlink",
              "ListenMessageQueue",
              "ListenUSBFunction"
            ] do
    non_empty("Socket", directive, value, span)
  end

  defp value_errors("Socket", directive, value, span)
       when directive in ["SocketMode", "DirectoryMode"] do
    octal_mode("Socket", directive, value, span)
  end

  defp value_errors("Socket", directive, value, span)
       when directive in ["Accept", "Writable", "KeepAlive", "NoDelay", "FreeBind"] do
    boolean("Socket", directive, value, span)
  end

  defp value_errors("Target", directive, value, span)
       when directive in [
              "AllowIsolate",
              "StopWhenUnneeded",
              "RefuseManualStart",
              "RefuseManualStop"
            ] do
    boolean("Target", directive, value, span)
  end

  defp value_errors("Mount", directive, value, span) when directive in ["What", "Where"] do
    non_empty("Mount", directive, value, span)
  end

  defp value_errors("Mount", directive, value, span)
       when directive in ["SloppyOptions", "LazyUnmount", "ForceUnmount", "ReadWriteOnly"] do
    boolean("Mount", directive, value, span)
  end

  defp value_errors("Mount", "DirectoryMode", value, span),
    do: octal_mode("Mount", "DirectoryMode", value, span)

  defp value_errors("Mount", "TimeoutSec", value, span),
    do: duration("Mount", "TimeoutSec", value, span)

  defp value_errors("Path", directive, value, span)
       when directive in [
              "PathExists",
              "PathExistsGlob",
              "PathChanged",
              "PathModified",
              "DirectoryNotEmpty"
            ] do
    non_empty("Path", directive, value, span)
  end

  defp value_errors("Path", "MakeDirectory", value, span),
    do: boolean("Path", "MakeDirectory", value, span)

  defp value_errors("Path", "DirectoryMode", value, span),
    do: octal_mode("Path", "DirectoryMode", value, span)

  defp value_errors("Path", "TriggerLimitIntervalSec", value, span),
    do: duration("Path", "TriggerLimitIntervalSec", value, span)

  defp value_errors("Install", directive, value, span)
       when directive in ["WantedBy", "RequiredBy", "Also", "Alias"] do
    non_empty_words("Install", directive, value, span)
  end

  defp value_errors(_section, _directive, _value, _span), do: []

  defp one_of(section, directive, value, allowed, span) do
    if value in allowed do
      []
    else
      [
        value_error(
          section,
          directive,
          value,
          "expected one of #{Enum.join(allowed, ", ")}",
          span
        )
      ]
    end
  end

  defp boolean(section, directive, value, span) do
    one_of(section, directive, String.downcase(value), ~w(1 yes true on 0 no false off), span)
  end

  defp duration(section, directive, value, span) do
    if ValueParser.duration?(value) do
      []
    else
      [
        value_error(
          section,
          directive,
          value,
          "expected a systemd duration such as 10s, 5min, or infinity",
          span
        )
      ]
    end
  end

  defp resource_limit(_section, _directive, "infinity", _span), do: []

  defp resource_limit(section, directive, value, span) do
    if ValueParser.resource_quantity?(value) do
      []
    else
      [
        value_error(
          section,
          directive,
          value,
          "expected bytes, K/M/G/T/P/E suffix, or infinity",
          span
        )
      ]
    end
  end

  defp positive_integer(section, directive, value, span) do
    if ValueParser.positive_integer?(value) do
      []
    else
      [value_error(section, directive, value, "expected a positive integer", span)]
    end
  end

  defp percentage(section, directive, value, span) do
    if ValueParser.percentage?(value) do
      []
    else
      [value_error(section, directive, value, "expected a percentage such as 50%", span)]
    end
  end

  defp octal_mode(section, directive, value, span) do
    if ValueParser.octal_mode?(value) do
      []
    else
      [value_error(section, directive, value, "expected an octal mode such as 0660", span)]
    end
  end

  defp non_empty(section, directive, value, span) do
    if String.trim(value) == "" do
      [value_error(section, directive, value, "must not be empty", span)]
    else
      []
    end
  end

  defp non_empty_words(section, directive, value, span) do
    case Value.words(value) do
      {:ok, [_ | _]} -> []
      _other -> [value_error(section, directive, value, "must contain at least one value", span)]
    end
  end

  defp value_error(section, directive, value, expectation, span) do
    error(
      :invalid_directive_value,
      "invalid #{section}.#{directive} value #{inspect(value)}: #{expectation}",
      section,
      directive,
      span
    )
  end

  defp collect_directive_scope_errors(errors, unit_file) do
    {_section, errors} =
      Enum.reduce(unit_file.entries, {nil, errors}, fn
        %Section{name: section}, {_current_section, errors} ->
          {section, errors}

        %Directive{name: directive, span: span}, {nil, errors} ->
          {nil,
           [
             error(
               :directive_outside_section,
               "directive #{inspect(directive)} appears before any section",
               nil,
               directive,
               span
             )
             | errors
           ]}

        _entry, acc ->
          acc
      end)

    errors
  end

  defp section_names(unit_file) do
    Enum.flat_map(unit_file.entries, fn
      %Section{name: name} -> [name]
      _entry -> []
    end)
  end

  defp required_sections(type), do: Map.get(@required_sections, type, [])

  defp normalize_type(nil), do: nil
  defp normalize_type(type) when is_atom(type), do: Atom.to_string(type)
  defp normalize_type(type) when is_binary(type), do: String.trim_leading(type, ".")

  defp error(reason, message, section, directive, span) do
    %ValidationError{
      reason: reason,
      message: message,
      section: section,
      directive: directive,
      span: span
    }
  end
end
