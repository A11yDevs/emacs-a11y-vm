#!/usr/bin/env bash
# ==============================================================================
# install-release-vm.sh — Baixa release do GitHub e cria VM no VirtualBox
#
# Exemplo (última release):
#   ./scripts/install-release-vm.sh
#
# Exemplo (tag específica):
#   ./scripts/install-release-vm.sh --tag v1.0.0
#
# Exemplo (outro repositório):
#   ./scripts/install-release-vm.sh --owner A11yDevs --repo emacs-a11y-vm
# ==============================================================================
set -euo pipefail

OWNER="A11yDevs"
REPO="emacs-a11y-vm"
TAG="latest"
VM_NAME="debian-a11y"
VM_RAM="2048"
VM_CPUS="2"
SSH_HOST_PORT="2222"
OUTPUT_DIR="$PWD/releases"
USER_DATA_SIZE="10240"
PRESERVE_USER_DATA="auto"
KEEP_OLD_VM="false"
FORCE_DOWNLOAD="false"
HEADLESS="false"
NETWORK_MODE="bridge"
BRIDGE_ADAPTER=""
AUDIO_DRIVER=""
SHARED_FOLDER=""

usage() {
    cat << 'EOF'
Uso:
    ./scripts/install-release-vm.sh [opções]

Opções:
  --owner <owner>         Dono do repositório no GitHub (padrão: A11yDevs)
  --repo <repo>           Nome do repositório (padrão: emacs-a11y-vm)
  --tag <tag|latest>      Tag da release (padrão: latest)
  --vm-name <nome>        Nome da VM no VirtualBox (padrão: debian-a11y)
  --ram <mb>              RAM da VM em MB (padrão: 2048)
  --cpus <n>              Número de CPUs (padrão: 2)
  --ssh-port <porta>      Porta SSH no host (NAT PF host:guest 2222:22)
  --output-dir <dir>      Pasta para baixar o VMDK (padrão: ./releases)
  --audio-driver <driver> Driver de áudio do VirtualBox (auto por padrão)
  --user-data-size <mb>   Tamanho do disco de dados em MB (padrão: 10240 = 10GB)
  --network-mode <nat|bridge> Modo de rede (padrão: nat)
  --bridge-adapter <nome> Adaptador para bridge (auto-detecta se vazio)
  --preserve-user-data    Preserva disco de dados de VM existente (padrão: auto)
  --no-preserve-user-data Não preserva disco de dados (instalação limpa)
  --keep-old-vm           Não remove VM existente com o mesmo nome
  --force-download        Força re-download mesmo se arquivo já existe
  --headless              Inicia VM sem janela (background, acesso via SSH)
  --shared-folder <path>  Compartilha pasta do host com guest em /home/shared
                          Exemplo: --shared-folder "$HOME" (Linux/macOS)
  -h, --help              Mostra esta ajuda

Pasta Compartilhada (Shared Folder):
  Use --shared-folder para montar uma pasta do host no guest (/home/shared)
  A pasta é montada AUTOMATICAMENTE no primeiro boot da VM!
  
  Guest Additions já vem pré-instalado na imagem.
  Basta iniciar a VM e acessar /home/shared - sem passos manuais.

Arquitetura de Discos:
  Disco 1 (Sistema): VMDK imutável da release (substituído em upgrades)
  Disco 2 (Dados):   VDI persistente local em /home (preservado em upgrades)

Fluxo:
  1) Busca release via API GitHub
  2) Baixa asset .vmdk (disco de sistema)
  3) Cria VM VirtualBox (Debian_64)
  4) Anexa disco VMDK (sistema) e VDI (dados do usuário)
  5) Habilita NAT + SSH forwarding
EOF
}

die() {
    echo "Erro: $*" >&2
    exit 1
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "Comando obrigatório não encontrado: $1"
}

detect_audio_driver() {
    case "$(uname -s)" in
        Darwin)  echo "coreaudio" ;;
        Linux)
            if command -v pulseaudio >/dev/null 2>&1 || command -v pipewire >/dev/null 2>&1; then
                echo "pulse"
            else
                echo "alsa"
            fi
            ;;
        MINGW*|MSYS*|CYGWIN*) echo "default" ;;
        *)                     echo "default" ;;
    esac
}

