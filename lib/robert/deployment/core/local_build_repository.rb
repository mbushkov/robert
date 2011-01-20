require "robert/deployment/utils/file_flag"

module Robert
module Deployment

class LocalProjectBuild
  attr_reader :real_revision, :project_root
  attr_reader :src_path, :patched_src_path, :dist_path, :patched_dist_path
  attr_reader :checked_out, :src_patched, :built, :dist_patched

  def initialize(real_revision, project_root)
    @project_root = project_root      
    @real_revision = real_revision

    @revision_root = File.join(@project_root, @real_revision.to_s)
    @src_path = File.join(@revision_root, "src")
    @patched_src_path = File.join(@revision_root, "src_patched")
    @dist_path = File.join(@revision_root, "dist")
    @patched_dist_path = File.join(@revision_root, "dist_patched")

    @checked_out_fflag = FileFlag.new(File.join(@revision_root, ".checked_out"))
    @src_patched_fflag = FileFlag.new(File.join(@revision_root, ".src_patched"))
    @built_fflag = FileFlag.new(File.join(@revision_root, ".built"))
    @dist_patched_fflag = FileFlag.new(File.join(@revision_root, ".dist_patched"))

    [:checked_out, :src_patched, :built, :dist_patched].each do |flag|
      class << self
        self
      end.instance_eval do
        attr_reader "#{flag}_fflag".to_sym

        define_method(flag) do
          instance_variable_get("@#{flag}_fflag").installed
        end

        define_method("#{flag}=") do |val|
          instance_variable_get("@#{flag}_fflag").installed = val
        end
      end

    end        
  end

  def files
    raise RuntimeError, "can't get the list of files, as project was not built" unless dist_patched
    Dir[File.join(@patched_dist_path, "**")]
  end

  def setup?
    [@src_path, @patched_src_path, @dist_path, @patched_dist_path].each do |path|
      return false unless File.directory? path
    end
    true
  end

  def setup!
    [@src_path, @patched_src_path, @dist_path, @patched_dist_path].each do |path|
      FileUtils.mkdir_p path
    end
  end

  def remove!
    FileUtils.rm_rf(@revision_root)
  end

end

class LocalProjectRepository
  attr_reader :project_name, :build_root, :project_root

  def initialize(project_name, build_root)
    @project_name = project_name
    @build_root = build_root
    @project_root = File.join(@build_root, @project_name)
    @revisions = {}
  end

  def [](real_rev)
    raise ArgumentError, "revision must be a string" unless real_rev.respond_to?(:length)
    raise ArgumentError, "revision can't be nil" if real_rev.nil?

    return @revisions[real_rev] if @revisions.key? real_rev 
    lpb = LocalProjectBuild.new(real_rev, @project_root)
    @revisions[real_rev] = lpb
  end

  def revisions
    @revisions.keys.sort
  end

  def revision?(rev)
    @revisions.key? rev
  end

  def setup?
    File.directory? @project_root
  end

  def setup!
    FileUtils.mkdir_p @project_root
  end

  def remove_outdated(builds_limit)
    if @revisions.size > builds_limit
      @revisions.keys.sort[0..-(builds_limit + 1)].each do |rev|
        @revisions.delete(rev).remove!
      end
    end
  end

  def sync
    revisions.clear
    Dir[File.join(@project_root, "*")].each do |dir|
      self[File.basename(dir)] if File.directory? dir
    end
    self
  end
end

end
end
