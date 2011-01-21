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

  describe ActionId do
    it "delegates calls to the call-later handler" do
      later = flexmock(lambda {})
      later.should_receive(:call).with(:"some_name.some_method", 42).once
    
      act_id = ActionId.new("some_name", &later)
      
      act_id.some_method(42)
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

  describe ActContextHandler do
    before do
      @add, @get, @leave = *0.upto(2).map do
        m = flexmock
        m.should_ignore_missing
        m
      end

      @handler = ActContextHandler.new(@add, @get, @leave)
    end
    
    it "calls leave-context handler after []" do
      @leave.should_receive(:call).once

      @handler[:a]
    end

    it "calls leave-context-handler after []=" do
      @leave.should_receive(:call).once

      @handler[:a] = 42
    end

    it "calls add-handler after []=" do
      @add.should_receive(:call).with(:a, 42).and_return(43).once

      @handler[:a] = 42
    end

    it "calls get-handler and returns its result after []" do
      @get.should_receive(:call).with(:a).and_return(42).once

      res = @handler[:a]

      res.should == 42
    end

    it "uses .name method for [] or []= argument, if possible" do
      @get.should_receive(:call).with(:another_name).once

      @handler[flexmock(:name => :another_name)]
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

  describe NSubContext do
    before do
      @conf = flexmock
    end
    
    it "does not perform if nsub_ctx is not a subpart of rule_ctx" do
      nsub = flexmock(NSubContext.new([:a, :b, :c], [:nsub]))

      nsub.should_receive(:perform_further)
      nsub.should_receive(:execute_further).never

      nsub.perform(@conf)
    end

    it "does not perform if only part of nsub_ctx is present in rule_ctx" do
      nsub = flexmock(NSubContext.new([:a, :b, :c, :nsub], [:nsub, :nsub_next]))

      nsub.should_receive(:perform_further)
      nsub.should_receive(:execute_further).never

      nsub.perform(@conf)
    end

    it "does perform if nsub_ctx is a subpart of rule_ctx" do
      nsub = flexmock(NSubContext.new([:a, :b, :c, :nsub, :nsub_next], [:nsub, :nsub_next]))

      nsub.should_receive(:perform_further)
      nsub.should_receive(:execute_further).once

      nsub.perform(@conf)
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
              acts[cat].call(ExecutionContext.new([conf_name]), *args)
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
      counter =  $top.ctx_counter_inc
      next_acts = next_acts.compact
      lambda do |ctx, *args|
        ctx.with_rule_ctx([full_name.to_s.split(/\./).map { |s| s.to_sym }, counter].flatten).
          with_rules(&block).
          with_next_acts(next_acts.size > 1 ? [seq(*next_acts)] : next_acts).
          perform(self) { |s| s.instance_exec(*args, &actions.fetch(full_name).body) }
      end
    end

    # Prepares the function that evaluates its arguments sequentially and returns the result
    # combined with +, if possible
    def seq(*args, &block)
      lambda do |ctx, *fargs|
        args.map { |arg| arg.call(ctx, *fargs) }.compact.inject { |arg, memo| memo.respond_to?(:+) ? arg + memo : nil }
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
      counter = $top.ctx_counter_inc
      
      class << self; self; end.class_eval do
        define_method name do
          acts.each do |k,v|
            v.call(NSubContext.new([conf_name], [name.to_sym, counter]))
          end
        end
      end
         
      lambda do |ctx, *args|
        nested_fn.call(ctx.with_rule_ctx([name.to_sym, counter]).with_rules(&block), *args)
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

  describe ActsContainer do
    before do
      @ac = flexmock(Object.new.extend(ActsContainer))
    end

    it "allows to define act with []= notation" do
      fn = ->{}
      @ac.instance_eval do
        act[:name] = fn
      end

      @ac.acts[:name].should equal(fn)
    end

    it "returns defined act with [] notation" do
      fn = ->{}
      fn2 = nil
      @ac.instance_eval do
        act[:name] = fn
        fn2 = act[:name]
      end
      fn2.should equal(fn)
    end

    it "allows to define multiple acts with []= and [] notation" do
      fn = ->{}
      fn1 = nil
      fn2 = nil
      @ac.instance_eval do
        act[:name1] = act[:name2] = fn
        fn1 = act[:name1]
        fn2 = act[:name2]
      end

      fn1.should equal(fn)
      fn2.should equal(fn)
    end

    it "defines method on self when act is defined" do
      @ac.instance_eval do
        act[:some_act] = ->{}
      end

      @ac.should respond_to(:some_act)
    end

    it "defines act with fn_act when non-predefined methods are called" do
      @ac.should_receive(:fn_act).with(:"backup.mysql").once

      @ac.instance_eval do
        act[:some_act] = backup.mysql
      end
    end
  end

  describe ActsContainer, "acts execution" do
    before do
      @prev_top, $top = $top, flexmock(:ctx_counter_inc => 0)

      @ctx = flexmock
      @ctx.should_receive(:with_rule_ctx).and_return(@ctx).by_default
      @ctx.should_receive(:with_rules).and_return(@ctx).by_default
      @ctx.should_receive(:with_next_acts).and_return(@ctx).by_default
      @ctx.should_receive(:perform).by_default

      @ac = flexmock(Object.new.extend(ActsContainer))
    end

    after do
      $top = @prev_top
    end
    
    it "defined act adds its name and counter to rule_ctx before execution" do
      @ac.instance_eval do
        act[:some_act] = backup.mysql
      end

      @ctx.should_receive(:with_rule_ctx).with([:backup, :mysql, 0]).and_return(@ctx).once
      
      @ac.acts[:some_act].call(@ctx)
    end

    it "defined act sets next act before execution" do
      fn = flexmock
      @ac.instance_eval do
        act[:some_act] = onfail.continue(fn)
      end

      @ctx.should_receive(:with_next_acts).with([fn]).and_return(@ctx).once

      @ac.acts[:some_act].call(@ctx)
    end

    it "defined act sets multiple next acts by grouping them with seq() before execution if needed" do
      fn1 = flexmock
      fn2 = flexmock
      fn_seq = flexmock

      @ac.instance_eval do
        act[:some_act] = onfail.continue(fn1, fn2)
      end

      @ac.should_receive(:seq).with(fn1, fn2).and_return(fn_seq)
      @ctx.should_receive(:with_next_acts).with([fn_seq]).and_return(@ctx).once

      @ac.acts[:some_act].call(@ctx)
    end

    it "defined act evaluates rules with with_rules before execution" do
      @ac.instance_eval do
        act[:some_act] = backup.mysql { var[:a] = 42 }
      end

      @ctx.should_receive(:with_rules).with(Proc).and_return(@ctx).once

      @ac.acts[:some_act].call(@ctx)
    end

    it "defined act calls .perform on execution" do
      @ac.instance_eval do
        act[:some_act] = backup.mysql
      end

      @ctx.should_receive(:perform).with(@ac, Proc).once

      @ac.acts[:some_act].call(@ctx)
    end
  end

  describe ActsContainer, "nsub handling" do
    before do
      @prev_top, $top = $top, flexmock(:ctx_counter_inc => 0)
      @ac = flexmock(Object.new.extend(ContextStateHolder).extend(ActsContainer))
    end

    it "defines a separate method for nsubbed subact" do
      @ac.instance_eval do
        act[:some_act] = onfail.continue(nsub(:failable_backup,
                                              backup.mysql))
      end

      @ac.should respond_to(:failable_backup)
    end

    it "calls only the needed subact when nsubbed method is called" do
      @ac.instance_eval do
        act[:some_act] = onfail.continue(nsub(:failable_backup,
                                              backup.mysql))
      end

      ac = @ac
      @ac.should_receive(:conf_name).and_return(:conf_name)
      @ac.should_receive(:actions).and_return({:"onfail.continue" => flexmock(:body => ->{ ac.onfail_continue }),
                                                :"backup.mysql" => flexmock(:body => ->{ ac.backup_mysql }) })
      @ac.should_receive(:onfail_continue).never
      @ac.should_receive(:backup_mysql).once

      @ac.failable_backup
    end

  end

end
