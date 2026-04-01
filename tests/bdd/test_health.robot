*** Settings ***
Documentation    Test scenarios for Aurapilot API
Resource         keywords.robot

Suite Setup      Setup API Session  

*** Test Cases ***
Health endpoint returns OK status
    [Documentation]    Checks whether endpoint /health returns 200 and if JSON returns 'ok'.
    
    Given the Aurapilot API is running
    When I send GET request to /health
    Then response status code should be 200
    And response should contain status ok