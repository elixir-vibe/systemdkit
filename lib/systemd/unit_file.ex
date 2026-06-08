defmodule Systemd.UnitFile do
  @moduledoc """
  Loss-aware representation of a systemd unit file.

  Unit files preserve ordering and duplicate directives. They are intentionally
  not represented as maps because repeated directives and reset directives such
  as `ExecStart=` are meaningful in systemd syntax.
  """

  alias Systemd.UnitFile.{Blank, Builder, Comment, Directive, Parser, Raw, Section}

  @type entry :: Blank.t() | Comment.t() | Directive.t() | Raw.t() | Section.t()
  @type t :: %__MODULE__{entries: [entry()]}

  defstruct entries: []

  @doc """
  Builds a service unit file from common `Unit`, `Service`, and `Install` sections.
  """
  @spec service(keyword()) :: t()
  defdelegate service(opts), to: Builder

  @doc """
  Parses unit file text.
  """
  @spec parse(String.t()) :: {:ok, t()} | {:error, term()}
  defdelegate parse(text), to: Parser

  @doc """
  Parses unit file text, raising on failure.
  """
  @spec parse!(String.t()) :: t()
  def parse!(text) do
    case parse(text) do
      {:ok, unit_file} -> unit_file
      {:error, reason} -> raise ArgumentError, "invalid unit file: #{inspect(reason)}"
    end
  end

  @doc """
  Renders a unit file.
  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{entries: entries}) do
    entries
    |> Enum.map(&entry_to_iodata/1)
    |> IO.iodata_to_binary()
  end

  @doc """
  Returns all directive values matching a section and directive name.
  """
  @spec get_all(t(), String.t(), String.t()) :: [String.t()]
  def get_all(%__MODULE__{} = unit_file, section, name) do
    unit_file.entries
    |> entries_with_sections()
    |> Enum.flat_map(fn
      {^section, %Directive{name: ^name, value: value}} -> [value]
      _entry -> []
    end)
  end

  @doc """
  Appends a directive to the last matching section, creating the section if needed.
  """
  @spec append(t(), String.t(), String.t(), String.t()) :: t()
  def append(%__MODULE__{entries: entries} = unit_file, section, name, value) do
    directive = %Directive{name: name, value: value}

    entries =
      if section?(entries, section) do
        append_to_last_section(entries, section, directive)
      else
        entries ++ [%Section{name: section}, directive]
      end

    %{unit_file | entries: entries}
  end

  @doc """
  Replaces all matching directives in a section with a single directive.
  """
  @spec put(t(), String.t(), String.t(), String.t()) :: t()
  def put(%__MODULE__{} = unit_file, section, name, value) do
    unit_file
    |> delete(section, name)
    |> append(section, name, value)
  end

  @doc """
  Deletes matching directives from a section.
  """
  @spec delete(t(), String.t(), String.t()) :: t()
  def delete(%__MODULE__{entries: entries} = unit_file, section, name) do
    {entries, _current_section} =
      Enum.reduce(entries, {[], nil}, fn
        %Section{name: section_name} = entry, {acc, _current_section} ->
          {[entry | acc], section_name}

        %Directive{name: ^name}, {acc, ^section} ->
          {acc, section}

        entry, {acc, current_section} ->
          {[entry | acc], current_section}
      end)

    %{unit_file | entries: Enum.reverse(entries)}
  end

  defp entry_to_iodata(%Blank{}), do: "\n"
  defp entry_to_iodata(%Comment{marker: marker, text: text}), do: [marker, text, "\n"]
  defp entry_to_iodata(%Section{name: name}), do: ["[", name, "]\n"]
  defp entry_to_iodata(%Directive{name: name, value: value}), do: [name, "=", value, "\n"]
  defp entry_to_iodata(%Raw{content: content}), do: [content, "\n"]

  defp entries_with_sections(entries) do
    {_section, entries} =
      Enum.reduce(entries, {nil, []}, fn
        %Section{name: section}, {_current_section, acc} ->
          {section, acc}

        entry, {section, acc} ->
          {section, [{section, entry} | acc]}
      end)

    Enum.reverse(entries)
  end

  defp section?(entries, section) do
    Enum.any?(entries, &match?(%Section{name: ^section}, &1))
  end

  defp append_to_last_section(entries, section, directive) do
    {entries, _in_section, inserted} =
      Enum.reduce(entries, {[], false, false}, fn
        %Section{name: ^section} = entry, {acc, _in_section, inserted} ->
          {[entry | acc], true, inserted}

        %Section{} = entry, {acc, true, false} ->
          {[entry, directive | acc], false, true}

        entry, {acc, in_section, inserted} ->
          {[entry | acc], in_section, inserted}
      end)

    entries = if inserted, do: entries, else: [directive | entries]
    Enum.reverse(entries)
  end
end
