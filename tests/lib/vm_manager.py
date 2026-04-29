"""
VMManager - QEMU VM lifecycle management for testing

This class manages the lifecycle of a QEMU VM for automated testing:
- Boot VM with QEMU + KVM acceleration
- SSH port forwarding for command execution
- Wait for SSH to become ready
- Execute commands via SSH (paramiko)
- Graceful shutdown and cleanup
"""

import subprocess
import time
import logging
import socket
import paramiko
from pathlib import Path

logger = logging.getLogger(__name__)


class VMManager:
    """Manage QEMU VM lifecycle for automated testing."""
    
    def __init__(self):
        self.qemu_process = None
        self.ssh_client = None
        self.ssh_host = "localhost"
        self.ssh_port = None
        self.ssh_user = "a11ydevs"
        self.ssh_password = "a11ydevs"
        self.qcow2_path = None
    
    def _is_port_available(self, port: int) -> bool:
        """
        Check if a TCP port is available for binding.
        
        Args:
            port: Port number to check
            
        Returns:
            True if port is available, False if in use
        """
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(1)
        try:
            # Try to bind to the port
            sock.bind(('localhost', port))
            sock.close()
            return True
        except OSError:
            # Port is in use
            return False
        finally:
            sock.close()
        
    def boot(self, qcow2_path: str, ssh_port: int = 2222, memory: int = 2048, cpus: int = 2):
        """
        Boot VM with QEMU.
        
        Args:
            qcow2_path: Path to QCOW2 disk image
            ssh_port: Host port for SSH forwarding (default: 2222)
            memory: RAM in MB (default: 2048)
            cpus: Number of CPUs (default: 2)
        
        Raises:
            FileNotFoundError: If QCOW2 file doesn't exist
            RuntimeError: If QEMU fails to start or port is already in use
        """
        qcow2_path = Path(qcow2_path)
        if not qcow2_path.exists():
            raise FileNotFoundError(f"QCOW2 file not found: {qcow2_path}")
        
        # Check if SSH port is available before starting QEMU
        if not self._is_port_available(ssh_port):
            raise RuntimeError(
                f"Port {ssh_port} is already in use. "
                f"Another VM or service might be using it. "
                f"Try a different port with --ssh-port option."
            )
        logger.info(f"Port {ssh_port} is available")
        
        self.qcow2_path = qcow2_path
        self.ssh_port = ssh_port
        
        # Build QEMU command
        cmd = [
            "qemu-system-x86_64",
            "-m", str(memory),
            "-smp", str(cpus),
            "-drive", f"file={qcow2_path},format=qcow2,if=virtio",
            "-netdev", f"user,id=net0,hostfwd=tcp::{ssh_port}-:22",
            "-device", "virtio-net,netdev=net0",
            "-nographic",
            "-serial", "none",
            "-monitor", "none",
        ]
        
        # Add KVM acceleration if available (Linux only)
        try:
            subprocess.run(["which", "kvm"], check=True, capture_output=True)
            cmd.append("-enable-kvm")
            logger.info("KVM acceleration enabled")
        except subprocess.CalledProcessError:
            logger.warning("KVM not available, running without acceleration")
        
        logger.info(f"Starting VM: {' '.join(cmd)}")
        
        # Start QEMU in background
        try:
            self.qemu_process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                start_new_session=True  # Detach from terminal
            )
            logger.info(f"QEMU started with PID {self.qemu_process.pid}")
        except Exception as e:
            raise RuntimeError(f"Failed to start QEMU: {e}")
        
        # Wait a bit for QEMU to initialize
        time.sleep(2)
        
        # Verify QEMU process is still running
        if self.qemu_process.poll() is not None:
            stderr = self.qemu_process.stderr.read().decode('utf-8')
            raise RuntimeError(
                f"QEMU process exited immediately with code {self.qemu_process.returncode}. "
                f"Error: {stderr}"
            )
    
    def _test_tcp_port(self, host: str, port: int, timeout: float = 2.0) -> bool:
        """
        Test if a TCP port is open and accepting connections.
        
        Args:
            host: Hostname or IP
            port: Port number
            timeout: Connection timeout in seconds
            
        Returns:
            True if port is open, False otherwise
        """
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        try:
            result = sock.connect_ex((host, port))
            sock.close()
            return result == 0
        except socket.error:
            return False
        finally:
            sock.close()
    
    def wait_ssh_ready(self, timeout: int = 120):
        """
        Wait for SSH to become accessible.
        
        Args:
            timeout: Maximum seconds to wait (default: 120)
        
        Raises:
            TimeoutError: If SSH doesn't become ready within timeout
        """
        logger.info(f"Waiting for SSH on {self.ssh_host}:{self.ssh_port} (timeout: {timeout}s)")
        
        start_time = time.time()
        last_log_time = start_time
        attempt = 0
        port_opened = False
        port_open_time = None
        
        while time.time() - start_time < timeout:
            elapsed = int(time.time() - start_time)
            attempt += 1
            
            # Check if QEMU process is still running
            if self.qemu_process and self.qemu_process.poll() is not None:
                raise RuntimeError(
                    f"QEMU process died while waiting for SSH (exit code: {self.qemu_process.returncode})"
                )
            
            # First check if TCP port is open (fast check)
            if not port_opened:
                if self._test_tcp_port(self.ssh_host, self.ssh_port, timeout=1.0):
                    port_opened = True
                    port_open_time = time.time()
                    wait_time = int(port_open_time - start_time)
                    logger.info(f"✓ Port {self.ssh_port} is now accepting connections after {wait_time}s")
                else:
                    # Port not open yet - log every 30 seconds
                    if elapsed - (last_log_time - start_time) >= 30:
                        logger.warning(
                            f"Port {self.ssh_port} not yet open ({elapsed}/{timeout}s elapsed, "
                            f"attempt #{attempt}). VM may still be booting..."
                        )
                        last_log_time = time.time()
                    time.sleep(5)
                    continue
            
            # Port is open, now try SSH
            # Log progress every 30 seconds
            if elapsed - (last_log_time - start_time) >= 30:
                ssh_wait = int(elapsed - (port_open_time - start_time))
                logger.info(
                    f"Port open but SSH not ready yet ({ssh_wait}s waiting for SSH, "
                    f"attempt #{attempt})"
                )
                last_log_time = time.time()
            
            try:
                # Attempt SSH connection
                client = paramiko.SSHClient()
                client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
                client.connect(
                    hostname=self.ssh_host,
                    port=self.ssh_port,
                    username=self.ssh_user,
                    password=self.ssh_password,
                    timeout=5,
                    banner_timeout=10
                )
                
                # Test command execution
                stdin, stdout, stderr = client.exec_command("echo ready")
                result = stdout.read().decode().strip()
                
                if result == "ready":
                    total_wait = int(time.time() - start_time)
                    logger.info(f"✓ SSH is ready after {total_wait}s total ({attempt} attempts)!")
                    self.ssh_client = client
                    return
                
                client.close()
            except Exception as e:
                logger.debug(f"SSH connection failed (attempt #{attempt}): {type(e).__name__}")
                time.sleep(5)
        
        # Timeout reached - provide diagnostic info
        error_msg = f"SSH did not become ready within {timeout} seconds (tried {attempt} times)"
        
        # Check QEMU status
        if self.qemu_process:
            if self.qemu_process.poll() is not None:
                error_msg += f"\n⚠️  QEMU process exited with code {self.qemu_process.returncode}"
                try:
                    stderr = self.qemu_process.stderr.read().decode('utf-8', errors='ignore')
                    if stderr:
                        error_msg += f"\n   QEMU stderr: {stderr[:500]}"
                except:
                    pass
            else:
                error_msg += f"\n✓  QEMU process (PID {self.qemu_process.pid}) is still running"
        
        # Port diagnostics
        if not port_opened:
            error_msg += f"\n⚠️  TCP port {self.ssh_port} never opened - VM likely failed to boot or port forwarding broken"
            error_msg += f"\n   Possible causes:"
            error_msg += f"\n   - VM failed to boot (check QEMU stderr above)"
            error_msg += f"\n   - Port {self.ssh_port} already in use"
            error_msg += f"\n   - QEMU port forwarding misconfigured"
        else:
            wait_time = int(port_open_time - start_time)
            error_msg += f"\n⚠️  Port opened after {wait_time}s but SSH never responded"
            error_msg += f"\n   Possible causes:"
            error_msg += f"\n   - SSH service failed to start in VM"
            error_msg += f"\n   - SSH listening on wrong interface"
            error_msg += f"\n   - Authentication issues"
        
        raise TimeoutError(error_msg)
    
    def ssh_exec(self, command: str, timeout: int = 30) -> str:
        """
        Execute command via SSH.
        
        Args:
            command: Shell command to execute
            timeout: Command timeout in seconds (default: 30)
        
        Returns:
            Command stdout as string
        
        Raises:
            RuntimeError: If SSH is not connected
            TimeoutError: If command exceeds timeout
        """
        if not self.ssh_client:
            raise RuntimeError("SSH not connected. Call wait_ssh_ready() first.")
        
        logger.debug(f"Executing: {command}")
        
        try:
            stdin, stdout, stderr = self.ssh_client.exec_command(command, timeout=timeout)
            exit_code = stdout.channel.recv_exit_status()
            
            stdout_str = stdout.read().decode()
            stderr_str = stderr.read().decode()
            
            if exit_code != 0:
                logger.warning(f"Command failed (exit {exit_code}): {stderr_str}")
            
            return stdout_str
        except Exception as e:
            raise RuntimeError(f"SSH command failed: {e}")
    
    def get_ssh_client(self):
        """Get the SSH client for direct paramiko operations."""
        if not self.ssh_client:
            raise RuntimeError("SSH not connected. Call wait_ssh_ready() first.")
        return self.ssh_client
    
    def reboot(self, wait_ready: bool = True):
        """
        Reboot the VM gracefully.
        
        Args:
            wait_ready: Wait for SSH to become ready after reboot (default: True)
        """
        logger.info("Rebooting VM...")
        
        try:
            self.ssh_exec("sudo reboot", timeout=5)
        except Exception:
            pass  # SSH connection will drop during reboot
        
        # Close SSH connection
        if self.ssh_client:
            self.ssh_client.close()
            self.ssh_client = None
        
        if wait_ready:
            time.sleep(10)  # Wait for reboot to start
            self.wait_ssh_ready(timeout=120)
    
    def shutdown(self):
        """Shutdown VM gracefully and cleanup."""
        logger.info("Shutting down VM...")
        
        # Try graceful shutdown via SSH
        if self.ssh_client:
            try:
                self.ssh_exec("sudo poweroff", timeout=5)
            except Exception:
                pass  # SSH may drop before command completes
            
            self.ssh_client.close()
            self.ssh_client = None
        
        # Wait for QEMU to exit gracefully
        if self.qemu_process:
            try:
                self.qemu_process.wait(timeout=30)
                logger.info("QEMU exited gracefully")
            except subprocess.TimeoutExpired:
                logger.warning("QEMU did not exit gracefully, terminating...")
                self.qemu_process.terminate()
                
                try:
                    self.qemu_process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    logger.error("QEMU did not terminate, killing...")
                    self.qemu_process.kill()
                    self.qemu_process.wait()
            
            self.qemu_process = None
    
    def __enter__(self):
        """Context manager entry."""
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit - ensures cleanup."""
        self.shutdown()
        return False
