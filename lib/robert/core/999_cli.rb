var[:cmdline,:filtered,:names] = var[:cmdline, :names] = ->{ $top.cclone(:cli).filter_names(var[:cmdline,:unfiltered,:names]) }

defn cli.all_keyword_to_names do
  body { |names|
    all_names = (names == [:all] ? $top.confs_names : names)
    has_next? ? call_next(all_names) : all_names
  }
end
      

defn cli.filter_names_with_selector do
  body { |names|
    sel_opts = ConfigurationSelector.all_selectors.inject({}) do |memo, sel|
      if var?[:cmdline,:args,sel.to_sym]
        memo[sel] = var[:cmdline,:args,sel.to_sym]
      end
      memo
    end
    
    filtered_names = (sel_opts != {} ? $top.select { |conf| names.include?(conf.conf_name) && with_options(sel_opts) }.names : names)
    has_next? ? call_next(filtered_names) : filtered_names
  }
end

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
  act[:filter_names] = memo(cli.all_keyword_to_names(cli.filter_names_with_selector(act[:filter_with_user_specified_filters])))
  act[:process_cmd] = cli.process_cmd(cli.pass_cmd_to_confs)
  act[:eval] = cli.eval_rule
end


