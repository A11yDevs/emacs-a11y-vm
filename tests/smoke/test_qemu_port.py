import pytest

@pytest.mark.smoke
def test_qemu_ssh_becomes_ready(qcow2_vm, ssh_port):
    """
    Considera a VM pronta apenas quando o SSH autentica e executa um comando.
    Isso evita falso positivo de "porta aberta" quando o sshd ainda nao subiu.
    """
    result = qcow2_vm.ssh_exec("echo ssh-ready")
    assert "ssh-ready" in result
