import pytest
from tests.conftest import healthy_snapshot,overloaded_snapshot
from app.services.policy import evaluate

def test_no_alerts_healthy(healthy_snapshot):
    alerts = evaluate(healthy_snapshot)
    assert len(alerts) == 0

def test_critical_cpu(overloaded_snapshot):
    alerts = evaluate(overloaded_snapshot)
    severities = [a.severity for a in alerts]
    assert "CRITICAL" in severities

def test_warning_not_critical_cpu():
    snapshot = {
        "cpu": {"usage_percent": 87.0, "load_avg": {"1min": 0.5}},
        "ram": {"used_percent": 50.0, "free_gb": 3.0},
        "disk": {"used_percent": 40.0},
        "system_errors": []
    }
    alerts = evaluate(snapshot)
    names = [a.name for a in alerts]
    severities = [a.severity for a in alerts]
    assert "WARNING" in severities
    assert "CRITICAL" not in severities

def test_critical_before_warning(overloaded_snapshot):
    alerts = evaluate(overloaded_snapshot)
    assert len(alerts) > 1
    print(alerts[0].severity)
    assert alerts[0].severity == "CRITICAL"

def test_disk_alert():
    snapshot = {
        "cpu": {"usage_percent": 30.0, "load_avg": {"1min": 0.5}},
        "ram": {"used_percent": 50.0, "free_gb": 3.0},
        "disk": {"used_percent": 93.0},
        "system_errors": []
    }
    alerts = evaluate(snapshot)
    severities = [a.severity for a in alerts]
    assert "CRITICAL" in severities