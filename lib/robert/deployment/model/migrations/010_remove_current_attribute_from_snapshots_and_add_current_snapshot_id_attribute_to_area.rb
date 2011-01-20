class RemoveCurrentAttributeFromSnapshotsAndAddCurrentSnapshotIdAttributeToArea < ActiveRecord::Migration
  
  def self.up
    add_column :areas, :current_snapshot_id, :integer
    remove_column :snapshots, :current
  end
  
  def self.down
    remove_column :areas, :current_snapshot_id
    add_column :snapshots, :current, :boolean, :default => false
  end
  
end
