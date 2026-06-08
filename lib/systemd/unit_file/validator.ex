defmodule Systemd.UnitFile.Validator do
  @moduledoc false

  alias Systemd.UnitFile
  alias Systemd.UnitFile.{Directive, Section, ValidationError}

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

  @doc false
  @spec validate(UnitFile.t(), String.t() | atom() | nil) :: :ok | {:error, [ValidationError.t()]}
  def validate(%UnitFile{} = unit_file, type \\ nil) do
    errors =
      []
      |> collect_duplicate_section_errors(unit_file)
      |> collect_unknown_section_errors(unit_file, normalize_type(type))
      |> collect_missing_section_errors(unit_file, normalize_type(type))
      |> collect_directive_scope_errors(unit_file)

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
