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
    @capistrano_conf ||= (result = ::Capistrano::Configuration.new
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
    )
  end
  private :capistrano_conf

  def setup_roles_hosts(opts)
    hosts = opts[:hosts] || var?[:hosts]
    roles = [var?[:role]].compact.flatten
    roles.each do |role|
      role_var_sym = "role_#{role}".to_sym
      capistrano_conf.roles.delete(role)
      capistrano_conf.role(role) { var[role_var_sym] }
    end
    raise "no hosts or roles specified" unless (hosts || (roles && !roles.empty?))
    [roles, hosts]
  end
  private :setup_roles_hosts

  def remote_run?(roles, hosts)
    capistrano_conf.find_servers(:roles => roles, :hosts => hosts).find { |serv| (serv.host != "127.0.0.1" && serv.host != "localhost") || serv.user != nil }
  end
  private :remote_run?

  def cap2syscmd(opts)
    res = []
    if opts[:env]
      res << "env"
      opts[:env].each { |k,v| res << "#{k}='#{v}'"}
    end
    res.empty? ? "" : res.join(" ") + " "
  end
  private :cap2syscmd

  def sudo(*parameters, &block)
    capistrano_conf.sudo(*parameters, &block)
  end

  def run(cmd, opts = {})
    roles, hosts = setup_roles_hosts(opts)
    capistrano_conf.run(cmd, opts.merge(:roles => roles, :hosts => hosts))
  end

  def capture(cmd, opts = {})
    roles, hosts = setup_roles_hosts(opts)
    capistrano_conf.capture(cmd, opts.merge(:roles => roles, :hosts => hosts))
  end

  def get(remote_path, path, opts = {}, &block)
    roles, hosts = setup_roles_hosts(opts)
    capistrano_conf.get(remote_path, path, opts.merge(:roles => roles, :hosts => hosts), &block)
  end

  def put(data, remote_path, opts = {})
    roles, hosts = setup_roles_hosts(opts)
    capistrano_conf.put(data, remote_path, opts.merge(:roles => roles, :hosts => hosts))
  end

  def upload(from, to, opts = {}, &block)
    roles, hosts = setup_roles_hosts(opts)
    capistrano_conf.upload(from, to, opts.merge(:roles => roles, :hosts => hosts), &block)
  end
end
