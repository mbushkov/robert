require 'robert/rule'

include Robert

describe Rule, "split_array()" do
  it "correctly splits array with one * in the middle" do
    Rule.send(:split_array, [:a, :b, :*, :c], :*).should == [[:c], [:a, :b]]
  end

  it "correctply splits array with two * in the middle" do
    Rule.send(:split_array, [:a, :b, :*, :c, :d, :*, :e], :*).should == [[:e] , [:c, :d], [:a, :b]]
  end

  it "correctly splits array with * in the beginnin" do
    Rule.send(:split_array, [:*, :a, :b], :*).should == [[:a, :b]]
  end
end

describe Rule do
  it "matches if rule's context is equal to a given context" do
    Rule.new([:a, :b], 42).match([:a, :b]).should be_true
  end
  
  it "does not match if rule's context is different from a given context" do
    Rule.new([:a, :b], 42).match([:a, :c]).should be_false
  end

  it "does not match if marked overriden" do
    rule = Rule.new([:a, :b], 42)
    rule.overriden_by = Rule.new([:a, :b], 43)

    rule.match([:a, :b]).should be_false
  end

  it "matches when asterisk can be evaluated as an arbitrary number of tokens" do
    rule = Rule.new([:*, :b, :c], 42)
    rule.match([:a, :b, :c]).should be_true
    rule.match([:b, :c]).should be_true
  end

  it "a" do
    rule = Rule.new([:*,:check,:procs,:*,:cmd], 42)
    rule.match([:cmdline,:cmd]).should be_false
  end

  it "non-greedily expands asterisks from the end of the rule's context" do
    rule = Rule.new([:a, :*, :m, :*, :k, :b, :*, :c], 42)
    rule.match([:a, :k, :b, :m, :k, :b, :c]).should be_true
  end
end

describe RuleStorage do
  before do
    @storage = RuleStorage.new
  end

  def add_rule(ctx, val)
    @storage << Rule.new(ctx, val)
  end

  it "raises when no rules match" do
    add_rule([:a,:b,:c], 42)
    add_rule([:a,:b,:c], 43)
    add_rule([:a,:b,:c], 44)

    ->{ @storage.eval_rule([:a, :c, :d], self)}.should raise_exception(RuleStorage::NoSuitableRuleFoundError)
  end

  it "last rule of equal rules winds" do
    add_rule([:a,:b,:c], 42)
    add_rule([:a,:b,:c], 43)
    add_rule([:a,:b,:c], 44)

    @storage.eval_rule([:a,:b,:c], self).should == 44
  end

  it "more precise rule can be later overriden by more generic one" do
    add_rule([:a,:b,:d], 42)
    add_rule([:a,:*,:d], 43)

    @storage.eval_rule([:a,:b,:c,:d], self).should == 43
  end

  it "more precise rule can be later overriden by more generic one" do
    add_rule([:a,:c,:b,:d], 42)
    add_rule([:*,:b,:d], 43)

    @storage.eval_rule([:a,:c,:b,:d], self).should == 43
  end
end
