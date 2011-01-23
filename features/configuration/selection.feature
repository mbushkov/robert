Feature: groups of configurations can be easily selected with "select"
  As a rob user
  In order to perform batch operations on configurations
  I want to be able to select particular configurations from the whole set using some criteria

  select() uses the following approach:
  * It instantiates (with cclone) all currently defined configurations
  * It filters them, retaining those, for which given block returned true
  * It returns the resulting array adding one custom method (.names) to it - this method maps the array of configurations into the array of their names

  Scenario: select() accepts a block which is executed for every configuration
    Given a Robert configuration with:
    """
    conf :my_conf do
    end

    defn my.action do
      body {
        result = $top.select { with_name(:my_conf) }
        puts result[0].conf_name
      }
    end

    conf :cli do
      act[:test] = my.action
    end
    """
    When I run "rob2 test"
    Then the output should contain "my_conf"

  Scenario: select() adds ".names" method to selection result
    Given a Robert configuration with:
    """
    conf :my_conf1 do
    end

    conf :my_conf2 do
    end

    defn my.action do
      body {
        result = $top.select { with_name(:my_conf1) || with_name(:my_conf2) }
        puts result.names
      }
    end

    conf :cli do
      act[:test] = my.action
    end
    """
    When I run "rob2 test"
    Then the output should contain "my_conf1"
    And the output should contain "my_conf2"

  Scenario: select() never selects :base or :base_after configuration
    Given a Robert configuration with:
    """
    defn my.action do
      body {
        puts $top.select { true }.names
      }
    end

    conf :cli do
      act[:test] = my.action
    end
    """
    When I run "rob2 test"
    Then the output should not contain "base"
    And the output should not contain "base_after"

  Scenario: select() returns instantiated configurations, i.e. you can call their methods
    Given a Robert configuration with:
    """
    conf :my_conf1 do
      act[:print] = console.print { var[:message] = "42" }
    end

    conf :my_conf2 do
      act[:print] = console.print { var[:message] = "43" }
    end

    defn my.action do
      body {
        result = $top.select { with_name(:my_conf1) || with_name(:my_conf2) }
        result.each { |conf| conf.print }
      }
    end

    conf :cli do
      act[:test] = my.action
    end
    """
    When I run "rob2 test"
    Then the output should contain "42"
    And the output should contain "43"

  Scenario: with_name predicate returns true if configuration name matches
    Given a Robert configuration with:
    """
    defn my.action do
      body {
        puts $top.select { with_name(:cli) }.names
      }
    end

    conf :cli do
      act[:test] = my.action
    end
    """
    When I run "rob2 test"
    Then the output should contain "cli"

  Scenario: without_name returns true if configuration name does not match
    Given a Robert configuration with:
    """
    defn my.action do
      body {
        puts $top.select { without_name(:cli) }.names
      }
    end

    conf :cli do
      act[:test] = my.action
    end
    """
    When I run "rob2 test"
    Then the output should not contain "cli"

  Scenario: with_tags returns true if configuration has all specified tags
    Given a Robert configuration with:
    """
    conf :conf1 do
      tags << :my_tag1 << :my_tag2
    end

    conf :conf2 do
      tags << :my_tag1 << :my_tag2
    end

    conf :conf3 do
    end

    defn my.action do
      body {
        puts $top.select { with_tags(:my_tag1, :my_tag2) }.names
      }
    end

    conf :cli do
      act[:test] = my.action
    end
    """
    When I run "rob2 test"
    Then the output should contain "conf1"
    And the output should contain "conf2"
    But the output should not contain "conf3"

  Scenario: without_tags returns true if configuration does not have all specified tags
    Given a Robert configuration with:
    """
    conf :conf1 do
      tags << :my_tag1
    end

    conf :conf2 do
      tags << :my_tag2
    end

    conf :conf3 do
    end

    defn my.action do
      body {
        puts $top.select { without_tags(:my_tag1,:my_tag2) }.names
      }
    end

    conf :cli do
      act[:test] = my.action
    end
    """
    When I run "rob2 test"
    Then the output should not contain "conf1"
    And the output should not contain "conf2"
    But the output should contain "conf3"

  Scenario: with_any_tag returns true if configuration has any of the specified
    Given a Robert configuration with:
    """
    conf :conf1 do
      tags << :my_tag1
    end

    conf :conf2 do
      tags << :my_tag2
    end

    conf :conf3 do
    end

    defn my.action do
      body {
        puts $top.select { with_any_tag(:my_tag1,:my_tag2) }.names
      }
    end

    conf :cli do
      act[:test] = my.action
    end
    """
    When I run "rob2 test"
    Then the output should contain "conf1"
    And the output should contain "conf2"
    But the output should not contain "conf3"

  Scenario: with_method returns true if configuration responds to specified method
    Given a Robert configuration with:
    """
    conf :conf1 do
      act[:print] = console.print { var[:message] = "42" }
    end

    conf :conf2 do
    end

    defn my.action do
      body {
        puts $top.select { with_method(:print) }.names
      }
    end

    conf :cli do
      act[:test] = my.action
    end
    """
    When I run "rob2 test"
    Then the output should contain "conf1"

  Scenario: with_var returns true if given context prefixed with configuration name matches against current set of rules
    Given a Robert configuration with:
    """
    conf :conf1 do
      var[:my,:rule] = 42
    end

    conf :conf2 do
    end
    
    defn my.action do
      body {
        puts $top.select { with_var(:my,:rule) }.names
      }
    end

    conf :cli do
      act[:test] = my.action
    end
    """
    When I run "rob2 test"
    Then the output should contain "conf1"
