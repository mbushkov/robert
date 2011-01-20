# -*- coding: utf-8 -*-
require 'robert/act'
require 'robert/rule'
require 'robert/ext'
require 'set'

module Robert
  # Helper class - Configuration.select uses it to instance_eval user-supplied block
  class ConfigurationSelector
    attr_reader :conf
    
    def initialize(conf)
      @conf = conf
    end

    def with_tags(*tags)
      tags = tags.map { |t| t.to_sym }
      tags.to_set.subset?(@conf.tags.to_set)
    end

    def without_tags(*tags)
      tags = tags.map { |t| t.to_sym }
      (@conf.tags.to_set & tags.to_set).empty?
    end

    def with_any_tag(*tags)
      tags = tags.map { |t| t.to_sym }
      !(@conf.tags.to_set & tags.to_set).empty?
    end

    def with_method(mname)
      @conf.respond_to?(mname)
    end

    def with_name(name)
      @conf.conf_name == name.to_sym
    end

    def without_name(name)
      @conf.conf_name != name.to_sym
    end

    def with_var(*var_ctx)
      @conf.rules.find { |r| r.match([@conf.conf_name] + var_ctx) }
    end

    def with_options(options)
      not options.find do |k,v|
        !send(k, *v)
      end
    end
  end

  describe ConfigurationSelector, "with_tags" do
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

  describe ConfigurationSelector, "without_tags" do
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

  describe ConfigurationSelector, "with_any_tag" do
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

  describe ConfigurationSelector, "with_method" do
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

  describe ConfigurationSelector, "with_var" do
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

  describe ConfigurationSelector, "with_options" do
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

  # Configuration is the basic entity in Robert. It is configured with acts, rules and extensions.
  # Contexts of rules defined inside the configuration are affected - they're prepended with
  # configuration name. Example:
  #  conf myproject do
  #    var[:host,:user] = "admin"
  #  end
  #
  # This will define rule :myproject,:host,:user => "admin".
  #
  # Configurations can be included in each other using "include" call. Including another configuration
  # effectively means executing its code in the context of this configuration.
  class Configuration
    include ActsContainer
    include RulesContainer
    include ExtsUser
    include ContextStateHolder

    attr_reader :conf_name, :tags

    def initialize(conf_name, *args)
      @conf_name = conf_name
      @conf_blocks = []
      @rule_ctx = [conf_name.to_sym]
      @tags = Set.new
    end

    def include_conf(conf)
      conf.conf_blocks.each { |blk| apply_conf_block(&blk) }
    end

    def include(*names)
      names.each {|name| include_conf($top.conf(name)) }
    end

    def apply_conf_block(&block)
      @no_recursive_add ||= 0
      if @no_recursive_add == 0
        @conf_blocks << block
      end
      @no_recursive_add += 1
      begin
        instance_eval(&block)
      ensure
        @no_recursive_add -= 1
      end
    end

    def actions
      $top.actions
    end

    protected
    attr_reader :conf_blocks
  end

  describe Configuration do
    before do
      @conf = Configuration.new(:some_conf)
    end

    it "prepends conf_name to rules' contexts" do
      @conf.var[:host,:user] = "admin"

      @conf.rules.first.context.should == [:some_conf,:host,:user]
    end
  end

  # ConfigurationsContainer should be mixed into class which should be able to define and handle
  # collection of configurations. Single configurations are defined with "conf" call. Batch operations
  # on configurations are performed with "confs" call. Groups of configurations are selected with "select".
  module ConfigurationsContainer
    def cclone(conf_name)
      rs = rules
      confs_hash.fetch(conf_name.to_sym).clone.extend(Module.new.module_eval {
        define_method :rules do
          rs
        end
        self
      })
    end

    def confs_names
      confs_hash.keys.to_set
    end

    def conf(conf_name, &block)
      if block
        confs_hash[conf_name.to_sym].apply_conf_block(&block)
      else
        raise "no configuration for name '#{conf_name}'" unless confs_hash.key?(conf_name.to_sym)
        confs_hash[conf_name.to_sym]
      end
    end

    def conf?(conf_name)
      confs_hash.key?(conf_name.to_sym)
    end

    def confs(*names, &block)
      raise ArgumentError, "at least one configuration name was expected" if names.empty?
      options = names.last.respond_to?(:keys) ? names.pop : {}

      if names.length == 1 and names.first.respond_to?(:each) and !names.first.respond_to?(:gsub)
        names = names.first
      end

      sel_confs = names.map { |name| confs_hash[name.to_sym] }.select do |conf|
        ConfigurationSelector.new(conf).with_options(options)
      end

      if block
        sel_confs.each { |conf| conf.apply_conf_block(&block) }
      end
      sel_confs
    end

    def select(&block)
      result = confs_hash.values.select { |conf| ConfigurationSelector.new(conf).instance_eval(&block) }.
        map { |conf| cclone(conf.conf_name) }
        
      def result.each_conf(&block)
        each { |conf| conf.instance_eval(&block) }
      end
      result
    end

    private
    def confs_hash
      @configurations ||= Hash.new do |h,k|
        new_conf = Configuration.new(k.to_sym, self, [k.to_sym])
        new_conf.include(:base) if conf?(:base)
        h[k.to_sym] = new_conf
      end
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
end
