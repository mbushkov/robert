defn build.sh do
  body {
    Dir.chdir(revision_build.patched_src_path) do
      syscmd(var[:cmd])
    end
  }
end
