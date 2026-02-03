"""Unit tests for TP-Link Archer AXE95 API wrapper.

Uses a MockRouterClient injected via client_class so no real router is needed.
Strict TDD: these tests were written BEFORE the implementation.
"""

import sys
import os
import pytest

# Add scripts directory to path so we can import the router package.
sys.path.insert(
    0, os.path.join(os.path.dirname(__file__), "..", "..", "scripts")
)

from router.tplink_client import TPLinkClient, RouterError


# ---------------------------------------------------------------------------
# Mock objects
# ---------------------------------------------------------------------------

class MockRouterClient:
    """Simulates the tplinkrouterc2 client for unit testing."""

    def __init__(self, host, password):
        self.host = host
        self.password = password
        self.authorized = False
        self._dns_set = None
        self._port_forwards_added = []

    def authorize(self):
        if self.password == "bad":
            raise Exception("Authentication failed")
        self.authorized = True

    def get_status(self):
        if not self.authorized:
            raise Exception("Not authorized")
        return MockStatus()

    def get_firmware(self):
        if not self.authorized:
            raise Exception("Not authorized")
        return MockFirmware()

    def get_ipv4_status(self):
        if not self.authorized:
            raise Exception("Not authorized")
        return MockIPv4Status()

    def get_ipv4_dhcp_settings(self):
        if not self.authorized:
            raise Exception("Not authorized")
        return MockDHCPSettings()

    def get_ipv4_reservations(self):
        if not self.authorized:
            raise Exception("Not authorized")
        return []

    def set_ipv4_dhcp_settings(self, **kwargs):
        if not self.authorized:
            raise Exception("Not authorized")
        self._dns_set = kwargs

    def add_port_forward(self, **kwargs):
        if not self.authorized:
            raise Exception("Not authorized")
        self._port_forwards_added.append(kwargs)

    def get_port_forwards(self):
        if not self.authorized:
            raise Exception("Not authorized")
        return [MockPortForward()]

    def get_wifi_2g(self):
        if not self.authorized:
            raise Exception("Not authorized")
        return MockWifi("HomeNet-2G", True)

    def get_wifi_5g(self):
        if not self.authorized:
            raise Exception("Not authorized")
        return MockWifi("HomeNet-5G", True)

    def get_wifi_6g(self):
        if not self.authorized:
            raise Exception("Not authorized")
        return MockWifi("HomeNet-6G", False)

    def logout(self):
        self.authorized = False


class MockStatus:
    wan_ipv4_addr = "203.0.113.42"
    wan_ipv4_gateway = "203.0.113.1"
    model = "Archer AXE95"
    hardware_version = "1.0"
    lan_ipv4_addr = "192.168.1.1"


class MockFirmware:
    firmware_version = "1.2.3"


class MockIPv4Status:
    wan_ipv4_ipaddr = "203.0.113.42"
    wan_ipv4_conntype = "Dynamic IP"


class MockDHCPSettings:
    enabled = True
    start_ip = "192.168.1.100"
    end_ip = "192.168.1.199"
    primary_dns = "1.1.1.1"
    secondary_dns = "8.8.8.8"


class MockWifi:
    def __init__(self, ssid, enabled):
        self.ssid = ssid
        self.enabled = enabled


class MockPortForward:
    name = "HTTP"
    ext_port = 80
    int_ip = "192.168.1.50"
    int_port = 80
    protocol = "TCP"
    enabled = True


class MockRouterClientAuthFail:
    """Mock that always fails authentication."""

    def __init__(self, host, password):
        self.host = host
        self.password = password

    def authorize(self):
        raise Exception("Authentication failed")


# ---------------------------------------------------------------------------
# Tests: initialization
# ---------------------------------------------------------------------------

class TestTPLinkClientInit:
    """Test TPLinkClient constructor behavior."""

    def test_default_host(self):
        client = TPLinkClient()
        assert client.host == "192.168.1.1"

    def test_custom_host(self):
        client = TPLinkClient(host="10.0.0.1")
        assert client.host == "10.0.0.1"

    def test_password_stored(self):
        client = TPLinkClient(password="secret")
        assert client.password == "secret"

    def test_client_class_injection(self):
        client = TPLinkClient(client_class=MockRouterClient)
        assert client._client_class is MockRouterClient

    def test_client_initially_none(self):
        client = TPLinkClient()
        assert client._client is None


# ---------------------------------------------------------------------------
# Tests: connect
# ---------------------------------------------------------------------------

class TestTPLinkClientConnect:
    """Test connect() method."""

    def test_connect_creates_client(self):
        client = TPLinkClient(
            password="admin", client_class=MockRouterClient
        )
        client.connect()
        assert client._client is not None

    def test_connect_authorizes(self):
        client = TPLinkClient(
            password="admin", client_class=MockRouterClient
        )
        client.connect()
        assert client._client.authorized is True

    def test_connect_raises_router_error_on_auth_failure(self):
        client = TPLinkClient(
            password="admin", client_class=MockRouterClientAuthFail
        )
        with pytest.raises(RouterError, match="Authentication failed"):
            client.connect()

    def test_connect_passes_host_and_password(self):
        client = TPLinkClient(
            host="10.0.0.1",
            password="mypass",
            client_class=MockRouterClient,
        )
        client.connect()
        assert client._client.host == "10.0.0.1"
        assert client._client.password == "mypass"


