defn build.persistent_one_time do
  body {
    unless revision_build.built
      call_next
      revision_build.built = true
    end
  }
end

defn build.session_one_time do
  body {
    unless @build_done
      call_next
      revision_build.built = true
    end
    @build_done = true
  }
end

