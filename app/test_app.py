import pytest
from app import app


@pytest.fixture
def client():
    """Flask test client fixture."""
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client


def test_root_endpoint(client):
    """Test GET / returns HTTP 200 and status JSON."""
    response = client.get("/")
    assert response.status_code == 200
    data = response.get_json()
    assert data is not None
    assert data.get("status") == "running"
    assert "message" in data


def test_health_endpoint(client):
    """Test GET /health returns HTTP 200 and healthy status."""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.get_json()
    assert data is not None
    assert data.get("status") == "healthy"


def test_metrics_endpoint(client):
    """Test GET /metrics returns Prometheus format metrics."""
    # Send a request first to ensure metrics counters are populated
    client.get("/")
    response = client.get("/metrics")
    assert response.status_code == 200
    content = response.data.decode("utf-8")
    assert "http_requests_total" in content
    assert "http_request_duration_seconds" in content
    assert "http_errors_total" in content


def test_error_handling_500(client):
    """Test unexpected internal server error produces clean HTTP 500 JSON response."""
    response = client.get("/force-error")
    assert response.status_code == 500
    data = response.get_json()
    assert data is not None
    assert data.get("error") == "Internal Server Error"
    assert "message" in data


def test_not_found_404(client):
    """Test non-existent endpoint handles HTTP 404 cleanly."""
    response = client.get("/unknown-route")
    assert response.status_code == 404
    data = response.get_json()
    assert data is not None
    assert "error" in data
