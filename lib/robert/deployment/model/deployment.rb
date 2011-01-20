require "set"
require "active_record"

module Robert
module Deployment
  
  class Deployment < ActiveRecord::Base
    belongs_to :snapshot
    serialize :runtime_dependencies

    def assign(dep)
      attrs = dep.attributes.dup
      attrs.delete(self.class.primary_key)
      attrs.delete("created_at")      
      self.attributes = self.attributes.merge(attrs)
    end

    def dup
      result = Deployment.new
      result.assign(self)
      result
    end

    def ==(obj)
      obj.equal?(self) || (obj.instance_of?(self.class) && obj.name == self.name && obj.revision == self.revision)
    end    
    
    def hash
      name.hash ^ revision.hash
    end
  end
      
end
end
