defn sources.checkout do
  body {
    brev = build_repository[revision]

    brev.setup!
    command = scm_checkout(revision, brev.src_path)

    syscmd(command)

    call_next if has_next?
  }
end
