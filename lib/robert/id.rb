module Robert
  module MethodMissingAsId
    class IdLeftPart
      def initialize(lname)
        @lname = lname
      end

      def method_missing(rname)
        :"#{@lname}.#{rname}"
      end

      def to_sym
        @lname.to_sym
      end

      def to_s
        @lname.to_s
      end
    end

    def method_missing(*args, &block)
      if @mm_for_id && args.size == 1
        IdLeftPart.new(args.first)
      else
        super
      end
    end

    attr_accessor :mm_for_id
  end
end
