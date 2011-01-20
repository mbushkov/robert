#NOTE: using string here, as .confs is a call
defn "confs.dump" do
  body {
    puts "dumping configurations"
    $top.confs_names.sort.each do |cname|
      conf = $top.cclone(cname)
      puts "== #{cname}, tags: #{conf.tags.to_a.sort.join(",")}"
    end
  }
end

conf :confs do
  act[:dump] = act[:list] = confs.dump
end

