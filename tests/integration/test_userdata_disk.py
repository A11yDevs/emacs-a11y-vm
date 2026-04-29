"""
Integration Test: User Data Disk

Validates persistent /home disk detection and mounting.
"""

import pytest


@pytest.mark.integration
def test_home_directory_exists(qcow2_vm):
    """/home directory should exist."""
    result = qcow2_vm.ssh_exec("test -d /home && echo 'exists'")
    assert "exists" in result


@pytest.mark.integration
def test_user_home_exists(qcow2_vm):
    """User a11ydevs home directory should exist."""
    result = qcow2_vm.ssh_exec("test -d /home/a11ydevs && echo 'exists'")
    assert "exists" in result


@pytest.mark.integration
def test_user_owns_home(qcow2_vm):
    """User should own their home directory."""
    result = qcow2_vm.ssh_exec("stat -c '%U' /home/a11ydevs")
    assert result.strip() == "a11ydevs"


@pytest.mark.integration
def test_home_writable(qcow2_vm):
    """User home should be writable."""
    result = qcow2_vm.ssh_exec("touch /home/a11ydevs/test-write && rm /home/a11ydevs/test-write && echo 'writable'")
    assert "writable" in result


@pytest.mark.integration
def test_bash_profile_exists(qcow2_vm):
    """User should have .profile file."""
    result = qcow2_vm.ssh_exec("test -f ~/.profile && echo 'exists'")
    assert "exists" in result


@pytest.mark.integration
def test_bashrc_exists(qcow2_vm):
    """User should have .bashrc file."""
    result = qcow2_vm.ssh_exec("test -f ~/.bashrc && echo 'exists'")
    assert "exists" in result


@pytest.mark.integration
def test_emacs_d_directory_exists(qcow2_vm):
    """User should have .emacs.d directory."""
    result = qcow2_vm.ssh_exec("test -d ~/.emacs.d && echo 'exists'")
    assert "exists" in result


@pytest.mark.integration
def test_emacs_init_exists(qcow2_vm):
    """User should have Emacs init.el configuration."""
    result = qcow2_vm.ssh_exec("test -f ~/.emacs.d/init.el && echo 'exists'")
    assert "exists" in result


@pytest.mark.integration
def test_disk_space_available(qcow2_vm):
    """Home partition should have available space."""
    result = qcow2_vm.ssh_exec("df -h /home | tail -1 | awk '{print $5}' | sed 's/%//'")
    usage = int(result.strip())
    assert usage < 95, f"Home partition is {usage}% full, should be <95%"


@pytest.mark.integration
def test_files_persist_across_operations(qcow2_vm):
    """Files created in home should persist."""
    # Create test file
    qcow2_vm.ssh_exec("echo 'persistence test' > ~/test-persist.txt")
    
    # Verify it exists
    result = qcow2_vm.ssh_exec("cat ~/test-persist.txt")
    assert "persistence test" in result
    
    # Cleanup
    qcow2_vm.ssh_exec("rm ~/test-persist.txt")
