defmodule Systemd.JobStatusTest do
  use ExUnit.Case, async: true

  alias Systemd.JobStatus

  test "builds job status from D-Bus rows" do
    assert %JobStatus{
             id: 1,
             unit: "example.service",
             type: "start",
             state: "running",
             job_path: "/org/freedesktop/systemd1/job/1",
             unit_path: "/org/freedesktop/systemd1/unit/example_2eservice"
           } =
             JobStatus.from_dbus([
               1,
               "example.service",
               "start",
               "running",
               "/org/freedesktop/systemd1/job/1",
               "/org/freedesktop/systemd1/unit/example_2eservice"
             ])
  end
end
