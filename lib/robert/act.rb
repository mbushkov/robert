module Robert
  
  class ActionId
    def initialize(lname, &later)
      @lname = lname
      @later = later
    end

    def method_missing(rname, *args, &block)
      @later.call(:"#{@lname}.#{rname}", *args, &block)
    end
  end

  # ActContextHandler abstracts usage of the following syntax:
  #
  #  obj[... some code ...] = ... something ...
  #
  # * We assume that "obj" is used only with [] or []= methods.
  # * The context is entered when ActContextHandler is created
  # * The context is left after [] or []= is called
  # * User specifies handlers for []= and [] calls and for "leaving context" event
  class ActContextHandler
    def initialize(add_act, get_act, leave_ctx)
      @add_act = add_act
      @get_act = get_act
      @leave_ctx = leave_ctx
    end

    def [](category)
      @leave_ctx.call
      @get_act.call(category.respond_to?(:name) ? category.name : category.to_sym)
    end

    def []=(category, act)
      begin
        @add_act.call(category.respond_to?(:name) ? category.name : category.to_sym, act)
      ensure
        @leave_ctx.call
      end
    end
  end

  # Context in Robert is defined by:
  # * Current set of rules
  # * Current rule context (i.e. :something,0,:another,3)
  # * Next acts to be called on call_next
  #
  # Classes that can be treated as contexts should define following methods:
  # * with_rule_ctx
  # * with_rules
  # * with_next_acts
  # * perform method
  #
  # Contexts are passed to defined acts. By using different types of contexts, we can perform variety of tasks
  # with already defined acts. Please see classes that mix Context in for details.
  module Context
    def rule_ctx
      @rule_ctx ||= []
    end

    def next_acts
      @next_acts ||= []
    end

    def clone_and_change(h)
      res = self.clone
      h.each { |k,v| res.instance_variable_set("@#{k}", v) }
      res
    end

    def with_next_act(next_act)
      clone_and_change(:next_acts => (next_act.nil? ? [] : [next_act]))
    end

    def with_next_acts(next_acts)
      clone_and_change(:next_acts => next_acts)
    end

    def with_rule_ctx(ctx_suffix)
      clone_and_change(:rule_ctx => rule_ctx + ctx_suffix)
    end                       
  end

  # RulesDefinitionContext is used to collect all rules defined in the act and its' next acts.
  # Uses RulesDefiner to process rules. Processed rules are added to the supplied rules container.
  class RulesDefinitionContext
    include Context

    def initialize(rule_ctx, rules_container)
      @rule_ctx = rule_ctx
      @rules_evaluator = Object.new.extend(RulesDefiner)

      class << @rules_evaluator; self; end.class_eval do
        attr_accessor :rule_ctx

        define_method :rules do
          rules_container
        end
      end
    end

    def with_rules(&block)
      if block
        @rules_evaluator.rule_ctx = rule_ctx
        @rules_evaluator.instance_eval(&block)
      end
      self
    end

    def rules
      @rules_evalutor.rules
    end

    # Not executing act's block (i.e. - not calling yield) as we only need to process rules (with with_rules).
    def perform(conf)
      next_acts.each { |na| na.call(self) }
    end
  end

  # ExecutionContext omits rules definitions (with_rules is empty). It setups rule_ctx and next_acts,
  # executes the act's body and restores original rule_ctx and next_acts afterwards.
  class ExecutionContext
    include Context

    def initialize(rule_ctx)
      @rule_ctx = rule_ctx
    end

    def with_rules(&block)
      self
    end

    def perform(conf)
      prev_rule_ctx, conf.rule_ctx = conf.rule_ctx, rule_ctx
      prev_next_acts, conf.next_acts = conf.next_acts, next_acts
      prev_ctx, conf.ctx = conf.ctx, self
      begin
        yield conf
      ensure
        conf.rule_ctx, conf.next_acts, conf.ctx = prev_rule_ctx, prev_next_acts, prev_ctx
      end
    end
  end

  # According to "nsub" design, when the nsubbed act is called, Robert will call every act
  # defined in the configuration and will pass NSubContext instance as an argument.
  # NSubContext executes act's body only if current rule_ctx contains the nsub context.
  class NSubContext
    include Context
    
    def initialize(rule_ctx, nsub_ctx)
      @rule_ctx = rule_ctx
      @nsub_ctx = nsub_ctx
    end

    def with_rules(&block)
      self
    end

    def perform(conf, &block)
      fi = rule_ctx.index(@nsub_ctx.first)
      if fi && rule_ctx[fi...(fi + @nsub_ctx.length)] == @nsub_ctx
        execute_further(rule_ctx, next_acts, conf, block)
      else
        perform_further(rule_ctx, next_acts, conf, block)
      end
    end

    private
    def execute_further(rule_ctx, next_acts, conf, block)
      ExecutionContext.new(rule_ctx).with_next_acts(next_acts).perform(conf, &block)
    end

    def perform_further(rule_ctx, next_acts, conf, block)
      next_acts.first.call(self)
    end
  end

   # ContextStateHolder should be mixed into the Class, which instances evaluate acts' functions.
  # It defines call_next and has_next? methods that can be used in actions' definitions.
  module ContextStateHolder
    attr_accessor :ctx, :rule_ctx, :next_acts

    def call_next(*args, &block)
      next_acts.first.call(ctx, *args, &block)
    end

    def has_next?
      !next_acts.empty?
    end
  end

  # ActsContainer is mixed into Configuration class. It adds the support for this kind of syntax:
  #  act[:act_name] = seq(deploy.remote { var[:rule] = 42 },
  #                       nsub(:distinct_name, check.is_running))
  module ActsContainer
    # def ctx_counter_inc
    #   @counter ||= 0
    #   @counter += 1
    # end
    
    def acts
      @acts ||= {}
    end

    # Defines a method for a given name that:
    # * Creates new ExecutionContext for current conf_name (assuming that self responds to .conf_name)
    # * Calls previously defined act with this execution context
    def define_cat_as_method(cat)
      unless respond_to?(cat)
        class << self; self; end.class_eval do
          define_method(cat) do |*args|
            # we can treat this call as execution call only if we're outside of act[]= contruction
            if mm_as_act == 0
              acts[cat].call(ExecutionContext.new([conf_name, cat]), *args)
            else
              method_missing(cat, *args)
            end
          end
        end
      end
    end
    private :define_cat_as_method

    # Defines new act. Everything is handled by ActContextHandler. Not meant to be used without [] or []=
    def act
      ch_mm_as_act(1)
      ActContextHandler.new(->(cat,act){ define_cat_as_method(cat); acts[cat] = act },
                    ->(cat){ acts[cat] },
                    ->{ ch_mm_as_act(-1) })
    end

    # If we're evaluating act syntax, then every unknown identifier is an action. This allows following syntax:
    #  act[:a] = backup.mysql
    #
    # backup.mysql will effectively be evaluated to function (by using fn_act)
    def method_missing(name, *args)
      if mm_as_act > 0
        ActionId.new(name) do |full_name, *args, &block|
          fn_act(full_name, *args, &block)
        end
      else
        super
      end
    end

    # Prepares the function that prepares the context and executes the specified action. The context
    # is prepared by:
    # * adding action name with a counter to the rule context
    # * adding rules, that are defined in the supplied block
    # * setting next_acts to arguments supplied to fn_act
    #
    # The action is executed by using instance_exec and passing all arguments to action's body function
    #
    # Example:
    #  act[:a] = onfail.continue(backup.mysql) { var[:a] = 42 }
    #
    # The example above will return a function that will:
    # * add :backup,:mysql,:0 to rule context
    # * add "var[:a] = 42" to the rules list
    # * set next_acts to the result of "backup.mysql" evaluation
    # * evaluate "onfail.continue" action with the given arguments
    def fn_act(full_name, *next_acts, &block)
