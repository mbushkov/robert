defn confs_to_deploy.from_cmdline do
  body { |prev_confs = []|
    next_confs = ([].to_set + var[:cli,:cmdline,:names].map { |n| $top.cclone(n) }.to_set).to_a

    prev_names = prev_confs.map { |c| c.conf_name }
    next_names = next_confs.map { |c| c.conf_name }
    logd "confs_to_deploy.from_cmdline, prev_names = #{prev_names}, passing further: #{next_names}"
    
    call_next next_confs
  }
end

defn confs_to_deploy.with_deps do
  body { |confs|
    deps_type = "#{var[:type].to_s}_dependencies".to_sym
    
    confs_map = confs.inject(Hash.new { |h,k| h[k] = $top.conf?(k) && $top.cclone(k) }) do |memo, conf|
      memo[conf.conf_name] = conf; memo
    end
    
    getter = lambda do |name|
      (confs_map[name] || nil) && confs_map[name].send(deps_type)
    end
    
    prev_names = confs.map { |c| c.conf_name }
    next_names = Robert::Deployment::DependencyResolver.new(getter).add_required(confs.map { |c| c.conf_name }).to_a

    logd "confs_to_deploy.with_deps (#{deps_type}), prev_names = #{prev_names}, passing further: #{next_names}"
    call_next next_names.map { |n| confs_map[n] || nil }.compact
  }
end

defn confs_to_deploy.order_by_deps do
  body { |confs|
    deps_type = "#{var[:type].to_s}_dependencies".to_sym
    
    confs_map = confs.inject(Hash.new { |h,k| h[k] = $top.conf?(k) && $top.cclone(k) }) do |memo, conf|
      memo[conf.conf_name] = conf; memo
    end
    
    getter = lambda do |name|
      (confs_map[name] || nil) && confs_map[name].send(deps_type)
    end
    
    prev_names = confs.map { |c| c.conf_name }
    next_names = Robert::Deployment::DependencyResolver.new(getter).order_by_dependencies(confs.map { |c| c.conf_name }).to_a

    logd "confs_to_deploy.order_by_deps (#{deps_type}), prev_names = #{prev_names}, passing further: #{next_names}"
    call_next next_names.map { |n| confs_map[n] }
  }
end

# defn names.remote_fresh_only do
#   body { |names|
#     call_next names
#   }
# end

defn confs_to_deploy.local_fresh_only do
  body { |confs|
    next_confs = confs.dup
    unless var?[:cmdline,:args,:force_build]
      local_area = Robert::Deployment::Area.find_or_create_by_name(:localhost)
      if local_area.current_snapshot
        next_confs = confs.delete_if do |conf|
          local_dep = local_area.current_snapshot.find_deployment_by_name(conf.conf_name.to_s)
          local_dep != nil && local_dep.revision == conf.revision.to_s
        end
      end
    end

    names = confs.map { |c| c.conf_name }
    next_names = next_confs.map { |c| c.conf_name }
    logd "confs_to_deploy.local_fresh_only, prev_names = #{names}, passing further: #{next_names}"
    
    call_next next_confs
  }
end
