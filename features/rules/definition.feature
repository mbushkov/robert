Feature: rules can have constant values or being evaluated every time they're accessed
  As a rob user
  In order to achieve maximum flexibility when using rules
  I want to set rules values to constants or to blocks of code

  Scenario: rules can be set to constants
    Given a Robert configuration with:
    """
    var[:my_project,:var] = 42
    """
    When I run "rob2 eval my_project,var"
    Then the output should contain "42"
    
  Scenario: multiple rules can be set in one series of assignments
    Given a Robert configuration with:
    """
    var[:my_project,:var] = var[:my_project,:another_var] = 42
    """
    When I run "rob2 eval my_project,var"
    Then the output should contain "42"
    When I run "rob2 eval my_project,another_var"
    Then the output should contain "42"

  Scenario: rules can be set to lambdas
    Given a Robert configuration with:
    """
    var[:my_project,:var] = ->{ 42 }
    """
    When I run "rob2 eval my_project,var"
    Then the output should contain "42"

  Scenario: rules set with lambdas can reference other rules
    Given a Robert configuration with:
    """
    var[:my_project,:var] = ->{ 42 }
    var[:my_project,:another_var] = ->{ var[:my_project,:var] + 1 }
    """
    When I run "rob2 eval my_project,another_var"
    Then the output should contain "43"

  Scenario: rules can be set with blocks instead of lambdas
    Given a Robert configuration with:
    """
    var(:my_project,:var) { 42 }
    var(:my_project,:another_var) { var[:my_project,:var] + 1 }
    """
    When I run "rob2 eval my_project,another_var"
    Then the output should contain "43"


