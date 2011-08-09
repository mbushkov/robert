defn deployment_copy.deploy do
  body {
    archived_output = syscmd_output("tar -cf - -C #{revision_deployment.deployment_root} ./ | gzip -c", true)
    with_capistrano :roles => :app do |cap|
      cap.run "mkdir -p '#{revision_deployment.deployment_root}'"
      cap.put archived_output, "#{File.join(revision_deployment.revision_root, "deployment.tar.gz")}"
      cap.run "tar -C '#{revision_deployment.deployment_root}' -xzf '#{File.join(revision_deployment.revision_root, "deployment.tar.gz")}'"
    end
  }
end

defn deployment_copy.link_deployment do
  body {
    with_capistrano :roles => :app do |cap|
      cap.run "sh '#{File.join(revision_deployment.deployment_root, var[:deployment,:link_script,:name])}' '#{revision_deployment.deployment_root}'"
    end
  }
end

defn deployment_copy.unlink_deployment do
  body {
    with_capistrano :roles => :app do |cap|
      cap.run "sh '#{File.join(revision_deployment.deployment_root, var[:deployment,:unlink_script,:name])}'"
    end
  }
end

defn deployment_copy.remove_deployment do
  body {
    with_capistrano :roles => :app do |cap|
      cap.run "rm -rf '#{revision_deployment.revision_root}'"
    end
  }
end

conf :deployment_copy do
  act[:deploy] = deployment_copy.deploy
  act[:link_deployment] = deployment_copy.link_deployment
  act[:unlink_deployment] = deployment_copy.unlink_deployment
  act[:remove_deployment] = deployment_copy.remove_deployment
end
