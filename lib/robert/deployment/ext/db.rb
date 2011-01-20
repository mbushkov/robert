var[:robert,:deployment,:db,:path] = "/usr/local/robert2/db/robert.db"

defn deployment_db.with_connection do

  class ActiveRecordLoggerWrapper
    def initialize(conf, cut_level)
      @conf, @cut_level = conf, cut_level
      @cut_level = cut_level
    end

    [:debug, :info, :error, :fatal].each do |mn|
      class_eval do
        define_method(mn) do |str = nil, &block|
          add(@conf.var[:log,:level,mn.to_sym], str, &block)
        end
        
        define_method("#{mn}?") do
          @cut_level >= @conf.var[:log,:level,mn.to_sym]
        end
      end
    end

    private
    def add(severity, str)
      return if severity > @cut_level
      
      if block_given?
        str = yield
      end
      @conf.log(severity, str)
    end
  end
  
  body {
    require 'active_record'
    
    db_path = var[:robert,:deployment,:db,:path]
    logd "using db file: #{db_path}"
    db_dir = File.dirname(db_path)
    unless File.directory?(db_dir)
      logd "db folder not found, creating: #{db_path}"
      FileUtils.mkdir_p(db_dir)
    end

    ActiveRecord::Base.logger = ActiveRecordLoggerWrapper.new($top.cclone(:deployment_db), var[:deployment_db,:activerecord,:log,:level])

    ActiveRecord::Base.establish_connection(
      :adapter => "sqlite3",
      :database => db_path
    )

    call_next
  }
end

defn deployment_db.migrate do
  body {
    ActiveRecord::Migrator.migrate(File.join(File.dirname(__FILE__), "..", "model", "migrations"))
    call_next if has_next?
  }
end

defn deployment_db.nuke do
  body {
    db_path = var[:robert,:deployment,:db,:path]
    logi("nuking the database: #{db_path}")
    FileUtils.rm_f(db_path)
  }
end

conf :deployment_db do
  var(:activerecord,:log,:level) { var[:log,:level,:error] }

  act[:migrate] = deployment_db.with_connection(deployment_db.migrate)
  act[:nuke] = deployment_db.nuke
end

