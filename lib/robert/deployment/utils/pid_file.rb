module Robert
module Deployment

  class PidFile
    attr_reader :path

    def initialize(path)
      @path = path
      @lock_count = 0
      @fd = nil
    end

    def is_locked?
      return $$ if @lock_count > 0
      return nil unless File.exists?(@path)

      open(@path, "a+") do |pidfile|
        if pidfile.flock(File::LOCK_EX | File::LOCK_NB)
          pidfile.flock(File::LOCK_UN)
          return nil
        end

        pidfile.flock(File::LOCK_SH)
        begin
          pidfile.rewind
          return Integer(pidfile.readline)
        ensure
          pidfile.flock(File::LOCK_UN)
        end
      end
    end

    def lock_nb
      if @lock_count > 0
        @lock_count += 1
        return true
      end

      should_chmod = !File.exists?(@path)
      @fd = open(@path, "a+")
      @fd.chmod 0666 if should_chmod
      if !@fd.flock(File::LOCK_EX | File::LOCK_NB)
        @fd.close
        @fd = nil
        return false
      end

      begin
        File.truncate(@path, 0)
        @fd.puts($$)
        @lock_count += 1
        raise "internal locking error on #{@path}" unless @fd.flock(File::LOCK_SH | File::LOCK_NB)
        return true
      rescue 
        @fd.flock(File::LOCK_UN)
        @fd.close
        @fd = nil
        raise
      end
    end

    def unlock_nb
      raise RuntimeError, "trying to unlock not PidFile, that is not locked" unless @lock_count > 0

      @lock_count -= 1
      if @lock_count == 0
        @fd.flock(File::LOCK_UN)
        @fd.close
        @fd = nil
      end
    end

    def synchronize_nb
      if lock_nb
        begin
          yield
          return true
        ensure
          unlock_nb
        end
      end

      return false
    end
    
    def to_s
      @path
    end
  end

end
end
