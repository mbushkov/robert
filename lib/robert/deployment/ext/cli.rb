require 'robert/deployment/model/area'
require 'robert/deployment/model/deployment'
require 'robert/deployment/model/snapshot'
require 'robert/deployment/core/snapshot_transaction'
require 'robert/deployment/utils/dependency_resolver'

var(:deployment,:sources,:force) { var?[:cmdline,:args,:force_sources] }
var(:deployment,:build,:force) { var?[:cmdline,:args,:force_build] }
var(:deployment,:deployment,:force) { var?[:cmdline,:args,:force_deploy] }

defn cli.determine_area do
  body { |names|
    raise "not supported"
  }
end

defn cli.deploy do
  body { |names|
    dep_confs = $top.select { names.include?(conf.conf_name) }
    deps = dep_confs.map do |dc|
      Robert::Deployment::Deployment.new(:name => dc.conf_name, :revision => dc.revision)
    end

    area_name = var?[:deployment,:area] || var?[:cmdline,:args,:area] || determine_area(names)
    used_configurations = Hash.new do |h,dep|
      if $top.conf?(dep.name)
        conf = $top.cclone(dep.name)
      else
        $top.conf(dep.name) {}
        conf = $top.cclone(dep.name)
        class << conf; self; end.class_eval do
          define_method :revision do
            dep.revision
          end
        end
      end
      conf.include("area:#{area_name}")
      h[dep] = conf
    end
    dep_transaction_getter = lambda { |dep| used_configurations[dep] }

    area = Robert::Deployment::Area.find_or_create_by_name(area_name)
    Robert::Deployment::SnapshotTransactionCleaner.new(dep_transaction_getter).clean_unfinished_snapshot(area)
    prev_current_snapshot = area.current_snapshot
    begin
      Robert::Deployment::SnapshotTransaction.new(dep_transaction_getter).deploy_new_snapshot(area, deps, :ignore_errors => var?[:cmdline,:args,:ignore_errors])
      logi "for fast rollback use command: rob fast_rollback sid=#{prev_current_snapshot.id}" if prev_current_snapshot && area.current_snapshot != prev_current_snapshot
    rescue => e
      loge "deployment failed: #{e}"
      raise e
    end
  }
end

conf :cli do
  act[:determine_area] = cli.determine_area
  act[:deploy] = deployment_db.with_connection(
                   deployment_db.migrate(
                     cli.prepare_deployment(
                       names.from_cmdline(
                         names.with_runtime_deps(
                           names.remote_fresh_only(
                             names.order_by_runtime_deps(
                               cli.deploy)))))))

  var[:prepare_build,:deployment,:area] = :local
  act[:build] = deployment_db.with_connection(
                  deployment_db.migrate(
                    cli.prepare_build(
                      names.from_cmdline(
                        names.local_fresh_only(
                          names.order_by_runtime_deps(
                            cli.deploy))))))
  act[:fast_rollback] = deployment_db.with_connection(deployment_db.migrate(cli.fast_rollback))
end
