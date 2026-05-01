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

### 3. Executar o script de instalação

O script detecta automaticamente o disco de dados e o preserva.

```powershell
# Windows — instala a última release
PowerShell -ExecutionPolicy Bypass -File .\scripts\install-release-vm.ps1

# Ou uma versão específica
PowerShell -ExecutionPolicy Bypass -File .\scripts\install-release-vm.ps1 -Tag v2.0.0
```

### 4. Verificar após o upgrade

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
