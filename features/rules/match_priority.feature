Feature: there are rules on how to resolve rules' conflicts - i.e. cases when several rules match
  Rule is considered overriden if there's later rule that will match in all cases when the original rule matches
  When multiple rules match context the following algorithm is used:
  1. All non-overriden rules are selected.
  2. If there are rules among them, where first element is equal to context's first element, then they're selected, otherwise we work with all rules from step 1.
  3. Among selected rules the one with the first different element, which match is closer to the right border of the context, wins

  Scenario Outline: rule is considered overriden if there's later rule that will match in all cases when the original rule matches
    When I define rule <rule>
    And I define rule <override rule>
    Then the rule <rule> is overriden by rule <override rule>

    Examples:
    | rule         | override rule |
    | a,b,c -> 1   | c -> 2        |
    | a,b,c -> 1   | b,c -> 2      |
    | a,b,c -> 1   | a,b,c -> 2    |
    | a,b,c,d -> 1 | d -> 2        |
    | a,b,c,d -> 1 | c,d -> 2      |
    | a,b,c,d -> 1 | b,d -> 2      |
    | a,b,c,d -> 1 | a,d -> 2      |
    | a,b,c,d -> 1 | b,c,d -> 2    |
    | a,b,c,d -> 1 | a,b,c,d -> 2  |

  Scenario Outline: during step 3, among matched rules,  one with the first different element, which match is closer to the right border of the context, wins
    Given rule <winner_rule> -> 42
    And rule <loser_rule> -> 43
    When I match rules against context <context>
    Then the result of the match will be 42
    
    Examples:
    | winner_rule                 | loser_rule                 | context                                             |
    | a,c                         | a,b,c                      | a,b,a,0,c                                           |
    | rsync,to                    | email,to                   | proj,continue,email,rsync,to                        |
    | backup,remote,dir           | backup,local,dir           | proj,backup,local,remote,0,dir                      |
    | process,backup,remote,dir   | action,backup,local,dir    | proj,action,process,backup,local,dir,remote,0,dir   |
    | process,a,backup,remote,dir | process,b,backup,local,dir | prpj,action,process,b,a,backup,local,dir,remote,dir |
    | backup,rsync,0,to           | notify,email,to            | proj,backup,notify,email,0,rsync,0,to               |
    | mysql,user                  | host,user                  | localhost,host,backup,0,mysql,user                  |

  Scenario: last rule of equal rules overrides its predecessors
    When I define rule a,b,c -> 1
    And I define rule a,b,c -> 2
    And I define rule a,b,c -> 3
    Then the rule a,b,c -> 1 is overriden by rule a,b,c -> 3
    And the rule a,b,c -> 2 is overriden by rule a,b,c -> 3

  Scenario: 1 rule is left after applying step 2 of the algorithm
    Given a rule a,b,c,d -> 1
    And a rule b,d -> 2
    And a rule a,c,d -> 3
    When I match rules against context a,b,c,d
    Then rules b,d -> 2 and a,c,d -> 3 are selected after step 1
    And rule a,c,d -> 3 is selected after step 2

  Scenario: 2 rules are left after applying step 2 of the algorithm, 1 rule selected after applying step 3
    Given a rule a,b,c,d -> 1
    And a rule b,d -> 2
    And a rule a,c,d -> 3
    And a rule a,b,d -> 4
    When I match rules against context a,b,c,d
    Then rules b,d -> 2 and a,c,d -> 3 and a,b,d -> 4 are selected after step 1
    And rules a,c,d -> 3 and a,b,d -> 4 are selected after step 2
    And rule a,c,d -> 3 is selected after step 3

  Scenario: 2 rules left after step 1, step 2 does not select any rules, 1 rule selected after applying step 3
    Given a rule b,c,d -> 1
    And a rule b,e,d -> 2
    When I match rules against context a,b,c,e,d
    Then rules b,c,d -> 1 and b,e,d -> 2 are selected after step 1
    And rules b,c,d -> 1 and b,e,d -> 2 are selected after step 2
    And rule b,e,d -> 2 is selected after step 3

