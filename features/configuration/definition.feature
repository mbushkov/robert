Feature: configurations can be defined
  As a rob user
  In order to separate concerns and simplify code reuse
  I want to group my configurations

  Scenario: configuration is defined with "conf" keyword
    Given a Robert configuration with:
    """
    conf :my_configuration do
    end
    """
    When I run "rob2 dump confs"
    Then the output should contain "my_configuration"

  Scenario: configuration definition is open and can be extended multiple times
    Given a Robert configuration with:
    """
    conf :my_conf do
      act[:print] = console.print { var[:message] = "42" }
    end

    conf :my_conf do
      act[:print] = seq(act[:print],
                        console.print { var[:message] = "43" })
    end
    """
    When I run "rob2 print my_conf"
    Then the output should contain "42\n43"

  Scenario: multiple configurations can be defined at once with "confs" keyword
    Given a Robert configuration with:
    """
    confs :my_conf1, :my_conf2, :my_conf3 do
    end
    """
    When I run "rob2 dump confs"
    Then the output should contain "my_conf1"
    And the output should contain "my_conf2"
    And the output should contain "my_conf3"

  Scenario: configuration can have tags assigned
    Given a Robert configuration with:
    """
    conf :my_configuration do
      tags << :my_tag
    end
    """
    When I run "rob2 dump confs"
    Then the output should contain "my_configuration, tags: my_tag"

  Scenario: configurations can be included in another configuration to delegate all its functionality
    Given a Robert configuration with:
    """
    conf :my_conf2 do
      act[:test] = console.print { var[:message] = "42" }
    end

    conf :my_conf1 do
      include :my_conf2
    end
    """
    When I run "rob2 test my_conf1"
    Then the output should contain "42"

  Scenario: rules from the included configuration are copied into the owner configuration
    Given a Robert configuration with:
    """
    conf :my_conf2 do
      var[:some,:rule] = 42
    end

    conf :my_conf1 do
      include :my_conf2
    end
    """
    When I run "rob2 dump rules"
    Then the output should contain "my_conf2,some,rule -> 42"
    And the output should contain "my_conf1,some,rule -> 42"

  Scenario: configurations can't be defined at runtime (i.e. - inside actions)
    Given a Robert configuration with:
    """
    defn my.action do
      body {
        $top.conf :some_other_conf do
        end
      }
    end

    conf :cli do
      act[:test] = my.action
    end
    """
    When I run "rob2 test"
    Then the exit status should not be 0
