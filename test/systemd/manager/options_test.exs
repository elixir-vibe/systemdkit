defmodule Systemd.Manager.OptionsTest do
  use ExUnit.Case, async: true

  alias Systemd.Manager.Options

  test "normalizes manager options" do
    assert %Options{
             bus: :session,
             mode: "fail",
             wait: false,
             timeout: 1_000,
             interval: 10,
             runtime: true,
             force: true
           } =
             Options.new(
               bus: :session,
               mode: "fail",
               wait: false,
               timeout: 1_000,
               interval: 10,
               runtime: true,
               force: true
             )
  end

  test "extracts await options" do
    assert Options.await_opts(%Options{timeout: 50, interval: 5}) == [timeout: 50, interval: 5]
  end
end
