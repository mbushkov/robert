require 'robert/rule'

module Robert

  # Action is the smallest piece of functionaly in Robert. It's defined by:
  # * name
  # * corresponding rules
  # * body - that performs the actual work
  # * spec - the rspec-like test for the action
  #
  # Actions are defined by ActionsContainer::defn
  class Action
    def initialize(name, rules, body, spec)
      @name = name
      @rules = rules
      @body = body
      @spec = spec
    end

    def lname
      name.to_s.split(/\./)[0].to_sym
    end

    def rname
      (result = name.to_s.split(/\./)[1]) && result.to_sym
    end

    attr_reader :name, :rules, :body, :spec
  end

  # ActionBuilder provides a context for action's definition DSL
  class ActionBuilder
    include RulesContainer

    def initialize(name, ctx)
      @name = name
      @ctx = ctx
    end

    def rule_ctx
      @ctx
    end

    def body(&block)
      @body = block
    end

    def spec(&block)
      @spec = block
    end

    def result_action
      Action.new(@name, rules, @body, @spec)
    end
  end

  # ActionsContainer is ought to be mixed into classes that support actions definitions.
  # Example of action definition:
  #  defn onfail.tryagain do
  #    var(:max_tries) { 1024 }
  #    var(:pause) { 0 }
  #    
  #    body do |*args|
  #      tries = 0
  #      begin
  #        call_next(*args)
  #      rescue => e
  #        tries += 1
  #        if tries < var[:max_tries]
  #          loge "#{e} happened #{tries} times, sleeping for #{var[:pause]}s, then retrying"
  #          sleep(var[:pause])
  #          retry
  #        else
  #          logf "#{e} happened #{tries} times, exceeding maximum tries limit (#{var[:max_tries]}), failing"
  #          raise
  #        end
  #      end
  #    end
  #  end
  module ActionsContainer
    def actions
      @actions ||= {}
    end

    def defn(id, &block)
      ab = ActionBuilder.new(id, [:*, id.to_s.split(/\./).map { |s| s.to_sym }, :*].flatten)
      ab.instance_eval(&block)
      actions[id.to_sym] = ab.result_action
    end    
  end

end
