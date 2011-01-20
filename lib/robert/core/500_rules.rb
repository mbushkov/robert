# using robrules to avoid name clash with :rules
# TODO: we should at least display a warning in case of name clash
defn robrules.dump do
  body {
    rules = $top.rules

    rules.each do |rule|
      rule_desc = "#{rule.context.join(',')} -> #{rule.value.respond_to?(:call) ? '...' : rule.value}"
      if rule.overriden_by
        rule_desc += red(" (OVERRIDEN by #{rule.overriden_by.context.join(",")})")
      end
      puts rule_desc
    end
  }
end

conf :rules do
  act[:dump] = act[:list] = robrules.dump
end
