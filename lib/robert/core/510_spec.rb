require 'rspec'

defn cli.spec do
  var[:cli,:spec,:mock,:framework] = :flexmock
  
  _spec_example_group = lambda do |action|
    if action.spec
      describe(action.name.to_s) do
        before do
          @action = flexmock(Object.new)
          @action.extend(::Robert::RulesStorageContainer)
          
          action.rules.each { |r| @action.rules.add(r) }
          
          class << @action; self; end.class_eval do
            define_method :rule_ctx do
              [action.lname, action.rname]
            end
            
            define_method :call do |*args|
              instance_exec(*args, &action.body)
            end
          end
        end

        class_eval(&action.spec)
      end
    end
  end
  
  body { |spec_example_group = _spec_example_group|
    mock_framework = var[:cli,:spec,:mock,:framework]
    
    RSpec::Core::Runner.disable_autorun!
    RSpec.configure do |config|
      config.mock_framework = mock_framework
    end
    logd "using mock framework: #{mock_framework}"
    $top.actions.values.map { |action| spec_example_group.call(action) } # groups will be added by side-effects
    RSpec::Core::CommandLine.new([]).run($stderr, $stdout)
  }
end

conf :cli do
  act[:spec] = cli.spec
end
