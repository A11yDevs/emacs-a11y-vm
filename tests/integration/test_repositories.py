"""
Integration Test: A11yDevs Repositories

Validates that A11yDevs repositories are correctly configured (v2.0.27 feature).
"""

import pytest


@pytest.mark.integration
def test_emacspeak_keyring_exists(qcow2_vm):
    """emacspeak GPG keyring should be installed in /usr/share/keyrings/."""
    result = qcow2_vm.ssh_exec("test -f /usr/share/keyrings/emacspeak-archive-keyring.gpg && echo 'exists'")
    assert "exists" in result


@pytest.mark.integration
def test_emacs_a11y_keyring_exists(qcow2_vm):
    """emacs-a11y GPG keyring should be installed in /usr/share/keyrings/."""
    result = qcow2_vm.ssh_exec("test -f /usr/share/keyrings/emacs-a11y-archive-keyring.gpg && echo 'exists'")
    assert "exists" in result


@pytest.mark.integration
def test_emacspeak_repo_configured(qcow2_vm):
    """emacspeak repository should be configured in sources.list.d."""
    result = qcow2_vm.ssh_exec("test -f /etc/apt/sources.list.d/emacspeak.list && echo 'exists'")
    assert "exists" in result


@pytest.mark.integration
def test_emacs_a11y_repo_configured(qcow2_vm):
    """emacs-a11y repository should be configured in sources.list.d."""
    result = qcow2_vm.ssh_exec("test -f /etc/apt/sources.list.d/emacs-a11y.list && echo 'exists'")
    assert "exists" in result


@pytest.mark.integration
def test_emacspeak_repo_url_correct(qcow2_vm):
    """emacspeak repository URL should be correct."""
    result = qcow2_vm.ssh_exec("cat /etc/apt/sources.list.d/emacspeak.list")
    assert "a11ydevs.github.io/emacspeak-a11ydevs/debian" in result
    assert "signed-by=/usr/share/keyrings/emacspeak-archive-keyring.gpg" in result


@pytest.mark.integration
def test_emacs_a11y_repo_url_correct(qcow2_vm):
    """emacs-a11y repository URL should be correct."""
    result = qcow2_vm.ssh_exec("cat /etc/apt/sources.list.d/emacs-a11y.list")
    assert "a11ydevs.github.io/emacs-a11y/debian" in result
    assert "signed-by=/usr/share/keyrings/emacs-a11y-archive-keyring.gpg" in result


@pytest.mark.integration
def test_emacs_a11y_config_installed(qcow2_vm):
    """emacs-a11y-config package should be installed."""
    result = qcow2_vm.ssh_exec("dpkg -l emacs-a11y-config")
    assert "emacs-a11y-config" in result
    assert "ii" in result  # Installed status


@pytest.mark.integration
def test_emacs_a11y_launchers_installed(qcow2_vm):
    """emacs-a11y-launchers package should be installed."""
    result = qcow2_vm.ssh_exec("dpkg -l emacs-a11y-launchers")
    assert "emacs-a11y-launchers" in result
    assert "ii" in result


@pytest.mark.integration
def test_apt_update_succeeds(qcow2_vm):
    """apt update should succeed without errors."""
    result = qcow2_vm.ssh_exec("sudo apt-get update 2>&1")
    assert "Err:" not in result or result.count("Err:") == 0
    # Some warnings are ok, but no errors


@pytest.mark.integration
def test_repositories_signed_correctly(qcow2_vm):
    """Repositories should be properly signed (no GPG errors)."""
    result = qcow2_vm.ssh_exec("sudo apt-get update 2>&1")
    assert "NO_PUBKEY" not in result
    assert "KEYEXPIRED" not in result
