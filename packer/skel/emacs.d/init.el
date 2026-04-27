;;; init.el --- Configuração base do Emacs para emacs-a11y-vm
;;
;; Este arquivo fornece uma configuração mínima e acessível do Emacs.
;; Personalize livremente, mas preserve as configurações de acessibilidade.
;;
;; Para mais informações sobre customização:
;; https://github.com/A11yDevs/emacs-a11y-vm/blob/main/docs/customization-guide.md
;;
;;; Code:

;; ==============================================================================
;; Configurações de Acessibilidade (recomenda-se manter)
;; ==============================================================================

;; Desabilitar mensagens visuais que podem interferir com leitores de tela
(setq visible-bell nil)
(setq ring-bell-function 'ignore)

;; Usar beeps audíveis para feedback (útil com síntese de voz)
;; Comente se preferir silencioso
(setq ring-bell-function 'ignore)

;; Configurar frame title para identificar buffers facilmente
(setq frame-title-format '("Emacs - %b"))

;; ==============================================================================
;; Interface e Usabilidade
;; ==============================================================================

;; Desabilitar elementos visuais desnecessários em modo textual
(when (fboundp 'menu-bar-mode) (menu-bar-mode -1))
(when (fboundp 'tool-bar-mode) (tool-bar-mode -1))
(when (fboundp 'scroll-bar-mode) (scroll-bar-mode -1))

;; Exibir número de linhas e colunas na mode-line
(line-number-mode t)
(column-number-mode t)

;; Destacar linha atual (útil com síntese de voz)
(global-hl-line-mode t)

;; Exibir par de parênteses correspondente
(show-paren-mode t)

;; ==============================================================================
;; Edição
;; ==============================================================================

;; Usar espaços ao invés de tabs
(setq-default indent-tabs-mode nil)
(setq-default tab-width 4)

;; Deletar seleção ao digitar
(delete-selection-mode t)

;; Salvar histórico de comandos
(savehist-mode t)

;; Salvar posição do cursor em arquivos
(save-place-mode t)

;; Auto-recarregar arquivos modificados externamente
(global-auto-revert-mode t)

;; ==============================================================================
;; Backup e Auto-save
;; ==============================================================================

;; Centralizar backups em diretório temporário
(setq backup-directory-alist
      `(("." . ,(concat user-emacs-directory "backups"))))

;; Criar diretório de backups se não existir
(let ((backup-dir (concat user-emacs-directory "backups")))
  (unless (file-exists-p backup-dir)
    (make-directory backup-dir t)))

;; ==============================================================================
;; Atalhos de Teclado Úteis
;; ==============================================================================

;; C-x C-b para ibuffer (melhor que list-buffers padrão)
(global-set-key (kbd "C-x C-b") 'ibuffer)

;; ==============================================================================
;; Mensagem de Boas-Vindas
;; ==============================================================================

(setq inhibit-startup-message t)
(setq initial-scratch-message
      ";; Emacs A11y VM - Configuração Base\n;;\n;; Este ambiente é otimizado para acessibilidade com síntese de voz.\n;; Customize este arquivo livremente em ~/.emacs.d/init.el\n;;\n;; C-h t - Tutorial do Emacs\n;; C-h k - Descrever tecla\n;; C-h f - Descrever função\n;;\n")

;;; init.el ends here
