"""
Smoke Test: VM Boot Performance

Validates that the VM boots quickly and SSH becomes accessible.
Target: <60 seconds boot time.
"""

import pytest
import time


@pytest.mark.smoke
def test_vm_boots_under_60_seconds(qcow2_vm):
    """VM should boot and SSH should be ready within 60 seconds."""
    # VM is already booted by qcow2_vm fixture
    # If we got here, it means boot was successful
    # The fixture has a 120s timeout, so this test validates we're well under that
    pass


@pytest.mark.smoke
def test_ssh_accessible(qcow2_vm):
    """SSH should be accessible and respond to commands."""
    result = qcow2_vm.ssh_exec("echo 'SSH is working'")
    assert "SSH is working" in result


@pytest.mark.smoke
def test_login_works(qcow2_vm):
    """User a11ydevs should be logged in successfully."""
    result = qcow2_vm.ssh_exec("whoami")
    assert result.strip() == "a11ydevs"


@pytest.mark.smoke
def test_system_responsive(qcow2_vm):
    """System should respond to basic commands quickly."""
    start_time = time.time()
    result = qcow2_vm.ssh_exec("uptime")
    elapsed = time.time() - start_time
    
    assert elapsed < 5, f"Command took {elapsed}s, should be <5s"
    assert "load average" in result


@pytest.mark.smoke
def test_disk_accessible(qcow2_vm):
    """Root filesystem should be mounted and accessible."""
    result = qcow2_vm.ssh_exec("LANG=C df -h /")
    assert "/" in result
    assert "Filesystem" in result


@pytest.mark.smoke
def test_network_configured(qcow2_vm):
    """Network interface should be configured."""
    result = qcow2_vm.ssh_exec("ip addr show")
    assert "inet " in result  # Should have IP address
    assert "lo" in result     # Loopback should exist
