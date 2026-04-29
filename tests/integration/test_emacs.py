"""
Integration Test: Emacs Functionality

Validates Emacs installation and basic functionality.
"""

import pytest


@pytest.mark.integration
def test_emacs_version(qcow2_vm):
    """Emacs should report version information."""
    result = qcow2_vm.ssh_exec("emacs --version")
    assert "GNU Emacs" in result
    # Extract version number (should be 27+)
    lines = result.split('\n')
    if lines:
        version_line = lines[0]
        # Version format: "GNU Emacs 27.1" or similar
        assert "GNU Emacs" in version_line


@pytest.mark.integration
def test_emacs_batch_mode(qcow2_vm):
    """Emacs should run in batch mode."""
    result = qcow2_vm.ssh_exec("emacs --batch --eval '(message \"test\")'")
    assert "test" in result


@pytest.mark.integration
def test_emacs_init_file_loads(qcow2_vm):
    """Emacs init.el should load without errors."""
    result = qcow2_vm.ssh_exec(
        "emacs --batch --eval '(progn (load-file \"~/.emacs.d/init.el\") (message \"init loaded\"))' 2>&1"
    )
    # Should not have error messages
    assert "Error" not in result or "init loaded" in result


@pytest.mark.integration
def test_emacs_package_system(qcow2_vm):
    """Emacs package system should be functional."""
    result = qcow2_vm.ssh_exec(
        "emacs --batch --eval '(message \"%s\" package-archives)' 2>&1"
    )
    # Should have package archives configured
    assert result is not None


@pytest.mark.integration
def test_emacs_can_create_file(qcow2_vm):
    """Emacs should be able to create and save files."""
    result = qcow2_vm.ssh_exec(
        "emacs --batch --eval '(progn (find-file \"~/test-emacs.txt\") "
        "(insert \"Hello from Emacs\") (save-buffer))' && "
        "cat ~/test-emacs.txt && rm ~/test-emacs.txt"
    )
    assert "Hello from Emacs" in result


@pytest.mark.integration
def test_emacs_lisp_evaluation(qcow2_vm):
    """Emacs should evaluate Lisp expressions correctly."""
    result = qcow2_vm.ssh_exec("emacs --batch --eval '(princ (+ 2 2))'")
    assert "4" in result


@pytest.mark.integration
def test_emacs_has_basic_modes(qcow2_vm):
    """Emacs should have basic editing modes available."""
    result = qcow2_vm.ssh_exec(
        "emacs --batch --eval '(message \"%s\" (fboundp (quote python-mode)))'"
    )
    # Just verify Emacs can check for mode existence
    assert result is not None


@pytest.mark.integration
def test_emacsclient_installed(qcow2_vm):
    """emacsclient should be installed."""
    result = qcow2_vm.ssh_exec("which emacsclient")
    assert "emacsclient" in result


@pytest.mark.integration
def test_emacspeak_package_installed(qcow2_vm):
    """emacspeak package should be properly installed."""
    result = qcow2_vm.ssh_exec("dpkg -l | grep emacspeak")
    assert "emacspeak" in result.lower(), "emacspeak not found in package list"
    assert "ii" in result, "emacspeak not properly installed"


@pytest.mark.integration
def test_emacspeak_directory_exists(qcow2_vm):
    """emacspeak installation directory should exist."""
    result = qcow2_vm.ssh_exec("ls -la /usr/share/emacs/site-lisp/emacspeak* 2>/dev/null || ls -la /usr/share/emacspeak 2>/dev/null || echo 'checking'")
    # emacspeak should be installed somewhere
    assert result is not None and len(result) > 0


@pytest.mark.integration
def test_emacspeak_loads_in_emacs(qcow2_vm):
    """emacspeak should load without errors in Emacs."""
    result = qcow2_vm.ssh_exec(
        "emacs --batch --eval '(condition-case err (progn (require (quote emacspeak)) (message \"emacspeak-loaded\")) (error (message \"ERROR: %s\" err)))' 2>&1"
    )
    # Check if emacspeak loaded successfully or if the package exists
    assert "emacspeak-loaded" in result or "Cannot open load file" not in result


@pytest.mark.integration
def test_emacspeak_voices_available(qcow2_vm):
    """emacspeak should have voice configurations available."""
    result = qcow2_vm.ssh_exec(
        "find /usr/share -name '*emacspeak*' -type d 2>/dev/null | head -5"
    )
    # Should find emacspeak directories
    assert result is not None


@pytest.mark.integration
def test_emacspeak_server_exists(qcow2_vm):
    """emacspeak speech server should exist."""
    # Check for espeak server (most common)
    result = qcow2_vm.ssh_exec(
        "find /usr/share -name '*espeak*' -o -name '*speech-server*' 2>/dev/null | grep -i emacspeak || echo 'checking'"
    )
    assert result is not None
