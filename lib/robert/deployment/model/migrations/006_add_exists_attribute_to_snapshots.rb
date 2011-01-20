class AddExistsAttributeToSnapshots < ActiveRecord::Migration
  
  def self.up
    add_column :snapshots, :exists, :boolean, :default => false
  end
  
  def self.down
    remove_column :snapshots, :exists
  end
  
end
