require 'spec_helper'

require 'robert/action'

include Robert

describe Action do
  it "correctly deduces lname from full name" do
    action = Action.new("lname.rname", nil, nil, nil)

    action.lname.should == :lname
  end

  it "correctly deduces rname from full name" do
    action = Action.new("lname.rname", nil, nil, nil)

    action.rname.should == :rname
  end

  it "returns nil if there's no rname" do
    action = Action.new("lname", nil, nil, nil)

    action.rname.should == nil
  end
end
