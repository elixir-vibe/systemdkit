defmodule Systemd.UnitFile.Parser do
  @moduledoc false

  import NimbleParsec

  alias Systemd.UnitFile
  alias Systemd.UnitFile.{Blank, Comment, Directive, ParseError, Raw, Section, Span}

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
    utf8_string([?\s, ?\t], min: 1)
    |> concat(rest_of_line)
    |> ignore(eol)
    |> post_traverse(:raw_line)

  line = choice([blank, comment, section, directive, raw])

  defparsecp(:document, repeat(line) |> eos())

  @spec parse(String.t()) :: {:ok, UnitFile.t()} | {:error, ParseError.t()}
  def parse("") do
    {:ok, %UnitFile{entries: []}}
  end

  def parse(text) when is_binary(text) do
    input = ensure_final_newline(text)

    case document(input) do
      {:ok, tokens, "", _context, _line, _offset} ->
        entries =
          tokens
          |> to_entries(source_lines(input))
          |> fold_continuations()

        {:ok, %UnitFile{entries: entries}}

      {:ok, _tokens, rest, _context, line, offset} ->
        {:error, parse_error(:unparsed_input, rest, line, offset)}

      {:error, reason, rest, _context, line, offset} ->
        {:error, parse_error(reason, rest, line, offset)}
    end
  end

  defp comment_line(rest, [text, marker], context, _line, _offset) do
    {rest, [{:comment, marker, trim_cr(text)}], context}
  end

  defp directive_line(rest, [value, name], context, _line, _offset) do
    {rest, [{:directive, name, trim_cr(value)}], context}
  end

  defp raw_line(rest, [content, whitespace], context, _line, _offset) do
    {rest, [{:raw, whitespace <> trim_cr(content)}], context}
  end

  defp to_entries(tokens, lines) do
    tokens
    |> Enum.zip(lines)
    |> Enum.with_index(1)
    |> Enum.map(fn {{token, line}, line_number} ->
      span = %Span{line: line_number, column: column_for(token, line)}

      case token do
        {:blank} -> %Blank{span: span}
        {:comment, marker, text} -> %Comment{marker: marker, text: text, span: span}
        {:section, name} -> %Section{name: name, span: span}
        {:directive, name, value} -> %Directive{name: name, value: value, span: span}
        {:raw, content} -> %Raw{content: trim_cr(content), span: span}
      end
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

  defp parse_error(reason, rest, {line, column}, _offset) do
    %ParseError{reason: reason, rest: rest, line: line, column: column}
  end

  defp source_lines(input) do
    input
    |> String.split("\n")
    |> Enum.drop(-1)
  end

  defp column_for({:blank}, line), do: first_non_whitespace_column(line)
  defp column_for({:comment, marker, _text}, line), do: find_column(line, marker)
  defp column_for({:section, _name}, line), do: find_column(line, "[")
  defp column_for({:directive, name, _value}, line), do: find_column(line, name)
  defp column_for({:raw, _content}, line), do: first_non_whitespace_column(line)

  defp find_column(line, needle) do
    case :binary.match(line, needle) do
      {index, _length} -> index + 1
      :nomatch -> 1
    end
  end

  defp first_non_whitespace_column(line) do
    line
    |> :binary.bin_to_list()
    |> Enum.with_index(1)
    |> Enum.find_value(1, fn
      {char, column} when char not in [?\s, ?\t] -> column
      _whitespace -> false
    end)
  end

  defp ensure_final_newline(text) do
    if String.ends_with?(text, ["\n", "\r\n"]), do: text, else: text <> "\n"
  end

  defp trim_cr(value), do: String.trim_trailing(value, "\r")
end
