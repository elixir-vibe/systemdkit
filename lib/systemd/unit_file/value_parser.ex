defmodule Systemd.UnitFile.ValueParser do
  @moduledoc false

  import NimbleParsec

  digits = ascii_string([?0..?9], min: 1)
  decimal = digits |> optional(ignore(string(".")) |> concat(digits))
  spacing = repeat(choice([string(" "), string("\t")]))

  duration_unit =
    choice([
      string("week"),
      string("day"),
      string("min"),
      string("sec"),
      string("hr"),
      string("us"),
      string("µs"),
      string("ms"),
      string("s"),
      string("m"),
      string("h"),
      string("d"),
      string("w")
    ])

  duration =
    choice([
      string("infinity"),
      decimal |> ignore(spacing) |> optional(duration_unit)
    ])
    |> eos()

  octal_mode = ascii_string([?0..?7], min: 3, max: 4) |> eos()

  defparsecp(:parse_duration_value, duration)
  defparsecp(:parse_octal_mode_value, octal_mode)

  @doc false
  @spec duration?(String.t()) :: boolean()
  def duration?(value) when is_binary(value) do
    parse_duration_value(value) |> parse_ok?()
  end

  @doc false
  @spec octal_mode?(String.t()) :: boolean()
  def octal_mode?(value) when is_binary(value) do
    parse_octal_mode_value(value) |> parse_ok?()
  end

  defp parse_ok?({:ok, _tokens, "", _context, _line, _offset}), do: true
  defp parse_ok?(_other), do: false
end
