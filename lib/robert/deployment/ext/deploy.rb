defn cli.prepare_deployment do
  body {
    force_deploy = var[:deployment,:deployment,:force]
    
    $top.confs($top.confs_names, :with_tags => :deployable) do
      act[:revision] = revision.current_local_snapshot
      act[:runtime_dependencies] = runtime_dependencies.current_local_snapshot

      include :deployment_copy
    end

    call_next
  }
end

