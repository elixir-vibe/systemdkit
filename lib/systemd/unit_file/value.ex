defmodule Systemd.UnitFile.Value do
  @moduledoc """
  Helpers for systemd directive values.

  The unit-file parser preserves directive values as raw strings. These helpers
  provide focused value-level parsing for callers that need shell-like words or
  simple quoted strings without baking value semantics into every directive.
  """

  @type word :: String.t()

  @doc """
  Splits a directive value into whitespace-separated words.

  Double and single quotes group whitespace. A backslash escapes the following
  character outside single quotes.
  """
  @spec words(String.t()) :: {:ok, [word()]} | {:error, term()}
  def words(value) when is_binary(value) do
    value
    |> String.to_charlist()
    |> do_words([], [], :bare)
  end

  defp do_words([], current, words, :bare) do
    {:ok, finish_words(current, words)}
  end

  defp do_words([], _current, _words, quote) when quote in [:single, :double] do
    {:error, {:unterminated_quote, quote}}
  end

  defp do_words([char | rest], current, words, :bare) when char in [?\s, ?\t] do
    do_words(rest, [], maybe_push_word(current, words), :bare)
  end

  defp do_words([?' | rest], current, words, :bare), do: do_words(rest, current, words, :single)
  defp do_words([?" | rest], current, words, :bare), do: do_words(rest, current, words, :double)

  defp do_words([?\\, char | rest], current, words, :bare),
    do: do_words(rest, [char | current], words, :bare)

  defp do_words([char | rest], current, words, :bare),
    do: do_words(rest, [char | current], words, :bare)

  defp do_words([?' | rest], current, words, :single), do: do_words(rest, current, words, :bare)

  defp do_words([char | rest], current, words, :single),
    do: do_words(rest, [char | current], words, :single)

  defp do_words([?" | rest], current, words, :double), do: do_words(rest, current, words, :bare)

  defp do_words([?\\, char | rest], current, words, :double),
    do: do_words(rest, [char | current], words, :double)

  defp do_words([char | rest], current, words, :double),
    do: do_words(rest, [char | current], words, :double)

  defp finish_words(current, words) do
    current
    |> maybe_push_word(words)
    |> Enum.reverse()
  end

  defp maybe_push_word([], words), do: words
  defp maybe_push_word(current, words), do: [current |> Enum.reverse() |> to_string() | words]
end
