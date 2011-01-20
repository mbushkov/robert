module Robert
module Deployment

  class RemoteProjectDeployment
    attr_reader :real_revision, :project_root, :revision_root, :deployment_root, :backup_root

    def initialize(real_revision, project_root)
      @project_root = project_root
      @real_revision = real_revision

      @revision_root = File.join(@project_root, @real_revision.to_s)
      @deployment_root = File.join(@revision_root, "dep")
      @backup_root = File.join(@revision_root, "backup")
    end

  end

  class RemoteProjectRepository
    def initialize(project_name, deployment_root)
      @project_name = project_name
      @deployment_root = deployment_root

      @project_root = File.join(@deployment_root, @project_name)
      @installed_rev_fpath = File.join(@project_root, '.installed_rev')
    end

    def [](rev)
      RemoteProjectDeployment.new(rev, @project_root)
    end

  end

end
end
