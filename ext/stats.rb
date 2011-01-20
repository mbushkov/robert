defn stats.num_cpus do
  var[:linux,:cmd] = ->{ "grep -e '^processor' /proc/cpuinfo" }
  var[:linux,:count_lines] = ->{ true }
  var[:osx,:cmd] = ->{ "/usr/sbin/system_profiler -detailLevel full SPHardwareDataType | grep -e 'Total Number Of Cores\\|Number Of CPUs'" }
  var[:solaris,:cmd] = ->{ "psrinfo -p" }
  var[:solaris,:count_lines] = ->{ true }
  body {
    var[:role] = ->{ :host }
    output = capture(var[var[:os_type],:cmd])
    if var?[var[:os_type],:count_lines]
      result = output.split($/).size
    else
      raise "can't find any number in CPU-related output" unless output =~ /\d+/
      result = $&.to_i
    end
    has_next? ? call_next(result) : result
  }

  spec {
    before do
      @action.should_receive(:has_next?).and_return(true)
    end
    
    it "should work correctly on linux" do
      @action.var(:os_type) { :linux }
      @action.should_receive(:capture).and_return(<<__EOF)
processor	: 0
processor	: 1
__EOF
      @action.should_receive(:call_next).with(2).once

      @action.call
    end

    it "should work correctly on mac os x" do
      @action.var(:os_type) { :osx }
      @action.should_receive(:capture).and_return(<<__EOF)
      Total Number Of Cores: 4
__EOF
      @action.should_receive(:call_next).with(4).once

      @action.call
    end

    it "should work correctly on solaris" do
      @action.var(:os_type) { :solaris }
      @action.should_receive(:capture).and_return(<<__EOF)
1
__EOF
      @action.should_receive(:call_next).with(1).once

      @action.call
    end

    it "should raise if OS type is not set" do
      ->{ @action.call}.should raise_exception
    end

    it "should raise if OS type is unknown" do
      @action.var(:ostype) { :windows }
      ->{ @action.call}.should raise_exception
    end
  }
end
