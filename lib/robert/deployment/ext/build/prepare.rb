defn build.prepare do
  body {
    sources
    src_patch
    call_next if has_next?
  }
end
