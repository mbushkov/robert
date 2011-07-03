require 'robert/deployment/core/local_build_repository'
require 'robert/deployment/core/remote_deployment_repository'
require 'robert/deployment/core/deployment_list'

conf :deployable do
  tags << :deployable
  
  var[:local,:build,:repository] = "/usr/local/robert2/build"
  var[:remote,:deployment,:repository] = "/usr/local/robert2/dep"

  def area
    @area ||= Robert::Deployment::Area.find_or_create_by_name(var[:deployment,:area])
  end

  def snapshot
    if sid = var?[:deployment,:sid]
      Robert::Deployment::Snapshot.find_by_id(sid)
    else
      area.current_snapshot
    end
  end
  
  def build_repository
    unless @build_repository
      @build_repository = Robert::Deployment::LocalProjectRepository.new(conf_name.to_s,
                                                                         var[:local,:build,:repository],
                                                                         lambda { |rev_str| self.scm_revision_from_str(rev_str) })
      @build_repository.sync
    end
    @build_repository
  end

  def deployment_repository
    @deployment_repository ||= Robert::Deployment::RemoteProjectRepository.new(conf_name.to_s, var[:remote,:deployment,:repository] )
  end

  def revision_build
    build_repository[revision]
  end

  def revision_deployment
    deployment_repository[revision]
  end

  act[:scm] = dummy.required
  act[:revision] = revision.real(revision.head)
  act[:sources] = sources.copy_update(sources.checkout)
  act[:src_patch] = src_patch.copy
  act[:dist_patch] = dist_patch.copy(dist_patch.link_scripts)
  act[:runtime_dependencies] = runtime_dependencies.explicit { var[:list] = [] }
  act[:deployment_list] = deployment_list.empty
end

conf :area do
end

conf :base_after do
  if tags.include?(:deployable)
    act[:revision] = revision.session_one_time(revision.from_str(act[:revision]))
    act[:build] = build.prepare(act[:build])
  end
end

