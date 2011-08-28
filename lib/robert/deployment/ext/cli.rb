require 'robert/deployment/model/area'
require 'robert/deployment/model/deployment'
require 'robert/deployment/model/snapshot'
require 'robert/deployment/core/snapshot_transaction'
require 'robert/deployment/utils/dependency_resolver'

defn deployment_state.area do
  body {
    raise "can't specify both area and sid in the command line" if var?[:cmdline,:args,:area] and var?[:cmdline,:args,:sid]

    unless var?[:cmdline,:args,:sid]
      area_name = var?[:deployment,:area] || var?[:cmdline,:args,:area] || determine_area(dep_confs)
      Robert::Deployment::Area.find_or_create_by_name(area_name)
    else
      snapshot.area
    end
  }
end

defn deployment_state.snapshot do
  body {
    raise "can't specify both area and sid in the command line" if var?[:cmdline,:args,:area] and var?[:cmdline,:args,:sid]

    snapshot_id = var[:cmdline,:args,:sid]
    if snapshot_id
      Robert::Deployment::Snapshot.find_by_id(snapshot_id)
    else
      area.snapshot
    end
  }
end

defn deployment_state.transaction_getter do
  body {
    area = self.area
    used_configurations = Hash.new do |h,dep|
      conf = nil
      $top.temporary do
        $top.adjust do
          $top.conf(dep.name) do
            include "area:#{area.name}"
            act[:revision] = revision.explicit { var[:revision] = dep.revision }

            #NOTE: A bit of a hack since this action is also executedin prepare_build/prepare_deployment
            include (area.name == "local" ? :deployment_local_build : :deployment_copy)
          end
        end

        conf = $top.cclone(dep.name)
      end
      
      h[dep] = conf
    end
    dep_transaction_getter = lambda { |dep| used_configurations[dep] }
  }
end

conf :deployment_state do
  act[:area] = deployment_state.area
  act[:snapshot] = deployment_state.snapshot
  act[:transaction_getter] = deployment_state.transaction_getter
end

var(:deployment,:sources,:force) { var?[:cmdline,:args,:force_sources] }
var(:deployment,:build,:force) { var?[:cmdline,:args,:force_build] }
var(:deployment,:deployment,:force) { var?[:cmdline,:args,:force_deploy] }

defn cli.determine_area do
  body { |confs|
    raise "not supported"
  }
end

defn cli.deploy do
  body { |confs|
    dep_confs = confs
    deps = dep_confs.map do |dc|
      Robert::Deployment::Deployment.new(:name => dc.conf_name, :revision => dc.revision.to_s)
    end

    deployment_state = $top.cclone(:deployment_state)
    area = deployment_state.area

    Robert::Deployment::SnapshotTransactionCleaner.new(deployment_state.transaction_getter).clean_unfinished_snapshot(area)
    prev_current_snapshot = area.current_snapshot

    Robert::Deployment::SnapshotTransaction.new(deployment_state.transaction_getter).deploy_new_snapshot(area, deps, :ignore_errors => var?[:cmdline,:args,:ignore_errors])
    logi "for fast rollback use command: rob fast_rollback sid=#{prev_current_snapshot.id}" if prev_current_snapshot && area.current_snapshot != prev_current_snapshot
  }
end

defn cli.prepare_build_or_deployment do
  
end

defn cli.fast_rollback do
  body {
    deployment_state = $top.cclone(:deployment_state)
    snapshot = deployment_state.snapshot

    raise "can't do fast rollback as there is current snapshot in the area" if snapshot.nil?
    area = snapshot.area

    raise "can't rollback to current snapshot" if snapshot == area.current_snapshot
    raise "can't rollback to unfinished snapshot" if snapshot == area.unfinished_snapshot
    raise "can't rollback to non-existent snapshot" unless snapshot.exists?

    prev_snapshot = area.previous_existent_snapshot_for_snapshot(area.current_snapshot)
    raise "destination snapshot (#{snapshot.id}) is not previous to current (#{area.current_snapshot.id}, previous is #{prev_snapshot.id}) - possibly other deployments had been performed" if prev_snapshot != snapshot

    Robert::Deployment::SnapshotTransactionCleaner.new(deployment_state.transaction_getter).clean_unfinished_snapshot(area)
    Robert::Deployment::Area.transaction do
      area.unfinished_snapshot = area.build_snapshot_from_snapshot(area.current_snapshot)

      area.current_snapshot.exists = false
      area.current_snapshot.save!
      
      area.current_snapshot = snapshot
      Robert::Deployment::SnapshotTransactionCleaner.new(deployment_state.transaction_getter).clean_unfinished_snapshot(area)
    end
  }
end

defn cli.show_status do
  body {
    begin
      call_next
      logi("#{var[:message]} OK")
    rescue => e
      logi("#{var[:message]} FAILED: #{e}")
      raise e
    end
  }
end

conf :cli do
  act[:determine_area] = cli.determine_area
  act[:deploy] = deployment_db.with_connection(
                   deployment_db.migrate(
                     cli.prepare_deployment(
                       cli.show_status(
                         confs_to_deploy.from_cmdline(
                           confs_to_deploy.with_runtime_deps(
#                             confs_to_deploy.remote_fresh_only(
                               confs_to_deploy.order_by_runtime_deps(
                                 cli.deploy)))))))
  var[:deploy,:*,:show_status,:message] = "deployment"

  var[:prepare_build,:deployment,:area] = :local
  act[:build] = deployment_db.with_connection(
                  deployment_db.migrate(
                    cli.prepare_build(
                      cli.show_status(
                        confs_to_deploy.from_cmdline(
                          confs_to_deploy.local_fresh_only(
                            confs_to_deploy.with_runtime_deps(
                              confs_to_deploy.order_by_runtime_deps(
                                cli.deploy))))))))
  var[:build,:*,:show_status,:message] = "build"

  act[:fast_rollback] = deployment_db.with_connection(
                          deployment_db.migrate(
                            cli.show_status(
                              cli.fast_rollback)))
  var[:fast_rollback,:*,:show_status,:message] = "fast rollback"
end
