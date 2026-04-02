import pytest
from tests.conftest import healthy_snapshot,overloaded_snapshot
from app.services.policy import evaluate

def test_no_alerts_healthy(healthy_snapshot):
    """
    Verifies that no alerts are generated for a healthy system state.
    
    Ensures that when system parameters are within optimal ranges, 
    the evaluate function returns an empty list of alerts.
    """
    alerts = evaluate(healthy_snapshot)
    assert len(alerts) == 0

def test_critical_cpu(overloaded_snapshot):
    """
    Verifies that high CPU usage triggers a CRITICAL alert.
    
    Checks if the evaluation logic correctly identifies a system overload 
    and assigns the 'CRITICAL' severity level to the resulting alerts.
    """
    alerts = evaluate(overloaded_snapshot)
    severities = [a.severity for a in alerts]
    assert "CRITICAL" in severities

def test_warning_not_critical_cpu():
    """
    Tests the threshold for WARNING versus CRITICAL CPU usage.
    
    Validates that a CPU usage of 87% correctly triggers a 'WARNING' 
    status but does not escalate to a 'CRITICAL' status.
    """
    snapshot = {
        "cpu": {"usage_percent": 87.0, "load_avg": {"1min": 0.5}},
        "ram": {"used_percent": 50.0, "free_gb": 3.0},
        "disk": {"used_percent": 40.0},
        "system_errors": []
    }
    alerts = evaluate(snapshot)
    severities = [a.severity for a in alerts]
    assert "WARNING" in severities
    assert "CRITICAL" not in severities

def test_critical_before_warning(overloaded_snapshot):
    """
    Verifies the prioritization of alerts in the returned list.
    
    Ensures that when multiple issues are detected, 'CRITICAL' alerts 
    are positioned at the top of the list for immediate visibility.
    """
    alerts = evaluate(overloaded_snapshot)
    assert len(alerts) > 1
    print(alerts[0].severity)
    assert alerts[0].severity == "CRITICAL"
