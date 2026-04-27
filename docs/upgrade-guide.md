# Guia de Upgrade da VM emacs-a11y

Este guia explica como atualizar sua VM emacs-a11y para uma versão mais recente, preservando suas configurações e dados.

## Visão Geral

A arquitetura de dois discos permite upgrades **sem perda de dados**:

- **Disco de Sistema (VMDK)**: Substituído pela nova versão
- **Disco de Dados (VDI)**: Preservado automaticamente

Suas configurações do Emacs, dotfiles, projetos e arquivos pessoais são mantidos intactos.

---

## Pré-requisitos

✅ Sua VM atual usa arquitetura de dois discos (versões recentes já usam)  
✅ Você tem disco de dados VDI em `releases/debian-a11y-userdata.vdi`  
✅ Conexão à internet para baixar nova release

### Verificar se Você Tem Disco de Dados

**No host (fora da VM):**

```bash
# Verificar se VDI existe
ls -lh releases/debian-a11y-userdata.vdi
```

**Dentro da VM:**

```bash
# Verificar se /home está em disco separado
df -h /home
# Deve mostrar /dev/sdb montado em /home

# Verificar flag de inicialização
ls -la /home/.emacs-a11y-userdata-initialized
```

Se você **não** tem disco de dados separado, veja: [Migrando VM Antiga](#migrando-vm-antiga)

---

## Processo de Upgrade

### Passo 1: Backup (Recomendado)

Mesmo com disco de dados separado, é prudente fazer backup:

```bash
# No host, fazer backup do disco de dados
VBoxManage clonemedium disk \
  releases/debian-a11y-userdata.vdi \
  backups/debian-a11y-userdata-$(date +%Y%m%d).vdi
```

**Opcional**: Backup via SSH antes de desligar VM:

```bash
# Do host, conectar à VM e exportar configurações
ssh -p 2222 a11ydevs@localhost "tar czf - .emacs.d .bashrc .profile" \
  > backup-configs-$(date +%Y%m%d).tar.gz
```

### Passo 2: Verificar Nova Release Disponível

Visite: https://github.com/A11yDevs/emacs-a11y-vm/releases

Ou via API:

```bash
curl -s https://api.github.com/repos/A11yDevs/emacs-a11y-vm/releases/latest \
  | grep '"tag_name"' | cut -d'"' -f4
```

### Passo 3: Desligar VM Atual

**Dentro da VM:**

```bash
sudo shutdown -h now
```

**Ou do host:**

```bash
VBoxManage controlvm debian-a11y poweroff
```

⏱️ Aguarde a VM desligar completamente antes de prosseguir.

### Passo 4: Executar Script de Instalação

O script **detecta automaticamente** o disco de dados existente e o preserva.

#### Windows (PowerShell)

```powershell
# Baixar e instalar última release (preservando dados)
.\scripts\install-release-vm.ps1

# Ou tag específica
.\scripts\install-release-vm.ps1 -Tag v2.0.0
```

#### Linux/macOS (Bash)

```bash
# Baixar e instalar última release (preservando dados)
./scripts/install-release-vm.sh

# Ou tag específica
./scripts/install-release-vm.sh --tag v2.0.0
```

### Passo 5: Verificar Upgrade

Após a VM iniciar automaticamente:

#### Conectar via SSH

```bash
ssh -p 2222 a11ydevs@localhost
```

#### Verificações

```bash
# 1. Confirmar versão do sistema
cat /etc/debian_version
uname -a

# 2. Verificar disco de dados ainda montado
df -h /home
# Deve mostrar /dev/sdb

# 3. Confirmar que suas configurações estão preservadas
ls -la ~/.emacs.d/init.el
cat ~/.bashrc | head -10

# 4. Testar Emacs
emacs --version
emacs -nw  # Abrir Emacs e verificar configuração
```

### Passo 6: Testar Funcionalidades

```bash
# Síntese de voz
systemctl status espeakup

# SSH
ssh -V

# Emacs packages (se você instalou algum)
emacs -nw --batch --eval "(package-list-packages)"

# Projetos (se você tem)
ls -la ~/projetos
```

---

## Processo Detalhado (O Que Acontece)

### 1. Script Detecta Disco de Dados

```
==> Disco de dados detectado, preservação automática habilitada
    releases/debian-a11y-userdata.vdi
```

### 2. VM Antiga é Removida (Mas VDI Preservado)

```
==> Verificando VM existente: debian-a11y
    Desanexando disco de dados antes de remover VM...
    VM existente encontrada, removendo...
    VM antiga removida com sucesso
```

### 3. Nova VM é Criada

```
==> Criando VM 'debian-a11y'
==> Anexando disco de sistema (VMDK)
    Disco de sistema anexado na porta SATA 0
```

### 4. Disco de Dados é Reanexado

```
==> Configurando disco de dados do usuário
    Disco de dados existente encontrado: 1234.56 MB
    Reutilizando: releases/debian-a11y-userdata.vdi
    Disco de dados anexado na porta SATA 1
```

### 5. VM Inicia com Dados Preservados

```
✔ VM criada e iniciada com sucesso.

Arquitetura de Discos:
  Sistema (SATA 0): releases/debian-a11ydevs.vmdk
  Dados (SATA 1):   releases/debian-a11y-userdata.vdi

O disco de dados será montado automaticamente em /home
no primeiro boot. Suas configurações do Emacs e arquivos
pessoais serão preservados em upgrades futuros.
```

---

## Troubleshooting

### Disco de Dados Não Foi Montado

**Sintoma**: `/home` vazio após upgrade

**Diagnóstico**:

```bash
# Verificar se disco existe
sudo fdisk -l /dev/sdb

# Verificar se está montado
df -h /home
```

**Solução**:

```bash
# Montar manualmente
sudo mount /dev/sdb /home

# Verificar logs do serviço
sudo journalctl -u emacs-a11y-userdata.service

# Se necessário, executar setup manualmente
sudo /usr/local/sbin/setup-userdata-disk.sh
```

### Erro "VM já existe"

**Sintoma**: 

```
Erro: VM 'debian-a11y' já existe e -KeepOldVM foi usado
```

**Solução**:

```bash
# Remover VM manualmente
VBoxManage unregistervm debian-a11y --delete

# Executar script novamente
./scripts/install-release-vm.sh
```

### Configurações do Emacs Parecem Resetadas

**Sintoma**: Emacs não carrega sua configuração customizada

**Diagnóstico**:

```bash
# Verificar se init.el existe
ls -la ~/.emacs.d/init.el

# Verificar dono do arquivo
ls -l ~/.emacs.d/
```

**Solução**:

```bash
# Ajustar permissões se necessário
sudo chown -R a11ydevs:a11ydevs ~/.emacs.d

# Verificar conteúdo do init.el
cat ~/.emacs.d/init.el
```

### Download Falha ou Interrompido

**Solução**:

```bash
# Forçar re-download
./scripts/install-release-vm.sh --force-download
```

### Quero Voltar para Versão Anterior (Rollback)

**Solução**:

1. Desligar VM atual:
   ```bash
   VBoxManage controlvm debian-a11y poweroff
   ```

2. Remover VM (mas preservar VDI de dados):
   ```bash
   VBoxManage unregistervm debian-a11y --delete
   ```

3. Baixar versão anterior:
   ```bash
   ./scripts/install-release-vm.sh --tag v1.0.0
   ```

O disco de dados será automaticamente reanexado com suas configurações intactas.

---

## Migrando VM Antiga

Se você tem uma VM antiga **sem** disco de dados separado:

### Opção 1: Backup e Restauração Manual

1. **Backup via SSH**:
   ```bash
   ssh -p 2222 a11ydevs@localhost "tar czf - /home" > backup-home.tar.gz
   ```

2. **Criar nova VM** com disco de dados:
   ```bash
   ./scripts/install-release-vm.sh
   ```

3. **Restaurar backup**:
   ```bash
   cat backup-home.tar.gz | ssh -p 2222 a11ydevs@localhost "tar xzf - -C /"
   ```

### Opção 2: Script de Migração (Futuro)

Planejado para versões futuras:

```bash
./scripts/migrate-old-vm.sh --vm-name debian-a11y
```

Este script automatizará:
- Detectar VM sem disco de dados
- Extrair `/home` da VM antiga
- Criar novo disco de dados VDI
- Recriar VM com arquitetura de dois discos
- Restaurar `/home` no novo disco

---

## Atualizações de Pacotes do Sistema

### Diferença Entre Upgrade de Release vs apt upgrade

| Tipo | O Que Atualiza | Preserva Dados? |
|------|---------------|-----------------|
| **Release upgrade** (recomendado) | Sistema base completo (Debian + Emacs + espeakup) | ✅ Sim (disco de dados) |
| **apt upgrade** | Apenas pacotes dentro da VM existente | N/A (não substitui VM) |

### Quando Usar apt upgrade

```bash
# Atualizar pacotes dentro da VM atual (entre releases)
sudo apt update
sudo apt upgrade -y
```

**Use para**:
- Correções de segurança urgentes
- Entre releases oficiais do projeto
- Pacotes que você instalou manualmente

**Limitações**:
- Não atualiza sistema base (Debian, Emacs, espeakup)
- Customizações são perdidas no próximo release upgrade

---

## Frequência de Upgrades

### Quando Atualizar?

✅ **Nova release disponível** - Check GitHub releases  
✅ **Correções de bugs importantes** - Ver changelog  
✅ **Novas features de acessibilidade** - Anúncios  
✅ **Atualizações de segurança** - Security advisories  

❌ **Não é necessário** atualizar toda semana se a versão atual funciona bem.

### Notificações de Novas Releases

Opção 1: Watch no GitHub (requer conta)
- Ir para https://github.com/A11yDevs/emacs-a11y-vm
- Clicar "Watch" → "Custom" → "Releases"

Opção 2: RSS Feed
- https://github.com/A11yDevs/emacs-a11y-vm/releases.atom

Opção 3: Script de verificação

```bash
#!/bin/bash
# check-updates.sh
LATEST=$(curl -s https://api.github.com/repos/A11yDevs/emacs-a11y-vm/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
CURRENT="v1.0.0"  # Ajuste para sua versão

if [ "$LATEST" != "$CURRENT" ]; then
    echo "Nova versão disponível: $LATEST (atual: $CURRENT)"
    echo "Execute: ./scripts/install-release-vm.sh --tag $LATEST"
else
    echo "Você está usando a versão mais recente: $CURRENT"
fi
```

---

## Checklist de Upgrade

Antes de atualizar:

- [ ] Verificar se nova release está disponível
- [ ] Ler changelog da nova versão
- [ ] Fazer backup do disco de dados (opcional mas recomendado)
- [ ] Exportar configurações importantes via SSH (opcional)
- [ ] Anotar versão atual (para rollback se necessário)

Durante o upgrade:

- [ ] Desligar VM completamente
- [ ] Executar script de instalação
- [ ] Aguardar download e criação da VM
- [ ] Verificar que disco de dados foi detectado e preservado

Após o upgrade:

- [ ] Conectar via SSH
- [ ] Verificar disco de dados montado em `/home`
- [ ] Confirmar configurações do Emacs preservadas
- [ ] Testar síntese de voz (espeakup)
- [ ] Verificar projetos e arquivos pessoais
- [ ] Testar funcionalidades que você mais usa

---

## Recursos

- [Arquitetura da VM](architecture.md) - Entender sistema de dois discos
- [Guia de Customização](customization-guide.md) - Personalização segura
- [README Principal](../README.md) - Visão geral do projeto
- [GitHub Releases](https://github.com/A11yDevs/emacs-a11y-vm/releases) - Baixar releases

---

## Perguntas Frequentes

### Quanto tempo leva um upgrade?

- **Download**: 5-15 minutos (depende da conexão, ~2-3 GB)
- **Criação da VM**: 1-2 minutos
- **Total**: ~10-20 minutos

### Posso usar a VM durante o upgrade?

**Não**. Desligue a VM antes de executar o script de upgrade.

### Meus projetos de Git serão preservados?

**Sim**. Tudo em `/home` (incluindo `~/projetos`) é preservado.

### E se eu tiver instalado pacotes com apt?

Pacotes instalados com `apt` **não** são preservados. Anote os pacotes e reinstale após upgrade:

```bash
# Antes do upgrade
dpkg --get-selections > ~/installed-packages.txt

# Após o upgrade
sudo apt install $(grep -v deinstall ~/installed-packages.txt | awk '{print $1}')
```

### Posso fazer downgrade?

**Sim**. Execute o script com a tag da versão anterior:

```bash
./scripts/install-release-vm.sh --tag v1.0.0
```

Seu disco de dados será preservado normalmente.

### O upgrade afeta a configuração de rede (SSH)?

**Não**. A configuração de rede (NAT + port forwarding SSH) é recriada automaticamente.

### Preciso reconfigurar alguma coisa após upgrade?

**Não**. Tudo em `/home` é preservado, incluindo configurações do Emacs, dotfiles, SSH keys, Git config, etc.
