from starlette.requests import Request

from app.middleware import _client_ip


class _FakeClient:
    def __init__(self, host: str):
        self.host = host


def _req(headers: dict[str, str], client_host: str = "10.0.0.1") -> Request:
    scope = {
        "type": "http",
        "asgi": {"version": "3.0"},
        "http_version": "1.1",
        "method": "GET",
        "scheme": "https",
        "path": "/",
        "raw_path": b"/",
        "query_string": b"",
        "headers": [(k.lower().encode(), v.encode()) for k, v in headers.items()],
        "client": (client_host, 12345),
        "server": ("test", 443),
    }
    return Request(scope)


def test_client_ip_prefers_x_real_ip():
    r = _req({"x-real-ip": "203.0.113.9", "x-forwarded-for": "1.1.1.1, 203.0.113.9"})
    assert _client_ip(r) == "203.0.113.9"


def test_client_ip_ignores_spoofed_first_xff_hop():
    # Edge nginx overwrites XFF to a single $remote_addr; if multiple, use last hop.
    r = _req({"x-forwarded-for": "8.8.8.8, 198.51.100.4"})
    assert _client_ip(r) == "198.51.100.4"


def test_client_ip_falls_back_to_client_host():
    r = _req({})
    assert _client_ip(r) == "10.0.0.1"
