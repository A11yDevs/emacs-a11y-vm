#!/bin/bash
# Script para montar automaticamente VirtualBox Shared Folders
# Executado pelo systemd no boot se Guest Additions estiver instalado.
#
# Para cada shared folder configurada no VirtualBox (VBoxControl sharedfolder list),
# monta em /home/<nome-da-share> com uid/gid do usuario a11ydevs.
# Isso permite que a pasta pessoal do Windows apareça em /home/<usuario-windows>.

set -uo pipefail

USER_UID=1000
USER_GID=1000

echo "=== mount-shared-folder.sh iniciado ==="
echo "Data: $(date)"

# --- Verificações de pré-requisito -------------------------------------------

# Guest Additions disponível?
if ! modinfo vboxsf &>/dev/null; then
    echo "AVISO: módulo vboxsf não encontrado (Guest Additions não instalado?)"
    exit 0
fi
echo "OK: módulo vboxsf disponível"

# Carregar módulo vboxsf se necessário
if ! lsmod | grep -q vboxsf; then
    echo "Carregando módulo vboxsf..."
    modprobe vboxsf 2>/dev/null || {
        echo "AVISO: falha ao carregar módulo vboxsf"
        exit 0
    }
fi
echo "OK: módulo vboxsf carregado"

# VBoxControl acessível?
if ! command -v VBoxControl &>/dev/null; then
    echo "AVISO: VBoxControl não encontrado no PATH"
    exit 0
fi
echo "OK: VBoxControl encontrado em $(command -v VBoxControl)"

# --- Descobrir shares configuradas -------------------------------------------
# Formato da saída de VBoxControl sharedfolder list (VirtualBox 6+):
#   No.  Name        Host Path        Access  AutoMount  AutoMountPoint
#   ---  ----        ---------        ------  ---------  --------------
#     1  joao        C:\Users\joao    rw      y          /home/joao
#
# Extrai a coluna "Name" (campo 2, linhas de dados após o cabeçalho).
# Usa método robusto: pula linhas que começam com "No." ou "---" ou são vazias.

mapfile -t SHARE_NAMES < <(
    VBoxControl sharedfolder list 2>/dev/null \
        | awk '$1 ~ /^[0-9]+$/ && NF>=2 { print $2 }'
)

# Debug: mostrar o que foi encontrado
echo "VBoxControl encontrou ${#SHARE_NAMES[@]} share(s)"
for share_name in "${SHARE_NAMES[@]}"; do
    echo "  - $share_name"
done

if [[ ${#SHARE_NAMES[@]} -eq 0 ]]; then
    # Nenhuma shared folder configurada — sair silenciosamente
    exit 0
fi

# --- Montar cada share -------------------------------------------------------

mounted=0
failed=0

for share_name in "${SHARE_NAMES[@]}"; do
    [[ -z "$share_name" ]] && continue

    mount_point="/home/$share_name"

    # Criar ponto de montagem se não existe
    if [[ ! -d "$mount_point" ]]; then
        mkdir -p "$mount_point"
        chown "$USER_UID:$USER_GID" "$mount_point"
    fi

    # Pular se já montado
    if mountpoint -q "$mount_point"; then
        echo "Shared folder '$share_name' ja montado em $mount_point"
        continue
    fi

    # Montar
    if mount -t vboxsf -o "uid=$USER_UID,gid=$USER_GID" "$share_name" "$mount_point"; then
        echo "Shared folder '$share_name' montado em $mount_point"
        (( mounted++ )) || true
    else
        echo "AVISO: Nao foi possivel montar '$share_name' em $mount_point"
        (( failed++ )) || true
    fi
done

echo "Resultado: $mounted share(s) montada(s), $failed falha(s)"
