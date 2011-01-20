defn dump.db do
  body {
    var[:role] = var[:backup_type] = lambda { :db }

    dump_to = temp_path("db.#{dump_db_ext}")
    begin
      dump_db(dump_to)
      super dump_to
    ensure
      run "rm #{dump_to}" rescue loge "error while removing temporary backup: #{$!}"
    end
  }
end

defn check.db do
  body {
    check_db
  }
end
