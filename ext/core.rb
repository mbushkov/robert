require 'open4'
ext :sh do
  def syscmd_status(command, output_io = nil, no_log = false)
    logi("executing locally: #{[command].flatten.join ' '}")

    Open4::popen4(*[command].flatten) do |pid, stdin, stdout, stderr|
      stdin.close

      out_thread = Thread.start {
        loop do
        line = stdout.readline
        output_io.write line if output_io
        logi "> #{line}" unless no_log
        end rescue ""
      }
      err_thread = Thread.start {
        loop do
        line = stderr.readline
        logd "err> #{line}" unless no_log
        end rescue ""
      }

      out_thread.join
      err_thread.join
    end
  end

  def syscmd(command, output_io = nil, no_log = false)
    if (status_code = syscmd_status(command, output_io, no_log)) != 0
      fail "command failed (#{status_code}): #{command}" 
    end
  end

  def syscmd_output(command, no_log = false)
    output = StringIO.new
    syscmd(command, output, no_log)
    output.string
  end    

  alias sh_status syscmd_status
  alias sh syscmd
  alias sh_output syscmd_output
end

ext :log do
  TRACE_LEVEL = 5
  DEBUG_LEVEL = 4
  INFO_LEVEL = 3
  WARNING_LEVEL = 2
  ERROR_LEVEL = 1
  FATAL_LEVEL = 0

  var(:log,:level) { TRACE_LEVEL }

  def log(level, message = nil, &block)
    raise ArgumentError, "either string or block should be provided" if message && block
    if level <= log_level
      puts((respond_to?(:conf_name) ? "[#{conf_name}] " : "") + (message || block.call))
    end
  end

  def logt(message = nil, &block)
    log(TRACE_LEVEL, message, &block)
  end

  def logd(message = nil, &block)
    log(DEBUG_LEVEL, message, &block)
  end

  def logi(message = nil, &block)
    log(INFO_LEVEL, message, &block)
  end

  def logw(message = nil, &block)
    log(WARNING_LEVEL, message, &block)
  end

  def loge(message = nil, &block)
    log(ERROR_LEVEL, message, &block)
  end

  def logf(message = nil, &block)
    log(FATAL_LEVEL, message, &block)
  end

  def log_level
    var[:log,:level]
  end
end

ext :temp_file do
  def with_temp_fname(suffix = "tmp")
    t = Time.now.strftime("%Y%m%d%H%M%S")
    tname = "/tmp/#{t}-#{$$}-#{Thread.current.object_id}-#{suffix}"
    begin
      yield tname
    ensure
      run "rm -f #{tname}" rescue loge "error while deleting #{tname}: #{$!}"
    end
  end
end

defn pause.pause do
  body do |seconds = var[:seconds]|
    logd "pausing for #{seconds} seconds"
    Kernel.sleep(seconds)
  end
end

defn onfail.continue do
  body do |*args|
    begin
      call_next(*args)
    rescue => e
      loge "#{e} happened"
    end
  end
end

defn onfail.tryagain do
  var(:max_tries) { 1024 }
  var(:pause) { 0 }

  body do |*args|
    tries = 0
    begin
      call_next(*args)
    rescue => e
      tries += 1
      if tries < var[:max_tries]
        loge "#{e} happened #{tries} times, sleeping for #{var[:pause]}s, then retrying"
        sleep(var[:pause])
        retry
      else
        logf "#{e} happened #{tries} times, exceeding maximum tries limit (#{var[:max_tries]}), failing"
        raise
      end
    end
  end
end

defn dummy.dummy do
  body do |*args|
  end
end

defn dummy.dummy_fail do
  body do
    raise "dummy exception"
  end
end
