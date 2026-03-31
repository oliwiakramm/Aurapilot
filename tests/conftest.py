import pytest
import os
os.environ["GEMINI_API_KEY"] = "dummy-key-for-tests"
from app.main import app         
from fastapi.testclient import TestClient

@pytest.fixture
def overloaded_snapshot():
    return {
        "timestamp": "20260329_130000",
        "cpu": {
            "usage_percent": 97.0,
            "load_avg": { "1min": 5.0 }
        },
        "ram": {
            "used_percent": 95.0,
            "free_gb": 0.3
        },
        "disk": {
            "used_percent": 91.0
        },
        "system_errors": ["kernel: error"]
    }

@pytest.fixture
def healthy_snapshot():
    return {
        "timestamp": "20260329_120000",
        "cpu": {
            "usage_percent": 30.0,
            "load_avg": { "1min": 0.5 }
        },
        "ram": {
            "used_percent": 50.0,
            "free_gb": 3.0
        },
        "disk": {
            "used_percent": 40.0
        },
        "system_errors": []
    }

@pytest.fixture
def test_rules_path():
      return "config/rules.yaml"

@pytest.fixture
def api_client():
     return TestClient(app)