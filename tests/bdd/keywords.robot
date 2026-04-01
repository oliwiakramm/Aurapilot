*** Settings ***
Library    RequestsLibrary
Library    Collections

*** Variables ***
${BASE_URL}    http://localhost:8000

*** Keywords ***
Setup API Session
    Create Session    api_session    ${BASE_URL}

the Aurapilot API is running
    Log    API session is active and ready.

I send GET request to /health
    ${response}=    GET On Session    api_session    /health    expected_status=any
    Set Test Variable    ${RESPONSE}    ${response}

response status code should be ${expected_status}
    Should Be Equal As Integers    ${RESPONSE.status_code}    ${expected_status}

response should contain status ok
    ${status_value}=    Set Variable    ${RESPONSE.json()['status']}
    Should Be Equal As Strings    ${status_value}    ok
    
    Log    Health Check was successful. Status: ${status_value}

a snapshot with CPU usage ${cpu_percent} percent exists
    ${snapshot}=    Evaluate    {"timestamp": "20260330_092740", "cpu": {"usage_percent": 97.0}} 

    Set Test Variable    ${SNAPSHOT}    ${snapshot}
    Log    Created snapshot: ${SNAPSHOT}

I send POST request to /analyze with the snapshot
    ${response}=    POST On Session    api_session    /analyze    json=${SNAPSHOT}    expected_status=any
    Set Test Variable    ${RESPONSE}    ${response}

response alerts should contain severity ${expected_severity}
    ${json}=    Set Variable    ${RESPONSE.json()}

    ${alerts}=    Get From Dictionary    ${json}    alerts

    ${severities}=    Evaluate    [alert.get("severity") for alert in $alerts]

    List Should Contain Value    ${severities}    ${expected_severity}
    Log    Found expected severity ${expected_severity} in alerts!