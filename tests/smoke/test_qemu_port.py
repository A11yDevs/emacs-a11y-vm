import socket
import pytest
import time

@pytest.mark.smoke
@pytest.mark.order(1)
def test_qemu_ssh_port_opens_first(qcow2_path, ssh_port, vm_config):
    """
    Testa se a porta TCP do SSH do QEMU abre em até 120s antes de tentar SSH.
    Falha rápido se a porta não abrir, evitando esperar timeout do SSH.
    """
    timeout = 120
    start = time.time()
    while time.time() - start < timeout:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(2)
        try:
            if sock.connect_ex(("localhost", ssh_port)) == 0:
                sock.close()
                return  # Porta aberta!
        except Exception:
            pass
        finally:
            sock.close()
        time.sleep(2)
    pytest.fail(f"Porta TCP {ssh_port} não abriu em {timeout}s. QEMU não está escutando ou port forwarding falhou.")
