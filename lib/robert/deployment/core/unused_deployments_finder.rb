require "set"

module Robert
module Deployment
  
  class UnusedDeploymentsFinder
    attr_reader :all_snapshots, :used_snapshots, :unused_snapshots
    
    def initialize
      @changed = false
      @all_snapshots = []
      @used_snapshots = []
      @unused_snapshots = []
    end
    
    def add_used_snapshot(snapshot)
      @all_snapshots << snapshot
      @used_snapshots << snapshot
      @changed = true
    end
    
    def add_unused_snapshot(snapshot)
      @all_snapshots << snapshot      
      @unused_snapshots << snapshot
      @changed = true
    end
    
    def all_deployments
      analyze if @changed
      @all_deployments
    end
    
    def used_deployments
      analyze if @changed
      @used_deployments
    end
    
    def unused_deployments
      analyze if @changed
      @unused_deployments
    end
    
    def analyze
      @all_deployments = Set.new
      @used_deployments = Set.new
      @unused_deployments = Set.new
      
      @used_snapshots.each do |snapshot|
        snapshot.each do |deployment|
          @all_deployments << deployment
          @used_deployments << deployment
        end
      end
      
      @unused_snapshots.each do |snapshot|
        snapshot.each do |deployment|
          @all_deployments << deployment
          @unused_deployments << deployment
        end
      end
      
      @unused_deployments -= @used_deployments
      @changed = false
    end
    private :analyze
  end
  
end
end
