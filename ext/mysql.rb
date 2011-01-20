ext :mysql do
  var[:mysql,:dir] = lambda { "/usr/local/mysql" }
  var[:mysql,:bin,:dir] = lambda { "#{var[:mysql,:dir]}/bin" }
  var[:mysql,:admin,:cmd] = lambda { "#{var[:mysql,:bin,:dir]}/mysqladmin" }
  var[:mysql,:check,:cmd] = lambda { "#{var[:mysql,:bin,:dir]}/mysqlcheck" }
  var[:mysql,:dump,:cmd] = lambda { "#{var[:mysql,:bin,:dir]}/mysqldump" }
  var[:mysql,:hotcopy,:cmd] = lambda { "#{var[:mysql,:bin,:dir]}/mysqlhotcopy" }
  var[:mysql,:query,:cmd] = lambda { "#{var[:mysql,:bin,:dir]}/mysql" }

  def collect_mysql_args(prefix, *keys)
    keys.inject({}) do |memo, k|
      if val = var?[prefix, k]
        memo[k] = val
      end
      memo
    end
  end
  private :collect_mysql_args

  var[:mysql,:host] = lambda { "127.0.0.1"}

  var[:mysql,:check,:quick] = lambda { nil }
  var[:mysql,:check,:auto_repair] = lambda { nil }
  def check_db
    var[:role] = lambda { :db }

    args = collect_mysql_args(:check, :user, :password, :host, :quick, :auto_repair)
    cmd = var[:mysql,:check,:cmd]
    cmd += " --user=#{args[:user]}" if args[:user]
    cmd += " --password=#{args[:password]}" if args[:password]
    cmd += " -h #{args[:host]}" if args[:host]
    cmd += " --auto-repair" if args[:auto_repair]
    cmd += " -q" if args[:quick]
    cmd += " #{var[:mysql,:dbname]}"
    run cmd
  end

  def query_db(sql)
    var[:role] = lambda { :db }

    args = collect_mysql_args(:check, :user, :password, :host, :quick, :auto_repair)
    cmd = "echo '#{sql}' | #{var[:mysql,:query,:cmd]}"
    cmd += " --user=#{args[:user]}" if args[:user]
    cmd += " --password=#{args[:password]}" if args[:password]
    cmd += " -h #{args[:host]}" if args[:host]
    cmd += " #{var[:mysql,:dbname]}"

    capture(cmd).split("\n")[1..-1].map { |line| line.split("\t") }
  end

  var[:mysql,:dump,:bzip2] = lambda { true }
  def dump_db(to)
    var[:role] = lambda { :db }

    if var[:mysql,:dump,:bzip2]
      raise ArgumentError, "can only dump to file whose names end with #{dump_db_ext}" unless var[:dump,:bzip2] and to =~ /(.+)\.#{Regexp.escape(dump_db_ext)}/
      basename = $1
    else
      basename = to
    end

    args = collect_mysql_args(:dump, :user, :password, :host)
    cmd = var[:mysql,:dump,:cmd]
    cmd += " --user=#{args[:user]}" if args[:user]
    cmd += " --password=#{args[:password]}" if args[:password]
    cmd += " -h #{args[:host]}" if args[:host]
    cmd += " #{var[:mysql,:dbname]} > #{basename}"

    cmd = "( #{cmd} ) && bzip2 #{basename}" if var[:mysql,:dump,:bzip2]
    begin
      run cmd
    ensure
      run "rm -f #{basename}" rescue loge "error while forcibly trying to delete #{basename}: #{$!}"
    end
  end

  def dump_db_ext
    var[:mysql,:dump,:bzip2] ? "bz2" : "sql"
  end

  var[:hotcopy,:suffix] = lambda { nil }
  def hotcopy_db(to = var?[:mysql,:hotcopy,:to])
    var[:mysql,:role] = lambda { :db }

    args = collect_mysql_args(:hotcopy, :user, :password, :host, :suffix)
    cmd = var[:mysql,:hotcopy,:cmd]
    cmd += " --user=#{args[:user]}" if args[:user]
    cmd += " --password=#{args[:password]}" if args[:password]
    cmd += " -h #{args[:host]}" if args[:host]
    cmd += " --suffix=#{args[:suffix]}" if args[:suffix]
    cmd += " #{var[:mysql,:dbname]}"
    cmd += " #{to}" if to

    run cmd
  end

  def drop_db(dbname)
    var[:role] = lambda { :db }

    args = collect_mysql_args(:drop_db, :user, :password, :host)
    cmd = var[:mysql,:admin,:cmd]
    cmd += " --user=#{args[:user]}" if args[:user]
    cmd += " --password=#{args[:password]}" if args[:password]
    cmd += " -h #{args[:host]}" if args[:host]
    cmd += " #{dbname}"

    run cmd
  end

  def list_all_db
    var[:role] = lambda { :db }

    args = collect_mysql_args(:list_all_db, :user, :password, :host)
    cmd = var[:mysql,:query,:cmd]
    cmd += " --user=#{args[:user]}" if args[:user]
    cmd += " --password=#{args[:password]}" if args[:password]
    cmd += " -h #{args[:host]}" if args[:host]
    cmd += " -Bse 'show databases'"

    res = capture(cmd)
    logd res
    res.lines.map { |s| s.chomp }
  end
end
