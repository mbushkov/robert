class CheckError < StandardError
end

class WarningCheckError < CheckError
end

class CriticalCheckError < CheckError
end

defn check.raise_on_condition do
  body { |status, descr, pdata|
    if status == var[:status]
      case status
        when :warn then raise WarningCheckError, data.to_s
        when :critical then raise CriticalCheckError, data.to_s
      end
    end
  }
end

defn check.nagios_result do
  body { |status, descr, pdata|
    $stdout.write("#{var[:category]} #{status.to_s.upcase}")
    $stdout.write(" - #{descr}") if descr
    $stdout.write("|" + pdata.map do |k,v|
                    pstr = "#{k}=#{v[:value]}#{v[:type] || ''};#{v[:warn]};#{v[:critical]}"
                    if v[:type] != :%
                      pstr += ";#{v[:min]}" if v[:min]
                      pstr += ";#{v[:max]}" if v[:max]
                    end
                    pstr
                  end.join(" ")) if pdata
    $stdout.puts
    $stdout.flush
                 
    exit_codes = { :ok => 0, :warn => 1, :critical => 2 }
    exit(exit_codes[status])
  }
end

defn check.ssh do
  body {
    var[:role] = lambda { :host }
    begin
      start_time = Time.now
      run "id"
      duration = Time.now - start_time
      call_next(:ok, "duration: #{duration}s",
                {:time =>
                  { :value => duration,
                    :type => :s }})
    rescue => e
      call_next(:critical, e, nil)
    end
  }
end

conf :Songsterr do
  act[:check] = check.cpu_load
end

# To learn how to set appropriate threshold values, see:
# http://hissohathair.blogspot.com/2008/07/tuning-nagios-load-checks.html
defn check.cpu_load do
  var[:cmd] = lambda { "uptime" }
  var[:regexp] = lambda { /load averages?: (\d+[,\.]\d+),? (\d+[,\.]\d+),? (\d+[,\.]\d+)/ }
  var[:warn,:load] = lambda { [6, 3, 3] }
  var[:critical,:load] = lambda { [14, 8, 8] }
  var[:num_cpus] = lambda { 1 }

  body {
    var[:role] = lambda { :host }
    uptime_str = capture(var[:cmd])
    if uptime_str =~ var[:regexp]
      load_avg =  [$1.to_f, $2.to_f, $3.to_f].map { |f| f / var[:num_cpus] }

      state = :ok
      state = :warn if load_avg.zip(var[:warn,:load]).any? { |v1,v2| v1 > v2 }
      state = :critical if load_avg.zip(var[:critical,:load]).any? { |v1,v2| v1 > v2 }

      perf_data = {:load1 => {:value => load_avg[0],
        :warn => var[:warn,:load][0],
        :critical => var[:critical,:load][0]
        },
        :load5 => {:value => load_avg[1],
          :warn => var[:warn,:load][1],
          :critical => var[:critical,:load][1]
        },
        :load15 => {:value => load_avg[2],
          :warn => var[:warn,:load][2],
          :critical => var[:critical,:load][2]
        }
    }

      call_next(state, load_avg, perf_data)
    else
      raise "invalid uptime format"
    end
  }

  spec {
    it "raises exception when uptime output can't be parsed" do
      @action.should_receive(:capture).with(String).and_return("invalid output")
      lambda { @action.call }.should raise_exception(RuntimeError)
    end

    it "returns ok status if load is below warning level" do
      @action.should_receive(:capture).with(String).and_return("load averages: 0.00 0.00 0.00")
      @action.should_receive(:call_next).with(:ok, Array, Hash).once

      @action.call
    end

    it "return warn status if load is above warning level and lower than critical" do
      @action.should_receive(:capture).with(String).and_return("load averages: 8.00 2.00 2.00")
      @action.should_receive(:call_next).with(:warn, Array, Hash).once

      @action.call
    end

    it "return critical status if 5min-load is above critical level" do
      @action.should_receive(:capture).with(String).and_return("load averages: 4.00 12.00 4.00")
      @action.should_receive(:call_next).with(:critical, Array, Hash).once

      @action.call
    end

    it "divides command output on number of cpus specified" do
      @action.var(:num_cpus) { 2 }
      @action.should_receive(:capture).and_return("load averages: 4.00 4.00 4.00")
      @action.should_receive(:call_next).with(Symbol, [2.0, 2.0, 2.0], Hash).once

      @action.call
    end
  }
