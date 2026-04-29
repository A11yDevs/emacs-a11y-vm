"""
Pytest configuration and shared fixtures for emacs-a11y-vm testing.

Fixtures:
- qcow2_vm: Session-scoped VM (boot once, reuse for all tests)
- ssh_client: Function-scoped SSH client
- fresh_vm: Function-scoped new VM instance
"""

import pytest
import logging
from pathlib import Path
from lib.vm_manager import VMManager

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

logger = logging.getLogger(__name__)


def pytest_addoption(parser):
    """Add custom command-line options."""
    parser.addoption(
        "--qcow2",
        action="store",
        default="output/debian-a11ydevs.qcow2",
        help="Path to QCOW2 image (default: output/debian-a11ydevs.qcow2)"
    )
    parser.addoption(
        "--ssh-port",
        action="store",
        default="2222",
        help="SSH port for VM (default: 2222)"
    )
    parser.addoption(
        "--vm-memory",
        action="store",
        default="2048",
        help="VM memory in MB (default: 2048)"
    )
    parser.addoption(
        "--vm-cpus",
        action="store",
        default="2",
        help="VM CPUs (default: 2)"
    )


@pytest.fixture(scope="session")
def qcow2_path(request):
    """Get QCOW2 path from command line or default."""
    path = Path(request.config.getoption("--qcow2"))
    if not path.exists():
        pytest.fail(f"QCOW2 file not found: {path}. Please provide a valid QCOW2 image with --qcow2 option.")
    return str(path)


@pytest.fixture(scope="session")
def ssh_port(request):
    """Get SSH port from command line or default."""
    return int(request.config.getoption("--ssh-port"))


@pytest.fixture(scope="session")
def vm_config(request):
    """Get VM configuration from command line."""
    return {
        "memory": int(request.config.getoption("--vm-memory")),
        "cpus": int(request.config.getoption("--vm-cpus")),
    }


@pytest.fixture(scope="session")
def qcow2_vm(qcow2_path, ssh_port, vm_config):
    """
    Session-scoped VM fixture.
    
    Boots VM once at the start of test session and keeps it running
    for all tests. This dramatically improves test speed.
    
    Usage:
        def test_something(qcow2_vm):
            result = qcow2_vm.ssh_exec("echo hello")
            assert "hello" in result
    """
    logger.info("=== Starting session-scoped VM ===")
    logger.info(f"QCOW2: {qcow2_path}")
    logger.info(f"SSH port: {ssh_port}")
    logger.info(f"Memory: {vm_config['memory']}MB, CPUs: {vm_config['cpus']}")
    
    vm = VMManager()
    
    try:
        # Boot VM
        vm.boot(
            qcow2_path,
            ssh_port=ssh_port,
            memory=vm_config["memory"],
            cpus=vm_config["cpus"]
        )
        
        # Wait for SSH
        logger.info("Waiting for SSH to become ready...")
        vm.wait_ssh_ready(timeout=120)
        
        logger.info("=== VM is ready for testing ===")
        
        # Yield VM to tests
        yield vm
        
    finally:
        # Cleanup after all tests
        logger.info("=== Shutting down session-scoped VM ===")
        vm.shutdown()


@pytest.fixture
def ssh_client(qcow2_vm):
    """
    Function-scoped SSH client fixture.
    
    Provides direct access to paramiko SSH client for advanced usage.
    
    Usage:
        def test_something(ssh_client):
            stdin, stdout, stderr = ssh_client.exec_command("ls /")
            files = stdout.read().decode()
            assert "home" in files
    """
    return qcow2_vm.get_ssh_client()


@pytest.fixture
def fresh_vm(qcow2_path, vm_config):
    """
    Function-scoped fresh VM fixture.
    
    Creates a new VM instance for each test. Use this for tests that
    require a clean VM state (e.g., testing first boot behavior).
    
    Note: This is SLOW - prefer qcow2_vm when possible.
    
    Usage:
        def test_first_boot(fresh_vm):
            result = fresh_vm.ssh_exec("uptime")
            # Test first boot behavior
    """
    logger.info("=== Starting fresh VM instance ===")
    
    vm = VMManager()
    
    try:
        # Use different SSH port to avoid conflict with session VM
        import random
        ssh_port = random.randint(3000, 4000)
        
        vm.boot(
            qcow2_path,
            ssh_port=ssh_port,
            memory=vm_config["memory"],
            cpus=vm_config["cpus"]
        )
        
        vm.wait_ssh_ready(timeout=120)
        
        yield vm
        
    finally:
        logger.info("=== Shutting down fresh VM instance ===")
        vm.shutdown()


# Pytest configuration
def pytest_configure(config):
    """Register custom markers."""
    config.addinivalue_line(
        "markers", "slow: mark test as slow (e2e tests)"
    )
    config.addinivalue_line(
        "markers", "smoke: mark test as smoke test (fast validation)"
    )
    config.addinivalue_line(
        "markers", "integration: mark test as integration test"
    )
