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

    def ctx_counter_inc
      @counter ||= 0
      @counter += 1
    end

    def rule_ctx
      []
    end

    def load(_path) # NOTE: using underscore to avoid name clashes, as argument '_path' will be in the binding
      logd "loading #{_path}" if respond_to?(:logd)
      eval(open(_path, "r") { |f| f.read }, binding, _path)
      @loaded_paths << _path
    end

    def collect_rules
      global_rules = reset_rules
      
      actions.each { |k,v| rules.add_all(v.rules) }
      extensions.each { |k,v| rules.add_all(v.rules) }

      confs_hash.each do |ck,cv|
        class << cv; alias_method :orig_rules, :rules; end if !cv.respond_to?(:orig_rules)

        cv.acts.each do |k,v|
          ctx = RulesDefinitionContext.new([ck.to_sym], rules)
          v.call(ctx)
        end
        rules.add_all(cv.orig_rules)
      end

      rules.add_all(global_rules)
    end

    def process_rules_and_extensions
      old_rules = reset_rules
      rules.add_all(top_rules)
      
      collect_rules

      apply_extensions(extensions)
      confs_hash.each do |ck,cv|
        cv.apply_extensions(extensions)

        def cv.rules
          $top.rules
        end
      end
      old_rules
    end


    def top_rules
      @top_rules ||= []
    end

    #TODO: cleaner code would be nice
    def rules
      res = super
      unless res.respond_to?(:_top_rules)
        m = res.method(:<<)
        top = self
        class << res; self; end.class_eval do
          define_method :<< do |obj|
            top.top_rules << obj
            m.call(obj)
          end

          def _top_rules
          end
        end
      end

      res
    end

#    def select(&block)
#      selector_block = lambda { |conf| ConfigurationSelector.new(conf).instance_eval(&block) }
#      configurations.values.select(&selector_block)
#    end    

    def initialize_copy(src)
      #TODO: implement
    end
  end

end
