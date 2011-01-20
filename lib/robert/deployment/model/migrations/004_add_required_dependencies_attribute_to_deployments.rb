class AddRequiredDependenciesAttributeToDeployments < ActiveRecord::Migration
  
  def self.up
    add_column :deployments, :required_dependencies, :text
  end
  
  def self.down
    remove_column :deployments, :required_dependencies
  end
  
end
