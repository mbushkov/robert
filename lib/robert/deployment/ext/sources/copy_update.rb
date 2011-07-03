require 'fileutils'

defn sources.copy_update do
  body {
    build_repository.setup!
    rev = build_repository.revisions.select { |r| r != revision && build_repository[r].checked_out }.sort.last
    if rev == nil
      logi "can't find any suitable revision to update. falling back to fresh checkout"
      call_next # will execute checkout due to the 'use' definition in the beginning
    else
      brev = build_repository[revision]
      brev.setup!
      FileUtils.rm_rf(brev.src_path)
      FileUtils.cp_r(build_repository[rev].src_path, brev.src_path)
      scm_sync(revision, brev.src_path)
    end
  }
end
