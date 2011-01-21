Feature: rules can be evaluated
  As a rob user
  In order to get access to particular configuration values
  I want rules to be evaluated

  Scenario: rules can be evaluated inside actions
    Given a Robert configuration with:
    """
    var[:my,:rule] = 42
    defn my.action do
      body {
        puts var[:my,:rule]
      }
    end

    conf :cli do
      act[:test] = my.action
    end
    """
    When I run "rob2 test"
    Then the output should contain "42"

  Scenario: rules can be evaluated inside methods
    Given a Robert configuration with:
    """
    var[:my,:rule] = 42

    conf :cli do
      def test
        puts var[:my,:rule]
      end
    end
    """
    When I run "rob2 test"
    Then the output should contain "42"

  Scenario: rules can be evaluated inside other rules if they're set with block or a lambda
    Given a Robert configuration with:
    """
    var[:my,:rule] = 42
    var(:my,:sum,:rule) { var[:my,:rule] + 1 }

    defn my.action do
      body {
        puts var[:my,:sum,:rule]
      }
    end

    conf :cli do
      act[:test] = my.action
    end
    """
    When I run "rob2 test"
    Then the output should contain "43"

  Scenario: rules can't be evaluated inside configurations' definitions
    Given a Robert configuration with:
    """
    var[:my,:rule] = 42
    
    puts var[:my,:rule]
    """
    When I run "rob2 dump rules"
    Then the exit status should not be 0

