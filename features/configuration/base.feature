Feature: base configuration is included automatically in every newly defined configuration
  As a rob user
  In order to be able to set up rules and action common for all configurations
  I want to be able to modify "base" configuration, which will be automatically included in every newly defined configuration

  Scenario: actions defined in base configuration are accessible in all other configurations
    Given a Robert configuration with:
    """
    conf :base do
      act[:test_base] = console.print { var[:message] = "42" }
    end

    conf :my_conf do
    end
    """
    When I run "rob2 test_base my_conf"
    Then the output should contain "42"

  Scenario: rules from base configuration are copied into all other configurations
    Given a Robert configuration with:
    """
    conf :base do
      var[:my,:rule] = 42
    end

    conf :my_conf do
    end
    """
    When I run "rob2 dump rules"
    Then the output should contain "my_conf,my,rule -> 42"

  Scenario: base configuration is included into the new configuration prior to everything else
    Given a Robert configuration with:
    """
    conf :base do
      act[:test_prior] = console.print { var[:message] = "42" }
    end

    conf :my_conf do
      act[:test_base] = seq(act[:test_prior],
                                console.print { var[:message] = "43" })
    end
    """
    When I run "rob2 test_base my_conf"
    Then the output should contain "42\n43"

  Scenario: changes in base configuration are reflected in the configurations that were already created
    Given a Robert configuration with:
    """
    conf :my_conf do
      act[:test_base] = seq(act[:test_prior],
                            console.print { var[:message] = "43" })
    end

    conf :base do
      act[:test_prior] = console.print { var[:message] = "42" }
    end
    """
    When I run "rob2 test_base my_conf"
    Then the output should contain "42\n43"
    
