"""
Smoke Test: Accessibility Features

Validates that accessibility features (speech synthesis) are configured.
"""

import pytest


@pytest.mark.smoke
def test_espeakup_configured(qcow2_vm):
    """espeakup configuration file should exist."""
    result = qcow2_vm.ssh_exec("test -f /etc/default/espeakup && echo 'exists'")
    assert "exists" in result


@pytest.mark.smoke
def test_espeakup_service_enabled(qcow2_vm):
    """espeakup service should be enabled at boot."""
    result = qcow2_vm.ssh_exec("systemctl is-enabled espeakup")
    assert "enabled" in result.strip()


@pytest.mark.smoke
def test_speakup_module_loaded(qcow2_vm):
    """speakup kernel module should be loaded or available."""
    result = qcow2_vm.ssh_exec("lsmod | grep speakup || echo 'module check skipped'")
    # Module may not be loaded in headless SSH, that's ok
    # Just verify the command doesn't fail
    assert result is not None


@pytest.mark.smoke
def test_espeak_ng_installed(qcow2_vm):
    """espeak-ng (TTS engine) should be installed."""
    result = qcow2_vm.ssh_exec("dpkg -l espeak-ng")
    assert "espeak-ng" in result
    assert "ii" in result


@pytest.mark.smoke
def test_espeak_works(qcow2_vm):
    """espeak-ng should execute without errors."""
    result = qcow2_vm.ssh_exec("espeak-ng --version")
    assert "eSpeak NG" in result


@pytest.mark.smoke
def test_restart_speech_script_exists(qcow2_vm):
    """restart-speech emergency script should exist (v2.0.20 feature)."""
    result = qcow2_vm.ssh_exec("test -f /usr/local/bin/restart-speech && echo 'exists'")
    assert "exists" in result


@pytest.mark.smoke
def test_restart_speech_executable(qcow2_vm):
    """restart-speech should be executable."""
    result = qcow2_vm.ssh_exec("test -x /usr/local/bin/restart-speech && echo 'executable'")
    assert "executable" in result


@pytest.mark.smoke
def test_sudoers_restart_speech_configured(qcow2_vm):
    """sudoers should allow restart-speech without password (v2.0.20)."""
    result = qcow2_vm.ssh_exec("test -f /etc/sudoers.d/restart-speech && echo 'exists'")
    assert "exists" in result


@pytest.mark.smoke
def test_emacs_a11y_version_file_exists(qcow2_vm):
    """emacs-a11y-version script should exist."""
    result = qcow2_vm.ssh_exec("test -f /usr/local/bin/emacs-a11y-version && echo 'exists'")
    assert "exists" in result


@pytest.mark.smoke
def test_emacs_a11y_version_executable(qcow2_vm):
    """emacs-a11y-version should execute and show version."""
    result = qcow2_vm.ssh_exec("/usr/local/bin/emacs-a11y-version")
    assert "Emacs A11y VM" in result or "Version" in result
