require "fileutils"

module Robert
module Deployment
  
  class FileFlag
    attr_reader :path
    
    def initialize(path)
      @path = path
    end
    
    def installed
      check_file
    end
    alias_method :installed?, :installed
    
    def installed=(flag)
      if flag
        touch_file
      else
        erase_file
      end
    end
    
    protected
    def check_file
      File.exists? @path
    end
    
    def touch_file
      FileUtils.touch @path
    end
  
    def erase_file
      FileUtils.rm_f @path
    end
  end
    
  def exec_unless_file(path)
    ff = FileFlag.new(path)
    return false if ff.installed?
    
    yield
    ff.installed = true
    return true
  end
  module_function :exec_unless_file

end
end
