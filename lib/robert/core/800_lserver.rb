defn local_server.handle_request do
  body { |io|
    args = Marshal.load(io)
    io.close_read

    ptop, pout, perr = $top, $stdout, $stderr
    topclone, sout, serr = $top.clone, StringIO.new, StringIO.new

    $top, $stdout, $stderr = topclone, sout, serr
    begin
      args_conf = Object.new.extend(RulesContainer)
      def args_conf.rule_ctx
        []
      end
      Robert::CLI.args_to_rules(Robert::CLI.parse_args(args, {}),
                                args_conf)
      topclone.rules.add_all(args_conf.rules)
      
      topclone.cclone(:cli).process_cmd(topclone.var[:cmdline,:cmd])
      exit_status = 0
    rescue SystemExit => e
      exit_status = e.status
    rescue Exception => e
      exit_status = 42
    ensure
      $top, $stdout, $stderr = ptop, pout, perr
      exit_status = 1
    end
    
    Marshal.dump({ :stdout => sout.string, :stderr => serr.string, :exit_code => exit_status }, io)
    io.flush
    io.close_write
  }
end

defn local_server.single_thread do
  body { |serv|
    loop do
      io, client_sock_addr = serv.accept
      begin
        call_next(io)
      ensure
        if !io.closed?
          io.close rescue $stderr.puts($!.to_s)
        end
      end
    end
  }
end

defn local_server.process_pool do
  var[:processes,:count] = 4
  
  body { |serv|
    pc = var[:processes,:count]
    
  }
end

defn local_server.run do
  var[:socket,:unix,:path] = "/tmp/rob-lserver"
  
  body {
    spath = var[:socket,:unix,:path]
    logd "starting server on unix socket: #{spath}"
    FileUtils.rm_f(spath)
    serv = UNIXServer.new(spath)

    call_next(serv)
  }
end

defn local_server.start do
  body {
  }
end

defn local_server.stop do
  body {
  }
end

defn local_server.restart do
  body {
  }
end

conf :local_server do
  act[:run] = local_server.run(local_server.single_thread(local_server.handle_request))
  act[:run_m] = local_server.run(local_server.process_pool(local_server.handle_request))
  
  act[:start] = local_server.start
  act[:stop] = local_server.stop
  act[:restart] = local_server.restart
end
