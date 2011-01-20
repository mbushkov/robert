Feature: rules are evaluated based on their priority
  When multiple rules match the same context
  In order to determine the exact rule to evaluate
  I want a set of priority-rules for rules evaluation

  Scenario: last rule of equal rules wins
    Given rule a,b,c -> 1
    And rule a,b,c -> 2
    And rule a,b,c -> 3
    When I match rules against context a,b,c
    Then the result of the match will be 3

  Scenario: a subrule of previously defined rule has higher priority
    Given rule a,b,d -> 43
    And rule a,d -> 42
    When I match rules against context a,b,c,d
    Then the result of the match will be 42

  Scenario: among matched rules the one, where first element matches first context element, wins
    Given rule Project,s3,acl -> 42
    And rule s3,base,acl -> 43
    When I match rules against context Project,0,s3,bucket,0,base,0,acl
    Then the result of the match will be 42

  Scenario: among matched rules the one, where first element matches first context element, wins
    Given rule Project,backup,db_check,0,quick -> 42
    And rule db,mysql,check,quick -> 43
    When I match rules against context Project,backup,db_check,0,db,mysql,1,check,quick
    Then the result of the match will be 42

  Scenario Outline: among matched rules (with first token different from context's firt token) one with the first different element, which match is closer to the right border of the context, wins
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
 
  Scenario: when several rules match, they're first filtered by matching their first element to context's first element and then by the distance of first different element from the right border of the context
    Given rule b,d -> 42
    And rule a,k,d -> 43
    And rule a,f,g,d -> 44
    When I match rules against context a,b,k,0,d
    Then the result of the match will be 43
