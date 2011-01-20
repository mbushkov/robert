require "active_record"

module Robert
module Deployment
  
class Area < ActiveRecord::Base
  has_many :snapshots, :dependent => :destroy
  belongs_to :current_snapshot, :class_name => "Snapshot"
  belongs_to :unfinished_snapshot, :class_name => "Snapshot"
  serialize :hosts

  def build_snapshot_from_snapshot(snapshot)
    result = snapshots.build
    result.assign(snapshot) if snapshot
    result
  end

  def last_snapshot
    snapshots.find(:first, :order => "created_at DESC", :limit => 1, :include => :deployments)
  end

  def existent_snapshots
    snapshots.find(:all, :order => "created_at DESC", :conditions => %q("exists" = 't'), :include => :deployments)
  end
  
  def previous_snapshot_for_snapshot(snapshot)
    snapshots.find(:first, :conditions => ["created_at < ?", snapshot.created_at], :order => "created_at DESC", :include => :deployments)
  end
  
  def find_snapshot_by_id(id)
    snapshots.find_by_id(id, :include => :deployments)
  end

  def add_snapshot(snapshot)
    snapshots << snapshot
  end

  def delete_snapshot(snapshot)
    snapshots.delete(snapshot)
  end
end
      
end
end
