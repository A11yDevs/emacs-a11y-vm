"""
Integration Test: Network Configuration

Validates network connectivity and DNS resolution.
"""

import pytest


@pytest.mark.integration
def test_network_interface_configured(qcow2_vm):
    """Network interface should have an IP address."""
    result = qcow2_vm.ssh_exec("ip addr show | grep 'inet ' | grep -v '127.0.0.1'")
    assert result.strip() != "", "No IP address found on network interface"


@pytest.mark.integration
def test_default_gateway_exists(qcow2_vm):
    """System should have a default gateway."""
    result = qcow2_vm.ssh_exec("ip route | grep default")
    assert "default via" in result


@pytest.mark.integration
def test_dns_resolution_works(qcow2_vm):
    """DNS resolution should work for common domains."""
    result = qcow2_vm.ssh_exec("nslookup github.com 2>&1 || host github.com 2>&1")
    assert "github.com" in result.lower()
    # Should not have "not found" or "can't find"
    assert "not found" not in result.lower()


@pytest.mark.integration
def test_resolv_conf_configured(qcow2_vm):
    """/etc/resolv.conf should have nameserver entries."""
    result = qcow2_vm.ssh_exec("cat /etc/resolv.conf")
    assert "nameserver" in result


@pytest.mark.integration
def test_can_ping_gateway(qcow2_vm):
    """Should be able to ping the default gateway."""
    # Get gateway IP
    gateway = qcow2_vm.ssh_exec("ip route | grep default | awk '{print $3}'").strip()
    
    if gateway:
        result = qcow2_vm.ssh_exec(f"ping -c 1 -W 2 {gateway}")
        assert "1 received" in result or "1 packets received" in result


@pytest.mark.integration
def test_internet_connectivity(qcow2_vm):
    """Should have internet connectivity."""
    result = qcow2_vm.ssh_exec("curl -s -m 5 http://example.com | head -n 1")
    # Should get HTML response
    assert result is not None and len(result) > 0


@pytest.mark.integration
def test_dhcp_client_configured(qcow2_vm):
    """DHCP client should be configured."""
    result = qcow2_vm.ssh_exec("cat /etc/network/interfaces")
    assert "dhcp" in result or "auto" in result


@pytest.mark.integration
def test_hostname_configured(qcow2_vm):
    """Hostname should be configured."""
    result = qcow2_vm.ssh_exec("hostname")
    assert result.strip() != ""
    assert result.strip() != "(none)"
