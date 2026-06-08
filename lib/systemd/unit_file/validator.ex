defmodule Systemd.UnitFile.Validator do
  @moduledoc false

  alias Systemd.UnitFile
  alias Systemd.UnitFile.{Directive, Section, ValidationError, Value}

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
        ~w(Description Documentation Requires Wants After Before BindsTo PartOf Conflicts ConditionPathExists AssertPathExists StartLimitIntervalSec StartLimitBurst)
      ),
    "Service" =>
      MapSet.new(
        ~w(Type ExecStart ExecStartPre ExecStartPost ExecReload ExecStop ExecStopPost Restart RestartSec User Group WorkingDirectory Environment EnvironmentFile TimeoutStartSec TimeoutStopSec KillSignal KillMode RemainAfterExit PIDFile RuntimeDirectory StateDirectory CacheDirectory LogsDirectory StandardOutput StandardError)
      ),
    "Install" => MapSet.new(~w(WantedBy RequiredBy Also Alias DefaultInstance)),
    "Socket" =>
      MapSet.new(
        ~w(ListenStream ListenDatagram ListenSequentialPacket SocketUser SocketGroup SocketMode Accept Service)
      ),
    "Timer" =>
      MapSet.new(
        ~w(OnActiveSec OnBootSec OnStartupSec OnUnitActiveSec OnUnitInactiveSec OnCalendar Unit Persistent AccuracySec RandomizedDelaySec)
      ),
    "Target" => MapSet.new(~w(AllowIsolate)),
    "Mount" =>
      MapSet.new(
        ~w(What Where Type Options SloppyOptions LazyUnmount ForceUnmount DirectoryMode TimeoutSec)
      ),
    "Path" =>
      MapSet.new(
        ~w(PathExists PathExistsGlob PathChanged PathModified DirectoryNotEmpty Unit MakeDirectory DirectoryMode)
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
       when directive in ["TimeoutStartSec", "TimeoutStopSec", "RestartSec"] do
    duration("Service", directive, value, span)
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

  defp value_errors("Timer", "Persistent", value, span),
    do: boolean("Timer", "Persistent", value, span)

  defp value_errors("Timer", "OnCalendar", value, span),
    do: non_empty("Timer", "OnCalendar", value, span)

  defp value_errors("Socket", directive, value, span)
       when directive in ["ListenStream", "ListenDatagram", "ListenSequentialPacket"] do
    non_empty("Socket", directive, value, span)
  end

  defp value_errors("Socket", "SocketMode", value, span),
    do: octal_mode("Socket", "SocketMode", value, span)

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

  defp duration(_section, _directive, "infinity", _span), do: []

  defp duration(section, directive, value, span) do
    if String.match?(value, ~r/^\d+(\.\d+)?\s*(us|µs|ms|s|sec|m|min|h|hr|d|day|w|week)?$/) do
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

  defp octal_mode(section, directive, value, span) do
    if String.match?(value, ~r/^[0-7]{3,4}$/) do
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
