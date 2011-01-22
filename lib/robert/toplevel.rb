require 'robert/action'
require 'robert/rule'
require 'robert/id'
require 'robert/conf'
require 'robert/ext'
require 'set'

module Robert
  class TopLevel < Configuration
    include ActionsContainer
    include ConfigurationsContainer
    include RulesStorageContainer
    include ExtsDefiner
    include MethodMissingAsId

    attr_reader :loaded_paths, :core_paths

    def initialize
      super(:top)
      
      @loaded_paths = []
      @core_paths = Dir["#{File.dirname __FILE__}/**/*.rb"]

      self.mm_for_id = true
    end

    def rule_ctx
      []
    end

    def load(_path) # NOTE: using underscore to avoid name clashes, as argument '_path' will be in the binding
      logd "loading #{_path}" if respond_to?(:logd)
      eval(open(_path, "r") { |f| f.read }, binding, _path)
      @loaded_paths << _path
    end

    def process_rules
      actions.each { |k,v| rules.add_all(v.rules) }
      extensions.each { |k,v| rules.add_all(v.rules) }

      confs_hash.each do |ck,cv|
        c = cclone(ck) { |conf| conf.extend(RulesDefiner) }

        c.acts.each do |k,v|
          ctx = RulesDefinitionContext.new([ck.to_sym], rules)
          v.call(ctx)
        end
        rules.add_all(c.orig_rules)
      end
    end
  end

end