end

defn check.http do
  var[:warn,:response,:time] = lambda { 10 }
  var[:critical,:response,:time] = lambda { 60 }
  var[:redirect,:limit] = lambda { 10 }

  body {
    require 'net/https'
    require 'net/http'
    require 'uri'
    
    class CheckHttpError < RuntimeError
      attr_reader :http_response

      def initialize(msg, http_response)
        super(msg)
        @http_response = http_response
      end
    end

    start_time = Time.now
    notify = lambda do |level, http = nil|
      if level == :ok
        level = :warn if time_diff > var[:warn,:response,:time]
        level = :critical if time_diff > var[:critical,:response,:time]
      end
      call_next(level, time_diff)
    end
    
    fetch = lambda do |uri, limit|
      http = Net::HTTP.new(uri.host, uri.port)
      if uri.scheme == "https"
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end      
      http.start do |http|
        http.open_timeout = http.read_timeout = var[:critical,:response,:time]
        response = http.request_get(uri.path.empty? ? "/" : uri.path)
        case response
        when Net::HTTPSuccess
          response
        when Net::HTTPRedirection
          if limit - 1 > 0
            fetch.call(URI.parse(response['location']), limit - 1)
          else
            raise CheckHttpError.new("HTTP redirection too deep", response)
          end
        else
          raise CheckHttpError.new("unexpected HTTP response: #{response}", response)
        end
      end
    end

    make_perf_data = lambda do |http|
      time_diff = Time.now - start_time
      {:time => {
          :value => time_diff,
          :type => :s,
          :warn => var[:warn,:response,:time],
          :critical => var[:critical,:response,:time] },
        :size => {
          :value => http.body.size,
          :type => :b}}
    end

    begin
      begin
        http_response = fetch.call(URI.parse(var[:uri]), var[:redirect,:limit])
      ensure
        time_diff = Time.now - start_time
      end
      
      if http_response.body.size < 42
        level = :critical
      else
        level = :ok
        level = :warn if time_diff > var[:warn,:response,:time]
        level = :critical if time_diff > var[:critical,:response,:time]
      end
      call_next(level, http_response, make_perf_data.call(http_response))
    rescue CheckHttpError => e
      call_next(:critical, e, make_perf_data.call(e.http_response))
    end
  }

  spec {
    before do
      @action.var(:uri) { "http://test.com" }
      @http = flexmock
      @http.should_receive(:start).and_yield(@http)
      @http.should_ignore_missing
      flexmock(Net::HTTP).should_receive(:new).and_return(@http)
    end

    it "should return critical status when HTTP status is not success or redirection" do
      @http.should_receive(:request_get).and_return(flexmock(Net::HTTPNotFound.new(nil, nil, nil), :body => "*" * 43))

      @action.should_receive(:call_next).with(:critical, Object, Hash).once
      
      @action.call
    end

    it "should return ok status when HTTP status is success" do
      @http.should_receive(:request_get).and_return(flexmock(Net::HTTPSuccess.new(nil, nil, nil), :body => "*" * 43))

      @action.should_receive(:call_next).with(:ok, Object, Hash).once

      @action.call
    end

    it "should return ok after redirect and successful HTTP request" do
      @http.should_receive(:request_get).and_return(flexmock(Net::HTTPRedirection.new(nil, nil, nil), :[] => "http://test2.com", :body => "*" * 43)).once
      @http.should_receive(:request_get).and_return(flexmock(Net::HTTPSuccess.new(nil, nil, nil), :body => "*" * 43))

      @action.should_receive(:call_next).with(:ok, Object, Hash).once

      @action.call
    end

    it "should return critical when redirection limit is reached" do
      @http.should_receive(:request_get).and_return(flexmock(Net::HTTPRedirection.new(nil, nil, nil), :[] => "http://test2.com", :body => "*" * 43))

      @action.should_receive(:call_next).with(:critical, Object, Hash).once

      @action.call
    end
                                                    
  }
