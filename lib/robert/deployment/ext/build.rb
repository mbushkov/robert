force_sources = false #var?[:deployment,:sources,:force]
force_build = false #var?[:deployment,:build,:force]

# confs(confs_names, :with_tags => :deployable) do
#   if force_sources
#     act[:sources] = sources.session_one_time(act[:sources])
#   else
#     act[:sources] = sources.persistent_one_time(act[:sources])
#   end
      
#   if force_build
#     act[:build] = build.session_one_time(act[:build])
#   else
#     act[:build] = build.persistent_one_time(act[:build])
#   end
      
#   act[:revision] = memo(act[:revision])
  
#   include :deployment_local_build
# end
# var[:deployment,:area] = :local
  
defn cli.prepare_build do
  body {
    raise "build can only be performed locally" if var[:deployment,:area] != :local

    force_sources = var[:deployment,:sources,:force]
    force_build = var[:deployment,:build,:force]

    $top.adjust do
      var[:deployment,:area] = :localhost
      
      $top.confs($top.confs_names, :with_tags => :deployable) do
        if force_sources
          act[:sources] = sources.session_one_time(act[:sources])
        else
          act[:sources] = sources.persistent_one_time(act[:sources])
        end
        
        if force_build
          act[:build] = build.session_one_time(act[:build])
        else
          act[:build] = build.persistent_one_time(act[:build])
        end
        
        act[:revision] = memo(act[:revision])
        
        include :deployment_local_build
      end
    end

    call_next
  }
end

