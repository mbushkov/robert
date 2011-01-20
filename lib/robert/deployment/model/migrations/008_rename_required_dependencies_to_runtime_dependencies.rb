class RenameRequiredDependenciesToRuntimeDependencies < ActiveRecord::Migration
  
  def self.up
    rename_column :deployments, :required_dependencies, :runtime_dependencies
  end
  
  def self.down
    rename_column :deployments, :runtime_dependencies, :required_dependencies
  end
  
end
