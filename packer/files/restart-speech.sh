#!/bin/bash
# restart-speech.sh - Reinicia espeakup e speakup (emergência acessibilidade)
# Instalado em: /usr/local/bin/restart-speech
#
# Este script fornece recuperação rápida quando a síntese de voz falha.
# Usuários cegos perdem todo acesso ao sistema sem áudio funcional.

set -e

echo "==> Reiniciando síntese de voz espeakup..."

# Parar espeakup
echo "    Parando serviço espeakup..."
sudo systemctl stop espeakup.service

# Recarregar módulo speakup_soft (limpa estado interno)
echo "    Recarregando módulo speakup_soft..."
sudo modprobe -r speakup_soft 2>/dev/null || true
sleep 1
sudo modprobe speakup_soft

# Reiniciar espeakup
echo "    Reiniciando serviço espeakup..."
sudo systemctl start espeakup.service

# Aguardar estabilização
sleep 2

# Verificar status
if systemctl is-active --quiet espeakup.service; then
    echo "✓ Espeakup reiniciado com sucesso!"
    echo "A síntese de voz está funcionando novamente."
    
    # Beep sonoro se disponível (feedback auditivo adicional)
    command -v beep >/dev/null 2>&1 && beep -f 1000 -l 100 2>/dev/null || true
    exit 0
else
    echo "✗ ERRO: Falha ao reiniciar espeakup"
    echo "Tente manualmente: sudo systemctl restart espeakup"
    exit 1
fi