detect_bridge_adapter() {
    VBoxManage list bridgedifs 2>/dev/null | awk -F: '/^Name:/{gsub(/^ +| +$/, "", $2); print $2; exit}'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --owner)
            OWNER="$2"
            shift 2
            ;;
        --repo)
            REPO="$2"
            shift 2
            ;;
        --tag)
            TAG="$2"
            shift 2
            ;;
        --vm-name)
            VM_NAME="$2"
            shift 2
            ;;
        --ram)
            VM_RAM="$2"
            shift 2
            ;;
        --cpus)
            VM_CPUS="$2"
            shift 2
            ;;
        --ssh-port)
            SSH_HOST_PORT="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --audio-driver)
            AUDIO_DRIVER="$2"
            shift 2
            ;;
        --user-data-size)
            USER_DATA_SIZE="$2"
            shift 2
            ;;
        --network-mode)
            NETWORK_MODE="$2"
            if [[ "$NETWORK_MODE" != "nat" ]] && [[ "$NETWORK_MODE" != "bridge" ]]; then
                die "--network-mode deve ser 'nat' ou 'bridge'"
            fi
            shift 2
            ;;
        --bridge-adapter)
            BRIDGE_ADAPTER="$2"
            shift 2
            ;;
        --preserve-user-data)
            PRESERVE_USER_DATA="true"
            shift
            ;;
        --no-preserve-user-data)
            PRESERVE_USER_DATA="false"
            shift
            ;;
        --keep-old-vm)
            KEEP_OLD_VM="true"
            shift
            ;;
        --force-download)
            FORCE_DOWNLOAD="true"
            shift
            ;;
        --headless)
            HEADLESS="true"
            shift
            ;;
        --shared-folder)
            SHARED_FOLDER="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "Opção inválida: $1. Use --help para ver as opções."
            ;;
    esac
done

need_cmd curl
need_cmd VBoxManage

if [[ -z "$AUDIO_DRIVER" ]]; then
    AUDIO_DRIVER="$(detect_audio_driver)"
fi

# Configurar rede
if [[ "$NETWORK_MODE" == "bridge" ]]; then
    if [[ -z "$BRIDGE_ADAPTER" ]]; then
        BRIDGE_ADAPTER="$(detect_bridge_adapter)"
    fi
    if [[ -z "$BRIDGE_ADAPTER" ]]; then
        die "Modo bridge selecionado mas nenhum adaptador bridge disponível. Use --bridge-adapter para especificar."
    fi
    echo "==> Modo de rede: Bridge (adaptador: $BRIDGE_ADAPTER)"
else
    echo "==> Modo de rede: NAT (SSH port forwarding: localhost:$SSH_HOST_PORT -> VM:22)"
fi

if command -v jq >/dev/null 2>&1; then
    HAS_JQ="true"
else
    HAS_JQ="false"
fi

# Resolver caminho absoluto do diretório de saída
OUTPUT_DIR="$(cd "$(dirname "$OUTPUT_DIR")" 2>/dev/null && pwd)/$(basename "$OUTPUT_DIR")" || OUTPUT_DIR="$PWD/releases"

echo "==> Configurando diretório de saída"
echo "    Caminho: $OUTPUT_DIR"

if [[ ! -d "$OUTPUT_DIR" ]]; then
    echo "    Diretório não existe, criando..."
    mkdir -p "$OUTPUT_DIR" || die "Falha ao criar diretório: $OUTPUT_DIR"
    echo "    Diretório criado com sucesso"
else
    echo "    Diretório já existe"
fi

if [[ "$TAG" == "latest" ]]; then
    API_URL="https://api.github.com/repos/${OWNER}/${REPO}/releases/latest"
else
    API_URL="https://api.github.com/repos/${OWNER}/${REPO}/releases/tags/${TAG}"
fi

echo "==> Consultando release: ${OWNER}/${REPO} (${TAG})"
RELEASE_JSON="$(curl -fsSL "$API_URL")" || die "Falha ao consultar release no GitHub."

