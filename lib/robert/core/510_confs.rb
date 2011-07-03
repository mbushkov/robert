#NOTE: using string here, as .confs is a call
defn "confs.dump" do
  body {
    puts "dumping configurations"
    $top.confs_names.sort.each do |cname|
      conf = $top.cclone(cname)
      puts "== #{cname}, tags: #{conf.tags.to_a.sort.join(",")}"
      conf.acts.each do |act_name,act|
        puts "  #{act_name}:"
      end
    end
  }
end

conf :confs do
  act[:dump] = act[:list] = confs.dump
end
