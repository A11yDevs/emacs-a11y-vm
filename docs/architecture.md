# Arquitetura da VM emacs-a11y

Este documento explica a arquitetura de discos da VM emacs-a11y e como ela suporta customização do usuário preservando a proposta de acessibilidade.

## Visão Geral

A VM utiliza uma **arquitetura de dois discos** para separar o sistema base (imutável) dos dados do usuário (persistentes):

```
┌─────────────────────────────────────────────────────────┐
│                     VM emacs-a11y                       │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Disco 1 (Sistema)          Disco 2 (Dados)           │
│  ┌──────────────────┐       ┌──────────────────┐      │
│  │  VMDK (SATA 0)   │       │  VDI (SATA 1)    │      │
│  │                  │       │                  │      │
│  │  • Debian base   │       │  • /home         │      │
│  │  • Emacs         │       │  • Configurações │      │
│  │  • espeakup      │       │  • .emacs.d      │      │
│  │  • Ferramentas   │       │  • Projetos      │      │
│  │                  │       │  • Dados         │      │
│  │  (Imutável)      │       │  (Persistente)   │      │
│  └──────────────────┘       └──────────────────┘      │
│         ↓                          ↓                   │
│   Substituído em              Preservado em            │
│      upgrades                    upgrades              │
└─────────────────────────────────────────────────────────┘
```

## Disco 1: Sistema (VDI)

### Características

- **Formato**: VDI (VirtualBox Disk Image)
- **Origem**: GitHub Releases (QCOW2) → convertido localmente para VDI
- **Tamanho**: ~8-10 GB (QCOW2 compactado ~1.5-2 GB)
- **Montagem**: `/` (raiz do sistema)
- **Conteúdo**:
  - Sistema Debian base (minimal)
  - Emacs e dependências
  - espeakup (síntese de voz)
  - openssh-server
  - sudo e ferramentas essenciais

> **Por que VDI?** Formato nativo do VirtualBox, gravável, sem child media automáticos. O CI distribui QCOW2 (< 2GB, passa limite do GitHub), o instalador converte para VDI no host do usuário (~5-10min).

### Ciclo de Vida

1. **Criação**: Gerado via Packer/QEMU no CI (GitHub Actions)
2. **Distribuição**: Publicado como asset em GitHub Releases
3. **Instalação**: Baixado e anexado pelos scripts `install-release-vm.*`
4. **Upgrade**: **Substituído completamente** por nova versão da release

⚠️ **Importante**: Nunca modifique arquivos neste disco fora de `/home`. Customizações serão perdidas em upgrades.

## Disco 2: Dados do Usuário (VDI)

### Características

- **Formato**: VDI (VirtualBox Disk Image)
- **Origem**: Criado localmente no host
- **Tamanho**: 10 GB (padrão, customizável via `--user-data-size`)
- **Tipo**: Growable (só aloca espaço conforme uso)
- **Montagem**: `/home` (completo)
- **Conteúdo**:
  - Diretórios home de todos os usuários
  - Configurações do Emacs (`.emacs.d/`)
  - Dotfiles (`.bashrc`, `.profile`, etc.)
  - Projetos e arquivos pessoais
  - Packages instalados pelo usuário

### Ciclo de Vida

1. **Criação**: Primeira vez que você executa `install-release-vm.*`
2. **Formatação**: ext4 com label `USERDATA`
3. **Migração**: Conteúdo inicial de `/home` copiado para o novo disco
4. **Montagem**: Via `/etc/fstab` (automático no boot)
5. **Upgrade**: **Preservado automaticamente** — nunca substituído

✅ **Seguro**: Customize livremente qualquer coisa em `/home`. Será preservado em upgrades.

## Primeiro Boot

No primeiro boot da VM, um serviço systemd (`emacs-a11y-userdata.service`) executa automaticamente:

1. **Detecta** o segundo disco (`/dev/sdb`)
2. **Formata** como ext4 se necessário
3. **Migra** conteúdo existente de `/home`
4. **Adiciona** entrada em `/etc/fstab`
5. **Monta** disco em `/home`
6. **Instala** dotfiles recomendados (se instalação nova)
7. **Cria** flag `.emacs-a11y-userdata-initialized`

Este processo é **idempotente**: executa apenas uma vez, mesmo se você reiniciar a VM.

### Dotfiles Recomendados

Em instalações novas, o sistema copia automaticamente configurações recomendadas:

- `.emacs.d/init.el` - Configuração base do Emacs (acessível)
- `.emacs.d/README.md` - Documentação da estrutura
- `.bashrc` - Aliases e prompt acessível
- `.profile` - Variáveis de ambiente

**Importante**: Em upgrades, suas configurações existentes são **sempre preservadas** — nunca sobrescritas.

## Fluxo de Upgrade

### Quando você executa `install-release-vm.*` em uma VM existente:

```
1. Script detecta disco de dados existente
   ↓
2. Desanexa disco de dados da VM antiga (sem deletar)
   ↓
3. Remove VM antiga (mas preserva VDI de dados)
   ↓
4. Cria nova VM
   ↓
5. Anexa novo VMDK (sistema atualizado)
   ↓
6. Anexa VDI de dados existente
   ↓
7. Inicia VM
   ↓
8. Disco de dados já montado em /home
   ↓
9. ✅ Suas configurações estão preservadas
```

## Benefícios da Arquitetura

### Para Usuários

✅ **Liberdade de customização** - Modifique Emacs, dotfiles, instale packages  
✅ **Upgrades seguros** - Atualize sistema base sem perder dados  
✅ **Rollback trivial** - Troque VMDK por versão anterior se necessário  
✅ **Backup simples** - Copie apenas o VDI de dados  

### Para Mantenedores

