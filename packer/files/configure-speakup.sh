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

# Mapear valores de espeak para speakup
# espeakup default_rate: 80-450, padrão 120
# speakup rate: 0-9, padrão 5
# Fórmula aproximada: speakup_rate = (espeak_rate - 80) / 40
if [[ -n "${default_rate:-}" ]]; then
    # Converter rate de espeak (80-450) para speakup (0-9)
    # 120 -> 5 (padrão)
    # 160 -> 7
    # 200 -> 9
    speakup_rate=$(( (default_rate - 80) / 40 ))
    # Limitar entre 0-9
    speakup_rate=$(( speakup_rate < 0 ? 0 : (speakup_rate > 9 ? 9 : speakup_rate) ))
    echo "$speakup_rate" > "$SPEAKUP_DIR/rate" 2>/dev/null || true
    echo "Configurado speakup rate: $speakup_rate (baseado em default_rate=$default_rate)"
fi

# espeakup default_pitch: 0-99, padrão 50
# speakup pitch: 0-9, padrão 5
# Fórmula: speakup_pitch = espeak_pitch / 10
if [[ -n "${default_pitch:-}" ]]; then
    speakup_pitch=$(( default_pitch / 10 ))
    speakup_pitch=$(( speakup_pitch < 0 ? 0 : (speakup_pitch > 9 ? 9 : speakup_pitch) ))
    echo "$speakup_pitch" > "$SPEAKUP_DIR/pitch" 2>/dev/null || true
    echo "Configurado speakup pitch: $speakup_pitch (baseado em default_pitch=$default_pitch)"
fi

# espeakup default_volume: 0-200, padrão 100
# speakup vol: 0-9, padrão 5
# Fórmula: speakup_vol = espeak_volume / 20
if [[ -n "${default_volume:-}" ]]; then
    speakup_vol=$(( default_volume / 20 ))
    speakup_vol=$(( speakup_vol < 0 ? 0 : (speakup_vol > 9 ? 9 : speakup_vol) ))
    echo "$speakup_vol" > "$SPEAKUP_DIR/vol" 2>/dev/null || true
    echo "Configurado speakup volume: $speakup_vol (baseado em default_volume=$default_volume)"
fi

echo "Configuração do speakup aplicada com sucesso"
exit 0
