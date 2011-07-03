defn confs_to_deploy.from_cmdline do
  body { |prev_confs = []|
    next_confs = ([].to_set + var[:cli,:cmdline,:names].map { |n| $top.cclone(n) }.to_set).to_a

    prev_names = prev_confs.map { |c| c.conf_name }
    next_names = next_confs.map { |c| c.conf_name }
    logd "name.from_cmdline, prev_names = #{prev_names}, passing further: #{next_names}"
    
    call_next next_confs
  }
end

defn confs_to_deploy.with_runtime_deps do
  body { |confs|
    call_next confs
  }
end

# defn confs.order_by_runtime_deps do
#   body { |confs|
#     getter = lambda do |name|
#       return nil unless $top.conf?(name)

#       conf = confs.find { |c| c.conf_name == name }
#       conf.runtime_dependencies
#     end

#     next_names = Robert::Deployment::DependencyResolver.new(getter).order_by_dependencies(confs.map { |c| c.conf_name }).to_a
#     logd "names.order_by_runtime_deps, prev_names = #{names}, passing further: #{next_names}"
#     call_next next_names
#   }
# end

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
    logd "confs.local_fresh_only, prev_names = #{names}, passing further: #{next_names}"
    
    call_next next_confs
  }
end
