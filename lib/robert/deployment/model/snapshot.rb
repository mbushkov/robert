require "active_record"

module Robert
module Deployment
      
class Snapshot < ActiveRecord::Base
  include Enumerable

  has_many :deployments, :dependent => :destroy
  belongs_to :area
  has_one :current_area, :class_name => "Area", :foreign_key => "current_snapshot_id", :dependent => :nullify
  has_one :unfinished_area, :class_name => "Area", :foreign_key => "unfinished_snapshot_id", :dependent => :nullify

  def assign(snapshot)
    if snapshot
      snapshot.deployments.each do |dep|
        deployments << dep.clone
      end
      attrs = snapshot.attributes.dup
      attrs.delete("deployments")
      attrs.delete(self.class.primary_key)
      attrs.delete("created_at")
      self.attributes = self.attributes.merge(attrs)
    end
  end

  def add_deployment(dep)
    deployments << dep
  end

  def delete_deployment(dep)
    deployments.delete dep
  end

  def find_deployment(dep)
    deployments.each { |dep_iter| return dep_iter if dep_iter == dep }
    nil
  end

  def find_deployment_by_name(name)
    deployments.each { |dep| return dep if dep.name == name }
    nil
  end  
  
  def diff(snapshot)
    deployments.select { |dep| !snapshot.find_deployment(dep) }
  end

  def find_or_initialize_deployment_by_name(name)
    find_deployment_by_name(name) || deployments.build(:name => name)
  end

  def each(&block)
    deployments.each(&block)
  end
end
      
end
end
