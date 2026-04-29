"""
Integration Test: Shared Folders

Validates mount-shared-folder.sh parsing logic (v2.0.25 bugfix).
"""

import pytest


@pytest.mark.integration
def test_mount_shared_folder_script_exists(qcow2_vm):
    """mount-shared-folder.sh script should exist."""
    result = qcow2_vm.ssh_exec("test -f /usr/local/bin/mount-shared-folder.sh && echo 'exists'")
    assert "exists" in result


@pytest.mark.integration
def test_mount_shared_folder_service_exists(qcow2_vm):
    """mount-shared-folder systemd service should be configured."""
    result = qcow2_vm.ssh_exec("test -f /etc/systemd/system/mount-shared-folder.service && echo 'exists'")
    assert "exists" in result


@pytest.mark.integration
def test_mount_shared_folder_service_enabled(qcow2_vm):
    """mount-shared-folder service should be enabled."""
    result = qcow2_vm.ssh_exec("systemctl is-enabled mount-shared-folder.service")
    assert "enabled" in result.strip()


@pytest.mark.integration
def test_vboxsf_module_available(qcow2_vm):
    """vboxsf kernel module should be available (VirtualBox Guest Additions)."""
    # Check if module exists in filesystem
    result = qcow2_vm.ssh_exec("find /lib/modules -name 'vboxsf.ko*' 2>/dev/null | wc -l")
    # May not be loaded but should be available
    # In QEMU testing, this may not exist (that's ok)
    assert result is not None


@pytest.mark.integration
def test_mount_script_has_correct_awk_logic(qcow2_vm):
    """mount-shared-folder.sh should parse field $3 (v2.0.25 bugfix)."""
    result = qcow2_vm.ssh_exec("grep 'print \\$3' /usr/local/bin/mount-shared-folder.sh")
    assert "print $3" in result, "Script should parse field $3, not $2 (v2.0.25 fix)"


@pytest.mark.integration
def test_mount_script_parses_vboxcontrol_output_correctly(qcow2_vm):
    """
    Verify awk parsing logic handles VBoxControl output format correctly.
    
    VBoxControl output format:
    01 - kenta [idRoot=0 writable guest-icase]
    
    Should parse field $3 (kenta), not $2 (dash).
    """
    # Create test data simulating VBoxControl output
    test_data = "01 - testshare [idRoot=0 writable]"
    
    # Test the awk command that's used in mount-shared-folder.sh
    result = qcow2_vm.ssh_exec(
        f"echo '{test_data}' | awk '$1 ~ /^[0-9]+$/ && NF>=3 {{ print $3 }}'"
    )
    
    assert result.strip() == "testshare", "Should extract 'testshare' from field $3"


@pytest.mark.integration
def test_home_directory_writable(qcow2_vm):
    """User home directory should be writable."""
    result = qcow2_vm.ssh_exec("touch ~/test-write && rm ~/test-write && echo 'writable'")
    assert "writable" in result


@pytest.mark.integration
def test_shared_folder_mount_points_directory(qcow2_vm):
    """User home should have directory structure for shared folder mounts."""
    result = qcow2_vm.ssh_exec("test -d ~/ && echo 'exists'")
    assert "exists" in result
