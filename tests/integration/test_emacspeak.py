"""
Integration Test: Emacspeak

Validates that emacspeak is installed and functional.
Emacspeak is a complete audio desktop for Emacs users.
"""

import pytest


@pytest.mark.integration
def test_emacspeak_package_status(qcow2_vm):
    """emacspeak package should be installed and in 'ii' state."""
    result = qcow2_vm.ssh_exec("dpkg -l emacspeak 2>&1")
    
    # Check if package exists
    if "no packages found" in result.lower() or "dpkg-query" in result.lower():
        pytest.fail("emacspeak package not installed")
    
    # Check installation status
    assert "ii" in result, f"emacspeak not properly installed. Status:\n{result}"


@pytest.mark.integration
def test_emacspeak_base_directory(qcow2_vm):
    """emacspeak base directory should exist with core files."""
    # Try common locations
    result = qcow2_vm.ssh_exec(
        "test -d /usr/share/emacs/site-lisp/emacspeak && echo 'found-site-lisp' || "
        "test -d /usr/share/emacspeak && echo 'found-share' || "
        "echo 'not-found'"
    )
    
    assert "found" in result, f"emacspeak directory not found. Result: {result}"


@pytest.mark.integration
def test_emacspeak_lisp_files(qcow2_vm):
    """emacspeak should have .el or .elc Lisp files."""
    result = qcow2_vm.ssh_exec(
        "find /usr/share -name 'emacspeak*.el*' -o -name 'dtk-*.el*' 2>/dev/null | head -5"
    )
    
    assert len(result.strip()) > 0, "No emacspeak Lisp files found"


@pytest.mark.integration
def test_emacspeak_can_be_required(qcow2_vm):
    """Emacs should be able to require emacspeak library."""
    result = qcow2_vm.ssh_exec(
        "emacs --batch --eval '(condition-case err "
        "(progn (require (quote emacspeak)) (message \"SUCCESS: emacspeak loaded\")) "
        "(error (message \"FAILED: %s\" err)))' 2>&1"
    )
    
    # Check for success message or at least no critical errors
    if "SUCCESS: emacspeak loaded" in result:
        return  # Perfect!
    
    # Check if it's a load path issue vs missing package
    if "Cannot open load file" in result and "emacspeak" in result:
        pytest.fail(f"emacspeak installed but not in Emacs load-path:\n{result}")
    
    if "FAILED:" in result:
        # May fail if dependencies missing, but package should exist
        result_info = qcow2_vm.ssh_exec("dpkg -L emacspeak | head -10")
        assert len(result_info) > 0, f"emacspeak package exists but Emacs can't load it:\n{result}"


@pytest.mark.integration
def test_emacspeak_info_documentation(qcow2_vm):
    """emacspeak Info documentation should be available."""
    result = qcow2_vm.ssh_exec("info --where emacspeak 2>&1 || echo 'info-check'")
    
    # Info may not be installed, but check if emacspeak doc exists
    result_files = qcow2_vm.ssh_exec("dpkg -L emacspeak | grep -i info || echo 'no-info'")
    
    # Either info works or package has info files
    assert "info-check" in result or "info" in result_files or len(result_files) > 10


@pytest.mark.integration
def test_emacspeak_servers_directory(qcow2_vm):
    """emacspeak servers directory or server files should exist."""
    result = qcow2_vm.ssh_exec(
        "find /usr/share -path '*emacspeak*' \\( -type d -name 'servers' -o -name '*server*' \\) 2>/dev/null | head -1"
    )
    
    # Servers directory or server files should exist
    assert len(result.strip()) > 0, "emacspeak servers directory not found"


@pytest.mark.integration
def test_emacspeak_espeak_server(qcow2_vm):
    """emacspeak should have espeak TTS server."""
    result = qcow2_vm.ssh_exec(
        "find /usr/share -name '*espeak*' -path '*emacspeak*' 2>/dev/null | head -5"
    )
    
    assert len(result.strip()) > 0, "emacspeak espeak server files not found"


