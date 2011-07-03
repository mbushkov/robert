require 'robert/act'

include Robert

describe ActionId do
  it "delegates calls to the call-later handler" do
    later = flexmock(lambda {})
    later.should_receive(:call).with(:"some_name.some_method", 42).once
    
    act_id = ActionId.new("some_name", &later)
    
    act_id.some_method(42)
  end
end

describe ActContextHandler do
  before do
    @add, @get, @leave = *0.upto(2).map do
      m = flexmock
      m.should_ignore_missing
      m
    end

    @handler = ActContextHandler.new(@add, @get, @leave)
  end
  
  it "calls leave-context handler after []" do
    @leave.should_receive(:call).once

    @handler[:a]
  end

  it "calls leave-context-handler after []=" do
    @leave.should_receive(:call).once

    @handler[:a] = 42
  end

  it "calls add-handler after []=" do
    @add.should_receive(:call).with(:a, 42).and_return(43).once

    @handler[:a] = 42
  end

  it "calls get-handler and returns its result after []" do
    @get.should_receive(:call).with(:a).and_return(42).once

    res = @handler[:a]

    res.should == 42
  end

  it "uses .name method for [] or []= argument, if possible" do
    @get.should_receive(:call).with(:another_name).once

    @handler[flexmock(:name => :another_name)]
  end
end

describe NSubContext do
  before do
    @conf = flexmock
  end
  
  it "does not perform if nsub_ctx is not a subpart of rule_ctx" do
    nsub = flexmock(NSubContext.new([:a, :b, :c], [:nsub]))

    nsub.should_receive(:perform_further)
    nsub.should_receive(:execute_further).never

    nsub.perform(@conf)
  end

  it "does not perform if only part of nsub_ctx is present in rule_ctx" do
    nsub = flexmock(NSubContext.new([:a, :b, :c, :nsub], [:nsub, :nsub_next]))

    nsub.should_receive(:perform_further)
    nsub.should_receive(:execute_further).never

    nsub.perform(@conf)
  end

  it "does perform if nsub_ctx is a subpart of rule_ctx" do
    nsub = flexmock(NSubContext.new([:a, :b, :c, :nsub, :nsub_next], [:nsub, :nsub_next]))

    nsub.should_receive(:perform_further)
    nsub.should_receive(:execute_further).once

    nsub.perform(@conf)
  end
end

describe ActsContainer do
  before do
    @ac = flexmock(Object.new.extend(ActsContainer))
  end

  it "allows to define act with []= notation" do
    fn = ->{}
    @ac.instance_eval do
      act[:name] = fn
    end

    @ac.acts[:name].should equal(fn)
  end

  it "returns defined act with [] notation" do
    fn = ->{}
    fn2 = nil
    @ac.instance_eval do
      act[:name] = fn
      fn2 = act[:name]
    end
    fn2.should equal(fn)
  end

  it "allows to define multiple acts with []= and [] notation" do
    fn = ->{}
    fn1 = nil
    fn2 = nil
    @ac.instance_eval do
      act[:name1] = act[:name2] = fn
      fn1 = act[:name1]
      fn2 = act[:name2]
    end

    fn1.should equal(fn)
    fn2.should equal(fn)
  end

  it "defines method on self when act is defined" do
    @ac.instance_eval do
      act[:some_act] = ->{}
    end

    @ac.should respond_to(:some_act)
  end

  it "defines act with fn_act when non-predefined methods are called" do
    @ac.should_receive(:fn_act).with(:"backup.mysql").once

    @ac.instance_eval do
      act[:some_act] = backup.mysql
    end
  end

  context "acts execution" do
    before do
      @ctx = flexmock
      @ctx.should_receive(:with_rule_ctx).and_return(@ctx).by_default
      @ctx.should_receive(:with_rules).and_return(@ctx).by_default
      @ctx.should_receive(:with_next_acts).and_return(@ctx).by_default
      @ctx.should_receive(:perform).by_default

      @ac = flexmock(Object.new.extend(ActsContainer), :ctx_counter_inc => 0)
    end

    it "defined act adds its name to rule_ctx before execution" do
      @ac.instance_eval do
        act[:some_act] = backup.mysql
      end

      @ctx.should_receive(:with_rule_ctx).with([:backup, :mysql]).and_return(@ctx).once
      
      @ac.acts[:some_act].call(@ctx)
    end

    it "defined act sets next act before execution" do
      fn = flexmock
      @ac.instance_eval do
        act[:some_act] = onfail.continue(fn)
      end

      @ctx.should_receive(:with_next_acts).with([fn]).and_return(@ctx).once

      @ac.acts[:some_act].call(@ctx)
    end

    it "defined act sets multiple next acts by grouping them with seq() before execution if needed" do
      fn1 = flexmock
      fn2 = flexmock
      fn_seq = flexmock

      @ac.instance_eval do
        act[:some_act] = onfail.continue(fn1, fn2)
      end

      @ac.should_receive(:seq).with(fn1, fn2).and_return(fn_seq)
      @ctx.should_receive(:with_next_acts).with([fn_seq]).and_return(@ctx).once

      @ac.acts[:some_act].call(@ctx)
    end

    it "defined act evaluates rules with with_rules before execution" do
      @ac.instance_eval do
        act[:some_act] = backup.mysql { var[:a] = 42 }
      end

      @ctx.should_receive(:with_rules).with(Proc).and_return(@ctx).once

      @ac.acts[:some_act].call(@ctx)
    end

    it "defined act calls .perform on execution" do
      @ac.instance_eval do
        act[:some_act] = backup.mysql
      end

      @ctx.should_receive(:perform).with(@ac, Proc).once

      @ac.acts[:some_act].call(@ctx)
    end
  end

  context "nsub handling" do
    before do
      @prev_top, $top = $top, flexmock(:ctx_counter_inc => 0)
      @ac = flexmock(Object.new.extend(ContextStateHolder).extend(ActsContainer))
    end

    it "defines a separate method for nsubbed subact" do
      @ac.instance_eval do
        act[:some_act] = onfail.continue(nsub(:failable_backup,
                                              backup.mysql))
      end

      @ac.should respond_to(:failable_backup)
    end

    it "calls only the needed subact when nsubbed method is called" do
      @ac.instance_eval do
        act[:some_act] = onfail.continue(nsub(:failable_backup,
                                              backup.mysql))
      end

      ac = @ac
      @ac.should_receive(:conf_name).and_return(:conf_name)
      @ac.should_receive(:actions).and_return({:"onfail.continue" => flexmock(:body => ->{ ac.onfail_continue }),
                                                :"backup.mysql" => flexmock(:body => ->{ ac.backup_mysql }) })
      @ac.should_receive(:onfail_continue).never
      @ac.should_receive(:backup_mysql).once

      @ac.failable_backup
    end
  end
end
