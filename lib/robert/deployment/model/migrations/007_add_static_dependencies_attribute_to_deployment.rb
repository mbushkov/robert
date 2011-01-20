require "robert/deployment/model/deployment"

class AddStaticDependenciesAttributeToDeployment < ActiveRecord::Migration
  include Robert::Deployment
  
  def self.up
    add_column :deployments, :static_dependencies, :text
    Deployment.update_all "static_dependencies = '#{[].to_yaml}'"
  end
  
  def self.down
    remove_column :deployments, :static_dependencies
  end
  
end
