defn dist_patch.copy do
  body {
    FileUtils.rm_rf(revision_build.patched_dist_path)
    FileUtils.cp_r(revision_build.dist_path, revision_build.patched_dist_path)

    call_next if has_next?
  }
end
