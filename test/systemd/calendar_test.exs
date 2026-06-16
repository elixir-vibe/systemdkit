defmodule Systemd.CalendarTest do
  use ExUnit.Case, async: true

  alias Systemd.Calendar

  test "builds daily calendar expressions" do
    assert Calendar.daily_at("02:30") == "*-*-* 02:30:00"
    assert Calendar.daily_at("02:30:15") == "*-*-* 02:30:15"
    assert Calendar.daily_at(~T[02:30:00]) == "*-*-* 02:30:00"
  end

  test "builds weekly calendar expressions" do
    assert Calendar.weekly_at(:monday, "02:30") == "Mon *-*-* 02:30:00"
    assert Calendar.weekly_at("sun", ~T[03:15:00]) == "Sun *-*-* 03:15:00"
  end

  test "builds monthly calendar expressions" do
    assert Calendar.monthly_at(1, "02:30") == "*-*-01 02:30:00"
    assert Calendar.monthly_at(31, ~T[23:59:59]) == "*-*-31 23:59:59"
  end

  test "rejects invalid values" do
    assert_raise ArgumentError, ~r/expected timer time/, fn -> Calendar.daily_at("2:30") end
    assert_raise ArgumentError, ~r/unknown weekday/, fn -> Calendar.weekly_at(:noday, "02:30") end
    assert_raise ArgumentError, ~r/monthly timer day/, fn -> Calendar.monthly_at(0, "02:30") end
  end
end
