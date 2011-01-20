defn revision.real do
  body {
    rev = call_next

    logd "querying revision '#{rev}' from #{scm}"
    real_rev = scm.query_revision(rev) { |cmd| syscmd_output(cmd) }
    logi "real revision: #{real_rev}"

    real_rev.to_s
  }
end

