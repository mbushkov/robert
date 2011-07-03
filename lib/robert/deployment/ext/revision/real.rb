defn revision.real do
  body {
    rev = call_next

    logd "querying revision '#{rev}'" #TODO: specify scm here
    real_rev = scm_query_revision(rev, lambda { |cmd| syscmd_output(cmd) })
    logi "real revision: #{real_rev}"

    real_rev.to_s
  }
end