# ---------------------------------------------------------------------------
# Tests: get_status
# ---------------------------------------------------------------------------

class TestGetStatus:
    """Test get_status() method."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.client = TPLinkClient(
            password="admin", client_class=MockRouterClient
        )
        self.client.connect()

    def test_returns_dict(self):
        result = self.client.get_status()
        assert isinstance(result, dict)

    def test_contains_wan_ip(self):
        result = self.client.get_status()
        assert "wan_ip" in result
        assert result["wan_ip"] == "203.0.113.42"

    def test_contains_model(self):
        result = self.client.get_status()
        assert "model" in result
        assert result["model"] == "Archer AXE95"

    def test_contains_firmware(self):
        result = self.client.get_status()
        assert "firmware" in result
        assert result["firmware"] == "1.2.3"

    def test_contains_connection_type(self):
        result = self.client.get_status()
        assert "connection_type" in result

    def test_raises_when_not_connected(self):
        client = TPLinkClient(
            password="admin", client_class=MockRouterClient
        )
        with pytest.raises(RouterError, match="Not connected"):
            client.get_status()


# ---------------------------------------------------------------------------
# Tests: get_wifi_settings
# ---------------------------------------------------------------------------

class TestGetWifiSettings:
    """Test get_wifi_settings() method."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.client = TPLinkClient(
            password="admin", client_class=MockRouterClient
        )
        self.client.connect()

    def test_returns_dict(self):
        result = self.client.get_wifi_settings()
        assert isinstance(result, dict)

    def test_contains_ssid_2g(self):
        result = self.client.get_wifi_settings()
        assert "ssid_2g" in result
        assert result["ssid_2g"] == "HomeNet-2G"

    def test_contains_ssid_5g(self):
        result = self.client.get_wifi_settings()
        assert "ssid_5g" in result
        assert result["ssid_5g"] == "HomeNet-5G"

    def test_contains_ssid_6g(self):
        result = self.client.get_wifi_settings()
        assert "ssid_6g" in result
        assert result["ssid_6g"] == "HomeNet-6G"

    def test_contains_enabled_bands(self):
        result = self.client.get_wifi_settings()
        assert "enabled_bands" in result
        assert isinstance(result["enabled_bands"], list)

    def test_enabled_bands_correct(self):
        result = self.client.get_wifi_settings()
        assert "2g" in result["enabled_bands"]
        assert "5g" in result["enabled_bands"]
        assert "6g" not in result["enabled_bands"]

    def test_raises_when_not_connected(self):
        client = TPLinkClient(
            password="admin", client_class=MockRouterClient
        )
        with pytest.raises(RouterError, match="Not connected"):
            client.get_wifi_settings()


# ---------------------------------------------------------------------------
# Tests: get_dhcp_settings
# ---------------------------------------------------------------------------

class TestGetDHCPSettings:
    """Test get_dhcp_settings() method."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.client = TPLinkClient(
            password="admin", client_class=MockRouterClient
        )
        self.client.connect()

    def test_returns_dict(self):
        result = self.client.get_dhcp_settings()
        assert isinstance(result, dict)

    def test_contains_enabled(self):
        result = self.client.get_dhcp_settings()
        assert "enabled" in result
        assert result["enabled"] is True

    def test_contains_start_ip(self):
        result = self.client.get_dhcp_settings()
        assert "start_ip" in result
        assert result["start_ip"] == "192.168.1.100"

    def test_contains_end_ip(self):
        result = self.client.get_dhcp_settings()
        assert "end_ip" in result
        assert result["end_ip"] == "192.168.1.199"

    def test_contains_dns_servers(self):
        result = self.client.get_dhcp_settings()
        assert "dns_servers" in result
        assert isinstance(result["dns_servers"], list)
        assert "1.1.1.1" in result["dns_servers"]
        assert "8.8.8.8" in result["dns_servers"]

    def test_raises_when_not_connected(self):
        client = TPLinkClient(
            password="admin", client_class=MockRouterClient
        )
        with pytest.raises(RouterError, match="Not connected"):
            client.get_dhcp_settings()


# ---------------------------------------------------------------------------
# Tests: get_port_forwards
# ---------------------------------------------------------------------------

class TestGetPortForwards:
    """Test get_port_forwards() method."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.client = TPLinkClient(
            password="admin", client_class=MockRouterClient
        )
        self.client.connect()

    def test_returns_list(self):
        result = self.client.get_port_forwards()
        assert isinstance(result, list)

    def test_forward_has_expected_keys(self):
        result = self.client.get_port_forwards()
        assert len(result) >= 1
        fwd = result[0]
        assert "ext_port" in fwd
        assert "int_ip" in fwd
        assert "int_port" in fwd
        assert "protocol" in fwd
        assert "enabled" in fwd

    def test_forward_values(self):
        result = self.client.get_port_forwards()
        fwd = result[0]
        assert fwd["ext_port"] == 80
        assert fwd["int_ip"] == "192.168.1.50"
        assert fwd["int_port"] == 80
        assert fwd["protocol"] == "TCP"
        assert fwd["enabled"] is True

    def test_raises_when_not_connected(self):
        client = TPLinkClient(
            password="admin", client_class=MockRouterClient
        )
        with pytest.raises(RouterError, match="Not connected"):
            client.get_port_forwards()


