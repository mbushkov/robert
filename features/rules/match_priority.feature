@dev
Feature: when multiple rules match context, the last one wins
  Scenario: when multiple rules match context, the last one wins
    When I define rule a,b,c -> 1
    And I define rule a,b,c -> 2
    And I define rule a,b,c -> 3
    When I match rules against context a,b,c
    Then the result of the match will be 3

  Scenario: when multiple rules match context, the last one wins
    When I define rule a,b,*,c -> 1
    And I define rule a,*,d,c -> 2
    When I match rules against context a,b,d,c
    Then the result of the match will be 2

