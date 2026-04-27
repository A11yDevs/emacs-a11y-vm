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
AUDIO_DRIVER=""

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
  --preserve-user-data    Preserva disco de dados de VM existente (padrão: auto)
  --no-preserve-user-data Não preserva disco de dados (instalação limpa)
  --keep-old-vm           Não remove VM existente com o mesmo nome
  --force-download        Força re-download mesmo se arquivo já existe
  -h, --help              Mostra esta ajuda

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

# Verificar se arquivo já existe
SKIP_DOWNLOAD="false"
if [[ -f "$VMDK_PATH" ]] && [[ "$FORCE_DOWNLOAD" != "true" ]]; then
    EXISTING_SIZE="$(stat -f%z "$VMDK_PATH" 2>/dev/null || stat -c%s "$VMDK_PATH" 2>/dev/null || echo "0")"
    
    if [[ -n "$ASSET_SIZE" ]] && [[ "$EXISTING_SIZE" == "$ASSET_SIZE" ]]; then
        EXISTING_SIZE_MB="$(awk "BEGIN {printf \"%.2f\", $EXISTING_SIZE / 1048576}")"
        echo "==> Arquivo VMDK já existe e está completo"
        echo "    Arquivo: $VMDK_PATH"
        echo "    Tamanho: ${EXISTING_SIZE_MB} MB"
        echo "    Pulando download..."
        SKIP_DOWNLOAD="true"
    else
        EXPECTED_SIZE_MB="$(awk "BEGIN {printf \"%.2f\", ${ASSET_SIZE:-0} / 1048576}")"
        EXISTING_SIZE_MB="$(awk "BEGIN {printf \"%.2f\", $EXISTING_SIZE / 1048576}")"
        echo "==> Arquivo VMDK existe mas tamanho difere"
        echo "    Esperado: ${EXPECTED_SIZE_MB} MB, Encontrado: ${EXISTING_SIZE_MB} MB"
        echo "    Removendo arquivo antigo e baixando novamente..."
        rm -f "$VMDK_PATH"
    fi
fi

if [[ "$SKIP_DOWNLOAD" != "true" ]]; then
    echo "==> Baixando asset: ${ASSET_NAME}"
    curl -fL "$ASSET_URL" -o "$VMDK_PATH"
    [[ -f "$VMDK_PATH" ]] || die "Download falhou: ${VMDK_PATH}"
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
    
    # Se PreserveUserData ativo, desanexar disco de dados antes de remover VM
    if [[ "$PRESERVE_USER_DATA" == "true" ]] && [[ "$USER_DATA_VDI_EXISTS" == "true" ]]; then
        echo "    Desanexando disco de dados antes de remover VM..."
        VBoxManage storageattach "$VM_NAME" --storagectl "SATA" --port 1 --device 0 --medium none 2>/dev/null || true
    fi
    
    echo "==> Removendo VM antiga: ${VM_NAME}"
    VBoxManage unregistervm "$VM_NAME" --delete || true
fi

echo "==> Criando VM '${VM_NAME}'"
VBoxManage createvm --name "$VM_NAME" --ostype Debian_64 --register

echo "==> Driver de áudio selecionado: ${AUDIO_DRIVER}"

# Configuração base: VM textual, áudio AC97 para acessibilidade, NAT com SSH forwarding
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

VBoxManage storagectl "$VM_NAME" --name "SATA" --add sata --controller IntelAhci

echo "==> Anexando disco de sistema (VMDK)"
VBoxManage storageattach "$VM_NAME" \
    --storagectl "SATA" --port 0 --device 0 \
    --type hdd --medium "$VMDK_PATH"

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

echo "==> Iniciando VM em modo headless"
VBoxManage startvm "$VM_NAME" --type headless

cat << EOF

✔ VM criada e iniciada com sucesso.

Release: ${OWNER}/${REPO} (${RESOLVED_TAG})
VM:      ${VM_NAME}
SSH:     ssh -p ${SSH_HOST_PORT} a11ydevs@localhost

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

cat << EOF

Credenciais padrão esperadas (release atual):
  usuário: a11ydevs
  senha:   a11ydevs

EOF

if [[ "$USER_DATA_VDI_EXISTS" == "true" ]]; then
    cat << EOF
Para mais informações sobre customização e upgrades, veja:
  https://github.com/${OWNER}/${REPO}/blob/main/docs/architecture.md

EOF
fi
