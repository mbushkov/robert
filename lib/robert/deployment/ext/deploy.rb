defn cli.prepare_deployment do
  body {
    force_deploy = var[:deployment,:deployment,:force]
    
    $top.confs($top.confs_names, :with_tags => :deployable) do
      act[:revision] = revision.current_local_snapshot
      act[:runtime_dependencies] = runtime_dependencies.current_local_snapshot

      include :deployment_copy
    end

    begin
      call_next
      logi("deployment OK")
    rescue => e
      loge("deployment FAILED: #{e}");
      raise e
    end
  }
end

