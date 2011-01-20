require "robert/deployment/model/deployment"

class AddDeployedAtAttributeToDeployment < ActiveRecord::Migration
  include Robert::Deployment
  
  def self.up
    add_column :deployments, :deployed_at, :datetime
    execute "UPDATE deployments SET deployed_at = (SELECT created_at FROM snapshots WHERE snapshots.id = deployments.snapshot_id)"
    change_column :deployments, :deployed_at, :datetime, :null => false
  end
  
end
