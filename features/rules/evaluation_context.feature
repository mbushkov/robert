Feature:

  @announce-stdout
  Scenario: when action is executed it adds its namespace, name and arbitrary integer to current rule context
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
    Then the output should match /my,action,\d+/

  Scenario: when action is executed it adds its namespace, name and arbitrary integer to current rule context
    Given a Robert configuration with:
    """
    defn my.action do
      body {
        call_next
      }
    end

    defn my.nested_action do
      body {
        puts rule_ctx.join(",")
        }
    end

    conf :cli do
      act[:test] = my.action(my.nested_action)
    end
    """
    When I run "rob2 test"
    Then the output should match /my,action,\d+,my,nested_action,\d+/
