# Guia de Customização da VM emacs-a11y

Este guia explica como personalizar sua VM emacs-a11y mantendo a acessibilidade e sem perder customizações em upgrades.

## Princípio Fundamental

✅ **SEGURO**: Qualquer modificação em `/home` é preservada em upgrades  
⚠️ **RISCO**: Modificações fora de `/home` serão perdidas em upgrades

A arquitetura de dois discos garante que tudo em `/home` (configurações do Emacs, dotfiles, projetos) seja preservado automaticamente.

Para entender a arquitetura, veja: [architecture.md](architecture.md)

---

## Customizando o Emacs

### Estrutura do `.emacs.d`

```
~/.emacs.d/
├── init.el           # Configuração principal (SEU arquivo)
├── README.md         # Documentação da estrutura
├── backups/          # Backups automáticos de arquivos
├── elpa/             # Pacotes instalados (gerado automaticamente)
└── custom.el         # Customizações via M-x customize (opcional)
```

### Editando a Configuração Principal

Abra o arquivo de configuração:

```bash
emacs -nw ~/.emacs.d/init.el
```

Ou dentro do Emacs:
```
C-x C-f ~/.emacs.d/init.el RET
```

### Configurações de Acessibilidade (Recomendadas)

O `init.el` padrão inclui estas configurações para acessibilidade:

```elisp
;; Desabilitar beeps visuais
(setq visible-bell nil)
(setq ring-bell-function 'ignore)

;; Frame title descritivo
(setq frame-title-format '("Emacs - %b"))

;; Destacar linha atual (útil com síntese de voz)
(global-hl-line-mode t)
```

**Você pode modificá-las conforme preferência**, mas considere como afetam o uso com síntese de voz.

### Instalando Pacotes do Emacs

#### Opção 1: Sistema de Pacotes Nativo

Adicione ao `init.el`:

```elisp
(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(add-to-list 'package-archives '("melpa-stable" . "https://stable.melpa.org/packages/") t)
(package-initialize)
```

Instalar pacotes:
```
M-x package-refresh-contents RET
M-x package-install RET nome-do-pacote RET
```

#### Opção 2: use-package (Recomendado)

Instale `use-package` primeiro:
```
M-x package-install RET use-package RET
```

Depois adicione ao `init.el`:

```elisp
(require 'use-package)
(setq use-package-always-ensure t)  ; Instala automaticamente se ausente

;; Exemplo: Magit (interface para Git)
(use-package magit
  :bind ("C-x g" . magit-status))

;; Exemplo: Company (auto-complete)
(use-package company
  :init (global-company-mode t)
  :config
  (setq company-idle-delay 0.2
        company-minimum-prefix-length 2))

;; Exemplo: Which-key (mostra atalhos disponíveis)
(use-package which-key
  :init (which-key-mode t)
  :config
  (setq which-key-idle-delay 1.0))
```

#### Opção 3: straight.el (Avançado)

Para usuários que preferem gerenciamento de pacotes baseado em Git:

```bash
# Instalar straight.el (execute dentro do Emacs)
# Cole no scratch buffer e execute com C-x C-e:
```

```elisp
(defvar bootstrap-version)
(let ((bootstrap-file
       (expand-file-name "straight/repos/straight.el/bootstrap.el" user-emacs-directory))
      (bootstrap-version 6))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-sync
         "https://raw.githubusercontent.com/radian-software/straight.el/develop/install.el"
         'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))
```

### Pacotes Recomendados para Acessibilidade

```elisp
;; Vertico: Interface de completion acessível
(use-package vertico
  :init (vertico-mode t))

;; Marginalia: Anotações descritivas em listas
(use-package marginalia
  :init (marginalia-mode t))

;; Consult: Comandos de busca melhorados
(use-package consult
  :bind (("C-s" . consult-line)
         ("C-x b" . consult-buffer)))

;; Embark: Ações contextuais
(use-package embark
  :bind ("C-." . embark-act))

;; Orderless: Matching flexível
(use-package orderless
  :custom
  (completion-styles '(orderless basic)))
```

