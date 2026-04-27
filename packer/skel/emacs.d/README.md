# Estrutura do .emacs.d

Este diretório contém a configuração do Emacs para o emacs-a11y-vm.

## Arquivos

- **init.el** - Configuração principal do Emacs
  - Configurações de acessibilidade
  - Atalhos de teclado
  - Comportamento de edição

## Personalização

Você pode customizar livremente este arquivo. As configurações marcadas como "recomenda-se manter" são importantes para acessibilidade, mas podem ser ajustadas conforme sua preferência.

### Adicionando Pacotes

Para instalar pacotes do Emacs (MELPA, ELPA), você pode:

1. **Usar o sistema de pacotes nativo:**
   ```elisp
   ;; Adicione ao init.el:
   (require 'package)
   (add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
   (package-initialize)
   ```

2. **Usar use-package (recomendado):**
   ```elisp
   ;; Instalar use-package primeiro:
   ;; M-x package-install RET use-package RET
   
   ;; Exemplo de uso:
   (use-package magit
     :ensure t
     :bind ("C-x g" . magit-status))
   ```

3. **Usar straight.el (alternativa moderna):**
   Veja documentação em: https://github.com/radian-software/straight.el

### Configurações Específicas por Modo

Crie arquivos separados para configurações específicas:

```elisp
;; Em init.el:
(load "~/.emacs.d/python-config.el" t)
(load "~/.emacs.d/org-config.el" t)
```

## Backup

Seus backups de arquivos são salvos em `~/.emacs.d/backups/`.

Este diretório inteiro está no disco de dados persistente, então será preservado em upgrades da VM.

## Recursos

- [Manual do Emacs](https://www.gnu.org/software/emacs/manual/html_node/emacs/)
- [EmacsWiki](https://www.emacswiki.org/)
- [Guia de Customização](https://github.com/A11yDevs/emacs-a11y-vm/blob/main/docs/customization-guide.md)

## Acessibilidade

Para usar o Emacs com espeakup (síntese de voz):

- **espeakup** está habilitado no boot
- Use os comandos padrão do Emacs; a síntese de voz lerá o conteúdo
- Ajuste velocidade do espeakup: `echo "5" | sudo tee /sys/accessibility/speakup/rate`

Para mais informações sobre acessibilidade no Emacs, consulte:
https://www.emacswiki.org/emacs/Accessibility
