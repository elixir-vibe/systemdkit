defmodule Systemd.UnitFile.Parser do
  @moduledoc false

  import NimbleParsec

  alias Systemd.UnitFile
  alias Systemd.UnitFile.{Blank, Comment, Directive, Raw, Section}

  whitespace = repeat(choice([string(" "), string("\t")]))
  eol = choice([string("\r\n"), string("\n")])

  section_name = ascii_string([?A..?Z, ?a..?z, ?0..?9, ?., ?@, ?-, ?_], min: 1)
  directive_name = ascii_string([?A..?Z, ?a..?z, ?0..?9], min: 1)
  rest_of_line = utf8_string([not: ?\n], min: 0)

  blank =
    ignore(whitespace)
    |> ignore(eol)
    |> replace({:blank})

  comment =
    ignore(whitespace)
    |> choice([string("#"), string(";")])
    |> concat(rest_of_line)
    |> ignore(eol)
    |> post_traverse(:comment_line)

  section =
    ignore(whitespace)
    |> ignore(string("["))
    |> concat(section_name)
    |> ignore(string("]"))
    |> ignore(whitespace)
    |> ignore(eol)
    |> unwrap_and_tag(:section)

  directive =
    ignore(whitespace)
    |> concat(directive_name)
    |> ignore(whitespace)
    |> ignore(string("="))
    |> concat(rest_of_line)
    |> ignore(eol)
    |> post_traverse(:directive_line)

  raw =
    rest_of_line
    |> ignore(eol)
    |> unwrap_and_tag(:raw)

  line = choice([blank, comment, section, directive, raw])

  defparsecp(:document, repeat(line) |> eos())

  @spec parse(String.t()) :: {:ok, UnitFile.t()} | {:error, term()}
  def parse("") do
    {:ok, %UnitFile{entries: []}}
  end

  def parse(text) when is_binary(text) do
    case document(ensure_final_newline(text)) do
      {:ok, tokens, "", _context, _line, _offset} ->
        {:ok, %UnitFile{entries: tokens |> to_entries() |> fold_continuations()}}

      {:ok, _tokens, rest, _context, line, offset} ->
        {:error, {:unparsed, rest, line, offset}}

      {:error, reason, rest, _context, line, offset} ->
        {:error, {reason, rest, line, offset}}
    end
  end

  defp comment_line(rest, [text, marker], context, _line, _offset) do
    {rest, [{:comment, marker, trim_cr(text)}], context}
  end

  defp directive_line(rest, [value, name], context, _line, _offset) do
    {rest, [{:directive, name, trim_cr(value)}], context}
  end

  defp to_entries(tokens) do
    Enum.map(tokens, fn
      {:blank} -> %Blank{}
      {:comment, marker, text} -> %Comment{marker: marker, text: text}
      {:section, name} -> %Section{name: name}
      {:directive, name, value} -> %Directive{name: name, value: value}
      {:raw, content} -> %Raw{content: trim_cr(content)}
    end)
  end

  defp fold_continuations(entries) do
    entries
    |> Enum.reduce([], &fold_continuation/2)
    |> Enum.reverse()
  end

  defp fold_continuation(%Raw{content: content}, [%Directive{value: value} = directive | rest]) do
    if continued?(value) do
      [%{directive | value: join_continuation(value, content)} | rest]
    else
      [%Raw{content: content}, directive | rest]
    end
  end

  defp fold_continuation(entry, acc), do: [entry | acc]

  defp continued?(value), do: String.ends_with?(value, "\\")

  defp join_continuation(value, content) do
    value
    |> String.trim_trailing("\\")
    |> Kernel.<>(String.trim_leading(content))
  end

  defp ensure_final_newline(text) do
    if String.ends_with?(text, ["\n", "\r\n"]), do: text, else: text <> "\n"
  end

  defp trim_cr(value), do: String.trim_trailing(value, "\r")
end