### Organizando Configurações Grandes

Para projetos maiores, divida a configuração:

```elisp
;; Em ~/.emacs.d/init.el:
(load "~/.emacs.d/editor-config.el" t)
(load "~/.emacs.d/programming-config.el" t)
(load "~/.emacs.d/org-config.el" t)
```

```bash
# Criar arquivos separados
touch ~/.emacs.d/editor-config.el
touch ~/.emacs.d/programming-config.el
touch ~/.emacs.d/org-config.el
```

---

## Customizando o Shell (Bash)

### Editando .bashrc

```bash
emacs -nw ~/.bashrc
```

### Aliases Úteis

Adicione ao final do `.bashrc`:

```bash
# Atalhos de projeto
alias proj='cd ~/projetos'
alias docs='cd ~/documentos'

# Git aliases
alias gst='git status'
alias gco='git checkout'
alias gcm='git commit -m'
alias gpl='git pull'
alias gps='git push'

# Python
alias py='python3'
alias pip='pip3'
alias venv='python3 -m venv'

# Emacs em modo daemon
alias emacs-daemon='emacs --daemon'
alias ec='emacsclient -t'  # Conecta ao daemon
```

### Ajustando o Prompt

O sistema vem com prompt **minimalista** por padrão (`PS1='$ '`) para máxima acessibilidade. Se preferir mais informações:

```bash
# Prompt padrão (minimalista)
PS1='$ '

# Prompt com usuário e diretório
PS1='\u@\h:\w\$ '

# Prompt com cores (se terminal suportar)
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

# Prompt com status do Git (requer git-prompt)
source /usr/lib/git-core/git-sh-prompt 2>/dev/null
PS1='\u@\h:\w$(__git_ps1 " (%s)")\$ '
```

### Ajustando Tamanho do Terminal

O sistema configura automaticamente 40 linhas (`stty rows 40`) para melhor experiência com leitores de tela. Para ajustar:

```bash
# Temporário (apenas sessão atual)
stty rows 50

# Permanente (adicionar ao ~/.bashrc.local)
echo 'stty rows 50' >> ~/.bashrc.local
```

### Variáveis de Ambiente

Edite `~/.profile` (ou `~/.bash_profile`):

```bash
# Editor padrão
export EDITOR="emacs -nw"
export VISUAL="emacs -nw"

# PATH customizado
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"

# Python
export PYTHONDONTWRITEBYTECODE=1
export WORKON_HOME="$HOME/.virtualenvs"

# Go (se instalar)
export GOPATH="$HOME/go"
export PATH="$PATH:$GOPATH/bin"

# Node.js (se instalar nvm)
export NVM_DIR="$HOME/.nvm"
```

---

## Instalando Software Adicional

### Via apt (Requer sudo)

```bash
# Atualizar lista de pacotes
sudo apt update

# Instalar ferramentas de desenvolvimento
sudo apt install -y git build-essential python3-pip

# Instalar linguagens de programação
sudo apt install -y python3-dev nodejs npm golang rustc

# Instalar ferramentas de texto
sudo apt install -y pandoc texlive-base
```

⚠️ **Atenção**: Pacotes instalados com `apt` no sistema base serão **perdidos em upgrades**. Para preservar:

1. Anote os pacotes instalados:
   ```bash
   dpkg --get-selections > ~/installed-packages.txt
   ```

2. Após upgrade, reinstale:
   ```bash
   sudo apt install $(grep -v deinstall ~/installed-packages.txt | awk '{print $1}')
   ```

### Via Gerenciadores de Pacotes Locais (Preservado)

Estas ferramentas instalam em `/home` e são **preservadas automaticamente**:

#### Python: pip

```bash
# Instalar em modo usuário (--user)
pip3 install --user numpy pandas matplotlib

# Ou usar virtualenv (recomendado)
python3 -m venv ~/projetos/meu-projeto/venv
source ~/projetos/meu-projeto/venv/bin/activate
pip install numpy pandas
```