if [[ "$HAS_JQ" == "true" ]]; then
    ASSET_URL="$(echo "$RELEASE_JSON" | jq -r '.assets[] | select(.name | endswith(".vmdk")) | .browser_download_url' | head -n1)"
    ASSET_NAME="$(echo "$RELEASE_JSON" | jq -r '.assets[] | select(.name | endswith(".vmdk")) | .name' | head -n1)"
    ASSET_SIZE="$(echo "$RELEASE_JSON" | jq -r '.assets[] | select(.name | endswith(".vmdk")) | .size' | head -n1)"
    RESOLVED_TAG="$(echo "$RELEASE_JSON" | jq -r '.tag_name // "unknown"')"
else
    ASSET_URL="$(echo "$RELEASE_JSON" | grep -Eo '"browser_download_url"\s*:\s*"[^"]+\.vmdk"' | head -n1 | sed -E 's/^.*"([^"]+)"$/\1/')"
    ASSET_NAME="$(basename "$ASSET_URL")"
    ASSET_SIZE="$(echo "$RELEASE_JSON" | grep -B5 "\"${ASSET_NAME}\"" | grep -Eo '"size"\s*:\s*[0-9]+' | grep -Eo '[0-9]+' | head -n1)"
    RESOLVED_TAG="$(echo "$RELEASE_JSON" | grep -Eo '"tag_name"\s*:\s*"[^"]+"' | head -n1 | sed -E 's/^.*"([^"]+)"$/\1/')"
fi

[[ -n "${ASSET_URL:-}" ]] || die "Nenhum asset .vmdk encontrado na release."

VMDK_PATH="${OUTPUT_DIR}/${ASSET_NAME}"

# Verificar se arquivo já existe (comparação por versão)
SKIP_DOWNLOAD="false"
VERSION_FILE="${VMDK_PATH}.version"
if [[ -f "$VMDK_PATH" ]] && [[ "$FORCE_DOWNLOAD" != "true" ]]; then
    # Verificar se versão salva corresponde à tag solicitada
    EXISTING_VERSION=""
    if [[ -f "$VERSION_FILE" ]]; then
        EXISTING_VERSION="$(cat "$VERSION_FILE" 2>/dev/null | tr -d '\n\r')"
    fi
    
    REQUESTED_VERSION="${TAG}"
    if [[ "$TAG" == "latest" ]]; then
        REQUESTED_VERSION="${RESOLVED_TAG}"
    fi
    
    if [[ "$EXISTING_VERSION" == "$REQUESTED_VERSION" ]]; then
        EXISTING_SIZE="$(stat -f%z "$VMDK_PATH" 2>/dev/null || stat -c%s "$VMDK_PATH" 2>/dev/null || echo "0")"
        EXISTING_SIZE_MB="$(awk "BEGIN {printf \"%.2f\", $EXISTING_SIZE / 1048576}")"
        echo "==> Arquivo VMDK já existe (versão: $EXISTING_VERSION)"
        echo "    Arquivo: $VMDK_PATH"
        echo "    Tamanho: ${EXISTING_SIZE_MB} MB"
        echo "    Pulando download..."
        SKIP_DOWNLOAD="true"
    else
        echo "==> Arquivo VMDK existe mas versão difere"
        echo "    Esperado: ${REQUESTED_VERSION}, Encontrado: ${EXISTING_VERSION}"
        echo "    Removendo arquivo antigo e baixando novamente..."
        rm -f "$VMDK_PATH"
        rm -f "$VERSION_FILE"
    fi
fi

if [[ "$SKIP_DOWNLOAD" != "true" ]]; then
    echo "==> Baixando asset: ${ASSET_NAME}"
    curl -fL "$ASSET_URL" -o "$VMDK_PATH"
    [[ -f "$VMDK_PATH" ]] || die "Download falhou: ${VMDK_PATH}"
    
    # Salvar versão do VMDK baixado
    DOWNLOADED_VERSION="${TAG}"
    if [[ "$TAG" == "latest" ]]; then
        DOWNLOADED_VERSION="${RESOLVED_TAG}"
    fi
    echo -n "$DOWNLOADED_VERSION" > "$VERSION_FILE"
    echo "    Versão salva: $DOWNLOADED_VERSION"
fi