✅ **Controle da base** - Sistema imutável garante acessibilidade  
✅ **Reprodutibilidade** - Todos usuários têm mesmo sistema base  
✅ **Distribuição eficiente** - Releases são apenas o VMDK  
✅ **Testes confiáveis** - Base conhecida facilita suporte  

## Armazenamento

### Localização dos Discos

Por padrão, os discos são salvos em:

```
releases/
├── debian-a11ydevs.vmdk          # Disco de sistema (da release)
└── debian-a11y-userdata.vdi      # Disco de dados (local)
```

### Tamanhos Típicos

| Disco | Tamanho Alocado | Uso Real | Tipo |
|-------|-----------------|----------|------|
| Sistema (VMDK) | ~8-10 GB | ~8-10 GB | Fixo |
| Dados (VDI) | 10 GB (padrão) | ~1-3 GB inicial | Growable |

**Nota**: O disco de dados só ocupa o espaço realmente utilizado, expandindo conforme necessário até o limite configurado.

## Customizando o Tamanho do Disco de Dados

### PowerShell (Windows)

```powershell
.\scripts\install-release-vm.ps1 -UserDataSize 20480  # 20 GB
```

### Bash (Linux/macOS)

```bash
./scripts/install-release-vm.sh --user-data-size 20480  # 20 GB
```

## Desabilitando Disco de Dados

Se preferir não usar disco separado (não recomendado):

### PowerShell

```powershell
# Forçar instalação limpa sem preservar dados
.\scripts\install-release-vm.ps1 -PreserveUserData:$false
```

### Bash

```bash
# Forçar instalação limpa sem preservar dados
./scripts/install-release-vm.sh --no-preserve-user-data
```

⚠️ **Atenção**: Sem disco de dados separado, upgrades apagarão suas customizações!

## Verificação

### Verificar Discos Montados

Dentro da VM:

```bash
# Listar discos
lsblk

# Verificar montagem de /home
df -h /home

# Ver entrada no fstab
grep USERDATA /etc/fstab

# Verificar flag de setup concluído
ls -la /home/.emacs-a11y-userdata-initialized
```

### Saída Esperada

```
$ lsblk
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda      8:0    0   16G  0 disk 
└─sda1   8:1    0   16G  0 part /
sdb      8:16   0   10G  0 disk /home

$ df -h /home
Filesystem      Size  Used Avail Use% Mounted on
/dev/sdb        9.8G  1.2G  8.1G  13% /home
```

## Backup e Restauração

### Backup do Disco de Dados

```bash
# No host (fora da VM)
VBoxManage clonemedium disk \
  releases/debian-a11y-userdata.vdi \
  backups/debian-a11y-userdata-$(date +%Y%m%d).vdi
```

### Restauração

```bash
# Substituir disco de dados atual
cp backups/debian-a11y-userdata-20260427.vdi \
   releases/debian-a11y-userdata.vdi

# Recriar VM com disco restaurado
./scripts/install-release-vm.sh
```

## Troubleshooting

### Disco de dados não foi montado

```bash
# Verificar se disco existe
sudo fdisk -l /dev/sdb

# Montar manualmente
sudo mount /dev/sdb /home

# Verificar logs do setup
sudo journalctl -u emacs-a11y-userdata.service
```

### Perdi meus dados após upgrade

Se você não tinha disco de dados separado e perdeu configurações:

1. **Não** execute novamente o script
2. Desligue a VM
3. Anexe o VMDK antigo temporariamente em outra VM
4. Copie `/home` para backup
5. Recrie a VM com disco de dados separado
6. Copie backup de volta para `/home`

### Quero migrar VM antiga para modelo de dois discos

Use o script auxiliar (quando disponível):

```bash
./scripts/migrate-old-vm.sh --vm-name debian-a11y
```

Ou manualmente:

1. Faça backup de `/home` via SSH
2. Delete VM antiga
3. Recrie com `install-release-vm.*`
4. Restaure backup de `/home` via SSH

## Recursos Relacionados

- [Guia de Customização](customization-guide.md) - Como personalizar com segurança
- [Guia de Upgrade](upgrade-guide.md) - Processo de atualização passo a passo
- [README Principal](../README.md) - Visão geral do projeto

## Decisões de Design

### Por que dois discos em vez de snapshots?

Snapshots do VirtualBox funcionam, mas:
- Acumulam rapidamente (espaço em disco)
- Degradam performance com o tempo
- Difíceis de gerenciar manualmente
- Não separam "sistema" de "dados" conceitualmente

Discos separados são mais simples, previsíveis e eficientes.

### Por que VDI em vez de VMDK para dados?

- VDI é nativo do VirtualBox (melhor suporte)
- Suporta snapshots nativamente (feature futura)
- Formato growable mais eficiente

### Por que QCOW2 → VDI em vez de distribuir VDI diretamente?

**Problema**: GitHub Releases limita assets a 2GB. VMDK gravável (monolithicSparse) e VDI excedem esse limite quando descompactados.

**Solução**: Distribuir QCOW2 compactado (~1.5-2 GB) e converter localmente para VDI.

**Trade-offs**:
- ✅ QCOW2 passa limite de 2GB do GitHub
- ✅ QCOW2 é universal (QEMU/KVM/libvirt)
- ✅ VDI nativo do VirtualBox, sem child media
- ⚠️ Conversão adiciona ~5-10min na primeira instalação (ocorre apenas quando versão muda)

### Por que montar em /home inteiro?

Alternativas consideradas:
- Montar apenas `.emacs.d` → Muito granular
- Montar `/home/a11ydevs` → Não suporta múltiplos usuários
- Montar `/mnt/userdata` + symlinks → Complexo e error-prone

Montar `/home` completo é simples, previsível e segue convenções Unix.
