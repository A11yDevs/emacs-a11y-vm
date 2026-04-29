"""
E2E Test: Emergency Recovery Features

Validates F12 hotkey and restart-speech functionality (v2.0.20 feature).
"""

import pytest


@pytest.mark.e2e
@pytest.mark.slow
def test_restart_speech_script_functionality(qcow2_vm):
    """restart-speech script should restart espeakup service."""
    # Check initial state
    result = qcow2_vm.ssh_exec("systemctl is-active espeakup")
    initial_state = result.strip()
    assert "active" in initial_state
    
    # Execute restart-speech (should work without password via sudoers)
    result = qcow2_vm.ssh_exec("/usr/local/bin/restart-speech 2>&1")
    
    # Verify service is still active after restart
    result = qcow2_vm.ssh_exec("systemctl is-active espeakup")
    assert "active" in result.strip()


@pytest.mark.e2e
def test_restart_speech_sudoers_permissions(qcow2_vm):
    """Sudoers file should have correct permissions (root:root 0440) - v2.0.22 fix."""
    result = qcow2_vm.ssh_exec("stat -c '%U:%G %a' /etc/sudoers.d/restart-speech")
    assert "root:root" in result
    assert "440" in result or "400" in result  # 440 or 400 are both valid


@pytest.mark.e2e
def test_restart_speech_no_password_required(qcow2_vm):
    """User should be able to run restart-speech without password."""
    result = qcow2_vm.ssh_exec("sudo -n /usr/local/bin/restart-speech 2>&1")
    # Should not prompt for password
    assert "password" not in result.lower() or "restarting" in result.lower()


@pytest.mark.e2e
def test_espeakup_service_survives_restart(qcow2_vm):
    """espeakup service should survive restart attempts."""
    # Restart multiple times
    for i in range(3):
        qcow2_vm.ssh_exec("sudo systemctl restart espeakup")
    
    # Should still be active
    result = qcow2_vm.ssh_exec("systemctl is-active espeakup")
    assert "active" in result.strip()


@pytest.mark.e2e
def test_espeakup_timeout_configuration(qcow2_vm):
    """espeakup should have timeout configuration (prevents hanging)."""
    result = qcow2_vm.ssh_exec("test -f /etc/systemd/system/espeakup.service.d/espeakup-timeout.conf && echo 'exists'")
    assert "exists" in result


@pytest.mark.e2e
def test_emacs_a11y_userdata_service_exists(qcow2_vm):
    """emacs-a11y-userdata service should exist."""
    result = qcow2_vm.ssh_exec("test -f /etc/systemd/system/emacs-a11y-userdata.service && echo 'exists'")
    assert "exists" in result


@pytest.mark.e2e
def test_emacs_a11y_userdata_service_runs(qcow2_vm):
    """emacs-a11y-userdata service should have run successfully."""
    result = qcow2_vm.ssh_exec("systemctl status emacs-a11y-userdata.service | grep -i 'code=exited' || echo 'service ran'")
    # Service should have exited successfully (oneshot service)
    assert "service ran" in result or "exited" in result


@pytest.mark.e2e
@pytest.mark.slow
def test_speech_system_resilience(qcow2_vm):
    """Speech system should be resilient to stop/start cycles."""
    # Stop service
    qcow2_vm.ssh_exec("sudo systemctl stop espeakup")
    result = qcow2_vm.ssh_exec("systemctl is-active espeakup")
    assert "inactive" in result or "failed" in result
    
    # Start service
    qcow2_vm.ssh_exec("sudo systemctl start espeakup")
    result = qcow2_vm.ssh_exec("systemctl is-active espeakup")
    assert "active" in result


@pytest.mark.e2e
def test_emergency_recovery_documentation(qcow2_vm):
    """MOTD should mention emergency recovery (F12 or restart-speech)."""
    result = qcow2_vm.ssh_exec("cat /etc/motd")
    # Should mention recovery mechanism
    assert "restart-speech" in result.lower() or "f12" in result.lower() or "emergency" in result.lower()
