@dev
Feature: context for rules evaluation changes during the execution
  As a rob user
  In order to narrow the number of rules that will match my request at the given point of time
  I want to have a 'context' that will change during the execution and will act as a prefix for matches

  Scenario: current rule context acts as a prefix when I want to evaluate particular rule
    Given a Robert configuration with:
    """
    var[:cli,:*,:my,:action,:*,:value] = 42 #TODO: should be :my,:action,:value

    defn my.action do
      body {
        puts var[:value]
      }
    end

    conf :cli do
      act[:test] = my.action
    end
    """
    When I run "rob2 test"
    Then the output should contain "42"

  @announce-stdout
  Scenario: when action is the first in the action's chain, it adds configuration name to the rule context, when it's executed
    Given a Robert configuration with:
    """
    defn my.action do
      body {
        puts rule_ctx.join(",")
      }
    end

    conf :cli do
      act[:test] = my.action
    end
    """
    When I run "rob2 test"
    Then the output should match /^cli/

  @announce-stdout
  Scenario: when action is executed it adds act's name and its left and right parts of the name current rule context
    Given a Robert configuration with:
    """
    defn my.action do
      body {
        puts rule_ctx.select { |e| e != :* }.join(",") #TODO: fix definition and evaluation contexts problem
      }
    end

    conf :cli do
      act[:test] = my.action
    end
    """
    When I run "rob2 test"
    Then the output should match /^cli,test,my,action/

  Scenario: when action is executed it adds act's name and its left and right parts of the name to current rule context
    Given a Robert configuration with:
    """
    defn my.action do
      body {
        call_next
      }
    end

    defn my.nested_action do
      body {
        puts rule_ctx.select { |e| e != :* }.join(",")
      }
    end

    conf :cli do
      act[:test] = my.action(my.nested_action)
    end
    """
    When I run "rob2 test"
    Then the output should match /^cli,test,my,action,my,nested_action/

  Scenario: when configuration calls action of some other configuration, that other action uses clean rule context
    Given a Robert configuration with:
    """
    defn my.action do
      body {
        $top.cclone(:conf2).test
      }
    end

    defn my.nested_action do
      body {
        puts rule_ctx.select { |e| e != :* }.join(",")
      }
    end
    
    conf :cli do
      act[:test] = my.action
    end

    conf :conf2 do
      act[:test] = my.nested_action
    end
    """
    When I run "rob2 test"
    Then the output should match /^conf2,test,my,nested_action/

