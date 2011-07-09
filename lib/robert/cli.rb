require 'rubygems'
require 'bundler/setup'

require 'robert/toplevel'

$top = Robert::TopLevel.new

module Robert
  
  class CLI
    CORE_ADDONS_PATH = "#{File.dirname __FILE__}/core"
    CONTRIB_ADDONS_PATH= "#{File.dirname __FILE__}/contrib"
    
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
        parsed = CLI.parse_args(argv.dup, env.dup)
        CLI.args_to_rules(parsed, $top)

        load_files(CORE_ADDONS_PATH)
        load_files(CONTRIB_ADDONS_PATH)
        $top.include(:base) #have to include it explicitly, as base is created and configured after the $top

        ignore_global, ignore_user = ENV['ROB_IGNORE_GLOBAL_CONFIGURATION_PATHS'], ENV['ROB_IGNORE_USER_CONFIGURATION_PATHS']

        load_files(GLOBAL_EXTENSIONS_PATH) unless ignore_global
        load_files(USER_EXTENSIONS_PATH) unless ignore_user
        load_files(GLOBAL_CONFIGURATIONS_PATH) unless ignore_global
        load_files(USER_CONFIGURATIONS_PATH) unless ignore_user
        $top.load(TOP_GLOBAL_CONFIGURATION_PATH) unless ignore_global or !File.exists?(TOP_GLOBAL_CONFIGURATION_PATH)
        $top.load(TOP_USER_CONFIGURATION_PATH) unless ignore_user or !File.exists?(TOP_USER_CONFIGURATION_PATH)

        $top.fix_unchangeable_rules
        $top.process_rules
        $top.extend(RulesEvaluator)
        
        # def $top.conf(*args)
        #   raise "changing configurations at runtime is not allowed"
        # end
        # def $top.confs(*args)
        #   raise "changing configurations at runtime is not allowed"
        # end
        
        $top.logd "all rules and extensions were processed"

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

    def self.parse_args(argv, env)
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

    def self.args_to_rules(parsed_args, conf)
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

    private
    def load_files(path)
      if File.directory?(path)
        Dir["#{path}/*.rb"].sort.each { |fp| $top.load(fp) }
      end
    end
  end

end
