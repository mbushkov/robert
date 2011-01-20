defn runtime_dependencies.current_local_snapshot do
  body {
    area = Robert::Deployment::Area.find_by_name("local")
    raise "no current snapshot" unless area && area.current_snapshot
    logd "runtime_dependencies.current_local_snapshot, using snapshot: #{area.current_snapshot.id}"

    dep = area.current_snapshot.find_deployment_by_name(conf_name.to_s)
    raise "no deployment for #{conf_name} found" unless dep
    dep.runtime_dependencies
  }
end

