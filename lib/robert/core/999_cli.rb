defn cli.process_cmd do
  body {
    cmd = var[:cmdline,:cmd]

    if respond_to?(cmd)
      send(cmd)
    else
      call_next
    end
  }
end

defn cli.pass_cmd_to_confs do
  body {
    names = var[:cmdline,:names]
    cmd = var[:cmdline,:cmd]
    
    errors = []
    names.map do |name|
      begin
        conf = $top.cclone(name)
        conf.send(cmd)
      rescue => e
        errors << e
      end
    end
    unless errors.empty?
      errors.each do |e|
        logd e.message
        logd e.backtrace.join("\n\t")
      end
      raise errors.join("\n")
    end
  }
end

defn cli.eval_rule do
  body {
    rule_ctx = var[:cmdline,:args,0]
    puts var[*rule_ctx[0]]
  }
end

conf :cli do
  act[:process_cmd] = cli.process_cmd(cli.pass_cmd_to_confs)
  act[:eval] = cli.eval_rule
end


