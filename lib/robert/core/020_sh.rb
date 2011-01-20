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

conf :base do
  use :sh
end
