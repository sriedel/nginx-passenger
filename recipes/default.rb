#
# Cookbook Name:: nginx-passenger
# Recipe:: default
#
# Copyright 2010, Example Com
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include_recipe "build-essential"

nginx_tarfile = "/usr/src/nginx-#{node[:nginx][:version]}.tar.gz"
nginx_sbin = "#{node[:nginx][:prefix]}/sbin/nginx"
nginx_version_matches = ::File.exists?( nginx_sbin ) && system( "#{nginx_sbin} -v 2>&1 | grep -q 'nginx/#{node[:nginx][:version]}'" ) 
passenger_version_matches = ::File.exists?( nginx_sbin ) && system("#{nginx_sbin} -V 2>&1 | grep -q 'passenger-#{node[:passenger][:version]}'") 

%w{libssl-dev libstdc++6-4.4-dev libpcre3-dev}.each do |pkg|
  package pkg
end

gem_package "passenger" do
  gem_binary File.join( node[:passenger][:ruby_bin_path], "gem" )
  version node[:passenger][:version]
  not_if { passenger_version_matches }
end

remote_file nginx_tarfile do
  source node[:nginx][:url]
  not_if do
    ::File.exists?( nginx_tarfile ) && !::File.zero?( nginx_tarfile ) 
  end
end

bash "Compile nginx" do 
  cwd "/usr/src"
  code <<-EOH
    export PATH="#{node[:passenger][:ruby_bin_path]}:$PATH"
    tar xfz #{nginx_tarfile}
    cd nginx-#{node[:nginx][:version]}
    ./configure --with-http_ssl_module \
                --with-http_stub_status_module \
                --add-module=$(#{node[:passenger][:ruby_bin_path]}/passenger-config --root)/ext/nginx \
                --prefix=#{node[:nginx][:prefix]}-#{node[:nginx][:version]} \
                --pid-path=/var/run \
                --http-log-path=/var/log/nginx/access.log \
                --error-log-path=/var/log/nginx/error.log \
                --with-cpu-opt=#{node[:nginx][:cpu_optimization]}
    make
    make install
    rm "#{node[:nginx][:prefix]}-#{node[:nginx][:version]}/conf/nginx.conf"
  EOH
  not_if { passenger_version_matches && nginx_version_matches }
end

link "Symlink Nginx" do
  to "#{node[:nginx][:prefix]}-#{node[:nginx][:version]}"
  target_file node[:nginx][:prefix]
  not_if do
    ::File.symlink?( node[:nginx][:prefix] ) && 
    ::File.readlink( node[:nginx][:prefix] ) == "#{node[:nginx][:prefix]}-#{node[:nginx][:version]}"
  end
end

template "/etc/init.d/nginx" do
  owner "root"
  group "root"
  mode 0755
  source "start-stop-script.erb"
  variables :nginx => node[:nginx]
  not_if { ::File.exists?( "/etc/init.d/nginx" ) }
end

bash "Update init scripts" do
  code %{update-rc.d nginx defaults}
  not_if "test -e /etc/rc2.d/S??nginx"
end

template ::File.join( node[:nginx][:prefix], "conf", "nginx.conf" ) do
  owner "root"
  group "root"
  mode 0644
  source "nginx.conf.erb"
  node[:passenger][:root] = %x{#{node[:passenger][:ruby_bin_path]}/passenger-config --root}.chomp
  variables :nginx     => node[:nginx],
            :passenger => node[:passenger]
  not_if { ::File.exists?( "#{node[:nginx][:prefix]}/conf/nginx.conf" ) }
end

directory ::File.join( node[:nginx][:prefix], "conf", "vhosts" ) do
  owner 'root'
  group "root"
  mode 0755
  not_if "test -d #{node[:nginx][:prefix]}/conf/vhosts"
end

template ::File.join( node[:nginx][:prefix], "conf", "vhosts", "status.conf" ) do
  owner "root"
  group "root"
  mode 0644
  source "status.conf.erb"
  not_if { ::File.exists?( "#{node[:nginx][:prefix]}/conf/vhosts/status.conf" ) }
end
