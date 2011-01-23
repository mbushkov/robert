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

      confs_names.each do |conf_name|
        conf_clone = cclone(conf_name)

        rules.add_all(conf_clone.orig_rules)
        conf_clone.acts.each do |k,v|
          ctx = RulesDefinitionContext.new([conf_name], rules)
          v.call(ctx)
        end
      end
    end
  end

end
