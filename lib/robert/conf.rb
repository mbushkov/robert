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

  class ConfigurationDescriptor
    attr_reader :conf_name

    def initialize(conf_name)
      @conf_name = conf_name
      @conf_blocks = []
    end

    def add_conf_block(&block)
      @conf_blocks << block
    end

    def apply_conf_blocks(dest)
      @conf_blocks.each { |cb| dest.instance_eval(&cb) }
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

    def include(*names)
      names.each {|name| $top.conf_descriptor(name).apply_conf_blocks(self) }
    end

    def actions
      $top.actions
    end

    protected
    attr_reader :conf_blocks
  end

  # ConfigurationsContainer should be mixed into class which should be able to define and handle
  # collection of configurations. Single configurations are defined with "conf" call. Batch operations
  # on configurations are performed with "confs" call. Groups of configurations are selected with "select".
  module ConfigurationsContainer
    def cclone(conf_name, &block)
      cs = conf_name.to_sym
      conf = Configuration.new(cs)

      es = extensions
      conf.extend(Module.new.module_eval {
        define_method :extensions do
          es
        end
        self
      })

      unless cs == :base or cs == :base_after
        conf.instance_eval(&block) if block
        conf_descriptor(cs).apply_conf_blocks(conf)
        conf_descriptor(:base_after).apply_conf_blocks(conf) if conf?(:base_after) && cs != :base && cs != :base_after
      end
        
      conf.extend(RulesEvaluator)
      class << conf
        alias_method :orig_rules, :rules
      end
      rs = rules
      conf.extend(Module.new.module_eval {
        define_method :rules do
          rs
        end
        self
      })
    end

    def confs_names
      cd_hash.keys.to_set
    end

    def conf(conf_name, &block)
      cd_hash[conf_name.to_sym].add_conf_block(&block)
    end
    
    def conf_descriptor(name)
      raise "no configuration for name '#{conf_name}'" unless cd_hash.key?(name.to_sym)
      cd_hash[name.to_sym]
    end

    def conf?(conf_name)
      cd_hash.key?(conf_name.to_sym)
    end
    
    def confs(*names, &block)
      raise ArgumentError, "no block given" unless block
      raise ArgumentError, "at least one configuration name was expected" if names.empty?
      options = names.last.respond_to?(:keys) ? names.pop : {}

      if names.length == 1 and names.first.respond_to?(:each) and !names.first.respond_to?(:gsub)
        names = names.first
      end

      sel_confs = names.map do |name|
        cd_hash[name.to_sym]
        cclone(name.to_sym)
      end.select do |conf|
        ConfigurationSelector.new(conf).with_options(options)
      end
    
      sel_confs.each { |conf_clone| conf(conf_clone.conf_name, &block) }
      nil
    end

    def select(&block)
      result = confs_names.map { |conf_name| cclone(conf_name) }.select { |conf| ConfigurationSelector.new(conf).instance_eval(&block) }
      def result.names
        map { |conf| conf.conf_name }
      end
      result
    end

    private
    def cd_hash
      @cd_hash ||= Hash.new do |h,k|
        new_cd = ConfigurationDescriptor.new(k.to_sym)
        unless k.to_sym == :base || k.to_sym == :base_after
          new_cd.add_conf_block do
            include(:base) if $top.conf?(:base)
          end
        end
        h[k.to_sym] = new_cd
      end
    end
  end
end
