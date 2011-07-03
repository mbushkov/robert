defn subversion.head do
  body {
    scm_obj.head
  }
end

defn subversion.checkout do
  body { |revision, destination|
    scm_obj.checkout(revision, destination)
  }
end

defn subversion.sync do
  body { |revision, destination|
    scm_obj.sync(revision, destination)
  }
end

defn subversion.query_revision do
  body { |revision, call_cmd|
    scm_obj.query_revision(revision, &call_cmd)
  }
end

defn subversion.revision_from_str do
  body { |revision_str|
    revision_str.to_i
  }
end

conf :subversion do
  act[:scm_obj] = cap_scm.subversion
  
  act[:scm_head] = subversion.head
  act[:scm_checkout] = subversion.checkout
  act[:scm_sync] = subversion.sync
  act[:scm_query_revision] = subversion.query_revision
  act[:scm_revision_from_str] = subversion.revision_from_str
end

