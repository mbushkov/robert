module Robert

  class Rule
    attr_reader :context, :value
    attr_accessor :overriden_by

    def initialize(context, value)
      @context, @value = context, value
    end

    def match(ctx)
      return nil if @overriden_by
      return nil if ctx.last != context.last

      offset = 0
      i = ctx.length
      context.reverse_each do |elm|
        if i = ctx[0...i].rindex(elm)
          offset += 1
        else
          return nil
        end
      end
      offset
    end
  end

  describe Rule do
    it "does not match if marked overriden" do
      rule = Rule.new([:a, :b], 42)
      rule.overriden_by = Rule.new([:b], 43)

      rule.match([:a, :b]).should be_nil
    end

    it "does not match if the last token of the rule is different from the last token of the context" do
      Rule.new([:a, :b], 42).match([:a, :c]).should be_nil
    end

    it "returns nil if the rule is not fully contained inside the context" do
       Rule.new([:a, :b], 42).match([:b]).should be_nil
    end

    it "returns nil if the rule's tokens are contained inside the context in different order" do
      Rule.new([:a, :b], 42).match([:b, :a]).should be_nil
    end

    it "returns index of the match of the first rule's token inside the context" do
      Rule.new([:a, :b], 42).match([:c, :d, :a, :b]).should == 2
      Rule.new([:a, :b], 42).match([:a, :b, :a, :b]).should == 2
    end
    
    it "works correctly in a series of real-world cases" do
      Rule.new([:Project, :backup, :continue, 1, :email, 1, :s3, 1, :www_dump, 0, :role], 42).match([:Project,:backup,:continue,1,:email,1,:s3,1,:www_dump,0,:continue,0,:email,0,:s3,0,:base,:s3,0,:capistrano,0,:role]).should_not be_nil
      Rule.new([:Project, :role_www], 42).match([:Project,:backup,:onfail,:continue,0,:notify,:email,0,:rsync,0,:role_www]).should_not be_nil
      Rule.new([:ssh,:authorized_keys,:public_key_path], 42).match([:Project,:backup,:onfail,:continue,0,:notify,:email,0,:rsync,0,:ssh,:public_key_path]).should be_nil
      Rule.new([:localhost,:check,:onfail,:continue,0,:notify,:campfire,1,:failure,:message], 42).match([:localhost,:check,:onfail,:continue,0,:notify,:campfire,1,:failure,:notify,:campfire,1,:message]).should_not be_nil
    end
  end

  class RuleStorage
    class NoSuitableRuleFoundError < RuntimeError; end

    attr_reader :rules, :rules_hash

    def initialize
      @rules = []
      @rules_hash = Hash.new { |h,k| h[k] = [] }
    end

    include Enumerable
    def each(&block)
      @rules.each(&block)
    end

    def add(rule, ctx_prefix = [])
      raise ArgumentError, "context can't include nil: #{rule.context.inspect}" if rule.context.include?(nil)

      new_rule = Rule.new(ctx_prefix + rule.context, rule.value)
      rules_hash[new_rule.context.last].each { |r| r.overriden_by = new_rule if new_rule.match(r.context) }
      rules << new_rule
      rules_hash[new_rule.context.last] << new_rule
    end
    alias_method :<<, :add

    def add_all(rules)
      rules.each { |r| add(r) }
    end

    def eval_rule(ctx, eval_ctx)
      bestm = rules_hash[ctx.last].map { |r| r.match(ctx) && r }.compact.inject do |a,b|
        ac, bc = a.context, b.context
        next a if ctx[(-ac.length)..-1] == ac and ctx[(-bc.length)..-1] != bc and (!a.match(bc))
        next b if ctx[(-ac.length)..-1] != ac and ctx[(-bc.length)..-1] == bc and (!b.match(ac))

        if ac.first != bc.first
          next a if ac.first == ctx.first
          next b if bc.first == ctx.first
        end
        
        raise "internal logic error: rules should be different #{ac.join(",")} #{bc.join(",")}" if ac == bc
        diff_elm = [ac.length, bc.length].max.times do |i|
          break i if ac[ac.length - i - 1] != bc[bc.length - i - 1]
        end
        if ac[diff_elm] && bc[diff_elm]
          ctx.rindex(bc[bc.length - diff_elm - 1]) > ctx.rindex(ac[ac.length - diff_elm - 1]) ? b : a
        else
          ac.length > bc.length ? a : b
        end
      end

      unless bestm
        err_msg = "no suitable rule found: #{ctx.join(',')}"
        err_msg += " (#{$!})" if $!
        raise NoSuitableRuleFoundError, err_msg
      end
      bestm.value.respond_to?(:call) ? eval_ctx.instance_exec(&bestm.value) : bestm.value
    end
  end

  describe RuleStorage do
    before do
      @storage = RuleStorage.new
    end

    def add_rule(ctx, val)
      @storage << Rule.new(ctx, val)
    end

    it "raises when no rules match" do
      add_rule([:a,:b,:c], 42)
      add_rule([:a,:b,:c], 43)
      add_rule([:a,:b,:c], 44)

      ->{ @storage.eval_rule([:a, :c, :d], self)}.should raise_exception(RuleStorage::NoSuitableRuleFoundError)
    end

    it "last rule of equal rules winds" do
      add_rule([:a,:b,:c], 42)
      add_rule([:a,:b,:c], 43)
      add_rule([:a,:b,:c], 44)

      @storage.eval_rule([:a,:b,:c], self).should == 44
    end

    it "more precise rule can be later overriden by more generic one" do
      add_rule([:a,:b,:d], 42)
      add_rule([:a,:d], 43)

      @storage.eval_rule([:a,:b,:c,:d], self).should == 43
    end

    it "more precise rule can be later overriden by more generic one" do
      add_rule([:a,:b,:d], 42)
      add_rule([:b,:d], 43)

      @storage.eval_rule([:a,:b,:c,:d], self).should == 43
    end

    it "more precise rule can be later overriden by more generic one" do
      add_rule([:Project,:email,:to], 42)
      add_rule([:email,:to], 43)

      @storage.eval_rule([:Project,:backup,:email,:to], self).should == 43
    end

    it "more generic rule does not override more precise one if last elements don't match" do
      add_rule([:ec2,:home,:bin], 42)
      add_rule([:ec2,:home], 43)

      @storage.eval_rule([:ec2,:home,:bin], self).should == 42
    end

    it "among matched rules one with the first different element, which match is closer to the right boerder of the context, wins" do
      add_rule([:backup,:remote_host_file,:dir], 42)
      add_rule([:backup,:same_host_file,:dir], 43)

      @storage.eval_rule([:Project,:backup,:same_host_file,:remote_host_file,0,:dir], self).should == 42
    end

    it "among matched rules one with the first different element, which match is closer to the right boerder of the context, wins" do
      add_rule([:backup,:remote_host_file,:dir], 42)
      add_rule([:backup,:same_host_file,:dir], 43)

      @storage.eval_rule([:Project,:backup,:same_host_file,:dir,:remote_host_file,0,:dir], self).should == 42
    end

    it "among matched rules one with the first different element, which match is closer to the right boerder of the context, wins" do
      add_rule([:Project,:process,:backup,:remote_host_file,:dir], 42)
      add_rule([:Project,:action,:backup,:same_host_file,:dir], 43)

      @storage.eval_rule([:Project,:action,:process,:backup,:same_host_file,:dir,:remote_host_file,0,:dir], self).should == 42
    end

    it "among matched rules one with the first different element, which match is closer to the right boerder of the context, wins" do
      add_rule([:Project,:process,:a,:backup,:remote_host_file,:dir], 42)
      add_rule([:Project,:action,:b,:backup,:same_host_file,:dir], 43)

      @storage.eval_rule([:Project,:action,:process,:b,:a,:backup,:same_host_file,:dir,:remote_host_file,:dir], self).should == 42
    end

    it "among matched rules one with the first different element, which match is closer to the right boerder of the context, wins" do
      add_rule([:Project,:backup,:rsync,0,:to], 42)
      add_rule([:notify,:email,:to], 43)

      @storage.eval_rule([:Project,:backup,:onfail,:continue,0,:notify,:email,0,:rsync,0,:to], self).should == 42
    end

    it "among matched rules one with the first different element, which match is closer to the right boerder of the context, wins" do
      add_rule([:a,:c], 42)
      add_rule([:a,:b,:c], 43)

      @storage.eval_rule([:a,:b,:a,0,:c], self).should == 42
    end

    it "among matched rules one with the first different element, which match is closer to the right boerder of the context, wins" do
      add_rule([:email, :to], 42)
      add_rule([:rsync, :to], 43)

      @storage.eval_rule([:Project,:continue,:email,:rsync,:to], self).should == 43
    end

    it "among matched rules the one, where first element matches first context element, wins" do
      add_rule([:s3,:base,:acl], 42)
      add_rule([:Project,:s3,:acl], 43)

      @storage.eval_rule([:Project,0,:s3,:sync_with_md5_check,0,:base,:temp_fname_support,0,:s3,:bucket,0,:base,0,:acl], self).should == 43
    end

    it "among matched rules the one, where first element matches first context element, wins" do
      add_rule([:db,:mysql,:check,:quick], 42)
      add_rule([:Project,:backup,:db_check,0,:quick], 43)

      @storage.eval_rule([:Project,:backup,:onfail,:continue,0,:notify,:email,0,:db_check,0,:db,:mysql,1,:check,:quick], self).should == 43
    end

    it "more generic rule overrides previous more concrete one" do
      add_rule([:localhost,:host,:user], 42)
      add_rule([:mysql,:user], 43)

      @storage.eval_rule([:localhost,:host,:backup,0,:mysql,:user], self).should == 43
    end

    it "more generic rule does not override next more concrete one" do
      add_rule([:a,:c], 42)
      add_rule([:a,:b,:c,:a,:c], 43)

      @storage.eval_rule([:a,:b,:c,:a,0,:c], self).should == 43
    end

    it "more generic rule does not override next more concrete one" do
      add_rule([:a,:c], 42)
      add_rule([:a,:b,:a,:c], 43)

      @storage.eval_rule([:a,:b,:a,0,:c], self).should == 43
    end

    it "NOTE: potential cause of problems - generic rules may unexpectedly match" do
      add_rule([:backup,:db_hotcopy,:suffix], 42)

      @storage.eval_rule([:Project,:backup,:onfail,:continue,0,:notify,:email,0,:db_hotcopy,0,:db,:mysql,1,:hotcopy,:suffix], self).should_not be_nil
    end
  end

  module RulesEvaluator
    class RuleId
      def initialize(&block)
        @get_rule = block
      end

      def [](*ctx)
        @get_rule.call(ctx)
      end
    end
    
    def var(*args)
      if args.empty?
        RuleId.new do |ctx|
          rules.eval_rule((@rule_ctx_override || rule_ctx) + ctx, self)
        end
      else
        rules.eval_rule((@rule_ctx_override || rule_ctx) + args, self)
      end
    end

    def var?(*args)
      protected_eval = lambda { |ctx|
        begin
          rules.eval_rule(rule_ctx + ctx, self)
        rescue RuleStorage::NoSuitableRuleFoundError => e
          nil
        end
      }
      if args.empty?
        RuleId.new(&protected_eval)
      else
        protected_eval.call(args)
      end
    end
  end

  module RulesDefiner
    class RuleId
      def initialize(&block)
        @add_rule = block
      end

      def []=(*ctx, value)
        @add_rule.call(ctx, value)
      end
    end

    def var(*args, &block)
      if args.empty?
        RuleId.new do |ctx, value|
          rules << Rule.new((@rule_ctx_override || rule_ctx) + ctx, value)
        end
      else
        rules << Rule.new((@rule_ctx_override || rule_ctx) + args, block)
      end
    end

    def var?(*args)
      raise "can't set rule with var? "
    end

    def with_rule_ctx(*args)
      #TODO: better implementation needed. this is not flexible
      prev_rule_ctx_override = @rule_ctx_override
      @rule_ctx_override = rule_ctx + args
      begin
        yield
      ensure
        @rule_ctx_override = prev_rule_ctx_override
      end
    end    
  end

  module RulesContainer
    include RulesDefiner

    def rules
      @rules ||= []
    end
  end

  module RulesStorageContainer
    include RulesDefiner

    def rules
      @rule_storage ||= RuleStorage.new
    end

    def reset_rules
      prev_rules = rules
      @rule_storage = nil
      prev_rules
    end
  end
end
