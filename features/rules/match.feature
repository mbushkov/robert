Feature: rules are matched against context only when specific conditions are met
  As a rob user
  In order to restrcit the set of rules that may be matched against specific context
  I want rules to match only when specific conditions are met

  Scenario: rule does not match if its' last token is different from contexts' last token
    Given a rule a,b -> 42
    When I match rule against context a,c
    Then the rule doesn't match

  Scenario: rule does not match if it's not fully contained in the context
    Given a rule a,b,c -> 42
    When I match rule against context a,b
    Then the rule doesn't match

  Scenario: rule does not match if its tokens are contained in the context in different order
    Given a rule a,b -> 42
    When I match rule against context b,a
    Then the rule doesn't match

  Scenario Outline: rule matches when it's last token is the equal to context's last token, and all other tokens are contained in the context in the same order
    Given a rule <rule> -> 42
    When I match rule against context <context>
    Then the rule will match

    Examples:
    | rule  | context               |
    | a,b,c | a,b,c                 |
    | a,b,c | a,0,b,c               |
    | a,b,c | a,0,z,f,m,b,1,y,h,n,c |

    
