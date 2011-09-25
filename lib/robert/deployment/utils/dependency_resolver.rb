require "set"

module Robert
module Deployment
  
  class DependencyResolver
    def initialize(get_required_dependencies_proc)
      @get_required_dependencies_proc = get_required_dependencies_proc
    end
    
    def build_dependencies(names)
      deps = {}
      names.each do |name|
        required_deps = @get_required_dependencies_proc.call(name)
        deps[name] = { :direct_required => required_deps } if required_deps
      end
    
      deps.each_key do |name|
        reqset = deps[name][:direct_required].to_set

        ssize = 0
        until ssize == reqset.size
          newelm = Set.new
          reqset.each { |req_proj| newelm.merge(deps[req_proj][:direct_required]) if deps[req_proj] }

          ssize = reqset.size
          reqset.merge newelm
        end
        deps[name][:all_required] = reqset
      end      
      
      deps
    end
    private :build_dependencies
    
    def order_by_dependencies(names)
      deps = build_dependencies(names)
      
      result_names = names.reject { |name| deps[name].nil? }
      loop do
        flag = false
        (0 .. (result_names.length - 2)).each do |i|
          (i .. (result_names.length - 1)).each do |j|
            if deps[result_names[i]][:all_required].include? result_names[j].to_s
              result_names[i], result_names[j] = result_names[j], result_names[i]
              flag = true
            end
          end            
        end
        
        break unless flag
      end
      
      result_names      
    end
    
    def get_dependencies(names, discarded_names)
      deps = Set.new
      names.each do |name|
        deps.merge((@get_required_dependencies_proc.call(name) || []).to_set - discarded_names)        
      end
      deps
    end
    private :get_dependencies
    
    def add_required(names)
      result = Set.new(names)
      new_deps = Set.new(names)
      loop do
        new_deps = get_dependencies(new_deps, result)
        break if new_deps.empty?
        result.merge(new_deps)
      end
      
      result
    end
    
    def add_dependent(names, names_to_check)
      result = names.dup.to_set
      result_size = result.size
      loop do
        names_to_check.each do |name|
          deps = @get_required_dependencies_proc.call(name)
          if deps && !(deps.to_set & result).empty?
            result << name 
          end
        end
        
        break if result.size == result_size
        result_size = result.size
      end
      
      result
    end
    
  end

end
end
