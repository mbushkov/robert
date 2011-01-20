class AddHostsAttributeToAreas < ActiveRecord::Migration
  
  def self.up
    add_column :areas, :hosts, :text
  end
  
  def self.down
    remove_column :areas, :hosts
  end
  
end
