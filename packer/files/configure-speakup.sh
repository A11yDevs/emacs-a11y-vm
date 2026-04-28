#!/bin/bash
# Script para configurar parâmetros do speakup em tempo de boot
# Os parâmetros default_rate, default_pitch, default_volume do espeakup
# não são aplicados diretamente. Precisamos configurar via sysfs.

set -euo pipefail

SPEAKUP_DIR="/sys/accessibility/speakup/soft"
CONFIG_FILE="/etc/default/espeakup"

# Verificar se speakup está carregado
if [[ ! -d "$SPEAKUP_DIR" ]]; then
    echo "Aviso: Speakup não disponível em $SPEAKUP_DIR"
    exit 0
fi

# Verificar se arquivo de configuração existe
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Aviso: Arquivo de configuração $CONFIG_FILE não encontrado"
    exit 0
fi

# Ler configurações do arquivo
source "$CONFIG_FILE" 2>/dev/null || true

# Aplicar valores diretamente (já no formato speakup: 0-9)
# Os valores em /etc/default/espeakup agora são diretos (0-9)
# sem necessidade de conversão

if [[ -n "${default_rate:-}" ]]; then
    # Limitar entre 0-9
    speakup_rate=$(( default_rate < 0 ? 0 : (default_rate > 9 ? 9 : default_rate) ))
    echo "$speakup_rate" > "$SPEAKUP_DIR/rate" 2>/dev/null || true
    echo "Configurado speakup rate: $speakup_rate"
fi

if [[ -n "${default_pitch:-}" ]]; then
    speakup_pitch=$(( default_pitch < 0 ? 0 : (default_pitch > 9 ? 9 : default_pitch) ))
    echo "$speakup_pitch" > "$SPEAKUP_DIR/pitch" 2>/dev/null || true
    echo "Configurado speakup pitch: $speakup_pitch"
fi

if [[ -n "${default_volume:-}" ]]; then
    speakup_vol=$(( default_volume < 0 ? 0 : (default_volume > 9 ? 9 : default_volume) ))
    echo "$speakup_vol" > "$SPEAKUP_DIR/vol" 2>/dev/null || true
    echo "Configurado speakup vol: $speakup_vol"
fi

echo "Configuração do speakup aplicada com sucesso"
exit 0
