munin_node_config_path = "/etc/munin/plugin-conf.d"
munin_node_config_file = File.join munin_node_config_path, "nginx-node"

package "munin"

template munin_node_config_file do
  source "nginx-node.erb"
  variables :ruby => File.join( node[:passenger][:ruby_bin_path], "ruby" )
  owner "root"
  group "root"
  mode 0644
  not_if do
    ::File.exists?( munin_node_config_file ) ||
    !::File.exists?( munin_node_config_path )
  end
end

munin_global_plugin_path = "/usr/share/munin/plugins"
munin_active_plugin_path = "/etc/munin/plugins"

install_plugins = %w{nginx_memory passenger_status passenger_memory_stats}
active_plugins = install_plugins + %w{ nginx_status nginx_request }

install_plugins.each do |plugin|
  remote_file File.join( munin_global_plugin_path, plugin ) do
    source plugin
    owner "root"
    group "root"
    mode 0755
    not_if "test -e #{File.join munin_global_plugin_path, plugin}"
  end
end

active_plugins.each do |plugin|
  link File.join( munin_active_plugin_path, plugin ) do
    to File.join( munin_global_plugin_path, plugin )
  end
end

