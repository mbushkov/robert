Feature: global commands
  In order to define and use some inter- or multi- configuration functionality
  As a rob user
  I want to be able to define global commands

  Scenario: method defined with 'def' in the 'cli' configuration is used as global command
    Given a Robert configuration with:
    """
    conf :cli do
      def test_output
        puts "global test_output command executed"
      end
    end
    """
    When I run "rob2 test_output"
    Then the output should contain "global test_output command executed"

  Scenario: method defined through 'act[]=' in the 'cli' configuration is used as global command
    Given a Robert configuration with:
    """
    conf :cli do
      act[:test_output] = console.print { var[:message] = "global test_output command executed" }
    end
    """
    When I run "rob2 test_output"
    Then the output should contain "global test_output command executed"

