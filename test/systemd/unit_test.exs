defmodule Systemd.UnitTest do
  use ExUnit.Case, async: true

  alias Systemd.Unit

  test "builds unit status from a ListUnits tuple" do
    row = {
      "ssh.service",
      "OpenBSD Secure Shell server",
      "loaded",
      "active",
      "running",
      "",
      "/org/freedesktop/systemd1/unit/ssh_2eservice",
      0,
      "",
      "/"
    }

    assert %Unit{
             name: "ssh.service",
             description: "OpenBSD Secure Shell server",
             load_state: "loaded",
             active_state: "active",
             sub_state: "running",
             followed: "",
             object_path: "/org/freedesktop/systemd1/unit/ssh_2eservice",
             job_id: 0,
             job_type: "",
             job_path: "/"
           } = Unit.from_list_units_row(row)
  end
end
