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

    def eval_rule_steps(ctx)
      step1 = rules_hash[ctx.last].map { |r| r.match(ctx) && r }.compact.select { |r| r.overriden_by.nil? }
      if step1.empty?
        err_msg = "no suitable rule found: #{ctx.join(',')}"
        err_msg += " (#{$!})" if $!
        raise NoSuitableRuleFoundError, err_msg
      end
      
      rules_with_ctx_first_token = step1.select { |r| r.context.first == ctx.first }
      step2 = rules_with_ctx_first_token.empty? ? step1 : rules_with_ctx_first_token

      step3 = step2.inject do |a,b|
        ac, bc = a.context, b.context
        raise "internal logic error: rules should be different #{ac.join(",")} #{bc.join(",")}" if ac == bc

        diff_elm = [ac.length, bc.length].max.times do |i|
          break i if ac[ac.length - i - 1] != bc[bc.length - i - 1]
        end
        if ac[diff_elm] && bc[diff_elm]
          ctx.rindex(bc[bc.length - diff_elm - 1]) > ctx.rindex(ac[ac.length - diff_elm - 1]) ? b : a
        else
          b
        end
      end

      [step1, step2, step3]
    end

    def eval_rule(ctx, eval_ctx)
      match_rule = eval_rule_steps(ctx)[2]
      match_rule.value.respond_to?(:call) ? eval_ctx.instance_exec(&match_rule.value) : match_rule.value
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
      return if block_given?
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
