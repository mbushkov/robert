@dev
Feature: rules are matched against context only when specific conditions are met
  As a rob user
  In order to restrcit the set of rules that may be matched against specific context
  I want rules to match only when specific conditions are met

  Scenario: if rule does not contain asterisks, then it matches context only if its' left side is equal to context
    Given a rule a,b -> 42
    When I match rule against context a,b
    Then the rule will match
    When I match rule against context a,c
    Then the rule doesn't match

  Scenario Outline: asterisks are evaluated as "any number of tokens"
    Given a rule <rule> -> 42
    When I match rule against context <context>
    Then the rule will match

    Examples:
    | rule  | context     |
    | a,*,c | a,b,c       |
    | a,*,c | a,b,b1,b2,c |
    | a,*,c | a,c         |

  Scenario: asterisks are evaluated in a non-greedy way, i.e. we're satisfied with earliest possible match (starting from the last token)
    Given a rule a,*,m,*,k,b,*,c -> 42
    When I match rule against context a,k,b,m,k,b,c
    Then the rule will match

