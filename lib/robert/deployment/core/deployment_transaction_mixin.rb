module Robert
module Deployment
  
  module DeploymentTransactionMixin
    
    def deployment_transaction_getter
      used_configurations = {}
      lambda do |deployment|
        used_configurations[deployment] ||= (configuration_defined?(deployment.name) ? 
          configuration_clone(deployment.name) :
          mc.create_orphaned_configuration(deployment.name)).use(:revision => :explicit) { set :revision, deployment.revision }
      end
    end
    
    def deployment_transaction(options = {}, &block)
      SnapshotTransaction.new(deployment_transaction_getter).deployment_transaction(area, options, &block)
    end
    
  end
  
end
end
