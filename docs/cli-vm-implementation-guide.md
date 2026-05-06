# Guia de Implementação: Funcionalidades de VM

Este documento descreve como implementar as funcionalidades de VM (VirtualBox e QEMU) na versão Bash da CLI.

## Arquitetura Geral

### Estrutura de Diretórios

```
~/.emacs-a11y-vm/
  ├── debian-a11ydevs.qcow2              # Imagem de sistema QEMU
  ├── debian-a11y-home.qcow2             # Disco de dados QEMU
  ├── qemu/                              # Estado das VMs QEMU
  │   └── debian-a11y.json               # Metadados JSON com PID, porta SSH, etc
  ├── vbox/                              # Estado das VMs VirtualBox
  │   └── debian-a11y.json               # Metadados JSON
  └── logs/                              # Logs de execução
      └── debian-a11y.log
```

## Implementação por Backend

### VirtualBox

#### 1. `vm list`

**Função:** Listar todas as VMs
**Dependência:** `vboxmanage` ou `VBoxManage`
**Implementação:**

```bash
invoke_vm_list_virtualbox() {
    # Verificar se vboxmanage está disponível
    if ! command -v vboxmanage &>/dev/null && ! command -v VBoxManage &>/dev/null; then
        ea11_error "VirtualBox não está instalado"
        return 1
    fi
    
    local cmd="vboxmanage"
    ! command -v vboxmanage &>/dev/null && cmd="VBoxManage"
    
    # Listar VMs
    $cmd list vms
}
```

#### 2. `vm start`

**Função:** Iniciar VM
**Dependência:** `vboxmanage`, `VBoxHeadless` (opcional)
**Parâmetros:**
- `--name` / `-n`: Nome da VM (padrão: debian-a11y)
- `--headless` / `-h`: Modo sem GUI
- `--type`: Gui ou Headless

**Implementação:**

```bash
invoke_vm_start_virtualbox() {
    local name="${1:-debian-a11y}"
    local headless=0
    
    # Verificar se está rodando
    if vboxmanage showvminfo "$name" 2>/dev/null | grep -q "running"; then
        ea11_info "VM $name já está rodando"
        return 0
    fi
    
    # Iniciar
    if [[ $headless -eq 1 ]]; then
        vboxmanage startvm "$name" --type headless
    else
        vboxmanage startvm "$name" --type gui
    fi
    
    # Aguardar inicialização
    sleep 3
}
```

#### 3. `vm stop`

**Função:** Parar VM
**Parâmetros:**
- `--name` / `-n`: Nome da VM
- `--force` / `-f`: Forçar (ACPI shutdown vs poweroff)

```bash
invoke_vm_stop_virtualbox() {
    local name="${1:-debian-a11y}"
    local force=0
    
    # Verificar se está rodando
    if ! vboxmanage showvminfo "$name" 2>/dev/null | grep -q "running"; then
        ea11_info "VM $name não está rodando"
        return 0
    fi
    
    if [[ $force -eq 1 ]]; then
        # Poweroff imediato
        vboxmanage controlvm "$name" poweroff
    else
        # ACPI shutdown (mais limpo)
        vboxmanage controlvm "$name" acpipowerbutton
        sleep 5
    fi
}
```

#### 4. `vm status`

**Função:** Verificar status da VM

```bash
invoke_vm_status_virtualbox() {
    local name="${1:-debian-a11y}"
    
    vboxmanage showvminfo "$name" | grep -E "^State|^Name" || {
        ea11_error "VM $name não encontrada"
        return 1
    }
}
```

#### 5. `vm ssh`

**Função:** Conectar via SSH
**Parâmetros:**
- `--user` / `-u`: Usuário SSH (padrão: a11ydevs)
- `--port` / `-p`: Porta SSH (padrão: 2222)

```bash
invoke_vm_ssh_virtualbox() {
    local user="${1:-a11ydevs}"
    local port="${2:-2222}"
    shift 2 || true
    
    # Validar se VM está rodando
    if ! vboxmanage list runningvms | grep -q "debian-a11y"; then
        ea11_warn "VM parece não estar rodando"
    fi
    
    ssh -p "$port" "$user@localhost" "$@"
}
```

#### 6. `share-folder`

**Função:** Gerenciar pastas compartilhadas

```bash
invoke_share_folder_add_virtualbox() {
    local name="${1:-debian-a11y}"
    local path="$2"
    local folder_name="${3:-shared}"
    local readonly="${4:-0}"
    
    if [[ ! -d "$path" ]]; then
        ea11_error "Caminho não existe: $path"
        return 1
    fi
    
    local readonly_flag=""
    [[ $readonly -eq 1 ]] && readonly_flag="--readonly"
    
    vboxmanage sharedfolder add "$name" --name "$folder_name" --hostpath "$path" $readonly_flag
}
```

### QEMU

#### 1. Estado JSON

Estrutura de estado para QEMU:

```json
{
  "vm_name": "debian-a11y",
  "backend": "qemu",
  "qemu_pid": 12345,
  "qemu_command": "qemu-system-x86_64 ...",
  "ssh_port": 2222,
  "monitor_port": 5555,
  "vnc_port": 5900,
  "system_image": "/Users/user/.emacs-a11y-vm/debian-a11ydevs.qcow2",
  "data_disk": "/Users/user/.emacs-a11y-vm/debian-a11y-home.qcow2",
  "started_at": "2026-05-05T22:30:00Z",
  "status": "running"
}
```

#### 2. `vm list` (QEMU)

