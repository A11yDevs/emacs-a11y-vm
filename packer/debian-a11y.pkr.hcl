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
  default     = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.4.0-amd64-netinst.iso"
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

variable "accelerator" {
  type        = string
  description = "Acelerador do QEMU. Use kvm no Linux/CI e hvf no macOS."
  default     = "kvm"
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
  default = "2.0.33"
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
  accelerator = var.accelerator

  # Placa de rede virtio para melhor desempenho
  net_device = "virtio-net"

  # Modo headless (sem janela gráfica — necessário no CI)
  headless = true

  # display = "none" removido: causa crash do QEMU/HVF quando o GRUB tenta
  # ativar gfxterm (modo gráfico). Com headless=true o Packer gerencia o VNC.

  # --- Servidor HTTP do Packer (serve o preseed.cfg) --------------------
  http_directory = "${path.root}/http"
  http_port_min  = 8100
  http_port_max  = 8199

  # --- Sequência de boot ------------------------------------------------
  # O instalador Debian 13 netinst usa ISOLINUX (SYSLINUX) para boot via BIOS
  # (QEMU usa SeaBIOS por padrão). A abordagem é idêntica ao Debian 12:
  #
  # 1) aguardar o ISOLINUX aparecer (boot_wait + <wait5>)
  # 2) pressionar ESC para abrir o prompt "boot:"
  # 3) digitar o label "auto" com parâmetros extras e pressionar Enter
  #
  # O label "auto" no isolinux.cfg já inclui auto=true priority=critical;
  # os parâmetros adicionais são concatenados ao final da linha de kernel.
  # Todos os parâmetros (incluindo net.ifnames=0 biosdevname=0) ficam
  # visíveis em /proc/cmdline e são processados pelo kernel e pelo d-i.
  boot_wait = "5s"
  boot_command = [
    "<wait5>",
    "<esc><wait2>",
    "auto priority=critical url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg net.ifnames=0 biosdevname=0 hostname=${var.vm_name} domain=local<enter>"
  ]

  # --- SSH (Packer usa para verificar que a instalação terminou) --------
  communicator = "ssh"
  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_port     = 22
  # Tempo generoso: download de pacotes + instalação completa
  ssh_timeout  = "120m"

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

    # Forçar nome de interface de rede estável (eth0)
    provisioner "shell" {
      inline = [
        "echo '=== Forçando nome de interface de rede para eth0 e mantendo speakup ==='",
        "sudo sed -i 's/^GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX=\"console=tty0 speakup.synth=soft net.ifnames=0 biosdevname=0\"/' /etc/default/grub",
        "sudo update-grub"
      ]
    }

  # Aplicar dotfiles ao usuário a11ydevs (diretamente durante build)
  provisioner "shell" {
    inline = [
      "echo '=== Aplicando dotfiles ao usuário a11ydevs ==='",
      "sudo cp -f /etc/skel/emacs-a11y/bashrc /home/a11ydevs/.bashrc",
      "sudo cp -f /etc/skel/emacs-a11y/profile /home/a11ydevs/.profile",
      "sudo cp -f /etc/skel/emacs-a11y/inputrc /home/a11ydevs/.inputrc",
      "sudo cp -rf /etc/skel/emacs-a11y/emacs.d /home/a11ydevs/.emacs.d",
      "sudo chown -R a11ydevs:a11ydevs /home/a11ydevs/.bashrc /home/a11ydevs/.profile /home/a11ydevs/.inputrc /home/a11ydevs/.emacs.d",
      "echo 'Dotfiles aplicados ao usuário a11ydevs'"
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

  # Instalar override de timeout do espeakup
  provisioner "file" {
    source      = "${path.root}/files/espeakup-timeout.conf"
    destination = "/tmp/espeakup-timeout.conf"
  }

  # Instalar script de recuperação de emergência da síntese de voz
  provisioner "file" {
    source      = "${path.root}/files/restart-speech.sh"
    destination = "/tmp/restart-speech.sh"
  }

  # Instalar configuração de resiliência do espeakup
  provisioner "file" {
    source      = "${path.root}/files/espeakup-resilience.conf"
    destination = "/tmp/espeakup-resilience.conf"
  }

  # Instalar sudoers para comandos de acessibilidade
  provisioner "file" {
    source      = "${path.root}/files/a11y-speech-sudoers"
    destination = "/tmp/a11y-speech-sudoers"
  }

  # Instalar script de informações da release
  provisioner "file" {
    source      = "${path.root}/files/emacs-a11y-version"
    destination = "/tmp/emacs-a11y-version"
  }

  # Instalar script de configuração do speakup
  provisioner "file" {
    source      = "${path.root}/files/configure-speakup.sh"
    destination = "/tmp/configure-speakup.sh"
  }

  # Instalar service de configuração do speakup
  provisioner "file" {
    source      = "${path.root}/files/configure-speakup.service"
    destination = "/tmp/configure-speakup.service"
  }

  # Instalar configuração de rede
  provisioner "file" {
    source      = "${path.root}/files/interfaces"
    destination = "/tmp/interfaces"
  }

  # Instalar mensagem de boas-vindas (motd)
  provisioner "file" {
    source      = "${path.root}/files/motd"
    destination = "/tmp/motd"
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
      "echo '=== Configurando disco de dados persistente ==='",
      "sudo mv /tmp/setup-userdata-disk.sh /usr/local/sbin/",
      "sudo chmod +x /usr/local/sbin/setup-userdata-disk.sh",
      "sudo mv /tmp/emacs-a11y-userdata.service /etc/systemd/system/",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable emacs-a11y-userdata.service",
      "echo 'Setup de disco de dados configurado'",
      "echo '=== Configurando voz pt-br no espeakup ==='",
      "sudo mv /tmp/espeakup.conf /etc/default/espeakup",
      "sudo chmod 644 /etc/default/espeakup",
      "sudo mkdir -p /etc/systemd/system/espeakup.service.d",
      "sudo mv /tmp/espeakup-timeout.conf /etc/systemd/system/espeakup.service.d/timeout.conf",
      "sudo chmod 644 /etc/systemd/system/espeakup.service.d/timeout.conf",
      "sudo systemctl daemon-reload",
      "sudo systemctl restart espeakup || echo 'Aviso: espeakup não está rodando (normal durante build)'",
      "echo 'Voz pt-br e timeout configurados'",
      "echo '=== Configurando recuperação de emergência da síntese de voz ==='",
      "sudo mv /tmp/restart-speech.sh /usr/local/bin/restart-speech",
      "sudo chmod 755 /usr/local/bin/restart-speech",
      "sudo mv /tmp/espeakup-resilience.conf /etc/systemd/system/espeakup.service.d/resilience.conf",
      "sudo chmod 644 /etc/systemd/system/espeakup.service.d/resilience.conf",
      "sudo mv /tmp/a11y-speech-sudoers /etc/sudoers.d/a11y-speech",
      "sudo chown root:root /etc/sudoers.d/a11y-speech",
      "sudo chmod 440 /etc/sudoers.d/a11y-speech",
      "sudo systemctl daemon-reload",
      "echo 'Recuperação de emergência configurada (F12 + falar + auto-restart)'",
      "echo '=== Configurando script de ajuste do speakup ==='",
      "sudo mv /tmp/configure-speakup.sh /usr/local/sbin/",
      "sudo chmod +x /usr/local/sbin/configure-speakup.sh",
      "sudo mv /tmp/configure-speakup.service /etc/systemd/system/",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable configure-speakup.service",
      "echo 'Script de configuração do speakup instalado'",
      "echo '=== Configurando rede (DHCP em eth0) ==='",
      "sudo mv /tmp/interfaces /etc/network/interfaces",
      "sudo chmod 644 /etc/network/interfaces",
      "echo 'Configuração de rede instalada'",
      "echo '=== Configurando mensagem de boas-vindas ==='",
      "sed 's/@@VERSION@@/${var.version}/' /tmp/motd | sudo tee /etc/motd",
      "sudo chmod 644 /etc/motd",
      "# Remover scripts update-motd.d (causam mensagens verbosas)",
      "if [[ -d /etc/update-motd.d ]]; then",
      "  sudo rm -f /etc/update-motd.d/* 2>/dev/null || true",
      "  echo 'Scripts de update-motd.d removidos'",
      "fi",
      "# Remover /run/motd.dynamic se existir",
      "sudo rm -f /run/motd.dynamic",
      "# Desabilitar pam_motd.so para evitar duplicação (bashrc já exibe)",
      "sudo sed -i 's/^\\(.*pam_motd\\.so.*\\)$/# \\1/' /etc/pam.d/login",
      "echo 'pam_motd.so desabilitado em /etc/pam.d/login'",
      "echo 'Mensagem de boas-vindas configurada (apenas /etc/motd via bashrc)'",
      "# Limpar /etc/issue (exibido ANTES do login - contém uname -a)",
      "echo 'Debian A11y Devs' | sudo tee /etc/issue > /dev/null",
      "echo 'Debian A11y Devs' | sudo tee /etc/issue.net > /dev/null",
      "sudo chmod 644 /etc/issue /etc/issue.net",
      "echo '/etc/issue e /etc/issue.net simplificados'"
    ]
  }

  # Instalar VirtualBox Guest Additions durante o build
  provisioner "shell" {
    inline = [
      "echo '=== Instalando dependências para Guest Additions ==='",
      "sudo apt-get update",
      "sudo apt-get install -y build-essential linux-headers-$(uname -r) dkms curl alsa-utils cifs-utils",
      "echo 'Dependências instaladas: build-essential, linux-headers, dkms, curl, alsa-utils, cifs-utils'"
    ]
  }

  # Copiar script de instalação do Guest Additions
  provisioner "file" {
    source      = "packer/files/install-guest-additions-build.sh"
    destination = "/tmp/install-guest-additions-build.sh"
  }

  # Executar instalação do Guest Additions
  provisioner "shell" {
    inline = [
      "echo '=== Instalando VirtualBox Guest Additions ==='",
      "sudo bash /tmp/install-guest-additions-build.sh",
      "sudo rm /tmp/install-guest-additions-build.sh"
    ]
  }

  # Configurar montagem automática de shared folders
  provisioner "file" {
    source      = "packer/files/mount-shared-folder.sh"
    destination = "/tmp/mount-shared-folder.sh"
  }

  provisioner "file" {
    source      = "packer/files/mount-shared-folder.service"
    destination = "/tmp/mount-shared-folder.service"
  }

  provisioner "shell" {
    inline = [
      "echo '=== Configurando montagem automática de shared folders ==='",
      "sudo mv /tmp/mount-shared-folder.sh /usr/local/bin/",
      "sudo chmod +x /usr/local/bin/mount-shared-folder.sh",
      "sudo mv /tmp/mount-shared-folder.service /etc/systemd/system/",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable mount-shared-folder.service",
      "echo 'Adicionar usuário a11ydevs ao grupo vboxsf'",
      "sudo usermod -aG vboxsf a11ydevs || echo 'Grupo vboxsf não existe ainda (será criado no boot)'",
      "echo 'Configuração de shared folders concluída'"
    ]
  }

  # Configurar repositórios A11yDevs e instalar pacotes
  provisioner "shell" {
    inline = [
      "echo '=== Configurando repositórios A11yDevs ==='",
      "echo 'Baixando keyring GPG do emacspeak...'",
      "sudo curl -fsSL https://a11ydevs.github.io/emacspeak-a11ydevs/debian/emacspeak-archive-keyring.gpg -o /usr/share/keyrings/emacspeak-archive-keyring.gpg",
      "echo 'Configurando repositório emacspeak...'",
      "echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/emacspeak-archive-keyring.gpg] https://a11ydevs.github.io/emacspeak-a11ydevs/debian stable main' | sudo tee /etc/apt/sources.list.d/emacspeak.list",
      "echo 'Baixando keyring GPG do emacs-a11y...'",
      "sudo curl -fsSL https://a11ydevs.github.io/emacs-a11y/debian/a11y-emacs-archive-keyring.gpg -o /usr/share/keyrings/emacs-a11y-archive-keyring.gpg",
      "echo 'Configurando repositório emacs-a11y...'",
      "echo 'deb [arch=all signed-by=/usr/share/keyrings/emacs-a11y-archive-keyring.gpg] https://a11ydevs.github.io/emacs-a11y/debian stable main' | sudo tee /etc/apt/sources.list.d/emacs-a11y.list",
      "echo 'Atualizando lista de pacotes...'",
      "sudo apt-get update",
      "echo 'Instalando pacotes A11yDevs (incluindo emacspeak)...'",
      "sudo apt-get install -y emacspeak emacs-a11y-config emacs-a11y-launchers",
      "echo 'Aplicando compatibilidade Emacs 30 no site-start do emacspeak...'",
      "sudo sed -i '1s/^/(defvar flavor (quote emacs))\\n/' /etc/emacs/site-start.d/50emacspeak.el 2>/dev/null || true",
      "echo 'Repositórios e pacotes A11yDevs configurados com sucesso'"
    ]
  }

  # Verificação mínima pós-instalação
  provisioner "shell" {
    inline = [
      "echo '=== Verificando instalação ==='",
      "uname -a",
      "systemctl is-enabled espeakup && echo 'espeakup: OK' || echo 'espeakup: AVISO — serviço não encontrado'",
      "systemctl is-enabled emacs-a11y-userdata && echo 'userdata setup: OK' || echo 'userdata setup: AVISO'",
      "systemctl is-enabled mount-shared-folder && echo 'mount-shared-folder: OK' || echo 'mount-shared-folder: AVISO'",
      "command -v emacs  && emacs --version | head -1 || echo 'emacs: AVISO — não encontrado'",
      "command -v ssh    && ssh -V || echo 'ssh: AVISO — não encontrado'",
      "test -f /sbin/mount.vboxsf && echo 'VBox Guest Additions: OK' || echo 'VBox Guest Additions: AVISO'",
      "grep -q 'speakup.synth=soft' /etc/default/grub && echo 'GRUB speakup: OK' || echo 'GRUB speakup: AVISO'",
      "test -x /usr/local/sbin/setup-userdata-disk.sh && echo 'setup-userdata-disk.sh: OK' || echo 'setup-userdata-disk.sh: AVISO'",
      "grep -q '^allow-hotplug eth0$' /etc/network/interfaces && grep -q '^iface eth0 inet dhcp$' /etc/network/interfaces && echo 'Network config: OK' || echo 'Network config: AVISO'",
      "test -f /etc/motd && echo 'MOTD: OK' || echo 'MOTD: AVISO'",
      "dpkg -l | grep -q '^ii  emacspeak ' && echo 'emacspeak: OK' || echo 'emacspeak: AVISO — pacote não instalado'",
      "dpkg -l | grep -q emacs-a11y-config && echo 'emacs-a11y-config: OK' || echo 'emacs-a11y-config: AVISO'",
      "dpkg -l | grep -q emacs-a11y-launchers && echo 'emacs-a11y-launchers: OK' || echo 'emacs-a11y-launchers: AVISO'",
      "test -f /etc/apt/sources.list.d/emacspeak.list && echo 'Repositório emacspeak: OK' || echo 'Repositório emacspeak: AVISO'",
      "test -f /etc/apt/sources.list.d/emacs-a11y.list && echo 'Repositório emacs-a11y: OK' || echo 'Repositório emacs-a11y: AVISO'",
      "command -v aplay >/dev/null 2>&1 && echo 'alsa-utils/aplay: OK' || echo 'alsa-utils/aplay: AVISO — não encontrado'"
    ]
  }
}