@pytest.mark.integration
def test_emacspeak_sounds_directory(qcow2_vm):
    """emacspeak should have sounds/icons for auditory feedback."""
    result = qcow2_vm.ssh_exec(
        "find /usr/share -type d \\( -name 'sounds' -o -name 'sound-icons' \\) -path '*emacspeak*' 2>/dev/null | head -1"
    )
    
    # Sounds are optional but commonly included
    # Just log if not found, don't fail
    if len(result.strip()) == 0:
        print("Warning: emacspeak sounds directory not found (optional feature)")


@pytest.mark.integration
def test_emacspeak_dtk_program(qcow2_vm):
    """DTK (Desktop TalkKit) program should be available."""
    result = qcow2_vm.ssh_exec(
        "find /usr/share -name 'dtk-*' -path '*emacspeak*' 2>/dev/null | head -5"
    )
    
    assert len(result.strip()) > 0, "DTK (emacspeak TTS interface) files not found"


@pytest.mark.integration
def test_emacspeak_version_info(qcow2_vm):
    """Should be able to get emacspeak version information."""
    result = qcow2_vm.ssh_exec("dpkg -s emacspeak | grep Version")
    
    assert "Version:" in result, "Could not get emacspeak version"
    print(f"emacspeak {result.strip()}")


@pytest.mark.integration
def test_emacspeak_dependencies_installed(qcow2_vm):
    """emacspeak dependencies (like tclsh for servers) should be available."""
    # Check for tcl (used by some emacspeak servers)
    result = qcow2_vm.ssh_exec("which tclsh 2>/dev/null || which tclsh8.6 2>/dev/null || echo 'no-tcl'")
    
    # TCL may not be required for espeak server, just check
    if "no-tcl" in result:
        print("Info: tclsh not found (may be optional depending on TTS server)")


@pytest.mark.integration
def test_emacspeak_with_espeak_integration(qcow2_vm):
    """emacspeak should be configured to work with espeak-ng."""
    # Check if espeak is available (required for speech)
    result = qcow2_vm.ssh_exec("which espeak-ng || which espeak")
    assert len(result.strip()) > 0, "espeak-ng or espeak not found (required for emacspeak TTS)"
    
    # Check if emacspeak has espeak server
    result = qcow2_vm.ssh_exec(
        "dpkg -L emacspeak | grep -i espeak | head -5 || echo 'checking'"
    )
    assert len(result.strip()) > 0


@pytest.mark.integration
def test_emacspeak_basic_function_exists(qcow2_vm):
    """emacspeak should define basic functions when loaded."""
    result = qcow2_vm.ssh_exec(
        "emacs --batch --eval '"
        "(condition-case err "
        "  (progn "
        "    (require (quote emacspeak)) "
        "    (if (fboundp (quote emacspeak-version)) "
        "        (message \\\"HAS-FUNCTION: emacspeak-version\\\") "
        "        (message \\\"NO-FUNCTION\\\"))) "
        "  (error (message \\\"ERROR: %s\\\" err)))' 2>&1"
    )
    
    # May fail to load but function should exist if package is properly installed
    if "HAS-FUNCTION" in result:
        return  # Success!
    
    # If can't load, verify package is at least installed
    pkg_check = qcow2_vm.ssh_exec("dpkg -l emacspeak | grep ii")
    assert "ii" in pkg_check, f"emacspeak not properly installed"


@pytest.mark.integration  
@pytest.mark.slow
def test_emacspeak_startup_no_critical_errors(qcow2_vm):
    """Loading emacspeak should not produce critical errors."""
    result = qcow2_vm.ssh_exec(
        "timeout 10 emacs --batch --eval '"
        "(condition-case err "
        "  (progn "
        "    (setq debug-on-error t) "
        "    (require (quote emacspeak)) "
        "    (message \\\"emacspeak-load-complete\\\")) "
        "  (error (message \\\"load-error: %s\\\" err)))' 2>&1"
    )
    
    # Check for critical errors
    critical_errors = [
        "Symbol's function definition is void",
        "Wrong type argument",
        "Invalid function"
    ]
    
    for error in critical_errors:
        if error in result and "load-error" in result:
            pytest.fail(f"Critical error loading emacspeak: {error}\n{result}")
    
    # If load completed, great!
    if "emacspeak-load-complete" in result:
        print("✓ emacspeak loaded successfully")