end

defn check.ping do
  var[:warn,:time] = lambda { 1000 }
  var[:critical,:time] = lambda { 3000 }
  var[:warn,:loss] = lambda { 0.1 }
  var[:critical,:loss] = lambda { 0.3 }

  body {
    ping_output = syscmd_output("ping -c 10 #{var[:host]}")
    ping_data = {}
    ping_output.lines.each do |l|
      # Regexps mostly borrowed from sscanfs in Nagios check_ping plugin
      if [/\d+ packets transmitted, \d+ packets received, \+\d+ errors, (.+?)% packet loss/,
          /\d+ packets transmitted, \d+ packets received, +\d+ duplicates, (.+?)% packet loss/,
          /\d+ packets transmitted, \d+ received, \+\d+ duplicates, (.+?)% packet loss/,
          /\d+ packets transmitted, \d+ packets received, (.+?)% packet loss/,
          /\d+ packets transmitted, \d+ packets received, (.+?)% loss, time/,
          /\d+ packets transmitted, \d+ received, (.+?)% loss, time/,
          /\d+ packets transmitted, \d+ received, (.+?)% packet loss, time/,
          /\d+ packets transmitted, \d+ received, +\d+ errors, (.+?)% packet loss/,
          /\d+ packets transmitted \d+ received, +\d+ errors, (.+?)% packet loss/].find { |r| r =~ l }
        ping_data[:loss] = $1.to_f / 100
      end
      if [%r{round-trip min/avg/max = .+?/(.+?)/.+?},
          %r{round-trip min/avg/max/(?:mdev|sdev|stddev) = .+?/(.+?)/.+?/.+?},
          %r{round-trip (ms) min/avg/max = .+?/(.+?)/.+?},
          %r{round-trip (ms) min/avg/max/stddev = .+?/(.+?)/.+?/.+?},
          %r{rtt min/avg/max/mdev = .+?/(.+?)/.+?/.+? ms}].find { |r| r =~ l }
          ping_data[:rtrip_avg] = $1.to_f
      end
    end

    perf_data = {:rta => {:value => ping_data[:rtrip_avg],
        :type => :ms,
        :warn => var[:warn,:time],
        :critical => var[:critical,:time]
      },
      :pl => { :value => ping_data[:loss],
        :type => :%,
        :warn => var[:warn,:loss],
        :critical => var[:critical,:loss]
      }
    }
    if ping_data[:loss].nil? || ping_data[:rtrip_avg].nil?
      call_next(:critical, nil, nil)
    elsif ping_data[:loss] >= var[:critical,:loss] || ping_data[:rtrip_avg] >= var[:critical,:time]
      call_next(:critical, ping_data, perf_data)
    elsif ping_data[:loss] >= var[:warn,:loss] || ping_data[:rtrip_avg] >= var[:warn,:time]
      call_next(:warn, ping_data, perf_data)
    else
      call_next(:ok, ping_data, perf_data)
    end
  }

  spec {
    before do
      @action.var(:host) { "idontknowyou.com" }
    end
    
    it "returns critical condition on unexpected ping output" do
      @action.should_receive(:syscmd_output).and_return(<<__EOF)
ping: cannot resolve idontknowyou.com: Unknown host
__EOF

      @action.should_receive(:call_next).with(:critical, nil, nil).once

      @action.call
    end

    it "returns ok when no conditions are exceeded" do
      @action.should_receive(:syscmd_output).and_return(<<__EOF)
--- idontknowyou.com ping statistics ---
10 packets transmitted, 10 packets received, 0.0% packet loss
round-trip min/avg/max/stddev = 64.564/88.716/229.016/50.286 ms
__EOF

      @action.should_receive(:call_next).with(:ok, Hash, Hash).once

      @action.call
    end

    it "returns critical condition when loss is above critical level" do
      @action.should_receive(:syscmd_output).and_return(<<__EOF)
--- idontknowyou.com ping statistics ---
10 packets transmitted, 7 packets received, 30% packet loss
round-trip min/avg/max/stddev = 64.564/88.716/229.016/50.286 ms
__EOF

      @action.should_receive(:call_next).with(:critical, Hash, Hash).once

      @action.call
    end

    it "returns critical condition when time is above critical level" do
      @action.should_receive(:syscmd_output).and_return(<<__EOF)
--- idontknowyou.com ping statistics ---
10 packets transmitted, 10 packets received, 0.0% packet loss
round-trip min/avg/max/stddev = 3000.564/3000.716/3000.016/1000.286 ms
__EOF

      @action.should_receive(:call_next).with(:critical, Hash, Hash).once

      @action.call
    end

    it "return warn condition when loss is above warn level and below critical" do
      @action.should_receive(:syscmd_output).and_return(<<__EOF)
--- idontknowyou.com ping statistics ---
10 packets transmitted, 9 packets received, 10% packet loss
round-trip min/avg/max/stddev = 64.564/88.716/229.016/50.286 ms
__EOF

      @action.should_receive(:call_next).with(:warn, Hash, Hash).once

      @action.call
    end

    it "returns warn condition when time is above warn level and below critical" do
      @action.should_receive(:syscmd_output).and_return(<<__EOF)
--- idontknowyou.com ping statistics ---
10 packets transmitted, 10 packets received, 0.0% packet loss
round-trip min/avg/max/stddev = 1064.564/1088.716/1229.016/150.286 ms
__EOF


      @action.should_receive(:call_next).with(:warn, Hash, Hash).once

      @action.call
    end
  }
