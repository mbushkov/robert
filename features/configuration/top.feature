Feature: configurations are defined and used through top-level object $top, which also acts as a global context
  As a rob user
  In order to manipulate (define, instantiate, etc) configurations
  I need some global object which will also act as a global context of execution
    
  Scenario: $top.conf? can be used at runtime to determine if the configuration was defined
    Given a Robert configuration with:
    """
    conf :my_configuration do
    end

    defn my.action do
      body {
        puts "my_configuration defined" if $top.conf?(:my_configuration)
        puts "my_other_configuration defined" if $top.conf?(:my_other_configuration)
      }
    end

    conf :cli do
      act[:test] = my.action
    end
    """
    When I run "rob2 test"
    Then the output should contain "my_configuration defined"
    But the output should not contain "my_other_configuration defined"
  
  Scenario: $top.confs_names can be used at runtime to determine names of defined configurations
    Given a Robert configuration with:
    """
    conf :my_configuration do
    end

    defn my.action do
      body {
        puts $top.confs_names.to_a.join(",")
      }
    end

    conf :cli do
      act[:test] = my.action
    end
    """
    When I run "rob2 test"
    Then the output should contain "my_configuration"
    And the output should contain "cli"

  Scenario: $top.cclone can be used at runtime to create instances of configurations
    Given a Robert configuration with:
    """
    conf :my_configuration do
      act[:print] = console.print { var[:message] = "42" }
    end

    defn my.action do
      body {
        $top.cclone(:my_configuration).print
      }
    end

    conf :cli do
      act[:test] = my.action
    end
    """
    When I run "rob2 test"
    Then the output should contain "42"

  Scenario: global context and the $top configuration are the same thing
    Given a Robert configuration with:
    """
    $top.conf :my_configuration do
    end
    conf :my_configuration do
    end

    $top.conf?(:my_configuration) 
    conf?(:my_configuration)

    $top.cclone(:my_configuration)
    cclone(:my_configuration)

    $top.confs_names
    confs_names

    $top.confs(:my_configuration) do
    end
    confs(:my_configuration) do
    end

    $top.select { with_name(:my_configuration) }
    select { with_name(:my_configuration) }

    conf :cli do
      act[:test] = dummy.dummy
    end
    """
    When I run "rob2 test"
    Then the exit status should be 0
