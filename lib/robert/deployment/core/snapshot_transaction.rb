require "ostruct"
require "robert/deployment/model/deployment"

module Robert
module Deployment
  
  class SnapshotTransactionCleaner
    attr :configuration_getter
    
    def initialize(configuration_getter)
      @configuration_getter = configuration_getter
    end
    
    def find_unfinished_deployments(unfinished_snap, cur_snap)
      result = []
      
      unfinished_snap.deployments.each do |unfinished_dep|
        cur_dep = cur_snap != nil ? cur_snap.find_deployment_by_name(unfinished_dep.name) : nil
        if !cur_dep || cur_dep != unfinished_dep
          result << OpenStruct.new(:cur_dep => cur_dep, :unfinished_dep => unfinished_dep)
        end
      end

      result
    end
    private :find_unfinished_deployments
    
    def clean_unfinished_deployment(unfinished_snap, unfinished_dep, cur_dep)
      puts "removing broken deployment: #{unfinished_dep.name}:#{unfinished_dep.revision}"
      conf = configuration_getter.call(unfinished_dep)          

      Deployment.transaction do
        begin
          conf.unlink_deployment
        rescue
          puts "unlink error, continuing"
        ensure
          unfinished_snap.delete_deployment(unfinished_dep)
        end

        if cur_dep
          conf = configuration_getter.call(cur_dep)
          conf.link_deployment

          unfinished_snap.add_deployment(cur_dep.clone)
        end
        unfinished_snap.save!
      end
    end
    private :clean_unfinished_deployment

    def clean_unfinished_snapshot(area)
      unfinished_snap = area.unfinished_snapshot
      
      if unfinished_snap
        find_unfinished_deployments(unfinished_snap, area.current_snapshot).each do |pair|
          clean_unfinished_deployment(unfinished_snap, pair.unfinished_dep, pair.cur_dep)
        end

        area.unfinished_snapshot = nil
        area.delete_snapshot(unfinished_snap)
        area.save!
      end
    end
    
  end

  class SnapshotTransactionError < RuntimeError
    attr_reader :transaction, :errors

    def initialize(transaction)
      @transaction = transaction
      @errors = {}
    end
    
    def [](name)
      errors[name]
    end

    def method_missing(name, *args, &block)
      errors.send name, *args, &block
    end

    def message
      lines = []
       errors.each_pair do |k,v|
         lines << "#{k} => #{v.message} #{v.backtrace.join("\n\t")}"
         lines << ""
       end
       lines.join("\n")      
    end
  end

  class SnapshotTransaction
    attr :configuration_getter
    
    def initialize(configuration_getter)
      @configuration_getter = configuration_getter
    end

    def prepare_and_save_new_snapshot(area)
      raise "there is already an unfinished snapshot in this area" if area.unfinished_snapshot
      new_snapshot = area.build_snapshot_from_snapshot(area.current_snapshot)
      new_snapshot.exists = true
      area.unfinished_snapshot = new_snapshot
      area.save!
      new_snapshot
    end
    private :prepare_and_save_new_snapshot

    def finish_new_snapshot(new_snapshot, area)
      Area.transaction do
        area.unfinished_snapshot = nil
        area.current_snapshot = new_snapshot
        area.save!
      end
    end
    private :finish_new_snapshot

    def deploy_single_deployment(arg, new_snapshot, prev_snapshot)
      dep = new_conf = nil
      if arg.respond_to?(:run) 
        new_conf = arg
        dep = OpenStruct.new(:name => new_conf.project_name, :revision => new_conf.revision.to_s)
      else
        dep = arg
        new_conf = configuration_getter.call(dep)
      end
      
      Deployment.transaction do
        new_dep = new_snapshot.find_or_initialize_deployment_by_name(dep.name)
        new_dep.revision = new_conf.revision.to_s
        new_dep.runtime_dependencies = new_conf.runtime_dependencies
        new_dep.deployed_at = Time.now
        new_dep.save!

        new_conf.deploy
        begin
          if prev_snapshot
            prev_dep = prev_snapshot.find_deployment_by_name(dep.name)
            prev_conf = configuration_getter.call(prev_dep) if prev_dep
            prev_conf.unlink_deployment if prev_conf
          end
        rescue => e
          puts "error #{e}, continuing"
        end
        new_conf.link_deployment
        begin
          new_conf.send(:deployment_succeeded) if new_conf.respond_to?(:deployment_succeeded)
        rescue => e
          new_conf.logger.important "after-deployment error: #{e}\n#{e.backtrace.join("\n\t")}"
          #TODO: process after-actual-deployment error
        end
      end

    rescue => e
      new_conf.send(:deployment_failed) if new_conf.respond_to?(:deployment_failed)
      raise e
    end
    private :deploy_single_deployment
    
    def clean_unfinished_snapshot(area)
      SnapshotTransactionCleaner.new(configuration_getter).clean_unfinished_snapshot(area)
    end
    private :clean_unfinished_snapshot
    
    def deploy_new_snapshot(area, deployments, options = {})
      return if deployments.empty?
      new_snapshot = prepare_and_save_new_snapshot(area)
      transaction_error = SnapshotTransactionError.new(self)
      successful_deployments = []
      deployments.each do |dep|
        begin
          deploy_single_deployment(dep, new_snapshot, area.current_snapshot)
          successful_deployments << dep
        rescue => e
          transaction_error[dep.name] = e
          break unless options[:ignore_errors]
        end
      end
      if options[:ignore_errors]
        finish_new_snapshot(new_snapshot, area)
        raise transaction_error unless transaction_error.empty?
      else 
        unless transaction_error.empty?
          clean_unfinished_snapshot area
          raise transaction_error
        else
          finish_new_snapshot(new_snapshot, area)
        end
      end
    end
    
    def deployment_transaction(area, options = {})
      raise ArgumentError, "block is expected" unless block_given?

      new_snapshot = prepare_and_save_new_snapshot(area)
      transaction_error = SnapshotTransactionError.new(self)

      deploy_operator = lambda do |*args|
        name = revision = conf = nil
        case args.length
        when 1 then conf = args.first
        when 2 then name, revision = *args
        else raise ArgumentError, "configuration or name and revision were epxected"
        end
        
        begin
          deploy_single_deployment(conf || OpenStruct.new(:name => name, :revision => revision), new_snapshot, area.current_snapshot)
        rescue => e
          transaction_error[name] = e
          raise transaction_error unless options[:ignore_errors]
        end
      end
      rollback_operator = lambda do 
        clean_unfinished_snapshot area
      end
      transaction_object = Object.new
      class << transaction_object; self; end.instance_eval do
        define_method :deploy do |*args|
          deploy_operator.call(*args)
        end
        define_method :rollback do
          rollback_operator.call
          throw :deployment_transaction
        end
      end
      
      catch :deployment_transaction do
        begin
          yield transaction_object
        rescue => e
          clean_unfinished_snapshot area
          raise e
        end
        finish_new_snapshot(new_snapshot, area)
        raise transaction_error unless transaction_error.empty?
      end
    end
    
  end
  
end
end
