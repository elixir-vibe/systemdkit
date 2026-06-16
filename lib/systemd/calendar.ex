defmodule Systemd.Calendar do
  @moduledoc "Helpers for building systemd calendar expressions."

  @weekdays %{
    monday: "Mon",
    mon: "Mon",
    tuesday: "Tue",
    tue: "Tue",
    wednesday: "Wed",
    wed: "Wed",
    thursday: "Thu",
    thu: "Thu",
    friday: "Fri",
    fri: "Fri",
    saturday: "Sat",
    sat: "Sat",
    sunday: "Sun",
    sun: "Sun"
  }

  @doc "Builds a daily calendar expression at a time of day."
  @spec daily_at(String.t() | Time.t()) :: String.t()
  def daily_at(time), do: "*-*-* #{time!(time)}"

  @doc "Builds a weekly calendar expression for a weekday and time of day."
  @spec weekly_at(atom() | String.t(), String.t() | Time.t()) :: String.t()
  def weekly_at(day, time), do: "#{weekday!(day)} *-*-* #{time!(time)}"

  @doc "Builds a monthly calendar expression for a day of month and time of day."
  @spec monthly_at(pos_integer(), String.t() | Time.t()) :: String.t()
  def monthly_at(day, time) when is_integer(day) and day in 1..31 do
    "*-*-#{String.pad_leading(to_string(day), 2, "0")} #{time!(time)}"
  end

  def monthly_at(day, _time) do
    raise ArgumentError, "monthly timer day must be an integer from 1 to 31, got: #{inspect(day)}"
  end

  defp time!(%Time{} = time) do
    time
    |> Time.truncate(:second)
    |> Time.to_iso8601()
  end

  defp time!(value) when is_binary(value) do
    value
    |> normalize_time_string()
    |> Time.from_iso8601()
    |> case do
      {:ok, time} ->
        time!(time)

      {:error, _reason} ->
        raise ArgumentError,
              "expected timer time as HH:MM or HH:MM:SS, got: #{inspect(value)}"
    end
  end

  defp time!(value) do
    raise ArgumentError, "expected timer time as HH:MM, HH:MM:SS, or Time, got: #{inspect(value)}"
  end

  defp normalize_time_string(<<_h1, _h2, ?:, _m1, _m2>> = time), do: time <> ":00"
  defp normalize_time_string(time), do: time

  defp weekday!(day) when is_atom(day) do
    case Map.fetch(@weekdays, day) do
      {:ok, weekday} -> weekday
      :error -> raise ArgumentError, "unknown weekday #{inspect(day)}"
    end
  end

  defp weekday!(day) when is_binary(day) do
    weekday = String.downcase(day)

    @weekdays
    |> Enum.find_value(fn {key, value} -> if Atom.to_string(key) == weekday, do: value end)
    |> case do
      nil -> raise ArgumentError, "unknown weekday #{inspect(day)}"
      value -> value
    end
  end
end
