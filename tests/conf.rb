require 'robert/conf'

include Robert

describe ConfigurationSelector do
  context "with_tags" do
    before do
      @conf = flexmock(:tags => [:pretty, :awesome])
      @sel = ConfigurationSelector.new(@conf)
    end
    
    it "returns true if all specified tags are present in configuration" do
      @sel.with_tags(:pretty).should be_true
      @sel.with_tags(:awesome).should be_true
      @sel.with_tags(:pretty, :awesome).should be_true
    end

    it "returns false if at least one tag is not present in configuration" do
      @sel.with_tags(:ugly).should be_false
      @sel.with_tags(:pretty, :ugly).should be_false
      @sel.with_tags(:awesome, :ugly).should be_false
      @sel.with_tags(:pretty, :awesome, :ugly).should be_false
    end
  end

  context "without_tags" do
    before do
      @conf = flexmock(:tags => [:pretty, :awesome])
      @sel = ConfigurationSelector.new(@conf)
    end

    it "returns true if none of the specified tags are present in configuration" do
      @sel.without_tags(:ugly).should be_true
      @sel.without_tags(:ugly, :duckling).should be_true
    end
    
    it "returns false if any of the specified tags are present in configuration" do
      @sel.without_tags(:pretty).should be_false
      @sel.without_tags(:awesome).should be_false
      @sel.without_tags(:pretty, :awesome).should be_false
      @sel.without_tags(:pretty, :ugly).should be_false
      @sel.without_tags(:awesome, :ugly).should be_false
    end
  end

  context "with_any_tag" do
    before do
      @conf = flexmock(:tags => [:pretty, :awesome])
      @sel = ConfigurationSelector.new(@conf)
    end

    it "returns true if any of the specified tags are present in configuration" do
      @sel.with_any_tag(:pretty).should be_true
      @sel.with_any_tag(:awesome).should be_true
      @sel.with_any_tag(:pretty, :awesome).should be_true
      @sel.with_any_tag(:pretty, :ugly).should be_true
      @sel.with_any_tag(:awesome, :ugly).should be_true
    end

    it "returns false if none of the specified tags are present in configuration" do
      @sel.with_any_tag(:ugly).should be_false
      @sel.with_any_tag(:duckling).should be_false
      @sel.with_any_tag(:ugly, :duckling).should be_false
    end
  end

  context "with_method" do
    before do
      @conf = flexmock(:some_method => 42)
      @sel = ConfigurationSelector.new(@conf)
    end

    it "returns true when method is present" do
      @sel.with_method(:some_method).should be_true
    end

    it "returns false when method is not present" do
      @sel.with_method(:another_method).should be_false
    end
  end

  context "with_var" do
    before do
      @conf = flexmock(:rules => [Rule.new([:a,:b,:c], 42),
                                  Rule.new([:some_conf,:x,:y,:z], 43)],
                       :conf_name => :some_conf)
      @sel = ConfigurationSelector.new(@conf)
    end

    it "returns true if there's a var with a matching context" do
      @sel.with_var(:a, :b, :c).should be_true
      @sel.with_var(:prea, :a, :b, :c).should be_true
    end

    it "returns false if there's no var with a matching context" do
      @sel.with_var(:b, :c).should be_false
      @sel.with_var(:a, :c).should be_false
      @sel.with_var(:a, :b, :c, :x, :y, :z, :some).should be_false
    end

    it "prepends configuration name to context used to match rules" do
      @sel.with_var(:x,:y,:z).should be_true
    end
  end

  context "with_options" do
    before do
      @conf = flexmock
      @sel = flexmock(ConfigurationSelector.new(@conf))
    end

    it "treats supplied options hash as a series of checks" do
      @sel.should_receive(:check1).with("string_arg").and_return(true).once
      @sel.should_receive(:check2).with(:enum_arg1, :enum_arg2).and_return(true).once
      
      res = @sel.with_options(:check1 => "string_arg",
                              :check2 => [:enum_arg1, :enum_arg2])
      res.should be_true
    end

    it "fails if any of the checks fails (works like AND predicate)" do
      # NOTE: check1 will be first during options - that's standard Ruby 1.9 behavior
      @sel.should_receive(:check1).with("string_arg").and_return(false).once
      @sel.should_receive(:check2).never
      
      res = @sel.with_options(:check1 => "string_arg",
                              :check2 => [:enum_arg1, :enum_arg2])
      res.should be_false
    end
  end


  before do
    @conf = Configuration.new(:some_conf)
  end

  it "prepends conf_name to rules' contexts" do
    @conf.var[:host,:user] = "admin"

    @conf.rules.first.context.should == [:some_conf,:host,:user]
  end
end

describe ConfigurationsContainer do
  before do
    @cc = flexmock(Object.new.extend(ConfigurationsContainer))
  end

  it "defines new configuration with a .conf call and a block" do
    @cc.conf(:new_conf) {}

    @cc.confs_names.should include(:new_conf)
  end

  it "accesses previously defined configuration with .conf call without a block" do
    @cc.conf(:new_conf) do
    end

    @cc.conf(:new_conf).should_not be_nil
  end

  it "raises when trying to get undefined configuration wuth .conf call" do
    ->{ @cc.conf(:new_conf) }.should raise_exception
  end

  it "allows to configure multiple configurations at once with .confs call and a block" do
    @cc.confs(:some_conf1, :some_conf2) {}

    @cc.confs_names.should include(:some_conf1)
    @cc.confs_names.should include(:some_conf2)
  end

  it "allows to use options to filter configurations to be configured in .confs call" do
    @cc.conf(:conf1) { tags << :conf1 }
    @cc.conf(:conf2) { tags << :conf2 }

    @cc.should_receive(:conf_called).with(:conf1).once
    @cc.should_receive(:conf_called).with(:conf2)

    cc = @cc
    @cc.confs(@cc.confs_names, :with_tags => :conf1) do
      cc.conf_called(conf_name)
    end
  end

  it "returns enumerable from .confs call if no block is supplied" do
    @cc.conf(:conf1) { tags << :conf1 }
    @cc.conf(:conf2) { tags << :conf2 }

    @cc.confs(:conf1, :conf2).should == [@cc.conf(:conf1), @cc.conf(:conf2)]
  end

  it "selects configurations with .select and adds each_conf helper method to resulting enumerable" do
    @cc.conf(:conf1) {}

    @cc.should_receive(:conf_iterated).once
    
    cc = @cc
    @cc.select { true }.each_conf { cc.conf_iterated }
  end
end
