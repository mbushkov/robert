Feature: base_after configuration is included automatically in every defined configuration after all configuration files have been read
  As a rob user
  In order to be able to set up rules and action common for all configurations
  I want to be able to modify "base" configuration, which will be automatically included in every newly defined configuration

  @announce
  Scenario: actions defined in base_after configuration are accessible in all other configurations
    Given a Robert configuration with:
    """
    conf :base_after do
      act[:test] = console.print { var[:message] = "42" }
    end

    conf :my_conf do
    end
    """
    When I run "rob2 test my_conf"
    Then the output should contain "42"

  Scenario: rules from base configuration are copied into all other configurations
    Given a Robert configuration with:
    """
    conf :base_after do
      var[:my,:rule] = 42
    end

    conf :my_conf do
    end
    """
    When I run "rob2 dump rules"
    Then the output should contain "my_conf,my,rule -> 42"

  @announce
  Scenario: base configuration is included into the new configuration after everything else (need to define act[:test] = dummy.dummy in base in order to be able to reference act[:test] in base_after)
    Given a Robert configuration with:
    """
    conf :my_conf do
      act[:test_after] = console.print { var[:message] = "42" }
    end

    conf :base_after do
      if act[:test_after]
        act[:test_after] = seq(act[:test_after],
                               console.print { var[:message] = "43" })
      end
    end
    """
    When I run "rob2 test_after my_conf"
    Then the output should contain "42\n43"

