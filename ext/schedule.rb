defn schedule.monthly do
  body { |*args|
    if Time.now.mday == 1
      call_next(*args)
    end
  }

  spec {
    it "calls next on May 1st, 1985" do
      flexmock(Time).should_receive(:now).and_return(Time.parse("May 1 12:00:00 GMT 1985"))

      @action.should_receive(:call_next).once

      @action.call
    end

    it "doesn't call next on May 2nd, 1985" do
      flexmock(Time).should_receive(:now).and_return(Time.parse("May 2 12:00:00 GMT 1985"))

      @action.should_receive(:call_next).never

      @action.call
    end
  }
end

defn schedule.weekly do
  body { |*args|
    if Time.now.wday == 1
      call_next(*args)
    end
  }

  spec {
    it "calls next on monday" do
      flexmock(Time).should_receive(:now).and_return(Time.parse("Mon Mar 29 12:00:00 GMT 2010"))

      @action.should_receive(:call_next).once

      @action.call
    end

    it "doesn't call next on tuesday" do
      flexmock(Time).should_receive(:now).and_return(Time.parse("Tue Mar 30 12:00:00 GMT 2010"))

      @action.should_receive(:call_next).never

      @action.call
    end
  }
end
