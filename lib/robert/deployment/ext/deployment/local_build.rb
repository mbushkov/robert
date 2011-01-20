defn deployment_local_build.deploy do
  body {
    build
    dist_patch

    dep_root = revision_deployment.deployment_root
    FileUtils.rm_rf dep_root
    FileUtils.mkdir_p File.dirname(dep_root)
    FileUtils.cp_r revision_build.patched_dist_path, dep_root
  }
end

defn deployment_local_build.link_deployment do
  body {
    syscmd("sh '#{File.join(revision_deployment.deployment_root, var[:deployment,:link_script,:name])}' '#{revision_deployment.deployment_root}'")
  }
end

defn deployment_local_build.unlink_deployment do
  body {
    syscmd("sh '#{File.join(revision_deployment.deployment_root, var[:deployment,:unlink_script,:name])}'")
  }
end

defn deployment_local_build.remove_deployment do
  body {
    FileUtils.rm_r revision_deployment.revision_root, :force => true
  }
end

conf :deployment_local_build do
  act[:deploy] = deployment_local_build.deploy
  act[:link_deployment] = deployment_local_build.link_deployment
  act[:unlink_deployment] = deployment_local_build.unlink_deployment
  act[:remove_deployment] = deployment_local_build.remove_deployment
end

