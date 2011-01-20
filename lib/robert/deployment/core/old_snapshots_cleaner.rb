require "robert/deployment/core/unused_deployments_finder"
require "robert/deployment/model/snapshot"

module Robert
module Deployment
  
  module OldSnapshotsCleaner
    
    module_function
    
    def create_unused_deployments_finder
      UnusedDeploymentsFinder.new
    end
    
    def clean_old_snapshots(area, limit, configuration_getter)
      finder = create_unused_deployments_finder
      
      existent_snapshots = area.existent_snapshots
      return if existent_snapshots.size <= limit
      
      i = 0
      existent_snapshots.each do |snapshot|
        next if snapshot == area.current_snapshot

        if i < limit
          finder.add_used_snapshot(snapshot)
        else
          finder.add_unused_snapshot(snapshot)
        end
        i += 1
      end

      Robert::Deployment::Snapshot.transaction do
        finder.unused_snapshots.each do |snapshot|
          snapshot.exists = false
          snapshot.save!
        end
        finder.unused_deployments.each do |deployment|
          puts "removing old deployment: #{deployment.name}:#{deployment.revision}"
          conf = configuration_getter.call(deployment)
          conf.remove_deployment if conf
        end      
      end
    end
    
  end
  
end
end
