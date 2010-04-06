remote_file "/etc/bluepill/webserver.pill" do
  source "webserver.pill"
  owner "root"
  group "root"
  mode 0644
end
