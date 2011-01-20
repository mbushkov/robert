class AddUnfinishedSnapshotIdAttributeToAreas < ActiveRecord::Migration
  
  def self.up
    add_column :areas, :unfinished_snapshot_id, :integer
  end
  
  def self.down
    remove_column :areas, :unfinished_snapshot_id
  end
  
end
