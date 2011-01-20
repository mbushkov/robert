class CreateIndices < ActiveRecord::Migration
  
  def self.up
    add_index :areas, :name
    add_index :snapshots, :area_id
    add_index :snapshots, [:area_id, :created_at]
    add_index :snapshots, [:area_id, :created_at, :exists]
    add_index :deployments, [:snapshot_id, :name]
  end
  
  def self.down
    remove_index :areas, :name
    remove_index :snapshots, :area_id
    remove_index :snapshots, [:area_id, :created_at]
    remove_index :snapshots, [:area_id, :created_at, :exists]
    remove_index :deployments, [:snapshot_id, :name]
  end
  
end
