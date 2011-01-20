require "robert/deployment/model/deployment"

class RemoveStaticDependenciesAttributeFromDeployment < ActiveRecord::Migration
  include Robert::Deployment
  
  def self.up
    remove_column :deployments, :static_dependencies
  end
  
end
