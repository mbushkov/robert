class AddCurrentAttributeToSnapshot < ActiveRecord::Migration
  
  def self.up
    add_column :snapshots, :current, :boolean, :default => false
  end
  
  def self.down
    remove_column :snapshots, :current
  end
  
end
