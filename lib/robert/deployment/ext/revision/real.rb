defn revision.real do
  body {
    rev = call_next

    logd "querying revision '#{rev}' from #{var[:scm,:name]}"
    real_rev = scm_query_revision(rev)
    logi "real revision: #{real_rev}"

    real_rev.to_s
  }
end

