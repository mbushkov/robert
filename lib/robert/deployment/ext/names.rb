defn names.from_cmdline do
  body { |prev_names = []|
    next_names = ([].to_set + var[:cli,:cmdline,:names].to_set).to_a
    logd "name.from_cmdline, prev_names = #{prev_names}, passing further: #{next_names}"
    call_next next_names
  }
end

defn names.with_runtime_deps do
  body { |names|
    call_next names
  }
end

defn names.order_by_runtime_deps do
  body { |names|
    getter = lambda do |name|
      return nil unless $top.conf?(name)
      
      $top.cclone(name).runtime_dependencies
    end

    next_names = Robert::Deployment::DependencyResolver.new(getter).order_by_dependencies(names).to_a
    logd "names.order_by_runtime_deps, prev_names = #{names}, passing further: #{next_names}"
    call_next next_names
  }
end

defn names.remote_fresh_only do
  body { |names|
    call_next names
  }
end

defn names.local_fresh_only do
  body { |names|
    local_area = Robert::Deployment::Area.find_or_create_by_name(:local)
    if local_area.current_snapshot
      next_names = names.delete_if do |name|
        local_dep = local_area.current_snapshot.find_deployment_by_name(name)
        local_dep != nil && local_dep.revision == $top.cclone(name).revision
      end
    else
      next_names = names
    end

    logd "names.local_fresh_only, prev_names = #{names}, passing further: #{next_names}"
    call_next next_names
  }
end