#### Node.js: nvm + npm

```bash
# Instalar nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

# Instalar Node.js
nvm install --lts
nvm use --lts

# Instalar pacotes globalmente (em ~/.nvm)
npm install -g typescript eslint prettier
```

#### Rust: rustup

```bash
# Instalar rustup
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Instalar ferramentas
cargo install ripgrep fd-find bat
```

#### Go: Binários em ~/go

```bash
# Instalar Go manualmente em ~/go
wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz
tar -C ~/ -xzf go1.21.0.linux-amd64.tar.gz

# Adicionar ao PATH em ~/.profile
export PATH="$HOME/go/bin:$PATH"

# Instalar ferramentas
go install golang.org/x/tools/gopls@latest
```

---

## Configuração de Rede

### DHCP Automático (Padrão)

A VM está configurada para obter IP automaticamente via DHCP na interface `enp0s3` (primeira interface de rede). Configuração em `/etc/network/interfaces`:

```bash
# Ver configuração atual
cat /etc/network/interfaces

# Saída esperada:
# auto lo
# iface lo inet loopback
#
# auto enp0s3
# iface enp0s3 inet dhcp
```

### Verificar Status da Rede

```bash
# Ver interfaces disponíveis
ip addr

# Verificar se interface está ativa
ip link show enp0s3

# Ver configuração DHCP obtida
ip addr show enp0s3

# Testar conectividade
ping -c 3 8.8.8.8
```

### Reiniciar Interface Manualmente

Se a rede não subir automaticamente:

```bash
# Método 1: ifup/ifdown (recomendado)
sudo ifdown enp0s3
sudo ifup enp0s3

# Método 2: systemd-networkd (se disponível)
sudo systemctl restart networking

# Método 3: forçar DHCP
sudo dhclient -r enp0s3  # release
sudo dhclient enp0s3     # request
```

### IP Estático (Opcional)

Para configurar IP fixo, edite `/etc/network/interfaces`:

```bash
# IMPORTANTE: Fazer backup primeiro
sudo cp /etc/network/interfaces /home/a11ydevs/interfaces.backup

# Editar configuração
sudo nano /etc/network/interfaces

# Substituir "iface enp0s3 inet dhcp" por:
auto enp0s3
iface enp0s3 inet static
    address 192.168.1.100
    netmask 255.255.255.0
    gateway 192.168.1.1
    dns-nameservers 8.8.8.8 8.8.4.4

# Aplicar
sudo ifdown enp0s3 && sudo ifup enp0s3
```

⚠️ **IMPORTANTE**: Modificações em `/etc/network/interfaces` são **preservadas em upgrades** (arquivo está fora do sistema base).

### Modo de Rede no VirtualBox

A VM pode usar dois modos:

- **Bridge** (padrão): VM recebe IP da rede local (acesso direto)
- **NAT**: VM usa rede privada com port forwarding (SSH: localhost:2222)

Para alternar, reconfigure a VM pelo VirtualBox Manager ou pelos scripts de instalação.

---

## Ajustando Acessibilidade

### Configuração da Voz (espeakup)

A VM vem configurada com voz **pt-br** (português brasileiro) por padrão. Configurações em `/etc/default/espeakup`:

```bash
# Ver configuração atual
cat /etc/default/espeakup

# Exemplo de conteúdo:
# default_voice=pt-br
# default_rate=120
# default_volume=100
# default_pitch=50
```

**Modificar configurações:**

```bash
# Editar configuração (requer sudo, será perdido em upgrades)
sudo nano /etc/default/espeakup

# Reiniciar serviços para aplicar
sudo systemctl restart espeakup
sudo systemctl restart configure-speakup
```

**Como funcionam os parâmetros:**

