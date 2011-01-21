Given /^a [Rr]obert configuration with:$/ do |string|
  Given %Q{a directory named ".robert/conf"}
  Given %Q{a file named ".robert/conf/cuke.rb" with:}, string
end

Before do
  @aruba_timeout_seconds = 5
  @__robert_original_home = ENV['HOME']
  @__robert_original_ignore_conf_paths = ENV['ROB_IGNORE_GLOBAL_CONFIGURATION_PATHS']
  
  ENV['HOME'] = File.expand_path(current_dir)
  ENV['ROB_IGNORE_GLOBAL_CONFIGURATION_PATHS'] = "1"
end

After do
  ENV['HOME'] = @__robert_original_home
  ENV['ROB_IGNORE_GLOBAL_CONFIGURATION_PATHS'] = @__robert_original_ignore_conf_path
end

require 'robert/rule'
Given /^(?:a )?rule ([^ ]+?) \-> (\d+)$/ do |rule_ctx_str,rule_val|
  rule_ctx = rule_ctx_str.split(/,/).map { |s| s =~ /\d+/ ? s.to_i : s.to_sym }
  
  @rule_storage ||= Robert::RuleStorage.new
  @rule_storage.add(Robert::Rule.new(rule_ctx, rule_val))
end

When /^I define rule ([^ ]+) \-> (.+)$/ do |rule_ctx_str,rule_val|
  rule_ctx = rule_ctx_str.split(/,/).map { |s| s =~ /\d+/ ? s.to_i : s.to_sym }
  
  @rule_storage ||= Robert::RuleStorage.new
  @rule_storage.add(Robert::Rule.new(rule_ctx, rule_val))
end

Then /^the rule ([^ ]+) \-> (.+) is overriden by rule ([^ ]+) \-> (.+)$/ do |rule_ctx_str,rule_var,over_rule_ctx_str,over_rule_var|
  raise "no rules defined for scenario" unless @rule_storage

  rule_ctx = rule_ctx_str.split(/,/).map { |s| s =~ /\d+/ ? s.to_i : s.to_sym }
  over_rule_ctx = over_rule_ctx_str.split(/,/).map { |s| s =~ /\d+/ ? s.to_i : s.to_sym }

  r = @rule_storage.find { |r| r.context == rule_ctx && r.value == rule_var }
  r.should_not be_nil

  r.overriden_by.should_not be_nil
  r.overriden_by.context.should == over_rule_ctx
  r.overriden_by.value.should == over_rule_var
end

Then /^rules? (.+ -> \d+) (?:are|is) selected after step (\d+)/ do |rules_strs,step|
  rules = rules_strs.split(/ ?and ?/).map { |s| s.split(/ -> /) }.map { |ctx,value| [ctx.split(/,/).map { |s| s.to_sym }, value] }
  rules.each do |ctx,value|
    [instance_variable_get("@rules_matching_step#{step}")].flatten.find { |r| r.context == ctx && r.value == value }.should_not be_nil
  end
end

When /^I match rules? against context ([^ ]+)$/ do |rule_ctx_str|
  raise "no rules defined for scenario" unless @rule_storage
  rule_ctx = rule_ctx_str.split(/,/).map { |s| s =~ /\d+/ ? s.to_i : s.to_sym }

  begin
    @rules_matching_step1, @rules_matching_step2, @rules_matching_step3 = @rule_storage.eval_rule_steps(rule_ctx)
    @rule_match = @rules_matching_step3.value
  rescue Robert::RuleStorage::NoSuitableRuleFoundError
    @rule_error = true
  end
end

Then /^the result of the match will be (.+)$/ do |match|
  @rule_match.should == match
end

Then /^the rule doesn\'t match/ do
  @rule_error.should_not be_nil
end

Then /^the rule will match/ do
  @rule_match.should_not be_nil
end

