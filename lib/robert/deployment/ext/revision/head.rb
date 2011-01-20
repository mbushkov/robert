defn revision.head do
  body {
    if scm.nil?
      logd "can't set revision to HEAD as there's no SCM"
      call_next
    end
    scm.head
  }
end