end

defn check.disk_usage do
  var[:warn,:capacity] = ->{ 0.95 }
  var[:critical,:capacity] = -> { 0.99 } 
  var[:cmd] = lambda { "df -l" }
  var[:fs_regexp] = lambda { %r{^/$} }

  body {
    var[:role] = lambda { :host }

    sel_fs = capture(var[:cmd]).split($/)[1..-1].map do |l|
      tokens = l.split(/\s+/)
      { :used => tokens[-4].to_i, :avail => tokens[-3].to_i, :mount_point => tokens[-1] }
    end.map do |fs|
      total = (fs[:used] + fs[:avail])
      fs.merge({ :total => total, :percent => fs[:used].to_f / total })
    end.select { |fs| fs[:mount_point] =~ var[:fs_regexp] }

    raise "can't find any filesystem" if sel_fs.empty?
    
    fs_warn = sel_fs.select { |fs| fs[:percent] > var[:warn,:capacity] }
    fs_crit = sel_fs.select { |fs| fs[:percent] > var[:critical,:capacity] }
    
    perf_data = sel_fs.map do |fs|
      {
        fs[:mount_point] => {:value => fs[:percent],
          :type => :%,
          :warn => var[:warn,:capacity],
          :critical => var[:critical,:capacity]
        }
      }
    end.inject(:merge)

    call_next((fs_warn.empty? && fs_crit.empty?) ? :ok : (fs_crit.empty? ? :warn : :critical), sel_fs, perf_data)
  }

  spec {
    it "does nothing when 1 of 1 filesystems has safe usage level" do
      @action.should_receive(:capture).with(String).and_return(<<-__EOF)
Filesystem   512-blocks      Used Available Capacity  Mounted on
/dev/disk0s2  233769824 204758136  28499688    88%    /
__EOF
      @action.should_receive(:call_next).with(:ok, Array, Hash).once

      @action.call
    end

    it "returns critical condition when 1 of 1 filesystems has critical usage level" do
      @action.should_receive(:capture).with(String).and_return(<<-__EOF)
Filesystem   512-blocks      Used Available Capacity  Mounted on
/dev/disk1s2  624470624 619463272   5007352   100%    /
__EOF
      @action.should_receive(:call_next).with(:critical, Array, Hash).once

      @action.call
    end

    it "returns critical condition when 1 of 2 filesystems has dangerous usage level" do
      @action.should_receive(:capture).with(String).and_return(<<-__EOF)
Filesystem   512-blocks      Used Available Capacity  Mounted on
/dev/disk0s2  233769824 204758136  28499688    88%    /Volumes/WD Passport
/dev/disk1s2  624470624 619463272   5007352   100%    /
__EOF
      @action.should_receive(:call_next).with(:critical, Array, Hash).once

      @action.call
    end
  }
