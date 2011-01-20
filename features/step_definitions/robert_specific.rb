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
Given /^(?:a )?rule ([^ ]+) \-> (.+)$/ do |rule_ctx_str,rule_val|
  rule_ctx = rule_ctx_str.split(/,/).map { |s| s =~ /\d+/ ? s.to_i : s.to_sym }
  
  @rule_storage ||= Robert::RuleStorage.new
  @rule_storage.add(Robert::Rule.new(rule_ctx, rule_val))
end

When /^I match rules? against context ([^ ]+)$/ do |rule_ctx_str|
  raise "no rules defined for scenario" unless @rule_storage
  rule_ctx = rule_ctx_str.split(/,/).map { |s| s =~ /\d+/ ? s.to_i : s.to_sym }

  begin
    @rule_match = @rule_storage.eval_rule(rule_ctx, nil)
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

