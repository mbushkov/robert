defn src_patch.copy do
  body {
    FileUtils.rm_rf(revision_build.patched_src_path)
    FileUtils.cp_r(revision_build.src_path, revision_build.patched_src_path)

    call_next if has_next?
  }
end
