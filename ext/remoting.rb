ext :remoting do
end

defn remote.call do
  require 'stringio'

  var(:rhome) { ".remoterob" }
  var(:rlib) { "#{var[:rhome]}/lib" }
  var(:rcore) { "#{var[:rlib]}/robert" }

  body { |*args|
    run "cd && mkdir -p #{var[:rhome]} #{var[:rcore]}"
    $top.core_paths.each { |cp| upload(cp, "#{var[:rcore]}/#{File.basename cp}")}

    corestr = $top.loaded_paths.inject(StringIO.new) do |io, lp|
      open(lp, "r") { |f| io.write(f.read); io.write("\n") }
      io
    end.string
    upload(StringIO.new(corestr), "#{var[:rlib]}/.ext.rb")

    result = capture("/opt/local/bin/ruby1.9 -I#{var[:rlib]} -- #{var[:rcore]}/rclient.rb", :data => Marshal.dump(:conf => corestr, :conf_name => conf_name, :rule_ctx => rule_ctx))
    error, next_args, stdout_str, stderr_str =  *Marshal.restore(result)

    puts "stdout:"
    puts stdout_str
    puts "stderr:"
    puts stderr_str
    raise error if error

    call_next_index(1, *next_args) if next_args
  }
end
