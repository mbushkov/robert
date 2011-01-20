### Generic definitions for producing nagios configuration

var[:nagios,:conf,:dir] = lambda { "/opt/local/etc/nagios" }
var[:nagios,:objects,:dir] = lambda { var[:nagios,:conf,:dir] + "/objects/rob" }
var[:nagios,:rob,:command] = lambda { "rob2" }

# generic host/service options
var[:nagios,:check,:interval] = ->{ 1 }
var[:nagios,:attempts,:max] = ->{ 3 }
var[:nagios,:retry,:interval] = ->{ 0.5 }
var[:nagios,:notification,:interval] = ->{ 15 }
var[:nagios,:notification,:first_delay] = ->{ 0 }
var[:nagios,:contacts] = ->{ nil }
var[:nagios,:contact_groups] = ->{ nil }


defn nagios.command do
  var[:nagios,:rob,:command,:args] = -> { "$ARG1$ log,level=0" }
  body {
    str = <<__EOF
define command {
  command_name #{var[:nagios_name]}
  command_line #{var[:nagios,:rob,:command]} #{var[:act_name]} #{var[:nagios,:rob,:command,:args]}
}
__EOF
    has_next? ? call_next + str : str
  }
end

defn nagios.host do
  var[:nagios_command] = ->{ "check_ping" }
  var[:notification,:options] = ->{ [:down,:unreachable,:recovery,:flapping,:scheduled] } # :none option is also possible

  body {
    str = StringIO.new
    str.puts(<<__EOF)
define host {
  use generic-host

  host_name #{var[:host]}
  alias #{conf_name}
  address #{var[:host]}
  check_command #{var[:nagios_command]}!#{conf_name}

  max_check_attempts #{var[:check,:attempts,:max]}
  check_interval #{var[:check,:interval]}
  retry_interval #{var[:retry,:interval]}
  notification_interval #{var[:notification,:interval]}
  first_notification_delay #{var[:notification,:first_delay]}
  notification_options #{var[:notification,:options].map { |o| o.to_s[0] }.join(',') }
__EOF
    str.puts("contacts #{var[:contacts].join(',')}") if var?[:contacts]
    str.puts("contact_groups #{var[:contact_groups].join(',')}") if var?[:contact_groups]
    str.puts("}")
    has_next? ? call_next + str.string : str.string
  }
end

defn nagios.check do
  var[:notification,:options] = ->{ [:warning,:unknown,:critical,:recovery,:flapping,:scheduled] }

  body {
    str = StringIO.new
    str.puts(<<__EOF)
define service {
  use generic-service

  host_name #{var[:host]}
  service_description #{var[:service]}
  check_command #{var[:nagios_command]}!#{conf_name}

  max_check_attempts #{var[:check,:attempts,:max]}
  check_interval #{var[:check,:interval]}
  retry_interval #{var[:retry,:interval]}
  notification_interval #{var[:notification,:interval]}
  first_notification_delay #{var[:notification,:first_delay]}
  notification_options #{var[:notification,:options].map { |o| o.to_s[0] }.join(',') }
__EOF
    str.puts("contacts #{var[:contacts].join(',')}") if var?[:contacts]
    str.puts("contact_groups #{var[:contact_groups].join(',')}") if var?[:contact_groups]
    str.puts("}")
    has_next? ? call_next + str.string : str.string
  }
end

defn nagios.hostgroup do
  body {
    members = var[:members].respond_to?(:each) && !var[:members].respond_to?(:gsub) ? var[:members].join(",") : var[:members]
    str = <<__EOF
define hostgroup {
  hostgroup_name #{var[:name]}
  alias #{var[:alias]}
  members #{members}
}
__EOF
    has_next? ? call_next + str : str
  }
end

defn nagios.contact do
  var[:service_nagios_command] = var[:host_nagios_command] = ->{ var[:nagios_command] }
  var[:alias] = ->{ var[:name] }
  body {
    str = <<__EOF
define contact {
  use generic-contact

  contact_name #{var[:name]}
  alias #{var[:alias]}
  email #{var[:email]}

  service_notification_commands #{var?[:service_nagios_command] || var[:service_nagios_commands].join(',')}
  host_notification_commands #{var?[:host_nagios_command] || var[:host_nagios_commands].join(',')}
}
__EOF
    has_next? ? call_next + str : str
  }
end

### Helper configurations to bridge checks from Robert to Nagios

nagios_commands_mappings = Hash.new { |h,k| k }.merge({"cpu_load" => "check_local_load",
                                                        "ping" => "check_ping",
                                                        "http" => "check_http",
                                                        "ssh" => "check_ssh",
                                                        "disk_usage" => "check_local_disk" })

conf :nagios_host do
  act[:configure_nagios] = nagios.host
end

nagios_commands_mappings.each do |act_name,nagios_name|
  conf "nagios_#{act_name}_service" do
    act["check_#{act_name}"] = check.send(act_name, check.nagios_result { var(:category) { "rob_#{act_name}" } } )
    act[:configure_nagios] = nagios.check(act[:configure_nagios]) {
      var(:service) { act_name }
      var(:nagios_command) { nagios_name }
    }
  end
end

conf "nagios_apache_service" do
  act["check_apache"] = nsub(:check_apache,
                             check.procs(check.nagios_result { var(:category) { "rob_apache" } }) {
                               var[:regexp] = ->{ /httpd/ }
                               var[:warn,:count,:max] = -> { 768 }
                               var[:critical,:count,:max] = ->{ 1024 }
                             })
  act[:configure_nagios] = nagios.check(act[:configure_nagios]) {
    var(:service) { "apache" }
    var(:nagios_command) { "check_apache" }
  }
end
conf :nagios do
  act[:configure_nagios] = nagios.command(act[:configure_nagios]) { var(:nagios_name) { "check_apache" }; var(:act_name) { "check_apache" } }
end

conf :nagios do
  def configure
    require 'fileutils'

    FileUtils.rm_r(var[:nagios,:objects,:dir], :force => true, :secure => true)
    FileUtils.mkdir_p(var[:nagios,:objects,:dir])
    
    $top.select { with_name(:nagios) || with_method(:configure_nagios) && with_any_tag(:host,:application,:person) }.each do |conf|
      $top.logi "nagios-configuring: #{conf.conf_name}"
      open(var[:nagios,:objects,:dir] + "/#{conf.conf_name}.cfg", "w") { |f| f.write(conf.configure_nagios) }
    end
  end

  nagios_commands_mappings.each do |act_name,nagios_name|
    act[:configure_nagios] = nagios.command(act[:configure_nagios]) { var(:nagios_name) { nagios_name }; var(:act_name) { "check_#{act_name}" } }
  end

  act[:configure_nagios] = nagios.hostgroup(act[:configure_nagios]) { var(:name) { "all" }; var(:alias) { "All Servers/Sites" }; var(:members) { "*" } }
end

