# Test Suite - emacs-a11y-vm

Infraestrutura de testes automatizados para validar imagens QCOW2 geradas pelo Packer.

## Visão Geral

Esta suite de testes valida a qualidade da VM Debian acessível com Emacs antes da distribuição. Os testes são organizados em três níveis:

- **Smoke** (~2 min): Validação rápida de funcionalidade essencial
- **Integration** (~10 min): Testes funcionais de componentes específicos
- **E2E** (~20 min): Fluxos completos de usuário

## Arquitetura

```
tests/
├── lib/
│   └── vm_manager.py      # Gerenciamento do ciclo de vida da VM (QEMU + SSH)
├── conftest.py            # Fixtures pytest compartilhadas
├── requirements.txt       # Dependências Python
├── smoke/                 # Testes rápidos de validação
├── integration/           # Testes funcionais por feature
├── e2e/                   # Testes de workflow completo
└── fixtures/              # Dados golden para testes de regressão
```

## Pré-requisitos

- Python 3.8+
- QEMU/KVM (para boot da VM)
- Imagem QCOW2 em `output/debian-a11ydevs.qcow2`

## Uso Local

### 1. Instalar dependências

```bash
cd tests
pip install -r requirements.txt
```

### 2. Executar testes

```bash
# Todos os testes
pytest -v

# Apenas smoke (rápido)
pytest smoke/ -v

# Apenas integration
pytest integration/ -v

# Apenas e2e
pytest e2e/ -v

# Testes em paralelo (mais rápido)
pytest -n auto

# Com timeout de 5 minutos por teste
pytest --timeout=300
```

### 3. Ver relatório detalhado

```bash
pytest -v --tb=short
```

## Estrutura de Testes

### Smoke Tests (smoke/)

Validação rápida de funcionalidade essencial:

- **test_boot.py**: VM inicia <60s, SSH acessível
- **test_essentials.py**: Pacotes críticos instalados (emacs, espeakup)
- **test_accessibility.py**: Síntese de voz configurada

### Integration Tests (integration/)

Testes funcionais por feature:

- **test_repositories.py**: Repositórios A11yDevs configurados (v2.0.27)
- **test_shared_folders.py**: mount-shared-folder.sh parsing correto (v2.0.25)
- **test_network.py**: DHCP, DNS, conectividade
- **test_userdata_disk.py**: Detecção do disco de dados
- **test_emacs.py**: Emacs funcional
- **test_emacspeak.py**: Emacspeak instalado e funcionando (leitor de tela para Emacs)
- **test_emacspeak.py**: Emacspeak instalado e funcionando

### E2E Tests (e2e/)

Fluxos completos de usuário:

- **test_emergency_recovery.py**: F12 hotkey, restart-speech (v2.0.20)
- **test_upgrade_path.py**: Upgrade preserva dados
- **test_full_workflow.py**: Sessão completa de usuário

## CI Integration

Os testes são executados automaticamente no GitHub Actions:

- **On push/PR**: Smoke + Integration
- **On release tag**: Smoke + Integration + E2E (gate de qualidade)

Ver [../.github/workflows/test.yml](../.github/workflows/test.yml) para detalhes.

## Fixtures Pytest

### `qcow2_vm` (session-scoped)

VM iniciada uma vez, reutilizada por todos os testes:

```python
def test_something(qcow2_vm):
    stdout = qcow2_vm.ssh_exec("echo hello")
    assert stdout.strip() == "hello"
```

### `ssh_client` (function-scoped)

Cliente SSH para comandos individuais:

```python
def test_package_installed(ssh_client):
    result = ssh_client.exec_command("dpkg -l emacs")
    assert "emacs" in result
```

### `fresh_vm` (function-scoped)

Nova instância da VM para testes que necessitam estado limpo:

```python
def test_first_boot(fresh_vm):
    # Testa comportamento no primeiro boot
    pass
```

## VMManager API

Classe principal para controle da VM:

```python
from lib.vm_manager import VMManager

vm = VMManager()
vm.boot("output/debian-a11ydevs.qcow2", ssh_port=2222)
vm.wait_ssh_ready(timeout=120)

# Executar comandos
stdout = vm.ssh_exec("uname -a")
print(stdout)

# Reboot
vm.reboot()

# Shutdown
vm.shutdown()
```

## Troubleshooting

### VM não inicia

```bash
# Verificar se QCOW2 existe
ls -lh output/debian-a11ydevs.qcow2

# Testar boot manual
qemu-system-x86_64 -m 2048 -smp 2 \
  -drive file=output/debian-a11ydevs.qcow2,format=qcow2 \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device virtio-net,netdev=net0 \
  -nographic -enable-kvm
```

### SSH não conecta

```bash
# Verificar se porta está escutando
ss -tlnp | grep 2222

# Testar conexão manual
ssh -p 2222 -o StrictHostKeyChecking=no a11ydevs@localhost
```

### Testes lentos

Use pytest-xdist para paralelização:

```bash
pytest -n auto  # Usa todos os cores disponíveis
```

## Validação por Versão

Cada teste valida features específicas de versões:

- **v2.0.20**: F12 emergency recovery, restart-speech
- **v2.0.25**: mount-shared-folder.sh parsing field $3
- **v2.0.26**: UUID cleanup com --delete
- **v2.0.27**: A11yDevs repositories auto-configuration

## Contribuindo

1. Adicione novos testes em smoke/, integration/ ou e2e/
2. Use fixtures existentes (qcow2_vm, ssh_client)
3. Documente o que está sendo validado
4. Execute localmente antes de commit:
   ```bash
   pytest -v
   ```
