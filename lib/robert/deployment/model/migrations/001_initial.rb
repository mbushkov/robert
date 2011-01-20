class Initial < ActiveRecord::Migration
  
  def self.up
    create_table :areas do |table|
      table.column :name, :text, :null => false
    end
    
    create_table :snapshots do |table|
      table.column :created_at, :datetime, :null => false
      table.column :area_id, :integer, :null => false
    end
    
    create_table :deployments do |table|
      table.column :name, :text, :null => false
      table.column :revision, :integer, :null => false
    end
  end
  
  def self.down
    drop_table :areas
    drop_table :snapshots
    drop_table :deployments
  end
  
end
