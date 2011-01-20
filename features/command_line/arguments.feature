@announce-stdout
Feature: command line arguments are processed into command and rules
  In order to affect Robert execution
  As a rob user
  I want command line arguments to be treated as command+rules

  Scenario: first argument is treated as command name, for others corresponding rules are created
    When I run "rob2 dump rules"
    Then the output should contain "cmdline,cmd -> dump"
    And the output should contain "cmdline,args,0 -> "
    And the output should contain "cmdline,args,rules -> "

  Scenario: second argument is aliased with cmdline,names rule
    Given a Robert configuration with:
    """
    conf :cli do
      def print_names
        puts var[:cmdline,:names].join(",")
      end
    end
    """
    When I run "rob2 print_names name1,name2,name3"
    Then the output should contain "name1,name2,name3"

  Scenario: arguments without right side are treated as rules with boolean true value
    Given a Robert configuration with:
    """
    conf :cli do
      def print_arg
        puts "sample_arg=#{var[:cmdline,:args,:sample_arg]}"
      end
    end
    """
    When I run "rob2 print_arg sample_arg"
    Then the output should contain "sample_arg=true"

  Scenario: arguments with right side are treated as rules with right side as their value"
    When I run "rob2 dump rules sample_rule=42"
    Then the output should contain "cmdline,args,sample_rule -> 42"

  Scenario: using commas in arguments allows rules with more concrete context to be defined"
    When I run "rob2 dump rules some1,some2=42"
    Then the output should contain "cmdline,args,some1,some2 -> 42"

  Scenario: using commas in right side of arguments makes them treated as arrays
    When I run "rob2 dump rules sample_rule=rhs1,rhs2"
    Then the output should contain:
    """
    cmdline,args,sample_rule -> ["rhs1", "rhs2"]
    """

  Scenario: in right parts of arguments numerical values are treated as numbers
    Given a Robert configuration with:
    """
    conf :cli do
      def pretty_print_arg
        p var[:cmdline,:args,:some_id] + 1
      end
    end
    """
    When I run "rob2 pretty_print_arg some_id=42"
    Then the output should contain "43"

  Scenario: in right parts of arguments non-numerical values are treated as strings
    Given a Robert configuration with:
    """
    conf :cli do
      def pretty_print_arg
        p var[:cmdline,:args,:some_id]
      end
    end
    """
    When I run "rob2 pretty_print_arg some_id=some_value"
    Then the output should contain:
    """
    "some_value"
    """

