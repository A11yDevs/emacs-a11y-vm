#!/usr/bin/env bash
# ==============================================================================
# setup-vm.sh — Cria uma VM Debian 13 acessível no VirtualBox (sem GUI)
#
# Automatiza os passos descritos em debian-a11-minimal-vm.md:
#   - VM mínima, totalmente textual (sem desktop/X11)
#   - Áudio AC97 para síntese de voz
#   - espeakup (Speakup + eSpeak-NG) habilitado em todo boot
#   - openssh-server instalado
#   - Rede NAT com port-forwarding para SSH
#
# Uso:
#   1. cp .env.example .env   (e edite o .env)
#   2. ./setup-vm.sh
#
# Todas as variáveis são lidas do arquivo .env na mesma pasta do script.
# Veja .env.example para a lista completa de opções.
# ==============================================================================
set -euo pipefail

# --- Carregar .env ------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "Erro: arquivo .env não encontrado."
    echo "Copie o exemplo e configure:"
    echo "  cp .env.example .env"
    exit 1
fi

# Carrega variáveis do .env (ignora comentários e linhas vazias)
set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

# --- Configuração (valores do .env ou padrões) --------------------------------
VM_NAME="${VM_NAME:-debian-a11ydevs}"
ISO_PATH="${ISO_PATH:?Defina ISO_PATH no arquivo .env}"
# Expandir ~ no caminho da ISO
ISO_PATH="${ISO_PATH/#\~/$HOME}"
VM_RAM="${VM_RAM:-2048}"
VM_CPUS="${VM_CPUS:-2}"
VM_DISK_MB="${VM_DISK_MB:-16000}"
VM_USER="${VM_USER:-a11ydevs}"
VM_PASSWORD="${VM_PASSWORD:-123456}"
VM_FULLNAME="${VM_FULLNAME:-A11y Devs}"
VM_HOSTNAME="${VM_HOSTNAME:-debian-a11ydevs}"
VM_DOMAIN="${VM_DOMAIN:-local}"
VM_LOCALE="${VM_LOCALE:-pt_BR}"
VM_COUNTRY="${VM_COUNTRY:-BR}"
VM_TIMEZONE="${VM_TIMEZONE:-America/Sao_Paulo}"
VM_KEYBOARD="${VM_KEYBOARD:-br}"
SSH_HOST_PORT="${SSH_HOST_PORT:-2222}"
BRIDGE_ADAPTER="${BRIDGE_ADAPTER:-}"

# Derivar código de idioma do locale (pt_BR → pt)
VM_LANGUAGE="${VM_LOCALE%%_*}"

# --- Funções auxiliares -------------------------------------------------------
detect_bridge_adapter() {
    # Retorna o nome da primeira interface bridge disponível no VirtualBox
    VBoxManage list bridgedifs 2>/dev/null \
        | awk -F: '/^Name:/{gsub(/^ +| +$/, "", $2); print $2; exit}'
}

detect_audio_driver() {
    case "$(uname -s)" in
        Darwin)  echo "coreaudio" ;;
        Linux)
            if command -v pulseaudio &>/dev/null || \
               command -v pipewire   &>/dev/null; then
                echo "pulse"
            else
                echo "alsa"
            fi
            ;;
        MINGW*|MSYS*|CYGWIN*) echo "dsound" ;;
        *)                     echo "none"   ;;
    esac
}

die() { echo "Erro: $*" >&2; exit 1; }

# --- Validações ---------------------------------------------------------------
command -v VBoxManage &>/dev/null \
    || die "VBoxManage não encontrado. Instale o VirtualBox."

[[ -f "$ISO_PATH" ]] \
    || die "ISO não encontrado: $ISO_PATH"

VBoxManage showvminfo "$VM_NAME" &>/dev/null \
    && die "VM '$VM_NAME' já existe. Remova-a primeiro:
  VBoxManage unregistervm '$VM_NAME' --delete"

