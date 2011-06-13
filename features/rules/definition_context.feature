@dev
Feature: when rules are defined, they're prefixed by current context (which depends on the place of definition) and with "*"
  As a rob user
  In order to narrow the defined rules without making them extremely verbose
  I want some "context" to affect the prefix of the rule

  Scenario: rule defined globally are prefixed with single *
    Given a Robert configuration with:
    """
    var[:my,:rule] = 42
    """
    When I run "rob2 dump rules"
    Then the output should match /^*,my,rule -> 42$/

  Scenario: rule defined inside action is prefixed with *, action's name's left and right parts and
    Given a Robert configuration with:
    """
    defn my.action do
      var[:some,:rule] = 42
      body {
      }
    end
    """
    When I run "rob2 dump rules"
    Then the output should contain "*,my,action,some,rule -> 42"

  @announce-stdout
  Scenario: rule defined inside the configuration is prefixed with configuration name and *
    Given a Robert configuration with:
    """
    conf :some_conf do
      var[:my,:rule] = 42
    end
    """
    When I run "rob2 dump rules"
    Then the output should contain "some_conf,*,my,rule -> 42"

  @announce-stdout
  Scenario: rule defined in the block within act[]= assignment is prefixed with: configuration's name, act's name, action name's left and right parts
    Given a Robert configuration with:
    """
    conf :cli do
      act[:test] = console.print { var[:message] = "42" }
    end
    """
    When I run "rob2 dump rules"
    Then the output should match /cli,test,console,print,message -> 42/

  @announce-stdout
  Scenario: rule defined inside the nested action in act[]= assignment is prefixed with: configuration name, act name, and for each action in chain - left and right part
    Given a Robert configuration with:
    """
    conf :cli do
      act[:test] = onfail.continue(console.print { var[:message] = "42" })
    end
    """
    When I run "rob2 dump rules"
    Then the output should match /cli,test,onfail,continue,console,print,message -> 42/