```bash
invoke_qemu_vm_list() {
    local state_dir
    state_dir=$(get_ea11_state_directory)/qemu
    
    if [[ ! -d "$state_dir" ]]; then
        return 0
    fi
    
    find "$state_dir" -name "*.json" -type f | while read -r state_file; do
        local vm_name
        vm_name=$(basename "$state_file" .json)
        
        # Verificar se PID ainda está rodando
        local pid
        pid=$(jq -r '.qemu_pid' "$state_file" 2>/dev/null || echo "")
        
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            echo "  $vm_name (running, PID: $pid)"
        else
            echo "  $vm_name (stopped)"
        fi
    done
}
```

#### 3. `vm start` (QEMU)

```bash
invoke_qemu_vm_start() {
    local name="${1:-debian-a11y}"
    local headless="${2:-1}"
    
    local state_file
    state_file=$(get_ea11_state_directory)/qemu/"$name".json
    
    # Verificar se já está rodando
    if [[ -f "$state_file" ]]; then
        local pid
        pid=$(jq -r '.qemu_pid' "$state_file" 2>/dev/null || echo "")
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            ea11_info "VM $name já está rodando (PID: $pid)"
            return 0
        fi
    fi
    
    local system_image
    system_image=$(get_home_directory)/.emacs-a11y-vm/debian-a11ydevs.qcow2
    
    if [[ ! -f "$system_image" ]]; then
        ea11_error "Imagem de sistema não encontrada: $system_image"
        return 1
    fi
    
    # Determinar portas disponíveis
    local ssh_port=2222
    local vnc_port=5900
    
    # Construir comando QEMU
    local qemu_cmd=(
        qemu-system-x86_64
        -m 2G
        -smp 2
        -enable-kvm
        -drive "file=$system_image,format=qcow2"
        -net user,hostfwd="tcp::$ssh_port-:22"
        -net nic
        -vnc "localhost:$((vnc_port - 5900))"
    )
    
    if [[ $headless -eq 1 ]]; then
        qemu_cmd+=(-nographic)
    fi
    
    # Iniciar em background
    local log_file
    log_file=$(get_ea11_state_directory)/logs/"$name".log
    mkdir -p "$(dirname "$log_file")"
    
    "${qemu_cmd[@]}" >"$log_file" 2>&1 &
    local qemu_pid=$!
    
    # Salvar estado
    local state
    state=$(cat <<EOF
{
  "vm_name": "$name",
  "backend": "qemu",
  "qemu_pid": $qemu_pid,
  "ssh_port": $ssh_port,
  "vnc_port": $vnc_port,
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "running"
}
EOF
)
    
    mkdir -p "$(dirname "$state_file")"
    echo "$state" > "$state_file"
    
    ea11_info "VM iniciada com PID: $qemu_pid"
}
```

## Dependências Externas

### Obrigatórias (conforme backend)

#### VirtualBox
- `vboxmanage` ou `VBoxManage`
- `VBoxHeadless` (opcional, para modo headless)

#### QEMU
- `qemu-system-x86_64`
- `jq` (para parsing JSON)

### Opcionais
- `ssh` (para conexão SSH)
- `curl` / `wget` (para downloads)

## Instalação de Dependências

### macOS
```bash
# VirtualBox
brew install --cask virtualbox

# QEMU
brew install qemu

# jq
brew install jq
```

### Debian/Ubuntu
```bash
# VirtualBox
sudo apt-get install virtualbox

# QEMU
sudo apt-get install qemu-system-x86 qemu-utils

# jq
sudo apt-get install jq
```

## Testes

### Teste VirtualBox
```bash
# Listar VMs
./ea11ctl vm list --backend virtualbox

# Iniciar
./ea11ctl vm start -n debian-a11y --backend virtualbox

# Status
./ea11ctl vm status --backend virtualbox

# Parar
./ea11ctl vm stop --backend virtualbox
```

### Teste QEMU
```bash
# Listar
./ea11ctl vm list --backend qemu

# Iniciar
./ea11ctl vm start --backend qemu

# SSH
./ea11ctl vm ssh --backend qemu
```

## Tratamento de Erros

### Casos Comuns

1. **VM já rodando**
   - Verificar se processo está ativo
   - Usar `--force` para forçar parada

2. **Porta em uso**
   - QEMU: tentar próximas portas (2222, 2223, etc.)
   - VirtualBox: verificar configuração de porta SSH

3. **Imagem não encontrada**
   - Verificar `~/.emacs-a11y-vm/`
   - Sugerir download da imagem

4. **Permissões**
   - VirtualBox: pode precisar de sudo
   - QEMU: KVM precisa de permissões especiais

## Performance

### Otimizações

1. **QEMU**
   - Usar `-enable-kvm` quando disponível
   - Alocar CPUs suficientes (`-smp`)
   - Cache de disco (`-drive cache=writeback`)

2. **VirtualBox**
   - Usar 3D acceleration quando possível
   - Alocar quantidade adequada de RAM
   - Usar modo headless para economia de recursos

## Logging e Debug

```bash
# Modo verbose
EA11CTL_DEBUG=1 ./ea11ctl vm start

# Salvar logs
./ea11ctl vm start --log /tmp/vm-start.log

# Ver logs de VM
tail -f ~/.emacs-a11y-vm/logs/debian-a11y.log
```

## Referências

- [QEMU Documentation](https://qemu.readthedocs.io/)
- [VirtualBox Documentation](https://www.virtualbox.org/wiki/Documentation)
- [PowerShell CLI Reference](../cli/ea11ctl.ps1)
- [Bash CLI Reference](../cli/ea11ctl)
