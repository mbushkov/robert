defn revision.from_str do
  body {
    scm_revision_from_str(call_next)
  }
end

