require 'robert/rule'

include Robert

describe Rule do
  it "does not match if marked overriden" do
    rule = Rule.new([:a, :b], 42)
    rule.overriden_by = Rule.new([:b], 43)

    rule.match([:a, :b]).should be_nil
  end

  it "does not match if the last token of the rule is different from the last token of the context" do
    Rule.new([:a, :b], 42).match([:a, :c]).should be_nil
  end

  it "returns nil if the rule is not fully contained inside the context" do
    Rule.new([:a, :b], 42).match([:b]).should be_nil
  end

  it "returns nil if the rule's tokens are contained inside the context in different order" do
    Rule.new([:a, :b], 42).match([:b, :a]).should be_nil
  end

  it "returns index of the match of the first rule's token inside the context" do
    Rule.new([:a, :b], 42).match([:c, :d, :a, :b]).should == 2
    Rule.new([:a, :b], 42).match([:a, :b, :a, :b]).should == 2
  end
  
  it "works correctly in a series of real-world cases" do
    Rule.new([:Project, :backup, :continue, 1, :email, 1, :s3, 1, :www_dump, 0, :role], 42).match([:Project,:backup,:continue,1,:email,1,:s3,1,:www_dump,0,:continue,0,:email,0,:s3,0,:base,:s3,0,:capistrano,0,:role]).should_not be_nil
    Rule.new([:Project, :role_www], 42).match([:Project,:backup,:onfail,:continue,0,:notify,:email,0,:rsync,0,:role_www]).should_not be_nil
    Rule.new([:ssh,:authorized_keys,:public_key_path], 42).match([:Project,:backup,:onfail,:continue,0,:notify,:email,0,:rsync,0,:ssh,:public_key_path]).should be_nil
    Rule.new([:localhost,:check,:onfail,:continue,0,:notify,:campfire,1,:failure,:message], 42).match([:localhost,:check,:onfail,:continue,0,:notify,:campfire,1,:failure,:notify,:campfire,1,:message]).should_not be_nil
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
    add_rule([:a,:d], 43)

    @storage.eval_rule([:a,:b,:c,:d], self).should == 43
  end

  it "more precise rule can be later overriden by more generic one" do
    add_rule([:a,:b,:d], 42)
    add_rule([:b,:d], 43)

    @storage.eval_rule([:a,:b,:c,:d], self).should == 43
  end

  it "more precise rule can be later overriden by more generic one" do
    add_rule([:Project,:email,:to], 42)
    add_rule([:email,:to], 43)

    @storage.eval_rule([:Project,:backup,:email,:to], self).should == 43
  end

  it "more generic rule does not override more precise one if last elements don't match" do
    add_rule([:ec2,:home,:bin], 42)
    add_rule([:ec2,:home], 43)

    @storage.eval_rule([:ec2,:home,:bin], self).should == 42
  end

  it "among matched rules one with the first different element, which match is closer to the right boerder of the context, wins" do
    add_rule([:backup,:remote_host_file,:dir], 42)
    add_rule([:backup,:same_host_file,:dir], 43)

    @storage.eval_rule([:Project,:backup,:same_host_file,:remote_host_file,0,:dir], self).should == 42
  end

  it "among matched rules one with the first different element, which match is closer to the right boerder of the context, wins" do
    add_rule([:backup,:remote_host_file,:dir], 42)
    add_rule([:backup,:same_host_file,:dir], 43)

    @storage.eval_rule([:Project,:backup,:same_host_file,:dir,:remote_host_file,0,:dir], self).should == 42
  end

  it "among matched rules one with the first different element, which match is closer to the right boerder of the context, wins" do
    add_rule([:Project,:process,:backup,:remote_host_file,:dir], 42)
    add_rule([:Project,:action,:backup,:same_host_file,:dir], 43)

    @storage.eval_rule([:Project,:action,:process,:backup,:same_host_file,:dir,:remote_host_file,0,:dir], self).should == 42
  end

  it "among matched rules one with the first different element, which match is closer to the right boerder of the context, wins" do
    add_rule([:Project,:process,:a,:backup,:remote_host_file,:dir], 42)
    add_rule([:Project,:action,:b,:backup,:same_host_file,:dir], 43)

    @storage.eval_rule([:Project,:action,:process,:b,:a,:backup,:same_host_file,:dir,:remote_host_file,:dir], self).should == 42
  end

  it "among matched rules one with the first different element, which match is closer to the right boerder of the context, wins" do
    add_rule([:Project,:backup,:rsync,0,:to], 42)
    add_rule([:notify,:email,:to], 43)

    @storage.eval_rule([:Project,:backup,:onfail,:continue,0,:notify,:email,0,:rsync,0,:to], self).should == 42
  end

  it "among matched rules one with the first different element, which match is closer to the right boerder of the context, wins" do
    add_rule([:a,:c], 42)
    add_rule([:a,:b,:c], 43)

    @storage.eval_rule([:a,:b,:a,0,:c], self).should == 42
  end

  it "among matched rules one with the first different element, which match is closer to the right boerder of the context, wins" do
    add_rule([:email, :to], 42)
    add_rule([:rsync, :to], 43)

    @storage.eval_rule([:Project,:continue,:email,:rsync,:to], self).should == 43
  end

  it "among matched rules the one, where first element matches first context element, wins" do
    add_rule([:s3,:base,:acl], 42)
    add_rule([:Project,:s3,:acl], 43)

    @storage.eval_rule([:Project,0,:s3,:sync_with_md5_check,0,:base,:temp_fname_support,0,:s3,:bucket,0,:base,0,:acl], self).should == 43
  end

  it "among matched rules the one, where first element matches first context element, wins" do
    add_rule([:db,:mysql,:check,:quick], 42)
    add_rule([:Project,:backup,:db_check,0,:quick], 43)

    @storage.eval_rule([:Project,:backup,:onfail,:continue,0,:notify,:email,0,:db_check,0,:db,:mysql,1,:check,:quick], self).should == 43
  end

  it "rule with first token equal to context's first token has more priority" do
    add_rule([:localhost,:host,:user], 42)
    add_rule([:mysql,:user], 43)

    @storage.eval_rule([:localhost,:host,:backup,0,:mysql,:user], self).should == 42
  end

  it "more generic rule does not override next more concrete one" do
    add_rule([:a,:c], 42)
    add_rule([:a,:b,:c,:a,:c], 43)

    @storage.eval_rule([:a,:b,:c,:a,0,:c], self).should == 43
  end

  it "more generic rule does not override next more concrete one" do
    add_rule([:a,:c], 42)
    add_rule([:a,:b,:a,:c], 43)

    @storage.eval_rule([:a,:b,:a,0,:c], self).should == 43
  end

  it "NOTE: potential cause of problems - generic rules may unexpectedly match" do
    add_rule([:backup,:db_hotcopy,:suffix], 42)

    @storage.eval_rule([:Project,:backup,:onfail,:continue,0,:notify,:email,0,:db_hotcopy,0,:db,:mysql,1,:hotcopy,:suffix], self).should_not be_nil
  end
end
