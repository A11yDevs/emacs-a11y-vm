"""
E2E Test: Full Workflow

Simulates complete user workflows from login to development tasks.
"""

import pytest
import time


@pytest.mark.e2e
@pytest.mark.slow
def test_complete_user_session(qcow2_vm):
    """
    Simulate a complete user session:
    1. Login (already done via SSH)
    2. Check system status
    3. Create a file
    4. Edit with Emacs
    5. Verify persistence
    """
    # 1. Verify logged in
    result = qcow2_vm.ssh_exec("whoami")
    assert "a11ydevs" in result
    
    # 2. Check system status
    result = qcow2_vm.ssh_exec("uptime && free -h && df -h")
    assert "load average" in result
    
    # 3. Create a test file
    qcow2_vm.ssh_exec("echo 'Testing complete workflow' > ~/workflow-test.txt")
    
    # 4. Edit with Emacs (batch mode)
    qcow2_vm.ssh_exec(
        "emacs --batch ~/workflow-test.txt "
        "--eval '(progn (goto-char (point-max)) (insert \"\\nEdited by Emacs\") (save-buffer))'"
    )
    
    # 5. Verify content
    result = qcow2_vm.ssh_exec("cat ~/workflow-test.txt")
    assert "Testing complete workflow" in result
    assert "Edited by Emacs" in result
    
    # Cleanup
    qcow2_vm.ssh_exec("rm ~/workflow-test.txt")


@pytest.mark.e2e
@pytest.mark.slow
def test_development_workflow(qcow2_vm):
    """
    Simulate a development workflow:
    1. Create project directory
    2. Initialize git repo
    3. Create source files
    4. Edit with Emacs
    5. Commit changes
    6. Verify history
    """
    project_dir = "~/test-project"
    
    # 1. Create project
    qcow2_vm.ssh_exec(f"mkdir -p {project_dir}")
    
    # 2. Initialize git
    qcow2_vm.ssh_exec(f"cd {project_dir} && git init")
    qcow2_vm.ssh_exec("git config --global user.email 'test@example.com'")
    qcow2_vm.ssh_exec("git config --global user.name 'Test User'")
    
    # 3. Create source file
    qcow2_vm.ssh_exec(f"cd {project_dir} && echo 'print(\"Hello World\")' > hello.py")
    
    # 4. Edit with Emacs
    qcow2_vm.ssh_exec(
        f"cd {project_dir} && emacs --batch hello.py "
        "--eval '(progn (goto-char (point-max)) (insert \"\\nprint(\\\"From Emacs\\\")\") (save-buffer))'"
    )
    
    # 5. Commit
    qcow2_vm.ssh_exec(f"cd {project_dir} && git add . && git commit -m 'Initial commit'")
    
    # 6. Verify history
    result = qcow2_vm.ssh_exec(f"cd {project_dir} && git log --oneline")
    assert "Initial commit" in result
    
    # Verify file content
    result = qcow2_vm.ssh_exec(f"cat {project_dir}/hello.py")
    assert "Hello World" in result
    assert "From Emacs" in result
    
    # Cleanup
    qcow2_vm.ssh_exec(f"rm -rf {project_dir}")


@pytest.mark.e2e
def test_multiple_terminal_sessions(qcow2_vm):
    """Test that VM can handle multiple operations."""
    # Run several commands in sequence
    commands = [
        "ls -la ~/",
        "ps aux | head",
        "df -h",
        "free -m",
        "uname -a"
    ]
    
    for cmd in commands:
        result = qcow2_vm.ssh_exec(cmd)
        assert result is not None
        assert len(result) > 0


@pytest.mark.e2e
@pytest.mark.slow
def test_system_stability_under_load(qcow2_vm):
    """Test system remains stable under moderate load."""
    # Create multiple files
    qcow2_vm.ssh_exec("for i in {1..10}; do echo 'test' > ~/test$i.txt; done")
    
    # Process them with Emacs
    for i in range(1, 11):
        qcow2_vm.ssh_exec(
            f"emacs --batch ~/test{i}.txt "
            "--eval '(progn (insert \"processed\") (save-buffer))'"
        )
    
    # Verify all processed
    result = qcow2_vm.ssh_exec("grep -l processed ~/test*.txt | wc -l")
    assert int(result.strip()) == 10
    
    # Cleanup
    qcow2_vm.ssh_exec("rm ~/test*.txt")


@pytest.mark.e2e
def test_user_customization_persists(qcow2_vm):
    """User customizations should persist in home directory."""
    # Create custom configuration
    qcow2_vm.ssh_exec("echo 'export MY_CUSTOM_VAR=test' >> ~/.bashrc")
    
    # Verify it's there
    result = qcow2_vm.ssh_exec("grep MY_CUSTOM_VAR ~/.bashrc")
    assert "MY_CUSTOM_VAR" in result
    
    # Verify it works in new shell
    result = qcow2_vm.ssh_exec("bash -c 'source ~/.bashrc && echo $MY_CUSTOM_VAR'")
    assert "test" in result
    
    # Cleanup
    qcow2_vm.ssh_exec("sed -i '/MY_CUSTOM_VAR/d' ~/.bashrc")


@pytest.mark.e2e
@pytest.mark.slow
def test_long_running_emacs_session(qcow2_vm):
    """Emacs should handle long-running operations."""
    # Create a file and perform multiple edits
    qcow2_vm.ssh_exec("echo 'Line 1' > ~/long-session.txt")
    
    for i in range(2, 6):
        qcow2_vm.ssh_exec(
            f"emacs --batch ~/long-session.txt "
            f"--eval '(progn (goto-char (point-max)) (insert \"\\nLine {i}\") (save-buffer))'"
        )
        time.sleep(0.5)
    
    # Verify all lines
    result = qcow2_vm.ssh_exec("cat ~/long-session.txt")
    for i in range(1, 6):
        assert f"Line {i}" in result
    
    # Cleanup
    qcow2_vm.ssh_exec("rm ~/long-session.txt")


@pytest.mark.e2e
def test_accessibility_features_remain_active(qcow2_vm):
    """Accessibility features should remain active throughout usage."""
    # Perform various operations
    qcow2_vm.ssh_exec("ls -la /")
    qcow2_vm.ssh_exec("cat /etc/os-release")
    qcow2_vm.ssh_exec("emacs --version")
    
    # espeakup should still be active
    result = qcow2_vm.ssh_exec("systemctl is-active espeakup")
    assert "active" in result


@pytest.mark.e2e
def test_system_resource_usage_reasonable(qcow2_vm):
    """System should not consume excessive resources."""
    # Check memory usage
    result = qcow2_vm.ssh_exec("free -m | grep Mem | awk '{print $3/$2 * 100}'")
    memory_usage = float(result.strip())
    
    # Should use less than 80% of available memory (2GB)
    assert memory_usage < 80, f"Memory usage is {memory_usage}%, should be <80%"
    
    # Check load average
    result = qcow2_vm.ssh_exec("uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ','")
    load_avg = float(result.strip())
    
    # Load should be reasonable (< 2.0 for 2 CPU system)
    assert load_avg < 2.0, f"Load average is {load_avg}, should be <2.0"
