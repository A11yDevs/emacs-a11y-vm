# Documentação para Desenvolvedores

Esta pasta contém documentação técnica para quem contribui com o projeto emacs-a11y-vm.

## Conteúdo

| Arquivo | Descrição |
|---|---|
| [constitution.md](constitution.md) | Princípios fundamentais do projeto |
| [architecture.md](architecture.md) | Arquitetura de dois discos da VM |
| [generate-vm.md](generate-vm.md) | Gerar a VM localmente com scripts |
| [manual-install.md](manual-install.md) | Instalação manual do Debian (passo a passo) |
| [releases.md](releases.md) | Pipeline de CI/CD e publicação de releases |

## Início rápido para contribuidores

```bash
# Clone o repositório
git clone https://github.com/A11yDevs/emacs-a11y-vm.git
cd emacs-a11y-vm

# Instale as dependências de teste
cd tests && pip install -r requirements.txt

# Leia a constituição do projeto antes de qualquer mudança
# docs/devs/constitution.md
```

A VM é gerada com **Packer + QEMU** no GitHub Actions. Veja [releases.md](releases.md) para entender o pipeline completo.
