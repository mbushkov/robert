require 'robert/rule'

module Robert
  
  # ExtsDefiner should be mixed into class that should be able to define extensions. Extension
  # is basically a Module with a set of rules. Example of extension definition:
  #  ext :sh do
  #    def syscmd_status(command, output_io = nil, no_log = false)
  #      ...
  #    end
  #  end
  #
  # Extensions can have rules defined inside. Extension does not affect the context of the rule
  # in any way. For example:
  #  ext :log do
  #    var[:log,:level] = 5
  #  end
  #
  #  This extension will define a rule with a context :log,:level (not with, say :log,:log,:level)
  module ExtsDefiner
    def extensions
      @extensions ||= {}
    end

    def ext(name, &block)
      mod = Module.new
      mod.extend(RulesContainer)
      class << mod; self; end.class_eval do
        define_method :rule_ctx do
          []
        end
      end
      mod.module_eval(&block)

      extensions[name.to_sym] = mod
    end
  end

  # ExtsUser should be mixed into class that should use extensions previously defined with ExtsDefiner.
  # To use extension means to call .extend on the caller with extension as an argument (every extension
  # is a module).
  # Example:
  #  conf :core do
  #    use :log, :sh, :temp_file, :capistrano, :s3
  #  end
  module ExtsUser
    def used_extensions
      @used_extensions ||= []
    end

    def use(*exts)
      used_extensions.concat(exts.map { |ename| ename.to_sym })
    end

    def apply_extensions(extensions)
      used_extensions.each { |ename| extend(extensions.fetch(ename)) }
    end
  end
end