O `espeakup` reconhece apenas `default_voice`. Os parâmetros `default_rate`, `default_pitch` e `default_volume` são convertidos automaticamente pelo script `configure-speakup.service` que os aplica via `/sys/accessibility/speakup/soft/`:

- **default_rate** (80-450, padrão: 120): Convertido para speakup rate (0-9)
  - Fórmula: `(rate - 80) / 40`
  - Exemplo: 160 → 7, 200 → 9
  
- **default_pitch** (0-99, padrão: 50): Convertido para speakup pitch (0-9)
  - Fórmula: `pitch / 10`
  - Exemplo: 50 → 5, 70 → 7

- **default_volume** (0-200, padrão: 100): Convertido para speakup vol (0-9)
  - Fórmula: `volume / 20`
  - Exemplo: 100 → 5, 160 → 8

⚠️ **IMPORTANTE**: Modificações em `/etc/default/espeakup` são **perdidas em upgrades**.  
✅ **Solução**: Copie o arquivo para `/home` e crie link simbólico:

```bash
# Copiar configuração para /home (preservado)
cp /etc/default/espeakup ~/.espeakup.conf

# Editar sua cópia (use default_voice, default_rate, default_volume, default_pitch)
nano ~/.espeakup.conf

# Criar link (após cada upgrade)
sudo ln -sf ~/.espeakup.conf /etc/default/espeakup
sudo systemctl restart espeakup
```

### Problema: Demora ao Parar o Serviço espeakup

Se `systemctl stop espeakup` demorar muito (>90 segundos), aplique este fix:

```bash
# Criar override de timeout
sudo mkdir -p /etc/systemd/system/espeakup.service.d
sudo tee /etc/systemd/system/espeakup.service.d/timeout.conf <<EOF
[Service]
TimeoutStopSec=5s
EOF

# Recarregar configuração
sudo systemctl daemon-reload

# Testar (agora deve parar em até 5 segundos)
sudo systemctl restart espeakup
```

**Explicação**: O timeout padrão do systemd é 90 segundos. Este override reduz para 5 segundos, tornando comandos `stop`/`restart` mais rápidos.

✅ Este arquivo em `/etc/systemd/system/espeakup.service.d/` **é preservado em upgrades** (diferente de `/etc/default/espeakup`).

**Verificar aplicação:**

```bash
# Ver configuração ativa do serviço
systemctl show espeakup -p TimeoutStopUSec

# Deve mostrar: TimeoutStopUSec=5s
```

### Vozes Disponíveis

```bash
# Listar todas as vozes
espeak --voices

# Testar voz em português brasileiro
espeak -v pt-br "Testando síntese de voz"

# Outras vozes em português:
espeak -v pt "Testando português de Portugal"
```

### Ajustes em Tempo Real (Temporários)

```bash
# Velocidade (rate: 80-450, padrão: 120)
# Menor = mais lento, maior = mais rápido
echo "5" | sudo tee /sys/accessibility/speakup/rate

# Volume (0-9, padrão 5)
echo "8" | sudo tee /sys/accessibility/speakup/volume

# Pitch/Tom (0-9, padrão 5)
# Menor = grave, maior = agudo
echo "6" | sudo tee /sys/accessibility/speakup/pitch
```

⚠️ **Nota**: Ajustes via `/sys/accessibility/speakup/` são temporários e resetam ao reiniciar.

---

## Criando Projetos

### Estrutura Recomendada

```bash
# Criar diretório de projetos
mkdir -p ~/projetos

# Exemplo: Projeto Python
mkdir -p ~/projetos/meu-app
cd ~/projetos/meu-app
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Exemplo: Projeto Node.js
mkdir -p ~/projetos/webapp
cd ~/projetos/webapp
npm init -y
npm install express
```

### Integração com Git

```bash
# Configurar Git
git config --global user.name "Seu Nome"
git config --global user.email "seu@email.com"

# Inicializar repositório
cd ~/projetos/meu-projeto
git init
git add .
git commit -m "Initial commit"

# Conectar a repositório remoto
git remote add origin git@github.com:usuario/repo.git
git push -u origin main
```

