defn build.copy do
  body {
    call_next if has_next?
    
    brev = revision_build
    FileUtils.rm_rf(brev.dist_path)
    FileUtils.cp_r(brev.patched_src_path, brev.dist_path)
  }
end
