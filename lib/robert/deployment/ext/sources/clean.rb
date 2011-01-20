defn sources.clean do
  body {
    brev = build_repository[revision]
    FileUtils.rm_r brev.src_path, :force => true, :secure => true
    brev.setup!
    
    call_next if has_next?
  }
end
