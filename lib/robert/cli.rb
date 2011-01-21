require 'rubygems'
require 'robert/toplevel'

$top = Robert::TopLevel.new

module Robert
  
  class CLI
    CORE_ADDONS_PATH = "#{File.dirname __FILE__}/core"
    
    TOP_GLOBAL_CONFIGURATION_PATH = "/etc/robert2.rb"
    GLOBAL_EXTENSIONS_PATH = "/usr/local/robert2/ext"
    GLOBAL_CONFIGURATIONS_PATH = "/usr/local/robert2/conf"

    TOP_USER_CONFIGURATION_PATH = File.expand_path("~/.robert/robert.rb")
    USER_EXTENSIONS_PATH = File.expand_path("~/.robert/ext")
    USER_CONFIGURATIONS_PATH = File.expand_path("~/.robert/conf")

    def execute(argv, env)
      trap "INT" do
        puts caller.join("\n\t")
        exit 1
      end

      begin
        parsed = parse_args(argv.dup, env.dup)
        args_to_rules(parsed, $top)

        load_files(CORE_ADDONS_PATH)        
        $top.include(:base) #have to include it explicitly, as base is created and configured after the $top
        $top.process_rules_and_extensions

        ignore_global, ignore_user = ENV['ROB_IGNORE_GLOBAL_CONFIGURATION_PATHS'], ENV['ROB_IGNORE_USER_CONFIGURATION_PATHS']

        load_files(GLOBAL_EXTENSIONS_PATH) unless ignore_global
        load_files(USER_EXTENSIONS_PATH) unless ignore_user
        load_files(GLOBAL_CONFIGURATIONS_PATH) unless ignore_global
        load_files(USER_CONFIGURATIONS_PATH) unless ignore_user
        $top.load(TOP_GLOBAL_CONFIGURATION_PATH) unless ignore_global or !File.exists?(TOP_GLOBAL_CONFIGURATION_PATH)
        $top.load(TOP_USER_CONFIGURATION_PATH) unless ignore_user or !File.exists?(TOP_USER_CONFIGURATION_PATH)
        $top.process_rules_and_extensions

        $top.confs($top.confs_names, :without_name => :base_after) { include :base_after } if $top.conf?(:base_after)
        $top.process_rules_and_extensions
        
        $top.logd "all rules and extensions were processed"

        Configuration.send(:include, RulesEvaluator)

        # if $top.var?[:cmdline,:names] &&
        #     unknown_name = $top.var[:cmdline,:names].find { |name| !$top.confs_names.include?(name) }
        #   raise "unknown name #{unknown_name}"
        # end

        cmd = $top.var[:cmdline,:cmd]
        $top.cclone(:cli).process_cmd(cmd)
      rescue => e
        $stderr.puts "error #{e}: #{e.message}"
        $stderr.puts e.backtrace.join("\n\t")

        raise e
      end
    end

    private
    def parse_args(argv, env)
      command = argv[0]

      vars = {}
      (argv[1..-1] || []).each do |ar|
        if ar =~ /^(.+)=(.+)$/
          lval, rval = $1, $2
          lval = lval.split(",").map { |s| s =~ /^\d+$/ ? s.to_i : s.to_sym }
          rval = rval.split(",").map { |s| s =~ /^\d+$/ ? s.to_i : s }

          lval = lval.first if lval.size == 1
          rval = rval.first if rval.size == 1
      
          vars[lval] = rval
        else
          arval = ar.split(",").map { |s| s =~ /^\d+$/ ? s.to_i : s.to_sym }
          arval = arval.first if arval.size == 1
          vars[arval] = true
        end
      end
      {:command => command,
       :vars => vars}
    end

    def args_to_rules(parsed_args, conf)
      conf.var[:cmdline,:cmd] = parsed_args[:command]
      parsed_args[:vars].each_with_index do |v, i|
        conf.var[:cmdline,:args,i] = v
        conf.var[:cmdline,:args,*v[0]] = v[1]
        # v[1] == true means argument without the right assignment part, i.e.: project1,project2
        if i == 0 && v[1]
          conf.var(:cmdline,:names) { v[0] == :all ? conf.confs_names.to_a : [v[0]].flatten }
        end
      end
    end

    def load_files(path)
      if File.directory?(path)
        Dir["#{path}/*.rb"].sort.each { |fp| $top.load(fp) }
      end
    end
  end

  describe CLI, "parse_args" do
    before do
      @cli = CLI.new
    end
    
    it "treats first argument as command" do
      res = @cli.send(:parse_args, ["update"], nil)
      res[:command].should == "update"
    end

    it "args which contain =, are treated as variables assignments" do
      res = @cli.send(:parse_args, ["build", "force=now", "verbose=extreme"], nil)
      res[:vars][:force].should == "now"
      res[:vars][:verbose].should == "extreme"
    end

    it "args which do not contain =, are treated as flag-variables" do
      res = @cli.send(:parse_args, ["build", "project1", "force", "no_pid_file"], nil)
      res[:vars][:force].should be_true
      res[:vars][:no_pid_file].should be_true
    end

    it "comma-separated lists inside flag-variables are treated as arrays" do
      res = @cli.send(:parse_args, ["build", "project1,project2"], nil)
      res[:vars][[:project1,:project2]].should be_true
    end

    it "comma-separated lists inside variable assignments are treated as arrays" do
      res = @cli.send(:parse_args, ["update",
                                    "build,notify,campfire=onfail",
                                    "dependencies=project1,project2",
                                    "build,dependencies=project1,project2"], nil)
      res[:vars][[:build,:notify,:campfire]].should == "onfail"
      res[:vars][:dependencies].should == ["project1", "project2"]
      res[:vars][[:build,:dependencies]] == ["project1", "project2"]
    end

    it "numbers are converted from string to numeric representation in variable assignments" do
      res = @cli.send(:parse_args, ["update", "verbose=4", "context=project1,0,something"], nil)
      res[:vars][:verbose].should == 4
      res[:vars][:context].should == ["project1",0,"something"]
    end
  end

  describe CLI, "args_to_rules" do
    before do
      @conf = flexmock(TopLevel.new)
      @cli = CLI.new
    end

    it "creates rule :cmdline,:cmd for the first argument (the command)" do
      @cli.send(:args_to_rules,
                {:vars => {},
                  :command => "update"},
                @conf)

      @conf.var[:cmdline, :cmd].should == "update"
    end
    
    it "creates rule with context :cmdline,:args,[index] for every positional argument, except the first one (the command)" do
      @cli.send(:args_to_rules,
                {:vars => {:force => "now"},
                  :cmd => "update"},
                @conf)

      @conf.var[:cmdline,:args,0].should == [:force, "now"]
      @conf.var[:cmdline,:args,0,:force].should == "now"
    end

    it "creates alias :cmdline,:args,:names for first positional argument" do
      @cli.send(:args_to_rules,
                {:vars => {[:project1,:project2,:project3] => true},
                  :cmd => "update"},
                @conf)

      @conf.var[:cmdline,:args,:names].should == [:project1,:project2,:project3]
    end

    it ":cmdline,:args,:names contains an array even when only one name was passed as an argument" do
      @cli.send(:args_to_rules,
                {:vars => {:project1 => true},
                  :cmd => "update"},
                @conf)

      @conf.var[:cmdline,:args,:names].should == [:project1]
    end

    it ":cmdline,:args,:names expand to all confs_names" do
      @conf.should_receive(:confs_names).and_return([:project1, :project2])
      
      @cli.send(:args_to_rules,
                {:vars => {:all => true},
                  :cmd => "update"},
                @conf)

      @conf.var[:cmdline,:args,:names].should == [:project1, :project2]
    end
  end

end
