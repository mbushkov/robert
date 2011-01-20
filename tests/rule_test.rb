require "rubygems"
require "test/unit"
require "flexmock/test_unit"
require "robert/rule"

class RuleTest < Test::Unit::TestCase
  Rule = Robert::Rule

  def setup
    @ctx = [:some_context, :some, 0, :some_context, :some, 1, :length]
  end

  def test_rule_with_different_last_token_is_not_applicable
    assert !Rule.new([:some_context, :some, 0, :some_context, :some, 1], 42).match(@ctx)
  end

  def test_rule_with_same_start_and_same_last_token_is_applicable
    assert Rule.new([:some_context, :some, :length], 42).match(@ctx)
  end

  def test_rule_with_same_start_same_token_in_the_middle_and_same_last_token_is_applicable
    assert Rule.new([:some_context, :some, :some_context, :length], 42).match(@ctx)
  end

  def test_rule_with_same_groups_of_tokens_in_the_middle_and_same_last_token_is_applicable
    assert Rule.new([:some, 0, :some, 1, :length], 42).match(@ctx)
  end

  def test_practical_rule_is_correctly_applied_1
    assert Rule.new([:Project, :backup, :continue, 1, :email, 1, :s3, 1, :www_dump, 0, :role], 42).match([:Project,:backup,:continue,1,:email,1,:s3,1,:www_dump,0,:continue,0,:email,0,:s3,0,:base,:s3,0,:capistrano,0,:role])
  end

  def test_practical_rule_is_correctly_applied_2
    assert Rule.new([:Project, :role_www], 42).match([:Project,:backup,:onfail,:continue,0,:notify,:email,0,:rsync,0,:role_www])
  end

  def test_practical_rule_is_correctly_applied_3
    assert !Rule.new([:ssh,:authorized_keys,:public_key_path], 42).match([:Project,:backup,:onfail,:continue,0,:notify,:email,0,:rsync,0,:ssh,:public_key_path])
  end

  def test_practical_rule_is_correctly_applied_4
    assert Rule.new([:localhost,:check,:onfail,:continue,0,:notify,:campfire,1,:failure,:message], 42).match([:localhost,:check,:onfail,:continue,0,:notify,:campfire,1,:failure,:notify,:campfire,1,:message])
  end
end

