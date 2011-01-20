defn sources.persistent_one_time do
  body {
    unless revision_build.checked_out
      call_next
      revision_build.checked_out = true
    end
  }
end

defn sources.session_one_time do
  body {
    unless @sources_done
      call_next
      revision_build.checked_out = true
    end
    @sources_done = true
  }
end

