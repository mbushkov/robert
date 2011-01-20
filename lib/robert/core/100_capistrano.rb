ext :capistrano do
  require 'capistrano'
  require 'capistrano/cli'

  class ConnectionFactoryWithCaching
    def initialize(wrapped_factory)
      @wrapped_factory = wrapped_factory
      @cached_sessions = {}
      @cached_pid = $$
      @lock = Mutex.new
    end

    def connect_to(server)
      session = nil
      @lock.synchronize do
        if @cached_pid != $$
          @cached_pid = $$
          @cached_sessions = {}
        else
          session = @cached_sessions[server]
        end
      end
      if session.nil?
        session = @wrapped_factory.connect_to(server)
        @lock.synchronize { @cached_sessions[server] = session }
      end
      session
    end
  end

  def capistrano_conf
    result = ::Capistrano::Configuration.new
    $connection_factory_with_scm ||= (ConnectionFactoryWithCaching.new(result.connection_factory))
    def result.connection_factory
      $connection_factory_with_scm
    end
    start_pid = $$
    prev_establish_connection = result.method(:establish_connection_to)
    class << result; self; end.class_eval do
      define_method :establish_connection_to do |*args|
        if $$ != start_pid
          start_pid = $$
          sessions.clear
        end
        prev_establish_connection.call(*args)
      end
    end
    if $capistrano_sudo_password
      result.set(:password, $capistrano_sudo_password)
    else
      result.set(:password) { ::Capistrano::CLI.password_prompt }
      $capistrano_sudo_password = lambda { result.password }
    end
    result.set(:ssh_options, var?[:capistrano,:ssh_options])
    result.logger.level = ::Capistrano::Logger::TRACE
    result
  end
  private :capistrano_conf

  def with_capistrano(options = {}, &block)
    cf = capistrano_conf
    this = self

    roles_names = options[:roles] && [options[:roles]].flatten
    if roles_names
      role_data = roles_names.inject([]) { |memo,obj| var[:role,obj].concat(memo) }
    else
      role_data = var[:role]
    end
    
    role_data.each do |rd|
      if rd.respond_to?(:has_key?)
        raise "not implemented"
      else
        cf.role(:robert, rd)
      end
    end
    
    cf.task(:_robert) do
      this.instance_exec(cf, &block)
    end
    
    cf._robert
  end
end

conf :base do
  use :capistrano
end
