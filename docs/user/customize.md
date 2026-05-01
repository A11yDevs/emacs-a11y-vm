# Personalizando a VM emacs-a11y

Tudo que você personalizar em `/home` é preservado automaticamente em upgrades.  
Nunca é necessário modificar arquivos fora de `/home`.

---

## Emacs

### Editar a configuração principal

```bash
emacs -nw ~/.emacs.d/init.el
```

### Instalar pacotes com `use-package`

Adicione ao `init.el`:

```elisp
(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

(require 'use-package)
(setq use-package-always-ensure t)

;; Exemplo: Magit (interface para Git)
(use-package magit
  :bind ("C-x g" . magit-status))

;; Exemplo: Which-key (mostra atalhos disponíveis em pausa)
(use-package which-key
  :init (which-key-mode t))
```

Para instalar `use-package` antes disso:

```
M-x package-install RET use-package RET
```

### Pacotes recomendados para acessibilidade

```elisp
;; Vertico: completion acessível
(use-package vertico :init (vertico-mode t))

;; Marginalia: descrições nas listas
(use-package marginalia :init (marginalia-mode t))

;; Orderless: matching flexível
(use-package orderless
  :custom (completion-styles '(orderless basic)))
```

---

## Shell (Bash)

### Editar o `.bashrc`

```bash
emacs -nw ~/.bashrc
```

### Aliases úteis

```bash
# Atalhos de projeto
alias proj='cd ~/projetos'

# Git
alias gst='git status'
alias gcm='git commit -m'

# Emacs no terminal
alias e='emacs -nw'
```

Após editar, recarregue:

```bash
source ~/.bashrc
```

---

## Seus arquivos

Crie pastas em `/home` para organizar seus projetos:

```bash
mkdir -p ~/projetos ~/documentos
```

Tudo nessas pastas é preservado em upgrades da VM.

---

## Mais informações

A arquitetura de dois discos que garante a preservação dos seus dados está documentada em [docs/devs/architecture.md](../devs/architecture.md).
