"""
Smoke Test: Essential Packages

Validates that critical packages are installed and services are running.
"""

import pytest


@pytest.mark.smoke
def test_emacs_installed(qcow2_vm):
    """Emacs should be installed."""
    result = qcow2_vm.ssh_exec("dpkg -l emacs 2>/dev/null || dpkg -l emacs-nox 2>/dev/null")
    assert "emacs" in result.lower()


@pytest.mark.smoke
def test_emacs_runs(qcow2_vm):
    """Emacs should execute without errors."""
    result = qcow2_vm.ssh_exec("emacs --version")
    assert "GNU Emacs" in result


@pytest.mark.smoke
def test_espeakup_installed(qcow2_vm):
    """espeakup package should be installed."""
    result = qcow2_vm.ssh_exec("dpkg -l espeakup")
    assert "espeakup" in result
    assert "ii" in result  # Installed status


@pytest.mark.smoke
def test_espeakup_service_running(qcow2_vm):
    """espeakup service should be active."""
    result = qcow2_vm.ssh_exec("systemctl is-active espeakup")
    assert "active" in result.strip()


@pytest.mark.smoke
def test_ssh_server_active(qcow2_vm):
    """SSH server should be running."""
    result = qcow2_vm.ssh_exec("systemctl is-active ssh")
    assert "active" in result.strip()


@pytest.mark.smoke
def test_sudo_installed(qcow2_vm):
    """sudo should be installed and configured."""
    result = qcow2_vm.ssh_exec("dpkg -l sudo")
    assert "sudo" in result
    assert "ii" in result


@pytest.mark.smoke
def test_user_has_sudo(qcow2_vm):
    """User a11ydevs should have sudo access."""
    result = qcow2_vm.ssh_exec("sudo -n true 2>&1")
    # Should succeed or require password (not "not in sudoers")
    assert "not in the sudoers file" not in result.lower()


@pytest.mark.smoke
def test_git_installed(qcow2_vm):
    """Git should be installed for development."""
    result = qcow2_vm.ssh_exec("git --version")
    assert "git version" in result


@pytest.mark.smoke
def test_curl_installed(qcow2_vm):
    """curl should be installed for downloading."""
    result = qcow2_vm.ssh_exec("curl --version")
    assert "curl" in result


@pytest.mark.smoke
def test_basic_shell_tools(qcow2_vm):
    """Basic shell tools should be available."""
    tools = ["bash", "grep", "sed", "awk", "find"]
    
    for tool in tools:
        result = qcow2_vm.ssh_exec(f"which {tool}")
        assert tool in result, f"{tool} not found in PATH"


@pytest.mark.smoke
def test_emacspeak_installed(qcow2_vm):
    """emacspeak package should be installed."""
    result = qcow2_vm.ssh_exec("dpkg -l emacspeak 2>/dev/null || dpkg -l emacspeak-ss 2>/dev/null")
    assert "emacspeak" in result.lower(), "emacspeak package not found"
