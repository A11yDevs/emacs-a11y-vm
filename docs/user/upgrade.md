# Atualizando a VM emacs-a11y

O sistema da VM pode ser atualizado sem perder suas configurações e arquivos. Seus dados em `/home` (configurações do Emacs, projetos, dotfiles) são preservados automaticamente.

---

## Pré-requisitos

Verifique se sua VM usa a arquitetura de dois discos. Dentro da VM:

```bash
df -h /home
# Deve mostrar /dev/sdb (ou similar) montado em /home
```

Se `/home` não aparece em disco separado, entre em contato com o suporte do projeto antes de prosseguir.

---

## Processo de upgrade

Use o mesmo comando `vm` da CLI, escolhendo o backend com `-b` (ou `--backend`).

### 1. Backup recomendado

Mesmo com disco de dados separado, é prudente guardar um backup:

```bash
# Do host, via SSH
ssh -p 2222 a11ydevs@localhost "tar czf - .emacs.d .bashrc .profile" \
  > backup-$(date +%Y%m%d).tar.gz
```

### 2. Desligar a VM

Dentro da VM:

```bash
sudo shutdown -h now
```

Ou pelo host, usando a CLI:

```powershell
# VirtualBox
ea11ctl vm stop -b virtualbox

# QEMU
ea11ctl vm stop -b qemu
```

### 3. Atualizar conforme o backend

#### VirtualBox (`-b virtualbox`)

O script detecta automaticamente o disco de dados e o preserva.

```powershell
# Windows — instala a última release
PowerShell -ExecutionPolicy Bypass -File .\scripts\install-release-vm.ps1

# Ou uma versão específica
PowerShell -ExecutionPolicy Bypass -File .\scripts\install-release-vm.ps1 -Tag v2.0.0
```

#### QEMU (`-b qemu`)

No backend QEMU, a imagem de sistema fica em `~/.emacs-a11y-vm/debian-a11ydevs.qcow2`.
O disco de dados (`~/.emacs-a11y-vm/<vm>-home.qcow2`) permanece intacto e continua sendo montado em `/home`.

Passos recomendados:

```bash
# 1) Garantir VM parada
ea11ctl vm stop -b qemu

# 2) Substituir a imagem de sistema pela versão nova
cp /caminho/para/debian-a11ydevs.qcow2 ~/.emacs-a11y-vm/debian-a11ydevs.qcow2

# 3) Iniciar novamente
ea11ctl vm start -b qemu
```

### 4. Verificar após o upgrade (todos os backends)

Conecte via SSH e confira:

```bash
ssh -p 2222 a11ydevs@localhost

# Versão do sistema
cat /etc/debian_version

# Disco de dados ainda montado
df -h /home

# Suas configurações preservadas
ls -la ~/.emacs.d/init.el
```

Se estiver usando QEMU, você também pode validar no host:

```bash
ea11ctl vm status -b qemu
```

---

## O que é preservado

- Configurações do Emacs (`~/.emacs.d/`)
- Dotfiles (`.bashrc`, `.profile`, `.inputrc`)
- Projetos e arquivos em `/home`
- Pacotes instalados pelo usuário

## O que é substituído

- Sistema Debian base
- Emacs e dependências do sistema
- espeakup e demais pacotes do sistema

---

## Verificar a versão atual

Dentro da VM:

```bash
cat /etc/emacs-a11y-version
```
