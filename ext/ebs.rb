#ext :ec2 do
#  var[:home] = lambda { "/usr/local/ec2" }
#  var[:home,:bin] = lambda { "#{var[:ec2,:home]}/bin" }
#
#  def ec2cmd(cmd, *args)
#    "#{var[:home,:bin]}/#{cmd} -C #{var[:cert]} -K #{var[:pk]} #{args.join(" ")}"
#  end
#  private :ec2cmd
#
#  def ec2env
#    {:env => {"EC2_HOME" => var[:home], "JAVA_HOME" => var[:java,:home]}}
#  end
#  private :ec2env
#
#  def create_snapshot
#    syscmd("#{ec2cmd('ec2-create-snapshot', conf_name)}", ec2env)
#  end
#
#  def all_snapshots
#    var[:role] = lambda { :host }
#    snapshots_descr = capture("#{ec2cmd('ec2-describe-snapshots')}", ec2env)
#    result = snapshots_descr.lines.map do |l|
#      fields = l.chomp.split(/\t/)
#      {:snapshot_id => fields[1], :volume_id => fields[2], :state => fields[3], :timestamp => fields[4], :completion => fields[5], :size => fields[6], :owner_id => fields[7], :description => fields[8]}
#    end
#    logd "all snapshots:"
#    result.each do |r|
#      r.each { |k,v| logd "\t#{k}=#{v}"}
#      logd ""
#    end
#    result
#  end
#
#  def describe_snapshots
#    snaps = all_snapshots.select { |s| s[:volume_id] == conf_name.to_s }
#    logd "snapshots for #{conf_name}:"
#    snaps.each do |s|
#      s.each { |k,v| logd "\t#{k}=#{v}"}
#      logd ""
#    end
#    snaps
#  end
#
#  def delete_snapshot(snapshot_id)
#    var[:role] = lambda { :host }
#    run "#{ec2cmd("ec2-delete-snapshot", snapshot_id)}", ec2env
#  end
#
#  def limit_snapshots
#    snaps = describe_snapshots.sort { |a,b| DateTime.parse(b[:timestamp]) <=> DateTime.parse(a[:timestamp])}
#    (snaps[var[:max_snapshots_num]..-1] || []).each do |s|
#      delete_snapshot(s[:snapshot_id])
#    end
#  end
#end