# Verificação final: garantir que o arquivo VMDK existe antes de prosseguir
echo "==> Verificando arquivo VMDK"
if [[ ! -f "$VMDK_PATH" ]]; then
    echo ""
    echo "Erro: Arquivo VMDK não encontrado!"
    echo "Caminho esperado: $VMDK_PATH"
    echo ""
    echo "Possíveis causas:"
    echo "  1. Download foi interrompido"
    echo "  2. Arquivo foi movido ou deletado"
    echo "  3. Permissões de arquivo impedem acesso"
    echo ""
    echo "Solução: Execute o script novamente com --force-download"
    die "Arquivo VMDK não encontrado"
fi

FINAL_FILE_SIZE="$(stat -f%z "$VMDK_PATH" 2>/dev/null || stat -c%s "$VMDK_PATH" 2>/dev/null || echo "0")"
FINAL_FILE_SIZE_MB="$(awk "BEGIN {printf \"%.2f\", $FINAL_FILE_SIZE / 1048576}")"
echo "    Arquivo encontrado: ${FINAL_FILE_SIZE_MB} MB"
echo "    Caminho completo: $VMDK_PATH"

# Determinar caminho do disco de dados (VDI persistente)
USER_DATA_VDI_PATH="${OUTPUT_DIR}/${VM_NAME}-userdata.vdi"
USER_DATA_VDI_EXISTS="false"

if [[ -f "$USER_DATA_VDI_PATH" ]]; then
    USER_DATA_VDI_EXISTS="true"
    
    # Auto-habilitar preservação se disco já existir e modo for auto
    if [[ "$PRESERVE_USER_DATA" == "auto" ]]; then
        PRESERVE_USER_DATA="true"
        echo "==> Disco de dados detectado, preservação automática habilitada"
    fi
fi

# Se modo ainda for auto e disco não existe, não preservar (primeira instalação)
if [[ "$PRESERVE_USER_DATA" == "auto" ]]; then
    PRESERVE_USER_DATA="false"
fi

echo "==> Verificando VM existente: ${VM_NAME}"
if VBoxManage showvminfo "$VM_NAME" >/dev/null 2>&1; then
    if [[ "$KEEP_OLD_VM" == "true" ]]; then
        die "VM '${VM_NAME}' já existe e --keep-old-vm foi usado. Escolha outro --vm-name."
    fi
    
    echo "    VM existente encontrada, desanexando discos antes de remover..."
    
    # Desanexar disco de dados (porta 1) se existir e PreserveUserData ativo
    if [[ "$PRESERVE_USER_DATA" == "true" ]] && [[ "$USER_DATA_VDI_EXISTS" == "true" ]]; then
        VBoxManage storageattach "$VM_NAME" --storagectl "SATA" --port 1 --device 0 --medium none 2>/dev/null && \
            echo "    Disco de dados desanexado" || \
            echo "    Aviso: Não foi possível desanexar disco de dados (pode não estar anexado)"
    fi
    
    # Desanexar disco de sistema (porta 0) para evitar que seja deletado junto com a VM
    VBoxManage storageattach "$VM_NAME" --storagectl "SATA" --port 0 --device 0 --medium none 2>/dev/null && \
        echo "    Disco de sistema desanexado" || \
        echo "    Aviso: Não foi possível desanexar disco de sistema (pode não estar anexado)"
    
    echo "    Removendo VM antiga..."
    VBoxManage unregistervm "$VM_NAME" --delete || true
fi

# Limpar TODOS os registros de discos antigos do VirtualBox
echo "==> Limpando registros antigos de discos..."
{
    # Listar todos os discos registrados e procurar pelo VMDK
    HDDS_OUTPUT=$(VBoxManage list hdds 2>/dev/null || echo "")
    
    # Normalizar path do VMDK para comparação
    VMDK_PATH_NORMALIZED=$(echo "$VMDK_PATH" | tr '[:upper:]' '[:lower:]')
    
    # Procurar UUIDs que correspondem ao VMDK
    CURRENT_UUID=""
    FOUND_VMDK=false
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^UUID:[[:space:]]+(\{[^}]+\}) ]]; then
            CURRENT_UUID="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^Location:[[:space:]]+(.+)$ ]]; then
            LOCATION="${BASH_REMATCH[1]}"
            LOCATION_NORMALIZED=$(echo "$LOCATION" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            if [[ "$LOCATION_NORMALIZED" == "$VMDK_PATH_NORMALIZED" ]]; then
                FOUND_VMDK=true
                if [[ -n "$CURRENT_UUID" ]]; then
                    echo "    Removendo registro com UUID: $CURRENT_UUID"
                    VBoxManage closemedium disk "$CURRENT_UUID" 2>/dev/null || true
                fi
            fi
        fi
    done <<< "$HDDS_OUTPUT"
    
    if [[ "$FOUND_VMDK" == "true" ]]; then
        echo "    Registros do VMDK removidos"
    else
        echo "    VMDK não estava registrado"
    fi
} || {
    echo "    Aviso: Falha ao limpar registros (continuando...)"
}

