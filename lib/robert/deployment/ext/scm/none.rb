defn scm_none.head do
  body {
    ""
  }
end

defn scm_none.checkout do
  body { |revision, destination|
    syscmd("#{var[:rsync,:command]} -auSx --delete --stats --temp-dir=/tmp #{var[:scm_none,:repository]}/ #{destination}")
  }
end

defn scm_none.query_revision do
  body { |revision|
    Time.now.to_i
  }
end

defn scm_none.revision_from_str do
  body { |revision_str|
    revision_str.to_i
  }
end

conf :scm_none do
  var[:scm,:name] = "none"

  act[:scm_head] = scm_none.head
  act[:scm_checkout] = scm_none.checkout
  act[:scm_sync] = scm_none.checkout
  act[:scm_query_revision] = scm_none.query_revision
  act[:scm_revision_from_str] = scm_none.revision_from_str
end
