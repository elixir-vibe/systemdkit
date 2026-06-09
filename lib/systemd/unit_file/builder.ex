defmodule Systemd.UnitFile.Builder do
  @moduledoc """
  Typed builders for common systemd unit file sections.
  """

  alias Systemd.UnitFile

  @type directives :: keyword() | %{optional(atom() | String.t()) => term()}

  @directive_names %{
    cpu_accounting: "CPUAccounting",
    cpu_quota: "CPUQuota",
    cpu_weight: "CPUWeight",
    io_accounting: "IOAccounting",
    io_weight: "IOWeight",
    ip_accounting: "IPAccounting",
    limit_as: "LimitAS",
    limit_core: "LimitCORE",
    limit_cpu: "LimitCPU",
    limit_data: "LimitDATA",
    limit_fsize: "LimitFSIZE",
    limit_locks: "LimitLOCKS",
    limit_memlock: "LimitMEMLOCK",
    limit_msgqueue: "LimitMSGQUEUE",
    limit_nice: "LimitNICE",
    limit_nofile: "LimitNOFILE",
    limit_nproc: "LimitNPROC",
    limit_rss: "LimitRSS",
    limit_rtprio: "LimitRTPRIO",
    limit_rttime: "LimitRTTIME",
    limit_sigpending: "LimitSIGPENDING",
    memory_accounting: "MemoryAccounting",
    memory_high: "MemoryHigh",
    memory_low: "MemoryLow",
    memory_max: "MemoryMax",
    memory_min: "MemoryMin",
    memory_swap_max: "MemorySwapMax",
    no_new_privileges: "NoNewPrivileges",
    oom_policy: "OOMPolicy",
    pid_file: "PIDFile",
    private_devices: "PrivateDevices",
    private_network: "PrivateNetwork",
    private_tmp: "PrivateTmp",
    private_users: "PrivateUsers",
    protect_clock: "ProtectClock",
    protect_control_groups: "ProtectControlGroups",
    protect_home: "ProtectHome",
    protect_hostname: "ProtectHostname",
    protect_kernel_logs: "ProtectKernelLogs",
    protect_kernel_modules: "ProtectKernelModules",
    protect_kernel_tunables: "ProtectKernelTunables",
    protect_proc: "ProtectProc",
    protect_system: "ProtectSystem",
    restrict_address_families: "RestrictAddressFamilies",
    restrict_namespaces: "RestrictNamespaces",
    restrict_realtime: "RestrictRealtime",
    restrict_suid_sgid: "RestrictSUIDSGID",
    runtime_directory_preserve: "RuntimeDirectoryPreserve",
    selinux_context: "SELinuxContext",
    system_call_architectures: "SystemCallArchitectures",
    system_call_error_number: "SystemCallErrorNumber",
    system_call_filter: "SystemCallFilter",
    tasks_accounting: "TasksAccounting",
    tasks_max: "TasksMax",
    smack_process_label: "SmackProcessLabel",
    syslog_identifier: "SyslogIdentifier",
    tty_path: "TTYPath",
    usb_function_descriptors: "USBFunctionDescriptors",
    usb_function_strings: "USBFunctionStrings"
  }

  @doc """
  Builds a unit file from common `Unit`, `Service`, and `Install` sections.
  """
  @spec service(keyword()) :: UnitFile.t()
  def service(opts) when is_list(opts) do
    UnitFile.parse!("")
    |> maybe_append_section("Unit", Keyword.get(opts, :unit, []))
    |> maybe_append_section("Service", Keyword.get(opts, :service, []))
    |> maybe_append_section("Install", Keyword.get(opts, :install, []))
  end

  @doc """
  Builds a socket unit file from common `Unit`, `Socket`, and `Install` sections.
  """
  @spec socket(keyword()) :: UnitFile.t()
  def socket(opts) when is_list(opts) do
    UnitFile.parse!("")
    |> maybe_append_section("Unit", Keyword.get(opts, :unit, []))
    |> maybe_append_section("Socket", Keyword.get(opts, :socket, []))
    |> maybe_append_section("Install", Keyword.get(opts, :install, []))
  end

  @doc """
  Builds a timer unit file from common `Unit`, `Timer`, and `Install` sections.
  """
  @spec timer(keyword()) :: UnitFile.t()
  def timer(opts) when is_list(opts) do
    UnitFile.parse!("")
    |> maybe_append_section("Unit", Keyword.get(opts, :unit, []))
    |> maybe_append_section("Timer", Keyword.get(opts, :timer, []))
    |> maybe_append_section("Install", Keyword.get(opts, :install, []))
  end

  @doc """
  Builds a mount unit file from common `Unit`, `Mount`, and `Install` sections.
  """
  @spec mount(keyword()) :: UnitFile.t()
  def mount(opts) when is_list(opts) do
    UnitFile.parse!("")
    |> maybe_append_section("Unit", Keyword.get(opts, :unit, []))
    |> maybe_append_section("Mount", Keyword.get(opts, :mount, []))
    |> maybe_append_section("Install", Keyword.get(opts, :install, []))
  end

  @doc """
  Builds a path unit file from common `Unit`, `Path`, and `Install` sections.
  """
  @spec path(keyword()) :: UnitFile.t()
  def path(opts) when is_list(opts) do
    UnitFile.parse!("")
    |> maybe_append_section("Unit", Keyword.get(opts, :unit, []))
    |> maybe_append_section("Path", Keyword.get(opts, :path, []))
    |> maybe_append_section("Install", Keyword.get(opts, :install, []))
  end

  @doc """
  Builds a target unit file from common `Unit`, `Target`, and `Install` sections.
  """
  @spec target(keyword()) :: UnitFile.t()
  def target(opts) when is_list(opts) do
    UnitFile.parse!("")
    |> maybe_append_section("Unit", Keyword.get(opts, :unit, []))
    |> maybe_append_section("Target", Keyword.get(opts, :target, []))
    |> maybe_append_section("Install", Keyword.get(opts, :install, []))
  end

  @doc """
  Builds a unit file with one section.
  """
  @spec section(String.t(), directives()) :: UnitFile.t()
  def section(name, directives) do
    UnitFile.parse!("")
    |> maybe_append_section(name, directives)
  end

  defp maybe_append_section(unit_file, _name, directives) when directives in [nil, [], %{}] do
    unit_file
  end

  defp maybe_append_section(unit_file, name, directives) do
    Enum.reduce(directives, unit_file, fn {directive, value}, unit_file ->
      append_directive(unit_file, name, normalize_name(directive), value)
    end)
  end

  defp append_directive(unit_file, section, name, values) when is_list(values) do
    Enum.reduce(values, unit_file, &UnitFile.append(&2, section, name, normalize_value(&1)))
  end

  defp append_directive(unit_file, section, name, value) do
    UnitFile.append(unit_file, section, name, normalize_value(value))
  end

  defp normalize_name(name) when is_atom(name) do
    Map.get_lazy(@directive_names, name, fn ->
      name
      |> Atom.to_string()
      |> Macro.camelize()
    end)
  end

  defp normalize_name(name) when is_binary(name), do: name
  defp normalize_value(value) when is_binary(value), do: value
  defp normalize_value(value), do: to_string(value)
end