class RuleStorageTest < Test::Unit::TestCase
  def setup
    @storage = Robert::RuleStorage.new
  end

  def add_rule(ctx, val)
    @storage << Robert::Rule.new(ctx, val)
  end

  def test_raises_when_no_rules_match
    add_rule([:a,:b,:c], 42)
    add_rule([:a,:b,:c], 43)
    add_rule([:a,:b,:c], 44)

    assert_raise(Robert::RuleStorage::NoSuitableRuleFoundError) { @storage.eval_rule([:a,:c,:b], self) }    
  end

  def test_last_rule_of_equal_rules_wins
    add_rule([:a,:b,:c], 42)
    add_rule([:a,:b,:c], 43)
    add_rule([:a,:b,:c], 44)

    assert_equal(44, @storage.eval_rule([:a,:b,:c], self))
  end

  def test_among_more_precise_rule_can_be_later_overriden_by_more_generic_one
    add_rule([:a,:b,:d], 42)
    add_rule([:a,:d], 43)

    assert_equal(43, @storage.eval_rule([:a,:b,:c,:d], self))
  end

  def test_among_more_precise_rule_can_be_later_overriden_by_more_generic_one_2
    add_rule([:a,:b,:d], 42)
    add_rule([:b,:d], 43)

    assert_equal(43, @storage.eval_rule([:a,:b,:c,:d], self))
  end

  def test_among_more_precise_rule_can_be_later_overriden_by_more_generic_one_3
    add_rule([:Project,:email,:to], 42)
    add_rule([:email,:to], 43)

    assert_equal(43, @storage.eval_rule([:Project,:backup,:email,:to], self))
  end

  def test_more_generic_rule_does_not_override_more_precise_one_if_last_elements_dont_match
    add_rule([:ec2,:home,:bin], 42)
    add_rule([:ec2,:home], 43)

    assert_equal(42, @storage.eval_rule([:ec2,:home,:bin], self))    
  end

  def test_among_matched_rules_rule_with_first_different_element_from_the_right_closer_to_the_right_in_context_wins
    add_rule([:backup,:remote_host_file,:dir], 42)
    add_rule([:backup,:same_host_file,:dir], 43)

    assert_equal(42, @storage.eval_rule([:Project,:backup,:same_host_file,:remote_host_file,0,:dir], self))
  end

  def test_among_matched_rules_rule_with_first_different_element_from_the_right_closer_to_the_right_in_context_wins_2
    add_rule([:backup,:remote_host_file,:dir], 42)
    add_rule([:backup,:same_host_file,:dir], 43)

    assert_equal(42, @storage.eval_rule([:Project,:backup,:same_host_file,:dir,:remote_host_file,0,:dir], self))
  end

  def test_among_matched_rules_rule_with_first_different_element_from_the_right_closer_to_the_right_in_context_wins_3
    add_rule([:Project,:process,:backup,:remote_host_file,:dir], 42)
    add_rule([:Project,:action,:backup,:same_host_file,:dir], 43)

    assert_equal(42, @storage.eval_rule([:Project,:action,:process,:backup,:same_host_file,:dir,:remote_host_file,0,:dir], self))
  end

  def test_among_matched_rules_rule_with_first_different_element_from_the_right_closer_to_the_right_in_context_wins_4
    add_rule([:Project,:process,:a,:backup,:remote_host_file,:dir], 42)
    add_rule([:Project,:action,:b,:backup,:same_host_file,:dir], 43)

    assert_equal(42, @storage.eval_rule([:Project,:action,:process,:b,:a,:backup,:same_host_file,:dir,:remote_host_file,:dir], self))
  end

  def test_among_matched_rules_rule_with_first_different_element_from_the_right_closer_to_the_right_in_context_wins_5
    add_rule([:Project,:backup,:rsync,0,:to], 42)
    add_rule([:notify,:email,:to], 43)

    assert_equal(42, @storage.eval_rule([:Project,:backup,:onfail,:continue,0,:notify,:email,0,:rsync,0,:to], self))
  end

  def test_among_matched_rules_rule_with_first_different_element_from_the_right_closer_to_the_right_in_context_wins_6
    add_rule([:a,:c], 42)
    add_rule([:a,:b,:c], 43)

    assert_equal(42, @storage.eval_rule([:a,:b,:a,0,:c], self))
  end

  def test_among_matched_rules_rule_with_first_different_element_from_the_right_closer_to_the_right_in_context_wins_7
    add_rule([:email, :to], 42)
    add_rule([:rsync, :to], 43)

    assert_equal(43, @storage.eval_rule([:Project,:continue,:email,:rsync,:to], self))
  end

  def test_if_first_rule_element_matches_first_context_element_the_rule_wins
    add_rule([:s3,:base,:acl], 42)
    add_rule([:Project,:s3,:acl], 43)

    assert_equal(43, @storage.eval_rule([:Project,0,:s3,:sync_with_md5_check,0,:base,:temp_fname_support,0,:s3,:bucket,0,:base,0,:acl], self))
  end

  def test_if_rule_matches_the_end_of_the_context_perfectly_it_wins
    add_rule([:localhost,:host,:user], 42)
    add_rule([:mysql,:user], 43)

    assert_equal(43, @storage.eval_rule([:localhost,:host,:backup,0,:mysql,:user], self))
  end

  def test_if_one_rule_is_subset_of_another_the_longer_one_wins
    add_rule([:a,:c], 42)
    add_rule([:a,:b,:c,:a,:c], 43)

    assert_equal(43, @storage.eval_rule([:a,:b,:c,:a,0,:c], self))
  end

#  def test_problemmatic_test
#    add_rule([:backup,:db_hotcopy,:suffix], 42)
#
#    assert_raise(RuntimeError) do
#      @storage.eval_rule([:Project,:backup,:onfail,:continue,0,:notify,:email,0,:db_hotcopy,0,:db,:mysql,1,:hotcopy,:suffix], self)
#    end
#  end

  def test_problemmatic_test2
    add_rule([:db,:mysql,:check,:quick], 42)
    add_rule([:Project,:backup,:db_check,0,:quick], 43)

    assert_equal(43, @storage.eval_rule([:Project,:backup,:onfail,:continue,0,:notify,:email,0,:db_check,0,:db,:mysql,1,:check,:quick], self))
  end

  def test_if_one_rule_is_subset_of_another_the_longer_one_wins_2
    add_rule([:a,:c], 42)
    add_rule([:a,:b,:a,:c], 43)

    assert_equal(43, @storage.eval_rule([:a,:b,:a,0,:c], self))
  end
end
