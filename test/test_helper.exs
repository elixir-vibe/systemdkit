ExUnit.start()

unless System.get_env("SYSTEMD_INTEGRATION") == "1" do
  ExUnit.configure(exclude: [integration: true])
end
