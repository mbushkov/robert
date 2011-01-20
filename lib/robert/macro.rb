module Robert
  class MacroContextHandler
    def initialize(add_macro, get_macro, leave_ctx)
      @add_macro = add_macro
      @get_macro = get_macro
      @leave_ctx = leave_ctx
    end

    def [](category)
      @leave_ctx.call
      @get_macro.call(category.respond_to?(:name) ? category.name : category)
    end

    def []=(category, macro)
      begin
        @add_macro.call(category.respond_to?(:name) ? category.name : category, macro)
      ensure
        @leave_ctx.call
      end
    end
  end

  module MacroDefiner
    def macros
      @macros ||= {}
    end

    def macro
      ch_mm_as_macro(1)
      MacroContextHandler.new(->(cat,macro){ macros[cat] = macro },
                    ->(cat){ macros_storage[cat] },
                    ->{ ch_mm_as_macro(-1) })
    end

    def mm_as_macro
      @mm_as_macro ||= 0
    end

    def ch_mm_as_macro(val)
      @mm_as_macro ? @mm_as_macro += val : @mm_as_macro = val
    end

    def method_missing(name, *args)
      if macros.key?(name)
        macros[name].call(*args)
      else
        super
      end
    end
  end
end
