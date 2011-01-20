require 'fileutils'

defn sources.copy_update do
  body {
    build_repository.setup!
    rev = build_repository.revisions.select { |r| build_repository[r].checked_out }.sort { |r1, r2| File.new(build_repository[r1].project_root).mtime > File.new(build_repository[r2].project_root).mtime }.first
    if rev == nil
      logi "can't find any suitable revision to update. falling back to fresh checkout"
      call_next # will execute checkout due to the 'use' definition in the beginning
    else
      brev = build_repository[revision]
      brev.setup!
      FileUtils.rm_rf(brev.src_path)
      FileUtils.cp_r(build_repository[rev].src_path, brev.src_path)
      syscmd scm.sync(revision, brev.src_path)
    end
  }
end
