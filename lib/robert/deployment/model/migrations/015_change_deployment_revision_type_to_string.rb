require "robert/deployment/model/deployment"

class ChangeDeploymentRevisionTypeToString < ActiveRecord::Migration
  include Robert::Deployment
  
  def self.up
    change_column :deployments, :revision, :text, :null => false
  end
  
end