---

## Backup de Configurações

### Backup Manual

```bash
# Backup completo do home
tar czf ~/backup-home-$(date +%Y%m%d).tar.gz \
  --exclude=.cache \
  --exclude=.local/share/Trash \
  ~/

# Apenas configurações essenciais
tar czf ~/backup-configs-$(date +%Y%m%d).tar.gz \
  ~/.emacs.d \
  ~/.bashrc \
  ~/.profile \
  ~/.gitconfig
```

### Backup via Git (Dotfiles)

```bash
# Criar repositório de dotfiles
mkdir ~/dotfiles
cd ~/dotfiles
git init

# Copiar configurações
cp ~/.emacs.d/init.el emacs-init.el
cp ~/.bashrc bashrc
cp ~/.profile profile

# Versionar
git add .
git commit -m "Backup de configurações"
git remote add origin git@github.com:usuario/dotfiles.git
git push -u origin main
```

### Backup Automático do Disco de Dados

No **host** (fora da VM):

```bash
# Script de backup do VDI
#!/bin/bash
VBoxManage clonemedium disk \
  releases/debian-a11y-userdata.vdi \
  backups/debian-a11y-userdata-$(date +%Y%m%d).vdi

# Manter apenas últimos 5 backups
cd backups
ls -t debian-a11y-userdata-*.vdi | tail -n +6 | xargs rm -f
```

---

## Testando Customizações

### Testando Configuração do Emacs

```bash
# Iniciar Emacs sem carregar init.el
emacs -nw -q

# Iniciar Emacs carregando apenas um arquivo de teste
emacs -nw -l ~/test-config.el
```

### Testando Bashrc

```bash
# Carregar .bashrc em nova sessão
bash --rcfile ~/.bashrc
```

### Validando Sintaxe

```bash
# Bash
bash -n ~/.bashrc

# Emacs Lisp (dentro do Emacs)
M-x check-parens
M-x byte-compile-file RET ~/.emacs.d/init.el RET
```

---

## Recursos e Referências

### Emacs

- [Manual oficial do Emacs](https://www.gnu.org/software/emacs/manual/html_node/emacs/)
- [EmacsWiki](https://www.emacswiki.org/)
- [r/emacs](https://www.reddit.com/r/emacs/)
- [Awesome Emacs](https://github.com/emacs-tw/awesome-emacs)

### Bash

- [GNU Bash Manual](https://www.gnu.org/software/bash/manual/)
- [Bash Guide for Beginners](https://tldp.org/LDP/Bash-Beginners-Guide/html/)

### Acessibilidade

- [Emacs Accessibility](https://www.emacswiki.org/emacs/Accessibility)
- [Speakup Documentation](https://www.linux-speakup.org/)

### Relacionados

- [Arquitetura da VM](architecture.md)
- [Guia de Upgrade](upgrade-guide.md)
- [README Principal](../README.md)

---

## Perguntas Frequentes

### Minhas customizações serão perdidas em upgrades?

**Não**, se estiverem em `/home`. A arquitetura de dois discos preserva automaticamente tudo em `/home`.

### Posso instalar um desktop environment (GNOME, KDE)?

**Tecnicamente sim**, mas não é recomendado para este projeto focado em acessibilidade textual. Se instalar via `apt`, será perdido em upgrades.

### Como sei se uma customização é segura?

**Regra de ouro**: Se está em `/home` → seguro. Se está fora de `/home` → será perdido.

### Posso usar múltiplos usuários?

**Sim**, o disco de dados monta `/home` inteiro. Crie usuários normalmente:

```bash
sudo adduser outro-usuario
```

### Como restaurar configurações padrão?

```bash
# Backup do atual
mv ~/.emacs.d ~/.emacs.d.backup

# Copiar padrão novamente
cp -r /etc/skel/emacs-a11y/emacs.d ~/.emacs.d
```