echo "==> Criando VM '${VM_NAME}'"
VBoxManage createvm --name "$VM_NAME" --ostype Debian_64 --register

echo "==> Driver de áudio selecionado: ${AUDIO_DRIVER}"

# Configuração base: VM textual, áudio AC97 para acessibilidade
if [[ "$NETWORK_MODE" == "bridge" ]]; then
    echo "    Configurando rede como bridge"
    VBoxManage modifyvm "$VM_NAME" \
        --memory "$VM_RAM" \
        --cpus "$VM_CPUS" \
        --ioapic on \
        --boot1 disk --boot2 none --boot3 none --boot4 none \
        --audio-driver "$AUDIO_DRIVER" \
        --audio-controller ac97 \
        --audio-enabled on \
        --audio-out on \
        --audio-in on \
        --nic1 bridged \
        --bridgeadapter1 "$BRIDGE_ADAPTER" \
        --graphicscontroller vmsvga \
        --vram 16
else
    echo "    Configurando rede como NAT com port forwarding"
    VBoxManage modifyvm "$VM_NAME" \
        --memory "$VM_RAM" \
        --cpus "$VM_CPUS" \
        --ioapic on \
        --boot1 disk --boot2 none --boot3 none --boot4 none \
        --audio-driver "$AUDIO_DRIVER" \
        --audio-controller ac97 \
        --audio-enabled on \
        --audio-out on \
        --audio-in on \
        --nic1 nat \
        --natpf1 "ssh,tcp,127.0.0.1,${SSH_HOST_PORT},,22" \
        --graphicscontroller vmsvga \
        --vram 16
fi

VBoxManage storagectl "$VM_NAME" --name "SATA" --add sata --controller IntelAhci

echo "==> Anexando disco de sistema (VMDK)"

# Regenerar UUID do VMDK para evitar conflitos com registros anteriores
echo "    Regenerando UUID do disco..."
if ! VBoxManage internalcommands sethduuid "$VMDK_PATH" 2>/dev/null; then
    echo "    Aviso: Falha ao regenerar UUID, tentando anexar mesmo assim..."
fi

if ! VBoxManage storageattach "$VM_NAME" \
    --storagectl "SATA" --port 0 --device 0 \
    --type hdd --medium "$VMDK_PATH"; then
    die "Falha ao anexar disco VMDK. Dica: Se o erro for sobre UUID ou child media, tente deletar manualmente a VM antiga no VirtualBox e executar o script novamente."
fi

echo "    Disco de sistema anexado na porta SATA 0"

# Criar ou reutilizar disco de dados do usuário (VDI persistente)
echo "==> Configurando disco de dados do usuário"

if [[ "$USER_DATA_VDI_EXISTS" == "true" ]]; then
    EXISTING_VDI_SIZE="$(stat -f%z "$USER_DATA_VDI_PATH" 2>/dev/null || stat -c%s "$USER_DATA_VDI_PATH" 2>/dev/null || echo "0")"
    EXISTING_VDI_SIZE_MB="$(awk "BEGIN {printf \"%.2f\", $EXISTING_VDI_SIZE / 1048576}")"
    echo "    Disco de dados existente encontrado: ${EXISTING_VDI_SIZE_MB} MB"
    echo "    Reutilizando: $USER_DATA_VDI_PATH"
else
    echo "    Criando novo disco de dados VDI: ${USER_DATA_SIZE} MB"
    
    if VBoxManage createmedium disk \
        --filename "$USER_DATA_VDI_PATH" \
        --size "$USER_DATA_SIZE" \
        --format VDI \
        --variant Standard >/dev/null 2>&1; then
        echo "    Disco de dados criado com sucesso"
        USER_DATA_VDI_EXISTS="true"
    else
        echo "    Aviso: Falha ao criar disco de dados"
        echo "    Continuando sem disco de dados separado"
        USER_DATA_VDI_EXISTS="false"
    fi
