import pytest
from tests.conftest import healthy_snapshot,overloaded_snapshot,api_client
from app.main import app
from unittest.mock import patch


def test_get_health(api_client):
    response = api_client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"


def test_analyze_post(api_client,healthy_snapshot):
    with patch("app.services.gemini.analyze") as mock_analyze:
        mock_analyze.return_value = "mocked analysis"
    
        response = api_client.post("/analyze",json=healthy_snapshot)
    
    assert response.status_code == 200
    data = response.json()
    assert "alerts" in data
    assert "analysis" in data

def test_no_snapshot_returns_404(api_client,tmp_path,monkeypatch):
   
    monkeypatch.chdir(tmp_path)

    response = api_client.get("/analyze/latest")
    assert response.status_code == 404
    data = response.json()
    assert data["detail"] == "No snapshot found, run collector first"


def test_invalid_body_returns_422(api_client):
    response = api_client.post("/analyze",json="Mock string")
    response.status_code = 422