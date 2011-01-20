module Robert
module Deployment
  
  class DeploymentList
    attr_reader :directories, :files, :links
    
    def initialize
      @directories = []
      @files = []
      @links = []
    end
    
    def directory(src, dest, options = {})
      raise RuntimeError, "directory source path must be relative" if src =~ /^\//
      raise RuntimeError, "directory destination path must be absolute" unless dest =~ /^\//
      @directories << [src, dest, options]
    end
    
    def file(src, dest, options = {})
      raise RuntimeError, "file source path must be relative" if src =~ /^\//
      raise RuntimeError, "file destination path must be absolute" unless dest =~ /^\//
      @files << [src, dest, options]
    end
    
    def link(src, dest, options = {})
      raise RuntimeError, "link source path must be absolute" unless src =~ /^\//
      raise RuntimeError, "link destination path must be absolute" unless dest =~ /^\//
      @links << [src, dest, options]
    end
    
    def +(list)
      result = self.clone
      result.directories.concat(list.directories)
      result.files.concat(list.files)
      result.links.concat(list.links)
      result
    end
  end
  
end
end
