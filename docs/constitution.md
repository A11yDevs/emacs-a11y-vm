# Constituição do Projeto emacs-a11y-vm

Este documento registra os princípios fundamentais que guiaram as decisões de design e implementação deste projeto. Ele deve ser consultado antes de qualquer modificação ou melhoria significativa.

---

## 1. Acessibilidade é a finalidade, não um recurso adicional

A VM existe para tornar o Emacs acessível via síntese de voz. Todo componente — desde o preseed de instalação até o `init.el` padrão — deve preservar essa finalidade. Configurações que comprometam o uso com leitores de tela (espeakup, BRLTTY) não devem ser adicionadas sem justificativa explícita.

---

## 2. Público-alvo: usuários Windows

O projeto é direcionado a usuários do Windows que utilizam o VirtualBox. O script de instalação principal é `scripts/install-release-vm.ps1`. Não há suporte ativo a Linux ou macOS no fluxo de instalação de releases. Novas funcionalidades devem considerar esse contexto.

---

## 3. Arquitetura de dois discos é inviolável

A separação entre disco de sistema (VMDK) e disco de dados do usuário (VDI) é a peça central do projeto:

- **VMDK** (`/`): imutável, substituído em upgrades, gerado pelo CI.
- **VDI** (`/home`): persistente, nunca substituído, criado localmente no primeiro uso.

Qualquer modificação que misture esses papéis — armazenar dados do usuário no VMDK ou fazer o script apagar o VDI sem consentimento explícito — viola esse princípio.

---

## 4. Customizações do usuário vivem exclusivamente em `/home`

O usuário não deve modificar nada fora de `/home`. Essa restrição é documentada, reforçada pelo script de inicialização de userdata e pelo guia de customização. Scripts e documentação não devem encorajar alterações fora desse escopo.

---

## 5. Idempotência nos scripts de instalação

O script `install-release-vm.ps1` deve poder ser executado múltiplas vezes com segurança:

- Se o VMDK já existe na versão correta, não baixar novamente.
- Se a VM já está registrada com os discos corretos, não recriar.
- Se o VDI já existe, preservá-lo — nunca sobrescrever sem `-PreserveUserData` explícito.

Qualquer bloco novo adicionado ao script deve respeitar os flags `$ReuseExistingVmdk`, `$SkipVmCreation` e `$PreserveUserData`.

---

## 6. Comparação de versão, não de tamanho de arquivo

A detecção de "novo download necessário" usa o arquivo `.version` gerado ao lado do VMDK, comparando tags de release. Comparação por tamanho de arquivo é proibida: VMDKs dinâmicos crescem com uso e o tamanho se torna não-determinístico após a primeira inicialização da VM.

---

## 7. Pasta de saída estável e independente do CWD

O diretório padrão de armazenamento é `%USERPROFILE%\.emacs-a11y-vm`. Nunca usar caminhos relativos ao diretório de trabalho do PowerShell, que pode variar conforme o contexto de execução (ex.: `C:\Program Files\Oracle\VirtualBox`). O caminho absoluto deve ser resolvido via `$env:USERPROFILE` ou `$env:LOCALAPPDATA`, nunca via `$PWD` ou `Get-Location`.

---

## 8. Distribuição via GitHub Releases, não via código-fonte

O usuário final não precisa clonar o repositório. O script pode ser executado diretamente via URL com `iex (iwr ...)`. Os artefatos distribuíveis são publicados como assets em GitHub Releases (`.vmdk`, `.qcow2`). O repositório contém apenas o código de geração e instalação, não imagens binárias (exceto `releases/debian-a11ydevs.vmdk` que é o seed inicial).

---

## 9. Build automatizado e reproduzível via CI

A imagem VMDK é gerada exclusivamente via Packer + QEMU no GitHub Actions (`release.yml`). Builds manuais locais são permitidos para desenvolvimento, mas não devem produzir artefatos publicáveis. O preseed (`packer/http/preseed.cfg`) e o template HCL (`packer/debian-a11y.pkr.hcl`) são a única fonte de verdade do sistema base.

---

## 10. Sem credenciais ou dados sensíveis em código ou documentação

Nenhum script, arquivo de configuração, preseed ou exemplo de documentação deve conter senhas reais, tokens de API, chaves SSH privadas ou outros dados sensíveis. Valores padrão usados no preseed (ex.: senha de instalação) são aceitáveis apenas por serem de uma VM descartável/local, e devem ser documentados como tal.

---

## 11. VBoxManage como única interface com o VirtualBox

Toda interação com o VirtualBox nos scripts de instalação ocorre via `VBoxManage`. Não usar GUIs, COM objects ou APIs alternativas. Isso garante funcionamento em sistemas sem interface gráfica (ex.: servidores de CI, Windows Server Core) e facilita depuração.

---

## 12. Erros devem ser fatais e informativos

O script usa `$ErrorActionPreference = "Stop"`. Qualquer falha deve interromper a execução com mensagem clara de contexto. Não suprimir erros com `2>$null` ou blocos `catch` vazios. Exceções da saída de progresso do VBoxManage (ex.: `"0%..."`) são a exceção conhecida — verificar existência do arquivo resultante em vez de confiar no código de saída nesses casos.

---

## 13. Documentação acompanha cada funcionalidade

Cada comportamento relevante deve ter documentação correspondente:

- `architecture.md` → arquitetura de discos
- `customization-guide.md` → o que o usuário pode e não pode modificar
- `upgrade-guide.md` → como atualizar preservando dados
- `github-releases.md` → fluxo de CI/CD e publicação

Ao adicionar uma funcionalidade nova, atualizar o documento pertinente. Ao remover uma funcionalidade, remover ou atualizar as referências existentes.

---

## 14. Mínimo de dependências externas

O script de instalação depende apenas de PowerShell (nativo no Windows) e VirtualBox (pré-requisito documentado). Não adicionar dependências de ferramentas externas (chocolatey, winget, 7-zip, curl) sem avaliação cuidadosa. Preferir as APIs nativas do PowerShell (`Invoke-WebRequest`, `Expand-Archive`, `[System.IO.Compression.ZipFile]`).

---

## 15. VMDK monolithicSparse para evitar child media indesejados

O VMDK distribuído nas releases é gerado com `subformat=monolithicSparse` (gravável), não `streamOptimized` (read-only). 

**Razão**: `streamOptimized` é read-only por design — o VirtualBox automaticamente cria discos differencing (snapshots) para qualquer escrita, resultando em hierarquia base+child não intencional. `monolithicSparse` permite escritas diretas sem child media, mantendo a estrutura simples de dois discos (sistema VMDK + dados VDI).

**Implicação no CI**: O comando `qemu-img convert` em `.github/workflows/release.yml` usa `-o subformat=monolithicSparse` para gerar VMDKs graváveis. Não alterar para `streamOptimized` ou outros formatos read-only sem avaliar impacto no comportamento do VirtualBox.

---

## Checklist para modificações

Antes de aplicar qualquer mudança significativa ao projeto, verifique:

- [ ] A modificação preserva o funcionamento com síntese de voz?
- [ ] O script de instalação continua idempotente?
- [ ] O disco VDI do usuário é preservado em todos os caminhos de execução?
- [ ] O caminho de armazenamento é absoluto e independente do CWD?
- [ ] A documentação relevante foi atualizada?
- [ ] Nenhuma credencial ou dado sensível foi introduzido?
- [ ] A modificação funciona no contexto do público-alvo (Windows + VirtualBox)?
