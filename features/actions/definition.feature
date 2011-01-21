Feature: custom actions can be defined
  As a rob user
  In order to extend rob's functionality
  I want to define custom actions

  Scenario: custom action can be defined with "defn" call
    Given a Robert configuration with:
    """
    defn my_namespace.my_action do
      body {
        puts "my action is working!"
      }
    end

    conf :cli do
      act[:test] = my_namespace.my_action
    end
    """
    When I run "rob2 test"
    Then the output should contain "my action is working!"

  Scenario: custom action can use call_next to call next action in the chain
    Given a Robert configuration with:
    """
    defn my_namespace.action do
      body {
        puts "The action was called!"
        call_next
      }
    end

    defn my_namespace.nested_action do
      body {
        puts "The nested action was called!"
      }
    end

    conf :cli do
      act[:test] = my_namespace.action(my_namespace.nested_action)
    end
    """
    When I run "rob2 test"
    Then the output should contain "The action was called!"
    And the output should contain "The nested action was called!"

  Scenario: custom action can use has_next to check if there's next action in the chain
    Given a Robert configuration with:
    """
    defn my_namespace.action do
      body {
        puts "has next action" if has_next?
      }
    end

    conf :cli do
      act[:test] = my_namespace.action
    end
    """
    When I run "rob2 test"
    Then the output should not contain "has next action"

  Scenario: custom action can have arguments
    Given a Robert configuration with:
    """
    defn my_namespace.action do
      body {
        call_next 42
      }
    end

    defn my_namespace.action_with_arguments do
      body { |num|
        puts "number is #{num}"
      }
    end

    conf :cli do
      act[:test] = my_namespace.action(my_namespace.action_with_arguments)
    end
    """
    When I run "rob2 test"
    Then the output should contain "number is 42"

  Scenario: custom action can have rules defined inside (rules will be prefixed with action name's left and right part)
    Given a Robert configuration with:
    """
    defn my_namespace.action do
      var[:my,:rule] = 42
      body {}
    end
    """
    When I run "rob2 dump rules"
    Then the output should contain "my_namespace,action,my,rule -> 42"

