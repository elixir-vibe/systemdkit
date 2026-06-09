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

  resource_unit = choice(Enum.map(~w(K M G T P E), &string/1))
  resource_quantity = digits |> optional(resource_unit) |> eos()

  positive_integer =
    ascii_string([?1..?9], min: 1) |> concat(repeat(ascii_string([?0..?9], 1))) |> eos()

  percentage = decimal |> ignore(string("%")) |> eos()
  octal_mode = ascii_string([?0..?7], min: 3, max: 4) |> eos()

  defparsecp(:parse_duration_value, duration)
  defparsecp(:parse_resource_quantity_value, resource_quantity)
  defparsecp(:parse_positive_integer_value, positive_integer)
  defparsecp(:parse_percentage_value, percentage)
  defparsecp(:parse_octal_mode_value, octal_mode)

  @doc false
  @spec duration?(String.t()) :: boolean()
  def duration?(value) when is_binary(value) do
    parse_duration_value(value) |> parse_ok?()
  end

  @doc false
  @spec resource_quantity?(String.t()) :: boolean()
  def resource_quantity?(value) when is_binary(value) do
    parse_resource_quantity_value(value) |> parse_ok?()
  end

  @doc false
  @spec positive_integer?(String.t()) :: boolean()
  def positive_integer?(value) when is_binary(value) do
    parse_positive_integer_value(value) |> parse_ok?()
  end

  @doc false
  @spec percentage?(String.t()) :: boolean()
  def percentage?(value) when is_binary(value) do
    parse_percentage_value(value) |> parse_ok?()
  end

  @doc false
  @spec octal_mode?(String.t()) :: boolean()
  def octal_mode?(value) when is_binary(value) do
    parse_octal_mode_value(value) |> parse_ok?()
  end

  defp parse_ok?({:ok, _tokens, "", _context, _line, _offset}), do: true
  defp parse_ok?(_other), do: false
end