# --- Caminhos -----------------------------------------------------------------
VM_DIR="$HOME/VirtualBox VMs/$VM_NAME"
VM_DISK="$VM_DIR/$VM_NAME.vdi"
PRESEED="$VM_DIR/preseed-a11y.cfg"
AUDIO_DRIVER="$(detect_audio_driver)"

# Detectar adaptador bridge se não foi especificado
if [[ -z "$BRIDGE_ADAPTER" ]]; then
    BRIDGE_ADAPTER="$(detect_bridge_adapter)"
    [[ -n "$BRIDGE_ADAPTER" ]] \
        || die "Nenhuma interface bridge encontrada. Defina BRIDGE_ADAPTER no .env."
fi
echo "==> Interface bridge: $BRIDGE_ADAPTER"

# ==============================================================================
# 1. Criar e registrar a VM
# ==============================================================================
echo "==> Criando VM '$VM_NAME'..."
VBoxManage createvm --name "$VM_NAME" --ostype Debian_64 --register

# ==============================================================================
# 2. Configurar hardware
# ==============================================================================
echo "==> Configurando hardware (${VM_RAM} MB RAM, ${VM_CPUS} CPUs, áudio AC97)..."
VBoxManage modifyvm "$VM_NAME" \
    --memory "$VM_RAM" \
    --cpus "$VM_CPUS" \
    --ioapic on \
    --boot1 dvd --boot2 disk --boot3 none --boot4 none \
    --audio-driver "$AUDIO_DRIVER" \
    --audio-controller ac97 \
    --audio-enabled on \
    --audio-out on \
    --nic1 bridged \
    --bridge-adapter1 "$BRIDGE_ADAPTER" \
    --graphicscontroller vmsvga \
    --vram 16

# ==============================================================================
# 3. Criar disco virtual
# ==============================================================================
echo "==> Criando disco virtual (${VM_DISK_MB} MB)..."
mkdir -p "$VM_DIR"
VBoxManage createmedium disk \
    --filename "$VM_DISK" \
    --size "$VM_DISK_MB" \
    --format VDI

# ==============================================================================
# 4. Controladora SATA — disco + DVD
# ==============================================================================
VBoxManage storagectl "$VM_NAME" \
    --name "SATA" --add sata --controller IntelAhci

VBoxManage storageattach "$VM_NAME" \
    --storagectl "SATA" --port 0 --device 0 \
    --type hdd --medium "$VM_DISK"

VBoxManage storageattach "$VM_NAME" \
    --storagectl "SATA" --port 1 --device 0 \
    --type dvddrive --medium "$ISO_PATH"

# ==============================================================================
# 5. Gerar preseed customizado para instalação acessível
# ==============================================================================
echo "==> Gerando preseed acessível..."

cat > "$PRESEED" << 'PRESEED_EOF'
# ============================================================================
# Preseed para instalação acessível Debian — gerado por setup-vm.sh
# Instala sistema mínimo (sem GUI) com espeakup + openssh-server
# ============================================================================

# --- Localização -------------------------------------------------------------
d-i debian-installer/locale string @@VBOX_INSERT_LOCALE@@
d-i keyboard-configuration/xkb-keymap select @@VBOX_INSERT_KEYBOARD_LAYOUT@@
d-i keyboard-configuration/layoutcode string @@VBOX_INSERT_KEYBOARD_LAYOUT@@
d-i console-setup/ask_detect boolean false

# --- Rede ---------------------------------------------------------------------
d-i netcfg/choose_interface select auto
d-i netcfg/hostname string @@VBOX_INSERT_HOSTNAME_WITHOUT_DOMAIN@@
d-i netcfg/get_domain string @@VBOX_INSERT_HOSTNAME_DOMAIN@@

# --- Mirror -------------------------------------------------------------------
d-i mirror/country string manual
d-i mirror/http/hostname string deb.debian.org
d-i mirror/http/directory string /debian
d-i mirror/http/proxy string

