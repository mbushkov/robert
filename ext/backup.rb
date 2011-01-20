

#ext :backup, :backup do
#  def backup(*args)
#  end
#
#  def temp_path(suffix)
#    t = Time.now.strftime("%Y%m%d%H%M%S")
#    "/tmp/#{t}-#{$$}-#{suffix}"
#  end
#  private :temp_path
#end
#
#ext :backup, :local do
#  require 'fileutils'
#
#  def backup(src_file)
#    get(src_file, src_file)
#    begin
#      var[:hosts] = lambda { "127.0.0.1" }
#      super src_file
#    ensure
#      FileUtils.rm_f(src_file)
#    end
#  end
#end
#
#ext :backup, :monthly do
#  def backup(src_file)
#    if Time.now.mday == 1
#      super src_file
#    end
#  end
#end
#
#ext :backup, :weekly do
#  def backup(src_file)
#    if Time.now.wday == 1
#      super src_file
#    end
#  end
#end
#
#ext :backup, :same_host_file do
#  var[:dir] = lambda { "/usr/local/backup/#{conf_name}/#{var[:backup_type]}" }
#  var[:limit] = lambda { 3 }
#
#  def backup(src_file)
#    run "mkdir -p #{var[:dir]} && chmod 0700 #{var[:dir]}"
#
#    ext = (m = File.basename(src_file).match(/\..+/)) ? m[0] : ""
#    backup_path = "#{var[:dir]}/#{var[:backup_type]}_#{Time.now.strftime("%Y_%m_%d_%H%M%S")}#{ext}"
#    run "cp #{src_file} #{backup_path} && chmod 0400 #{backup_path}"
#    run "cd #{var[:dir]} && ls -r | tail -n +#{var[:limit] + 1} | xargs rm -f"
#  end
#end
#
#ext :backup, :s3 do
#  var[:limit] = lambda { 3 }
#
#  def backup(src_file)
#    ptokens = var[:s3_path].split(/\//)
#    bucket = ptokens[0]
#    key = (ptokens[1..-1] || []).join("/")
#
#    create_s3_bucket(bucket)
#    upload_to_s3(src_file, "#{key}/#{File.basename src_file}", bucket)
#    backups = list_s3(key, bucket)
#    (backups[0...(- var[:limit])] || []).each { |name| delete_from_s3("#{key}/#{File.basename name}", bucket) }
#  end
#end
#
#ext :backup, :rsync do
#  var[:cmd] = lambda { "rsync" }
#  var[:args] = lambda { "-auSx --delete --stats --temp-dir=/tmp -e 'ssh -i #{var[:public_key_path]}'" }
#  var[:include] = lambda { nil }
#  var[:exclude] = lambda { nil }
#
#  def backup
#    role_host = var["role_#{var[:role]}".to_sym]
#
#    syscmd("mkdir -p #{var[:to]}")
#    syscmd("#{var[:cmd]} #{var[:args]} #{role_host}:#{var[:from]} #{var[:to]}")
#  end
#end
#
#ext :backup, :svn_repo_dump do
#  var[:svn_bin_dir] = lambda { "/opt/subversion/bin" }
#  var[:svnadmin_cmd] = lambda { "#{var[:svn_bin_dir]}/svnadmin" }
#
#  def backup
#    var[:role] = var[:backup_type] = lambda { :svn }
#
#    dump_to = temp_path("svn")
#    run "mkdir -p #{dump_to} && chmod 0700 #{dump_to}"
#    run "#{var[:svnadmin_cmd]} hotcopy #{var[:svn_repo_path]} #{dump_to}"
#
#    begin
#      dump_to_tar_gz = "#{dump_to}.tar.gz"
#      run "tar -C #{dump_to} -czf #{dump_to_tar_gz} ."
#      super dump_to_tar_gz
#    ensure
#      run "rm -r #{dump_to}" rescue loge "error while removing temporary svn backup dir: #{$!}"
#      run "rm #{dump_to_tar_gz}" rescue loge "error while removing temporary svn backup archive: #{$!}"
#    end
#  end
#end
#
#ext :backup, :db_dump do
#  def backup
#    var[:role] = var[:backup_type] = lambda { :db }
#
#    dump_to = temp_path("db.#{dump_db_ext}")
#    begin
#      dump_db(dump_to)
#      super dump_to
#    ensure
#      run "rm #{dump_to}" rescue loge "error while removing temporary backup: #{$!}"
#    end
#  end
#end
#
#ext :backup, :db_check do
#  def backup
#    check_db
#  end
#end
#
#ext :backup, :db_hotcopy do
#  var[:backup_limit] = lambda { 2 }
#  var[:suffix] = lambda { "backup" }
#
#  def backup
#    var[:role] = var[:backup_type] = lambda { :db }
#
#    dbname = var[:db,:dbname]
#    suffix = var[:suffix]
#    begin
#      hc_name = "#{dbname}_#{suffix}_#{Time.now.strftime("%Y%m%d%H%M%S")}"
#      hotcopy_db(hc_name)
#      var[:hotcopied_dbname] = lambda { hc_name }
#    ensure
#      dbs = list_all_db
#      backups = dbs.select { |s| s =~ /^#{Regexp.escape(dbname)}_#{Regexp.escape(suffix)}_(\d+)$/i}.sort
#      (backups[0...(- var[:backup_limit])] || []).each { |name| drop_db(name) }
#    end
#  end
#end
#
#ext_test :backup, :db_hotcopy do
#  def test_does_not_delete_main_database_when_there_are_no_backups
#    conf.should_receive(:hotcopy_db)
#    conf.var[:db,:dbname] = lambda { "Project" }
#
#    conf.should_receive(:list_all_db).and_return(["Project"])
#    conf.should_receive(:drop_db).never
#
#    conf.backup
#  end
#
#  def test_correctly_limits_backup_databases
#    conf.should_receive(:hotcopy_db)
#    conf.var[:db,:dbname] = lambda { "Project" }
#
#    conf.should_receive(:list_all_db).and_return(["Project", "Project_backup_0102", "Project_backup_0104", "Project_backup_0104"])
#    conf.should_receive(:drop_db).with("Project_backup_0102").once
#
#    conf.backup
#  end
#end
#
#ext :backup, :www_dump do
#  var[:www_dir] = lambda { "/Library/WebServer/Documents/#{conf_name.to_s.downcase}" }
#
#  def backup
#    var[:role] = var[:backup_type] = lambda { :www }
#
#    dump_to = temp_path("www.tar.gz")
#    begin
#      run "tar -czf #{dump_to} -C #{var[:www_dir]} ."
#      super dump_to
#    ensure
#      run "rm #{dump_to}" rescue loge "error while removing temporary backup: #{$!}"
#    end
#  end
#end
