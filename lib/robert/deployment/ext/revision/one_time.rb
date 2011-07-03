defn revision.session_one_time do
  body {
    @revision_memoized || (@revision_memoized = call_next)
  }
end