#      counter =  ctx_counter_inc
      next_acts = next_acts.compact
      lambda do |ctx, *args|
        ctx.with_rule_ctx([full_name.to_s.split(/\./).map { |s| s.to_sym }].flatten).
          with_rules(&block).
          with_next_acts(next_acts.size > 1 ? [seq(*next_acts)] : next_acts).
          perform(self) { |s| s.instance_exec(*args, &actions.fetch(full_name).body) }
      end
    end

    # Prepares the function that evaluates its arguments sequentially and returns the result
    # combined with +, if possible
    def seq(*args, &block)
      lambda do |ctx, *fargs|
        index = 0
        index_inc = lambda { i = index; index += 1; i }
        args.map { |arg| arg.call(ctx.with_rule_ctx([:seq, index_inc.call]), *fargs) }.compact.inject { |arg, memo| memo.respond_to?(:+) ? arg + memo : nil }
      end
    end

    # Adds support for the following syntax:
    #  act[:a] = some.action(nsub("some_other_action",
    #                             some.other_action))
    #
    # The idea is to add support for explicit naming for parts of the acts defined. In the example above,
    # everything nested inside nsub, can be called by name "some_other_action".
    #
    # Works by defining a method with the given name on self that creates NSubContext and executes
    # all defined acts with this context. Only the needed act will really perform in this case - please
    # see NSubContext for details.
    def nsub(name, nested_fn, &block)
#      counter = ctx_counter_inc
      
      class << self; self; end.class_eval do
        define_method name do
          acts.each do |k,v|
            v.call(NSubContext.new([conf_name], [name.to_sym]))
          end
        end
      end
         
      lambda do |ctx, *args|
        nested_fn.call(ctx.with_rule_ctx([name.to_sym]).with_rules(&block), *args)
      end
    end

    def memo(nested_fn)
      m = {}
      lambda do |ctx, *args|
        m[ctx.class] ||= nested_fn.call(ctx, *args)
      end
    end

    # Act syntax evaluation contet index.
    # For example, in act[:a] = act[:b] = ... some code ..., when "some code" is evaluated, mm_as_act will be 2
    def mm_as_act
      @mm_as_act ||= 0
    end

    def ch_mm_as_act(val)
      @mm_as_act ? @mm_as_act += val : @mm_as_act = val
    end
  end

end
