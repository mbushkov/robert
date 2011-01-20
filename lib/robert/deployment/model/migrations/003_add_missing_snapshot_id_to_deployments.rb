class AddMissingSnapshotIdToDeployments < ActiveRecord::Migration
  
  def self.up
    add_column :deployments, :snapshot_id, :integer
  end
  
  def self.down
    remove_column :deployments, :snapshot_id
  end
  
end
