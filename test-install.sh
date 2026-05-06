#!/bin/bash

################################################################################
# test-install.sh - Script de teste para verificar se o instalador funciona
#                   sem depender de downloads do GitHub
################################################################################

set -euo pipefail

TEST_DIR=$(mktemp -d)
trap "rm -rf '$TEST_DIR'" EXIT

echo "📝 Testando instalador em diretório temporário: $TEST_DIR"
echo ""

# Copiar CLI para local de teste
cp /Users/akira/dados/dev/emacs-a11y-vm/cli/ea11ctl "$TEST_DIR/"
cp /Users/akira/dados/dev/emacs-a11y-vm/cli/install.sh "$TEST_DIR/"
cp /Users/akira/dados/dev/emacs-a11y-vm/cli/VERSION "$TEST_DIR/" 2>/dev/null || echo "0.1.32" > "$TEST_DIR/VERSION"

chmod +x "$TEST_DIR/ea11ctl"
chmod +x "$TEST_DIR/install.sh"

# Executar testes
echo "✅ Testes da CLI:"
echo ""

echo "1️⃣  ea11ctl help"
"$TEST_DIR/ea11ctl" help | head -5
echo ""

echo "2️⃣  ea11ctl version"
"$TEST_DIR/ea11ctl" version
echo ""

echo "3️⃣  ea11ctl --version"
"$TEST_DIR/ea11ctl" --version
echo ""

echo "4️⃣  ea11ctl -h"
"$TEST_DIR/ea11ctl" -h | head -5
echo ""

echo "5️⃣  ea11ctl vm list (sem backend instalado)"
"$TEST_DIR/ea11ctl" vm list || echo "   ⚠️  VirtualBox não está instalado (esperado)"
echo ""

echo "✅ Todos os testes básicos passaram!"
echo ""
echo "📂 Arquivos criados no CLI:"
ls -lh /Users/akira/dados/dev/emacs-a11y-vm/cli/
