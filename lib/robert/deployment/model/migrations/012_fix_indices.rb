class FixIndices < ActiveRecord::Migration
  
  def self.up
    remove_index :snapshots, [:area_id, :created_at]
    remove_index :snapshots, [:area_id, :created_at, :exists]
    remove_index :deployments, [:snapshot_id, :name]
    
    add_index :snapshots, [:area_id, :exists]
    add_index :snapshots, :created_at
    
    add_index :deployments, [:name, :snapshot_id]
    add_index :deployments, :snapshot_id
  end
  
  def self.down
    add_index :snapshots, [:area_id, :created_at]
    add_index :snapshots, [:area_id, :created_at, :exists]
    add_index :deployments, [:snapshot_id, :name]
    
    remove_index :snapshots, [:area_id, :exists]
    remove_index :snapshots, :created_at
    
    remove_index :deployments, [:name, :snapshot_id]
    remove_index :deployments, :snapshot_id
  end
  
end
