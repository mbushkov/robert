conf :rules do
  
end

# module CLICommands
 #    def dump_rules(names, vars)
 #      puts "dumping rules"
 #      $top.rules.dump
 #    end

 #    def dump_confs(names, vars)
 #      puts "dumping configurations"
 #      $top.conf_names.each do |cname|
 #        conf = $top.cclone(cname)
 #        puts "== #{cname}, tags: #{conf.tags.to_a.join(",")}"
 #        conf.act_storage.dump
 #        puts
 #      end
 #    end

 #    def spec_example_group(action)
 #      if action.spec
 #        example_class = Class.new(Spec::Example::ExampleGroup)
 #        example_class.describe(action.name.to_s)
 #        example_class.class_eval do
 #          before do
 #            @action = flexmock(Object.new)
 #            @action.extend(::Robert::RulesStorageContainer)
                 
 #            action.rules.each { |r| @action.rules.add(r) }

 #            class << @action; self; end.class_eval do
 #              define_method :rule_ctx do
 #                [action.lname, action.rname]
 #              end

 #              define_method :call do |*args|
 #                instance_exec(*args, &action.body)
 #              end
 #            end
 #          end
 #        end
 #        example_class.class_eval(&action.spec)
 #        example_class
 #      end
 #    end
 #    private :spec_example_group

 #    def spec(names, vars)
 #      Spec::Runner.configure do |config|
 #        config.mock_with :flexmock
 #      end
 #      mock_framework = Spec::Runner.configuration.mock_framework
 #      require mock_framework
 #      Spec::Example::ExampleMethods.module_eval { include Spec::Adapters::MockFramework }

 #      options = Spec::Runner.options
 #      $top.actions.values.map { |action| spec_example_group(action) } # groups will be added by side-effects
 #      runner = Spec::Runner::ExampleGroupRunner.new(options)

 #      runner.run
 #    end

 #    def run_tests(names, vars)
 #      puts "running tests"
 #      suite = $top.ext_test_cat_name_pairs.map { |cat, name| $top.ext_test(cat, name) }.reduce { |a,b| a + b }
 #      suite.run
 #    end

 #    def list_names(names, vars)
 #      puts "done"
 #    end

 #    def run(names, vars)
 #      names.each do |name|
 #        conf = $top.cclone(name)
 #        conf.instance_eval do
 #          var[:role] = lambda { :host }
 #          run "#{vars[:cmd]}", :pty => true
 #        end
 #      end
 #    end

 #    def sudo(names, vars)
 #      names.each do |name|
 #        conf = $top.cclone(name)
 #        conf.instance_eval do
 #          var[:role] = lambda { :host }
 #          run "#{sudo} #{vars[:cmd]}", :pty => true
 #        end
 #      end
 #    end

 #    def local_server(names,vars)
 #      require 'robert/lserver'
 #      Robert.run_local_server($top.var[:robert,:local_server,:unix_socket], :num_threads => $top.var?[:robert,:local_server,:num_threads])
 #    end

 #    def start_local_server(names, vars)
 #      daemon_local_server(:start, names, vars)
 #    end

 #    def stop_local_server(names, vars)
 #      daemon_local_server(:stop, names, vars)
 #    end

 #    def restart_local_server(names, vars)
 #      daemon_local_server(:restart, names, vars)
 #    end

 #    def daemon_local_server(action, names, vars)
 #      require 'daemons'

 #      daemons_opts = { :app_name => "rob_local_server",
 #        :monitor => $top.var?[:robert,:local_server,:autorestart],
 #        :user => $top.var?[:robert,:local_server,:user],
 #        :group => $top.var?[:robert,:local_server,:group],
 #        :ARGV => [action.to_s]
 #      }

 #      Daemons.run_proc("rob_local_server", daemons_opts) do
 #        local_server(names, vars)
 #      end
 #    end
 #    private :daemon_local_server
 #  end