end

defn check.procs do
  var[:critical,:count,:min] = ->{ 0 }
  var[:critical,:count,:max] = ->{ nil }
  var[:warn,:count,:min] = -> { nil }
  var[:warn,:count,:max] = -> { nil }
  var[:cmd] = "ps -axwo 'stat uid pid ppid vsz rss pcpu ucomm command'"

  body {
    var[:role] = ->{ :host }

    sel_procs = capture(var[:cmd]).split($/)[1..-1].select { |l| l =~ var[:regexp] }
    perf_data = {:count =>
      { :value => sel_procs.size,
        :min => 0 }}
    descr = "#{sel_procs.size} processes"
    
    if var[:critical,:count,:min] && sel_procs.size <= var[:critical,:count,:min] ||
        var[:critical,:count,:max] && sel_procs.size >= var[:critical,:count,:max]
      call_next(:critical, descr, perf_data)
    elsif var[:warn,:count,:min] && sel_procs.size <= var[:warn,:count,:min] ||
        var[:warn,:count,:max] && sel_procs.size >= var[:warn,:count,:max]
      call_next(:warn, descr, perf_data)
    else
      call_next(:ok, descr, perf_data)
    end
  }

  spec {
    before do
      @action.var(:regexp) { /apache2/ }
    end
    
    it "does nothing when 1 process is active" do
      @action.should_receive(:capture).with(String).and_return(<<-__EOF)
STAT   UID   PID  PPID    VSZ   RSS %CPU COMMAND         COMMAND
S       33  3281 16515  20860  4664  0.0 apache2         /usr/sbin/apache2 -k start
__EOF
      @action.should_receive(:call_next).with(:ok, String, Hash).once
      
      @action.call
    end

    it "signals critical condition when 0 processes are found" do
      @action.should_receive(:capture).with(String).and_return(<<-__EOF)
STAT   UID   PID  PPID    VSZ   RSS %CPU COMMAND         COMMAND
__EOF
      @action.should_receive(:call_next).with(:critical, String, Hash).once
      
      @action.call
    end

    it "signals critical condition when more than critical limit of processes found" do
      @action.var(:critical,:count,:max) { 4 }
      @action.should_receive(:capture).with(String).and_return(<<-__EOF)
STAT   UID   PID  PPID    VSZ   RSS %CPU COMMAND         COMMAND
S       33  3281 16515  20860  4664  0.0 apache2         /usr/sbin/apache2 -k start
S       33  3784 16515  20860  4640  0.0 apache2         /usr/sbin/apache2 -k start
S       33  3902 16515  20860  4764  0.0 apache2         /usr/sbin/apache2 -k start
S       33  4146 16515  20860  4636  0.0 apache2         /usr/sbin/apache2 -k start
S       33  4261 16515  20860  4628  0.0 apache2         /usr/sbin/apache2 -k start
__EOF
      @action.should_receive(:call_next).with(:critical, String, Hash).once
      
      @action.call
    end
  }
end
