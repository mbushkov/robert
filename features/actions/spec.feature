Feature: custom actions' test code can be written 
  As a rob user
  In order to facilitate the development of custom Robert actions
  I want to be able to test them with RSpec easily

  Scenario: spec block with RSpec test is accepted inside action definition
    Given a Robert configuration with:
    """
    defn my.action do
      body {
      }
      spec {
        it "prints out a message" do
          puts "spec before"
        end
      }
    end
    """
    When I run "rob2 spec my.action"
    Then the output should contain "spec before"

  Scenario: @action variable contains the "current action" object. @action.call is used to call the functionality of defined action
    Given a Robert configuration with:
    """
    defn my.action do
      body {
        puts "action called"
      }
      spec {
        it "prints out a message" do
          @action.call
        end
      }
    end
    """
    When I run "rob2 spec my.action"
    Then the output should contain "action called"

  Scenario: @action variable can be used to define rules that affect action's behavior
    Given a Robert configuration with:
    """
    defn my.action do
      body {
        puts var[:message]
      }
      spec {
        it "prints out a message" do
          @action.var[:message] = "action called"
          @action.call
        end
      }
    end
    """
    When I run "rob2 spec my.action"
    Then the output should contain "action called"

  Scenario: @action is also a flexmock object which can be used to define expectations on any calls - on call_next() call, for example
    Given a Robert configuration with:
    """
    defn my.action do
      body {
        call_next 42
      }
      spec {
        it "calls next with 42" do
          @action.should_receive(:call_next).with(42)
          @action.call
        end
      }
    end
    """
    When I run "rob2 spec my.action"
    Then the exit status should be 0

  Scenario: @action is also a flexmock object which can be used to define expectations on any calls - on syscmd_output, for example
    Given a Robert configuration with:
    """
    defn my.action do
      body {
        output = syscmd_output("id")
        call_next "output: #{output}"
      }
      spec {
        it "calls next with 42" do
          @action.should_receive(:syscmd_output).with("id").and_return("user")
          @action.should_receive(:call_next).with("output: user")
          @action.call
        end
      }
    end
    """
    When I run "rob2 spec my.action"
    Then the exit status should be 0
