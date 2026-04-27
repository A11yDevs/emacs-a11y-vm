# ==============================================================================
# debian-a11y.pkr.hcl — Build da VM Debian acessível via QEMU
#
# Uso local (requer QEMU + KVM):
#   packer init packer/debian-a11y.pkr.hcl
#   packer build \
#     -var "iso_url=file:///caminho/para/debian-netinst.iso" \
#     -var "iso_checksum=none" \
#     packer/debian-a11y.pkr.hcl
#
# No CI (GitHub Actions), as variáveis são passadas pelo workflow.
# ==============================================================================

packer {
  required_plugins {
    qemu = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

# ------------------------------------------------------------------------------
# Variáveis
# ------------------------------------------------------------------------------

variable "iso_url" {
  type        = string
  description = "URL ou caminho local (file://) da ISO netinst do Debian."
  default     = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.11.0-amd64-netinst.iso"
}

variable "iso_checksum" {
  type        = string
  description = "Checksum da ISO (ex: sha256:abc123…). Use 'none' para desabilitar."
  default     = "none"
}

variable "output_dir" {
  type        = string
  description = "Diretório de saída para a imagem gerada."
  default     = "output"
}

variable "vm_name" {
  type    = string
  default = "debian-a11ydevs"
}

variable "disk_size" {
  type    = string
  default = "16G"
}

variable "memory" {
  type    = number
  default = 2048
}

variable "cpus" {
  type    = number
  default = 2
}

variable "ssh_username" {
  type    = string
  default = "a11ydevs"
}

variable "ssh_password" {
  type      = string
  default   = "a11ydevs"
  sensitive = true
}

variable "version" {
  type    = string
  default = "2.0.1"
}

# ------------------------------------------------------------------------------
# Source: QEMU builder
# ------------------------------------------------------------------------------

source "qemu" "debian-a11y" {
  # --- ISO ---------------------------------------------------------------
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  # --- Saída -------------------------------------------------------------
  vm_name          = "${var.vm_name}.qcow2"
  output_directory = var.output_dir
  format           = "qcow2"

  # --- Hardware ----------------------------------------------------------
  cpus        = var.cpus
  memory      = var.memory
  disk_size   = var.disk_size
  accelerator = "kvm"        # KVM disponível nos runners ubuntu-latest

  # Placa de rede virtio para melhor desempenho
  net_device = "virtio-net"

  # Modo headless (sem janela gráfica — necessário no CI)
  headless = true

  # VGA mínimo; a VM é puramente textual
  display = "none"

  # --- Servidor HTTP do Packer (serve o preseed.cfg) --------------------
  http_directory = "${path.root}/http"
  http_port_min  = 8100
  http_port_max  = 8199

  # --- Sequência de boot ------------------------------------------------
  # O instalador Debian netinst usa ISOLINUX (BIOS).
  # ESC → prompt "boot:" → comando de instalação automática com preseed via HTTP.
  boot_wait = "12s"
  boot_command = [
    "<esc><wait2>",
    "auto priority=critical ",
    "url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg ",
    "hostname=${var.vm_name} domain=local ",
    "speakup.synth=soft ",
    "<enter>"
  ]

  # --- SSH (Packer usa para verificar que a instalação terminou) --------
  communicator = "ssh"
  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_port     = 22
  # Tempo generoso: download de pacotes + instalação completa
  ssh_timeout  = "90m"

  # Desligar a VM ao fim do build
  shutdown_command = "echo '${var.ssh_password}' | sudo -S shutdown -P now"
}

# ------------------------------------------------------------------------------
# Build
# ------------------------------------------------------------------------------

build {
  name    = "debian-a11y"
  sources = ["source.qemu.debian-a11y"]

  # Criar diretório para dotfiles
  provisioner "shell" {
    inline = ["mkdir -p /tmp/emacs-a11y-skel"]
  }

  # Copiar dotfiles recomendados
  provisioner "file" {
    source      = "${path.root}/skel/"
    destination = "/tmp/emacs-a11y-skel"
  }

  # Instalar dotfiles em /etc/skel/emacs-a11y/
  provisioner "shell" {
    inline = [
      "echo '=== Instalando dotfiles recomendados ==='",
      "sudo mkdir -p /etc/skel/emacs-a11y",
      "sudo cp -r /tmp/emacs-a11y-skel/. /etc/skel/emacs-a11y/",
      "sudo chmod -R 755 /etc/skel/emacs-a11y",
      "echo 'Dotfiles instalados em /etc/skel/emacs-a11y/'"
    ]
  }

  # Instalar script de setup de disco de dados
  provisioner "file" {
    source      = "${path.root}/scripts/setup-userdata-disk.sh"
    destination = "/tmp/setup-userdata-disk.sh"
  }

  # Instalar systemd service para disco de dados
  provisioner "file" {
    source      = "${path.root}/files/emacs-a11y-userdata.service"
    destination = "/tmp/emacs-a11y-userdata.service"
  }

  # Instalar configuração do espeakup (voz pt-br)
  provisioner "file" {
    source      = "${path.root}/files/espeakup.conf"
    destination = "/tmp/espeakup.conf"
  }

  # Instalar script de informações da release
  provisioner "file" {
    source      = "${path.root}/files/emacs-a11y-version"
    destination = "/tmp/emacs-a11y-version"
  }

  # Criar arquivo de versão da release
  provisioner "shell" {
    inline = [
      "echo '=== Criando arquivo de versão da release ==='",
      "echo 'EMACS_A11Y_VERSION=${var.version}' | sudo tee /etc/emacs-a11y-release",
      "echo 'BUILD_DATE='$(date -u +%Y-%m-%dT%H:%M:%SZ) | sudo tee -a /etc/emacs-a11y-release",
      "sudo chmod 644 /etc/emacs-a11y-release",
      "cat /etc/emacs-a11y-release",
      "echo '=== Instalando script de informações da release ==='",
      "sudo mv /tmp/emacs-a11y-version /usr/local/bin/emacs-a11y-version",
      "sudo chmod +x /usr/local/bin/emacs-a11y-version",
      "echo 'Script instalado em /usr/local/bin/emacs-a11y-version'"
    ]
  }

  # Configurar script e service
  provisioner "shell" {
    inline = [
      "echo '=== Configurando disco de dados persistente ===",
      "sudo mv /tmp/setup-userdata-disk.sh /usr/local/sbin/",
      "sudo chmod +x /usr/local/sbin/setup-userdata-disk.sh",
      "sudo mv /tmp/emacs-a11y-userdata.service /etc/systemd/system/",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable emacs-a11y-userdata.service",
      "echo 'Setup de disco de dados configurado'",
      "echo '=== Configurando voz pt-br no espeakup ===",
      "sudo mv /tmp/espeakup.conf /etc/default/espeakup",
      "sudo chmod 644 /etc/default/espeakup",
      "sudo systemctl restart espeakup || echo 'Aviso: espeakup não está rodando (normal durante build)'",
      "echo 'Voz pt-br configurada'"
    ]
  }

  # Verificação mínima pós-instalação
  provisioner "shell" {
    inline = [
      "echo '=== Verificando instalação ==='",
      "uname -a",
      "systemctl is-enabled espeakup && echo 'espeakup: OK' || echo 'espeakup: AVISO — serviço não encontrado'",
      "systemctl is-enabled emacs-a11y-userdata && echo 'userdata setup: OK' || echo 'userdata setup: AVISO'",
      "command -v emacs  && emacs --version | head -1 || echo 'emacs: AVISO — não encontrado'",
      "command -v ssh    && ssh -V || echo 'ssh: AVISO — não encontrado'",
      "grep -q 'speakup.synth=soft' /etc/default/grub && echo 'GRUB speakup: OK' || echo 'GRUB speakup: AVISO'",
      "test -x /usr/local/sbin/setup-userdata-disk.sh && echo 'setup-userdata-disk.sh: OK' || echo 'setup-userdata-disk.sh: AVISO'",
    ]
  }
}
