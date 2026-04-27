#!/usr/bin/env bash
# ==============================================================================
# setup-userdata-disk.sh — Configura disco de dados persistente para /home
#
# Este script é executado automaticamente no primeiro boot da VM via systemd.
# Detecta o segundo disco (/dev/sdb), formata se necessário, e monta em /home.
#
# Fluxo:
#   1. Verifica se /dev/sdb existe (segundo disco VDI)
#   2. Formata como ext4 se não formatado
#   3. Move conteúdo atual de /home para o novo disco
#   4. Adiciona entrada em /etc/fstab
#   5. Monta disco em /home
#   6. Cria flag indicando conclusão
#
# Este script deve ser executado como root.
# ==============================================================================
set -euo pipefail

DEVICE="/dev/sdb"
MOUNT_POINT="/home"
LABEL="USERDATA"
FLAG_FILE="/home/.emacs-a11y-userdata-initialized"
TEMP_MOUNT="/mnt/userdata-setup"

log() {
    echo "[setup-userdata-disk] $*"
}

error() {
    log "ERRO: $*" >&2
    exit 1
}

# Verificar se está executando como root
if [[ $EUID -ne 0 ]]; then
    error "Este script deve ser executado como root"
fi

# Verificar se flag já existe (setup já foi concluído)
if [[ -f "$FLAG_FILE" ]]; then
    log "Setup já foi concluído anteriormente (flag existe: $FLAG_FILE)"
    log "Nada a fazer."
    exit 0
fi

# Verificar se segundo disco existe
if [[ ! -b "$DEVICE" ]]; then
    log "Segundo disco ($DEVICE) não encontrado"
    log "VM provavelmente não tem disco de dados separado"
    log "Pulando configuração de disco de dados"
    exit 0
fi

log "Segundo disco detectado: $DEVICE"

# Verificar se o disco já está formatado
if blkid "$DEVICE" >/dev/null 2>&1; then
    EXISTING_FSTYPE="$(blkid -o value -s TYPE "$DEVICE" || echo "unknown")"
    log "Disco já formatado como: $EXISTING_FSTYPE"
else
    log "Disco não formatado, formatando como ext4..."
    
    # Formatar disco como ext4 com label
    if ! mkfs.ext4 -L "$LABEL" "$DEVICE"; then
        error "Falha ao formatar disco $DEVICE"
    fi
    
    log "Disco formatado com sucesso (ext4, label: $LABEL)"
fi

# Criar ponto de montagem temporário
log "Criando ponto de montagem temporário: $TEMP_MOUNT"
mkdir -p "$TEMP_MOUNT"

# Montar disco temporariamente
log "Montando $DEVICE em $TEMP_MOUNT"
if ! mount "$DEVICE" "$TEMP_MOUNT"; then
    error "Falha ao montar disco temporariamente"
fi

# Verificar se /home tem conteúdo para migrar
if [[ -n "$(ls -A "$MOUNT_POINT" 2>/dev/null || true)" ]]; then
    log "Migrando conteúdo existente de $MOUNT_POINT para o novo disco..."
    
    # Copiar preservando permissões, timestamps, etc
    if ! cp -ax "$MOUNT_POINT"/. "$TEMP_MOUNT/"; then
        umount "$TEMP_MOUNT"
        error "Falha ao copiar dados de $MOUNT_POINT"
    fi
    
    log "Conteúdo migrado com sucesso"
else
    log "Diretório $MOUNT_POINT está vazio, nada para migrar"
fi

# Desmontar disco temporário
log "Desmontando disco temporário"
umount "$TEMP_MOUNT"
rmdir "$TEMP_MOUNT"

# Adicionar entrada no fstab se não existir
FSTAB_ENTRY="LABEL=$LABEL $MOUNT_POINT ext4 defaults 0 2"

if grep -q "LABEL=$LABEL" /etc/fstab 2>/dev/null; then
    log "Entrada já existe em /etc/fstab"
else
    log "Adicionando entrada em /etc/fstab"
    echo "$FSTAB_ENTRY" >> /etc/fstab
    log "Entrada adicionada: $FSTAB_ENTRY"
fi

# Limpar conteúdo antigo de /home antes de montar
# (necessário para que o mount point esteja vazio)
if [[ -n "$(ls -A "$MOUNT_POINT" 2>/dev/null || true)" ]]; then
    log "Limpando conteúdo antigo de $MOUNT_POINT (já copiado para o disco de dados)"
    rm -rf "${MOUNT_POINT:?}"/*
fi

# Montar disco em /home
log "Montando $DEVICE em $MOUNT_POINT via fstab"
if ! mount "$MOUNT_POINT"; then
    error "Falha ao montar disco em $MOUNT_POINT"
fi

# Verificar se montagem foi bem-sucedida
if ! mountpoint -q "$MOUNT_POINT"; then
    error "Disco não está montado em $MOUNT_POINT após mount"
fi

# Criar flag de conclusão
log "Criando flag de conclusão"
touch "$FLAG_FILE"
chmod 644 "$FLAG_FILE"

# Verificar se usuário padrão existe e ajustar permissões
if id "a11ydevs" >/dev/null 2>&1; then
    HOME_DIR="/home/a11ydevs"
    if [[ -d "$HOME_DIR" ]]; then
        log "Ajustando permissões de $HOME_DIR"
        chown -R a11ydevs:a11ydevs "$HOME_DIR"
        
        # Instalar dotfiles recomendados se for instalação nova
        if [[ ! -f "$HOME_DIR/.emacs.d/init.el" ]] && [[ -d /etc/skel/emacs-a11y ]]; then
            log "Instalação nova detectada, copiando dotfiles recomendados"
            
            # Copiar configuração do Emacs
            if [[ -d /etc/skel/emacs-a11y/emacs.d ]] && [[ ! -d "$HOME_DIR/.emacs.d" ]]; then
                cp -r /etc/skel/emacs-a11y/emacs.d "$HOME_DIR/.emacs.d"
                chown -R a11ydevs:a11ydevs "$HOME_DIR/.emacs.d"
                log "Configuração do Emacs instalada"
            fi
            
            # Copiar bashrc se não existir
            if [[ -f /etc/skel/emacs-a11y/bashrc ]] && [[ ! -f "$HOME_DIR/.bashrc" ]]; then
                cp /etc/skel/emacs-a11y/bashrc "$HOME_DIR/.bashrc"
                chown a11ydevs:a11ydevs "$HOME_DIR/.bashrc"
                log "Configuração do bash instalada"
            fi
            
            # Copiar profile se não existir
            if [[ -f /etc/skel/emacs-a11y/profile ]] && [[ ! -f "$HOME_DIR/.profile" ]]; then
                cp /etc/skel/emacs-a11y/profile "$HOME_DIR/.profile"
                chown a11ydevs:a11ydevs "$HOME_DIR/.profile"
                log "Configuração de profile instalada"
            fi
        else
            log "Dotfiles já existem ou não disponíveis, preservando configurações existentes"
        fi
    fi
fi

log "Setup concluído com sucesso!"
log "Disco de dados montado em $MOUNT_POINT"
log "$(df -h "$MOUNT_POINT" | tail -n1)"

exit 0
