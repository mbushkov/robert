require 'robert/cli'

include Robert

describe CLI do
  context "parse_args" do
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

  context "args_to_rules" do
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