# ---------------------------------------------------------------------------
# Tests: set_dhcp_dns
# ---------------------------------------------------------------------------

class TestSetDHCPDns:
    """Test set_dhcp_dns() method."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.client = TPLinkClient(
            password="admin", client_class=MockRouterClient
        )
        self.client.connect()

    def test_returns_true_on_success(self):
        result = self.client.set_dhcp_dns("1.1.1.1", "8.8.8.8")
        assert result is True

    def test_sets_primary_dns(self):
        self.client.set_dhcp_dns("9.9.9.9")
        dns_args = self.client._client._dns_set
        assert dns_args is not None
        assert dns_args.get("primary_dns") == "9.9.9.9"

    def test_sets_secondary_dns(self):
        self.client.set_dhcp_dns("9.9.9.9", "1.0.0.1")
        dns_args = self.client._client._dns_set
        assert dns_args.get("secondary_dns") == "1.0.0.1"

    def test_secondary_dns_optional(self):
        self.client.set_dhcp_dns("9.9.9.9")
        dns_args = self.client._client._dns_set
        assert "primary_dns" in dns_args

    def test_raises_when_not_connected(self):
        client = TPLinkClient(
            password="admin", client_class=MockRouterClient
        )
        with pytest.raises(RouterError, match="Not connected"):
            client.set_dhcp_dns("1.1.1.1")


# ---------------------------------------------------------------------------
# Tests: add_port_forward
# ---------------------------------------------------------------------------

class TestAddPortForward:
    """Test add_port_forward() method."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.client = TPLinkClient(
            password="admin", client_class=MockRouterClient
        )
        self.client.connect()

    def test_returns_true_on_success(self):
        result = self.client.add_port_forward(
            8080, "192.168.1.10", 80
        )
        assert result is True

    def test_passes_ext_port(self):
        self.client.add_port_forward(8080, "192.168.1.10", 80)
        args = self.client._client._port_forwards_added[0]
        assert args["ext_port"] == 8080

    def test_passes_int_ip(self):
        self.client.add_port_forward(8080, "192.168.1.10", 80)
        args = self.client._client._port_forwards_added[0]
        assert args["int_ip"] == "192.168.1.10"

    def test_passes_int_port(self):
        self.client.add_port_forward(8080, "192.168.1.10", 80)
        args = self.client._client._port_forwards_added[0]
        assert args["int_port"] == 80

    def test_default_protocol_tcp(self):
        self.client.add_port_forward(8080, "192.168.1.10", 80)
        args = self.client._client._port_forwards_added[0]
        assert args["protocol"] == "TCP"

    def test_custom_protocol(self):
        self.client.add_port_forward(
            53, "192.168.1.10", 53, protocol="UDP"
        )
        args = self.client._client._port_forwards_added[0]
        assert args["protocol"] == "UDP"

    def test_name_parameter(self):
        self.client.add_port_forward(
            8080, "192.168.1.10", 80, name="WebServer"
        )
        args = self.client._client._port_forwards_added[0]
        assert args["name"] == "WebServer"

    def test_raises_when_not_connected(self):
        client = TPLinkClient(
            password="admin", client_class=MockRouterClient
        )
        with pytest.raises(RouterError, match="Not connected"):
            client.add_port_forward(8080, "192.168.1.10", 80)


# ---------------------------------------------------------------------------
# Tests: disconnect
# ---------------------------------------------------------------------------

class TestDisconnect:
    """Test disconnect() method."""

    def test_disconnect_clears_client(self):
        client = TPLinkClient(
            password="admin", client_class=MockRouterClient
        )
        client.connect()
        assert client._client is not None
        client.disconnect()
        assert client._client is None

    def test_disconnect_when_not_connected(self):
        client = TPLinkClient(
            password="admin", client_class=MockRouterClient
        )
        # Should not raise -- disconnecting when not connected is a no-op.
        client.disconnect()
        assert client._client is None

    def test_operations_fail_after_disconnect(self):
        client = TPLinkClient(
            password="admin", client_class=MockRouterClient
        )
        client.connect()
        client.disconnect()
        with pytest.raises(RouterError, match="Not connected"):
            client.get_status()
