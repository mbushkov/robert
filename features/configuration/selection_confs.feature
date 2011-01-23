Feature: confs() call treats options as filters for the given set of names
  As a rob user
  In order to write less code
  I want to be able to tweak a large number of configurations that match a given criteria

  Scenario: tweak all configurations except one with a given name
    Given a Robert configuration with:
    """
    conf :my_conf1 do
    end
    
    conf :my_conf2 do
    end

    confs(confs_names, :without_name => :my_conf2) do
      tags << :selected
    end
    """
    When I run "rob2 dump confs"
    Then the output should contain "my_conf1, tags: selected"
    But the output should not contain "my_conf2, tags: selected"

  Scenario: tweak only configurations with all given tags
    Given a Robert configuration with:
    """
    conf :my_conf1 do
      tags << :my_tag1 << :my_tag2
    end

    conf :my_conf2 do
      tags << :my_tag1 << :my_tag2
    end

    conf :my_conf3 do
      tags << :my_tag1
    end

    confs(confs_names, :with_tags => [:my_tag1, :my_tag2]) do
      tags << :selected
    end
    """
    When I run "rob2 dump confs"
    Then the output should match /my_conf1, tags: .*selected$/
    And the output should match /my_conf2, tags: .*selected$/
    But the output should not match /my_conf3, tags: .*selected$/

  Scenario: tweak only configurations which respond to specified method
    Given a Robert configuration with:
    """
    conf :my_conf1 do
      act[:print] = console.print { var[:message] = "42" }
    end

    conf :my_conf2 do
    end
    
    confs(confs_names, :with_method => :print) do
      tags << :selected
    end
    """
    When I run "rob2 dump confs"
    Then the output should contain "my_conf1, tags: selected"
    But the output should not contain "my_conf2, tags: selected"

  Scenario: tweak only configurations which name + given context form a rule that matches against current set of rules
    Given a Robert configuration with:
    """
    conf :my_conf1 do
      var[:my,:rule] = 42
    end

    conf :my_conf2 do
    end

    confs(confs_names, :with_var => [:my,:rule]) do
      tags << :selected
    end
    """
    When I run "rob2 dump confs"
    Then the output should contain "my_conf1, tags: selected"
    But the output should not contain "my_conf2, tags: selected"

    Scenario: select() {}.names pattern can be used with confs() to tweak specified set of configurations
      Given a Robert configuration with:
      """
      conf :my_conf1 do
      end
    
      conf :my_conf2 do
      end

      confs(select { without_name(:my_conf2) }.names) do
        tags << :selected
      end
      """
      When I run "rob2 dump confs"
      Then the output should contain "my_conf1, tags: selected"
      But the output should not contain "my_conf2, tags: selected"
