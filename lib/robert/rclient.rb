# require 'rubygems'
# require 'robert/toplevel'

# prev_stdout = $stdout
# prev_stderr = $stderr

# $str_stdout = StringIO.new
# $str_stderr = StringIO.new
# $stdout = $str_stdout
# $strerr = $str_stderr

# begin
#   env = Marshal.restore(STDIN)

#   def load_conf(_t, _c)
#     _t.instance_eval { eval(_c, binding) }
#   end

#   $top = Robert::TopLevel.new
#   load_conf($top, env.fetch(:conf))
#   $top.collect_rules
#   $top.var[:log,:log_level] = lambda { -1 }

#   conf = $top.conf(env.fetch(:conf_name))
#   target_rule_ctx = env.fetch(:rule_ctx)

#   target_act = nil
#   conf.acts.each do |k,v|
#     passed_acts = []
#     v.iterate_with_ctx([conf.conf_name]) do |act, ctx, cur_ctx_part, call_next|
#       if ctx == target_rule_ctx
#         target_act = act.args.first
#       else
#         passed_acts << act
#         call_next.call
#       end
#     end
#   end

#   def assign_call_next(act)
#     act_args = act.args.select { |a| a.respond_to?(:uid) }
#     if act_args.empty?
#       act.args << Robert::Act.new(:"_remote.callback", nil, [])
#     else
#       act_args.each { |a| assign_call_next(a) }
#     end
#   end
#   assign_call_next(target_act)

#   $top.defn :"_remote.callback" do
#     body { |*args|
#       $remote_callback_args = args
#     }
#   end

#   raise "can't find corresponding remote act" unless target_act

#   conf.act[:_remote] = target_act

#   conf.apply_extensions($top.extensions)
#   conf.compose_acts_into_self(target_rule_ctx, $top.actions)
#   def conf.rules
#     $top.rules
#   end

#   $top.var[:log,:log_level] = lambda { 5 }
#   conf._remote
# ensure
#   $stdout = prev_stdout
#   $stderr = prev_stderr
#   Marshal.dump([$!, $remote_callback_args, $str_stdout.string, $str_stderr.string], $stdout)
# end