# --- Contas -------------------------------------------------------------------
d-i passwd/root-login boolean true
d-i passwd/root-password password @@VBOX_INSERT_USER_PASSWORD@@
d-i passwd/root-password-again password @@VBOX_INSERT_USER_PASSWORD@@
d-i passwd/user-fullname string @@VBOX_INSERT_USER_FULL_NAME@@
d-i passwd/username string @@VBOX_INSERT_USER_LOGIN@@
d-i passwd/user-password password @@VBOX_INSERT_USER_PASSWORD@@
d-i passwd/user-password-again password @@VBOX_INSERT_USER_PASSWORD@@

# --- Relógio ------------------------------------------------------------------
d-i clock-setup/utc boolean true
d-i time/zone string @@VBOX_INSERT_TIME_ZONE_UX@@

# --- Particionamento — disco inteiro, partição única --------------------------
d-i partman-auto/method string regular
d-i partman-auto/choose_recipe select atomic
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true

# --- Seleção de pacotes — APENAS sistema padrão (SEM desktop/GUI) -------------
tasksel tasksel/first multiselect standard, ssh-server
d-i pkgsel/include string espeakup sudo emacs
d-i pkgsel/upgrade select full-upgrade

# --- GRUB ---------------------------------------------------------------------
d-i grub-installer/only_debian boolean true
d-i grub-installer/bootdev string default

# --- Pós-instalação: Speakup no GRUB + sudo + habilitar espeakup -------------
d-i preseed/late_command string \
    in-target sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=""/' /etc/default/grub; \
    in-target sed -i 's/^GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX="speakup.synth=soft"/' /etc/default/grub; \
    in-target sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' /etc/default/grub; \
    in-target update-grub; \
    in-target systemctl enable espeakup; \
    in-target usermod -aG sudo @@VBOX_INSERT_USER_LOGIN@@

# --- Finalizar ----------------------------------------------------------------
d-i finish-install/reboot_in_progress note
PRESEED_EOF

# Substituir token de teclado que o VBoxManage não suporta nativamente
sed -i.bak "s/@@VBOX_INSERT_KEYBOARD_LAYOUT@@/${VM_KEYBOARD}/g" "$PRESEED"
rm -f "$PRESEED.bak"

# ==============================================================================
# 6. Instalação desassistida com preseed
# ==============================================================================
echo "==> Configurando instalação desassistida..."
VBoxManage unattended install "$VM_NAME" \
    --iso="$ISO_PATH" \
    --user="$VM_USER" \
    --password="$VM_PASSWORD" \
    --full-user-name="$VM_FULLNAME" \
    --hostname="${VM_HOSTNAME}.${VM_DOMAIN}" \
    --locale="$VM_LOCALE" \
    --country="$VM_COUNTRY" \
    --time-zone="$VM_TIMEZONE" \
    --script-template="$PRESEED" \
    --extra-install-kernel-parameters="file=/cdrom/preseed.cfg auto=true priority=critical keyboard-configuration/xkb-keymap=${VM_KEYBOARD} console-setup/ask_detect=false speakup.synth=soft"

# ==============================================================================
# 7. Iniciar a VM
# ==============================================================================
echo "==> Iniciando VM em modo headless..."
VBoxManage startvm "$VM_NAME" --type headless

cat << EOF

 ✔ VM '$VM_NAME' criada — instalação desassistida em andamento.
   Aguarde alguns minutos até que a instalação termine e a VM reinicie.

   Acompanhar estado:
     VBoxManage showvminfo "$VM_NAME" | grep -i state

   Acessar via SSH (após instalação — descubra o IP com 'ip a' no console):
     ssh ${VM_USER}@<IP_DA_VM>

   Ver console (opcional):
     VBoxManage startvm "$VM_NAME" --type gui

   Desligar a VM:
     VBoxManage controlvm "$VM_NAME" acpipowerbutton

   Remover a VM completamente:
     VBoxManage unregistervm "$VM_NAME" --delete

EOF