fi

# Anexar disco de dados na porta SATA 1
if [[ "$USER_DATA_VDI_EXISTS" == "true" ]]; then
    if VBoxManage storageattach "$VM_NAME" \
        --storagectl "SATA" --port 1 --device 0 \
        --type hdd --medium "$USER_DATA_VDI_PATH" 2>/dev/null; then
        echo "    Disco de dados anexado na porta SATA 1"
    else
        echo "    Aviso: Falha ao anexar disco de dados"
        echo "    VM continuará funcionando, mas sem disco de dados separado"
        USER_DATA_VDI_EXISTS="false"
    fi
fi

# Configurar pasta compartilhada (Shared Folder)
if [[ -n "$SHARED_FOLDER" ]]; then
    echo "==> Configurando pasta compartilhada"
    
    # Verificar se pasta existe
    if [[ ! -d "$SHARED_FOLDER" ]]; then
        echo "    AVISO: Pasta não encontrada: $SHARED_FOLDER"
        echo "    Pulando configuração de pasta compartilhada"
    else
        SHARED_FOLDER_NAME="host-home"
        echo "    Nome: $SHARED_FOLDER_NAME"
        echo "    Caminho host: $SHARED_FOLDER"
        echo "    Caminho guest: /home/shared (montado automaticamente)"
        
        if VBoxManage sharedfolder add "$VM_NAME" \
            --name "$SHARED_FOLDER_NAME" \
            --hostpath "$SHARED_FOLDER" \
            --automount 2>/dev/null; then
            echo "    Pasta compartilhada configurada com sucesso!"
            echo ""
            echo "    A pasta será montada AUTOMATICAMENTE em /home/shared"
            echo "    Guest Additions já vem pré-instalado na VM"
            echo "    Basta iniciar a VM e acessar: cd /home/shared"
            echo ""
        else
            echo "    AVISO: Falha ao configurar pasta compartilhada"
        fi
    fi
fi

# Determinar modo de inicialização
if [[ "$HEADLESS" == "true" ]]; then
    VM_TYPE="headless"
    VM_TYPE_DESC="headless (sem janela, acesso via SSH)"
else
    VM_TYPE="gui"
    VM_TYPE_DESC="GUI (console visível)"
fi

echo "==> Iniciando VM em modo $VM_TYPE_DESC"
VBoxManage startvm "$VM_NAME" --type "$VM_TYPE"

cat << EOF

✔ VM criada e iniciada com sucesso.

Release: ${OWNER}/${REPO} (${RESOLVED_TAG})
VM:      ${VM_NAME}
Modo:    ${VM_TYPE_DESC}

EOF

if [[ "$HEADLESS" == "true" ]]; then
    cat << EOF
VM rodando em background (modo headless)
Para acessar, conecte via SSH:
  ssh -p ${SSH_HOST_PORT} a11ydevs@localhost

EOF
else
    cat << EOF
VM iniciada com console visível!
A janela do VirtualBox deve estar aberta.

Use o console TUI para login direto:
  usuário: a11ydevs
  senha:   a11ydevs

Acesso SSH também disponível:
  ssh -p ${SSH_HOST_PORT} a11ydevs@localhost

EOF
fi

cat << EOF
Arquitetura de Discos:
  Sistema (SATA 0): ${VMDK_PATH}
EOF

if [[ "$USER_DATA_VDI_EXISTS" == "true" ]]; then
    cat << EOF
  Dados (SATA 1):   ${USER_DATA_VDI_PATH}

O disco de dados será montado automaticamente em /home
no primeiro boot. Suas configurações do Emacs e arquivos
pessoais serão preservados em upgrades futuros.
EOF
else
    cat << EOF
  Dados: Não configurado (tudo em disco único)
EOF
fi

if [[ "$USER_DATA_VDI_EXISTS" == "true" ]]; then
    cat << EOF
Para mais informações sobre customização e upgrades, veja:
  https://github.com/${OWNER}/${REPO}/blob/main/docs/architecture.md

EOF
fi
