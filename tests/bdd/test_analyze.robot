*** Settings ***
Documentation    Test scenarios for Aurapilot Analyze API
Resource         keywords.robot

Suite Setup      Setup API Session  

*** Test Cases ***
Analyze endpoint detects critical CPU usage
    [Documentation]    Checks if the analyze endpoint correctly identifies high CPU usage.
    
    Given the Aurapilot API is running
    And a snapshot with CPU usage 97 percent exists
    When I send POST request to /analyze with the snapshot
    Then response status code should be 200
    And response alerts should contain severity CRITICAL