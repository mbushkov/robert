Feature: actions can be used inside configurations
  As a rob user
  In order to apply actions' functionality
  I want to be able to use them

  Scenario: actions become methods of configurations after assigning them to configurations using act[]= syntax
    Given a Robert configuration with:
    """
    defn my.action do
      body {
        puts "my action executed"
      }
      spec {
      }
    end

    conf :cli do
      act[:test] = my.action(my.nested_action)
    end
    """
    When I run "rob2 test"
    Then the output should contain "my action executed"

  Scenario: defined acts can be used in other acts' definitions
    Given a Robert configuration with:
    """
    defn my.action do
      body {
        call_next
      }
    end

    conf :cli do
      act[:test_print] = console.print { var[:message] = "42" }
      act[:test] = my.action(act[:test_print])
    end
    """
    When I run "rob2 test"
    Then the output should contain "42"

  Scenario: defined acts are copied, not referenced, when they're used in other acts' definitions
    Given a Robert configuration with:
    """
    defn my.action do
      body {
        call_next
      }
    end

    conf :cli do
      act[:test_print] = console.print { var[:message] = "42" }
      act[:test] = my.action(act[:test_print])
      act[:test_print] = console.print { var[:message] = "43" }
    end
    """
    When I run "rob2 test"
    Then the output should contain "42"

  Scenario: act can be defined even if there's no action with provided name is found - as long as this act is not called
    Given a Robert configuration with:
    """
    conf :cli do
      act[:something_special] = something.special
    end
    """
    When I run "rob2 dump rules"
    Then the exit status should be 0

  @announce-stderr
  Scenario: if the act with undefined action inside is called, error is thrown
    Given a Robert configuration with:
    """
    conf :cli do
      act[:something_special] = something.special
    end
    """
    When I run "rob2 something_special"
    Then the exit status should not be 0
