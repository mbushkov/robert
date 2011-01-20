require 'stringio'
require 'fileutils'

module Robert
  def process_local_request(io)
    pid = fork {
      pout, perr = $stdout, $stderr
      $stdout, $stderr = StringIO.new, StringIO.new
      begin
        args = Marshal.load(io)
        io.close_read
        
        exit_status = 0
        begin
          CLI.new.execute_without_init(args, [])
        rescue SystemExit => e
          exit_status = e.status
        rescue Exception => e
          exit_status = 42
        end

        Marshal.dump({ :stdout => $stdout.string, :stderr => $stderr.string, :exit_code => exit_status }, io)
        io.flush
        io.close_write
      ensure
        if !io.closed?
          io.close rescue $stderr.puts($!.to_s)
        end
        pout.write($stdout.string); pout.flush
        perr.write($stderr.string); perr.flush
        $stdout, $stderr = pout, perr
      end
    }
    io.close rescue $stderr.puts($!.to_s)
    Process.detach(pid)
  end
  module_function :process_local_request
  
  def run_local_server(unix_socket_path, options = {})
    puts "starting server on unix socket: #{unix_socket_path}"
    FileUtils.rm_f(unix_socket_path)
    serv = UNIXServer.new(unix_socket_path)
    loop do
      client, client_sock_addr = serv.accept
      process_local_request(client)
    end
      
  end
  module_function :run_local_server

end
