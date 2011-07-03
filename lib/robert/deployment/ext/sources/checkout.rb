defn sources.checkout do
  body {
    brev = build_repository[revision]

    brev.setup!
    scm_checkout(revision, brev.src_path)

    call_next if has_next?
  }
end
