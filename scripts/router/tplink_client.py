"""TP-Link Archer AXE95 API wrapper.

Wraps the tplinkrouterc2 library for programmatic router management.
All methods return structured data and raise RouterError on failure.
"""


class RouterError(Exception):
    """Raised when router communication fails."""

    pass


class TPLinkClient:
    """Client for TP-Link Archer AXE95 router.

    Uses dependency injection via *client_class* so that unit tests can
    supply a mock without importing tplinkrouterc2.
    """

    def __init__(self, host="192.168.1.1", password=None, client_class=None):
        """Initialize with router IP and optional password.

        Args:
            host: Router IP address (default from inventory).
            password: Admin password.
            client_class: Optional override for the tplinkrouterc2 client
                class.  When ``None`` the real library is imported at
                connect-time.
        """
        self.host = host
        self.password = password
        self._client_class = client_class
        self._client = None

    # ------------------------------------------------------------------
    # Connection
    # ------------------------------------------------------------------

    def connect(self):
        """Authenticate with the router.

        Raises:
            RouterError: If authentication fails.
        """
        cls = self._client_class
        if cls is None:
            try:
                from tplinkrouterc2 import TplinkRouter

                cls = TplinkRouter
            except ImportError as exc:
                raise RouterError(
                    "tplinkrouterc2 is not installed"
                ) from exc

        try:
            self._client = cls(self.host, self.password)
            self._client.authorize()
        except Exception as exc:
            self._client = None
            raise RouterError(
                f"Authentication failed: {exc}"
            ) from exc

    def disconnect(self):
        """Close the router connection."""
        if self._client is not None:
            try:
                self._client.logout()
            except Exception:
                pass
            self._client = None

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    def _require_connection(self):
        """Raise RouterError when there is no active connection."""
        if self._client is None:
            raise RouterError("Not connected to router")

    def _safe_call(self, fn, *args, **kwargs):
        """Call *fn* on the underlying client, wrapping errors."""
        self._require_connection()
        try:
            return fn(*args, **kwargs)
        except Exception as exc:
            raise RouterError(str(exc)) from exc

    # ------------------------------------------------------------------
    # Read operations
    # ------------------------------------------------------------------

    def get_status(self):
        """Return router status as a dict.

        Keys: wan_ip, connection_type, firmware, model.
        """
        self._require_connection()
        try:
            status = self._client.get_status()
            firmware_info = self._client.get_firmware()
            ipv4 = self._client.get_ipv4_status()

            return {
                "wan_ip": getattr(status, "wan_ipv4_addr", None)
                or getattr(ipv4, "wan_ipv4_ipaddr", None),
                "connection_type": getattr(
                    ipv4, "wan_ipv4_conntype", "Unknown"
                ),
                "firmware": getattr(
                    firmware_info, "firmware_version", "Unknown"
                ),
                "model": getattr(status, "model", "Unknown"),
            }
        except RouterError:
            raise
        except Exception as exc:
            raise RouterError(
                f"Failed to get status: {exc}"
            ) from exc

    def get_wifi_settings(self):
        """Return WiFi settings as a dict.

        Keys: ssid_2g, ssid_5g, ssid_6g, enabled_bands.
        """
        self._require_connection()
        try:
            wifi_2g = self._client.get_wifi_2g()
            wifi_5g = self._client.get_wifi_5g()
            wifi_6g = self._client.get_wifi_6g()

            enabled_bands = []
            if getattr(wifi_2g, "enabled", False):
                enabled_bands.append("2g")
            if getattr(wifi_5g, "enabled", False):
                enabled_bands.append("5g")
            if getattr(wifi_6g, "enabled", False):
                enabled_bands.append("6g")

            return {
                "ssid_2g": getattr(wifi_2g, "ssid", None),
                "ssid_5g": getattr(wifi_5g, "ssid", None),
                "ssid_6g": getattr(wifi_6g, "ssid", None),
                "enabled_bands": enabled_bands,
            }
        except RouterError:
            raise
        except Exception as exc:
            raise RouterError(
                f"Failed to get WiFi settings: {exc}"
            ) from exc

    def get_dhcp_settings(self):
        """Return DHCP settings as a dict.

        Keys: enabled, start_ip, end_ip, dns_servers.
        """
        self._require_connection()
        try:
            dhcp = self._client.get_ipv4_dhcp_settings()

            dns_servers = []
            primary = getattr(dhcp, "primary_dns", None)
            secondary = getattr(dhcp, "secondary_dns", None)
            if primary:
                dns_servers.append(primary)
            if secondary:
                dns_servers.append(secondary)

            return {
                "enabled": getattr(dhcp, "enabled", False),
                "start_ip": getattr(dhcp, "start_ip", None),
                "end_ip": getattr(dhcp, "end_ip", None),
                "dns_servers": dns_servers,
            }
        except RouterError:
            raise
        except Exception as exc:
            raise RouterError(
                f"Failed to get DHCP settings: {exc}"
            ) from exc

    def get_port_forwards(self):
        """Return port-forwarding rules as a list of dicts.

        Each dict has: ext_port, int_ip, int_port, protocol, enabled.
        """
        self._require_connection()
        try:
            forwards = self._client.get_port_forwards()
            return [
                {
                    "ext_port": getattr(fwd, "ext_port", None),
                    "int_ip": getattr(fwd, "int_ip", None),
                    "int_port": getattr(fwd, "int_port", None),
                    "protocol": getattr(fwd, "protocol", None),
                    "enabled": getattr(fwd, "enabled", False),
                }
                for fwd in forwards
            ]
        except RouterError:
            raise
        except Exception as exc:
            raise RouterError(
                f"Failed to get port forwards: {exc}"
            ) from exc

    # ------------------------------------------------------------------
    # Write operations
    # ------------------------------------------------------------------

    def set_dhcp_dns(self, primary_dns, secondary_dns=None):
        """Set the DHCP-distributed DNS servers.

        Args:
            primary_dns: Primary DNS server IP.
            secondary_dns: Optional secondary DNS server IP.

        Returns:
            True on success.

        Raises:
            RouterError: On failure or if not connected.
        """
        self._require_connection()
        try:
            kwargs = {"primary_dns": primary_dns}
            if secondary_dns is not None:
                kwargs["secondary_dns"] = secondary_dns
            self._client.set_ipv4_dhcp_settings(**kwargs)
            return True
        except RouterError:
            raise
        except Exception as exc:
            raise RouterError(
                f"Failed to set DNS: {exc}"
            ) from exc

    def add_port_forward(
        self, ext_port, int_ip, int_port, protocol="TCP", name=""
    ):
        """Add a port-forwarding rule.

        Args:
            ext_port: External port number.
            int_ip: Internal host IP address.
            int_port: Internal port number.
            protocol: ``"TCP"`` or ``"UDP"`` (default ``"TCP"``).
            name: Optional human-readable rule name.

        Returns:
            True on success.

        Raises:
            RouterError: On failure or if not connected.
        """
        self._require_connection()
        try:
            self._client.add_port_forward(
                ext_port=ext_port,
                int_ip=int_ip,
                int_port=int_port,
                protocol=protocol,
                name=name,
            )
            return True
        except RouterError:
            raise
        except Exception as exc:
            raise RouterError(
                f"Failed to add port forward: {exc}"
            ) from exc
